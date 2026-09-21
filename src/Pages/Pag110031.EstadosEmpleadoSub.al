namespace UAS.Payroll;

// El historial de estados de UNA entidad, para incrustar en su ficha.
//
// Misma grilla que "Estados Empleado", sin la columna del empleado —lo pone el vínculo— y con los
// dos triggers que sí importan: el que completa la fecha y el que fuerza la relectura después de
// insertar. Ese segundo no es adorno: el OnInsert de la tabla puede materializar un estado siguiente
// (Vacaciones deja armado el regreso), y sin releer la grilla esa fila hermana no aparece hasta que
// alguien navega a otro lado y vuelve.
//
// Lo que decide sigue estando en la tabla y en "Gestión Estado Empleado": la contigüidad, la
// validación de que después de una baja solo venga un alta, las transiciones automáticas. Acá solo
// hay disposición.
page 110031 "Estados Empleado Sub"
{
    ApplicationArea = All;
    Caption = 'Historial de Estados';
    PageType = ListPart;
    SourceTable = "Estado Empleado";
    // Lo más nuevo arriba. Con el histórico de Meta4 migrado, un tripulante con veinte años de
    // antigüedad tiene cientos de estados, y el que interesa —el de hoy— quedaba al final.
    // El sorting usa la clave K2 completa: ordenar sólo por "Fecha Inicio" no tiene índice que lo
    // sostenga y BC lo resuelve con un sort en memoria de todo el historial.
    SourceTableView = sorting("Tipo Entidad", "No. Empleado", "Fecha Inicio") order(descending);
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Fecha Inicio"; Rec."Fecha Inicio") { ApplicationArea = All; }
                field("Cód. Estado"; Rec."Cód. Estado") { ApplicationArea = All; }
                field("Descripción Estado"; Rec."Descripción Estado") { ApplicationArea = All; }
                field("Fecha Fin"; Rec."Fecha Fin")
                {
                    ApplicationArea = All;
                    ToolTip = 'Último día del estado, inclusive. Vacío = estado abierto (vigente). Mientras haya un estado posterior se mantiene sola contra el inicio de ése; si la acortás o la alargás, ese estado siguiente se corre para que no queden días sin estado.';
                }
                field("No. Proyecto"; Rec."No. Proyecto")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Proyecto del que salió este estado. En blanco = estado cargado a mano o propagado desde el buque.';
                }
                field(Observaciones; Rec.Observaciones) { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(VerFases)
            {
                ApplicationArea = All;
                Caption = 'Fases de Alta';
                Image = History;
                ToolTip = 'Aparea cada alta con la baja que la cierra y muestra los días que aporta cada fase. Es la lectura que usa el cálculo de antigüedad.';

                trigger OnAction()
                var
                    Fases: Page "Fases de Alta";
                begin
                    if Rec."No. Empleado" = '' then
                        exit;
                    Fases.SetEmpleado(Rec."No. Empleado");
                    Fases.RunModal();
                end;
            }
        }
    }

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        // El empleado lo completa el vínculo con la ficha. La fecha se propone porque acá, a
        // diferencia de los atributos, el historial es contiguo y lo habitual es cargar el estado
        // que empieza hoy; si no fuera hoy, se corrige antes de que la fila exista —DelayedInsert—
        // así que no hay renombre.
        Rec."Fecha Inicio" := WorkDate();
    end;

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        Rec.Insert(true);
        CurrPage.Update(false);
        exit(false);
    end;
}
