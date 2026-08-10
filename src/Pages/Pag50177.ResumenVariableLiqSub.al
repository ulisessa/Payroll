namespace UAS.Payroll;

page 50177 "Resumen Variable Liq. Sub"
{
    ApplicationArea = All;
    Caption = 'Acumuladores Anuales';
    PageType = ListPart;
    SourceTable = "Resumen Variable Liq.";
    SourceTableView = SORTING("No. Liquidación", "Nombre Variable");
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Etiqueta; Rec.Etiqueta) { ApplicationArea = All; }
                field("Nombre Variable"; Rec."Nombre Variable") { ApplicationArea = All; }
                field(Valor; Rec.Valor)
                {
                    ApplicationArea = All;
                    Style = Strong;
                }
            }
        }
    }
}
