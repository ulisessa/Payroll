namespace UAS.Payroll;

page 50194 "Conceptos Tipo Liq. Sub"
{
    // List part for the concept ↔ liquidation-type tool. Holds a temporary set of concepts (one per code,
    // latest version) fed by the parent. Rows that apply to ALL currently ticked types are highlighted.
    PageType = ListPart;
    Caption = 'Conceptos';
    SourceTable = "Concepto Liquidación";
    SourceTableTemporary = true;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; StyleExpr = FEstilo; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; StyleExpr = FEstilo; }
                field("Tipo Concepto"; Rec."Tipo Concepto") { ApplicationArea = All; StyleExpr = FEstilo; }
                field("Tipos Liq. Aplicables"; Rec."Tipos Liq. Aplicables")
                {
                    ApplicationArea = All;
                    Caption = 'Tipos Aplicables';
                    StyleExpr = FEstilo;
                    ToolTip = 'Tipos de liquidación a los que aplica el concepto. Vacío = aplica a todos.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        if AplicaATodos(Rec."Tipos Liq. Aplicables") then
            FEstilo := 'Favorable'
        else
            FEstilo := 'Standard';
    end;

    // Pipe-delimited list of the types currently ticked in the parent; drives the row highlight.
    procedure SetTipos(TiposPipe: Text)
    begin
        FTiposSel := TiposPipe;
    end;

    // Replaces the shown set with the concepts in Origen.
    procedure CargarLista(var Origen: Record "Concepto Liquidación" temporary)
    begin
        Rec.Reset();
        Rec.DeleteAll();
        if Origen.FindSet() then
            repeat
                Rec := Origen;
                Rec.Insert();
            until Origen.Next() = 0;
        CurrPage.Update(false);
    end;

    // Returns the multi-selected rows into Destino.
    procedure GetSeleccionados(var Destino: Record "Concepto Liquidación" temporary)
    begin
        Destino.Reset();
        Destino.DeleteAll();
        CurrPage.SetSelectionFilter(Rec);
        if Rec.FindSet() then
            repeat
                Destino := Rec;
                Destino.Insert();
            until Rec.Next() = 0;
        Rec.Reset();
    end;

    local procedure AplicaATodos(Texto: Text): Boolean
    var
        Tipo: Text;
    begin
        if FTiposSel = '' then exit(false);
        foreach Tipo in FTiposSel.Split('|') do
            if not ContieneTipo(Texto, Tipo) then exit(false);
        exit(true);
    end;

    local procedure ContieneTipo(Texto: Text; Tipo: Text): Boolean
    begin
        // Empty = no explicit assignment → NOT counted as included for the tool's highlight/filter.
        if Texto = '' then exit(false);
        exit(('|' + Texto + '|').Contains('|' + Tipo + '|'));
    end;

    var
        FTiposSel: Text;
        FEstilo: Text;
}
