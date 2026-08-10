namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

table 60026 "Importación SIRADIG"
{
    Caption = 'Importación SIRADIG';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "No."; Integer)
        {
            Caption = 'No.';
            AutoIncrement = true;
        }
        field(2; "CUIL Empleado"; Code[20])
        {
            Caption = 'CUIL Empleado';
            NotBlank = true;
        }
        field(3; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            TableRelation = Employee."No.";
        }
        field(4; "Período"; Integer)
        {
            Caption = 'Período';
            NotBlank = true;
        }
        field(5; "Nro. Presentación"; Integer)
        {
            Caption = 'Nro. Presentación';
        }
        field(6; "Fecha Presentación"; Date)
        {
            Caption = 'Fecha Presentación';
        }
        field(7; "Archivo Origen"; Text[250])
        {
            Caption = 'Archivo Origen';
        }
        field(8; "Fecha Importación"; DateTime)
        {
            Caption = 'Fecha Importación';
            Editable = false;
        }
        field(9; "Usuario Importación"; Code[50])
        {
            Caption = 'Usuario Importación';
            Editable = false;
        }
        field(10; Estado; Enum "Estado Importación SIRADIG")
        {
            Caption = 'Estado';
            InitValue = "Pendiente Procesar";
        }
        field(11; "Deducciones Importadas"; Integer)
        {
            Caption = 'Deducciones Importadas';
            Editable = false;
        }
        field(12; "Cargas Familia Importadas"; Integer)
        {
            Caption = 'Cargas de Familia Importadas';
            Editable = false;
        }
        field(13; "Mensajes Error"; Text[500])
        {
            Caption = 'Mensajes Error';
            Editable = false;
        }
        field(14; "AFIP Register Entry No."; Integer)
        {
            Caption = 'AFIP Register Entry No.';
            Editable = false;
            TableRelation = "AFIP Interface Register"."Entry no.";
        }
    }

    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
        key(K2; "CUIL Empleado", "Período", "Nro. Presentación")
        {
        }
        key(K3; Estado, "Fecha Importación")
        {
        }
    }
}
