namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

/// <summary>
/// Una fila por empleado con el reparto de sus días del rango entre estados, y cuántos quedaron sin
/// liquidar. Siempre temporal: no se persiste nada.
/// </summary>
/// <remarks>
/// Las columnas de días por estado no están acá: son dinámicas —una por cada Cód. Estado que aparezca
/// en el rango— y las arma la página con el patrón de matriz. Acá van los totales de la fila, que son
/// los que se leen de un vistazo: si los días con estado no llegan a los días del rango, a esa persona
/// le falta liquidar.
/// </remarks>
table 110013 "Cobertura Liq. Buffer"
{
    Caption = 'Control de Días Liquidados';
    DataClassification = CustomerContent;
    TableType = Temporary;

    fields
    {
        field(1; "No. Empleado"; Code[20])
        {
            Caption = 'Legajo';
            DataClassification = EndUserIdentifiableInformation;
            TableRelation = Employee."No.";
        }
        field(2; "Nombre Empleado"; Text[100])
        {
            Caption = 'Apellido y Nombre';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(3; "Fecha Alta"; Date)
        {
            Caption = 'Alta';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(4; "Fecha Baja"; Date)
        {
            Caption = 'Baja';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(5; "Cód. Convenio"; Code[20])
        {
            Caption = 'Convenio';
            DataClassification = CustomerContent;
        }
        field(6; "Cód. Categoría"; Code[20])
        {
            Caption = 'Categoría';
            DataClassification = CustomerContent;
        }
        field(7; "Días del Rango"; Integer)
        {
            Caption = 'Días del Rango';
            DataClassification = CustomerContent;
            // Los días del rango en que la persona estuvo de alta. No es el largo del rango: quien
            // entró el 15 debe medio mes, y medirlo contra el mes entero lo marcaría en falta.
        }
        field(8; "Días con Estado"; Integer)
        {
            Caption = 'Días con Estado';
            DataClassification = CustomerContent;
            // La suma de las columnas de estado. Menor que "Días del Rango" significa días en los que
            // la persona estaba de alta y no tenía ningún estado: un agujero en el historial, que es
            // un problema distinto —y anterior— al de la liquidación.
        }
        field(9; "Días Liquidados"; Integer)
        {
            Caption = 'Días Liquidados';
            DataClassification = CustomerContent;
        }
        field(10; "Días sin Liquidar"; Integer)
        {
            Caption = 'Sin Liquidar';
            DataClassification = CustomerContent;
            // Días con estado que ninguna liquidación cubre. Es el número que se mira.
        }
        field(11; "Tramos sin Liquidar"; Integer)
        {
            Caption = 'Tramos';
            DataClassification = CustomerContent;
            // En cuántos pedazos sueltos caen esos días. Uno solo al final del mes es un olvido
            // simple; tres desperdigados suele ser el historial de estados mal cargado.
        }
        field(13; "Días en Borrador"; Integer)
        {
            Caption = 'En Borrador';
            DataClassification = CustomerContent;
            // De los días sin liquidar, cuántos SÍ tienen una liquidación creada pero todavía en
            // borrador. Es el mismo faltante con otra solución: no hay que crear nada, hay que
            // calcular lo que ya está. Sin esta columna los dos casos se ven iguales.
        }
        field(12; "Detalle Sin Liquidar"; Text[250])
        {
            Caption = 'Detalle';
            DataClassification = CustomerContent;
            // Los tramos en texto ("21/07..31/07 ORDENES"), para poder leerlos sin abrir nada y para
            // que bajen con el "Abrir en Excel" de la grilla.
        }
    }

    keys
    {
        key(PK; "No. Empleado") { Clustered = true; }
        key(SinLiquidar; "Días sin Liquidar") { }
        key(Nombre; "Nombre Empleado") { }
    }
}
