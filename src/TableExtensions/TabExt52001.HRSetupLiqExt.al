namespace UAS.Payroll;

using Microsoft.HumanResources.Setup;
using Microsoft.Foundation.NoSeries;
using Microsoft.Projects.Project.Job;

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
        field(52011; "Cód. Serie Préstamos"; Code[20])
        {
            Caption = 'Serie Núm. Préstamos';
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
        }
        field(52012; "Proyecto Nómina"; Code[20])
        {
            Caption = 'Proyecto Nómina';
            DataClassification = CustomerContent;
            TableRelation = Job."No.";
            // Fallback inactivity project: used to park employees in an inactive state when their marea
            // project has no "Proyecto Inactividad Nómina" set.
        }
    }
}
