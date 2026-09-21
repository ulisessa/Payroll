namespace UAS.Payroll;

// Las cabeceras de informe del capitán que llegaron de NAV, antes de aplicarse.
page 110040 "Sinc. Informe Cap. Cab NAV"
{
    ApplicationArea = All;
    Caption = 'Informes del Capitán traídos de NAV - Cabeceras';
    PageType = List;
    UsageCategory = Lists;
    SourceTable = "Stg Informe Cap Cab NAV";
    SourceTableView = sorting("Estado Sinc", "No Proyecto");
    Editable = false;
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Filas)
            {
                field("Estado Sinc"; Rec."Estado Sinc")
                {
                    ApplicationArea = All;
                    StyleExpr = Estilo;
                    ToolTip = 'Pendiente: todavía no se aplicó. Procesado: ya está en el informe. Error: llegó y no se pudo aplicar, el motivo está en la observación.';
                }
                field("No Proyecto"; Rec."No Proyecto") { ApplicationArea = All; ToolTip = 'La marea a la que pertenece el informe.'; }
                field(Capitan; Rec.Capitan) { ApplicationArea = All; }
                field(Actividad; Rec.Actividad) { ApplicationArea = All; }
                field("Fecha Inicio Descarga"; Rec."Fecha Inicio Descarga") { ApplicationArea = All; }
                field(Cantidad; Rec.Cantidad)
                {
                    ApplicationArea = All;
                    ToolTip = 'El total que declara NAV. Sirve de control: si no coincide con lo que suman las líneas que llegaron, faltaron líneas.';
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
                ToolTip = 'Aplica ahora las cabeceras pendientes.';

                trigger OnAction()
                var
                    Sinc: Codeunit "Sinc NAV Liq.";
                begin
                    Message(MsgProcesado, Sinc.ProcesarEntidad("Entidad Sinc NAV"::"Informe Cap Cabecera"));
                    CurrPage.Update(false);
                end;
            }
            action(VolverAPendiente)
            {
                ApplicationArea = All;
                Caption = 'Volver a pendiente';
                Image = Restore;
                ToolTip = 'Marca esta fila para que se vuelva a intentar en el próximo proceso.';

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
