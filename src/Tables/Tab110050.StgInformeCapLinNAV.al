namespace UAS.Payroll;

table 110050 "Stg Informe Cap Lin NAV"
{
    Caption = 'Staging Informe del Capitán - Líneas';
    DataClassification = CustomerContent;
    LookupPageId = "Sinc. Informe Cap. Lin NAV";
    DrillDownPageId = "Sinc. Informe Cap. Lin NAV";
    // El detalle del informe: una fila por clasificación declarada en la marea.
    //
    // "Clasificación" es el grado del producto (L-1, L-2, L-ENTERO...), y es lo que decide con qué
    // valor se liquida cada kilo. No confundirla con el lote ni con la familia: la familia agrupa,
    // la clasificación tarifa.

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
            // Sin punto ni acento en el nombre del campo, igual que en las otras tablas de staging:
            // el script T-SQL las referencia literalmente y un "No." se convierte en "No_" del lado
            // SQL. Además "LineNo" a secas es palabra reservada en T-SQL y hay que corchetearla.
        }
        field(10; Clasificacion; Code[20])
        {
            Caption = 'Clasificación';
            DataClassification = CustomerContent;
        }
        field(11; Descripcion; Text[150])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(12; "Unidad Medida"; Code[10])
        {
            Caption = 'Unidad de Medida';
            DataClassification = CustomerContent;
        }
        field(13; Cantidad; Decimal)
        {
            Caption = 'Cantidad';
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
