namespace UAS.Payroll;

page 50175 "Acumuladores Liq. Sub"
{
    ApplicationArea = All;
    Caption = 'Acumuladores';
    PageType = ListPart;
    SourceTable = "Línea Liquidación";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Cód. Concepto"; Rec."Cód. Concepto") { ApplicationArea = All; }
                field("Descripción Concepto"; Rec."Descripción Concepto") { ApplicationArea = All; }
                field(Importe; Rec.Importe)
                {
                    ApplicationArea = All;
                    Style = Strong;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.SetRange("Tipo Concepto", Rec."Tipo Concepto"::Informativo);
        Rec.SetFilter(Importe, '<>0');
    end;
}
