namespace UAS.Payroll;

// Detalle de una diferencia entre Meta4 y BC: qué concepto la explica.
//
// Temporal, igual que el buffer de la comparación: se arma al hacer drilldown sobre un mes y se
// descarta al cerrar.
//
// LAS FILAS QUE IMPORTAN SON LAS QUE TIENEN UN SOLO LADO. Un concepto con importe en Meta4 y cero
// en BC es algo que el motor no está liquidando; al revés, algo que liquida de más. Las que
// coinciden son ruido y la página las esconde por defecto.
table 110058 "Comp. Det. Meta4 Buffer"
{
    Caption = 'Detalle de la diferencia';
    DataClassification = CustomerContent;
    TableType = Temporary;

    fields
    {
        field(1; "No. Línea"; Integer) { Caption = 'No. Línea'; DataClassification = CustomerContent; }
        field(2; "Cód. Concepto"; Code[20]) { Caption = 'Concepto'; DataClassification = CustomerContent; }
        field(3; Descripción; Text[100]) { Caption = 'Descripción'; DataClassification = CustomerContent; }
        field(4; "Columna Meta4"; Code[50]) { Caption = 'Columna Meta4'; DataClassification = CustomerContent; }
        field(5; "Importe Meta4"; Decimal) { Caption = 'Meta4'; DataClassification = CustomerContent; }
        field(6; "Importe BC"; Decimal) { Caption = 'BC'; DataClassification = CustomerContent; }
        field(7; Diferencia; Decimal) { Caption = 'Diferencia'; DataClassification = CustomerContent; }
        field(8; Origen; Option)
        {
            Caption = 'Origen';
            OptionMembers = Ambos,"Sólo Meta4","Sólo BC","Sin equivalencia";
            OptionCaption = 'Ambos,Sólo Meta4,Sólo BC,Sin equivalencia';
            DataClassification = CustomerContent;
            // "Sin equivalencia" es una columna de Meta4 con valor cuyo concepto de BC se desconoce.
            // No es lo mismo que "Sólo Meta4": ahí sabemos qué concepto es y BC no lo liquidó; acá
            // ni siquiera sabemos contra qué compararlo. Mezclarlos haría parecer un defecto del
            // motor lo que es un hueco del mapeo.
        }
    }

    keys
    {
        key(PK; "No. Línea") { Clustered = true; }
        key(PorDif; Diferencia) { }
    }
}
