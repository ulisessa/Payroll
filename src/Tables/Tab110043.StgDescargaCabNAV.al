namespace UAS.Payroll;

table 110043 "Stg Descarga Cab NAV"
{
    Caption = 'Staging Descarga - Cabecera NAV';
    DataClassification = CustomerContent;
    LookupPageId = "Sinc. Cab. Descargas NAV";
    DrillDownPageId = "Sinc. Cab. Descargas NAV";
    // Espejo de "Cab. descarga" (tabla 50561). La clave primaria de esa tabla es SÓLO el proyecto:
    // hay una cabecera de descarga por marea, no una por remito. Los remitos son las líneas.
    //
    // "Cab. descarga" no tiene código —viene de la conversión Tables Only de la personalización de
    // NAV— así que acá no hay lógica de negocio que respetar, sólo el orden: si el proyecto todavía
    // no llegó a BC, la fila espera en Pendiente en vez de fallar.

    fields
    {
        field(1; "No Proyecto"; Code[20])
        {
            Caption = 'No. Proyecto';
            DataClassification = CustomerContent;
        }
        field(10; Capitan; Text[50])
        {
            Caption = 'Capitán';
            DataClassification = CustomerContent;
        }
        field(11; Actividad; Code[10])
        {
            Caption = 'Actividad';
            DataClassification = CustomerContent;
        }
        field(12; "Fecha Inicio Descarga"; Date)
        {
            Caption = 'Fecha de Inicio de Descarga';
            DataClassification = CustomerContent;
        }
        field(13; Buque; Code[10])
        {
            Caption = 'Buque';
            DataClassification = CustomerContent;
        }
        field(14; Marea; Code[10])
        {
            Caption = 'Marea';
            DataClassification = CustomerContent;
        }
        field(15; "Cod Camara"; Code[20])
        {
            Caption = 'Cámara';
            DataClassification = CustomerContent;
            // Campo "Location" en el origen.
        }
        field(16; "Libro Diario"; Code[10])
        {
            Caption = 'Libro Diario';
            DataClassification = CustomerContent;
        }
        field(17; Puerto; Code[10])
        {
            Caption = 'Puerto';
            DataClassification = CustomerContent;
        }
        field(18; "Pallets Desde"; Integer)
        {
            Caption = 'Pallets Desde';
            DataClassification = CustomerContent;
        }
        field(19; "Pallets Hasta"; Integer)
        {
            Caption = 'Pallets Hasta';
            DataClassification = CustomerContent;
        }
        field(20; "Hora Inicio Descarga"; Time)
        {
            Caption = 'Hora Inicio Descarga';
            DataClassification = CustomerContent;
        }
        field(21; "Hora Fin Descarga"; Time)
        {
            Caption = 'Hora Fin Descarga';
            DataClassification = CustomerContent;
        }
        field(22; "Cod Balanza"; Code[10])
        {
            Caption = 'Cód. Balanza';
            DataClassification = CustomerContent;
        }
        field(23; Registrado; Boolean)
        {
            Caption = 'Registrado';
            DataClassification = CustomerContent;
        }
        field(24; "Origen Carton"; Integer)
        {
            Caption = 'Origen del Cartón (ordinal)';
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
        key(PK; "No Proyecto") { Clustered = true; }
        key(K2; "Estado Sinc", "No Proyecto") { }
    }
}
