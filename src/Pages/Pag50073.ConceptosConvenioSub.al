namespace UAS.Payroll;

page 50073 "Conceptos Convenio Sub"
{
    // List part for the concept ↔ convenio tool. Holds a temporary set of concepts (one per code,
    // latest version) fed by the parent. Rows restricted to ALL currently ticked convenios are
    // highlighted. A diferencia del campo de Tipos Liq., acá la asignación vive en filas de
    // "Concepto CCT Vigente", así que la columna de convenios se arma leyendo esa tabla por fila.
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
                field(Convenios; FConvenios)
                {
                    ApplicationArea = All;
                    Caption = 'Convenios Aplicables';
                    Editable = false;
                    StyleExpr = FEstilo;
                    ToolTip = 'Convenios a los que está restringido el concepto. "(todos)" = sin restricción: aplica a cualquier convenio.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        FConvenios := ConveniosDelConcepto(Rec.Código);
        if AplicaATodosLosTildados(Rec.Código) then
            FEstilo := 'Favorable'
        else
            FEstilo := 'Standard';
    end;

    // Pipe-delimited list of the convenios currently ticked in the parent; drives the row highlight.
    procedure SetConvenios(ConveniosPipe: Text)
    begin
        FConveniosSel := ConveniosPipe;
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

    // Convenios distintos con al menos una fila para el concepto (sin importar la vigencia: el
    // versionado es por convenio, así que si existe alguna fila el convenio está contemplado).
    local procedure ConveniosDelConcepto(CodConcepto: Code[20]): Text
    var
        CCTVig: Record "Concepto CCT Vigente";
        Resultado: Text;
        Excluidos: Text;
        Vistos: List of [Code[20]];
    begin
        CCTVig.SetRange("Cód. Concepto", CodConcepto);
        CCTVig.SetRange(Excluye, false);
        if CCTVig.FindSet() then
            repeat
                if not Vistos.Contains(CCTVig."Cód. Convenio") then begin
                    Vistos.Add(CCTVig."Cód. Convenio");
                    if Resultado <> '' then Resultado += ', ';
                    Resultado += CCTVig."Cód. Convenio";
                end;
            until CCTVig.Next() = 0;

        // Las exclusiones se muestran aparte y no como un convenio más de la lista: significan lo
        // contrario. Sin esto, un concepto "a todos menos ESP" se leía como "solo ESP", que es
        // exactamente al revés de lo que hace el motor.
        Clear(Vistos);
        CCTVig.SetRange(Excluye, true);
        if CCTVig.FindSet() then
            repeat
                if not Vistos.Contains(CCTVig."Cód. Convenio") then begin
                    Vistos.Add(CCTVig."Cód. Convenio");
                    if Excluidos <> '' then Excluidos += ', ';
                    Excluidos += CCTVig."Cód. Convenio";
                end;
            until CCTVig.Next() = 0;

        if Resultado = '' then
            Resultado := TodosTxt;
        if Excluidos <> '' then
            Resultado += StrSubstNo(ExceptoTxt, Excluidos);
        exit(Resultado);
    end;

    // True when the concept is explicitly restricted to EVERY ticked convenio.
    local procedure AplicaATodosLosTildados(CodConcepto: Code[20]): Boolean
    var
        CCTVig: Record "Concepto CCT Vigente";
        Convenio: Text;
    begin
        if FConveniosSel = '' then exit(false);
        foreach Convenio in FConveniosSel.Split('|') do begin
            // Solo inclusiones: esta herramienta administra a qué convenios se ASIGNA el concepto.
            // Las exclusiones se cargan de a una en la subpágina de la ficha, donde se ve qué son.
            CCTVig.SetRange(Excluye, false);
            CCTVig.SetRange("Cód. Concepto", CodConcepto);
            CCTVig.SetRange("Cód. Convenio", CopyStr(Convenio, 1, 20));
            if CCTVig.IsEmpty() then exit(false);
        end;
        exit(true);
    end;

    var
        FConveniosSel: Text;
        FConvenios: Text;
        FEstilo: Text;
        TodosTxt: Label '(todos)';
        ExceptoTxt: Label ' — excepto %1', Comment = '%1=lista de convenios excluidos';
}
