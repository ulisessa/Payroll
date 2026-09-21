namespace UAS.Payroll;

using Microsoft.Foundation.UOM;

/// <summary>
/// Plural de la unidad de medida, para que el recibo diga "9 DIAS" y no "9 DIA".
/// </summary>
/// <remarks>
/// El plural va acá y no en el concepto: es una propiedad de la unidad, no de para qué se la usa. Si
/// estuviera en el concepto habría que escribir "DIAS" en cada uno de los que se miden en días, y la
/// primera corrección obligaría a repasarlos todos. Acá se carga una vez por unidad y lo heredan los
/// conceptos, las incidencias y las novedades, que las tres apuntan a esta misma tabla.
///
/// Se deja en blanco cuando la regla del castellano alcanza —DIA→DIAS, MES→MESES, KN→KN—, que es
/// casi siempre; ver "Unidad Cantidad" en Línea Liquidación. El campo existe para los casos en que
/// no alcanza: unidades irregulares, abreviaturas con punto, o un plural que la empresa escribe de
/// una forma determinada en el recibo.
/// </remarks>
tableextension 110033 "Unidad Plural Liq." extends "Unit of Measure"
{
    fields
    {
        field(52020; "Plural Liq."; Code[20])
        {
            Caption = 'Plural (recibo)';
            DataClassification = CustomerContent;
            ToolTip = 'Cómo se escribe esta unidad cuando la cantidad no es 1, en el recibo y en las líneas de liquidación. Si se deja en blanco se arma solo: DIA→DIAS, MES→MESES, y las abreviaturas sin vocales —KN, TN, KG— quedan invariables.';
        }
    }
}
