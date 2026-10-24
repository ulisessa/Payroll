namespace UAS.Payroll;

query 110000 "Versiones Parámetro En Uso"
{
    QueryType = Normal;
    TopNumberOfRows = 1;
    // La conciliación decide qué marcas puede liberar dentro de la transacción del cálculo.
    // Las queries tienen aislamiento propio: no usar lecturas sucias ni una réplica de lectura.
    ReadState = ReadExclusive;
    DataAccessIntent = ReadWrite;

    elements
    {
        dataitem(Uso; "Uso Parámetro Liq.")
        {
            filter(CodigoBase; "Cód. Parámetro Base") { }
            filter(ClaveParametro; "Cód. Parámetro") { }
            filter(VigenciaDesde; "Vigencia Desde") { }

            dataitem(Liquidacion; "Liquidación")
            {
                DataItemLink = "No." = Uso."No. Liquidación";
                SqlJoinType = InnerJoin;
                DataItemTableFilter = Estado = filter(Calculada | Aprobada | Contabilizada);
                // Sólo interesa la existencia. Limitar a una fila evita recorrer y bloquear
                // todos los recibos que comparten un parámetro general.
                column(NumeroLiquidacion; "No.") { }
            }
        }
    }
}
