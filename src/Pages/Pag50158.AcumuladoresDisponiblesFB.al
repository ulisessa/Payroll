namespace UAS.Payroll;

page 50158 "Acumuladores Disponibles FB"
{
    ApplicationArea = All;
    Caption = 'Acumuladores disponibles';
    PageType = ListPart;
    SourceTable = "Concepto Liquidación";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.SetRange("Es Acumulador", true);
        Rec.SetRange(Activo, true);
    end;
}
