namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.Projects.Project.Job;

table 60011 "Liquidación"
{
    Caption = 'Liquidación';
    DataClassification = CustomerContent;
    LookupPageId = 50100;
    DrillDownPageId = 50100;

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(2; "Cód. Período"; Code[10])
        {
            Caption = 'Cód. Período';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Período Liquidación".Código;
        }
        field(3; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = Employee."No.";

            trigger OnValidate()
            var
                Emp: Record Employee;
            begin
                if Emp.Get("No. Empleado") then begin
                    "Nombre Empleado" := Emp."First Name" + ' ' + Emp."Last Name";
                    "Cód. Convenio" := Emp."Cód. Convenio";
                    "Cód. Categoría" := Emp."Cód. Categoría";
                    ResolverParDeAtributos();
                end;
            end;
        }
        field(4; "Nombre Empleado"; Text[100])
        {
            Caption = 'Nombre Empleado';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(5; "No. Proyecto"; Code[20])
        {
            Caption = 'No. Proyecto (Marea)';
            DataClassification = CustomerContent;
            TableRelation = Job."No.";
        }
        field(6; "Cód. Convenio"; Code[20])
        {
            Caption = 'Cód. Convenio';
            DataClassification = CustomerContent;
            TableRelation = "Convenio Colectivo".Código;
        }
        field(7; "Cód. Categoría"; Code[20])
        {
            Caption = 'Cód. Categoría';
            DataClassification = CustomerContent;
            TableRelation = "Categoría CCT".Código WHERE("Cód. Convenio" = FIELD("Cód. Convenio"));
        }
        field(8; "Fecha Liquidación"; Date)
        {
            Caption = 'Fecha Liquidación';
            DataClassification = CustomerContent;
        }
        field(9; Estado; Enum "Estado Liq.")
        {
            Caption = 'Estado';
            DataClassification = CustomerContent;
        }
        field(30; "Cód. Tipo Liq."; Code[20])
        {
            Caption = 'Tipo Liquidación';
            DataClassification = CustomerContent;
            TableRelation = "Tipo Liquidación".Código;
        }
        field(11; "No. Liq. Origen"; Code[20])
        {
            Caption = 'No. Liq. Origen';
            DataClassification = CustomerContent;
            TableRelation = "Liquidación"."No.";
        }
        field(12; "Cobertura Desde"; Date)
        {
            Caption = 'Cubre Desde';
            DataClassification = CustomerContent;
            Editable = false;
            // Qué días cubre efectivamente esta liquidación. NO es el período: un cierre de marea
            // cubre solamente los días del viaje, y dos mareas en el mismo mes dejan un mensual con
            // los días que sobran. Sin esto guardado, "el empleado tiene una liquidación de julio"
            // parece cobertura completa cuando en realidad son veinte días de treinta y uno.
        }
        field(13; "Cobertura Hasta"; Date)
        {
            Caption = 'Cubre Hasta';
            DataClassification = CustomerContent;
            Editable = false;
        }
        // Totals are stored (not FlowField) so they remain stable after period close
        // and support reliquidation comparison. The motor updates them after each run.
        field(20; "Total Haberes"; Decimal)
        {
            Caption = 'Total Haberes';
            DataClassification = CustomerContent;
            Editable = false;
            DecimalPlaces = 2 : 2;
        }
        field(21; "Total Descuentos"; Decimal)
        {
            Caption = 'Total Descuentos';
            DataClassification = CustomerContent;
            Editable = false;
            DecimalPlaces = 2 : 2;
        }
        field(22; "Total Contribuciones"; Decimal)
        {
            Caption = 'Total Contribuciones';
            DataClassification = CustomerContent;
            Editable = false;
            DecimalPlaces = 2 : 2;
        }
        field(23; "Neto a Pagar"; Decimal)
        {
            Caption = 'Neto a Pagar';
            DataClassification = CustomerContent;
            Editable = false;
            DecimalPlaces = 2 : 2;
        }
        field(24; "Haberes Ordinarios Gravados"; Decimal)
        {
            Caption = 'Haberes Ordinarios Gravados';
            DataClassification = CustomerContent;
            Editable = false;
            DecimalPlaces = 2 : 2;
            // Snapshot del acumulador BASE_IG4 al finalizar el cálculo: remunerativo
            // normal y habitual del mes, excluyendo extraordinarios (BASE_EXT_IG4).
            // Permite consultar este valor por mes/empleado vía Fuente Datos Liquidación
            // (ej. MEJOR_REM_SEM para el cálculo del SAC, que debe excluir extraordinarios).
        }
        field(31; "Traza Contexto"; Blob)
        {
            Caption = 'Traza del contexto';
            DataClassification = CustomerContent;
            // Lo que el contexto resolvió para toda la liquidación (fuentes de datos FDS:, deducciones familiares DED_FAM:, variables
            // que leyeron las de sistema), una sola vez. Antes iba al principio de "Fuente Parámetros" de CADA línea: el mismo texto
            // repetido línea por línea (295 MB) y cortado en 2048, así que las variables del propio concepto quedaban afuera.
            // Se escribe al cerrar el cálculo; ver GuardarTrazaContexto / LeerTrazaContexto.
        }
    }

    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
        key(K2; "Cód. Período", "No. Empleado")
        {
        }
        key(K3; "No. Proyecto")
        {
        }
        key(K4; Estado, "Cód. Período")
        {
        }
        // El filtro exacto de CalcularPorPeriodo (Cod50018): período + tipo + estado. Con K4 la base
        // resolvía estado y período pero después descartaba por tipo fila por fila.
        key(K5; "Cód. Período", "Cód. Tipo Liq.", Estado)
        {
        }
        // El de LiqExiste, que se pregunta una vez por cada persona del lote. Sin clave, cada
        // pregunta terminaba filtrando sobre el índice de período+empleado y descartando el resto.
        //
        // A propósito NO es Unique: si algún caso legítimo repitiera la combinación, el choque
        // aparecería como error en medio de un lote de cientos. La unicidad la cuida LiqExiste, que
        // es donde se puede avisar con sentido.
        key(K6; "No. Empleado", "No. Proyecto", "Cód. Período", "Cód. Tipo Liq.")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "No.", "Cód. Período", "No. Empleado", "Nombre Empleado", "Cód. Tipo Liq.", Estado) { }
    }

    /// <summary>
    /// Calcula qué días cubre esta liquidación y los deja en "Cobertura Desde"/"Cobertura Hasta".
    /// </summary>
    /// <remarks>
    /// Una liquidación mensual abarca todo el período; un cierre de marea, solamente los días del
    /// viaje. Sin esa distinción, dos mareas de julio y su mensual parecerían tres coberturas del mes
    /// entero, y los días que ninguna cubre —el resto del mes, que sí hay que liquidar— no aparecen
    /// por ningún lado.
    ///
    /// Vive en la tabla y no en un codeunit porque son dos los que necesitan la misma respuesta: el
    /// motor, que la guarda al calcular, y Gestión Novedades, que la usa para repartir las novedades
    /// entre las liquidaciones de un mismo período. Dos definiciones de "qué días cubre" que se
    /// separaran harían que una novedad entrara en una liquidación que el control da por no cubierta.
    /// </remarks>
    /// <summary>Guarda la traza del contexto de la liquidación (no hace Modify: lo hace quien cierra el cálculo).</summary>
    procedure GuardarTrazaContexto(Texto: Text)
    var
        Salida: OutStream;
    begin
        Clear("Traza Contexto");
        if Texto = '' then
            exit;
        "Traza Contexto".CreateOutStream(Salida, TextEncoding::UTF8);
        Salida.WriteText(Texto);
    end;

    /// <summary>La traza del contexto de la liquidación, o '' si se calculó antes de que existiera el campo.</summary>
    procedure LeerTrazaContexto(): Text
    var
        Entrada: InStream;
        Texto: Text;
        Parte: Text;
    begin
        CalcFields("Traza Contexto");
        if not "Traza Contexto".HasValue() then
            exit('');
        "Traza Contexto".CreateInStream(Entrada, TextEncoding::UTF8);
        while not Entrada.EOS() do begin
            Entrada.ReadText(Parte);
            Texto += Parte;
        end;
        exit(Texto);
    end;

    procedure CalcularCobertura()
    var
        Desde: Date;
        Hasta: Date;
    begin
        Cobertura(Desde, Hasta);
        "Cobertura Desde" := Desde;
        "Cobertura Hasta" := Hasta;
    end;

    /// <summary>Los días que cubre, sin escribirlos en el registro.</summary>
    procedure Cobertura(var Desde: Date; var Hasta: Date)
    var
        Periodo: Record "Período Liquidación";
        TipoLiqRec: Record "Tipo Liquidación";
        Job: Record Job;
    begin
        Desde := 0D;
        Hasta := 0D;
        if not Periodo.Get("Cód. Período") then
            exit;
        Desde := Periodo."Fecha Desde";
        Hasta := Periodo."Fecha Hasta";

        // Lo decide el tipo de PROYECTO, no el disparador: el Devengado corre sobre mareas igual que
        // el Cierre aunque no se dispare al arribo, y con la condición anterior se quedaba con el mes
        // entero. Ver CubreSoloElProyecto.
        if not TipoLiqRec.CubreSoloElProyecto("Cód. Tipo Liq.") then
            exit;
        if ("No. Proyecto" = '') or not Job.Get("No. Proyecto") then
            exit;

        // Primero se intenta con los días que ESTE empleado estuvo en el proyecto. Las fechas del
        // proyecto son las del barco, no las de la persona: el estado de Puerto de Salida ya
        // pertenece a la marea aunque la marea zarpe al día siguiente, y ese día se paga en ese
        // documento —Meta4 lo hace así: el recibo de la marea 7 del 03062 dice "25/01 al 31/01"
        // cuando el proyecto arranca el 26—. Recortando contra el barco, ese día quedaba sin cubrir.
        if not RecortarAlTramoDelEmpleado(Desde, Hasta) then begin
            // Sin estados del empleado en ese proyecto no hay tramo propio que usar, y se recorta
            // contra el proyecto como antes. Recortado contra el período: una marea que arrancó el
            // mes anterior se cubre desde el 1.
            if (Job."Starting Date" <> 0D) and (Job."Starting Date" > Desde) then
                Desde := Job."Starting Date";
            if (Job."Ending Date" <> 0D) and (Job."Ending Date" < Hasta) then
                Hasta := Job."Ending Date";
        end;
    end;

    /// <summary>Acota la ventana a los días que el empleado estuvo en el proyecto. False si no estuvo.</summary>
    /// <remarks>
    /// Se recorren todos los tramos y no sólo el primero: un tripulante puede entrar, salir y volver
    /// al mismo proyecto dentro del mes, y la cobertura tiene que ir del primer día al último.
    ///
    /// Sólo ACOTA: si el empleado estuvo en el proyecto más allá del período, la ventana sigue siendo
    /// la del período. Lo que se paga este mes son los días de este mes.
    /// </remarks>
    local procedure RecortarAlTramoDelEmpleado(var Desde: Date; var Hasta: Date): Boolean
    var
        EstadoEmp: Record "Estado Empleado";
        PrimerDia: Date;
        UltimoDia: Date;
        Fin: Date;
    begin
        if "No. Empleado" = '' then
            exit(false);

        EstadoEmp.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        EstadoEmp.SetRange("Tipo Entidad", EstadoEmp."Tipo Entidad"::Empleado);
        EstadoEmp.SetRange("No. Empleado", "No. Empleado");
        EstadoEmp.SetRange("No. Proyecto", "No. Proyecto");
        EstadoEmp.SetFilter("Fecha Inicio", '<=%1', Hasta);
        if not EstadoEmp.FindSet() then
            exit(false);

        repeat
            Fin := EstadoEmp.FechaFinEfectiva();
            if Fin >= Desde then begin
                if (PrimerDia = 0D) or (EstadoEmp."Fecha Inicio" < PrimerDia) then
                    PrimerDia := EstadoEmp."Fecha Inicio";
                if Fin > UltimoDia then
                    UltimoDia := Fin;
            end;
        until EstadoEmp.Next() = 0;

        if PrimerDia = 0D then
            exit(false);

        if PrimerDia > Desde then
            Desde := PrimerDia;
        if (UltimoDia <> 0D) and (UltimoDia < Hasta) then
            Hasta := UltimoDia;
        exit(true);
    end;

    /// <summary>
    /// Pone en la cabecera el convenio y la categoría que el empleado tiene como ATRIBUTOS.
    /// </summary>
    /// <remarks>
    /// La cabecera muestra siempre el par de atributos —es el encuadre del empleado, y es lo que sale
    /// impreso en el recibo—, aunque después algún concepto se liquide con el par de la asignación al
    /// proyecto. Esa excepción vive en la línea, no en la cabecera.
    ///
    /// Acá es solo el valor inicial, para que la liquidación recién creada ya muestre lo correcto: el
    /// motor lo vuelve a resolver en cada cálculo contra la fecha de referencia real. Si el empleado
    /// no tiene atributos cargados todavía, se respeta lo que haya puesto el llamador (hoy, el par de
    /// la ficha).
    /// </remarks>
    /// <summary>La fecha contra la que se resuelve todo lo efectivo-fechado de esta liquidación.</summary>
    /// <remarks>
    /// Es una APROXIMACIÓN, y por eso lleva el nombre. La definitiva la calcula el motor —fin de
    /// período, o el arribo en un Cierre de Marea— y hasta que corra el cálculo no existe. Sirve
    /// para la ficha y para prellenar el par: pantalla, no plata.
    ///
    /// Vive acá y no en cada llamador para que la ficha y el prellenado no puedan separarse: el día
    /// que uno resuelva contra el fin de período y el otro contra la fecha de liquidación, la
    /// pantalla mostraría un convenio y el recibo saldría con otro.
    /// </remarks>
    procedure FechaReferenciaAprox(): Date
    var
        Periodo: Record "Período Liquidación";
    begin
        if "Fecha Liquidación" <> 0D then
            exit("Fecha Liquidación");
        if Periodo.Get("Cód. Período") and (Periodo."Fecha Hasta" <> 0D) then
            exit(Periodo."Fecha Hasta");
        exit(WorkDate());
    end;

    procedure ResolverParDeAtributos()
    var
        Periodo: Record "Período Liquidación";
        ParCCT: Codeunit "Convenio Categoría Liq.";
        Convenio: Code[20];
        Categoria: Code[20];
        FechaRef: Date;
    begin
        if "No. Empleado" = '' then
            exit;

        Periodo.Get("Cód. Período");
        FechaRef := FechaReferenciaAprox();

        if ParCCT.ParDeEntidad("No. Empleado", FechaRef, Periodo."Fecha Desde", Periodo."Fecha Hasta", Convenio, Categoria) then begin
            "Cód. Convenio" := Convenio;
            "Cód. Categoría" := Categoria;
        end;
    end;

    trigger OnDelete()
    var
        CuentaFrancos: Codeunit "Cuenta Corriente Francos";
        LinLiq: Record "Línea Liquidación";
        Det: Record "Detalle Variable Línea Liq.";
        DetGan: Record "Detalle Ganancias Liq.";
        ResVar: Record "Resumen Variable Liq.";
        Tramo: Record "Tramo Cobertura Liq.";
        CtxBuilder: Codeunit "Contexto Liquidación";
        OtraLiq: Record "Liquidación";
        ParamVig: Record "Parámetro Vigente";
        GestNov: Codeunit "Gestión Novedades Liq.";
    begin
        if Estado <> Estado::Borrador then
            Error(ErrEstado);
        CuentaFrancos.Revertir("No.");
        // Los detalles de TODAS las líneas se borran de una vez y las líneas sin disparar su OnDelete.
        // Ese trigger sólo borra los detalles de la línea; con DeleteAll(true) se pagaba un DeleteAll
        // por línea (243 hits en el perfil de borrado) y SQL no podía borrar el lote en una sentencia.
        // Si el OnDelete de "Línea Liquidación" llega a hacer algo más, esto vuelve a ser DeleteAll(true).
        Det.SetRange("No. Liquidación", "No.");
        Det.DeleteAll();
        LinLiq.SetRange("No. Liquidación", "No.");
        LinLiq.DeleteAll(false);

        // Los tramos de cobertura se van con ella. Si sobrevivieran, la próxima liquidación que
        // pregunte "qué días quedan libres" los vería tomados por una liquidación que ya no existe,
        // y se quedaría sin días sin que nada lo explique.
        Tramo.SetRange("No. Liquidación", "No.");
        Tramo.DeleteAll();

        // El detalle de Ganancias y el resumen de variables se iban quedando. Al 7/10/2026 eran
        // 27.650 filas huérfanas sobre 28.698 en el detalle —el 96%— y 3.383.317 sobre 3.464.978 en
        // el resumen —el 98%—: casi todo lo que había en las dos tablas colgaba de liquidaciones
        // que ya no existían.
        //
        // No daban un resultado mal: las dos se leen filtradas por "No. Liquidación", así que una
        // fila huérfana no se cruza con nada. Lo que hacían era crecer sin techo y volver lento todo
        // lo que las recorre, y ensuciar cualquier cuenta hecha sobre la tabla entera.
        DetGan.SetRange("No. Liquidación", "No.");
        DetGan.DeleteAll();
        ResVar.SetRange("No. Liquidación", "No.");
        ResVar.DeleteAll();

        // El registro de uso de parámetros se va con la liquidación: si sobreviviera, seguiría
        // diciendo que esta versión está en uso y nadie la liberaría nunca.
        CtxBuilder.BorrarUsoParametros("No.");

        // Las novedades que se habían materializado acá vuelven a estar disponibles. Sin esto
        // quedan Aplicada contra una liquidación borrada y no entran nunca más en ninguna.
        GestNov.RevertirLiquidacion("No.");

        // Si después de borrar esta liquidación no quedan liquidaciones en estado
        // calculada/aprobada/contabilizada, liberar todos los bloqueos "En Uso".
        OtraLiq.SetFilter("No.", '<>%1', "No.");
        OtraLiq.SetFilter(Estado, '%1|%2|%3',
            Estado::Calculada, Estado::Aprobada, Estado::Contabilizada);
        if OtraLiq.IsEmpty() then begin
            ParamVig.SetRange("En Uso", true);
            if ParamVig.FindSet(true) then
                repeat
                    ParamVig."En Uso" := false;
                    ParamVig.Modify();
                until ParamVig.Next() = 0;
        end;
    end;

    var
        ErrEstado: Label 'Solo se pueden eliminar liquidaciones en estado Borrador.';
}
