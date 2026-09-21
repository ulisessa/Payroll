namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

// Lo que NAV mandó de empleados. Las dos últimas columnas —convenio y categoría del origen— no se
// aplican a la ficha: están para que quien completa el empleado en BC vea qué decía NAV, porque esa
// codificación no es la de Convenio Colectivo y traducirla es una decisión de liquidación.
page 110034 "Sinc. Empleados NAV"
{
    ApplicationArea = All;
    Caption = 'Empleados traídos de NAV';
    PageType = List;
    UsageCategory = Lists;
    SourceTable = "Stg Empleado NAV";
    SourceTableView = sorting("Estado Sinc", "No Empleado");
    Editable = false;
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Filas)
            {
                field("Estado Sinc"; Rec."Estado Sinc")
                {
                    ApplicationArea = All;
                    StyleExpr = Estilo;
                    ToolTip = 'Pendiente: todavía no se aplicó. Procesado: el empleado ya está en BC. Error: llegó y no se pudo dar de alta, el motivo está en la observación.';
                }
                field("No Empleado"; Rec."No Empleado") { ApplicationArea = All; ToolTip = 'Legajo en NAV. Es el mismo No. con el que se crea en BC.'; }
                field(Apellido; Rec.Apellido) { ApplicationArea = All; ToolTip = 'Apellido en el origen.'; }
                field(Nombre; Rec.Nombre) { ApplicationArea = All; ToolTip = 'Nombre en el origen.'; }
                field("Fecha Ingreso"; Rec."Fecha Ingreso")
                {
                    ApplicationArea = All;
                    ToolTip = 'Fecha con la que se abre la fase de alta en el historial de estados. Si viene vacía el empleado se crea igual, pero sin fase abierta la antigüedad no se puede calcular.';
                }
                field("No Seguridad Social"; Rec."No Seguridad Social") { ApplicationArea = All; ToolTip = 'CUIL tal como vino de NAV.'; }
                field("Convenio Origen"; Rec."Convenio Origen")
                {
                    ApplicationArea = All;
                    ToolTip = 'Convenio que tenía cargado en NAV. NO se aplica a la ficha: es referencia para quien completa el empleado en BC.';
                }
                field("Categoria Origen"; Rec."Categoria Origen")
                {
                    ApplicationArea = All;
                    ToolTip = 'Categoría que tenía cargada en NAV. Tampoco se aplica: es referencia.';
                }
                field(Observacion; Rec.Observacion) { ApplicationArea = All; ToolTip = 'Por qué falló, o qué quedó pendiente aunque se haya aplicado.'; }
                field(Intentos; Rec.Intentos) { ApplicationArea = All; ToolTip = 'Cuántas veces se intentó aplicar esta fila.'; }
                field("Traido El"; Rec."Traido El") { ApplicationArea = All; ToolTip = 'Cuándo la trajo el job de SQL desde NAV.'; }
                field("Procesado El"; Rec."Procesado El") { ApplicationArea = All; ToolTip = 'Cuándo se intentó aplicar por última vez.'; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Procesar)
            {
                ApplicationArea = All;
                Caption = 'Procesar pendientes';
                Image = Apply;
                ToolTip = 'Aplica ahora las filas pendientes de empleados.';

                trigger OnAction()
                var
                    Sinc: Codeunit "Sinc NAV Liq.";
                begin
                    Message(MsgProcesado, Sinc.ProcesarEntidad("Entidad Sinc NAV"::Empleado));
                    CurrPage.Update(false);
                end;
            }
            action(VolverAPendiente)
            {
                ApplicationArea = All;
                Caption = 'Volver a pendiente';
                Image = Restore;
                ToolTip = 'Marca esta fila para que se vuelva a intentar en el próximo proceso.';

                trigger OnAction()
                begin
                    Rec."Estado Sinc" := "Estado Sinc NAV"::Pendiente;
                    Rec.Intentos := 0;
                    Rec.Modify(true);
                end;
            }
        }
        area(Navigation)
        {
            action(AbrirEmpleado)
            {
                ApplicationArea = All;
                Caption = 'Ficha del empleado';
                Image = Employee;
                RunObject = page "Employee Card";
                RunPageLink = "No." = field("No Empleado");
                ToolTip = 'Abre el empleado en BC para completar convenio y categoría.';
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(Procesar_Promoted; Procesar) { }
                actionref(AbrirEmpleado_Promoted; AbrirEmpleado) { }
                actionref(VolverAPendiente_Promoted; VolverAPendiente) { }
            }
        }
    }

    var
        Estilo: Text;
        MsgProcesado: Label '%1 filas aplicadas.', Comment = '%1 = cantidad';

    trigger OnAfterGetRecord()
    begin
        Estilo := '';
        case Rec."Estado Sinc" of
            "Estado Sinc NAV"::Error:
                Estilo := 'Unfavorable';
            "Estado Sinc NAV"::Pendiente:
                Estilo := 'Ambiguous';
            "Estado Sinc NAV"::Procesado:
                Estilo := 'Favorable';
        end;
    end;
}
