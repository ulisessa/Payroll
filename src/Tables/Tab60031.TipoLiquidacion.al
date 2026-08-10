namespace UAS.Payroll;

table 50578 "Tipo Liquidación"
{
    // Configurable master of liquidation types, replacing the hard-coded enum. Generic types are pure data;
    // types with special engine behaviour are marked with a flag (there is no code keyed to a specific code).
    Caption = 'Tipo Liquidación';
    DataClassification = CustomerContent;
    LookupPageId = "Tipos Liquidación";
    DrillDownPageId = "Tipos Liquidación";

    fields
    {
        field(1; Código; Code[20])
        {
            Caption = 'Código';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(2; Descripción; Text[50])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(3; Orden; Integer)
        {
            Caption = 'Orden';
            DataClassification = CustomerContent;
            // Also feeds the TIPO_LIQ formula variable (Cod50016) — must stay unique so two types never
            // resolve to the same number in a concept's Fórmula/Condición.
            trigger OnValidate()
            begin
                ValidarOrdenUnico();
            end;
        }
        field(4; "Liquida al Arribo"; Boolean)
        {
            Caption = 'Liquida al Arribo';
            DataClassification = CustomerContent;
            // Cierre de Marea behaviour: reference date = arrival (Job Ending), coverage up to arrival,
            // job/personnel filters by arrival/discharge instead of period end.
        }
        field(5; "Incluye Francos Puerto"; Boolean)
        {
            Caption = 'Incluye Francos en Puerto';
            DataClassification = CustomerContent;
            // When created for a period, also generates project-less liquidations for employees enjoying
            // francos in port (was the Regular behaviour).
        }
        field(6; Activo; Boolean)
        {
            Caption = 'Activo';
            DataClassification = CustomerContent;
            InitValue = true;
        }
    }

    keys
    {
        key(PK; Código) { Clustered = true; }
        key(Orden; Orden) { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Código, Descripción) { }
    }

    trigger OnInsert()
    begin
        ValidarOrdenUnico();
    end;

    trigger OnModify()
    begin
        ValidarOrdenUnico();
    end;

    // Guards TIPO_LIQ correctness: two types resolving to the same formula number would make a concept
    // condition like IF(TIPO_LIQ = 70, ...) ambiguously match both. Runs on every insert/modify — not just
    // the field's own OnValidate — so programmatic inserts (e.g. Cod50055.Sembrar) are covered too.
    local procedure ValidarOrdenUnico()
    var
        Otro: Record "Tipo Liquidación";
    begin
        Otro.SetRange(Orden, Orden);
        Otro.SetFilter(Código, '<>%1', Código);
        if Otro.FindFirst() then
            Error(ErrOrdenDuplicado, Orden, Otro.Código);
    end;

    // Code of the type flagged "Liquida al Arribo" (Cierre de Marea). Errors if none is configured.
    procedure CodigoArribo(): Code[20]
    var
        TipoLiq: Record "Tipo Liquidación";
    begin
        TipoLiq.SetRange("Liquida al Arribo", true);
        if TipoLiq.FindFirst() then
            exit(TipoLiq.Código);
        Error(ErrSinArribo);
    end;

    // Code of the type flagged "Incluye Francos Puerto" (Regular), or '' if none.
    procedure CodigoFrancosPuerto(): Code[20]
    var
        TipoLiq: Record "Tipo Liquidación";
    begin
        TipoLiq.SetRange("Incluye Francos Puerto", true);
        if TipoLiq.FindFirst() then
            exit(TipoLiq.Código);
        exit('');
    end;

    procedure EsArribo(Codigo: Code[20]): Boolean
    var
        TipoLiq: Record "Tipo Liquidación";
    begin
        exit(TipoLiq.Get(Codigo) and TipoLiq."Liquida al Arribo");
    end;

    var
        ErrSinArribo: Label 'No hay ningún Tipo de Liquidación marcado como "Liquida al Arribo" (Cierre de Marea).';
        ErrOrdenDuplicado: Label 'El Orden %1 ya está usado por el tipo ''%2''. Cada tipo debe tener un Orden distinto (también se usa como valor de TIPO_LIQ en fórmulas).';
}
