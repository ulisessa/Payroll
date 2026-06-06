namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.Finance.Currency;

table 60008 "Parámetro Vigente"
{
    Caption = 'Parámetro Vigente';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Cód. Parámetro"; Code[50])
        {
            Caption = 'Cód. Parámetro';
            NotBlank = true;
            DataClassification = CustomerContent;
            // No TableRelation: derived keys (e.g. BASICO_175/75_CAPITAN) do not exist
            // as Parámetro records. Referential integrity is enforced via Parámetro.OnDelete.
        }
        field(2; "Vigencia Desde"; Date)
        {
            Caption = 'Vigencia Desde';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(3; Descripción; Text[100])
        {
            Caption = 'Descripción Versión';
            DataClassification = CustomerContent;
        }
        field(4; Valor; Decimal)
        {
            Caption = 'Valor';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 6;
        }
        field(5; Moneda; Code[10])
        {
            Caption = 'Moneda';
            DataClassification = CustomerContent;
            TableRelation = Currency;
        }
        field(6; "En Uso"; Boolean)
        {
            Caption = 'En Uso';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(7; Notas; Text[250])
        {
            Caption = 'Notas';
            DataClassification = CustomerContent;
        }
        field(8; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            DataClassification = CustomerContent;
            TableRelation = Employee."No.";
        }
    }

    keys
    {
        key(PK; "Cód. Parámetro", "Vigencia Desde")
        {
            Clustered = true;
        }
    }

    trigger OnModify()
    begin
        if xRec."En Uso" and "En Uso" then
            Error(ErrEnUso);
    end;

    trigger OnDelete()
    begin
        if "En Uso" then
            Error(ErrEnUso);
    end;

    var
        ErrEnUso: Label 'No se puede modificar ni eliminar un parámetro que ya fue utilizado en una liquidación registrada.';
}
