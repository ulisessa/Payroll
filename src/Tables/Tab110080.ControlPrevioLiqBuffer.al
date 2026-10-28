namespace UAS.Payroll;

// Resultado de una revisión manual. TableType evita crear almacenamiento físico.
table 110080 "Control Previo Liq. Buffer"
{
    Caption = 'Preparación de liquidaciones';
    TableType = Temporary;
    DataClassification = CustomerContent;

    fields
    {
        field(1; "No. Línea"; Integer) { Caption = 'No. línea'; }
        field(2; Severidad; Enum "Severidad Registro Liq.") { Caption = 'Severidad'; }
        field(3; Área; Text[30]) { Caption = 'Área'; }
        field(4; "Nombre Variable"; Code[60]) { Caption = 'Variable'; }
        field(5; "Cód. Parámetro"; Code[20]) { Caption = 'Parámetro'; }
        field(6; "Cód. Concepto"; Code[20]) { Caption = 'Concepto'; }
        field(7; "No. Empleado"; Code[20]) { Caption = 'Empleado'; }
        field(8; "No. Proyecto"; Code[20]) { Caption = 'Proyecto'; }
        field(9; "Cód. Convenio"; Code[20]) { Caption = 'Convenio'; }
        field(10; "Cód. Categoría"; Code[20]) { Caption = 'Categoría'; }
        field(11; "Cód. Tipo Liq."; Code[20]) { Caption = 'Tipo de liquidación'; }
        field(12; "Fecha Desde"; Date) { Caption = 'Fecha desde'; }
        field(13; "Fecha Hasta"; Date) { Caption = 'Fecha hasta'; }
        field(14; "Vigencia Desde"; Date) { Caption = 'Vigencia del dato'; }
        field(15; Mensaje; Text[250]) { Caption = 'Qué revisar'; }
        field(16; Detalle; Text[2048]) { Caption = 'Detalle'; }
        field(17; "Tipo Entidad"; Enum "Tipo Entidad Estado") { Caption = 'Tipo de entidad'; }
        field(18; "Cód. Entidad"; Code[20]) { Caption = 'Entidad'; }
        field(19; "Cód. Tipo Atributo"; Code[20]) { Caption = 'Atributo'; }
        field(20; "Nombre Fuente"; Code[30]) { Caption = 'Fuente de datos'; }
        field(21; "Clave Parámetro"; Code[50]) { Caption = 'Clave del parámetro'; }
        field(22; Repeticiones; Integer) { Caption = 'Repeticiones'; }
        field(23; "Conceptos relacionados"; Text[2048]) { Caption = 'Conceptos relacionados'; }
    }

    keys
    {
        key(PK; "No. Línea") { Clustered = true; }
        key(SeveridadArea; Severidad, Área, "Nombre Variable", "No. Línea") { }
    }
}
