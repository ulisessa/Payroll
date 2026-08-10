namespace UAS.Payroll;

page 110005 "Ficha Cambio Fórmula"
{
    ApplicationArea = All;
    Caption = 'Cambio de Fórmula';
    PageType = Card;
    UsageCategory = None;
    SourceTable = "Historial Fórmula Concepto";
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(GrpCambio)
            {
                Caption = 'Cambio';

                field("Fecha Hora"; Rec."Fecha Hora") { ApplicationArea = All; }
                field(Usuario; Rec.Usuario) { ApplicationArea = All; }
                field("Tipo Cambio"; Rec."Tipo Cambio") { ApplicationArea = All; }
                field("Cód. Concepto"; Rec."Cód. Concepto") { ApplicationArea = All; }
                field("Descripción Concepto"; Rec."Descripción Concepto") { ApplicationArea = All; }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
            }
            group(GrpFormula)
            {
                Caption = 'Fórmula';
                Visible = Rec."Cambió Fórmula";

                field("Fórmula Anterior"; Rec."Fórmula Anterior")
                {
                    ApplicationArea = All;
                    MultiLine = true;
                    Style = Unfavorable;
                    StyleExpr = true;
                }
                field("Fórmula Nueva"; Rec."Fórmula Nueva")
                {
                    ApplicationArea = All;
                    MultiLine = true;
                    Style = Favorable;
                    StyleExpr = true;
                }
            }
            group(GrpCondicion)
            {
                Caption = 'Condición';
                Visible = Rec."Cambió Condición";

                field("Condición Anterior"; Rec."Condición Anterior")
                {
                    ApplicationArea = All;
                    MultiLine = true;
                    Style = Unfavorable;
                    StyleExpr = true;
                }
                field("Condición Nueva"; Rec."Condición Nueva")
                {
                    ApplicationArea = All;
                    MultiLine = true;
                    Style = Favorable;
                    StyleExpr = true;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Restaurar)
            {
                ApplicationArea = All;
                Caption = 'Restaurar texto anterior';
                Image = Undo;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Devuelve la fórmula y la condición del concepto al texto que tenían antes de este cambio.';

                trigger OnAction()
                var
                    HistorialMgt: Codeunit "Historial Fórmulas Liq.";
                begin
                    HistorialMgt.Restaurar(Rec);
                end;
            }
        }
    }
}
