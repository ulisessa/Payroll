namespace UAS.Payroll;

page 50195 "Tipos Liquidación"
{
    ApplicationArea = All;
    Caption = 'Tipos de Liquidación';
    PageType = List;
    SourceTable = "Tipo Liquidación";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field(Orden; Rec.Orden) { ApplicationArea = All; }
                field("Liquida al Arribo"; Rec."Liquida al Arribo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Comportamiento Cierre de Marea: liquida a la fecha de arribo (navegación + producción).';
                }
                field("Sólo Proyectos en Curso"; Rec."Sólo Proyectos en Curso")
                {
                    ApplicationArea = All;
                    ToolTip = 'Marcado, sólo entran los proyectos que al cierre del período todavía no arribaron. Es lo propio de los Devengados, que acumulan mientras la marea está en el mar. No lo marques en la Regular: recorre los proyectos para encontrar a la gente, y dejaría afuera a los que volvieron durante el mes.';
                }
                field("Tipo Proyecto"; Rec."Tipo Proyecto")
                {
                    ApplicationArea = All;
                    ToolTip = 'Sobre qué proyectos corre la creación de este tipo. Productivo para los que pertenecen a una marea —Devengados, Cierre de Marea—. Todos para la Regular, que recorre los proyectos sólo para encontrar a la gente y después agrupa por empleado.';
                }
                field("Agrupa por Empleado"; Rec."Agrupa por Empleado")
                {
                    ApplicationArea = All;
                    ToolTip = 'Marcado, se crea UNA liquidación por empleado y período, sin proyecto, en vez de una por cada proyecto al que estuvo asignado. Es lo que corresponde a la Regular, que paga lo del mes y no lo de un buque. No lo marques en tipos cuyos importes dependan del proyecto —Devengados, o cualquiera que use navegación o producción—: la cabecera queda sin proyecto y esas variables dan cero.';
                }
                field("Incluye Francos Puerto"; Rec."Incluye Francos Puerto")
                {
                    ApplicationArea = All;
                    ToolTip = 'Al crear por período, genera también liquidaciones para empleados en francos en puerto (comportamiento Regular).';
                }
                field(Activo; Rec.Activo) { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SembrarMigrar)
            {
                ApplicationArea = All;
                Caption = 'Sembrar y migrar datos';
                Image = Setup;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Crea los tipos por defecto (si faltan) y convierte las liquidaciones, líneas y conceptos existentes del enum al código de esta tabla. Es seguro ejecutarlo varias veces.';

                trigger OnAction()
                var
                    GestionTipoLiq: Codeunit "Gestión Tipo Liq.";
                begin
                    if not Confirm(QstMigrar, true) then
                        exit;
                    GestionTipoLiq.Sembrar();
                    GestionTipoLiq.MigrarDatos();
                    Message(MsgMigrado);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    var
        QstMigrar: Label 'Se crearán los tipos por defecto y se convertirán las liquidaciones, líneas y conceptos existentes al nuevo código. ¿Continuar?';
        MsgMigrado: Label 'Tipos sembrados y datos migrados.';
}
