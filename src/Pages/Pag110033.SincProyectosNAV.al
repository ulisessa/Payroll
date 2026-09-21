namespace UAS.Payroll;

// Lo que NAV mandó de proyectos, tal como llegó y antes de aplicarse. Es la pantalla donde se mira
// qué decía el origen cuando lo que quedó en la ficha del proyecto no es lo que se esperaba.
page 110033 "Sinc. Proyectos NAV"
{
    ApplicationArea = All;
    Caption = 'Proyectos traídos de NAV';
    PageType = List;
    UsageCategory = Lists;
    SourceTable = "Stg Proyecto NAV";
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
                    ToolTip = 'Pendiente: todavía no se aplicó. Procesado: ya está en el proyecto. Error: llegó y no se pudo aplicar, el motivo está en la observación.';
                }
                field("No Proyecto"; Rec."No Proyecto")
                {
                    ApplicationArea = All;
                    ToolTip = 'No. de proyecto en NAV. Es el mismo con el que se crea en BC.';
                }
                field(Descripcion; Rec.Descripcion) { ApplicationArea = All; ToolTip = 'Descripción del proyecto en el origen.'; }
                field(Buque; Rec.Buque) { ApplicationArea = All; ToolTip = 'Código de buque, que se aplica como Dimensión Global 1 del proyecto.'; }
                field(Marea; Rec.Marea) { ApplicationArea = All; ToolTip = 'Código de marea, que se aplica como Dimensión Global 2 del proyecto.'; }
                field("Fecha Inicio"; Rec."Fecha Inicio") { ApplicationArea = All; ToolTip = 'Fecha de zarpada.'; }
                field("Fecha Fin"; Rec."Fecha Fin")
                {
                    ApplicationArea = All;
                    ToolTip = 'Fecha de arribo. Aplicarla sobre un proyecto que la tenía vacía cierra la marea y da de baja las asignaciones de personal abiertas.';
                }
                field(Observacion; Rec.Observacion)
                {
                    ApplicationArea = All;
                    ToolTip = 'Por qué falló, o qué quedó pendiente aunque se haya aplicado.';
                }
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
                ToolTip = 'Aplica ahora las filas pendientes de proyectos.';

                trigger OnAction()
                var
                    Sinc: Codeunit "Sinc NAV Liq.";
                begin
                    Message(MsgProcesado, Sinc.ProcesarEntidad("Entidad Sinc NAV"::Proyecto));
                    CurrPage.Update(false);
                end;
            }
            action(VolverAPendiente)
            {
                ApplicationArea = All;
                Caption = 'Volver a pendiente';
                Image = Restore;
                ToolTip = 'Marca esta fila para que se vuelva a intentar en el próximo proceso. Se usa después de corregir en BC lo que la hacía fallar.';

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
