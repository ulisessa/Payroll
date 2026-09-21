namespace UAS.Payroll;

// Conceptos cuya fórmula o condición NO se puede parsear.
//
// El control de sintaxis del campo corta al validarlo, pero hay tres caminos que no pasan por ahí:
// el editor con IntelliSense —que guarda con asignación directa porque emite mientras se tipea—,
// la importación por ConfigPackage y cualquier carga por SQL. Por esos tres, una fórmula rota se
// guarda y no la mira nadie hasta que falla una liquidación: con el concepto ya versionado, en
// producción, y con el error apareciendo de a un empleado por vez.
//
// Esta pantalla corre la MISMA pasada que la fase 1 del motor, pero sin necesitar una liquidación.
// Es la diferencia entre enterarse al guardar y enterarse el día que hay que pagar.
//
// Solo sintaxis, no variables desconocidas: una variable que todavía no existe es una advertencia
// razonable mientras se configura —el parámetro puede cargarse después— pero un paréntesis sin
// cerrar no se arregla solo nunca.
page 110045 "Fórmulas con Errores"
{
    ApplicationArea = All;
    Caption = 'Fórmulas con errores de sintaxis';
    PageType = List;
    UsageCategory = Administration;
    SourceTable = "Concepto Liquidación";
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código)
                {
                    ApplicationArea = All;
                    Style = Attention;
                }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field("Vigencia Hasta"; Rec."Vigencia Hasta")
                {
                    ApplicationArea = All;
                    ToolTip = 'En blanco = vigencia abierta. Las versiones ya discontinuadas no se listan: no las va a volver a evaluar nadie.';
                }
                field(Campo; CampoConError)
                {
                    ApplicationArea = All;
                    Caption = 'Dónde';
                    ToolTip = 'Si el error está en la fórmula o en la condición del concepto.';
                }
                field(Error; TextoError)
                {
                    ApplicationArea = All;
                    Caption = 'Error';
                    ToolTip = 'Lo que dice el evaluador al intentar parsearla. Es el mismo mensaje con el que fallaría el cálculo.';
                }
                field("Orden Cálculo"; Rec."Orden Cálculo") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Abrir)
            {
                ApplicationArea = All;
                Caption = 'Abrir concepto';
                Image = Card;
                ToolTip = 'Abre la ficha del concepto para corregir la fórmula.';
                trigger OnAction()
                var
                    Concepto: Record "Concepto Liquidación";
                begin
                    Concepto.SetRange(Código, Rec.Código);
                    Concepto.SetRange("Vigencia Desde", Rec."Vigencia Desde");
                    Page.Run(Page::"Concepto Liq. Card", Concepto);
                end;
            }
            action(Revisar)
            {
                ApplicationArea = All;
                Caption = 'Revisar de nuevo';
                Image = Refresh;
                ToolTip = 'Vuelve a parsear todas las fórmulas y rehace la lista.';
                trigger OnAction()
                begin
                    MarcarRotas();
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';
                actionref(RevisarProm; Revisar) { }
                actionref(AbrirProm; Abrir) { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        MarcarRotas();
    end;

    trigger OnAfterGetRecord()
    begin
        Analizar();
    end;

    /// <remarks>
    /// Se recorre y se marca en vez de filtrar: "no parsea" no es una condición que se pueda
    /// expresar como filtro de tabla — hay que intentar evaluar cada fórmula para saberlo.
    ///
    /// Se descartan las versiones ya discontinuadas. Una que cerró el año pasado no la va a volver a
    /// evaluar nadie, y listarla sería ruido que esconde lo que sí importa. Las FUTURAS en cambio se
    /// listan: van a romper el día que entren en vigencia, y ese es justo el momento en que uno no
    /// quiere enterarse.
    /// </remarks>
    local procedure MarcarRotas()
    var
        Concepto: Record "Concepto Liquidación";
        Encontradas: Integer;
    begin
        Rec.Reset();
        Rec.ClearMarks();

        Concepto.SetFilter("Vigencia Hasta", '%1|>=%2', 0D, WorkDate());
        if Concepto.FindSet() then
            repeat
                if ErrorDeConcepto(Concepto) <> '' then
                    if Rec.Get(Concepto.Código, Concepto."Vigencia Desde") then begin
                        Rec.Mark(true);
                        Encontradas += 1;
                    end;
            until Concepto.Next() = 0;

        Rec.MarkedOnly(true);
        if Encontradas = 0 then
            Message(MsgTodoBien);
    end;

    local procedure Analizar()
    begin
        TextoError := CopyStr(ErrorDeConcepto(Rec), 1, MaxStrLen(TextoError));
        if TextoError = '' then
            CampoConError := ''
        else
            if EsDeLaCondicion then
                CampoConError := TxtCondicion
            else
                CampoConError := TxtFormula;
    end;

    /// <summary>El error de sintaxis del concepto, o vacío. Deja anotado en cuál de los dos campos.</summary>
    /// <remarks>
    /// Modo indulgente, igual que la primera pasada del OnValidate del campo: con el contexto vacío,
    /// lo que depende del VALOR —dividir por una variable en cero, pedir un tramo que no existe— no
    /// dice nada de la fórmula. Lo que se busca acá es lo estructural, que es lo que no se arregla
    /// solo.
    /// </remarks>
    local procedure ErrorDeConcepto(Concepto: Record "Concepto Liquidación"): Text
    var
        Eval: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Importe: Decimal;
        Cumple: Boolean;
    begin
        EsDeLaCondicion := false;

        if Concepto.Fórmula <> '' then begin
            Eval.Init(Ctx, WorkDate());
            Eval.SetLenientMode(true);
            if not Eval.TryEvalFormula(Concepto.Fórmula, Importe) then
                exit(GetLastErrorText());
        end;

        if Concepto.Condición <> '' then begin
            Eval.Init(Ctx, WorkDate());
            Eval.SetLenientMode(true);
            if not Eval.TryEvalCondicion(Concepto.Condición, Cumple) then begin
                EsDeLaCondicion := true;
                exit(GetLastErrorText());
            end;
        end;

        exit('');
    end;

    var
        CampoConError: Text[30];
        TextoError: Text[250];
        EsDeLaCondicion: Boolean;
        TxtFormula: Label 'Fórmula';
        TxtCondicion: Label 'Condición';
        MsgTodoBien: Label 'Ninguna fórmula ni condición vigente tiene errores de sintaxis.';
}
