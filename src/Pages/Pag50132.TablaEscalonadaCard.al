namespace UAS.Payroll;

page 50132 "Tabla Escalonada Card"
{
    ApplicationArea = All;
    Caption = 'Tabla Escalonada';
    PageType = Card;
    SourceTable = "Tabla Escalonada";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field(Código; Rec.Código) { ApplicationArea = All; }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
            }
            part(Tramos; "Tabla Escalonada Det. Sub")
            {
                ApplicationArea = All;
                SubPageLink = Código = FIELD(Código), "Vigencia Desde" = FIELD("Vigencia Desde");
                UpdatePropagation = Both;
            }
        }
    }
}
