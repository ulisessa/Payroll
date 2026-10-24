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
        field(52017; "Convertir Param. por TC"; Boolean)
        {
            Caption = 'Convertir parámetros en divisa con su Variable TC';
            DataClassification = CustomerContent;
            // LA LLAVE DE PASO del cambio descrito en GROSSING_UP_Y_TC_CONFIGURABLES.md.
            //
            // Apagada —como nace— el motor se comporta igual que siempre: los parámetros en divisa
            // entran al contexto en divisa, las fórmulas los convierten con la bandera
            // {VARIABLE}_ESFCY, y el grossing-up usa el vendedor cableado.
            //
            // Encendida, cada parámetro con Moneda se convierte a pesos leyendo su
            // "Cód. Variable TC", y las fórmulas pasan a recibirlo ya convertido.
            //
            // ENCENDERLA SIN MIGRAR LAS FÓRMULAS MULTIPLICA DOS VECES. Las 4 fórmulas que todavía
            // usan _ESFCY tienen que cambiarse en el MISMO movimiento: sobre un parámetro ya
            // convertido, el IF vuelve a multiplicar por el TC. Por eso esto es un interruptor y no
            // una constante: si algo sale mal en producción se apaga sin publicar.
        }

        // LOS CINCO DEL GROSSING-UP. Los tres nombres de variable y las dos constantes estaban a
        // fuego en Cod50014, repartidos en dieciséis lugares, y en el catálogo de Cod50060.
        //
        // TODOS NACEN EN BLANCO Y EN BLANCO SIGNIFICA EL VALOR DE SIEMPRE. No se usa InitValue:
        // la fila de Config. RRHH ya existe, así que un InitValue no la tocaría y haría falta un
        // Upgrade para una cosa que el fallback resuelve sin riesgo. Ver CargarConfigGU.
        //
        // Lo que NO se puede configurar es el algoritmo: el bucle de convergencia no es una
        // fórmula sino una búsqueda de punto fijo sobre la liquidación entera, y el evaluador no
        // tiene bucles. Si alguna vez hace falta otro, es una interfaz en AL con dos
        // implementaciones. Acá sólo se decide CUÁL es el objetivo y DÓNDE cae el ajuste.
        field(52023; "Cód. Acum. Excl. Neto GU"; Code[20])
        {
            Caption = 'Acumulador excluido del neto del grossing-up';
            DataClassification = CustomerContent;
            TableRelation = "Concepto Liquidación".Código WHERE("Es Acumulador" = CONST(true));
            // QUÉ CONCEPTOS NO CUENTAN cuando el grossing-up mide si llegó al neto objetivo. En
            // blanco cuentan todos, que es como se comportaba antes.
            //
            // El caso que lo motivó es el anticipo de llegada. Es un descuento, así que baja el
            // neto, y la convergencia lo trata como algo a compensar: infla el bruto hasta que el
            // neto vuelve al objetivo. El resultado es que el empleado cobra el objetivo COMPLETO
            // más el anticipo que ya tenía en la mano. En el 04724 eso fueron 456.300 de bruto de
            // más para devolverle 250.000 que ya se le habían pagado.
            //
            // El anticipo es plata ya entregada, no algo que se deje de ganar: el objetivo del
            // grossing-up es lo que se GANA, y el anticipo sólo cambia cuándo se cobra.
            //
            // Va por acumulador y no por una bandera en cada concepto para que la lista entera se
            // vea en un solo lugar --las Fracciones del acumulador--, con las vigencias y los
            // porcentajes que esa maquinaria ya tiene. Mismo patrón que "Cód. Acum. Haberes
            // Gravados".
        }
        field(52024; "Motivos Baja Liq. Final"; Text[250])
        {
            Caption = 'Motivos de baja que generan Liquidación Final';
            DataClassification = CustomerContent;
            // QUÉ BAJAS DISPARAN LA LIQUIDACIÓN FINAL. Es una EXPRESIÓN DE FILTRO sobre el
            // "Cód. Motivo Baja" de la fase de alta, así que admite varios: BAJ-1|BAJ-2.
            // EN BLANCO CUENTA CUALQUIER BAJA, que es el comportamiento sin configurar.
            //
            // Hace falta porque no toda fecha de baja es una desvinculación. En enero de 2026 nueve
            // empleados tenían una, y Meta4 liquidó final --su Tipo Imputación 14-- a SIETE: los
            // siete BAJ-1. Los otros dos no: uno con BAJ-0 que se dio de alta otra vez el mismo mes
            // --una corrección, no una salida-- y otro con BAJ-12, que repite las mismas fechas
            // todos los años y parece un contrato de temporada. El motivo discrimina los nueve
            // casos sin un solo error; "no volvió en el mes" no, porque dejaría entrar al BAJ-12.
            //
            // No hay catálogo donde poner una bandera: "Grounds for Termination" está vacía y el
            // campo de la fase es un Code[20] libre. Por eso la lista vive acá, en la configuración,
            // y no se hardcodea un código de negocio en el motor.
        }
        field(52018; "Cód. Var. Es Grossing-Up"; Code[60])
        {
            Caption = 'Variable "Es Grossing-up"';
            DataClassification = CustomerContent;
            // SIN TableRelation a proposito: estas tres variables NO son filas de Variable Sistema
            // Liq., las inyecta el motor por codigo (ver el catalogo de Cod50060, seccion 1). Una
            // relacion a esa tabla daria una busqueda vacia y sugeriria que hay que sembrarlas.
            // Con qué nombre las fórmulas preguntan si esta liquidación converge. En blanco:
            // ES_GROSSING_UP.
        }
        field(52019; "Cód. Var. Neto Garantizado"; Code[60])
        {
            Caption = 'Variable "Neto Garantizado"';
            DataClassification = CustomerContent;
            // Con qué nombre llega el objetivo a las fórmulas. No confundir con "Cód. Concepto Neto
            // Garantizado", que es QUÉ CONCEPTO lo calcula: esto es el nombre de la variable donde
            // el motor deja el resultado. En blanco: NETO_GARANTIZADO.
        }
        field(52020; "Cód. Var. Complemento GU"; Code[60])
        {
            Caption = 'Variable "Complemento Grossing-up"';
            DataClassification = CustomerContent;
            // El ajuste que el bucle mueve. Lo paga cualquier concepto cuya fórmula lo nombre —hoy
            // el 1003, el 2003, el 3553 y el 4743—, así que renombrarlo obliga a cambiar esas
            // fórmulas en el mismo movimiento. En blanco: COMPLEMENTO_GU.
        }
        field(52021; "Máx. Iter. Grossing-Up"; Integer)
        {
            Caption = 'Máx. iteraciones del grossing-up';
            DataClassification = CustomerContent;
            MinValue = 0;
            // Cuántas vueltas antes de darse por vencido con un error. Veinte alcanzan para llegar
            // a un peso desde cualquier punto de partida; subirlo no arregla una liquidación que no
            // converge, sólo tarda más en decirlo. En blanco o cero: 20.
        }
        field(52022; "Tolerancia Grossing-Up"; Decimal)
        {
            Caption = 'Tolerancia del grossing-up';
            DataClassification = CustomerContent;
            MinValue = 0;
            // A qué distancia del objetivo se considera alcanzado, en pesos. En blanco o cero: 1.
            //
            // Bajarlo a centavos puede dejar liquidaciones sin converger por redondeos de los
            // conceptos intermedios, que no tienen por qué cerrar al centavo.
        }
    }
}
