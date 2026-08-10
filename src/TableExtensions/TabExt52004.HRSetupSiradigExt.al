namespace UAS.Payroll;

using Microsoft.HumanResources.Setup;

tableextension 52004 "HR Setup SIRADIG Ext." extends "Human Resources Setup"
{
    fields
    {
        field(50100; "Carpeta Importación SIRADIG"; Text[250])
        {
            Caption = 'Carpeta Importación SIRADIG';
            DataClassification = CustomerContent;
        }
    }
}
