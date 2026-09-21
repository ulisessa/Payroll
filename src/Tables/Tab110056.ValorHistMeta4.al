namespace UAS.Payroll;

// Un valor de una liquidación de Meta4. Forma angosta: una fila por cada columna QUE TENÍA DATO.
//
// ES LA TABLA MÁS GRANDE DEL SISTEMA POR VARIOS ÓRDENES DE MAGNITUD: ~117 millones de filas para los
// 31 años (97,6 millones de valores numéricos y 19,1 de texto y fecha), contra 485.000 cabeceras.
// Cualquier campo que se le agregue se multiplica por 117 millones — un Decimal de más son 2 GB.
// Antes de tocar esta tabla, calcular cuánto cuesta el campo.
//
// SÓLO SE GUARDAN LOS NO NULOS. Una fila de Meta4 tiene ~250 valores cargados de 1.818 columnas: el
// 86% son ceros que no se escriben. Un cero ausente acá significa cero, no "se desconoce" — es la
// misma semántica que tenía la columna ancha en Oracle.
//
// El 70% de cada fila son las columnas de sistema de BC ($systemId, $systemCreatedAt, CreatedBy,
// ModifiedAt, ModifiedBy y el timestamp: 72 bytes contra ~33 de datos útiles). Son ~7 GB de control
// de cambios sobre un archivo que por definición no cambia nunca. No hay forma de desactivarlas en
// BC; es el precio de que esto se pueda abrir desde adentro del producto, que fue el requisito.
table 110056 "Valor Hist. Meta4"
{
    Caption = 'Valores de la Historia Meta4';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "No. Entrada"; Integer)
        {
            Caption = 'No. Entrada';
            DataClassification = CustomerContent;
            TableRelation = "Hist. Liq. Meta4"."No. Entrada";
            ValidateTableRelation = false;
        }
        field(2; "No. Columna"; Integer)
        {
            Caption = 'Columna';
            DataClassification = CustomerContent;
            TableRelation = "Columna Hist. Meta4"."No.";
            ValidateTableRelation = false;
        }
        field(3; Valor; Decimal)
        {
            Caption = 'Valor';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(4; "Valor Texto"; Text[100])
        {
            Caption = 'Valor (texto)';
            DataClassification = CustomerContent;
        }
        field(5; "Valor Fecha"; Date)
        {
            Caption = 'Valor (fecha)';
            DataClassification = CustomerContent;
            // Campo propio y no una fecha serializada dentro de "Valor Texto". Cuesta 8 bytes en las
            // 117 millones de filas (~940 MB) para beneficiar a 19 millones, y aun así se deja: esto
            // lo va a leer una persona dentro de diez años y una fecha tiene que verse como fecha,
            // sin que nadie tenga que saber en qué formato se guardó.
            //
            // UN DATE DE ORACLE LLEVA HORA Y ESTE CAMPO NO LA ADMITE. Un DATE de Oracle es un
            // timestamp al segundo. Si se escribe con hora, la INSERCIÓN NO FALLA: falla la página
            // al renderizarlo, con "La fecha no es válida", y se cierra entera. O sea que una carga
            // puede parecer perfecta —todos los controles de importe en cero— y estar rota.
            //
            // La carga inicial metió 2.200.914 filas así, todas de FEC_ULT_ACTUALIZACION, la marca
            // de auditoría de Meta4. Se truncaron a medianoche, pero la hora NO se tiró: quedó como
            // texto ISO en "Valor Texto", porque son 52.000 horas distintas y esto es un archivo
            // literal. Perder el dato para que abra una página sería arreglar el síntoma.
            //
            // Cualquier carga nueva tiene que truncar del lado de Oracle (TRUNC(col) o TO_CHAR con
            // formato de fecha) antes de traer la columna.
        }
        field(6; "Nombre Columna"; Code[50])
        {
            Caption = 'Columna';
            FieldClass = FlowField;
            CalcFormula = lookup("Columna Hist. Meta4"."Nombre Columna" where("No." = field("No. Columna")));
            Editable = false;
        }
        field(7; "Descripción Columna"; Text[100])
        {
            Caption = 'Descripción';
            FieldClass = FlowField;
            CalcFormula = lookup("Columna Hist. Meta4".Descripción where("No." = field("No. Columna")));
            Editable = false;
        }
    }

    keys
    {
        // La clave agrupada es exactamente el acceso que se le va a dar: abrir una liquidación y ver
        // todos sus valores juntos. Con 117 millones de filas, que ese recorrido sea contiguo en
        // disco es la diferencia entre abrir un recibo viejo en un segundo o en un minuto.
        //
        // NO HAY ÍNDICE POR COLUMNA a propósito. Serviría para "este concepto a lo largo del tiempo",
        // que es una consulta de análisis, no de archivo — y costaría otros ~3 GB. Si aparece esa
        // necesidad se agrega, pero conviene que sea una decisión con el número a la vista.
        key(PK; "No. Entrada", "No. Columna") { Clustered = true; }
    }
}
