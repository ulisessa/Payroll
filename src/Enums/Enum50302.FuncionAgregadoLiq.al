namespace UAS.Payroll;

enum 50302 "Función Agregado Liq."
{
    Extensible = false;

    value(0; "SUM") { Caption = 'Suma'; }
    value(1; "COUNT") { Caption = 'Cantidad'; }
    value(2; "MAX") { Caption = 'Máximo'; }
    value(3; "MIN") { Caption = 'Mínimo'; }
    value(4; "LOOKUP") { Caption = 'Búsqueda directa'; }
    // LOOKUP es FindLast(): la última fila por CLAVE PRIMARIA, no por fecha. Sobre Currency
    // Exchange Rate eso da la cotización más reciente porque la clave termina en Starting Date,
    // pero sobre una tabla de historial con clave por número de entrada —Estado Empleado, por
    // ejemplo— devuelve la fila insertada última, que no es la más nueva. Estas dos eligen por el
    // campo de fecha declarado y no dependen de la forma de la clave.
    value(5; "DIAS_OVERLAP") { Caption = 'Días solapados'; }
    value(6; "DURACION_INICIO") { Caption = 'Duración desde inicio'; }
    value(7; "DURACION_AÑO") { Caption = 'Duración en el año'; }
    value(8; "FILA_MAS_RECIENTE") { Caption = 'Fila más reciente'; }
    value(9; "FILA_MAS_ANTIGUA") { Caption = 'Fila más antigua'; }
    value(10; "DIAS_OVERLAP_30") { Caption = 'Días solapados (mes comercial de 30)'; }
}
