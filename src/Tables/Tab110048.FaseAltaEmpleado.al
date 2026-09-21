namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

/// <summary>
/// Los períodos de relación laboral de un empleado: desde el alta hasta la baja. Una fila por fase.
/// </summary>
/// <remarks>
/// POR QUÉ ES UNA TABLA Y NO UNA VISTA DEL HISTORIAL DE ESTADOS.
///
/// Hasta ahora el alta y la baja vivían como dos filas de "Estado Empleado", y las fases se armaban
/// recorriéndolo. Eso mete dos cosas ortogonales en una tabla que admite UN estado por empleado por
/// fecha, y las hace competir por el mismo día: el día que alguien ingresa y embarca, Meta4 registra
/// las dos cosas —el alta y el estado operativo— y las dos son ciertas. En el modelo viejo una tenía
/// que perder. En la migración de enero eso eran 153 filas, y no por datos sucios: por el modelo.
///
/// Meta4 lo tiene bien separado desde siempre: M4T_FASES_ALTA para altas y bajas,
/// M4T_HIST_ESTADOS_EMPL para lo operativo. Acá se hace igual.
///
/// QUÉ QUEDA DE CADA LADO:
///   · Esta tabla   → cuándo la persona pertenece a la empresa. No tiene proyecto ni continuidad
///                    diaria: son tramos, y entre dos fases puede haber años sin nada.
///   · "Estado Empleado" → qué estaba haciendo cada día, con su proyecto. Contiguo, sin huecos, y
///                    ahora SIN altas ni bajas: la tabla lo rechaza activamente.
///
/// LOS MOTIVOS SIGUEN EN "Cód. Estado Empleado", filtrados por Tipo Alta y Tipo Baja. No se duplica
/// el catálogo: los códigos ya existen con su semántica (ALT, BAJ-1, BAJ-7, BAJ-8, BAJ-9, BAJ-12) y
/// tenerlos en dos lugares es garantizar que algún día digan cosas distintas.
///
/// LA ANTIGÜEDAD SE CALCULA DE ACÁ. Antes salía de recorrer el historial abriendo en cada Alta y
/// cerrando en cada Baja; ahora el tramo ya está escrito. Una fase sin "Fecha Baja" es la vigente y
/// se mide contra la fecha de referencia.
/// </remarks>
table 110048 "Fase Alta Empleado"
{
    Caption = 'Fases de Alta del Empleado';
    DataClassification = CustomerContent;
    LookupPageId = "Fases De Alta";
    DrillDownPageId = "Fases De Alta";

    fields
    {
        field(1; "No. Empleado"; Code[20])
        {
            Caption = 'Cód. Legajo';
            DataClassification = CustomerContent;
            TableRelation = Employee."No.";
            NotBlank = true;
        }
        field(2; "No. Fase"; Integer)
        {
            Caption = 'Fase';
            DataClassification = CustomerContent;
            // Correlativo por empleado, no global: la primera fase de cada persona es la 1. Lo asigna
            // AbrirFase, que mira el máximo existente.
        }
        field(10; "Fecha Alta"; Date)
        {
            Caption = 'Fecha Alta';
            DataClassification = CustomerContent;
            NotBlank = true;

            trigger OnValidate()
            begin
                ValidarOrdenDeFechas();
            end;
        }
        field(11; "Cód. Motivo Alta"; Code[20])
        {
            Caption = 'Motivo del Alta';
            DataClassification = CustomerContent;
            TableRelation = "Cód. Estado Empleado".Código where("Tipo Estado" = const(Alta));
        }
        field(12; "Comentario Alta"; Text[250])
        {
            Caption = 'Comentario del Alta';
            DataClassification = CustomerContent;
        }
        field(20; "Fecha Baja"; Date)
        {
            Caption = 'Fecha Baja';
            DataClassification = CustomerContent;
            // Vacía = fase abierta, la persona sigue en la empresa.

            trigger OnValidate()
            begin
                ValidarOrdenDeFechas();
            end;
        }
        field(21; "Cód. Motivo Baja"; Code[20])
        {
            Caption = 'Motivo de la Baja';
            DataClassification = CustomerContent;
            TableRelation = "Cód. Estado Empleado".Código where("Tipo Estado" = const(Baja));
            // De acá salen los atributos indemnizatorios de la baja. Hoy viven como prosa en la
            // Descripción Ampliada del código; el día que se tipifiquen (% Indem. Antigüedad,
            // Genera Preaviso, Genera Integración) se leen desde este campo sin tocar esta tabla.
        }
        field(22; "Comentario Baja"; Text[250])
        {
            Caption = 'Comentario de la Baja';
            DataClassification = CustomerContent;
        }
        field(30; Días; Integer)
        {
            Caption = 'Días';
            DataClassification = CustomerContent;
            Editable = false;
            // Se recalcula al guardar. En la fase abierta queda en cero: no se puede escribir un
            // número que depende de "hoy" en una tabla que se lee mañana. Lo mide CalcDias.
        }
        field(31; Abierta; Boolean)
        {
            Caption = 'Abierta';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }

    keys
    {
        key(PK; "No. Empleado", "No. Fase") { Clustered = true; }
        key(PorAlta; "No. Empleado", "Fecha Alta") { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "No. Empleado", "Fecha Alta", "Fecha Baja") { }
    }

    trigger OnInsert()
    begin
        ValidarOrdenDeFechas();
        ValidarSinSuperposicion();
        Recalcular();
        CerrarEstadosPorBaja();
    end;

    trigger OnModify()
    begin
        ValidarOrdenDeFechas();
        ValidarSinSuperposicion();
        Recalcular();
        CerrarEstadosPorBaja();
    end;

    local procedure Recalcular()
    begin
        Abierta := "Fecha Baja" = 0D;
        if Abierta then
            Días := 0
        else
            Días := "Fecha Baja" - "Fecha Alta";
    end;

    /// <summary>
    /// Cerrar la fase cierra los estados operativos que quedarían pasados de la baja.
    /// </summary>
    /// <remarks>
    /// La tabla de estados ya impide cargar un estado FUERA de una fase (ValidarDentroDeFaseDeAlta),
    /// pero nada cubría la dirección contraria: cerrar la fase dejaba el último estado abierto. Y un
    /// estado sin fecha fin no vale hasta la baja — vale hasta el 31/12/9999, que es lo que devuelve
    /// FechaFinEfectiva cuando no hay siguiente. De ahí salían los estados de 2001 que se solapaban
    /// con enero de 2026 y metían a gente que no estaba en el lote y en el control de cobertura.
    ///
    /// Alcanza a los estados que EMPIEZAN dentro de la fase: son los que esta baja cierra. Uno que
    /// arranca después de la baja no es asunto de esta fase — es un error de dato aparte, y moverlo
    /// desde acá sería taparlo.
    ///
    /// MODIFY(FALSE) Y NO MODIFY(TRUE), por dos razones concretas:
    ///   · El OnModify de "Estado Empleado" empuja el estado SIGUIENTE cuando cambia la fecha fin.
    ///     Acortar contra una baja no debe arrastrar nada: lo que venga después pertenece a otra
    ///     fase, o es justamente uno de los estados fuera de fase que hay que revisar a mano.
    ///   · Ese mismo trigger bloquea si hay una liquidación sobre el tramo. Que exista una
    ///     liquidación vieja no es motivo para impedir registrar una baja: la baja es el hecho, y la
    ///     inconsistencia de la liquidación se resuelve recalculándola.
    /// </remarks>
    local procedure CerrarEstadosPorBaja()
    var
        EstadoEmp: Record "Estado Empleado";
    begin
        if ("Fecha Baja" = 0D) or ("No. Empleado" = '') then
            exit;

        EstadoEmp.SetRange("Tipo Entidad", EstadoEmp."Tipo Entidad"::Empleado);
        EstadoEmp.SetRange("No. Empleado", "No. Empleado");
        EstadoEmp.SetRange("Fecha Inicio", "Fecha Alta", "Fecha Baja");
        // Abierto, o cerrado más allá de la baja. El que ya termina antes no se toca.
        EstadoEmp.SetFilter("Fecha Fin", '%1|>%2', 0D, "Fecha Baja");
        if EstadoEmp.FindSet(true) then
            repeat
                EstadoEmp."Fecha Fin" := "Fecha Baja";
                EstadoEmp.Modify(false);
            until EstadoEmp.Next() = 0;
    end;

    /// <summary>
    /// Una baja no puede ser anterior a su alta.
    /// </summary>
    /// <remarks>
    /// Vive en la tabla y no en CerrarFase porque las fases también se editan a mano y se cargan por
    /// migración. Una fase de días negativos no da error en ningún lado: RESTA antigüedad, y el
    /// resultado es una persona con menos años de los que tiene.
    /// </remarks>
    local procedure ValidarOrdenDeFechas()
    begin
        if ("Fecha Alta" = 0D) or ("Fecha Baja" = 0D) then
            exit;
        if "Fecha Baja" < "Fecha Alta" then
            Error(ErrBajaAntesDelAlta, "Fecha Baja", "Fecha Alta", "No. Empleado");
    end;

    /// <summary>
    /// Dos fases del mismo empleado no pueden solaparse.
    /// </summary>
    /// <remarks>
    /// Es la regla que sostiene el cálculo de antigüedad: CalcDiasHasta suma los días de cada fase
    /// sin mirar a las otras, así que dos tramos superpuestos cuentan los días compartidos dos veces.
    /// Nadie lo nota hasta que alguien cobra una antigüedad mayor que su vida laboral.
    ///
    /// La fase abierta se trata como si terminara en el infinito: si hay una abierta, ninguna otra
    /// puede empezar después de ella.
    /// </remarks>
    local procedure ValidarSinSuperposicion()
    var
        Otra: Record "Fase Alta Empleado";
        FinPropio: Date;
        FinOtra: Date;
    begin
        if ("No. Empleado" = '') or ("Fecha Alta" = 0D) then
            exit;

        FinPropio := "Fecha Baja";
        if FinPropio = 0D then
            FinPropio := DMY2Date(31, 12, 9999);

        Otra.SetRange("No. Empleado", "No. Empleado");
        Otra.SetFilter("No. Fase", '<>%1', "No. Fase");
        if Otra.FindSet() then
            repeat
                FinOtra := Otra."Fecha Baja";
                if FinOtra = 0D then
                    FinOtra := DMY2Date(31, 12, 9999);

                // Dos tramos se solapan si cada uno empieza antes de que el otro termine.
                if ("Fecha Alta" <= FinOtra) and (Otra."Fecha Alta" <= FinPropio) then
                    Error(ErrSuperpuesta, "No. Fase", Otra."No. Fase", "No. Empleado",
                          Otra."Fecha Alta", Otra."Fecha Baja");
            until Otra.Next() = 0;
    end;

    /// <summary>
    /// Abre una fase para el empleado. Si ya tiene una abierta, no hace nada y devuelve false.
    /// </summary>
    /// <remarks>
    /// No abrir dos fases superpuestas es la regla que sostiene el cálculo de antigüedad: dos tramos
    /// abiertos a la vez suman los mismos días dos veces, y el resultado es un número más grande que
    /// la vida laboral de la persona. Nadie lo mira hasta que alguien cobra una antigüedad que no le
    /// corresponde.
    /// </remarks>
    procedure AbrirFase(EmployeeNo: Code[20]; FechaAlta: Date; Motivo: Code[20]; Comentario: Text): Boolean
    var
        Existente: Record "Fase Alta Empleado";
        Ultima: Integer;
    begin
        if (EmployeeNo = '') or (FechaAlta = 0D) then
            exit(false);

        if TieneFaseAbierta(EmployeeNo) then
            exit(false);

        Existente.SetRange("No. Empleado", EmployeeNo);
        if Existente.FindLast() then
            Ultima := Existente."No. Fase";

        Init();
        "No. Empleado" := EmployeeNo;
        "No. Fase" := Ultima + 1;
        "Fecha Alta" := FechaAlta;
        "Cód. Motivo Alta" := Motivo;
        "Comentario Alta" := CopyStr(Comentario, 1, MaxStrLen("Comentario Alta"));
        Insert(true);
        exit(true);
    end;

    /// <summary>
    /// Cierra la fase abierta del empleado. False si no había ninguna abierta.
    /// </summary>
    procedure CerrarFase(EmployeeNo: Code[20]; FechaBaja: Date; Motivo: Code[20]; Comentario: Text): Boolean
    var
        Abierta2: Record "Fase Alta Empleado";
    begin
        if not BuscarAbierta(EmployeeNo, Abierta2) then
            exit(false);

        // El orden de las fechas lo valida la tabla, no este procedimiento: las fases también se
        // editan a mano y se cargan por migración, y la regla tiene que valer por los tres caminos.
        Abierta2."Fecha Baja" := FechaBaja;
        Abierta2."Cód. Motivo Baja" := Motivo;
        Abierta2."Comentario Baja" := CopyStr(Comentario, 1, MaxStrLen(Abierta2."Comentario Baja"));
        Abierta2.Modify(true);
        exit(true);
    end;

    procedure TieneFaseAbierta(EmployeeNo: Code[20]): Boolean
    var
        Dummy: Record "Fase Alta Empleado";
    begin
        exit(BuscarAbierta(EmployeeNo, Dummy));
    end;

    procedure BuscarAbierta(EmployeeNo: Code[20]; var Fase: Record "Fase Alta Empleado"): Boolean
    begin
        Fase.Reset();
        Fase.SetRange("No. Empleado", EmployeeNo);
        Fase.SetRange("Fecha Baja", 0D);
        exit(Fase.FindLast());
    end;

    /// <summary>
    /// ¿La persona pertenecía a la empresa en algún momento de ese rango?
    /// </summary>
    /// <remarks>
    /// Es la pregunta que el lote NO hacía. Elegía a la gente por la asignación a proyecto, que
    /// puede quedar abierta cuando alguien se va —y con una fila por par empleado+proyecto, también
    /// ATRAVIESA el hueco entre dos temporadas—, así que generaba liquidaciones de gente que ese mes
    /// no estaba. En enero de 2026 fueron 47, todas sin una sola línea.
    ///
    /// La intersección es la de siempre: una fase que empiece antes del fin del rango y que termine
    /// después del principio. La baja en blanco es "todavía no terminó".
    ///
    /// SIN FASES CARGADAS DEVUELVE TRUE, y es deliberado. Un legajo sin fases no dice "no estaba",
    /// dice "no lo sabemos": la migración pudo no alcanzarlo. El precio de equivocarse no es
    /// simétrico —de más, sale una liquidación vacía que se borra; de menos, alguien no cobra— así
    /// que ante la duda entra.
    /// </remarks>
    procedure EstuvoActivoEntre(EmployeeNo: Code[20]; Desde: Date; Hasta: Date): Boolean
    var
        Fase: Record "Fase Alta Empleado";
    begin
        if EmployeeNo = '' then
            exit(false);

        Fase.SetRange("No. Empleado", EmployeeNo);
        if Fase.IsEmpty() then
            exit(true);

        if Hasta <> 0D then
            Fase.SetFilter("Fecha Alta", '<=%1', Hasta);
        if Desde <> 0D then
            Fase.SetFilter("Fecha Baja", '%1|>=%2', 0D, Desde);
        exit(not Fase.IsEmpty());
    end;

    /// <summary>
    /// Días de relación laboral acumulados hasta la fecha de referencia, sumando todas las fases.
    /// </summary>
    /// <remarks>
    /// La fase abierta se mide contra FechaRef, no contra "hoy": la antigüedad de una liquidación de
    /// enero se calcula al 31 de enero aunque se recalcule en marzo.
    ///
    /// Las fases que empiezan DESPUÉS de la fecha de referencia no cuentan — al liquidar enero, un
    /// reingreso de marzo todavía no ocurrió.
    /// </remarks>
    procedure CalcDiasHasta(EmployeeNo: Code[20]; FechaRef: Date) Dias: Integer
    var
        Fase: Record "Fase Alta Empleado";
        Hasta: Date;
    begin
        if (EmployeeNo = '') or (FechaRef = 0D) then
            exit(0);

        Fase.SetRange("No. Empleado", EmployeeNo);
        Fase.SetFilter("Fecha Alta", '<=%1', FechaRef);
        if Fase.FindSet() then
            repeat
                Hasta := Fase."Fecha Baja";
                if (Hasta = 0D) or (Hasta > FechaRef) then
                    Hasta := FechaRef;
                if Hasta > Fase."Fecha Alta" then
                    Dias += Hasta - Fase."Fecha Alta";
            until Fase.Next() = 0;
    end;

    var
        ErrBajaAntesDelAlta: Label 'La baja del %1 es anterior al alta del %2 para el legajo %3. Una fase de días negativos resta antigüedad en vez de sumarla.', Comment = '%1 = fecha baja; %2 = fecha alta; %3 = legajo';
        ErrSuperpuesta: Label 'La fase %1 se superpone con la fase %2 del legajo %3, que va del %4 al %5. Dos fases superpuestas cuentan dos veces los días compartidos y dan una antigüedad mayor que la real.', Comment = '%1 = fase propia; %2 = otra fase; %3 = legajo; %4 = alta de la otra; %5 = baja de la otra';
}
