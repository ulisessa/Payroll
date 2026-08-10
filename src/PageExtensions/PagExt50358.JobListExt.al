namespace UAS.Payroll;

using Microsoft.Projects.Project.Job;

pageextension 50358 "Proyecto Pesca List Ext." extends "Job List"
{
    actions
    {
        addlast(Processing)
        {
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
