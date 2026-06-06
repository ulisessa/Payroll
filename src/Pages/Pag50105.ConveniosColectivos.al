namespace UAS.Payroll;

page 50105 "Convenios Colectivos"
{
    ApplicationArea = All;
    Caption = 'Convenios Colectivos';
    PageType = List;
    SourceTable = "Convenio Colectivo";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("No. CCT"; Rec."No. CCT") { ApplicationArea = All; }
                field(Sindicato; Rec.Sindicato) { ApplicationArea = All; }
                field(Cámara; Rec.Cámara) { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(Categorías)
            {
                ApplicationArea = All;
                Caption = 'Categorías';
                Image = Category;
                RunObject = Page "Categorías CCT";
                RunPageLink = "Cód. Convenio" = FIELD(Código);
            }
            action(Conceptos)
            {
                ApplicationArea = All;
                Caption = 'Conceptos';
                Image = ItemLines;
                RunObject = Page "Conceptos Liquidación";
            }
        }
    }
}
