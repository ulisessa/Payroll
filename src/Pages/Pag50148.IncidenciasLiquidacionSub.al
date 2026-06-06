namespace UAS.Payroll;

page 50148 "Incidencias Liquidación Sub"
{
    ApplicationArea = All;
    Caption = 'Incidencias';
    PageType = ListPart;
    SourceTable = "Incidencia Liquidación";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Cód. Concepto"; Rec."Cód. Concepto") { ApplicationArea = All; }
                field(DescConcepto; DescConcepto)
                {
                    ApplicationArea = All;
                    Caption = 'Descripción';
                    Editable = false;
                    ToolTip = 'Descripción del concepto seleccionado.';
                }
                field(Importe; Rec.Importe) { ApplicationArea = All; }
                field(Observaciones; Rec.Observaciones) { ApplicationArea = All; }
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Concepto.SetRange(Código, Rec."Cód. Concepto");
        if Concepto.FindLast() then
            DescConcepto := Concepto.Descripción
        else
            DescConcepto := '';
    end;

    var
        DescConcepto: Text[100];
}
