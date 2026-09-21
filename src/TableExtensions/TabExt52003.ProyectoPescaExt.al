namespace UAS.Payroll;

using Microsoft.Projects.Project.Job;

tableextension 52003 "Proyecto Pesca Ext." extends Job
{
    fields
    {
        field(52020; "Estado Liq. Personal Predet."; Code[20])
        {
            Caption = 'Estado Liq. Personal Predet.';
            DataClassification = CustomerContent;
            TableRelation = "Cód. Estado Empleado".Código;
            // Al asignar un empleado a este proyecto (Personal Proyecto."Fecha Alta Asignación"),
            // este estado se asigna automáticamente en su historial (Estado Empleado) vía SetEstado.
        }
        field(52021; "Zona Desfavorable"; Integer)
        {
            Caption = 'Zona Desfavorable';
            DataClassification = CustomerContent;
            MinValue = 0;
            // Zona (adicional patagónico/desfavorable) del viaje: toda la dotación de la marea la comparte.
            // El motor la inyecta como COD_ZONA; si es 0 cae al valor de la ficha del empleado.
            // Es la RED: si hay una Fuente de Datos llamada COD_ZONA —el camino para tomar la zona
            // del atributo con historial— manda esa y estos dos campos no se leen.
        }
        field(52022; "Proyecto Inactividad Nómina"; Code[20])
        {
            Caption = 'Proyecto Inactividad Nómina';
            DataClassification = CustomerContent;
            TableRelation = Job."No.";
            // Al pasar un empleado de un estado activo (que devenga francos) a uno inactivo, se lo asigna
            // automáticamente a este proyecto. Si está en blanco, se usa el "Proyecto Nómina" de Config. HHRR.

            trigger OnValidate()
            begin
                if "Proyecto Inactividad Nómina" = "No." then
                    Error(ErrInactSiMismo);
            end;
        }
    }

    /// <remarks>
    /// Cargar la fecha de arribo ES cerrar la marea. Hasta ahora eso no arrastraba nada: las
    /// asignaciones quedaban abiertas y, con ellas, los estados de navegación — el tripulante seguía
    /// "navegando" en un buque que ya estaba en puerto.
    ///
    /// Sólo dispara cuando la fecha de arribo pasa de vacía a cargada. Corregirla después no vuelve a
    /// cerrar nada: las asignaciones ya tienen su baja y reabrirlas en cadena sería peor que el error
    /// que se estaría corrigiendo.
    /// </remarks>
    trigger OnModify()
    var
        EstadoMgt: Codeunit "Gestión Estado Empleado";
    begin
        if (xRec."Ending Date" = 0D) and ("Ending Date" <> 0D) then
            EstadoMgt.CerrarAsignacionesDeProyecto("No.", "Ending Date");
    end;

    var
        ErrInactSiMismo: Label 'El proyecto de inactividad no puede ser el mismo proyecto.';
}
