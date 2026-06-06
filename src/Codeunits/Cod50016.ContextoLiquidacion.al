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
        FTipoLiq: Enum "Tipo Liq.";
        FParamLog: Text;
        FParamCodMap: Dictionary of [Text, Code[50]]; // NombreVar → CódParámetroEfectivo
        FParamVigMap: Dictionary of [Text, Date];     // NombreVar → VigenciaDesde
        FTipoMap: Dictionary of [Text, Text];         // NombreVar → 'Parámetro'|'Sistema'|'Fuente Datos'|'Acumulador'

    procedure Init(
        EmployeeNo: Code[20];
        JobNo: Code[20];
        CodPeriodo: Code[10];
        FechaRef: Date;
        CodConvenio: Code[20];
        CodCategoria: Code[20];
        LiqNo: Code[20];
        TipoLiq: Enum "Tipo Liq.")
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
        Clear(FParamCodMap);
        Clear(FParamVigMap);
        Clear(FTipoMap);
    end;

    procedure BuildContext(var Ctx: Dictionary of [Text, Decimal])
    begin
        Clear(Ctx);
        LoadScalars(Ctx);
        LoadDynamicSources(Ctx);
        InitAccumulators(Ctx);
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
            if Param."Sufijo Empleado" then
                CodigoEfectivo := Param.Código + '_' + FEmployeeNo
            else if Param."Sufijo CCT" then
                CodigoEfectivo := Param.Código + '_' + FCodConvenio + '_' + FCodCategoria
            else
                CodigoEfectivo := Param.Código;

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

            // {VarName}_ESFCY = 1 when the parameter value is stored in foreign currency,
            // 0 when it is already in local currency. Lets formulas gate TC multiplication:
            //   IF(BASICO_ESFCY, BASICO * TC_CERCANO, BASICO)
            // Uppercase suffix so it matches the formula evaluator's ToUpper() normalization.
            NombreEsFCY := Param."Nombre Variable" + '_ESFCY';
            if Moneda <> '' then EsFCY := 1 else EsFCY := 0;
            if not Ctx.ContainsKey(NombreEsFCY) then
                Ctx.Add(NombreEsFCY, EsFCY)
            else
                Ctx.Set(NombreEsFCY, EsFCY);
            SetTipo(NombreEsFCY, 'Parámetro');

            // Record source so MarkEnUso can find the record when the var is actually used
            if VigDate > 0D then begin
                if not FParamCodMap.ContainsKey(Param."Nombre Variable") then
                    FParamCodMap.Add(Param."Nombre Variable", CodigoEfectivo)
                else
                    FParamCodMap.Set(Param."Nombre Variable", CodigoEfectivo);
                if not FParamVigMap.ContainsKey(Param."Nombre Variable") then
                    FParamVigMap.Add(Param."Nombre Variable", VigDate)
                else
                    FParamVigMap.Set(Param."Nombre Variable", VigDate);
            end;
        until Param.Next() = 0;
    end;

    // Single sorted pass over Parámetro Vigente keeps only the latest vigencia <= FFechaRef
    // per Cód. Parámetro. Replaces one FindLast() per parameter (N queries → 1 scan).
    local procedure BuildParametroCache(
        var ValorMap: Dictionary of [Code[50], Decimal];
        var VigMap: Dictionary of [Code[50], Date];
        var MonedaMap: Dictionary of [Code[50], Code[10]])
    var
        ParamVig: Record "Parámetro Vigente";
    begin
        ParamVig.SetCurrentKey("Cód. Parámetro", "Vigencia Desde");
        ParamVig.SetFilter("Vigencia Desde", '<=%1', FFechaRef);
        if not ParamVig.FindSet() then exit;
        repeat
            // Sorted ascending by vigencia within each code → last write wins
            if ValorMap.ContainsKey(ParamVig."Cód. Parámetro") then begin
                ValorMap.Set(ParamVig."Cód. Parámetro", ParamVig.Valor);
                VigMap.Set(ParamVig."Cód. Parámetro", ParamVig."Vigencia Desde");
                MonedaMap.Set(ParamVig."Cód. Parámetro", ParamVig.Moneda);
            end else begin
                ValorMap.Add(ParamVig."Cód. Parámetro", ParamVig.Valor);
                VigMap.Add(ParamVig."Cód. Parámetro", ParamVig."Vigencia Desde");
                MonedaMap.Add(ParamVig."Cód. Parámetro", ParamVig.Moneda);
            end;
        until ParamVig.Next() = 0;
    end;

    procedure MarkEnUso(EvalParamLog: Text)
    var
        Entries: List of [Text];
        Entry: Text;
        VarName: Text;
        ParamVig: Record "Parámetro Vigente";
    begin
        Entries := EvalParamLog.Split('|');
        foreach Entry in Entries do begin
            if Entry.StartsWith('VAR:') then begin
                VarName := CopyStr(Entry, 5); // strip 'VAR:' prefix
                if FParamCodMap.ContainsKey(VarName) and FParamVigMap.ContainsKey(VarName) then
                    if ParamVig.Get(FParamCodMap.Get(VarName), FParamVigMap.Get(VarName)) then
                        if not ParamVig."En Uso" then begin
                            ParamVig."En Uso" := true;
                            ParamVig.Modify();
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
        Job: Record Job;
        Dias: Decimal;
    begin
        case VarSis."Cód. Cálculo" of
            'ANIOS_ANTIGUEDAD':
                exit(CalcAntiguedad());
            'DIAS_HAB':
                exit(CalcDiasHabiles());
            'PCT_ESCALA':
                begin
                    if Cat.Get(FCodConvenio, FCodCategoria) then
                        exit(Cat."% Escala" / 100);
                    exit(0);
                end;
            'DIAS_PROYECTO':
                begin
                    if (FJobNo <> '') and Job.Get(FJobNo) and
                       (Job."Ending Date" > 0D) and (Job."Starting Date" > 0D)
                    then begin
                        // Base: days from departure to day before arrival
                        Dias := Job."Ending Date" - Job."Starting Date";
                        // Arrival PM (≥ 12:00) → arrival day counts as navegación
                        if Job."Hora ingreso a puerto" >= 120000T then
                            Dias += 1;
                        // Departure PM (≥ 12:00) → departure day counts as puerto
                        if Job."Hora de zarpada" >= 120000T then
                            Dias -= 1;
                        exit(Dias);
                    end;
                    exit(0);
                end;
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
            'TIPO_LIQ':
                exit(FTipoLiq.AsInteger());
            'YTD_ACUM':
                exit(CalcImporteAnualPorAcumulador(VarSis."Cód. Acumulador"));
            'YTD_LINEAS':
                exit(CalcImporteAnualLiq(VarSis."Tipo Concepto", ''));
            else
                exit(0);
        end;
    end;

    // Returns the YTD sum of LinLiq.Importe for all concepts that feed CodAcum
    // (Restar = false, latest Vigencia <= FFechaRef). Each distinct concept code counted once.
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
        //Fraccion.SetRange(Restar, false);
        Fraccion.SetFilter("Vigencia Desde", '<=%1', FFechaRef);
        if not Fraccion.FindSet() then exit(0);
        repeat
            if not Procesados.ContainsKey(Fraccion."Cód. Concepto") then begin
                Procesados.Add(Fraccion."Cód. Concepto", true);
                LinLiq.Reset();
                LinLiq.SetRange("No. Empleado", FEmployeeNo);
                LinLiq.SetRange("Fecha Liquidación", AnioInicio, FFechaRef);
                LinLiq.SetRange("Cód. Concepto", Fraccion."Cód. Concepto");
                LinLiq.CalcSums(Importe);
                If Fraccion.Restar then
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
        LinLiq.CalcSums(Importe);
        exit(LinLiq.Importe);
    end;

    local procedure CalcDeduccionesGanancias(): Decimal
    var
        EmpDed: Record "Ded. Ganancias Empleado";
        EmpRel: Record "Employee Relative";
        ParamVig: Record "Parámetro Vigente";
        Param: Record "Parámetro";
        DetGan: Record "Detalle Ganancias Liq.";
        VigenciaEfectiva: Date;
        TipoCount: Dictionary of [Code[20], Integer];
        CodTipo: Code[20];
        Cnt: Integer;
        Total: Decimal;
        ParamDesc: Text[100];
    begin
        // Part 1: family members — count active Employee Relative rows per deduction type
        EmpRel.SetRange("Employee No.", FEmployeeNo);
        EmpRel.SetFilter("Cód. Tipo Ded.", '<>%1', '');
        if EmpRel.FindSet() then
            repeat
                if ((EmpRel."Fecha Ingreso Impuesto" = 0D) or (EmpRel."Fecha Ingreso Impuesto" <= FFechaRef)) and
                   ((EmpRel."Fecha Egreso Impuesto" = 0D) or (EmpRel."Fecha Egreso Impuesto" >= FPeriodoFechaDesde))
                then begin
                    CodTipo := EmpRel."Cód. Tipo Ded.";
                    if TipoCount.ContainsKey(CodTipo) then
                        TipoCount.Set(CodTipo, TipoCount.Get(CodTipo) + 1)
                    else
                        TipoCount.Add(CodTipo, 1);
                end;
            until EmpRel.Next() = 0;

        foreach CodTipo in TipoCount.Keys() do begin
            Cnt := TipoCount.Get(CodTipo);
            ParamVig.SetRange("Cód. Parámetro", CodTipo);
            ParamVig.SetFilter("Vigencia Desde", '<=%1', FFechaRef);
            if ParamVig.FindLast() then begin
                if Param.Get(CodTipo) then
                    ParamDesc := Param.Descripción
                else
                    ParamDesc := CodTipo;
                AppendParamLog('DED_FAM:' + CodTipo + '|' + Format(ParamVig."Vigencia Desde") + '|' + Format(Cnt));
                Total += ParamVig.Valor * Cnt;
                if FLiqNo <> '' then begin
                    Clear(DetGan);
                    DetGan."No. Liquidación" := FLiqNo;
                    DetGan.Tipo := DetGan.Tipo::Familiar;
                    DetGan.Código := CodTipo;
                    DetGan.Descripción := CopyStr(ParamDesc, 1, MaxStrLen(DetGan.Descripción));
                    DetGan.Cantidad := Cnt;
                    DetGan."Importe Unit. Anual" := ParamVig.Valor;
                    DetGan."Importe Total" := ParamVig.Valor * Cnt;
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
    begin
        exit(CalcAntiguedadAlFecha(FFechaRef));
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

    // Art. 167 LCT: 1 day per 20 effective working days, truncated (no rounding up).
    local procedure CalcVacacionesProporcionales(): Decimal
    begin
        exit(Round(CalcDiasAltaAnio() / 20, 1, '<'));
    end;

    // Calendar days in Vacaciones state that overlap with [FPeriodoFechaDesde, FFechaRef].
    // Used as DIAS_VAC_PERIODO in the vacation day discount formula.
    local procedure CalcDiasVacacionesPeriodo(): Decimal
    var
        EstadoEmp: Record "Estado Empleado";
        CodEst: Record "Cód. Estado Empleado";
        FechaFinEfectiva: Date;
        OlapStart: Date;
        OlapEnd: Date;
        Total: Integer;
    begin
        EstadoEmp.SetRange("No. Empleado", FEmployeeNo);
        if not EstadoEmp.FindSet() then exit(0);
        repeat
            if CodEst.Get(EstadoEmp."Cód. Estado") and
               (CodEst."Tipo Estado" = CodEst."Tipo Estado"::Vacaciones)
            then begin
                FechaFinEfectiva := EstadoEmp."Fecha Fin";
                if FechaFinEfectiva = 0D then FechaFinEfectiva := FFechaRef;
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
        FechaActual := DMY2Date(1, 1, Anio);
        while FechaActual <= DMY2Date(31, 12, Anio) do begin
            if EsDiaHabil(FechaActual, CodCalendario) then
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
                                if EsDiaHabil(FechaActual, CodCalendario) then
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
                if EsDiaHabil(FechaActual, CodCalendario) then
                    Dias += 1;
                FechaActual += 1;
            end;
        end;

        exit(Dias);
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
    begin
        Fuente.SetRange(Activo, true);
        if not Fuente.FindSet() then
            exit;
        repeat
            if not Ctx.ContainsKey(Fuente."Nombre Variable") then
                Ctx.Add(Fuente."Nombre Variable", ResolveFuente(Fuente))
            else
                Ctx.Set(Fuente."Nombre Variable", ResolveFuente(Fuente));
            SetTipo(Fuente."Nombre Variable", 'Fuente Datos');
        until Fuente.Next() = 0;
    end;

    local procedure ResolveFuente(Fuente: Record "Fuente Datos Liquidación"): Decimal
    var
        RecRef: RecordRef;
        FieldVar: FieldRef;
        Total: Decimal;
        CurrVal: Decimal;
        FechaInicioRef: FieldRef;
        FechaFinRef: FieldRef;
        FechaInicio: Date;
        FechaFin: Date;
        OlapStart: Date;
        OlapEnd: Date;
        FechaInicioAnio: Date;
        FechaFinAnio: Date;
    begin
        if Fuente."Id. Tabla" = 0 then exit(0);

        RecRef.Open(Fuente."Id. Tabla");
        ApplyRecordFilter(RecRef, Fuente."No. Filtro 1", ApplyTokens(Fuente."Filtro Valor 1"));
        ApplyRecordFilter(RecRef, Fuente."No. Filtro 2", ApplyTokens(Fuente."Filtro Valor 2"));
        ApplyRecordFilter(RecRef, Fuente."No. Filtro 3", ApplyTokens(Fuente."Filtro Valor 3"));
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
                        if Fuente."No. Campo Fecha Fin" > 0 then begin
                            FechaFinRef := RecRef.Field(Fuente."No. Campo Fecha Fin");
                            FechaFin := FieldRefToDate(FechaFinRef);
                        end else
                            FechaFin := 0D;
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
                            if Fuente."No. Campo Fecha Fin" > 0 then begin
                                FechaFinRef := RecRef.Field(Fuente."No. Campo Fecha Fin");
                                FechaFin := FieldRefToDate(FechaFinRef);
                            end else
                                FechaFin := 0D;
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
                        if Fuente."No. Campo Fecha Fin" > 0 then begin
                            FechaFinRef := RecRef.Field(Fuente."No. Campo Fecha Fin");
                            FechaFin := FieldRefToDate(FechaFinRef);
                        end else
                            FechaFin := 0D;
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

    local procedure ApplyRecordFilter(var RecRef: RecordRef; FieldNo: Integer; FilterValue: Text)
    var
        FieldVar: FieldRef;
    begin
        if (FieldNo = 0) or (FilterValue = '') then exit;
        FieldVar := RecRef.Field(FieldNo);
        FieldVar.SetFilter(FilterValue);
    end;

    local procedure ApplyTokens(Value: Text): Text
    begin
        Value := Value.Replace('{EMP_NO}', FEmployeeNo);
        Value := Value.Replace('{JOB_NO}', FJobNo);
        Value := Value.Replace('{PERIODO}', FCodPeriodo);
        Value := Value.Replace('{FECHA_REF}', Format(FFechaRef));
        Value := Value.Replace('{LIQ_NO}', FLiqNo);
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
    begin
        // All accumulators are configured as concepts with Es Acumulador = true.
        // No hardcoded names — add or rename accumulators purely as data.
        Concepto.SetRange("Es Acumulador", true);
        Concepto.SetRange(Activo, true);
        if Concepto.FindSet() then
            repeat
                if not Ctx.ContainsKey(Concepto.Código) then
                    Ctx.Add(Concepto.Código, 0);
                SetTipo(Concepto.Código, 'Acumulador');
            until Concepto.Next() = 0;
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
