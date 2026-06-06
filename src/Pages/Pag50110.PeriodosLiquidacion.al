namespace UAS.Payroll;

page 50110 "Períodos Liquidación"
{
    ApplicationArea = All;
    Caption = 'Períodos Liquidación';
    PageType = List;
    SourceTable = "Período Liquidación";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Año; Rec.Año) { ApplicationArea = All; }
                field(Mes; Rec.Mes) { ApplicationArea = All; }
                field("Fecha Desde"; Rec."Fecha Desde") { ApplicationArea = All; }
                field("Fecha Hasta"; Rec."Fecha Hasta") { ApplicationArea = All; }
                field(Estado; Rec.Estado)
                {
                    ApplicationArea = All;
                    StyleExpr = EstadoStyle;
                }
                field("Cód. Calendario"; Rec."Cód. Calendario")
                {
                    ApplicationArea = All;
                    ToolTip = 'Calendario base que define los días no laborables. Vacío = se cuentan días lunes a viernes.';
                }
                field("Cant. Liquidaciones"; Rec."Cant. Liquidaciones")
                {
                    ApplicationArea = All;
                    // Hidden by default: this is a Count FlowField that triggers a
                    // SELECT COUNT(*) per visible row. Users can enable via personalization.
                    Visible = false;
                }
                field("Fecha Cierre"; Rec."Fecha Cierre") { ApplicationArea = All; Editable = false; }
                field("Usuario Cierre"; Rec."Usuario Cierre") { ApplicationArea = All; Editable = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CerrarPeriodo)
            {
                ApplicationArea = All;
                Caption = 'Cerrar Período';
                Image = Close;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = Rec.Estado = Rec.Estado::Abierto;

                trigger OnAction()
                begin
                    if not Confirm('¿Confirma el cierre del período %1? Esta acción no se puede deshacer.', false, Rec.Código) then
                        exit;
                    Rec.Estado := Rec.Estado::Cerrado;
                    Rec."Fecha Cierre" := Today();
                    Rec."Usuario Cierre" := CopyStr(UserId(), 1, 50);
                    Rec.Modify(true);
                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(VerLiquidaciones)
            {
                ApplicationArea = All;
                Caption = 'Liquidaciones';
                Image = List;
                RunObject = Page "Lista Liquidaciones";
                RunPageLink = "Cód. Período" = FIELD(Código);
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        if Rec.Estado = Rec.Estado::Cerrado then
            EstadoStyle := 'Subordinate'
        else
            EstadoStyle := 'Favorable';
    end;

    var
        EstadoStyle: Text;
}
