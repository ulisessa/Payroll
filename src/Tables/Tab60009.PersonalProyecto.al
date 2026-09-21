namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.Projects.Project.Job;


table 60009 "Personal Proyecto"
{
    Caption = 'Personal Proyecto';
    DataClassification = CustomerContent;
    // Links an Employee to a Job. Covers fishing tides (Mareas), administrative assignments,
    // and processing-plant assignments.

    fields
    {
        field(1; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = Employee."No.";
        }
        field(2; "No. Proyecto"; Code[20])
        {
            Caption = 'No. Proyecto';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = Job."No.";

            trigger OnValidate()
            var
                Job: Record Job;
            begin
                if Job.Get("No. Proyecto") then begin
                    Buque := Job."Global Dimension 1 Code";
                    Marea := Job."Global Dimension 2 Code";
                    // Inherit the project dates only where the assignment leaves them blank
                    // (a per-employee override, once entered, keeps priority).
                    if "Fecha Alta Asignación" = 0D then
                        "Fecha Alta Asignación" := Job."Starting Date";
                    if "Fecha Baja" = 0D then
                        "Fecha Baja" := Job."Ending Date";
                end;
            end;
        }
        field(5; "Fecha Alta Asignación"; Date)
        {
            Caption = 'Fecha Alta Asignación';
            DataClassification = CustomerContent;
            // Drives the linked Estado Empleado "Fecha Inicio" (synced on Insert/Modify).
        }
        field(6; "Fecha Baja"; Date)
        {
            Caption = 'Fecha Baja';
            DataClassification = CustomerContent;
            // Informational assignment end. In the effective-dated state model the arrival transition
            // (embarcado → francos/órdenes) is created by the Cierre Marea automation, not stored here.
        }
        field(8; Buque; Code[20])
        {
            Caption = 'Buque';
            DataClassification = CustomerContent;
            Editable = false;
            // Code[20] y no Code[10]: se copia desde Job."Global Dimension 1 Code", que es Code[20].
            // Con el largo anterior, un código de más de diez caracteres se truncaba en silencio al
            // copiarse y quedaban dos identidades del mismo buque sin que nada lo delatara.
        }
        field(9; Marea; Code[10])
        {
            Caption = 'Marea';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(10; Observaciones; Text[250])
        {
            Caption = 'Observaciones';
            DataClassification = CustomerContent;
        }
        field(11; "Nombre Empleado"; Text[100])
        {
            Caption = 'Nombre Empleado';
            FieldClass = FlowField;
            CalcFormula = Lookup(Employee."First Name" WHERE("No." = FIELD("No. Empleado")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "No. Empleado", "No. Proyecto")
        {
            Clustered = true;
        }
        key(K2; "No. Proyecto")
        {
        }
        key(K3; Buque, Marea)
        {
        }
        // "La última asignación del empleado antes de tal fecha", que es como se resuelve su convenio
        // y categoría de origen. La clave primaria ordena por proyecto, así que sin ésta había que
        // traer todo el historial del empleado y recorrerlo para quedarse con la más reciente.
        key(K4; "No. Empleado", "Fecha Alta Asignación")
        {
        }
    }

    trigger OnInsert()
    var
        EstadoMgt: Codeunit "Gestión Estado Empleado";
    begin
        EstadoMgt.SincronizarEstadoDesdeProyecto(Rec);
    end;

    trigger OnModify()
    var
        EstadoMgt: Codeunit "Gestión Estado Empleado";
    begin
        EstadoMgt.SincronizarEstadoDesdeProyecto(Rec);
        // Recién al COMPLETAR la fecha de baja —no en cada modificación— se encadena lo que sigue:
        // el estado siguiente al día posterior y el alta en el proyecto que lo tenga como
        // predeterminado. Si esa cadena no se puede armar, el error revierte también el cierre de
        // esta asignación: es preferible que la fecha de baja no se guarde a que se guarde dejando
        // al empleado sin estado desde el día siguiente.
        if (xRec."Fecha Baja" = 0D) and ("Fecha Baja" <> 0D) then
            EstadoMgt.EncadenarSiguienteAsignacion(Rec);
    end;

    trigger OnDelete()
    var
        EstadoMgt: Codeunit "Gestión Estado Empleado";
    begin
        EstadoMgt.EliminarEstadoDeProyecto("No. Empleado", "No. Proyecto");
    end;

    // SIN VALIDACIÓN DE LA BAJA CONTRA LA FECHA DE ARRIBO DEL PROYECTO, y vale la pena dejar escrito
    // por qué, porque parece que tendría que haberla.
    //
    // La regla suena evidente —nadie sigue asignado a una marea después de que la marea terminó— y
    // se escribió así en un primer momento: Error si "Fecha Baja" > Job."Ending Date". Los datos la
    // desmintieron. La ventana del Job cubre SÓLO la navegación, y hay estados de marea que caen
    // legítimamente afuera:
    //
    //   · PL (puerto llegada) — 1.587 casos, TODOS entre uno y tres días DESPUÉS del arribo.
    //     Ninguno más lejos. Es el día de puerto de la llegada, y es parte de la marea.
    //   · PS (puerto salida)  — 9.221 de 10.004 hasta tres días ANTES de la zarpada: el tripulante
    //     sube a preparar el barco, o espera un día de más para relevar a alguien que sigue a bordo.
    //
    // Como la asignación se deriva del primero y el último estado del empleado en ese proyecto, su
    // baja cae en el PL y queda después del arribo. Validarla contra "Ending Date" rechazaría dato
    // correcto, y encima recién al editar la fila, mucho después de haberla escrito.
    //
    // El límite real no es la fecha de arribo sino la PRÓXIMA ZARPADA DEL BUQUE: ahí sí, si un
    // estado de esta marea empieza cuando el barco ya salió de nuevo, está apuntando a una marea que
    // ya fue reemplazada. Esa validación es la que tiene sentido escribir, y necesita la marea
    // siguiente del mismo buque — un dato que esta tabla no tiene a mano.
    //
    // Lo que sí quedó cubierto de este problema: los GP/DQ/PI que colgaban de la marea equivocada se
    // separan con "Transcurre en Marea" (Tab60003), que es donde estaba la causa de fondo.
}
