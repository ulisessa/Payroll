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
                field(Activo; Rec.Activo) { ApplicationArea = All; }
            }
        }
    }
}
