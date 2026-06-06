namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

tableextension 52000 "Empleado Pesca Ext." extends Employee
{
    fields
    {
        field(52000; "Cód. Convenio"; Code[20])
        {
            Caption = 'Cód. Convenio';
            DataClassification = CustomerContent;
            TableRelation = "Convenio Colectivo".Código;

            trigger OnValidate()
            begin
                "Cód. Categoría" := '';
            end;
        }
        field(52001; "Cód. Categoría"; Code[20])
        {
            Caption = 'Cód. Categoría';
            DataClassification = CustomerContent;
            TableRelation = "Categoría CCT".Código WHERE("Cód. Convenio" = FIELD("Cód. Convenio"));
        }
        field(52002; "Antigüedad Reconocida"; Decimal)
        {
            Caption = 'Antigüedad Reconocida (años)';
            DataClassification = CustomerContent;
            MinValue = 0;
            DecimalPlaces = 0 : 2;
            // Years of prior or recognized service to add as a base.
            // Total seniority = this value + full years since the last Alta state in Estado Empleado.
        }
    }
}
