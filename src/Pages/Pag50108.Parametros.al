namespace UAS.Payroll;

page 50108 "Parámetros"
{
    ApplicationArea = All;
    Caption = 'Parámetros';
    PageType = List;
    SourceTable = "Parámetro";
    UsageCategory = Administration;
    CardPageId = "Parámetro Card";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Nombre Variable"; Rec."Nombre Variable") { ApplicationArea = All; }
                field("Sufijo CCT"; Rec."Sufijo CCT") { ApplicationArea = All; }
                field("Sufijo Empleado"; Rec."Sufijo Empleado") { ApplicationArea = All; }
                field(Notas; Rec.Notas) { ApplicationArea = All; Visible = false; }
            }
        }
    }
}
