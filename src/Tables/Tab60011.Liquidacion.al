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

        if not TipoLiqRec.EsArribo("Cód. Tipo Liq.") then
            exit;
        if ("No. Proyecto" = '') or not Job.Get("No. Proyecto") then
            exit;
        // Recortado contra el período: una marea que arrancó el mes anterior se cubre desde el 1.
        if (Job."Starting Date" <> 0D) and (Job."Starting Date" > Desde) then
            Desde := Job."Starting Date";
        if (Job."Ending Date" <> 0D) and (Job."Ending Date" < Hasta) then
            Hasta := Job."Ending Date";
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
        LinLiq: Record "Línea Liquidación";
        CtxBuilder: Codeunit "Contexto Liquidación";
        OtraLiq: Record "Liquidación";
        ParamVig: Record "Parámetro Vigente";
        GestNov: Codeunit "Gestión Novedades Liq.";
    begin
        if Estado <> Estado::Borrador then
            Error(ErrEstado);
        LinLiq.SetRange("No. Liquidación", "No.");
        LinLiq.DeleteAll(true);

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
