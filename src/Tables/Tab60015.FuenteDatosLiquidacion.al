namespace UAS.Payroll;

using System.Reflection;

table 60015 "Fuente Datos Liquidación"
{
    Caption = 'Fuente Datos Liquidación';
    DataClassification = CustomerContent;
    // Defines a named context variable populated at calculation time by querying
    // any BC table via RecordRef. Table, value field, and filter fields are stored
    // as object/field IDs so no code changes are needed when adding new sources.
    //
    // Filter values support tokens replaced at runtime:
    //   {EMP_NO}   → No. Empleado
    //   {JOB_NO}   → No. Proyecto
    //   {PERIODO}  → Cód. Período
    //   {FECHA_REF}→ Fecha de referencia (fin de período)

    fields
    {
        field(1; "Nombre Variable"; Code[30])
        {
            Caption = 'Nombre Variable';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(2; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(3; "Id. Tabla"; Integer)
        {
            Caption = 'Id. Tabla';
            DataClassification = CustomerContent;
            MinValue = 0;

            trigger OnValidate()
            var
                AllObj: Record AllObjWithCaption;
                Filtro: Record "Filtro Fuente Datos Liq.";
            begin
                if "Id. Tabla" = 0 then exit;
                AllObj.SetRange("Object Type", AllObj."Object Type"::Table);
                AllObj.SetRange("Object ID", "Id. Tabla");
                if not AllObj.FindFirst() then
                    Error(ErrTablaNoExiste, "Id. Tabla");
                "No. Campo Valor" := 0;
                "No. Filtro 1" := 0;
                "No. Filtro 2" := 0;
                "No. Filtro 3" := 0;
                "No. Campo Fecha Inicio" := 0;
                "No. Campo Fecha Fin" := 0;
                "Fin Efectivo" := false;
                if "Nombre Variable" <> '' then begin
                    Filtro.SetRange("Nombre Variable", "Nombre Variable");
                    Filtro.DeleteAll();
                end;
            end;
        }
        field(4; "No. Campo Valor"; Integer)
        {
            Caption = 'No. Campo Valor';
            DataClassification = CustomerContent;
            MinValue = 0;

            trigger OnValidate()
            begin
                ValidarCampo("Id. Tabla", "No. Campo Valor");
                ValidarTipoCampo();
            end;
        }
        field(18; "Tipo Dato"; Enum "Tipo Dato Fuente Liq.")
        {
            Caption = 'Tipo Dato';
            DataClassification = CustomerContent;
            // La fórmula sigue viendo SIEMPRE un número: el contexto es Dictionary of [Text, Decimal].
            // Esto declara qué es el valor en origen, para dos cosas que antes no se podían:
            //   • conservarlo en su forma real y que el recibo imprima "126205 - OSECAC" y no un número
            //   • saber con qué criterio proyectarlo a número (una fecha son días, un texto es 1/0)
            trigger OnValidate()
            begin
                ValidarTipoCampo();
            end;
        }
        field(5; "Función Agregado"; Enum "Función Agregado Liq.")
        {
            Caption = 'Función Agregado';
            DataClassification = CustomerContent;
        }
        field(6; "No. Filtro 1"; Integer)
        {
            Caption = 'No. Filtro 1 (obsoleto)';
            DataClassification = CustomerContent;
            MinValue = 0;
            ObsoleteState = Pending;
            ObsoleteReason = 'Reemplazado por tabla "Filtro Fuente Datos Liq." que permite filtros ilimitados.';
        }
        field(7; "Filtro Valor 1"; Text[250])
        {
            Caption = 'Filtro Valor 1 (obsoleto)';
            DataClassification = CustomerContent;
            ObsoleteState = Pending;
            ObsoleteReason = 'Reemplazado por tabla "Filtro Fuente Datos Liq." que permite filtros ilimitados.';
        }
        field(8; "No. Filtro 2"; Integer)
        {
            Caption = 'No. Filtro 2 (obsoleto)';
            DataClassification = CustomerContent;
            MinValue = 0;
            ObsoleteState = Pending;
            ObsoleteReason = 'Reemplazado por tabla "Filtro Fuente Datos Liq." que permite filtros ilimitados.';
        }
        field(9; "Filtro Valor 2"; Text[250])
        {
            Caption = 'Filtro Valor 2 (obsoleto)';
            DataClassification = CustomerContent;
            ObsoleteState = Pending;
            ObsoleteReason = 'Reemplazado por tabla "Filtro Fuente Datos Liq." que permite filtros ilimitados.';
        }
        field(10; "No. Filtro 3"; Integer)
        {
            Caption = 'No. Filtro 3 (obsoleto)';
            DataClassification = CustomerContent;
            MinValue = 0;
            ObsoleteState = Pending;
            ObsoleteReason = 'Reemplazado por tabla "Filtro Fuente Datos Liq." que permite filtros ilimitados.';
        }
        field(11; "Filtro Valor 3"; Text[250])
        {
            Caption = 'Filtro Valor 3 (obsoleto)';
            DataClassification = CustomerContent;
            ObsoleteState = Pending;
            ObsoleteReason = 'Reemplazado por tabla "Filtro Fuente Datos Liq." que permite filtros ilimitados.';
        }
        field(12; Activo; Boolean)
        {
            Caption = 'Activo';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(13; "No. Campo Fecha Inicio"; Integer)
        {
            Caption = 'No. Campo Fecha Inicio';
            DataClassification = CustomerContent;
            MinValue = 0;

            trigger OnValidate()
            begin
                ValidarCampo("Id. Tabla", "No. Campo Fecha Inicio");
            end;
        }
        field(14; "No. Campo Fecha Fin"; Integer)
        {
            Caption = 'No. Campo Fecha Fin';
            DataClassification = CustomerContent;
            MinValue = 0;

            trigger OnValidate()
            begin
                ValidarCampo("Id. Tabla", "No. Campo Fecha Fin");
            end;
        }
        field(15; "Mostrar en Recibo"; Boolean)
        {
            Caption = 'Mostrar en Recibo';
            DataClassification = CustomerContent;
        }
        field(17; "Fin Efectivo"; Boolean)
        {
            Caption = 'Fin Efectivo (Estado Siguiente)';
            DataClassification = CustomerContent;
            // For effective-dated tables (e.g. Estado Empleado, sin campo Fecha Fin): the interval end of
            // each row is derived as the next row's start date − 1 for the same entity, ignoring the row's
            // constant selection filters (only the token filters — {EMP_NO}, {JOB_NO}… — scope the entity).
            // Applies to DIAS_OVERLAP/DURACION_INICIO/DURACION_ANIO.
        }
        field(16; "Etiqueta Recibo"; Text[100])
        {
            Caption = 'Etiqueta Recibo';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Nombre Variable") { Clustered = true; }
    }

    trigger OnDelete()
    var
        Filtro: Record "Filtro Fuente Datos Liq.";
    begin
        Filtro.SetRange("Nombre Variable", "Nombre Variable");
        Filtro.DeleteAll();
    end;

    procedure CopiarEn(NuevoNombre: Code[30])
    var
        NuevaDef: Record "Fuente Datos Liquidación";
        FiltroOrig: Record "Filtro Fuente Datos Liq.";
        FiltroNuevo: Record "Filtro Fuente Datos Liq.";
    begin
        NuevaDef := Rec;
        NuevaDef."Nombre Variable" := NuevoNombre;
        NuevaDef.Insert(true);

        FiltroOrig.SetRange("Nombre Variable", "Nombre Variable");
        if FiltroOrig.FindSet() then
            repeat
                FiltroNuevo := FiltroOrig;
                FiltroNuevo."Nombre Variable" := NuevoNombre;
                FiltroNuevo."No. Línea" := 0;
                FiltroNuevo.Insert(true);
            until FiltroOrig.Next() = 0;
    end;

    local procedure ValidarCampo(IdTabla: Integer; NoCampo: Integer)
    var
        FieldRec: Record Field;
    begin
        if (IdTabla = 0) or (NoCampo = 0) then exit;
        if not FieldRec.Get(IdTabla, NoCampo) then
            Error(ErrCampoNoExiste, NoCampo, IdTabla);
    end;

    // Cierra un agujero viejo: la lectura convierte con FieldRefToDecimal, que solo entiende
    // Decimal/Integer/BigInteger. Apuntar el campo valor a uno de texto o fecha no daba error —
    // devolvía CERO en silencio, y ese cero entraba al cálculo como cualquier otro número.
    local procedure ValidarTipoCampo()
    var
        FieldRec: Record Field;
    begin
        if ("Id. Tabla" = 0) or ("No. Campo Valor" = 0) then
            exit;
        if not FieldRec.Get("Id. Tabla", "No. Campo Valor") then
            exit;

        case "Tipo Dato" of
            "Tipo Dato"::Decimal:
                if not (FieldRec.Type in [FieldRec.Type::Decimal, FieldRec.Type::Integer, FieldRec.Type::BigInteger]) then
                    Error(ErrTipoCampoNoCoincide, FieldRec."Field Caption", Format(FieldRec.Type), Format("Tipo Dato"));
            "Tipo Dato"::Texto:
                if not (FieldRec.Type in [FieldRec.Type::Text, FieldRec.Type::Code, FieldRec.Type::Option]) then
                    Error(ErrTipoCampoNoCoincide, FieldRec."Field Caption", Format(FieldRec.Type), Format("Tipo Dato"));
            "Tipo Dato"::Fecha:
                if not (FieldRec.Type in [FieldRec.Type::Date, FieldRec.Type::DateTime]) then
                    Error(ErrTipoCampoNoCoincide, FieldRec."Field Caption", Format(FieldRec.Type), Format("Tipo Dato"));
        end;
    end;

    var
        ErrTablaNoExiste: Label 'La tabla con ID %1 no existe en esta base de datos.';
        ErrCampoNoExiste: Label 'El campo %1 no existe en la tabla %2.';
        ErrTipoCampoNoCoincide: Label 'El campo "%1" es de tipo %2 y la fuente está declarada como %3. Si no coinciden, la lectura devuelve cero sin avisar.';
}
