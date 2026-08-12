namespace UAS.Payroll;

page 50157 "Alimentadores Acumulador Sub"
{
    ApplicationArea = All;
    Caption = 'Conceptos que alimentan este acumulador';
    PageType = ListPart;
    SourceTable = "Fracción Acumulador";
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Cód. Concepto"; Rec."Cód. Concepto") { ApplicationArea = All; }
                field(DescripciónConcepto; ConceptoDesc)
                {
                    ApplicationArea = All;
                    Caption = 'Descripción';
                    Editable = false;
                }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field(Porcentaje; Rec.Porcentaje)
                {
                    ApplicationArea = All;
                    Caption = '% Importe';
                }
                field(InvertirSigno; Rec."Invertir Signo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Si está activo, el importe se resta del acumulador en lugar de sumarse.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Concepto.SetRange(Código, Rec."Cód. Concepto");
        if Concepto.FindLast() then
            ConceptoDesc := Concepto.Descripción
        else
            ConceptoDesc := '';
    end;

    var
        ConceptoDesc: Text[100];
}
