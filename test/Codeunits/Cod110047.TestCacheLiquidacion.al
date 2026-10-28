namespace UAS.Payroll;

codeunit 110047 "Test Cache Liquidacion"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure CantidadIndicadoraSinVigenciaNoEsPagoPendiente()
    var
        Motor: Codeunit "Motor Liquidación";
        Concepto: Record "Concepto Liquidación";
        Fuente: Record "Fuente Datos Liquidación";
        Incidencia: Record "Incidencia Liquidación";
        Ctx: Dictionary of [Text, Decimal];
        EsEntrada: Boolean;
    begin
        PrepararEntradaInformativa(Concepto, Fuente, Incidencia, Ctx);
        Assert(Concepto."Vigencia Desde" = DMY2Date(1, 2, 2026), 'El catálogo puede comenzar después del período de la entrada.');
        EsEntrada := Motor.EsCantidadInformativaDeFuente(Incidencia, Ctx);
        Assert(EsEntrada, 'La cantidad consumida por una fuente no es un haber pendiente de pago.');
        Assert((Incidencia.Cantidad = 1) and (Incidencia.Importe = 0), 'Clasificar el aviso no debe transformar la cantidad en importe.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure IndicadorExigeFuenteActivaYAlcanceExacto()
    var
        Motor: Codeunit "Motor Liquidación";
        Concepto: Record "Concepto Liquidación";
        Fuente: Record "Fuente Datos Liquidación";
        Incidencia: Record "Incidencia Liquidación";
        Filtro: Record "Filtro Fuente Datos Liq.";
        Novedad: Record "Novedad Liquidación";
        Ctx: Dictionary of [Text, Decimal];
        EsEntrada: Boolean;
    begin
        PrepararEntradaInformativa(Concepto, Fuente, Incidencia, Ctx);
        Fuente.Activo := false;
        Fuente.Modify(false);
        EsEntrada := Motor.EsCantidadInformativaDeFuente(Incidencia, Ctx);
        Assert(not EsEntrada, 'Una fuente inactiva no acredita el uso del indicador.');
        Fuente.Activo := true;
        Fuente.Modify(false);
        Ctx.Set(Fuente."Nombre Variable", 0);
        EsEntrada := Motor.EsCantidadInformativaDeFuente(Incidencia, Ctx);
        Assert(not EsEntrada, 'El nombre sembrado en cero no acredita una cantidad leída.');
        Ctx.Set(Fuente."Nombre Variable", 1);
        Filtro.Get(Fuente."Nombre Variable", 3);
        Filtro."Filtro Valor" := '{JOB_NO}';
        Filtro.Modify(false);
        EsEntrada := Motor.EsCantidadInformativaDeFuente(Incidencia, Ctx);
        Assert(not EsEntrada, 'Un token de otro alcance no debe ocultar la advertencia.');
        Filtro."Filtro Valor" := '{PERIODO}';
        Filtro.Modify(false);
        Filtro.Init();
        Filtro."Nombre Variable" := Fuente."Nombre Variable";
        Filtro."No. Línea" := 4;
        Filtro."No. Campo" := Novedad.FieldNo(Observaciones);
        Filtro."Filtro Valor" := 'OTRO';
        Filtro.Insert(false);
        EsEntrada := Motor.EsCantidadInformativaDeFuente(Incidencia, Ctx);
        Assert(not EsEntrada, 'Un filtro adicional puede excluir la entrada y conserva el aviso.');
        Filtro.Delete(false);
        EsEntrada := Motor.EsCantidadInformativaDeFuente(Incidencia, Ctx);
        Assert(EsEntrada, 'El alcance exacto del indicador debe reconocerse al restaurarlo.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure CantidadPagableOVersionHistoricaConservaAviso()
    var
        Motor: Codeunit "Motor Liquidación";
        Concepto: Record "Concepto Liquidación";
        Anterior: Record "Concepto Liquidación";
        Fuente: Record "Fuente Datos Liquidación";
        Incidencia: Record "Incidencia Liquidación";
        Ctx: Dictionary of [Text, Decimal];
        EsEntrada: Boolean;
    begin
        PrepararEntradaInformativa(Concepto, Fuente, Incidencia, Ctx);
        Incidencia."Desde Novedad" := false;
        EsEntrada := Motor.EsCantidadInformativaDeFuente(Incidencia, Ctx);
        Assert(not EsEntrada, 'Una incidencia manual no demuestra una entrada leída desde novedades.');
        Incidencia."Desde Novedad" := true;
        Concepto.Fórmula := 'CANT_INCIDENCIA';
        Concepto.Modify(false);
        EsEntrada := Motor.EsCantidadInformativaDeFuente(Incidencia, Ctx);
        Assert(not EsEntrada, 'Una cantidad que espera fórmula debe conservar el aviso.');
        Concepto.Fórmula := '';
        Concepto."Es Devengo" := true;
        Concepto.Modify(false);
        EsEntrada := Motor.EsCantidadInformativaDeFuente(Incidencia, Ctx);
        Assert(not EsEntrada, 'Un devengo informativo puede tener efecto y no se excluye del control.');
        Concepto."Es Devengo" := false;
        Concepto.Modify(false);
        Anterior := Concepto;
        Anterior."Vigencia Desde" := DMY2Date(1, 1, 2026);
        Anterior."Vigencia Hasta" := DMY2Date(31, 1, 2026);
        Anterior."Tipo Concepto" := Anterior."Tipo Concepto"::"Haber Remunerativo";
        Anterior.Insert(false);
        EsEntrada := Motor.EsCantidadInformativaDeFuente(Incidencia, Ctx);
        Assert(not EsEntrada, 'Un informativo futuro no debe ocultar una cantidad pagable de una versión anterior.');
        Anterior.Delete(false);
        EsEntrada := Motor.EsCantidadInformativaDeFuente(Incidencia, Ctx);
        Assert(EsEntrada, 'Sólo un catálogo íntegramente informativo reconoce la excepción.');
    end;

    [Test]
    procedure IncidenciasConservanDatosYSeRenuevan()
    var
        Motor: Codeunit "Motor Liquidación";
        Origen: Record "Incidencia Liquidación";
        Copia: Record "Incidencia Liquidación" temporary;
        LiqNo: Code[20];
    begin
        LiqNo := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20);
        Origen."No. Liquidación" := LiqNo;
        Origen."Cód. Concepto" := 'CANTIDAD';
        Origen.Importe := 0;
        Origen.Cantidad := 21;
        Origen."Unidad Cantidad" := 'H';
        Origen."Valor Unitario" := 7;
        Origen."Desde Novedad" := true;
        Origen.Observaciones := 'Conservar datos completos';
        Origen.Insert(false);

        Motor.ReiniciarCachesLiquidacion();
        Motor.CargarIncidencias(LiqNo);
        Motor.CompartirIncidencias(Copia);
        Copia.Get(LiqNo, 'CANTIDAD');
        Assert((Copia.Importe = 0) and (Copia.Cantidad = 21) and
            (Copia."Unidad Cantidad" = 'H') and (Copia."Valor Unitario" = 7) and
            Copia."Desde Novedad" and (Copia.Observaciones = Origen.Observaciones),
            'La instantánea debe conservar la incidencia de cantidad y su información.');

        Origen.Cantidad := 30;
        Origen.Modify(false);
        Copia.Get(LiqNo, 'CANTIDAD');
        Assert(Copia.Cantidad = 21, 'Las iteraciones deben usar la misma instantánea.');
        Motor.ReiniciarCachesLiquidacion();
        Motor.CargarIncidencias(LiqNo);
        Motor.CompartirIncidencias(Copia);
        Copia.Get(LiqNo, 'CANTIDAD');
        Assert(Copia.Cantidad = 30, 'El recálculo debe leer la incidencia actualizada.');
        Motor.CargarIncidencias('');
        Motor.CompartirIncidencias(Copia);
        Assert(Copia.IsEmpty(), 'No deben quedar incidencias del empleado anterior.');
        Origen.Delete(false);
    end;

    [Test]
    procedure CCTSeparaCategoriaFechaYReinicio()
    var
        Motor: Codeunit "Motor Liquidación";
        Concepto: Record "Concepto Liquidación" temporary;
        Restriccion: Record "Concepto CCT Vigente";
        Fecha: Date;
    begin
        Fecha := DMY2Date(1, 1, 2026);
        Concepto.Código := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20);
        Concepto."Vigencia Desde" := Fecha;
        Restriccion."Cód. Concepto" := Concepto.Código;
        Restriccion."Vigencia Desde" := Fecha;
        Restriccion."Cód. Convenio" := 'CONV';
        Restriccion."Cód. Categoría" := 'A';
        Restriccion.Insert(false);
        Motor.ReiniciarCachesLiquidacion();
        Assert(Motor.CCTAplicaAConcepto(Concepto, 'CONV', 'A', Fecha), 'Categoría incluida.');
        Assert(not Motor.CCTAplicaAConcepto(Concepto, 'CONV', 'B', Fecha), 'Categoría no incluida.');
        Assert(Motor.CCTAplicaAConcepto(Concepto, 'CONV', 'B', Fecha - 1), 'Antes de la restricción aplica.');
        Assert(not Motor.CCTAplicaAConcepto(Concepto, 'OTRO', 'A', Fecha), 'Otro convenio no incluido.');
        Restriccion.Excluye := true;
        Restriccion.Modify(false);
        Assert(Motor.CCTAplicaAConcepto(Concepto, 'CONV', 'A', Fecha), 'La decisión permanece durante la liquidación.');
        Motor.ReiniciarCachesLiquidacion();
        Assert(not Motor.CCTAplicaAConcepto(Concepto, 'CONV', 'A', Fecha), 'El recálculo toma la exclusión nueva.');
        Assert(Motor.CCTAplicaAConcepto(Concepto, 'CONV', 'B', Fecha), 'Sin inclusiones, aplica a las no excluidas.');
        Restriccion.Delete(false);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenIgnoraAporteCeroYConservaImportes()
    var
        Lector: Code[20];
        Aportante: Code[20];
    begin
        InicializarOrden();
        Lector := ConceptoOrden('L1', AcumuladorOrden, '', 10, false);
        Aportante := ConceptoOrden('P1', '0', '', 20, false);
        FraccionOrden(Aportante, 100, '', false, FechaOrden);
        EjecutarOrden();
        Assert(ImporteOrden(Lector) = 100, 'El lector debe conservar el subtotal de su fórmula.');
        Assert(ImporteOrden(Aportante) = 0, 'La línea cero debe seguir existiendo.');
        Assert(ContextoOrden.Get(AcumuladorOrden) = 100, 'El aporte cero no cambia la base.');
        Assert(MotorOrden.AvisosOrdenCalculados() = '', 'No debe contar un aporte nulo.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenRespetaFraccionAnuladaYVigencias()
    var
        Aportante: Code[20];
    begin
        InicializarOrden();
        ConceptoOrden('L1', AcumuladorOrden, '', 10, false);
        Aportante := ConceptoOrden('P1', '9', '', 20, false);
        FraccionOrden(Aportante, 100, '', true, FechaOrden - 2);
        FraccionOrden(Aportante, 0, '', false, FechaOrden - 1);
        FraccionOrden(Aportante, 100, '', false, FechaOrden + 1);
        EjecutarOrden();
        Assert(ImporteOrden(Aportante) = 9, 'Anular la fracción no anula la línea del concepto.');
        Assert(ContextoOrden.Get(AcumuladorOrden) = 100, 'Debe ganar la fracción cero; la futura no aplica.');
        Assert(MotorOrden.AvisosOrdenCalculados() = '', 'Una distribución anulada no es un aporte efectivo.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenRespetaFiltroConvenioDelAporte()
    var
        Aportante: Code[20];
    begin
        InicializarOrden();
        ConceptoOrden('L1', AcumuladorOrden, '', 10, false);
        Aportante := ConceptoOrden('P1', '9', '', 20, false);
        FraccionOrden(Aportante, 100, '<>' + LiquidacionOrden."Cód. Convenio", false, FechaOrden);
        EjecutarOrden();
        Assert(ImporteOrden(Aportante) = 9, 'El filtro del acumulador no debe modificar el importe de la línea.');
        Assert(ContextoOrden.Get(AcumuladorOrden) = 100, 'El convenio excluido no recibe el aporte.');
        Assert(MotorOrden.AvisosOrdenCalculados() = '', 'No debe anunciar una fracción excluida por convenio.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenConservaAportesNegativosYLecturaAnterior()
    var
        Lector: Code[20];
        Aportante: Code[20];
    begin
        InicializarOrden();
        Lector := ConceptoOrden('L1', AcumuladorOrden, '', 10, false);
        Aportante := ConceptoOrden('P1', '9', '', 20, false);
        FraccionOrden(Aportante, 50, '', true, FechaOrden);
        EjecutarOrden();
        Assert(ImporteOrden(Lector) = 100, 'El diagnóstico no reevalúa el lector.');
        Assert(ContextoOrden.Get(AcumuladorOrden) = 95.5, 'Debe conservar porcentaje y signo del aporte.');
        Assert(StrPos(MotorOrden.AvisosOrdenCalculados(), Lector + ' lee') > 0, 'Un aporte negativo efectivo también merece revisión.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenDistingueCadaLectorYElSubtotalFinal()
    var
        Primero: Code[20];
        Segundo: Code[20];
        Ultimo: Code[20];
        Aportante: Code[20];
        Avisos: Text;
    begin
        InicializarOrden();
        Primero := ConceptoOrden('L1', AcumuladorOrden, '', 10, false);
        Segundo := ConceptoOrden('L2', AcumuladorOrden + '*2', '', 15, false);
        Aportante := ConceptoOrden('P1', '9', '', 20, false);
        Ultimo := ConceptoOrden('L3', AcumuladorOrden, '', 30, false);
        FraccionOrden(Aportante, 100, '', false, FechaOrden);
        EjecutarOrden();
        Avisos := MotorOrden.AvisosOrdenCalculados();
        Assert((ImporteOrden(Primero) = 100) and (ImporteOrden(Segundo) = 200) and (ImporteOrden(Ultimo) = 109), 'Cada fórmula debe conservar el subtotal que leyó.');
        Assert((StrPos(Avisos, Primero + ' lee') > 0) and (StrPos(Avisos, Segundo + ' lee') > 0), 'Debe identificar ambas lecturas anteriores, no sólo la primera.');
        Assert(StrPos(Avisos, Ultimo + ' lee') = 0, 'El lector posterior ya recibió el aporte.');
        Assert(StrPos(Avisos, 'quedó calculado') = 0, 'El aviso no debe afirmar una pérdida de importe.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenReconoceEtapaSinCambiarElAcumulador()
    var
        Lector: Code[20];
        Aportante: Code[20];
    begin
        InicializarOrden();
        Lector := ConceptoOrden('L1', AcumuladorOrden + '/10', '', 10, false);
        Aportante := ConceptoOrden('P1', '9', '', 20, false);
        FraccionOrden(Lector, 100, '', false, FechaOrden);
        FraccionOrden(Aportante, 100, '', false, FechaOrden);
        EjecutarOrden();
        Assert(ImporteOrden(Lector) = 10, 'La lectura por etapas debe mantener su resultado.');
        Assert(ContextoOrden.Get(AcumuladorOrden) = 119, 'No debe sumar de nuevo la propia lectura.');
        Assert(StrPos(MotorOrden.AvisosOrdenCalculados(), 'El lector también aporta a la base') > 0,
            'Debe identificar que el lector también aporta sin ocultar la observación.');
        Assert(StrPos(MotorOrden.AvisosOrdenCalculados(), 'no confirma que el subtotal sea intencional') > 0,
            'La participación en la base no debe dar por justificado su alcance.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenNoAvisaPorInformativoSinConsumidor()
    var
        Auxiliar: Code[20];
        Aportante: Code[20];
    begin
        InicializarOrden();
        Auxiliar := ConceptoOrden('H1', AcumuladorOrden + '/2', '', 5, true);
        Aportante := ConceptoOrden('P1', '9', '', 20, false);
        FraccionOrden(Aportante, 100, '', false, FechaOrden);
        EjecutarOrden();
        Assert(ImporteOrden(Auxiliar) = 50, 'El informativo debe seguir guardando su resultado.');
        Assert(ContextoOrden.Get(AcumuladorOrden) = 109, 'Debe conservar el total de la base.');
        Assert(MotorOrden.AvisosOrdenCalculados() = '', 'Un auxiliar sin consumidor efectivo no demuestra riesgo económico.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenSigueInformativoConsumidoConNumeral()
    var
        Auxiliar: Code[20];
        Aportante: Code[20];
        Monetario: Code[20];
    begin
        InicializarOrden();
        Auxiliar := ConceptoOrden('H1', AcumuladorOrden + '/2', '', 5, true);
        Aportante := ConceptoOrden('P1', '9', '', 20, false);
        Monetario := ConceptoOrden('L1', '#' + Auxiliar + '*2', '', 30, false);
        FraccionOrden(Aportante, 100, '', false, FechaOrden);
        EjecutarOrden();
        Assert(ImporteOrden(Monetario) = 100, 'El numeral conserva el resultado anterior del auxiliar.');
        Assert(StrPos(MotorOrden.AvisosOrdenCalculados(), Auxiliar + ' lee') > 0, 'No debe ocultar un auxiliar que sí alimenta una línea monetaria.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenSigueInformativoConsumidoPorNombre()
    var
        Auxiliar: Code[20];
        Aportante: Code[20];
        Monetario: Code[20];
    begin
        InicializarOrden();
        Auxiliar := ConceptoOrden('H1', AcumuladorOrden + '/2', '', 5, true);
        Aportante := ConceptoOrden('P1', '9', '', 20, false);
        Monetario := ConceptoOrden('L1', Auxiliar + '*2', '', 30, false);
        FraccionOrden(Aportante, 100, '', false, FechaOrden);
        EjecutarOrden();
        Assert(ImporteOrden(Monetario) = 100, 'El nombre sin numeral también conserva el resultado anterior del auxiliar.');
        Assert(StrPos(MotorOrden.AvisosOrdenCalculados(), Auxiliar + ' lee') > 0, 'No debe ocultar la dependencia efectiva de un nombre sin numeral.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenConservaAvisoDeInformativoQueDevengaUnLote()
    var
        Devengo: Code[20];
        Aportante: Code[20];
        Linea: Record "Línea Liquidación";
    begin
        InicializarOrden();
        Devengo := ConceptoOrden('H1', AcumuladorOrden + '/10', '', 5, true);
        SeleccionOrden.Get(Devengo, FechaOrden);
        SeleccionOrden."Rol Franco" := SeleccionOrden."Rol Franco"::Devengo;
        SeleccionOrden."Es Devengo" := true;
        SeleccionOrden."Unidad Cantidad" := 'DIA';
        SeleccionOrden.Modify(false);
        Aportante := ConceptoOrden('P1', '9', '', 20, false);
        FraccionOrden(Aportante, 100, '', false, FechaOrden);
        EjecutarOrden();
        Linea.SetRange("No. Liquidación", LiquidacionOrden."No.");
        Linea.SetRange("Cód. Concepto", Devengo);
        Linea.FindFirst();
        Assert((Linea.Cantidad = 10) and (Linea.Importe = 0) and Linea."Es Devengo", 'El lote debe conservar los días devengados sin convertirlos en dinero.');
        Assert(ContextoOrden.Get(AcumuladorOrden) = 109, 'El diagnóstico no cambia el acumulador usado para devengar.');
        Assert(StrPos(MotorOrden.AvisosOrdenCalculados(), Devengo + ' lee') > 0, 'Un informativo que genera días de un lote sí tiene efecto.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenSigueInformativoPorFraccionAOtroAcumulador()
    var
        Auxiliar: Code[20];
        Aportante: Code[20];
        Monetario: Code[20];
        Destino: Code[20];
    begin
        InicializarOrden();
        Destino := AcumuladorAdicionalOrden('AD');
        Auxiliar := ConceptoOrden('H1', AcumuladorOrden + '/2', '', 5, true);
        Aportante := ConceptoOrden('P1', '9', '', 20, false);
        Monetario := ConceptoOrden('L1', Destino + '*2', '', 30, false);
        FraccionADestinoOrden(Auxiliar, Destino);
        FraccionOrden(Aportante, 100, '', false, FechaOrden);
        EjecutarOrden();
        Assert((ImporteOrden(Monetario) = 100) and (ContextoOrden.Get(Destino) = 50), 'El importe debe conservar el aporte real del informativo al otro acumulador.');
        Assert(StrPos(MotorOrden.AvisosOrdenCalculados(), Auxiliar + ' lee') > 0, 'El informativo sí tiene consumidor mediante su fracción.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenNoEnlazaConsumoAnteriorConAporteFuturo()
    var
        Auxiliar: Code[20];
        Aportante: Code[20];
        Monetario: Code[20];
        Destino: Code[20];
        Avisos: Text;
    begin
        InicializarOrden();
        Destino := AcumuladorAdicionalOrden('AD');
        Monetario := ConceptoOrden('L1', Destino + '+1', '', 10, false);
        Auxiliar := ConceptoOrden('H1', AcumuladorOrden + '/2', '', 15, true);
        Aportante := ConceptoOrden('P1', '9', '', 20, false);
        FraccionADestinoOrden(Auxiliar, Destino);
        FraccionOrden(Aportante, 100, '', false, FechaOrden);
        EjecutarOrden();
        Avisos := MotorOrden.AvisosOrdenCalculados();
        Assert((ImporteOrden(Monetario) = 1) and (ContextoOrden.Get(Destino) = 50), 'El diagnóstico no debe actualizar retrospectivamente el importe.');
        Assert(StrPos(Avisos, Monetario + ' lee') > 0, 'Debe revisar el aporte a la base que llegó después de la lectura monetaria.');
        Assert(StrPos(Avisos, Auxiliar + ' lee') = 0, 'El consumidor anterior nunca recibió el resultado del informativo.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenArrobaReevaluaSinHeredarLaLecturaVieja()
    var
        Auxiliar: Code[20];
        Descartado: Code[20];
        Aportante: Code[20];
        Monetario: Code[20];
        Avisos: Text;
    begin
        InicializarOrden();
        Auxiliar := ConceptoOrden('H1', AcumuladorOrden + '/2', '', 5, true);
        Descartado := ConceptoOrden('D1', '9', '@' + Auxiliar + '<0', 10, false);
        Aportante := ConceptoOrden('P1', '9', '', 20, false);
        Monetario := ConceptoOrden('L1', '@' + Auxiliar + '*2', '', 30, false);
        FraccionOrden(Aportante, 100, '', false, FechaOrden);
        Aportante := ConceptoOrden('P2', '3', '', 40, false);
        FraccionOrden(Aportante, 100, '', false, FechaOrden);
        EjecutarOrden();
        Avisos := MotorOrden.AvisosOrdenCalculados();
        Assert(ImporteOrden(Monetario) = 109, 'La arroba debe utilizar la base de su momento, no el valor50 guardado.');
        Assert(ContextoOrden.Get(AcumuladorOrden) = 112, 'El aporte posterior no reevalúa la fórmula.');
        Assert(StrPos(Avisos, Monetario + ' lee') > 0, 'Debe conservar la lectura indirecta de la arroba.');
        Assert(StrPos(Avisos, Auxiliar + ' lee') = 0, 'La arroba no consume la instantánea anterior del auxiliar.');
        Assert(StrPos(Avisos, Descartado + ' lee') = 0, 'La memo de la condición descartada debe renovarse antes del importe siguiente.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenCondicionDescartadaNoContaminaSiguienteLinea()
    var
        Siguiente: Code[20];
        Aportante: Code[20];
        Linea: Record "Línea Liquidación";
    begin
        InicializarOrden();
        ConceptoOrden('D1', '9', AcumuladorOrden + '<0', 10, false);
        Siguiente := ConceptoOrden('L1', 'TEST_OTRO', '', 15, false);
        Aportante := ConceptoOrden('P1', '9', '', 20, false);
        FraccionOrden(Aportante, 100, '', false, FechaOrden);
        EjecutarOrden();
        Assert(ImporteOrden(Siguiente) = 3, 'El contexto del siguiente concepto debe conservarse.');
        Linea.SetRange("No. Liquidación", LiquidacionOrden."No.");
        Linea.SetRange("Cód. Concepto", Siguiente);
        Linea.FindFirst();
        Assert(StrPos(Linea."Fuente Parámetros", AcumuladorOrden) = 0, 'La traza de una condición descartada no pertenece a la línea siguiente.');
        Assert(MotorOrden.AvisosOrdenCalculados() = '', 'La lectura descartada no tiene consumidor monetario.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenCondicionDescartadaConsumidaConservaElAviso()
    var
        Descartado: Code[20];
        Monetario: Code[20];
        Aportante: Code[20];
    begin
        InicializarOrden();
        Descartado := ConceptoOrden('D1', '9', AcumuladorOrden + '<0', 10, false);
        Aportante := ConceptoOrden('P1', '9', '', 20, false);
        Monetario := ConceptoOrden('L1', '#' + Descartado + '+1', '', 30, false);
        FraccionOrden(Aportante, 100, '', false, FechaOrden);
        EjecutarOrden();
        Assert(ImporteOrden(Monetario) = 1, 'El cero de la condición descartada sigue siendo un resultado consumido.');
        Assert(StrPos(MotorOrden.AvisosOrdenCalculados(), Descartado + ' lee') > 0, 'Debe conservar el riesgo de una condición cuyo cero sí se consume.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenBaseDePresentacionNoSeConfundeConImporte()
    var
        Lector: Code[20];
        Aportante: Code[20];
        Linea: Record "Línea Liquidación";
    begin
        InicializarOrden();
        Lector := ConceptoOrden('L1', '7', '', 10, false);
        SeleccionOrden.Get(Lector, FechaOrden);
        SeleccionOrden."Variable Base" := AcumuladorOrden;
        SeleccionOrden.Modify(false);
        Aportante := ConceptoOrden('P1', '9', '', 20, false);
        FraccionOrden(Aportante, 100, '', false, FechaOrden);
        EjecutarOrden();
        Linea.SetRange("No. Liquidación", LiquidacionOrden."No.");
        Linea.SetRange("Cód. Concepto", Lector);
        Linea.FindFirst();
        Assert((Linea.Importe = 7) and (Linea."Base Cálculo" = 100), 'El importe y su base de presentación deben conservarse.');
        Assert(MotorOrden.AvisosOrdenCalculados() = '', 'La base de presentación no calcula el importe constante.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure TrazaConservaContextoMemoYEscalasDelEvaluador()
    var
        Auxiliar: Code[20];
        Valor: Decimal;
    begin
        InicializarOrden();
        Auxiliar := ConceptoOrden('H1', 'TEST_OTRO*2', '', 5, true);
        EvaluadorOrden.Init(ContextoOrden, FechaOrden);
        Assert(EvaluadorOrden.TryEvalFormula('@' + Auxiliar, Valor), 'Debe evaluar la referencia sintética.');
        Assert(Valor = 6, 'La referencia debe utilizar el contexto actual.');
        EvaluadorOrden.SembrarTramoGuardado('TEST_TRAZA', 100, 9);
        MotorOrden.IniciarTrazaConcepto(EvaluadorOrden);
        Assert(EvaluadorOrden.GetParamLog() = '', 'Debe vaciar únicamente la traza.');
        Assert(EvaluadorOrden.TryGetConceptoRefValue(Auxiliar, Valor), 'Debe conservar la memo de la arroba.');
        Assert(Valor = 6, 'El valor memoizado no debe cambiar.');
        Assert(EvaluadorOrden.TryEvalFormula('TEST_OTRO+1', Valor), 'Debe conservar el contexto numérico.');
        Assert(Valor = 4, 'La variable debe conservar su valor.');
        EvaluadorOrden.UsarDatosGuardados();
        Assert(EvaluadorOrden.TryEvalFormula('TRAMO(''TEST_TRAZA'',100)', Valor), 'Debe conservar la escala memoizada.');
        Assert(Valor = 9, 'La escala debe conservar su resultado.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenIncidenciaNoHeredaLecturasDeLaFormulaReemplazada()
    var
        Lector: Code[20];
        Aportante: Code[20];
    begin
        InicializarOrden();
        Lector := ConceptoOrden('L1', AcumuladorOrden, '', 10, false);
        Aportante := ConceptoOrden('P1', '9', '', 20, false);
        FraccionOrden(Aportante, 100, '', false, FechaOrden);
        IncidenciasOrden.Init();
        IncidenciasOrden."No. Liquidación" := LiquidacionOrden."No.";
        IncidenciasOrden."Cód. Concepto" := Lector;
        IncidenciasOrden.Importe := 7;
        IncidenciasOrden.Insert(false);
        EjecutarOrden();
        Assert(ImporteOrden(Lector) = 7, 'La incidencia debe seguir reemplazando a la fórmula.');
        Assert(ContextoOrden.Get(AcumuladorOrden) = 109, 'El aporte conserva su cálculo.');
        Assert(MotorOrden.AvisosOrdenCalculados() = '', 'La fórmula reemplazada no se leyó económicamente.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AcumuladosConservanPrimeraFraccionYFiltros()
    var
        Constructor: Codeunit "Contexto Liquidación";
        Anual: Record "Variable Sistema Liq.";
        Periodo: Record "Variable Sistema Liq.";
        Actual: Record "Liquidación";
        Linea: Record "Línea Liquidación";
        Prefijo: Code[15];
        ImporteAntes: Decimal;
        LineasAntes: Integer;
    begin
        PrepararAcumulados(Constructor, Anual, Periodo, Actual, Prefijo);
        InsertarLineaAcumulado(Actual."No.", 1, Actual."No. Empleado", Actual."Cód. Período",
            Actual."Fecha Liquidación", Prefijo + 'A', 5.5, "Estado Liq."::Calculada);
        InsertarLineaAcumulado(Actual."No.", 2, Actual."No. Empleado", Actual."Cód. Período",
            Actual."Fecha Liquidación", Prefijo + 'B', 1.25, "Estado Liq."::Calculada);
        Linea.SetRange("No. Empleado", Actual."No. Empleado");
        Linea.CalcSums(Importe);
        ImporteAntes := Linea.Importe;
        LineasAntes := Linea.Count();

        // Estas lecturas históricas cuentan cada concepto una vez, con el primer signo por K2.
        // No son la distribución corriente, que selecciona la última fracción vigente.
        // Año: (120,125 - 20,125 + 80,25 + 5,5) - (30,375 + 10,125 + 1,25) = 144.
        Assert(Constructor.ComputeVariableSistema(Anual) = 144,
            'El anual debe conservar la primera fracción por concepto, sus signos y la ventana del año.');
        // Período: (120,125 - 20,125) - 30,375 = 69,625; no incluye la liquidación actual.
        Assert(Constructor.ComputeVariableSistema(Periodo) = 69.625,
            'El período debe excluir la liquidación actual y los otros períodos, sin repetir conceptos.');
        Assert(Constructor.ComputeVariableSistema(Anual) = 144, 'La lectura desde caché debe conservar el anual.');
        Assert(Constructor.ComputeVariableSistema(Periodo) = 69.625, 'La lectura desde caché debe conservar el período.');
        Linea.CalcSums(Importe);
        Assert((Linea.Importe = ImporteAntes) and (Linea.Count() = LineasAntes),
            'Leer acumulados no debe modificar los importes ni las líneas originales.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AcumuladosRenovadosIncluyenPropiaSoloEnAnual()
    var
        Constructor: Codeunit "Contexto Liquidación";
        Anual: Record "Variable Sistema Liq.";
        Periodo: Record "Variable Sistema Liq.";
        Actual: Record "Liquidación";
        Prefijo: Code[15];
    begin
        PrepararAcumulados(Constructor, Anual, Periodo, Actual, Prefijo);
        Assert(Constructor.ComputeVariableSistema(Anual) = 139.75, 'El anual inicial sólo tiene historia.');
        Assert(Constructor.ComputeVariableSistema(Periodo) = 69.625, 'El período inicial sólo tiene otros recibos.');

        InsertarLineaAcumulado(Actual."No.", 1, Actual."No. Empleado", Actual."Cód. Período",
            Actual."Fecha Liquidación", Prefijo + 'A', 15.125, "Estado Liq."::Calculada);
        InsertarLineaAcumulado(Actual."No.", 2, Actual."No. Empleado", Actual."Cód. Período",
            Actual."Fecha Liquidación", Prefijo + 'B', 2.25, "Estado Liq."::Calculada);
        Assert(Constructor.ComputeVariableSistema(Anual) = 139.75,
            'Antes de invalidar debe conservarse la instantánea que ya leyó el contexto.');
        // Contrato del contexto: quien vuelve a pedir acumulados después de escribir debe invalidar.
        Constructor.InvalidarAcumulados();
        Assert(Constructor.ComputeVariableSistema(Anual) = 152.625,
            'Al renovar, el anual debe sumar lo que la liquidación lleva escrito aunque la cabecera esté en Borrador.');
        Assert(Constructor.ComputeVariableSistema(Periodo) = 69.625,
            'El período debe seguir excluyendo las nuevas líneas Calculadas de la liquidación actual.');

        InsertarLineaAcumulado(Actual."No.", 3, Actual."No. Empleado", Actual."Cód. Período",
            Actual."Fecha Liquidación", Prefijo + 'A', -4.5, "Estado Liq."::Calculada);
        Constructor.InvalidarAcumulados();
        Assert(Constructor.ComputeVariableSistema(Anual) = 148.125,
            'Una segunda renovación debe incluir la nueva línea negativa sin repetir el histórico.');
        Assert(Constructor.ComputeVariableSistema(Periodo) = 69.625,
            'La evolución de la liquidación propia no debe cambiar lo ya liquidado por otros recibos.');
    end;

    local procedure PrepararAcumulados(var Constructor: Codeunit "Contexto Liquidación"; var Anual: Record "Variable Sistema Liq."; var Periodo: Record "Variable Sistema Liq."; var Actual: Record "Liquidación"; var Prefijo: Code[15])
    var
        OtroPeriodo: Code[10];
        Acumulador: Code[20];
    begin
        Prefijo := 'T' + CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 14);
        Actual.Init();
        Actual."No." := Prefijo + 'ACT';
        Actual."No. Empleado" := Prefijo + 'EMP';
        Actual."Cód. Período" := CopyStr(Prefijo, 1, 10);
        Actual."Fecha Liquidación" := DMY2Date(31, 1, 2020);
        Actual.Estado := Actual.Estado::Borrador;
        Actual.Insert(false);
        OtroPeriodo := CopyStr(Prefijo, 1, 9) + 'X';
        Acumulador := Prefijo + 'AC';

        // Insertar desordenadas obliga a respetar K2 y no el orden de inserción.
        InsertarFraccionAcumulado(Acumulador, Prefijo + 'A', DMY2Date(15, 1, 2020), true);
        InsertarFraccionAcumulado(Acumulador, Prefijo + 'A', DMY2Date(1, 1, 2020), false);
        InsertarFraccionAcumulado(Acumulador, Prefijo + 'B', DMY2Date(20, 1, 2020), false);
        InsertarFraccionAcumulado(Acumulador, Prefijo + 'B', DMY2Date(5, 1, 2020), true);
        InsertarFraccionAcumulado(Acumulador, Prefijo + 'F', DMY2Date(1, 2, 2020), false);
        InsertarFraccionAcumulado(Prefijo + 'OT', Prefijo + 'X', DMY2Date(1, 1, 2020), false);

        InsertarLineaAcumulado(Prefijo + 'HIS', 1, Actual."No. Empleado", Actual."Cód. Período", DMY2Date(10, 1, 2020), Prefijo + 'A', 120.125, "Estado Liq."::Calculada);
        InsertarLineaAcumulado(Prefijo + 'HIS', 2, Actual."No. Empleado", Actual."Cód. Período", DMY2Date(10, 1, 2020), Prefijo + 'A', -20.125, "Estado Liq."::Calculada);
        InsertarLineaAcumulado(Prefijo + 'HIS', 3, Actual."No. Empleado", Actual."Cód. Período", DMY2Date(10, 1, 2020), Prefijo + 'B', 30.375, "Estado Liq."::Calculada);
        InsertarLineaAcumulado(Prefijo + 'HIS', 4, Actual."No. Empleado", Actual."Cód. Período", DMY2Date(10, 1, 2020), Prefijo + 'F', 1000, "Estado Liq."::Calculada);
        InsertarLineaAcumulado(Prefijo + 'HIS', 5, Actual."No. Empleado", Actual."Cód. Período", DMY2Date(10, 1, 2020), Prefijo + 'X', 2000, "Estado Liq."::Calculada);
        InsertarLineaAcumulado(Prefijo + 'OTR', 1, Actual."No. Empleado", OtroPeriodo, DMY2Date(8, 1, 2020), Prefijo + 'A', 80.25, "Estado Liq."::Aprobada);
        InsertarLineaAcumulado(Prefijo + 'OTR', 2, Actual."No. Empleado", OtroPeriodo, DMY2Date(8, 1, 2020), Prefijo + 'B', 10.125, "Estado Liq."::Aprobada);
        InsertarLineaAcumulado(Prefijo + 'ANT', 1, Actual."No. Empleado", OtroPeriodo, DMY2Date(31, 12, 2019), Prefijo + 'A', 5000.5, "Estado Liq."::Contabilizada);
        InsertarLineaAcumulado(Prefijo + 'FUT', 1, Actual."No. Empleado", OtroPeriodo, DMY2Date(1, 2, 2020), Prefijo + 'A', 6000.5, "Estado Liq."::Calculada);
        InsertarLineaAcumulado(Prefijo + 'BOR', 1, Actual."No. Empleado", Actual."Cód. Período", DMY2Date(10, 1, 2020), Prefijo + 'A', 9000.5, "Estado Liq."::Borrador);
        InsertarLineaAcumulado(Prefijo + 'AJE', 1, Prefijo + 'AJ', Actual."Cód. Período", DMY2Date(10, 1, 2020), Prefijo + 'A', 8000.5, "Estado Liq."::Calculada);

        Anual.Init();
        Anual."Cód. Cálculo" := 'YTD_ACUM';
        Anual."Cód. Acumulador" := Acumulador;
        Periodo.Init();
        Periodo."Cód. Cálculo" := 'PERIODO_ACUM';
        Periodo."Cód. Acumulador" := Acumulador;
        // Sin tipo conserva el alcance histórico completo del período; no depende de tipos reales.
        Constructor.Init(Actual."No. Empleado", '', Actual."Cód. Período", Actual."Fecha Liquidación",
            '', '', Actual."No.", '', DMY2Date(1, 1, 2020));
    end;

    local procedure InsertarFraccionAcumulado(Acumulador: Code[20]; Concepto: Code[20]; Desde: Date; Invertir: Boolean)
    var
        Fraccion: Record "Fracción Acumulador";
    begin
        Fraccion."Cód. Concepto" := Concepto;
        Fraccion."Cód. Acumulador" := Acumulador;
        Fraccion."Vigencia Desde" := Desde;
        Fraccion.Porcentaje := 100;
        Fraccion."Invertir Signo" := Invertir;
        Fraccion.Insert(false);
    end;

    local procedure InsertarLineaAcumulado(Numero: Code[20]; NumeroLinea: Integer; Empleado: Code[20]; Periodo: Code[10]; Fecha: Date; Concepto: Code[20]; Importe: Decimal; Estado: Enum "Estado Liq.")
    var
        Cabecera: Record "Liquidación";
        Linea: Record "Línea Liquidación";
    begin
        if not Cabecera.Get(Numero) then begin
            Cabecera.Init();
            Cabecera."No." := Numero;
            Cabecera."No. Empleado" := Empleado;
            Cabecera."Cód. Período" := Periodo;
            Cabecera."Fecha Liquidación" := Fecha;
            Cabecera.Estado := Estado;
            Cabecera.Insert(false);
        end;
        Linea."No. Liquidación" := Numero;
        Linea."No. Línea" := NumeroLinea;
        Linea."No. Empleado" := Empleado;
        Linea."Cód. Período" := Periodo;
        Linea."Fecha Liquidación" := Fecha;
        Linea."Cód. Concepto" := Concepto;
        Linea.Importe := Importe;
        Linea.Estado := Estado;
        Linea.Insert(false);
    end;

    local procedure InicializarOrden()
    var
        Acumulador: Record "Concepto Liquidación";
    begin
        Clear(MotorOrden);
        Clear(ConstructorOrden);
        Clear(EvaluadorOrden);
        Clear(ContextoOrden);
        SeleccionOrden.Reset();
        SeleccionOrden.DeleteAll();
        IncidenciasOrden.Reset();
        IncidenciasOrden.DeleteAll();
        PrefijoOrden := 'T' + CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 14);
        FechaOrden := DMY2Date(15, 1, 2020);
        LiquidacionOrden.Init();
        LiquidacionOrden."No." := PrefijoOrden + 'LIQ';
        LiquidacionOrden."Cód. Período" := 'T_ORDEN';
        LiquidacionOrden."Cód. Tipo Liq." := 'T_ORDEN';
        LiquidacionOrden."Cód. Convenio" := 'T_ORDEN_CCT';
        LiquidacionOrden."Fecha Liquidación" := FechaOrden;
        LiquidacionOrden.Insert(false);
        AcumuladorOrden := PrefijoOrden + 'AC';
        Acumulador.Init();
        Acumulador.Código := AcumuladorOrden;
        Acumulador."Vigencia Desde" := FechaOrden;
        Acumulador.Activo := true;
        Acumulador."Es Acumulador" := true;
        Acumulador."Tipo Concepto" := Acumulador."Tipo Concepto"::Informativo;
        Acumulador.Insert(false);
        ContextoOrden.Add(AcumuladorOrden, 100);
        ContextoOrden.Add('TEST_OTRO', 3);
    end;

    local procedure ConceptoOrden(Sufijo: Code[3]; Formula: Text; Condicion: Text; Orden: Integer; Informativo: Boolean): Code[20]
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Concepto.Init();
        Concepto.Código := PrefijoOrden + Sufijo;
        Concepto."Vigencia Desde" := FechaOrden;
        Concepto.Activo := true;
        Concepto."Orden Cálculo" := Orden;
        Concepto."Fórmula Orden Cálculo" := Format(Orden, 0, 9);
        Concepto.Fórmula := CopyStr(Formula, 1, MaxStrLen(Concepto.Fórmula));
        Concepto.Condición := CopyStr(Condicion, 1, MaxStrLen(Concepto.Condición));
        Concepto."Tipos Liq. Aplicables" := 'T_ORDEN';
        if Informativo then
            Concepto."Tipo Concepto" := Concepto."Tipo Concepto"::Informativo;
        Concepto.Insert(false);
        SeleccionOrden := Concepto;
        SeleccionOrden.Insert(false);
        ContextoOrden.Add(Concepto.Código, 0);
        exit(Concepto.Código);
    end;

    local procedure FraccionOrden(Codigo: Code[20]; Porcentaje: Decimal; Filtro: Text; Invertir: Boolean; Desde: Date)
    var
        Fraccion: Record "Fracción Acumulador";
    begin
        Fraccion.Init();
        Fraccion."Cód. Concepto" := Codigo;
        Fraccion."Cód. Acumulador" := AcumuladorOrden;
        Fraccion."Vigencia Desde" := Desde;
        Fraccion.Porcentaje := Porcentaje;
        Fraccion."Filtro Convenio" := CopyStr(Filtro, 1, MaxStrLen(Fraccion."Filtro Convenio"));
        Fraccion."Invertir Signo" := Invertir;
        Fraccion.Insert(false);
    end;

    local procedure AcumuladorAdicionalOrden(Sufijo: Code[3]): Code[20]
    var
        Acumulador: Record "Concepto Liquidación";
    begin
        Acumulador.Init();
        Acumulador.Código := PrefijoOrden + Sufijo;
        Acumulador."Vigencia Desde" := FechaOrden;
        Acumulador.Activo := true;
        Acumulador."Es Acumulador" := true;
        Acumulador."Tipo Concepto" := Acumulador."Tipo Concepto"::Informativo;
        Acumulador.Insert(false);
        ContextoOrden.Add(Acumulador.Código, 0);
        exit(Acumulador.Código);
    end;

    local procedure FraccionADestinoOrden(Codigo: Code[20]; Destino: Code[20])
    var
        Fraccion: Record "Fracción Acumulador";
    begin
        Fraccion.Init();
        Fraccion."Cód. Concepto" := Codigo;
        Fraccion."Cód. Acumulador" := Destino;
        Fraccion."Vigencia Desde" := FechaOrden;
        Fraccion.Porcentaje := 100;
        Fraccion.Insert(false);
    end;

    local procedure EjecutarOrden()
    var
        TipoEmpleado: Enum "Aplica A Liq.";
    begin
        MotorOrden.PrepararControlOrden(FechaOrden);
        EvaluadorOrden.Init(ContextoOrden, FechaOrden);
        SeleccionOrden.SetCurrentKey("Orden Cálculo", Código);
        MotorOrden.RecorrerConceptosSeleccionados(LiquidacionOrden, FechaOrden, ContextoOrden,
            ConstructorOrden, EvaluadorOrden, SeleccionOrden, IncidenciasOrden, TipoEmpleado::Todos);
    end;

    local procedure ImporteOrden(Codigo: Code[20]): Decimal
    var
        Linea: Record "Línea Liquidación";
    begin
        Linea.SetRange("No. Liquidación", LiquidacionOrden."No.");
        Linea.SetRange("Cód. Concepto", Codigo);
        Linea.CalcSums(Importe);
        exit(Linea.Importe);
    end;

    local procedure PrepararEntradaInformativa(var Concepto: Record "Concepto Liquidación"; var Fuente: Record "Fuente Datos Liquidación"; var Incidencia: Record "Incidencia Liquidación"; var Ctx: Dictionary of [Text, Decimal])
    var
        Filtro: Record "Filtro Fuente Datos Liq.";
        Novedad: Record "Novedad Liquidación";
        Codigo: Code[20];
    begin
        Codigo := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20);
        Concepto.Código := Codigo;
        Concepto."Vigencia Desde" := DMY2Date(1, 2, 2026);
        Concepto."Tipo Concepto" := Concepto."Tipo Concepto"::Informativo;
        Concepto.Insert(false);
        Fuente."Nombre Variable" := 'TIND_' + Codigo;
        Fuente.Activo := true;
        Fuente."Id. Tabla" := Database::"Novedad Liquidación";
        Fuente."No. Campo Valor" := Novedad.FieldNo(Cantidad);
        Fuente."Tipo Dato" := Fuente."Tipo Dato"::Decimal;
        Fuente."Función Agregado" := Fuente."Función Agregado"::SUM;
        Fuente.Insert(false);
        Filtro."Nombre Variable" := Fuente."Nombre Variable";
        Filtro."No. Línea" := 1;
        Filtro."No. Campo" := Novedad.FieldNo("No. Empleado");
        Filtro."Filtro Valor" := '{EMP_NO}';
        Filtro.Insert(false);
        Filtro."No. Línea" := 2;
        Filtro."No. Campo" := Novedad.FieldNo("Cód. Concepto");
        Filtro."Filtro Valor" := Codigo;
        Filtro.Insert(false);
        Filtro."No. Línea" := 3;
        Filtro."No. Campo" := Novedad.FieldNo("Cód. Período");
        Filtro."Filtro Valor" := '{PERIODO}';
        Filtro.Insert(false);
        Ctx.Add(Fuente."Nombre Variable", 1);
        Incidencia."Cód. Concepto" := Codigo;
        Incidencia."Desde Novedad" := true;
        Incidencia.Cantidad := 1;
    end;

    local procedure Assert(Condicion: Boolean; Mensaje: Text)
    begin
        if not Condicion then
            Error(Mensaje);
    end;

    var
        MotorOrden: Codeunit "Motor Liquidación";
        ConstructorOrden: Codeunit "Contexto Liquidación";
        EvaluadorOrden: Codeunit "Evaluador Fórmula";
        ContextoOrden: Dictionary of [Text, Decimal];
        LiquidacionOrden: Record "Liquidación";
        SeleccionOrden: Record "Concepto Liquidación" temporary;
        IncidenciasOrden: Record "Incidencia Liquidación" temporary;
        PrefijoOrden: Code[15];
        AcumuladorOrden: Code[20];
        FechaOrden: Date;

}
