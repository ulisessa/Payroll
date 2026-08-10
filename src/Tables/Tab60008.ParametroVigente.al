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
        field(10; "Cód. Parámetro Base"; Code[20])
        {
            Caption = 'Cód. Parámetro Base';
            DataClassification = CustomerContent;
            TableRelation = "Parámetro";
        }
        field(11; "Cód. Convenio"; Code[20])
        {
            Caption = 'Cód. Convenio';
            DataClassification = CustomerContent;
            TableRelation = "Convenio Colectivo".Código;
            // Input helper for Sufijo CCT params: with "Cód. Categoría" it builds "Cód. Parámetro".
        }
        field(12; "Cód. Categoría"; Code[20])
        {
            Caption = 'Cód. Categoría';
            DataClassification = CustomerContent;
            TableRelation = "Categoría CCT".Código WHERE("Cód. Convenio" = FIELD("Cód. Convenio"));
        }
    }

    keys
    {
        key(PK; "Cód. Parámetro Base", "Cód. Parámetro", "Vigencia Desde")
        {
            Clustered = true;
        }
        key(Codigo; "Cód. Parámetro", "Vigencia Desde") { }
    }

    trigger OnInsert()
    begin
        if "Cód. Parámetro Base" = '' then
            "Cód. Parámetro Base" := DeriveBase("Cód. Parámetro");
    end;

    trigger OnModify()
    begin
        if xRec."En Uso" and "En Uso" then
            if HayLiquidacionesBloqueantes() then
                Error(ErrEnUso)
            else begin
                "En Uso" := false;
                xRec."En Uso" := false;
            end;
    end;

    trigger OnDelete()
    begin
        if "En Uso" then
            if HayLiquidacionesBloqueantes() then
                Error(ErrEnUso)
            else
                "En Uso" := false;
    end;

    local procedure HayLiquidacionesBloqueantes(): Boolean
    var
        Liq: Record "Liquidación";
    begin
        if "No. Empleado" <> '' then
            Liq.SetRange("No. Empleado", "No. Empleado");
        Liq.SetFilter(Estado, '%1|%2|%3',
            Liq.Estado::Calculada, Liq.Estado::Aprobada, Liq.Estado::Contabilizada);
        exit(not Liq.IsEmpty());
    end;

    local procedure DeriveBase(CodParam: Code[50]): Code[20]
    var
        Param: Record "Parámetro";
        BestCode: Code[20];
        BestLen: Integer;
        CodParamTxt: Text;
    begin
        CodParamTxt := CodParam;
        if Param.FindSet() then
            repeat
                if (StrLen(Param.Código) > BestLen) and
                   ((CodParam = Param.Código) or
                    CodParamTxt.StartsWith(Param.Código + '_'))
                then begin
                    BestCode := Param.Código;
                    BestLen := StrLen(Param.Código);
                end;
            until Param.Next() = 0;
        exit(BestCode);
    end;

    var
        ErrEnUso: Label 'No se puede modificar ni eliminar un parámetro que ya fue utilizado en una liquidación registrada.';
}
