namespace UAS.Payroll;

using Microsoft.HumanResources.Setup;

pageextension 50355 "HR Setup SIRADIG Ext." extends "Human Resources Setup"
{
    layout
    {
        addafter(Numbering)
        {
            group(SIRADIG)
            {
                Caption = 'SIRADIG';

                field("Carpeta Importación SIRADIG"; Rec."Carpeta Importación SIRADIG")
                {
                    ApplicationArea = All;
                    ToolTip = 'Especifica la carpeta del servidor donde se buscan los archivos de importación SIRADIG (.xml.zip o .xml) por defecto.';
                }
            }
        }
    }
}
