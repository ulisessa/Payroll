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

    var
        ErrInactSiMismo: Label 'El proyecto de inactividad no puede ser el mismo proyecto.';
}
