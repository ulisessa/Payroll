namespace UAS.Payroll;

page 50109 "Personal Proyecto"
{
    ApplicationArea = All;
    Caption = 'Personal Proyecto';
    DelayedInsert = true;
    PageType = ListPart;
    SourceTable = "Personal Proyecto";
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No. Empleado"; Rec."No. Empleado") { ApplicationArea = All; }
                field("Nombre Empleado"; Rec."Nombre Empleado") { ApplicationArea = All; }
                field("No. Proyecto"; Rec."No. Proyecto") { ApplicationArea = All; }
                field(Buque; Rec.Buque) { ApplicationArea = All; Editable = false; }
                field(Marea; Rec.Marea) { ApplicationArea = All; Editable = false; }
                field("Cód. Convenio"; Rec."Cód. Convenio") { ApplicationArea = All; }
                field("Cód. Categoría"; Rec."Cód. Categoría") { ApplicationArea = All; }
                field("Rol en Proyecto"; Rec."Rol en Proyecto") { ApplicationArea = All; }
                field("Fecha Alta Asignación"; Rec."Fecha Alta Asignación") { ApplicationArea = All; }
                field("Fecha Baja"; Rec."Fecha Baja") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(LiquidarTripulante)
            {
                ApplicationArea = All;
                Caption = 'Crear Liquidación';
                Image = CreateDocument;
                ToolTip = 'Crea una liquidación en borrador para este empleado en el proyecto actual.';

                trigger OnAction()
                var
                    Liq: Record "Liquidación";
                    LiqNo: Code[20];
                begin
                    Rec.TestField("No. Empleado");
                    Rec.TestField("No. Proyecto");
                    Rec.TestField("Cód. Convenio");
                    Rec.TestField("Cód. Categoría");

                    Liq.Init();
                    Liq."No." := 'LIQ-' + Rec."No. Empleado" + '-' + Rec."No. Proyecto";
                    Liq."No. Empleado" := Rec."No. Empleado";
                    Liq."No. Proyecto" := Rec."No. Proyecto";
                    Liq."Cód. Convenio" := Rec."Cód. Convenio";
                    Liq."Cód. Categoría" := Rec."Cód. Categoría";
                    Liq."Fecha Liquidación" := WorkDate();
                    Liq.Estado := Liq.Estado::Borrador;
                    if Liq.Insert(true) then
                        Page.Run(Page::"Ficha Liquidación", Liq);
                end;
            }
        }
    }
}
