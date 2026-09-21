namespace UAS.Payroll;

table 110052 "Stg Dia Abordo Lin NAV"
{
    Caption = 'Staging Diario de Abordo - Líneas';
    DataClassification = CustomerContent;
    LookupPageId = "Sinc. Dia Abordo Lin NAV";
    DrillDownPageId = "Sinc. Dia Abordo Lin NAV";
    // LA PRODUCCIÓN DÍA POR DÍA. Es la única fuente con esa granularidad: el informe del capitán
    // consolida por marea y las descargas registran lo que bajó a puerto al final del viaje.
    //
    // De acá sale poder liquidarle a un tripulante lo producido hasta la fecha en que dejó el barco.
    // Sin esto, lo único posible sería prorratear el total de la marea por días a bordo, que no es
    // lo mismo: la pesca no se reparte pareja a lo largo del viaje.
    //
    // "Concepto" distingue los días de pesca de los que no lo son (PUERTO, navegación). Un día en
    // puerto trae cantidad y kilos en cero, y eso no es un dato faltante: es el dato.

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
        field(10; "Fecha Registro"; Date)
        {
            Caption = 'Fecha de Registro';
            DataClassification = CustomerContent;
            // El día al que corresponde la producción. Es el campo que hace útil a esta tabla.
        }
        field(11; Concepto; Code[10])
        {
            Caption = 'Concepto';
            DataClassification = CustomerContent;
        }
        field(12; Producto; Code[20])
        {
            Caption = 'Producto';
            DataClassification = CustomerContent;
            // En OData llega como N_x00BA_: el "No." de la línea, con el símbolo de ordinal
            // codificado. Buscarlo por su nombre legible devuelve vacío sin fallar.
        }
        field(13; Descripcion; Text[199])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(14; Cantidad; Decimal)
        {
            Caption = 'Cantidad';
            DataClassification = CustomerContent;
        }
        field(15; Kilos; Decimal)
        {
            Caption = 'Kilos';
            DataClassification = CustomerContent;
        }
        field(16; "Unidad Medida Desc"; Text[50])
        {
            Caption = 'Unidad de Medida';
            DataClassification = CustomerContent;
            // La página de NAV expone la DESCRIPCIÓN de la unidad, no su código. Si hiciera falta el
            // código para algún cálculo, hay que agregarlo a la página del origen.
        }
        field(17; "Zona Pesca"; Text[50])
        {
            Caption = 'Zona de Pesca';
            DataClassification = CustomerContent;
            // Texto, y no se escribe en BC. Ver el comentario del mismo campo en la cabecera.
        }
        field(18; Enviado; Boolean)
        {
            Caption = 'Enviado';
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
        key(PorFecha; "No Proyecto", "Fecha Registro") { }
    }
}
