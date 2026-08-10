namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

tableextension 52002 "Empleado Relativo Liq. Ext." extends "Employee Relative"
{
    fields
    {
        field(50210; "Cód. Tipo Ded."; Code[20])
        {
            // Apunta a un Parámetro (ej. DED_CONYUGE), NO a un Concepto Liquidación ni a un tipo de
            // "Ded. Ganancias Vigente": el motor lee su Parámetro Vigente y usa el Valor como importe
            // anual de la deducción (ver LoadDeduccionesFamiliares en "Contexto Liquidación").
            Caption = 'Parámetro Deducción Ganancias';
            DataClassification = CustomerContent;
            TableRelation = "Parámetro".Código;

            trigger OnValidate()
            begin
                if ("Cód. Tipo Ded." <> '') and ("Fecha Ingreso Impuesto" <> 0D) and ("% Deducción" = 0) then
                    "% Deducción" := 100;
            end;
        }
        field(50211; "Fecha Ingreso Impuesto"; Date)
        {
            Caption = 'Fecha Ingreso Impuesto';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if ("Cód. Tipo Ded." <> '') and ("Fecha Ingreso Impuesto" <> 0D) and ("% Deducción" = 0) then
                    "% Deducción" := 100;
            end;
        }
        field(50212; "Fecha Egreso Impuesto"; Date)
        {
            Caption = 'Fecha Egreso Impuesto';
            DataClassification = CustomerContent;
        }
        field(50213; "% Deducción"; Decimal)
        {
            Caption = '% Deducción';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 2;
            MinValue = 0;
            MaxValue = 100;
            InitValue = 100;
        }
        // Documento del familiar: la tabla base no lo tiene, y es el único dato que identifica de
        // forma estable a una carga de familia entre importaciones sucesivas de SIRADIG (el nombre
        // puede venir escrito distinto). Se usa como clave para reemplazar en vez de duplicar.
        field(50214; "Tipo Documento"; Code[10])
        {
            Caption = 'Tipo Documento';
            DataClassification = CustomerContent;
        }
        field(50215; "Nro. Documento"; Code[20])
        {
            Caption = 'Nro. Documento';
            DataClassification = CustomerContent;
        }
    }
}
