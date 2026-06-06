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

                action(EstablecerEstado)
                {
                    ApplicationArea = All;
                    Caption = 'Establecer Estado...';
                    Image = NewRow;
                    Promoted = true;
                    PromotedCategory = Process;
                    ToolTip = 'Establece un nuevo estado laboral para el empleado, cerrando el estado actual automáticamente.';

                    trigger OnAction()
                    var
                        NuevoEstadoPag: Page "Nuevo Estado Empleado";
                        EstadoMgt: Codeunit "Gestión Estado Empleado";
                        CodEstado: Code[20];
                        FechaInicio: Date;
                        Obs: Text[250];
                        NombreEmp: Text[100];
                    begin
                        NombreEmp := Rec."First Name" + ' ' + Rec."Last Name";
                        NuevoEstadoPag.SetEmpleado(Rec."No.", NombreEmp);
                        if NuevoEstadoPag.RunModal() = Action::OK then begin
                            NuevoEstadoPag.GetResultado(CodEstado, FechaInicio, Obs);
                            EstadoMgt.SetEstado(Rec."No.", CodEstado, FechaInicio);
                        end;
                    end;
                }
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
            }
        }
    }
}
