namespace UAS.Payroll;

using Microsoft.HumanResources.Setup;

pageextension 50353 "HR Setup Liq. Ext." extends "Human Resources Setup"
{
    layout
    {
        addlast(content)
        {
            group(GrpPayroll)
            {
                Caption = 'Liquidaciones';

                field("Cód. Serie Liq."; Rec."Cód. Serie Liq.")
                {
                    ApplicationArea = All;
                    Caption = 'Serie Núm. Liquidaciones';
                    ToolTip = 'Serie de numeración usada para generar el número de cada liquidación (ej. LIQ-000001).';
                    ShowMandatory = true;
                }
                field("Proyecto Nómina"; Rec."Proyecto Nómina")
                {
                    ApplicationArea = All;
                    ToolTip = 'Proyecto de inactividad por defecto: se usa para asignar empleados que pasan a un estado inactivo cuando su marea no tiene un "Proyecto Inactividad Nómina" propio.';
                }
            }
        }
    }
}
