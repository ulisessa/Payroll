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
                field("Cód. Acum. Excl. Neto GU"; Rec."Cód. Acum. Excl. Neto GU")
                {
                    ApplicationArea = All;
                    ToolTip = 'Acumulador que junta los conceptos que NO deben pesar cuando el grossing-up mide si alcanzó el neto objetivo. El caso típico es el anticipo de llegada: como es un descuento baja el neto, y sin esto la convergencia lo compensa inflando el bruto, de modo que el empleado cobra el objetivo completo MÁS el anticipo que ya tenía. Qué conceptos entran se define en las Fracciones de ese acumulador. En blanco cuentan todos.';
                }
                field("Convertir Param. por TC"; Rec."Convertir Param. por TC")
                {
                    ApplicationArea = All;
                    ToolTip = 'Encendida, cada parámetro que declara una moneda se convierte a pesos al armar el contexto, leyendo la "Variable Tipo de Cambio" de su fila de valor, y las fórmulas lo reciben ya convertido. Apagada, los parámetros llegan en divisa y cada fórmula decide si convierte. Es una llave de paso: apagarla vuelve al comportamiento anterior sin publicar. No la enciendas sin haber migrado las fórmulas que multiplican por un tipo de cambio, porque sobre un parámetro ya convertido volverían a multiplicar.';
                }
            }
            group(GrossingUpLiq)
            {
                Caption = 'Grossing-up';

                // Los cinco nacen en blanco y en blanco significa el valor de siempre, así que
                // esta pestaña se puede dejar vacía para siempre. Está para los casos en que haya
                // que convivir con nombres distintos, no para cargarla.
                field("Cód. Var. Es Grossing-Up"; Rec."Cód. Var. Es Grossing-Up")
                {
                    ApplicationArea = All;
                    ToolTip = 'Nombre con el que las fórmulas preguntan si esta liquidación converge por grossing-up. En blanco el motor usa ES_GROSSING_UP, que es lo que usan las fórmulas actuales.';
                }
                field("Cód. Var. Neto Garantizado"; Rec."Cód. Var. Neto Garantizado")
                {
                    ApplicationArea = All;
                    ToolTip = 'Nombre de la variable donde el motor deja el neto objetivo. No confundir con "Concepto Neto Garantizado", que es qué concepto lo calcula. En blanco el motor usa NETO_GARANTIZADO.';
                }
                field("Cód. Var. Complemento GU"; Rec."Cód. Var. Complemento GU")
                {
                    ApplicationArea = All;
                    ToolTip = 'Nombre del ajuste que el bucle mueve hasta alcanzar el objetivo. Lo paga cualquier concepto cuya fórmula lo nombre, así que renombrarlo obliga a cambiar esas fórmulas en el mismo movimiento o el complemento deja de pagarse. En blanco el motor usa COMPLEMENTO_GU.';
                }
                field("Máx. Iter. Grossing-Up"; Rec."Máx. Iter. Grossing-Up")
                {
                    ApplicationArea = All;
                    // Un cero significa "sin cargar", no "cero iteraciones". Mostrarlo en blanco es
                    // la unica forma de que la pantalla cuente la misma historia que el fallback.
                    BlankZero = true;
                    ToolTip = 'Cuántas vueltas intenta el cálculo antes de detenerse con un error. En blanco o cero son 20, que alcanzan para llegar a la tolerancia desde cualquier punto de partida. Subirlo no arregla una liquidación que no converge: sólo tarda más en avisar.';
                }
                field("Tolerancia Grossing-Up"; Rec."Tolerancia Grossing-Up")
                {
                    ApplicationArea = All;
                    BlankZero = true;
                    ToolTip = 'A qué distancia del objetivo, en pesos, se considera alcanzado el neto. En blanco o cero es 1. Bajarlo a centavos puede dejar liquidaciones sin converger por los redondeos de los conceptos intermedios, que no tienen por qué cerrar al centavo.';
                }
            }
        }
    }
}
