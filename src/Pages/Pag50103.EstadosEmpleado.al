namespace UAS.Payroll;

page 50103 "Estados Empleado"
{
    ApplicationArea = All;
    Caption = 'Estados Empleado';
    PageType = List;
    SourceTable = "Estado Empleado";
    // Lo más nuevo arriba, igual que en la subpágina de la ficha. Ordena por la clave K2 completa
    // y no sólo por "Fecha Inicio": un campo suelto no tiene índice que lo sostenga y BC lo
    // resuelve ordenando en memoria las 244.000 filas del histórico migrado de Meta4.
    SourceTableView = sorting("Tipo Entidad", "No. Empleado", "Fecha Inicio") order(descending);
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
                field("No. Proyecto"; Rec."No. Proyecto")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Proyecto del que salió este estado. En blanco = estado cargado a mano o propagado desde el buque. Estaba oculto y no debía: dos estados del mismo día que sólo se diferencian en este campo se veían como filas repetidas.';
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
