namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

pageextension 50356 "Empleado Pesca List Ext." extends "Employee List"
{
    actions
    {
        addlast(Navigation)
        {
            group(GrpLiquidacionList)
            {
                Caption = 'Liquidación';
                Image = PaymentHistory;

                action(ListVerLiquidaciones)
                {
                    ApplicationArea = All;
                    Caption = 'Liquidaciones';
                    Image = PaymentHistory;
                    RunObject = Page "Lista Liquidaciones";
                    RunPageLink = "No. Empleado" = FIELD("No.");
                    ToolTip = 'Ver todas las liquidaciones del empleado seleccionado.';
                }
                action(ListVerEstados)
                {
                    ApplicationArea = All;
                    Caption = 'Historial de Estados';
                    Image = History;
                    RunObject = Page "Estados Empleado";
                    RunPageLink = "No. Empleado" = FIELD("No.");
                    ToolTip = 'Ver el historial de altas y bajas del empleado seleccionado.';
                }
                action(ListVerProyectos)
                {
                    ApplicationArea = All;
                    Caption = 'Proyectos Asignados';
                    Image = Employee;
                    RunObject = Page "Personal Proyecto";
                    RunPageLink = "No. Empleado" = FIELD("No.");
                    ToolTip = 'Ver los proyectos (mareas / plantas) asignados al empleado seleccionado.';
                }
                action(ListVerPrestamos)
                {
                    ApplicationArea = All;
                    Caption = 'Préstamos y Anticipos';
                    Image = Payment;
                    RunObject = Page "Lista Préstamos Empleado";
                    RunPageLink = "No. Empleado" = FIELD("No.");
                    ToolTip = 'Ver los préstamos y anticipos del empleado seleccionado.';
                }
                action(ListNuevoPrestamo)
                {
                    ApplicationArea = All;
                    Caption = 'Nuevo Préstamo / Anticipo';
                    Image = NewDocument;
                    ToolTip = 'Registrar un nuevo préstamo o anticipo para el empleado seleccionado.';
                    trigger OnAction()
                    var
                        Prestamo: Record "Préstamo Empleado";
                        FichaPrestamo: Page "Ficha Préstamo Empleado";
                    begin
                        Clear(Prestamo);
                        Prestamo."No. Empleado" := Rec."No.";
                        Prestamo.Validate("No. Empleado");
                        Prestamo.Fecha := Today();
                        FichaPrestamo.SetRecord(Prestamo);
                        FichaPrestamo.RunModal();
                    end;
                }
            }
        }
        addlast(Processing)
        {
            action(ListCrearLiquidacion)
            {
                ApplicationArea = All;
                Caption = 'Crear Liquidación';
                Image = CreateDocuments;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Crear una liquidación para el empleado seleccionado usando el informe de creación.';
                trigger OnAction()
                var
                    CrearLiqRpt: Report "Crear Liq. para Empleado";
                begin
                    CrearLiqRpt.RunModal();
                end;
            }
            action(ListEstablecerEstadoLote)
            {
                ApplicationArea = All;
                Caption = 'Establecer estado (lote)';
                Image = Change;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Asigna un estado a los empleados seleccionados en una fecha efectiva.';
                trigger OnAction()
                var
                    EmpSel: Record Employee;
                    EstadoMgt: Codeunit "Gestión Estado Empleado";
                    Dlg: Page "Estado en Lote Dialog";
                    CodEstado: Code[20];
                    Fecha: Date;
                    Cantidad: Integer;
                begin
                    CurrPage.SetSelectionFilter(EmpSel);
                    if EmpSel.IsEmpty() then exit;

                    Dlg.Init(WorkDate(), false);
                    if Dlg.RunModal() <> Action::OK then exit;
                    Dlg.GetResultado(CodEstado, Fecha);
                    if (CodEstado = '') or (Fecha = 0D) then exit;

                    Cantidad := EstadoMgt.SetEstadoEnLoteEmpleados(EmpSel, CodEstado, Fecha);
                    Message(MsgEstadoLote, Cantidad, CodEstado, Fecha);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    var
        MsgEstadoLote: Label '%1 empleado(s) actualizados al estado ''%2'' desde %3.';
}
