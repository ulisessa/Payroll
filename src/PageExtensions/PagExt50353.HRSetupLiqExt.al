namespace UAS.Payroll;

using Microsoft.HumanResources.Setup;

pageextension 50353 "HR Setup Liq. Ext." extends "Human Resources Setup"
{
    layout
    {
        addlast(content)
        {
            group(GrpPayroll)
            {
                Caption = 'Liquidaciones';

                field("Cód. Serie Liq."; Rec."Cód. Serie Liq.")
                {
                    ApplicationArea = All;
                    Caption = 'Serie Núm. Liquidaciones';
                    ToolTip = 'Serie de numeración usada para generar el número de cada liquidación (ej. LIQ-000001).';
                    ShowMandatory = true;
                }
                field("Proyecto Nómina"; Rec."Proyecto Nómina")
                {
                    ApplicationArea = All;
                    ToolTip = 'Proyecto de inactividad por defecto: se usa para asignar empleados que pasan a un estado inactivo cuando su marea no tiene un "Proyecto Inactividad Nómina" propio.';
                }
                field("Cód. Estado Alta Sinc."; Rec."Cód. Estado Alta Sinc.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Código de estado de tipo Alta que se asigna en el historial a los empleados que llegan por la sincronización con NAV, usando su fecha de ingreso. Sin este código la sincronización de empleados no crea la fase de alta y, por lo tanto, la antigüedad de esos empleados calcularía cero.';
                }
                field("Máx. Intentos Sinc."; Rec."Máx. Intentos Sinc.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Cuántas corridas puede esperar una fila que depende de otra que todavía no llegó, típicamente una línea de descarga cuyo proyecto aún no se sincronizó. Superado el límite pasa a error, que es un estado visible, en lugar de seguir reintentando en silencio.';
                }
                field("Cód. Concepto Neto Garantizado"; Rec."Cód. Concepto Neto Garantizado")
                {
                    ApplicationArea = All;
                    ToolTip = 'Concepto cuya fórmula calcula el neto que el grossing-up debe alcanzar. El concepto tiene que ser de tipo Informativo: así deja su línea en la liquidación, auditable y con su detalle de variables, sin sumar al neto que el propio cálculo está tratando de igualar. Su fórmula no puede referenciar COMPLEMENTO_GU, porque entonces el objetivo se movería en cada iteración y el cálculo no cerraría nunca; si lo hace, la liquidación se detiene con un error que lo explica. Si este campo queda vacío, ninguna liquidación aplica grossing-up.';
                }
                field("Cód. Acum. Haberes Gravados"; Rec."Cód. Acum. Haberes Gravados")
                {
                    ApplicationArea = All;
                    ToolTip = 'Acumulador del que se toma el importe que se guarda en "Haberes Ordinarios Gravados" de cada liquidación, que es la base de la que después parten los informes de Ganancias. Sólo se pueden elegir conceptos marcados como acumulador. Si queda vacío, ese campo de la liquidación queda en cero: el cálculo se completa igual y no da error, pero el dato no llega a los informes.';
                }
            }
        }
    }
}
