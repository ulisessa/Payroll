namespace UAS.Payroll;

codeunit 50014 "Motor Liquidación"
{
    // Orchestrates the full liquidation calculation for one employee/period.
    //
    // Call sequence:
    //   Motor.Liquidar(LiqNo) — runs on an existing Liquidación in Borrador state
    //
    // Performance:
    //   • LatestVersionMap and FracAccumList/FracAccumPct are pre-built with single
    //     scans of Concepto Liquidación and Fracción Acumulador respectively.
    //   • CCT applicability is resolved per-concept against a MaxFlowField on
    //     Concepto Liquidación ("Vigencia CCT Más Reciente"); unrestricted concepts
    //     cost a single CalcFields, restricted ones cost ~3 indexed lookups total.

    procedure Liquidar(LiqNo: Code[20])
    var
        Liq: Record "Liquidación";
    begin
        Liq.Get(LiqNo);
        LiquidarRecord(Liq);
    end;

    procedure LiquidarRecord(var Liq: Record "Liquidación")
    var
        Periodo: Record "Período Liquidación";
        EstadoMgt: Codeunit "Gestión Estado Empleado";
        CtxBuilder: Codeunit "Contexto Liquidación";
        Evaluador: Codeunit "Evaluador Fórmula";
        ValidationCtx: Dictionary of [Text, Decimal];
        Ctx: Dictionary of [Text, Decimal];
    begin
        if Liq.Estado = Liq.Estado::Contabilizada then
            Error(ErrEstadoInvalido);

        Periodo.Get(Liq."Cód. Período");
        if Periodo.Estado = Periodo.Estado::Cerrado then
            Error(ErrPeriodoCerrado);

        // Ensure the header date matches the period end date regardless of when the record was created.
        if Liq."Fecha Liquidación" <> Periodo."Fecha Hasta" then
            Liq."Fecha Liquidación" := Periodo."Fecha Hasta";

        EstadoMgt.ValidarEstadoExiste(Liq."No. Empleado", Periodo."Fecha Hasta");

        // Phase 1: validate all formulas with a dry-run context (LiqNo = '' prevents DB writes).
        // Any formula error is reported here before data is touched.
        CtxBuilder.Init(
            Liq."No. Empleado", Liq."No. Proyecto", Liq."Cód. Período",
            Periodo."Fecha Hasta", Liq."Cód. Convenio", Liq."Cód. Categoría",
            '', Liq."Tipo Liquidación");
        CtxBuilder.BuildContext(ValidationCtx);
        Evaluador.Init(ValidationCtx, Periodo."Fecha Hasta");
        ValidarFormulas(Liq, Periodo."Fecha Hasta", ValidationCtx, Evaluador);

        // Phase 2: full calculation — only reached if Phase 1 passes.
        CtxBuilder.Init(
            Liq."No. Empleado", Liq."No. Proyecto", Liq."Cód. Período",
            Periodo."Fecha Hasta", Liq."Cód. Convenio", Liq."Cód. Categoría",
            Liq."No.", Liq."Tipo Liquidación");
        DeleteLineas(Liq."No.");
        CtxBuilder.BuildContext(Ctx);
        Evaluador.Init(Ctx, Periodo."Fecha Hasta");
        RunConceptos(Liq, Periodo."Fecha Hasta", Ctx, CtxBuilder, Evaluador);
        UpdateTotals(Liq);
        SaveResumenVariables(Liq."No.", Ctx);
        Liq.Estado := Liq.Estado::Calculada;
        Liq.Modify(true);
    end;

    local procedure ValidarFormulas(
        var Liq: Record "Liquidación";
        FechaRef: Date;
        var Ctx: Dictionary of [Text, Decimal];
        var Evaluador: Codeunit "Evaluador Fórmula")
    var
        Concepto: Record "Concepto Liquidación";
        LatestVersionMap: Dictionary of [Code[20], Date];
        CodEstado: Record "Cód. Estado Empleado";
        EstadoMgt: Codeunit "Gestión Estado Empleado";
        EstadoEmp: Record "Estado Empleado";
        TipoEmpleado: Enum "Aplica A Liq.";
        Importe: Decimal;
        Errores: Text;
    begin
        EstadoMgt.GetEstado(Liq."No. Empleado", FechaRef, EstadoEmp);
        if CodEstado.Get(EstadoEmp."Cód. Estado") then
            TipoEmpleado := CodEstado."Tipo Empleado"
        else
            TipoEmpleado := TipoEmpleado::Todos;

        SelectConceptos(Concepto, TipoEmpleado, FechaRef, Liq."Tipo Liquidación");
        BuildLatestVersionCache(FechaRef, LatestVersionMap);

        if not Concepto.FindSet() then exit;
        repeat
            if LatestVersionMap.ContainsKey(Concepto.Código) and
               (Concepto."Vigencia Desde" = LatestVersionMap.Get(Concepto.Código)) and
               CCTAplicaAConcepto(Concepto, Liq."Cód. Convenio", FechaRef) and
               not Concepto."Es Acumulador" and
               (Concepto.Fórmula <> '')
            then
                if not Evaluador.TryEvalFormula(Concepto.Fórmula, Importe) then begin
                    if Errores <> '' then Errores += '\';
                    Errores += StrSubstNo(ErrConceptoFalló, Concepto.Código, GetLastErrorText());
                end;
        until Concepto.Next() = 0;

        if Errores <> '' then
            Error(ErrFormulasInvalidas, Errores);
    end;

    local procedure RunConceptos(
        var Liq: Record "Liquidación";
        FechaRef: Date;
        var Ctx: Dictionary of [Text, Decimal];
        var CtxBuilder: Codeunit "Contexto Liquidación";
        var Evaluador: Codeunit "Evaluador Fórmula")
    var
        Concepto: Record "Concepto Liquidación";
        LinLiq: Record "Línea Liquidación";
        DetGan: Record "Detalle Ganancias Liq.";
        CodEstado: Record "Cód. Estado Empleado";
        EstadoMgt: Codeunit "Gestión Estado Empleado";
        EstadoEmp: Record "Estado Empleado";
        TipoEmpleado: Enum "Aplica A Liq.";
        Importe: Decimal;
        ConceptLog: Text;
        FullParamLog: Text;
        LatestVersionMap: Dictionary of [Code[20], Date];
        FracAccumList: Dictionary of [Code[20], Text];
        FracAccumPct: Dictionary of [Text, Decimal];
    begin
        EstadoMgt.GetEstado(Liq."No. Empleado", FechaRef, EstadoEmp);
        if CodEstado.Get(EstadoEmp."Cód. Estado") then
            TipoEmpleado := CodEstado."Tipo Empleado"
        else
            TipoEmpleado := TipoEmpleado::Todos;

        SelectConceptos(Concepto, TipoEmpleado, FechaRef, Liq."Tipo Liquidación");

        // Pre-build caches — one-time table scans replace per-concept DB queries
        BuildLatestVersionCache(FechaRef, LatestVersionMap);
        BuildFractionCache(FechaRef, FracAccumList, FracAccumPct);

        if not Concepto.FindSet() then
            exit;

        repeat
            if LatestVersionMap.ContainsKey(Concepto.Código) and
               (Concepto."Vigencia Desde" = LatestVersionMap.Get(Concepto.Código)) and
               CCTAplicaAConcepto(Concepto, Liq."Cód. Convenio", FechaRef) and
               CondicionOk(Evaluador, Concepto) and
               not Concepto."Es Acumulador"
            then begin
                if not Evaluador.TryEvalFormula(Concepto.Fórmula, Importe) then
                    Error(ErrConceptoFalló, Concepto.Código, GetLastErrorText());
                Importe := Abs(Importe);

                Clear(LinLiq);
                LinLiq."No. Liquidación" := Liq."No.";
                LinLiq."No. Empleado" := Liq."No. Empleado";
                LinLiq."Cód. Período" := Liq."Cód. Período";
                LinLiq."No. Proyecto" := Liq."No. Proyecto";
                LinLiq."Tipo Liquidación" := Liq."Tipo Liquidación";
                LinLiq."Cód. Convenio" := Liq."Cód. Convenio";
                LinLiq."Cód. Categoría" := Liq."Cód. Categoría";
                LinLiq.Estado := LinLiq.Estado::Calculada;
                LinLiq."Fecha Liquidación" := Liq."Fecha Liquidación";
                LinLiq."Cód. Concepto" := Concepto.Código;
                LinLiq."Descripción Concepto" := Concepto.Descripción;
                LinLiq."Nombre Impresión" := Concepto."Nombre Impresión";
                LinLiq."Tipo Concepto" := Concepto."Tipo Concepto";
                LinLiq."Imprime en Recibo" := Concepto."Imprime en Recibo";
                LinLiq.Importe := Importe;
                if (Concepto."Variable Cantidad" <> '') and Ctx.ContainsKey(Concepto."Variable Cantidad") then begin
                    LinLiq.Cantidad := Ctx.Get(Concepto."Variable Cantidad");
                    LinLiq."Unidad Cantidad" := Concepto."Unidad Cantidad";
                end;
                LinLiq."Orden Cálculo" := Concepto."Orden Cálculo";
                LinLiq."Fórmula Aplicada" := Concepto.Fórmula;
                LinLiq."Fórmula Evaluada" := BuildFormulaEvaluada(Concepto.Fórmula, Ctx);
                LinLiq."Vigencia Concepto" := Concepto."Vigencia Desde";
                ConceptLog := Evaluador.FlushConceptLog();
                if FullParamLog <> '' then FullParamLog += '|';
                FullParamLog += ConceptLog;
                LinLiq."Fuente Parámetros" := CtxBuilder.GetParamLog() + '|' + ConceptLog;
                LinLiq.Insert(true);

                if Concepto."Etiqueta Det. Ganancias" <> '' then begin
                    Clear(DetGan);
                    DetGan."No. Liquidación" := Liq."No.";
                    DetGan.Tipo := DetGan.Tipo::Paso;
                    DetGan.Descripción := CopyStr(Concepto."Etiqueta Det. Ganancias", 1, MaxStrLen(DetGan.Descripción));
                    DetGan."Importe Total" := Importe;
                    DetGan.Orden := Concepto."Orden Cálculo";
                    DetGan.Insert();
                end;

                WriteVariableDetail(Liq."No.", LinLiq."No. Línea", ConceptLog, Ctx);

                UpdateAccumulatorsFromCache(
                    Concepto.Código, Importe, FracAccumList, FracAccumPct, Ctx);
                Evaluador.UpdateContext(Ctx);
            end;
        until Concepto.Next() = 0;

        CtxBuilder.MarkEnUso(FullParamLog);
    end;

    local procedure SelectConceptos(
        var Concepto: Record "Concepto Liquidación";
        TipoEmpleado: Enum "Aplica A Liq.";
        FechaRef: Date;
        TipoLiq: Enum "Tipo Liq.")
    begin
        Concepto.Reset();
        Concepto.SetRange(Activo, true);
        Concepto.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        if TipoEmpleado <> TipoEmpleado::Todos then
            Concepto.SetFilter("Aplica A", '%1|%2', Concepto."Aplica A"::Todos, TipoEmpleado);
        Concepto.SetFilter("Aplica Tipo Liq.", '%1|%2',
            "Aplica Tipo Liq. Concepto"::Todos,
            TipoLiq.AsInteger() + 1);
        Concepto.SetCurrentKey("Orden Cálculo", Código);
    end;

    // ── Pre-build caches (called once per liquidation, before the concept loop) ──

    local procedure BuildLatestVersionCache(FechaRef: Date; var LatestMap: Dictionary of [Code[20], Date])
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Concepto.Reset();
        Concepto.SetRange(Activo, true);
        Concepto.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        if not Concepto.FindSet() then exit;
        repeat
            if not LatestMap.ContainsKey(Concepto.Código) then
                LatestMap.Add(Concepto.Código, Concepto."Vigencia Desde")
            else
                if Concepto."Vigencia Desde" > LatestMap.Get(Concepto.Código) then
                    LatestMap.Set(Concepto.Código, Concepto."Vigencia Desde");
        until Concepto.Next() = 0;
    end;

    // Returns true if this concept applies to CodConvenio at FechaRef.
    // Fast path via the "Vigencia CCT Más Reciente" MaxFlowField: when 0D there are
    // no restrictions for the concept at all and the lookup short-circuits.
    // When restrictions exist, two indexed lookups (FindLast + Get) resolve the
    // applicability for FechaRef without scanning the table.
    local procedure CCTAplicaAConcepto(var Concepto: Record "Concepto Liquidación"; CodConvenio: Code[20]; FechaRef: Date): Boolean
    var
        CCTVig: Record "Concepto CCT Vigente";
    begin
        Concepto.CalcFields("Vigencia CCT Más Reciente");
        if Concepto."Vigencia CCT Más Reciente" = 0D then
            exit(true);

        CCTVig.SetRange("Cód. Concepto", Concepto.Código);
        CCTVig.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        if not CCTVig.FindLast() then
            exit(true); // restrictions exist but none active yet at FechaRef

        exit(CCTVig.Get(Concepto.Código, CCTVig."Vigencia Desde", CodConvenio));
    end;

    // Single-pass build of fraction cache, sorted by Concepto+Vigencia.
    // When a higher vigencia appears for the same concept, prior accum entries are
    // discarded from AccumList (stale AccumPct entries remain but are never accessed).
    local procedure BuildFractionCache(FechaRef: Date;
        var AccumList: Dictionary of [Code[20], Text];
        var AccumPct: Dictionary of [Text, Decimal])
    var
        Fraccion: Record "Fracción Acumulador";
        PrevConcepto: Code[20];
        PrevVig: Date;
        AccumKey: Text;
        FracCurrList: Text;
        PctConSigno: Decimal;
    begin
        Fraccion.SetCurrentKey("Cód. Concepto", "Vigencia Desde");
        Fraccion.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        if not Fraccion.FindSet() then exit;

        PrevConcepto := '';
        PrevVig := 0D;

        repeat
            if Fraccion."Cód. Concepto" <> PrevConcepto then begin
                PrevConcepto := Fraccion."Cód. Concepto";
                PrevVig := Fraccion."Vigencia Desde";
            end else
                if Fraccion."Vigencia Desde" > PrevVig then begin
                    // Higher vigencia for same concept: reset its accum list
                    if AccumList.ContainsKey(Fraccion."Cód. Concepto") then
                        AccumList.Set(Fraccion."Cód. Concepto", '');
                    PrevVig := Fraccion."Vigencia Desde";
                end;

            AccumKey := Fraccion."Cód. Concepto" + '~' + Fraccion."Cód. Acumulador";
            PctConSigno := Fraccion.Porcentaje;
            if Fraccion.Restar then PctConSigno := -PctConSigno;
            if AccumPct.ContainsKey(AccumKey) then
                AccumPct.Set(AccumKey, PctConSigno)
            else
                AccumPct.Add(AccumKey, PctConSigno);

            if not AccumList.ContainsKey(Fraccion."Cód. Concepto") then
                AccumList.Add(Fraccion."Cód. Concepto", Fraccion."Cód. Acumulador")
            else begin
                FracCurrList := AccumList.Get(Fraccion."Cód. Concepto");
                if FracCurrList = '' then
                    AccumList.Set(Fraccion."Cód. Concepto", Fraccion."Cód. Acumulador")
                else
                    AccumList.Set(Fraccion."Cód. Concepto",
                        FracCurrList + '|' + Fraccion."Cód. Acumulador");
            end;
        until Fraccion.Next() = 0;
    end;

    local procedure UpdateAccumulatorsFromCache(
        CodConcepto: Code[20];
        Importe: Decimal;
        var AccumList: Dictionary of [Code[20], Text];
        var AccumPct: Dictionary of [Text, Decimal];
        var Ctx: Dictionary of [Text, Decimal])
    var
        AccumCodes: List of [Text];
        AccumCode: Text;
        AccumKey: Text;
        UpdCurrList: Text;
    begin
        if not AccumList.ContainsKey(CodConcepto) then exit;
        UpdCurrList := AccumList.Get(CodConcepto);
        if UpdCurrList = '' then exit;
        AccumCodes := UpdCurrList.Split('|');
        foreach AccumCode in AccumCodes do begin
            AccumKey := CodConcepto + '~' + AccumCode;
            if AccumPct.ContainsKey(AccumKey) and Ctx.ContainsKey(AccumCode) then
                Ctx.Set(AccumCode, Ctx.Get(AccumCode) + Importe * AccumPct.Get(AccumKey) / 100);
        end;
    end;

    local procedure UpdateTotals(var Liq: Record "Liquidación")
    var
        Lin: Record "Línea Liquidación";
    begin
        Lin.SetRange("No. Liquidación", Liq."No.");

        Lin.SetRange("Tipo Concepto", Lin."Tipo Concepto"::"Haber Remunerativo");
        Lin.CalcSums(Importe);
        Liq."Total Haberes" := Lin.Importe;

        Lin.SetRange("Tipo Concepto", Lin."Tipo Concepto"::"Haber No Remunerativo");
        Lin.CalcSums(Importe);
        Liq."Total Haberes" += Lin.Importe;

        Lin.SetRange("Tipo Concepto", Lin."Tipo Concepto"::"Descuento Empleado");
        Lin.CalcSums(Importe);
        Liq."Total Descuentos" := Lin.Importe;

        Lin.SetRange("Tipo Concepto", Lin."Tipo Concepto"::Retención);
        Lin.CalcSums(Importe);
        Liq."Total Descuentos" += Lin.Importe;

        Lin.SetRange("Tipo Concepto", Lin."Tipo Concepto"::"Seguridad Social");
        Lin.CalcSums(Importe);
        Liq."Total Descuentos" += Lin.Importe;

        Lin.SetRange("Tipo Concepto", Lin."Tipo Concepto"::"Contribución Patronal");
        Lin.CalcSums(Importe);
        Liq."Total Contribuciones" := Lin.Importe;

        Liq."Neto a Pagar" := Liq."Total Haberes" - Liq."Total Descuentos";
    end;

    local procedure CondicionOk(var Evaluador: Codeunit "Evaluador Fórmula"; var Concepto: Record "Concepto Liquidación"): Boolean
    var
        Result: Boolean;
    begin
        if Concepto.Condición.Trim() = '' then
            exit(true);
        if not Evaluador.TryEvalCondicion(Concepto.Condición, Result) then
            Error(ErrConceptoFalló, Concepto.Código, GetLastErrorText());
        exit(Result);
    end;

    local procedure DeleteLineas(LiqNo: Code[20])
    var
        Lin: Record "Línea Liquidación";
        Det: Record "Detalle Variable Línea Liq.";
        Resumen: Record "Resumen Variable Liq.";
        DetGan: Record "Detalle Ganancias Liq.";
    begin
        Det.SetRange("No. Liquidación", LiqNo);
        Det.DeleteAll();
        Resumen.SetRange("No. Liquidación", LiqNo);
        Resumen.DeleteAll();
        DetGan.SetRange("No. Liquidación", LiqNo);
        DetGan.DeleteAll();
        Lin.SetRange("No. Liquidación", LiqNo);
        Lin.DeleteAll(true);
    end;

    local procedure WriteVariableDetail(
        LiqNo: Code[20];
        LineNo: Integer;
        ConceptLog: Text;
        var Ctx: Dictionary of [Text, Decimal])
    var
        Det: Record "Detalle Variable Línea Liq.";
        Entries: List of [Text];
        Entry: Text;
        VarName: Text;
    begin
        if ConceptLog = '' then exit;
        Entries := ConceptLog.Split('|');
        foreach Entry in Entries do
            if Entry.StartsWith('VAR:') then begin
                VarName := CopyStr(Entry, 5);
                if (VarName <> '') and Ctx.ContainsKey(VarName) then begin
                    Clear(Det);
                    Det."No. Liquidación" := LiqNo;
                    Det."No. Línea" := LineNo;
                    Det."Nombre Variable" := CopyStr(VarName, 1, MaxStrLen(Det."Nombre Variable"));
                    Det.Valor := Ctx.Get(VarName);
                    if Det.Insert() then;
                end;
            end;
    end;

    // Replaces each identifier token in Formula with its current value from Ctx.
    // Function names (MAX, MIN, etc.) and keywords are kept verbatim.
    // Numbers, operators, and parentheses pass through unchanged.
    local procedure BuildFormulaEvaluada(Formula: Text; var Ctx: Dictionary of [Text, Decimal]): Text
    var
        Result: Text;
        Pos: Integer;
        Len: Integer;
        C: Char;
        Start: Integer;
        Token: Text;
    begin
        Formula := Formula.ToUpper().Trim();
        Len := StrLen(Formula);
        Pos := 1;
        while Pos <= Len do begin
            C := Formula[Pos];
            if IsIdentStartChar(C) then begin
                Start := Pos;
                while (Pos <= Len) and IsIdentChar(Formula[Pos]) do
                    Pos += 1;
                Token := CopyStr(Formula, Start, Pos - Start);
                if not IsFormulaKeyword(Token) and Ctx.ContainsKey(Token) then
                    Result += FormatVarValue(Ctx.Get(Token))
                else
                    Result += Token;
            end else begin
                Result += CopyStr(Formula, Pos, 1);
                Pos += 1;
            end;
        end;
        exit(CopyStr(Result, 1, 500));
    end;

    local procedure IsIdentStartChar(C: Char): Boolean
    begin
        exit(((C >= 'A') and (C <= 'Z')) or (C = '_'));
    end;

    local procedure IsIdentChar(C: Char): Boolean
    begin
        exit(((C >= 'A') and (C <= 'Z')) or ((C >= '0') and (C <= '9')) or (C = '_'));
    end;

    local procedure IsFormulaKeyword(Token: Text): Boolean
    begin
        exit(Token in ['MAX', 'MIN', 'ROUND', 'ABS', 'IF', 'DIV', 'TRAMO', 'AND', 'OR', 'NOT']);
    end;

    local procedure FormatVarValue(Val: Decimal): Text
    begin
        if Val = Round(Val, 1) then
            exit(Format(Val, 0, '<Sign><Integer>'))
        else
            exit(Format(Round(Val, 0.000001)));
    end;

    local procedure SaveResumenVariables(LiqNo: Code[20]; var Ctx: Dictionary of [Text, Decimal])
    var
        FuenteDatos: Record "Fuente Datos Liquidación";
        VarSistema: Record "Variable Sistema Liq.";
        Resumen: Record "Resumen Variable Liq.";
    begin
        FuenteDatos.SetRange("Mostrar en Recibo", true);
        FuenteDatos.SetRange(Activo, true);
        if FuenteDatos.FindSet() then
            repeat
                if Ctx.ContainsKey(FuenteDatos."Nombre Variable") then begin
                    Clear(Resumen);
                    Resumen."No. Liquidación" := LiqNo;
                    Resumen."Nombre Variable" := FuenteDatos."Nombre Variable";
                    Resumen.Etiqueta := FuenteDatos."Etiqueta Recibo";
                    if Resumen.Etiqueta = '' then
                        Resumen.Etiqueta := CopyStr(FuenteDatos.Descripción, 1, MaxStrLen(Resumen.Etiqueta));
                    Resumen.Valor := Ctx.Get(FuenteDatos."Nombre Variable");
                    if Resumen.Insert() then;
                end;
            until FuenteDatos.Next() = 0;

        VarSistema.SetRange("Mostrar en Recibo", true);
        VarSistema.SetRange(Activo, true);
        if VarSistema.FindSet() then
            repeat
                if Ctx.ContainsKey(VarSistema."Nombre Variable") then begin
                    Clear(Resumen);
                    Resumen."No. Liquidación" := LiqNo;
                    Resumen."Nombre Variable" := VarSistema."Nombre Variable";
                    Resumen.Etiqueta := VarSistema."Etiqueta Recibo";
                    if Resumen.Etiqueta = '' then
                        Resumen.Etiqueta := CopyStr(VarSistema.Descripción, 1, MaxStrLen(Resumen.Etiqueta));
                    Resumen.Valor := Ctx.Get(VarSistema."Nombre Variable");
                    if Resumen.Insert() then;
                end;
            until VarSistema.Next() = 0;
    end;

    var
        ErrEstadoInvalido: Label 'No se puede recalcular una liquidación contabilizada.';
        ErrPeriodoCerrado: Label 'El período %1 está cerrado. No se puede reliquidar.';
        ErrConceptoFalló: Label 'Error al calcular el concepto %1: %2';
        ErrFormulasInvalidas: Label 'Las siguientes fórmulas contienen errores. Corrija antes de calcular:\%1';
}
