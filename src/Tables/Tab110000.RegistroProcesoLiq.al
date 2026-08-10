namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using System.Security.AccessControl;

table 110000 "Registro Proceso Liq."
{
    Caption = 'Registro de Proceso';
    DataClassification = CustomerContent;
    LookupPageId = "Registros Proceso Liq.";
    DrillDownPageId = "Registros Proceso Liq.";
    // Un registro por operación sobre una liquidación (calcular, aprobar, reabrir, revertir,
    // eliminar). Las entradas hijas guardan lo que pasó adentro: errores, advertencias y acciones.
    //
    // Antes de esto, una advertencia vivía en un Text en memoria que se perdía al cerrar el mensaje,
    // y un error de cálculo no dejaba ningún rastro: la liquidación quedaba a medias y no había
    // forma de saber qué había fallado ni cuándo.

    fields
    {
        field(1; "No. Registro"; Integer)
        {
            Caption = 'No. Registro';
            AutoIncrement = true;
            DataClassification = CustomerContent;
        }
        field(2; "No. Sesión"; Guid)
        {
            Caption = 'No. Sesión';
            DataClassification = CustomerContent;
            // Comparten sesión todos los registros de una misma corrida por lote, para poder ver de
            // un saque cómo salió un proceso de 200 empleados.
        }
        field(10; "Tipo Proceso"; Enum "Tipo Proceso Liq.")
        {
            Caption = 'Tipo Proceso';
            DataClassification = CustomerContent;
        }
        field(11; "No. Liquidación"; Code[20])
        {
            Caption = 'No. Liquidación';
            DataClassification = CustomerContent;
            TableRelation = "Liquidación"."No.";
        }
        field(12; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            DataClassification = CustomerContent;
            TableRelation = Employee."No.";
        }
        field(13; "Nombre Empleado"; Text[100])
        {
            Caption = 'Nombre Empleado';
            DataClassification = CustomerContent;
        }
        field(14; "Cód. Período"; Code[10])
        {
            Caption = 'Cód. Período';
            DataClassification = CustomerContent;
            TableRelation = "Período Liquidación".Código;
        }
        field(15; "Cód. Tipo Liq."; Code[20])
        {
            Caption = 'Cód. Tipo Liq.';
            DataClassification = CustomerContent;
            TableRelation = "Tipo Liquidación".Código;
        }
        field(20; "Fecha Hora Inicio"; DateTime)
        {
            Caption = 'Inicio';
            DataClassification = CustomerContent;
        }
        field(21; "Fecha Hora Fin"; DateTime)
        {
            Caption = 'Fin';
            DataClassification = CustomerContent;
        }
        field(22; "Duración (ms)"; Integer)
        {
            Caption = 'Duración (ms)';
            DataClassification = CustomerContent;
        }
        field(23; Usuario; Code[50])
        {
            Caption = 'Usuario';
            DataClassification = EndUserIdentifiableInformation;
            TableRelation = User."User Name";
        }
        field(30; Resultado; Enum "Severidad Registro Liq.")
        {
            Caption = 'Resultado';
            DataClassification = CustomerContent;
            // Severidad máxima de las entradas: Información = salió limpio.
        }
        field(31; "Cant. Errores"; Integer)
        {
            Caption = 'Errores';
            DataClassification = CustomerContent;
        }
        field(32; "Cant. Advertencias"; Integer)
        {
            Caption = 'Advertencias';
            DataClassification = CustomerContent;
        }
        field(33; Mensaje; Text[250])
        {
            Caption = 'Mensaje';
            DataClassification = CustomerContent;
            // Primer error, o la primera advertencia si no hubo errores: lo que se lee en la grilla
            // sin tener que abrir el detalle.
        }
        field(34; "Cant. Entradas"; Integer)
        {
            Caption = 'Entradas';
            FieldClass = FlowField;
            CalcFormula = Count("Entrada Registro Liq." WHERE("No. Registro" = FIELD("No. Registro")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "No. Registro") { Clustered = true; }
        key(K2; "No. Liquidación", "Fecha Hora Inicio") { }
        key(K3; "No. Sesión") { }
        key(K4; Resultado, "Fecha Hora Inicio") { }
        key(K5; "Cód. Período", "Fecha Hora Inicio") { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "No. Registro", "Tipo Proceso", "No. Liquidación", Resultado) { }
    }

    trigger OnDelete()
    var
        Entrada: Record "Entrada Registro Liq.";
    begin
        Entrada.SetRange("No. Registro", "No. Registro");
        Entrada.DeleteAll();
    end;

    procedure MostrarEntradas()
    var
        Entrada: Record "Entrada Registro Liq.";
    begin
        Entrada.SetRange("No. Registro", "No. Registro");
        Page.Run(Page::"Entradas Registro Liq.", Entrada);
    end;
}
