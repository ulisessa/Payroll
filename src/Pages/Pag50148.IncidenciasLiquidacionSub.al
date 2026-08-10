namespace UAS.Payroll;

page 50148 "Incidencias Liquidación Sub"
{
    ApplicationArea = All;
    Caption = 'Incidencias';
    PageType = ListPart;
    SourceTable = "Incidencia Liquidación";
    InsertAllowed = true;
    ModifyAllowed = true;
    DeleteAllowed = true;

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
                field(Cantidad; Rec.Cantidad) { ApplicationArea = All; }
                field("Unidad Cantidad"; Rec."Unidad Cantidad") { ApplicationArea = All; }
                field("Valor Unitario"; Rec."Valor Unitario") { ApplicationArea = All; }
                field(Importe; Rec.Importe)
                {
                    ApplicationArea = All;
                    ToolTip = 'Si cargás Cantidad y Valor Unitario se calcula solo; también podés escribirlo directamente.';
                }
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

    trigger OnAfterGetCurrRecord()
    var
        Liq: Record "Liquidación";
    begin
        if Liq.Get(Rec."No. Liquidación") then
            IsEditable := Liq.Estado = Liq.Estado::Borrador
        else
            IsEditable := true;
        CurrPage.Editable(IsEditable);
    end;

    var
        DescConcepto: Text[100];
        IsEditable: Boolean;
}
