namespace UAS.Payroll;

table 110049 "Stg Informe Cap Cab NAV"
{
    Caption = 'Staging Informe del Capitán - Cabecera';
    DataClassification = CustomerContent;
    LookupPageId = "Sinc. Informe Cap. Cab NAV";
    DrillDownPageId = "Sinc. Informe Cap. Cab NAV";
    // El informe del capitán de una marea, antes de aplicarse. Una fila por proyecto: la clave de
    // "Cab. informe capitán" en NAV es sólo el No. de proyecto.
    //
    // PARA QUÉ SE TRAE: cuando un tripulante corta la marea —un accidente, una urgencia— se le
    // liquida la producción hasta ese día. El informe da el total del viaje por clasificación, y los
    // días a bordo salen del historial de estados; el prorrateo se hace con esas dos cosas.
    //
    // OJO: este informe NO tiene detalle diario. Es por marea. Si algún día hace falta la producción
    // real de un día concreto —y no la prorrateada—, el origen es otro: "On board capture"
    // (tablas 50501/50502 de la personalización), que sí registra por fecha.

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
            Caption = 'Fecha Inicio Descarga';
            DataClassification = CustomerContent;
        }
        field(13; Cantidad; Decimal)
        {
            Caption = 'Cantidad Total';
            DataClassification = CustomerContent;
            // En NAV es un FlowField: la suma de las líneas. Se trae igual, como control — si no
            // coincide con la suma de lo que llegó, faltaron líneas.
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
