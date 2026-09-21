namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

// Carga inicial del historial de convenio y categoría: toma el par que cada empleado ya tiene —en su
// ficha o en su asignación a proyecto— y lo escribe como atributos con una fecha de inicio común.
//
// Es un proceso de migración, no de operación: se corre una vez al pasar de los campos sueltos de la
// ficha al historial con vigencias. De ahí en adelante los cambios se cargan como una vigencia nueva
// en cada empleado, que es justamente lo que los campos de la ficha no podían representar.
//
// Los dos tipos de atributo NO se nombran acá: se buscan por su espejo. El que refleja Convenio
// Colectivo es el del convenio y el que refleja Categoría CCT es el de la categoría, se llamen como
// se llamen. Escribir 'CONVENIO' a mano en este proceso habría sido otra copia de una decisión que ya
// está tomada en la configuración.
report 50046 "Migrar Convenio y Categoría"
{
    ApplicationArea = All;
    Caption = 'Migrar Convenio y Categoría a Atributos';
    UsageCategory = Tasks;
    ProcessingOnly = true;

    dataset
    {
        dataitem(Empleado; Employee)
        {
            RequestFilterFields = "No.", Status, "Cód. Convenio";

            trigger OnPreDataItem()
            begin
                Preparar();
            end;

            trigger OnAfterGetRecord()
            begin
                Procesar(Empleado);
            end;

            trigger OnPostDataItem()
            begin
                Terminar();
            end;
        }
    }

    requestpage
    {
        layout
        {
            area(Content)
            {
                group(Que)
                {
                    Caption = 'Qué migrar';

                    field(FechaInicioFld; FechaInicio)
                    {
                        ApplicationArea = All;
                        Caption = 'Vigencia desde';
                        ToolTip = 'Fecha de inicio de la primera vigencia. Es el día desde el que el par convenio/categoría queda registrado como historial; lo anterior a esa fecha queda sin cubrir.';
                    }
                    field(SimularFld; Simular)
                    {
                        ApplicationArea = All;
                        Caption = 'Solo simular';
                        ToolTip = 'Recorre todo y te dice qué haría, sin escribir nada. Conviene correrlo así la primera vez y mirar el detalle de los que no se pueden migrar.';
                    }
                }
            }
        }

        trigger OnOpenPage()
        begin
            if FechaInicio = 0D then
                FechaInicio := DMY2Date(1, 1, 2026);
        end;
    }

    // ── Proceso ───────────────────────────────────────────────────────────────

    local procedure Preparar()
    begin
        if FechaInicio = 0D then
            Error(ErrFaltaFecha);

        FTipoConvenio := TipoConEspejo("Espejo Atributo Liq."::"Convenio Colectivo");
        FTipoCategoria := TipoConEspejo("Espejo Atributo Liq."::"Categoría CCT");
        if FTipoConvenio = '' then
            Error(ErrSinTipoEspejo, Format("Espejo Atributo Liq."::"Convenio Colectivo"));
        if FTipoCategoria = '' then
            Error(ErrSinTipoEspejo, Format("Espejo Atributo Liq."::"Categoría CCT"));

        Progreso.Open(TxtProgreso);
    end;

    /// <remarks>
    /// El convenio se escribe SIEMPRE antes que la categoría: la categoría depende de él y su
    /// validación busca el valor del padre vigente a esa misma fecha. Al revés, cada empleado
    /// fallaría con "no tiene convenio vigente" en la primera fila.
    /// </remarks>
    local procedure Procesar(var Emp: Record Employee)
    var
        Convenio: Code[20];
        Categoria: Code[20];
    begin
        Vistos += 1;
        Progreso.Update(1, Emp."No." + '  ' + Emp."First Name" + ' ' + Emp."Last Name");
        Progreso.Update(2, Migrados);

        ResolverPar(Emp, Convenio, Categoria);
        if Convenio = '' then begin
            Anotar(Emp."No.", TxtSinDatos);
            SinDatos += 1;
            exit;
        end;

        if not Asignar(Emp."No.", FTipoConvenio, Convenio) then
            exit;
        // Sin categoría el empleado queda con su convenio y nada más, que es un estado válido: hay
        // personal fuera de convenio y personal sin categoría asignada.
        if Categoria <> '' then
            if not Asignar(Emp."No.", FTipoCategoria, Categoria) then
                exit;

        Migrados += 1;
    end;

    /// <summary>El par del empleado, de su ficha.</summary>
    /// <remarks>
    /// Antes esto podia tomarlo tambien de la asignacion a proyecto, con una opcion para elegir cual
    /// ganaba cuando diferian. Esos campos se eliminaron de Personal Proyecto el 18/9/2026: el par vive
    /// en los atributos y el puesto en el suyo, asi que la ficha quedo como unica fuente posible y la
    /// opcion no tenia nada que elegir.
    /// </remarks>
    local procedure ResolverPar(var Emp: Record Employee; var Convenio: Code[20]; var Categoria: Code[20])
    begin
        Convenio := Emp."Cód. Convenio";
        Categoria := Emp."Cód. Categoría";
    end;

    /// <summary>Escribe una vigencia. False si no se pudo, y queda anotado el motivo.</summary>
    /// <remarks>
    /// Un empleado que falla NO corta el proceso: en una migración de cientos, abortar en el número
    /// 50 deja el trabajo a medias y sin registro de qué entró y qué no. Se anota y se sigue, y al
    /// final el detalle sale junto.
    /// </remarks>
    local procedure Asignar(EmployeeNo: Code[20]; CodTipo: Code[20]; CodValor: Code[20]): Boolean
    var
        Atributo: Record "Atributo Entidad Liq.";
    begin
        // Ya tiene algo cargado en esa fecha: no se pisa. El historial existente manda sobre una
        // migración, que por definición es una reconstrucción aproximada.
        Atributo.SetRange("Tipo Entidad", Atributo."Tipo Entidad"::Empleado);
        Atributo.SetRange("Cód. Entidad", EmployeeNo);
        Atributo.SetRange("Cód. Tipo Atributo", CodTipo);
        if not Atributo.IsEmpty() then begin
            Anotar(EmployeeNo, StrSubstNo(TxtYaTiene, CodTipo));
            YaTenian += 1;
            exit(false);
        end;

        if Simular then begin
            Anotar(EmployeeNo, StrSubstNo(TxtSimulado, CodTipo, CodValor));
            exit(true);
        end;

        Clear(Atributo);
        Atributo."Tipo Entidad" := Atributo."Tipo Entidad"::Empleado;
        Atributo."Cód. Entidad" := EmployeeNo;
        Atributo."Cód. Tipo Atributo" := CodTipo;
        Atributo."Vigencia Desde" := FechaInicio;
        Atributo."Cód. Valor" := CodValor;

        // Cada alta en su propia transacción: un código que quedó en la ficha y ya no existe en el
        // maestro tiene que dejar registro y no voltear la corrida entera. El Commit es lo que
        // habilita a leer el resultado del Run — sin él, la plataforma no deja usar el valor de
        // retorno cuando la vuelta anterior dejó escrituras pendientes.
        Commit();
        if not FAlta.Run(Atributo) then begin
            Anotar(EmployeeNo, StrSubstNo(TxtFallo, CodTipo, CodValor, GetLastErrorText()));
            Fallidos += 1;
            exit(false);
        end;
        exit(true);
    end;

    // Delegado y no repetido: "cuál es el atributo del convenio" tiene que ser la misma respuesta acá
    // que en el motor, o la migración cargaría un atributo y el cálculo leería otro.
    local procedure TipoConEspejo(Espejo: Enum "Espejo Atributo Liq."): Code[20]
    var
        ParCCT: Codeunit "Convenio Categoría Liq.";
    begin
        exit(ParCCT.TipoConEspejo(Espejo));
    end;

    local procedure Anotar(EmployeeNo: Code[20]; Motivo: Text)
    begin
        if Detalle.Length() > 3000 then
            exit;
        Detalle.AppendLine(EmployeeNo + ': ' + Motivo);
    end;

    local procedure Terminar()
    begin
        Progreso.Close();
        if Simular then
            Message(MsgSimulacion, Vistos, Migrados, YaTenian, SinDatos, Fallidos, Detalle.ToText())
        else
            Message(MsgResultado, Vistos, Migrados, YaTenian, SinDatos, Fallidos, Detalle.ToText());
    end;

    var
        FAlta: Codeunit "Alta Atributo Entidad Liq.";
        Progreso: Dialog;
        Detalle: TextBuilder;
        FTipoConvenio: Code[20];
        FTipoCategoria: Code[20];
        FechaInicio: Date;
        Simular: Boolean;
        Vistos: Integer;
        Migrados: Integer;
        YaTenian: Integer;
        SinDatos: Integer;
        Fallidos: Integer;
        TxtProgreso: Label 'Migrando convenio y categoría\\Empleado #1##################################\Migrados #2########';
        TxtSinDatos: Label 'sin convenio cargado en el origen elegido';
        TxtYaTiene: Label 'ya tiene historial de %1, no se toca', Comment = '%1=código del tipo de atributo';
        TxtSimulado: Label 'se cargaría %1 = %2', Comment = '%1=tipo de atributo, %2=valor';
        TxtFallo: Label 'no se pudo cargar %1 = %2 (%3)', Comment = '%1=tipo de atributo, %2=valor, %3=error';
        ErrFaltaFecha: Label 'Indicá desde qué fecha rige el historial.';
        ErrSinTipoEspejo: Label 'No hay ningún tipo de atributo declarado como espejo de %1. Configuralo antes de migrar: es el que dice cuál de los atributos guarda ese dato.', Comment = '%1=nombre del maestro';
        MsgResultado: Label '%1 empleado(s) recorridos.\\Migrados: %2\Ya tenían historial: %3\Sin datos de origen: %4\Con error: %5\\%6', Comment = '%1..%5=cantidades, %6=detalle';
        MsgSimulacion: Label 'SIMULACIÓN — no se escribió nada.\\%1 empleado(s) recorridos.\\Se migrarían: %2\Ya tienen historial: %3\Sin datos de origen: %4\Con error: %5\\%6', Comment = '%1..%5=cantidades, %6=detalle';
}
