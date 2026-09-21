namespace UAS.Payroll;

using Microsoft.Projects.Project.Job;
using Microsoft.HumanResources.Employee;
using Microsoft.Foundation.Calendar;

codeunit 50016 "Contexto Liquidación"
{
    // Builds the variable dictionary fed to the formula evaluator.
    //
    // Variable resolution order:
    //   1. Fixed scalar variables (BASICO, DIAS_MAR, AÑOS_ANTIGUEDAD, etc.)
    //   2. Dynamic sources from "Fuente Datos Liquidación" records
    //   3. Atributos de entidad: un valor por cada "Tipo Atributo Liq." con Nombre Variable, resuelto
    //      contra la entidad de esta liquidación (empleado, proyecto o buque del proyecto)
    //   4. Accumulators initialised to 0 (updated by the motor as concepts run)
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
        FPeriodosMes: List of [Code[10]];
        FPeriodosMesCargados: Boolean;
        FParamLog: Text;
        FActualCodMap: Dictionary of [Code[50], Code[50]]; // EffectiveKey → CódParámetro real en DB
        FParamBaseMap: Dictionary of [Text, Code[20]];  // NombreVar → CódParámetroBase
        FParamCodMap: Dictionary of [Text, Code[50]];   // NombreVar → CódParámetro real en DB
        FParamVigMap: Dictionary of [Text, Date];       // NombreVar → VigenciaDesde
        FMoneda: Code[10];
        FTipoMap: Dictionary of [Text, Text];          // NombreVar → 'Atributo'|'Parámetro'|'Sistema'|'Fuente Datos'|'Acumulador'
        FValoresTexto: Dictionary of [Text, Text];     // NombreVar → valor en su tipo original (fuentes no numéricas)
        FAdvertenciasParametros: Text;
        MsgParamSinValor: Label '%1: no tiene ningún valor cargado en Parámetros Vigentes.';
        MsgCodCalculoDesconocido: Label 'La variable %1 tiene el Cód. Cálculo "%2", que el motor no conoce: vale CERO en todas las fórmulas que la usen. Revisá el código en Variables de Sistema.', Comment = '%1=nombre de la variable, %2=código de cálculo';
        MsgFuenteSinFiltros: Label 'La Fuente de Datos %1 no tiene ningún filtro cargado: está agregando la tabla entera. Si sus filtros vivían en "Filtro Fuente Datos Liq.", revisá que sigan cargados.', Comment = '%1=nombre de variable de la fuente';
        MsgParamDesactualizado: Label '%1: el último valor vigente es del %2 (%3 día(s) de antigüedad respecto a la liquidación). Verifique si corresponde cargar una versión más reciente.';
        // Calendar cache — loaded once per (CodCalendario, Año), shared by CalcDiasHabilesAnio
        // and CalcDiasAltaAnio to avoid ~730 DB queries per liquidation.
        FSilenciarAvisosParam: Boolean;
        // Caché de los valores de parámetro por par convenio/categoría — ver UsarParCCT.
        FNombresParam: List of [Text];
        FParClave1: Text;
        FParValores1: Dictionary of [Text, Decimal];
        FParClave2: Text;
        FParValores2: Dictionary of [Text, Decimal];
        FCalCacheLoaded: Boolean;
        FCalCacheCode: Code[10];
        FCalCacheAnio: Integer;
        FCalDateOverride: Dictionary of [Date, Boolean]; // specific date → is_working
        FCalWeekRule: Dictionary of [Integer, Boolean];  // day_of_week (1=Mon..7=Sun) → is_working
        // Fechas de inicio por fuente "Fin Efectivo" — ver GetFechasInicioFuente.
        FFinEfCache: Dictionary of [Text, List of [Date]]; // Nombre Variable → fechas de inicio del scope token
        FFinEfMapa: Dictionary of [Text, Date];            // "NombreVar|fecha" → fin efectivo de ese inicio
        FFinEfOrden: Dictionary of [Text, Boolean];        // Nombre Variable → la lista vino ordenada y hay mapa

    procedure Init(
        EmployeeNo: Code[20];
        JobNo: Code[20];
        CodPeriodo: Code[10];
        FechaRef: Date;
        CodConvenio: Code[20];
        CodCategoria: Code[20];
        LiqNo: Code[20];
        TipoLiq: Code[20];
        CoberturaDesde: Date)
    var
        Periodo: Record "Período Liquidación";
    begin
        FEmployeeNo := EmployeeNo;
        FJobNo := JobNo;
        FCodPeriodo := CodPeriodo;
        FFechaRef := FechaRef;
        // LA VENTANA ES LA DE LA LIQUIDACIÓN, NO LA DEL PERÍODO. Un cierre de marea
        // vive dentro de un período mensual pero cubre sólo sus días: la del 3/1 al
        // 29/1 de enero no tiene por qué ver lo que pasó el 1 y el 2. Tomando el
        // inicio del período, toda variable de período —DIAS_GP_PERIODO, francos,
        // vacaciones, cualquier Fuente de Datos— arrastraba días de antes del
        // embarque, que además ya los paga la liquidación REGULAR de la nómina:
        // se contaban dos veces.
        //
        // El límite superior no hace falta tocarlo: FechaRef ya es Cobertura Hasta
        // en las 156 liquidaciones que tienen cobertura cargada.
        if CoberturaDesde <> 0D then
            FPeriodoFechaDesde := CoberturaDesde
        else if Periodo.Get(CodPeriodo) then
            FPeriodoFechaDesde := Periodo."Fecha Desde"
        else
            FPeriodoFechaDesde := FechaRef;
        FCodConvenio := CodConvenio;
        FCodCategoria := CodCategoria;
        FLiqNo := LiqNo;
        FTipoLiq := TipoLiq;
        FParamLog := '';
        FMoneda := '';
        // Los períodos del mes se recalculan por liquidación: el mismo codeunit se reusa para todo
        // un lote, y un lote puede cruzar meses.
        Clear(FPeriodosMes);
        FPeriodosMesCargados := false;
        FAdvertenciasParametros := '';
        Clear(FValoresTexto);
        Clear(FActualCodMap);
        Clear(FParamBaseMap);
        Clear(FParamCodMap);
        Clear(FParamVigMap);
        Clear(FTipoMap);
        Clear(FFinEfCache);
        // Van juntos: son la misma información en otra forma. Limpiar uno y no los otros dejaría el
        // mapa del empleado anterior contestando por el nuevo, y sin error.
        Clear(FFinEfMapa);
        Clear(FFinEfOrden);
        // La caché por par es POR LIQUIDACIÓN: los valores dependen del empleado y de la fecha de
        // referencia, así que arrastrarla a la siguiente daría importes de otra persona.
        FParClave1 := '';
        FParClave2 := '';
        Clear(FParValores1);
        Clear(FParValores2);
        Clear(FNombresParam);
        FCalCacheLoaded := false;
    end;

    procedure BuildContext(var Ctx: Dictionary of [Text, Decimal])
    begin
        Clear(Ctx);
        LoadScalars(Ctx);
        LoadDynamicSources(Ctx);
        LoadAtributos(Ctx);
        InitAccumulators(Ctx);
    end;

    /// <summary>
    /// El mismo juego de NOMBRES que BuildContext, pero todos en cero y sin resolver nada.
    /// </summary>
    /// <remarks>
    /// Para la validación de fórmulas, que es lo primero que hace el motor. Ahí no interesa cuánto
    /// vale cada variable: se busca que la fórmula sea sintácticamente válida, que sus funciones
    /// existan y que cada nombre que menciona esté definido en algún lado. Todo eso depende del
    /// juego de nombres, no de los valores.
    ///
    /// Construir el contexto completo para eso costaba una liquidación entera de más: la cascada de
    /// sufijos de cada parámetro, el cálculo de cada variable de sistema —días de navegación,
    /// francos FIFO, deducciones, calendarios— y una consulta por cada Fuente de Datos. Todo para
    /// tirarlo y volver a construirlo diez líneas después, porque el contexto real se arma DESPUÉS
    /// de materializar préstamos y novedades y no puede reutilizar éste.
    ///
    /// Lo que se pierde: un error que solo aparezca con ciertos valores —una tabla escalonada sin
    /// tramo para el importe real— ya no lo detecta la fase 1 y explota en la fase 2. Sale por el
    /// mismo camino (el cálculo falla y queda registrado), solo que sin el aviso anticipado.
    /// </remarks>
    procedure BuildContextParaValidacion(var Ctx: Dictionary of [Text, Decimal])
    var
        Param: Record "Parámetro";
        VarSis: Record "Variable Sistema Liq.";
        Fuente: Record "Fuente Datos Liquidación";
        TipoAtr: Record "Tipo Atributo Liq.";
    begin
        Clear(Ctx);

        Param.SetFilter("Nombre Variable", '<>%1', '');
        if Param.FindSet() then
            repeat
                DefinirEnCero(Ctx, Param."Nombre Variable", 'Parámetro');
                DefinirEnCero(Ctx, Param."Nombre Variable" + '_ESFCY', 'Parámetro');
            until Param.Next() = 0;

        VarSis.SetRange(Activo, true);
        VarSis.SetFilter("Nombre Variable", '<>%1', '');
        if VarSis.FindSet() then
            repeat
                DefinirEnCero(Ctx, VarSis."Nombre Variable", 'Sistema');
            until VarSis.Next() = 0;

        Fuente.SetRange(Activo, true);
        if Fuente.FindSet() then
            repeat
                DefinirEnCero(Ctx, Fuente."Nombre Variable", 'Fuente Datos');
            until Fuente.Next() = 0;

        TipoAtr.SetFilter("Nombre Variable", '<>%1', '');
        if TipoAtr.FindSet() then
            repeat
                DefinirEnCero(Ctx, TipoAtr."Nombre Variable", 'Atributo');
            until TipoAtr.Next() = 0;

        InitAccumulators(Ctx);
    end;

    local procedure DefinirEnCero(var Ctx: Dictionary of [Text, Decimal]; Nombre: Text; Tipo: Text)
    begin
        if Nombre = '' then
            exit;
        if not Ctx.ContainsKey(Nombre) then
            Ctx.Add(Nombre, 0);
        SetTipo(Nombre, Tipo);
    end;

    /// <summary>
    /// Reresuelve en Ctx todo lo que depende del par convenio/categoría, con el par indicado.
    /// </summary>
    /// <remarks>
    /// Para los conceptos que se liquidan con el par de la asignación al proyecto y no con el del
    /// empleado. El motor la llama antes de evaluar uno de esos conceptos y la vuelve a llamar con
    /// el par original después, así el resto del cálculo no se entera.
    ///
    /// Se recargan los PARÁMETROS —que es donde vive la cascada por sufijo `CÓDIGO_CONVENIO_CATEGORÍA`—
    /// y PCT_ESCALA, que sale de la Categoría CCT. Deliberadamente NO se vuelve a correr el resto de
    /// las variables de sistema: ninguna otra depende del par, y LoadVariablesSistema además escribe
    /// las filas del detalle de Ganancias, que se duplicarían una vez por concepto marcado.
    ///
    /// Los avisos de parámetro desactualizado se silencian en la recarga: son los mismos parámetros
    /// que ya se revisaron al armar el contexto, y repetirlos por cada concepto marcado llenaría el
    /// mensaje final de líneas iguales.
    /// </remarks>
    procedure UsarParCCT(CodConvenio: Code[20]; CodCategoria: Code[20]; var Ctx: Dictionary of [Text, Decimal])
    var
        ClaveNueva: Text;
    begin
        if (CodConvenio = FCodConvenio) and (CodCategoria = FCodCategoria) then
            exit;

        // Lo que está en el contexto AHORA se guarda antes de irse, para poder volver sin ir a la
        // base. En una liquidación hay a lo sumo dos pares en juego —el del empleado y el de la
        // asignación—, así que después del primer cambio todo el resto es memoria.
        //
        // Sin esto, cada concepto marcado costaba DOS reconstrucciones completas de la cascada de
        // parámetros (una al entrar y otra al salir). Con quince conceptos de producción marcados y
        // un lote de cincuenta liquidaciones, eso es mil quinientas reconstrucciones para leer los
        // mismos valores una y otra vez.
        GuardarValoresDelPar(FCodConvenio + '|' + FCodCategoria, Ctx);

        FCodConvenio := CodConvenio;
        FCodCategoria := CodCategoria;
        ClaveNueva := CodConvenio + '|' + CodCategoria;

        if not RestaurarValoresDelPar(ClaveNueva, Ctx) then begin
            FSilenciarAvisosParam := true;
            LoadParametros(Ctx);
            FSilenciarAvisosParam := false;
            GuardarValoresDelPar(ClaveNueva, Ctx);
        end;

        // PCT_ESCALA se recalcula siempre: es una sola lectura de Categoría CCT, más barata que
        // guardarla y menos frágil que suponer que no cambió.
        RecargarPctEscala(Ctx);
    end;

    // Dos ranuras alcanzan y sobran: el par del empleado y el de la asignación. Si alguna vez
    // aparece un tercero, la más vieja se pisa y lo único que se pierde es la caché — el valor se
    // vuelve a leer de la base, que es exactamente lo que se hacía antes.
    local procedure GuardarValoresDelPar(Clave: Text; var Ctx: Dictionary of [Text, Decimal])
    begin
        if (FParClave1 = '') or (FParClave1 = Clave) then begin
            FParClave1 := Clave;
            CapturarValoresParam(Ctx, FParValores1);
            exit;
        end;
        FParClave2 := Clave;
        CapturarValoresParam(Ctx, FParValores2);
    end;

    local procedure RestaurarValoresDelPar(Clave: Text; var Ctx: Dictionary of [Text, Decimal]): Boolean
    begin
        if (FParClave1 = Clave) and (FParValores1.Count() > 0) then begin
            AplicarValoresParam(Ctx, FParValores1);
            exit(true);
        end;
        if (FParClave2 = Clave) and (FParValores2.Count() > 0) then begin
            AplicarValoresParam(Ctx, FParValores2);
            exit(true);
        end;
        exit(false);
    end;

    // El nombre de variable NO es único entre parámetros: LoadParametros ya lo contempla —usa
    // ContainsKey/Set y no Add— porque dos filas de Parámetro pueden declarar el mismo nombre y gana
    // la última. Acá hay que hacer lo mismo: un Add sobre una clave repetida corta el cálculo con
    // "ya se ha agregado un producto con la misma clave", que no dice nada sobre lo que pasó.
    local procedure CapturarValoresParam(var Ctx: Dictionary of [Text, Decimal]; var Destino: Dictionary of [Text, Decimal])
    var
        Nombre: Text;
    begin
        Clear(Destino);
        foreach Nombre in FNombresParam do
            if Ctx.ContainsKey(Nombre) then
                if Destino.ContainsKey(Nombre) then
                    Destino.Set(Nombre, Ctx.Get(Nombre))
                else
                    Destino.Add(Nombre, Ctx.Get(Nombre));
    end;

    local procedure AplicarValoresParam(var Ctx: Dictionary of [Text, Decimal]; var Origen: Dictionary of [Text, Decimal])
    var
        Nombre: Text;
    begin
        foreach Nombre in Origen.Keys() do
            if Ctx.ContainsKey(Nombre) then
                Ctx.Set(Nombre, Origen.Get(Nombre))
            else
                Ctx.Add(Nombre, Origen.Get(Nombre));
    end;

    /// <summary>El par con el que está resolviendo el contexto ahora mismo.</summary>
    procedure GetParCCT(var CodConvenio: Code[20]; var CodCategoria: Code[20])
    begin
        CodConvenio := FCodConvenio;
        CodCategoria := FCodCategoria;
    end;

    // PCT_ESCALA es la única variable de sistema que depende del par. Se busca por su Cód. Cálculo
    // y no por su nombre, que es configurable.
    local procedure RecargarPctEscala(var Ctx: Dictionary of [Text, Decimal])
    var
        VarSis: Record "Variable Sistema Liq.";
        Valor: Decimal;
    begin
        VarSis.SetRange(Activo, true);
        VarSis.SetRange("Cód. Cálculo", 'PCT_ESCALA');
        if not VarSis.FindSet() then
            exit;
        repeat
            Valor := ComputeVariableSistema(VarSis);
            if Ctx.ContainsKey(VarSis."Nombre Variable") then
                Ctx.Set(VarSis."Nombre Variable", Valor)
            else
                Ctx.Add(VarSis."Nombre Variable", Valor);
        until VarSis.Next() = 0;
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

        // La lista de nombres que esta pasada escribe en el contexto. La usa la caché por par para
        // saber qué copiar y qué restaurar sin volver a la base.
        Clear(FNombresParam);

        Param.SetFilter("Nombre Variable", '<>%1', '');
        if not Param.FindSet() then exit;
        repeat
            FNombresParam.Add(Param."Nombre Variable");
            FNombresParam.Add(Param."Nombre Variable" + '_ESFCY');
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
    //   COD_<empleado> → COD_<convenio>_<categoría> → COD_<convenio> → COD
    // La fila sin convenio ni categoría deriva la clave base (COD) y hace de valor por defecto:
    // así se cargan solo las excepciones por convenio/categoría y el resto cae al genérico, en vez
    // de quedar en 0 por no existir la combinación exacta.
    // Si no hay ninguna, devuelve la más específica (no encontrada) para conservar el comportamiento
    // previo: el llamador la trata como valor 0 / sin vigencia.
    local procedure ResolverCodigoEfectivo(var Param: Record "Parámetro"; var ValorMap: Dictionary of [Code[50], Decimal]): Code[50]
    var
        Claves: Codeunit "Claves Parámetro Liq.";
    begin
        // La cascada vive en un solo lugar. Ya no depende de banderas declaradas en el parámetro:
        // se consultan todos los ejes y gana el más específico que tenga valor cargado.
        exit(Claves.Resolver(Param.Código, FEmployeeNo, FCodConvenio, FCodCategoria, ValorMap));
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
        // La recarga con el par de la asignación revisa los mismos parámetros que ya se revisaron al
        // armar el contexto: sin esto, cada concepto marcado repetiría los mismos avisos.
        if FSilenciarAvisosParam then exit;
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

    local procedure AvisarCodigoDesconocido(VarSis: Record "Variable Sistema Liq.")
    var
        Mensaje: Text;
    begin
        if FSilenciarAvisosParam then
            exit;
        Mensaje := StrSubstNo(MsgCodCalculoDesconocido, VarSis."Nombre Variable", VarSis."Cód. Cálculo");
        if StrPos(FAdvertenciasParametros, Mensaje) > 0 then
            exit;
        if FAdvertenciasParametros <> '' then
            FAdvertenciasParametros += '';
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
        // El registro de uso se rehace entero: un recálculo puede haber cambiado qué parámetros
        // resuelve esta liquidación, y una fila que quedó de la corrida anterior mantendría
        // bloqueada una versión que ya nadie usa.
        BorrarUsoParametros(FLiqNo);

        Entries := EvalParamLog.Split('|');
        foreach Entry in Entries do begin
            if Entry.StartsWith('VAR:') then begin
                VarName := CopyStr(Entry, 5); // strip 'VAR:' prefix
                if not Vistas.ContainsKey(VarName) then begin
                    Vistas.Add(VarName, true);
                    if FParamBaseMap.ContainsKey(VarName) and FParamCodMap.ContainsKey(VarName) and FParamVigMap.ContainsKey(VarName) then
                        if ParamVig.Get(FParamBaseMap.Get(VarName), FParamCodMap.Get(VarName), FParamVigMap.Get(VarName)) then begin
                            if not ParamVig."En Uso" then begin
                                ParamVig."En Uso" := true;
                                ParamVig.Modify();
                            end;
                            RegistrarUsoParametro(VarName, ParamVig);
                        end;
                end;
            end;
        end;
    end;

    /// <summary>Deja anotado que esta liquidación usó esta versión del parámetro.</summary>
    /// <remarks>
    /// Es el índice que hace barata la pregunta inversa al reabrir: "¿queda alguna otra liquidación
    /// usando esta versión?". Antes esa respuesta salía de leer las líneas de todas las
    /// liquidaciones y buscar el token dentro de un texto.
    /// </remarks>
    local procedure RegistrarUsoParametro(VarName: Text; var ParamVig: Record "Parámetro Vigente")
    var
        Uso: Record "Uso Parámetro Liq.";
    begin
        if FLiqNo = '' then
            exit;
        Uso.Init();
        Uso."No. Liquidación" := FLiqNo;
        Uso."Nombre Variable" := CopyStr(VarName, 1, MaxStrLen(Uso."Nombre Variable"));
        Uso."Cód. Parámetro Base" := ParamVig."Cód. Parámetro Base";
        Uso."Cód. Parámetro" := ParamVig."Cód. Parámetro";
        Uso."Vigencia Desde" := ParamVig."Vigencia Desde";
        if Uso.Insert() then;
    end;

    /// <summary>Borra el registro de uso de una liquidación. Público: lo llaman reabrir y borrar.</summary>
    procedure BorrarUsoParametros(LiqNo: Code[20])
    var
        Uso: Record "Uso Parámetro Liq.";
    begin
        if LiqNo = '' then
            exit;
        Uso.SetRange("No. Liquidación", LiqNo);
        Uso.DeleteAll();
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
            'AÑOS_ANTIGUEDAD':
                exit(CalcAntiguedad());
            'AÑOS_ANTIG_30JUN':
                exit(CalcAntiguedadAl30Junio());
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
            'DIAS_MAREA':
                // Todos los días de la marea dentro de la ventana de esta liquidación: navegación
                // más puerto. Los dos son complementarios —cada día de borde cae en uno o en el
                // otro— así que la suma es exactamente la ventana completa, sin huecos ni dobles.
                //
                // Existe porque "los días de la marea" es un concepto del negocio que no tenía
                // nombre: las fórmulas lo escribían como DIAS_PROYECTO+DIAS_PUERTO cada vez, y en
                // los campos que esperan el NOMBRE de una variable —Variable Base— esa suma no se
                // podía expresar y quedaba en cero sin avisar.
                exit(CalcDiasNavegacionMarea() + CalcDiasPuertoMarea());
            'DIAS_FERIADOS_MAREA':
                // Feriados within the marea's own window (not the período's full range) — días
                // efectivamente a bordo. Para recargo por feriado trabajado (Art. 166 LCT) en la marea.
                exit(CalcDiasFeriadosMarea());
            'DIAS_FERIADOS_GUARDIA':
                // Feriados a bordo PERO FUERA DE LA MAREA: guardia en puerto, dique, pilotaje. Es el
                // complemento exacto de DIAS_FERIADOS_MAREA, no un reemplazo, y las dos cuentas no se
                // pueden pisar: un estado transcurre en marea o no transcurre, nunca las dos cosas.
                // Sumarlas da todos los feriados que el tripulante pasó a bordo.
                exit(CalcDiasFeriadosGuardia());
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
            'DIAS_HAB_AÑO':
                exit(CalcDiasHabilesAnio());
            'DIAS_ALTA_AÑO':
                exit(CalcDiasAltaAnio());
            'VACACIONES_PROP_DIAS':
                exit(CalcVacacionesProporcionales());
            'MESES_PROM_VAC':
                exit(CalcMesesPromedioVacaciones());
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
            'PERIODO_ACUM':
                exit(CalcImportePeriodoPorAcumulador(VarSis."Cód. Acumulador"));
            'PERIODO_CONCEPTO':
                exit(CalcImportePeriodoPorConcepto(VarSis."Cód. Concepto"));
            'YTD_LINEAS':
                exit(CalcImporteAnualLiq(VarSis."Tipo Concepto", ''));
            else begin
                // Un Cód. Cálculo que el motor no conoce vale cero, y ese cero entra a las fórmulas
                // sin decir nada: la variable existe, tiene nombre, aparece en el catálogo del editor
                // y simplemente no suma. Es lo que pasa con una fila que quedó escrita con una grafía
                // vieja después de un renombre —el caso ANIO/AÑO— o con un código tipeado a mano.
                //
                // El cero se mantiene: cortar la liquidación entera por una variable mal escrita
                // sería peor, y en muchas instalaciones habría filas que nadie usa. Pero deja de ser
                // mudo. Antes esto era el único lugar del motor donde algo desconocido no avisaba.
                AvisarCodigoDesconocido(VarSis);
                exit(0);
            end;
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

    /// <summary>
    /// Lo mismo que YTD_ACUM pero acotado al PERÍODO y a las OTRAS liquidaciones del empleado.
    /// </summary>
    /// <remarks>
    /// Existe para los topes mensuales, y el caso concreto es el tope SIPA. Los acumuladores son por
    /// liquidación: BASE_SS_TRAB de la liquidación de la marea no sabe nada de la mensual del mismo
    /// mes. Con un empleado que tiene dos liquidaciones en el período, cada una aplica el tope
    /// entero por su cuenta y los aportes se calculan dos veces sobre el mismo techo.
    ///
    /// El uso en la fórmula es descontar del tope lo que las otras ya consumieron:
    ///   MIN(BASE_SS_TRAB, MAX(0, TOPE_SIPA - BASE_SS_YA_LIQUIDADA)) * PCT_JUB
    /// donde BASE_SS_YA_LIQUIDADA es una variable de sistema con Cód. Cálculo = PERIODO_ACUM y el
    /// acumulador de la base de seguridad social.
    ///
    /// Excluye la liquidación en curso por partida doble: por su número y por el estado Borrador. La
    /// primera es la que vale cuando se recalcula una ya calculada; la segunda deja afuera a las que
    /// están creadas y todavía sin calcular, que no consumieron tope todavía.
    /// </remarks>
    local procedure CalcImportePeriodoPorAcumulador(CodAcum: Code[20]): Decimal
    var
        Fraccion: Record "Fracción Acumulador";
        LinLiq: Record "Línea Liquidación";
        Procesados: Dictionary of [Code[20], Boolean];
        Total: Decimal;
    begin
        if (CodAcum = '') or (FCodPeriodo = '') then
            exit(0);

        Fraccion.SetCurrentKey("Cód. Acumulador", "Vigencia Desde");
        Fraccion.SetRange("Cód. Acumulador", CodAcum);
        Fraccion.SetFilter("Vigencia Desde", '<=%1', FFechaRef);
        if not Fraccion.FindSet() then
            exit(0);
        repeat
            if not Procesados.ContainsKey(Fraccion."Cód. Concepto") then begin
                Procesados.Add(Fraccion."Cód. Concepto", true);
                LinLiq.Reset();
                LinLiq.SetCurrentKey("No. Empleado", "Cód. Período", "Tipo Concepto");
                LinLiq.SetRange("No. Empleado", FEmployeeNo);
                LinLiq.SetRange("Cód. Período", FCodPeriodo);
                LinLiq.SetRange("Cód. Concepto", Fraccion."Cód. Concepto");
                if FLiqNo <> '' then
                    LinLiq.SetFilter("No. Liquidación", '<>%1', FLiqNo);
                LinLiq.SetFilter(Estado, '<>%1', LinLiq.Estado::Borrador);
                LinLiq.CalcSums(Importe);
                if Fraccion."Invertir Signo" then
                    Total -= LinLiq.Importe
                else
                    Total += LinLiq.Importe;
            end;
        until Fraccion.Next() = 0;
        exit(Total);
    end;

    /// <summary>
    /// Importe ya liquidado en el período para UN concepto, sin contar la liquidación en curso.
    /// </summary>
    /// <remarks>
    /// Mismo criterio que PERIODO_ACUM —y por los mismos motivos— pero sin obligar a crear un
    /// acumulador dedicado sólo para poder mirar un concepto. Con acumulador sigue siendo la vía
    /// correcta cuando lo que interesa es una BASE (varios conceptos que suman a un tope); acá la
    /// pregunta es más chica: cuánto se pagó de este concepto en el mes.
    ///
    /// Excluye la liquidación en curso por partida doble, igual que la otra: por su número —que es
    /// lo que vale al RECALCULAR una ya calculada, donde sus propias líneas siguen en la base— y por
    /// el estado Borrador, que deja afuera a las creadas y todavía sin calcular. Sin eso, la segunda
    /// liquidación del mes se sumaría a sí misma.
    ///
    /// Sin "Invertir Signo": ese campo es de la fracción de un acumulador y acá no hay acumulador.
    /// El importe se suma tal como quedó en la línea, con el signo que le puso la fórmula.
    /// </remarks>
    local procedure CalcImportePeriodoPorConcepto(CodConcepto: Code[20]) Total: Decimal
    var
        LinLiq: Record "Línea Liquidación";
        CodPeriodo: Code[10];
    begin
        if (CodConcepto = '') or (FCodPeriodo = '') or (FEmployeeNo = '') then
            exit(0);

        // Por MES y no por código de período: un mes puede tener más de uno —MENS072026 y
        // MENS072026B— y con un solo código la segunda liquidación no vería a la primera, que es
        // exactamente lo que esta variable existe para evitar.
        foreach CodPeriodo in PeriodosDelMes() do begin
            LinLiq.Reset();
            LinLiq.SetCurrentKey("No. Empleado", "Cód. Período", "Tipo Concepto");
            LinLiq.SetRange("No. Empleado", FEmployeeNo);
            LinLiq.SetRange("Cód. Período", CodPeriodo);
            LinLiq.SetRange("Cód. Concepto", CodConcepto);
            if FLiqNo <> '' then
                LinLiq.SetFilter("No. Liquidación", '<>%1', FLiqNo);
            LinLiq.SetFilter(Estado, '<>%1', LinLiq.Estado::Borrador);
            LinLiq.CalcSums(Importe);
            Total += LinLiq.Importe;
        end;
    end;

    /// <summary>Códigos de período del mismo mes que el de esta liquidación, cacheados.</summary>
    /// <remarks>
    /// Se resuelve una vez por contexto: varias variables de sistema pueden usar PERIODO_CONCEPTO con
    /// conceptos distintos, y todas preguntan por el mismo mes.
    /// </remarks>
    local procedure PeriodosDelMes(): List of [Code[10]]
    var
        Periodo: Record "Período Liquidación";
    begin
        if FPeriodosMesCargados then
            exit(FPeriodosMes);
        FPeriodosMesCargados := true;

        if Periodo.Get(FCodPeriodo) then
            FPeriodosMes := Periodo.CodigosDelMismoMes()
        else
            FPeriodosMes.Add(FCodPeriodo);
        exit(FPeriodosMes);
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
        FechaIngresoImp: Date;
        FechaEgresoImp: Date;
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
                FechaIngresoImp := FechaIngresoImpuesto(EmpRel);
                FechaEgresoImp := FechaEgresoImpuesto(EmpRel);
                if ((FechaIngresoImp = 0D) or (FechaIngresoImp <= FFechaRef)) and
                   ((FechaEgresoImp = 0D) or (FechaEgresoImp >= FPeriodoFechaDesde))
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
        // Fraccionaria (0.1) para AÑOS_ANTIGUEDAD — no la exacta de años completos que usan
        // los tramos legales de vacaciones (ver CalcAntiguedadAlFecha/CalcVacacionesAnuales).
        exit(EstadoMgt.CalcAntiguedadFraccionAlFecha(FEmployeeNo, FFechaRef));
    end;

    // Parameterized version — used by AÑOS_ANTIGUEDAD (FFechaRef) and
    // VACACIONES_ANUALES (31/12 of the vacation year, per Art. 164 LCT).
    //
    // Seniority = sum of all employment periods (Alta → Baja) + Antigüedad Reconocida.
    // Intermediate states (Vacaciones, Enfermedad, Suspensión) are inside a period and

    local procedure FechaIngresoImpuesto(EmpRel: Record "Employee Relative"): Date
    var
        Fecha: Date;
    begin
        // Canónico: "Fecha inicial" (50000), de tableextension 50673. Todo converge ahí; las tres de
        // abajo son legacy y quedan sólo como respaldo para filas que la migración no alcanzó.
        Fecha := LeerFechaLegacyEmpRel(EmpRel, 50000);
        if Fecha <> 0D then
            exit(Fecha);

        Fecha := LeerFechaLegacyEmpRel(EmpRel, 50010); // Fecha alta familiar a cargo
        if Fecha <> 0D then
            exit(Fecha);

        Fecha := LeerFechaLegacyEmpRel(EmpRel, 50008); // Fecha alta impuesto
        if Fecha <> 0D then
            exit(Fecha);

        Fecha := LeerFechaLegacyEmpRel(EmpRel, 50211); // Fecha Ingreso Impuesto
        if Fecha <> 0D then
            exit(Fecha);

        exit(0D);
    end;

    local procedure FechaEgresoImpuesto(EmpRel: Record "Employee Relative"): Date
    var
        Fecha: Date;
    begin
        // Canónico: "Fecha final" (50001). Mismo criterio que la de alta.
        Fecha := LeerFechaLegacyEmpRel(EmpRel, 50001);
        if Fecha <> 0D then
            exit(Fecha);

        Fecha := LeerFechaLegacyEmpRel(EmpRel, 50011); // Fecha baja familiar a cargo
        if Fecha <> 0D then
            exit(Fecha);

        Fecha := LeerFechaLegacyEmpRel(EmpRel, 50009); // Fecha baja impuesto
        if Fecha <> 0D then
            exit(Fecha);

        Fecha := LeerFechaLegacyEmpRel(EmpRel, 50212); // Fecha Egreso Impuesto
        if Fecha <> 0D then
            exit(Fecha);

        exit(0D);
    end;

    local procedure LeerFechaLegacyEmpRel(EmpRel: Record "Employee Relative"; FieldNo: Integer): Date
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable(EmpRel);
        if not RecRef.FieldExist(FieldNo) then
            exit(0D);
        exit(FieldRefToDate(RecRef.Field(FieldNo)));
    end;
    // are included automatically; only Baja states close a period.
    // Uses a virtual-start-date approach: FechaVirtual = FechaRef − TotalDias, then
    // computes complete years from FechaVirtual to FechaRef for exact anniversary logic.
    /// <summary>
    /// Años completos de antigüedad al 30 de junio que rige para esta liquidación.
    /// </summary>
    /// <remarks>
    /// El Art. 32 del CCT congela la antigüedad de la bonificación al 30 de junio y la mantiene hasta
    /// el 30 de junio siguiente: el porcentaje no sube el mes del aniversario del tripulante, sube
    /// una vez al año para todos. Por eso el año del corte depende del mes que se liquida — de julio
    /// en adelante rige el 30/06 de este año; de enero a junio todavía rige el del año anterior.
    ///
    /// Devuelve AÑOS COMPLETOS, no la fracción, y es a propósito: los tramos del convenio son
    /// "más de N y hasta N+1", que es exactamente el intervalo que ocupa cada año completo. La
    /// fórmula los lee con >=: quien tiene 1 año completo está en el tramo del 2%, quien tiene 2 en
    /// el del 4%. Queda un solo caso de borde, el del tripulante que cumple años justo el 30 de
    /// junio: ese día tiene N exactos y el convenio lo deja en el tramo de abajo ("hasta N"),
    /// mientras que acá pasa al de arriba. Es un día por año y por persona.
    ///
    /// La antigüedad la resuelve CalcDiasAntiguedad, que ya suma todos los tramos Alta→Baja del
    /// legajo más la Antigüedad Reconocida: el último párrafo del artículo —la que se interrumpió por
    /// despido o renuncia y vuelve a contar— sale de ahí sin necesidad de nada más.
    /// </remarks>
    local procedure CalcAntiguedadAl30Junio(): Decimal
    var
        EstadoMgt: Codeunit "Gestión Estado Empleado";
    begin
        // La regla del corte vive en Gestión Estado Empleado, no acá: la comparten el motor y las
        // vistas de antigüedad, y tienen que ser la misma o la pantalla y el recibo se separan.
        exit(EstadoMgt.CalcAntiguedadAl30Junio(FEmployeeNo, FFechaRef));
    end;

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

    /// <summary>
    /// El calendario de feriados que corresponde a este empleado: el de su convenio si lo tiene,
    /// el del período si no.
    /// </summary>
    /// <remarks>
    /// LOS CONVENIOS TIENEN FERIADOS DISTINTOS Y EL PERÍODO TIENE UNO SOLO. El Art. 36 del CCT 768/19
    /// suma el 8 y 9 de febrero y fija el 20 de noviembre en su fecha, no en la trasladada; el Art. 51
    /// del 729/15 no los tiene. Los dos suman el 29 de diciembre, Día del Pescador, que no es feriado
    /// nacional y por lo tanto no está en el calendario general.
    ///
    /// El del período queda como respaldo y sigue sirviendo para todo lo que no es de convenio: los
    /// convenios de tierra no necesitan calendario propio y con dejarles el campo en blanco heredan
    /// el general.
    /// </remarks>
    local procedure CalendarioDeFeriados(var Periodo: Record "Período Liquidación"): Code[10]
    var
        Convenio: Record "Convenio Colectivo";
    begin
        if FCodConvenio <> '' then
            if Convenio.Get(FCodConvenio) then
                if Convenio."Cód. Calendario" <> '' then
                    exit(Convenio."Cód. Calendario");
        exit(Periodo."Cód. Calendario");
    end;

    // Same window as DIAS_HAB (the full liquidation período), counting only genuine holidays.
    local procedure CalcDiasFeriados(): Decimal
    var
        Periodo: Record "Período Liquidación";
        FechaActual: Date;
        CodCal: Code[10];
        Dias: Integer;
    begin
        if not Periodo.Get(FCodPeriodo) then exit(0);
        CodCal := CalendarioDeFeriados(Periodo);
        if CodCal = '' then exit(0); // no calendar → no feriados to distinguish
        FechaActual := Periodo."Fecha Desde";
        while FechaActual <= Periodo."Fecha Hasta" do begin
            EnsureCalendarioCache(CodCal, Date2DMY(FechaActual, 3));
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
    /// <summary>
    /// Feriados dentro de la ventana de esta liquidación con el empleado a bordo pero FUERA de la
    /// marea: guardia en puerto, dique, pilotaje.
    /// </summary>
    /// <remarks>
    /// EXISTE PORQUE EL FERIADO DE GUARDIA NO SE PAGABA. El concepto 1023 se apoyaba sólo en
    /// DIAS_FERIADOS_MAREA, que cuenta únicamente los estados marcados "Transcurre en Marea" —NV, PL,
    /// PS—, así que un feriado pasado de guardia en puerto no existía para el cálculo. En enero de
    /// 2026 eso dejó sin pagar a 97 tripulantes: el 1 de enero, con las mareas arrancando el 3.
    ///
    /// LAS DOS BANDERAS NO SON LA MISMA. "Transcurre en Marea" dice si el día es de la marea; "Devenga
    /// Francos" dice si el tripulante está a bordo. GP, DQ y PI devengan francos y no transcurren en
    /// marea: son exactamente los días que se perdían.
    ///
    /// Y POR ESO ES UN COMPLEMENTO Y NO UN REEMPLAZO. Contar acá todo lo que devenga francos haría que
    /// un feriado dentro de la marea se contara dos veces —una en el cierre de marea y otra en la
    /// regular del mes, cuyas ventanas se solapan—. Excluyendo lo que transcurre en marea, los dos
    /// conjuntos son disjuntos por construcción y la suma no puede duplicar nada.
    /// </remarks>
    local procedure CalcDiasFeriadosGuardia(): Decimal
    var
        Periodo: Record "Período Liquidación";
        EstadoEmp: Record "Estado Empleado";
        CodEst: Record "Cód. Estado Empleado";
        FechaActual: Date;
        OlapStart: Date;
        OlapEnd: Date;
        CodCal: Code[10];
        Dias: Integer;
    begin
        if FEmployeeNo = '' then exit(0);
        if not Periodo.Get(FCodPeriodo) then exit(0);
        CodCal := CalendarioDeFeriados(Periodo);
        if CodCal = '' then exit(0);

        EstadoEmp.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        EstadoEmp.SetRange("Tipo Entidad", EstadoEmp."Tipo Entidad"::Empleado);
        EstadoEmp.SetRange("No. Empleado", FEmployeeNo);
        if not EstadoEmp.FindSet() then exit(0);
        repeat
            if CodEst.Get(EstadoEmp."Cód. Estado") then
                if CodEst."Devenga Francos" and not CodEst."Transcurre en Marea" then begin
                    // La ventana es la de la liquidación, no la del período: un cierre de marea no
                    // tiene por qué ver los días de guardia previos al embarque, que ya paga la
                    // regular de la nómina.
                    OlapStart := EstadoEmp."Fecha Inicio";
                    if FPeriodoFechaDesde > OlapStart then OlapStart := FPeriodoFechaDesde;
                    OlapEnd := EstadoEmp.FechaFinEfectiva();
                    if FFechaRef < OlapEnd then OlapEnd := FFechaRef;
                    FechaActual := OlapStart;
                    while FechaActual <= OlapEnd do begin
                        EnsureCalendarioCache(CodCal, Date2DMY(FechaActual, 3));
                        if EsFeriadoCached(FechaActual) then
                            Dias += 1;
                        FechaActual += 1;
                    end;
                end;
        until EstadoEmp.Next() = 0;
        exit(Dias);
    end;

    local procedure CalcDiasFeriadosMarea(): Decimal
    var
        Periodo: Record "Período Liquidación";
        Job: Record Job;
        RangeStart: Date;
        RangeEnd: Date;
        FechaActual: Date;
        CodCal: Code[10];
        Dias: Integer;
    begin
        if (FJobNo = '') or not Job.Get(FJobNo) or (Job."Starting Date" = 0D) then exit(0);
        if not Periodo.Get(FCodPeriodo) then exit(0);
        CodCal := CalendarioDeFeriados(Periodo);
        if CodCal = '' then exit(0);

        RangeStart := Job."Starting Date";
        if FPeriodoFechaDesde > RangeStart then
            RangeStart := FPeriodoFechaDesde;

        RangeEnd := FFechaRef;
        if (Job."Ending Date" > 0D) and (Job."Ending Date" < RangeEnd) then
            RangeEnd := Job."Ending Date";

        if RangeEnd < RangeStart then exit(0);

        FechaActual := RangeStart;
        while FechaActual <= RangeEnd do begin
            EnsureCalendarioCache(CodCal, Date2DMY(FechaActual, 3));
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
        VentDesde: Date;
        VentHasta: Date;
        RangeStart: Date;
        RangeEnd: Date;
        Dias: Integer;
    begin
        if (FJobNo = '') or not Job.Get(FJobNo) or (Job."Starting Date" = 0D) then
            exit(0);

        VentanaEmpleadoEnMarea(Job, VentDesde, VentHasta);

        // La navegación arranca en el zarpe aunque el tripulante haya embarcado antes: los días de
        // víspera de un relevo son puerto, no navegación (ver CalcDiasPuertoMarea).
        RangeStart := VentDesde;
        if Job."Starting Date" > RangeStart then
            RangeStart := Job."Starting Date";
        if FPeriodoFechaDesde > RangeStart then
            RangeStart := FPeriodoFechaDesde;

        RangeEnd := FFechaRef;
        if (VentHasta > 0D) and (VentHasta < RangeEnd) then
            RangeEnd := VentHasta;

        if RangeEnd < RangeStart then
            exit(0);

        Dias := RangeEnd - RangeStart;

        // Departure boundary: only when the actual departure day is inside the window.
        if (RangeStart = Job."Starting Date") and (Job."Hora de zarpada" >= 120000T) then
            Dias -= 1;

        // End boundary: arrival day (AM/PM rule) if the window ends at arrival; otherwise the cutoff
        // is a full navigation day. Dos cosas caen en ese "otherwise": el corte de fin de mes con la
        // marea todavía abierta, y el desembarco de un tripulante relevado a mitad de marea. En los
        // dos casos el buque sigue navegando ese día, así que es día de navegación entero.
        if (Job."Ending Date" > 0D) and (RangeEnd = Job."Ending Date") then begin
            if Job."Hora ingreso a puerto" >= 120000T then
                Dias += 1;
        end else
            Dias += 1;

        exit(Dias);
    end;

    /// <summary>
    /// La ventana del TRIPULANTE dentro de la marea: [Fecha Alta Asignación, Fecha Baja], con las
    /// fechas del proyecto como valor por defecto. No es la ventana de la marea.
    /// </summary>
    /// <remarks>
    /// Las dos fechas viven en Personal Proyecto y hasta acá ningún cálculo de días las miraba: los
    /// tres (navegación, puerto, enrolamiento) arrancaban y terminaban en las del Job. Eso rompía en
    /// los dos extremos, y de maneras distintas:
    ///
    /// • RELEVO EN PUERTO. Al que sube se lo asigna la víspera del zarpe: marea del 10/07 al 20/07,
    ///   asignación del 09/07. El 09/07 quedaba fuera de la ventana y no era navegación, ni puerto,
    ///   ni enrolamiento: desaparecía. Cobraba once días habiendo estado a bordo doce.
    ///
    /// • RELEVO A MITAD DE MAREA. Uno baja el 15/07 y otro sube a reemplazarlo. Los dos cobraban la
    ///   marea ENTERA —10/07 al 20/07— porque el fin de la ventana salía de Job."Ending Date" y la
    ///   baja de la asignación no se leía en ninguna parte. El que se bajó cobraba cinco días de más.
    ///   DIAS_ENROLAMIENTO, en cambio, ya daba bien: solapa contra el Estado Empleado, que sí se
    ///   cierra en la Fecha Baja. Dos variables de la misma liquidación decían cosas distintas.
    ///
    /// Nada de esto se notaba en el caso normal porque el OnValidate de la asignación copia las
    /// fechas del proyecto cuando se dejan en blanco (ver Personal Proyecto): ahí las dos ventanas
    /// coinciden y no hay diferencia.
    ///
    /// El fin recorta pero no estira: una baja POSTERIOR al arribo no agrega días. Terminada la
    /// marea el proyecto se cierra, y lo que venga después es preparación de la marea siguiente o
    /// un estado distinto del tripulante, no días de ésta.
    ///
    /// Qué pasa con el día del relevo —si lo cobran los dos o uno solo— no se decide acá: sale de
    /// cómo se carguen las fechas. Baja el 15 y alta el 15 lo pagan los dos; baja el 15 y alta el 16
    /// lo paga uno solo y la suma da la marea exacta.
    /// </remarks>
    local procedure VentanaEmpleadoEnMarea(Job: Record Job; var Desde: Date; var Hasta: Date)
    var
        PersProy: Record "Personal Proyecto";
    begin
        Desde := Job."Starting Date";
        Hasta := Job."Ending Date";

        if (FEmployeeNo = '') or (FJobNo = '') then
            exit;
        if not PersProy.Get(FEmployeeNo, FJobNo) then
            exit;

        if PersProy."Fecha Alta Asignación" > 0D then
            Desde := PersProy."Fecha Alta Asignación";
        if (PersProy."Fecha Baja" > 0D) and ((Hasta = 0D) or (PersProy."Fecha Baja" < Hasta)) then
            Hasta := PersProy."Fecha Baja";
    end;

    // Port days of the marea within this liquidation's window, per the CCT rule: buque entra AM →
    // puerto; buque sale PM → puerto (the complementary AM/PM cases are navigation). Mid-voyage days
    // are always navigation.
    //
    // A los dos días de borde se suman los días de víspera: el tramo entre el embarque del tripulante
    // y el día anterior al zarpe, que existe cuando la asignación arranca antes que la marea.
    //
    // Los días de borde son de la MAREA, no del tripulante, así que sólo los cobra el que estaba a
    // bordo ese día: el que se baja a mitad de marea no cobra el arribo, y el que sube a mitad no
    // cobra la zarpada. Sale solo de que la ventana sea la del tripulante (ver
    // VentanaEmpleadoEnMarea) y de que las reglas AM/PM se pregunten si ese día cae DENTRO de ella.
    //
    // Nav + Puerto sigue dando la ventana completa del TRIPULANTE —que ya no es la de la marea— sin
    // huecos ni dobles.
    local procedure CalcDiasPuertoMarea(): Decimal
    var
        Job: Record Job;
        VentDesde: Date;
        VentHasta: Date;
        RangeStart: Date;
        RangeEnd: Date;
        TopeVispera: Date;
        Dias: Integer;
    begin
        if (FJobNo = '') or not Job.Get(FJobNo) or (Job."Starting Date" = 0D) then
            exit(0);

        VentanaEmpleadoEnMarea(Job, VentDesde, VentHasta);

        RangeStart := VentDesde;
        if FPeriodoFechaDesde > RangeStart then
            RangeStart := FPeriodoFechaDesde;

        RangeEnd := FFechaRef;
        if (VentHasta > 0D) and (VentHasta < RangeEnd) then
            RangeEnd := VentHasta;

        if RangeEnd < RangeStart then
            exit(0);

        // Días de víspera. El día de zarpada queda deliberadamente afuera de este tramo: lo resuelve
        // la regla AM/PM de abajo, y contarlo acá lo pagaría dos veces.
        //
        // El tope por RangeEnd es lo que hace que una marea a caballo de dos meses reparta bien: con
        // asignación el 30/06 y zarpe el 01/07, la liquidación de junio cierra en el 30/06 y paga ese
        // día como puerto, y la de julio arranca en el zarpe y no vuelve a contarlo. Cada mes paga
        // los días que le cayeron.
        if Job."Starting Date" > RangeStart then begin
            TopeVispera := Job."Starting Date" - 1;
            if RangeEnd < TopeVispera then
                TopeVispera := RangeEnd;
            Dias += TopeVispera - RangeStart + 1;
        end;

        // Departure PM → that day is a port day (only if the departure day is inside the window).
        // La condición mira que el zarpe caiga DENTRO de la ventana, no que la abra: con días de
        // víspera la ventana ya empieza antes, y el "RangeStart = Starting Date" de antes dejaba de
        // reconocer el día de zarpada justo en el caso que este cambio agrega.
        if (Job."Starting Date" >= RangeStart) and (Job."Starting Date" <= RangeEnd) and
           (Job."Hora de zarpada" >= 120000T)
        then
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
        // Misma ventana del tripulante que usan navegación y puerto: el día de víspera de un relevo
        // devenga francos como cualquier otro día a bordo, y el que se baja a mitad de marea deja de
        // devengar ese día. El solape contra el Estado Empleado ya recortaba por la baja —de ahí que
        // ésta fuera la única de las tres que daba bien—, pero que las tres partan de la misma
        // ventana es lo que evita que vuelvan a separarse.
        VentanaEmpleadoEnMarea(Job, WinStart, WinEnd);
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
            AvisarSiFuenteSinFiltros(Fuente);
            Valor := ResolveFuente(Fuente);
            if not Ctx.ContainsKey(Fuente."Nombre Variable") then
                Ctx.Add(Fuente."Nombre Variable", Valor)
            else
                Ctx.Set(Fuente."Nombre Variable", Valor);
            SetTipo(Fuente."Nombre Variable", 'Fuente Datos');
        until Fuente.Next() = 0;
    end;

    /// <summary>
    /// Pone en el contexto un valor por cada Tipo de Atributo que declare un Nombre Variable.
    /// </summary>
    /// <remarks>
    /// Es el atajo que evita tener que declarar una Fuente de Datos por cada atributo. El atributo
    /// ya sabe todo lo que hace falta: a qué maestro se cuelga ("Se carga en"), cómo se proyecta a
    /// número ("Valor Numérico", congelado al asignar) y desde cuándo rige. Con el nombre de
    /// variable cargado, la fórmula lo ve como a cualquier otra variable.
    ///
    /// La entidad NO se elige: sale del tipo de atributo y se resuelve contra esta liquidación —el
    /// empleado, el proyecto, o el buque del proyecto—. Un atributo que se carga en buques no
    /// aparece si la liquidación no tiene proyecto, y queda en cero.
    ///
    /// NO pisa lo que ya esté definido. Si una Fuente de Datos, un parámetro o una variable de
    /// sistema ya ocupan ese nombre, ese valor manda: la fuente es una definición hecha a mano que
    /// puede estar haciendo algo más fino (una cascada proyecto→empleado, un agregado), y un
    /// atributo cargado después no tiene por qué cambiarle el significado a una fórmula que anda.
    /// El choque además se evita de entrada: el Nombre Variable del tipo de atributo rechaza un
    /// nombre que ya esté tomado.
    ///
    /// Se guarda también el valor en su tipo original —el código de la lista, el texto, la fecha—
    /// por el mismo motivo que las fuentes no numéricas: con qué número calculó la fórmula y qué hay
    /// que mostrar en el recibo son dos preguntas distintas.
    /// </remarks>
    local procedure LoadAtributos(var Ctx: Dictionary of [Text, Decimal])
    var
        TipoAtr: Record "Tipo Atributo Liq.";
        Atributo: Record "Atributo Entidad Liq.";
        CodEntidad: Code[20];
        Valor: Decimal;
    begin
        TipoAtr.SetFilter("Nombre Variable", '<>%1', '');
        if not TipoAtr.FindSet() then
            exit;
        repeat
            if not Ctx.ContainsKey(TipoAtr."Nombre Variable") then begin
                Valor := 0;
                CodEntidad := EntidadDeLaLiquidacion(TipoAtr."Tipo Entidad");
                if (CodEntidad <> '') and AtributoVigente(TipoAtr.Código, TipoAtr."Tipo Entidad", CodEntidad, Atributo) then begin
                    Valor := Atributo."Valor Numérico";
                    GuardarValorTexto(TipoAtr."Nombre Variable", Atributo.ValorParaMostrar());
                end;
                Ctx.Add(TipoAtr."Nombre Variable", Valor);
                SetTipo(TipoAtr."Nombre Variable", 'Atributo');
            end;
        until TipoAtr.Next() = 0;
    end;

    /// <summary>
    /// A qué entidad concreta de ESTA liquidación se le pregunta un atributo de ese tipo.
    /// </summary>
    /// <remarks>
    /// El buque no está en la liquidación: sale del proyecto, cuya dimensión global 1 es el buque
    /// (ver "Gestión Entidades Liq.", donde el código de la entidad ES el del valor de dimensión).
    /// </remarks>
    local procedure EntidadDeLaLiquidacion(TipoEntidad: Enum "Tipo Entidad Estado"): Code[20]
    var
        Job: Record Job;
    begin
        case TipoEntidad of
            TipoEntidad::Empleado:
                exit(FEmployeeNo);
            TipoEntidad::Proyecto:
                exit(FJobNo);
            TipoEntidad::Buque:
                if (FJobNo <> '') and Job.Get(FJobNo) then
                    exit(Job."Global Dimension 1 Code");
        end;
        exit('');
    end;

    /// <summary>
    /// La asignación vigente a la fecha de referencia: la última que empezó antes y no cerró antes.
    /// </summary>
    /// <remarks>
    /// Misma regla que el resto del historial del sistema (estados, convenio, categoría). Fin en
    /// blanco = abierta. Sin red hacia adelante a propósito: un atributo que empieza DESPUÉS del
    /// cierre del período no rige en ese período, y adivinarlo escondería una carga mal fechada.
    /// </remarks>
    local procedure AtributoVigente(CodTipoAtributo: Code[20]; TipoEntidad: Enum "Tipo Entidad Estado"; CodEntidad: Code[20]; var Atributo: Record "Atributo Entidad Liq."): Boolean
    begin
        Atributo.Reset();
        Atributo.SetRange("Tipo Entidad", TipoEntidad);
        Atributo.SetRange("Cód. Entidad", CodEntidad);
        Atributo.SetRange("Cód. Tipo Atributo", CodTipoAtributo);
        Atributo.SetFilter("Vigencia Desde", '<=%1', FFechaRef);
        Atributo.SetFilter("Vigencia Hasta", '%1|>=%2', 0D, FFechaRef);
        exit(Atributo.FindLast());
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
                    FechaInicio := FieldRefToDate(RecRef.Field(CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Fecha Inicio")));
                if FilaVigenteAFechaRef(Fuente, RecRef, FechaInicio) then
                    if (not Encontrado) or (FechaInicio >= MejorInicio) then begin
                        MejorInicio := FechaInicio;
                        Encontrado := true;
                        FieldVar := RecRef.Field(CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Valor"));
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
                        FieldVar := RecRef.Field(CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Valor"));
                        Total += FieldRefToDecimal(FieldVar);
                    until RecRef.Next() = 0;
            Fuente."Función Agregado"::MAX:
                if (Fuente."No. Campo Valor" > 0) and RecRef.FindSet() then begin
                    FieldVar := RecRef.Field(CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Valor"));
                    Total := FieldRefToDecimal(FieldVar);
                    while RecRef.Next() <> 0 do begin
                        FieldVar := RecRef.Field(CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Valor"));
                        CurrVal := FieldRefToDecimal(FieldVar);
                        if CurrVal > Total then Total := CurrVal;
                    end;
                end;
            Fuente."Función Agregado"::MIN:
                if (Fuente."No. Campo Valor" > 0) and RecRef.FindSet() then begin
                    FieldVar := RecRef.Field(CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Valor"));
                    Total := FieldRefToDecimal(FieldVar);
                    while RecRef.Next() <> 0 do begin
                        FieldVar := RecRef.Field(CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Valor"));
                        CurrVal := FieldRefToDecimal(FieldVar);
                        if CurrVal < Total then Total := CurrVal;
                    end;
                end;
            Fuente."Función Agregado"::LOOKUP:
                if (Fuente."No. Campo Valor" > 0) and RecRef.FindLast() then begin
                    FieldVar := RecRef.Field(CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Valor"));
                    Total := FieldRefToDecimal(FieldVar);
                end;
            Fuente."Función Agregado"::"DIAS_OVERLAP":
                if (Fuente."No. Campo Fecha Inicio" > 0) and RecRef.FindSet() then
                    repeat
                        FechaInicioRef := RecRef.Field(CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Fecha Inicio"));
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
                        FechaInicioRef := RecRef.Field(CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Fecha Inicio"));
                        FechaInicio := FieldRefToDate(FechaInicioRef);
                        if (FechaInicio >= FPeriodoFechaDesde) and (FechaInicio <= FFechaRef) then begin
                            FechaFin := ResolverFechaFin(Fuente, RecRef, FechaInicio);
                            if FechaFin = 0D then
                                FechaFin := FFechaRef;
                            Total += FechaFin - FechaInicio + 1;
                        end;
                    until RecRef.Next() = 0;
            Fuente."Función Agregado"::"DURACION_AÑO":
                // Same as DIAS_OVERLAP but clips to the full calendar year [01/01, 31/12].
                // Used for VAC_TOMADAS_AÑO via Estado Empleado filtered by vacation state.
                if (Fuente."No. Campo Fecha Inicio" > 0) and RecRef.FindSet() then begin
                    FechaInicioAnio := DMY2Date(1, 1, Date2DMY(FFechaRef, 3));
                    FechaFinAnio := DMY2Date(31, 12, Date2DMY(FFechaRef, 3));
                    repeat
                        FechaInicioRef := RecRef.Field(CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Fecha Inicio"));
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
            exit(FieldRefToDate(RecRef.Field(CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Fecha Fin"))));
        exit(0D);
    end;

    // Effective end = next row's start − 1 for the same entity. The entity is scoped by the source's
    // TOKEN filters only ({EMP_NO}…); constant selection filters (e.g. Cód. Estado) are ignored so the
    // "next row" is the next state of any type. 0D when there is no later row (open interval).
    local procedure CalcFinEfectivo(Fuente: Record "Fuente Datos Liquidación"; StartActual: Date): Date
    begin
        if (Fuente."Id. Tabla" = 0) or (Fuente."No. Campo Fecha Inicio" = 0) then exit(0D);
        exit(FinEfectivoDeLista(Fuente."Nombre Variable", GetFechasInicioFuente(Fuente), StartActual));
    end;

    /// <summary>
    /// El fin efectivo de StartActual: el menor inicio estrictamente posterior, menos un día.
    /// </summary>
    /// <remarks>
    /// Intenta el mapa y, si no hay, recorre. Las dos formas tienen que dar SIEMPRE lo mismo — es lo
    /// que afirma "Test Fin Efectivo Liq.". Interna y no local para que esa prueba pueda llamarla con
    /// listas armadas a mano, que es la única manera de ejercitar los casos que no aparecen en los
    /// datos de hoy pero aparecerían el día menos pensado: lista desordenada, fechas repetidas,
    /// consulta por una fecha que no es ningún inicio.
    /// </remarks>
    internal procedure FinEfectivoDeLista(NombreVar: Text; Fechas: List of [Date]; StartActual: Date): Date
    var
        Clave: Text;
    begin
        if ConstruirMapaFinEfectivo(NombreVar, Fechas) then begin
            Clave := ClaveFinEfectivo(NombreVar, StartActual);
            if FFinEfMapa.ContainsKey(Clave) then
                exit(FFinEfMapa.Get(Clave));
        end;
        exit(FinEfectivoPorRecorrido(Fechas, StartActual));
    end;

    /// <summary>LA DEFINICIÓN de la regla. El mapa es una forma más rápida de contestar esto mismo.</summary>
    internal procedure FinEfectivoPorRecorrido(Fechas: List of [Date]; StartActual: Date): Date
    var
        Cur: Date;
        NextStart: Date;
    begin
        foreach Cur in Fechas do
            if Cur > StartActual then
                if (NextStart = 0D) or (Cur < NextStart) then
                    NextStart := Cur;
        if NextStart = 0D then exit(0D);
        exit(NextStart - 1);
    end;

    local procedure ClaveFinEfectivo(NombreVar: Text; Fecha: Date): Text
    begin
        exit(NombreVar + '|' + Format(Fecha, 0, 9));
    end;

    /// <summary>Arma el mapa inicio → fin efectivo de la fuente. False si no se pudo.</summary>
    /// <remarks>
    /// Antes, CalcFinEfectivo recorría la lista ENTERA por cada fila del agregado para encontrar el
    /// menor inicio estrictamente posterior: con N filas y M fechas, N×M comparaciones. La caché de
    /// fechas —que ya existía y sacó las consultas repetidas a la base— no tocaba eso. Acá el
    /// recorrido se hace UNA VEZ por fuente y el resto son búsquedas directas.
    ///
    /// LA LISTA NO VIENE ORDENADA POR FECHA. AplicarFiltrosFuente no fija clave, así que la base la
    /// devuelve por clave primaria: en Estado Empleado eso es "No. Mov.", el orden de alta. Suele
    /// coincidir con el cronológico pero no hay nada que lo garantice, y armar el mapa sobre una
    /// lista desordenada daría intervalos mal cerrados. Se ordena una copia una sola vez para
    /// construir el mapa, conservando la lista original y los filtros de la fuente.
    ///
    /// LAS FECHAS REPETIDAS se deduplican, no se descartan: dos estados que arrancan el mismo día
    /// comparten el mismo fin efectivo —el primer inicio DISTINTO que venga después—, que es
    /// exactamente lo que devolvía el recorrido.
    /// </remarks>
    // Ordenación por mezcla sobre una copia; no modifica la lista compartida de la fuente.
    internal procedure OrdenarFechas(Fechas: List of [Date]) Ordenadas: List of [Date]
    var
        Izquierda: List of [Date];
        Derecha: List of [Date];
        i: Integer;
        j: Integer;
        Mitad: Integer;
        varFecha: Date;
    begin
        if Fechas.Count() <= 1 then begin
            foreach varFecha in Fechas do
                Ordenadas.Add(varFecha);
            exit(Ordenadas);
        end;
        Mitad := Fechas.Count() div 2;
        for i := 1 to Fechas.Count() do
            if i <= Mitad then
                Izquierda.Add(Fechas.Get(i))
            else
                Derecha.Add(Fechas.Get(i));
        Izquierda := OrdenarFechas(Izquierda);
        Derecha := OrdenarFechas(Derecha);
        i := 1;
        j := 1;
        while (i <= Izquierda.Count()) and (j <= Derecha.Count()) do
            if Izquierda.Get(i) <= Derecha.Get(j) then begin
                Ordenadas.Add(Izquierda.Get(i));
                i += 1;
            end else begin
                Ordenadas.Add(Derecha.Get(j));
                j += 1;
            end;
        while i <= Izquierda.Count() do begin
            Ordenadas.Add(Izquierda.Get(i));
            i += 1;
        end;
        while j <= Derecha.Count() do begin
            Ordenadas.Add(Derecha.Get(j));
            j += 1;
        end;
    end;

    local procedure ConstruirMapaFinEfectivo(NombreVar: Text; Fechas: List of [Date]): Boolean
    var
        Distintas: List of [Date];
        Ordenadas: List of [Date];
        Cur: Date;
        Ultima: Date;
        Actual: Date;
        Siguiente: Date;
        i: Integer;
    begin
        if FFinEfOrden.ContainsKey(NombreVar) then
            exit(FFinEfOrden.Get(NombreVar));

        Ordenadas := OrdenarFechas(Fechas);
        foreach Cur in Ordenadas do begin
            if Distintas.Count() > 0 then
                Distintas.Get(Distintas.Count(), Ultima);
            if (Distintas.Count() = 0) or (Cur <> Ultima) then
                Distintas.Add(Cur);
        end;

        for i := 1 to Distintas.Count() do begin
            Distintas.Get(i, Actual);
            if i < Distintas.Count() then begin
                Distintas.Get(i + 1, Siguiente);
                FFinEfMapa.Add(ClaveFinEfectivo(NombreVar, Actual), Siguiente - 1);
            end else
                // La última no tiene siguiente: intervalo abierto, que el llamador recorta a FechaRef.
                FFinEfMapa.Add(ClaveFinEfectivo(NombreVar, Actual), 0D);
        end;

        FFinEfOrden.Add(NombreVar, true);
        exit(true);
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
        if AplicarFiltrosFuente(Fuente, Rec2, true) then begin
            // De cada fila se lee UN campo. Sin esto viene el registro entero, y el historial de un
            // tripulante con veinte años son cientos de filas de Estado Empleado —el promedio es 61 y
            // hay 651 empleados arriba de 100— traídas completas para extraerles una fecha.
            //
            // Los filtros no necesitan que el campo esté cargado, así que SetLoadFields va después de
            // AplicarFiltrosFuente sin afectarlos. Nada más abajo toca otro campo: si alguien agrega
            // una lectura, la plataforma recarga la fila y el ahorro se pierde en silencio.
            Rec2.SetLoadFields(CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Fecha Inicio"));
            if Rec2.FindSet() then
                repeat
                    Fechas.Add(FieldRefToDate(Rec2.Field(CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Fecha Inicio"))));
                until Rec2.Next() = 0;
        end;
        Rec2.Close();
        FFinEfCache.Add(CacheKey, Fechas);
    end;

    // Applies the source's filters to RecRef. When SoloTokens, only filters whose raw value contains a
    // {TOKEN} are applied (they scope the entity); constant filters are skipped. Returns false if a token
    // filter resolved to empty (caller treats as "no data").
    /// <summary>
    /// Avisa cuando una fuente activa va a resolver SIN ningún filtro.
    /// </summary>
    /// <remarks>
    /// Una fuente sin filtros agrega la tabla entera. A veces es lo querido —un total global— pero
    /// casi siempre significa que sus filtros se perdieron, y el síntoma es desconcertante: varias
    /// fuentes que solo se diferenciaban por el filtro empiezan a devolver todas el MISMO número, sin
    /// ningún error. Pasó exactamente eso cuando se vació "Filtro Fuente Datos Liq.", que es de donde
    /// salen los filtros desde que dejaron de ser tres campos fijos.
    ///
    /// Va al mismo canal que los avisos de parámetro desactualizado: no frena el cálculo, aparece al
    /// terminar y queda en el registro del proceso.
    /// </remarks>
    local procedure AvisarSiFuenteSinFiltros(Fuente: Record "Fuente Datos Liquidación")
    var
        FiltroFDS: Record "Filtro Fuente Datos Liq.";
        Mensaje: Text;
    begin
        if FSilenciarAvisosParam then
            exit;
        FiltroFDS.SetRange("Nombre Variable", Fuente."Nombre Variable");
        if not FiltroFDS.IsEmpty() then
            exit;

        Mensaje := StrSubstNo(MsgFuenteSinFiltros, Fuente."Nombre Variable");
        if StrPos(FAdvertenciasParametros, Mensaje) > 0 then
            exit;
        if FAdvertenciasParametros <> '' then
            FAdvertenciasParametros += '\';
        FAdvertenciasParametros += Mensaje;
    end;

    local procedure AplicarFiltrosFuente(Fuente: Record "Fuente Datos Liquidación"; var RecRef: RecordRef; SoloTokens: Boolean): Boolean
    var
        FiltroFDS: Record "Filtro Fuente Datos Liq.";
    begin
        FiltroFDS.SetRange("Nombre Variable", Fuente."Nombre Variable");
        if FiltroFDS.FindSet() then begin
            repeat
                if not AplicarUnFiltro(RecRef, Fuente."Id. Tabla", FiltroFDS."No. Campo", FiltroFDS."Filtro Valor", SoloTokens) then
                    exit(false);
            until FiltroFDS.Next() = 0;
            // Con filtros en la tabla, los tres campos VIEJOS no se aplican. Y no es una preferencia
            // de estilo: SetFilter sobre un campo REEMPLAZA el filtro anterior de ese campo, no lo
            // acota. Una fuente creada con "Copiar como..." se lleva los campos viejos del original,
            // así que al resolver, el filtro heredado pisaba al de la tabla y la fuente terminaba
            // leyendo los registros del original.
            //
            // Es exactamente lo que pasó con PROD_KN_L4, L5 y L6: copiadas de L3, con sus filtros
            // nuevos correctos, devolvían los kilos de L3 — sin error, sin aviso, y con el número de
            // otra clasificación adentro del recibo.
            exit(true);
        end;

        // Si no hay filtros en la tabla auxiliar, la fuente queda sin restricciones.
        exit(true);
    end;

    local procedure AplicarUnFiltro(var RecRef: RecordRef; SourceTableId: Integer; FieldNo: Integer; RawValue: Text; SoloTokens: Boolean): Boolean
    var
        Resolved: Text;
    begin
        if SoloTokens and (not RawValue.Contains('{')) then
            exit(true);   // constant filter → skip when only the entity (token) scope is wanted
        Resolved := ApplyTokens(RawValue);
        if TokenResolvedToEmpty(RawValue, Resolved) then
            exit(false);
        ApplyRecordFilter(RecRef, SourceTableId, FieldNo, Resolved);
        exit(true);
    end;

    local procedure ApplyRecordFilter(var RecRef: RecordRef; SourceTableId: Integer; FieldNo: Integer; FilterValue: Text)
    var
        FieldVar: FieldRef;
        CampoEfectivo: Integer;
    begin
        if (FieldNo = 0) or (FilterValue = '') then exit;
        CampoEfectivo := CampoFuenteCanonico(SourceTableId, FieldNo);
        if CampoEfectivo = 0 then
            exit;
        FieldVar := RecRef.Field(CampoEfectivo);
        FieldVar.SetFilter(FilterValue);
    end;

    local procedure CampoFuenteCanonico(SourceTableId: Integer; FieldNo: Integer): Integer
    begin
        if SourceTableId <> Database::"Employee Relative" then
            exit(FieldNo);

        case FieldNo of
            // Todas las fechas de alta legacy -> "Fecha inicial" (50000), que es la canónica.
            50008, 50010, 50211:
                exit(50000);
            // Todas las fechas de baja legacy -> "Fecha final" (50001).
            50009, 50011, 50212:
                exit(50001);
            else
                exit(FieldNo);
        end;
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
        AnclaProm: Date;
        PromDesde: Date;
        PromHasta: Date;
        SemDesde: Date;
        SemHasta: Date;
        AsigDesde: Date;
        AsigHasta: Date;
        MareaDesde: Date;
        MareaHasta: Date;
    begin
        Value := Value.Replace('{EMP_NO}', FEmployeeNo);
        Value := Value.Replace('{JOB_NO}', FJobNo);
        Value := Value.Replace('{PERIODO}', FCodPeriodo);
        Value := Value.Replace('{FECHA_REF}', Format(FFechaRef));
        // El inicio del período, para acotar una fuente por AMBAS puntas. Con {FECHA_REF} sola, un
        // filtro de fecha acota hacia adelante pero arrastra todo lo anterior: en una marea a caballo
        // de dos meses, el cierre de agosto vuelve a sumar la producción que el devengado de julio ya
        // pagó. Con "{PERIODO_DESDE}..{FECHA_REF}" cada liquidación toma sólo su tramo.
        Value := Value.Replace('{PERIODO_DESDE}', Format(FPeriodoFechaDesde));
        // Alta y baja de ESTE tripulante en ESTA marea. Los demás tokens de fecha valen lo mismo
        // para toda la tripulación, y hay cosas que no se pueden acotar con ellos: la producción se
        // cuenta hasta el día en que cada uno desembarca, así que el que se bajó veinte días antes
        // no suma las toneladas que se descargaron después. Con {PERIODO_DESDE}..{FECHA_REF} cobraba
        // la marea entera, sin ninguna señal de que estaba de más.
        //
        // La baja en blanco se resuelve como la fecha de referencia y no como 31/12/9999: en un
        // filtro "desde..hasta" el infinito arrastraría descargas posteriores al cierre que se está
        // liquidando, que es el otro lado del mismo error.
        if Value.Contains('{ASIG_DESDE}') or Value.Contains('{ASIG_HASTA}') then begin
            ResolverFechasAsignacion(AsigDesde, AsigHasta);
            Value := Value.Replace('{ASIG_DESDE}', Format(AsigDesde));
            Value := Value.Replace('{ASIG_HASTA}', Format(AsigHasta));
        end;
        // Zarpada y arribo del proyecto, SIN recortar por el período. Son la contraparte de los
        // {ASIG_*}: comparando una punta contra la otra se sabe si el tripulante hizo la marea
        // entera o sólo un tramo, que es lo que decide de dónde salen sus kilos. Con {PERIODO_DESDE}
        // no alcanza —una marea puede empezar el mes anterior— y con {FECHA_REF} tampoco, porque en
        // una mensual no es el arribo.
        if Value.Contains('{MAREA_DESDE}') or Value.Contains('{MAREA_HASTA}') then begin
            ResolverFechasMarea(MareaDesde, MareaHasta);
            Value := Value.Replace('{MAREA_DESDE}', Format(MareaDesde));
            Value := Value.Replace('{MAREA_HASTA}', Format(MareaHasta));
        end;
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
        // Los SEIS MESES CALENDARIO ANTERIORES a aquel EN QUE EMPIEZA LA LICENCIA. Es la ventana
        // del Art. 34 del CCT: "las remuneraciones… correspondientes a los seis meses anteriores a
        // aquel en que comience a gozar sus vacaciones".
        //
        // EL ANCLA ES EL INICIO DE LA LICENCIA, NO LA FECHA DE REFERENCIA DE LA LIQUIDACIÓN. Casi
        // siempre dan lo mismo —se liquida el mes en que el tripulante sale— y por eso es fácil
        // escribirlo mal. Dejan de coincidir con el PAGO ANTICIPADO, que el mismo artículo autoriza:
        // un adelanto pedido en diciembre por una licencia que arranca en febrero tiene que promediar
        // agosto–enero, no julio–diciembre. Anclado en la fecha de referencia, el adelanto se pagaría
        // con el promedio equivocado y el número saldría creíble.
        //
        // Sin estado de vacaciones se cae a la fecha de referencia: la fuente sigue teniendo una
        // ventana con sentido en vez de quedarse sin filtro, que es la peor forma de fallar.
        //
        // EL MES EN CURSO QUEDA AFUERA. Además de que el convenio dice "anteriores", incluirlo sería
        // circular: la liquidación que consulta el promedio es la que estaría alimentándolo, así que
        // el importe dependería del orden de cálculo — distinto en cada corrida y sin error.
        //
        // La ventana es de calendario: un mes en tierra entra como cero. Cuántos meses se dividen
        // —"la cantidad de períodos mensuales considerados"— es otra cuenta y no vive acá.
        if Value.Contains('{PROM_DESDE}') or Value.Contains('{PROM_HASTA}') then begin
            AnclaProm := FechaInicioVacaciones();
            if AnclaProm = 0D then
                AnclaProm := FFechaRef;
            PromHasta := CalcDate('<-CM-1D>', AnclaProm);
            PromDesde := CalcDate('<-CM>', CalcDate('<-5M>', PromHasta));
            Value := Value.Replace('{PROM_DESDE}', Format(PromDesde));
            Value := Value.Replace('{PROM_HASTA}', Format(PromHasta));
        end;
        exit(Value);
    end;

    /// <summary>
    /// Alta y baja del empleado en el proyecto de esta liquidación, acotadas al período liquidado.
    /// </summary>
    /// <remarks>
    /// Sin asignación —una liquidación sin proyecto, o un tripulante que no figura en la marea— se
    /// devuelve el tramo del período. Así una fuente que use los tokens no se queda sin filtro y
    /// suma la tabla entera, que es la peor forma de fallar: da un número grande y creíble.
    /// </remarks>
    /// <summary>
    /// El día en que arranca la licencia que esta liquidación está pagando. 0D si no hay ninguna.
    /// </summary>
    /// <remarks>
    /// Se toma la PRIMERA vigencia de vacaciones que llega hasta el período o más allá, recorriendo
    /// en orden de fecha. No la que "cae adentro": una licencia que arrancó el mes pasado y sigue
    /// corriendo es la misma licencia, y su promedio se mide desde donde empezó — no desde el mes que
    /// se está liquidando. Partirla en dos daría dos promedios distintos para una sola licencia.
    ///
    /// Se excluyen las que arrancan después de que el período terminó: todavía no son esta
    /// liquidación.
    /// </remarks>
    /// <summary>
    /// Cuántos períodos mensuales se promedian para las vacaciones. Entre 0 y 6.
    /// </summary>
    /// <remarks>
    /// Es el divisor del Art. 34 del CCT: "El total así obtenido, se dividirá por la cantidad de
    /// períodos mensuales considerados". No es seis fijo — el mismo artículo prevé "la fracción menor
    /// de prestación de servicios que corresponda" para quien no llegue a los seis meses.
    ///
    /// SE CUENTAN LOS MESES CON PRESTACIÓN, NO LOS MESES CON REMUNERACIÓN. Un mes en tierra, sin
    /// embarcar y sin cobrar, es un período considerado igual: el tripulante estaba en la empresa y
    /// ese cero baja el promedio, que es lo que corresponde. Lo que reduce el divisor es no haber
    /// pertenecido a la empresa, no haber ganado poco. Contando meses con remuneración, alguien que
    /// pasó cuatro meses en tierra cobraría las vacaciones como si hubiera trabajado todo el semestre.
    ///
    /// Alcanza con UN DÍA de fase en el mes para que cuente. Un alta el 28 hace que ese mes entre
    /// entero al divisor con casi nada de remuneración; es la lectura literal de "períodos mensuales
    /// considerados" y es la que perjudica al empleado, así que si el convenio se interpreta de otra
    /// forma en la práctica, es acá donde hay que cambiarlo.
    ///
    /// La ventana es la misma que la del token {PROM_DESDE}..{PROM_HASTA} y por el mismo ancla: si
    /// las dos se separan, el numerador y el denominador serían de semestres distintos.
    /// </remarks>
    local procedure CalcMesesPromedioVacaciones(): Decimal
    var
        Fase: Record "Fase Alta Empleado";
        Ancla: Date;
        Desde: Date;
        Hasta: Date;
        MesDesde: Date;
        MesHasta: Date;
        Meses: Integer;
        i: Integer;
    begin
        if FEmployeeNo = '' then
            exit(0);

        Ancla := FechaInicioVacaciones();
        if Ancla = 0D then
            Ancla := FFechaRef;
        Hasta := CalcDate('<-CM-1D>', Ancla);
        Desde := CalcDate('<-CM>', CalcDate('<-5M>', Hasta));

        // Sin ninguna fase cargada no hay con qué decidir, y devolver 0 haría una división por cero
        // en la fórmula. Se devuelven los seis del semestre completo, que es el caso normal.
        Fase.SetRange("No. Empleado", FEmployeeNo);
        if Fase.IsEmpty() then
            exit(6);

        for i := 0 to 5 do begin
            MesDesde := CalcDate(StrSubstNo('<+%1M>', i), Desde);
            MesHasta := CalcDate('<CM>', MesDesde);
            Fase.Reset();
            Fase.SetRange("No. Empleado", FEmployeeNo);
            Fase.SetFilter("Fecha Alta", '<=%1', MesHasta);
            Fase.SetFilter("Fecha Baja", '%1|>=%2', 0D, MesDesde);
            if not Fase.IsEmpty() then
                Meses += 1;
        end;

        exit(Meses);
    end;

    local procedure FechaInicioVacaciones(): Date
    var
        EstadoEmp: Record "Estado Empleado";
        CodEst: Record "Cód. Estado Empleado";
    begin
        if FEmployeeNo = '' then
            exit(0D);
        EstadoEmp.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        EstadoEmp.SetRange("Tipo Entidad", EstadoEmp."Tipo Entidad"::Empleado);
        EstadoEmp.SetRange("No. Empleado", FEmployeeNo);
        EstadoEmp.SetFilter("Fecha Inicio", '<=%1', FFechaRef);
        if not EstadoEmp.FindSet() then
            exit(0D);
        repeat
            if CodEst.Get(EstadoEmp."Cód. Estado") then
                if CodEst."Tipo Estado" = CodEst."Tipo Estado"::Vacaciones then
                    if EstadoEmp.FechaFinEfectiva() >= FPeriodoFechaDesde then
                        exit(EstadoEmp."Fecha Inicio");
        until EstadoEmp.Next() = 0;
        exit(0D);
    end;

    local procedure ResolverFechasAsignacion(var Desde: Date; var Hasta: Date)
    var
        PersProy: Record "Personal Proyecto";
    begin
        Desde := FPeriodoFechaDesde;
        Hasta := FFechaRef;

        if (FEmployeeNo = '') or (FJobNo = '') then
            exit;
        if not PersProy.Get(FEmployeeNo, FJobNo) then
            exit;

        // El alta de la asignación puede ser anterior al período —una marea que empezó el mes
        // pasado— y ahí manda el inicio del período, si no el cierre de este mes vuelve a contar lo
        // que el anterior ya pagó.
        if PersProy."Fecha Alta Asignación" > Desde then
            Desde := PersProy."Fecha Alta Asignación";
        if (PersProy."Fecha Baja" <> 0D) and (PersProy."Fecha Baja" < Hasta) then
            Hasta := PersProy."Fecha Baja";
    end;

    /// <summary>
    /// Zarpada y arribo del proyecto de esta liquidación, tal cual están en el proyecto.
    /// </summary>
    /// <remarks>
    /// Sin recortar por el período, al revés que las fechas de asignación: acá lo que se necesita es
    /// la marea completa, para poder comparar contra el tramo del tripulante. Sin proyecto, o con el
    /// proyecto sin fechas, se cae al período — así una fuente que use los tokens conserva un filtro
    /// razonable en vez de quedarse sin ninguno.
    /// </remarks>
    local procedure ResolverFechasMarea(var Desde: Date; var Hasta: Date)
    var
        Job: Record Job;
    begin
        Desde := FPeriodoFechaDesde;
        Hasta := FFechaRef;

        if FJobNo = '' then
            exit;
        if not Job.Get(FJobNo) then
            exit;
        if Job."Starting Date" <> 0D then
            Desde := Job."Starting Date";
        if Job."Ending Date" <> 0D then
            Hasta := Job."Ending Date";
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
