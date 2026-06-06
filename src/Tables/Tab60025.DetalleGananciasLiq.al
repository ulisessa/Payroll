namespace UAS.Payroll;

table 60025 "Detalle Ganancias Liq."
{
    Caption = 'Detalle Deducciones Ganancias';
    DataClassification = CustomerContent;
    // One row per active deduction at calculation time:
    //   Familiar — counted from Employee Relative (Cód. Tipo Ded. set and date-active)
    //   Gasto    — from Ded. Ganancias Empleado with Importe Fijo > 0
    // Written by CalcDeduccionesGanancias in Cod50016 during liquidation calculation.
    // Deleted by DeleteLineas in Cod50014 on recalculation.

    fields
    {
        field(1; "No. Liquidación"; Code[20])
        {
            Caption = 'No. Liquidación';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Liquidación"."No.";
        }
        field(2; "No. Línea"; Integer)
        {
            Caption = 'No. Línea';
            DataClassification = CustomerContent;
            AutoIncrement = true;
        }
        field(3; Tipo; Option)
        {
            Caption = 'Tipo';
            OptionMembers = Familiar,Gasto,Paso;
            OptionCaption = 'Familiar,Gasto,Paso de Cálculo';
            DataClassification = CustomerContent;
        }
        field(4; Código; Code[20])
        {
            Caption = 'Código';
            DataClassification = CustomerContent;
        }
        field(5; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(6; Cantidad; Integer)
        {
            Caption = 'Cantidad';
            DataClassification = CustomerContent;
            // For Familiar: number of active relatives of this type.
            // For Gasto: 0 (not applicable).
        }
        field(7; "Importe Unit. Anual"; Decimal)
        {
            Caption = 'Importe Unit. Anual';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 2;
            // For Familiar: AFIP annual amount per relative (from Ded. Ganancias Vigente).
            // For Gasto: 0 (Importe Total holds the fixed amount directly).
        }
        field(8; "Importe Total"; Decimal)
        {
            Caption = 'Importe Total';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 2;
            // For Familiar: Cantidad × Importe Unit. Anual.
            // For Gasto: Importe Fijo declared by the employee.
            // For Paso: concept result amount.
        }
        field(9; Orden; Integer)
        {
            Caption = 'Orden';
            DataClassification = CustomerContent;
            // Controls display order in the receipt ganancias section.
            // Familiar/Gasto rows use 500; Paso rows use the concept's Orden Cálculo.
        }
    }

    keys
    {
        key(PK; "No. Liquidación", "No. Línea")
        {
            Clustered = true;
            SumIndexFields = "Importe Total";
        }
    }
}
