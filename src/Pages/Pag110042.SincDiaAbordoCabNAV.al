namespace UAS.Payroll;

// Las cabeceras del parte de pesca que llegaron de NAV, antes de aplicarse.
page 110042 "Sinc. Dia Abordo Cab NAV"
{
    ApplicationArea = All;
    Caption = 'Diario de Abordo traído de NAV - Cabeceras';
    PageType = List;
    UsageCategory = Lists;
    SourceTable = "Stg Dia Abordo Cab NAV";
    SourceTableView = sorting("Estado Sinc", "No Proyecto");
    Editable = false;
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Filas)
            {
                field("Estado Sinc"; Rec."Estado Sinc") { ApplicationArea = All; StyleExpr = Estilo; }
                field("No Proyecto"; Rec."No Proyecto") { ApplicationArea = All; }
                field(Buque; Rec.Buque) { ApplicationArea = All; }
                field(Marea; Rec.Marea) { ApplicationArea = All; }
                field(Patron; Rec.Patron) { ApplicationArea = All; }
                field("Fecha Salida"; Rec."Fecha Salida") { ApplicationArea = All; }
                field(Historico; Rec.Historico) { ApplicationArea = All; }
                field("Zona Pesca"; Rec."Zona Pesca")
                {
                    ApplicationArea = All;
                    ToolTip = 'Como viene de NAV, en texto. No se escribe en BC: allá es un campo de opción y traducir la caption a su ordinal sin verificarlo es cómo se guarda un valor plausible y equivocado.';
                }
                field(Observacion; Rec.Observacion) { ApplicationArea = All; }
                field(Intentos; Rec.Intentos) { ApplicationArea = All; }
                field("Traido El"; Rec."Traido El") { ApplicationArea = All; }
                field("Procesado El"; Rec."Procesado El") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Procesar)
            {
                ApplicationArea = All;
                Caption = 'Procesar pendientes';
                Image = Apply;

                trigger OnAction()
                var
                    Sinc: Codeunit "Sinc NAV Liq.";
                begin
                    Message(MsgProcesado, Sinc.ProcesarEntidad("Entidad Sinc NAV"::"Dia Abordo Cabecera"));
                    CurrPage.Update(false);
                end;
            }
            action(VolverAPendiente)
            {
                ApplicationArea = All;
                Caption = 'Volver a pendiente';
                Image = Restore;

                trigger OnAction()
                begin
                    Rec."Estado Sinc" := "Estado Sinc NAV"::Pendiente;
                    Rec.Intentos := 0;
                    Rec.Modify(true);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(Procesar_Promoted; Procesar) { }
                actionref(VolverAPendiente_Promoted; VolverAPendiente) { }
            }
        }
    }

    var
        Estilo: Text;
        MsgProcesado: Label '%1 filas aplicadas.', Comment = '%1 = cantidad';

    trigger OnAfterGetRecord()
    begin
        Estilo := '';
        case Rec."Estado Sinc" of
            "Estado Sinc NAV"::Error:
                Estilo := 'Unfavorable';
            "Estado Sinc NAV"::Pendiente:
                Estilo := 'Ambiguous';
            "Estado Sinc NAV"::Procesado:
                Estilo := 'Favorable';
        end;
    end;
}
