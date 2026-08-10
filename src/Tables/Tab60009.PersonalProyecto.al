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

            trigger OnValidate()
            var
                Emp: Record Employee;
            begin
                if Emp.Get("No. Empleado") then begin
                    if "Cód. Convenio" = '' then
                        "Cód. Convenio" := Emp."Cód. Convenio";
                    if "Cód. Categoría" = '' then
                        "Cód. Categoría" := Emp."Cód. Categoría";
                end;
            end;
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
        field(3; "Cód. Convenio"; Code[20])
        {
            Caption = 'Cód. Convenio';
            DataClassification = CustomerContent;
            TableRelation = "Convenio Colectivo".Código;

            trigger OnValidate()
            begin
                "Cód. Categoría" := '';
            end;
        }
        field(4; "Cód. Categoría"; Code[20])
        {
            Caption = 'Cód. Categoría';
            DataClassification = CustomerContent;
            TableRelation = "Categoría CCT".Código WHERE("Cód. Convenio" = FIELD("Cód. Convenio"));
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
        field(7; "Rol en Proyecto"; Text[50])
        {
            Caption = 'Rol en Proyecto';
            DataClassification = CustomerContent;
        }
        field(8; Buque; Code[10])
        {
            Caption = 'Buque';
            DataClassification = CustomerContent;
            Editable = false;
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
    }

    trigger OnInsert()
    var
        EstadoMgt: Codeunit "Gestión Estado Empleado";
    begin
        TestField("Cód. Convenio");
        TestField("Cód. Categoría");
        EstadoMgt.SincronizarEstadoDesdeProyecto(Rec);
    end;

    trigger OnModify()
    var
        EstadoMgt: Codeunit "Gestión Estado Empleado";
    begin
        EstadoMgt.SincronizarEstadoDesdeProyecto(Rec);
    end;

    trigger OnDelete()
    var
        EstadoMgt: Codeunit "Gestión Estado Empleado";
    begin
        EstadoMgt.EliminarEstadoDeProyecto("No. Empleado", "No. Proyecto");
    end;
}
