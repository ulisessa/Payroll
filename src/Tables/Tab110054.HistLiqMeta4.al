namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

// Una liquidación de Meta4, tal como quedó registrada. Es la cabecera de un ARCHIVO LITERAL: no se
// interpreta, no se mapea a conceptos de BC y no lo lee el motor de cálculo. Está para poder abrir un
// recibo de 2003 cuando ANSES pide una certificación de servicios o cuando llega una demanda, y para
// que Meta4 se pueda apagar.
//
// LA HISTORIA QUE BC CALCULA ES OTRA COSA Y VIVE EN "Liquidación" + "Línea Liquidación". Las Fuentes
// de Datos y el recibo sólo leen esas dos tablas; nada de acá alimenta un promedio ni una antigüedad.
// Mezclar las dos cosas en una sola estructura fue la primera idea y es la que hay que evitar: una
// necesita los bytes originales sin tocar, la otra necesita códigos de concepto de BC.
//
// POR QUÉ NO SE REPLICAN LAS CINCO TABLAS DE META4. M4T_ACUMULADO_RL hasta RL5 comparten exactamente
// la misma clave primaria: no son cinco entidades, son UNA fila partida en cinco porque Oracle no
// admite más de 1.000 columnas. Sumadas dan 1.818 columnas, y eso no entra en SQL Server de ninguna
// forma — el límite duro es 1.024 columnas por tabla, y 1.818 decimales de BC son ~31 KB por fila
// contra un máximo de 8.060 bytes. No es una cuestión de gusto: la forma ancha no se puede construir.
//
// Y aunque entrara, no convendría: medida sobre los datos reales, una fila tiene ~250 valores no
// nulos de 1.759 columnas numéricas. El 86% de la forma ancha son ceros.
table 110054 "Hist. Liq. Meta4"
{
    Caption = 'Historia de Liquidaciones Meta4';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "No. Entrada"; Integer)
        {
            Caption = 'No. Entrada';
            DataClassification = CustomerContent;
            AutoIncrement = true;
            // Sustituto entero de la clave natural de Meta4, que son cinco campos. El detalle tiene
            // ~117 millones de filas: arrastrarle los cinco campos costaría del orden de 5 GB sólo
            // en repetir la clave.
        }
        field(2; "Cód. Sociedad"; Code[10])
        {
            Caption = 'Sociedad';
            DataClassification = CustomerContent;
            // ID_SOCIEDAD
        }
        field(3; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            DataClassification = CustomerContent;
            TableRelation = Employee;
            ValidateTableRelation = false;
            // ID_EMPLEADO. Los legajos de Meta4 y los de BC coinciden, pero la relación NO se valida:
            // hay 31 años de historia y gente que ya no está en el padrón de BC. Un archivo que
            // rechaza filas porque el empleado se dio de baja no sirve como archivo.
        }
        field(4; "Fecha Alta Empleado"; Date)
        {
            Caption = 'Fecha Alta Empleado';
            DataClassification = CustomerContent;
            // FEC_ALTA_EMPLEADO. Es parte de la clave en Meta4, no un dato de la ficha: un reingreso
            // genera otra alta y por lo tanto otra serie de liquidaciones.
        }
        field(5; "Fecha Imputación"; Date)
        {
            Caption = 'Fecha Imputación';
            DataClassification = CustomerContent;
            // FEC_IMPUTACION. El mes al que pertenece la liquidación.
        }
        field(6; "Fecha Pago"; Date)
        {
            Caption = 'Fecha Pago';
            DataClassification = CustomerContent;
            // FEC_PAGO. Distingue corridas dentro del mismo mes.
        }
        field(7; "Tipo Imputación"; Integer)
        {
            Caption = 'Tipo Imputación';
            DataClassification = CustomerContent;
            // TP_IMPUT. Se guarda el número crudo, sin traducir: 4 = anticipos, 99 = indemnizaciones
            // puras, 14 = liquidaciones finales, 3 = vacaciones, 1 = la corrida más frecuente. El
            // significado se dedujo perfilando qué columnas trae cada uno en no-cero, no de una tabla
            // de dominio — Meta4 no expone ninguna. Traducirlo acá sería inventar.
        }
        field(8; "Contador Liq."; Integer)
        {
            Caption = 'Contador Liquidación';
            DataClassification = CustomerContent;
            // CONTADOR_LIQ. ES EL ORDEN REAL DE LAS CORRIDAS, y no coincide con la fecha: el legajo
            // 03774 en enero 2026 tiene la corrida del día 19 con contador 6 y la del día 6 con
            // contador 7. Cualquier lectura que dependa del orden tiene que usar este campo.
        }
        field(9; "Cód. Convenio Meta4"; Code[10])
        {
            Caption = 'Convenio (Meta4)';
            DataClassification = CustomerContent;
            // ID_CONVENIO con los códigos de Meta4 (MR, OF, FA, CA, FE, EC), NO los de BC (175/75,
            // 729/15). Sin traducir, a propósito: es un archivo literal.
        }
        field(10; "Cód. Empresa Meta4"; Code[10])
        {
            Caption = 'Empresa (Meta4)';
            DataClassification = CustomerContent;
        }
        field(11; Año; Integer)
        {
            Caption = 'Año';
            DataClassification = CustomerContent;
            // Derivados de "Fecha Imputación" y guardados. Se podrían calcular, pero sobre 485.000
            // filas un filtro por año es la consulta más frecuente y con el campo guardado usa índice.
        }
        field(12; Mes; Integer)
        {
            Caption = 'Mes';
            DataClassification = CustomerContent;
        }
        field(15; "Cód. Buque Meta4"; Code[10])
        {
            Caption = 'Buque (Meta4)';
            DataClassification = CustomerContent;
            // ID_BUQUE de M4T_ACUMULADO_RL3, con el código de Meta4 (A28, HF801), no el de BC.
        }
        field(16; "No. Marea Meta4"; Integer)
        {
            Caption = 'Marea (Meta4)';
            DataClassification = CustomerContent;
            // ID_MAREA de M4T_ACUMULADO_RL3. ES LA MAREA QUE ESTA CORRIDA PAGA, no la que el
            // tripulante tiene en curso — pero eso SOLO se ve fila por fila.
            //
            // Agregado por mes engaña: un tripulante con cuatro corridas en enero tiene tres mareas
            // distintas (la 58 en la corrida de puerto, la 59 en el cierre, la 60 en la mensual), y
            // tomar el máximo o la última da la que no es. Yo mismo concluí que el campo no servía
            // justamente por haberlo mirado agregado.
            //
            // Fila por fila es exacto y es lo que permite comparar marea contra marea: el cierre de
            // marea de BC se enfrenta a la corrida de Meta4 que lleva ESE número de marea.
        }
        field(13; "Apellido Empleado"; Text[50])
        {
            Caption = 'Apellido';
            FieldClass = FlowField;
            CalcFormula = lookup(Employee."Last Name" where("No." = field("No. Empleado")));
            Editable = false;
            // FlowFields y no campos guardados: el nombre es del padrón ACTUAL, no un dato histórico.
            // Quedan vacíos para quien ya no está en BC, que es lo correcto — el archivo no debería
            // afirmar un nombre que no puede verificar.
            //
            // Van separados porque Employee no tiene un campo "Full Name" en esta versión (tiene el
            // método FullName(), que un FlowField no puede llamar) y un FlowField no concatena.
        }
        field(14; "Nombre Empleado"; Text[50])
        {
            Caption = 'Nombre';
            FieldClass = FlowField;
            CalcFormula = lookup(Employee."First Name" where("No." = field("No. Empleado")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "No. Entrada") { Clustered = true; }
        key(PorEmpleado; "No. Empleado", "Fecha Imputación", "Fecha Pago") { }
        key(PorFecha; "Fecha Imputación") { }
        key(PorAnio; Año, Mes) { }
        key(PorMarea; "Cód. Buque Meta4", "No. Marea Meta4") { }
        // El orden de las corridas dentro del mes. Lo necesita el comparador: TOT_REMUN_27617 es un
        // acumulado corrido, asi que el aporte de cada corrida es su valor menos el de la anterior
        // POR CONTADOR. Sin este orden la diferencia se calcula contra la corrida equivocada.
        key(PorEmpMes; "No. Empleado", Año, Mes, "Contador Liq.") { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "No. Empleado", "Fecha Imputación", "Tipo Imputación") { }
    }
}
