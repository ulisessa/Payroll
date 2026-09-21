namespace UAS.Payroll;

using Microsoft.Foundation.UOM;

pageextension 110032 "Unidades Medida Liq. Ext." extends "Units of Measure"
{
    layout
    {
        addafter(Description)
        {
            field("Plural Liq."; Rec."Plural Liq.")
            {
                ApplicationArea = All;
                ToolTip = 'Cómo se escribe esta unidad cuando la cantidad no es 1, en el recibo y en las líneas de liquidación. Si se deja en blanco se arma solo: DIA→DIAS, MES→MESES, y las abreviaturas sin vocales —KN, TN, KG— quedan invariables.';
            }
        }
    }
}
