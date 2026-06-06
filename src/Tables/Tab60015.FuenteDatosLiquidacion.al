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
            end;
        }
        field(5; "Función Agregado"; Enum "Función Agregado Liq.")
        {
            Caption = 'Función Agregado';
            DataClassification = CustomerContent;
        }
        field(6; "No. Filtro 1"; Integer)
        {
            Caption = 'No. Filtro 1';
            DataClassification = CustomerContent;
            MinValue = 0;

            trigger OnValidate()
            begin
                ValidarCampo("Id. Tabla", "No. Filtro 1");
            end;
        }
        field(7; "Filtro Valor 1"; Text[250])
        {
            Caption = 'Filtro Valor 1';
            DataClassification = CustomerContent;
        }
        field(8; "No. Filtro 2"; Integer)
        {
            Caption = 'No. Filtro 2';
            DataClassification = CustomerContent;
            MinValue = 0;

            trigger OnValidate()
            begin
                ValidarCampo("Id. Tabla", "No. Filtro 2");
            end;
        }
        field(9; "Filtro Valor 2"; Text[250])
        {
            Caption = 'Filtro Valor 2';
            DataClassification = CustomerContent;
        }
        field(10; "No. Filtro 3"; Integer)
        {
            Caption = 'No. Filtro 3';
            DataClassification = CustomerContent;
            MinValue = 0;

            trigger OnValidate()
            begin
                ValidarCampo("Id. Tabla", "No. Filtro 3");
            end;
        }
        field(11; "Filtro Valor 3"; Text[250])
        {
            Caption = 'Filtro Valor 3';
            DataClassification = CustomerContent;
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

    local procedure ValidarCampo(IdTabla: Integer; NoCampo: Integer)
    var
        FieldRec: Record Field;
    begin
        if (IdTabla = 0) or (NoCampo = 0) then exit;
        if not FieldRec.Get(IdTabla, NoCampo) then
            Error(ErrCampoNoExiste, NoCampo, IdTabla);
    end;

    var
        ErrTablaNoExiste: Label 'La tabla con ID %1 no existe en esta base de datos.';
        ErrCampoNoExiste: Label 'El campo %1 no existe en la tabla %2.';
}
