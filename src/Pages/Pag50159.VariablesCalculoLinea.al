namespace UAS.Payroll;

page 50159 "Variables Cálculo Línea"
{
    ApplicationArea = All;
    Caption = 'Variables del Cálculo';
    PageType = List;
    SourceTable = "Detalle Variable Línea Liq.";
    Editable = false;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
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

    actions
    {
        area(Processing)
        {
            action(VerAcumulador)
            {
                ApplicationArea = All;
                Caption = 'Detalle Acumulador';
                Image = Totals;
                ToolTip = 'Si esta variable es un acumulador, muestra qué conceptos lo alimentaron (con el valor que tenían al momento del cálculo) y con qué importe.';
                Enabled = EsAcumulador;
                trigger OnAction()
                var
                    DetPage: Page "Detalle Acumulador Liq.";
                begin
                    DetPage.LoadFromLiquidacion(Rec."No. Liquidación", CopyStr(Rec."Nombre Variable", 1, 20));
                    // El valor que ESTA línea usó, para contrastarlo con la suma real de los aportes:
                    // si difieren, la línea leyó el acumulador antes de que terminara de llenarse.
                    DetPage.SetValorUsado(Rec.Valor);
                    DetPage.Caption := Rec."Nombre Variable";
                    DetPage.RunModal();
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        ValorVisible := FormatValor();
        EsAcumulador := IsAcumulador(Rec."Nombre Variable");
    end;

    local procedure IsAcumulador(NombreVar: Text): Boolean
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Concepto.SetRange(Código, CopyStr(NombreVar, 1, 20));
        Concepto.SetRange("Es Acumulador", true);
        exit(not Concepto.IsEmpty());
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
        EsAcumulador: Boolean;
}
