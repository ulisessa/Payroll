namespace UAS.Payroll;

using Microsoft.HumanResources.Setup;
using Microsoft.Foundation.NoSeries;
using Microsoft.Projects.Project.Job;

tableextension 52001 "HR Setup Liq. Ext." extends "Human Resources Setup"
{
    fields
    {
        field(52010; "Cód. Serie Liq."; Code[20])
        {
            Caption = 'Serie Núm. Liquidaciones';
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
        }
        field(52011; "Cód. Serie Préstamos"; Code[20])
        {
            Caption = 'Serie Núm. Préstamos';
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
        }
        field(52012; "Proyecto Nómina"; Code[20])
        {
            Caption = 'Proyecto Nómina';
            DataClassification = CustomerContent;
            TableRelation = Job."No.";
            // Fallback inactivity project: used to park employees in an inactive state when their marea
            // project has no "Proyecto Inactividad Nómina" set.
        }
        field(52013; "Cód. Estado Alta Sinc."; Code[20])
        {
            Caption = 'Cód. Estado de Alta (Sinc. NAV)';
            DataClassification = CustomerContent;
            TableRelation = "Cód. Estado Empleado".Código WHERE("Tipo Estado" = CONST(Alta));
            // Con qué código se abre la fase de alta de un empleado que llega de NAV. Si queda en
            // blanco, la sincronización busca el único código activo de Tipo Estado = Alta; si hay
            // más de uno no adivina, y marca las altas en error hasta que se defina cuál va acá.
        }
        field(52014; "Máx. Intentos Sinc."; Integer)
        {
            Caption = 'Máx. Intentos (Sinc. NAV)';
            DataClassification = CustomerContent;
            InitValue = 5;
            MinValue = 0;
            // Cuántas corridas puede esperar una fila que depende de otra que todavía no llegó (una
            // línea de descarga sin su proyecto). Superado el límite pasa a Error, que es visible;
            // el objetivo es que nada se quede reintentando para siempre sin que nadie se entere.
        }

        field(52015; "Cód. Concepto Neto Garantizado"; Code[20])
        {
            Caption = 'Concepto Neto Garantizado (Grossing-up)';
            DataClassification = CustomerContent;
            TableRelation = "Concepto Liquidación".Código;
            // Qué concepto calcula el neto objetivo que el grossing-up tiene que alcanzar. Antes el
            // motor lo armaba solo: leía un parámetro NETO_GU y le sumaba el proporcional de
            // vacaciones con una Fuente de Datos DIAS_VAC_INICIO y el divisor 150 —el diferencial
            // del Art. 155 LCT entre pagar a /25 y a /30—. Eran tres nombres y una regla de negocio
            // a fuego en AL. Ahora la fórmula vive en un concepto, con su vigencia y su historial.
            // En blanco, el grossing-up no se aplica en ninguna liquidación.
        }
        field(52016; "Cód. Acum. Haberes Gravados"; Code[20])
        {
            Caption = 'Acumulador Haberes Gravados';
            DataClassification = CustomerContent;
            TableRelation = "Concepto Liquidación".Código WHERE("Es Acumulador" = CONST(true));
            // De qué acumulador sale el importe que se guarda en "Haberes Ordinarios Gravados" de la
            // liquidación. El motor tenía BASE_IG4 escrito en el código; renombrar ese acumulador
            // dejaba el campo en cero sin avisar. En blanco pasa lo mismo, pero al menos es una
            // decisión visible en la configuración.
            //
            // El NOMBRE va abreviado a propósito: "Cód. Acumulador Haberes Gravados" son 32
            // caracteres y el compilador avisa (AL0468) que pasar de 30 es propenso a errores de
            // SQL, con la advertencia anunciada como error futuro. La Caption queda completa, así
            // que en pantalla no cambia nada. No lo "arregles" volviendo al nombre largo.
        }
    }
}
