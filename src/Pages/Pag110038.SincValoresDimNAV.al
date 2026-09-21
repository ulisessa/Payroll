namespace UAS.Payroll;

// Los valores de dimensión que NAV mandó, antes de aplicarse. Se mira cuando un proyecto quedó en
// Error por un buque o una marea que BC no conoce: acá está si el valor llegó y qué pasó al crearlo.
page 110038 "Sinc. Valores Dim. NAV"
{
    ApplicationArea = All;
    Caption = 'Valores de dimensión traídos de NAV';
    PageType = List;
    UsageCategory = Lists;
    SourceTable = "Stg Valor Dim NAV";
    SourceTableView = sorting("Estado Sinc", "Cod Dimension", Codigo);
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
                    ToolTip = 'Pendiente: todavía no se aplicó. Procesado: el valor existe en BC. Error: llegó y no se pudo crear, el motivo está en la observación.';
                }
                field("Cod Dimension"; Rec."Cod Dimension")
                {
                    ApplicationArea = All;
                    ToolTip = 'Dimensión a la que pertenece el valor. Sólo se traen las tres que usa la sincronización de proyectos: buque, marea y actividad.';
                }
                field(Codigo; Rec.Codigo) { ApplicationArea = All; ToolTip = 'Código del valor, tal como viene de NAV.'; }
                field(Nombre; Rec.Nombre) { ApplicationArea = All; ToolTip = 'Nombre en NAV. Es el motivo por el que estos valores se traen en vez de crearse con el código como nombre.'; }
                field(Bloqueado; Rec.Bloqueado) { ApplicationArea = All; ToolTip = 'Si en NAV está bloqueado, en BC se crea bloqueado también.'; }
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
                ToolTip = 'Crea ahora en BC los valores de dimensión pendientes. Conviene correrlo antes que los proyectos.';

                trigger OnAction()
                var
                    Sinc: Codeunit "Sinc NAV Liq.";
                begin
                    Message(MsgProcesado, Sinc.ProcesarEntidad("Entidad Sinc NAV"::"Valor Dimension"));
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
