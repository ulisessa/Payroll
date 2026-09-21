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
                action(ListVerAtributos)
                {
                    ApplicationArea = All;
                    Caption = 'Atributos';
                    Image = Dimensions;
                    RunObject = Page "Atributos de Entidad";
                    RunPageLink = "Tipo Entidad" = const(Empleado), "Cód. Entidad" = field("No.");
                    ToolTip = 'Atributos del empleado seleccionado con sus vigencias: convenio, categoría y los que se hayan definido.';
                }
                action(ListVerNovedades)
                {
                    ApplicationArea = All;
                    Caption = 'Novedades';
                    Image = Journal;
                    RunObject = Page "Novedades Liquidación";
                    RunPageLink = "No. Empleado" = field("No.");
                    ToolTip = 'Novedades cargadas para el empleado seleccionado, con su estado: cuáles ya entraron en una liquidación, cuáles siguen pendientes y cuáles el motor descartó con un motivo.';
                }
                action(ListVerFrancos)
                {
                    ApplicationArea = All;
                    Caption = 'Francos';
                    Image = Absence;
                    ToolTip = 'Saldo de francos del empleado seleccionado, abierto por la categoría en que se ganó cada lote. Los francos no son fungibles: se pagan al valor de la categoría en que se devengaron, no a la del encuadre actual.';

                    trigger OnAction()
                    var
                        Francos: Page "Francos por Tripulante";
                    begin
                        Rec.TestField("No.");
                        Francos.SetFiltroEmpleado(Rec."No.");
                        Francos.Run();
                    end;
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

    views
    {
        addlast
        {
            view(PendientesCompletarSinc)
            {
                Caption = 'Pendientes de completar (Sinc.)';
                Filters = where("Cód. Convenio" = filter(''));
                // Los empleados que llegan de NAV traen legajo, nombre, documento y fecha de ingreso,
                // pero no convenio ni categoría: eso se define acá. Mientras el convenio esté en
                // blanco el motor no los liquida, así que esta vista es la lista de trabajo de quien
                // tiene que completarlos, y no hay que acordarse de filtrar a mano.
            }
        }
    }

    var
        MsgEstadoLote: Label '%1 empleado(s) actualizados al estado ''%2'' desde %3.';
}
