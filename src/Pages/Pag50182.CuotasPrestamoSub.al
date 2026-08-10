namespace UAS.Payroll;

page 50182 "Cuotas Préstamo Sub"
{
    ApplicationArea = All;
    Caption = 'Cuotas';
    PageType = ListPart;
    SourceTable = "Cuota Préstamo";
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No. Cuota"; Rec."No. Cuota") { ApplicationArea = All; Editable = false; }
                field(Importe; Rec.Importe)
                {
                    ApplicationArea = All;
                    Style = Strong;
                    Editable = Rec.Estado = Rec.Estado::Pendiente;
                }
                field("Cód. Período"; Rec."Cód. Período")
                {
                    ApplicationArea = All;
                    ToolTip = 'Período de liquidación en que se descuenta automáticamente. Dejarlo en blanco si se asigna por liquidación directa.';
                    Editable = Rec.Estado = Rec.Estado::Pendiente;
                }
                field("No. Liquidación"; Rec."No. Liquidación")
                {
                    ApplicationArea = All;
                    ToolTip = 'Liquidación específica donde se aplicará. Tiene prioridad sobre el Período.';
                    Editable = Rec.Estado = Rec.Estado::Pendiente;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Liq: Record "Liquidación";
                        LiqPage: Page "Lista Liquidaciones";
                    begin
                        // Filter by employee (FlowField, must CalcFields first)
                        Rec.CalcFields("No. Empleado");
                        if Rec."No. Empleado" <> '' then
                            Liq.SetRange("No. Empleado", Rec."No. Empleado");

                        // Narrow further if a period is already set
                        if Rec."Cód. Período" <> '' then
                            Liq.SetRange("Cód. Período", Rec."Cód. Período");

                        LiqPage.SetTableView(Liq);
                        LiqPage.LookupMode(true);
                        if LiqPage.RunModal() = Action::LookupOK then begin
                            LiqPage.GetRecord(Liq);
                            Rec."No. Liquidación" := Liq."No.";
                            Text := Liq."No.";
                            exit(true);
                        end;
                        exit(false);
                    end;
                }
                field(Estado; Rec.Estado)
                {
                    ApplicationArea = All;
                    StyleExpr = EstadoStyle;
                    Editable = false;
                }
                field("No. Liquidación Aplicada"; Rec."No. Liquidación Aplicada")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Fecha Aplicada"; Rec."Fecha Aplicada")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Anular)
            {
                ApplicationArea = All;
                Caption = 'Anular Cuota';
                Image = Cancel;
                Enabled = Rec.Estado = Rec.Estado::Pendiente;
                trigger OnAction()
                begin
                    Rec.TestField(Estado, Rec.Estado::Pendiente);
                    Rec.Estado := Rec.Estado::Anulada;
                    Rec.Modify();
                end;
            }
            action(Reactivar)
            {
                ApplicationArea = All;
                Caption = 'Reactivar Cuota';
                Image = ResetStatus;
                Enabled = Rec.Estado = Rec.Estado::Anulada;
                trigger OnAction()
                begin
                    Rec.Estado := Rec.Estado::Pendiente;
                    Rec.Modify();
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec.Estado of
            Rec.Estado::Pendiente: EstadoStyle := 'Favorable';
            Rec.Estado::Aplicada: EstadoStyle := 'Strong';
            Rec.Estado::Anulada: EstadoStyle := 'Subordinate';
        end;
    end;

    var
        EstadoStyle: Text;
}
