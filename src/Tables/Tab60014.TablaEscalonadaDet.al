namespace UAS.Payroll;

table 60014 "Tabla Escalonada Det."
{
    Caption = 'Tabla Escalonada Det.';
    DataClassification = CustomerContent;

    fields
    {
        field(1; Código; Code[20])
        {
            Caption = 'Código';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Tabla Escalonada".Código;
        }
        field(2; "Vigencia Desde"; Date)
        {
            Caption = 'Vigencia Desde';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(3; "No. Tramo"; Integer)
        {
            Caption = 'No. Tramo';
            NotBlank = true;
            DataClassification = CustomerContent;
            MinValue = 1;
        }
        field(4; "Límite Inferior"; Decimal)
        {
            Caption = 'Límite Inferior';
            DataClassification = CustomerContent;
            MinValue = 0;
        }
        field(5; "Límite Superior"; Decimal)
        {
            Caption = 'Límite Superior';
            DataClassification = CustomerContent;
            MinValue = 0;
            // 0 means unbounded (the last tramo).
        }
        field(6; "Monto Fijo"; Decimal)
        {
            Caption = 'Monto Fijo';
            DataClassification = CustomerContent;
        }
        field(7; Porcentaje; Decimal)
        {
            Caption = '% Sobre Excedente';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 6;
        }
        field(8; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; Código, "Vigencia Desde", "No. Tramo")
        {
            Clustered = true;
        }
        key(K2; Código, "Vigencia Desde", "Límite Inferior")
        {
        }
    }

    trigger OnInsert()
    begin
        ValidarLimites();
    end;

    trigger OnModify()
    begin
        ValidarLimites();
    end;

    local procedure ValidarLimites()
    begin
        if ("Límite Superior" <> 0) and ("Límite Superior" < "Límite Inferior") then
            Error(ErrLimites);
    end;

    var
        ErrLimites: Label 'El límite superior debe ser mayor o igual al límite inferior (o cero para indicar sin límite).';
}
