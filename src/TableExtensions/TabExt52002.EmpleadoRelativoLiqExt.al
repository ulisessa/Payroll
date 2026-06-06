namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

tableextension 52002 "Empleado Relativo Liq. Ext." extends "Employee Relative"
{
    fields
    {
        field(50210; "Cód. Tipo Ded."; Code[20])
        {
            Caption = 'Tipo Deducción Ganancias';
            DataClassification = CustomerContent;
            TableRelation = "Parámetro".Código;
        }
        field(50211; "Fecha Ingreso Impuesto"; Date)
        {
            Caption = 'Fecha Ingreso Impuesto';
            DataClassification = CustomerContent;
        }
        field(50212; "Fecha Egreso Impuesto"; Date)
        {
            Caption = 'Fecha Egreso Impuesto';
            DataClassification = CustomerContent;
        }
    }
}
