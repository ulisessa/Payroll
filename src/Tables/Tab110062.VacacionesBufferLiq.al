namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

/// <summary>
/// Buffer temporal del análisis de vacaciones: una fila por empleado con el cálculo del promedio
/// desarmado pieza por pieza.
/// </summary>
/// <remarks>
/// Temporal y sólo de la página, igual que [[Francos Buffer Liq.]]: no se guarda nada.
///
/// LAS COLUMNAS SON LOS PASOS DEL ART. 49, en orden, porque el valor de un día de vacaciones sale de
/// una cadena larga y cuando no cuadra hay que poder ver EN QUÉ ESLABÓN se rompe:
///
///     fase → ventana → meses → base → promedio mensual → /25 → valor del día
///
/// Cada una de esas puntas ya falló por separado durante la conciliación de enero de 2026: la
/// ventana se metía en la fase anterior, el divisor contaba meses que el numerador no sumaba, y la
/// base llegaba corta porque un aportante no entraba al acumulador. Un total por empleado escondía
/// las tres.
/// </remarks>
table 110062 "Vacaciones Buffer Liq."
{
    Caption = 'Vacaciones por Empleado';
    TableType = Temporary;
    DataClassification = CustomerContent;

    fields
    {
        field(1; "No. Empleado"; Code[20])
        {
            Caption = 'No. empleado';
            TableRelation = Employee;
        }
        field(2; "Nombre Empleado"; Text[100])
        {
            Caption = 'Nombre';
        }
        field(3; "Cód. Convenio"; Code[20])
        {
            Caption = 'Convenio';
        }
        field(4; "Cód. Categoría"; Code[20])
        {
            Caption = 'Categoría';
        }
        // Decide QUÉ NORMA se aplica, y por eso va a la vista: el art. 49 del CCT —181 días, uno
        // cada veinte— rige sólo para tripulantes; el personal de tierra va por LCT. Se deduce de
        // tener movimientos de franco, que es lo que distingue a un embarcado.
        field(5; Tripulante; Boolean)
        {
            Caption = 'Tripulante';
        }
        field(10; "Fecha Alta Fase"; Date)
        {
            Caption = 'Alta de la fase';
        }
        field(11; "Fecha Baja"; Date)
        {
            Caption = 'Baja';
        }
        field(12; "Días Prestación"; Integer)
        {
            Caption = 'Días de prestación';
        }
        field(20; "Ventana Desde"; Date)
        {
            Caption = 'Promedio desde';
        }
        field(21; "Ventana Hasta"; Date)
        {
            Caption = 'Promedio hasta';
        }
        // EL DIVISOR REAL DEL ART. 49, y son DÍAS, no meses: "el total así obtenido se dividirá por
        // la cantidad de períodos mensuales considerados", donde un período mensual son 30 días.
        // La cuenta es base / días * 30, y cierra al centavo contra PROM_6_ULT_MES de Meta4 en los
        // seis tripulantes dados de baja en enero de 2026.
        //
        // Contar MESES —que es lo que se hacía antes— hunde el promedio de quien entró o salió a
        // mitad de mes: ese mes aporta su fracción al numerador pero pesa un mes entero abajo.
        field(22; "Días Prestación Ventana"; Integer)
        {
            Caption = 'Días (divisor)';
        }
        field(23; "Meses con Dato"; Integer)
        {
            Caption = 'Meses con base';
        }
        field(24; "Ventana es Fracción"; Boolean)
        {
            Caption = 'Fracción';
        }
        field(30; "Base Acumulada"; Decimal)
        {
            Caption = 'Base del período';
            AutoFormatType = 1;
        }
        field(31; "Promedio Mensual"; Decimal)
        {
            Caption = 'Promedio mensual';
            AutoFormatType = 1;
        }
        field(32; "Valor Día"; Decimal)
        {
            Caption = 'Valor del día';
            AutoFormatType = 1;
        }
        field(40; "Días Art. 150"; Decimal)
        {
            Caption = 'Días por antigüedad';
            DecimalPlaces = 0 : 2;
        }
        field(41; "Días Proporcionales"; Decimal)
        {
            Caption = 'Días que corresponden';
            DecimalPlaces = 0 : 2;
        }
        field(42; "Días Gozados"; Decimal)
        {
            Caption = 'Días gozados';
            DecimalPlaces = 0 : 2;
        }
        field(43; "Días No Gozados"; Decimal)
        {
            Caption = 'Días no gozados';
            DecimalPlaces = 0 : 2;
        }
        field(50; "Importe No Gozadas"; Decimal)
        {
            Caption = 'Importe a pagar';
            AutoFormatType = 1;
        }
        // Lo que el motor liquidó de verdad, para contrastarlo con lo que esta vista calcula. Si no
        // coinciden, el que está mal es el concepto, no el análisis —o al revés—, y cuál de los dos
        // lo dice el resto de las columnas.
        field(51; "Liquidado 3973"; Decimal)
        {
            Caption = 'Liquidado (3973)';
            AutoFormatType = 1;
        }
        field(52; "Cód. Período"; Code[20])
        {
            Caption = 'Período';
        }
    }

    keys
    {
        key(PK; "No. Empleado")
        {
            Clustered = true;
        }
        key(Valor; "Valor Día") { }
    }
}
