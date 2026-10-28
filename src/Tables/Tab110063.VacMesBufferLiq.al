namespace UAS.Payroll;

/// <summary>
/// Buffer temporal del detalle mes a mes de la ventana del promedio de vacaciones: qué aportó cada
/// mes y si cuenta en el divisor.
/// </summary>
/// <remarks>
/// Es el equivalente de [[Lote Franco Buffer Liq.]] para vacaciones: el resumen dice que el promedio
/// quedó corto, y esta vista dice QUÉ MES lo hundió.
///
/// LAS DOS COLUMNAS QUE IMPORTAN SON "Cuenta en el Divisor" Y "Base". Un mes puede:
///   - contar en el divisor y aportar base  → el caso normal;
///   - contar en el divisor y NO aportar    → hunde el promedio, y es el síntoma de una historia
///     con huecos o de un mes que no debería estar en la ventana;
///   - aportar MENOS de lo que corresponde  → el mes del ingreso o del egreso, trabajado a medias,
///     que entra entero al numerador pero vale un mes completo en el divisor.
///
/// El último caso es el que desparramó los ratios en enero de 2026: a un tripulante que entró el 25
/// de noviembre, ese mes le aportaba una fracción y le sumaba un mes entero al divisor.
/// </remarks>
table 110063 "Vac. Mes Buffer Liq."
{
    Caption = 'Meses del promedio';
    TableType = Temporary;
    DataClassification = CustomerContent;

    fields
    {
        field(1; "No. Empleado"; Code[20])
        {
            Caption = 'No. empleado';
        }
        field(2; "No. Línea"; Integer)
        {
            Caption = 'No. línea';
        }
        field(3; "Cód. Período"; Code[20])
        {
            Caption = 'Período';
        }
        field(4; "Mes Desde"; Date)
        {
            Caption = 'Desde';
        }
        field(5; "Mes Hasta"; Date)
        {
            Caption = 'Hasta';
        }
        field(10; Base; Decimal)
        {
            Caption = 'Base del mes';
            AutoFormatType = 1;
        }
        field(11; "Cuenta en el Divisor"; Boolean)
        {
            Caption = 'Cuenta';
        }
        // Días que la fase cubre DENTRO del mes. Si son menos que los del mes, es un mes parcial:
        // aporta una fracción al numerador pero pesa un mes entero en el divisor.
        field(12; "Días Cubiertos"; Integer)
        {
            Caption = 'Días con alta';
        }
        field(13; "Días del Mes"; Integer)
        {
            Caption = 'Días del mes';
        }
        field(14; Completo; Boolean)
        {
            Caption = 'Mes completo';
        }
        field(15; Observación; Text[120])
        {
            Caption = 'Observación';
        }
    }

    keys
    {
        key(PK; "No. Empleado", "No. Línea")
        {
            Clustered = true;
        }
    }
}
