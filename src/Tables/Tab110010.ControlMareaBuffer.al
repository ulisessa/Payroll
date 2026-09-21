namespace UAS.Payroll;

// Buffer del control de liquidación por marea. Siempre temporal: no se persiste nada.
//
// Lleva las DOS secciones del informe en una sola tabla, distinguidas por "Sección": el resumen por
// concepto de toda la tripulación y el detalle empleado por empleado. Son la misma forma de fila
// —concepto, cantidad, importe— y separarlas en dos tablas habría duplicado la estructura para
// ahorrar un campo.
table 110010 "Control Marea Buffer"
{
    Caption = 'Control de Liquidación por Marea';
    DataClassification = CustomerContent;
    TableType = Temporary;

    fields
    {
        field(1; Sección; Option)
        {
            Caption = 'Sección';
            OptionMembers = Resumen,Detalle,Diferencia,Tripulante;
            OptionCaption = 'Resumen,Detalle,Diferencia,Tripulante';
            // "Tripulante" son las FILAS de la matriz: una por persona. Las arma la propia página en
            // su tabla temporal, no el codeunit — son una forma de presentar el detalle, no un dato
            // más que haya que calcular.
            DataClassification = CustomerContent;
        }
        field(2; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            DataClassification = CustomerContent;
            // Vacío en las filas de resumen.
        }
        field(3; "Orden Cálculo"; Integer)
        {
            Caption = 'Orden Cálculo';
            DataClassification = CustomerContent;
        }
        field(4; "Cód. Concepto"; Code[20])
        {
            Caption = 'Cód. Concepto';
            DataClassification = CustomerContent;
        }
        field(5; "No. Línea"; Integer)
        {
            Caption = 'No. Línea';
            DataClassification = CustomerContent;
            // Un concepto puede dar VARIAS líneas al mismo empleado —el consumo de francos se abre
            // en una por categoría de lote—, así que sin esto la segunda pisaría a la primera.
        }
        field(6; "Nombre Empleado"; Text[100])
        {
            Caption = 'Empleado';
            DataClassification = CustomerContent;
        }
        field(7; "Nombre Impresión"; Text[50])
        {
            Caption = 'Concepto';
            DataClassification = CustomerContent;
        }
        field(8; "Tipo Concepto"; Enum "Tipo Concepto Liq.")
        {
            Caption = 'Tipo';
            DataClassification = CustomerContent;
        }
        field(9; Cantidad; Decimal)
        {
            Caption = 'Cantidad';
            DecimalPlaces = 0 : 5;
            DataClassification = CustomerContent;
        }
        field(10; "Unidad Cantidad"; Text[10])
        {
            Caption = 'Unidad';
            DataClassification = CustomerContent;
        }
        field(11; "Base Cálculo"; Decimal)
        {
            Caption = 'Base Cálculo';
            DecimalPlaces = 2 : 2;
            DataClassification = CustomerContent;
        }
        field(12; Importe; Decimal)
        {
            Caption = 'Importe';
            DecimalPlaces = 2 : 2;
            DataClassification = CustomerContent;
        }
        field(13; Empleados; Integer)
        {
            Caption = 'Empleados';
            DataClassification = CustomerContent;
            // Solo en el resumen: a cuántos tripulantes les salió este concepto. Un concepto que
            // aparece en 23 de 24 es la clase de cosa que este informe existe para mostrar.
        }
        field(14; "No. Liquidación"; Code[20])
        {
            Caption = 'No. Liquidación';
            DataClassification = CustomerContent;
        }
        field(15; "Cód. Convenio"; Code[20])
        {
            Caption = 'Convenio';
            DataClassification = CustomerContent;
        }
        field(16; "Cód. Categoría"; Code[20])
        {
            Caption = 'Categoría';
            DataClassification = CustomerContent;
        }
        field(18; "Convenio Empleado"; Code[20])
        {
            Caption = 'Convenio del empleado';
            DataClassification = CustomerContent;
            // El par de la CABECERA de la liquidación: el encuadre del tripulante. Los campos 15/16
            // llevan el de la línea, que en los conceptos liquidados por la asignación a la marea es
            // otro. Filtrar por categoría tiene que dejar afuera al tripulante entero, no a algunas
            // de sus líneas, así que la columna que filtra es ésta y no aquélla.
        }
        field(19; "Categoría Empleado"; Code[20])
        {
            Caption = 'Categoría del empleado';
            DataClassification = CustomerContent;
        }
        field(17; "Imprime en Recibo"; Boolean)
        {
            Caption = 'Imprime en Recibo';
            DataClassification = CustomerContent;
            // Lo que no imprime son las contribuciones patronales y los acumuladores: números
            // correctos que no forman parte de lo que el tripulante cobra, y que en una matriz de
            // control se llevan filas sin aportar nada que controlar.
        }
        field(22; "Fecha Alta"; Date)
        {
            Caption = 'Alta';
            DataClassification = EndUserIdentifiableInformation;
            // Solo en las filas de tripulante: la antigüedad explica media planilla —adicional por
            // antigüedad, días de vacaciones— y tenerla al lado evita ir a la ficha por cada duda.
        }
        field(20; "Importe Habitual"; Decimal)
        {
            Caption = 'Su categoría';
            DecimalPlaces = 2 : 2;
            DataClassification = CustomerContent;
            // Solo en la sección Diferencia: lo que cobró la MAYORÍA de la categoría del empleado por
            // ese concepto. Es contra este número que se mide el apartamiento, y no contra un
            // tripulante elegido de representante — si el representante fuera justo el distinto, todos
            // los demás aparecerían como diferencia y el caso real quedaría escondido.
        }
        field(21; Diferencia; Decimal)
        {
            Caption = 'Diferencia';
            DecimalPlaces = 2 : 2;
            DataClassification = CustomerContent;
            // Importe - "Importe Habitual". Se guarda calculada para poder ordenar por ella.
        }
    }

    keys
    {
        key(PK; Sección, "No. Empleado", "Orden Cálculo", "Cód. Concepto", "No. Línea") { Clustered = true; }
        // Para ordenar las diferencias por tamaño haciendo clic en la columna.
        key(Dif; Sección, Diferencia) { }
        // El resumen se lee por orden de cálculo, que es el orden en que el motor los liquidó y el
        // mismo en el que aparecen en el recibo.
        key(Orden; Sección, "Orden Cálculo", "Cód. Concepto") { }
        // Para que el usuario pueda ordenar la matriz por código de concepto haciendo clic en la
        // columna: el cliente solo ofrece ordenar por campos que estén en alguna clave.
        key(Concepto; Sección, "Cód. Concepto", "Orden Cálculo") { }
    }
}
