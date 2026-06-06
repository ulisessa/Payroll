namespace UAS.Payroll;

using Microsoft.Projects.Project.Job;

pageextension 50351 "Proyecto Pesca Card Ext." extends "Job Card"
{
    layout
    {
        addafter("Ending Date")
        {
            field("Hora ingreso a puerto"; Rec."Hora ingreso a puerto")
            {
                ApplicationArea = All;
                Caption = 'Hora de arribo';
                ToolTip = 'Hora de entrada a puerto. AM (antes de las 12:00) = día de puerto; PM (12:00 o después) = día de navegación.';
            }
            field("Hora de zarpada"; Rec."Hora de zarpada")
            {
                ApplicationArea = All;
                Caption = 'Hora de zarpada';
                ToolTip = 'Hora de salida del puerto. AM (antes de las 12:00) = día de navegación; PM (12:00 o después) = día de puerto.';
            }
        }
        addlast(FactBoxes)
        {
            part(Personal; "Personal Proyecto")
            {
                ApplicationArea = All;
                Caption = 'Personal';
                SubPageLink = "No. Proyecto" = FIELD("No.");
                Visible = true;
            }
        }
    }

    actions
    {
        addlast(navigation)
        {
            group(GrpPesca)
            {
                Caption = 'Personal';

                action(VerTripulacion)
                {
                    ApplicationArea = All;
                    Caption = 'Personal Asignado';
                    Image = Resource;
                    RunObject = Page "Personal Proyecto";
                    RunPageLink = "No. Proyecto" = FIELD("No.");
                }
                action(VerLiquidaciones)
                {
                    ApplicationArea = All;
                    Caption = 'Liquidaciones';
                    Image = PaymentJournal;
                    RunObject = Page "Lista Liquidaciones";
                    RunPageLink = "No. Proyecto" = FIELD("No.");
                    ToolTip = 'Muestra todas las liquidaciones generadas para este proyecto.';
                }
                action(LiquidarMarea)
                {
                    ApplicationArea = All;
                    Caption = 'Liquidar Personal (Regular)';
                    Image = Calculate;
                    Promoted = true;
                    PromotedCategory = Process;
                    ToolTip = 'Crea liquidaciones Regular en borrador para el personal activo que aún no tenga una para este proyecto.';

                    trigger OnAction()
                    var
                        Periodo: Record "Período Liquidación";
                        ProcLiq: Codeunit "Proceso Liq. Por Lotes";
                        Creadas: Integer;
                    begin
                        if Page.RunModal(Page::"Períodos Liquidación", Periodo) <> Action::LookupOK then
                            exit;
                        Creadas := ProcLiq.CrearPorProyecto(Rec, Periodo.Código, "Tipo Liq."::Regular);
                        Message(MsgCreadosFmt, Creadas, Periodo.Código);
                    end;
                }
                action(LiquidarDevengados)
                {
                    ApplicationArea = All;
                    Caption = 'Crear Devengados';
                    Image = PaymentPeriod;
                    Promoted = true;
                    PromotedCategory = Process;
                    ToolTip = 'Crea liquidaciones de Devengados (fijos mensuales sin producción) para el personal activo en este proyecto.';

                    trigger OnAction()
                    var
                        Periodo: Record "Período Liquidación";
                        ProcLiq: Codeunit "Proceso Liq. Por Lotes";
                        Creadas: Integer;
                    begin
                        if Page.RunModal(Page::"Períodos Liquidación", Periodo) <> Action::LookupOK then
                            exit;
                        Creadas := ProcLiq.CrearPorProyecto(Rec, Periodo.Código, "Tipo Liq."::Devengados);
                        Message(MsgCreadosFmt, Creadas, Periodo.Código);
                    end;
                }
                action(LiquidarCierreMarea)
                {
                    ApplicationArea = All;
                    Caption = 'Crear Cierre Marea';
                    Image = Approval;
                    Promoted = true;
                    PromotedCategory = Process;
                    ToolTip = 'Crea la liquidación de Cierre Marea (navegación + producción) para todo el personal del viaje.';
                    Enabled = HasEndingDate;

                    trigger OnAction()
                    var
                        Periodo: Record "Período Liquidación";
                        ProcLiq: Codeunit "Proceso Liq. Por Lotes";
                        Creadas: Integer;
                    begin
                        if Page.RunModal(Page::"Períodos Liquidación", Periodo) <> Action::LookupOK then
                            exit;
                        Creadas := ProcLiq.CrearPorProyecto(Rec, Periodo.Código, "Tipo Liq."::"Cierre Marea");
                        Message(MsgCreadosFmt, Creadas, Periodo.Código);
                    end;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        HasEndingDate := Rec."Ending Date" <> 0D;
    end;

    var
        HasEndingDate: Boolean;
        MsgCreadosFmt: Label '%1 liquidación(es) creada(s) en borrador para el período %2.';
}
