namespace UAS.Payroll;

// El equivalente a una Dimensión de BC: define QUÉ se puede cargar, no el valor.
//
// Existe para que un dato que importa al cálculo —zona desfavorable, obra social, régimen horario—
// se pueda agregar como configuración y no como campo nuevo en una tabla. El motor no necesita
// enterarse: se llega a él con una fila de "Fuente Datos Liquidación" apuntando a esta estructura.
table 110003 "Tipo Atributo Liq."
{
    Caption = 'Tipo de Atributo';
    DataClassification = CustomerContent;
    LookupPageId = "Tipos de Atributo";
    DrillDownPageId = "Tipos de Atributo";

    fields
    {
        field(1; Código; Code[20])
        {
            Caption = 'Código';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(2; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(3; "Tipo Dato"; Enum "Tipo Dato Atributo Liq.")
        {
            Caption = 'Tipo de Dato';
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                Atributo: Record "Atributo Entidad Liq.";
            begin
                // Cambiar el tipo dejaría las asignaciones existentes con el valor en una columna
                // que ya no corresponde, y su proyección numérica congelada con la regla vieja.
                if "Tipo Dato" = xRec."Tipo Dato" then
                    exit;
                Atributo.SetRange("Cód. Tipo Atributo", Código);
                if not Atributo.IsEmpty() then
                    Error(ErrTipoConDatos, Código);
            end;
        }
        field(4; "Tipo Entidad"; Enum "Tipo Entidad Estado")
        {
            Caption = 'Se carga en';
            DataClassification = CustomerContent;
            // A qué maestro se le cuelga: empleado, buque o proyecto (marea).
        }
        field(5; Obligatorio; Boolean)
        {
            Caption = 'Obligatorio';
            DataClassification = CustomerContent;
            // Informativo por ahora: marca los que se esperan cargados en toda entidad. No bloquea
            // la liquidación, porque un atributo faltante debe avisar, no impedir que se pague.
        }
        field(6; "Nombre Variable"; Code[30])
        {
            Caption = 'Nombre Variable Sugerido';
            DataClassification = CustomerContent;
            // Solo documentación: el nombre real con el que la fórmula ve este atributo lo define la
            // fila de "Fuente Datos Liquidación" que lo lee. Se guarda acá para que quien configura
            // sepa qué escribir en las dos puntas.
            //
            // En MAYÚSCULAS a propósito: el evaluador pasa la fórmula entera por ToUpper antes de
            // resolver, así que una variable con minúsculas nunca se encuentra.
            trigger OnValidate()
            begin
                "Nombre Variable" := UpperCase("Nombre Variable");
            end;
        }
    }

    keys
    {
        key(PK; Código) { Clustered = true; }
        key(K2; "Tipo Entidad", Código) { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Código, Descripción, "Tipo Dato") { }
        fieldgroup(Brick; Código, Descripción) { }
    }

    trigger OnDelete()
    var
        Valor: Record "Valor Atributo Liq.";
        Atributo: Record "Atributo Entidad Liq.";
    begin
        Atributo.SetRange("Cód. Tipo Atributo", Código);
        if not Atributo.IsEmpty() then
            Error(ErrTipoConDatos, Código);
        Valor.SetRange("Cód. Tipo Atributo", Código);
        Valor.DeleteAll();
    end;

    /// <summary>
    /// True si el valor de este atributo se elige de una lista cerrada.
    /// </summary>
    procedure UsaLista(): Boolean
    begin
        exit("Tipo Dato" = "Tipo Dato"::Lista);
    end;

    var
        ErrTipoConDatos: Label 'El tipo de atributo %1 ya tiene valores cargados en entidades. Borrá esas asignaciones antes de cambiarlo o eliminarlo.';
}
