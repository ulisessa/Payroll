namespace UAS.Payroll;

page 50180 "Lista Préstamos Empleado"
{
    ApplicationArea = All;
    Caption = 'Préstamos y Anticipos';
    CardPageId = "Ficha Préstamo Empleado";
    PageType = List;
    SourceTable = "Préstamo Empleado";
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No."; Rec."No.") { ApplicationArea = All; }
                field(Tipo; Rec.Tipo) { ApplicationArea = All; }
                field("No. Empleado"; Rec."No. Empleado") { ApplicationArea = All; }
                field("Nombre Empleado"; Rec."Nombre Empleado") { ApplicationArea = All; }
                field(Fecha; Rec.Fecha) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Importe Total"; Rec."Importe Total")
                {
                    ApplicationArea = All;
                    Style = Strong;
                }
                field("Cant. Cuotas"; Rec."Cant. Cuotas") { ApplicationArea = All; }
                field("Total Aplicado"; Rec."Total Aplicado")
                {
                    ApplicationArea = All;
                    StyleExpr = SaldadoStyle;
                }
                field("Cód. Concepto Descuento"; Rec."Cód. Concepto Descuento") { ApplicationArea = All; }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        Rec.CalcFields("Total Aplicado");
        if Rec."Total Aplicado" >= Rec."Importe Total" then
            SaldadoStyle := 'Favorable'
        else
            SaldadoStyle := 'Subordinate';
    end;

    var
        SaldadoStyle: Text;
}
