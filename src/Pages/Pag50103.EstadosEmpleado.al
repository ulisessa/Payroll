namespace UAS.Payroll;

page 50103 "Estados Empleado"
{
    ApplicationArea = All;
    Caption = 'Estados Empleado';
    PageType = List;
    SourceTable = "Estado Empleado";
    UsageCategory = None;
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No. Empleado"; Rec."No. Empleado")
                {
                    ApplicationArea = All;
                    Visible = ShowEmployee;
                    Editable = false;
                }
                field("Fecha Inicio"; Rec."Fecha Inicio")
                {
                    ApplicationArea = All;
                }
                field("Cód. Estado"; Rec."Cód. Estado")
                {
                    ApplicationArea = All;
                }
                field("Descripción Estado"; Rec."Descripción Estado")
                {
                    ApplicationArea = All;
                }
                field("Fecha Fin"; Rec."Fecha Fin")
                {
                    ApplicationArea = All;
                    Style = Subordinate;
                }
                field(Observaciones; Rec.Observaciones)
                {
                    ApplicationArea = All;
                }
            }
        }
    }


    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        Rec."Fecha Inicio" := WorkDate();
    end;

    procedure SetMostrarEmpleado(Show: Boolean)
    begin
        ShowEmployee := Show;
    end;

    var
        ShowEmployee: Boolean;
}
