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
                field(Disparador; Rec.Disparador)
                {
                    ApplicationArea = All;
                    ToolTip = 'Qué hecho hace que este tipo corresponda. Arribo de marea es el Cierre, que liquida a la fecha de arribo. Marea en curso son los Devengados, que acumulan mientras el barco está en el mar. Baja del empleado es la Liquidación Final, que corre todos los meses pero sale sólo para quien se fue. Ninguno corre para todos los que pasen el resto de los filtros.';
                }
                field(Meses; Rec.Meses)
                {
                    ApplicationArea = All;
                    ToolTip = 'En qué meses corre, con sintaxis de filtro: 6|12 para el aguinaldo, 1..6 para un rango. Vacío significa todos los meses. Es el único filtro que no mira al empleado sino al calendario.';
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
                field(AplicaA; Rec."Aplica A")
                {
                    ApplicationArea = All;
                    ToolTip = 'A qué clase de empleado le corresponde este DOCUMENTO. "Todos" no restringe. Es el mismo eje que el "Aplica a" del concepto, pero decide el recibo entero en vez de una línea: Vacaciones va en Tripulante porque al mensualizado no se le emite un recibo aparte, cobra el haber de vacaciones y el descuento de días en su recibo mensual. La clase sale del convenio del empleado.';
                }
                field(SoloConceptosDeclarados; Rec."Sólo Conceptos Declarados")
                {
                    ApplicationArea = All;
                    ToolTip = 'Marcado, este tipo corre ÚNICAMENTE los conceptos que lo nombran en "Aplica a Tipo Liq.". Sin marcar, un concepto que no declara ningún tipo corre en todos — que es lo que hacía que la liquidación de Vacaciones recalculara el recibo entero. Usalo en los tipos que pagan una cosa puntual y asignales sus conceptos desde Conceptos por Tipo de Liquidación.';
                }
                field(EntraEnCorridaCompleta; Rec."Entra en Corrida Completa")
                {
                    ApplicationArea = All;
                    ToolTip = 'Marcalo si este tipo tiene que correr todos los meses cuando se crean o calculan liquidaciones sin elegir tipo. Activo sólo dice que el tipo existe y se puede usar a mano; esto dice que se dispara solo. Los de una sola vez (saldos iniciales) y los que no los dispara ningún hecho del empleado (reliquidación) van sin marcar.';
                }
                field(GeneraAsiento; Rec."Genera Asiento")
                {
                    ApplicationArea = All;
                    ToolTip = 'Marcado, las liquidaciones de este tipo entran en el asiento de sueldos. La historia migrada de Meta4 y los saldos iniciales van sin marcar: están aprobados, pero ya se contabilizaron en su momento.';
                }
            }
            part(Estados; "Estados Tipo Liq. Sub")
            {
                ApplicationArea = All;
                Caption = 'Estados que lo justifican';
                SubPageLink = "Cód. Tipo Liq." = field(Código);
                UpdatePropagation = Both;
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
