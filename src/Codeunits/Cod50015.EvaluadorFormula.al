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
        FTokStart: Integer; // dónde arranca el token actual — lo usa la traza, ver AnotarTermino
        FLen: Integer;
        // Traza de sumas y restas para el detalle de cálculo. Apagada por defecto: no cuesta nada
        // cuando no se pide, y liquidar un lote no tiene por qué armar texto que nadie va a leer.
        FTrazaActiva: Boolean;
        FTrazaNivel: Integer;
        FTraza: Text;
        FTokKind: Option None,Number,Ident,StrLit,Plus,Minus,Star,Slash,LPar,RPar,Comma,EOF,Eq,NEq,Lt,Gt,LEq,GEq;
        FTokText: Text;
        FTokNum: Decimal;
        FContext: Dictionary of [Text, Decimal];
        FFechaRef: Date;
        FParamLog: Text;
        FResolvedVars: Dictionary of [Text, Boolean]; // tracks which vars were actually used
        FLenient: Boolean; // when true, unknown variables resolve to 0 instead of throwing
        FModoValidacion: Boolean; // tolera solo los errores que dependen del valor — ver SetModoValidacion
        // TRAMO caches — valid for the lifetime of one Init() call (one liquidation).
        // FTramoVigCache avoids the Cab.FindLast query after the first call per table.
        // FTramoResultCache avoids the Det.FindLast query for repeated (table, value) pairs.
        FTramoVigCache: Dictionary of [Text, Date];
        FTramoResultCache: Dictionary of [Text, Decimal];
        // La entrada de log ya armada para cada par (tabla, valor). Existe para poder RE-emitir el
        // log cuando el resultado sale de la caché: la caché vive toda la liquidación, pero el
        // detalle de variables se arma por LÍNEA, y loguear solo en el primer cálculo dejaba sin
        // fila a todas las líneas siguientes que consultan la misma tabla con el mismo valor.
        FTramoLogCache: Dictionary of [Text, Text];
        // Pila de códigos de concepto en curso de resolución vía @CÓDIGO, para cortar
        // referencias circulares (A depende de B que depende de A) en vez de recursión infinita.
        FResolvingConceptos: List of [Text];
        // Último valor calculado para cada @CÓDIGO resuelto. BuildFormulaEvaluada (Cod50014) lo
        // lee para mostrar el número en el texto de auditoría SIN volver a evaluar la fórmula
        // referenciada — evitaba esto una recomputación entera por cada @ en cada línea, que con
        // referencias anidadas se multiplica rápido y puede volver el cálculo muy pesado.
        FLastConceptoRefValues: Dictionary of [Text, Decimal];

    procedure Init(var Ctx: Dictionary of [Text, Decimal]; FechaRef: Date)
    begin
        FContext := Ctx;
        FFechaRef := FechaRef;
        FParamLog := '';
        Clear(FResolvedVars);
        Clear(FTramoVigCache);
        Clear(FTramoResultCache);
        Clear(FTramoLogCache);
        Clear(FResolvingConceptos);
        Clear(FLastConceptoRefValues);
    end;

    // Lee el valor calculado en la última evaluación real de @CÓDIGO (misma línea, sin recalcular).
    // Devuelve false si esa referencia no llegó a evaluarse (ej. rama muerta de un IF perezoso) —
    // en ese caso el llamador debe resolverla de cero con ResolveConceptoRefPublic.
    procedure TryGetConceptoRefValue(CodigoConcepto: Text; var Value: Decimal): Boolean
    begin
        if FLastConceptoRefValues.ContainsKey(CodigoConcepto) then begin
            Value := FLastConceptoRefValues.Get(CodigoConcepto);
            exit(true);
        end;
        exit(false);
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
        // Punto de entrada de nivel superior (nunca se llama recursivamente desde
        // ResolveConceptoRef, que usa EvalFormula directo) — acá es seguro limpiar la memo de
        // @CÓDIGO: arranca "fresca" para esta fórmula/concepto, pero se reutiliza dentro de toda
        // la cadena de referencias anidadas que dispare (ver ResolveConceptoRef).
        Clear(FLastConceptoRefValues);
        Result := EvalFormula(Formula);
    end;

    // Punto de entrada público para resolver @CÓDIGO fuera de una expresión — lo usa
    // BuildFormulaEvaluada (Cod50014) para mostrar el valor real de una referencia @ en el
    // texto de "Fórmula con Valores", en vez de dejar "@2498" sin expandir.
    procedure ResolveConceptoRefPublic(CodigoConcepto: Text): Decimal
    begin
        exit(ResolveConceptoRef(CodigoConcepto));
    end;

    [TryFunction]
    procedure TryEvalCondicion(Condicion: Text; var Result: Boolean)
    begin
        Clear(FLastConceptoRefValues);
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
        Termino: Decimal;
        Op: Option None,Number,Ident,StrLit,Plus,Minus,Star,Slash,LPar,RPar,Comma,EOF,Eq,NEq,Lt,Gt,LEq,GEq;
        Nivel: Integer;
        Orden: Integer;
        Inicio: Integer;
    begin
        // LA TRAZA SE TOMA ACÁ Y NO EN OTRO NIVEL. Un "paso a paso" de un cálculo es la cadena de
        // sumas y restas: es donde el signo de cada término significa algo y donde tiene sentido un
        // total corriente. Multiplicar y dividir no se lee así —nadie quiere ver el acumulado a
        // mitad de "base * 11 / 100 / 12"—, y por eso ParseMulDiv no traza.
        //
        // El orden y el signo salen de la FÓRMULA, no de una configuración aparte. Es la diferencia
        // que hace que esto sirva para cualquier concepto sin cargar nada, y que no pueda quedar
        // desincronizado: si alguien cambia la fórmula, la traza cambia con ella.
        if not FTrazaActiva then begin
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

        FTrazaNivel += 1;
        Nivel := FTrazaNivel;
        Orden := 0;

        Inicio := FTokStart;
        Result := ParseMulDiv();
        // Se anota DESPUÉS de parsear, porque recién ahí se sabe dónde terminó el término y cuánto
        // valió. Y sólo si hubo al menos un +/-: un ParseAddSub sin operadores no es una suma, es
        // sólo el camino hacia abajo del parser, y trazarlo llenaría la página de ruido.
        if FTokKind in [FTokKind::Plus, FTokKind::Minus] then begin
            Orden += 1;
            AnotarTermino(Nivel, Orden, '+', Inicio, Result, Result);
            while FTokKind in [FTokKind::Plus, FTokKind::Minus] do begin
                Op := FTokKind;
                NextTok();
                Inicio := FTokStart;
                Termino := ParseMulDiv();
                Orden += 1;
                if Op = FTokKind::Plus then begin
                    Result += Termino;
                    AnotarTermino(Nivel, Orden, '+', Inicio, Termino, Result);
                end else begin
                    Result -= Termino;
                    AnotarTermino(Nivel, Orden, '-', Inicio, Termino, Result);
                end;
            end;
        end;

        FTrazaNivel -= 1;
        exit(Result);
    end;

    // Una fila de la traza. El texto del término se recorta del original entre donde arrancó y
    // donde está parado el parser ahora — que es el comienzo del token siguiente, o sea el
    // operador que cierra este término (o el fin de la expresión).
    local procedure AnotarTermino(Nivel: Integer; Orden: Integer; Signo: Text; Inicio: Integer; Valor: Decimal; Acumulado: Decimal)
    var
        Trozo: Text;
        Fin: Integer;
    begin
        Fin := FTokStart;
        if FTokKind = FTokKind::EOF then
            Fin := FLen + 1;
        if Fin <= Inicio then
            Trozo := ''
        else
            Trozo := CopyStr(FExpr, Inicio, Fin - Inicio);

        // APLANAR EL TÉRMINO ANTES DE METERLO EN LA FILA. Las fórmulas se guardan formateadas en
        // varias líneas, así que el trozo recortado puede traer saltos adentro —no sólo al final—
        // y cada uno partiría la fila en dos al volcar la traza. Se reemplazan por espacios los
        // tres caracteres que usa el formato: TAB separa campos, CR y LF separan filas.
        Trozo := Trozo.Replace(TabChar(), ' ').Replace(CrChar(), ' ').Replace(LfChar(), ' ');
        while StrPos(Trozo, '  ') > 0 do
            Trozo := Trozo.Replace('  ', ' ');
        Trozo := Trozo.Trim();

        FTraza += Format(Nivel) + TabChar() + Format(Orden) + TabChar() + Signo + TabChar() +
                  Format(Valor, 0, 9) + TabChar() + Format(Acumulado, 0, 9) + TabChar() + Trozo +
                  LfChar();
    end;

    // Los separadores. Se arman asignando el código a un Char porque AL no tiene Chr() y
    // Format(9, 0, '<Char>') —que parece razonable— no es una expresión de formato válida:
    // revienta en tiempo de ejecución con "campo o atributo no válido para la propiedad Format".
    local procedure TabChar(): Text
    var
        C: Char;
    begin
        C := 9;
        exit(Format(C));
    end;

    local procedure CrChar(): Text
    var
        C: Char;
    begin
        C := 13;
        exit(Format(C));
    end;

    local procedure LfChar(): Text
    var
        C: Char;
    begin
        C := 10;
        exit(Format(C));
    end;

    /// <summary>
    /// Precarga el valor de una referencia @CÓDIGO o #CÓDIGO en vez de dejar que el evaluador la
    /// recalcule contra la base. Lo usa el detalle de cálculo para reproducir una línea con los
    /// valores que REALMENTE se usaron el día que se liquidó: sin esto, una fórmula como
    /// "-(#4423 + #4433)" volvería a calcular esos dos conceptos con los datos de hoy y el
    /// resultado podría no coincidir con el importe guardado.
    /// </summary>
    procedure SeedConceptoRef(CodigoConcepto: Text; Valor: Decimal)
    begin
        if FLastConceptoRefValues.ContainsKey(CodigoConcepto) then
            FLastConceptoRefValues.Set(CodigoConcepto, Valor)
        else
            FLastConceptoRefValues.Add(CodigoConcepto, Valor);
    end;

    /// <summary>
    /// Enciende la traza de sumas y restas. La consume la página de detalle de cálculo, que
    /// re-evalúa la fórmula GUARDADA en la línea con los valores GUARDADOS en el detalle de
    /// variables — no la fórmula de hoy, que puede haber cambiado desde que se liquidó.
    /// </summary>
    procedure ActivarTraza(Activa: Boolean)
    begin
        FTrazaActiva := Activa;
        FTraza := '';
        FTrazaNivel := 0;
    end;

    /// <summary>
    /// Devuelve la traza como filas separadas por LF, con los campos separados por TAB:
    /// Nivel, Orden, Signo, Valor, Acumulado, Texto del término.
    /// </summary>
    procedure GetTraza(): Text
    begin
        exit(FTraza);
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
                    // En validación los valores son ficticios (todos en cero): dividir por una
                    // variable no es un error de la fórmula, es una consecuencia de no haber
                    // resuelto los valores. El error de verdad, si existe, aparece al calcular.
                    if FLenient or FModoValidacion then
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
                    Arg3 := ParseOr();
                    Expect(FTokKind::RPar);
                    // Con precisión 0 la plataforma corta con un error propio ("the rounding
                    // precision must not be 0") que desde una fórmula no se entiende. En validación
                    // la precisión sale de una variable en cero, así que se devuelve sin redondear.
                    if Arg3 = 0 then begin
                        if FLenient or FModoValidacion then
                            Result := Arg2
                        else
                            Error(ErrPrecisionCero);
                    end else
                        Result := Round(Arg2, Arg3);
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
                        SaltearOValidar();
                    end else begin
                        SaltearOValidar();
                        Expect(FTokKind::Comma);
                        Result := ParseOr();
                    end;
                    Expect(FTokKind::RPar);
                end;
            'CASE':
                // CASE(cond1, valor1, cond2, valor2, …, default)
                //
                // Devuelve el valor de la PRIMERA condición verdadera. El argumento suelto del final
                // —cuando la cantidad es impar— es el default; con cantidad par no hay default y el
                // resultado es 0. Perezosa como el IF: solo se evalúa el valor que se devuelve.
                //
                // Es azúcar sobre IF anidados y existe por legibilidad: una escala de cuatro tramos
                // son tres IF encajados y siete paréntesis, y esa profundidad es lo que hace que un
                // paréntesis faltante se reporte a diez caracteres del lugar donde está el error.
                Result := EvalCase();
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
        ResultCacheKey: Text;
        Result: Decimal;
    begin
        if Value <= 0 then begin
            // Se loguea igual: una fórmula con TRAMO que devuelve cero es justamente el caso que uno
            // viene a mirar al detalle, y sin fila parece que la función nunca se llamó.
            AppendParamLog(EntradaTramo(TableCode, 0, StrSubstNo(TxtTramoSinBase, FormatImporte(Value))));
            exit(0);
        end;

        // Result cache: exact (TableCode, Value) pair seen before in this liquidation.
        // La clave va en formato invariante: con el formato local, un separador decimal distinto
        // haría que el mismo valor genere dos claves.
        ResultCacheKey := TableCode + '|' + Format(Value, 0, 9);
        if FTramoResultCache.ContainsKey(ResultCacheKey) then begin
            if FTramoLogCache.ContainsKey(ResultCacheKey) then
                AppendParamLog(FTramoLogCache.Get(ResultCacheKey));
            exit(FTramoResultCache.Get(ResultCacheKey));
        end;

        // Vigencia cache: avoid repeating Cab.FindLast for the same table
        if FTramoVigCache.ContainsKey(TableCode) then
            VigenciaEfectiva := FTramoVigCache.Get(TableCode)
        else begin
            Cab.SetRange(Código, TableCode);
            Cab.SetFilter("Vigencia Desde", '<=%1', FFechaRef);
            if not Cab.FindLast() then begin
                if FLenient then begin
                    FTramoResultCache.Add(ResultCacheKey, 0);
                    GuardarLogTramo(ResultCacheKey, TableCode, 0, StrSubstNo(TxtTramoSinTabla, FFechaRef));
                    exit(0);
                end;
                Error(ErrTablaEscalonada, TableCode, FFechaRef);
            end;
            VigenciaEfectiva := Cab."Vigencia Desde";
            FTramoVigCache.Add(TableCode, VigenciaEfectiva);
        end;

        // Find the tramo that contains Value
        Det.SetCurrentKey(Código, "Vigencia Desde", "Límite Inferior");
        Det.SetRange(Código, TableCode);
        Det.SetRange("Vigencia Desde", VigenciaEfectiva);
        Det.SetFilter("Límite Inferior", '<=%1', Value);
        Det.SetFilter("Límite Superior", '%1|>=%2', 0, Value); // 0 = unbounded
        if not Det.FindLast() then begin
            // "No hay tramo para ESTE valor" depende del valor, así que en validación no dice nada:
            // el importe con el que se va a consultar todavía no existe. Que la TABLA no exista, en
            // cambio, es un error de configuración y se sigue reportando.
            if FLenient or FModoValidacion then begin
                FTramoResultCache.Add(ResultCacheKey, 0);
                GuardarLogTramo(ResultCacheKey, TableCode, 0,
                    StrSubstNo(TxtTramoSinTramo, VigenciaEfectiva, FormatImporte(Value)));
                exit(0);
            end;
            Error(ErrTramoNoEncontrado, TableCode, Value);
        end;

        Result := Det."Monto Fijo" + (Det.Porcentaje / 100) * (Value - Det."Límite Inferior");
        FTramoResultCache.Add(ResultCacheKey, Result);
        GuardarLogTramo(ResultCacheKey, TableCode, Result, DescribirTramo(Det, Value));
        exit(Result);
    end;

    /// <summary>
    /// Arma la entrada de log de una consulta TRAMO: código, valor devuelto y en qué tramo cayó.
    /// </summary>
    /// <remarks>
    /// El separador interno es "~" porque el "|" ya separa las ENTRADAS del log. La entrada vieja
    /// —'TRAMO:CODIGO|fecha'— se partía en dos al leerla y la fecha quedaba como una entrada suelta.
    ///
    /// El valor va en formato invariante (Format(x, 0, 9)) porque del otro lado se lee con Evaluate:
    /// escrito con el formato local, una coma decimal lo convierte en otro número.
    /// </remarks>
    local procedure EntradaTramo(TableCode: Text; Result: Decimal; Detalle: Text): Text
    begin
        exit('TRAMO:' + TableCode + '~' + Format(Result, 0, 9) + '~' + DelChr(Detalle, '=', '|~'));
    end;

    local procedure GuardarLogTramo(ClaveCache: Text; TableCode: Text; Result: Decimal; Detalle: Text)
    var
        Entrada: Text;
    begin
        Entrada := EntradaTramo(TableCode, Result, Detalle);
        if not FTramoLogCache.ContainsKey(ClaveCache) then
            FTramoLogCache.Add(ClaveCache, Entrada);
        AppendParamLog(Entrada);
    end;

    local procedure DescribirTramo(var Det: Record "Tabla Escalonada Det."; Value: Decimal): Text
    var
        Hasta: Text;
    begin
        if Det."Límite Superior" = 0 then
            Hasta := TxtSinLimite
        else
            Hasta := FormatImporte(Det."Límite Superior");
        exit(StrSubstNo(TxtTramoDet, Det."No. Tramo", Det."Vigencia Desde", FormatImporte(Value),
            FormatImporte(Det."Límite Inferior"), Hasta,
            FormatImporte(Det."Monto Fijo"), Format(Det.Porcentaje)));
    end;

    local procedure FormatImporte(Valor: Decimal): Text
    begin
        exit(Format(Round(Valor, 0.01), 0, '<Precision,2:2><Standard Format,0>'));
    end;

    /// <summary>
    /// Evalúa un CASE variádico, consumiendo hasta el paréntesis de cierre inclusive.
    /// </summary>
    /// <remarks>
    /// No cuenta los argumentos de antemano —no puede: contarlos exigiría parsearlos, y parsear es
    /// evaluar en este diseño—. Se apoya en una propiedad del recorrido: si después de una condición
    /// viene ')' en vez de ',', esa expresión no era una condición sino el default. Y llegar hasta
    /// ahí significa que ninguna condición anterior dio verdadera, así que devolverla es exactamente
    /// lo correcto.
    /// </remarks>
    local procedure EvalCase(): Decimal
    var
        Cond: Decimal;
        Elegido: Decimal;
        Pares: Integer;
    begin
        while true do begin
            Cond := ParseOr();

            if FTokKind = FTokKind::RPar then begin
                // Argumento sin par = default. Con un solo argumento no hay ninguna condición y la
                // fórmula está mal escrita: un CASE(x) es un x con paréntesis de más.
                if Pares = 0 then
                    Error(ErrCaseSinPares);
                Expect(FTokKind::RPar);
                exit(Cond);
            end;

            Expect(FTokKind::Comma);
            Pares += 1;

            if Cond <> 0 then begin
                Elegido := ParseOr();
                SaltearRestoCase();
                exit(Elegido);
            end;

            SaltearOValidar();
            if FTokKind = FTokKind::RPar then begin
                // Cantidad par de argumentos: ninguna condición dio verdadera y no hay default.
                Expect(FTokKind::RPar);
                exit(0);
            end;
            Expect(FTokKind::Comma);
        end;
    end;

    local procedure SaltearRestoCase()
    begin
        while FTokKind = FTokKind::Comma do begin
            Expect(FTokKind::Comma);
            SaltearOValidar();
        end;
        Expect(FTokKind::RPar);
    end;

    /// <summary>
    /// Descarta la rama no elegida: la saltea sin parsear, o la parsea si estamos validando.
    /// </summary>
    /// <remarks>
    /// En un cálculo real la rama muerta se saltea a nivel de tokens, y eso es lo que permite que un
    /// IF proteja una división por cero: la expresión peligrosa nunca se ejecuta.
    ///
    /// Pero saltear sin parsear también significa que un error de sintaxis o una variable inexistente
    /// escondidos en una rama que hoy no se toma no los detecta nadie —ni la validación previa al
    /// cálculo— hasta el día que la condición cambie y esa rama se vuelva la elegida. Con IF son dos
    /// ramas; con CASE pueden ser ocho, así que el agujero crece.
    ///
    /// En los modos de validación, entonces, la rama sí se parsea y su resultado se descarta. Ahí es
    /// seguro: esos modos ya toleran los errores que dependen del VALOR —dividir por una variable en
    /// cero, un tramo inexistente, redondear con precisión cero— y dejan pasar solo los estructurales,
    /// que son justamente los que se quieren encontrar.
    /// </remarks>
    local procedure SaltearOValidar()
    var
        Descartado: Decimal;
    begin
        if FLenient or FModoValidacion then
            Descartado := ParseOr()
        else
            SkipExpression();
    end;

    procedure SetLenientMode(Lenient: Boolean)
    begin
        FLenient := Lenient;
    end;

    /// <summary>
    /// Modo validación: tolera los errores que dependen del VALOR, no de la fórmula.
    /// </summary>
    /// <remarks>
    /// La fase 1 del motor valida contra un contexto de nombres con todos los valores en cero, para
    /// no pagar dos veces la resolución completa. Con esos valores ficticios, dividir por una
    /// variable, buscar el tramo de un importe inexistente o redondear con precisión cero dejan de
    /// ser errores de la fórmula y pasan a ser ruido. Lo estructural —variable desconocida, función
    /// inexistente, tabla escalonada que no existe, sintaxis— se sigue reportando, que es para lo
    /// que la validación existe.
    ///
    /// No es lo mismo que el modo tolerante: ése además hace desaparecer las variables desconocidas,
    /// y eso es justamente lo que hay que detectar.
    /// </remarks>
    procedure SetModoValidacion(Activo: Boolean)
    begin
        FModoValidacion := Activo;
    end;

    local procedure ResolveVariable(VarName: Text): Decimal
    begin
        if VarName.StartsWith('@') then
            exit(ResolveConceptoRef(CopyStr(VarName, 2)));

        if VarName.StartsWith('#') then
            exit(ResolveConceptoCalculado(CopyStr(VarName, 2)));

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

    // @CÓDIGO referencia OTRO concepto directamente: evalúa su Condición y Fórmula ahora mismo
    // (no lee un importe ya calculado), así no depende del Orden Cálculo relativo entre ambos.
    // Reentrante: como el tokenizer vive en variables de instancia, hay que guardar y restaurar
    // su estado alrededor de la evaluación anidada para no romper la fórmula que llamó a esta.
    // Memoizado por FLastConceptoRefValues durante UNA sola llamada de nivel superior (ver
    // TryEvalFormula/TryEvalCondicion, que la limpian al arrancar): si @2498 aparece varias veces
    // en la misma fórmula, sea directo o porque varios términos lo referencian transitivamente
    // (ej. @1013, @1083, @1053 referencian @2498 cada uno), se recalcula una sola vez en vez de
    // una vez por aparición — antes esto podía explotar combinatoriamente con fórmulas de muchos
    // términos @ y causar el bloqueo/lentitud reportado.
    local procedure ResolveConceptoRef(CodigoConcepto: Text): Decimal
    var
        Concepto: Record "Concepto Liquidación";
        SavedExpr: Text;
        SavedPos: Integer;
        SavedLen: Integer;
        SavedTokKind: Option None,Number,Ident,StrLit,Plus,Minus,Star,Slash,LPar,RPar,Comma,EOF,Eq,NEq,Lt,Gt,LEq,GEq;
        SavedTokText: Text;
        SavedTokNum: Decimal;
        CondValor: Boolean;
        Resultado: Decimal;
    begin
        if FLastConceptoRefValues.ContainsKey(CodigoConcepto) then
            exit(FLastConceptoRefValues.Get(CodigoConcepto));

        if FResolvingConceptos.Contains(CodigoConcepto) then
            Error(ErrReferenciaCircular, CodigoConcepto);

        Concepto.SetRange(Código, CopyStr(CodigoConcepto, 1, 20));
        Concepto.SetFilter("Vigencia Desde", '<=%1', FFechaRef);
        if not Concepto.FindLast() then begin
            if FLenient then
                exit(0);
            Error(ErrConceptoRefNoEncontrado, CodigoConcepto);
        end;

        if not FResolvedVars.ContainsKey('@' + CodigoConcepto) then begin
            FResolvedVars.Add('@' + CodigoConcepto, true);
            AppendParamLog('VAR:@' + CodigoConcepto);
        end;

        SavedExpr := FExpr;
        SavedPos := FPos;
        SavedLen := FLen;
        SavedTokKind := FTokKind;
        SavedTokText := FTokText;
        SavedTokNum := FTokNum;

        FResolvingConceptos.Add(CodigoConcepto);

        if Concepto.Condición <> '' then
            CondValor := EvalCondicion(Concepto.Condición)
        else
            CondValor := true;

        if CondValor then
            Resultado := EvalFormula(Concepto.Fórmula)
        else
            Resultado := 0;

        FResolvingConceptos.Remove(CodigoConcepto);

        if FLastConceptoRefValues.ContainsKey(CodigoConcepto) then
            FLastConceptoRefValues.Set(CodigoConcepto, Resultado)
        else
            FLastConceptoRefValues.Add(CodigoConcepto, Resultado);

        FExpr := SavedExpr;
        FPos := SavedPos;
        FLen := SavedLen;
        FTokKind := SavedTokKind;
        FTokText := SavedTokText;
        FTokNum := SavedTokNum;

        exit(Resultado);
    end;

    // #CÓDIGO lee el Importe YA CALCULADO para ese concepto en esta misma liquidación (tal cual
    // quedó reflejado en Ctx — incluida cualquier Incidencia que lo haya sobrescrito), a diferencia
    // de @CÓDIGO que reevalúa la fórmula del concepto desde cero. Por eso depende del Orden Cálculo:
    // si el concepto referenciado todavía no corrió (o su Condición dio falso), se lee como 0 — igual
    // que un acumulador que todavía no recibió nada — en vez de dar error, tanto en la validación de
    // la fórmula al guardar el concepto (que corre en un contexto simulado) como en el cálculo real.
    local procedure ResolveConceptoCalculado(CodigoConcepto: Text): Decimal
    var
        Concepto: Record "Concepto Liquidación";
        VarName: Text;
    begin
        Concepto.SetRange(Código, CopyStr(CodigoConcepto, 1, 20));
        Concepto.SetFilter("Vigencia Desde", '<=%1', FFechaRef);
        if not Concepto.FindLast() then begin
            if FLenient then
                exit(0);
            Error(ErrConceptoCalculadoNoEncontrado, CodigoConcepto);
        end;

        VarName := '#' + CodigoConcepto;
        if not FResolvedVars.ContainsKey(VarName) then begin
            FResolvedVars.Add(VarName, true);
            AppendParamLog('VAR:' + VarName);
        end;

        if FContext.ContainsKey(CodigoConcepto) then
            exit(FContext.Get(CodigoConcepto));
        exit(0);
    end;

    // ── Tokenizer ─────────────────────────────────────────────────────────────

    local procedure NextTok()
    var
        C: Char;
        Start: Integer;
        NumText: Text;
    begin
        // Espacios, tabulaciones y saltos de línea. Los saltos importan desde que las fórmulas se
        // guardan formateadas en varias líneas: antes el campo las aplanaba al validar, así que un
        // CR o un LF no podían llegar hasta acá y caían en el else como "token inesperado".
        while (FPos <= FLen) and EsEspacio(FExpr[FPos]) do
            FPos += 1;

        // Dónde ARRANCA el token que se va a leer. La traza lo necesita para recortar del texto
        // original el trozo que corresponde a cada término de una suma: sin esto sólo se puede
        // mostrar el valor de cada término, no cómo estaba escrito.
        FTokStart := FPos;

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
                    // Solo dígitos y punto. La coma es SIEMPRE separador de argumentos.
                    //
                    // Antes una coma entre dígitos se consumía como separador decimal, y eso rompía
                    // en silencio el patrón más común de todos: IF(condición,0,otra_cosa). El "0,0"
                    // se leía como UN número —cero coma cero— y la función quedaba con dos
                    // argumentos en vez de tres. La fórmula se veía impecable y fallaba, o peor,
                    // resolvía otra cosa.
                    //
                    // El decimal se escribe con punto, que es como están escritas todas las fórmulas
                    // cargadas (round(...,0.0001)). Si alguna usara coma —1,5— ahora se parte en dos
                    // argumentos y falla al validar, ruidosamente, que es lo que corresponde.
                    while (FPos <= FLen) and (IsDigit(FExpr[FPos]) or (FExpr[FPos] = '.')) do
                        FPos += 1;
                    NumText := CopyStr(FExpr, Start, FPos - Start);
                    if not ParseDecimalLiteral(NumText, FTokNum) then
                        Error(ErrNumeroInvalido, NumText);
                    FTokKind := FTokKind::Number;
                    FTokText := NumText;
                end;
            IsAlpha(C) or (C = '_') or (C = '@') or (C = '#'):
                begin
                    // '@' referencia el importe de OTRO concepto directamente (ej. @1003), sin
                    // pasar por un acumulador. '#' lee el Importe YA CALCULADO de otro concepto
                    // en esta misma liquidación (ej. #1003), sin reevaluar su fórmula. Ambos se
                    // consumen como parte del mismo identificador; el código de concepto puede
                    // ser numérico, por eso sigue con IsAlphaNum.
                    Start := FPos;
                    FPos += 1;
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

    local procedure EsEspacio(C: Char): Boolean
    begin
        exit((C = ' ') or (C = 9) or (C = 10) or (C = 13));
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
        // Ya no llegan comas: el tokenizador corta el número en la coma porque es separador de
        // argumentos. Se deja el rechazo explícito por si alguien vuelve a meterla por otra vía.
        if NumText.Contains(',') then
            exit(false);

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

    /// <remarks>
    /// Incluye las letras del español. Los nombres que el evaluador tiene que leer los escribe una
    /// persona en campos Code —código de concepto, nombre de variable de un parámetro o de una fuente
    /// de datos— y esos campos aceptan Ñ y acentos. Sin esto, la plataforma dejaba crear
    /// AÑOS_ANTIGUEDAD y después el tokenizador cortaba el identificador en la Ñ: la fórmula fallaba
    /// con "Variable desconocida: A", que no se parece en nada al problema real.
    /// </remarks>
    local procedure IsAlpha(C: Char): Boolean
    begin
        if ((C >= 'A') and (C <= 'Z')) or ((C >= 'a') and (C <= 'z')) then
            exit(true);
        exit(EsLetraEspañola(C));
    end;

    local procedure EsLetraEspañola(C: Char): Boolean
    begin
        exit(C in ['Ñ', 'ñ', 'Á', 'á', 'É', 'é', 'Í', 'í', 'Ó', 'ó', 'Ú', 'ú', 'Ü', 'ü']);
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
        ErrPrecisionCero: Label 'ROUND con precisión 0: la precisión no puede ser cero. Revisá la variable que la define.';
        ErrTokenInesperado: Label 'Token inesperado: "%1".';
        ErrTokenEsperado: Label 'Se esperaba token %1 pero se encontró "%2".';
        ErrVariableDesconocida: Label 'Variable desconocida en la fórmula: "%1". Ningún Parámetro, Variable de Sistema, Fuente de Datos ni Tipo de Atributo la define con ese Nombre Variable.';
        ErrFuncionDesconocida: Label 'Función desconocida: "%1".';
        ErrCaseSinPares: Label 'CASE necesita al menos una condición con su valor: CASE(condición, valor, …, default).';
        ErrNumeroInvalido: Label 'Número inválido en la fórmula: "%1".';
        TxtTramoDet: Label 'Tramo %1 · vigencia %2 · base %3 · de %4 a %5 · fijo %6 + %7%% s/excedente';
        TxtTramoSinBase: Label 'No se consultó la tabla: la base es %1.';
        TxtTramoSinTabla: Label 'No hay ninguna versión de la tabla vigente al %1.';
        TxtTramoSinTramo: Label 'La versión vigente desde el %1 no tiene ningún tramo que contenga %2.';
        TxtSinLimite: Label 'sin límite';
        ErrTablaEscalonada: Label 'No se encontró la tabla escalonada "%1" vigente al %2.';
        ErrTramoNoEncontrado: Label 'El valor %2 no corresponde a ningún tramo de la tabla "%1".';
        ErrConceptoRefNoEncontrado: Label 'Variable desconocida: la fórmula referencia @%1, pero no existe ningún concepto "%1" vigente (no existe).';
        ErrReferenciaCircular: Label 'Referencia circular en la fórmula: @%1 depende, directa o indirectamente, de sí mismo.';
        ErrConceptoCalculadoNoEncontrado: Label 'Variable desconocida: la fórmula referencia #%1, pero no existe ningún concepto "%1" vigente (no existe).';
}
