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
    PromotedActionCategories = 'Nuevo,Proceso,Informe,Liquidar';

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
                field("Cód. Tipo Liq."; Rec."Cód. Tipo Liq.")
                {
                    ApplicationArea = All;
                }
                field(Job; Rec."No. Proyecto")
                {
                    ApplicationArea = All;
                }
                field("Cobertura Desde"; Rec."Cobertura Desde")
                {
                    ApplicationArea = All;
                    ToolTip = 'Primer día que cubre esta liquidación. Una mensual cubre el período entero; un cierre de marea, sólo los días del viaje.';
                }
                field("Cobertura Hasta"; Rec."Cobertura Hasta")
                {
                    ApplicationArea = All;
                    ToolTip = 'Último día que cubre. Los días que ninguna liquidación cubre son los que faltan liquidar.';
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
            action(CalcularSeleccion)
            {
                ApplicationArea = All;
                Caption = 'Calcular';
                Image = Calculate;
                Promoted = true;
                PromotedCategory = Category4;
                PromotedIsBig = true;
                ToolTip = 'Calcula todas las liquidaciones marcadas en la lista que estén en estado Borrador o Calculada.';

                trigger OnAction()
                var
                    LiqSel: Record "Liquidación";
                    Lotes: Codeunit "Lotes Liquidación Liq.";
                begin
                    // NUNCA un SetFilter sobre un campo después de SetSelectionFilter. Cuando la
                    // selección abarca las filas visibles, la plataforma la expresa copiando los
                    // filtros de la página; si esa página está filtrada por Estado = Borrador y acá
                    // se filtra Estado otra vez, el segundo filtro REEMPLAZA al primero y la
                    // selección se ensancha sola. Con ese bug, seleccionar seis borradores
                    // recalculaba todo el período: entraban también las ya Calculadas y Aprobadas.
                    //
                    // Por eso la selección se pasa tal cual al lote, que tampoco la toca y verifica
                    // el estado registro por registro.
                    CurrPage.SetSelectionFilter(LiqSel);
                    Lotes.Calcular(LiqSel);
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
                Promoted = true;
                PromotedCategory = Category4;
                PromotedIsBig = true;
                ToolTip = 'Reabre las liquidaciones marcadas que estén en estado Calculada, devolviéndolas a Borrador.';

                trigger OnAction()
                var
                    LiqSel: Record "Liquidación";
                    Lotes: Codeunit "Lotes Liquidación Liq.";
                begin
                    // Sin SetRange sobre Estado: la selección puede venir expresada como los filtros
                    // de la página, y filtrar el mismo campo otra vez los reemplaza en vez de
                    // acotarlos — con eso se reabrirían liquidaciones que no estaban seleccionadas.
                    // El lote verifica el estado por registro.
                    CurrPage.SetSelectionFilter(LiqSel);
                    Lotes.Reabrir(LiqSel);
                    CurrPage.Update(false);
                end;
            }
            action(EliminarSeleccion)
            {
                ApplicationArea = All;
                Caption = 'Eliminar Selección';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Elimina las liquidaciones seleccionadas que estén en estado Borrador.';

                trigger OnAction()
                var
                    LiqSel: Record "Liquidación";
                    Lotes: Codeunit "Lotes Liquidación Liq.";
                begin
                    CurrPage.SetSelectionFilter(LiqSel);
                    Lotes.Eliminar(LiqSel);
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
}
