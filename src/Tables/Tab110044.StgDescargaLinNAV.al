namespace UAS.Payroll;

table 110044 "Stg Descarga Lin NAV"
{
    Caption = 'Staging Descarga - Líneas NAV';
    DataClassification = CustomerContent;
    LookupPageId = "Sinc. Lín. Descargas NAV";
    DrillDownPageId = "Sinc. Lín. Descargas NAV";
    // Espejo de "Lín. descarga" (tabla 50562), la tabla de la que sale la producción de la marea.
    // Acá se copian TODOS los campos de datos del origen, y no sólo los kilos: el motor la lee por
    // Fuente Datos, y una Fuente Datos puede filtrar o sumar por cualquier campo —subfamilia,
    // actividad, puerto— sin tocar código. Recortar la copia sería decidir hoy qué conceptos se van
    // a poder configurar mañana.
    //
    // Quedan afuera únicamente los FlowFields del origen, que no existen como columna en SQL.

    fields
    {
        field(1; "No Proyecto"; Code[20])
        {
            Caption = 'No. Proyecto';
            DataClassification = CustomerContent;
        }
        field(2; "Line No"; Integer)
        {
            Caption = 'No. Línea';
            DataClassification = CustomerContent;
        }
        field(10; "No Remito"; Code[20])
        {
            Caption = 'No. Remito';
            DataClassification = CustomerContent;
        }
        field(11; "Item No"; Code[20])
        {
            Caption = 'No. Producto';
            DataClassification = CustomerContent;
        }
        field(12; Descripcion; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(13; "Unidad Medida"; Code[10])
        {
            Caption = 'Unidad de Medida';
            DataClassification = CustomerContent;
        }
        field(14; Cantidad; Decimal)
        {
            Caption = 'Cantidad';
            DataClassification = CustomerContent;
        }
        field(15; "Peso Neto"; Decimal)
        {
            Caption = 'Peso Neto';
            DataClassification = CustomerContent;
        }
        field(16; "Peso Bruto"; Decimal)
        {
            Caption = 'Peso Bruto';
            DataClassification = CustomerContent;
        }
        field(17; "Fecha Remito"; Date)
        {
            Caption = 'Fecha Remito';
            DataClassification = CustomerContent;
        }
        field(18; "Licencia Transporte"; Code[10])
        {
            Caption = 'Licencia de Transporte';
            DataClassification = CustomerContent;
        }
        field(19; Temperatura; Decimal)
        {
            Caption = 'Temperatura';
            DataClassification = CustomerContent;
        }
        field(20; "Hora Ingreso"; Time)
        {
            Caption = 'Hora de Ingreso';
            DataClassification = CustomerContent;
        }
        field(21; "Tipo Amparo Sanitario"; Integer)
        {
            Caption = 'Tipo de Amparo Sanitario (ordinal)';
            DataClassification = CustomerContent;
        }
        field(22; "No Amparo Sanitario"; Code[30])
        {
            Caption = 'No. Amparo Sanitario';
            DataClassification = CustomerContent;
        }
        field(23; Destino; Code[30])
        {
            Caption = 'Destino';
            DataClassification = CustomerContent;
        }
        field(24; "No Pallet"; Code[20])
        {
            Caption = 'No. Pallet';
            DataClassification = CustomerContent;
        }
        field(25; "Cod Camara"; Code[10])
        {
            Caption = 'Cámara';
            DataClassification = CustomerContent;
        }
        field(26; Buque; Code[10])
        {
            Caption = 'Buque';
            DataClassification = CustomerContent;
        }
        field(27; Marea; Code[10])
        {
            Caption = 'Marea';
            DataClassification = CustomerContent;
        }
        field(28; Puerto; Code[10])
        {
            Caption = 'Puerto';
            DataClassification = CustomerContent;
        }
        field(29; Promedio; Decimal)
        {
            Caption = 'Promedio';
            DataClassification = CustomerContent;
        }
        field(30; "Bin Code"; Code[20])
        {
            Caption = 'Cód. Contenedor';
            DataClassification = CustomerContent;
        }
        field(31; Tara; Decimal)
        {
            Caption = 'Tara';
            DataClassification = CustomerContent;
        }
        field(32; "Bruto Mas Tara"; Decimal)
        {
            Caption = 'Bruto + Tara';
            DataClassification = CustomerContent;
        }
        field(33; "Fecha Hora Pesaje"; DateTime)
        {
            Caption = 'Fecha y Hora de Pesaje';
            DataClassification = CustomerContent;
        }
        field(34; Confirmado; Integer)
        {
            Caption = 'Confirmado (ordinal)';
            DataClassification = CustomerContent;
        }
        field(35; "Estado Origen"; Text[50])
        {
            Caption = 'Estado (origen)';
            DataClassification = CustomerContent;
        }
        field(36; Actividad; Code[10])
        {
            Caption = 'Actividad';
            DataClassification = CustomerContent;
        }
        field(37; Familia; Code[10])
        {
            Caption = 'Familia';
            DataClassification = CustomerContent;
        }
        field(38; Subfamilia; Code[10])
        {
            Caption = 'Subfamilia';
            DataClassification = CustomerContent;
            // La que agrupan las Fuentes de Datos de producción (langostino cola, entero, merluza).
        }
        field(39; "Unidad Medida Manual"; Code[10])
        {
            Caption = 'Unidad de Medida Manual';
            DataClassification = CustomerContent;
        }
        field(40; "Peso Manual"; Decimal)
        {
            Caption = 'Peso Manual';
            DataClassification = CustomerContent;
        }
        field(90; "Estado Sinc"; Enum "Estado Sinc NAV")
        {
            Caption = 'Estado';
            DataClassification = CustomerContent;
        }
        field(91; Observacion; Text[250])
        {
            Caption = 'Observación';
            DataClassification = CustomerContent;
        }
        field(92; Intentos; Integer)
        {
            Caption = 'Intentos';
            DataClassification = CustomerContent;
        }
        field(93; "Marca Origen"; Text[20])
        {
            Caption = 'Rowversion Origen';
            DataClassification = CustomerContent;
        }
        field(94; "Traido El"; DateTime)
        {
            Caption = 'Traído El';
            DataClassification = CustomerContent;
        }
        field(95; "Procesado El"; DateTime)
        {
            Caption = 'Procesado El';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "No Proyecto", "Line No") { Clustered = true; }
        key(K2; "Estado Sinc", "No Proyecto", "Line No") { }
    }
}
