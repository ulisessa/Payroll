namespace UAS.Payroll;

/// <summary>Una fila con un número de mes, para poder evaluar el filtro "Meses" de un tipo.</summary>
/// <remarks>
/// Existe sólo para usarse TEMPORARY. El campo "Meses" de Tipo Liquidación guarda un filtro de BC
/// —"6|12", "1..6"— y la forma de evaluarlo sin escribir un parser propio es ponerle el mes a una
/// fila y dejar que la plataforma aplique el filtro. Un parser a mano funcionaría para el caso fácil
/// y diferiría del de BC justo en los de borde, que es donde nadie lo va a estar mirando.
/// </remarks>
table 110060 "Mes Filtro Liq."
{
    Caption = 'Mes (auxiliar de filtro)';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; Numero; Integer)
        {
            Caption = 'Mes';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; Numero) { Clustered = true; }
    }
}
