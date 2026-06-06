namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

page 50139 "Asistente Fórmula Liq."
{
    ApplicationArea = All;
    Caption = 'Asistente de Fórmulas';
    PageType = Card;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            group(GrpContexto)
            {
                Caption = 'Contexto de prueba';
                field(CodEmpleado; CodEmpleado)
                {
                    ApplicationArea = All;
                    Caption = 'No. Empleado';
                    trigger OnValidate()
                    begin
                        if (CodEmpleado <> '') and (CodPeriodo <> '') then begin
                            DoCargarContextoCompleto();
                            CurrPage.Update(false);
                        end;
                    end;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Emp: Record Employee;
                    begin
                        if Page.RunModal(Page::"Employee List", Emp) = Action::LookupOK then begin
                            CodEmpleado := Emp."No.";
                            Text := Emp."No.";
                            exit(true);
                        end;
                    end;
                }
                field(CodPeriodo; CodPeriodo)
                {
                    ApplicationArea = All;
                    Caption = 'Período';
                    trigger OnValidate()
                    begin
                        if (CodEmpleado <> '') and (CodPeriodo <> '') then begin
                            DoCargarContextoCompleto();
                            CurrPage.Update(false);
                        end;
                    end;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Per: Record "Período Liquidación";
                    begin
                        if Page.RunModal(Page::"Períodos Liquidación", Per) = Action::LookupOK then begin
                            CodPeriodo := Per.Código;
                            Text := Per.Código;
                            exit(true);
                        end;
                    end;
                }
                field(CodConvenio; CodConvenio)
                {
                    ApplicationArea = All;
                    Caption = 'Cód. Convenio';
                    trigger OnValidate()
                    begin
                        CodCategoria := '';
                    end;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Convenio: Record "Convenio Colectivo";
                    begin
                        if Page.RunModal(Page::"Convenios Colectivos", Convenio) = Action::LookupOK then begin
                            CodConvenio := Convenio.Código;
                            CodCategoria := '';
                            Text := Convenio.Código;
                            exit(true);
                        end;
                    end;
                }
                field(CodCategoria; CodCategoria)
                {
                    ApplicationArea = All;
                    Caption = 'Cód. Categoría';
                    trigger OnValidate()
                    begin
                        if (CodEmpleado <> '') and (CodPeriodo <> '') then begin
                            DoCargarContextoCompleto();
                            CurrPage.Update(false);
                        end;
                    end;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Categoria: Record "Categoría CCT";
                    begin
                        Categoria.SetRange("Cód. Convenio", CodConvenio);
                        if Page.RunModal(Page::"Categorías CCT", Categoria) = Action::LookupOK then begin
                            CodCategoria := Categoria.Código;
                            Text := Categoria.Código;
                            if (CodEmpleado <> '') and (CodPeriodo <> '') then begin
                                DoCargarContextoCompleto();
                                CurrPage.Update(false);
                            end;
                            exit(true);
                        end;
                    end;
                }
                field(TipoLiqCtx; TipoLiqCtx)
                {
                    ApplicationArea = All;
                    Caption = 'Tipo Liquidación';
                    ToolTip = 'Tipo de liquidación a simular. Afecta TIPO_LIQ en el contexto.';
                    trigger OnValidate()
                    begin
                        if (CodEmpleado <> '') and (CodPeriodo <> '') then begin
                            DoCargarContextoCompleto();
                            CurrPage.Update(false);
                        end;
                    end;
                }
            }
            group(GrpFormula)
            {
                Caption = 'Fórmula';
                field(FormulaText; FormulaText)
                {
                    ApplicationArea = All;
                    Caption = 'Fórmula';
                    MultiLine = true;
                    StyleExpr = StyleFormula;
                    ToolTip = 'Expresión aritmética. Funciones: TRAMO(''cod'',val), ROUND(val,prec), ABS(val), MAX(a,b), MIN(a,b).';
                    trigger OnValidate()
                    begin
                        ValidarSintaxis(FormulaText, StyleFormula);
                    end;
                }
                field(CondicionText; CondicionText)
                {
                    ApplicationArea = All;
                    Caption = 'Condición (opcional)';
                    MultiLine = true;
                    StyleExpr = StyleCondicion;
                    ToolTip = 'Expresión booleana. Vacía = siempre activo.';
                    trigger OnValidate()
                    begin
                        ValidarSintaxisCondicion(CondicionText, StyleCondicion);
                    end;
                }
            }
            group(GrpResultado)
            {
                Caption = 'Resultado';
                field(ResultadoImporte; ResultadoImporte)
                {
                    ApplicationArea = All;
                    Caption = 'Importe calculado';
                    Editable = false;
                    DecimalPlaces = 2 : 6;
                    StyleExpr = StyleResultado;
                }
                field(CondicionActiva; CondicionActiva)
                {
                    ApplicationArea = All;
                    Caption = 'Condición activa';
                    Editable = false;
                }
                field(MensajeResultado; MensajeResultado)
                {
                    ApplicationArea = All;
                    Caption = 'Mensaje';
                    Editable = false;
                    MultiLine = true;
                    StyleExpr = StyleMensaje;
                }
            }
            part(Variables; "Variables Liq. Test Sub")
            {
                ApplicationArea = All;
                Caption = 'Variables (doble clic = insertar en fórmula)';
                UpdatePropagation = Both;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CargarVariables)
            {
                ApplicationArea = All;
                Caption = 'Cargar variables';
                Image = Refresh;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Carga parámetros vigentes y acumuladores con sus valores reales. Los marcados como "editable" se pueden ajustar para simular distintos escenarios.';
                trigger OnAction()
                begin
                    CargarVariablesStd();
                    CurrPage.Update(false);
                end;
            }
            action(CargarContextoCompleto)
            {
                ApplicationArea = All;
                Caption = 'Cargar contexto completo';
                Image = RefreshLines;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Carga todas las variables del contexto real para el empleado y período indicados, incluyendo Fuente Datos (DIAS_VAC, INCID_*, etc.). Requiere No. Empleado y Período.';
                trigger OnAction()
                begin
                    DoCargarContextoCompleto();
                    CurrPage.Update(false);
                end;
            }
            action(AutoCompletar)
            {
                ApplicationArea = All;
                Caption = 'Auto-completar';
                Image = Find;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Completa la última palabra de la fórmula con variables disponibles o funciones. Si hay varias coincidencias muestra un menú de selección.';
                trigger OnAction()
                begin
                    DoAutoCompletar();
                    CurrPage.Update(false);
                end;
            }
            action(Evaluar)
            {
                ApplicationArea = All;
                Caption = 'Evaluar';
                Image = Calculate;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Evalúa la fórmula y condición con los valores de prueba ingresados.';
                trigger OnAction()
                begin
                    EvaluarFormula();
                    CurrPage.Update(false);
                end;
            }
            group(GrpFunciones)
            {
                Caption = 'Insertar';
                Image = Insert;
                ToolTip = 'Inserta una función u operador al final de la fórmula.';

                group(GrpFnAritmeticas)
                {
                    Caption = 'Funciones';

                    action(InsABS)
                    {
                        ApplicationArea = All;
                        Caption = 'ABS( )';
                        ToolTip = 'Valor absoluto. ABS(valor)';
                        trigger OnAction()
                        begin InsertText('ABS('); end;
                    }
                    action(InsROUND)
                    {
                        ApplicationArea = All;
                        Caption = 'ROUND( , )';
                        ToolTip = 'Redondeo. ROUND(valor, precisión). Ej: ROUND(x, 0.01)';
                        trigger OnAction()
                        begin InsertText('ROUND('); end;
                    }
                    action(InsMAX)
                    {
                        ApplicationArea = All;
                        Caption = 'MAX( , )';
                        ToolTip = 'Máximo de dos valores. MAX(a, b)';
                        trigger OnAction()
                        begin InsertText('MAX('); end;
                    }
                    action(InsMIN)
                    {
                        ApplicationArea = All;
                        Caption = 'MIN( , )';
                        ToolTip = 'Mínimo de dos valores. MIN(a, b)';
                        trigger OnAction()
                        begin InsertText('MIN('); end;
                    }
                    action(InsIF)
                    {
                        ApplicationArea = All;
                        Caption = 'IF( , , )';
                        ToolTip = 'Condicional. IF(condición, valor_si_true, valor_si_false). Todos los argumentos se evalúan antes de elegir la rama.';
                        trigger OnAction()
                        begin InsertText('IF('); end;
                    }
                    action(InsDIV)
                    {
                        ApplicationArea = All;
                        Caption = 'DIV( , )';
                        ToolTip = 'División segura: devuelve 0 si el divisor es 0. DIV(a, b)';
                        trigger OnAction()
                        begin InsertText('DIV('); end;
                    }
                    action(InsTRAMO)
                    {
                        ApplicationArea = All;
                        Caption = 'TRAMO( , )';
                        ToolTip = 'Consulta tabla escalonada. TRAMO(''código'', valor). Ej: TRAMO(''TAB_IMP_4CAT'', BASE_IG4 * 12)';
                        trigger OnAction()
                        begin InsertText('TRAMO('); end;
                    }
                }
                group(GrpOperadores)
                {
                    Caption = 'Operadores (Condición)';

                    action(InsAND)
                    {
                        ApplicationArea = All;
                        Caption = 'AND';
                        ToolTip = 'Conjunción lógica. Ej: ANIOS_ANTIGUEDAD >= 2 AND BASE_SS > 0';
                        trigger OnAction()
                        begin InsertText(' AND '); end;
                    }
                    action(InsOR)
                    {
                        ApplicationArea = All;
                        Caption = 'OR';
                        ToolTip = 'Disyunción lógica. Ej: DIAS_MAR = 0 OR BASE_SS = 0';
                        trigger OnAction()
                        begin InsertText(' OR '); end;
                    }
                    action(InsNOT)
                    {
                        ApplicationArea = All;
                        Caption = 'NOT';
                        ToolTip = 'Negación lógica. Ej: NOT DIAS_MAR = 0';
                        trigger OnAction()
                        begin InsertText('NOT '); end;
                    }
                }
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    var
        Pendiente: Text[100];
    begin
        // Pick up any variable inserted from the subpage row action
        Pendiente := CurrPage.Variables.Page.GetAndClearPendingInsert();
        if Pendiente <> '' then begin
            if FormulaText <> '' then
                FormulaText += ' ';
            FormulaText += Pendiente;
            ValidarSintaxis(FormulaText, StyleFormula);
        end;
    end;

    var
        FormulaText: Text[500];
        CondicionText: Text[500];
        ResultadoImporte: Decimal;
        CondicionActiva: Boolean;
        MensajeResultado: Text[500];
        StyleFormula: Text[50];
        StyleCondicion: Text[50];
        StyleResultado: Text[50];
        StyleMensaje: Text[50];
        CodEmpleado: Code[20];
        CodPeriodo: Code[10];
        CodConvenio: Code[20];
        CodCategoria: Code[20];
        TipoLiqCtx: Enum "Tipo Liq.";

    procedure SetFormula(Formula: Text[500]; Condicion: Text[500])
    begin
        FormulaText := Formula;
        CondicionText := Condicion;
    end;

    local procedure CargarVariablesStd()
    var
        CategoriaCCT: Record "Categoría CCT";
        Concepto: Record "Concepto Liquidación";
    begin
        SetVar('BASICO', GetParam('BASICO_' + CodConvenio + '_' + CodCategoria), 'Básico del convenio/categoría — editable', 'Parámetro');
        SetVar('TC_COMPRADOR', GetParam('TC_COMPRADOR'), 'Tipo de cambio comprador', 'Parámetro');
        SetVar('SMVM', GetParam('SMVM'), 'Salario mínimo vital y móvil', 'Parámetro');

        if (CodConvenio <> '') and CategoriaCCT.Get(CodConvenio, CodCategoria) then
            SetVar('PCT_ESCALA', CategoriaCCT."% Escala" / 100, 'Escala ' + CodCategoria, 'Sistema')
        else
            SetVar('PCT_ESCALA', 1, 'Escala (editable)', 'Sistema');

        SetVar('ANIOS_ANTIGUEDAD', 0, 'Años de antigüedad — editable', 'Sistema');
        SetVar('DIAS_MAR', 0, 'Días de marea — editable', 'Sistema');
        SetVar('DIAS_HAB', 22, 'Días hábiles del período — editable', 'Sistema');

        SetVar('TOPE_SIPA',    GetParam('TOPE_SIPA'),    'Tope imponible SIPA (jub/19032)', 'Parámetro');
        SetVar('TOPE_SIPA_OS', GetParam('TOPE_SIPA_OS'), 'Tope imponible SIPA (obra social)', 'Parámetro');

        SetVar('MNI_ANUAL',     GetParam('MNI_ANUAL'),     'MNI anual Ganancias 4ta', 'Parámetro');
        SetVar('DEDUCCION_ESP', GetParam('DEDUCCION_ESP'), 'Deducción especial anual Ganancias 4ta', 'Parámetro');
        SetVar('DEDUC_GANANCIAS', 0,                       'Deducción ganancias empleado — editable', 'Sistema');

        SetVar('PCT_ANTIG', GetParam('PCT_ANTIG'), 'Porcentaje antigüedad por año (0.01 = 1%)', 'Parámetro');

        SetVar('PCT_JUB',          GetParam('PCT_JUB'),          'Aporte jubilación empleado (11%)', 'Parámetro');
        SetVar('PCT_19032',        GetParam('PCT_19032'),        'Aporte Ley 19032 empleado (3%)', 'Parámetro');
        SetVar('PCT_OS',           GetParam('PCT_OS'),           'Aporte obra social empleado (3%)', 'Parámetro');
        SetVar('PCT_ADICIONAL_OS', GetParam('PCT_ADICIONAL_OS'), 'Aporte adicional OS empleado (1.5%)', 'Parámetro');

        SetVar('PCT_CONT_JUB',   GetParam('PCT_CONT_JUB'),   'Contrib. patronal jubilación (10.77%)', 'Parámetro');
        SetVar('PCT_CONT_23660', GetParam('PCT_CONT_23660'), 'Contrib. patronal OS Ley 23660 (6%)', 'Parámetro');
        SetVar('PCT_CONT_19032', GetParam('PCT_CONT_19032'), 'Contrib. patronal Ley 19032 (1.59%)', 'Parámetro');
        SetVar('PCT_ART',        GetParam('PCT_ART'),        'Contrib. patronal ART porcentaje (5.51%)', 'Parámetro');
        SetVar('VALOR_ART_FIJO', GetParam('VALOR_ART_FIJO'), 'Contrib. patronal ART valor fijo/mes', 'Parámetro');

        SetVar('REMUNERATIVO_BRUTO', 0, 'Acumulador remunerativo — editable', 'Acumulador');
        SetVar('NO_REMUNERATIVO', 0, 'Acumulador no remunerativo', 'Acumulador');
        SetVar('TOTAL_DESCUENTOS', 0, 'Acumulador descuentos', 'Acumulador');

        Concepto.SetRange("Es Acumulador", true);
        Concepto.SetRange(Activo, true);
        if Concepto.FindSet() then
            repeat
                SetVar(Concepto.Código, 0, 'Acumulador: ' + Concepto.Descripción, 'Acumulador');
            until Concepto.Next() = 0;
    end;

    local procedure DoCargarContextoCompleto()
    var
        CtxBuilder: Codeunit "Contexto Liquidación";
        Periodo: Record "Período Liquidación";
        Ctx: Dictionary of [Text, Decimal];
        TipoMap: Dictionary of [Text, Text];
    begin
        if CodEmpleado = '' then begin
            Message('Ingresá un No. Empleado para cargar el contexto completo.');
            exit;
        end;
        if CodPeriodo = '' then begin
            Message('Ingresá un Período para cargar el contexto completo.');
            exit;
        end;
        if not Periodo.Get(CodPeriodo) then begin
            Message('El período %1 no existe.', CodPeriodo);
            exit;
        end;
        CtxBuilder.Init(CodEmpleado, '', CodPeriodo, Periodo."Fecha Hasta", CodConvenio, CodCategoria, '', TipoLiqCtx);
        CtxBuilder.BuildContext(Ctx);
        CtxBuilder.GetTipoMap(TipoMap);
        CurrPage.Variables.Page.LoadFromContext(Ctx, TipoMap);
    end;

    local procedure EvaluarFormula()
    var
        Evaluador: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        ImporteResult: Decimal;
        CondResult: Boolean;
    begin
        ResultadoImporte := 0;
        CondicionActiva := false;
        MensajeResultado := '';
        StyleResultado := 'Subordinate';
        StyleMensaje := '';

        if FormulaText.Trim() = '' then begin
            MensajeResultado := 'Ingresá una fórmula.';
            StyleMensaje := 'Attention';
            exit;
        end;

        CurrPage.Variables.Page.GetContext(Ctx);
        Evaluador.Init(Ctx, WorkDate());

        if CondicionText.Trim() <> '' then begin
            if not Evaluador.TryEvalCondicion(CondicionText, CondResult) then begin
                MensajeResultado := 'Error en condición: ' + GetLastErrorText();
                StyleMensaje := 'Unfavorable';
                exit;
            end;
            CondicionActiva := CondResult;
        end else
            CondicionActiva := true;

        if not Evaluador.TryEvalFormula(FormulaText, ImporteResult) then begin
            MensajeResultado := GetLastErrorText();
            StyleMensaje := 'Unfavorable';
            StyleFormula := 'Unfavorable';
            exit;
        end;

        ResultadoImporte := ImporteResult;
        MensajeResultado := 'Sin errores.';
        StyleResultado := 'Favorable';
        StyleMensaje := 'Favorable';
        StyleFormula := 'Favorable';
    end;

    local procedure ValidarSintaxis(Formula: Text; var StyleExprVar: Text[50])
    var
        Evaluador: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Dummy: Decimal;
    begin
        if Formula.Trim() = '' then begin
            StyleExprVar := '';
            exit;
        end;
        CurrPage.Variables.Page.GetContext(Ctx);
        if Ctx.Count = 0 then exit; // no variables loaded yet — skip
        Evaluador.Init(Ctx, WorkDate());
        if Evaluador.TryEvalFormula(Formula, Dummy) then
            StyleExprVar := 'Favorable'
        else
            StyleExprVar := 'Unfavorable';
    end;

    local procedure ValidarSintaxisCondicion(Condicion: Text; var StyleExprVar: Text[50])
    var
        Evaluador: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Dummy: Boolean;
    begin
        if Condicion.Trim() = '' then begin
            StyleExprVar := '';
            exit;
        end;
        CurrPage.Variables.Page.GetContext(Ctx);
        if Ctx.Count = 0 then exit;
        Evaluador.Init(Ctx, WorkDate());
        if Evaluador.TryEvalCondicion(Condicion, Dummy) then
            StyleExprVar := 'Favorable'
        else
            StyleExprVar := 'Unfavorable';
    end;

    // ── Auto-complete ─────────────────────────────────────────────────────────

    local procedure DoAutoCompletar()
    var
        Prefix: Text;
        Matches: List of [Text];
        Selected: Text;
    begin
        Prefix := GetLastPartialWord(FormulaText);
        BuildMatches(Prefix, Matches);

        case Matches.Count of
            0:
                if Prefix <> '' then
                    Message('No hay coincidencias para "%1".', Prefix)
                else
                    Message('Posicioná el cursor al final de una palabra parcial antes de auto-completar.');
            1:
                begin
                    Selected := Matches.Get(1);
                    ReplaceLastWord(FormulaText, Selected);
                    ValidarSintaxis(FormulaText, StyleFormula);
                end;
            else begin
                if PickFromList(Matches, Selected) then begin
                    ReplaceLastWord(FormulaText, Selected);
                    ValidarSintaxis(FormulaText, StyleFormula);
                end;
            end;
        end;
    end;

    local procedure GetLastPartialWord(FullText: Text): Text
    var
        Upper: Text;
        i: Integer;
        C: Char;
        Word: Text;
    begin
        Upper := FullText.ToUpper();
        i := StrLen(Upper);
        while i >= 1 do begin
            C := Upper[i];
            if ((C >= 'A') and (C <= 'Z')) or ((C >= '0') and (C <= '9')) or (C = '_') then begin
                Word := CopyStr(Upper, i, 1) + Word;
                i -= 1;
            end else
                break;
        end;
        exit(Word);
    end;

    local procedure ReplaceLastWord(var FullText: Text[500]; NewWord: Text)
    var
        Partial: Text;
        PrefixLen: Integer;
    begin
        Partial := GetLastPartialWord(FullText);
        PrefixLen := StrLen(FullText) - StrLen(Partial);
        FullText := CopyStr(FullText, 1, PrefixLen) + NewWord;
    end;

    local procedure BuildMatches(Prefix: Text; var Matches: List of [Text])
    var
        Ctx: Dictionary of [Text, Decimal];
        Keys: List of [Text];
        CtxKey: Text;
    begin
        // Built-in functions
        AddIfMatch('ABS', Prefix, Matches);
        AddIfMatch('DIV', Prefix, Matches);
        AddIfMatch('IF', Prefix, Matches);
        AddIfMatch('MAX', Prefix, Matches);
        AddIfMatch('MIN', Prefix, Matches);
        AddIfMatch('ROUND', Prefix, Matches);
        AddIfMatch('TRAMO', Prefix, Matches);

        // Variables from test context
        CurrPage.Variables.Page.GetContext(Ctx);
        Keys := Ctx.Keys();
        foreach CtxKey in Keys do
            AddIfMatch(CtxKey, Prefix, Matches);
    end;

    local procedure AddIfMatch(Candidate: Text; Prefix: Text; var Matches: List of [Text])
    begin
        if (Prefix = '') or Candidate.StartsWith(Prefix) then
            if not Matches.Contains(Candidate) then
                Matches.Add(Candidate);
    end;

    local procedure PickFromList(var Options: List of [Text]; var Selected: Text): Boolean
    var
        MenuStr: Text;
        i: Integer;
        Idx: Integer;
    begin
        for i := 1 to Options.Count do begin
            if i > 1 then MenuStr += ',';
            MenuStr += Options.Get(i);
        end;
        Idx := StrMenu(MenuStr, 1, 'Seleccioná una variable o función:');
        if Idx = 0 then exit(false);
        Selected := Options.Get(Idx);
        exit(true);
    end;

    // ── Helpers ───────────────────────────────────────────────────────────────

    local procedure SetVar(VarNombre: Text[100]; VarValor: Decimal; VarDesc: Text[100]; VarTipo: Text[20])
    begin
        CurrPage.Variables.Page.SetVariable(VarNombre, VarValor, VarDesc, VarTipo);
    end;

    local procedure InsertText(Token: Text)
    begin
        if FormulaText <> '' then
            FormulaText += ' ';
        FormulaText += Token;
        ValidarSintaxis(FormulaText, StyleFormula);
        CurrPage.Update(false);
    end;

    local procedure GetParam(Codigo: Code[20]): Decimal
    var
        Param: Record "Parámetro Vigente";
    begin
        Param.SetRange("Cód. Parámetro", Codigo);
        Param.SetFilter("Vigencia Desde", '<=%1', WorkDate());
        if Param.FindLast() then
            exit(Param.Valor);
        exit(0);
    end;
}
