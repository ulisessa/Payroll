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
                field(Valor; Rec.Valor)
                {
                    ApplicationArea = All;
                    Caption = 'Valor';
                    DecimalPlaces = 0 : 6;
                }
            }
        }
    }
}
