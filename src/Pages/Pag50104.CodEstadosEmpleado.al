namespace UAS.Payroll;

page 50104 "Cód. Estados Empleado"
{
    ApplicationArea = All;
    Caption = 'Cód. Estados Empleado';
    PageType = List;
    SourceTable = "Cód. Estado Empleado";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Tipo Empleado"; Rec."Tipo Empleado") { ApplicationArea = All; }
                field("Tipo Estado"; Rec."Tipo Estado") { ApplicationArea = All; }
                field("Ámbito"; Rec."Ámbito")
                {
                    ApplicationArea = All;
                    ToolTip = 'A qué entidades aplica este estado: Empleado, Buque o Ambos.';
                }
                field("Estado Siguiente"; Rec."Estado Siguiente")
                {
                    ApplicationArea = All;
                    ToolTip = 'Estado al que se transiciona automáticamente cuando termina la condición de éste (ej. Francos → Órdenes al agotarse el saldo). Vacío = terminal.';
                }
                field("Devenga Francos"; Rec."Devenga Francos")
                {
                    ApplicationArea = All;
                    ToolTip = 'Estado productivo/embarcado: sus días en marea cuentan para el devengo de francos (DIAS_ENROLAMIENTO).';
                }
                field(Activo; Rec.Activo) { ApplicationArea = All; }
            }
        }
    }
}
