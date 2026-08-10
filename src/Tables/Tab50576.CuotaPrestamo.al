namespace UAS.Payroll;

table 50580 "Cuota Préstamo"
{
    Caption = 'Cuota Préstamo';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "No. Préstamo"; Code[20])
        {
            Caption = 'No. Préstamo';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Préstamo Empleado"."No.";
        }
        field(2; "No. Cuota"; Integer)
        {
            Caption = 'No. Cuota';
            DataClassification = CustomerContent;
            AutoIncrement = true;
        }
        field(3; Importe; Decimal)
        {
            Caption = 'Importe';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
            MinValue = 0;
        }
        field(4; "Cód. Período"; Code[10])
        {
            Caption = 'Período Destino';
            DataClassification = CustomerContent;
            TableRelation = "Período Liquidación".Código;
            // Optional: auto-applies when a liquidation for this period is calculated.
            // If blank, must be applied manually or via No. Liquidación.
        }
        field(5; "No. Liquidación"; Code[20])
        {
            Caption = 'Liquidación Destino';
            DataClassification = CustomerContent;
            TableRelation = "Liquidación"."No.";
            // Optional: overrides Cód. Período — cuota is applied only to this liquidation.
        }
        field(6; Estado; Enum "Estado Cuota Préstamo")
        {
            Caption = 'Estado';
            DataClassification = CustomerContent;
        }
        field(7; "No. Liquidación Aplicada"; Code[20])
        {
            Caption = 'Liq. Aplicada';
            DataClassification = CustomerContent;
            Editable = false;
            TableRelation = "Liquidación"."No.";
        }
        field(8; "Fecha Aplicada"; Date)
        {
            Caption = 'Fecha Aplicada';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(9; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            FieldClass = FlowField;
            CalcFormula = Lookup("Préstamo Empleado"."No. Empleado" WHERE("No." = FIELD("No. Préstamo")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "No. Préstamo", "No. Cuota") { Clustered = true; }
        key(K2; "No. Liquidación Aplicada") { }
        key(K3; "Cód. Período", Estado) { }
    }

    trigger OnModify()
    begin
        if Estado = Estado::Aplicada then
            Error(ErrYaAplicada);
    end;

    var
        ErrYaAplicada: Label 'No se puede modificar una cuota ya aplicada. Revertí la liquidación correspondiente primero.';
}
