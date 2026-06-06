namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

pageextension 50354 "Empleado Relativo Liq. Ext." extends "Employee Relatives"
{
    layout
    {
        addafter("Birth Date")
        {
            field("Cód. Tipo Ded."; Rec."Cód. Tipo Ded.")
            {
                ApplicationArea = All;
                ToolTip = 'Tipo de deducción de Ganancias 4ta que aplica a este familiar (CONYUGE, HIJO_MENOR, etc.). Vacío = no genera deducción impositiva.';
            }
            field("Fecha Ingreso Impuesto"; Rec."Fecha Ingreso Impuesto")
            {
                ApplicationArea = All;
                ToolTip = 'Fecha desde la cual este familiar es deducible (alta en AFIP, nacimiento, matrimonio, etc.).';
            }
            field("Fecha Egreso Impuesto"; Rec."Fecha Egreso Impuesto")
            {
                ApplicationArea = All;
                ToolTip = 'Último día en que este familiar es deducible (inclusive). Ej.: si aplica todo 2025, ingresá 31/12/2025. Vacío = sin fecha de vencimiento.';
            }
        }
    }
}
