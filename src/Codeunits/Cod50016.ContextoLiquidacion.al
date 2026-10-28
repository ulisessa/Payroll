namespace UAS.Payroll;

using Microsoft.Projects.Project.Job;
using Microsoft.HumanResources.Employee;
using Microsoft.HumanResources.Setup;
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
        FFechaHastaPuerto: Date;
        FPeriodoFechaDesde: Date;
        FCoberturaDesde: Date;
        FCoberturaHasta: Date;
        FTramosDesde: List of [Date];
        FTramosHasta: List of [Date];
        FCodConvenio: Code[20];
        FCodCategoria: Code[20];
        FLiqNo: Code[20];
        FFrancosMgt: Codeunit "Gestión Francos";
        FTiposCambio: Dictionary of [Text, Decimal];
        FTipoLiq: Code[20];
        FPeriodosMes: List of [Code[10]];
        FPeriodosMesCargados: Boolean;
        FBuqueUltMarea: Code[20];
        FBuqueUltMareaListo: Boolean;
        FFechaTC: Date;
        FFechaTCListo: Boolean;
        FParamLog: Text;
        FActualCodMap: Dictionary of [Code[50], Code[50]]; // EffectiveKey → CódParámetro real en DB
        FBasesConFilas: Dictionary of [Code[20], Boolean]; // CódParámetroBase que tiene AL MENOS una versión vigente
        FParamBaseMap: Dictionary of [Text, Code[20]];  // NombreVar → CódParámetroBase
        FParamCodMap: Dictionary of [Text, Code[50]];   // NombreVar → CódParámetro real en DB
        FParamVigMap: Dictionary of [Text, Date];       // NombreVar → VigenciaDesde
        FParamSinFila: Dictionary of [Text, Boolean];   // NombreVar: precio del convenio sin fila para este empleado/par/fecha
        FBasesDelConvenio: Dictionary of [Code[20], Boolean]; // Bases con alguna fila clave del convenio de la liquidación
        FParametrosCCTHistoricos: Record "Parámetro Vigente" temporary;
        FMoneda: Code[10];
        // Qué variable convierte cada parámetro en divisa, por Nombre Variable. Se llena en
        // LoadParametros y la consume ConvertirParametrosEnDivisa, que corre después de las fuentes
        // de datos porque es ahí donde recién existen TC_COMPRADOR y TC_VENDEDOR.
        FParamTC: Dictionary of [Text, Code[60]];
        FTipoMap: Dictionary of [Text, Text];          // NombreVar → 'Atributo'|'Parámetro'|'Sistema'|'Fuente Datos'|'Acumulador'
        FValoresTexto: Dictionary of [Text, Text];     // NombreVar → valor en su tipo original (fuentes no numéricas)
        FCodigosAtributos: Dictionary of [Text, Text];
        // Cód. Tipo Atributo → el SUFIJO que su valor vigente aporta a una clave de parámetro, para
        // esta liquidación. Lo llena CargarSufijosDeEje y lo consume la cascada.
        //
        // ES UNA PASADA APARTE Y NO SALE DE LoadAtributos, QUE SERÍA EL LUGAR OBVIO. LoadAtributos
        // corre al FINAL de BuildContext, después de los parámetros, y está escrito así a propósito:
        // para no pisar un nombre de variable que ya ocupó un parámetro o una fuente. Adelantarlo
        // invertiría esa precedencia. Esta pasada no escribe en el contexto —sólo llena este
        // diccionario—, así que no puede pisar nada ni ser pisada, y mira únicamente los tipos que
        // algún parámetro declara como eje: hoy uno, no los cuarenta.
        FSufijoEje: Dictionary of [Code[20], Code[10]];
        FEjesCargados: Boolean;
        FAdvertenciasParametros: Text;
        MsgParamSinValor: Label '%1: no tiene ningún valor cargado en Parámetros Vigentes.';
        // Prefijos de los dos únicos tokens con argumento. Van Locked: son sintaxis, no texto.
        TokAtribDesde: Label '{ATRIB_DESDE:', Locked = true;
        TokAtribHasta: Label '{ATRIB_HASTA:', Locked = true;
        // El acumulador del que sale la base del SAC y del promedio de vacaciones. Va como Label y
        // no como literal suelto para que se vea de una que las dos bases son la misma.
        ConceptoBasePromedioTok: Label 'BASE_PROMEDIO', Locked = true;
        CodCalcTipoLiqTok: Label 'TIPO_LIQ', Locked = true;
        MsgTramosMultiples: Label 'El empleado tiene más de un tramo del atributo %1 en el proyecto %2. Un tramo partido en dos no se puede expresar con un solo desde..hasta, y tomar del primero al último contaría el hueco del medio, así que el filtro quedó en la ventana de la asignación: la producción se contó ENTERA y no por tramo. Unificá los tramos en una sola vigencia, o cargá el importe en la novedad del concepto.', Comment = '%1=código de tipo de atributo, %2=No. de proyecto';
        // Los tres cortan el cálculo en vez de avisar. El resultado de no convertir es un importe en
        // divisa haciéndose pasar por pesos: mil cuatrocientas veces más chico, sin error, y los
        // controles de importe no lo ven porque el número es válido. Los tres se arreglan con un
        // campo en Parámetros Vigentes o con una cotización cargada, así que cortar es barato.
        ErrParamSinVariableTC: Label '%1 está en moneda extranjera y no declara con qué variable convertirse. Completá "Variable Tipo de Cambio" en Parámetros Vigentes: sin eso su importe quedaría en divisa y no en pesos.', Comment = '%1=nombre de la variable del parámetro';
        ErrVariableTCInexistente: Label 'La variable %1, que %2 declara para convertirse, no existe en el contexto. Revisá que siga siendo una Fuente de Datos activa.', Comment = '%1=variable de tipo de cambio, %2=nombre de la variable del parámetro';
        ErrVariableTCEnCero: Label 'La variable %1 vale cero a esta fecha, así que %2 no se puede convertir. Cargá la cotización de %3.', Comment = '%1=variable de tipo de cambio, %2=nombre de la variable del parámetro, %3=fecha de referencia';
        MsgCodCalculoDesconocido: Label 'La variable %1 tiene el Cód. Cálculo "%2", que el motor no conoce: vale CERO en todas las fórmulas que la usen. Revisá el código en Variables de Sistema.', Comment = '%1=nombre de la variable, %2=código de cálculo';
        MsgFuenteSinFiltros: Label 'La Fuente de Datos %1 no tiene ningún filtro cargado: está agregando la tabla entera. Si sus filtros vivían en "Filtro Fuente Datos Liq.", revisá que sigan cargados.', Comment = '%1=nombre de variable de la fuente';
        MsgFuenteSinCampoFecha: Label 'La Fuente de Datos %1 elige la fila más reciente o más antigua, pero no declara "No. Campo Fecha Inicio": sin ese campo no hay por dónde ordenar y vale CERO. Completalo en la Fuente de Datos.', Comment = '%1=nombre de variable de la fuente';
        MsgFuenteSinClaveUtil: Label 'La Fuente de Datos %1 pide ordenar por el campo %2, pero la tabla no tiene ninguna clave que lo contenga. En AL sólo se puede ordenar por una clave declarada, así que el recorrido queda por clave primaria. Declará la clave en la tabla o elegí otro campo.', Comment = '%1=nombre de variable de la fuente, %2=número de campo';
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
        // Los precios sin fila de cada par: dependen del par igual que los valores y vuelven con ellos.
        FParSinFila1: Dictionary of [Text, Boolean];
        FParSinFila2: Dictionary of [Text, Boolean];
        FCalCacheLoaded: Boolean;
        FCalCacheCode: Code[10];
        FCalCacheAnio: Integer;
        FCalDateOverride: Dictionary of [Date, Boolean]; // specific date → is_working
        FCalWeekRule: Dictionary of [Integer, Boolean];  // day_of_week (1=Mon..7=Sun) → is_working
        // Fechas de inicio por fuente "Fin Efectivo" — ver GetFechasInicioFuente.
        FFinEfCache: Dictionary of [Text, List of [Date]]; // Nombre Variable → fechas de inicio del scope token
        FFinEfMapa: Dictionary of [Text, Date];            // "NombreVar|fecha" → fin efectivo de ese inicio
        FFinEfOrden: Dictionary of [Text, Boolean];        // Nombre Variable → la lista vino ordenada y hay mapa
        // Acumulados históricos por concepto — ver CargarAcumHistorico.
        FAcumAnual: Dictionary of [Code[20], Decimal];     // Cód. Concepto → suma del año, SIN esta liquidación
        FAcumPeriodo: Dictionary of [Code[20], Decimal];   // Cód. Concepto → suma del período, SIN esta liquidación
        FEstaLiq: Dictionary of [Code[20], Decimal];    // Cód. Concepto → lo que ESTA liquidación lleva escrito
        FAcumAnualCargado: Boolean;
        FAcumPeriodoCargado: Boolean;
        // Orden de cálculo de cada Tipo Liquidación (Tab50578.Orden): decide qué liquidaciones del mes cuentan
        // como "ya liquidadas" para la actual — ver EsAnteriorEnElMes.
        FOrdenTipo: Dictionary of [Code[20], Integer];
        FOrdenTipoCargado: Boolean;
        FEstaLiqCargado: Boolean;
        FNombresVarSis: List of [Text];
        FNombresVarSisCargados: Boolean;

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
    begin
        // Los llamadores existentes conservan exactamente su límite de valoración.
        Init(EmployeeNo, JobNo, CodPeriodo, FechaRef, CodConvenio, CodCategoria,
            LiqNo, TipoLiq, CoberturaDesde, FechaRef);
    end;

    procedure Init(
        EmployeeNo: Code[20];
        JobNo: Code[20];
        CodPeriodo: Code[10];
        FechaRef: Date;
        CodConvenio: Code[20];
        CodCategoria: Code[20];
        LiqNo: Code[20];
        TipoLiq: Code[20];
        CoberturaDesde: Date;
        CoberturaHasta: Date)
    var
        Periodo: Record "Período Liquidación";
    begin
        FEmployeeNo := EmployeeNo;
        FJobNo := JobNo;
        FCodPeriodo := CodPeriodo;
        FFechaRef := FechaRef;
        // Los acumulados históricos dependen de empleado, fecha, período y liquidación: los cuatro
        // se fijan acá, así que acá se tiran. Sin esto, un lote que reusa la instancia le pasaría
        // los totales de un tripulante al siguiente.
        InvalidarAcumulados();
        Clear(FOrdenTipo);
        FOrdenTipoCargado := false;
        // LA VENTANA ES LA DE LA LIQUIDACIÓN, NO LA DEL PERÍODO. Un cierre de marea
        // vive dentro de un período mensual pero cubre sólo sus días: la del 3/1 al
        // 29/1 de enero no tiene por qué ver lo que pasó el 1 y el 2. Tomando el
        // inicio del período, toda variable de período —DIAS_GP_PERIODO, francos,
        // vacaciones, cualquier Fuente de Datos— arrastraba días de antes del
        // embarque, que además ya los paga la liquidación REGULAR de la nómina:
        // se contaban dos veces.
        //
        // La valoración del cierre sigue al arribo. El puerto personal posterior puede
        // estar en la cobertura sin pertenecer al viaje ni cambiar TC o vigencias.
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
        ConfigurarLimitePuerto(CoberturaHasta);
        CargarTramos(LiqNo);
        FParamLog := '';
        FMoneda := '';
        Clear(FParamTC);
        // Los períodos del mes se recalculan por liquidación: el mismo codeunit se reusa para todo
        // un lote, y un lote puede cruzar meses.
        Clear(FPeriodosMes);
        FPeriodosMesCargados := false;
        FAdvertenciasParametros := '';
        Clear(FValoresTexto);
        Clear(FCodigosAtributos);
        // Dependen del empleado, del proyecto y de la fecha de referencia, que se fijan acá. Dejar el
        // sufijo de la liquidación anterior le daría el precio de otra pesquería a esta.
        Clear(FSufijoEje);
        FEjesCargados := false;
        // Depende de empleado y fecha de referencia, que se fijan acá.
        FBuqueUltMareaListo := false;
        FBuqueUltMarea := '';
        FFechaTCListo := false;
        FFechaTC := 0D;
        Clear(FActualCodMap);
        Clear(FParamBaseMap);
        Clear(FParamCodMap);
        Clear(FParamVigMap);
        FParametrosCCTHistoricos.Reset();
        FParametrosCCTHistoricos.DeleteAll();
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
        Clear(FParSinFila1);
        Clear(FParSinFila2);
        Clear(FNombresParam);
        FCalCacheLoaded := false;
    end;

    local procedure ConfigurarLimitePuerto(CoberturaHasta: Date)
    var
        Tipo: Record "Tipo Liquidación";
        Periodo: Record "Período Liquidación";
    begin
        FFechaHastaPuerto := FFechaRef;
        if CoberturaHasta <= FFechaRef then
            exit;
        if not Tipo.EsArribo(FTipoLiq) then
            exit;
        if not Periodo.Get(FCodPeriodo) then
            exit;
        if Periodo."Fecha Hasta" < FFechaRef then
            exit;
        FFechaHastaPuerto := CoberturaHasta;
        if FFechaHastaPuerto > Periodo."Fecha Hasta" then
            FFechaHastaPuerto := Periodo."Fecha Hasta";
    end;

    procedure BuildContext(var Ctx: Dictionary of [Text, Decimal])
    begin
        Clear(Ctx);
        LoadScalars(Ctx);
        LoadDynamicSources(Ctx);
        // VA DESPUÉS DE LoadDynamicSources Y NO DENTRO DE LoadParametros, que sería el lugar obvio:
        // TC_COMPRADOR y TC_VENDEDOR son Fuentes de Datos, así que mientras se cargan los parámetros
        // todavía no existen. Convertir ahí los dejaría en cero.
        //
        // Y NO se resuelve adelantando LoadDynamicSources: LoadAtributos está escrito para no pisar
        // lo que ya ocupó un parámetro o una fuente, y mover el orden invierte esa precedencia.
        ConvertirParametrosEnDivisa(Ctx);
        LoadAtributos(Ctx);
        InitAccumulators(Ctx);
    end;

    /// <summary>
    /// Resuelve las Fuentes de Datos TC_* y se las presta al ledger de francos.
    /// </summary>
    /// <remarks>
    /// POR QUÉ EL LEDGER NO PUEDE LEERLAS DEL CONTEXTO. Busca el precio con el convenio y la
    /// categoría SELLADOS EN CADA LOTE, no con el par de esta liquidación —es lo que hace al franco
    /// no fungible—, así que lee `Parámetro Vigente` por su cuenta y se saltea
    /// `ConvertirParametrosEnDivisa`. Sin esto, una fila en divisa se usaría como si fueran pesos.
    ///
    /// DÓNDE SE LLAMA: en medio de LoadScalars, entre LoadParametros —que es donde se conoce
    /// FMoneda, que el filtro de la fuente necesita— y LoadVariablesSistema, que es donde se valúan
    /// los francos. La ventana es de una línea.
    ///
    /// SE LE PASA TAMBIÉN AL MOTOR. `Cod50014` tiene su PROPIA instancia de Gestión Francos para el
    /// desglose por lote, y una instancia no ve lo que se le publicó a la otra: el motor las pide
    /// con `GetTiposCambioFrancos` después de armar el contexto.
    /// </remarks>
    local procedure ResolverTiposCambioFrancos()
    var
        Fuente: Record "Fuente Datos Liquidación";
        Nombre: Text;
    begin
        Clear(FTiposCambio);
        Fuente.SetRange(Activo, true);
        Fuente.SetFilter("Nombre Variable", 'TC_*');
        if Fuente.FindSet() then
            repeat
                Nombre := Fuente."Nombre Variable";
                if FTiposCambio.ContainsKey(Nombre) then
                    FTiposCambio.Set(Nombre, ResolveFuente(Fuente))
                else
                    FTiposCambio.Add(Nombre, ResolveFuente(Fuente));
            until Fuente.Next() = 0;
        FFrancosMgt.PublicarTiposCambio(FTiposCambio);
    end;

    /// <summary>Las cotizaciones ya resueltas, para la otra instancia del ledger.</summary>
    procedure GetTiposCambioFrancos(var TCs: Dictionary of [Text, Decimal])
    begin
        TCs := FTiposCambio;
    end;

    /// <summary>
    /// Las cotizaciones TC_* a una fecha, para quien valúa francos SIN armar un contexto de
    /// liquidación.
    /// </summary>
    /// <remarks>
    /// ESTE ES EL CAMINO DE LAS PÁGINAS. `GetTiposCambioFrancos` sirve al motor, que ya armó el
    /// contexto y sólo pide prestadas las cotizaciones que resolvió. Una página no armó nada: abre
    /// el detalle de una línea ya calculada y reconstruye el desglose por lote, así que su instancia
    /// del ledger nace con el diccionario vacío y la primera fila en divisa corta con
    /// `ErrFrancoTCInexistente` —"la cotización no existe en el contexto de la liquidación"—.
    ///
    /// Es la tercera vez que aparece el mismo agujero: una instancia de Gestión Francos no ve lo que
    /// se le publicó a otra. Lo tenían el motor y el desglose por lote de `Cod50014`; faltaban las
    /// dos páginas. En vez de que cada llamador aprenda la firma de `Init`, se la encierra acá.
    ///
    /// El par convenio/categoría va vacío A PROPÓSITO: las fuentes TC_* son cotizaciones por fecha y
    /// no dependen del encuadre, y el franco se valúa con el par SELLADO EN SU LOTE, que el ledger
    /// lee por su cuenta. Pasar el par del tripulante de hoy sería justo el error que hace al franco
    /// fungible.
    ///
    /// LA MONEDA SÍ HAY QUE PASARLA, y va DESPUÉS de `Init`, que la limpia. `TC_COMPRADOR` filtra la
    /// cotización por `{MONEDA}`, token que llena `LoadParametros` —acá no corre—, así que sin esto
    /// el filtro queda vacío y la fuente devuelve la cotización de otra divisa o cero. El llamador
    /// la saca de `GestionFrancos.MonedaDelPrecio`, que la lee del parámetro del precio.
    /// </remarks>
    procedure TiposCambioFrancosAFecha(EmployeeNo: Code[20]; FechaRef: Date; Moneda: Code[10]; var TCs: Dictionary of [Text, Decimal])
    begin
        Init(EmployeeNo, '', '', FechaRef, '', '', '', '', 0D);
        FMoneda := Moneda;
        ResolverTiposCambioFrancos();
        TCs := FTiposCambio;
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
                // El compañero <VAR>_ULT_MAREA, por el mismo motivo que el _ESFCY de los parámetros
                // doce líneas más arriba: es un nombre que sólo existe en runtime, y este contexto
                // es el que la validación previa usa para decidir si una fórmula nombra algo que no
                // existe. Sin esto la liquidación ni siquiera llega a calcularse: ValidarFormulas
                // corta antes, y el error apunta a la variable como si estuviera mal escrita.
                if TipoAtr."Publicar Última Marea" then
                    DefinirEnCero(Ctx, TipoAtr."Nombre Variable" + '_ULT_MAREA', 'Atributo');
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
            // HAY QUE VOLVER A CONVERTIR. LoadParametros pisa el contexto con los valores crudos de
            // la base, así que los parámetros en divisa del par nuevo entran en divisa y la pasada
            // de la carga inicial ya pasó. Sin esto, un concepto marcado con otro par lee dólares
            // creyendo que son pesos: el 03664 tenía BASE_PROD_CAL convertido y PROD_EMPRESA sin
            // convertir EN LA MISMA LIQUIDACIÓN, porque uno usa el par del empleado y el otro el de
            // la asignación. No se nota como error, sólo como un importe mil veces más chico.
            //
            // Va ANTES de GuardarValoresDelPar: lo que se cachea tiene que ser el valor convertido,
            // porque al volver al par se restaura de la caché y no se recarga.
            ConvertirParametrosEnDivisa(Ctx);
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
            CopiarSinFila(FParamSinFila, FParSinFila1);
            exit;
        end;
        FParClave2 := Clave;
        CapturarValoresParam(Ctx, FParValores2);
        CopiarSinFila(FParamSinFila, FParSinFila2);
    end;

    // Restaurar sólo los valores dejaba la lista de precios sin fila del OTRO par: un concepto del par del empleado avisaba
    // PRECIO_PUERTO sin valor mientras lo liquidaba con 1.800.000 (175/75 OF02, enero de 2026).
    local procedure RestaurarValoresDelPar(Clave: Text; var Ctx: Dictionary of [Text, Decimal]): Boolean
    begin
        if (FParClave1 = Clave) and (FParValores1.Count() > 0) then begin
            AplicarValoresParam(Ctx, FParValores1);
            CopiarSinFila(FParSinFila1, FParamSinFila);
            exit(true);
        end;
        if (FParClave2 = Clave) and (FParValores2.Count() > 0) then begin
            AplicarValoresParam(Ctx, FParValores2);
            CopiarSinFila(FParSinFila2, FParamSinFila);
            exit(true);
        end;
        exit(false);
    end;

    // Copia elemento por elemento para que el Clear de la pasada siguiente no pueda alcanzar a la caché.
    local procedure CopiarSinFila(var Origen: Dictionary of [Text, Boolean]; var Destino: Dictionary of [Text, Boolean])
    var
        Nombre: Text;
    begin
        Clear(Destino);
        foreach Nombre in Origen.Keys() do
            Destino.Add(Nombre, true);
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

    /// <summary>
    /// ¿El parámetro con ese nombre de variable es un precio que el convenio del empleado tiene cargado, pero sin ninguna fila para
    /// su categoría y fecha?
    /// </summary>
    procedure EsParametroSinFila(Nombre: Text): Boolean
    begin
        exit(FParamSinFila.ContainsKey(Nombre));
    end;

    // Las bases que tienen alguna fila con la clave exacta del empleado: terminada en _<convenio>_<categoría> o en _<convenio>
    // (con o sin sufijo de eje adelante, como VALOR_FRANCO_CAL_729/15_MR08), en cualquier fecha. Si LoadParametros no encontró
    // ninguna fila vigente, las que hay son todas posteriores. Una sola consulta por pasada, no una por parámetro sin fila.
    local procedure CargarBasesDelConvenio()
    var
        ParamVig: Record "Parámetro Vigente";
    begin
        Clear(FBasesDelConvenio);
        if FCodConvenio = '' then
            exit;
        ParamVig.SetLoadFields("Cód. Parámetro Base");
        if FCodCategoria <> '' then
            ParamVig.SetFilter("Cód. Parámetro", '%1|%2', '*_' + FCodConvenio + '_' + FCodCategoria, '*_' + FCodConvenio)
        else
            ParamVig.SetFilter("Cód. Parámetro", '%1', '*_' + FCodConvenio);
        if ParamVig.FindSet() then
            repeat
                if not FBasesDelConvenio.ContainsKey(ParamVig."Cód. Parámetro Base") then
                    FBasesDelConvenio.Add(ParamVig."Cód. Parámetro Base", true);
            until ParamVig.Next() = 0;
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
        // JUSTO ACÁ, EN MEDIO DE LAS DOS, y la ventana es de una sola línea de ancho:
        //   • DESPUÉS de LoadParametros porque el filtro de TC_COMPRADOR es `{MONEDA}`, y FMoneda
        //     recién se conoce ahí —sale de la primera fila de parámetro que venga en divisa—.
        //     Antes, el filtro queda en blanco, la fuente no trae ninguna fila y el TC da cero.
        //   • ANTES de LoadVariablesSistema porque PAGO_FRANCOS_FIFO y SALDO_FRANCOS valúan contra
        //     el ledger, que ya necesita la cotización para convertir el precio del franco.
        // No sirve ponerlo junto al resto de las Fuentes de Datos: LoadDynamicSources corre después
        // de LoadScalars y para entonces los francos ya se valuaron.
        ResolverTiposCambioFrancos();
        LoadVariablesSistema(Ctx);
    end;

    /// <summary>Convierte a pesos los parámetros cargados en divisa, con el TC que cada uno declara.</summary>
    /// <remarks>
    /// Segunda pasada: los parámetros entran al contexto en su divisa y acá se convierten, una vez
    /// que las Fuentes de Datos ya pusieron TC_COMPRADOR y TC_VENDEDOR sobre la mesa.
    ///
    /// APAGADA POR DEFECTO. Mientras "Convertir Param. por TC" esté en falso el motor se comporta
    /// como siempre y esto no toca nada. El plan para encenderla —y por qué hay que migrar en el
    /// mismo movimiento las 4 fórmulas que todavía usan {VARIABLE}_ESFCY— está en
    /// GROSSING_UP_Y_TC_CONFIGURABLES.md.
    ///
    /// El valor de {VARIABLE}_ESFCY se deja como está aunque el valor ya esté convertido: apagar la
    /// bandera volvería a multiplicar, y mientras la llave de paso exista las dos lecturas tienen que
    /// seguir contando la misma historia. Se limpia cuando se retire el mecanismo viejo.
    /// </remarks>
    local procedure ConvertirParametrosEnDivisa(var Ctx: Dictionary of [Text, Decimal])
    var
        HRSetup: Record "Human Resources Setup";
        NombreVar: Text;
        NombreTC: Code[60];
        TipoCambio: Decimal;
    begin
        if not HRSetup.Get() then
            exit;
        if not HRSetup."Convertir Param. por TC" then
            exit;

        // Los tres casos que no pueden convertir CORTAN. Antes avisaban y dejaban el importe en
        // divisa, que es la peor de las opciones: un número válido, mil cuatrocientas veces más
        // chico, que ningún control de importe detecta. Convertir por 1 sería lo mismo.
        //
        // Cortar es barato porque los tres se arreglan con un campo o con una cotización, y porque
        // la llave de paso sigue ahí: apagar "Convertir Param. por TC" vuelve al comportamiento
        // viejo sin publicar.
        foreach NombreVar in FParamTC.Keys() do begin
            NombreTC := FParamTC.Get(NombreVar);
            if NombreTC = '' then
                Error(ErrParamSinVariableTC, NombreVar);
            if not Ctx.ContainsKey(NombreTC) then
                Error(ErrVariableTCInexistente, NombreTC, NombreVar);
            TipoCambio := Ctx.Get(NombreTC);
            if TipoCambio <= 0 then
                Error(ErrVariableTCEnCero, NombreTC, NombreVar, FFechaRef);
            if Ctx.ContainsKey(NombreVar) then
                Ctx.Set(NombreVar, Ctx.Get(NombreVar) * TipoCambio);
        end;
    end;

    internal procedure LoadParametros(var Ctx: Dictionary of [Text, Decimal])
    var
        Param: Record "Parámetro";
        CodigoEfectivo: Code[50];
        ActualCod: Code[50];
        ValorMap: Dictionary of [Code[50], Decimal];
        VigMap: Dictionary of [Code[50], Date];
        MonedaMap: Dictionary of [Code[50], Code[10]];
        TCMap: Dictionary of [Code[50], Code[60]];
        Valor: Decimal;
        VigDate: Date;
        Moneda: Code[10];
        NombreEsFCY: Text;
        EsFCY: Decimal;
    begin
        BuildParametroCache(ValorMap, VigMap, MonedaMap, TCMap);

        // FParamTC se rearma de cero en cada pasada, igual que la caché de valores. UsarParCCT
        // vuelve a llamar acá con otro par, y un parámetro puede estar en divisa en un par y en
        // pesos en el otro —BASICO y PRECIO_PUERTO son mixtos a propósito: ARS para marinería y USD
        // para oficiales, en el mismo parámetro—. Conservar la
        // entrada del par anterior haría que la conversión multiplique por el tipo de cambio un
        // valor que ya está en pesos.
        Clear(FParamTC);

        // La lista de nombres que esta pasada escribe en el contexto. La usa la caché por par para
        // saber qué copiar y qué restaurar sin volver a la base.
        Clear(FNombresParam);
        // Los que esta pasada no pudo resolver a ninguna fila: valen cero. El evaluador los anota cuando una fórmula los lee
        // como valor (precio faltante). Se rehace en cada pasada, igual que FParamTC: otro par puede tenerlos.
        Clear(FParamSinFila);
        CargarBasesDelConvenio();

        Param.SetFilter("Nombre Variable", '<>%1', '');
        if not Param.FindSet() then exit;
        repeat
            FNombresParam.Add(Param."Nombre Variable");
            FNombresParam.Add(Param."Nombre Variable" + '_ESFCY');
            CodigoEfectivo := ResolverCodigoEfectivo(Param, ValorMap, VigMap);

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
            // Sin fila para este empleado no alcanza: en este motor un parámetro ausente que vale cero es la forma normal de decir
            // "no aplica" (NETO_GU sólo para los garantizados, PCT_CONTRIB_SIND sólo para algunos sindicatos, PCT_PROD sólo para
            // las categorías que cobran producción). Tampoco alcanza que el convenio lo tenga para OTRAS categorías: ese cero
            // también puede ser correcto. Lo que delata un precio faltante sin dudas es que la clave EXACTA del empleado —su
            // convenio y categoría, o su convenio— tenga filas, pero ninguna vigente a la fecha: cargado desde más adelante, o con
            // un hueco de vigencia (primera versión del 25/10/2026: el informe de enero dio 3.285 avisos, casi todos "no aplica").
            if VigDate = 0D then begin
                if FBasesDelConvenio.ContainsKey(Param.Código) then
                    if not FParamSinFila.ContainsKey(Param."Nombre Variable") then
                        FParamSinFila.Add(Param."Nombre Variable", true);
            end else
                if FParamSinFila.ContainsKey(Param."Nombre Variable") then
                    FParamSinFila.Remove(Param."Nombre Variable");

            // {VarName}_ESFCY = 1 when the parameter value is stored in foreign currency,
            // 0 when it is already in local currency. Lets formulas gate TC multiplication:
            //   IF(BASICO_ESFCY, BASICO * TC_CERCANO, BASICO)
            // Uppercase suffix so it matches the formula evaluator's ToUpper() normalization.
            NombreEsFCY := Param."Nombre Variable" + '_ESFCY';
            if Moneda <> '' then begin
                EsFCY := 1;
                if FMoneda = '' then
                    FMoneda := Moneda;
                if TCMap.ContainsKey(CodigoEfectivo) then
                    FParamTC.Set(Param."Nombre Variable", TCMap.Get(CodigoEfectivo));
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

    // Resuelve la clave derivada a usar para este parámetro. Los candidatos van de la MÁS específica
    // a la MENOS específica:
    //   COD_<empleado> → COD_<convenio>_<categoría> → COD_<convenio> → COD
    // pero el que gana es el de VIGENCIA MÁS RECIENTE, y la especificidad sólo desempata. Una fila
    // genérica con vigencia posterior pisa a una específica anterior: es la forma de expresar un
    // cambio que alcanza a todos sin repetirlo en cada fila. Ver Claves Parámetro Liq..Resolver, que
    // explica la regla y lo que cuesta.
    // Si no hay ninguna, devuelve la más específica (no encontrada): el llamador la trata como
    // valor 0 / sin vigencia.
    local procedure ResolverCodigoEfectivo(var Param: Record "Parámetro"; var ValorMap: Dictionary of [Code[50], Decimal]; var VigMap: Dictionary of [Code[50], Date]): Code[50]
    var
        Claves: Codeunit "Claves Parámetro Liq.";
        Ejes: List of [Code[10]];
    begin
        // La cascada vive en un solo lugar. Ya no depende de banderas declaradas en el parámetro:
        // se consultan todos los alcances y se eligen por fecha.
        Ejes := SufijosDeEjeDelParametro(Param);
        exit(Claves.ResolverConEjes(Param.Código, Ejes, FEmployeeNo, FCodConvenio, FCodCategoria, ValorMap, VigMap));
    end;

    /// <summary>
    /// Los sufijos de eje que le corresponden a ESTE parámetro en ESTA liquidación.
    /// </summary>
    /// <remarks>
    /// La lista tiene que quedar DENSA y en orden, porque la cascada la lee como prefijo. Si el valor
    /// vigente de un eje no resuelve —el empleado no está embarcado, el buque no tiene el atributo
    /// cargado— se corta ahí y no se siguen agregando: con el eje 1 vacío y el 2 cargado, la clave
    /// pondría el sufijo del 2 en la primera posición y resolvería contra las filas del 1.
    ///
    /// Que la lista salga corta no es un error: la cascada prueba igual los prefijos más cortos y
    /// termina en la clave base, que es el valor por defecto. Lo que no puede hacer es desordenarse.
    /// </remarks>
    local procedure SufijosDeEjeDelParametro(var Param: Record "Parámetro") Lista: List of [Code[10]]
    var
        Tipos: List of [Code[20]];
        CodTipo: Code[20];
        Sufijo: Code[10];
    begin
        if (Param."Cód. Tipo Atributo 1" = '') and (Param."Cód. Tipo Atributo 2" = '')
           and (Param."Cód. Tipo Atributo 3" = '') then
            exit;

        CargarSufijosDeEje();

        if Param."Cód. Tipo Atributo 1" <> '' then
            Tipos.Add(Param."Cód. Tipo Atributo 1");
        if Param."Cód. Tipo Atributo 2" <> '' then
            Tipos.Add(Param."Cód. Tipo Atributo 2");
        if Param."Cód. Tipo Atributo 3" <> '' then
            Tipos.Add(Param."Cód. Tipo Atributo 3");

        foreach CodTipo in Tipos do begin
            // ContainsKey y Get NUNCA en la misma expresión: AL no cortocircuita y el Get correría
            // igual sobre la clave que no está.
            if not FSufijoEje.ContainsKey(CodTipo) then
                exit;
            Sufijo := FSufijoEje.Get(CodTipo);
            if Sufijo = '' then
                exit;
            Lista.Add(Sufijo);
        end;
    end;

    /// <summary>
    /// Resuelve, una vez por liquidación, el sufijo vigente de cada tipo de atributo usado como eje.
    /// </summary>
    /// <remarks>
    /// SE CACHEA POR LIQUIDACIÓN Y NO POR PASADA. UsarParCCT vuelve a llamar a LoadParametros con
    /// otro convenio y otra categoría, y los ejes no dependen del par —salen del empleado, del
    /// proyecto o del buque—, así que recalcularlos sería leer la misma cosa dos veces por concepto
    /// marcado.
    /// </remarks>
    local procedure CargarSufijosDeEje()
    var
        Param: Record "Parámetro";
    begin
        if FEjesCargados then
            exit;
        // Se marca ANTES de resolver: si un tipo no resuelve no se guarda entrada, y sin la marca
        // cada parámetro que lo declare volvería a intentarlo contra la base.
        FEjesCargados := true;

        Param.SetFilter("Cód. Tipo Atributo 1", '<>%1', '');
        if Param.FindSet() then
            repeat
                ResolverSufijoDeEje(Param."Cód. Tipo Atributo 1");
                ResolverSufijoDeEje(Param."Cód. Tipo Atributo 2");
                ResolverSufijoDeEje(Param."Cód. Tipo Atributo 3");
            until Param.Next() = 0;
    end;

    local procedure ResolverSufijoDeEje(CodTipoAtributo: Code[20])
    var
        TipoAtr: Record "Tipo Atributo Liq.";
        Atributo: Record "Atributo Entidad Liq.";
        Valor: Record "Valor Atributo Liq.";
        CodEntidad: Code[20];
    begin
        if CodTipoAtributo = '' then
            exit;
        if FSufijoEje.ContainsKey(CodTipoAtributo) then
            exit;
        if not TipoAtr.Get(CodTipoAtributo) then
            exit;

        // De qué entidad es el atributo lo dice el propio tipo: TIPOACTIVIDAD es del BUQUE, y el
        // buque sale del proyecto de la liquidación. Un eje por obra social sería del empleado.
        CodEntidad := EntidadDeLaLiquidacion(TipoAtr."Tipo Entidad");
        if CodEntidad = '' then
            exit;
        if not AtributoVigente(CodTipoAtributo, TipoAtr."Tipo Entidad", CodEntidad, Atributo) then
            exit;

        // El valor se busca por rango y no con un Get: la PK de "Valor Atributo Liq." lleva TRES
        // campos —tipo, valor padre y código— y un Get con dos asignaría el código al campo del
        // padre sin que nada falle.
        Valor.SetRange("Cód. Tipo Atributo", CodTipoAtributo);
        Valor.SetRange(Código, Atributo."Cód. Valor");
        if not Valor.FindFirst() then
            exit;
        if Valor."Sufijo Parámetro" = '' then
            exit;
        FSufijoEje.Set(CodTipoAtributo, Valor."Sufijo Parámetro");
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
        if VigDate = 0D then begin
            // Un parámetro cargado por convenio, por par o por empleado no resuelve para quien
            // queda fuera de ese alcance, y eso es lo normal: la fórmula que lo consume lo envuelve
            // en IFZERO. Pero LoadParametros recorre TODOS los parámetros en TODAS las
            // liquidaciones, así que sin este corte cada uno dejaba un aviso por liquidación de
            // cada empleado ajeno a su alcance: 4.683 de COEF_GUARDIA_PUERTO, 5.481 de
            // PRECIO_PUERTO_CAL y 4.174 de PRECIO_PUERTO_LAN sólo en enero de 2026.
            //
            // Lo que sí hay que avisar es la base que no tiene NINGUNA versión vigente a la fecha:
            // ahí falta una carga, no un alcance.
            if FBasesConFilas.ContainsKey(Param.Código) then exit;
            Mensaje := StrSubstNo(MsgParamSinValor, Param."Nombre Variable");
        end else begin
            FechaLimite := CalcDate(Param."Antigüedad Máxima Vigencia", FFechaRef);
            if VigDate < FechaLimite then
                Mensaje := StrSubstNo(MsgParamDesactualizado, Param."Nombre Variable", VigDate, FFechaRef - VigDate);
        end;
        AgregarAdvertenciaParametro(Mensaje);
    end;

    /// <summary>Suma un aviso a la tira que el motor muestra al terminar de calcular.</summary>
    local procedure AgregarAdvertenciaParametro(Mensaje: Text)
    begin
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
        var MonedaMap: Dictionary of [Code[50], Code[10]];
        var TCMap: Dictionary of [Code[50], Code[60]])
    var
        ParamVig: Record "Parámetro Vigente";
        EffKey: Code[50];
    begin
        Clear(FBasesConFilas);
        ParamVig.SetCurrentKey("Cód. Parámetro", "Vigencia Desde");
        ParamVig.SetFilter("Vigencia Desde", '<=%1', FFechaRef);
        if not ParamVig.FindSet() then exit;
        repeat
            EffKey := EffectiveKey(ParamVig);
            // Qué bases llegaron a tener alguna versión vigente a esta fecha, sin importar para
            // qué alcance. Lo usa CheckVigenciaDesactualizada para no confundir "no está cargado"
            // con "no aplica a este empleado".
            if not FBasesConFilas.ContainsKey(ParamVig."Cód. Parámetro Base") then
                FBasesConFilas.Add(ParamVig."Cód. Parámetro Base", true);
            if ValorMap.ContainsKey(EffKey) then begin
                ValorMap.Set(EffKey, ParamVig.Valor);
                VigMap.Set(EffKey, ParamVig."Vigencia Desde");
                MonedaMap.Set(EffKey, ParamVig.Moneda);
                TCMap.Set(EffKey, ParamVig."Cód. Variable TC");
            end else begin
                ValorMap.Add(EffKey, ParamVig.Valor);
                VigMap.Add(EffKey, ParamVig."Vigencia Desde");
                MonedaMap.Add(EffKey, ParamVig.Moneda);
                TCMap.Add(EffKey, ParamVig."Cód. Variable TC");
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
        IndiceHistorico: Integer;
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
        // Una misma acumulación puede usar varias vigencias de un parámetro. La PK del índice
        // admite una fila por nombre: los alias de auditoría distinguen las vigencias, y los
        // campos propios conservan su código/clave/fecha reales. No son variables de fórmula.
        FParametrosCCTHistoricos.Reset();
        if FParametrosCCTHistoricos.FindSet() then
            repeat
                if not ParamVig.Get(FParametrosCCTHistoricos."Cód. Parámetro Base", FParametrosCCTHistoricos."Cód. Parámetro", FParametrosCCTHistoricos."Vigencia Desde") then
                    Error('No se encuentra la vigencia histórica del parámetro %1 usada en el cálculo.', FParametrosCCTHistoricos."Cód. Parámetro");
                if (ParamVig.Valor <> FParametrosCCTHistoricos.Valor) or (ParamVig.Moneda <> FParametrosCCTHistoricos.Moneda) or
                   (ParamVig."Cód. Variable TC" <> FParametrosCCTHistoricos."Cód. Variable TC")
                then
                    Error('La vigencia histórica del parámetro %1 cambió durante el cálculo.', ParamVig."Cód. Parámetro");
                if not ParamVig."En Uso" then begin
                    ParamVig."En Uso" := true;
                    ParamVig.Modify();
                end;
                IndiceHistorico += 1;
                RegistrarUsoParametro('HIST_CCT~' + Format(IndiceHistorico, 0, 9), ParamVig);
            until FParametrosCCTHistoricos.Next() = 0;
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

            // TIPO_LIQ se publica ADEMÁS como código, para que una fórmula pueda escribir
            // TIPO_LIQ = 'LIQ_FINAL' en vez del Orden. El número sigue funcionando; esto agrega una
            // segunda forma de nombrarlo, no la reemplaza.
            //
            // Va acá y no donde se fija FTipoLiq porque el nombre de la variable es CONFIGURABLE
            // —una instalación puede renombrarla, y Cod50077 lo dice— así que el código tiene que
            // colgarse del nombre real de la fila, no del literal. Es también el único lugar donde
            // el Cód. Cálculo y el Nombre Variable están los dos a mano sin una lectura extra.
            if VarSis."Cód. Cálculo" = CodCalcTipoLiqTok then
                FCodigosAtributos.Set(VarSis."Nombre Variable", FTipoLiq);

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

    /// <summary>
    /// El valor de la variable de sistema activa que se llama como un concepto, para devolvérselo al
    /// diccionario cuando se reinician los importes de los conceptos. False si el nombre no es de una variable.
    /// </summary>
    procedure ValorVariableSistemaHomonima(Nombre: Text; var Valor: Decimal): Boolean
    var
        VarSis: Record "Variable Sistema Liq.";
    begin
        // Se lo pregunta por cada concepto en cada vuelta del grossing-up: los nombres se leen una vez.
        if not FNombresVarSisCargados then begin
            VarSis.SetRange(Activo, true);
            if VarSis.FindSet() then
                repeat
                    if not FNombresVarSis.Contains(VarSis."Nombre Variable") then
                        FNombresVarSis.Add(VarSis."Nombre Variable");
                until VarSis.Next() = 0;
            FNombresVarSisCargados := true;
        end;
        if not FNombresVarSis.Contains(Nombre) then
            exit(false);

        VarSis.Reset();
        VarSis.SetRange(Activo, true);
        VarSis.SetRange("Nombre Variable", CopyStr(Nombre, 1, MaxStrLen(VarSis."Nombre Variable")));
        if not VarSis.FindFirst() then
            exit(false);
        Valor := ComputeVariableSistema(VarSis);
        exit(true);
    end;

    internal procedure ComputeVariableSistema(VarSis: Record "Variable Sistema Liq."): Decimal
    var
        Cat: Record "Categoría CCT";
        TipoLiq: Record "Tipo Liquidación";
    begin
        case VarSis."Cód. Cálculo" of
            'AÑOS_ANTIGUEDAD':
                exit(CalcAntiguedad());
            'AÑOS_ANTIG_30JUN':
                exit(CalcAntiguedadAl30Junio());
            'DIAS_HAB':
                exit(CalcDiasHabiles());
            'DIAS_MES':
                exit(CalcDiasMes());
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
            'HORAS_PROYECTO':
                exit(CalcHorasProyecto());
            'DIAS_MAREA':
                // Todos los días de la marea dentro de la ventana de esta liquidación: navegación
                // más puerto. Los dos son complementarios —cada día de borde cae en uno o en el
                // otro— así que la suma es exactamente la ventana completa, sin huecos ni dobles.
                //
                // Existe porque "los días de la marea" es un concepto del negocio que no tenía
                // nombre: las fórmulas lo escribían como DIAS_PROYECTO+DIAS_PUERTO cada vez, y en
                // los campos que esperan el NOMBRE de una variable —Variable Base— esa suma no se
                // podía expresar y quedaba en cero sin avisar.
                //
                // LOS DÍAS DE PUERTO DE FUERA DE LA ASIGNACIÓN SE RESTAN, y es la razón de ser de
                // esta variable frente a DIAS_PROYECTO + DIAS_PUERTO escritos a mano. La marea son
                // los días del BUQUE, de la zarpada al arribo; un tripulante que sube antes a hacer
                // trabajos de puerto suma un día SUYO, que el 1083 paga y que NO estira la marea.
                // DIAS_MAREA alimenta el objetivo del grossing-up y la producción, y ahí ese día no
                // va: el acuerdo se prorratea sobre los días del viaje. Medido contra el recibo de
                // Meta4, que lleva las dos cuentas por separado —DIAS_NAVEG 22, DIAS_PUERTO 1,
                // DIAS_MAREA 23— y prorratea el acuerdo sobre 22.
                exit(CalcDiasNavegacionMarea() + CalcDiasPuertoDelViaje());
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
            'EXCESO_NETO_GU_MES':
                exit(CalcExcesoNetoGUMes());
            'DIAS_ALTA_SEMESTRE':
                // Días CALENDARIO con el empleado de alta desde el 1 de enero (o julio) hasta el cierre del
                // período. Es el DIAS_SAC de Meta4 y es lo que prorratea el tope de SIPA de una liquidación
                // final: no los días del mes (DIAS_ALTA_30), porque el tope del SAC cubre el semestre.
                //
                // MEDIDO en las finales de febrero de 2026: 04766 dado de baja el 6/2 tiene 37 (31 de enero
                // + 6); Meta4 aporta el SAC sobre 3.932.339,08 x 37 / 360 = 404.155 y BC, con los 6 días del
                // mes, sobre 65.539. 04751 (baja el 12/2) tiene 43; 04139, 40. En enero coincide con los
                // días del mes (04190: 26, 04807: 28), por eso las finales de enero cerraban sin esto.
                exit(CalcDiasAltaSemestre());
            'SALDO_FRANCOS':
                // Saldo disponible a la fecha de esta liquidación, excluyendo su propia pasada.
                exit(FFrancosMgt.SaldoFrancos(FEmployeeNo, FLiqNo, FFechaRef));
            'PAGO_FRANCOS_SALDO':
                // EL SALDO ENTERO, valuado FIFO: para la indemnización de francos no gozados de una
                // liquidación final (concepto 2803). PAGO_FRANCOS_FIFO no sirve acá porque paga los
                // francos CONSUMIDOS del período —los días en estado Francos— y el que se va no los
                // consumió: se va con el saldo sin gozar.
                //
                // NO ALCANZA UN VALOR_FRANCO POR TERNA, y los datos lo dicen: en las finales de enero
                // de 2026, tres empleados de 729/15 MR08 cobraron 54.143,09, 59.803,50 y 53.158,67 por
                // día, y tres de MR04 otros tres valores distintos. Mismo convenio y misma categoría
                // pagando distinto sólo se explica por el lote: cada franco vale lo de SU lote, y un
                // parámetro con vigencia daría el valor de hoy para todos.
                //
                // Compone dos funciones que ya existían, sin lógica nueva: el saldo entra como los
                // días solicitados del mismo recorrido FIFO que usa el consumo normal. CaminarFIFO
                // marca los lotes, así que el saldo queda en cero después de pagarlo —que es lo
                // correcto: el vínculo se terminó y no quedan francos vivos.
                //
                // NO INCLUYE EL DEVENGO DE ESTA MISMA LIQUIDACIÓN, y no puede: las variables de
                // sistema se precalculan en LoadScalars, ANTES del bucle de conceptos, así que
                // cuando esto se evalúa el lote que el 1062 va a generar todavía no existe. El
                // devengo del último tramo se suma en la FÓRMULA del concepto, con
                // DIAS_DEVENGA_FRANCOS_COBERTURA y VALOR_FRANCO_DIA.
                exit(FFrancosMgt.ValorPagoFrancosFIFO(
                    FEmployeeNo, FFrancosMgt.SaldoFrancos(FEmployeeNo, FLiqNo, FFechaRef), FFechaRef, FLiqNo));
            'VALOR_FRANCO_DIA':
                // El precio de UN día de franco para el par que paga esta liquidación, para
                // valorizar en la fórmula los francos que todavía no tienen lote.
                exit(FFrancosMgt.ValorFrancoDiaDeLaLiquidacion(FEmployeeNo, FLiqNo, FFechaRef));
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
            'BASE_SAC_SEMESTRE':
                // Remuneraciones del SEMESTRE EN CURSO ya grabadas, para el SAC de egreso.
                //
                // EL SAC ES LA DOCEAVA PARTE DEL TOTAL DE LAS REMUNERACIONES (art. 121 LCT), no la
                // mitad de la mejor multiplicada por una proporción de días. Verificado al centavo
                // contra la columna TOT_PROMEDIOS de Meta4 en seis de los siete egresados de enero
                // de 2026: 6.650.454,07/12 = 554.204,51, 7.678.433,99/12 = 639.869,50.
                //
                // LA VENTANA ES EL SEMESTRE, no los seis meses anteriores: el SAC del primer
                // semestre se gana con lo trabajado DESDE el 1 de enero. Es la misma base que el
                // promedio de vacaciones —BASE_PROMEDIO— mirada por otra ventana, y por eso en un
                // egresado de enero las dos coinciden cuando su fase también arranca en enero.
                //
                // NO INCLUYE LA LIQUIDACIÓN EN CURSO: las variables de sistema se precalculan antes
                // del bucle de conceptos. La fórmula del concepto le suma #BASE_PROMEDIO.
                exit(CalcBaseSacSemestre());
            'DIAS_DEVENGA_FRANCOS_COBERTURA':
                // Días de estados que DEVENGAN FRANCOS dentro de la cobertura de esta liquidación.
                //
                // QUÉ ESTADOS DEVENGAN NO SE DECIDE ACÁ: sale de la bandera "Devenga Francos" del
                // Cód. Estado Empleado, que es configuración. Esto sólo los cuenta en otra ventana.
                //
                // POR QUÉ NO ALCANZA DIAS_ENROLAMIENTO: esa cuenta los días de LA MAREA y arranca
                // con `if FJobNo = '' then exit(0)`, así que en una liquidación final —que nace sin
                // proyecto porque agrupa por empleado— devuelve cero. El tripulante que devenga
                // francos en tierra, en guardia de puerto, no tiene marea que contar.
                //
                // EL AGUJERO QUE VIENE A TAPAR: el concepto de devengo (1062) sólo aplica a
                // CIERRE_MAREA, así que quien devenga francos en un tramo sin cierre no los devenga
                // nunca. Medido en enero de 2026: de 118 empleados con estados que devengan, 90
                // tuvieron cierre y 28 NO. Uno de ellos, con guardia de puerto del 1 al 14 de enero,
                // perdía los 7 francos que Meta4 sí le reconoce.
                exit(CalcDiasDevengaFrancosCobertura());
            'DIAS_PREST_PROM_VAC':
                // Los días de prestación DENTRO de la ventana del promedio. Es el divisor real del
                // art. 49, y reemplaza a MESES_PROM_VAC.
                //
                // "El total así obtenido, se dividirá por la cantidad de PERÍODOS MENSUALES
                // CONSIDERADOS". Un "período mensual" son TREINTA DÍAS, no un mes del calendario:
                // la fórmula es base / días * 30.
                //
                // NO ES UNA INTERPRETACIÓN: es lo que hace el sistema que se está reemplazando, y
                // cierra al centavo en los seis tripulantes dados de baja en enero de 2026 —94, 80,
                // 121, 64, 107 y 37 días— contra su propia columna PROM_6_ULT_MES.
                //
                // Y ES MEJOR QUE CONTAR MESES, que es lo que se hacía antes: un mes trabajado a
                // medias aportaba su fracción al numerador pero pesaba un mes ENTERO en el divisor, y
                // hundía el promedio. A un tripulante que entró el 25 de noviembre, ese mes le
                // aportaba seis días de sueldo y le sumaba treinta al divisor. Medido: los promedios
                // quedaban entre 38% y 1% cortos, desparejos; con días, exactos.
                exit(CalcDiasPrestacionPromedioVac());
            'VENT_PROM_ES_MES_ACTUAL':
                // 1 cuando la ventana del promedio de vacaciones ES el mes que se está liquidando.
                //
                // PARA QUÉ. SUMA_REM_VAC lee líneas YA GUARDADAS, así que la propia liquidación en
                // curso no entra: es correcto en el caso normal —la ventana son los seis meses
                // ANTERIORES (art. 49) y el mes actual no va—, pero no cuando el empleado entró este
                // mismo mes y su "fracción menor de prestación" ES este mes. Ahí la base se quedaría
                // sólo con lo que otra liquidación del mes ya grabó.
                //
                // MEDIDO en 04807, alta el 1/1/2026 y baja el 28/1: la base tomaba los 7.332.902,72
                // del cierre de marea pero no los 345.531,27 de su propia final —sueldo de franco,
                // de puerto y de feriado—, y el día de vacaciones salía 293.316,11 contra los
                // 329.075,74 del recibo de Meta4.
                //
                // Es una bandera y no la suma misma porque el valor en curso sólo lo tiene el
                // evaluador: la fórmula lo lee con #BASE_PROMEDIO, que acá no existe. Sin
                // circularidad: los cuatro conceptos de no gozados no aportan a BASE_PROMEDIO, y
                // todos los que sí aportan corren antes del orden 555.
                exit(VentanaPromedioIncluyeMesActual());
            'MESES_PROM_AUS_6':
                exit(CalcMesesPromedioAusencia(6));
            'MESES_PROM_AUS_12':
                exit(CalcMesesPromedioAusencia(12));
            'DIV_PROM_ENF_6':
                exit(CalcDivisorPromedioEnfermedad(6));
            'DIV_PROM_ENF_12':
                exit(CalcDivisorPromedioEnfermedad(12));
            'DIV_PROM_LIC':
                exit(CalcDivisorPromedioLicencia(VarSis));
            'DIAS_ESTADO_PERIODO':
                exit(CalcDiasEstadoPeriodo(VarSis."Cód. Estado"));
            'DIAS_ESTADO_PREVIOS':
                exit(CalcDiasEstadoPrevios(VarSis."Cód. Estado"));
            'DIAS_ALTA_30':
                // Días del MES COMERCIAL DE 30 en que el empleado estuvo de alta. Su complemento
                // —30 menos esto— son los días que el sueldo mensual no devengó, y es lo que
                // prorratea la deducción por ausencias del 4703.
                //
                // NO ES DIAS_MES, que da los días calendario y vale 31 en enero: la liquidación
                // argentina divide por 30 fijo y el día 31 no cuenta. Verificado contra Meta4 en
                // enero de 2026: de alta del 5 al 31 da 26 y Meta4 deduce 4/30; del 9 al 24 da 16 y
                // deduce 14/30.
                //
                // VA POR LA FASE Y NO POR LA COBERTURA DE LA LIQUIDACIÓN, aunque en los dos casos
                // medidos dieran lo mismo. Una cobertura parcial NO es una ausencia: la regular de
                // un tripulante cubre sólo los días que no cubre el cierre de marea, y prorratear
                // por eso le descontaría media nómina. La fase dice si existía la relación laboral,
                // que es lo que decide si el sueldo se devengó.
                exit(CalcDiasAlta30());
            'DIAS_VAC_PERIODO':
                // Days the employee was in a Vacaciones state that overlap with the current billing period.
                // Use this as the divisor/multiplier in the vacation day discount formula (concept 4743).
                exit(CalcDiasVacacionesPeriodo());

            'DEDUC_GANANCIAS':
                exit(CalcDeduccionesGanancias());
            'DEDUC_GANANCIAS_ACUM':
                exit(CalcDeduccionesGananciasAcum());
            'MES_ANUAL':
                // Calendar month number of the reference date (1 = January … 12 = December).
                // Used to project YTD income to annual: (HAB_GRAV_ANUAL + BASE_IG4) / MES_ANUAL * 12.
                exit(Date2DMY(FFechaRef, 2));
            'TIPO_LIQ':
                // El Orden del tipo de liquidación de esta corrida, para que una fórmula pueda
                // comportarse distinto según el documento. El caso que lo motivó: la producción de
                // una marea (PROD_KN_MAREA) son los kilos de la marea ENTERA, así que sólo es
                // comparable en un cierre; en un devengado a mitad de marea hay que ir por el
                // garantizado, que sí está prorrateado por los días del período.
                //
                // Se devuelve el Orden y no el código porque las fórmulas son numéricas.
                // Tab50578 obliga a que el Orden sea único justamente para que IF(TIPO_LIQ = 1, …)
                // identifique un solo tipo.
                //
                // OJO con el cero: una liquidación sin Cód. Tipo Liq. —las viejas, anteriores a la
                // migración— también da cero, y cero es el Orden de SALDO_INICIAL. Comparar contra
                // 0 no distingue esos dos casos; contra cualquier otro Orden sí.
                begin
                    if FTipoLiq = '' then
                        exit(0);
                    if TipoLiq.Get(FTipoLiq) then
                        exit(TipoLiq.Orden);
                    exit(0);
                end;
            'YTD_ACUM':
                exit(CalcImporteAnualPorAcumulador(VarSis."Cód. Acumulador"));
            'PERIODO_ACUM':
                exit(CalcImportePeriodoPorAcumulador(VarSis."Cód. Acumulador"));
            'PERIODO_CONCEPTO':
                exit(CalcImportePeriodoPorConcepto(VarSis."Cód. Concepto"));
            'MEJOR_MES_ACUM_SEMESTRE':
                // El MEJOR MES del semestre de un acumulador (Cód. Acumulador), sin el efecto de un
                // concepto (Cód. Concepto: se resta del acumulador mes a mes). Es el "mejor total mensual"
                // del que parte el SAC de egreso de un administrativo (ver CalcMejorMesAcumSemestre).
                exit(CalcMejorMesAcumSemestre(VarSis."Cód. Acumulador", VarSis."Cód. Concepto"));
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
    /// <summary>
    /// Carga de una sola vez, agrupados por concepto, los importes históricos del empleado — el del
    /// año para YTD_ACUM y el del período para PERIODO_ACUM.
    /// </summary>
    /// <remarks>
    /// POR QUE EXISTE. Antes cada lectura de un acumulador hacía UN CalcSums POR CONCEPTO de la
    /// fracción. Un acumulador con 100 conceptos son 100 consultas, no hay memoización de variables
    /// de sistema —cada fórmula que lo nombra vuelve a resolverlo— y hay varios acumuladores por
    /// liquidación. En el perfil de la 1.0.0.497 eso daba 3,41 s en el del período y 2,06 s en el
    /// anual sobre 27,4 s de cálculo. Acá se recorre UNA vez el conjunto del empleado y se suma por
    /// concepto en memoria.
    ///
    /// LOS DOS EXCLUYEN LA LIQUIDACIÓN EN CURSO, y eso NO es lo que hacía el anual. El del período ya
    /// la excluía. El anual no: sus líneas se escriben con Estado Calculada, así que entran en el
    /// filtro "Estado distinto de Borrador" y el importe del concepto NO es sólo histórico. Por eso se cachea
    /// la parte que no se mueve y lo de esta liquidación se lee aparte — ver CargarEstaLiq.
    ///
    /// HOY ESA SEGUNDA LECTURA VUELVE VACÍA SIEMPRE, y conviene saberlo antes de "simplificarla":
    /// las variables de sistema se resuelven una sola vez, en BuildContext, y para entonces
    /// DeleteLineas ya borró las líneas de esta liquidación y RunConceptos todavía no escribió
    /// ninguna. Es una consulta que no devuelve filas. Se deja porque es lo que hace que la función
    /// dé bien SIN IMPORTAR CUÁNDO se la llame: el día que alguien recalcule un acumulador a mitad
    /// de la corrida —como ya hace RecargarPctEscala con PCT_ESCALA— sin esto el valor perdería en
    /// silencio todo lo que la liquidación lleva liquidado.
    ///
    /// SE CARGA CON SetLoadFields porque sólo hacen falta dos campos de una tabla ancha, y el año de
    /// un tripulante son cientos de líneas.
    /// </remarks>
    local procedure CargarAcumHistorico(Anual: Boolean)
    var
        LinLiq: Record "Línea Liquidación";
        Acumulado: Decimal;
    begin
        LinLiq.Reset();
        LinLiq.SetLoadFields("Cód. Concepto", Importe, "No. Liquidación", "Cód. Tipo Liq.");
        LinLiq.SetRange("No. Empleado", FEmployeeNo);
        if Anual then begin
            LinLiq.SetCurrentKey("No. Empleado", "Fecha Liquidación");
            LinLiq.SetRange("Fecha Liquidación", DMY2Date(1, 1, Date2DMY(FFechaRef, 3)), FFechaRef);
        end else begin
            LinLiq.SetCurrentKey("No. Empleado", "Cód. Período", "Tipo Concepto");
            LinLiq.SetRange("Cód. Período", FCodPeriodo);
        end;
        LinLiq.SetFilter(Estado, '<>%1', LinLiq.Estado::Borrador);
        if FLiqNo <> '' then
            LinLiq.SetFilter("No. Liquidación", '<>%1', FLiqNo);
        if LinLiq.FindSet() then
            repeat
                if Anual then begin
                    if FAcumAnual.Get(LinLiq."Cód. Concepto", Acumulado) then
                        FAcumAnual.Set(LinLiq."Cód. Concepto", Acumulado + LinLiq.Importe)
                    else
                        FAcumAnual.Add(LinLiq."Cód. Concepto", LinLiq.Importe);
                end else
                    if EsAnteriorEnElMes(LinLiq."Cód. Tipo Liq.", LinLiq."No. Liquidación") then
                        if FAcumPeriodo.Get(LinLiq."Cód. Concepto", Acumulado) then
                            FAcumPeriodo.Set(LinLiq."Cód. Concepto", Acumulado + LinLiq.Importe)
                        else
                            FAcumPeriodo.Add(LinLiq."Cód. Concepto", LinLiq.Importe);
            until LinLiq.Next() = 0;
    end;

    /// <summary>
    /// Lo que la liquidación EN CURSO lleva liquidado, por concepto, dentro de la ventana del año.
    /// </summary>
    /// <remarks>
    /// SE ARMA EL MAPA ENTERO DE UNA VEZ, nunca por concepto: releerlo concepto por concepto serían
    /// 150 consultas para REMUNERATIVO_BRUTO, que es cambiar 150 consultas grandes por 150 chicas.
    ///
    /// Y SE CACHEA CON LA MISMA VIDA QUE EL HISTÓRICO, o sea hasta el próximo Init. Antes se releía
    /// en cada lectura de acumulador —una consulta por variable YTD— y el perfil 165 le puso precio:
    /// 41 muestras, 1,5% del tiempo ocupado, por una consulta que hoy NO DEVUELVE FILAS NUNCA. Las
    /// variables de sistema se resuelven todas juntas en BuildContext, cuando DeleteLineas ya borró
    /// las líneas de esta liquidación y RunConceptos todavía no escribió ninguna.
    ///
    /// SI ALGÚN DÍA SE RECALCULA UN ACUMULADOR A MITAD DE LA CORRIDA —como ya hace RecargarPctEscala
    /// con PCT_ESCALA— hay que llamar a InvalidarAcumulados() antes, o el valor va a quedar con la
    /// foto vieja. Esa es la contrapartida de no releer, y por eso el invalidador es público y tiene
    /// nombre: para que se encuentre desde el lugar donde haría falta.
    /// </remarks>
    /// <summary>
    /// Tira las tres cachés de acumulados: el histórico del año, el del período y lo que esta
    /// liquidación lleva escrito.
    /// </summary>
    /// <remarks>
    /// La llama Init, porque las tres dependen de empleado, fecha, período y liquidación, y los
    /// cuatro se fijan ahí. Es pública además para el caso que hoy no existe pero es el que puede
    /// romper esto en silencio: alguien que vuelva a pedir un acumulador DESPUÉS de que la corrida
    /// escribió líneas. Sin invalidar, se lleva la foto de antes de escribirlas.
    /// </remarks>
    procedure InvalidarAcumulados()
    begin
        Clear(FAcumAnual);
        Clear(FAcumPeriodo);
        Clear(FEstaLiq);
        FAcumAnualCargado := false;
        FAcumPeriodoCargado := false;
        FEstaLiqCargado := false;
    end;

    local procedure CargarEstaLiq(var Mapa: Dictionary of [Code[20], Decimal])
    var
        LinLiq: Record "Línea Liquidación";
        Acumulado: Decimal;
    begin
        Clear(Mapa);
        if FLiqNo = '' then
            exit;
        LinLiq.Reset();
        LinLiq.SetLoadFields("Cód. Concepto", Importe);
        LinLiq.SetRange("No. Liquidación", FLiqNo);
        LinLiq.SetRange("Fecha Liquidación", DMY2Date(1, 1, Date2DMY(FFechaRef, 3)), FFechaRef);
        LinLiq.SetFilter(Estado, '<>%1', LinLiq.Estado::Borrador);
        if LinLiq.FindSet() then
            repeat
                if Mapa.Get(LinLiq."Cód. Concepto", Acumulado) then
                    Mapa.Set(LinLiq."Cód. Concepto", Acumulado + LinLiq.Importe)
                else
                    Mapa.Add(LinLiq."Cód. Concepto", LinLiq.Importe);
            until LinLiq.Next() = 0;
    end;

    local procedure CalcImporteAnualPorAcumulador(CodAcum: Code[20]): Decimal
    var
        Fraccion: Record "Fracción Acumulador";
        Procesados: Dictionary of [Code[20], Boolean];
        Importe: Decimal;
        Parcial: Decimal;
        Total: Decimal;
    begin
        if not FAcumAnualCargado then begin
            CargarAcumHistorico(true);
            FAcumAnualCargado := true;
        end;
        if not FEstaLiqCargado then begin
            CargarEstaLiq(FEstaLiq);
            FEstaLiqCargado := true;
        end;

        Fraccion.SetLoadFields("Cód. Concepto", "Invertir Signo");
        Fraccion.SetCurrentKey("Cód. Acumulador", "Vigencia Desde");
        Fraccion.SetRange("Cód. Acumulador", CodAcum);
        Fraccion.SetFilter("Vigencia Desde", '<=%1', FFechaRef);
        if not Fraccion.FindSet() then exit(0);
        repeat
            if not Procesados.ContainsKey(Fraccion."Cód. Concepto") then begin
                Procesados.Add(Fraccion."Cód. Concepto", true);
                // El histórico sale de la caché; lo de esta liquidación se relee, porque crece
                // mientras se calcula. La suma de los dos es lo que devolvía el CalcSums de antes.
                if not FAcumAnual.Get(Fraccion."Cód. Concepto", Importe) then
                    Importe := 0;
                if FEstaLiq.Get(Fraccion."Cód. Concepto", Parcial) then
                    Importe += Parcial;
                if Fraccion."Invertir Signo" then
                    Total -= Importe
                else
                    Total += Importe;
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
        Procesados: Dictionary of [Code[20], Boolean];
        Importe: Decimal;
        Total: Decimal;
    begin
        if (CodAcum = '') or (FCodPeriodo = '') then
            exit(0);

        // ACÁ NO HAY PARTE VIVA, al revés que en el anual: este acumulador ya excluía la liquidación
        // en curso, así que lo que queda son liquidaciones que nadie está tocando. La caché alcanza.
        if not FAcumPeriodoCargado then begin
            CargarAcumHistorico(false);
            FAcumPeriodoCargado := true;
        end;

        Fraccion.SetLoadFields("Cód. Concepto", "Invertir Signo");
        Fraccion.SetCurrentKey("Cód. Acumulador", "Vigencia Desde");
        Fraccion.SetRange("Cód. Acumulador", CodAcum);
        Fraccion.SetFilter("Vigencia Desde", '<=%1', FFechaRef);
        if not Fraccion.FindSet() then
            exit(0);
        repeat
            if not Procesados.ContainsKey(Fraccion."Cód. Concepto") then begin
                Procesados.Add(Fraccion."Cód. Concepto", true);
                if not FAcumPeriodo.Get(Fraccion."Cód. Concepto", Importe) then
                    Importe := 0;
                if Fraccion."Invertir Signo" then
                    Total -= Importe
                else
                    Total += Importe;
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
    /// <summary>
    /// Cuánto neto pagaron DE MÁS, sobre su objetivo de grossing-up, las liquidaciones anteriores del mes.
    /// </summary>
    /// <remarks>
    /// EL NETO ACORDADO DE UN OFICIAL ES DEL MES, NO DE CADA LIQUIDACIÓN. Cuando el premio del cierre de marea ya
    /// supera el objetivo prorrateado, el tapón del grossing-up (2003) no suma nada y ese exceso queda cobrado. Meta4
    /// lo descuenta del objetivo de la liquidación siguiente; BC no, y la siguiente pagaba su objetivo entero. En
    /// febrero de 2026 04724 cobró 515.390 de neto de más en el cierre y 942.686 de bruto de más en el devengado.
    ///
    /// Por cada liquidación anterior que tenga línea NETO_GARANT: neto a pagar de la cabecera, más lo que el
    /// acumulador de exclusión del neto devuelve (los anticipos: plata ya entregada que no pesa en la convergencia),
    /// menos el objetivo. Es la misma cuenta de CalcNetoDesdeBD. Se devuelve la suma con signo; la fórmula de
    /// NETO_GARANT decide con MAX(0, …) si descuenta el exceso. Las liquidaciones sin NETO_GARANT (una Regular, un
    /// Anticipo) no entran: su neto no es un pago contra un objetivo.
    /// </remarks>
    local procedure CalcExcesoNetoGUMes() Total: Decimal
    var
        Liq: Record "Liquidación";
        Lin: Record "Línea Liquidación";
        HRSetup: Record "Human Resources Setup";
        CodPeriodo: Code[10];
        Objetivo: Decimal;
        Excluido: Decimal;
    begin
        if (FEmployeeNo = '') or (FCodPeriodo = '') or (FLiqNo = '') then
            exit(0);
        foreach CodPeriodo in PeriodosDelMes() do begin
            Liq.Reset();
            Liq.SetCurrentKey("Cód. Período", "No. Empleado");
            Liq.SetRange("No. Empleado", FEmployeeNo);
            Liq.SetRange("Cód. Período", CodPeriodo);
            Liq.SetFilter("No.", '<>%1', FLiqNo);
            Liq.SetFilter(Estado, '<>%1', Liq.Estado::Borrador);
            if Liq.FindSet() then
                repeat
                    if EsAnteriorEnElMes(Liq."Cód. Tipo Liq.", Liq."No.") then begin
                        Lin.Reset();
                        Lin.SetRange("No. Liquidación", Liq."No.");
                        Lin.SetRange("Cód. Concepto", 'NETO_GARANT');
                        Lin.CalcSums(Importe);
                        Objetivo := Lin.Importe;
                        if Objetivo <> 0 then begin
                            Excluido := 0;
                            if HRSetup.Get() then
                                if HRSetup."Cód. Acum. Excl. Neto GU" <> '' then begin
                                    Lin.SetRange("Cód. Concepto", HRSetup."Cód. Acum. Excl. Neto GU");
                                    Lin.CalcSums(Importe);
                                    Excluido := Lin.Importe;
                                end;
                            Total += Liq."Neto a Pagar" + Excluido - Objetivo;
                        end;
                    end;
                until Liq.Next() = 0;
        end;
    end;

    /// <summary>
    /// Una liquidación del mismo mes, ¿cuenta como "ya liquidada" para la que se está calculando?
    /// </summary>
    /// <remarks>
    /// SÓLO LAS ANTERIORES EN EL ORDEN DE CÁLCULO: primero el Orden del Tipo de Liquidación —el mismo con que
    /// el cálculo por lotes ordena, ver Cod50076—, y a igual Orden el No. Antes contaba TODAS las demás
    /// liquidaciones calculadas del mes, sin orden entre ellas, y entonces dos liquidaciones del mismo mes se
    /// veían una a la otra: el tope SIPA del cierre descontaba lo que había tomado el devengado y el del
    /// devengado lo que había tomado el cierre, y las dos retenían cero (04826 y 32 empleados más en febrero
    /// de 2026, 733 mil de bruto cada uno en los de grossing-up). Con el orden, la primera toma el tope y la
    /// segunda el resto, calcúlense en el orden que se calculen.
    ///
    /// Contrapartida: recalcular UNA liquidación no corrige a las que la siguen en el orden; si se rehace
    /// la primera hay que rehacer las demás del mes (el recálculo en cadena hace lo mismo con los períodos).
    /// Una liquidación sin Tipo (las viejas, previas a la migración) conserva el criterio anterior: las ve todas.
    /// </remarks>
    local procedure EsAnteriorEnElMes(TipoLinea: Code[20]; NoLinea: Code[20]): Boolean
    var
        OrdenLinea: Integer;
        OrdenActual: Integer;
    begin
        if FTipoLiq = '' then
            exit(true);
        OrdenLinea := OrdenDeTipoLiq(TipoLinea);
        OrdenActual := OrdenDeTipoLiq(FTipoLiq);
        if OrdenLinea <> OrdenActual then
            exit(OrdenLinea < OrdenActual);
        exit(NoLinea < FLiqNo);
    end;

    local procedure OrdenDeTipoLiq(CodTipo: Code[20]): Integer
    var
        TipoLiq: Record "Tipo Liquidación";
        Orden: Integer;
    begin
        if not FOrdenTipoCargado then begin
            if TipoLiq.FindSet() then
                repeat
                    FOrdenTipo.Set(TipoLiq.Código, TipoLiq.Orden);
                until TipoLiq.Next() = 0;
            FOrdenTipoCargado := true;
        end;
        if FOrdenTipo.Get(CodTipo, Orden) then
            exit(Orden);
        exit(0);
    end;

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
            LinLiq.SetLoadFields(Importe, "No. Liquidación", "Cód. Tipo Liq.");
            if LinLiq.FindSet() then
                repeat
                    if EsAnteriorEnElMes(LinLiq."Cód. Tipo Liq.", LinLiq."No. Liquidación") then
                        Total += LinLiq.Importe;
                until LinLiq.Next() = 0;
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
        DeduccionHist: Codeunit "Deducción Familiar Histórica";
        ReferenciaHist: Text;
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
        ImportePersonal: Decimal;
        FechaIngresoImp: Date;
        FechaEgresoImp: Date;
    begin
        // Part 1: family members — accumulate deduction fractions per type.
        // Las fechas determinan inclusión/exclusión, sin prorratear días del familiar.
        // Los parámetros están expresados por mes; la fórmula mensual los acumula.
        // En LIQ_FINAL se devuelve el monto anual, según RG4003 art.21b.
        // "% Deducción" (custody %) IS applied as the coefficient (e.g., 0.5 for shared custody).
        // Una foto mensual importada preserva el cálculo original sin reescribir
        // el maestro actual. Sin foto de ESTE mes se conserva el cálculo habitual.
        if DeduccionHist.Obtener(FEmployeeNo, FCodPeriodo, FTipoLiq, FFechaRef, Total, ReferenciaHist) then begin
            AppendParamLog('DED_FAM_HIST|' + FCodPeriodo + '|' + ReferenciaHist);
            if FLiqNo <> '' then begin
                Clear(DetGan);
                DetGan."No. Liquidación" := FLiqNo;
                DetGan.Tipo := DetGan.Tipo::Familiar;
                DetGan.Código := 'FAM_HIST_M4';
                DetGan.Descripción := 'Cargas familiares originales de Meta4 (mes)';
                // Es un total declarado, no la cantidad de familiares reconstruida.
                DetGan.Cantidad := 0;
                DetGan."Importe Unit. Anual" := 0;
                DetGan."Importe Total" := Total;
                DetGan.Orden := 500;
                DetGan.Insert();
            end;
        end else begin
            FraccionesFamiliares(FFechaRef, FPeriodoFechaDesde, InicioMesEdadActual(), TipoFraccion);

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
                    // Las cargas de familia del catálogo están expresadas por mes.
                    // La final computa el monto anual; los gastos declarados se conservan.
                    ImportePersonal := ParamVig.Valor;
                    if FTipoLiq = 'LIQ_FINAL' then
                        ImportePersonal *= 12;
                    Total += ImportePersonal * Fraccion;
                    if FLiqNo <> '' then begin
                        Clear(DetGan);
                        DetGan."No. Liquidación" := FLiqNo;
                        DetGan.Tipo := DetGan.Tipo::Familiar;
                        DetGan.Código := CodTipo;
                        DetGan.Descripción := CopyStr(ParamDesc, 1, MaxStrLen(DetGan.Descripción));
                        DetGan.Cantidad := Fraccion;
                        DetGan."Importe Unit. Anual" := ImportePersonal;
                        DetGan."Importe Total" := ImportePersonal * Fraccion;
                        DetGan.Orden := 500;
                        DetGan.Insert();
                    end;
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

    /// <summary>
    /// Suma, por tipo de deducción, la fracción de los familiares que deducen Ganancias en un mes.
    /// </summary>
    /// <remarks>
    /// Es el loop de la Parte 1 de CalcDeduccionesGanancias, sacado a un procedimiento para que el mes
    /// en curso y cada mes del acumulado anual (DEDUC_GANANCIAS_ACUM) usen EXACTAMENTE la misma regla. Un familiar
    /// deduce en el mes si tiene alta de impuesto a esa fecha, su baja no es anterior al inicio y no pasó el tope de
    /// edad al inicio del mes (el mes del cumpleaños cuenta).
    /// </remarks>
    local procedure FraccionesFamiliares(FechaRefMes: Date; DesdeBaja: Date; InicioMesEdad: Date; var TipoFraccion: Dictionary of [Code[20], Decimal])
    var
        EmpRel: Record "Employee Relative";
        CodTipo: Code[20];
        Fraccion: Decimal;
        PctRel: Decimal;
        FechaIngresoImp: Date;
        FechaEgresoImp: Date;
    begin
        EmpRel.SetRange("Employee No.", FEmployeeNo);
        EmpRel.SetFilter("Cód. Tipo Ded.", '<>%1', '');
        if EmpRel.FindSet() then
            repeat
                // SIN FECHA DE ALTA NO HAY DEDUCCIÓN: tener el familiar en la ficha no alcanza (ver
                // la lección familiar-alta-impuesto).
                FechaIngresoImp := FechaIngresoImpuesto(EmpRel);
                FechaEgresoImp := FechaEgresoImpuesto(EmpRel);
                if (FechaIngresoImp <> 0D) and (FechaIngresoImp <= FechaRefMes) and
                   ((FechaEgresoImp = 0D) or (FechaEgresoImp >= DesdeBaja)) and
                   DentroDeEdadAl(EmpRel, InicioMesEdad)
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
    end;

    /// <summary>
    /// Deducción por cargas de familia de UN mes del año, calculada con los familiares tal como estaban a ese mes.
    /// </summary>
    local procedure DeduccionFamiliarDelMes(Mes: Integer): Decimal
    var
        ParamVig: Record "Parámetro Vigente";
        TipoFraccion: Dictionary of [Code[20], Decimal];
        CodTipo: Code[20];
        DesdeMes: Date;
        HastaMes: Date;
        Total: Decimal;
    begin
        DesdeMes := DMY2Date(1, Mes, Date2DMY(FFechaRef, 3));
        HastaMes := CalcDate('<CM>', DesdeMes);

        FraccionesFamiliares(HastaMes, DesdeMes, DesdeMes, TipoFraccion);
        foreach CodTipo in TipoFraccion.Keys() do begin
            ParamVig.Reset();
            ParamVig.SetRange("Cód. Parámetro Base", CodTipo);
            ParamVig.SetRange("Cód. Parámetro", CodTipo);
            ParamVig.SetFilter("Vigencia Desde", '<=%1', HastaMes);
            if ParamVig.FindLast() then
                Total += ParamVig.Valor * TipoFraccion.Get(CodTipo);
        end;
        exit(Total);
    end;

    /// <summary>Gastos deducibles declarados vigentes a una fecha (Parte 2 de CalcDeduccionesGanancias), sin detalle.</summary>
    local procedure GastosDeclaradosVigentes(FechaRef: Date): Decimal
    var
        EmpDed: Record "Ded. Ganancias Empleado";
        Total: Decimal;
    begin
        EmpDed.SetRange("No. Empleado", FEmployeeNo);
        EmpDed.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        if not EmpDed.FindLast() then
            exit(0);
        EmpDed.SetRange("Vigencia Desde", EmpDed."Vigencia Desde");
        EmpDed.SetFilter("Importe Fijo", '>%1', 0);
        if EmpDed.FindSet() then
            repeat
                Total += EmpDed."Importe Fijo";
            until EmpDed.Next() = 0;
        exit(Total);
    end;

    /// <summary>
    /// Deducciones de Ganancias del año a la fecha: cargas de familia mes por mes más los gastos declarados por los meses transcurridos.
    /// </summary>
    /// <remarks>
    /// POR QUÉ NO DEDUC_GANANCIAS × MES_ANUAL. Esa cuenta supone que la deducción del mes en curso valió lo mismo en todos
    /// los meses del año. Meta4 acumula mes por mes, y las dos cuentas se separan cuando la ficha de familia cambia dentro
    /// del año: un hijo que cumple 18 en enero o en febrero se deduce sólo hasta su mes de cumpleaños, un cónyuge con baja en
    /// marzo no deja de contar enero y febrero, un alta de abril cuenta desde abril. Con la multiplicación, BC le sacaba al
    /// hijo de 18 los meses que Meta4 le había deducido (00794, 04169 y 03664, marzo de 2026).
    ///
    /// Los gastos declarados (Parte 2) siguen la regla de siempre —los del mes en curso por cada mes transcurrido—: su vigencia
    /// y el reparto a partir de abril se decidieron aparte. Sólo cambia la familia.
    /// En LIQ_FINAL la fórmula no usa esta variable (computa la deducción anual completa).
    /// </remarks>
    local procedure CalcDeduccionesGananciasAcum(): Decimal
    var
        Mes: Integer;
        MesActual: Integer;
        Total: Decimal;
    begin
        if (FEmployeeNo = '') or (FFechaRef = 0D) then
            exit(0);
        MesActual := Date2DMY(FFechaRef, 2);
        // NO USA LAS FOTOS MENSUALES DE META4 (FAM_HIST_M4). Son el acumulado de Meta4 a ESE mes dividido por los meses: sirven
        // para reproducir una liquidación vieja, pero fijan el acumulado con la ficha de entonces y no ven una alta retroactiva
        // cargada después (04926 y 90447, marzo de 2026: Meta4 acumuló de golpe en marzo lo que la foto de febrero no tenía).
        // Calcular cada mes con la ficha actual da el mismo acumulado que Meta4 sin la foto (00794, 04169) y además recoge los
        // retroactivos.
        for Mes := 1 to MesActual do
            Total += DeduccionFamiliarDelMes(Mes);
        Total += GastosDeclaradosVigentes(FFechaRef) * MesActual;
        exit(Total);
    end;

    local procedure CalcAntiguedad(): Decimal
    var
        EstadoMgt: Codeunit "Gestión Estado Empleado";
        Periodo: Record "Período Liquidación";
        FechaAntiguedad: Date;
    begin
        // Fraccionaria (0.1) para AÑOS_ANTIGUEDAD — no la exacta de años completos que usan
        // los tramos legales de vacaciones (ver CalcAntiguedadAlFecha/CalcVacacionesAnuales).
        //
        // SE MIDE AL FIN DEL PERÍODO Y NO A LA FECHA DE REFERENCIA, para que el porcentaje de
        // antigüedad sea el mismo en todas las liquidaciones del mes. Un cierre de marea tiene como
        // referencia el arribo (el 22/3) y la devengada que le sigue el fin de mes: si el empleado
        // cumple el escalón entre las dos fechas, el cierre pagaba el escalón anterior y la
        // devengada el nuevo (04722: 2 % y 4 %; 04659: 4 % y 8 %), y Meta4 pagó el nuevo en las
        // tres corridas. Los convenios no fijan el momento (SOMU lo mide al 30/6, el CCT 175/75 no
        // lo especifica): se unificó al fin de mes por decisión del usuario.
        FechaAntiguedad := FFechaRef;
        if Periodo.Get(FCodPeriodo) then
            if Periodo."Fecha Hasta" > FechaAntiguedad then
                FechaAntiguedad := Periodo."Fecha Hasta";
        exit(EstadoMgt.CalcAntiguedadFraccionAlFecha(FEmployeeNo, FechaAntiguedad));
    end;

    // Parameterized version — used by AÑOS_ANTIGUEDAD (FFechaRef) and
    // VACACIONES_ANUALES (31/12 of the vacation year, per Art. 164 LCT).
    //
    // Seniority = sum of all employment periods (Alta → Baja) + Antigüedad Reconocida.
    // Intermediate states (Vacaciones, Enfermedad, Suspensión) are inside a period and

    /// <summary>
    /// ¿El familiar está dentro del tope de edad que fija su tipo de deducción?
    /// </summary>
    /// <remarks>
    /// "Se podrán declarar a cargo al cónyuge, conviviente, hijos e hijastros MENORES DE 18 AÑOS de
    /// edad, o INCAPACITADOS SIN LÍMITE DE EDAD". El tope lo trae el parámetro del tipo —HIJO lleva
    /// 18, HIJO_INC y CONYUGE no llevan ninguno— así que acá no hay ningún código de tipo escrito.
    ///
    /// EL MES DEL CUMPLEAÑOS CUENTA: el hijo que cumple 18 el 20 de marzo se deduce en marzo y deja
    /// de deducirse en abril. Es el mismo criterio binario que usa el resto de la función, que
    /// aplica la deducción anual completa cuando el familiar es válido y no la prorratea.
    ///
    /// SE MIDE CONTRA EL INICIO DEL PERÍODO, NO CONTRA EL DE LA COBERTURA, y por eso lee el período
    /// en vez de usar FPeriodoFechaDesde como hace el test de alta y baja unas líneas más arriba.
    /// La diferencia importa cuando alguien tiene dos liquidaciones en el mismo mes: un cierre de
    /// marea cubre del 3 al 29 y la regular de la nómina del 1 al 31, así que un hijo que cumple 18
    /// el 2 de enero quedaría deducido en una y no en la otra, y la retención oscilaría entre dos
    /// liquidaciones del mismo mes. Ganancias se liquida por mes: el mes es la unidad.
    ///
    /// SIN TOPE O SIN FECHA DE NACIMIENTO, DEDUCE. Las dos puertas abiertas son a propósito: con el
    /// tope en cero el cálculo queda como estaba —así esto se puede publicar sin cambiar un peso, y
    /// la baja se decide después cargando el 18—, y sin fecha de nacimiento no se le puede quitar
    /// una deducción a alguien por un dato que falta.
    /// </remarks>
    local procedure DentroDeEdad(EmpRel: Record "Employee Relative"): Boolean
    begin
        exit(DentroDeEdadAl(EmpRel, InicioMesEdadActual()));
    end;

    /// <summary>El inicio del período de esta liquidación: contra él se mide la edad tope de un familiar.</summary>
    local procedure InicioMesEdadActual(): Date
    var
        Periodo: Record "Período Liquidación";
    begin
        if Periodo.Get(FCodPeriodo) then
            exit(Periodo."Fecha Desde");
        exit(FPeriodoFechaDesde);   // sin período no queda otra referencia
    end;

    /// <summary>¿El familiar está dentro del tope de edad al inicio del mes dado? Ver DentroDeEdad.</summary>
    local procedure DentroDeEdadAl(EmpRel: Record "Employee Relative"; InicioMes: Date): Boolean
    var
        Param: Record "Parámetro";
        Nacimiento: Date;
        Corte: Date;
    begin
        if EmpRel."Cód. Tipo Ded." = '' then
            exit(true);
        if not Param.Get(EmpRel."Cód. Tipo Ded.") then
            exit(true);
        if Param."Edad Máxima Familiar" <= 0 then
            exit(true);

        Nacimiento := EmpRel."Birth Date";
        if Nacimiento = 0D then
            exit(true);

        // Cumple el tope el día que llega a esa edad; se deduce mientras ese día caiga dentro del
        // mes o después.
        Corte := CalcDate('<+' + Format(Param."Edad Máxima Familiar") + 'Y>', Nacimiento);
        exit(Corte >= InicioMes);
    end;

    local procedure FechaIngresoImpuesto(EmpRel: Record "Employee Relative"): Date
    var
        Fecha: Date;
    begin
        // Canónico: "Fecha alta impuesto" (50008), que es el FEC_ALTA_IMP de Meta4: la fecha en que
        // el familiar se declaró como carga A EFECTOS DE GANANCIAS.
        //
        // NO se leen "Fecha inicial" (50000) ni "Fecha alta familiar a cargo" (50010). Esas dos
        // existen para otra cosa —la vigencia de la fila y las asignaciones familiares— y están
        // cargadas para TODOS los familiares. Leerlas acá hacía que cualquier familiar en la ficha
        // dedujera Ganancias, aunque nunca se lo hubiera declarado: la "Fecha inicial" del cónyuge
        // del legajo 90016 es de 1991 y su alta de impuesto está vacía, y así BC le deducía
        // 404.330,39 que Meta4 no deduce. Con 1.852 cónyuges en la base y 46 sin alta de impuesto,
        // el error no se ve en un caso suelto: se ve en el total de retenciones.
        // Fuente única. "Fecha Ingreso Impuesto" (50211), que es nuestra, quedó ObsoleteState =
        // Pending y está vacía en las 8.315 filas: no hay página que la cargue, así que leerla como
        // respaldo no puede aportar nada y sólo sostiene la duplicación.
        exit(LeerFechaLegacyEmpRel(EmpRel, 50008));
    end;

    local procedure FechaEgresoImpuesto(EmpRel: Record "Employee Relative"): Date
    var
        Fecha: Date;
    begin
        // Canónico: "Fecha baja impuesto" (50009), el FEC_BAJA_IMP de Meta4. Mismo criterio que la
        // de alta: no se leen "Fecha final" ni "Fecha baja familiar a cargo", que son la vigencia
        // de la fila y la baja de asignaciones familiares. Acá el efecto de confundirlas es el
        // inverso —dejar de deducir antes de tiempo— y es igual de silencioso.
        // Fuente única, por el mismo motivo que la de alta: "Fecha Egreso Impuesto" (50212) está
        // obsoleta y vacía.
        exit(LeerFechaLegacyEmpRel(EmpRel, 50009));
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

    /// <summary>Días calendario del período, de punta a punta: 31 en enero, 28 en febrero.</summary>
    /// <remarks>
    /// Existe para prorratear un valor mensual entre las liquidaciones que se reparten el mes. La
    /// alternativa que venía de las planillas de producción es un 30 fijo —`+H13/30*F13*$C$7` en
    /// `HF802 6 CLC producción.xlsx`—, puesto así para no tener que tocar la planilla mes a mes.
    /// Con el 30 fijo los tramos de un mes NO suman el mes: los 22 + 7 días de un oficial en enero
    /// dan 29/30 del objetivo, y en febrero 29/30 de algo que debería ser 29/28.
    ///
    /// Se mide sobre el PERÍODO y no sobre el mes del calendario porque el período es lo que el
    /// motor liquida; hoy coinciden, y si alguna vez un período dejara de ser un mes natural, esto
    /// sigue diciendo lo que hay que repartir.
    /// </remarks>
    local procedure CalcDiasMes(): Decimal
    var
        Periodo: Record "Período Liquidación";
    begin
        if not Periodo.Get(FCodPeriodo) then
            exit(0);
        if (Periodo."Fecha Desde" = 0D) or (Periodo."Fecha Hasta" = 0D) then
            exit(0);
        exit(Periodo."Fecha Hasta" - Periodo."Fecha Desde" + 1);
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
        // RECORRE EL PERÍODO PERO SÓLO CUENTA LO QUE ESTA LIQUIDACIÓN CUBRE. Antes contaba el mes
        // entero sin mirar siquiera la cobertura, así que un empleado con dos liquidaciones en el
        // mes cobraba los mismos feriados en las dos. Va día por día y no por diferencia de fechas
        // porque un feriado depende del calendario, no del largo del tramo.
        FechaActual := Periodo."Fecha Desde";
        while FechaActual <= Periodo."Fecha Hasta" do begin
            if DiaEnLaVentana(FechaActual) then begin
                EnsureCalendarioCache(CodCal, Date2DMY(FechaActual, 3));
                if EsFeriadoCached(FechaActual) then
                    Dias += 1;
            end;
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
        CodCal: Code[10];
        Dias: Integer;
        i: Integer;
    begin
        if FEmployeeNo = '' then exit(0);
        if not Periodo.Get(FCodPeriodo) then exit(0);
        CodCal := CalendarioDeFeriados(Periodo);
        if CodCal = '' then exit(0);

        EstadoEmp.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        EstadoEmp.SetRange("Tipo Entidad", EstadoEmp."Tipo Entidad"::Empleado);
        EstadoEmp.SetRange("No. Empleado", FEmployeeNo);
        // Un estado que EMPIEZA después de la fecha de referencia no puede tocar la ventana: los
        // tramos viven dentro del período y el período termina en esa fecha. Además de ahorrar
        // trabajo, es lo que sacaba del paso a los estados futuros —los 14 cierres que fallaban
        // tenían un GP abierto iniciado entre abril y junio mientras se liquidaba enero—.
        EstadoEmp.SetFilter("Fecha Inicio", '<=%1', FFechaRef);
        if not EstadoEmp.FindSet() then exit(0);
        repeat
            if CodEst.Get(EstadoEmp."Cód. Estado") then
                if CodEst."Devenga Francos" and not CodEst."Transcurre en Marea" then
                    // La ventana es la de la liquidación y no la del período: un cierre de marea no
                    // tiene por qué ver los días de guardia previos al embarque, que ya paga la
                    // regular de la nómina. Y se recorren los TRAMOS, para que dos liquidaciones del
                    // mismo mes no cuenten el mismo feriado.
                    if FTramosDesde.Count() = 0 then
                        Dias += FeriadosDelTramo(CodCal, EstadoEmp."Fecha Inicio", EstadoEmp.FechaFinEfectiva(),
                                                 VentanaDesde(), VentanaHasta())
                    else
                        for i := 1 to FTramosDesde.Count() do
                            Dias += FeriadosDelTramo(CodCal, EstadoEmp."Fecha Inicio", EstadoEmp.FechaFinEfectiva(),
                                                     FTramosDesde.Get(i), FTramosHasta.Get(i));
        until EstadoEmp.Next() = 0;
        exit(Dias);
    end;

    /// <summary>
    /// La ventana de esta liquidación cuando no hay tramos: su cobertura, y el período como último
    /// recurso.
    /// </summary>
    /// <remarks>
    /// El período entero NUNCA es la respuesta correcta para una liquidación que cubre parte del mes:
    /// le haría pagar feriados y días que corresponden a otra. Se usa sólo cuando la cabecera todavía
    /// no tiene cobertura calculada, que es el único caso en que no hay nada mejor.
    /// </remarks>
    local procedure VentanaDesde(): Date
    begin
        if FCoberturaDesde <> 0D then
            exit(FCoberturaDesde);
        exit(FPeriodoFechaDesde);
    end;

    local procedure VentanaHasta(): Date
    begin
        if FCoberturaHasta <> 0D then
            exit(FCoberturaHasta);
        exit(FFechaRef);
    end;

    /// <summary>
    /// Feriados del calendario en la intersección del estado con un tramo de la ventana.
    /// </summary>
    /// <remarks>
    /// ACÁ ESTABA EL ERROR "La fecha no es válida". Antes esto recorría el estado ENTERO día por día
    /// preguntando en cada uno si caía en la ventana. Un estado abierto no termina: FechaFinEfectiva
    /// devuelve 31/12/9999, así que el bucle iba a recorrer casi ocho mil años y, al llegar al tope,
    /// el `FechaActual += 1` se pasaba del máximo que admite un Date y reventaba el cálculo entero.
    /// Eran 14 cierres de marea de enero de 2026 —183 errores en el registro— que quedaban sin
    /// liquidar, y como BarrerVacias borra las cabeceras sin líneas, el único rastro era el registro.
    ///
    /// Recortar contra el tramo ANTES de recorrer arregla las dos cosas: no hay desborde posible
    /// porque el fin nunca supera la ventana, y el bucle pasa de millones de vueltas a los días del
    /// mes. El resultado no cambia: los días que se descartaban uno por uno son los mismos que ahora
    /// quedan fuera de la intersección.
    /// </remarks>
    local procedure FeriadosDelTramo(CodCal: Code[10]; EstDesde: Date; EstHasta: Date; TramoDesde: Date; TramoHasta: Date) Dias: Integer
    var
        FechaActual: Date;
    begin
        if EstDesde < TramoDesde then EstDesde := TramoDesde;
        if EstHasta > TramoHasta then EstHasta := TramoHasta;
        if EstHasta < EstDesde then exit(0);

        FechaActual := EstDesde;
        while FechaActual <= EstHasta do begin
            EnsureCalendarioCache(CodCal, Date2DMY(FechaActual, 3));
            if EsFeriadoCached(FechaActual) then
                Dias += 1;
            FechaActual += 1;
        end;
    end;

    local procedure CalcDiasFeriadosMarea(): Decimal
    var
        Periodo: Record "Período Liquidación";
        Job: Record Job;
        RangeStart: Date;
        RangeEnd: Date;
        CodCal: Code[10];
        Dias: Integer;
        i: Integer;
    begin
        if (FJobNo = '') or not Job.Get(FJobNo) or (Job."Starting Date" = 0D) then exit(0);
        if not Periodo.Get(FCodPeriodo) then exit(0);
        CodCal := CalendarioDeFeriados(Periodo);
        if CodCal = '' then exit(0);

        // La marea acota por sus propias fechas, y la LIQUIDACIÓN por las suyas. Antes el extremo
        // derecho era FFechaRef y el izquierdo el inicio del período: para un cierre de marea eso
        // coincide con el arribo y funciona, pero ignora los TRAMOS, que son los que evitan que dos
        // liquidaciones del mismo mes se cuenten el mismo feriado. Se recorre igual que la guardia.
        // LA VENTANA ES LA DEL TRIPULANTE, no la de la marea: el que se asigna antes del zarpe —la víspera,
        // en estado PS— estaba a bordo esos días, y DIAS_PUERTO y DIAS_PROYECTO ya los cuentan desde la alta de
        // su asignación (ver VentanaEmpleadoEnMarea). Con el inicio del proyecto el carnaval del 17/2 se perdía
        // para los 28 tripulantes de HF801 asignados ese día con zarpe el 20/2: Meta4 pagaba el feriado y BC no.
        // No duplica con DIAS_FERIADOS_GUARDIA: la víspera es PS, que transcurre en marea y la guardia excluye.
        VentanaEmpleadoEnMarea(Job, RangeStart, RangeEnd);
        if RangeStart = 0D then
            RangeStart := Job."Starting Date";
        if (RangeEnd = 0D) or (RangeEnd > FFechaRef) then
            RangeEnd := FFechaRef;
        if RangeEnd < RangeStart then exit(0);

        if FTramosDesde.Count() = 0 then
            exit(FeriadosDelTramo(CodCal, RangeStart, RangeEnd, VentanaDesde(), VentanaHasta()));

        for i := 1 to FTramosDesde.Count() do
            Dias += FeriadosDelTramo(CodCal, RangeStart, RangeEnd,
                                     FTramosDesde.Get(i), FTramosHasta.Get(i));
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

    /// <summary>
    /// La ventana del tripulante en un CIERRE, estirada hasta el último día que cubre la liquidación.
    /// </summary>
    /// <remarks>
    /// El fin del proyecto es la llegada, y una marea con dos días de puerto (A28/62: llegada 22/4, estado PL el 22 y el 23) cubre
    /// un día más. Con el tope en el fin del proyecto, ese segundo día de puerto —del tripulante, que sigue asignado hasta el 23— se
    /// trataba como "puerto personal fuera de la asignación" y se restaba de DIAS_MAREA (22 contra 23 de Meta4, que divide el
    /// feriado de los oficiales entre 23), y no entraba en los días de enrolamiento (23 contra 24: el 2003 salía un día de asegurado
    /// más bajo, porque A_CUENTA_MAREA ya descuenta el día de marzo). Sólo estira, sólo en el cierre, y nunca más allá de la baja
    /// de la asignación. NO se usa en navegación ni en el puerto que paga el 1083, que con el fin del proyecto ya dan lo de Meta4.
    /// </remarks>
    local procedure VentanaCierreHastaCobertura(Job: Record Job; var Desde: Date; var Hasta: Date)
    var
        PersProy: Record "Personal Proyecto";
        TipoLiq: Record "Tipo Liquidación";
        NuevoFin: Date;
    begin
        VentanaEmpleadoEnMarea(Job, Desde, Hasta);
        if (Hasta = 0D) or (FCoberturaHasta <= Hasta) then
            exit;
        if not TipoLiq.EsArribo(FTipoLiq) then
            exit;
        if not PersProy.Get(FEmployeeNo, FJobNo) then
            exit;
        NuevoFin := FCoberturaHasta;
        if (PersProy."Fecha Baja" <> 0D) and (PersProy."Fecha Baja" < NuevoFin) then
            NuevoFin := PersProy."Fecha Baja";
        if NuevoFin > Hasta then
            Hasta := NuevoFin;
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

        if RangeEnd < RangeStart then begin
            if FFechaHastaPuerto > FFechaRef then
                exit(DiasPuertoDeclaradosFueraDeLaAsignacion(VentDesde, VentHasta));
            exit(0);
        end;

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

        // LOS DÍAS DE PUERTO QUE DECLARA EL ESTADO Y LA ASIGNACIÓN NO CUBRE.
        //
        // La marea son los días del BUQUE —de la zarpada al arribo— y la asignación del tripulante
        // es su parte de esa marea. Pero alguien puede embarcar antes para hacer trabajos de puerto
        // sobre esa misma marea: son días suyos, se pagan como puerto, y NO estiran la marea ni
        // entran en el prorrateo del neto acordado. El caso que lo destapó: un primer oficial que
        // subió el 2/1 con el buque zarpando el 3/1.
        //
        // Hasta acá esos días sólo existían si la asignación arrancaba antes que la zarpada, y
        // entonces los tomaba la regla de víspera de más arriba. Pero poner la asignación en la
        // zarpada es lo CORRECTO —22 días de marea, que es lo que cobra el acuerdo— y hacía
        // desaparecer el día de puerto: quedaba dentro de la cobertura y no lo pagaba nadie.
        //
        // Se suman por separado para no contarlos dos veces: sólo los que caen FUERA de la ventana
        // de la asignación, que es justo donde la regla de víspera no llega.
        Dias += DiasPuertoDeclaradosFueraDeLaAsignacion(VentDesde, VentHasta);

        // Y los de después del arribo mientras la asignación siga abierta: el espejo de los de víspera.
        Dias += DiasPuertoPosterioresEnLaAsignacion();

        exit(Dias);
    end;

    /// <summary>Duración del proyecto en horas: de la zarpada (fecha y hora) al arribo (fecha y hora de ingreso a puerto).</summary>
    /// <remarks>
    /// Existe para el pilotaje, que se liquida aparte como una marea y se paga por tramo de duración
    /// (CCT SOMU art. 43 y de oficiales art. 29: 5, 10, 15 o 30 días según sean hasta 120, 240, 360 o
    /// 720 horas). Una hora en blanco cuenta como 00:00. Sin zarpe o sin arribo, o con el arribo antes
    /// del zarpe, da 0: no inventa una duración.
    /// </remarks>
    local procedure CalcHorasProyecto(): Decimal
    var
        Job: Record Job;
        HoraZarpe: Time;
        HoraArribo: Time;
        Inicio: DateTime;
        Fin: DateTime;
    begin
        if (FJobNo = '') or not Job.Get(FJobNo) then
            exit(0);
        if (Job."Starting Date" = 0D) or (Job."Ending Date" = 0D) then
            exit(0);
        HoraZarpe := Job."Hora de zarpada";
        if HoraZarpe = 0T then
            HoraZarpe := 000000T;
        HoraArribo := Job."Hora ingreso a puerto";
        if HoraArribo = 0T then
            HoraArribo := 000000T;
        Inicio := CreateDateTime(Job."Starting Date", HoraZarpe);
        Fin := CreateDateTime(Job."Ending Date", HoraArribo);
        if Fin <= Inicio then
            exit(0);
        exit(Round((Fin - Inicio) / 3600000, 0.01));
    end;

    /// <summary>Días de puerto POSTERIORES al arribo que cubre la asignación del tripulante.</summary>
    /// <remarks>
    /// EL DÍA EXTRA DE PUERTO DEL FINAL FUNCIONA IGUAL QUE EL DEL INICIO (decisión del usuario,
    /// 21/10/2026): se suma si el empleado está asignado a la marea ese día. Al inicio lo hace la
    /// regla de víspera de CalcDiasPuertoMarea, que cuenta desde el alta de la asignación hasta el día
    /// anterior al zarpe; acá es el reflejo: desde el día siguiente al arribo hasta la baja de la
    /// asignación. Medido en abril de 2026 contra Meta4 en 40 tripulantes con la baja un día después
    /// del arribo (su estado PI empieza ese día): Meta4 paga ese día de puerto en la corrida de
    /// pilotaje y BC no tiene esa corrida, así que lo suma el cierre de marea.
    ///
    /// SOLO LO QUE EL PUERTO ACTUAL NO CUENTA. La extensión de FFechaHastaPuerto (puerto personal
    /// declarado por estado, hasta la cobertura del cierre) ya paga los días hasta ahí; esto arranca
    /// después de ese límite o del arribo, el mayor, para que ningún día se pague dos veces. Se acota
    /// al fin del período, igual que aquélla: una marea que cruza de mes no cobra el mismo día en dos.
    ///
    /// SOLO PARA TIPOS CON DISPARADOR ARRIBO y cuando la liquidación llega al arribo (FFechaRef):
    /// la regular de la nómina no tiene proyecto de marea. No cambia el viaje: CalcDiasPuertoDelViaje
    /// los resta, como a los declarados, y DIAS_MAREA queda en los días del buque.
    /// Una baja en blanco (asignación abierta) o anterior o igual al arribo no suma nada.
    /// </remarks>
    local procedure DiasPuertoPosterioresEnLaAsignacion(): Integer
    var
        Job: Record Job;
        PersProy: Record "Personal Proyecto";
        Tipo: Record "Tipo Liquidación";
        Periodo: Record "Período Liquidación";
        Desde: Date;
        Hasta: Date;
    begin
        if (FEmployeeNo = '') or (FJobNo = '') or not Job.Get(FJobNo) or (Job."Ending Date" = 0D) then
            exit(0);
        if not Tipo.EsArribo(FTipoLiq) then
            exit(0);
        if FFechaRef < Job."Ending Date" then
            exit(0);
        if not PersProy.Get(FEmployeeNo, FJobNo) then
            exit(0);
        if PersProy."Fecha Baja" <= Job."Ending Date" then
            exit(0);

        Desde := Job."Ending Date";
        if FFechaHastaPuerto > Desde then
            Desde := FFechaHastaPuerto;
        Desde += 1;

        // Sin período no hay dónde acotar: igual que ConfigurarLimitePuerto, no se extiende nada.
        if not Periodo.Get(FCodPeriodo) then
            exit(0);
        Hasta := PersProy."Fecha Baja";
        if Hasta > Periodo."Fecha Hasta" then
            Hasta := Periodo."Fecha Hasta";

        if Hasta < Desde then
            exit(0);
        exit(Hasta - Desde + 1);
    end;

    /// <summary>Los días de puerto que son parte del VIAJE: sin los que el tripulante hizo fuera de su asignación.</summary>
    /// <remarks>
    /// `DIAS_PUERTO` —lo que cobra el 1083— incluye el día del que sube antes a trabajar en puerto.
    /// `DIAS_MAREA` no, porque la marea son los días del buque y ese día es del tripulante: el
    /// acuerdo se prorratea sobre el viaje, no sobre su presencia.
    ///
    /// Se escribe como una resta sobre el total y no como un segundo recorrido a propósito: así las
    /// dos variables no pueden desincronizarse si mañana cambia una regla de borde.
    /// </remarks>
    local procedure CalcDiasPuertoDelViaje(): Decimal
    var
        Job: Record Job;
        VentDesde: Date;
        VentHasta: Date;
    begin
        if (FJobNo = '') or not Job.Get(FJobNo) or (Job."Starting Date" = 0D) then
            exit(0);
        VentanaCierreHastaCobertura(Job, VentDesde, VentHasta);
        exit(CalcDiasPuertoMarea() - DiasPuertoDeclaradosFueraDeLaAsignacion(VentDesde, VentHasta) - DiasPuertoPosterioresEnLaAsignacion());
    end;

    /// <summary>Días de puerto de esta marea que el estado declara y la asignación no cubre.</summary>
    /// <remarks>
    /// Son los que la regla de víspera no ve porque la asignación empieza en la zarpada. Se acotan a
    /// la cobertura de puerto de ESTA liquidación, para que una marea a
    /// caballo de dos meses no cobre el mismo día en los dos.
    ///
    /// NO HACE FALTA DISTINGUIR NAVEGACIÓN DE PUERTO, y conviene no intentarlo. Un día de estado de
    /// marea que cae FUERA de la ventana de la asignación es, por definición, un día a bordo que no
    /// es parte del viaje que le toca: eso es un día de puerto, sea cual sea el código del estado.
    ///
    /// El primer intento sí distinguía, tomando como "navegación" el `Estado Liq. Personal Predet.`
    /// del proyecto. No funciona: ese campo está cargado en **11 de 3.975** proyectos de marea, así
    /// que la función salía por la guarda y no contaba nada. Y en `Cód. Estado Empleado` no hay
    /// ninguna bandera que separe `NV` de `PS`/`PL` —`Transcurre en Marea` los marca a los tres—,
    /// así que distinguirlos pedía un campo nuevo. Medido: no cambia ni un resultado.
    ///
    /// Medido antes de escribirlo: sobre las 180 liquidaciones de marea calculadas, 179 dan
    /// exactamente los mismos días que hoy y la única que cambia es la que había perdido su día de
    /// puerto. No inventa días en ningún otro lado.
    /// </remarks>
    local procedure DiasPuertoDeclaradosFueraDeLaAsignacion(VentDesde: Date; VentHasta: Date): Integer
    var
        Estado: Record "Estado Empleado";
        CodEst: Record "Cód. Estado Empleado";
        Desde: Date;
        Hasta: Date;
        Dias: Integer;
    begin
        if (FEmployeeNo = '') or (FJobNo = '') then
            exit(0);

        Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
        Estado.SetRange("No. Empleado", FEmployeeNo);
        Estado.SetRange("No. Proyecto", FJobNo);
        if not Estado.FindSet() then
            exit(0);

        repeat
            // El Get va en su propio if y no pegado al and: AL evalúa los dos lados, así que un
            // código de estado que no exista haría fallar la lectura de la bandera igual.
            if CodEst.Get(Estado."Cód. Estado") then
                if CodEst."Transcurre en Marea" then begin
                    Desde := Estado."Fecha Inicio";
                    Hasta := Estado."Fecha Fin";
                    if Hasta = 0D then
                        Hasta := FFechaHastaPuerto;

                    // Sólo el puerto personal puede alcanzar la cobertura posterior al arribo.
                    // FFechaRef sigue siendo la fecha de valoración; el viaje no se extiende.
                    if Desde < FPeriodoFechaDesde then Desde := FPeriodoFechaDesde;
                    if Hasta > FFechaHastaPuerto then Hasta := FFechaHastaPuerto;

                    // Y recortado contra la ventana de la asignación, que ya la cuentan las reglas
                    // de arriba. Sólo sobrevive lo que queda ANTES del alta o DESPUÉS de la baja.
                    if Hasta >= Desde then
                        if (VentDesde > 0D) and (Desde < VentDesde) then begin
                            if Hasta >= VentDesde then
                                Dias += DiasPuertoFueraEnCobertura(Desde, VentDesde - 1)
                            else
                                Dias += DiasPuertoFueraEnCobertura(Desde, Hasta);
                        end else
                            if (VentHasta > 0D) and (Hasta > VentHasta) then begin
                                if Desde <= VentHasta then
                                    Dias += DiasPuertoFueraEnCobertura(VentHasta + 1, Hasta)
                                else
                                    Dias += DiasPuertoFueraEnCobertura(Desde, Hasta);
                            end;
                end;
        until Estado.Next() = 0;

        exit(Dias);
    end;

    local procedure DiasPuertoFueraEnCobertura(Desde: Date; Hasta: Date) Dias: Integer
    var
        HastaLegado: Date;
        Dia: Date;
    begin
        if Hasta < Desde then
            exit(0);

        // Conserva exactamente el conteo anterior hasta la fecha de valoración.
        // Sólo la extensión nueva debe pertenecer a los tramos de esta liquidación.
        HastaLegado := Hasta;
        if HastaLegado > FFechaRef then
            HastaLegado := FFechaRef;
        if HastaLegado >= Desde then
            Dias := HastaLegado - Desde + 1;

        Dia := Desde;
        if Dia <= FFechaRef then
            Dia := FFechaRef + 1;
        if FTramosDesde.Count() = 0 then begin
            if Hasta >= Dia then
                Dias += Hasta - Dia + 1;
            exit(Dias);
        end;
        while Dia <= Hasta do begin
            if DiaEnLaVentana(Dia) then
                Dias += 1;
            Dia += 1;
        end;
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
        VentanaCierreHastaCobertura(Job, WinStart, WinEnd);
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
                // Por los TRAMOS de la liquidación, no por su desde-hasta: una Regular que cubre "del 1
                // al 4 y del 26 al 31" no tiene que contar los días del medio, que son de otra.
                Total += DiasEnLaVentana(EstadoEmp."Fecha Inicio", EstadoEmp.FechaFinEfectiva());
            end;
        until EstadoEmp.Next() = 0;
        exit(Total + DiasFrancoNovedad());
    end;

    /// <summary>
    /// Días de franco cargados a mano como novedad DIAS_FRANCO, que se suman a los de los estados.
    /// </summary>
    /// <remarks>
    /// POR QUÉ EXISTE. En Meta4 los días de franco que se pagan son una incidencia (la 1061), y casi siempre
    /// coinciden con los estados Francos. No coinciden cuando alguien concede días que el historial no tiene:
    /// 04047, baja el 12/2 con un accidente hasta el 11/2 y ningún estado Francos, cobró 5 días de franco
    /// cargados a mano. Eso movía cinco conceptos —el 1063, el 2803/2804 al partir el saldo, la antigüedad del
    /// 1053 y el SAC de egreso del 3813— y por eso no es un detalle de clasificación.
    ///
    /// Se suma en DIAS_FRANCOS_PERIODO y no en cada fórmula, porque es la variable que leen el 1063, el 1053, el
    /// 1023 y el 2083: si sólo la leyera el consumo, la antigüedad y el resto seguirían sin ver esos días.
    ///
    /// La novedad nunca se materializa en una línea (NovedadAplica la saltea) y por eso queda Pendiente, igual
    /// que FECHA_TC. Si nombra tipo de liquidación o proyecto sólo vale para esa liquidación; en blanco, para
    /// todas las del empleado en el período. Las anuladas no cuentan.
    /// </remarks>
    local procedure DiasFrancoNovedad(): Decimal
    var
        Nov: Record "Novedad Liquidación";
        Dias: Decimal;
    begin
        if (FEmployeeNo = '') or (FCodPeriodo = '') then
            exit(0);
        Nov.SetCurrentKey("Cód. Período", "No. Empleado", "Cód. Concepto");
        Nov.SetRange("Cód. Período", FCodPeriodo);
        Nov.SetRange("No. Empleado", FEmployeeNo);
        Nov.SetRange("Cód. Concepto", 'DIAS_FRANCO');
        Nov.SetFilter(Estado, '<>%1', Nov.Estado::Anulada);
        if Nov.FindSet() then
            repeat
                if ((Nov."Cód. Tipo Liq." = '') or (Nov."Cód. Tipo Liq." = FTipoLiq)) and
                   ((Nov."No. Proyecto" = '') or (Nov."No. Proyecto" = FJobNo))
                then
                    Dias += Nov.Cantidad;
            until Nov.Next() = 0;
        exit(Dias);
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

                // Por los TRAMOS y no por el desde-hasta de la cabecera: si las vacaciones están
                // repartidas entre dos liquidaciones, cada una cuenta las suyas.
                Total += DiasEnLaVentana(EstadoEmp."Fecha Inicio", FechaFinEfectiva);
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
                Clear(Atributo);
                CodEntidad := EntidadDeLaLiquidacion(TipoAtr."Tipo Entidad");
                if (CodEntidad <> '') and AtributoVigente(TipoAtr.Código, TipoAtr."Tipo Entidad", CodEntidad, Atributo) then begin
                    Valor := Atributo."Valor Numérico";
                    GuardarValorTexto(TipoAtr."Nombre Variable", Atributo.ValorParaMostrar());
                end;
                Ctx.Add(TipoAtr."Nombre Variable", Valor);
                if TipoAtr.UsaLista() then
                    FCodigosAtributos.Set(TipoAtr."Nombre Variable", Atributo."Cód. Valor");
                SetTipo(TipoAtr."Nombre Variable", 'Atributo');
            end;
            PublicarAtributoUltimaMarea(TipoAtr, Ctx);
        until TipoAtr.Next() = 0;
    end;

    /// <summary>
    /// A qué entidad concreta de ESTA liquidación se le pregunta un atributo de ese tipo.
    /// </summary>
    /// <remarks>
    /// El buque no está en la liquidación: sale del proyecto, cuya dimensión global 1 es el buque
    /// (ver "Gestión Entidades Liq.", donde el código de la entidad ES el del valor de dimensión).
    /// </remarks>
    /// <summary>
    /// Publica "&lt;variable&gt;_ULT_MAREA" con el mismo atributo resuelto contra el buque de la
    /// última marea, para los Tipos de Atributo que lo pidan.
    /// </summary>
    /// <remarks>
    /// AGREGA UNA VARIABLE, NO CAMBIA LA QUE YA HABÍA. El buque del proyecto que se liquida sigue
    /// siendo el correcto para el recibo, para los precios y para el coeficiente de pesquería: lo
    /// único que necesita mirar la última marea es la decisión entre sueldo a órdenes y Artículo 48.
    /// Reemplazar TIPOACTIVIDAD habría arrastrado COEF_PESQUERIA de 1 a 0,30 y el importe habría
    /// quedado mal por el otro lado.
    ///
    /// El sufijo sigue la convención de {VARIABLE}_ESFCY: un nombre derivado que el catálogo no
    /// declara pero las fórmulas pueden usar.
    ///
    /// Registra también el CÓDIGO en FCodigosAtributos cuando el atributo es de lista, que es lo
    /// que permite escribir TIPOACTIVIDAD_ULT_MAREA = 'TA' en vez de compararlo contra su proyección
    /// numérica. Importa: el numérico de 'TA' es CERO, indistinguible de "no resolvió" para alguien
    /// que nunca navegó.
    /// </remarks>
    local procedure PublicarAtributoUltimaMarea(TipoAtr: Record "Tipo Atributo Liq."; var Ctx: Dictionary of [Text, Decimal])
    var
        Atributo: Record "Atributo Entidad Liq.";
        NombreDerivado: Text;
        CodBuque: Code[20];
        Valor: Decimal;
    begin
        if not TipoAtr."Publicar Última Marea" then
            exit;
        if TipoAtr."Tipo Entidad" <> TipoAtr."Tipo Entidad"::Buque then
            exit;
        if TipoAtr."Nombre Variable" = '' then
            exit;

        NombreDerivado := TipoAtr."Nombre Variable" + '_ULT_MAREA';
        if Ctx.ContainsKey(NombreDerivado) then
            exit;

        CodBuque := BuqueDeLaUltimaMarea();
        if (CodBuque <> '') and AtributoVigente(TipoAtr.Código, TipoAtr."Tipo Entidad", CodBuque, Atributo) then begin
            Valor := Atributo."Valor Numérico";
            GuardarValorTexto(NombreDerivado, Atributo.ValorParaMostrar());
        end;

        Ctx.Add(NombreDerivado, Valor);
        if TipoAtr.UsaLista() then
            FCodigosAtributos.Set(NombreDerivado, Atributo."Cód. Valor");
        SetTipo(NombreDerivado, 'Atributo');
    end;

    /// <summary>
    /// El buque de la última marea en la que el empleado estuvo embarcado a la fecha de referencia.
    /// </summary>
    /// <remarks>
    /// QUÉ CUENTA COMO EMBARCADO NO SE DECIDE ACÁ: lo dice la bandera "Transcurre en Marea" de
    /// Cód. Estado Empleado, que hoy está en NV (Navegación), PL (Puerto Llegada) y PS (Puerto
    /// Salida). Los tres son "afectado a esa marea", incluidos los días de puerto de cada punta.
    /// Si mañana cambia el criterio se toca la bandera, no este código.
    ///
    /// Por eso no se puede expresar con una Fuente de Datos: la bandera vive en el maestro de
    /// códigos y no en Estado Empleado, así que filtrarla es un join, y una fuente lee una sola
    /// tabla. Poner 'NV|PL|PS' en una línea de filtro cablearía justo lo que la bandera configura.
    ///
    /// Se queda con el estado de inicio MÁS RECIENTE que ya haya empezado, aunque esté cerrado
    /// --cerrado es el caso normal acá-- y sin mirar hacia adelante, igual que AtributoVigente.
    /// Se recorre comparando en vez de confiar en el orden: la clave de Estado Empleado es
    /// "No. Mov." sola, o sea el orden de alta, que suele coincidir con el cronológico y no hay
    /// nada que lo garantice.
    ///
    /// Vacío cuando el empleado nunca estuvo embarcado --personal de tierra-- y también cuando el
    /// proyecto de esa marea no tiene dimensión 1. Vacío es correcto y además es seguro:
    /// TokenResolvedToEmpty hace que la fuente que lo use devuelva 0 en lugar de leer sin filtrar.
    /// </remarks>
    /// <summary>
    /// La fecha con la que se busca la cotización: la de una novedad FECHA_TC si la hay, y si no la de
    /// referencia de la liquidación.
    /// </summary>
    /// <remarks>
    /// POR QUÉ UNA NOVEDAD. El tipo de cambio de los sueldos en divisa de nómina no es el del último
    /// día del período sino el de la fecha en que se CORTÓ el proceso, que cambia cada mes y no se
    /// puede deducir (en 2026 fue 27/1, 26/2 y 27/3). Es un dato que alguien conoce y carga, así que
    /// vive donde se cargan los datos del mes, junto al resto de las novedades, y no en código.
    ///
    /// La novedad es del empleado y del período. Si nombra tipo de liquidación o proyecto, sólo vale
    /// para esa liquidación, igual que cualquier otra novedad; en blanco, vale para todas las del
    /// empleado en el período. Con varias gana la última cargada. Las anuladas no cuentan.
    ///
    /// Nunca se materializa en una línea: Gestión Novedades la saltea (NovedadAplica) y por eso queda
    /// Pendiente. Eso es lo esperado y no significa que no se haya usado.
    /// </remarks>
    procedure FechaTipoCambio(): Date
    var
        Nov: Record "Novedad Liquidación";
        TipoLiqTC: Record "Tipo Liquidación";
    begin
        if FFechaTCListo then
            exit(FFechaTC);
        FFechaTC := FFechaRef;
        // LA FINAL COTIZA AL EGRESO, no al fin del período: Meta4 usa la cotización del último día
        // trabajado. 04766 (baja el 7/2) cobra el franco de un oficial a 1.400 —la del 6/2— y BC lo
        // pagaba a 1.370, la del 27/2, que es lo que da FechaRef en una final de febrero. Cobertura Hasta
        // de una final es el egreso. La novedad FECHA_TC, si existe, sigue ganando.
        if (FTipoLiq = 'LIQ_FINAL') and (FCoberturaHasta <> 0D) and (FCoberturaHasta < FFechaRef) then
            FFechaTC := FCoberturaHasta;
        // EL CIERRE COTIZA AL ÚLTIMO DÍA QUE CUBRE. La fecha de liquidación de un cierre es el fin del PROYECTO, y la
        // llegada de una marea con dos días de puerto —PL el 22 y el 23— es el primero de los dos: A28/62 tiene fin 22/4 y
        // cubre hasta el 23/4. Meta4 y la planilla CLC cotizan al 23/4 (1.365) y BC cotizaba al 22/4 (1.350): el asegurado y la
        // producción de los oficiales salían 1,1 % más bajos. Sólo estira, nunca acorta, y la novedad FECHA_TC sigue ganando.
        if (FCoberturaHasta > FFechaRef) and TipoLiqTC.EsArribo(FTipoLiq) then
            FFechaTC := FCoberturaHasta;
        FFechaTCListo := true;
        if (FEmployeeNo = '') or (FCodPeriodo = '') then
            exit(FFechaTC);

        Nov.SetCurrentKey("Cód. Período", "No. Empleado", "Cód. Concepto");
        Nov.SetRange("Cód. Período", FCodPeriodo);
        Nov.SetRange("No. Empleado", FEmployeeNo);
        Nov.SetRange("Cód. Concepto", 'FECHA_TC');
        Nov.SetFilter(Estado, '<>%1', Nov.Estado::Anulada);
        if Nov.FindSet() then
            repeat
                if (Nov.Fecha <> 0D) and
                   ((Nov."Cód. Tipo Liq." = '') or (Nov."Cód. Tipo Liq." = FTipoLiq)) and
                   ((Nov."No. Proyecto" = '') or (Nov."No. Proyecto" = FJobNo))
                then
                    FFechaTC := Nov.Fecha;
            until Nov.Next() = 0;
        exit(FFechaTC);
    end;

    local procedure BuqueDeLaUltimaMarea(): Code[20]
    begin
        // UNA VEZ POR LIQUIDACIÓN. ApplyTokens la llamaba en cada filtro de cada fuente de datos, esté
        // o no el token en el texto, y recorre todo el historial de estados del empleado: 488 muestras
        // propias de 4.021 en un cálculo (12 %). El resultado sólo depende del empleado y de la fecha
        // de referencia, que Init fija.
        if not FBuqueUltMareaListo then begin
            FBuqueUltMarea := CalcularBuqueDeLaUltimaMarea();
            FBuqueUltMareaListo := true;
        end;
        exit(FBuqueUltMarea);
    end;

    local procedure CalcularBuqueDeLaUltimaMarea(): Code[20]
    var
        Estado: Record "Estado Empleado";
        CodEstado: Record "Cód. Estado Empleado";
        Job: Record Job;
        MejorInicio: Date;
        MejorProyecto: Code[20];
        Encontrado: Boolean;
    begin
        if FEmployeeNo = '' then
            exit('');

        Estado.SetRange("No. Empleado", FEmployeeNo);
        Estado.SetRange("Tipo Entidad", "Tipo Entidad Estado"::Empleado);
        Estado.SetFilter("Fecha Inicio", '<=%1', FFechaRef);
        if Estado.FindSet() then
            repeat
                if Estado."No. Proyecto" <> '' then
                    if CodEstado.Get(Estado."Cód. Estado") then
                        if CodEstado."Transcurre en Marea" then
                            if (not Encontrado) or (Estado."Fecha Inicio" >= MejorInicio) then begin
                                MejorInicio := Estado."Fecha Inicio";
                                MejorProyecto := Estado."No. Proyecto";
                                Encontrado := true;
                            end;
            until Estado.Next() = 0;

        if not Encontrado then
            exit('');
        if not Job.Get(MejorProyecto) then
            exit('');
        exit(Job."Global Dimension 1 Code");
    end;

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
        exit(Atributo.Vigente(CodTipoAtributo, TipoEntidad, CodEntidad,
            FechaReferenciaAtributos(TipoEntidad)));
    end;

    local procedure FechaReferenciaAtributos(TipoEntidad: Enum "Tipo Entidad Estado"): Date
    begin
        exit(FechaAtributosDeCobertura(FTipoLiq, TipoEntidad, FFechaRef, FCoberturaHasta));
    end;

    internal procedure FechaAtributosDeCobertura(TipoLiq: Code[20]; TipoEntidad: Enum "Tipo Entidad Estado"; FechaRef: Date; CoberturaHasta: Date): Date
    begin
        // Sólo el empleado egresado se resuelve al último día cubierto. La fecha de parámetros,
        // cotizaciones e historia permanece en FFechaRef; buque y proyecto mantienen su criterio.
        if (TipoEntidad = TipoEntidad::Empleado) and (TipoLiq = 'LIQ_FINAL') and
           (CoberturaHasta <> 0D) and (CoberturaHasta < FechaRef)
        then
            exit(CoberturaHasta);
        exit(FechaRef);
    end;

    /// <summary>Códigos vigentes de atributos de lista, independientes de su proyección numérica.</summary>
    procedure GetCodigosAtributos(var Destino: Dictionary of [Text, Text])
    begin
        Destino := FCodigosAtributos;
    end;

    /// <summary>Valores de presentación para auditar e imprimir, por nombre de variable.</summary>
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
        AplicarClaveFuente(Fuente, RecRef);

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
                if FilaElegibleNoNumerica(Fuente, RecRef, FechaInicio) then
                    if (not Encontrado) or
                       ((Fuente."Función Agregado" = Fuente."Función Agregado"::"FILA_MAS_ANTIGUA") and (FechaInicio <= MejorInicio)) or
                       ((Fuente."Función Agregado" <> Fuente."Función Agregado"::"FILA_MAS_ANTIGUA") and (FechaInicio >= MejorInicio))
                    then begin
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

    /// <summary>
    /// Fija la clave de recorrido declarada por la fuente, si declaró una.
    /// </summary>
    /// <remarks>
    /// EN AL SÓLO SE PUEDE ORDENAR POR UNA CLAVE DECLARADA EN LA TABLA: no hay forma de pedirle a
    /// la base que ordene por un campo cualquiera. Por eso la fuente declara el CAMPO y acá se
    /// busca una clave que lo contenga —prefiriendo aquella donde sea el ÚLTIMO campo, que es la
    /// que ordena por él dentro del grupo que los filtros ya acotaron—.
    ///
    /// El ejemplo es Estado Empleado: su clave K2 es (Tipo Entidad, No. Empleado, Fecha Inicio), y
    /// con los dos primeros fijados por los filtros, recorrerla ordena por Fecha Inicio. Su clave
    /// primaria, en cambio, es "No. Mov." sola —el orden de alta—, que suele coincidir con el
    /// cronológico y no hay nada que lo garantice.
    ///
    /// Sin clave utilizable AVISA y deja el orden como estaba. Seguir en silencio devolvería la
    /// fila equivocada con cara de buena, que es justo lo que este campo viene a evitar.
    /// </remarks>
    local procedure AplicarClaveFuente(Fuente: Record "Fuente Datos Liquidación"; var RecRef: RecordRef)
    var
        KeyR: KeyRef;
        CampoClave: Integer;
        i: Integer;
        j: Integer;
        Elegida: Integer;
        EsUltimo: Boolean;
    begin
        if Fuente."No. Campo Clave" = 0 then
            exit;

        CampoClave := CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Clave");
        // Se queda con la primera clave que contenga el campo, y la cambia si aparece otra donde el
        // campo sea el ÚLTIMO. Una vez encontrada ésa no se sigue mejorando: es la mejor posible.
        for i := 1 to RecRef.KeyCount() do begin
            KeyR := RecRef.KeyIndex(i);
            for j := 1 to KeyR.FieldCount() do
                if (not EsUltimo) and (KeyR.FieldIndex(j).Number() = CampoClave) then begin
                    EsUltimo := j = KeyR.FieldCount();
                    if (Elegida = 0) or EsUltimo then
                        Elegida := i;
                end;
        end;

        if Elegida = 0 then begin
            AgregarAdvertenciaParametro(StrSubstNo(MsgFuenteSinClaveUtil, Fuente."Nombre Variable", Fuente."No. Campo Clave"));
            exit;
        end;

        RecRef.CurrentKeyIndex(Elegida);
        RecRef.Ascending(not Fuente."Orden Descendente");
    end;

    /// <summary>
    /// Qué filas mira una fuente de texto o fecha: las vigentes, o también las ya cerradas.
    /// </summary>
    /// <remarks>
    /// Con FILA_MAS_RECIENTE o FILA_MAS_ANTIGUA alcanza con que la fila haya empezado; con
    /// cualquier otra función sigue valiendo la vigencia de siempre. Es la misma distinción que en
    /// ValorDeFilaPorFecha y tiene que quedar igual en los dos caminos: una fuente de texto y una
    /// numérica con la misma función no pueden elegir filas distintas.
    /// </remarks>
    local procedure FilaElegibleNoNumerica(Fuente: Record "Fuente Datos Liquidación"; var RecRef: RecordRef; FechaInicio: Date): Boolean
    begin
        if Fuente."Función Agregado" in
           [Fuente."Función Agregado"::"FILA_MAS_RECIENTE", Fuente."Función Agregado"::"FILA_MAS_ANTIGUA"]
        then
            exit((FechaInicio <> 0D) and (FechaInicio <= FFechaRef));
        exit(FilaVigenteAFechaRef(Fuente, RecRef, FechaInicio));
    end;

    /// <summary>
    /// La fila más reciente —o la más antigua— por el campo de fecha declarado, y su Campo Valor.
    /// </summary>
    /// <remarks>
    /// SE QUEDA CON FILAS YA CERRADAS, y ésa es toda la diferencia con la vigencia del resto del
    /// motor. Las demás lecturas preguntan "qué rige HOY"; éstas preguntan "cuál fue la última",
    /// que no es lo mismo y hasta ahora no se podía expresar. El caso que lo motivó: en qué marea
    /// estuvo embarcado por última vez un empleado que justamente YA NO lo está — si el estado
    /// siguiera abierto, la pregunta no haría falta.
    ///
    /// Lo que sí se respeta es que no hay red hacia adelante: una fila que empieza después de la
    /// fecha de referencia no cuenta, igual que en AtributoVigente. Adivinar hacia el futuro
    /// escondería una carga mal fechada.
    ///
    /// Sin campo de fecha declarado no hace nada y avisa, en vez de caer de vuelta en FindLast():
    /// elegir por clave primaria es exactamente el defecto que estas dos funciones vienen a evitar,
    /// y hacerlo en silencio sería peor que no resolver.
    /// </remarks>
    local procedure ValorDeFilaPorFecha(Fuente: Record "Fuente Datos Liquidación"; var RecRef: RecordRef): Decimal
    var
        FieldVar: FieldRef;
        FechaFila: Date;
        MejorFecha: Date;
        Mejor: Decimal;
        Encontrado: Boolean;
        MasReciente: Boolean;
    begin
        if Fuente."No. Campo Valor" = 0 then
            exit(0);
        if Fuente."No. Campo Fecha Inicio" = 0 then begin
            AgregarAdvertenciaParametro(StrSubstNo(MsgFuenteSinCampoFecha, Fuente."Nombre Variable"));
            exit(0);
        end;

        MasReciente := Fuente."Función Agregado" = Fuente."Función Agregado"::"FILA_MAS_RECIENTE";
        if RecRef.FindSet() then
            repeat
                FechaFila := FieldRefToDate(RecRef.Field(CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Fecha Inicio")));
                if (FechaFila <> 0D) and (FechaFila <= FFechaRef) then
                    if (not Encontrado) or
                       (MasReciente and (FechaFila >= MejorFecha)) or
                       ((not MasReciente) and (FechaFila <= MejorFecha))
                    then begin
                        MejorFecha := FechaFila;
                        Encontrado := true;
                        FieldVar := RecRef.Field(CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Valor"));
                        Mejor := FieldRefToDecimal(FieldVar);
                    end;
            until RecRef.Next() = 0;

        exit(Mejor);
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

    /// <summary>Precio CCT histórico por documento, ponderado por una cantidad guardada.</summary>
    /// <remarks>
    /// La fuente elige cabeceras previas del empleado/proyecto; el precio se resuelve con las
    /// dimensiones selladas y la fecha de CADA cabecera, sin precio personal. El TC y la cantidad
    /// salen de su resumen guardado. No se reconstruye ni se modifica el contexto actual.
    /// </remarks>
    procedure AcumularParametroCCT(NombreFuente: Code[30]; CodigoParametro: Code[20]; NombreCantidad: Code[30]; Divisor: Decimal): Decimal
    var
        Fuente: Record "Fuente Datos Liquidación";
        Cabecera: Record "Liquidación";
        Cantidad: Record "Resumen Variable Liq.";
        VariablesGuardadas: Codeunit "Variables Guardadas Liq.";
        ParamVig: Record "Parámetro Vigente";
        RecRef: RecordRef;
        Precio: Decimal;
        Total: Decimal;
    begin
        ValidarAcumulacionParametroCCT(NombreFuente, CodigoParametro, NombreCantidad);
        if Divisor <= 0 then
            Error('ACUM_PARAM_CCT requiere un divisor positivo.');
        Fuente.Get(NombreFuente);
        RecRef.Open(Database::"Liquidación");
        if not AplicarFiltrosFuente(Fuente, RecRef, false) then begin
            RecRef.Close();
            exit(0);
        end;
        AplicarClaveFuente(Fuente, RecRef);
        if RecRef.FindSet() then
            repeat
                RecRef.SetTable(Cabecera);
                // La configuración selecciona; estas guardas impiden que un filtro incompleto
                // incluya otro empleado/proyecto, un borrador, el documento actual o el futuro.
                if (Cabecera."No. Empleado" <> FEmployeeNo) or (Cabecera."No. Proyecto" <> FJobNo) then
                    Error('La fuente %1 de ACUM_PARAM_CCT incluye la liquidación %2 fuera del empleado/proyecto actual.', NombreFuente, Cabecera."No.");
                if (Cabecera.Estado = Cabecera.Estado::Borrador) or (Cabecera."No." = FLiqNo) or
                   (Cabecera."Fecha Liquidación" = 0D) or (Cabecera."Fecha Liquidación" >= FFechaRef)
                then
                    Error('La fuente %1 de ACUM_PARAM_CCT incluye la liquidación %2 que no es un histórico calculado previo.', NombreFuente, Cabecera."No.");
                if not VariablesGuardadas.Obtener(Cabecera."No.", NombreCantidad, Cantidad) then
                    Error('Falta la variable histórica %1 en la liquidación %2.', NombreCantidad, Cabecera."No.");
                Precio := PrecioParametroCCTHistorico(CodigoParametro, Cabecera, ParamVig);
                if not FParametrosCCTHistoricos.Get(ParamVig."Cód. Parámetro Base", ParamVig."Cód. Parámetro", ParamVig."Vigencia Desde") then begin
                    FParametrosCCTHistoricos := ParamVig;
                    FParametrosCCTHistoricos.Insert(false);
                end;
                Total += Precio * Cantidad.Valor / Divisor;
            until RecRef.Next() = 0;
        RecRef.Close();
        exit(Total);
    end;

    /// <summary>Valida los nombres/configuración aun cuando se ensaya una fórmula sin valores.</summary>
    procedure ValidarAcumulacionParametroCCT(NombreFuente: Code[30]; CodigoParametro: Code[20]; NombreCantidad: Code[30])
    var
        Fuente: Record "Fuente Datos Liquidación";
        Filtro: Record "Filtro Fuente Datos Liq.";
        Parametro: Record "Parámetro";
        Cabecera: Record "Liquidación";
        Variable: Record "Variable Sistema Liq.";
        ParamCantidad: Record "Parámetro";
        FuenteCantidad: Record "Fuente Datos Liquidación";
        AtributoCantidad: Record "Tipo Atributo Liq.";
        ScopeEmpleado: Boolean;
        ScopeProyecto: Boolean;
        CantidadConocida: Boolean;
    begin
        if (NombreFuente = '') or (CodigoParametro = '') or (NombreCantidad = '') then
            Error('ACUM_PARAM_CCT requiere nombres de fuente, parámetro y cantidad histórica.');
        if not Fuente.Get(NombreFuente) then
            Error('La fuente %1 de ACUM_PARAM_CCT no existe.', NombreFuente);
        if (not Fuente.Activo) or (Fuente."Id. Tabla" <> Database::"Liquidación") then
            Error('La fuente %1 de ACUM_PARAM_CCT debe estar activa y consultar cabeceras de Liquidación.', NombreFuente);
        Filtro.SetRange("Nombre Variable", NombreFuente);
        if Filtro.FindSet() then
            repeat
                if (Filtro."No. Campo" = Cabecera.FieldNo("No. Empleado")) and (Filtro."Filtro Valor".Trim().ToUpper() = '{EMP_NO}') then
                    ScopeEmpleado := true;
                if (Filtro."No. Campo" = Cabecera.FieldNo("No. Proyecto")) and (Filtro."Filtro Valor".Trim().ToUpper() = '{JOB_NO}') then
                    ScopeProyecto := true;
            until Filtro.Next() = 0;
        if not (ScopeEmpleado and ScopeProyecto) then
            Error('La fuente %1 de ACUM_PARAM_CCT debe filtrar empleado y proyecto con {EMP_NO} y {JOB_NO}.', NombreFuente);
        if not Parametro.Get(CodigoParametro) then
            Error('El parámetro %1 de ACUM_PARAM_CCT no existe.', CodigoParametro);
        if (Parametro."Cód. Tipo Atributo 1" <> '') or (Parametro."Cód. Tipo Atributo 2" <> '') or (Parametro."Cód. Tipo Atributo 3" <> '') then
            Error('El parámetro %1 de ACUM_PARAM_CCT debe usar claves base/convenio/categoría sin ejes de atributos.', CodigoParametro);
        CantidadConocida := Variable.Get(NombreCantidad) or FuenteCantidad.Get(NombreCantidad);
        if not CantidadConocida then begin
            ParamCantidad.SetRange("Nombre Variable", NombreCantidad);
            AtributoCantidad.SetRange("Nombre Variable", NombreCantidad);
            CantidadConocida := not ParamCantidad.IsEmpty() or not AtributoCantidad.IsEmpty();
        end;
        if not CantidadConocida then
            Error('La cantidad histórica %1 de ACUM_PARAM_CCT no es una variable configurada.', NombreCantidad);
    end;

    local procedure PrecioParametroCCTHistorico(CodigoParametro: Code[20]; Cabecera: Record "Liquidación"; var ParamVig: Record "Parámetro Vigente"): Decimal
    var
        Claves: Codeunit "Claves Parámetro Liq.";
        VariablesGuardadas: Codeunit "Variables Guardadas Liq.";
        TipoCambio: Record "Resumen Variable Liq.";
        CodigoEfectivo: Code[50];
        Precio: Decimal;
    begin
        if (Cabecera."Cód. Convenio" = '') or (Cabecera."Cód. Categoría" = '') then
            Error('La liquidación histórica %1 no tiene convenio/categoría sellados para ACUM_PARAM_CCT.', Cabecera."No.");
        // La cascada existente preserva la regla de vigencias/especificidad. El empleado vacío
        // es deliberado: un fijo personal no puede reemplazar una garantía normativa del CCT.
        CodigoEfectivo := Claves.ResolverEnTabla(CodigoParametro, '', Cabecera."Cód. Convenio", Cabecera."Cód. Categoría", Cabecera."Fecha Liquidación");
        ParamVig.Reset();
        ParamVig.SetCurrentKey("Cód. Parámetro", "Vigencia Desde");
        ParamVig.SetRange("Cód. Parámetro Base", CodigoParametro);
        ParamVig.SetRange("Cód. Parámetro", CodigoEfectivo);
        ParamVig.SetRange("No. Empleado", '');
        ParamVig.SetFilter("Vigencia Desde", '<=%1', Cabecera."Fecha Liquidación");
        if not ParamVig.FindLast() then
            Error('Falta una vigencia CCT del parámetro %1 para %2/%3 al %4 (liquidación %5).', CodigoParametro, Cabecera."Cód. Convenio", Cabecera."Cód. Categoría", Cabecera."Fecha Liquidación", Cabecera."No.");
        Precio := ParamVig.Valor;
        if ParamVig.Moneda = '' then
            exit(Precio);
        if (ParamVig."Cód. Variable TC" = '') or (StrLen(ParamVig."Cód. Variable TC") > MaxStrLen(TipoCambio."Nombre Variable")) then
            Error('El parámetro histórico %1 debe declarar una variable TC guardable en el resumen.', CodigoEfectivo);
        if not VariablesGuardadas.Obtener(Cabecera."No.", CopyStr(ParamVig."Cód. Variable TC", 1, MaxStrLen(TipoCambio."Nombre Variable")), TipoCambio) then
            Error('Falta el tipo de cambio histórico %1 en la liquidación %2.', ParamVig."Cód. Variable TC", Cabecera."No.");
        if TipoCambio.Valor <= 0 then
            Error('El tipo de cambio histórico %1 de la liquidación %2 debe ser positivo.', ParamVig."Cód. Variable TC", Cabecera."No.");
        exit(Precio * TipoCambio.Valor);
    end;

    internal procedure ResolveFuente(Fuente: Record "Fuente Datos Liquidación"): Decimal
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
        AplicarClaveFuente(Fuente, RecRef);
        AppendParamLog('FDS:' + Format(Fuente."Id. Tabla") + '/' + Fuente."Nombre Variable");

        case Fuente."Función Agregado" of
            Fuente."Función Agregado"::COUNT:
                Total := RecRef.Count();
            Fuente."Función Agregado"::SUM:
                begin
                    PrepararLecturaParcialSuma(Fuente, RecRef);
                    if (Fuente."No. Campo Valor" > 0) and RecRef.FindSet() then
                        repeat
                            FieldVar := RecRef.Field(Fuente."No. Campo Valor");
                            FieldVar := RecRef.Field(CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Valor"));
                            Total += FieldRefToDecimal(FieldVar);
                        until RecRef.Next() = 0;
                end;
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
            Fuente."Función Agregado"::"FILA_MAS_RECIENTE",
            Fuente."Función Agregado"::"FILA_MAS_ANTIGUA":
                Total := ValorDeFilaPorFecha(Fuente, RecRef);
            Fuente."Función Agregado"::"DIAS_OVERLAP",
            Fuente."Función Agregado"::"DIAS_OVERLAP_30":
                if (Fuente."No. Campo Fecha Inicio" > 0) and RecRef.FindSet() then
                    repeat
                        FechaInicioRef := RecRef.Field(CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Fecha Inicio"));
                        FechaInicio := FieldRefToDate(FechaInicioRef);
                        FechaFin := ResolverFechaFin(Fuente, RecRef, FechaInicio);
                        if FechaFin = 0D then
                            FechaFin := FFechaRef;
                        if Fuente."Función Agregado" = Fuente."Función Agregado"::"DIAS_OVERLAP_30" then
                            Total += DiasEnLaVentanaComercial(FechaInicio, FechaFin)
                        else
                            Total += DiasEnLaVentana(FechaInicio, FechaFin);
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

    local procedure PrepararLecturaParcialSuma(Fuente: Record "Fuente Datos Liquidación"; var RecRef: RecordRef)
    var
        CampoValor: Integer;
    begin
        CampoValor := CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Valor");
        if CampoValor <= 0 then
            exit;
        // Una definición inválida sin filas antes devolvía cero; no adelantar ese error.
        if not RecRef.FieldExist(CampoValor) then
            exit;
        // FlowFields/FlowFilters no admiten lectura parcial. Conservar su camino original,
        // sin calcularlos ni cambiar la conversión, los filtros, el orden o la traza FDS.
        if not RecRef.SetLoadFields(CampoValor) then
            RecRef.SetLoadFields();
    end;

    /// <summary>
    /// Cuántos días del intervalo caen dentro de lo que esta liquidación cubre.
    /// </summary>
    /// <remarks>
    /// CON TRAMOS CARGADOS suma contra cada uno; sin tramos, contra la ventana única de siempre. Esa
    /// bifurcación es lo que deja entrar la maquinaria sin cambiarle el resultado a ninguna
    /// liquidación hasta que la configuración del tipo diga otra cosa.
    ///
    /// Los tramos existen porque un desde/hasta no puede decir "del 1 al 4 y del 26 al 31", que es
    /// justo lo que le queda a la Regular cuando las vacaciones caen en el medio del mes. Sin eso,
    /// la Regular reclama los 31 días y vuelve a pagar lo que ya pagó la de Vacaciones.
    /// </remarks>
    local procedure DiasEnLaVentana(Desde: Date; Hasta: Date) Dias: Integer
    var
        i: Integer;
        OlapStart: Date;
        OlapEnd: Date;
    begin
        if FTramosDesde.Count() = 0 then begin
            OlapStart := Desde;
            if FPeriodoFechaDesde > OlapStart then OlapStart := FPeriodoFechaDesde;
            OlapEnd := Hasta;
            if FFechaRef < OlapEnd then OlapEnd := FFechaRef;
            if OlapEnd >= OlapStart then
                exit(OlapEnd - OlapStart + 1);
            exit(0);
        end;

        for i := 1 to FTramosDesde.Count() do begin
            OlapStart := Desde;
            if FTramosDesde.Get(i) > OlapStart then OlapStart := FTramosDesde.Get(i);
            OlapEnd := Hasta;
            if FTramosHasta.Get(i) < OlapEnd then OlapEnd := FTramosHasta.Get(i);
            if OlapEnd >= OlapStart then
                Dias += OlapEnd - OlapStart + 1;
        end;
    end;

    /// <summary>¿Este día lo cubre esta liquidación? Para los cálculos que van día por día.</summary>
    /// <remarks>
    /// Mismo criterio que DiasEnLaVentana, en la forma que necesitan los que tienen que mirar cada
    /// día por separado —los feriados, que no se pueden contar por diferencia de fechas porque
    /// dependen del calendario—.
    /// </remarks>
    local procedure DiaEnLaVentana(Dia: Date): Boolean
    var
        i: Integer;
    begin
        if FTramosDesde.Count() = 0 then
            exit((Dia >= FPeriodoFechaDesde) and (Dia <= FFechaRef));
        for i := 1 to FTramosDesde.Count() do
            if (Dia >= FTramosDesde.Get(i)) and (Dia <= FTramosHasta.Get(i)) then
                exit(true);
        exit(false);
    end;

    local procedure CargarTramos(LiqNo: Code[20])
    var
        Tramo: Record "Tramo Cobertura Liq.";
        Liq: Record "Liquidación";
    begin
        Clear(FTramosDesde);
        Clear(FTramosHasta);
        FCoberturaDesde := 0D;
        FCoberturaHasta := 0D;
        if LiqNo = '' then
            exit;
        // La cobertura de la cabecera es el respaldo de los tramos: al 1/10/2026, 560 de las 567
        // liquidaciones de enero tenían tramos y 7 no, y esas 7 caían al PERÍODO ENTERO. Para una
        // mensual que cubre el 1 y el 2 de enero eso significa contar los feriados de todo el mes.
        if Liq.Get(LiqNo) then begin
            FCoberturaDesde := Liq."Cobertura Desde";
            FCoberturaHasta := Liq."Cobertura Hasta";
        end;
        Tramo.SetRange("No. Liquidación", LiqNo);
        if not Tramo.FindSet() then
            exit;
        repeat
            FTramosDesde.Add(Tramo.Desde);
            FTramosHasta.Add(Tramo.Hasta);
        until Tramo.Next() = 0;
    end;

    // Igual que FechaFinEfectiva(): el fin guardado tiene prioridad; si está vacío se puede
    // derivar del siguiente inicio de la entidad. 0D significa abierto y se recorta a FechaRef.
    local procedure ResolverFechaFin(Fuente: Record "Fuente Datos Liquidación"; var RecRef: RecordRef; FechaInicioActual: Date): Date
    var
        FinGuardado: Date;
    begin
        if Fuente."No. Campo Fecha Fin" > 0 then
            FinGuardado := FieldRefToDate(RecRef.Field(CampoFuenteCanonico(Fuente."Id. Tabla", Fuente."No. Campo Fecha Fin")));
        if FinGuardado <> 0D then
            exit(FinGuardado);
        if Fuente."Fin Efectivo" then
            exit(CalcFinEfectivo(Fuente, FechaInicioActual));
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

        // LOS TRES PARES DE FECHAS NO SE CANONIZAN ENTRE SÍ. Acá había un mapeo que mandaba el par
        // del impuesto (50008/50009) y el de familiar a cargo (50010/50011) al par del vínculo
        // (50000/50001), con el comentario de que ése era "el canónico". Es exactamente el
        // aplanamiento contra el que advierten FechaIngresoImpuesto y FechaEgresoImpuesto unas
        // pantallas más arriba, y el que le dedujo 404.330,39 de más al 90016.
        //
        // Lo que rompía: FAM_ADIC_OS filtra por "Fecha alta familiar a cargo", el mapeo la convertía
        // en "Fecha inicial" —que está cargada en las 8.315 filas— y entonces contaba TODOS los
        // familiares. El 02792 sumaba sus 7 en vez de 0.
        //
        // Lo único que sí es un alias son nuestros dos campos obsoletos, y van al par del IMPUESTO,
        // que es de donde salieron: no al del vínculo.
        case FieldNo of
            50211:
                exit(50008);
            50212:
                exit(50009);
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
        PromDesde: Date;
        PromHasta: Date;
        SemDesde: Date;
        SemHasta: Date;
        AsigDesde: Date;
        AsigHasta: Date;
        MareaDesde: Date;
        MareaHasta: Date;
        AnclaAus: Date;
        AusHasta: Date;
        EnfDesde: Date;
        EnfHasta: Date;
    begin
        Value := Value.Replace('{EMP_NO}', FEmployeeNo);
        Value := Value.Replace('{JOB_NO}', FJobNo);
        // EL BUQUE DEL PROYECTO, que es la dimensión 1 del Job. Hace falta para las fuentes que
        // leen el historial de estados del BUQUE y no el del empleado --la veda, por ejemplo--, donde
        // la entidad filtrada no es el legajo. Sale del proyecto y no del empleado a propósito: el
        // buque al que corresponde la liquidación es el del proyecto que está liquidando, sea una
        // marea o el PN- de nómina de ese mismo buque.
        //
        // Sin proyecto queda VACÍO, y eso NO es un descuido: TokenResolvedToEmpty hace que la fuente
        // devuelva 0 en vez de leer sin filtrar. Una regular sin proyecto sumaría la veda de toda la
        // flota, que es la peor forma de fallar porque da un número grande y creíble.
        // Se resuelve con la MISMA función que usan los atributos de buque, no con una copia:
        // si algún día el buque deja de salir de la dimensión 1 del proyecto, cambia en un solo lugar.
        Value := Value.Replace('{BUQUE}', EntidadDeLaLiquidacion("Tipo Entidad Estado"::Buque));
        // EL BUQUE DE LA ÚLTIMA MAREA EN QUE ESTUVO EMBARCADO, que NO es {BUQUE}. La diferencia
        // sólo aparece cuando el empleado ya no está embarcado, que es justo cuando hace falta:
        // para decidir si cobra sueldo a órdenes o el Art. 48 párrafo 11 hay que saber si su última
        // marea fue en un potero o en un tangonero, y la liquidación corre contra el PN- de nómina.
        //
        // Los PN- son POR BUQUE --PN-116-NOMINA, PN-128-NOMINA--, así que {BUQUE} devuelve un buque
        // plausible y no vacío: el de la nómina a la que el empleado está asignado. En enero de 2026
        // eso coincidía con la última marea en 240 casos y difería en 18, cuatro de ellos cruzando
        // la serie 801/802 --los poteros--. No falla: miente.
        // Sólo si el token está: el reemplazo resolvía el buque aunque ningún filtro lo usara.
        if Value.Contains('{BUQUE_ULT_MAREA}') then
            Value := Value.Replace('{BUQUE_ULT_MAREA}', BuqueDeLaUltimaMarea());
        Value := Value.Replace('{PERIODO}', FCodPeriodo);
        Value := Value.Replace('{FECHA_REF}', Format(FFechaRef));
        // LA FECHA DEL TIPO DE CAMBIO, que por defecto es la de referencia pero se puede forzar con una
        // novedad FECHA_TC (ver FechaTipoCambio). Sólo la usan las Fuentes TC_COMPRADOR y TC_VENDEDOR.
        if Value.Contains('{FECHA_TC}') then
            Value := Value.Replace('{FECHA_TC}', Format(FechaTipoCambio()));
        // El inicio del período, para acotar una fuente por AMBAS puntas. Con {FECHA_REF} sola, un
        // filtro de fecha acota hacia adelante pero arrastra todo lo anterior: en una marea a caballo
        // de dos meses, el cierre de agosto vuelve a sumar la producción que el devengado de julio ya
        // pagó. Con "{PERIODO_DESDE}..{FECHA_REF}" cada liquidación toma sólo su tramo.
        Value := Value.Replace('{PERIODO_DESDE}', Format(FPeriodoFechaDesde));
        // El 1 de enero del año de la liquidación, para las cuentas corrientes que se reinician con
        // el año calendario. La primera es el artículo 19 del CCT 729/2015: el tope de días que el
        // armador paga después de la temporada de calamar sale de los días embarcados y "no es
        // acumulable por años", así que lo ya pagado se suma desde {AÑO_DESDE} y no desde siempre.
        // Con la función de agregado DURACION_AÑO alcanza para recortar intervalos, pero una suma
        // sobre Línea Liquidación necesita el filtro de fecha explícito.
        Value := Value.Replace('{AÑO_DESDE}', Format(DMY2Date(1, 1, Date2DMY(FFechaRef, 3))));
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
        // VIGENCIA DE UN ATRIBUTO, POR CÓDIGO: {ATRIB_DESDE:X} y {ATRIB_HASTA:X}.
        //
        // Son los dos únicos tokens con argumento. Los demás nombran algo fijo de la liquidación;
        // éstos necesitan saber DE CUÁL atributo, y ese dato no puede venir de la fórmula: las
        // fuentes se resuelven ANTES de que corra cualquier fórmula, porque son las que arman el
        // contexto que la fórmula lee. El filtro de la fuente es el lugar donde se lee, así que es
        // el lugar donde se nombra —y así no hace falta un campo de configuración que lo diga—.
        //
        // El caso que los motivó es el adicional por frío compartido: dos tripulantes se
        // intercambian el puesto a mitad de marea y cada uno cobra sobre los kilos de SUS días del
        // diario de a bordo. Ver [[adicional-frio-por-tramo-del-diario]].
        if Value.Contains(TokAtribDesde) or Value.Contains(TokAtribHasta) then
            Value := ResolverTokensAtributo(Value);
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
            VentanaPromedioVacaciones(PromDesde, PromHasta);
            Value := Value.Replace('{PROM_DESDE}', Format(PromDesde));
            Value := Value.Replace('{PROM_HASTA}', Format(PromHasta));
        end;
        // LA VENTANA DEL PROMEDIO DE AUSENCIA: los 6 o los 12 meses calendario anteriores a aquel
        // en que EMPEZÓ la licencia. Misma idea que {PROM_DESDE} de vacaciones y por el mismo
        // motivo —el promedio es el de cuando se enfermó, no el de cuando se liquida—, pero anclada
        // en el estado de ausencia y con dos largos, porque el convenio los parte: 12 meses para
        // 729/15 y 768/19, 6 para 175/75.
        //
        // El HASTA es común a los dos: el mes anterior al del inicio. Sólo cambia el DESDE.
        //
        // Sin estado de ausencia se cae a la fecha de referencia, igual que la de vacaciones: la
        // fuente sigue teniendo una ventana con sentido en vez de quedarse sin filtro.
        if Value.Contains('{AUS_PROM') then begin
            AnclaAus := FechaInicioAusencia();
            if AnclaAus = 0D then
                AnclaAus := FFechaRef;
            AusHasta := CalcDate('<-CM-1D>', AnclaAus);
            Value := Value.Replace('{AUS_PROM_HASTA}', Format(AusHasta));
            Value := Value.Replace('{AUS_PROM6_DESDE}', Format(CalcDate('<-CM>', CalcDate('<-5M>', AusHasta))));
            Value := Value.Replace('{AUS_PROM12_DESDE}', Format(CalcDate('<-CM>', CalcDate('<-11M>', AusHasta))));
        end;
        // Enfermedad tiene una ventana propia: sólo el vínculo de la licencia, sin arrastrar
        // fases anteriores. Los tokens AUS compartidos con ART conservan su comportamiento.
        if Value.Contains('{ENF_PROM') then begin
            VentanaPromedioEnfermedad(6, EnfDesde, EnfHasta);
            Value := Value.Replace('{ENF_PROM6_DESDE}', Format(EnfDesde));
            VentanaPromedioEnfermedad(12, EnfDesde, EnfHasta);
            Value := Value.Replace('{ENF_PROM12_DESDE}', Format(EnfDesde));
            Value := Value.Replace('{ENF_PROM_HASTA}', Format(EnfHasta));
        end;
        // El argumento identifica la MISMA variable que aporta el divisor. Así la fuente
        // y la fórmula comparten estado, ventana y parámetros, aun cuando se cambie la regla.
        Value := ReemplazarTokenPromedioLicencia(Value, '{PROM_LIC_DESDE:', true);
        Value := ReemplazarTokenPromedioLicencia(Value, '{PROM_LIC_HASTA:', false);
        exit(Value);
    end;

    local procedure ReemplazarTokenPromedioLicencia(Value: Text; Prefijo: Text; TomarDesde: Boolean): Text
    var
        Variable: Record "Variable Sistema Liq.";
        NombreVariable: Code[30];
        Desde: Date;
        Hasta: Date;
        Fecha: Date;
        Resto: Text;
        Pos: Integer;
        Fin: Integer;
    begin
        Pos := StrPos(Value, Prefijo);
        while Pos > 0 do begin
            Resto := CopyStr(Value, Pos + StrLen(Prefijo));
            Fin := StrPos(Resto, '}');
            if (Fin <= 1) or (Fin - 1 > MaxStrLen(NombreVariable)) then
                Error('El token de promedio de licencia %1 debe indicar una variable de sistema y terminar en }.', Prefijo);
            NombreVariable := CopyStr(Resto, 1, Fin - 1);
            if not Variable.Get(NombreVariable) then
                Error('La variable de sistema %1 del token de promedio de licencia no existe.', NombreVariable);
            if (not Variable.Activo) or (Variable."Cód. Cálculo" <> 'DIV_PROM_LIC') then
                Error('La variable %1 del token de promedio de licencia debe estar activa y usar DIV_PROM_LIC.', NombreVariable);
            VentanaPromedioLicencia(Variable, Desde, Hasta);
            if TomarDesde then
                Fecha := Desde
            else
                Fecha := Hasta;
            Value := CopyStr(Value, 1, Pos - 1) + Format(Fecha) + CopyStr(Resto, Fin + 1);
            Pos := StrPos(Value, Prefijo);
        end;
        exit(Value);
    end;

    /// <summary>
    /// El día en que arrancó la licencia de ausencia que esta liquidación está pagando. 0D si no hay.
    /// </summary>
    /// <remarks>
    /// Misma regla que FechaInicioVacaciones: la PRIMERA vigencia que llega hasta el período o más
    /// allá, recorriendo en orden de fecha. Una enfermedad que empezó el mes pasado y sigue corriendo
    /// es la misma licencia, y su promedio se mide desde donde empezó — no desde el mes que se está
    /// liquidando. Partirla en dos daría dos promedios distintos para una sola licencia.
    ///
    /// Los estados que cuentan los marca la bandera "Promedia Ausencia" del catálogo, no una lista
    /// de códigos acá: el enum "Tipo Estado" no distingue enfermedad de navegación —las dos son
    /// Normal— así que no hay de dónde deducirlo.
    /// </remarks>
    local procedure FechaInicioAusencia(): Date
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
                if CodEst."Promedia Ausencia" then
                    if EstadoEmp.FechaFinEfectiva() >= FPeriodoFechaDesde then
                        exit(EstadoEmp."Fecha Inicio");
        until EstadoEmp.Next() = 0;
        exit(0D);
    end;

    local procedure VentanaPromedioEnfermedad(Largo: Integer; var Desde: Date; var Hasta: Date): Decimal
    var
        Variable: Record "Variable Sistema Liq.";
        CodigoCalculo: Code[30];
        MesesConfigurados: Integer;
        UmbralDias: Integer;
        DiasMes: Decimal;
    begin
        // Compatibilidad con las fuentes históricas que nombran las ventanas 6/12. El estado
        // y la regla de proporcionalidad salen de configuración, igual que en la fuente nueva.
        if Largo >= 12 then begin
            Largo := 12;
            CodigoCalculo := 'DIV_PROM_ENF_12';
        end else begin
            Largo := 6;
            CodigoCalculo := 'DIV_PROM_ENF_6';
        end;
        Variable.SetRange("Cód. Cálculo", CodigoCalculo);
        Variable.SetRange(Activo, true);
        if Variable.Count() <> 1 then
            Error('La ventana histórica %1 requiere una única variable de sistema activa con ese código de cálculo.', CodigoCalculo);
        Variable.FindFirst();
        LeerConfiguracionPromedioLicencia(MesesConfigurados, UmbralDias, DiasMes);
        exit(ResolverVentanaLicencia(Variable."Cód. Estado", Largo, UmbralDias, DiasMes, Desde, Hasta));
    end;

    local procedure AltaVinculoLicencia(Ancla: Date): Date
    var
        Fase: Record "Fase Alta Empleado";
    begin
        Fase.SetCurrentKey("No. Empleado", "Fecha Alta");
        Fase.SetRange("No. Empleado", FEmployeeNo);
        Fase.SetFilter("Fecha Alta", '<=%1', Ancla);
        if Fase.FindLast() then
            if (Fase."Fecha Baja" = 0D) or (Fase."Fecha Baja" >= Ancla) then
                exit(Fase."Fecha Alta");
        exit(0D);
    end;

    local procedure ResolverVentanaLicencia(CodEstado: Code[20]; Meses: Integer; UmbralDias: Integer; DiasMes: Decimal; var Desde: Date; var Hasta: Date): Decimal
    var
        Ancla: Date;
    begin
        if CodEstado = '' then
            Error('Completá Cód. Estado en la variable de sistema del promedio de licencia.');
        Ancla := FechaInicioEstadoEnPeriodo(CodEstado);
        if Ancla = 0D then
            Ancla := FFechaRef;
        exit(ResolverPromedioLicencia(AltaVinculoLicencia(Ancla), Ancla, Meses, UmbralDias, DiasMes, Desde, Hasta));
    end;

    local procedure VentanaPromedioLicencia(Variable: Record "Variable Sistema Liq."; var Desde: Date; var Hasta: Date): Decimal
    var
        Meses: Integer;
        UmbralDias: Integer;
        DiasMes: Decimal;
    begin
        LeerConfiguracionPromedioLicencia(Meses, UmbralDias, DiasMes);
        exit(ResolverVentanaLicencia(Variable."Cód. Estado", Meses, UmbralDias, DiasMes, Desde, Hasta));
    end;

    local procedure LeerConfiguracionPromedioLicencia(var Meses: Integer; var UmbralDias: Integer; var DiasMes: Decimal)
    var
        Valor: Decimal;
    begin
        Valor := ParametroPromedioLicencia('PROM_LIC_MESES');
        if (Valor <= 0) or (Valor <> Round(Valor, 1)) then
            Error('PROM_LIC_MESES debe ser un número entero positivo.');
        Meses := Valor;
        Valor := ParametroPromedioLicencia('PROM_LIC_UMBRAL');
        if (Valor <= 0) or (Valor <> Round(Valor, 1)) then
            Error('PROM_LIC_UMBRAL debe ser un número entero positivo de días.');
        UmbralDias := Valor;
        DiasMes := ParametroPromedioLicencia('PROM_LIC_DIAS_MES');
        if DiasMes <= 0 then
            Error('PROM_LIC_DIAS_MES debe ser positivo.');
    end;

    local procedure ParametroPromedioLicencia(NombreVariable: Text): Decimal
    var
        Parametro: Record "Parámetro Vigente";
    begin
        // LoadParametros ya eligió la vigencia y la clave por empleado/convenio/categoría.
        // Leer esa selección evita una segunda cascada que pueda diferir de la fórmula.
        if not (FParamBaseMap.ContainsKey(NombreVariable) and FParamCodMap.ContainsKey(NombreVariable) and FParamVigMap.ContainsKey(NombreVariable)) then
            Error('Falta un valor vigente del parámetro %1 para esta liquidación.', NombreVariable);
        if not Parametro.Get(FParamBaseMap.Get(NombreVariable), FParamCodMap.Get(NombreVariable), FParamVigMap.Get(NombreVariable)) then
            Error('No se encuentra la vigencia seleccionada del parámetro %1.', NombreVariable);
        if Parametro.Moneda <> '' then
            Error('El parámetro %1 configura días o meses y debe cargarse sin moneda.', NombreVariable);
        AppendParamLog('VAR:' + NombreVariable);
        exit(Parametro.Valor);
    end;

    local procedure CalcDivisorPromedioEnfermedad(Largo: Integer): Decimal
    var
        Desde: Date;
        Hasta: Date;
    begin
        exit(VentanaPromedioEnfermedad(Largo, Desde, Hasta));
    end;

    local procedure CalcDivisorPromedioLicencia(Variable: Record "Variable Sistema Liq."): Decimal
    var
        Desde: Date;
        Hasta: Date;
    begin
        exit(VentanaPromedioLicencia(Variable, Desde, Hasta));
    end;

    /// <summary>Ventana y divisor del vínculo actual de una licencia; también permite analizarlo.</summary>
    /// <remarks>
    /// Meta4 mide días hasta el primer día del mes de inicio, no hasta el día exacto de enfermedad.
    /// La configuración indica ventana, umbral de días para el divisor completo y días por mes.
    /// La ventana y el divisor comparten el ancla, así una licencia continuada congela su precio.
    /// Sin vínculo previo se devuelve cero y una fecha centinela válida: nunca un filtro vacío.
    /// </remarks>
    procedure ResolverPromedioLicencia(AltaVinculo: Date; Ancla: Date; Meses: Integer; UmbralDias: Integer; DiasMes: Decimal; var Desde: Date; var Hasta: Date): Decimal
    var
        Corte: Date;
        Dias: Integer;
        i: Integer;
    begin
        if (Meses <= 0) or (UmbralDias <= 0) or (DiasMes <= 0) then
            Error('El promedio de licencia requiere meses, umbral de días y días por mes positivos.');
        Desde := DMY2Date(1, 1, 1900);
        Hasta := Desde;
        if (AltaVinculo = 0D) or (Ancla = 0D) then
            exit(0);
        Corte := CalcDate('<-CM>', Ancla);
        Dias := Corte - AltaVinculo;
        if Dias <= 0 then
            exit(0);
        Hasta := Corte - 1;
        Desde := Corte;
        for i := 1 to Meses do
            Desde := CalcDate('<-1M>', Desde);
        if AltaVinculo > Desde then
            Desde := AltaVinculo;
        if Dias >= UmbralDias then
            exit(Meses);
        exit(Dias / DiasMes);
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
    /// <summary>
    /// Cuántos de los meses de la ventana del promedio de ausencia tienen al empleado de alta.
    /// </summary>
    /// <remarks>
    /// Es el DIVISOR del promedio, y tiene que contar meses con alta y no los meses del período:
    /// un ingreso a mitad de la ventana divide por 12 lo que se ganó en 3 y da un promedio que no
    /// existe. La regla que dio el usuario para ese caso —"se promedian las remuneraciones desde el
    /// ingreso hasta el día de inicio de la baja"— sale sola de acá: el numerador ya viene acotado
    /// por la ventana de la fuente y el denominador queda en los meses que efectivamente trabajó.
    ///
    /// Misma mecánica que CalcMesesPromedioVacaciones, anclada en el inicio de la licencia en vez
    /// del inicio de las vacaciones, y con el largo como parámetro porque el convenio lo parte:
    /// 12 meses para 729/15 y 768/19, 6 para 175/75.
    /// </remarks>
    local procedure CalcMesesPromedioAusencia(Largo: Integer): Decimal
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

        Ancla := FechaInicioAusencia();
        if Ancla = 0D then
            Ancla := FFechaRef;
        Hasta := CalcDate('<-CM-1D>', Ancla);
        // Las dos fórmulas van literales y no armadas con StrSubstNo. Una fórmula de fecha
        // construida a partir de un número es exactamente el tipo de cosa que el compilador no
        // mira y que falla en runtime con un mensaje que no dice de dónde salió —"La fórmula de
        // fecha '0' debe contener una unidad de tiempo"—, sin nombrar tabla, campo ni concepto.
        // Son dos casos y valen dos líneas; ver también los literales de {AUS_PROM*_DESDE}.
        if Largo >= 12 then
            Desde := CalcDate('<-CM>', CalcDate('<-11M>', Hasta))
        else
            Desde := CalcDate('<-CM>', CalcDate('<-5M>', Hasta));

        // Sin fases cargadas no hay con qué decidir, y un 0 haría división por cero en la fórmula.
        Fase.SetRange("No. Empleado", FEmployeeNo);
        if Fase.IsEmpty() then
            exit(Largo);

        // Se avanza mes a mes con '<+1M>' en vez de saltar desde el origen con '<+%1M>'. Mismo
        // resultado y ninguna fórmula de fecha armada en runtime.
        MesDesde := Desde;
        for i := 1 to Largo do begin
            MesHasta := CalcDate('<CM>', MesDesde);
            Fase.Reset();
            Fase.SetRange("No. Empleado", FEmployeeNo);
            Fase.SetFilter("Fecha Alta", '<=%1', MesHasta);
            Fase.SetFilter("Fecha Baja", '%1|>=%2', 0D, MesDesde);
            if not Fase.IsEmpty() then
                Meses += 1;
            MesDesde := CalcDate('<+1M>', MesDesde);
        end;

        exit(Meses);
    end;

    /// <summary>
    /// Días calendario en un estado dado que caen dentro del período liquidado.
    /// </summary>
    /// <remarks>
    /// Genérica a propósito: DIAS_ENFERMEDAD y DIAS_ACCIDENTE son la misma cuenta sobre AU1 y ACC.
    /// Sin el tope de derecho que sí tiene DIAS_VAC_PERIODO —una enfermedad dura lo que dura—.
    ///
    /// Se recorta contra el período y no contra la cobertura: lo que se paga este mes son los días
    /// de baja de ESTE mes, y una licencia que cruza el cierre se paga partida en dos liquidaciones.
    /// </remarks>
    local procedure CalcDiasEstadoPeriodo(CodEstado: Code[20]): Decimal
    var
        EstadoEmp: Record "Estado Empleado";
        Total: Integer;
    begin
        if (FEmployeeNo = '') or (CodEstado = '') then
            exit(0);

        EstadoEmp.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        EstadoEmp.SetRange("Tipo Entidad", EstadoEmp."Tipo Entidad"::Empleado);
        EstadoEmp.SetRange("No. Empleado", FEmployeeNo);
        EstadoEmp.SetRange("Cód. Estado", CodEstado);
        EstadoEmp.SetFilter("Fecha Inicio", '<=%1', FFechaRef);
        if not EstadoEmp.FindSet() then
            exit(0);

        repeat
            // Por los TRAMOS de la liquidación. Es la variable que alimenta DIAS_ENFERMEDAD y
            // DIAS_ACCIDENTE, así que sin esto una enfermedad que cae dentro del tramo de otra
            // liquidación se cobraría en las dos.
            Total += DiasEnLaVentana(EstadoEmp."Fecha Inicio", EstadoEmp.FechaFinEfectiva());
        until EstadoEmp.Next() = 0;

        exit(Total);
    end;

    internal procedure DiasEnLaVentanaComercial(DesdeEstado: Date; HastaEstado: Date): Integer
    var
        Dia: Date;
        Total: Integer;
    begin
        Dia := VentanaDesde();
        while Dia <= FFechaRef do begin
            if (Dia >= DesdeEstado) and (Dia <= HastaEstado) then
                if DiasEnLaVentana(Dia, Dia) > 0 then
                    Total += PesoDiaComercial(Dia);
            Dia += 1;
        end;
        exit(Total);
    end;

    /// <summary>
    /// Días en ese estado ANTERIORES al período que se liquida, contados desde el inicio de la
    /// licencia en curso. 0 si la licencia empieza en este período.
    /// </summary>
    /// <remarks>
    /// Existe por el art. 13 de la LRT: los primeros 10 días de incapacidad los paga el empleador y
    /// del 11 en adelante paga la ART. El corte no es por período sino por licencia, así que para
    /// saber cuántos de los días de ESTE mes todavía le tocan al empleador hay que saber cuántos ya
    /// se pagaron antes. Verificado contra Meta4: en julio 2023 el legajo 03952 tiene 10 días por
    /// ACCIDENTE_NR y 1 por PRESTAC_ART_NR —empezó ese mes— y en enero 2024 hay licencias con 30
    /// días enteros de ART y cero de accidente, que son las que venían de meses anteriores.
    /// </remarks>
    local procedure CalcDiasEstadoPrevios(CodEstado: Code[20]): Decimal
    var
        EstadoEmp: Record "Estado Empleado";
        Inicio: Date;
        OlapStart: Date;
        OlapEnd: Date;
        Total: Integer;
    begin
        if (FEmployeeNo = '') or (CodEstado = '') then
            exit(0);

        Inicio := FechaInicioEstadoEnPeriodo(CodEstado);
        if (Inicio = 0D) or (Inicio >= FPeriodoFechaDesde) then
            exit(0);

        EstadoEmp.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        EstadoEmp.SetRange("Tipo Entidad", EstadoEmp."Tipo Entidad"::Empleado);
        EstadoEmp.SetRange("No. Empleado", FEmployeeNo);
        EstadoEmp.SetRange("Cód. Estado", CodEstado);
        EstadoEmp.SetFilter("Fecha Inicio", '<%1', FPeriodoFechaDesde);
        if not EstadoEmp.FindSet() then
            exit(0);

        repeat
            OlapStart := EstadoEmp."Fecha Inicio";
            if Inicio > OlapStart then
                OlapStart := Inicio;
            OlapEnd := EstadoEmp.FechaFinEfectiva();
            if FPeriodoFechaDesde - 1 < OlapEnd then
                OlapEnd := FPeriodoFechaDesde - 1;
            if OlapEnd >= OlapStart then
                Total += OlapEnd - OlapStart + 1;
        until EstadoEmp.Next() = 0;

        exit(Total);
    end;

    /// <summary>Inicio de la licencia del mismo estado que alcanza el período actual.</summary>
    internal procedure FechaInicioEstadoEnPeriodo(CodEstado: Code[20]): Date
    var
        EstadoEmp: Record "Estado Empleado";
    begin
        if (FEmployeeNo = '') or (CodEstado = '') then
            exit(0D);
        EstadoEmp.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        EstadoEmp.SetRange("Tipo Entidad", EstadoEmp."Tipo Entidad"::Empleado);
        EstadoEmp.SetRange("No. Empleado", FEmployeeNo);
        EstadoEmp.SetRange("Cód. Estado", CodEstado);
        EstadoEmp.SetFilter("Fecha Inicio", '<=%1', FFechaRef);
        if EstadoEmp.FindSet() then
            repeat
                if EstadoEmp.FechaFinEfectiva() >= FPeriodoFechaDesde then
                    exit(EstadoEmp."Fecha Inicio");
            until EstadoEmp.Next() = 0;
        exit(0D);
    end;

    local procedure CalcMesesPromedioVacaciones(): Decimal
    var
        Fase: Record "Fase Alta Empleado";
        Desde: Date;
        Hasta: Date;
        MesDesde: Date;
        MesHasta: Date;
        Meses: Integer;
    begin
        if FEmployeeNo = '' then
            exit(0);

        // LA MISMA VENTANA QUE EL NUMERADOR, de una sola fuente. Si se separan, se divide la suma de
        // un semestre por la cantidad de meses de otro.
        VentanaPromedioVacaciones(Desde, Hasta);

        // Sin ninguna fase cargada no hay con qué decidir, y devolver 0 haría una división por cero
        // en la fórmula. Se devuelven los seis del semestre completo, que es el caso normal.
        Fase.SetRange("No. Empleado", FEmployeeNo);
        if Fase.IsEmpty() then
            exit(6);

        // Se recorre la ventana y no seis meses fijos: ahora puede ser más corta que el semestre
        // —la "fracción menor de prestación" del art. 49—, y contar seis igual metería meses de la
        // fase anterior en el divisor mientras el numerador ya no los suma. Nunca pasa de seis
        // porque la ventana nace de ahí y sólo se achica.
        MesDesde := Desde;
        while MesDesde <= Hasta do begin
            MesHasta := CalcDate('<CM>', MesDesde);
            Fase.Reset();
            Fase.SetRange("No. Empleado", FEmployeeNo);
            Fase.SetFilter("Fecha Alta", '<=%1', MesHasta);
            Fase.SetFilter("Fecha Baja", '%1|>=%2', 0D, MesDesde);
            if not Fase.IsEmpty() then
                Meses += 1;
            MesDesde := CalcDate('<+1M>', MesDesde);
        end;

        exit(Meses);
    end;

    /// <summary>
    /// La ventana del promedio de vacaciones: los seis meses anteriores al del inicio de la licencia,
    /// RECORTADOS al alta de la fase vigente.
    /// </summary>
    /// <remarks>
    /// EL RECORTE ES LA REGLA DEL CONVENIO, no una precaución. El art. 49 del CCT dice que se suman
    /// las remuneraciones "correspondientes a los seis meses anteriores a aquel en que comience a
    /// gozar sus vacaciones, O LA FRACCIÓN MENOR DE PRESTACIÓN DE SERVICIOS QUE CORRESPONDA". En una
    /// dotación de temporada —altas y bajas varias veces al año: 04190 tiene doce fases desde 2015—
    /// los seis meses calendario se meten en la fase ANTERIOR, que es otra relación laboral y otro
    /// sueldo.
    ///
    /// MEDIDO: 04807 se dio de alta el 1/1/2026 y de baja el 28/1/2026. Sin recorte, su promedio
    /// salía de agosto, septiembre y octubre de 2025 —meses de su fase anterior— y sus vacaciones no
    /// gozadas pagaban CINCO VECES menos que en Meta4. Con el recorte, la ventana es enero de 2026,
    /// su única fracción de prestación, y cierra.
    ///
    /// Si la fase arrancó en el mes del ancla o después, no hay ningún mes anterior que mirar y la
    /// ventana quedaría vacía —división por cero en el divisor, o suma cero en el numerador—. Ese es
    /// justamente el caso de la "fracción menor": la ventana pasa a ser el PROPIO mes del ancla.
    ///
    /// Numerador y divisor salen los dos de acá. Antes la ventana estaba escrita dos veces —una en
    /// ApplyTokens para {PROM_DESDE}..{PROM_HASTA} y otra en CalcMesesPromedioVacaciones— y el riesgo
    /// de que se separaran ya estaba anotado en el código: serían semestres distintos arriba y abajo
    /// de la división.
    /// </remarks>
    local procedure VentanaPromedioVacaciones(var Desde: Date; var Hasta: Date)
    var
        Ancla: Date;
        AltaFase: Date;
        CorteFase: Date;
    begin
        Ancla := FechaInicioVacaciones();
        if Ancla = 0D then
            Ancla := FFechaRef;
        Hasta := CalcDate('<-CM-1D>', Ancla);
        Desde := CalcDate('<-CM>', CalcDate('<-5M>', Hasta));

        // El mes del alta entra entero: la fracción se mide en meses, que es la unidad que el
        // convenio divide ("la cantidad de períodos mensuales considerados").
        AltaFase := FechaAltaFaseVigente();
        if AltaFase <> 0D then begin
            CorteFase := CalcDate('<-CM>', AltaFase);
            if CorteFase > Desde then
                Desde := CorteFase;
        end;

        if Desde > Hasta then begin
            Desde := CalcDate('<-CM>', Ancla);
            Hasta := CalcDate('<CM>', Ancla);
        end;
    end;

    /// <summary>
    /// La ventana del promedio y su divisor, para un empleado y una fecha, SIN liquidar nada.
    /// </summary>
    /// <remarks>
    /// Existe para la página de análisis de vacaciones. Que la vista y el cálculo salgan de la MISMA
    /// función es el punto: una página que recalculara la ventana por su cuenta mostraría lo que
    /// debería pasar en vez de lo que pasa, y en una conciliación eso es peor que no tener vista.
    ///
    /// Pisa el estado de la instancia, así que se llama sobre una instancia propia —igual que
    /// TiposCambioFrancosAFecha—, nunca sobre la que está liquidando.
    /// </remarks>
    procedure VentanaPromedioVacacionesPara(EmployeeNo: Code[20]; FechaRef: Date; var Desde: Date; var Hasta: Date; var Meses: Integer)
    begin
        FEmployeeNo := EmployeeNo;
        FFechaRef := FechaRef;
        // El ancla cae a FFechaRef cuando no hay estado de vacaciones, y FechaInicioVacaciones compara
        // contra FPeriodoFechaDesde: sin esto, un estado viejo podría colarse como ancla.
        FPeriodoFechaDesde := CalcDate('<-CM>', FechaRef);
        VentanaPromedioVacaciones(Desde, Hasta);
        Meses := CalcMesesPromedioVacaciones();
    end;

    /// <summary>Los días de vacaciones por antigüedad (art. 150 LCT / art. 49 CCT) a una fecha.</summary>
    procedure DiasVacacionesPorAntiguedadPara(EmployeeNo: Code[20]; FechaRef: Date): Decimal
    begin
        FEmployeeNo := EmployeeNo;
        FFechaRef := FechaRef;
        exit(CalcVacacionesAnuales());
    end;

    /// <summary>Base del SAC: remuneraciones del semestre en curso ya grabadas.</summary>
    /// <remarks>
    /// Recorta por el ALTA DE LA FASE igual que el promedio de vacaciones: el SAC se gana en la
    /// relación laboral vigente, y en una dotación de temporada el semestre calendario se mete en la
    /// fase anterior, que es otro vínculo.
    ///
    /// Excluye la liquidación actual porque todavía no está grabada cuando esto se evalúa; la
    /// fórmula del concepto le suma #BASE_PROMEDIO para completar.
    /// </remarks>
    /// <summary>
    /// El mejor mes del semestre de un acumulador, sin el efecto de un concepto, sin contar la liquidación
    /// en curso (la fórmula suma la suya).
    /// </summary>
    /// <remarks>
    /// POR QUÉ EXISTE. El SAC de egreso de un administrativo no es lo acumulado dividido 12: en Meta4
    /// (concepto 3605, rama AD) es la mitad de la MEJOR remuneración mensual del semestre —la suma de los
    /// haberes ANTES de descontar ausencias—, por los días de alta sobre 180. Con sueldo parejo y mes
    /// entero las dos cuentas coinciden; con ausencias, un aumento o un ingreso a mitad de mes se
    /// separan (90331: 105.947,88 contra 102.737,33).
    ///
    /// El mes se arma con el acumulador (BASE_SAC) menos el concepto de ausencias (4703, que resta): la
    /// remuneración que habría correspondido sin la ausencia. Ambos son DATOS de la variable
    /// (Cód. Acumulador y Cód. Concepto): el motor no sabe de SAC ni de ausencias.
    ///
    /// El semestre y el alta se resuelven como en CalcBaseSacSemestre. Los borradores no cuentan.
    /// </remarks>
    local procedure CalcMejorMesAcumSemestre(CodAcumulador: Code[20]; CodConcepto: Code[20]): Decimal
    var
        Lin: Record "Línea Liquidación";
        Meses: Dictionary of [Integer, Decimal];
        Desde: Date;
        AltaFase: Date;
        Clave: Integer;
        Valor: Decimal;
        Mejor: Decimal;
    begin
        if (FEmployeeNo = '') or (FFechaRef = 0D) or (CodAcumulador = '') then
            exit(0);

        if Date2DMY(FFechaRef, 2) <= 6 then
            Desde := DMY2Date(1, 1, Date2DMY(FFechaRef, 3))
        else
            Desde := DMY2Date(1, 7, Date2DMY(FFechaRef, 3));
        AltaFase := FechaAltaFaseVigente();
        if (AltaFase <> 0D) and (AltaFase > Desde) then
            Desde := AltaFase;

        Lin.SetCurrentKey("No. Empleado", "Fecha Liquidación", "Tipo Concepto");
        Lin.SetRange("No. Empleado", FEmployeeNo);
        if CodConcepto = '' then
            Lin.SetRange("Cód. Concepto", CodAcumulador)
        else
            Lin.SetFilter("Cód. Concepto", '%1|%2', CodAcumulador, CodConcepto);
        Lin.SetRange("Fecha Liquidación", Desde, FFechaRef);
        if FLiqNo <> '' then
            Lin.SetFilter("No. Liquidación", '<>%1', FLiqNo);
        Lin.SetFilter(Estado, '<>%1', Lin.Estado::Borrador);
        Lin.SetLoadFields(Importe, "Cód. Concepto", "Fecha Liquidación");
        if Lin.FindSet() then
            repeat
                Clave := Date2DMY(Lin."Fecha Liquidación", 3) * 100 + Date2DMY(Lin."Fecha Liquidación", 2);
                if not Meses.Get(Clave, Valor) then
                    Valor := 0;
                if Lin."Cód. Concepto" = CodAcumulador then
                    Valor += Lin.Importe
                else
                    Valor -= Lin.Importe;
                Meses.Set(Clave, Valor);
            until Lin.Next() = 0;

        foreach Clave in Meses.Keys() do
            if Meses.Get(Clave, Valor) then
                if Valor > Mejor then
                    Mejor := Valor;
        exit(Mejor);
    end;

    local procedure CalcBaseSacSemestre(): Decimal
    var
        Lin: Record "Línea Liquidación";
        Desde: Date;
        AltaFase: Date;
        Total: Decimal;
    begin
        if (FEmployeeNo = '') or (FFechaRef = 0D) then
            exit(0);

        // El semestre que contiene la fecha de referencia: enero o julio.
        if Date2DMY(FFechaRef, 2) <= 6 then
            Desde := DMY2Date(1, 1, Date2DMY(FFechaRef, 3))
        else
            Desde := DMY2Date(1, 7, Date2DMY(FFechaRef, 3));

        AltaFase := FechaAltaFaseVigente();
        if (AltaFase <> 0D) and (AltaFase > Desde) then
            Desde := AltaFase;

        Lin.SetCurrentKey("No. Empleado", "Fecha Liquidación", "Tipo Concepto");
        Lin.SetRange("No. Empleado", FEmployeeNo);
        Lin.SetRange("Cód. Concepto", ConceptoBasePromedioTok);
        Lin.SetRange("Fecha Liquidación", Desde, FFechaRef);
        if FLiqNo <> '' then
            Lin.SetFilter("No. Liquidación", '<>%1', FLiqNo);
        Lin.SetLoadFields(Importe);
        if Lin.FindSet() then
            repeat
                Total += Lin.Importe;
            until Lin.Next() = 0;
        exit(Total);
    end;

    /// <summary>Días de estados que devengan francos dentro de la cobertura de esta liquidación.</summary>
    /// <remarks>
    /// La ventana es la COBERTURA y no el período: una liquidación que cubre parte del mes no puede
    /// devengar por días que le tocan a otra, que es la misma razón por la que existen VentanaDesde
    /// y VentanaHasta. Si dos liquidaciones del mismo mes contaran los mismos días, el devengo se
    /// duplicaría —y un franco de más es plata.
    ///
    /// Qué estado devenga sale de la bandera del Cód. Estado Empleado, que es configuración: acá no
    /// hay ninguna lista de códigos.
    /// </remarks>
    local procedure CalcDiasDevengaFrancosCobertura(): Decimal
    var
        Estado: Record "Estado Empleado";
        CodEst: Record "Cód. Estado Empleado";
        Hasta: Date;
        EstDesde: Date;
        EstHasta: Date;
        Total: Integer;
    begin
        if FEmployeeNo = '' then
            exit(0);
        Hasta := VentanaHasta();
        if Hasta = 0D then
            exit(0);

        Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
        Estado.SetRange("No. Empleado", FEmployeeNo);
        Estado.SetFilter("Fecha Inicio", '<=%1', Hasta);
        if Estado.FindSet() then
            repeat
                // El Get en su propio if: AL evalúa los dos lados de un and, así que un código de
                // estado inexistente haría fallar la lectura de la bandera igual.
                if CodEst.Get(Estado."Cód. Estado") then
                    if CodEst."Devenga Francos" then begin
                        EstDesde := Estado."Fecha Inicio";
                        EstHasta := Estado.FechaFinEfectiva();
                        Total += DiasDelEstadoEnLosTramos(EstDesde, EstHasta);
                    end;
            until Estado.Next() = 0;
        exit(Total);
    end;

    /// <summary>Días de un estado que caen dentro de los TRAMOS de cobertura, no del envolvente.</summary>
    /// <remarks>
    /// LA DIFERENCIA NO ES COSMÉTICA. "Cobertura Desde/Hasta" de la cabecera es el ENVOLVENTE de los
    /// tramos, y una liquidación final suele tener dos —los días antes de la marea y los de después—
    /// con el cierre de marea en el medio. En enero de 2026, la final de 04807 tiene los tramos
    /// [1-2] y [25-31] y un envolvente de [1-31]: contar por el envolvente le sumaría los 22 días
    /// que el cierre ya pagó, y el devengo de francos saldría al doble.
    ///
    /// Sin tramos cargados se cae al envolvente, que es el mismo respaldo que usa CargarTramos: al
    /// 1/10/2026, 7 de 567 liquidaciones de enero no tenían tramos.
    /// </remarks>
    /// <summary>Días del mes comercial de 30 en que el empleado estuvo de alta.</summary>
    /// <remarks>
    /// Recorre el calendario del período día por día en vez de restar fechas, por dos razones: hay
    /// que saltear el 31, y un empleado de temporada puede tener MÁS DE UNA FASE dentro del mismo
    /// mes —entra, se va y vuelve—, así que restar alta de baja contaría mal.
    ///
    /// El tope se aplica al DÍA DEL MES, no al total: el que estuvo de alta del 2 al 31 tiene 29
    /// días, no 30. Toparlo por el total daría 30 y le pagaría un día que no devengó.
    /// </remarks>
    local procedure CalcDiasAlta30(): Decimal
    var
        Periodo: Record "Período Liquidación";
        Dia: Date;
        Ultimo: Date;
        Total: Integer;
    begin
        if (FEmployeeNo = '') or not Periodo.Get(FCodPeriodo) then
            exit(0);
        Dia := Periodo."Fecha Desde";
        Ultimo := Periodo."Fecha Hasta";
        while Dia <= Ultimo do begin
            if DiaDeAlta(Dia) then
                Total += PesoDiaComercial(Dia);
            Dia += 1;
        end;
        exit(Total);
    end;

    /// <summary>
    /// Días calendario de alta entre el comienzo del semestre y el fin del período. Recorre las fases
    /// y no los días: esta variable se precalcula para todos los empleados.
    /// </summary>
    local procedure CalcDiasAltaSemestre(): Decimal
    var
        Periodo: Record "Período Liquidación";
        Fase: Record "Fase Alta Empleado";
        Inicio: Date;
        Hasta: Date;
        D: Date;
        H: Date;
        Total: Integer;
    begin
        if (FEmployeeNo = '') or not Periodo.Get(FCodPeriodo) then
            exit(0);
        Hasta := Periodo."Fecha Hasta";
        if Date2DMY(Hasta, 2) <= 6 then
            Inicio := DMY2Date(1, 1, Date2DMY(Hasta, 3))
        else
            Inicio := DMY2Date(1, 7, Date2DMY(Hasta, 3));

        Fase.SetRange("No. Empleado", FEmployeeNo);
        Fase.SetFilter("Fecha Alta", '<=%1', Hasta);
        if Fase.FindSet() then
            repeat
                if (Fase."Fecha Baja" = 0D) or (Fase."Fecha Baja" >= Inicio) then begin
                    D := Fase."Fecha Alta";
                    if D < Inicio then
                        D := Inicio;
                    H := Fase."Fecha Baja";
                    if (H = 0D) or (H > Hasta) then
                        H := Hasta;
                    if H >= D then
                        Total += H - D + 1;
                end;
            until Fase.Next() = 0;
        exit(Total);
    end;

    /// <summary>Peso de un día calendario dentro del mes comercial de 30.</summary>
    procedure PesoDiaComercial(Dia: Date): Integer
    var
        Numero: Integer;
    begin
        if Dia = 0D then
            exit(0);
        Numero := Date2DMY(Dia, 1);
        if Numero = 31 then
            exit(0);
        if (Dia = CalcDate('<CM>', Dia)) and (Numero < 30) then
            exit(31 - Numero);
        exit(1);
    end;

    /// <remarks>
    /// Fecha Baja en 0D es una fase abierta. Se compara contra 0D y no se la reemplaza por
    /// 31/12/9999: acá sólo hace falta saber si el día cae adentro, y meter la fecha máxima en una
    /// resta es lo que desborda el Date.
    /// </remarks>
    local procedure DiaDeAlta(Dia: Date): Boolean
    var
        Fase: Record "Fase Alta Empleado";
    begin
        Fase.SetRange("No. Empleado", FEmployeeNo);
        Fase.SetFilter("Fecha Alta", '<=%1', Dia);
        if not Fase.FindSet() then
            exit(false);
        repeat
            if (Fase."Fecha Baja" = 0D) or (Fase."Fecha Baja" >= Dia) then
                exit(true);
        until Fase.Next() = 0;
        exit(false);
    end;

    local procedure DiasDelEstadoEnLosTramos(EstDesde: Date; EstHasta: Date): Integer
    var
        D: Date;
        H: Date;
        Total: Integer;
        i: Integer;
    begin
        if FTramosDesde.Count() = 0 then begin
            D := EstDesde;
            H := EstHasta;
            if D < VentanaDesde() then
                D := VentanaDesde();
            if H > VentanaHasta() then
                H := VentanaHasta();
            if H >= D then
                exit(H - D + 1);
            exit(0);
        end;

        for i := 1 to FTramosDesde.Count() do begin
            D := EstDesde;
            H := EstHasta;
            if D < FTramosDesde.Get(i) then
                D := FTramosDesde.Get(i);
            // FechaFinEfectiva da 31/12/9999 en un estado abierto; se acota ANTES de restar o el
            // Date desborda.
            if H > FTramosHasta.Get(i) then
                H := FTramosHasta.Get(i);
            if H >= D then
                Total += H - D + 1;
        end;
        exit(Total);
    end;

    /// <summary>Días de prestación efectiva dentro de la ventana del promedio de vacaciones.</summary>
    /// <remarks>
    /// Recorre las FASES y no el calendario: un empleado de temporada puede tener más de una dentro
    /// de la ventana, y los días que no estuvo de alta no son prestación.
    ///
    /// Se acota a la ventana por los dos extremos. El de arriba importa tanto como el de abajo: la
    /// ventana de una fracción llega al fin del mes, pero el que se da de baja el 28 prestó 28 días,
    /// no 31 —y ése es justo el caso que hacía fallar a 04807 por un 6,7%—.
    /// </remarks>
    local procedure CalcDiasPrestacionPromedioVac(): Decimal
    var
        Fase: Record "Fase Alta Empleado";
        Desde: Date;
        Hasta: Date;
        D: Date;
        H: Date;
        Total: Integer;
        AltaFase: Date;
    begin
        if FEmployeeNo = '' then
            exit(0);
        VentanaPromedioVacaciones(Desde, Hasta);
        if (Desde = 0D) or (Hasta = 0D) then
            exit(0);
        AltaFase := FechaAltaFaseVigente();

        Fase.SetRange("No. Empleado", FEmployeeNo);
        Fase.SetFilter("Fecha Alta", '<=%1', Hasta);
        if Fase.FindSet() then
            repeat
                // Una fase ANTERIOR a la vigente no cuenta aunque su baja caiga en el mes del alta
                // (la ventana arranca en ese mes, así que sólo ahí se la podía colar). Medido en
                // 04751: baja el 5/9/2025 y alta el 23/9/2025; Meta4 divide por los 131 días de la
                // fase vigente y BC por 136, con los 5 días de la fase vieja.
                if (Fase."Fecha Baja" = 0D) or ((Fase."Fecha Baja" >= Desde) and ((AltaFase = 0D) or (Fase."Fecha Baja" >= AltaFase))) then begin
                    D := Fase."Fecha Alta";
                    H := Fase."Fecha Baja";
                    if H = 0D then
                        H := Hasta;
                    if D < Desde then
                        D := Desde;
                    if H > Hasta then
                        H := Hasta;
                    if H >= D then
                        Total += H - D + 1;
                end;
            until Fase.Next() = 0;
        exit(Total);
    end;

    /// <summary>Los días de prestación de la ventana, para la página de análisis.</summary>
    procedure DiasPrestacionPromedioVacPara(EmployeeNo: Code[20]; FechaRef: Date): Decimal
    begin
        FEmployeeNo := EmployeeNo;
        FFechaRef := FechaRef;
        FPeriodoFechaDesde := CalcDate('<-CM>', FechaRef);
        exit(CalcDiasPrestacionPromedioVac());
    end;

    /// <summary>1 si la fecha de referencia cae dentro de la ventana del promedio de vacaciones.</summary>
    /// <remarks>
    /// Sólo puede pasar en la rama de "fracción menor": la ventana normal termina el último día del
    /// mes ANTERIOR al ancla, así que la fecha de referencia nunca cae adentro.
    /// </remarks>
    local procedure VentanaPromedioIncluyeMesActual(): Decimal
    var
        Desde: Date;
        Hasta: Date;
    begin
        if FEmployeeNo = '' then
            exit(0);
        VentanaPromedioVacaciones(Desde, Hasta);
        if (FFechaRef >= Desde) and (FFechaRef <= Hasta) then
            exit(1);
        exit(0);
    end;

    /// <summary>El alta de la fase que estaba vigente a la fecha de referencia. 0D si no hay.</summary>
    /// <remarks>
    /// La ÚLTIMA fase que empezó en o antes de la fecha de referencia. Se busca por la fecha de alta
    /// y no por la de baja porque la fase de un egresado ya está cerrada, y la de un activo tiene la
    /// baja vacía: el alta es el único extremo que siempre está.
    /// </remarks>
    local procedure FechaAltaFaseVigente(): Date
    var
        Fase: Record "Fase Alta Empleado";
    begin
        if FEmployeeNo = '' then
            exit(0D);
        Fase.SetCurrentKey("No. Empleado", "Fecha Alta");
        Fase.SetRange("No. Empleado", FEmployeeNo);
        Fase.SetFilter("Fecha Alta", '<=%1', FFechaRef);
        if Fase.FindLast() then
            exit(Fase."Fecha Alta");
        exit(0D);
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

    /// <summary>
    /// Reemplaza cada {ATRIB_DESDE:X} y {ATRIB_HASTA:X} por la vigencia del atributo X.
    /// </summary>
    /// <remarks>
    /// Se recorre el texto en vez de hacer un Replace por nombre fijo porque el token lleva
    /// argumento: un mismo filtro puede nombrar dos atributos distintos, y el nombre no se conoce
    /// hasta leerlo.
    /// </remarks>
    local procedure ResolverTokensAtributo(Value: Text): Text
    begin
        Value := ReemplazarTokenAtributo(Value, TokAtribDesde, true);
        Value := ReemplazarTokenAtributo(Value, TokAtribHasta, false);
        exit(Value);
    end;

    local procedure ReemplazarTokenAtributo(Value: Text; Prefijo: Text; TomarDesde: Boolean): Text
    var
        CodAtributo: Code[20];
        Desde: Date;
        Hasta: Date;
        Fecha: Date;
        Resto: Text;
        Pos: Integer;
        Fin: Integer;
        Vueltas: Integer;
    begin
        Pos := StrPos(Value, Prefijo);
        while Pos > 0 do begin
            Vueltas += 1;
            // GUARDA DE BUCLE. Un token sin cerrar —'{ATRIB_DESDE:X' sin '}'— no se reemplaza, así
            // que StrPos lo volvería a encontrar en la vuelta siguiente y el while giraría para
            // siempre. Se devuelve el texto como vino: el token queda literal, el filtro no
            // encuentra filas y la fuente da 0, que es el modo de falla que ya tiene un token mal
            // escrito (regla 3 de la resolución de tokens). Cincuenta es muy por encima de
            // cualquier filtro real; el tope existe para que un error de tipeo no cuelgue el cálculo.
            if Vueltas > 50 then
                exit(Value);
            Resto := CopyStr(Value, Pos + StrLen(Prefijo));
            Fin := StrPos(Resto, '}');
            if Fin <= 1 then
                exit(Value);
            CodAtributo := CopyStr(Resto, 1, Fin - 1);
            ResolverFechasAtributo(CodAtributo, Desde, Hasta);
            if TomarDesde then
                Fecha := Desde
            else
                Fecha := Hasta;
            Value := CopyStr(Value, 1, Pos - 1) + Format(Fecha) + CopyStr(Resto, Fin + 1);
            Pos := StrPos(Value, Prefijo);
        end;
        exit(Value);
    end;

    /// <summary>
    /// Vigencia del atributo de este empleado cuyo valor apunta AL PROYECTO de esta liquidación.
    /// </summary>
    /// <remarks>
    /// El valor del atributo es el proyecto y no un catálogo de puestos: así la búsqueda es exacta
    /// —una fila por tramo y por marea— y el tripulante que tuvo tramos en varias mareas no se
    /// confunde. Se aceptan las dos formas de valor, Cód. Valor y Valor Texto, porque un atributo
    /// de lista y uno de texto guardan el proyecto en campos distintos.
    ///
    /// SIN FILA SE CAE A LA VENTANA DE LA ASIGNACIÓN, nunca a vacío. Es deliberado y es la razón de
    /// que este resolvedor exista en vez de un Replace directo: la fuente que usa estos tokens suma
    /// producción, y quien no tiene tramo cargado tiene que ver la marea entera, que es lo que veía
    /// antes de que el tramo existiera. Con vacío, TokenResolvedToEmpty le daría CERO y el concepto
    /// pagaría cero sin un solo error a la vista. Es la misma convención de los {ASIG_*}.
    ///
    /// DOS FILAS PARA LA MISMA MAREA NO SE ADIVINAN. Un tramo partido en dos —frío, planta, frío—
    /// no se puede expresar con un solo desde..hasta, y tomar del primero al último contaría el
    /// hueco del medio. Se avisa y se cae al fallback, que paga como antes: de más, pero visible.
    /// </remarks>
    local procedure ResolverFechasAtributo(CodTipoAtributo: Code[20]; var Desde: Date; var Hasta: Date)
    var
        Atributo: Record "Atributo Entidad Liq.";
        DesdeAtrib: Date;
        HastaAtrib: Date;
        Cuantos: Integer;
    begin
        // El fallback va PRIMERO: así todo camino de salida deja una ventana usable.
        ResolverFechasAsignacion(Desde, Hasta);

        if (FEmployeeNo = '') or (FJobNo = '') or (CodTipoAtributo = '') then
            exit;

        Atributo.SetRange("Tipo Entidad", "Tipo Entidad Estado"::Empleado);
        Atributo.SetRange("Cód. Entidad", FEmployeeNo);
        Atributo.SetRange("Cód. Tipo Atributo", CodTipoAtributo);
        if Atributo.FindSet() then
            repeat
                if (Atributo."Cód. Valor" = FJobNo) or (Atributo."Valor Texto" = FJobNo) then begin
                    Cuantos += 1;
                    DesdeAtrib := Atributo."Vigencia Desde";
                    HastaAtrib := Atributo."Vigencia Hasta";
                end;
            until Atributo.Next() = 0;

        if Cuantos = 0 then
            exit;
        if Cuantos > 1 then begin
            AvisarTramosMultiples(CodTipoAtributo);
            exit;
        end;

        // Se recorta a la ventana de la asignación, igual que {ASIG_*}: una vigencia abierta puesta
        // en un filtro de fechas arrastraría el 31/12/9999, y con él las descargas de las mareas
        // siguientes. El fin en blanco se queda con el de la asignación.
        if DesdeAtrib > Desde then
            Desde := DesdeAtrib;
        if (HastaAtrib <> 0D) and (HastaAtrib < Hasta) then
            Hasta := HastaAtrib;
    end;

    local procedure AvisarTramosMultiples(CodTipoAtributo: Code[20])
    var
        Mensaje: Text;
    begin
        if FSilenciarAvisosParam then
            exit;
        // ApplyTokens corre una vez por fila de filtro y por fuente, así que sin el corte el mismo
        // aviso se repetiría una decena de veces en la misma liquidación.
        Mensaje := StrSubstNo(MsgTramosMultiples, CodTipoAtributo, FJobNo);
        if StrPos(FAdvertenciasParametros, Mensaje) > 0 then
            exit;
        AgregarAdvertenciaParametro(Mensaje);
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
