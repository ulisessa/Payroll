namespace UAS.Payroll;

// Qué clase de cosa es un valor de dimensión: buque, planta de proceso, administración.
//
// Hoy la dimensión global 1 mezcla las tres sin nada que las distinga, y esa distinción es la que
// permite que un atributo sepa a qué entidades corresponde: los datos que hacen falta de un barco
// no son los de una planta.
//
// ── Sobre la migración a 28.0 ────────────────────────────────────────────────────────────────
// En 28.0 la tabla "Vessels" pasa al contenedor compartido y el camino natural es que se convierta
// en un maestro de Entidad con esta misma clase adentro. Por eso acá NO se guarda ningún dato de la
// entidad: solo el catálogo de clases. La asignación vive en una extensión de "Dimension Value"
// (ver tableextension "Clase en Dimension Value"), y se referencia siempre por CÓDIGO — que es el
// mismo string hoy como valor de dimensión y mañana como Entidad.Código.
//
// Con eso, cuando exista el maestro compartido, la clase se muda cambiando de dónde se lee: ninguna
// fila se migra, porque la clave nunca cambió.
table 110006 "Clase Entidad Liq."
{
    Caption = 'Clase de Entidad';
    DataClassification = CustomerContent;
    LookupPageId = "Clases de Entidad";
    DrillDownPageId = "Clases de Entidad";

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
        field(3; "Cant. Atributos"; Integer)
        {
            Caption = 'Atributos definidos';
            FieldClass = FlowField;
            CalcFormula = count("Tipo Atributo Liq." where("Cód. Clase" = field(Código)));
            Editable = false;
        }
    }

    keys
    {
        key(PK; Código) { Clustered = true; }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Código, Descripción) { }
    }

    trigger OnDelete()
    var
        TipoAtr: Record "Tipo Atributo Liq.";
    begin
        TipoAtr.SetRange("Cód. Clase", Código);
        if not TipoAtr.IsEmpty() then
            Error(ErrClaseConAtributos, Código);
    end;

    var
        ErrClaseConAtributos: Label 'La clase %1 tiene tipos de atributo asociados. Reasignalos o borralos antes de eliminarla.';
}
