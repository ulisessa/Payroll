namespace UAS.Payroll;

table 110065 "Movimiento Franco Liq."
{
    Caption = 'Cuenta corriente de francos';
    DataClassification = CustomerContent;
    fields
    {
        field(1; "No. Movimiento"; Integer) { AutoIncrement = true; }
        field(2; "No. Empleado"; Code[20]) { DataClassification = EndUserIdentifiableInformation; }
        field(3; "No. Liquidación"; Code[20]) { }
        field(4; "No. Línea Origen"; Integer) { }
        field(5; "Fecha Devengamiento"; Date) { }
        field(6; "No. Lote"; Integer) { }
        field(7; Cantidad; Decimal) { DecimalPlaces = 0 : 4; }
        field(8; "Revierte Movimiento"; Integer) { }
        field(9; "Cód. Convenio"; Code[20]) { }
        field(10; "Cód. Categoría"; Code[20]) { }
        field(11; "No. Proyecto"; Code[20]) { }
        field(12; "Cód. Período"; Code[10]) { }
        field(13; "Cód. Concepto"; Code[20]) { }
        field(14; "Cód. Puesto"; Code[20]) { }
        field(15; "Cód. Estado"; Code[20]) { }
        field(16; "Id. Selección"; Guid) { }
        field(17; Tipo; Option) { OptionMembers = Devengo,Consumo,Reversion,Inicio; OptionCaption = 'Devengo,Consumo,Reversión,Inicio de cuenta'; }
        field(18; Reconstruido; Boolean) { }
    }
    keys
    {
        key(PK; "No. Movimiento") { Clustered = true; }
        key(Lote; "No. Lote", "Fecha Devengamiento") { SumIndexFields = Cantidad; }
        key(Empleado; "No. Empleado", Tipo, "Fecha Devengamiento", "No. Movimiento") { }
        key(Documento; "No. Liquidación", Tipo) { }
        key(Reversion; "Revierte Movimiento") { }
        key(Seleccion; "Id. Selección", "No. Lote") { }
    }
    trigger OnModify()
    begin
        Error('Los movimientos de francos son inmutables. Registrá un contramovimiento.');
    end;
    trigger OnDelete()
    begin
        Error('Los movimientos de francos se conservan aunque se elimine la liquidación.');
    end;
}
