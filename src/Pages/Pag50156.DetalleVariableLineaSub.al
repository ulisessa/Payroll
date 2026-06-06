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
