namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

pageextension 50354 "Empleado Relativo Liq. Ext." extends "Employee Relatives"
{
    layout
    {
        addafter("Birth Date")
        {
            field("Tipo Documento"; Rec."Tipo Documento")
            {
                ApplicationArea = All;
                ToolTip = 'Tipo de documento del familiar. Lo completa la importación SIRADIG con el código informado por AFIP.';
            }
            field("Nro. Documento"; Rec."Nro. Documento")
            {
                ApplicationArea = All;
                ToolTip = 'Número de documento del familiar. La importación SIRADIG lo usa para reconocer una carga ya existente y actualizarla en vez de duplicarla.';
            }
            field("Cód. Tipo Ded."; Rec."Cód. Tipo Ded.")
            {
                ApplicationArea = All;
                ToolTip = 'Parámetro de deducción de Ganancias 4ta que aplica a este familiar (ej. DED_CONYUGE, DED_HIJO_MENOR). Su Parámetro Vigente aporta el importe anual. Vacío = no genera deducción impositiva.';
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
            field("% Deducción"; Rec."% Deducción")
            {
                ApplicationArea = All;
                ToolTip = 'Porcentaje de la deducción que aplica a este familiar. 100 = deducción completa, 50 = mitad (ej: hijo compartido).';
            }
        }
    }
}
