namespace UAS.Payroll;

page 50133 "Tabla Escalonada Det. Sub"
{
    ApplicationArea = All;
    Caption = 'Tramos';
    PageType = ListPart;
    SourceTable = "Tabla Escalonada Det.";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No. Tramo"; Rec."No. Tramo") { ApplicationArea = All; }
                field("Límite Inferior"; Rec."Límite Inferior") { ApplicationArea = All; }
                field("Límite Superior"; Rec."Límite Superior")
                {
                    ApplicationArea = All;
                    ToolTip = 'Cero indica sin límite superior (último tramo).';
                }
                field("Monto Fijo"; Rec."Monto Fijo") { ApplicationArea = All; }
                field(Porcentaje; Rec.Porcentaje) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
            }
        }
    }
}
