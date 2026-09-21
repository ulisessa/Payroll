namespace UAS.Payroll;

using Microsoft.Finance.Dimension;
using Microsoft.Finance.GeneralLedger.Setup;

// La entidad operativa: un buque, una planta de proceso, una administración.
//
// Su código es SIEMPRE el del valor de dimensión del que nace, y esa igualdad es lo que sostiene
// todo lo demás: los proyectos se vinculan al buque por Job."Global Dimension 1 Code", los estados
// y los atributos guardan ese mismo string, y el día que "Vessels" se convierta en el maestro
// compartido de 28.0 la convergencia será un cambio de origen y no una migración.
//
// Por eso no se da de alta suelta: se crea desde el valor de dimensión (ver Gestión Entidades Liq.)
// y se renombra con él. Una entidad con un código que no exista como valor de dimensión sería una
// identidad huérfana, y ya hay demasiadas identidades del mismo barco dando vueltas.
table 110008 "Entidad Liq."
{
    Caption = 'Entidad';
    DataClassification = CustomerContent;
    LookupPageId = "Entidades";
    DrillDownPageId = "Entidades";

    fields
    {
        field(1; Código; Code[20])
        {
            Caption = 'Código';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Dimension Value".Code;
            Editable = false;
            // No editable: el código lo fija el valor de dimensión de origen. Cambiarlo se hace
            // renombrando ese valor, y el cascade lo trae hasta acá.
        }
        field(2; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(3; "Cód. Clase"; Code[20])
        {
            Caption = 'Clase';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Clase Entidad Liq.".Código;
            // Obligatoria: la clase es lo que define qué atributos le corresponden, y una entidad
            // sin clase no puede recibir su plantilla. Se exige al dar de alta.
        }
        field(4; "Cant. Atributos"; Integer)
        {
            Caption = 'Atributos cargados';
            FieldClass = FlowField;
            CalcFormula = count("Atributo Entidad Liq." where("Cód. Entidad" = field(Código)));
            Editable = false;
        }
    }

    keys
    {
        key(PK; Código) { Clustered = true; }
        key(K2; "Cód. Clase", Código) { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Código, Descripción, "Cód. Clase") { }
        fieldgroup(Brick; Código, Descripción) { }
    }

    trigger OnInsert()
    begin
        TestField("Cód. Clase");
        ValidarValorDimension();
    end;

    trigger OnDelete()
    var
        Atributo: Record "Atributo Entidad Liq.";
    begin
        Atributo.SetRange("Cód. Entidad", Código);
        if not Atributo.IsEmpty() then
            Error(ErrConAtributos, Código);
    end;

    // El código tiene que existir como valor de dimensión de la dimensión global 1. Sin esta
    // verificación, una entidad podría nacer con un código que no le corresponde a ningún buque ni
    // planta, y quedaría invisible para todo lo que resuelve por dimensión.
    local procedure ValidarValorDimension()
    var
        DimValue: Record "Dimension Value";
        GLSetup: Record "General Ledger Setup";
    begin
        GLSetup.Get();
        GLSetup.TestField("Global Dimension 1 Code");
        if not DimValue.Get(GLSetup."Global Dimension 1 Code", Código) then
            Error(ErrSinValorDimension, Código, GLSetup."Global Dimension 1 Code");
    end;

    var
        ErrConAtributos: Label 'La entidad %1 tiene atributos cargados. Borralos antes de eliminarla.';
        ErrSinValorDimension: Label 'No existe el valor %1 en la dimensión %2. Las entidades se crean desde el valor de dimensión, no de forma suelta.';
}
