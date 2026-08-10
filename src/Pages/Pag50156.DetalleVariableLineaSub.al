namespace UAS.Payroll;

page 50156 "Detalle Variable Línea Sub"
{
    PageType = ListPart;
    Caption = 'Variables del Cálculo';
    SourceTable = "Detalle Variable Línea Liq.";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No. Línea"; Rec."No. Línea")
                {
                    ApplicationArea = All;
                    Caption = 'Lín.';
                }
                field("Nombre Variable"; Rec."Nombre Variable")
                {
                    ApplicationArea = All;
                    Caption = 'Variable';
                }
                field(Valor; ValorVisible)
                {
                    ApplicationArea = All;
                    Caption = 'Valor';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        ValorVisible := FormatValor();
    end;

    local procedure FormatValor(): Text
    begin
        if IsPercentageVariable(Rec."Nombre Variable") then begin
            // ≤ 1 → fracción (0,85 → 85%); > 1 → ya es porcentaje entero (78 → 78%, no 7800%).
            if Abs(Rec.Valor) <= 1 then
                exit(Format(Round(Rec.Valor * 100, 0.000001)) + '%');
            exit(Format(Round(Rec.Valor, 0.000001)) + '%');
        end;
        exit(Format(Round(Rec.Valor, 0.000001)));
    end;

    local procedure IsPercentageVariable(VariableName: Text): Boolean
    begin
        VariableName := VariableName.ToUpper();
        exit(VariableName.StartsWith('PCT_') or VariableName.Contains('_PCT') or VariableName.Contains('PORC'));
    end;

    var
        ValorVisible: Text[50];
}
