namespace UAS.Payroll;

table 110051 "Stg Dia Abordo Cab NAV"
{
    Caption = 'Staging Diario de Abordo - Cabecera';
    DataClassification = CustomerContent;
    LookupPageId = "Sinc. Dia Abordo Cab NAV";
    DrillDownPageId = "Sinc. Dia Abordo Cab NAV";
    // El parte de pesca de una marea, antes de aplicarse. Una fila por proyecto.
    //
    // ES EL QUE TIENE LA PRODUCCIÓN POR DÍA, en sus líneas. El informe del capitán da el total del
    // viaje por clasificación y alcanza para liquidar una marea completa; esto es lo que permite
    // cortar a una fecha, que es lo que hace falta cuando un tripulante deja el barco antes —un
    // accidente, una urgencia— y se le liquida la producción hasta ese día.
    //
    // Latitud y longitud no se traen: son del parte de pesca, no de la liquidación. Están en el
    // origen si algún día hacen falta.

    fields
    {
        field(1; "No Proyecto"; Code[20])
        {
            Caption = 'No. Proyecto';
            DataClassification = CustomerContent;
        }
        field(10; Buque; Code[10])
        {
            Caption = 'Buque';
            DataClassification = CustomerContent;
        }
        field(11; Marea; Code[10])
        {
            Caption = 'Marea';
            DataClassification = CustomerContent;
        }
        field(12; Patron; Text[30])
        {
            Caption = 'Patrón';
            DataClassification = CustomerContent;
        }
        field(13; "Zona Pesca"; Text[50])
        {
            Caption = 'Zona de Pesca';
            DataClassification = CustomerContent;
            // Se guarda como TEXTO, tal como lo devuelve OData, y NO se escribe en la tabla de BC.
            // Allá es un campo de opción y traducir una caption a su ordinal sin poder verificar el
            // orden es cómo se termina guardando un valor plausible y equivocado. Acá queda a la
            // vista por si alguien lo necesita; el día que haga falta escribirlo, primero se mira el
            // OptionMembers real.
        }
        field(14; "Fecha Salida"; Date)
        {
            Caption = 'Fecha de Salida';
            DataClassification = CustomerContent;
        }
        field(15; Historico; Date)
        {
            Caption = 'Histórico';
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
