namespace UAS.Payroll;

// Buffer de la comparación entre lo que liquidó Meta4 y lo que calcula BC, por empleado y mes.
//
// ES TEMPORAL Y NO SE GUARDA: se arma en memoria cada vez que se abre la página. Un contraste
// contra un archivo de 116 millones de filas tiene que leer el archivo en el momento; guardar el
// resultado sería guardar una foto que envejece en cuanto alguien recalcula una liquidación.
//
// POR QUÉ ESTO NO ES UNA MIGRACIÓN. 2026 se conserva como REFERENCIA, no como insumo: Meta4 siguió
// siendo el sistema de producción de enero a julio de 2026, y BC corrió en paralelo. Cargar esos
// meses como historia —igual que se hizo con 2025— haría que alimenten los acumuladores, y
// entonces el mes contaría dos veces en cuanto alguien apruebe las liquidaciones que BC ya tiene
// calculadas. Por eso los conceptos HIST_* vencen el 31/12/2025 y acá no se escribe nada.
table 110057 "Comp. Meta4 Buffer"
{
    Caption = 'Comparación BC contra Meta4';
    DataClassification = CustomerContent;
    TableType = Temporary;

    fields
    {
        field(1; "No. Empleado"; Code[20]) { Caption = 'No. Empleado'; DataClassification = CustomerContent; }
        field(2; Año; Integer) { Caption = 'Año'; DataClassification = CustomerContent; }
        field(3; Mes; Integer) { Caption = 'Mes'; DataClassification = CustomerContent; }
        field(4; Apellido; Text[50]) { Caption = 'Apellido'; DataClassification = CustomerContent; }
        field(5; Nombre; Text[50]) { Caption = 'Nombre'; DataClassification = CustomerContent; }
        field(6; "Importe Meta4"; Decimal)
        {
            Caption = 'Bruto Meta4';
            DataClassification = CustomerContent;
            // TOT_REMUN_27617. Es un ACUMULADOR CORRIDO DENTRO DEL MES —cada corrida guarda el total
            // hasta ella—, así que lo que aportó cada corrida es su valor menos el de la anterior.
            // Sumar los valores en crudo triplica un mes de tres corridas.
            //
            // LAS OTRAS DOS COLUMNAS DE META4 NO SE COMPORTAN ASÍ, y conviene tenerlo presente
            // porque viven en la misma tabla: TOT_RETEN y LIQUIDO son POR CORRIDA. Verificado en el
            // legajo 03664 de enero de 2026, donde TOT_REMUN_27617 va 250.000 → 37.034.483,70 →
            // 38.227.779,31 → 39.642.779,68 mientras TOT_DEVENGO da 250.000 / 37.034.484,31 /
            // 1.193.295,37 / 1.415.000,40, que son justamente las diferencias.
        }
        field(7; "Importe BC"; Decimal)
        {
            Caption = 'Bruto BC';
            DataClassification = CustomerContent;
            // El acumulador REMUNERATIVO_BRUTO de las liquidaciones que calculó el motor. Se suma
            // porque un empleado puede tener varias liquidaciones en el mes (regular, marea, SAC) y
            // cada una lleva su propia línea de acumulador.
        }
        field(8; Diferencia; Decimal) { Caption = 'Dif. Bruto'; DataClassification = CustomerContent; }
        field(9; "% Diferencia"; Decimal) { Caption = '% Dif.'; DataClassification = CustomerContent; DecimalPlaces = 2 : 2; }

        // ── descuentos y neto ────────────────────────────────────────────────
        // TRES COMPARACIONES Y NO UNA, porque un bruto que coincide no garantiza un neto que
        // coincida: el bruto sale de los haberes y el neto además de las retenciones, que tienen sus
        // propios topes y escalas. Una liquidación puede cerrar perfecto arriba y estar mal abajo.
        //
        // Del lado de Meta4 los dos salen de columnas POR CORRIDA —TOT_RETEN y LIQUIDO—, así que se
        // suman las corridas de la marea sin restar nada, al revés del bruto.
        //
        // Del lado de BC salen de la CABECERA de la liquidación, no de las líneas: "Total Descuentos"
        // y "Neto a Pagar". Sumar líneas por tipo de concepto daría casi lo mismo pero no igual, y
        // lo que se quiere comparar es lo que el recibo dice que se le paga a la persona.
        field(12; "Descuentos Meta4"; Decimal)
        {
            Caption = 'Descuentos Meta4';
            DataClassification = CustomerContent;
            // TOT_RETEN. NO incluye contribuciones patronales, igual que "Total Descuentos" de BC:
            // las dos son lo que se le retiene al empleado.
        }
        field(13; "Descuentos BC"; Decimal) { Caption = 'Descuentos BC'; DataClassification = CustomerContent; }
        field(14; "Dif. Descuentos"; Decimal)
        {
            Caption = 'Dif. Descuentos';
            DataClassification = CustomerContent;
            // BC menos Meta4, igual que arriba. OJO CON EL SIGNO AL LEERLO: acá un positivo es BC
            // reteniendo DE MÁS, que baja el neto. En el bruto un positivo lo sube.
        }
        field(15; "Neto Meta4"; Decimal)
        {
            Caption = 'Neto Meta4';
            DataClassification = CustomerContent;
            // LIQUIDO, el líquido a cobrar de la corrida.
        }
        field(16; "Neto BC"; Decimal) { Caption = 'Neto BC'; DataClassification = CustomerContent; }
        field(17; "Dif. Neto"; Decimal) { Caption = 'Dif. Neto'; DataClassification = CustomerContent; }
        field(10; "Liq. en BC"; Integer)
        {
            Caption = 'Liq. BC';
            DataClassification = CustomerContent;
            // Cuántas liquidaciones de BC entraron en el importe. Un cero con Meta4 distinto de cero
            // es el caso que más interesa: el mes que BC todavía no calculó.
        }
        field(11; "Hay Borrador"; Boolean)
        {
            Caption = 'Con borrador';
            DataClassification = CustomerContent;
            // Un borrador entra en esta comparación pero NO en los acumuladores del motor, que
            // filtran Estado <> Borrador. Sin esta marca, una diferencia de cero acá puede convivir
            // con un YTD en cero allá, y no se entiende por qué.
        }
    }

    keys
    {
        key(PK; "No. Empleado", Año, Mes) { Clustered = true; }
        key(PorDiferencia; Diferencia) { }
    }
}
