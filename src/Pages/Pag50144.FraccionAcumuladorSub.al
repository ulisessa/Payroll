namespace UAS.Payroll;

page 50144 "Fracción Acumulador Sub"
{
    ApplicationArea = All;
    Caption = 'Distribución en acumuladores';
    PageType = ListPart;
    SourceTable = "Fracción Acumulador";
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Cód. Acumulador"; Rec."Cód. Acumulador") { ApplicationArea = All; }
                field(DescAccumulator; AccumDesc)
                {
                    ApplicationArea = All;
                    Caption = 'Descripción';
                    Editable = false;
                }
                field(Porcentaje; Rec.Porcentaje)
                {
                    ApplicationArea = All;
                    Caption = '% Importe';
                }
                field(Restar; Rec.Restar)
                {
                    ApplicationArea = All;
                    ToolTip = 'Si está activo, el importe se resta del acumulador en lugar de sumarse. Útil para conceptos de descuento que deben cancelar base de cálculo.';
                }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Concepto.SetRange(Código, Rec."Cód. Acumulador");
        if Concepto.FindLast() then
            AccumDesc := Concepto.Descripción
        else
            AccumDesc := '';
    end;

    var
        AccumDesc: Text[100];
}
