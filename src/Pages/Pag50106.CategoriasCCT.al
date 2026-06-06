namespace UAS.Payroll;

page 50106 "Categorías CCT"
{
    ApplicationArea = All;
    Caption = 'Categorías CCT';
    PageType = List;
    SourceTable = "Categoría CCT";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Cód. Convenio"; Rec."Cód. Convenio") { ApplicationArea = All; }
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("% Escala"; Rec."% Escala") { ApplicationArea = All; }
                field(Observaciones; Rec.Observaciones) { ApplicationArea = All; Visible = false; }
            }
        }
    }
}
