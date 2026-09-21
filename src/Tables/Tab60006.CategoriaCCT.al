namespace UAS.Payroll;

table 60006 "Categoría CCT"
{
    Caption = 'Categoría CCT';
    DataClassification = CustomerContent;
    LookupPageId = "Categorías CCT";
    DrillDownPageId = "Categorías CCT";

    fields
    {
        field(1; "Cód. Convenio"; Code[20])
        {
            Caption = 'Cód. Convenio';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Convenio Colectivo".Código;
        }
        field(2; Código; Code[20])
        {
            Caption = 'Código';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(3; Descripción; Text[100])
        {
            Caption = 'Descripción';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(4; "% Escala"; Decimal)
        {
            Caption = '% Escala';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 4;
            MinValue = 0;
            MaxValue = 999.9999;
        }
        field(5; Observaciones; Text[250])
        {
            Caption = 'Observaciones';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Cód. Convenio", Código)
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Código, Descripción, "% Escala") { }
    }

    // Espejo: ver la nota de Convenio Colectivo. Acá el par (Cód. Convenio, Código) se copia tal
    // cual al valor del atributo, que lleva el convenio como valor padre — las dos tablas tienen la
    // misma forma, así que la copia es campo a campo.
    trigger OnInsert()
    var
        Espejo: Codeunit "Espejo Atributos Liq.";
    begin
        Espejo.AlEscribirCategoria("Cód. Convenio", Código, Descripción, "% Escala");
    end;

    trigger OnModify()
    var
        Espejo: Codeunit "Espejo Atributos Liq.";
    begin
        Espejo.AlEscribirCategoria("Cód. Convenio", Código, Descripción, "% Escala");
    end;

    // Solo el código de la categoría: mover una categoría de convenio es otra cosa —cambia de padre
    // y con ella su historial—, y no se resuelve con un renombrado.
    trigger OnRename()
    var
        Espejo: Codeunit "Espejo Atributos Liq.";
    begin
        if xRec."Cód. Convenio" <> "Cód. Convenio" then
            Error(ErrCambioDeConvenio, xRec."Cód. Convenio", "Cód. Convenio");
        Espejo.AlRenombrarCategoria("Cód. Convenio", xRec.Código, Código);
    end;

    trigger OnDelete()
    var
        Espejo: Codeunit "Espejo Atributos Liq.";
    begin
        Espejo.AlBorrarCategoria("Cód. Convenio", Código);
    end;

    var
        ErrCambioDeConvenio: Label 'No se puede mover una categoría de %1 a %2 renombrándola: el historial de los empleados que la tienen asignada quedaría en el convenio equivocado. Creá la categoría en %2 y cargá la vigencia nueva en cada empleado.', Comment = '%1=convenio origen, %2=convenio destino';
}
