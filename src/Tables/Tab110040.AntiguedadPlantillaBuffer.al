namespace UAS.Payroll;

// Una fila por legajo con su antigüedad ya resuelta. Siempre temporal.
//
// No guarda nada: es la misma cuenta que hace el motor, hecha para toda la plantilla de una vez. La
// diferencia con mirar legajo por legajo no es de comodidad — es que los problemas de antigüedad no
// se ven de a uno. Un empleado con la antigüedad en cero porque nunca se le cargó un alta parece
// normal en su ficha; en una lista de mil, ordenada por avisos, salta a la primera.
table 110040 "Antigüedad Plantilla Buffer"
{
    Caption = 'Antigüedad de la Plantilla';
    DataClassification = CustomerContent;
    TableType = Temporary;

    fields
    {
        field(1; "No. Empleado"; Code[20])
        {
            Caption = 'Cód. Legajo';
            DataClassification = CustomerContent;
        }
        field(2; "Nombre Empleado"; Text[100])
        {
            Caption = 'Nombre';
            DataClassification = CustomerContent;
        }
        field(10; "Fecha Primer Alta"; Date)
        {
            Caption = 'Primer Alta';
            DataClassification = CustomerContent;
            // La más vieja de todas. No es la que manda para la antigüedad cuando hubo bajas en el
            // medio: los tramos sin relación laboral no cuentan.
        }
        field(11; "Fecha Última Alta"; Date)
        {
            Caption = 'Última Alta';
            DataClassification = CustomerContent;
        }
        field(12; "Fecha Última Baja"; Date)
        {
            Caption = 'Última Baja';
            DataClassification = CustomerContent;
        }
        field(13; "De Alta"; Boolean)
        {
            Caption = 'De Alta';
            DataClassification = CustomerContent;
            // La última fase quedó abierta a la fecha de referencia.
        }
        field(14; "Estado Vigente"; Code[20])
        {
            Caption = 'Estado Vigente';
            DataClassification = CustomerContent;
            // El que rige a la fecha de referencia. Es de donde sale 'De Alta', y tenerlo a la vista
            // ahorra la pregunta de por qué un legajo quedó fuera del filtro.
        }
        field(15; "Descripción Estado"; Text[100])
        {
            Caption = 'Descripción Estado';
            DataClassification = CustomerContent;
        }
        field(20; Fases; Integer)
        {
            Caption = 'Fases';
            DataClassification = CustomerContent;
        }
        field(21; "Días Totales"; Integer)
        {
            Caption = 'Días Totales';
            DataClassification = CustomerContent;
            // Suma de los días de las fases. Es informativo: no incluye la Antigüedad Reconocida,
            // que sí entra en los años. Si los años no cierran con estos días, es por eso.
        }
        field(30; "Años Completos"; Decimal)
        {
            Caption = 'Años Completos';
            DataClassification = CustomerContent;
        }
        field(31; "Antigüedad (años)"; Decimal)
        {
            Caption = 'Antigüedad (años)';
            DataClassification = CustomerContent;
            // La fraccionaria, con un decimal: la que usan las fórmulas que prorratean.
        }
        field(32; "Años al 30/06"; Decimal)
        {
            Caption = 'Años al 30/06';
            DataClassification = CustomerContent;
            // La del corte del Art. 32, que es la que efectivamente se paga durante todo el año.
            // Cuando difiere de "Años Completos", el tripulante ya cumplió otro año pero todavía no
            // se le paga: es la diferencia que explica casi todos los reclamos.
        }
        field(33; "Antigüedad Reconocida"; Decimal)
        {
            Caption = 'Antig. Reconocida';
            DataClassification = CustomerContent;
        }
        field(40; Avisos; Integer)
        {
            Caption = 'Avisos';
            DataClassification = CustomerContent;
        }
        field(41; Aviso; Text[250])
        {
            Caption = 'Aviso';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "No. Empleado") { Clustered = true; }
        // Para ordenar por lo que interesa mirar: primero los problemas, después los más antiguos.
        key(PorAviso; Avisos, "No. Empleado") { }
        key(PorAntiguedad; "Días Totales") { }
        key(PorNombre; "Nombre Empleado") { }
    }
}
