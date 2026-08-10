namespace UAS.Payroll;

using System.Reflection;

table 60029 "Filtro Fuente Datos Liq."
{
    Caption = 'Filtro Fuente Datos Liquidación';
    DataClassification = CustomerContent;
    // Each row defines one filter applied when resolving a Fuente Datos Liquidación.
    // Field tokens supported in Filtro Valor: {EMP_NO}, {JOB_NO}, {PERIODO},
    // {FECHA_REF}, {LIQ_NO}, {MONEDA}, {SEM_DESDE}, {SEM_HASTA}.

    fields
    {
        field(1; "Nombre Variable"; Code[30])
        {
            Caption = 'Fuente Datos';
            DataClassification = CustomerContent;
            TableRelation = "Fuente Datos Liquidación"."Nombre Variable";
        }
        field(2; "No. Línea"; Integer)
        {
            Caption = 'No. Línea';
            DataClassification = CustomerContent;
            AutoIncrement = true;
        }
        field(3; "No. Campo"; Integer)
        {
            Caption = 'Campo (No.)';
            DataClassification = CustomerContent;
            MinValue = 0;

            trigger OnValidate()
            var
                Fuente: Record "Fuente Datos Liquidación";
                FieldRec: Record Field;
            begin
                if ("No. Campo" = 0) or not Fuente.Get("Nombre Variable") then exit;
                if Fuente."Id. Tabla" = 0 then exit;
                if not FieldRec.Get(Fuente."Id. Tabla", "No. Campo") then
                    Error(ErrCampoNoExiste, "No. Campo", Fuente."Id. Tabla");
            end;
        }
        field(4; "Filtro Valor"; Text[250])
        {
            Caption = 'Filtro / Valor';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Nombre Variable", "No. Línea") { Clustered = true; }
    }

    var
        ErrCampoNoExiste: Label 'El campo %1 no existe en la tabla %2.';
}
