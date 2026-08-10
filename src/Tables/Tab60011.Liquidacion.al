namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.Projects.Project.Job;

table 60011 "Liquidación"
{
    Caption = 'Liquidación';
    DataClassification = CustomerContent;
    LookupPageId = 50100;
    DrillDownPageId = 50100;

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(2; "Cód. Período"; Code[10])
        {
            Caption = 'Cód. Período';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Período Liquidación".Código;
        }
        field(3; "No. Empleado"; Code[20])
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
                    "Nombre Empleado" := Emp."First Name" + ' ' + Emp."Last Name";
                    "Cód. Convenio" := Emp."Cód. Convenio";
                    "Cód. Categoría" := Emp."Cód. Categoría";
                end;
            end;
        }
        field(4; "Nombre Empleado"; Text[100])
        {
            Caption = 'Nombre Empleado';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(5; "No. Proyecto"; Code[20])
        {
            Caption = 'No. Proyecto (Marea)';
            DataClassification = CustomerContent;
            TableRelation = Job."No.";
        }
        field(6; "Cód. Convenio"; Code[20])
        {
            Caption = 'Cód. Convenio';
            DataClassification = CustomerContent;
            TableRelation = "Convenio Colectivo".Código;
        }
        field(7; "Cód. Categoría"; Code[20])
        {
            Caption = 'Cód. Categoría';
            DataClassification = CustomerContent;
            TableRelation = "Categoría CCT".Código WHERE("Cód. Convenio" = FIELD("Cód. Convenio"));
        }
        field(8; "Fecha Liquidación"; Date)
        {
            Caption = 'Fecha Liquidación';
            DataClassification = CustomerContent;
        }
        field(9; Estado; Enum "Estado Liq.")
        {
            Caption = 'Estado';
            DataClassification = CustomerContent;
        }
        field(30; "Cód. Tipo Liq."; Code[20])
        {
            Caption = 'Tipo Liquidación';
            DataClassification = CustomerContent;
            TableRelation = "Tipo Liquidación".Código;
        }
        field(11; "No. Liq. Origen"; Code[20])
        {
            Caption = 'No. Liq. Origen';
            DataClassification = CustomerContent;
            TableRelation = "Liquidación"."No.";
        }
        // Totals are stored (not FlowField) so they remain stable after period close
        // and support reliquidation comparison. The motor updates them after each run.
        field(20; "Total Haberes"; Decimal)
        {
            Caption = 'Total Haberes';
            DataClassification = CustomerContent;
            Editable = false;
            DecimalPlaces = 2 : 2;
        }
        field(21; "Total Descuentos"; Decimal)
        {
            Caption = 'Total Descuentos';
            DataClassification = CustomerContent;
            Editable = false;
            DecimalPlaces = 2 : 2;
        }
        field(22; "Total Contribuciones"; Decimal)
        {
            Caption = 'Total Contribuciones';
            DataClassification = CustomerContent;
            Editable = false;
            DecimalPlaces = 2 : 2;
        }
        field(23; "Neto a Pagar"; Decimal)
        {
            Caption = 'Neto a Pagar';
            DataClassification = CustomerContent;
            Editable = false;
            DecimalPlaces = 2 : 2;
        }
        field(24; "Haberes Ordinarios Gravados"; Decimal)
        {
            Caption = 'Haberes Ordinarios Gravados';
            DataClassification = CustomerContent;
            Editable = false;
            DecimalPlaces = 2 : 2;
            // Snapshot del acumulador BASE_IG4 al finalizar el cálculo: remunerativo
            // normal y habitual del mes, excluyendo extraordinarios (BASE_EXT_IG4).
            // Permite consultar este valor por mes/empleado vía Fuente Datos Liquidación
            // (ej. MEJOR_REM_SEM para el cálculo del SAC, que debe excluir extraordinarios).
        }
    }

    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
        key(K2; "Cód. Período", "No. Empleado")
        {
        }
        key(K3; "No. Proyecto")
        {
        }
        key(K4; Estado, "Cód. Período")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "No.", "Cód. Período", "No. Empleado", "Nombre Empleado", "Cód. Tipo Liq.", Estado) { }
    }

    trigger OnDelete()
    var
        LinLiq: Record "Línea Liquidación";
        OtraLiq: Record "Liquidación";
        ParamVig: Record "Parámetro Vigente";
        GestNov: Codeunit "Gestión Novedades Liq.";
    begin
        if Estado <> Estado::Borrador then
            Error(ErrEstado);
        LinLiq.SetRange("No. Liquidación", "No.");
        LinLiq.DeleteAll(true);

        // Las novedades que se habían materializado acá vuelven a estar disponibles. Sin esto
        // quedan Aplicada contra una liquidación borrada y no entran nunca más en ninguna.
        GestNov.RevertirLiquidacion("No.");

        // Si después de borrar esta liquidación no quedan liquidaciones en estado
        // calculada/aprobada/contabilizada, liberar todos los bloqueos "En Uso".
        OtraLiq.SetFilter("No.", '<>%1', "No.");
        OtraLiq.SetFilter(Estado, '%1|%2|%3',
            Estado::Calculada, Estado::Aprobada, Estado::Contabilizada);
        if OtraLiq.IsEmpty() then begin
            ParamVig.SetRange("En Uso", true);
            if ParamVig.FindSet(true) then
                repeat
                    ParamVig."En Uso" := false;
                    ParamVig.Modify();
                until ParamVig.Next() = 0;
        end;
    end;

    var
        ErrEstado: Label 'Solo se pueden eliminar liquidaciones en estado Borrador.';
}
