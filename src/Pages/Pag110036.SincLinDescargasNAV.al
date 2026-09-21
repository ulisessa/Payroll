namespace UAS.Payroll;

// Líneas de descarga traídas de NAV: los kilos de la marea. De acá salen, ya aplicadas sobre
// "Lín. descarga", las variables de producción que el motor arma por Fuente Datos.
page 110036 "Sinc. Lín. Descargas NAV"
{
    ApplicationArea = All;
    Caption = 'Descargas traídas de NAV - Líneas';
    PageType = List;
    UsageCategory = Lists;
    SourceTable = "Stg Descarga Lin NAV";
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
                    ToolTip = 'Pendiente: todavía no se aplicó, o espera a que llegue el proyecto. Procesado: ya está en Lín. descarga. Error: no se pudo aplicar.';
                }
                field("No Proyecto"; Rec."No Proyecto") { ApplicationArea = All; ToolTip = 'Proyecto (marea) de la descarga.'; }
                field("Line No"; Rec."Line No") { ApplicationArea = All; ToolTip = 'No. de línea en el origen. Junto con el proyecto identifica la fila.'; }
                field("No Remito"; Rec."No Remito") { ApplicationArea = All; ToolTip = 'Remito con el que entró la mercadería.'; }
                field("Item No"; Rec."Item No") { ApplicationArea = All; ToolTip = 'Producto descargado.'; }
                field(Subfamilia; Rec.Subfamilia) { ApplicationArea = All; ToolTip = 'Subfamilia del producto: es por acá que las Fuentes de Datos agrupan la producción.'; }
                field(Cantidad; Rec.Cantidad) { ApplicationArea = All; ToolTip = 'Cantidad descargada.'; }
                field("Peso Neto"; Rec."Peso Neto") { ApplicationArea = All; ToolTip = 'Kilos netos.'; }
                field("Peso Bruto"; Rec."Peso Bruto") { ApplicationArea = All; ToolTip = 'Kilos brutos.'; }
                field("Fecha Remito"; Rec."Fecha Remito") { ApplicationArea = All; ToolTip = 'Fecha del remito.'; }
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
                ToolTip = 'Aplica ahora las líneas de descarga pendientes.';

                trigger OnAction()
                var
                    Sinc: Codeunit "Sinc NAV Liq.";
                begin
                    Message(MsgProcesado, Sinc.ProcesarEntidad("Entidad Sinc NAV"::"Descarga Linea"));
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
