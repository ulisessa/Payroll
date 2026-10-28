namespace UAS.Payroll;

page 110058 "Deducciones Aplicadas Liq."
{
    Caption = 'Deducciones guardadas al liquidar';
    PageType = List;
    SourceTable = "Detalle Ganancias Liq.";
    Editable = false;
    UsageCategory = None;
    ApplicationArea = All;
    layout
    {
        area(Content)
        {
            repeater(Deducciones)
            {
                field(Tipo; Rec.Tipo) { }
                field(Descripción; Rec.Descripción) { }
                field(Cantidad; Rec.Cantidad) { Caption = 'Coeficiente anual'; }
                field("Importe Unit. Anual"; Rec."Importe Unit. Anual") { }
                field("Importe Total"; Rec."Importe Total") { }
            }
        }
    }
}
