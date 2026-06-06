namespace UAS.Payroll;

codeunit 50015 "Evaluador Fórmula"
{
    // Recursive-descent parser for payroll formula expressions.
    //
    // Grammar:
    //   Formula    = OrExpr
    //   OrExpr     = AndExpr ('OR' AndExpr)*
    //   AndExpr    = NotExpr ('AND' NotExpr)*
    //   NotExpr    = 'NOT' NotExpr | Compare
    //   Compare    = AddSub (('='|'<>'|'<'|'>'|'<='|'>=') AddSub)?
    //   AddSub     = MulDiv (('+' | '-') MulDiv)*
    //   MulDiv     = Unary  (('*' | '/') Unary)*
    //   Unary      = '-' Unary | Primary
    //   Primary    = Number | StringLit | '(' OrExpr ')' | Ident ('(' ArgList ')')?
    //   ArgList    = OrExpr (',' OrExpr)*
    //
    // Built-in functions: TRAMO(code, value)
    // All other identifiers are resolved from the variable context dictionary.
    // String literals use single quotes: 'RET_4CAT'

    var
        FExpr: Text;
        FPos: Integer;
        FLen: Integer;
        FTokKind: Option None,Number,Ident,StrLit,Plus,Minus,Star,Slash,LPar,RPar,Comma,EOF,Eq,NEq,Lt,Gt,LEq,GEq;
        FTokText: Text;
        FTokNum: Decimal;
        FContext: Dictionary of [Text, Decimal];
        FFechaRef: Date;
        FParamLog: Text;
        FResolvedVars: Dictionary of [Text, Boolean]; // tracks which vars were actually used
        FLenient: Boolean; // when true, unknown variables resolve to 0 instead of throwing

    procedure Init(var Ctx: Dictionary of [Text, Decimal]; FechaRef: Date)
    begin
        FContext := Ctx;
        FFechaRef := FechaRef;
        FParamLog := '';
        Clear(FResolvedVars);
    end;

    // Call this (instead of Init) when only the context needs refreshing mid-calculation.
    // Does NOT reset the param log or resolved-vars tracking.
    procedure UpdateContext(var Ctx: Dictionary of [Text, Decimal])
    begin
        FContext := Ctx;
    end;

    procedure EvalFormula(Formula: Text): Decimal
    begin
        if Formula.Trim() = '' then
            exit(0);
        BeginParse(Formula.ToUpper().Trim());
        exit(ParseAddSub());
    end;

    procedure EvalCondicion(Condicion: Text): Boolean
    begin
        if Condicion.Trim() = '' then
            exit(true);
        BeginParse(Condicion.ToUpper().Trim());
        exit(ParseOr() <> 0);
    end;

    procedure GetParamLog(): Text
    begin
        exit(FParamLog);
    end;

    // Returns the VAR: entries accumulated since the last flush (or since Init),
    // then resets both the log and the resolved-vars dictionary so the next concept
    // starts with a clean slate.  Call once per concept, after EvalFormula.
    procedure FlushConceptLog(): Text
    var
        Log: Text;
    begin
        Log := FParamLog;
        FParamLog := '';
        Clear(FResolvedVars);
        exit(Log);
    end;

    [TryFunction]
    procedure TryEvalFormula(Formula: Text; var Result: Decimal)
    begin
        Result := EvalFormula(Formula);
    end;

    [TryFunction]
    procedure TryEvalCondicion(Condicion: Text; var Result: Boolean)
    begin
        Result := EvalCondicion(Condicion);
    end;

    // ── Parser entry ──────────────────────────────────────────────────────────

    local procedure BeginParse(Expr: Text)
    begin
        FExpr := Expr;
        FPos := 1;
        FLen := StrLen(FExpr);
        NextTok();
    end;

    local procedure ParseOr(): Decimal
    var
        Left: Decimal;
    begin
        Left := ParseAnd();
        while FTokKind = FTokKind::Ident do begin
            if FTokText <> 'OR' then
                break;
            NextTok();
            if ParseAnd() <> 0 then
                Left := 1
            else
                if Left <> 0 then
                    Left := 1;
        end;
        exit(Left);
    end;

    local procedure ParseAnd(): Decimal
    var
        Left: Decimal;
    begin
        Left := ParseNot();
        while FTokKind = FTokKind::Ident do begin
            if FTokText <> 'AND' then
                break;
            NextTok();
            if (Left <> 0) and (ParseNot() <> 0) then
                Left := 1
            else
                Left := 0;
        end;
        exit(Left);
    end;

    local procedure ParseNot(): Decimal
    begin
        if (FTokKind = FTokKind::Ident) and (FTokText = 'NOT') then begin
            NextTok();
            if ParseNot() = 0 then
                exit(1)
            else
                exit(0);
        end;
        exit(ParseCompare());
    end;

    local procedure ParseCompare(): Decimal
    var
        Left: Decimal;
        Op: Option None,Number,Ident,StrLit,Plus,Minus,Star,Slash,LPar,RPar,Comma,EOF,Eq,NEq,Lt,Gt,LEq,GEq;
        Right: Decimal;
    begin
        Left := ParseAddSub();
        Op := FTokKind;
        case Op of
            FTokKind::Eq, FTokKind::NEq,
            FTokKind::Lt, FTokKind::Gt,
            FTokKind::LEq, FTokKind::GEq:
                begin
                    NextTok();
                    Right := ParseAddSub();
                    case Op of
                        FTokKind::Eq:
                            exit(BoolToDecimal(Left = Right));
                        FTokKind::NEq:
                            exit(BoolToDecimal(Left <> Right));
                        FTokKind::Lt:
                            exit(BoolToDecimal(Left < Right));
                        FTokKind::Gt:
                            exit(BoolToDecimal(Left > Right));
                        FTokKind::LEq:
                            exit(BoolToDecimal(Left <= Right));
                        FTokKind::GEq:
                            exit(BoolToDecimal(Left >= Right));
                    end;
                end;
        end;
        exit(Left);
    end;

    local procedure ParseAddSub(): Decimal
    var
        Result: Decimal;
        Op: Option None,Number,Ident,StrLit,Plus,Minus,Star,Slash,LPar,RPar,Comma,EOF,Eq,NEq,Lt,Gt,LEq,GEq;
    begin
        Result := ParseMulDiv();
        while FTokKind in [FTokKind::Plus, FTokKind::Minus] do begin
            Op := FTokKind;
            NextTok();
            if Op = FTokKind::Plus then
                Result += ParseMulDiv()
            else
                Result -= ParseMulDiv();
        end;
        exit(Result);
    end;

    local procedure ParseMulDiv(): Decimal
    var
        Result: Decimal;
        Divisor: Decimal;
        Op: Option None,Number,Ident,StrLit,Plus,Minus,Star,Slash,LPar,RPar,Comma,EOF,Eq,NEq,Lt,Gt,LEq,GEq;
    begin
        Result := ParseUnary();
        while FTokKind in [FTokKind::Star, FTokKind::Slash] do begin
            Op := FTokKind;
            NextTok();
            if Op = FTokKind::Star then
                Result *= ParseUnary()
            else begin
                Divisor := ParseUnary();
                if Divisor = 0 then begin
                    if FLenient then
                        Result := 0
                    else
                        Error(ErrDivCero);
                end else
                    Result /= Divisor;
            end;
        end;
        exit(Result);
    end;

    local procedure ParseUnary(): Decimal
    begin
        if FTokKind = FTokKind::Minus then begin
            NextTok();
            exit(-ParseUnary());
        end;
        if FTokKind = FTokKind::Plus then begin
            NextTok();
            exit(ParseUnary());
        end;
        exit(ParsePrimary());
    end;

    local procedure ParsePrimary(): Decimal
    var
        Val: Decimal;
        FuncName: Text;
    begin
        case FTokKind of
            FTokKind::Number:
                begin
                    Val := FTokNum;
                    NextTok();
                    exit(Val);
                end;
            FTokKind::StrLit:
                begin
                    // String literals evaluate to 0 in arithmetic context;
                    // they are used as function arguments (e.g. TRAMO('CODE', x)).
                    NextTok();
                    exit(0);
                end;
            FTokKind::LPar:
                begin
                    NextTok();
                    Val := ParseOr();
                    Expect(FTokKind::RPar);
                    exit(Val);
                end;
            FTokKind::Ident:
                begin
                    FuncName := FTokText;
                    NextTok();
                    if FTokKind = FTokKind::LPar then begin
                        NextTok();
                        exit(CallFunction(FuncName));
                    end;
                    exit(ResolveVariable(FuncName));
                end;
        end;
        Error(ErrTokenInesperado, FTokText);
    end;

    local procedure CallFunction(FuncName: Text): Decimal
    var
        Arg1: Text;
        Arg2: Decimal;
        Arg3: Decimal;
        Result: Decimal;
    begin
        case FuncName of
            'TRAMO':
                begin
                    // TRAMO('TABLE_CODE', numeric_expression)
                    Arg1 := FTokText; // string literal: the table code
                    Expect(FTokKind::StrLit);
                    Expect(FTokKind::Comma);
                    Arg2 := ParseOr();
                    Expect(FTokKind::RPar);
                    Result := EvalTramo(Arg1, Arg2);
                end;
            'ROUND':
                begin
                    // ROUND(value, precision)
                    Arg2 := ParseOr();
                    Expect(FTokKind::Comma);
                    Result := Round(Arg2, ParseOr());
                    Expect(FTokKind::RPar);
                end;
            'ABS':
                begin
                    Result := Abs(ParseOr());
                    Expect(FTokKind::RPar);
                end;
            'MIN':
                begin
                    Arg2 := ParseOr();
                    Expect(FTokKind::Comma);
                    Result := ParseOr();
                    if Arg2 < Result then
                        Result := Arg2;
                    Expect(FTokKind::RPar);
                end;
            'MAX':
                begin
                    Arg2 := ParseOr();
                    Expect(FTokKind::Comma);
                    Result := ParseOr();
                    if Arg2 > Result then
                        Result := Arg2;
                    Expect(FTokKind::RPar);
                end;
            'REDONDEAR':
                begin
                    // REDONDEAR(valor, n) — rounds to n decimal places.
                    // REDONDEAR(5473.286, 2) = 5473.29; REDONDEAR(5473.286, 0) = 5473
                    Arg2 := ParseOr();
                    Expect(FTokKind::Comma);
                    Arg3 := ParseOr(); // decimal places (used as countdown)
                    Expect(FTokKind::RPar);
                    Result := 1; // build precision: 1/10^n
                    while Arg3 > 0 do begin
                        Result := Result / 10;
                        Arg3 -= 1;
                    end;
                    exit(Round(Arg2, Result));
                end;
            'PISO':
                begin
                    // PISO(valor) — floor: largest integer ≤ valor
                    Arg2 := ParseOr();
                    Expect(FTokKind::RPar);
                    exit(Round(Arg2, 1, '<'));
                end;
            'TECHO':
                begin
                    // TECHO(valor) — ceiling: smallest integer ≥ valor
                    Arg2 := ParseOr();
                    Expect(FTokKind::RPar);
                    exit(Round(Arg2, 1, '>'));
                end;
            'IF':
                begin
                    // IF(condition, value_if_true, value_if_false)
                    // Lazy: only the selected branch is evaluated; the other is skipped
                    // without invoking the formula engine, so division-by-zero and other
                    // errors in the dead branch will not surface.
                    Arg2 := ParseOr();
                    Expect(FTokKind::Comma);
                    if Arg2 <> 0 then begin
                        Result := ParseOr();
                        Expect(FTokKind::Comma);
                        SkipExpression();
                    end else begin
                        SkipExpression();
                        Expect(FTokKind::Comma);
                        Result := ParseOr();
                    end;
                    Expect(FTokKind::RPar);
                end;
            'DIV':
                begin
                    // DIV(a, b) — safe division: returns 0 when b = 0 instead of error.
                    // Use inside IF branches to avoid eager-evaluation division-by-zero.
                    Arg2 := ParseOr();
                    Expect(FTokKind::Comma);
                    Arg3 := ParseOr();
                    Expect(FTokKind::RPar);
                    if Arg3 = 0 then
                        Result := 0
                    else
                        Result := Arg2 / Arg3;
                end;
            else begin
                if FLenient then
                    Result := 0
                else
                    Error(ErrFuncionDesconocida, FuncName);
            end;
        end;
        exit(Result);
    end;

    // Consumes tokens until a top-level ',' or ')' is reached, without evaluating.
    // Used for the unselected IF branch so dead code can never error out.
    local procedure SkipExpression()
    var
        Depth: Integer;
    begin
        while true do begin
            if FTokKind = FTokKind::EOF then
                Error(ErrTokenInesperado, 'EOF');
            case FTokKind of
                FTokKind::LPar:
                    Depth += 1;
                FTokKind::RPar:
                    begin
                        if Depth = 0 then
                            exit;
                        Depth -= 1;
                    end;
                FTokKind::Comma:
                    if Depth = 0 then
                        exit;
            end;
            NextTok();
        end;
    end;

    local procedure EvalTramo(TableCode: Text; Value: Decimal): Decimal
    var
        Cab: Record "Tabla Escalonada";
        Det: Record "Tabla Escalonada Det.";
        VigenciaEfectiva: Date;
    begin
        if Value <= 0 then
            exit(0);

        // Find the most recent version of the table effective on FFechaRef
        Cab.SetRange(Código, TableCode);
        Cab.SetFilter("Vigencia Desde", '<=%1', FFechaRef);
        if not Cab.FindLast() then begin
            if FLenient then
                exit(0);
            Error(ErrTablaEscalonada, TableCode, FFechaRef);
        end;

        VigenciaEfectiva := Cab."Vigencia Desde";
        AppendParamLog('TRAMO:' + TableCode + '|' + Format(VigenciaEfectiva));

        // Find the tramo that contains Value
        Det.SetCurrentKey(Código, "Vigencia Desde", "Límite Inferior");
        Det.SetRange(Código, TableCode);
        Det.SetRange("Vigencia Desde", VigenciaEfectiva);
        Det.SetFilter("Límite Inferior", '<=%1', Value);
        Det.SetFilter("Límite Superior", '%1|>=%2', 0, Value); // 0 = unbounded
        if not Det.FindLast() then begin
            if FLenient then
                exit(0);
            Error(ErrTramoNoEncontrado, TableCode, Value);
        end;

        exit(Det."Monto Fijo" + (Det.Porcentaje / 100) * (Value - Det."Límite Inferior"));
    end;

    procedure SetLenientMode(Lenient: Boolean)
    begin
        FLenient := Lenient;
    end;

    local procedure ResolveVariable(VarName: Text): Decimal
    begin
        if not FContext.ContainsKey(VarName) then begin
            if FLenient then
                exit(0);
            Error(ErrVariableDesconocida, VarName);
        end;
        // Log first-time use only (deduplicated) so MarkEnUso can identify referenced params
        if not FResolvedVars.ContainsKey(VarName) then begin
            FResolvedVars.Add(VarName, true);
            AppendParamLog('VAR:' + VarName);
        end;
        exit(FContext.Get(VarName));
    end;

    // ── Tokenizer ─────────────────────────────────────────────────────────────

    local procedure NextTok()
    var
        C: Char;
        Start: Integer;
        NumText: Text;
    begin
        // Skip whitespace
        while (FPos <= FLen) and (FExpr[FPos] = ' ') do
            FPos += 1;

        if FPos > FLen then begin
            FTokKind := FTokKind::EOF;
            FTokText := '';
            exit;
        end;

        C := FExpr[FPos];

        case true of
            C = '+':
                begin
                    FTokKind := FTokKind::Plus;
                    FTokText := '+';
                    FPos += 1;
                end;
            C = '-':
                begin
                    FTokKind := FTokKind::Minus;
                    FTokText := '-';
                    FPos += 1;
                end;
            C = '*':
                begin
                    FTokKind := FTokKind::Star;
                    FTokText := '*';
                    FPos += 1;
                end;
            C = '/':
                begin
                    FTokKind := FTokKind::Slash;
                    FTokText := '/';
                    FPos += 1;
                end;
            C = '(':
                begin
                    FTokKind := FTokKind::LPar;
                    FTokText := '(';
                    FPos += 1;
                end;
            C = ')':
                begin
                    FTokKind := FTokKind::RPar;
                    FTokText := ')';
                    FPos += 1;
                end;
            C = ',':
                begin
                    FTokKind := FTokKind::Comma;
                    FTokText := ',';
                    FPos += 1;
                end;
            C = '=':
                begin
                    FTokKind := FTokKind::Eq;
                    FTokText := '=';
                    FPos += 1;
                end;
            C = '<':
                begin
                    FPos += 1;
                    if (FPos <= FLen) and (FExpr[FPos] = '>') then begin
                        FTokKind := FTokKind::NEq;
                        FTokText := '<>';
                        FPos += 1;
                    end else if (FPos <= FLen) and (FExpr[FPos] = '=') then begin
                        FTokKind := FTokKind::LEq;
                        FTokText := '<=';
                        FPos += 1;
                    end else begin
                        FTokKind := FTokKind::Lt;
                        FTokText := '<';
                    end;
                end;
            C = '>':
                begin
                    FPos += 1;
                    if (FPos <= FLen) and (FExpr[FPos] = '=') then begin
                        FTokKind := FTokKind::GEq;
                        FTokText := '>=';
                        FPos += 1;
                    end else begin
                        FTokKind := FTokKind::Gt;
                        FTokText := '>';
                    end;
                end;
            C = 39: // single quote
                begin
                    FPos += 1;
                    Start := FPos;
                    FTokText := '';
                    while (FPos <= FLen) and (FExpr[FPos] <> 39) do begin
                        FTokText += CopyStr(FExpr, FPos, 1);
                        FPos += 1;
                    end;
                    FPos += 1; // skip closing quote
                    FTokKind := FTokKind::StrLit;
                end;
            IsDigit(C) or (C = '.'):
                begin
                    Start := FPos;
                    // Consume digits, '.', and ',' when followed by a digit (decimal separator).
                    while (FPos <= FLen) and
                          (IsDigit(FExpr[FPos]) or (FExpr[FPos] = '.') or
                           ((FExpr[FPos] = ',') and (FPos + 1 <= FLen) and IsDigit(FExpr[FPos + 1])))
                    do
                        FPos += 1;
                    NumText := CopyStr(FExpr, Start, FPos - Start);
                    if not ParseDecimalLiteral(NumText, FTokNum) then
                        Error(ErrNumeroInvalido, NumText);
                    FTokKind := FTokKind::Number;
                    FTokText := NumText;
                end;
            IsAlpha(C) or (C = '_'):
                begin
                    Start := FPos;
                    while (FPos <= FLen) and (IsAlphaNum(FExpr[FPos]) or (FExpr[FPos] = '_')) do
                        FPos += 1;
                    FTokText := CopyStr(FExpr, Start, FPos - Start);
                    FTokKind := FTokKind::Ident;
                end;
            else begin
                FTokKind := FTokKind::None;
                FTokText := CopyStr(FExpr, FPos, 1);
                FPos += 1;
            end;
        end;
    end;

    local procedure Expect(Kind: Option None,Number,Ident,StrLit,Plus,Minus,Star,Slash,LPar,RPar,Comma,EOF,Eq,NEq,Lt,Gt,LEq,GEq)
    begin
        if FTokKind <> Kind then
            Error(ErrTokenEsperado, Kind, FTokText);
        NextTok();
    end;

    // ── Helpers ───────────────────────────────────────────────────────────────

    // Parses a numeric literal that may use ',' or '.' as decimal separator.
    // ',' → delegate to Evaluate (Spanish BC locale handles it natively).
    // '.' → split on dot and reconstruct to avoid locale ambiguity.
    local procedure ParseDecimalLiteral(NumText: Text; var Value: Decimal): Boolean
    var
        DotPos: Integer;
        IntPart: Text;
        FracPart: Text;
        IntVal: Integer;
        FracIntVal: Integer;
        FracVal: Decimal;
        FracLen: Integer;
        i: Integer;
    begin
        // Comma decimal (e.g. '0,11'): Evaluate handles it correctly in Spanish BC.
        if NumText.Contains(',') then
            exit(Evaluate(Value, NumText));

        // Period decimal (e.g. '0.11'): split manually to avoid locale ambiguity.
        DotPos := NumText.IndexOf('.');
        if DotPos = 0 then begin
            if not Evaluate(IntVal, NumText) then
                exit(false);
            Value := IntVal;
            exit(true);
        end;
        IntPart := CopyStr(NumText, 1, DotPos - 1);
        FracPart := CopyStr(NumText, DotPos + 1);
        if IntPart = '' then
            IntVal := 0
        else
            if not Evaluate(IntVal, IntPart) then
                exit(false);
        if FracPart = '' then begin
            Value := IntVal;
            exit(true);
        end;
        if not Evaluate(FracIntVal, FracPart) then
            exit(false);
        FracLen := StrLen(FracPart);
        FracVal := FracIntVal;
        for i := 1 to FracLen do
            FracVal /= 10;
        Value := IntVal + FracVal;
        exit(true);
    end;

    local procedure IsDigit(C: Char): Boolean
    begin
        exit((C >= '0') and (C <= '9'));
    end;

    local procedure IsAlpha(C: Char): Boolean
    begin
        exit(((C >= 'A') and (C <= 'Z')) or ((C >= 'a') and (C <= 'z')));
    end;

    local procedure IsAlphaNum(C: Char): Boolean
    begin
        exit(IsAlpha(C) or IsDigit(C));
    end;

    local procedure BoolToDecimal(B: Boolean): Decimal
    begin
        if B then
            exit(1)
        else
            exit(0);
    end;

    local procedure AppendParamLog(Entry: Text)
    begin
        if FParamLog <> '' then
            FParamLog += '|';
        FParamLog += Entry;
    end;

    var
        ErrDivCero: Label 'División por cero en la fórmula.';
        ErrTokenInesperado: Label 'Token inesperado: "%1".';
        ErrTokenEsperado: Label 'Se esperaba token %1 pero se encontró "%2".';
        ErrVariableDesconocida: Label 'Variable desconocida en la fórmula: "%1". Verifique la configuración de Fuente Datos Liquidación.';
        ErrFuncionDesconocida: Label 'Función desconocida: "%1".';
        ErrNumeroInvalido: Label 'Número inválido en la fórmula: "%1".';
        ErrTablaEscalonada: Label 'No se encontró la tabla escalonada "%1" vigente al %2.';
        ErrTramoNoEncontrado: Label 'El valor %2 no corresponde a ningún tramo de la tabla "%1".';
}
