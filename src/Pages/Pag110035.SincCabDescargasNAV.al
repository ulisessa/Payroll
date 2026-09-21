namespace UAS.Payroll;

// Cabeceras de descarga traídas de NAV. Hay una por marea: la clave de "Cab. descarga" es sólo el
// proyecto. Una fila que espera al proyecto no es un error todavía; sigue en pendiente hasta que el
// proyecto llegue o hasta que se agoten los intentos.
page 110035 "Sinc. Cab. Descargas NAV"
{
    ApplicationArea = All;
    Caption = 'Descargas traídas de NAV - Cabeceras';
    PageType = List;
    UsageCategory = Lists;
    SourceTable = "Stg Descarga Cab NAV";
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
                    ToolTip = 'Pendiente: todavía no se aplicó, o espera a que llegue el proyecto. Procesado: ya está en Cab. descarga. Error: no se pudo aplicar.';
                }
                field("No Proyecto"; Rec."No Proyecto") { ApplicationArea = All; ToolTip = 'Proyecto (marea) al que pertenece la descarga.'; }
                field(Buque; Rec.Buque) { ApplicationArea = All; ToolTip = 'Buque que descarga.'; }
                field(Marea; Rec.Marea) { ApplicationArea = All; ToolTip = 'Código de marea.'; }
                field("Fecha Inicio Descarga"; Rec."Fecha Inicio Descarga") { ApplicationArea = All; ToolTip = 'Fecha en que empezó la descarga.'; }
                field(Puerto; Rec.Puerto) { ApplicationArea = All; ToolTip = 'Puerto de descarga.'; }
                field(Capitan; Rec.Capitan) { ApplicationArea = All; ToolTip = 'Capitán declarado en la descarga.'; }
                field(Observacion; Rec.Observacion) { ApplicationArea = All; ToolTip = 'Por qué falló, o a qué está esperando.'; }
                field(Intentos; Rec.Intentos) { ApplicationArea = All; ToolTip = 'Cuántas veces se intentó aplicar esta fila.'; }
                field("Traido El"; Rec."Traido El") { ApplicationArea = All; ToolTip = 'Cuándo la trajo el job de SQL desde NAV.'; }
                field("Procesado El"; Rec."Procesado El") { ApplicationArea = All; ToolTip = 'Cuándo se intentó aplicar por última vez.'; }
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
                ToolTip = 'Aplica ahora las cabeceras de descarga pendientes.';

                trigger OnAction()
                var
                    Sinc: Codeunit "Sinc NAV Liq.";
                begin
                    Message(MsgProcesado, Sinc.ProcesarEntidad("Entidad Sinc NAV"::"Descarga Cabecera"));
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
