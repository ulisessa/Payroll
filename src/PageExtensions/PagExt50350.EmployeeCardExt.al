namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

pageextension 50350 "Empleado Pesca Card Ext." extends "Employee Card"
{
    layout
    {
        addlast(General)
        {
            group(Liquidación)
            {
                Caption = 'Liquidación';

                field("Cód. Convenio"; Rec."Cód. Convenio")
                {
                    ApplicationArea = All;
                    ToolTip = 'Convenio colectivo de trabajo aplicable por defecto. Se hereda a cada nueva asignación de proyecto.';
                }
                field("Cód. Categoría"; Rec."Cód. Categoría")
                {
                    ApplicationArea = All;
                    ToolTip = 'Categoría dentro del CCT. Define el % de escala sobre el básico.';
                }
                field("Antigüedad Reconocida"; Rec."Antigüedad Reconocida")
                {
                    ApplicationArea = All;
                    ToolTip = 'Años de antigüedad reconocida como base. El sistema suma los años completos desde el último alta laboral.';
                }
                field("Fecha Jubilación"; Rec."Fecha Jubilación")
                {
                    ApplicationArea = All;
                    ToolTip = 'Fecha desde la cual el empleado es jubilado. Vacío = no es jubilado.';
                }
                field("Zona Desfavorable"; Rec."Zona Desfavorable")
                {
                    ApplicationArea = All;
                    ToolTip = 'Código de zona desfavorable del empleado. Se usa como valor por defecto si el proyecto no tiene zona asignada.';
                }
            }
        }
        addafter(General)
        {
            part(DeduccionesGanancias; "Ded. Ganancias Empleado Sub")
            {
                ApplicationArea = All;
                Caption = 'Deducciones Ganancias 4ta Cat.';
                SubPageLink = "No. Empleado" = FIELD("No.");
            }
        }
        addlast(FactBoxes)
        {
            part(EstadoActual; "Estado Empleado FactBox")
            {
                ApplicationArea = All;
                Caption = 'Estado Actual';
                SubPageLink = "No. Empleado" = FIELD("No.");
            }
        }
    }

    actions
    {
        addlast(Navigation)
        {
            group(GrpLiquidacion)
            {
                Caption = 'Liquidación';
                Image = PaymentHistory;

                action(VerEstados)
                {
                    ApplicationArea = All;
                    Caption = 'Historial de Estados';
                    Image = History;
                    RunObject = Page "Estados Empleado";
                    RunPageLink = "No. Empleado" = FIELD("No.");
                }
                action(VerLiquidaciones)
                {
                    ApplicationArea = All;
                    Caption = 'Liquidaciones';
                    Image = PaymentHistory;
                    RunObject = Page "Lista Liquidaciones";
                    RunPageLink = "No. Empleado" = FIELD("No.");
                }
                action(VerTripulaciones)
                {
                    ApplicationArea = All;
                    Caption = 'Proyectos Asignados';
                    Image = Employee;
                    RunObject = Page "Personal Proyecto";
                    RunPageLink = "No. Empleado" = FIELD("No.");
                }
                action(VerPrestamos)
                {
                    ApplicationArea = All;
                    Caption = 'Préstamos y Anticipos';
                    Image = Payment;
                    RunObject = Page "Lista Préstamos Empleado";
                    RunPageLink = "No. Empleado" = FIELD("No.");
                    ToolTip = 'Ver y gestionar los préstamos y anticipos del empleado.';
                }
                action(NuevoPrestamo)
                {
                    ApplicationArea = All;
                    Caption = 'Nuevo Préstamo / Anticipo';
                    Image = NewDocument;
                    ToolTip = 'Registrar un nuevo préstamo o anticipo para este empleado.';
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
    }
}
