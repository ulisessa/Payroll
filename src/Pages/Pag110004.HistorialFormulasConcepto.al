namespace UAS.Payroll;

page 110004 "Historial Fórmulas Concepto"
{
    ApplicationArea = All;
    Caption = 'Historial de Cambios de Fórmula';
    PageType = List;
    UsageCategory = History;
    SourceTable = "Historial Fórmula Concepto";
    SourceTableView = sorting("Fecha Hora") order(descending);
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    CardPageId = "Ficha Cambio Fórmula";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Fecha Hora"; Rec."Fecha Hora")
                {
                    ApplicationArea = All;
                    Width = 16;
                }
                field(Usuario; Rec.Usuario)
                {
                    ApplicationArea = All;
                    Width = 14;
                }
                field("Tipo Cambio"; Rec."Tipo Cambio")
                {
                    ApplicationArea = All;
                    Width = 10;
                    StyleExpr = FilaStyle;
                }
                field("Cód. Concepto"; Rec."Cód. Concepto")
                {
                    ApplicationArea = All;
                    Width = 8;

                    trigger OnDrillDown()
                    begin
                        AbrirConcepto();
                    end;
                }
                field("Descripción Concepto"; Rec."Descripción Concepto") { ApplicationArea = All; }
                field("Vigencia Desde"; Rec."Vigencia Desde")
                {
                    ApplicationArea = All;
                    Width = 10;
                }
                field("Cambió Fórmula"; Rec."Cambió Fórmula")
                {
                    ApplicationArea = All;
                    Width = 8;
                }
                field("Cambió Condición"; Rec."Cambió Condición")
                {
                    ApplicationArea = All;
                    Width = 8;
                }
                field(Resumen; Resumen)
                {
                    ApplicationArea = All;
                    Caption = 'Texto resultante';
                    // Una fórmula puede tener 2048 caracteres: en la grilla va el texto recortado y
                    // el completo se ve en la ficha del cambio, que lo muestra contra el anterior.
                    ToolTip = 'Texto que quedó después del cambio, recortado. Abrí el cambio para ver el antes y el después completos.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(VerCambio)
            {
                ApplicationArea = All;
                Caption = 'Ver cambio';
                Image = ViewDetails;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ShortcutKey = 'Return';
                ToolTip = 'Muestra el texto anterior y el nuevo, completos, uno al lado del otro.';

                trigger OnAction()
                var
                    Ficha: Page "Ficha Cambio Fórmula";
                begin
                    Ficha.SetRecord(Rec);
                    Ficha.RunModal();
                end;
            }
            action(Restaurar)
            {
                ApplicationArea = All;
                Caption = 'Restaurar texto anterior';
                Image = Undo;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Devuelve la fórmula y la condición del concepto al texto que tenían antes de este cambio. La restauración queda registrada como un cambio más.';

                trigger OnAction()
                var
                    HistorialMgt: Codeunit "Historial Fórmulas Liq.";
                begin
                    HistorialMgt.Restaurar(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(AbrirConceptoAccion)
            {
                ApplicationArea = All;
                Caption = 'Abrir concepto';
                Image = Card;
                ToolTip = 'Abre la ficha del concepto afectado.';

                trigger OnAction()
                begin
                    AbrirConcepto();
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        Resumen := CopyStr(Rec.ResumenCambio(), 1, MaxStrLen(Resumen));
        case Rec."Tipo Cambio" of
            Rec."Tipo Cambio"::Eliminación:
                FilaStyle := 'Unfavorable';
            Rec."Tipo Cambio"::Alta:
                FilaStyle := 'Favorable';
            else
                FilaStyle := 'Ambiguous';
        end;
    end;

    local procedure AbrirConcepto()
    var
        Concepto: Record "Concepto Liquidación";
    begin
        if Concepto.Get(Rec."Cód. Concepto", Rec."Vigencia Desde") then
            Page.Run(Page::"Concepto Liq. Card", Concepto);
    end;

    var
        Resumen: Text[250];
        FilaStyle: Text[20];
}
