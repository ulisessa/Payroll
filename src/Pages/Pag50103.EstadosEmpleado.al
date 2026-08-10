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
                    ToolTip = 'Último día del estado, inclusive. Vacío = estado abierto (vigente). Mientras haya un estado posterior se mantiene sola contra el inicio de ése; si la acortás o la alargás, ese estado siguiente se corre para que no queden días sin estado.';
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
        if Rec.GetFilter("No. Empleado") <> '' then
            Rec."No. Empleado" := CopyStr(Rec.GetRangeMin("No. Empleado"), 1, MaxStrLen(Rec."No. Empleado"));
        Rec."Fecha Inicio" := WorkDate();
    end;

    // Take over the insert so we can refresh the list afterwards: the table's OnInsert may materialize a
    // follow-up state (e.g. Vacaciones → return), and the grid must re-read to show that sibling row.
    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        Rec.Insert(true);
        CurrPage.Update(false);
        exit(false);
    end;

    procedure SetMostrarEmpleado(Show: Boolean)
    begin
        ShowEmployee := Show;
    end;

    var
        ShowEmployee: Boolean;
}
