namespace UAS.Payroll;

using Microsoft.Projects.Project.Job;

pageextension 50358 "Proyecto Pesca List Ext." extends "Job List"
{
    actions
    {
        addlast(reporting)
        {
            action(ControlLiquidacionExcelList)
            {
                ApplicationArea = All;
                Caption = 'Control de Liquidación (Excel)';
                Image = ExportToExcel;
                Promoted = true;
                PromotedCategory = Report;
                ToolTip = 'Baja a Excel la matriz de control de la marea seleccionada: una fila por concepto y una columna por categoría, con el importe de un tripulante representante de cada una.';

                trigger OnAction()
                var
                    ControlExcel: Codeunit "Control Marea Excel Liq.";
                begin
                    Rec.TestField("No.");
                    ControlExcel.Generar(Rec."No.");
                end;
            }
        }
        addlast(Processing)
        {
            action(ControlLiquidacionList)
            {
                ApplicationArea = All;
                Caption = 'Control de Liquidación';
                Image = Costs;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                RunObject = Page "Control Liquidación Marea";
                RunPageLink = "No." = field("No.");
                ToolTip = 'Matriz de conceptos por tripulante de la marea seleccionada, con los datos de cálculo del viaje y drill-down a cada liquidación.';
            }
            action(CrearNuevaMareaList)
            {
                ApplicationArea = All;
                Caption = 'Crear Nueva Marea';
                Image = NewItem;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Genera un nuevo proyecto (marea) copiando tareas, personal, parámetros y dimensiones del proyecto seleccionado, incrementando la Marea (Dim. Global 2) en uno.';

                trigger OnAction()
                var
                    GestionMarea: Codeunit "Gestión Marea";
                    NuevaJob: Record Job;
                    NuevoNo: Code[20];
                begin
                    Rec.TestField("No.");
                    if not Confirm(QstNuevaMarea, true, Rec."No.") then
                        exit;
                    NuevoNo := GestionMarea.CrearNuevaMarea(Rec);
                    Message(MsgNuevaMarea, NuevoNo);
                    if NuevaJob.Get(NuevoNo) then
                        Page.Run(Page::"Job Card", NuevaJob);
                end;
            }
        }
    }

    var
        QstNuevaMarea: Label 'Crear una nueva marea copiando tareas, personal, parámetros y dimensiones de %1. ¿Continuar?';
        MsgNuevaMarea: Label 'Nueva marea creada: %1.';
}
