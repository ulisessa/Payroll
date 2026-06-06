namespace UAS.Payroll;

using Microsoft.HumanResources.Setup;
using Microsoft.Foundation.NoSeries;

tableextension 52001 "HR Setup Liq. Ext." extends "Human Resources Setup"
{
    fields
    {
        field(52010; "Cód. Serie Liq."; Code[20])
        {
            Caption = 'Serie Núm. Liquidaciones';
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
        }
    }
}
