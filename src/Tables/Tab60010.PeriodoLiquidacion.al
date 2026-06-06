namespace UAS.Payroll;

using Microsoft.Foundation.Calendar;

table 60010 "Período Liquidación"
{
    Caption = 'Período Liquidación';
    DataClassification = CustomerContent;
    LookupPageId = "Períodos Liquidación";
    DrillDownPageId = "Períodos Liquidación";

    fields
    {
        field(1; Código; Code[10])
        {
            Caption = 'Código';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(2; Año; Integer)
        {
            Caption = 'Año';
            DataClassification = CustomerContent;
            MinValue = 2000;
        }
        field(3; Mes; Integer)
        {
            Caption = 'Mes';
            DataClassification = CustomerContent;
            MinValue = 1;
            MaxValue = 12;
            trigger OnValidate()
            begin
                if (Rec.Mes >= 1) and (Rec.Mes <= 12) and (Rec.Año >= 2000) then begin
                    if Rec."Fecha Desde" = 0D then
                        Rec."Fecha Desde" := DMY2Date(1, Rec.Mes, Rec.Año);
                    if Rec."Fecha Hasta" = 0D then
                        Rec."Fecha Hasta" := CalcDate('<CM>', Rec."Fecha Desde");
                end;
            end;
        }
        field(4; "Fecha Desde"; Date)
        {
            Caption = 'Fecha Desde';
            DataClassification = CustomerContent;
        }
        field(5; "Fecha Hasta"; Date)
        {
            Caption = 'Fecha Hasta';
            DataClassification = CustomerContent;
        }
        field(6; Estado; Enum "Estado Período Liq.")
        {
            Caption = 'Estado';
            DataClassification = CustomerContent;
        }
        field(7; "Fecha Cierre"; Date)
        {
            Caption = 'Fecha Cierre';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(8; "Usuario Cierre"; Code[50])
        {
            Caption = 'Usuario Cierre';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
        }
        field(9; "Cant. Liquidaciones"; Integer)
        {
            Caption = 'Cant. Liquidaciones';
            FieldClass = FlowField;
            CalcFormula = Count(Liquidación WHERE("Cód. Período" = FIELD(Código)));
            Editable = false;
        }
        field(10; "Cód. Calendario"; Code[10])
        {
            Caption = 'Cód. Calendario';
            DataClassification = CustomerContent;
            TableRelation = "Base Calendar";
            // Optional. When set, DIAS_HAB respects this calendar's nonworking days.
            // When blank, DIAS_HAB falls back to a plain Mon–Fri count.
        }
    }

    keys
    {
        key(PK; Código)
        {
            Clustered = true;
        }
        key(K2; Año, Mes)
        {
        }
    }

    trigger OnInsert()
    begin
        if Código = '' then
            Código := Format(Año) + Format(Mes, 2, '<Integer,2>');
        if (Mes >= 1) and (Mes <= 12) and (Año >= 2000) then begin
            if "Fecha Desde" = 0D then
                "Fecha Desde" := DMY2Date(1, Mes, Año);
            if "Fecha Hasta" = 0D then
                "Fecha Hasta" := CalcDate('<CM>', "Fecha Desde");
        end;
    end;

    trigger OnDelete()
    var
        Liq: Record Liquidación;
    begin
        if Estado = Estado::Cerrado then
            Error(ErrCerrado);
        Liq.SetRange("Cód. Período", Código);
        if not Liq.IsEmpty() then
            Error(ErrConLiquidaciones);
    end;

    var
        ErrCerrado: Label 'No se puede eliminar un período cerrado.';
        ErrConLiquidaciones: Label 'No se puede eliminar un período que contiene liquidaciones.';
}
