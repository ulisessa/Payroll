namespace UAS.Payroll;

page 50100 "Lista Liquidaciones"
{
    ApplicationArea = All;
    Caption = 'Liquidaciones';
    CardPageId = "Ficha Liquidación";
    PageType = List;
    SourceTable = "Liquidación";
    UsageCategory = Lists;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                }
                field("Cód. Período"; Rec."Cód. Período")
                {
                    ApplicationArea = All;
                }
                field("No. Empleado"; Rec."No. Empleado")
                {
                    ApplicationArea = All;
                }
                field("Nombre Empleado"; Rec."Nombre Empleado")
                {
                    ApplicationArea = All;
                }
                field("Tipo Liquidación"; Rec."Tipo Liquidación")
                {
                    ApplicationArea = All;
                }
                field("Cód. Convenio"; Rec."Cód. Convenio")
                {
                    ApplicationArea = All;
                }
                field("Cód. Categoría"; Rec."Cód. Categoría")
                {
                    ApplicationArea = All;
                }
                field(Estado; Rec.Estado)
                {
                    ApplicationArea = All;
                    StyleExpr = EstadoStyle;
                }
                field("Total Haberes"; Rec."Total Haberes")
                {
                    ApplicationArea = All;
                }
                field("Total Descuentos"; Rec."Total Descuentos")
                {
                    ApplicationArea = All;
                }
                field("Neto a Pagar"; Rec."Neto a Pagar")
                {
                    ApplicationArea = All;
                    Style = Strong;
                }
            }
        }
        area(FactBoxes)
        {
            systempart(Control1; Links) { ApplicationArea = All; }
            systempart(Control2; Notes) { ApplicationArea = All; }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Calcular)
            {
                ApplicationArea = All;
                Caption = 'Calcular';
                Image = Calculate;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Enabled = CanCalcular;

                trigger OnAction()
                var
                    Motor: Codeunit "Motor Liquidación";
                begin
                    Motor.LiquidarRecord(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(CalcularSeleccion)
            {
                ApplicationArea = All;
                Caption = 'Calcular Selección';
                Image = CalculateLines;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Calcula todas las liquidaciones marcadas en la lista que estén en estado Borrador o Calculada.';

                trigger OnAction()
                var
                    LiqSel: Record "Liquidación";
                    Motor: Codeunit "Motor Liquidación";
                    Calculadas: Integer;
                begin
                    CurrPage.SetSelectionFilter(LiqSel);
                    LiqSel.SetFilter(Estado, '%1|%2|%3', LiqSel.Estado::Borrador, LiqSel.Estado::Calculada, LiqSel.Estado::Aprobada);
                    if not LiqSel.FindSet(true) then begin
                        Message(MsgSinSeleccion);
                        exit;
                    end;
                    repeat
                        Motor.LiquidarRecord(LiqSel);
                        Calculadas += 1;
                    until LiqSel.Next() = 0;
                    Message(MsgCalculadas, Calculadas);
                    CurrPage.Update(false);
                end;
            }
            action(Aprobar)
            {
                ApplicationArea = All;
                Caption = 'Aprobar';
                Image = Approve;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    Gestion: Codeunit "Gestión Liquidación";
                begin
                    Gestion.Aprobar(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(Reabrir)
            {
                ApplicationArea = All;
                Caption = 'Reabrir';
                Image = ReOpen;

                trigger OnAction()
                var
                    Gestion: Codeunit "Gestión Liquidación";
                begin
                    Gestion.Reabrir(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(RevertirAprobacion)
            {
                ApplicationArea = All;
                Caption = 'Revertir Aprobación';
                Image = Undo;
                ToolTip = 'Devuelve la liquidación al estado Calculada para permitir su revisión o corrección.';

                trigger OnAction()
                var
                    Gestion: Codeunit "Gestión Liquidación";
                begin
                    if Gestion.RevertirAprobacion(Rec) then
                        CurrPage.Update(false);
                end;
            }
        }
        area(Reporting)
        {
            action(ImprimirRecibo)
            {
                ApplicationArea = All;
                Caption = 'Imprimir Recibo';
                Image = Print;
                Promoted = true;
                PromotedCategory = Report;
                ToolTip = 'Imprime el recibo de sueldo de la liquidación seleccionada.';

                trigger OnAction()
                var
                    Liq: Record "Liquidación";
                begin
                    Liq.SetRange("No.", Rec."No.");
                    Report.RunModal(Report::"Recibo de Sueldo", true, false, Liq);
                end;
            }
            action(ImprimirReciboSeleccion)
            {
                ApplicationArea = All;
                Caption = 'Imprimir Recibo (Selección)';
                Image = PrintReport;
                Promoted = true;
                PromotedCategory = Report;
                ToolTip = 'Imprime los recibos de sueldo de todas las liquidaciones marcadas.';

                trigger OnAction()
                var
                    Liq: Record "Liquidación";
                begin
                    CurrPage.SetSelectionFilter(Liq);
                    Report.RunModal(Report::"Recibo de Sueldo", true, false, Liq);
                end;
            }
        }
        area(Navigation)
        {
            action(VerLineas)
            {
                ApplicationArea = All;
                Caption = 'Ver Líneas';
                Image = Line;
                RunObject = Page "Líneas Liquidación";
                RunPageLink = "No. Liquidación" = FIELD("No.");
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        CanCalcular := Rec.Estado = Rec.Estado::Borrador;
        SetEstadoStyle();
    end;

    local procedure SetEstadoStyle()
    begin
        case Rec.Estado of
            Rec.Estado::Borrador:
                EstadoStyle := 'Subordinate';
            Rec.Estado::Calculada:
                EstadoStyle := 'Favorable';
            Rec.Estado::Aprobada:
                EstadoStyle := 'Strong';
            Rec.Estado::Contabilizada:
                EstadoStyle := 'Attention';
        end;
    end;

    var
        EstadoStyle: Text;
        CanCalcular: Boolean;
        MsgSinSeleccion: Label 'No hay liquidaciones en estado Borrador o Calculada en la selección.';
        MsgCalculadas: Label '%1 liquidación(es) calculada(s).';
}
