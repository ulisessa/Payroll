namespace UAS.Payroll;

using Microsoft.Projects.Project.Job;
using Microsoft.HumanResources.Employee;
using Microsoft.Foundation.Calendar;

codeunit 50016 "Contexto Liquidación"
{
    // Builds the variable dictionary fed to the formula evaluator.
    //
    // Variable resolution order:
    //   1. Fixed scalar variables (BASICO, DIAS_MAR, ANIOS_ANTIGUEDAD, etc.)
    //   2. Dynamic sources from "Fuente Datos Liquidación" records
    //   3. Accumulators initialised to 0 (updated by the motor as concepts run)
    //
    // Context token {JOB_NO} in filter values is replaced with the actual Job No.
    // at resolution time, enabling per-tide data source queries.

    var
        FEmployeeNo: Code[20];
        FJobNo: Code[20];
        FCodPeriodo: Code[10];
        FFechaRef: Date;
        FPeriodoFechaDesde: Date;
        FCodConvenio: Code[20];
        FCodCategoria: Code[20];
        FLiqNo: Code[20];
        FFrancosMgt: Codeunit "Gestión Francos";
        FTipoLiq: Code[20];
        FParamLog: Text;
        FActualCodMap: Dictionary of [Code[50], Code[50]]; // EffectiveKey → CódParámetro real en DB
        FParamBaseMap: Dictionary of [Text, Code[20]];  // NombreVar → CódParámetroBase
        FParamCodMap: Dictionary of [Text, Code[50]];   // NombreVar → CódParámetro real en DB
        FParamVigMap: Dictionary of [Text, Date];       // NombreVar → VigenciaDesde
        FMoneda: Code[10];
        FTipoMap: Dictionary of [Text, Text];          // NombreVar → 'Parámetro'|'Sistema'|'Fuente Datos'|'Acumulador'
        FValoresTexto: Dictionary of [Text, Text];     // NombreVar → valor en su tipo original (fuentes no numéricas)
        FAdvertenciasParametros: Text;
        MsgParamSinValor: Label '%1: no tiene ningún valor cargado en Parámetros Vigentes.';
        MsgParamDesactualizado: Label '%1: el último valor vigente es del %2 (%3 día(s) de antigüedad respecto a la liquidación). Verifique si corresponde cargar una versión más reciente.';
        // Calendar cache — loaded once per (CodCalendario, Año), shared by CalcDiasHabilesAnio
        // and CalcDiasAltaAnio to avoid ~730 DB queries per liquidation.
        FCalCacheLoaded: Boolean;
        FCalCacheCode: Code[10];
        FCalCacheAnio: Integer;
        FCalDateOverride: Dictionary of [Date, Boolean]; // specific date → is_working
        FCalWeekRule: Dictionary of [Integer, Boolean];  // day_of_week (1=Mon..7=Sun) → is_working
        // Fechas de inicio por fuente "Fin Efectivo" — ver GetFechasInicioFuente.
        FFinEfCache: Dictionary of [Text, List of [Date]]; // Nombre Variable → fechas de inicio del scope token

    procedure Init(
        EmployeeNo: Code[20];
        JobNo: Code[20];
        CodPeriodo: Code[10];
        FechaRef: Date;
        CodConvenio: Code[20];
        CodCategoria: Code[20];
        LiqNo: Code[20];
        TipoLiq: Code[20])
    var
        Periodo: Record "Período Liquidación";
    begin
        FEmployeeNo := EmployeeNo;
        FJobNo := JobNo;
        FCodPeriodo := CodPeriodo;
        FFechaRef := FechaRef;
        if Periodo.Get(CodPeriodo) then
            FPeriodoFechaDesde := Periodo."Fecha Desde"
        else
            FPeriodoFechaDesde := FechaRef;
        FCodConvenio := CodConvenio;
        FCodCategoria := CodCategoria;
        FLiqNo := LiqNo;
        FTipoLiq := TipoLiq;
        FParamLog := '';
        FMoneda := '';
        FAdvertenciasParametros := '';
        Clear(FValoresTexto);
        Clear(FActualCodMap);
        Clear(FParamBaseMap);
        Clear(FParamCodMap);
        Clear(FParamVigMap);
        Clear(FTipoMap);
        Clear(FFinEfCache);
        FCalCacheLoaded := false;
    end;

    procedure BuildContext(var Ctx: Dictionary of [Text, Decimal])
    begin
        Clear(Ctx);
        LoadScalars(Ctx);
        LoadDynamicSources(Ctx);
        InitAccumulators(Ctx);
    end;

    procedure GetMoneda(): Code[10]
    begin
        exit(FMoneda);
    end;

    procedure GetParamLog(): Text
    begin
        exit(FParamLog);
    end;

    // ── Scalar variables ──────────────────────────────────────────────────────
    // All context scalars are data-driven:
    //   • Parámetro records where "Nombre Variable" ≠ '' → parameter-based variables
    //   • Variable Sistema Liq. records → system-computed variables (logic in code, name configurable)
    // No variable names are hardcoded here.

    local procedure LoadScalars(var Ctx: Dictionary of [Text, Decimal])
    begin
        LoadParametros(Ctx);
        LoadVariablesSistema(Ctx);
    end;

    local procedure LoadParametros(var Ctx: Dictionary of [Text, Decimal])
    var
        Param: Record "Parámetro";
        CodigoEfectivo: Code[50];
        ActualCod: Code[50];
        ValorMap: Dictionary of [Code[50], Decimal];
        VigMap: Dictionary of [Code[50], Date];
        MonedaMap: Dictionary of [Code[50], Code[10]];
        Valor: Decimal;
        VigDate: Date;
        Moneda: Code[10];
        NombreEsFCY: Text;
        EsFCY: Decimal;
    begin
        BuildParametroCache(ValorMap, VigMap, MonedaMap);

        Param.SetFilter("Nombre Variable", '<>%1', '');
        if not Param.FindSet() then exit;
        repeat
            CodigoEfectivo := ResolverCodigoEfectivo(Param, ValorMap);

            if ValorMap.ContainsKey(CodigoEfectivo) then begin
                Valor := ValorMap.Get(CodigoEfectivo);
                VigDate := VigMap.Get(CodigoEfectivo);
                Moneda := MonedaMap.Get(CodigoEfectivo);
            end else begin
                Valor := 0;
                VigDate := 0D;
                Moneda := '';
            end;

            if not Ctx.ContainsKey(Param."Nombre Variable") then
                Ctx.Add(Param."Nombre Variable", Valor)
            else
                Ctx.Set(Param."Nombre Variable", Valor);
            SetTipo(Param."Nombre Variable", 'Parámetro');
            CheckVigenciaDesactualizada(Param, VigDate);

            // {VarName}_ESFCY = 1 when the parameter value is stored in foreign currency,
            // 0 when it is already in local currency. Lets formulas gate TC multiplication:
            //   IF(BASICO_ESFCY, BASICO * TC_CERCANO, BASICO)
            // Uppercase suffix so it matches the formula evaluator's ToUpper() normalization.
            NombreEsFCY := Param."Nombre Variable" + '_ESFCY';
            if Moneda <> '' then begin
                EsFCY := 1;
                if FMoneda = '' then
                    FMoneda := Moneda;
            end else
                EsFCY := 0;
            if not Ctx.ContainsKey(NombreEsFCY) then
                Ctx.Add(NombreEsFCY, EsFCY)
            else
                Ctx.Set(NombreEsFCY, EsFCY);
            SetTipo(NombreEsFCY, 'Parámetro');

            if VigDate > 0D then begin
                ActualCod := CodigoEfectivo;
                if FActualCodMap.ContainsKey(CodigoEfectivo) then
                    ActualCod := FActualCodMap.Get(CodigoEfectivo);
                if not FParamBaseMap.ContainsKey(Param."Nombre Variable") then
                    FParamBaseMap.Add(Param."Nombre Variable", Param.Código)
                else
                    FParamBaseMap.Set(Param."Nombre Variable", Param.Código);
                if not FParamCodMap.ContainsKey(Param."Nombre Variable") then
                    FParamCodMap.Add(Param."Nombre Variable", ActualCod)
                else
                    FParamCodMap.Set(Param."Nombre Variable", ActualCod);
                if not FParamVigMap.ContainsKey(Param."Nombre Variable") then
                    FParamVigMap.Add(Param."Nombre Variable", VigDate)
                else
                    FParamVigMap.Set(Param."Nombre Variable", VigDate);
            end;
        until Param.Next() = 0;
    end;

    // Resuelve la clave derivada a usar para este parámetro, cascadeando de la MÁS específica a
    // la MENOS específica y quedándose con la primera que tenga valor cargado:
    //   Sufijo Empleado  → COD_<empleado>            → COD
    //   Sufijo CCT       → COD_<convenio>_<categoría> → COD_<convenio> → COD
    //   Sufijo Convenio  → COD_<convenio>            → COD
    // La fila sin convenio ni categoría deriva la clave base (COD) y hace de valor por defecto:
    // así se cargan solo las excepciones por convenio/categoría y el resto cae al genérico, en vez
    // de quedar en 0 por no existir la combinación exacta.
    // Si no hay ninguna, devuelve la más específica (no encontrada) para conservar el comportamiento
    // previo: el llamador la trata como valor 0 / sin vigencia.
    local procedure ResolverCodigoEfectivo(var Param: Record "Parámetro"; var ValorMap: Dictionary of [Code[50], Decimal]) CodigoEfectivo: Code[50]
    var
        Candidatos: List of [Code[50]];
        Candidato: Code[50];
    begin
        if Param."Sufijo Empleado" then begin
            Candidatos.Add(ClaveDerivada(Param.Código, FEmployeeNo, ''));
            Candidatos.Add(Param.Código);
        end else if Param."Sufijo CCT" then begin
            Candidatos.Add(ClaveDerivada(Param.Código, FCodConvenio, FCodCategoria));
            Candidatos.Add(ClaveDerivada(Param.Código, FCodConvenio, ''));
            Candidatos.Add(Param.Código);
        end else if Param."Sufijo Convenio" then begin
            Candidatos.Add(ClaveDerivada(Param.Código, FCodConvenio, ''));
            Candidatos.Add(Param.Código);
        end else
            Candidatos.Add(Param.Código);

        foreach Candidato in Candidatos do
            if ValorMap.ContainsKey(Candidato) then
                exit(Candidato);

        Candidatos.Get(1, CodigoEfectivo);
    end;

    // Arma COD, COD_<p1> o COD_<p1>_<p2> salteando los tramos vacíos, para que la cascada nunca
    // genere claves con separadores colgando (ej. "VALOR_L1_" o "VALOR_L1__OF01") que no
    // coincidirían con ninguna clave derivada real.
    local procedure ClaveDerivada(CodigoBase: Code[20]; Parte1: Code[20]; Parte2: Code[20]): Code[50]
    var
        Clave: Text;
    begin
        Clave := CodigoBase;
        if Parte1 <> '' then begin
            Clave += '_' + Parte1;
            if Parte2 <> '' then
                Clave += '_' + Parte2;
        end;
        exit(CopyStr(Clave, 1, 50));
    end;

    // Collects a warning when a parameter's latest vigente value is older than its
    // configured staleness threshold relative to FFechaRef. The threshold is a
    // DateFormula (e.g. '-1M', '-35D') applied to FFechaRef to get the oldest
    // acceptable Vigencia Desde. VigDate = 0D (no value at all) is always reported.
    local procedure CheckVigenciaDesactualizada(Param: Record "Parámetro"; VigDate: Date)
    var
        FechaLimite: Date;
        Mensaje: Text;
    begin
        if Format(Param."Antigüedad Máxima Vigencia") = '' then exit;
        if VigDate = 0D then
            Mensaje := StrSubstNo(MsgParamSinValor, Param."Nombre Variable")
        else begin
            FechaLimite := CalcDate(Param."Antigüedad Máxima Vigencia", FFechaRef);
            if VigDate < FechaLimite then
                Mensaje := StrSubstNo(MsgParamDesactualizado, Param."Nombre Variable", VigDate, FFechaRef - VigDate);
        end;
        if Mensaje = '' then exit;
        if FAdvertenciasParametros <> '' then
            FAdvertenciasParametros += '\';
        FAdvertenciasParametros += Mensaje;
    end;

    procedure GetAdvertenciasParametros(): Text
    begin
        exit(FAdvertenciasParametros);
    end;

    // Single sorted pass over Parámetro Vigente keeps only the latest vigencia <= FFechaRef
    // per Cód. Parámetro. Replaces one FindLast() per parameter (N queries → 1 scan).
    local procedure BuildParametroCache(
        var ValorMap: Dictionary of [Code[50], Decimal];
        var VigMap: Dictionary of [Code[50], Date];
        var MonedaMap: Dictionary of [Code[50], Code[10]])
    var
        ParamVig: Record "Parámetro Vigente";
        EffKey: Code[50];
    begin
        ParamVig.SetCurrentKey("Cód. Parámetro", "Vigencia Desde");
        ParamVig.SetFilter("Vigencia Desde", '<=%1', FFechaRef);
        if not ParamVig.FindSet() then exit;
        repeat
            EffKey := EffectiveKey(ParamVig);
            if ValorMap.ContainsKey(EffKey) then begin
                ValorMap.Set(EffKey, ParamVig.Valor);
                VigMap.Set(EffKey, ParamVig."Vigencia Desde");
                MonedaMap.Set(EffKey, ParamVig.Moneda);
            end else begin
                ValorMap.Add(EffKey, ParamVig.Valor);
                VigMap.Add(EffKey, ParamVig."Vigencia Desde");
                MonedaMap.Add(EffKey, ParamVig.Moneda);
            end;
            FActualCodMap.Set(EffKey, ParamVig."Cód. Parámetro");
        until ParamVig.Next() = 0;
    end;

    local procedure EffectiveKey(ParamVig: Record "Parámetro Vigente"): Code[50]
    var
        CodTxt: Text;
    begin
        if (ParamVig."Cód. Parámetro Base" = '') or
           (ParamVig."Cód. Parámetro" = ParamVig."Cód. Parámetro Base")
        then
            exit(ParamVig."Cód. Parámetro");
        CodTxt := ParamVig."Cód. Parámetro";
        if CodTxt.StartsWith(ParamVig."Cód. Parámetro Base" + '_') then
            exit(ParamVig."Cód. Parámetro");
        exit(CopyStr(ParamVig."Cód. Parámetro Base" + '_' + ParamVig."Cód. Parámetro", 1, 50));
    end;

    procedure MarkEnUso(EvalParamLog: Text)
    var
        Entries: List of [Text];
        Entry: Text;
        VarName: Text;
        Vistas: Dictionary of [Text, Boolean];
        ParamVig: Record "Parámetro Vigente";
    begin
        // El evaluador deduplica su log por CONCEPTO (FlushConceptLog limpia FResolvedVars en
        // cada concepto), pero el motor concatena el log de todos los conceptos antes de llamar
        // acá. Sin este Dictionary, una variable usada en 20 conceptos hacía 20 Get sobre
        // Parámetro Vigente para marcar la misma fila una sola vez.
        Entries := EvalParamLog.Split('|');
        foreach Entry in Entries do begin
            if Entry.StartsWith('VAR:') then begin
                VarName := CopyStr(Entry, 5); // strip 'VAR:' prefix
                if not Vistas.ContainsKey(VarName) then begin
                    Vistas.Add(VarName, true);
                    if FParamBaseMap.ContainsKey(VarName) and FParamCodMap.ContainsKey(VarName) and FParamVigMap.ContainsKey(VarName) then
                        if ParamVig.Get(FParamBaseMap.Get(VarName), FParamCodMap.Get(VarName), FParamVigMap.Get(VarName)) then
                            if not ParamVig."En Uso" then begin
                                ParamVig."En Uso" := true;
                                ParamVig.Modify();
                            end;
                end;
            end;
        end;
    end;

    local procedure LoadVariablesSistema(var Ctx: Dictionary of [Text, Decimal])
    var
        VarSis: Record "Variable Sistema Liq.";
        DetGan: Record "Detalle Ganancias Liq.";
        Valor: Decimal;
    begin
        VarSis.SetRange(Activo, true);
        if not VarSis.FindSet() then exit;
        repeat
            Valor := ComputeVariableSistema(VarSis);
            if not Ctx.ContainsKey(VarSis."Nombre Variable") then
                Ctx.Add(VarSis."Nombre Variable", Valor)
            else
                Ctx.Set(VarSis."Nombre Variable", Valor);
            SetTipo(VarSis."Nombre Variable", 'Sistema');

            if (FLiqNo <> '') and (VarSis."Etiqueta Det. Ganancias" <> '') then begin
                Clear(DetGan);
                DetGan."No. Liquidación" := FLiqNo;
                DetGan.Tipo := DetGan.Tipo::Paso;
                DetGan.Descripción := VarSis."Etiqueta Det. Ganancias";
                DetGan."Importe Total" := Valor;
                DetGan.Orden := VarSis."Orden Det. Ganancias";
                DetGan.Insert();
            end;
        until VarSis.Next() = 0;
    end;

    local procedure ComputeVariableSistema(VarSis: Record "Variable Sistema Liq."): Decimal
    var
        Cat: Record "Categoría CCT";
    begin
        case VarSis."Cód. Cálculo" of
            'ANIOS_ANTIGUEDAD':
                exit(CalcAntiguedad());
            'DIAS_HAB':
                exit(CalcDiasHabiles());
            'DIAS_FERIADOS':
                // Calendar days in [Período.Fecha Desde, Fecha Hasta] with a date-specific "Base Calendar
                // Change" entry marked Nonworking = true. Only counts genuine feriados (fixed-date
                // holiday entries) — an ordinary Saturday/Sunday from a weekly recurring rule does NOT
                // count, even though EsDiaHabil would also treat it as non-working.
                exit(CalcDiasFeriados());
            'PCT_ESCALA':
                begin
                    if Cat.Get(FCodConvenio, FCodCategoria) then
                        exit(Cat."% Escala" / 100);
                    exit(0);
                end;
            'DIAS_PROYECTO':
                exit(CalcDiasNavegacionMarea());
            'DIAS_PUERTO':
                exit(CalcDiasPuertoMarea());
            'DIAS_FERIADOS_MAREA':
                // Feriados within the marea's own window (not the período's full range) — días
                // efectivamente a bordo. Para recargo por feriado trabajado (Art. 166 LCT) en la marea.
                exit(CalcDiasFeriadosMarea());
            'DIAS_ENROLAMIENTO':
                // Calendar days enrolled on the vessel during the whole marea (states flagged "Devenga
                // Francos"). Base for the franco accrual: REDONDEAR(COEF_FRANCOS * DIAS_ENROLAMIENTO + 1).
                exit(CalcDiasEnrolamientoMarea());
            'DIAS_FRANCOS_PERIODO':
                // Calendar days the employee was in a Francos state within the current billing period.
                // Number of francos consumed (paid, FIFO) this liquidation.
                exit(CalcDiasFrancosPeriodo());
            'PAGO_FRANCOS_FIFO':
                // Amount to pay for the francos consumed this period, FIFO, each lot valued at its own
                // category (VALOR_FRANCO_<CONVENIO>_<CATEGORÍA>). Use as the consumption concept's importe.
                exit(FFrancosMgt.ValorPagoFrancosFIFO(FEmployeeNo, CalcDiasFrancosPeriodo(), FFechaRef, FLiqNo));
            'FRANCOS_CONSUMIDOS':
                // Francos actually consumed this period = min(días en estado Francos, saldo disponible).
                // Use as the consumption concept's Cantidad so quantity matches the FIFO-valued importe.
                exit(FFrancosMgt.FrancosConsumidos(FEmployeeNo, CalcDiasFrancosPeriodo(), FFechaRef, FLiqNo));
            'SALDO_FRANCOS':
                // Pending franco balance (accrued − consumed) for the employee, excluding this liquidation.
                exit(FFrancosMgt.SaldoFrancos(FEmployeeNo, FLiqNo));
            'VACACIONES_ANUALES':
                exit(CalcVacacionesAnuales());
            'DIAS_HAB_ANIO':
                exit(CalcDiasHabilesAnio());
            'DIAS_ALTA_ANIO':
                exit(CalcDiasAltaAnio());
            'VACACIONES_PROP_DIAS':
                exit(CalcVacacionesProporcionales());
            'DIAS_VAC_PERIODO':
                // Days the employee was in a Vacaciones state that overlap with the current billing period.
                // Use this as the divisor/multiplier in the vacation day discount formula (concept 4743).
                exit(CalcDiasVacacionesPeriodo());

            'DEDUC_GANANCIAS':
                exit(CalcDeduccionesGanancias());
            'MES_ANUAL':
                // Calendar month number of the reference date (1 = January … 12 = December).
                // Used to project YTD income to annual: (HAB_GRAV_ANUAL + BASE_IG4) / MES_ANUAL * 12.
                exit(Date2DMY(FFechaRef, 2));
            'YTD_ACUM':
                exit(CalcImporteAnualPorAcumulador(VarSis."Cód. Acumulador"));
            'YTD_LINEAS':
                exit(CalcImporteAnualLiq(VarSis."Tipo Concepto", ''));
            else
                exit(0);
        end;
    end;

    // Returns the YTD sum of LinLiq.Importe for all concepts that feed CodAcum
    // ("Invertir Signo" = false, latest Vigencia <= FFechaRef). Each distinct concept code counted once.
    local procedure CalcImporteAnualPorAcumulador(CodAcum: Code[20]): Decimal
    var
        Fraccion: Record "Fracción Acumulador";
        LinLiq: Record "Línea Liquidación";
        Procesados: Dictionary of [Code[20], Boolean];
        AnioInicio: Date;
        Total: Decimal;
    begin
        AnioInicio := DMY2Date(1, 1, Date2DMY(FFechaRef, 3));
        Fraccion.SetCurrentKey("Cód. Acumulador", "Vigencia Desde");
        Fraccion.SetRange("Cód. Acumulador", CodAcum);
        //Fraccion.SetRange("Invertir Signo", false);
        Fraccion.SetFilter("Vigencia Desde", '<=%1', FFechaRef);
        if not Fraccion.FindSet() then exit(0);
        repeat
            if not Procesados.ContainsKey(Fraccion."Cód. Concepto") then begin
                Procesados.Add(Fraccion."Cód. Concepto", true);
                LinLiq.Reset();
                LinLiq.SetRange("No. Empleado", FEmployeeNo);
                LinLiq.SetRange("Fecha Liquidación", AnioInicio, FFechaRef);
                LinLiq.SetRange("Cód. Concepto", Fraccion."Cód. Concepto");
                LinLiq.SetFilter(Estado, '<>%1', LinLiq.Estado::Borrador);
                LinLiq.CalcSums(Importe);
                If Fraccion."Invertir Signo" then
                    Total -= LinLiq.Importe
                else
                    Total += LinLiq.Importe;
            end;
        until Fraccion.Next() = 0;
        exit(Total);
    end;

    local procedure CalcImporteAnualLiq(TipoConcepto: Enum "Tipo Concepto Liq."; CodConcepto: Code[20]): Decimal
    var
        LinLiq: Record "Línea Liquidación";
        AnioInicio: Date;
    begin
        AnioInicio := DMY2Date(1, 1, Date2DMY(FFechaRef, 3));
        LinLiq.SetRange("No. Empleado", FEmployeeNo);
        LinLiq.SetRange("Fecha Liquidación", AnioInicio, FFechaRef);
        LinLiq.SetRange("Tipo Concepto", TipoConcepto);
        if CodConcepto <> '' then
            LinLiq.SetRange("Cód. Concepto", CodConcepto);
        LinLiq.SetFilter(Estado, '<>%1', LinLiq.Estado::Borrador);
        LinLiq.CalcSums(Importe);
        exit(LinLiq.Importe);
    end;

    // Computes months active within the current calendar year up to FFechaRef,
    // for one family member, respecting Fecha Ingreso and Fecha Egreso.
    // Used to prorate the annual deduction: a relative active from June gives 7/12.
    local procedure CalcMesesFamiliar(FechaIngreso: Date; FechaEgreso: Date): Decimal
    var
        AnioInicio: Date;
        EfectDesde: Date;
        EfectHasta: Date;
        MesDesde: Integer;
        MesHasta: Integer;
    begin
        AnioInicio := DMY2Date(1, 1, Date2DMY(FFechaRef, 3));

        // Effective start: later of Jan 1 and declared start date
        if (FechaIngreso = 0D) or (FechaIngreso < AnioInicio) then
            EfectDesde := AnioInicio
        else
            EfectDesde := FechaIngreso;

        // Effective end: earlier of FFechaRef and declared end date
        if (FechaEgreso = 0D) or (FechaEgreso > FFechaRef) then
            EfectHasta := FFechaRef
        else
            EfectHasta := FechaEgreso;

        if EfectHasta < EfectDesde then
            exit(0);

        MesDesde := Date2DMY(EfectDesde, 2);
        MesHasta := Date2DMY(EfectHasta, 2);
        exit(MesHasta - MesDesde + 1);
    end;

    local procedure CalcDeduccionesGanancias(): Decimal
    var
        EmpDed: Record "Ded. Ganancias Empleado";
        EmpRel: Record "Employee Relative";
        ParamVig: Record "Parámetro Vigente";
        Param: Record "Parámetro";
        DetGan: Record "Detalle Ganancias Liq.";
        VigenciaEfectiva: Date;
        TipoFraccion: Dictionary of [Code[20], Decimal];
        CodTipo: Code[20];
        Fraccion: Decimal;
        PctRel: Decimal;
        Total: Decimal;
        ParamDesc: Text[100];
    begin
        // Part 1: family members — accumulate deduction fractions per type.
        // AFIP proyección anual method: when a relative is valid for the current period,
        // the FULL annual deduction applies (no month proration). Dates are used only
        // to determine binary inclusion/exclusion for the current period.
        // "% Deducción" (custody %) IS applied as the coefficient (e.g., 0.5 for shared custody).
        EmpRel.SetRange("Employee No.", FEmployeeNo);
        EmpRel.SetFilter("Cód. Tipo Ded.", '<>%1', '');
        if EmpRel.FindSet() then
            repeat
                if ((EmpRel."Fecha Ingreso Impuesto" = 0D) or (EmpRel."Fecha Ingreso Impuesto" <= FFechaRef)) and
                   ((EmpRel."Fecha Egreso Impuesto" = 0D) or (EmpRel."Fecha Egreso Impuesto" >= FPeriodoFechaDesde))
                then begin
                    CodTipo := EmpRel."Cód. Tipo Ded.";
                    PctRel := EmpRel."% Deducción";
                    if PctRel = 0 then PctRel := 100;
                    Fraccion := PctRel / 100;
                    if TipoFraccion.ContainsKey(CodTipo) then
                        TipoFraccion.Set(CodTipo, TipoFraccion.Get(CodTipo) + Fraccion)
                    else
                        TipoFraccion.Add(CodTipo, Fraccion);
                end;
            until EmpRel.Next() = 0;

        foreach CodTipo in TipoFraccion.Keys() do begin
            Fraccion := TipoFraccion.Get(CodTipo);
            ParamVig.SetRange("Cód. Parámetro Base", CodTipo);
            ParamVig.SetRange("Cód. Parámetro", CodTipo);
            ParamVig.SetFilter("Vigencia Desde", '<=%1', FFechaRef);
            if ParamVig.FindLast() then begin
                if Param.Get(CodTipo) then
                    ParamDesc := Param.Descripción
                else
                    ParamDesc := CodTipo;
                AppendParamLog('DED_FAM:' + CodTipo + '|' + Format(ParamVig."Vigencia Desde") + '|Frac:' + Format(Fraccion));
                Total += ParamVig.Valor * Fraccion;
                if FLiqNo <> '' then begin
                    Clear(DetGan);
                    DetGan."No. Liquidación" := FLiqNo;
                    DetGan.Tipo := DetGan.Tipo::Familiar;
                    DetGan.Código := CodTipo;
                    DetGan.Descripción := CopyStr(ParamDesc, 1, MaxStrLen(DetGan.Descripción));
                    DetGan.Cantidad := Fraccion;
                    DetGan."Importe Unit. Anual" := ParamVig.Valor;
                    DetGan."Importe Total" := ParamVig.Valor * Fraccion;
                    DetGan.Orden := 500;
                    DetGan.Insert();
                end;
            end;
        end;

        // Part 2: fixed-amount expense deductions (PREPAGA, HIPOTECA, SERV_DOM, etc.)
        EmpDed.SetRange("No. Empleado", FEmployeeNo);
        EmpDed.SetFilter("Vigencia Desde", '<=%1', FFechaRef);
        if not EmpDed.FindLast() then exit(Total);

        VigenciaEfectiva := EmpDed."Vigencia Desde";
        EmpDed.SetRange("Vigencia Desde", VigenciaEfectiva);
        EmpDed.SetFilter("Importe Fijo", '>%1', 0);
        if EmpDed.FindSet() then
            repeat
                Total += EmpDed."Importe Fijo";
                if FLiqNo <> '' then begin
                    Clear(DetGan);
                    DetGan."No. Liquidación" := FLiqNo;
                    DetGan.Tipo := DetGan.Tipo::Gasto;
                    DetGan.Código := EmpDed."Cód. Tipo";
                    DetGan.Descripción := CopyStr(EmpDed.Descripción, 1, MaxStrLen(DetGan.Descripción));
                    DetGan.Cantidad := 0;
                    DetGan."Importe Unit. Anual" := 0;
                    DetGan."Importe Total" := EmpDed."Importe Fijo";
                    DetGan.Orden := 500;
                    DetGan.Insert();
                end;
            until EmpDed.Next() = 0;

        exit(Total);
    end;


    local procedure CalcAntiguedad(): Decimal
    var
        EstadoMgt: Codeunit "Gestión Estado Empleado";
    begin
        // Fraccionaria (0.1) para ANIOS_ANTIGUEDAD — no la exacta de años completos que usan
        // los tramos legales de vacaciones (ver CalcAntiguedadAlFecha/CalcVacacionesAnuales).
        exit(EstadoMgt.CalcAntiguedadFraccionAlFecha(FEmployeeNo, FFechaRef));
    end;

    // Parameterized version — used by ANIOS_ANTIGUEDAD (FFechaRef) and
    // VACACIONES_ANUALES (31/12 of the vacation year, per Art. 164 LCT).
    //
    // Seniority = sum of all employment periods (Alta → Baja) + Antigüedad Reconocida.
    // Intermediate states (Vacaciones, Enfermedad, Suspensión) are inside a period and
    // are included automatically; only Baja states close a period.
    // Uses a virtual-start-date approach: FechaVirtual = FechaRef − TotalDias, then
    // computes complete years from FechaVirtual to FechaRef for exact anniversary logic.
    local procedure CalcAntiguedadAlFecha(FechaRef: Date): Decimal
    var
        EstadoMgt: Codeunit "Gestión Estado Empleado";
    begin
        exit(EstadoMgt.CalcAntiguedadAlFecha(FEmployeeNo, FechaRef));
    end;

    local procedure CalcVacacionesAnuales(): Decimal
    var
        Anios: Decimal;
        Fecha31Dic: Date;
    begin
        // Art. 164 LCT: seniority computed as of 31/12 of the vacation year.
        Fecha31Dic := DMY2Date(31, 12, Date2DMY(FFechaRef, 3));
        Anios := CalcAntiguedadAlFecha(Fecha31Dic);
        case true of
            Anios < 5:
                exit(14);
            Anios < 10:
                exit(21);
            Anios < 20:
                exit(28);
            else
                exit(35);
        end;
    end;

    local procedure CalcDiasHabiles(): Decimal
    var
        Periodo: Record "Período Liquidación";
        FechaActual: Date;
        Dias: Integer;
    begin
        if not Periodo.Get(FCodPeriodo) then
            exit(0);
        FechaActual := Periodo."Fecha Desde";
        Dias := 0;
        while FechaActual <= Periodo."Fecha Hasta" do begin
            if EsDiaHabil(FechaActual, Periodo."Cód. Calendario") then
                Dias += 1;
            FechaActual += 1;
        end;
        exit(Dias);
    end;

    // Same window as DIAS_HAB (the full liquidation período), counting only genuine holidays.
    local procedure CalcDiasFeriados(): Decimal
    var
        Periodo: Record "Período Liquidación";
        FechaActual: Date;
        Dias: Integer;
    begin
        if not Periodo.Get(FCodPeriodo) then exit(0);
        if Periodo."Cód. Calendario" = '' then exit(0); // no calendar → no feriados to distinguish
        FechaActual := Periodo."Fecha Desde";
        while FechaActual <= Periodo."Fecha Hasta" do begin
            EnsureCalendarioCache(Periodo."Cód. Calendario", Date2DMY(FechaActual, 3));
            if EsFeriadoCached(FechaActual) then
                Dias += 1;
            FechaActual += 1;
        end;
        exit(Dias);
    end;

    // A date counts as a feriado only if it has its OWN date-specific calendar-change entry marked
    // Nonworking = true — i.e. FCalDateOverride, never the weekly Sat/Sun rule in FCalWeekRule.
    local procedure EsFeriadoCached(Fecha: Date): Boolean
    begin
        if FCalDateOverride.ContainsKey(Fecha) then
            exit(not FCalDateOverride.Get(Fecha));
        exit(false);
    end;

    // Feriados within the marea's own window for this liquidation — same clipped range as
    // CalcDiasNavegacionMarea/CalcDiasPuertoMarea: [max(marea start, período start), min(arrival or
    // FechaRef, FechaRef)] — NOT the período's full calendar range (DIAS_FERIADOS). A crew works every
    // day aboard, including feriados, so this is what a "feriado trabajado" recargo (Art. 166 LCT) needs:
    // días feriados efectivamente a bordo durante esta liquidación, sea Devengados o Cierre Marea.
    local procedure CalcDiasFeriadosMarea(): Decimal
    var
        Periodo: Record "Período Liquidación";
        Job: Record Job;
        RangeStart: Date;
        RangeEnd: Date;
        FechaActual: Date;
        Dias: Integer;
    begin
        if (FJobNo = '') or not Job.Get(FJobNo) or (Job."Starting Date" = 0D) then exit(0);
        if not Periodo.Get(FCodPeriodo) then exit(0);
        if Periodo."Cód. Calendario" = '' then exit(0);

        RangeStart := Job."Starting Date";
        if FPeriodoFechaDesde > RangeStart then
            RangeStart := FPeriodoFechaDesde;

        RangeEnd := FFechaRef;
        if (Job."Ending Date" > 0D) and (Job."Ending Date" < RangeEnd) then
            RangeEnd := Job."Ending Date";

        if RangeEnd < RangeStart then exit(0);

        FechaActual := RangeStart;
        while FechaActual <= RangeEnd do begin
            EnsureCalendarioCache(Periodo."Cód. Calendario", Date2DMY(FechaActual, 3));
            if EsFeriadoCached(FechaActual) then
                Dias += 1;
            FechaActual += 1;
        end;
        exit(Dias);
    end;

    // Art. 167 LCT: 1 day per 20 effective working days, truncated (no rounding up).
    local procedure CalcVacacionesProporcionales(): Decimal
    begin
        exit(Round(CalcDiasAltaAnio() / 20, 1, '<'));
    end;

    // Navigation days of the marea (project) that fall within this liquidation's window
    // [max(marea start, period start), min(arrival, FechaRef)]:
    //   • Devengados mid-voyage → cuts at FechaRef (period/month end), voyage still open.
    //   • Cierre Marea          → cuts at arrival (= FechaRef).
    // Each liquidation therefore accrues only its month's navigation portion.
    // AM/PM rules apply only when the departure/arrival day actually falls in the window:
    //   departure PM → that day is a port day (−1); arrival PM → that day is navigation (+1);
    //   a month-end cutoff while still at sea is a full navigation day (+1).
    local procedure CalcDiasNavegacionMarea(): Decimal
    var
        Job: Record Job;
        RangeStart: Date;
        RangeEnd: Date;
        Dias: Integer;
    begin
        if (FJobNo = '') or not Job.Get(FJobNo) or (Job."Starting Date" = 0D) then
            exit(0);

        RangeStart := Job."Starting Date";
        if FPeriodoFechaDesde > RangeStart then
            RangeStart := FPeriodoFechaDesde;

        RangeEnd := FFechaRef;
        if (Job."Ending Date" > 0D) and (Job."Ending Date" < RangeEnd) then
            RangeEnd := Job."Ending Date";

        if RangeEnd < RangeStart then
            exit(0);

        Dias := RangeEnd - RangeStart;

        // Departure boundary: only when the actual departure day is inside the window.
        if (RangeStart = Job."Starting Date") and (Job."Hora de zarpada" >= 120000T) then
            Dias -= 1;

        // End boundary: arrival day (AM/PM rule) if the window ends at arrival; otherwise the
        // month-end cutoff is a full navigation day (voyage still open).
        if (Job."Ending Date" > 0D) and (RangeEnd = Job."Ending Date") then begin
            if Job."Hora ingreso a puerto" >= 120000T then
                Dias += 1;
        end else
            Dias += 1;

        exit(Dias);
    end;

    // Port days of the marea within this liquidation's window. Only the boundary days count as
    // port, per the CCT rule: buque entra AM → puerto; buque sale PM → puerto (the complementary
    // AM/PM cases are navigation). Mid-voyage days are always navigation, so a window has 0-2
    // port days. Nav + Port = total inclusive days in the window.
    local procedure CalcDiasPuertoMarea(): Decimal
    var
        Job: Record Job;
        RangeStart: Date;
        RangeEnd: Date;
        Dias: Integer;
    begin
        if (FJobNo = '') or not Job.Get(FJobNo) or (Job."Starting Date" = 0D) then
            exit(0);

        RangeStart := Job."Starting Date";
        if FPeriodoFechaDesde > RangeStart then
            RangeStart := FPeriodoFechaDesde;

        RangeEnd := FFechaRef;
        if (Job."Ending Date" > 0D) and (Job."Ending Date" < RangeEnd) then
            RangeEnd := Job."Ending Date";

        if RangeEnd < RangeStart then
            exit(0);

        // Departure PM → that day is a port day (only if the departure day is inside the window).
        if (RangeStart = Job."Starting Date") and (Job."Hora de zarpada" >= 120000T) then
            Dias += 1;

        // Arrival AM → that day is a port day (only if the window actually reaches arrival).
        if (Job."Ending Date" > 0D) and (RangeEnd = Job."Ending Date") and (Job."Hora ingreso a puerto" < 120000T) then
            Dias += 1;

        exit(Dias);
    end;

    // Calendar days enrolled on the vessel across the whole marea (Job window), counting only states
    // flagged "Devenga Francos". Independent of the billing period: the accrual reflects the full voyage.
    local procedure CalcDiasEnrolamientoMarea(): Decimal
    var
        Job: Record Job;
        EstadoEmp: Record "Estado Empleado";
        CodEst: Record "Cód. Estado Empleado";
        WinStart: Date;
        WinEnd: Date;
        OlapStart: Date;
        OlapEnd: Date;
        Total: Integer;
    begin
        if (FEmployeeNo = '') or (FJobNo = '') or not Job.Get(FJobNo) or (Job."Starting Date" = 0D) then
            exit(0);
        WinStart := Job."Starting Date";
        WinEnd := Job."Ending Date";
        if WinEnd = 0D then
            WinEnd := FFechaRef;

        EstadoEmp.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        EstadoEmp.SetRange("Tipo Entidad", EstadoEmp."Tipo Entidad"::Empleado);
        EstadoEmp.SetRange("No. Empleado", FEmployeeNo);
        if not EstadoEmp.FindSet() then exit(0);
        repeat
            if CodEst.Get(EstadoEmp."Cód. Estado") and CodEst."Devenga Francos" then begin
                OlapStart := EstadoEmp."Fecha Inicio";
                if WinStart > OlapStart then OlapStart := WinStart;
                OlapEnd := EstadoEmp.FechaFinEfectiva();
                if WinEnd < OlapEnd then OlapEnd := WinEnd;
                if OlapEnd >= OlapStart then
                    Total += OlapEnd - OlapStart + 1;
            end;
        until EstadoEmp.Next() = 0;
        exit(Total);
    end;

    // Calendar days in a Francos state (Tipo Estado = Francos) that overlap [FPeriodoFechaDesde, FFechaRef].
    // Number of francos enjoyed/consumed in this liquidation.
    local procedure CalcDiasFrancosPeriodo(): Decimal
    var
        EstadoEmp: Record "Estado Empleado";
        CodEst: Record "Cód. Estado Empleado";
        OlapStart: Date;
        OlapEnd: Date;
        Total: Integer;
    begin
        EstadoEmp.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        EstadoEmp.SetRange("Tipo Entidad", EstadoEmp."Tipo Entidad"::Empleado);
        EstadoEmp.SetRange("No. Empleado", FEmployeeNo);
        if not EstadoEmp.FindSet() then exit(0);
        repeat
            if CodEst.Get(EstadoEmp."Cód. Estado") and
               (CodEst."Tipo Estado" = CodEst."Tipo Estado"::Francos)
            then begin
                OlapStart := EstadoEmp."Fecha Inicio";
                if FPeriodoFechaDesde > OlapStart then OlapStart := FPeriodoFechaDesde;
                OlapEnd := EstadoEmp.FechaFinEfectiva();
                if FFechaRef < OlapEnd then OlapEnd := FFechaRef;
                if OlapEnd >= OlapStart then
                    Total += OlapEnd - OlapStart + 1;
            end;
        until EstadoEmp.Next() = 0;
        exit(Total);
    end;

    // Calendar days in Vacaciones state that overlap with [FPeriodoFechaDesde, FFechaRef].
    // Used as DIAS_VAC_PERIODO in the vacation day discount formula.
    local procedure CalcDiasVacacionesPeriodo(): Decimal
    var
        EstadoEmp: Record "Estado Empleado";
        CodEst: Record "Cód. Estado Empleado";
        EstadoMgt: Codeunit "Gestión Estado Empleado";
        FechaFinEfectiva: Date;
        FechaFinDerecho: Date;
        OlapStart: Date;
        OlapEnd: Date;
        Total: Integer;
    begin
        EstadoEmp.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        EstadoEmp.SetRange("Tipo Entidad", EstadoEmp."Tipo Entidad"::Empleado);
        EstadoEmp.SetRange("No. Empleado", FEmployeeNo);
        if not EstadoEmp.FindSet() then exit(0);
        repeat
            if CodEst.Get(EstadoEmp."Cód. Estado") and
               (CodEst."Tipo Estado" = CodEst."Tipo Estado"::Vacaciones)
            then begin
                // Effective end = min(next state start - 1, entitlement end). The vacation state runs
                // until the next state, but never counts more than the days the employee is entitled to.
                FechaFinEfectiva := EstadoEmp.FechaFinEfectiva();
                FechaFinDerecho := EstadoEmp."Fecha Inicio" + EstadoMgt.CalcDiasVacaciones(FEmployeeNo, EstadoEmp."Fecha Inicio") - 1;
                if FechaFinDerecho < FechaFinEfectiva then FechaFinEfectiva := FechaFinDerecho;

                OlapStart := EstadoEmp."Fecha Inicio";
                if FPeriodoFechaDesde > OlapStart then OlapStart := FPeriodoFechaDesde;
                OlapEnd := FechaFinEfectiva;
                if FFechaRef < OlapEnd then OlapEnd := FFechaRef;
                if OlapEnd >= OlapStart then
                    Total += OlapEnd - OlapStart + 1;
            end;
        until EstadoEmp.Next() = 0;
        exit(Total);
    end;


    // Total working days in the calendar year of FFechaRef.
    // Used as the denominator for the Art. 165 LCT half-year check.
    local procedure CalcDiasHabilesAnio(): Decimal
    var
        Periodo: Record "Período Liquidación";
        CodCalendario: Code[10];
        FechaActual: Date;
        Anio: Integer;
        Dias: Integer;
    begin
        Anio := Date2DMY(FFechaRef, 3);
        if Periodo.Get(FCodPeriodo) then
            CodCalendario := Periodo."Cód. Calendario";
        EnsureCalendarioCache(CodCalendario, Anio);
        FechaActual := DMY2Date(1, 1, Anio);
        while FechaActual <= DMY2Date(31, 12, Anio) do begin
            if EsDiaHabilCached(FechaActual) then
                Dias += 1;
            FechaActual += 1;
        end;
        exit(Dias);
    end;

    // Working days in the calendar year of FFechaRef that fall within an active
    // employment period (Alta → Baja). Vacaciones, Enfermedad, Suspensión and any
    // other intermediate state are included because they are inside the employment
    // relationship. Only Baja closes a period.
    // Used as the numerator for the Art. 165 LCT half-year check.
    local procedure CalcDiasAltaAnio(): Decimal
    var
        Periodo: Record "Período Liquidación";
        EstadoEmp: Record "Estado Empleado";
        CodEst: Record "Cód. Estado Empleado";
        CodCalendario: Code[10];
        FechaInicioAnio: Date;
        FechaFinAnio: Date;
        FechaInicioEmpleo: Date;
        FechaDesde: Date;
        FechaHasta: Date;
        FechaActual: Date;
        Anio: Integer;
        Dias: Integer;
        InEmpleo: Boolean;
    begin
        Anio := Date2DMY(FFechaRef, 3);
        FechaInicioAnio := DMY2Date(1, 1, Anio);
        FechaFinAnio := DMY2Date(31, 12, Anio);
        if Periodo.Get(FCodPeriodo) then
            CodCalendario := Periodo."Cód. Calendario";

        EnsureCalendarioCache(CodCalendario, Anio);

        EstadoEmp.SetRange("No. Empleado", FEmployeeNo);
        EstadoEmp.SetCurrentKey("No. Empleado", "Fecha Inicio");

        if EstadoEmp.FindSet() then
            repeat
                if CodEst.Get(EstadoEmp."Cód. Estado") then
                    if CodEst."Tipo Estado" = CodEst."Tipo Estado"::Alta then begin
                        InEmpleo := true;
                        FechaInicioEmpleo := EstadoEmp."Fecha Inicio";
                    end else if (CodEst."Tipo Estado" = CodEst."Tipo Estado"::Baja) and InEmpleo then begin
                        FechaDesde := FechaInicioEmpleo;
                        if FechaDesde < FechaInicioAnio then FechaDesde := FechaInicioAnio;
                        FechaHasta := EstadoEmp."Fecha Inicio" - 1;
                        if FechaHasta > FechaFinAnio then FechaHasta := FechaFinAnio;
                        if FechaHasta >= FechaDesde then begin
                            FechaActual := FechaDesde;
                            while FechaActual <= FechaHasta do begin
                                if EsDiaHabilCached(FechaActual) then
                                    Dias += 1;
                                FechaActual += 1;
                            end;
                        end;
                        InEmpleo := false;
                    end;
            until EstadoEmp.Next() = 0;

        if InEmpleo then begin
            FechaDesde := FechaInicioEmpleo;
            if FechaDesde < FechaInicioAnio then FechaDesde := FechaInicioAnio;
            FechaActual := FechaDesde;
            while FechaActual <= FechaFinAnio do begin
                if EsDiaHabilCached(FechaActual) then
                    Dias += 1;
                FechaActual += 1;
            end;
        end;

        exit(Dias);
    end;

    // Populates FCalDateOverride and FCalWeekRule with a single DB query for the
    // given calendar/year pair. Subsequent calls with the same pair are no-ops.
    local procedure EnsureCalendarioCache(CodCalendario: Code[10]; Anio: Integer)
    var
        CalChange: Record "Base Calendar Change";
        DiaKey: Integer;
    begin
        if FCalCacheLoaded and (FCalCacheCode = CodCalendario) and (FCalCacheAnio = Anio) then
            exit;
        Clear(FCalDateOverride);
        Clear(FCalWeekRule);
        FCalCacheCode := CodCalendario;
        FCalCacheAnio := Anio;
        FCalCacheLoaded := true;
        if CodCalendario = '' then exit;
        CalChange.SetRange("Base Calendar Code", CodCalendario);
        if not CalChange.FindSet() then exit;
        repeat
            if CalChange.Date <> 0D then begin
                if Date2DMY(CalChange.Date, 3) = Anio then
                    if not FCalDateOverride.ContainsKey(CalChange.Date) then
                        FCalDateOverride.Add(CalChange.Date, not CalChange.Nonworking);
            end else begin
                DiaKey := CalChange.Day;
                if not FCalWeekRule.ContainsKey(DiaKey) then
                    FCalWeekRule.Add(DiaKey, not CalChange.Nonworking);
            end;
        until CalChange.Next() = 0;
    end;

    // In-memory variant of EsDiaHabil — requires EnsureCalendarioCache called first.
    local procedure EsDiaHabilCached(Fecha: Date): Boolean
    var
        DiaSemana: Integer;
    begin
        DiaSemana := Date2DWY(Fecha, 1);
        if FCalCacheCode = '' then
            exit(DiaSemana in [1 .. 5]);
        if FCalDateOverride.ContainsKey(Fecha) then
            exit(FCalDateOverride.Get(Fecha));
        if FCalWeekRule.ContainsKey(DiaSemana) then
            exit(FCalWeekRule.Get(DiaSemana));
        exit(DiaSemana in [1 .. 5]);
    end;

    // If a Base Calendar code is provided, honors its date-specific and weekday
    // nonworking-day rules. With no calendar, defaults to Mon–Fri.
    local procedure EsDiaHabil(Fecha: Date; CodCalendario: Code[10]): Boolean
    var
        CalChange: Record "Base Calendar Change";
        DiaSemana: Integer;
    begin
        DiaSemana := Date2DWY(Fecha, 1); // 1 = Mon … 7 = Sun

        if CodCalendario = '' then
            exit(DiaSemana in [1 .. 5]);

        // Date-specific override wins
        CalChange.SetRange("Base Calendar Code", CodCalendario);
        CalChange.SetRange(Date, Fecha);
        if CalChange.FindFirst() then
            exit(not CalChange.Nonworking);

        // Weekly recurring rule
        CalChange.SetRange(Date, 0D);
        CalChange.SetRange(Day, DiaSemana);
        if CalChange.FindFirst() then
            exit(not CalChange.Nonworking);

        // No rule → default Mon–Fri
        exit(DiaSemana in [1 .. 5]);
    end;

    // ── Dynamic sources ───────────────────────────────────────────────────────

    local procedure LoadDynamicSources(var Ctx: Dictionary of [Text, Decimal])
    var
        Fuente: Record "Fuente Datos Liquidación";
        Valor: Decimal;
    begin
        Fuente.SetRange(Activo, true);
        if not Fuente.FindSet() then
            exit;
        repeat
            // Una sola llamada. Estaba invocada en las dos ramas del if, así que cada fuente
            // resolvía DOS veces —con su lectura de tabla y sus filtros— y el resultado de la
            // primera se descartaba.
            Valor := ResolveFuente(Fuente);
            if not Ctx.ContainsKey(Fuente."Nombre Variable") then
                Ctx.Add(Fuente."Nombre Variable", Valor)
            else
                Ctx.Set(Fuente."Nombre Variable", Valor);
            SetTipo(Fuente."Nombre Variable", 'Fuente Datos');
        until Fuente.Next() = 0;
    end;

    /// <summary>
    /// Valor en su tipo original de las fuentes que no son numéricas, por nombre de variable.
    /// </summary>
    /// <remarks>
    /// El contexto de cálculo sigue siendo solo decimales: esto es lo que se guarda al lado para
    /// auditar e imprimir. Son dos preguntas distintas — con qué número calculó la fórmula, y qué
    /// texto hay que mostrarle a la persona.
    /// </remarks>
    procedure GetValoresTexto(var Destino: Dictionary of [Text, Text])
    var
        Clave: Text;
    begin
        Clear(Destino);
        foreach Clave in FValoresTexto.Keys() do
            Destino.Add(Clave, FValoresTexto.Get(Clave));
    end;

    // Fuentes declaradas como Texto o Fecha. Se leen con la misma semántica que LOOKUP —la última
    // fila que pasa los filtros— y se guardan dos cosas: el valor tal cual, para mostrar, y su
    // proyección a número, que es lo único que la fórmula puede ver.
    local procedure ResolverFuenteNoNumerica(Fuente: Record "Fuente Datos Liquidación"): Decimal
    var
        RecRef: RecordRef;
        FieldVar: FieldRef;
        TextoValor: Text;
        FechaValor: Date;
        FechaInicio: Date;
        MejorInicio: Date;
        Encontrado: Boolean;
    begin
        if (Fuente."Id. Tabla" = 0) or (Fuente."No. Campo Valor" = 0) then
            exit(0);

        RecRef.Open(Fuente."Id. Tabla");
        if not AplicarFiltrosFuente(Fuente, RecRef, false) then begin
            RecRef.Close();
            exit(0);
        end;

        // La vigencia se resuelve recorriendo, no con un SetFilter. El filtro tendría que decir
        // "fecha fin en blanco O >= fecha de referencia", y esa forma sobre un campo Date ya nos
        // costó un cálculo entero: cuando no se comporta como uno espera devuelve menos filas y el
        // error aparece lejos del origen. Acá el recorrido está acotado por los filtros propios de
        // la fuente (empleado + tipo de atributo), así que son unas pocas filas.
        if RecRef.FindSet() then
            repeat
                FechaInicio := 0D;
                if Fuente."No. Campo Fecha Inicio" > 0 then
                    FechaInicio := FieldRefToDate(RecRef.Field(Fuente."No. Campo Fecha Inicio"));
                if FilaVigenteAFechaRef(Fuente, RecRef, FechaInicio) then
                    if (not Encontrado) or (FechaInicio >= MejorInicio) then begin
                        MejorInicio := FechaInicio;
                        Encontrado := true;
                        FieldVar := RecRef.Field(Fuente."No. Campo Valor");
                        TextoValor := Format(FieldVar.Value());
                    end;
            until RecRef.Next() = 0;
        RecRef.Close();

        if not Encontrado then
            exit(0);

        GuardarValorTexto(Fuente."Nombre Variable", TextoValor);
        AppendParamLog('FDS:' + Format(Fuente."Id. Tabla") + '/' + Fuente."Nombre Variable");

        case Fuente."Tipo Dato" of
            Fuente."Tipo Dato"::Texto:
                // Bandera de presencia: 1 si hay valor. Para preguntar por un valor PUNTUAL desde una
                // fórmula, la vía es una fuente con Función Agregado = COUNT y el texto en el filtro,
                // que compara en SQL — el evaluador no tiene tipo texto.
                exit(BoolANumero(TextoValor <> ''));
            Fuente."Tipo Dato"::Fecha:
                begin
                    if not Evaluate(FechaValor, TextoValor) then
                        exit(0);
                    if FechaValor = 0D then
                        exit(0);
                    // Días transcurridos hasta la fecha de referencia. Positivo = pasado (antigüedad,
                    // días desde el último examen), negativo = futuro (días hasta un vencimiento).
                    exit(FFechaRef - FechaValor);
                end;
        end;
        exit(0);
    end;

    // Sin campo de fecha inicio configurado, la fuente no tiene noción de vigencia y toda fila sirve.
    // Con él, vale la fila que ya arrancó y cuyo fin todavía no pasó — fin en blanco = abierta.
    local procedure FilaVigenteAFechaRef(Fuente: Record "Fuente Datos Liquidación"; var RecRef: RecordRef; FechaInicio: Date): Boolean
    var
        FechaFin: Date;
    begin
        if Fuente."No. Campo Fecha Inicio" = 0 then
            exit(true);
        if FechaInicio > FFechaRef then
            exit(false);
        FechaFin := ResolverFechaFin(Fuente, RecRef, FechaInicio);
        if FechaFin = 0D then
            exit(true);
        exit(FechaFin >= FFechaRef);
    end;

    local procedure GuardarValorTexto(NombreVariable: Text; Valor: Text)
    begin
        if FValoresTexto.ContainsKey(NombreVariable) then
            FValoresTexto.Set(NombreVariable, Valor)
        else
            FValoresTexto.Add(NombreVariable, Valor);
    end;

    local procedure BoolANumero(B: Boolean): Decimal
    begin
        if B then
            exit(1);
        exit(0);
    end;

    local procedure ResolveFuente(Fuente: Record "Fuente Datos Liquidación"): Decimal
    var
        RecRef: RecordRef;
        FieldVar: FieldRef;
        Total: Decimal;
        // Las fuentes no numéricas van por otro camino: leen la fila vigente, conservan el valor
        // original para auditar/imprimir y devuelven su proyección a número.
        CurrVal: Decimal;
        FechaInicioRef: FieldRef;
        FechaInicio: Date;
        FechaFin: Date;
        OlapStart: Date;
        OlapEnd: Date;
        FechaInicioAnio: Date;
        FechaFinAnio: Date;
    begin
        if Fuente."Id. Tabla" = 0 then exit(0);
        if Fuente."Tipo Dato" <> Fuente."Tipo Dato"::Decimal then
            exit(ResolverFuenteNoNumerica(Fuente));

        RecRef.Open(Fuente."Id. Tabla");
        if not AplicarFiltrosFuente(Fuente, RecRef, false) then begin
            RecRef.Close();
            exit(0);
        end;
        AppendParamLog('FDS:' + Format(Fuente."Id. Tabla") + '/' + Fuente."Nombre Variable");

        case Fuente."Función Agregado" of
            Fuente."Función Agregado"::COUNT:
                Total := RecRef.Count();
            Fuente."Función Agregado"::SUM:
                if (Fuente."No. Campo Valor" > 0) and RecRef.FindSet() then
                    repeat
                        FieldVar := RecRef.Field(Fuente."No. Campo Valor");
                        Total += FieldRefToDecimal(FieldVar);
                    until RecRef.Next() = 0;
            Fuente."Función Agregado"::MAX:
                if (Fuente."No. Campo Valor" > 0) and RecRef.FindSet() then begin
                    FieldVar := RecRef.Field(Fuente."No. Campo Valor");
                    Total := FieldRefToDecimal(FieldVar);
                    while RecRef.Next() <> 0 do begin
                        FieldVar := RecRef.Field(Fuente."No. Campo Valor");
                        CurrVal := FieldRefToDecimal(FieldVar);
                        if CurrVal > Total then Total := CurrVal;
                    end;
                end;
            Fuente."Función Agregado"::MIN:
                if (Fuente."No. Campo Valor" > 0) and RecRef.FindSet() then begin
                    FieldVar := RecRef.Field(Fuente."No. Campo Valor");
                    Total := FieldRefToDecimal(FieldVar);
                    while RecRef.Next() <> 0 do begin
                        FieldVar := RecRef.Field(Fuente."No. Campo Valor");
                        CurrVal := FieldRefToDecimal(FieldVar);
                        if CurrVal < Total then Total := CurrVal;
                    end;
                end;
            Fuente."Función Agregado"::LOOKUP:
                if (Fuente."No. Campo Valor" > 0) and RecRef.FindLast() then begin
                    FieldVar := RecRef.Field(Fuente."No. Campo Valor");
                    Total := FieldRefToDecimal(FieldVar);
                end;
            Fuente."Función Agregado"::"DIAS_OVERLAP":
                if (Fuente."No. Campo Fecha Inicio" > 0) and RecRef.FindSet() then
                    repeat
                        FechaInicioRef := RecRef.Field(Fuente."No. Campo Fecha Inicio");
                        FechaInicio := FieldRefToDate(FechaInicioRef);
                        FechaFin := ResolverFechaFin(Fuente, RecRef, FechaInicio);
                        if FechaFin = 0D then
                            FechaFin := FFechaRef;
                        OlapStart := FechaInicio;
                        if FPeriodoFechaDesde > OlapStart then OlapStart := FPeriodoFechaDesde;
                        OlapEnd := FechaFin;
                        if FFechaRef < OlapEnd then OlapEnd := FFechaRef;
                        if OlapEnd >= OlapStart then
                            Total += OlapEnd - OlapStart + 1;
                    until RecRef.Next() = 0;
            Fuente."Función Agregado"::"DURACION_INICIO":
                // Returns the full duration of any interval whose start falls within the current period.
                // Used for Art. 155 LCT: vacation pay covers all days if vacation starts this month.
                if (Fuente."No. Campo Fecha Inicio" > 0) and RecRef.FindSet() then
                    repeat
                        FechaInicioRef := RecRef.Field(Fuente."No. Campo Fecha Inicio");
                        FechaInicio := FieldRefToDate(FechaInicioRef);
                        if (FechaInicio >= FPeriodoFechaDesde) and (FechaInicio <= FFechaRef) then begin
                            FechaFin := ResolverFechaFin(Fuente, RecRef, FechaInicio);
                            if FechaFin = 0D then
                                FechaFin := FFechaRef;
                            Total += FechaFin - FechaInicio + 1;
                        end;
                    until RecRef.Next() = 0;
            Fuente."Función Agregado"::"DURACION_ANIO":
                // Same as DIAS_OVERLAP but clips to the full calendar year [01/01, 31/12].
                // Used for VAC_TOMADAS_ANIO via Estado Empleado filtered by vacation state.
                if (Fuente."No. Campo Fecha Inicio" > 0) and RecRef.FindSet() then begin
                    FechaInicioAnio := DMY2Date(1, 1, Date2DMY(FFechaRef, 3));
                    FechaFinAnio := DMY2Date(31, 12, Date2DMY(FFechaRef, 3));
                    repeat
                        FechaInicioRef := RecRef.Field(Fuente."No. Campo Fecha Inicio");
                        FechaInicio := FieldRefToDate(FechaInicioRef);
                        FechaFin := ResolverFechaFin(Fuente, RecRef, FechaInicio);
                        if FechaFin = 0D then
                            FechaFin := FFechaRef;
                        OlapStart := FechaInicio;
                        if FechaInicioAnio > OlapStart then OlapStart := FechaInicioAnio;
                        OlapEnd := FechaFin;
                        if FechaFinAnio < OlapEnd then OlapEnd := FechaFinAnio;
                        if OlapEnd >= OlapStart then
                            Total += OlapEnd - OlapStart + 1;
                    until RecRef.Next() = 0;
                end;
        end;

        RecRef.Close();
        exit(Total);
    end;

    // Interval end of the current source row. With "Fin Efectivo" (effective-dated tables like Estado
    // Empleado, without a stored Fecha Fin), it is the next row's start − 1 for the same entity; otherwise
    // it reads the configured Fecha Fin field. Returns 0D for an open interval (caller clips to FechaRef).
    local procedure ResolverFechaFin(Fuente: Record "Fuente Datos Liquidación"; var RecRef: RecordRef; FechaInicioActual: Date): Date
    begin
        if Fuente."Fin Efectivo" then
            exit(CalcFinEfectivo(Fuente, FechaInicioActual));
        if Fuente."No. Campo Fecha Fin" > 0 then
            exit(FieldRefToDate(RecRef.Field(Fuente."No. Campo Fecha Fin")));
        exit(0D);
    end;

    // Effective end = next row's start − 1 for the same entity. The entity is scoped by the source's
    // TOKEN filters only ({EMP_NO}…); constant selection filters (e.g. Cód. Estado) are ignored so the
    // "next row" is the next state of any type. 0D when there is no later row (open interval).
    local procedure CalcFinEfectivo(Fuente: Record "Fuente Datos Liquidación"; StartActual: Date): Date
    var
        Fechas: List of [Date];
        Cur: Date;
        NextStart: Date;
    begin
        if (Fuente."Id. Tabla" = 0) or (Fuente."No. Campo Fecha Inicio" = 0) then exit(0D);
        Fechas := GetFechasInicioFuente(Fuente);
        foreach Cur in Fechas do
            if Cur > StartActual then
                if (NextStart = 0D) or (Cur < NextStart) then
                    NextStart := Cur;
        if NextStart = 0D then exit(0D);
        exit(NextStart - 1);
    end;

    // Fechas de inicio de la fuente, acotadas SOLO por sus filtros token ({EMP_NO}…), cacheadas por
    // fuente. Los tokens quedan fijos entre Init y el fin del BuildContext, así que el conjunto es
    // constante durante toda la construcción del contexto de un empleado.
    //
    // Antes, CalcFinEfectivo resolvía esto contra la base UNA VEZ POR FILA del agregado que la
    // llamaba: cada llamada abría la tabla, releía "Filtro Fuente Datos Liq." completa dentro de
    // AplicarFiltrosFuente y recorría todas las filas posteriores. Con n estados eso daba del orden
    // de n² consultas por fuente y empleado; ahora es una sola lectura y el resto es memoria.
    //
    // Una fuente cuyos filtros token resuelven a vacío cachea una lista vacía: el llamador termina
    // devolviendo 0D (intervalo abierto), que es exactamente lo que devolvía antes en ese caso.
    local procedure GetFechasInicioFuente(Fuente: Record "Fuente Datos Liquidación") Fechas: List of [Date]
    var
        Rec2: RecordRef;
        CacheKey: Text;
    begin
        CacheKey := Fuente."Nombre Variable";
        if FFinEfCache.ContainsKey(CacheKey) then
            exit(FFinEfCache.Get(CacheKey));

        Rec2.Open(Fuente."Id. Tabla");
        if AplicarFiltrosFuente(Fuente, Rec2, true) then
            if Rec2.FindSet() then
                repeat
                    Fechas.Add(FieldRefToDate(Rec2.Field(Fuente."No. Campo Fecha Inicio")));
                until Rec2.Next() = 0;
        Rec2.Close();
        FFinEfCache.Add(CacheKey, Fechas);
    end;

    // Applies the source's filters to RecRef. When SoloTokens, only filters whose raw value contains a
    // {TOKEN} are applied (they scope the entity); constant filters are skipped. Returns false if a token
    // filter resolved to empty (caller treats as "no data").
    local procedure AplicarFiltrosFuente(Fuente: Record "Fuente Datos Liquidación"; var RecRef: RecordRef; SoloTokens: Boolean): Boolean
    var
        FiltroFDS: Record "Filtro Fuente Datos Liq.";
    begin
        FiltroFDS.SetRange("Nombre Variable", Fuente."Nombre Variable");
        if FiltroFDS.FindSet() then
            repeat
                if not AplicarUnFiltro(RecRef, FiltroFDS."No. Campo", FiltroFDS."Filtro Valor", SoloTokens) then
                    exit(false);
            until FiltroFDS.Next() = 0;
        // Legacy fixed filters (backward compat while data is migrated)
        if not AplicarUnFiltro(RecRef, Fuente."No. Filtro 1", Fuente."Filtro Valor 1", SoloTokens) then exit(false);
        if not AplicarUnFiltro(RecRef, Fuente."No. Filtro 2", Fuente."Filtro Valor 2", SoloTokens) then exit(false);
        if not AplicarUnFiltro(RecRef, Fuente."No. Filtro 3", Fuente."Filtro Valor 3", SoloTokens) then exit(false);
        exit(true);
    end;

    local procedure AplicarUnFiltro(var RecRef: RecordRef; FieldNo: Integer; RawValue: Text; SoloTokens: Boolean): Boolean
    var
        Resolved: Text;
    begin
        if SoloTokens and (not RawValue.Contains('{')) then
            exit(true);   // constant filter → skip when only the entity (token) scope is wanted
        Resolved := ApplyTokens(RawValue);
        if TokenResolvedToEmpty(RawValue, Resolved) then
            exit(false);
        ApplyRecordFilter(RecRef, FieldNo, Resolved);
        exit(true);
    end;

    local procedure ApplyRecordFilter(var RecRef: RecordRef; FieldNo: Integer; FilterValue: Text)
    var
        FieldVar: FieldRef;
    begin
        if (FieldNo = 0) or (FilterValue = '') then exit;
        FieldVar := RecRef.Field(FieldNo);
        FieldVar.SetFilter(FilterValue);
    end;

    // Returns true when a filter template contained a {TOKEN} placeholder that resolved
    // to an empty string (e.g. {LIQ_NO} when no liquidation is in context). Callers return 0
    // rather than querying without that constraint, which would read unrelated records.
    local procedure TokenResolvedToEmpty(Template: Text; Resolved: Text): Boolean
    begin
        exit(Template.Contains('{') and (Resolved = ''));
    end;

    local procedure ApplyTokens(Value: Text): Text
    var
        Anio: Integer;
        SemDesde: Date;
        SemHasta: Date;
    begin
        Value := Value.Replace('{EMP_NO}', FEmployeeNo);
        Value := Value.Replace('{JOB_NO}', FJobNo);
        Value := Value.Replace('{PERIODO}', FCodPeriodo);
        Value := Value.Replace('{FECHA_REF}', Format(FFechaRef));
        Value := Value.Replace('{LIQ_NO}', FLiqNo);
        Value := Value.Replace('{MONEDA}', FMoneda);
        if Value.Contains('{SEM_DESDE}') or Value.Contains('{SEM_HASTA}') then begin
            Anio := Date2DMY(FFechaRef, 3);
            if Date2DMY(FFechaRef, 2) <= 6 then begin
                SemDesde := DMY2Date(1, 1, Anio);
                SemHasta := DMY2Date(30, 6, Anio);
            end else begin
                SemDesde := DMY2Date(1, 7, Anio);
                SemHasta := DMY2Date(31, 12, Anio);
            end;
            Value := Value.Replace('{SEM_DESDE}', Format(SemDesde));
            Value := Value.Replace('{SEM_HASTA}', Format(SemHasta));
        end;
        exit(Value);
    end;

    local procedure FieldRefToDecimal(FieldVar: FieldRef): Decimal
    var
        V: Variant;
        Result: Decimal;
    begin
        V := FieldVar.Value();
        case true of
            V.IsDecimal():
                Result := V;
            V.IsInteger():
                Result := V;
            V.IsBigInteger():
                Result := V;
        end;
        exit(Result);
    end;

    local procedure FieldRefToDate(FieldVar: FieldRef): Date
    var
        V: Variant;
        Result: Date;
    begin
        V := FieldVar.Value();
        if V.IsDate() then
            Result := V;
        exit(Result);
    end;

    // ── Accumulators ──────────────────────────────────────────────────────────

    local procedure InitAccumulators(var Ctx: Dictionary of [Text, Decimal])
    var
        Concepto: Record "Concepto Liquidación";
        Procesados: List of [Code[20]];
    begin
        // All accumulators are configured as concepts with Es Acumulador = true.
        // No hardcoded names — add or rename accumulators purely as data.
        //
        // El barrido solo propone candidatos: es acumulador el concepto cuya VERSIÓN VIGENTE a la
        // fecha de referencia lo declara así, y eso lo decide EsAcumuladorVigente. Antes se recorrían
        // todas las vigencias sin filtro de fecha, así que un concepto que recién pasa a ser
        // acumulador el año que viene ya se inicializaba hoy, y uno que dejó de serlo seguía
        // creando su clave. WriteAccumulatorLines (Cod50014) sí resuelve por versión: las dos
        // mitades del mecanismo no coincidían.
        Concepto.SetRange("Es Acumulador", true);
        Concepto.SetFilter("Vigencia Desde", '<=%1', FFechaRef);
        if Concepto.FindSet() then
            repeat
                if not Procesados.Contains(Concepto.Código) then begin
                    Procesados.Add(Concepto.Código);
                    if EsAcumuladorVigente(Concepto.Código) then
                        InicializarAcumulador(Ctx, Concepto.Código);
                end;
            until Concepto.Next() = 0;
    end;

    local procedure EsAcumuladorVigente(CodConcepto: Code[20]): Boolean
    var
        Vigente: Record "Concepto Liquidación";
    begin
        Vigente.SetRange(Código, CodConcepto);
        // Con el intervalo en el filtro, FindLast no puede caer en una versión ya cerrada: un
        // concepto en un hueco de vigencia —cerrado en marzo, retomado en julio— no devuelve nada
        // para mayo, en lugar de resucitar la versión de marzo.
        Vigente.FiltrarVigentesA(FFechaRef);
        if not Vigente.FindLast() then
            exit(false);
        exit(Vigente."Es Acumulador" and Vigente.VigenteA(FFechaRef));
    end;

    local procedure InicializarAcumulador(var Ctx: Dictionary of [Text, Decimal]; CodConcepto: Code[20])
    begin
        // Un acumulador siempre arranca en 0, aunque otra fuente (Parámetro, Variable Sistema,
        // Fuente Datos) haya cargado antes una clave con el mismo nombre — de lo contrario el
        // acumulador queda "sembrado" con ese valor ajeno y todo lo que aportan los conceptos se
        // suma encima en vez de partir de cero.
        if Ctx.ContainsKey(CodConcepto) then
            Ctx.Set(CodConcepto, 0)
        else
            Ctx.Add(CodConcepto, 0);
        SetTipo(CodConcepto, 'Acumulador');
    end;

    local procedure AppendParamLog(Entry: Text)
    begin
        if FParamLog <> '' then
            FParamLog += '|';
        FParamLog += Entry;
    end;

    local procedure SetTipo(VarName: Text; Tipo: Text)
    begin
        if not FTipoMap.ContainsKey(VarName) then
            FTipoMap.Add(VarName, Tipo)
        else
            FTipoMap.Set(VarName, Tipo);
    end;

    procedure GetTipoMap(var TipoMap: Dictionary of [Text, Text])
    begin
        TipoMap := FTipoMap;
    end;
}
