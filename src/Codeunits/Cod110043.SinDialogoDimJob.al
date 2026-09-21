namespace UAS.Payroll;

using Microsoft.Projects.Project.Job;

/// <summary>
/// Mientras la sincronización con NAV está aplicando proyectos, evita el cuadro de diálogo
/// "Ha cambiado una dimensión. ¿Desea actualizar las líneas?" — y propaga la dimensión a las tareas
/// igual, que es lo que el diálogo iba a hacer.
/// </summary>
/// <remarks>
/// POR QUÉ HACE FALTA. La tabla Job pregunta cada vez que cambia una dimensión global, ANTES de
/// fijarse siquiera si el proyecto tiene tareas. Con 4477 proyectos son 4477 diálogos, y desde una
/// página no hay forma de saltearlos: el `Job` no expone `SetHideValidationDialog` (verificado
/// contra los símbolos de la 25.5), así que el gancho habitual no existe.
///
/// Lo que sí existe es `OnBeforeUpdateJobTaskDimension` con `IsHandled`. Poniéndolo en true, la
/// rutina base no corre —ni el Confirm ni la propagación— y queda a cargo de este suscriptor.
///
/// POR QUÉ PROPAGA EN VEZ DE SALTEAR. Con `IsHandled` solo, el efecto sería el de responder "No":
/// la dimensión del proyecto queda bien —se guarda antes de preguntar— pero las tareas conservan la
/// vieja. Y ése NO es el comportamiento de una corrida desatendida: en el Job Queue `GuiAllowed()`
/// es falso, el Confirm ni se evalúa y la rutina base SÍ actualiza las tareas. Saltear acá haría
/// que el mismo lote diera resultados distintos según se corriera desde la página o desde la
/// entrada de proyecto, que es la clase de diferencia que nadie encuentra después.
///
/// SÓLO DURANTE LA SINCRONIZACIÓN. Fuera de ella el interruptor está apagado y el diálogo aparece
/// como siempre: quien edita un proyecto a mano tiene que seguir decidiendo qué pasa con sus tareas.
/// </remarks>
codeunit 110043 "Sin Dialogo Dim Job"
{
    SingleInstance = true;
    Access = Internal;

    var
        Activo: Boolean;

    procedure Activar()
    begin
        Activo := true;
    end;

    procedure Desactivar()
    begin
        Activo := false;
    end;

    [EventSubscriber(ObjectType::Table, Database::Job, 'OnBeforeUpdateJobTaskDimension', '', false, false)]
    local procedure AlActualizarDimensionDeTareas(Job: Record Job; FieldNumber: Integer; ShortcutDimCode: Code[20]; var IsHandled: Boolean)
    var
        JobTask: Record "Job Task";
    begin
        if not Activo then
            exit;

        IsHandled := true;

        // Misma propagación que hace la rutina base después del Confirm. Se replica en vez de
        // llamarla porque es local: no hay forma de invocarla sin el diálogo.
        JobTask.SetRange("Job No.", Job."No.");
        if JobTask.FindSet(true) then
            repeat
                case FieldNumber of
                    1:
                        JobTask.Validate("Global Dimension 1 Code", ShortcutDimCode);
                    2:
                        JobTask.Validate("Global Dimension 2 Code", ShortcutDimCode);
                end;
                JobTask.Modify();
            until JobTask.Next() = 0;
    end;
}
