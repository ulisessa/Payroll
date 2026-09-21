namespace UAS.Payroll;

// La producción día por día que llegó de NAV, antes de aplicarse.
//
// Es la pantalla donde mirar cuando hay que liquidarle a alguien hasta una fecha: acá está lo que
// se produjo cada día, y "Fecha Registro" es la columna que lo hace posible.
page 110043 "Sinc. Dia Abordo Lin NAV"
{
    ApplicationArea = All;
    Caption = 'Diario de Abordo traído de NAV - Líneas';
    PageType = List;
    UsageCategory = Lists;
    SourceTable = "Stg Dia Abordo Lin NAV";
    SourceTableView = sorting("Estado Sinc", "No Proyecto", "Line No");
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
                field("Line No"; Rec."Line No") { ApplicationArea = All; }
                field("Fecha Registro"; Rec."Fecha Registro")
                {
                    ApplicationArea = All;
                    ToolTip = 'El día al que corresponde la producción. Es lo que permite cortar una marea a una fecha y liquidar hasta ahí.';
                }
                field(Concepto; Rec.Concepto)
                {
                    ApplicationArea = All;
                    ToolTip = 'Distingue los días de pesca de los que no lo son. Un día en PUERTO viene con cantidad y kilos en cero, y eso no es un dato faltante: es el dato.';
                }
                field(Producto; Rec.Producto) { ApplicationArea = All; }
                field(Descripcion; Rec.Descripcion) { ApplicationArea = All; }
                field(Cantidad; Rec.Cantidad) { ApplicationArea = All; }
                field(Kilos; Rec.Kilos) { ApplicationArea = All; }
                field("Unidad Medida Desc"; Rec."Unidad Medida Desc") { ApplicationArea = All; }
                field(Enviado; Rec.Enviado) { ApplicationArea = All; }
                field("Zona Pesca"; Rec."Zona Pesca") { ApplicationArea = All; Visible = false; }
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
                    Message(MsgProcesado, Sinc.ProcesarEntidad("Entidad Sinc NAV"::"Dia Abordo Linea"));
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
