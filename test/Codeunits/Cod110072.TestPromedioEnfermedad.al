namespace UAS.Payroll;

// Fechas, estados y valores sintéticos para las reglas configurables de licencias.
// Las pruebas con fuentes se ejecutan con AutoRollback: ningún dato de prueba queda guardado.
codeunit 110072 "Test Promedio Enfermedad"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure AltaEneroPromediaTreintaYUnDias()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Desde: Date;
        Hasta: Date;
        Divisor: Decimal;
    begin
        Divisor := Ctx.ResolverPromedioLicencia(D(2026, 1, 1), D(2026, 2, 28), 12, 362, 30, Desde, Hasta);
        AssertDecimal(31 / 30, Divisor, 'El divisor diario llega al primer día del mes de la enfermedad.');
        AssertFecha(D(2026, 1, 1), Desde, 'Se excluye el vínculo anterior.');
        AssertFecha(D(2026, 1, 31), Hasta, 'Febrero no integra su propio promedio.');
        AssertDecimal(100, 3100 / Divisor / 30, 'Un total sintético de 3100 en enero produce 100 por día.');
    end;

    [Test]
    procedure ReingresoJulioCuentaSetentaYSieteDias()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Desde: Date;
        Hasta: Date;
        Divisor: Decimal;
    begin
        Divisor := Ctx.ResolverPromedioLicencia(D(2025, 7, 16), D(2025, 10, 2), 12, 362, 30, Desde, Hasta);
        AssertDecimal(77 / 30, Divisor, 'La fracción activa se divide por días, sin agregar uno.');
        AssertFecha(D(2025, 7, 16), Desde, 'La ventana empieza en el alta del vínculo actual.');
        AssertFecha(D(2025, 9, 30), Hasta, 'El promedio termina antes del mes de inicio.');
    end;

    [Test]
    procedure AltaUltimosCuatroDiasNoImponeUnMes()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Desde: Date;
        Hasta: Date;
        Divisor: Decimal;
    begin
        Divisor := Ctx.ResolverPromedioLicencia(D(2026, 1, 28), D(2026, 2, 18), 12, 362, 30, Desde, Hasta);
        AssertDecimal(4 / 30, Divisor, 'Una alta reciente puede tener un divisor menor que un mes.');
        AssertFecha(D(2026, 1, 28), Desde, 'Se conservan los cuatro días del vínculo actual.');
        AssertFecha(D(2026, 1, 31), Hasta, 'El mes previo se toma hasta su último día.');
        AssertDecimal(100, 400 / Divisor / 30, 'MAX(1, divisor) diluiría este precio diario.');
    end;

    [Test]
    procedure SemestreCambiaDeDiarioACompletoEn181()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Desde: Date;
        Hasta: Date;
        Corte: Date;
        Divisor: Decimal;
    begin
        Corte := D(2026, 1, 1);
        Divisor := Ctx.ResolverPromedioLicencia(Corte - 180, D(2026, 1, 15), 6, 181, 30, Desde, Hasta);
        AssertDecimal(180 / 30, Divisor, 'La rama diaria permanece hasta 180 días.');
        AssertFecha(Corte - 180, Desde, 'La ventana se recorta al alta reciente.');
        AssertFecha(D(2025, 12, 31), Hasta, 'El corte es anterior al mes de inicio.');
        Divisor := Ctx.ResolverPromedioLicencia(Corte - 181, D(2026, 1, 15), 6, 181, 30, Desde, Hasta);
        AssertDecimal(6, Divisor, 'A los 181 días Meta4 divide por seis meses.');
        AssertFecha(Corte - 181, Desde, 'El alta se respeta incluso al alcanzar el umbral.');
        AssertFecha(D(2025, 12, 31), Hasta, 'El umbral no mueve el fin de la ventana.');
    end;

    [Test]
    procedure AnualCambiaDeDiarioACompletoEn362()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Desde: Date;
        Hasta: Date;
        Corte: Date;
        Divisor: Decimal;
    begin
        Corte := D(2026, 1, 1);
        Divisor := Ctx.ResolverPromedioLicencia(Corte - 361, D(2026, 1, 15), 12, 362, 30, Desde, Hasta);
        AssertDecimal(361 / 30, Divisor, 'A los 361 días todavía se aplica el divisor diario.');
        AssertFecha(Corte - 361, Desde, 'La ventana se limita al vínculo actual.');
        Divisor := Ctx.ResolverPromedioLicencia(Corte - 362, D(2026, 1, 15), 12, 362, 30, Desde, Hasta);
        AssertDecimal(12, Divisor, 'El umbral anual original es 362 días.');
        AssertFecha(Corte - 362, Desde, 'No se agregan días anteriores al alta.');
        AssertFecha(D(2025, 12, 31), Hasta, 'El promedio excluye el mes de inicio.');
    end;

    [Test]
    procedure VinculoCompletoTieneDoceMesesCalendario()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Desde: Date;
        Hasta: Date;
        Divisor: Decimal;
    begin
        Divisor := Ctx.ResolverPromedioLicencia(D(2020, 1, 1), D(2026, 2, 18), 12, 362, 30, Desde, Hasta);
        AssertDecimal(12, Divisor, 'Un vínculo completo se promedia en doce meses.');
        AssertFecha(D(2025, 2, 1), Desde, 'No se extiende la ventana hasta el ingreso remoto.');
        AssertFecha(D(2026, 1, 31), Hasta, 'La ventana termina al cierre del mes anterior.');
    end;

    [Test]
    procedure SemestreCompletoTieneSeisMesesCalendario()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Desde: Date;
        Hasta: Date;
        Divisor: Decimal;
    begin
        Divisor := Ctx.ResolverPromedioLicencia(D(2020, 1, 1), D(2026, 2, 18), 6, 181, 30, Desde, Hasta);
        AssertDecimal(6, Divisor, 'La rama de oficiales de máquinas conserva seis meses.');
        AssertFecha(D(2025, 8, 1), Desde, 'Se toman sólo los seis meses calendario previos.');
        AssertFecha(D(2026, 1, 31), Hasta, 'El mes actual permanece excluido.');
    end;

    [Test]
    procedure AltaEnMismoMesNoLeeOtraHistoria()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Desde: Date;
        Hasta: Date;
        Divisor: Decimal;
    begin
        Divisor := Ctx.ResolverPromedioLicencia(D(2026, 2, 1), D(2026, 2, 28), 12, 362, 30, Desde, Hasta);
        AssertDecimal(0, Divisor, 'Sin meses previos del vínculo actual el promedio es cero.');
        AssertFecha(D(1900, 1, 1), Desde, 'La fuente recibe una fecha válida que no lee historia anterior.');
        AssertFecha(D(1900, 1, 1), Hasta, 'No se genera un rango de fechas invertido.');
        Divisor := Ctx.ResolverPromedioLicencia(D(2026, 2, 15), D(2026, 2, 28), 6, 181, 30, Desde, Hasta);
        AssertDecimal(0, Divisor, 'Una alta posterior al inicio del mes también produce cero.');
        AssertFecha(D(1900, 1, 1), Desde, 'La alta de mitad de mes mantiene el rango vacío seguro.');
        AssertFecha(D(1900, 1, 1), Hasta, 'No se leen remuneraciones de otro vínculo.');
    end;

    [Test]
    procedure LicenciaOctubreConservaPrecioEnMesPosterior()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Desde: Date;
        Hasta: Date;
        Divisor: Decimal;
        PrecioDia: Decimal;
    begin
        // Enero y febrero de una licencia iniciada en octubre reciben el mismo ancla original.
        Divisor := Ctx.ResolverPromedioLicencia(D(2025, 7, 16), D(2025, 10, 2), 12, 362, 30, Desde, Hasta);
        PrecioDia := 7700 / Divisor / 30;
        AssertFecha(D(2025, 7, 16), Desde, 'Una licencia que continúa no incorpora meses ya enfermo.');
        AssertFecha(D(2025, 9, 30), Hasta, 'El corte de octubre queda congelado.');
        AssertDecimal(100, PrecioDia, 'El precio sintético original se mantiene.');
        AssertDecimal(3000, PrecioDia * 30, 'Un mes completo usa el mismo precio diario.');
        AssertDecimal(2400, PrecioDia * 24, 'Un mes parcial posterior conserva el precio original.');
    end;

    [Test]
    procedure EneroDeTreintaYUnDiasPagaTreinta()
    var
        Ctx: Codeunit "Contexto Liquidación";
    begin
        AssertDecimal(30, SumarDiasComerciales(D(2026, 1, 1), D(2026, 1, 31)), 'Enero suma treinta días comerciales.');
        AssertDecimal(0, Ctx.PesoDiaComercial(D(2026, 1, 31)), 'El día 31 no agrega sueldo mensual.');
        AssertDecimal(13, SumarDiasComerciales(D(2026, 1, 18), D(2026, 1, 31)), 'La ausencia iniciada el 18 llega al día 30.');
    end;

    [Test]
    procedure FebreroCompletoYEnfermedadParcialTierra()
    var
        Ctx: Codeunit "Contexto Liquidación";
    begin
        AssertDecimal(30, SumarDiasComerciales(D(2026, 2, 1), D(2026, 2, 28)), 'Febrero alcanza treinta días comerciales.');
        AssertDecimal(3, Ctx.PesoDiaComercial(D(2026, 2, 28)), 'El último día de febrero común completa treinta.');
        AssertDecimal(1, Ctx.PesoDiaComercial(D(2026, 2, 27)), 'El día previo conserva peso uno.');
        AssertDecimal(13, SumarDiasComerciales(D(2026, 2, 18), D(2026, 2, 28)), 'En tierra del 18 al 28 son trece días comerciales.');
        AssertDecimal(11, D(2026, 2, 28) - D(2026, 2, 18) + 1, 'La misma ausencia tiene once días calendario.');
    end;

    [Test]
    procedure FebreroBisiestoCompletaTreintaAlDia29()
    var
        Ctx: Codeunit "Contexto Liquidación";
    begin
        AssertDecimal(30, SumarDiasComerciales(D(2024, 2, 1), D(2024, 2, 29)), 'Febrero bisiesto suma treinta días comerciales.');
        AssertDecimal(1, Ctx.PesoDiaComercial(D(2024, 2, 28)), 'En año bisiesto el 28 no completa el mes.');
        AssertDecimal(2, Ctx.PesoDiaComercial(D(2024, 2, 29)), 'El día 29 incorpora un día comercial adicional.');
        AssertDecimal(13, SumarDiasComerciales(D(2024, 2, 18), D(2024, 2, 29)), 'La licencia parcial termina en el día comercial 30.');
    end;

    [Test]
    procedure VentanaTrimestralUsaSuPropioUmbral()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Desde: Date;
        Hasta: Date;
        Corte: Date;
        Divisor: Decimal;
    begin
        Corte := D(2026, 5, 1);
        Divisor := Ctx.ResolverPromedioLicencia(Corte - 89, D(2026, 5, 18), 3, 90, 30, Desde, Hasta);
        AssertDecimal(89 / 30, Divisor, 'Un umbral configurado de noventa días conserva la rama diaria hasta ochenta y nueve.');
        AssertFecha(D(2026, 2, 1), Desde, 'La ventana trimestral utiliza tres meses y no seis ni doce.');
        AssertFecha(D(2026, 4, 30), Hasta, 'El trimestre excluye el mes del ancla.');
        Divisor := Ctx.ResolverPromedioLicencia(Corte - 90, D(2026, 5, 18), 3, 90, 30, Desde, Hasta);
        AssertDecimal(3, Divisor, 'Al alcanzar su propio umbral divide por tres meses.');
        AssertFecha(D(2026, 2, 1), Desde, 'La ventana no incorpora días anteriores al trimestre.');
    end;

    [Test]
    procedure DivisorDiarioUsaDiasMesConfigurados()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Desde: Date;
        Hasta: Date;
        Corte: Date;
        Divisor: Decimal;
    begin
        Corte := D(2026, 7, 1);
        Divisor := Ctx.ResolverPromedioLicencia(Corte - 70, D(2026, 7, 15), 4, 120, 28, Desde, Hasta);
        AssertDecimal(2.5, Divisor, 'El divisor diario utiliza veintiocho días por mes cuando así se configura.');
        AssertFecha(Corte - 70, Desde, 'La ventana de cuatro meses se recorta al vínculo actual.');
        AssertFecha(D(2026, 6, 30), Hasta, 'El recorte conserva el cierre del mes anterior.');
        AssertDecimal(100, 7000 / Divisor / 28, 'La fórmula puede utilizar la misma unidad diaria configurada.');
    end;

    [Test]
    procedure CambioDeUmbralNoCambiaLaVentana()
    var
        Ctx: Codeunit "Contexto Liquidación";
        DesdeDiario: Date;
        HastaDiario: Date;
        DesdeCompleto: Date;
        HastaCompleto: Date;
        Corte: Date;
    begin
        Corte := D(2026, 7, 1);
        AssertDecimal(100 / 30,
            Ctx.ResolverPromedioLicencia(Corte - 100, D(2026, 7, 15), 4, 120, 30, DesdeDiario, HastaDiario),
            'Con el umbral mayor se conserva el divisor diario.');
        AssertDecimal(4,
            Ctx.ResolverPromedioLicencia(Corte - 100, D(2026, 7, 15), 4, 80, 30, DesdeCompleto, HastaCompleto),
            'Con el umbral menor los mismos datos alcanzan cuatro meses completos.');
        AssertFecha(DesdeDiario, DesdeCompleto, 'Numerador y divisor comparten el mismo recorte de historia.');
        AssertFecha(HastaDiario, HastaCompleto, 'Cambiar el umbral no incorpora el mes que se está calculando.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AnclaUsaEstadoConfiguradoYNoOtraLicencia()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Empleado: Code[20];
        Ancla: Date;
        Desde: Date;
        Hasta: Date;
    begin
        Empleado := NuevoCodigo();
        InsertarEstado(Empleado, 'LIC_ALT', D(2026, 1, 5), D(2026, 1, 10));
        InsertarEstado(Empleado, 'AU1', D(2026, 1, 11), D(2026, 2, 10));
        InsertarEstado(Empleado, 'LIC_ALT', D(2026, 2, 18), D(2026, 3, 10));
        Ctx.Init(Empleado, '', '', D(2026, 2, 28), 'OTRO_CCT', 'OTRA_CAT', '', 'PRUEBA', D(2026, 2, 1));
        Ancla := Ctx.FechaInicioEstadoEnPeriodo('LIC_ALT');
        AssertFecha(D(2026, 2, 18), Ancla, 'El estado configurable elige la licencia vigente y no la anterior del mismo código.');
        AssertFecha(D(2026, 1, 11), Ctx.FechaInicioEstadoEnPeriodo('AU1'), 'Otro estado del mismo empleado mantiene su propio inicio.');
        AssertFecha(0D, Ctx.FechaInicioEstadoEnPeriodo('EST_INEXISTENTE'), 'Una licencia inexistente no hereda el inicio de otra.');
        AssertDecimal(31 / 30,
            Ctx.ResolverPromedioLicencia(D(2026, 1, 1), Ancla, 3, 90, 30, Desde, Hasta),
            'La ventana y el divisor utilizan el inicio del estado seleccionado.');
        AssertFecha(D(2026, 1, 1), Desde, 'La historia empieza en el alta del vínculo actual.');
        AssertFecha(D(2026, 1, 31), Hasta, 'La licencia de febrero usa enero y no el corte de la otra licencia.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FuentesOtroEstadoCuentanFebreroSegunFormula()
    var
        Ctx: Codeunit "Contexto Liquidación";
        FuenteCalendario: Record "Fuente Datos Liquidación" temporary;
        FuenteComercial: Record "Fuente Datos Liquidación" temporary;
        Evaluador: Codeunit "Evaluador Fórmula";
        Variables: Dictionary of [Text, Decimal];
        Empleado: Code[20];
    begin
        Empleado := NuevoCodigo();
        InsertarEstado(Empleado, 'LIC_ALT', D(2026, 2, 1), D(2026, 2, 28));
        CrearFuente('LIC_ALT', false, true, FuenteCalendario);
        CrearFuente('LIC_ALT', true, true, FuenteComercial);
        Ctx.Init(Empleado, '', '', D(2026, 2, 28), 'CCT_ALTERNATIVO', 'CAT_ALTERNATIVA', '', 'PRUEBA', D(2026, 2, 1));
        Variables.Add('DIAS_CAL', Ctx.ResolveFuente(FuenteCalendario));
        Variables.Add('DIAS_30', Ctx.ResolveFuente(FuenteComercial));
        AssertDecimal(28, Variables.Get('DIAS_CAL'), 'La fuente calendario funciona con un estado distinto de AU1.');
        AssertDecimal(30, Variables.Get('DIAS_30'), 'La fuente comercial no depende del convenio ni la categoría.');
        Variables.Add('AUS_MES_COMERCIAL', 1);
        Evaluador.Init(Variables, D(2026, 2, 28));
        AssertDecimal(30, Evaluador.EvalFormula('IF(AUS_MES_COMERCIAL = 1, DIAS_30, DIAS_CAL)'),
            'El parámetro en la fórmula elige el calendario comercial.');
        Variables.Set('AUS_MES_COMERCIAL', 0);
        Evaluador.Init(Variables, D(2026, 2, 28));
        AssertDecimal(28, Evaluador.EvalFormula('IF(AUS_MES_COMERCIAL = 1, DIAS_30, DIAS_CAL)'),
            'La misma licencia utiliza días calendario cambiando sólo el parámetro.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FuentesParcialesOtroEstadoSonTreceYOnce()
    var
        Ctx: Codeunit "Contexto Liquidación";
        FuenteCalendario: Record "Fuente Datos Liquidación" temporary;
        FuenteComercial: Record "Fuente Datos Liquidación" temporary;
        Empleado: Code[20];
    begin
        Empleado := NuevoCodigo();
        InsertarEstado(Empleado, 'LIC_ALT', D(2026, 2, 18), D(2026, 2, 28));
        CrearFuente('LIC_ALT', false, true, FuenteCalendario);
        CrearFuente('LIC_ALT', true, true, FuenteComercial);
        Ctx.Init(Empleado, '', '', D(2026, 2, 28), 'OTRO_CCT', 'OTRA_CAT', '', 'PRUEBA', D(2026, 2, 1));
        AssertDecimal(11, Ctx.ResolveFuente(FuenteCalendario), 'Del dieciocho al veintiocho son once días calendario.');
        AssertDecimal(13, Ctx.ResolveFuente(FuenteComercial), 'La fuente comercial agrega el cierre de febrero en ese mismo intervalo.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FuentesRespetanHuecosEntreTramos()
    var
        Ctx: Codeunit "Contexto Liquidación";
        FuenteCalendario: Record "Fuente Datos Liquidación" temporary;
        FuenteComercial: Record "Fuente Datos Liquidación" temporary;
        Empleado: Code[20];
        Liquidacion: Code[20];
    begin
        Empleado := NuevoCodigo();
        Liquidacion := NuevoCodigo();
        InsertarEstado(Empleado, 'LIC_ALT', D(2026, 2, 1), D(2026, 2, 28));
        InsertarTramo(Liquidacion, 1, D(2026, 2, 1), D(2026, 2, 4));
        InsertarTramo(Liquidacion, 2, D(2026, 2, 18), D(2026, 2, 28));
        CrearFuente('LIC_ALT', false, true, FuenteCalendario);
        CrearFuente('LIC_ALT', true, true, FuenteComercial);
        Ctx.Init(Empleado, '', '', D(2026, 2, 28), 'OTRO_CCT', 'OTRA_CAT', Liquidacion, 'PRUEBA', D(2026, 2, 1));
        AssertDecimal(15, Ctx.ResolveFuente(FuenteCalendario), 'Los días cinco al diecisiete pertenecen al hueco de cobertura.');
        AssertDecimal(17, Ctx.ResolveFuente(FuenteComercial), 'El comercial conserva el hueco y agrega sólo el cierre cubierto.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FuenteRespetaFinExplicitoAntesDelSiguiente()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Fuente: Record "Fuente Datos Liquidación" temporary;
        Empleado: Code[20];
    begin
        Empleado := NuevoCodigo();
        InsertarEstado(Empleado, 'LIC_ALT', D(2026, 2, 18), D(2026, 2, 20));
        InsertarEstado(Empleado, 'OTRO_ESTADO', D(2026, 2, 27), 0D);
        CrearFuente('LIC_ALT', true, true, Fuente);
        Ctx.Init(Empleado, '', '', D(2026, 2, 28), 'OTRO_CCT', 'OTRA_CAT', '', 'PRUEBA', D(2026, 2, 1));
        AssertDecimal(3, Ctx.ResolveFuente(Fuente), 'Un fin explícito al veinte prevalece aunque el siguiente estado empiece el veintisiete.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FuenteAbiertaCierraConSiguienteEstadoDeLaEntidad()
    var
        Ctx: Codeunit "Contexto Liquidación";
        FuenteCalendario: Record "Fuente Datos Liquidación" temporary;
        FuenteComercial: Record "Fuente Datos Liquidación" temporary;
        Empleado: Code[20];
        OtroEmpleado: Code[20];
    begin
        Empleado := NuevoCodigo();
        OtroEmpleado := NuevoCodigo();
        InsertarEstado(Empleado, 'LIC_ALT', D(2026, 2, 18), 0D);
        InsertarEstado(Empleado, 'OTRO_ESTADO', D(2026, 2, 27), 0D);
        InsertarEstado(OtroEmpleado, 'LIC_ALT', D(2026, 2, 20), 0D);
        CrearFuente('LIC_ALT', false, true, FuenteCalendario);
        CrearFuente('LIC_ALT', true, true, FuenteComercial);
        Ctx.Init(Empleado, '', '', D(2026, 2, 28), 'OTRO_CCT', 'OTRA_CAT', '', 'PRUEBA', D(2026, 2, 1));
        AssertDecimal(9, Ctx.ResolveFuente(FuenteCalendario), 'Se deriva el fin del estado propio aunque tenga otro código; el otro empleado no acorta la licencia.');
        AssertDecimal(9, Ctx.ResolveFuente(FuenteComercial), 'Una licencia terminada antes del cierre no recibe días comerciales de fin de mes.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure TramoSinFinDeFebreroNoRecibeDiasAdicionales()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Fuente: Record "Fuente Datos Liquidación" temporary;
        Empleado: Code[20];
        Liquidacion: Code[20];
    begin
        Empleado := NuevoCodigo();
        Liquidacion := NuevoCodigo();
        InsertarEstado(Empleado, 'LIC_ALT', D(2026, 2, 18), 0D);
        InsertarTramo(Liquidacion, 1, D(2026, 2, 18), D(2026, 2, 27));
        CrearFuente('LIC_ALT', true, true, Fuente);
        Ctx.Init(Empleado, '', '', D(2026, 2, 28), 'OTRO_CCT', 'OTRA_CAT', Liquidacion, 'PRUEBA', D(2026, 2, 1));
        AssertDecimal(10, Ctx.ResolveFuente(Fuente), 'El peso del último día de febrero se aplica sólo si la liquidación cubre ese día.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ConfiguracionConservaDiasYPromediosDeRecibos()
    var
        Liquidacion: Record "Liquidación";
        Linea: Record "Línea Liquidación";
        Promedio: Record "Línea Liquidación";
        Periodo: Record "Período Liquidación";
        Variable: Record "Variable Sistema Liq.";
        Previos: Record "Resumen Variable Liq.";
        Fuente: Record "Fuente Datos Liquidación";
        VariablePrevios: Record "Variable Sistema Liq.";
        Ctx: Codeunit "Contexto Liquidación";
        Valores: Dictionary of [Text, Decimal];
        FechaRef: Date;
        Dias: Decimal;
        Prom: Decimal;
        Divisor: Decimal;
        BasePromedio: Decimal;
        NoRemunerativo: Decimal;
    begin
        // La suite también sirve en compañías vacías. Si hay configuración instalada,
        // compara en lectura contra recibos existentes; la fórmula aún no se recalcula.
        if not Variable.Get('DIV_PROM_LIC') then
            exit;
        Liquidacion.SetFilter("Cód. Período", '202601|202602');
        Liquidacion.SetRange(Estado, Liquidacion.Estado::Calculada);
        if not Liquidacion.FindSet() then
            exit;
        repeat
            Linea.Reset();
            Linea.SetRange("No. Liquidación", Liquidacion."No.");
            Linea.SetFilter("Cód. Concepto", '4110|4120|4125|4160|4165');
            Linea.SetFilter(Importe, '<>%1', 0);
            if Linea.FindFirst() then begin
                FechaRef := Liquidacion."Cobertura Hasta";
                if FechaRef = 0D then begin
                    if Periodo.Get(Liquidacion."Cód. Período") then
                        FechaRef := Periodo."Fecha Hasta"
                    else
                        FechaRef := Liquidacion.FechaReferenciaAprox();
                end;
                Ctx.Init(Liquidacion."No. Empleado", Liquidacion."No. Proyecto", Liquidacion."Cód. Período",
                    FechaRef, Liquidacion."Cód. Convenio", Liquidacion."Cód. Categoría", Liquidacion."No.",
                    Liquidacion."Cód. Tipo Liq.", Liquidacion."Cobertura Desde");
                Clear(Valores);
                // Los saldos FIFO de un recibo calculado ya incluyen su consumo. Para comparar
                // ausentismo se resuelven sólo sus operaciones, sin intentar valuar francos otra vez.
                Ctx.LoadParametros(Valores);
                if Linea."Cód. Concepto" = '4110' then begin
                    if Valores.Get('AUS_MES_COMERCIAL') = 1 then
                        Fuente.Get('DIAS_ENFERMEDAD_30')
                    else
                        Fuente.Get('DIAS_ENFERMEDAD');
                    Dias := Ctx.ResolveFuente(Fuente);
                end else begin
                    Fuente.Get('DIAS_ACCIDENTE');
                    Dias := Ctx.ResolveFuente(Fuente);
                    if Previos.Get(Liquidacion."No.", 'DIAS_ACC_PREVIOS') then begin
                        VariablePrevios.Get('DIAS_ACC_PREVIOS');
                        AssertDecimal(Previos.Valor, Ctx.ComputeVariableSistema(VariablePrevios),
                            'El conteo genérico conserva los días previos pagados de la misma licencia de accidente.');
                    end;
                end;
                AssertDecimal(Linea.Cantidad, Dias, 'La configuración conserva los días pagados en enero y febrero.');
                if (Liquidacion."Cód. Período" = '202602') and (Linea."Cód. Concepto" = '4110') then begin
                    Promedio.Reset();
                    Promedio.SetRange("No. Liquidación", Liquidacion."No.");
                    Promedio.SetRange("Cód. Concepto", 'PROM_ENF_MES');
                    if Promedio.FindFirst() then begin
                        Prom := 0;
                        Divisor := Ctx.ComputeVariableSistema(Variable);
                        if Divisor > 0 then begin
                            Fuente.Get('ENF_BASE');
                            BasePromedio := Ctx.ResolveFuente(Fuente);
                            Fuente.Get('ENF_NR');
                            NoRemunerativo := Ctx.ResolveFuente(Fuente);
                            Prom := (BasePromedio + NoRemunerativo) / Divisor;
                        end;
                        if Abs(Promedio.Importe - Prom) > 0.0001 then
                            Error('La configuración modificó un promedio ya calculado de febrero.');
                    end;
                end;
            end;
        until Liquidacion.Next() = 0;
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FuentesExistentesConFinGuardadoConservanResultados()
    var
        Fuente: Record "Fuente Datos Liquidación";
        Resumen: Record "Resumen Variable Liq.";
        Liquidacion: Record "Liquidación";
        Periodo: Record "Período Liquidación";
        Ctx: Codeunit "Contexto Liquidación";
        FechaRef: Date;
    begin
        Fuente.SetRange(Activo, true);
        Fuente.SetRange("Fin Efectivo", true);
        Fuente.SetFilter("No. Campo Fecha Fin", '>0');
        if not Fuente.FindSet() then
            exit;
        repeat
            // Las fuentes de enfermedad cambian de origen y la elección de calendario se
            // comprueba en la prueba anterior. Aquí se controla la configuración previa.
            if not (Fuente."Nombre Variable" in ['DIAS_ENFERMEDAD', 'DIAS_ENFERMEDAD_30', 'DIAS_ACCIDENTE']) then begin
                Resumen.Reset();
                Resumen.SetRange("Nombre Variable", Fuente."Nombre Variable");
                if Resumen.FindSet() then
                    repeat
                        if Liquidacion.Get(Resumen."No. Liquidación") then
                            if (Liquidacion.Estado = Liquidacion.Estado::Calculada) and
                               (Liquidacion."Cód. Período" in ['202601', '202602'])
                            then begin
                                FechaRef := Liquidacion."Cobertura Hasta";
                                if FechaRef = 0D then
                                    if Periodo.Get(Liquidacion."Cód. Período") then
                                        FechaRef := Periodo."Fecha Hasta"
                                    else
                                        FechaRef := Liquidacion.FechaReferenciaAprox();
                                Ctx.Init(Liquidacion."No. Empleado", Liquidacion."No. Proyecto", Liquidacion."Cód. Período",
                                    FechaRef, Liquidacion."Cód. Convenio", Liquidacion."Cód. Categoría", Liquidacion."No.",
                                    Liquidacion."Cód. Tipo Liq.", Liquidacion."Cobertura Desde");
                                AssertDecimal(Resumen.Valor, Ctx.ResolveFuente(Fuente),
                                    'El fin guardado conserva los valores de las fuentes previamente configuradas.');
                            end;
                    until Resumen.Next() = 0;
            end;
        until Fuente.Next() = 0;
    end;

    local procedure CrearFuente(CodEstado: Code[20]; Comercial: Boolean; FinEfectivo: Boolean; var Fuente: Record "Fuente Datos Liquidación" temporary)
    var
        Estado: Record "Estado Empleado";
    begin
        Fuente.Init();
        Fuente."Nombre Variable" := NuevoCodigo();
        Fuente."Id. Tabla" := Database::"Estado Empleado";
        Fuente."No. Campo Fecha Inicio" := Estado.FieldNo("Fecha Inicio");
        Fuente."No. Campo Fecha Fin" := Estado.FieldNo("Fecha Fin");
        Fuente."Fin Efectivo" := FinEfectivo;
        if Comercial then
            Fuente."Función Agregado" := Fuente."Función Agregado"::DIAS_OVERLAP_30
        else
            Fuente."Función Agregado" := Fuente."Función Agregado"::DIAS_OVERLAP;
        InsertarFiltro(Fuente."Nombre Variable", Estado.FieldNo("No. Empleado"), '{EMP_NO}');
        InsertarFiltro(Fuente."Nombre Variable", Estado.FieldNo("Cód. Estado"), CodEstado);
        InsertarFiltro(Fuente."Nombre Variable", Estado.FieldNo("Tipo Entidad"), '0');
    end;

    local procedure InsertarFiltro(Nombre: Code[30]; NoCampo: Integer; Valor: Text[250])
    var
        Filtro: Record "Filtro Fuente Datos Liq.";
    begin
        Filtro.Init();
        Filtro."Nombre Variable" := Nombre;
        Filtro."No. Campo" := NoCampo;
        Filtro."Filtro Valor" := Valor;
        Filtro.Insert(false);
    end;

    local procedure InsertarEstado(Empleado: Code[20]; CodEstado: Code[20]; Desde: Date; Hasta: Date)
    var
        Estado: Record "Estado Empleado";
    begin
        Estado.Init();
        Estado."No. Empleado" := Empleado;
        Estado."Cód. Estado" := CodEstado;
        Estado."Fecha Inicio" := Desde;
        Estado."Fecha Fin" := Hasta;
        Estado.Insert(false);
    end;

    local procedure InsertarTramo(Liquidacion: Code[20]; NoLinea: Integer; Desde: Date; Hasta: Date)
    var
        Tramo: Record "Tramo Cobertura Liq.";
    begin
        Tramo.Init();
        Tramo."No. Liquidación" := Liquidacion;
        Tramo."No. Línea" := NoLinea;
        Tramo.Desde := Desde;
        Tramo.Hasta := Hasta;
        Tramo.Insert(false);
    end;

    local procedure NuevoCodigo(): Code[20]
    begin
        exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
    end;

    local procedure SumarDiasComerciales(Desde: Date; Hasta: Date): Integer
    var
        Ctx: Codeunit "Contexto Liquidación";
        Dia: Date;
        Total: Integer;
    begin
        Dia := Desde;
        while Dia <= Hasta do begin
            Total += Ctx.PesoDiaComercial(Dia);
            Dia += 1;
        end;
        exit(Total);
    end;

    local procedure D(Anio: Integer; Mes: Integer; Dia: Integer): Date
    begin
        exit(DMY2Date(Dia, Mes, Anio));
    end;

    local procedure AssertDecimal(Esperado: Decimal; Obtenido: Decimal; Caso: Text)
    begin
        if Abs(Esperado - Obtenido) > 0.000000001 then
            Error(ErrDecimal, Caso, Esperado, Obtenido);
    end;

    local procedure AssertFecha(Esperada: Date; Obtenida: Date; Caso: Text)
    begin
        if Esperada <> Obtenida then
            Error(ErrFecha, Caso, Esperada, Obtenida);
    end;

    var
        ErrDecimal: Label '%1 Se esperaba %2 y se obtuvo %3.', Comment = '%1=caso; %2=valor esperado; %3=valor obtenido';
        ErrFecha: Label '%1 Se esperaba %2 y se obtuvo %3.', Comment = '%1=caso; %2=fecha esperada; %3=fecha obtenida';
}
