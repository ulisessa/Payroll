namespace UAS.Payroll;

using System.Security.AccessControl;

table 110002 "Historial Fórmula Concepto"
{
    Caption = 'Historial de Cambios de Fórmula';
    DataClassification = CustomerContent;
    LookupPageId = "Historial Fórmulas Concepto";
    DrillDownPageId = "Historial Fórmulas Concepto";
    // Quién cambió la fórmula (o la condición) de un concepto, cuándo, y de qué texto a qué texto.
    //
    // No lo cubría nada: "Historial de Fórmulas" en la ficha lista las VIGENCIAS del concepto — el
    // versionado por fecha — pero editar la fórmula de una vigencia existente sobrescribía el texto
    // sin dejar rastro. El Change Log de BC tampoco sirve acá: guarda valores en Text[250] y una
    // fórmula puede tener hasta 2048 caracteres, así que llegaría truncada.

    fields
    {
        field(1; "No. Entrada"; Integer)
        {
            Caption = 'No. Entrada';
            AutoIncrement = true;
            DataClassification = CustomerContent;
        }
        field(10; "Cód. Concepto"; Code[20])
        {
            Caption = 'Cód. Concepto';
            DataClassification = CustomerContent;
            TableRelation = "Concepto Liquidación".Código;
        }
        field(11; "Vigencia Desde"; Date)
        {
            Caption = 'Vigencia';
            DataClassification = CustomerContent;
            // Qué versión del concepto se tocó: el historial es por vigencia, no por código.
        }
        field(12; "Descripción Concepto"; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(20; "Fecha Hora"; DateTime)
        {
            Caption = 'Fecha Hora';
            DataClassification = CustomerContent;
            // Cuándo EMPEZÓ la sesión de edición. No se toca después: es la referencia contra la
            // que se mide la ventana de agrupación, y además el orden de la lista. Si avanzara con
            // cada tecleo, la ventana no se cerraría nunca y la entrada saltaría al tope de la
            // pantalla mientras se escribe. Lo último editado va en "Última Edición".
        }
        field(23; "Última Edición"; DateTime)
        {
            Caption = 'Última Edición';
            DataClassification = CustomerContent;
            // Cuándo se guardó por última vez dentro de la misma sesión. Igual a "Fecha Hora" si la
            // sesión tuvo un solo guardado.
        }
        field(21; Usuario; Code[50])
        {
            Caption = 'Usuario';
            DataClassification = EndUserIdentifiableInformation;
            TableRelation = User."User Name";
        }
        field(22; "Tipo Cambio"; Enum "Tipo Cambio Fórmula")
        {
            Caption = 'Tipo Cambio';
            DataClassification = CustomerContent;
        }
        field(30; "Fórmula Anterior"; Text[2048])
        {
            Caption = 'Fórmula Anterior';
            DataClassification = CustomerContent;
        }
        field(31; "Fórmula Nueva"; Text[2048])
        {
            Caption = 'Fórmula Nueva';
            DataClassification = CustomerContent;
        }
        field(32; "Condición Anterior"; Text[2048])
        {
            Caption = 'Condición Anterior';
            DataClassification = CustomerContent;
        }
        field(33; "Condición Nueva"; Text[2048])
        {
            Caption = 'Condición Nueva';
            DataClassification = CustomerContent;
        }
        field(34; "Cambió Fórmula"; Boolean)
        {
            Caption = 'Cambió Fórmula';
            DataClassification = CustomerContent;
        }
        field(35; "Cambió Condición"; Boolean)
        {
            Caption = 'Cambió Condición';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "No. Entrada") { Clustered = true; }
        key(K2; "Cód. Concepto", "Vigencia Desde", "Fecha Hora") { }
        key(K3; "Fecha Hora") { }
        key(K4; Usuario, "Fecha Hora") { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Fecha Hora", "Cód. Concepto", Usuario, "Tipo Cambio") { }
    }

    /// <summary>Texto corto para la grilla: una fórmula de 2048 caracteres no entra en una columna.</summary>
    procedure ResumenCambio(): Text
    begin
        if "Tipo Cambio" = "Tipo Cambio"::Eliminación then
            exit("Fórmula Anterior");
        exit("Fórmula Nueva");
    end;
}
