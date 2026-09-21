namespace UAS.Payroll;

// El detalle de los informes del capitán que llegaron de NAV, antes de aplicarse.
page 110041 "Sinc. Informe Cap. Lin NAV"
{
    ApplicationArea = All;
    Caption = 'Informes del Capitán traídos de NAV - Líneas';
    PageType = List;
    UsageCategory = Lists;
    SourceTable = "Stg Informe Cap Lin NAV";
    SourceTableView = sorting("Estado Sinc", "No Proyecto", "Line No");
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
                field("No Proyecto"; Rec."No Proyecto") { ApplicationArea = All; }
                field("Line No"; Rec."Line No") { ApplicationArea = All; }
                field(Clasificacion; Rec.Clasificacion)
                {
                    ApplicationArea = All;
                    ToolTip = 'El grado del producto (L-1, L-2, L-ENTERO). Es lo que decide con qué valor se liquida cada kilo — no confundir con el lote ni con la familia.';
                }
                field(Descripcion; Rec.Descripcion) { ApplicationArea = All; }
                field("Unidad Medida"; Rec."Unidad Medida") { ApplicationArea = All; }
                field(Cantidad; Rec.Cantidad) { ApplicationArea = All; }
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
                ToolTip = 'Aplica ahora las líneas pendientes. La cabecera tiene que estar aplicada antes.';

                trigger OnAction()
                var
                    Sinc: Codeunit "Sinc NAV Liq.";
                begin
                    Message(MsgProcesado, Sinc.ProcesarEntidad("Entidad Sinc NAV"::"Informe Cap Linea"));
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
