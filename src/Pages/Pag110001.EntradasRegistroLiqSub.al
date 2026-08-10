namespace UAS.Payroll;

page 110001 "Entradas Registro Liq. Sub"
{
    ApplicationArea = All;
    Caption = 'Detalle del proceso';
    PageType = ListPart;
    SourceTable = "Entrada Registro Liq.";
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Severidad; Rec.Severidad)
                {
                    ApplicationArea = All;
                    StyleExpr = FilaStyle;
                    Width = 10;
                }
                field(Categoría; Rec.Categoría)
                {
                    ApplicationArea = All;
                    Width = 10;
                }
                field("Nombre Variable"; Rec."Nombre Variable")
                {
                    ApplicationArea = All;
                    Caption = 'Acumulador / Variable';
                    Width = 14;
                    Style = Strong;
                    StyleExpr = true;
                }
                field("Cód. Concepto"; Rec."Cód. Concepto")
                {
                    ApplicationArea = All;
                    Width = 8;

                    trigger OnDrillDown()
                    var
                        Concepto: Record "Concepto Liquidación";
                    begin
                        if Rec."Cód. Concepto" = '' then
                            exit;
                        Concepto.SetRange(Código, Rec."Cód. Concepto");
                        if Concepto.FindLast() then
                            Page.Run(Page::"Concepto Liq. Card", Concepto);
                    end;
                }
                field(Mensaje; Rec.Mensaje)
                {
                    ApplicationArea = All;
                    StyleExpr = FilaStyle;
                    // Sin MultiLine a propósito: en un repeater agranda TODAS las filas, no solo la
                    // que tiene texto largo. El clic muestra el texto completo.

                    trigger OnDrillDown()
                    begin
                        if Rec.Detalle <> '' then
                            Message('%1\\%2', Rec.Mensaje, Rec.Detalle)
                        else
                            Message(Rec.Mensaje);
                    end;
                }
                field(Importe; Rec.Importe)
                {
                    ApplicationArea = All;
                    Width = 18;
                    BlankZero = true;
                }
                field("Fecha Hora"; Rec."Fecha Hora") { ApplicationArea = All; Visible = false; }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec.Severidad of
            Rec.Severidad::Error:
                FilaStyle := 'Unfavorable';
            Rec.Severidad::Advertencia:
                FilaStyle := 'Ambiguous';
            else
                FilaStyle := 'Subordinate';
        end;
    end;

    var
        FilaStyle: Text[20];
}
