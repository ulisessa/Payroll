namespace UAS.Payroll;

codeunit 110056 "Test Detalle Calculo"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure HistoricoDistingueReferenciasYNoConsultaConceptos()
    var
        Eval: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Valor: Decimal;
    begin
        Ctx.Add('@TEST', 120);
        Ctx.Add('#TEST', 20);
        Eval.Init(Ctx, Today());
        Eval.UsarDatosGuardados();
        Assert(Eval.TryEvalFormula('(@TEST - #TEST) * 2 / 4', Valor), 'Debe usar los valores históricos sin consultar conceptos.');
        Assert(Valor = 50, 'Los prefijos @ y # deben conservar valores independientes.');
        Assert(not Eval.TryEvalFormula('AUSENTE + 1', Valor), 'Una variable no guardada no puede reemplazarse por cero.');
    end;

    [Test]
    procedure EscalaHistoricaConservaBasesDistintas()
    var
        Eval: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Valor: Decimal;
    begin
        Eval.Init(Ctx, Today());
        Eval.UsarDatosGuardados();
        Eval.SembrarTramoGuardado('TEST_SIN_TABLA', 100, 7);
        Eval.SembrarTramoGuardado('TEST_SIN_TABLA', 200, 19);
        Assert(Eval.TryEvalFormula('TRAMO(''TEST_SIN_TABLA'',200)-TRAMO(''TEST_SIN_TABLA'',100)', Valor), 'Debe reconstruir sin ninguna tabla vigente.');
        Assert(Valor = 12, 'Cada base debe conservar su resultado.');
        Assert(not Eval.TryEvalFormula('TRAMO(''TEST_SIN_TABLA'',300)', Valor), 'No debe inventar la escala de otra base.');
    end;

    [Test]
    procedure ReconstruccionSeparaBaseYRetenciones()
    var
        Liq: Record "Liquidación";
        Linea: Record "Línea Liquidación";
        Pasos: Record "Paso Cálculo Línea" temporary;
        Motor: Codeunit "Motor Liquidación";
        Constructor: Codeunit "Detalle Cálculo Línea";
        Eval: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        HayBase: Boolean;
        HayRetenciones: Boolean;
    begin
        Liq."No." := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20);
        Liq."Fecha Liquidación" := Today();
        Liq.Insert();
        Linea."No. Liquidación" := Liq."No.";
        Linea."No. Línea" := 1;
        Linea."Fórmula Aplicada" := 'TRAMO(''T'', A-B)-(C+D)';
        Linea.Importe := 8;
        Ctx.Add('A', 200);
        Ctx.Add('B', 100);
        Ctx.Add('C', 3);
        Ctx.Add('D', 4);
        Eval.Init(Ctx, Today());
        Motor.WriteVariableDetail(Liq."No.", 1, 'VAR:A|VAR:B|VAR:C|VAR:D|TRAMO:T~15~escala conservada~100~50~10~10~2026-01-01', Ctx, Eval);
        Constructor.Construir(Linea, Pasos);
        Assert(Pasos.FindLast(), 'Debe generar el detalle.');
        Assert(Pasos."Es Total" and (Pasos.Valor = 8), 'Debe comprobar el importe histórico.');
        Pasos.FindSet();
        repeat
            if Pasos.Término = 'B' then
                HayBase := Pasos."Es Base Escala";
            if Pasos.Término = 'D' then
                HayRetenciones := not Pasos."Es Base Escala";
        until Pasos.Next() = 0;
        Assert(HayBase and HayRetenciones, 'Una resta anidada de retenciones no pertenece a la base imponible.');
    end;

    [Test]
    procedure EscalaAntiguaNoProduceTotalFalso()
    var
        Liq: Record "Liquidación";
        Linea: Record "Línea Liquidación";
        Pasos: Record "Paso Cálculo Línea" temporary;
        Constructor: Codeunit "Detalle Cálculo Línea";
    begin
        Liq."No." := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20);
        Liq."Fecha Liquidación" := Today();
        Liq.Insert();
        Linea."No. Liquidación" := Liq."No.";
        Linea."Fórmula Aplicada" := 'TRAMO(''HISTORICO'',100)';
        Constructor.Construir(Linea, Pasos);
        Assert(Pasos.FindFirst(), 'Debe explicar por qué no se puede comprobar.');
        Assert(not Pasos."Es Total", 'No debe presentar cero como un resultado comprobado.');
        Assert(StrPos(Pasos.Descripción, 'No comprobado:') = 1, 'Debe advertir que falta evidencia histórica.');
    end;

    [Test]
    procedure CondicionUsaCodigoGuardadoSinConsultarCatalogo()
    var
        Eval: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Codigos: Dictionary of [Text, Text];
        Valor: Decimal;
    begin
        Ctx.Add('ATR_TEST', 1);
        Codigos.Add('ATR_TEST', 'HISTORICO');
        Eval.Init(Ctx, Today());
        Eval.UsarDatosGuardados();
        Eval.SetCodigosAtributos(Codigos);
        Assert(Eval.TryEvalFormula('IF(ATR_TEST = ''HISTORICO'', 25, 0)', Valor), 'Debe evaluar el código guardado aunque no exista en el catálogo actual.');
        Assert(Valor = 25, 'Debe elegir la rama correspondiente al código histórico.');
        Clear(Codigos);
        Eval.SetCodigosAtributos(Codigos);
        Assert(not Eval.TryEvalFormula('IF(ATR_TEST = ''HISTORICO'', 25, 0)', Valor), 'Un código no conservado no debe producir un falso cero.');
    end;

    [Test]
    procedure GananciasHistoricaSinEtiquetaSeReconocePorEscala()
    var
        Linea: Record "Línea Liquidación";
        Presentacion: Codeunit "Presentación Cálculo Liq.";
    begin
        Linea."Cód. Concepto" := 'TEST-HISTORICO';
        Linea."No. Liquidación" := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20);
        Linea."Fórmula Aplicada" := 'round(MAX(TRAMO( ''TAB_IMP_4CAT'', 100),0),0.01)';
        Assert(Presentacion.EsGanancias(Linea), 'La escala fiscal debe abrir Ganancias aunque no exista etiqueta ni snapshot.');
        Linea."Fórmula Aplicada" := 'TRAMO(''OTRA_TABLA'',100)';
        Assert(not Presentacion.EsGanancias(Linea), 'Una escala de usuario debe conservar la vista de fórmulas.');
    end;

    [Test]
    procedure GananciasPorVariableConParentesisYSufijo()
    var
        Linea: Record "Línea Liquidación";
        Variable: Record "Detalle Variable Línea Liq.";
        Presentacion: Codeunit "Presentación Cálculo Liq.";
    begin
        Linea."Cód. Concepto" := 'TEST-HISTORICO';
        Linea."No. Liquidación" := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20);
        Linea."No. Línea" := 1;
        Linea."Fórmula Aplicada" := '100';
        Assert(not Presentacion.EsGanancias(Linea), 'Sin evidencia fiscal debe abrir el detalle genérico sin error.');
        Variable."No. Liquidación" := Linea."No. Liquidación";
        Variable."No. Línea" := 1;
        Variable."Nombre Variable" := 'TRAMO(TAB_IMP_4CAT) #2';
        Variable.Insert();
        Assert(Presentacion.EsGanancias(Linea), 'Debe reconocer el nombre literal con paréntesis y sufijo.');
        Linea."No. Línea" := 2;
        Assert(not Presentacion.EsGanancias(Linea), 'La evidencia de otra línea no debe cambiar la vista.');
        Variable.Init();
        Variable."No. Liquidación" := Linea."No. Liquidación";
        Variable."No. Línea" := 2;
        Variable."Nombre Variable" := 'TRAMO(TAB_IMP_4CAT_OTRA)';
        Variable.Insert();
        Assert(not Presentacion.EsGanancias(Linea), 'Una tabla con nombre parecido no es la escala fiscal.');
    end;

    [Test]
    procedure OrdenAlternativoRespetaTipoYConvenio()
    var
        Motor: Codeunit "Motor Liquidación";
        Concepto: Record "Concepto Liquidación" temporary;
    begin
        PrepararCatalogosValidadorOrden();
        Concepto."Orden Cálculo" := 455;
        Concepto."Fórmula Orden Cálculo" := 'IF(TIPO_LIQ = ''LIQ_FINAL'' AND CONVENIO = ''372/04'', 667, ORDEN_BASE)';
        Assert(Motor.OrdenEfectivo(Concepto, 'LIQ_FINAL', '372/04') = 667, 'La final del convenio indicado debe usar el orden alternativo.');
        Assert(Motor.OrdenEfectivo(Concepto, 'REGULAR', '372/04') = 455, 'La regular debe conservar el orden de las vacaciones gozadas.');
        Assert(Motor.OrdenEfectivo(Concepto, 'LIQ_FINAL', '729/15') = 455, 'Los demás convenios deben conservar el orden del SAC y sus consumidores.');
        Concepto."Fórmula Orden Cálculo" := 'IF(TIPO_LIQ = ''LIQ_FINAL'', 667, ORDEN_BASE)';
        Assert(Motor.OrdenEfectivo(Concepto, 'LIQ_FINAL', '729/15') = 667, 'Un convenio alternativo vacío aplica a todos los del tipo.');
        Concepto."Fórmula Orden Cálculo" := '';
        Assert(Motor.OrdenEfectivo(Concepto, 'LIQ_FINAL', '372/04') = 455, 'Sin tipo configurado no debe cambiar el comportamiento histórico.');
    end;

    [Test]
    procedure AtributosFinalNoSeLeenDespuesDeLaBaja()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Tipo: Enum "Tipo Entidad Estado";
        Fecha: Date;
        Baja: Date;
    begin
        Fecha := DMY2Date(31, 1, 2026);
        Baja := DMY2Date(24, 1, 2026);
        Assert(Ctx.FechaAtributosDeCobertura('LIQ_FINAL', Tipo::Empleado, Fecha, Baja) = Baja, 'Un atributo cerrado en la baja debe estar disponible en la final.');
        Assert(Ctx.FechaAtributosDeCobertura('REGULAR', Tipo::Empleado, Fecha, Baja) = Fecha, 'Las regulares conservan su fecha habitual.');
        Assert(Ctx.FechaAtributosDeCobertura('LIQ_FINAL', Tipo::Buque, Fecha, Baja) = Fecha, 'El cambio no modifica la fecha del buque.');
        Assert(Ctx.FechaAtributosDeCobertura('LIQ_FINAL', Tipo::Empleado, Fecha, 0D) = Fecha, 'Sin cobertura se conserva la fecha de referencia.');
        Assert(Ctx.FechaAtributosDeCobertura('LIQ_FINAL', Tipo::Empleado, Fecha, DMY2Date(1, 2, 2026)) = Fecha, 'La cobertura nunca habilita leer un atributo futuro.');
    end;

    [Test]
    procedure FormulaOrdenTienePrioridadSobreConfiguracionAnterior()
    var
        Motor: Codeunit "Motor Liquidación";
        Concepto: Record "Concepto Liquidación" temporary;
    begin
        PrepararCatalogosValidadorOrden();
        Concepto."Orden Cálculo" := 455;
        Concepto."Tipo Liq. Orden Alternativo" := 'LIQ_FINAL';
        Concepto."Convenio Orden Alternativo" := '372/04';
        Concepto."Orden Cálculo Alternativo" := 667;
        Assert(Motor.OrdenEfectivo(Concepto, 'LIQ_FINAL', '372/04') = 667, 'La configuración publicada antes debe conservar su comportamiento.');
        Concepto."Fórmula Orden Cálculo" := 'ORDEN_BASE + 10';
        Assert(Motor.OrdenEfectivo(Concepto, 'LIQ_FINAL', '372/04') = 465, 'Una fórmula explícita debe reemplazar la configuración anterior.');
    end;
    [Test]
    procedure OrdenUsaContextoEstableYConservaOtrasModalidades()
    var
        Motor: Codeunit "Motor Liquidación";
        Concepto: Record "Concepto Liquidación" temporary;
        Ctx: Dictionary of [Text, Decimal];
        Codigos: Dictionary of [Text, Text];
        Fecha: Date;
    begin
        Fecha := DMY2Date(18, 2, 2026);
        Concepto.Código := 'TEST_ORDEN';
        Concepto."Orden Cálculo" := 159;
        Concepto."Fórmula Orden Cálculo" := 'IF(APLICA_PROD_FIJO>0 AND TIPOACTIVIDAD=1 AND ES_GROSSING_UP=0,451,ORDEN_BASE)';
        Ctx.Add('APLICA_PROD_FIJO', 1);
        Ctx.Add('TIPOACTIVIDAD', 1);
        Ctx.Add('ES_GROSSING_UP', 0);
        Codigos.Add('CONVENIO', 'ORIGINAL');
        Assert(Motor.OrdenEfectivo(Concepto, 'CIERRE_MAREA', '768/19', Fecha, Ctx, Codigos) = 451, 'La modalidad parametrizada debe correr después del feriado.');
        Assert(Motor.OrdenEfectivo(Concepto, 'DEVENGADOS', '768/19', Fecha, Ctx, Codigos) = 451, 'El mismo flag puede ordenar un devengado habilitado por su fuente.');
        Ctx.Set('APLICA_PROD_FIJO', 0);
        Assert(Motor.OrdenEfectivo(Concepto, 'REGULAR', '768/19', Fecha, Ctx, Codigos) = 159, 'Fuera del alcance de la fuente debe conservar el orden anterior.');
        Assert(Motor.OrdenEfectivo(Concepto, 'CIERRE_MAREA', '729/15', Fecha, Ctx, Codigos) = 159, 'Un convenio fuera del alcance conserva el orden base.');
        Ctx.Set('APLICA_PROD_FIJO', 1);
        Ctx.Set('ES_GROSSING_UP', 1);
        Assert(Motor.OrdenEfectivo(Concepto, 'CIERRE_MAREA', '768/19', Fecha, Ctx, Codigos) = 159, 'Grossing-up conserva el orden anterior.');
        Ctx.Set('ES_GROSSING_UP', 0);
        Ctx.Set('TIPOACTIVIDAD', 2);
        Assert(Motor.OrdenEfectivo(Concepto, 'CIERRE_MAREA', '768/19', Fecha, Ctx, Codigos) = 159, 'Tangoneros conservan el orden anterior.');
        Assert(not Ctx.ContainsKey('ORDEN_BASE'), 'Preparar el orden no debe alterar el contexto del cálculo.');
        Assert(not Ctx.ContainsKey('CONVENIO'), 'Los tokens de compatibilidad deben agregarse a una copia.');
        Assert(Codigos.Get('CONVENIO') = 'ORIGINAL', 'Los códigos del contexto de entrada deben conservarse.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenUsaParametroYCodigoDeAtributoResueltos()
    var
        Motor: Codeunit "Motor Liquidación";
        Concepto: Record "Concepto Liquidación" temporary;
        Tipo: Record "Tipo Atributo Liq.";
        Valor: Record "Valor Atributo Liq.";
        Ctx: Dictionary of [Text, Decimal];
        Codigos: Dictionary of [Text, Text];
    begin
        Tipo.Código := 'TEST_ORD_ATTR';
        Tipo."Nombre Variable" := 'TEST_ORD_ATTR';
        Tipo."Tipo Dato" := Tipo."Tipo Dato"::Lista;
        Tipo.Insert(false);
        Valor."Cód. Tipo Atributo" := Tipo.Código;
        Valor.Código := 'CAL';
        Valor.Insert(false);
        Concepto."Orden Cálculo" := 159;
        Concepto."Fórmula Orden Cálculo" := 'IF(TEST_ORD_ATTR = ''CAL'', ORDEN_BASE + TEST_ORD_DESPLAZAMIENTO, ORDEN_BASE)';
        Ctx.Add('TEST_ORD_ATTR', 7);
        Ctx.Add('TEST_ORD_DESPLAZAMIENTO', 292);
        Codigos.Add('TEST_ORD_ATTR', 'CAL');
        Assert(Motor.OrdenEfectivo(Concepto, 'CIERRE_MAREA', '768/19', Today(), Ctx, Codigos) = 451, 'El orden debe recibir el parámetro y el código del atributo, no sólo su número.');
        Assert(Ctx.Get('TEST_ORD_DESPLAZAMIENTO') = 292, 'El parámetro resuelto no debe cambiar.');
    end;

    [Test]
    procedure OrdenRechazaReferenciasDeConceptos()
    var
        Motor: Codeunit "Motor Liquidación";
        Concepto: Record "Concepto Liquidación" temporary;
    begin
        Concepto.Código := 'TEST_ORDEN';
        Concepto."Fórmula Orden Cálculo" := 'IF(1,451,#1003)';
        asserterror Motor.OrdenEfectivo(Concepto, 'CIERRE_MAREA', '768/19');
        Assert(StrPos(GetLastErrorText(), '# o @') > 0, 'Una referencia # está prohibida también en una rama no elegida.');
        Concepto."Fórmula Orden Cálculo" := 'IF(1,451,@1003)';
        asserterror Motor.OrdenEfectivo(Concepto, 'CIERRE_MAREA', '768/19');
        Assert(StrPos(GetLastErrorText(), '# o @') > 0, 'Una referencia @ no puede decidir el recorrido.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenRechazaAcumuladorAunqueSeaCeroEnRamaMuerta()
    var
        Motor: Codeunit "Motor Liquidación";
        Acumulador: Record "Concepto Liquidación";
        Concepto: Record "Concepto Liquidación" temporary;
        Ctx: Dictionary of [Text, Decimal];
        Codigos: Dictionary of [Text, Text];
    begin
        Acumulador.Código := 'TEST_ORD_ACUM';
        Acumulador."Vigencia Desde" := DMY2Date(1, 1, 1900);
        Acumulador."Es Acumulador" := true;
        Acumulador.Insert(false);
        Concepto.Código := 'TEST_ORDEN';
        Concepto."Fórmula Orden Cálculo" := 'IF(1,451,TEST_ORD_ACUM)';
        Ctx.Add('TEST_ORD_ACUM', 0);
        asserterror Motor.OrdenEfectivo(Concepto, 'CIERRE_MAREA', '768/19', Today(), Ctx, Codigos);
        Assert(StrPos(GetLastErrorText(), 'TEST_ORD_ACUM') > 0, 'El cero sembrado en el contexto no vuelve estable al acumulador.');
    end;

    [Test]
    procedure OrdenRechazaConsultasDinamicas()
    var
        Motor: Codeunit "Motor Liquidación";
        Concepto: Record "Concepto Liquidación" temporary;
    begin
        Concepto.Código := 'TEST_ORDEN';
        Concepto."Fórmula Orden Cálculo" := 'IF(1,451,ACUM_PARAM_CCT(''FUENTE'',''PARAM'',''DIAS'',30))';
        asserterror Motor.OrdenEfectivo(Concepto, 'CIERRE_MAREA', '768/19');
        Assert(StrPos(GetLastErrorText(), 'ACUM_PARAM_CCT') > 0, 'Las consultas históricas no deben ejecutarse para decidir el orden.');
        Concepto."Fórmula Orden Cálculo" := 'IF(1,451,TRAMO(''TABLA'',100))';
        asserterror Motor.OrdenEfectivo(Concepto, 'CIERRE_MAREA', '768/19');
        Assert(StrPos(GetLastErrorText(), 'TRAMO') > 0, 'Una consulta debe resolverse antes y pasarse como variable estable.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenLiteralNoSeConfundeConCodigoNumerico()
    var
        Motor: Codeunit "Motor Liquidación";
        Otro: Record "Concepto Liquidación";
        Concepto: Record "Concepto Liquidación" temporary;
    begin
        if not Otro.Get('1003', DMY2Date(1, 1, 1900)) then begin
            Otro.Código := '1003';
            Otro."Vigencia Desde" := DMY2Date(1, 1, 1900);
            Otro.Insert(false);
        end;
        Concepto."Fórmula Orden Cálculo" := '1003';
        Assert(Motor.OrdenEfectivo(Concepto, 'CIERRE_MAREA', '768/19') = 1003, 'Un literal numérico es un orden válido aunque coincida con un código de concepto.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AcumParametroCCTGuardaArgumentosYConsultasDistintas()
    var
        Motor: Codeunit "Motor Liquidación";
        Eval: Codeunit "Evaluador Fórmula";
        Det: Record "Detalle Variable Línea Liq.";
        Ctx: Dictionary of [Text, Decimal];
        LiqNo: Code[20];
    begin
        LiqNo := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20);
        Eval.Init(Ctx, Today());
        Motor.WriteVariableDetail(LiqNo, 1,
            'ACUMCCT:TEST_HIST~PRECIO~DIAS~30~10|ACUMCCT:TEST_HIST~PRECIO~DIAS~30~10|ACUMCCT:TEST_HIST~PRECIO~DIAS~60~5', Ctx, Eval);
        Det.SetRange("No. Liquidación", LiqNo);
        Det.SetRange("No. Línea", 1);
        Assert(Det.Count() = 2, 'La misma consulta se guarda una vez; argumentos distintos deben conservar ambos resultados.');
        Assert(Det.Get(LiqNo, 1, 'ACUM_PARAM_CCT(TEST_HIST)'), 'La consulta debe tener un nombre legible.');
        Assert(Det.Valor = 10, 'Debe conservar el importe realmente evaluado.');
        Assert(Det.Detalle = 'ACUMCCT:TEST_HIST~PRECIO~DIAS~30', 'Debe conservar los cuatro argumentos para la reconstrucción histórica.');
        Assert(Det.Get(LiqNo, 1, 'ACUM_PARAM_CCT(TEST_HIST) #2'), 'La segunda consulta debe desambiguarse con un sufijo.');
        Assert(Det.Valor = 5, 'No debe perder el resultado de la consulta con otro divisor.');
        Assert(Det.Detalle = 'ACUMCCT:TEST_HIST~PRECIO~DIAS~60', 'El sufijo no debe reemplazar ni alterar la clave histórica.');
    end;

    [Test]
    procedure AcumParametroCCTHistoricoUsaResultadosGuardados()
    var
        Eval: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Valor: Decimal;
    begin
        Eval.Init(Ctx, Today());
        Eval.UsarDatosGuardados();
        Eval.SembrarAcumParametroCCTGuardado('TEST_SIN_FUENTE', 'TEST_SIN_PARAM', 'TEST_SIN_VAR', 30, 10);
        Eval.SembrarAcumParametroCCTGuardado('TEST_SIN_FUENTE', 'TEST_SIN_PARAM', 'TEST_SIN_VAR', 60, 5);
        Assert(Eval.TryEvalFormula('ACUM_PARAM_CCT(''TEST_SIN_FUENTE'',''TEST_SIN_PARAM'',''TEST_SIN_VAR'',30)+ACUM_PARAM_CCT(''TEST_SIN_FUENTE'',''TEST_SIN_PARAM'',''TEST_SIN_VAR'',60)', Valor), 'Una consulta histórica debe resolverse aunque las fuentes y parámetros no existan hoy.');
        Assert(Valor = 15, 'Cada juego de argumentos debe conservar su importe.');
        Assert(not Eval.TryEvalFormula('ACUM_PARAM_CCT(''TEST_SIN_FUENTE'',''TEST_SIN_PARAM'',''TEST_SIN_VAR'',31)', Valor), 'Un resultado no conservado no debe inventarse ni reconstruirse con la configuración actual.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ControlOrdenResuelveFormulaDinamicaConContexto()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Concepto: Record "Concepto Liquidación" temporary;
        Orden: Integer;
    begin
        PrepararCatalogosControlOrden();
        Concepto."Orden Cálculo" := 470;
        Concepto."Fórmula Orden Cálculo" := 'IF(TIPO_LIQ = ''LIQ_FINAL'' AND CONVENIO = ''372/04'', 668, ORDEN_BASE)';
        Assert(Control.ResolverOrden(Concepto, DMY2Date(28, 2, 2026), 'LIQ_FINAL', '372/04', Orden), 'El contexto completo debe resolver la fórmula de orden.');
        Assert(Orden = 668, 'El control debe usar 668 y no la columna antigua 470.');
        Assert(Control.ResolverOrden(Concepto, DMY2Date(28, 2, 2026), 'REGULAR', '372/04', Orden), 'El contexto regular también debe resolverse.');
        Assert(Orden = 470, 'La rama regular conserva el orden base.');
    end;

    [Test]
    procedure ControlOrdenNoInventaContextoNiParametros()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Concepto: Record "Concepto Liquidación" temporary;
        Orden: Integer;
    begin
        Concepto."Orden Cálculo" := 470;
        Concepto."Fórmula Orden Cálculo" := 'IF(TIPO_LIQ = ''LIQ_FINAL'', 668, ORDEN_BASE)';
        Assert(not Control.ResolverOrden(Concepto, DMY2Date(28, 2, 2026), '', '', Orden), 'Sin tipo no se puede elegir una rama suponiendo un texto vacío.');
        Assert(Orden = 0, 'Una fórmula no resuelta no debe presentarse con el orden numérico antiguo.');
        Concepto."Fórmula Orden Cálculo" := 'IF(TEST_ORDEN_SIN_VALOR > 0, 668, ORDEN_BASE)';
        Assert(not Control.ResolverOrden(Concepto, DMY2Date(28, 2, 2026), 'LIQ_FINAL', '372/04', Orden), 'Un parámetro no proporcionado exige contexto, no cero.');
        Assert(Orden = 0, 'La falta de un parámetro tampoco habilita usar la columna antigua.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ControlOrdenUltimaFraccionCeroAnulaAporte()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Acumulador: Code[20];
        Lector: Code[20];
        Aportante: Code[20];
    begin
        CrearCasoControlOrden(Acumulador, Lector, Aportante);
        CrearFraccionControlOrden(Aportante, Acumulador, DMY2Date(1, 2, 2026), 0, '');
        Control.Analizar(DMY2Date(28, 2, 2026), 'REGULAR', 'TEST_ORD_CCT', '', Buffer);
        Assert(Buffer.Get(Acumulador), 'El acumulador sintético debe figurar en el análisis.');
        Assert(Buffer."Cant. Aportes" = 0, 'Una fracción posterior de cero revoca el aporte anterior de cien.');
        Assert(not Buffer.Conflicto, 'Un aporte revocado no genera conflicto.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ControlOrdenExcluyeTiposMutuamenteExcluyentes()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Lector: Code[20];
        Aportante: Code[20];
    begin
        CrearCasoControlOrden(Acumulador, Lector, Aportante);
        Concepto.Get(Lector, DMY2Date(1, 1, 2026));
        Concepto."Tipos Liq. Aplicables" := 'LIQ_FINAL';
        Concepto.Modify(false);
        Concepto.Get(Aportante, DMY2Date(1, 1, 2026));
        Concepto."Tipos Liq. Aplicables" := 'CIERRE_MAREA|DEVENGADOS|';
        Concepto.Modify(false);
        Control.Analizar(DMY2Date(28, 2, 2026), 'LIQ_FINAL', 'TEST_ORD_CCT', '', Buffer);
        Buffer.Get(Acumulador);
        Assert((Buffer."Cant. Lecturas" = 1) and (Buffer."Cant. Aportes" = 0), 'La final no recibe el aporte exclusivo de devengados y cierres.');
        Assert(not Buffer.Conflicto, 'Los tipos excluyentes no forman una dependencia real.');
        Control.Analizar(DMY2Date(28, 2, 2026), 'DEVENGADOS', 'TEST_ORD_CCT', '', Buffer);
        Buffer.Get(Acumulador);
        Assert((Buffer."Cant. Lecturas" = 0) and (Buffer."Cant. Aportes" = 1), 'En devengados existe el aporte pero no el lector exclusivo de la final.');
        Assert(not Buffer.Conflicto, 'La segunda selección tampoco debe inventar un conflicto.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ControlOrdenRespetaConvenioDelConcepto()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Acumulador: Code[20];
        Lector: Code[20];
        Aportante: Code[20];
    begin
        CrearCasoControlOrden(Acumulador, Lector, Aportante);
        CrearRestriccionControlOrden(Aportante, 'TEST_ORD_CCT_A', '');
        Control.Analizar(DMY2Date(28, 2, 2026), 'REGULAR', 'TEST_ORD_CCT_A', 'GENERAL', Buffer);
        Buffer.Get(Acumulador);
        Assert(Buffer.Conflicto and (Buffer."Cant. Aportes" = 1), 'Dentro del convenio el aporte posterior debe seguir visible.');
        Control.Analizar(DMY2Date(28, 2, 2026), 'REGULAR', 'TEST_ORD_CCT_B', 'GENERAL', Buffer);
        Buffer.Get(Acumulador);
        Assert((Buffer."Cant. Aportes" = 0) and not Buffer.Conflicto, 'El aporte restringido a otro convenio no corresponde a esta corrida.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ControlOrdenRespetaCategoriaDelConcepto()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Acumulador: Code[20];
        Lector: Code[20];
        Aportante: Code[20];
    begin
        CrearCasoControlOrden(Acumulador, Lector, Aportante);
        CrearRestriccionControlOrden(Aportante, 'TEST_ORD_CCT_A', 'CAT_A');
        Control.Analizar(DMY2Date(28, 2, 2026), 'REGULAR', 'TEST_ORD_CCT_A', 'CAT_A', Buffer);
        Buffer.Get(Acumulador);
        Assert(Buffer.Conflicto, 'La categoría incluida debe conservar el diagnóstico del aporte tardío.');
        Control.Analizar(DMY2Date(28, 2, 2026), 'REGULAR', 'TEST_ORD_CCT_A', 'CAT_B', Buffer);
        Buffer.Get(Acumulador);
        Assert((Buffer."Cant. Aportes" = 0) and not Buffer.Conflicto, 'No debe mezclarse un aporte de otra categoría del mismo convenio.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ControlOrdenRespetaFiltroConvenioDeFraccion()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Acumulador: Code[20];
        Lector: Code[20];
        Aportante: Code[20];
    begin
        CrearCasoControlOrden(Acumulador, Lector, Aportante);
        CrearFraccionControlOrden(Aportante, Acumulador, DMY2Date(1, 2, 2026), 100, 'TEST_ORD_CCT_A');
        Control.Analizar(DMY2Date(28, 2, 2026), 'REGULAR', 'TEST_ORD_CCT_A', '', Buffer);
        Buffer.Get(Acumulador);
        Assert(Buffer.Conflicto, 'El convenio incluido en la fracción debe mantener su aporte.');
        Control.Analizar(DMY2Date(28, 2, 2026), 'REGULAR', 'TEST_ORD_CCT_B', '', Buffer);
        Buffer.Get(Acumulador);
        Assert((Buffer."Cant. Aportes" = 0) and not Buffer.Conflicto, 'La última fracción con filtro no puede reemplazarse por la antigua sin filtro.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ControlOrdenSubtotalNoSugiereResolverSuPropioCiclo()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Acumulador: Code[20];
        Lector: Code[20];
        Aportante: Code[20];
    begin
        CrearCasoControlOrden(Acumulador, Lector, Aportante);
        CrearFraccionControlOrden(Lector, Acumulador, DMY2Date(1, 1, 2026), 100, '');
        Control.Analizar(DMY2Date(28, 2, 2026), 'REGULAR', 'TEST_ORD_CCT', '', Buffer);
        Buffer.Get(Acumulador);
        Assert(Buffer.Conflicto, 'Los aportes posteriores deben quedar visibles para revisar la etapa del subtotal.');
        Assert(Buffer."Orden Sugerido" = 0, 'Leer y aportar al mismo acumulador no se resuelve colocándose después de todos sus aportes.');
        Assert(Buffer.Observación <> '', 'El control debe explicar el alcance del diagnóstico en vez de afirmar un importe incorrecto.');
    end;

    [Test]
    procedure ControlOrdenTokensNoConfundenTextosNiUnicode()
    var
        Control: Codeunit "Control Orden Acumuladores";
    begin
        Assert(Control.MencionaVariable('#BASE_IG4 + @BASE_IG4', 'BASE_IG4'), 'Los prefijos deben conservar la lectura del acumulador.');
        Assert(not Control.MencionaVariable('IF(TIPO_LIQ = ''BASE_IG4'', 1, 0)', 'BASE_IG4'), 'El nombre dentro de una cadena es un valor, no una lectura.');
        Assert(not Control.MencionaVariable('''Texto con ''''BASE_IG4'''' escapado''', 'BASE_IG4'), 'Las comillas escapadas no deben finalizar la cadena antes de tiempo.');
        Assert(not Control.MencionaVariable('BASE_IG4_EXTRA + OTRA_BASE_IG4', 'BASE_IG4'), 'Un nombre más largo no debe coincidir por substring.');
        Assert(not Control.MencionaVariable('ÁBASE_IG4 + BASE_IG4Ñ', 'BASE_IG4'), 'Las letras Unicode forman parte del identificador.');
    end;

    [Test]
    procedure ControlOrdenFormulaNumericaPrevaleceSobreColumnaAntigua()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Concepto: Record "Concepto Liquidación" temporary;
        Orden: Integer;
    begin
        Concepto."Orden Cálculo" := 999;
        Concepto."Fórmula Orden Cálculo" := '20';
        Assert(Control.ResolverOrden(Concepto, DMY2Date(28, 2, 2026), '', '', Orden), 'Una fórmula literal no necesita contexto.');
        Assert(Orden = 20, 'La fórmula 20 prevalece sobre el número heredado 999.');
        Concepto."Fórmula Orden Cálculo" := 'ORDEN_BASE + 10';
        Assert(Control.ResolverOrden(Concepto, DMY2Date(28, 2, 2026), '', '', Orden), 'ORDEN_BASE proviene del propio concepto y no requiere inventar un contexto.');
        Assert(Orden = 1009, 'El control debe evaluar la expresión y no intentar leerla como un entero literal.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ControlOrdenEmpateUsaCodigoEnAmbosExtremos()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Prefijo: Text;
        Acumulador: Code[20];
        AporteAnterior: Code[20];
        LectorAnterior: Code[20];
        AportePosterior: Code[20];
        LectorPosterior: Code[20];
    begin
        Prefijo := CopyStr(NuevoCodigoControlOrden(), 1, 17);
        Acumulador := Prefijo + 'ACU';
        AporteAnterior := Prefijo + 'AAA';
        LectorAnterior := Prefijo + 'BBB';
        AportePosterior := Prefijo + 'CCC';
        LectorPosterior := Prefijo + 'DDD';
        CrearConceptoControlOrden(Acumulador, 0, '', true);
        CrearConceptoControlOrden(AportePosterior, 20, '100', false);
        CrearConceptoControlOrden(AporteAnterior, 20, '100', false);
        CrearConceptoControlOrden(LectorAnterior, 20, Acumulador, false);
        CrearConceptoControlOrden(LectorPosterior, 20, Acumulador, false);
        CrearFraccionControlOrden(AporteAnterior, Acumulador, DMY2Date(1, 1, 2026), 100, '');
        CrearFraccionControlOrden(AportePosterior, Acumulador, DMY2Date(1, 1, 2026), 100, '');
        Control.Analizar(DMY2Date(28, 2, 2026), 'REGULAR', 'TEST_ORD_CCT', 'GENERAL', Buffer);
        Buffer.Get(Acumulador);
        Assert(Buffer."Concepto Máx. Aporte" = AportePosterior, 'Con órdenes iguales debe elegirse el último código aportante.');
        Assert(Buffer."Concepto Mín. Lectura" = LectorAnterior, 'Con órdenes iguales debe elegirse el primer código lector.');
        Assert(Buffer.Conflicto and (Buffer."Aportes en Conflicto" = 1), 'Sólo el aporte CCC llega después del lector BBB.');
        Concepto.Get(LectorAnterior, DMY2Date(1, 1, 2026));
        Concepto.Fórmula := '';
        Concepto.Modify(false);
        Control.Analizar(DMY2Date(28, 2, 2026), 'REGULAR', 'TEST_ORD_CCT', 'GENERAL', Buffer);
        Buffer.Get(Acumulador);
        Assert(Buffer."Concepto Mín. Lectura" = LectorPosterior, 'Al retirar la lectura BBB queda la lectura DDD.');
        Assert(not Buffer.Conflicto, 'Los dos aportes del mismo orden ya preceden al lector DDD.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ControlOrdenParPuestoNoSeDescartaConParDeCabecera()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Lector: Code[20];
        Aportante: Code[20];
    begin
        CrearCasoControlOrden(Acumulador, Lector, Aportante);
        Concepto.Get(Aportante, DMY2Date(1, 1, 2026));
        Concepto."Par CCT a Usar" := Concepto."Par CCT a Usar"::Puesto;
        Concepto.Modify(false);
        CrearRestriccionControlOrden(Aportante, 'TEST_ORD_OTRO_CCT', 'OTRA_CAT');
        CrearFraccionControlOrden(Aportante, Acumulador, DMY2Date(1, 2, 2026), 100, 'TEST_ORD_OTRO_CCT');
        Control.Analizar(DMY2Date(28, 2, 2026), 'REGULAR', 'TEST_ORD_CCT', 'GENERAL', Buffer);
        Buffer.Get(Acumulador);
        Assert(Buffer."Cant. Aportes" = 1, 'El aporte con par del puesto no se puede excluir por el convenio ni por la categoría de cabecera.');
        Assert(Buffer."Requiere Contexto", 'El filtro de la fracción también necesita el par efectivamente usado por ese concepto.');
        Assert(Buffer.Conflicto and (Buffer."Orden Sugerido" = 0), 'Debe conservarse la revisión pendiente sin inventar un orden corrector.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ControlOrdenValidadorAndOrParentizados()
    var
        Concepto: Record "Concepto Liquidación" temporary;
    begin
        PrepararCatalogosValidadorOrden();
        Concepto.Código := 'TEST_ORD_LOGICO';
        Concepto."Orden Cálculo" := 159;
        // La secuencia AND seguida de '(' es exactamente la que bloqueó las corridas reales.
        Concepto."Fórmula Orden Cálculo" := 'IF((TIPO_LIQ = ''CIERRE_MAREA'' OR TIPO_LIQ = ''DEVENGADOS'') AND (CONVENIO = ''768/19'' OR CONVENIO = ''ESP''), 451, 159)';
        ComprobarOrdenEnMotorYControl(Concepto, 'CIERRE_MAREA', '768/19', 451);
        ComprobarOrdenEnMotorYControl(Concepto, 'DEVENGADOS', 'ESP', 451);
        ComprobarOrdenEnMotorYControl(Concepto, 'REGULAR', '768/19', 159);
        ComprobarOrdenEnMotorYControl(Concepto, 'CIERRE_MAREA', '729/15', 159);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ControlOrdenValidadorNotEspaciosYSaltos()
    var
        Concepto: Record "Concepto Liquidación" temporary;
        Salto: Char;
        Tabulador: Char;
    begin
        PrepararCatalogosValidadorOrden();
        Salto := 10;
        Tabulador := 9;
        Concepto.Código := 'TEST_ORD_ESPACIOS';
        Concepto."Orden Cálculo" := 159;
        Concepto."Fórmula Orden Cálculo" := 'IF(NOT' + Format(Salto) + ' (TIPO_LIQ = ''LIQ_FINAL'') OR' + Format(Tabulador) + ' (CONVENIO = ''ESP'' AND' + Format(Salto) + ' (ORDEN_BASE = 159)), 451, 159)';
        ComprobarOrdenEnMotorYControl(Concepto, 'REGULAR', '768/19', 451);
        ComprobarOrdenEnMotorYControl(Concepto, 'LIQ_FINAL', 'ESP', 451);
        ComprobarOrdenEnMotorYControl(Concepto, 'LIQ_FINAL', '768/19', 159);
        Concepto."Fórmula Orden Cálculo" := 'IF(NOT(TIPO_LIQ = ''LIQ_FINAL'') AND(CONVENIO = ''ESP''), 451, 159)';
        ComprobarOrdenEnMotorYControl(Concepto, 'REGULAR', 'ESP', 451);
        ComprobarOrdenEnMotorYControl(Concepto, 'LIQ_FINAL', 'ESP', 159);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ControlOrdenValidadorLiteralesNoSonFunciones()
    var
        Motor: Codeunit "Motor Liquidación";
        Control: Codeunit "Control Orden Acumuladores";
        Concepto: Record "Concepto Liquidación" temporary;
        Ctx: Dictionary of [Text, Decimal];
        Codigos: Dictionary of [Text, Text];
        Orden: Integer;
    begin
        PrepararCatalogosValidadorOrden();
        CrearListaValidadorOrden('TEST_ORD_TEXTO', 'TEST_ORD_TXT', 'OR''AND');
        CrearListaValidadorOrden('TEST_ORD_TEXTO', 'TEST_ORD_TXT', 'TRAMO(FILA_X)');
        Concepto.Código := 'TEST_ORD_TEXTO';
        Concepto."Orden Cálculo" := 159;
        Ctx.Add('TEST_ORD_TXT', 1);
        Codigos.Add('TEST_ORD_TXT', 'OR''AND');
        Concepto."Fórmula Orden Cálculo" := 'IF(TEST_ORD_TXT = ''OR''''AND'', 451, 159)';
        Assert(Motor.OrdenEfectivo(Concepto, 'REGULAR', 'ESP', DMY2Date(28, 2, 2026), Ctx, Codigos) = 451, 'Las comillas escapadas y AND dentro del literal no son operadores ni funciones.');
        Codigos.Set('TEST_ORD_TXT', 'TRAMO(FILA_X)');
        Concepto."Fórmula Orden Cálculo" := 'IF(TEST_ORD_TXT = ''TRAMO(FILA_X)'', 451, 159)';
        Assert(Motor.OrdenEfectivo(Concepto, 'REGULAR', 'ESP', DMY2Date(28, 2, 2026), Ctx, Codigos) = 451, 'Un literal que nombra una consulta no debe ejecutar ni prohibir esa consulta.');
        Assert(not Control.ResolverOrden(Concepto, DMY2Date(28, 2, 2026), 'REGULAR', 'ESP', Orden), 'El control sin el atributo no puede inventar su código.');
        Assert(Orden = 0, 'La falta de contexto deja el orden sin resolver.');
        CrearListaValidadorOrden('TEST_ORD_CONVENIO', 'CONVENIO', 'OR''AND');
        CrearListaValidadorOrden('TEST_ORD_CONVENIO', 'CONVENIO', 'TRAMO(FILA_X)');
        Concepto."Fórmula Orden Cálculo" := 'IF(CONVENIO = ''OR''''AND'', 451, 159)';
        ComprobarOrdenEnMotorYControl(Concepto, 'REGULAR', 'OR''AND', 451);
        Concepto."Fórmula Orden Cálculo" := 'IF(CONVENIO = ''TRAMO(FILA_X)'', 451, 159)';
        ComprobarOrdenEnMotorYControl(Concepto, 'REGULAR', 'TRAMO(FILA_X)', 451);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ControlOrdenValidadorOnceExpresionesExactas()
    var
        Motor: Codeunit "Motor Liquidación";
        Concepto: Record "Concepto Liquidación" temporary;
        Ctx: Dictionary of [Text, Decimal];
        Codigos: Dictionary of [Text, Text];
        Indice: Integer;
        Esperado: Integer;
    begin
        PrepararCatalogosValidadorOrden();
        PrepararContextoValidadorOrden(Ctx, Codigos);
        for Indice := 1 to 11 do begin
            CargarFormulaOrdenPublicada(Indice, Concepto);
            if Indice <= 3 then
                Esperado := 450
            else
                if Indice <= 8 then
                    Esperado := 451
                else
                    if Indice <= 10 then
                        Esperado := 470
                    else
                        Esperado := 478;
            Assert(Motor.OrdenEfectivo(Concepto, 'CIERRE_MAREA', '768/19', Concepto."Vigencia Desde", Ctx, Codigos) = Esperado, StrSubstNo('La expresión física %1 del plan debe resolver la rama tangonera sin interpretar AND como una función.', Indice));
            if Indice <= 3 then
                Esperado := 470
            else
                if Indice <= 8 then
                    Esperado := 159
                else
                    if Indice <= 10 then
                        Esperado := 686
                    else
                        Esperado := 687;
            Assert(Motor.OrdenEfectivo(Concepto, 'LIQ_FINAL', '768/19', Concepto."Vigencia Desde", Ctx, Codigos) = Esperado, StrSubstNo('La expresión %1 debe conservar su rama final y el parámetro ya resuelto.', Indice));
        end;
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ControlOrdenValidadorOverridesYActividad()
    var
        Motor: Codeunit "Motor Liquidación";
        Concepto: Record "Concepto Liquidación" temporary;
        Ctx: Dictionary of [Text, Decimal];
        Codigos: Dictionary of [Text, Text];
        Indice: Integer;
        Override: Integer;
        Flag: Integer;
        Esperado: Integer;
    begin
        PrepararCatalogosValidadorOrden();
        PrepararContextoValidadorOrden(Ctx, Codigos);
        for Indice := 1 to 8 do begin
            CargarFormulaOrdenPublicada(Indice, Concepto);
            if Indice <= 3 then
                Esperado := 470
            else
                Esperado := 159;
            for Override := 1 to 3 do begin
                Ctx.Set('INC_1534_CANT_CERO', Override mod 2);
                Ctx.Set('INC_1534_IMP_NO_CERO', Override div 2);
                Assert(Motor.OrdenEfectivo(Concepto, 'CIERRE_MAREA', '768/19', Concepto."Vigencia Desde", Ctx, Codigos) = Esperado, 'Cantidad cero, importe informado o ambos deben conservar el ELSE anterior.');
            end;
            Ctx.Set('INC_1534_CANT_CERO', 0);
            Ctx.Set('INC_1534_IMP_NO_CERO', 0);
            Ctx.Set('TIPOACTIVIDAD', 1);
            if Indice <= 3 then
                Esperado := 470
            else
                if Indice = 4 then
                    Esperado := 159
                else
                    if Indice <= 6 then
                        Esperado := 451
                    else
                        Esperado := 471;
            Assert(Motor.OrdenEfectivo(Concepto, 'CIERRE_MAREA', '768/19', Concepto."Vigencia Desde", Ctx, Codigos) = Esperado, 'La actividad potero conserva exactamente la rama anterior de cada vigencia.');
            for Flag := 1 to 4 do begin
                case Flag of
                    1:
                        Ctx.Set('APLICA_PROD_FIJO', 0);
                    2:
                        Ctx.Set('PCT_PROD_CAPECA', 0);
                    3:
                        Ctx.Set('NETO_GU_MAREA', 1);
                    4:
                        Ctx.Set('ES_GROSSING_UP', 1);
                end;
                if Indice <= 3 then
                    Esperado := 470
                else
                    if (Indice >= 7) and (Flag >= 3) then
                        Esperado := 471
                    else
                        Esperado := 159;
                Assert(Motor.OrdenEfectivo(Concepto, 'CIERRE_MAREA', '768/19', Concepto."Vigencia Desde", Ctx, Codigos) = Esperado, 'Los flags 0/1 de la rama original conservan su diferencia entre vigencias.');
                Ctx.Set('APLICA_PROD_FIJO', 1);
                Ctx.Set('PCT_PROD_CAPECA', 1);
                Ctx.Set('NETO_GU_MAREA', 0);
                Ctx.Set('ES_GROSSING_UP', 0);
            end;
            Ctx.Set('TIPOACTIVIDAD', 2);
            Codigos.Set('CATEGORIA', 'GENERAL');
            if Indice <= 3 then
                Esperado := 470
            else
                Esperado := 159;
            Assert(Motor.OrdenEfectivo(Concepto, 'CIERRE_MAREA', 'ESP', Concepto."Vigencia Desde", Ctx, Codigos) = Esperado, 'ESP fuera de FE01/FE03 conserva el orden original.');
            Codigos.Set('CATEGORIA', 'FE03');
            if Indice <= 3 then
                Esperado := 450
            else
                Esperado := 451;
            Assert(Motor.OrdenEfectivo(Concepto, 'DEVENGADOS', 'ESP', Concepto."Vigencia Desde", Ctx, Codigos) = Esperado, 'La segunda categoría permitida también debe recibir la coordinación.');
            Codigos.Set('CATEGORIA', 'FE01');
        end;
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ControlOrdenValidadorParametroSacCeroYUno()
    var
        Motor: Codeunit "Motor Liquidación";
        Concepto: Record "Concepto Liquidación" temporary;
        Ctx: Dictionary of [Text, Decimal];
        Codigos: Dictionary of [Text, Text];
        Convenios: List of [Code[20]];
        Convenio: Code[20];
        Indice: Integer;
        Parametro: Integer;
        Esperado: Integer;
    begin
        PrepararCatalogosValidadorOrden();
        PrepararContextoValidadorOrden(Ctx, Codigos);
        Convenios.Add('175/75');
        Convenios.Add('768/19');
        Convenios.Add('ESP');
        Convenios.Add('372/04');
        Convenios.Add('729/15');
        for Indice := 9 to 11 do begin
            CargarFormulaOrdenPublicada(Indice, Concepto);
            foreach Convenio in Convenios do
                for Parametro := 0 to 1 do begin
                    Ctx.Set('ORDEN_SAC_TARDIO', Parametro);
                    if (Parametro = 0) and (Convenio in ['175/75', '768/19', 'ESP']) then begin
                        if Indice <= 10 then
                            Esperado := 470
                        else
                            Esperado := 669;
                    end else
                        if Indice <= 10 then
                            Esperado := 686
                        else
                            Esperado := 687;
                    Assert(Motor.OrdenEfectivo(Concepto, 'LIQ_FINAL', Convenio, DMY2Date(1, 2, 2026), Ctx, Codigos) = Esperado, 'El parámetro resuelto debe preservar la excepción marina sin afectar los demás convenios.');
                    if Indice = 11 then
                        Esperado := 478;
                    Assert(Motor.OrdenEfectivo(Concepto, 'RELIQUIDACION', Convenio, DMY2Date(2, 2, 2026), Ctx, Codigos) = Esperado, 'RELIQUIDACION usa la rama tardía de 3813 y conserva la rama ajena de 3814.');
                    if Indice <= 10 then
                        Esperado := 470
                    else
                        Esperado := 478;
                    Assert(Motor.OrdenEfectivo(Concepto, 'SALDO_INICIAL', Convenio, DMY2Date(2, 2, 2026), Ctx, Codigos) = Esperado, 'SALDO_INICIAL conserva el orden histórico con cualquiera de los valores del parámetro.');
                end;
        end;
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ControlOrdenValidadorNoInventaLasFuentesReales()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Concepto: Record "Concepto Liquidación" temporary;
        Indice: Integer;
        Orden: Integer;
    begin
        PrepararCatalogosValidadorOrden();
        for Indice := 1 to 11 do begin
            CargarFormulaOrdenPublicada(Indice, Concepto);
            Orden := 123;
            Assert(not Control.ResolverOrden(Concepto, Concepto."Vigencia Desde", 'LIQ_FINAL', '768/19', Orden), 'El diagnóstico sin actividad, categoría, incidencias ni parámetro no puede inventar esos datos, ni siquiera en una rama no elegida.');
            Assert(Orden = 0, 'Un orden desconocido no debe presentarse como el número base.');
        end;
    end;

    [Test]
    procedure ControlOrdenValidadorRechazaValoresDeRecorrido()
    var
        Referencias: List of [Text];
        Referencia: Text;
    begin
        ExigirEmpresaValidadorOrden();
        Referencias.Add('#1003');
        Referencias.Add('@1003');
        Referencias.Add('FILA_EMPLEADO');
        Referencias.Add('CANT_INCIDENCIA');
        Referencias.Add('COMPLEMENTO_GU');
        foreach Referencia in Referencias do
            ComprobarRechazoValidadorOrden('IF(1,451,' + Referencia + ')', Referencia);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ControlOrdenValidadorRechazaConceptoYAcumulador()
    var
        Concepto: Record "Concepto Liquidación";
        Indice: Integer;
        Codigo: Code[20];
    begin
        ExigirEmpresaValidadorOrden();
        for Indice := 1 to 2 do begin
            if Indice = 1 then
                Codigo := 'TEST_ORD_DEP'
            else
                Codigo := 'TEST_ORD_ACUM';
            // AssertError puede revertir la fixture: cada rechazo tiene su propio origen sintético.
            if not Concepto.Get(Codigo, DMY2Date(1, 1, 2026)) then begin
                Concepto.Init();
                Concepto.Código := Codigo;
                Concepto."Vigencia Desde" := DMY2Date(1, 1, 2026);
                Concepto."Es Acumulador" := Indice = 2;
                Concepto.Insert(false);
            end;
            ComprobarRechazoValidadorOrden('IF(1,451,' + Codigo + ')', Codigo);
        end;
    end;

    [Test]
    procedure ControlOrdenValidadorRechazaConsultasNoElegidas()
    begin
        ExigirEmpresaValidadorOrden();
        ComprobarRechazoValidadorOrden('IF(1,451,TRAMO(''TEST_SIN_TABLA'',100))', 'TRAMO');
        ComprobarRechazoValidadorOrden('IF(1,451,ACUM_PARAM_CCT(''SIN_FUENTE'',''SIN_PARAM'',''DIAS'',30))', 'ACUM_PARAM_CCT');
        ComprobarRechazoValidadorOrden('IF(1,451,CONSULTA_NO_AUTORIZADA(100))', 'CONSULTA_NO_AUTORIZADA');
    end;

    local procedure ComprobarOrdenEnMotorYControl(Concepto: Record "Concepto Liquidación" temporary; Tipo: Code[20]; Convenio: Code[20]; Esperado: Integer)
    var
        Motor: Codeunit "Motor Liquidación";
        Control: Codeunit "Control Orden Acumuladores";
        Orden: Integer;
        Ordenes: List of [Integer];
    begin
        Assert(Motor.OrdenEfectivo(Concepto, Tipo, Convenio) = Esperado, 'El motor debe resolver operadores lógicos sin convertirlos en consultas dinámicas.');
        Assert(Control.ResolverOrden(Concepto, DMY2Date(28, 2, 2026), Tipo, Convenio, Orden), 'El diagnóstico debe resolver la misma expresión lógica con todo su contexto disponible.');
        Assert(Orden = Esperado, 'Motor y diagnóstico deben coincidir en ambas ramas.');
        Assert(Control.ObtenerOrdenesPosibles(Concepto, DMY2Date(28, 2, 2026), Tipo, Convenio, Ordenes), 'El análisis puro también debe aceptar el contexto conocido y sus operadores parentizados.');
        Assert(Ordenes.Count() = 1, 'Con contexto conocido debe haber un único orden posible.');
        Assert(Ordenes.Get(1) = Esperado, 'La evaluación pura debe conservar el mismo orden exacto.');
    end;

    local procedure ComprobarRechazoValidadorOrden(Formula: Text; TokenEsperado: Text)
    var
        Motor: Codeunit "Motor Liquidación";
        Control: Codeunit "Control Orden Acumuladores";
        Concepto: Record "Concepto Liquidación" temporary;
        Ctx: Dictionary of [Text, Decimal];
        Codigos: Dictionary of [Text, Text];
        Orden: Integer;
    begin
        Concepto.Código := 'TEST_ORD_RECHAZO';
        Concepto."Orden Cálculo" := 159;
        Concepto."Fórmula Orden Cálculo" := CopyStr(Formula, 1, MaxStrLen(Concepto."Fórmula Orden Cálculo"));
        Ctx.Add('FILA_EMPLEADO', 0);
        Ctx.Add('CANT_INCIDENCIA', 0);
        Ctx.Add('COMPLEMENTO_GU', 0);
        Ctx.Add('TEST_ORD_DEP', 0);
        Ctx.Add('TEST_ORD_ACUM', 0);
        Assert(not Control.ResolverOrden(Concepto, DMY2Date(28, 2, 2026), 'CIERRE_MAREA', '768/19', Orden), 'La validación no puede resolver una dependencia prohibida escondida en el ELSE.');
        Assert(Orden = 0, 'El rechazo deja sin resolver el orden.');
        asserterror Motor.OrdenEfectivo(Concepto, 'CIERRE_MAREA', '768/19', DMY2Date(28, 2, 2026), Ctx, Codigos);
        if (StrPos(Formula, '#') > 0) or (StrPos(Formula, '@') > 0) then
            Assert(StrPos(GetLastErrorText(), '# o @') > 0, 'La referencia calculada debe rechazarse antes de evaluar ramas.')
        else
            Assert(StrPos(GetLastErrorText(), TokenEsperado) > 0, 'Debe explicar cuál dependencia o consulta continúa prohibida.');
    end;

    local procedure PrepararContextoValidadorOrden(var Ctx: Dictionary of [Text, Decimal]; var Codigos: Dictionary of [Text, Text])
    begin
        Clear(Ctx);
        Clear(Codigos);
        Ctx.Add('CATEGORIA', 1);
        Ctx.Add('TIPOACTIVIDAD', 2);
        Ctx.Add('INC_1534_CANT_CERO', 0);
        Ctx.Add('INC_1534_IMP_NO_CERO', 0);
        Ctx.Add('APLICA_PROD_FIJO', 1);
        Ctx.Add('NETO_GU_MAREA', 0);
        Ctx.Add('ES_GROSSING_UP', 0);
        Ctx.Add('PCT_PROD_CAPECA', 1);
        Ctx.Add('ORDEN_SAC_TARDIO', 1);
        Codigos.Add('CATEGORIA', 'FE01');
    end;

    local procedure PrepararCatalogosValidadorOrden()
    var
        Tipo: Record "Tipo Liquidación";
        Codigo: Code[20];
        Codigos: List of [Code[20]];
    begin
        ExigirEmpresaValidadorOrden();
        PrepararCatalogosControlOrden();
        Codigos.Add('RELIQUIDACION');
        Codigos.Add('SALDO_INICIAL');
        foreach Codigo in Codigos do
            if not Tipo.Get(Codigo) then begin
                Tipo.Init();
                Tipo.Código := Codigo;
                Tipo.Insert(false);
            end;
        CrearListaValidadorOrden('TEST_ORD_CONVENIO', 'CONVENIO', '768/19');
        CrearListaValidadorOrden('TEST_ORD_CONVENIO', 'CONVENIO', '729/15');
        CrearListaValidadorOrden('TEST_ORD_CONVENIO', 'CONVENIO', '175/75');
        CrearListaValidadorOrden('TEST_ORD_CONVENIO', 'CONVENIO', 'ESP');
        CrearListaValidadorOrden('TEST_ORD_CATEGORIA', 'CATEGORIA', 'FE01');
        CrearListaValidadorOrden('TEST_ORD_CATEGORIA', 'CATEGORIA', 'FE03');
        CrearListaValidadorOrden('TEST_ORD_CATEGORIA', 'CATEGORIA', 'GENERAL');
    end;

    local procedure CrearListaValidadorOrden(CodigoTipo: Code[20]; NombreVariable: Code[30]; CodigoValor: Code[20])
    var
        Tipo: Record "Tipo Atributo Liq.";
        Valor: Record "Valor Atributo Liq.";
    begin
        Tipo.SetRange("Nombre Variable", NombreVariable);
        Tipo.SetRange("Tipo Dato", Tipo."Tipo Dato"::Lista);
        if not Tipo.FindFirst() then begin
            Tipo.Init();
            Tipo.Código := CodigoTipo;
            Tipo."Nombre Variable" := NombreVariable;
            Tipo."Tipo Dato" := Tipo."Tipo Dato"::Lista;
            Tipo.Insert(false);
        end;
        if not Valor.Get(Tipo.Código, '', CodigoValor) then begin
            Valor.Init();
            Valor."Cód. Tipo Atributo" := Tipo.Código;
            Valor.Código := CodigoValor;
            Valor."Valor Numérico" := 1;
            Valor.Insert(false);
        end;
    end;

    local procedure ExigirEmpresaValidadorOrden()
    var
        Empresa: Text;
    begin
        Empresa := CompanyName();
        if not Empresa.StartsWith('TEST_') then
            Error('El validador de orden sólo se prueba en una empresa aislada TEST_.');
    end;

    local procedure CargarFormulaOrdenPublicada(Indice: Integer; var Concepto: Record "Concepto Liquidación" temporary)
    begin
        Concepto.Init();
        case Indice of
            1:
                begin
                    Concepto.Código := '1023';
                    Concepto."Vigencia Desde" := DMY2Date(2, 2, 2026);
                    Concepto."Orden Cálculo" := 470;
                    Concepto."Fórmula Orden Cálculo" := 'IF((TIPO_LIQ = ''CIERRE_MAREA'' OR TIPO_LIQ = ''DEVENGADOS'') AND (CONVENIO = ''768/19'' OR (CONVENIO = ''ESP'' AND (CATEGORIA = ''FE01'' OR CATEGORIA = ''FE03''))) AND TIPOACTIVIDAD <> 1 AND INC_1534_CANT_CERO = 0 AND INC_1534_IMP_NO_CERO = 0, 450, 470)';
                end;
            2:
                begin
                    Concepto.Código := '1023';
                    Concepto."Vigencia Desde" := DMY2Date(3, 2, 2026);
                    Concepto."Orden Cálculo" := 470;
                    Concepto."Fórmula Orden Cálculo" := 'IF((TIPO_LIQ = ''CIERRE_MAREA'' OR TIPO_LIQ = ''DEVENGADOS'') AND (CONVENIO = ''768/19'' OR (CONVENIO = ''ESP'' AND (CATEGORIA = ''FE01'' OR CATEGORIA = ''FE03''))) AND TIPOACTIVIDAD <> 1 AND INC_1534_CANT_CERO = 0 AND INC_1534_IMP_NO_CERO = 0, 450, 470)';
                end;
            3:
                begin
                    Concepto.Código := '1023';
                    Concepto."Vigencia Desde" := DMY2Date(4, 2, 2026);
                    Concepto."Orden Cálculo" := 470;
                    Concepto."Fórmula Orden Cálculo" := 'IF((TIPO_LIQ = ''CIERRE_MAREA'' OR TIPO_LIQ = ''DEVENGADOS'') AND (CONVENIO = ''768/19'' OR (CONVENIO = ''ESP'' AND (CATEGORIA = ''FE01'' OR CATEGORIA = ''FE03''))) AND TIPOACTIVIDAD <> 1 AND INC_1534_CANT_CERO = 0 AND INC_1534_IMP_NO_CERO = 0, 450, 470)';
                end;
            4:
                begin
                    Concepto.Código := '1534';
                    Concepto."Vigencia Desde" := DMY2Date(1, 2, 2026);
                    Concepto."Orden Cálculo" := 159;
                    Concepto."Fórmula Orden Cálculo" := 'IF((TIPO_LIQ = ''CIERRE_MAREA'' OR TIPO_LIQ = ''DEVENGADOS'') AND (CONVENIO = ''768/19'' OR (CONVENIO = ''ESP'' AND (CATEGORIA = ''FE01'' OR CATEGORIA = ''FE03''))) AND TIPOACTIVIDAD <> 1 AND INC_1534_CANT_CERO = 0 AND INC_1534_IMP_NO_CERO = 0, 451, 159)';
                end;
            5:
                begin
                    Concepto.Código := '1534';
                    Concepto."Vigencia Desde" := DMY2Date(2, 2, 2026);
                    Concepto."Orden Cálculo" := 159;
                    Concepto."Fórmula Orden Cálculo" := 'IF((TIPO_LIQ = ''CIERRE_MAREA'' OR TIPO_LIQ = ''DEVENGADOS'') AND (CONVENIO = ''768/19'' OR (CONVENIO = ''ESP'' AND (CATEGORIA = ''FE01'' OR CATEGORIA = ''FE03''))) AND TIPOACTIVIDAD <> 1 AND INC_1534_CANT_CERO = 0 AND INC_1534_IMP_NO_CERO = 0, 451, IF(APLICA_PROD_FIJO > 0 AND TIPOACTIVIDAD = 1 AND NETO_GU_MAREA = 0 AND ES_GROSSING_UP = 0 AND PCT_PROD_CAPECA > 0, 451, 159))';
                end;
            6:
                begin
                    Concepto.Código := '1534';
                    Concepto."Vigencia Desde" := DMY2Date(3, 2, 2026);
                    Concepto."Orden Cálculo" := 159;
                    Concepto."Fórmula Orden Cálculo" := 'IF((TIPO_LIQ = ''CIERRE_MAREA'' OR TIPO_LIQ = ''DEVENGADOS'') AND (CONVENIO = ''768/19'' OR (CONVENIO = ''ESP'' AND (CATEGORIA = ''FE01'' OR CATEGORIA = ''FE03''))) AND TIPOACTIVIDAD <> 1 AND INC_1534_CANT_CERO = 0 AND INC_1534_IMP_NO_CERO = 0, 451, IF(APLICA_PROD_FIJO > 0 AND TIPOACTIVIDAD = 1 AND NETO_GU_MAREA = 0 AND ES_GROSSING_UP = 0 AND PCT_PROD_CAPECA > 0, 451, 159))';
                end;
            7:
                begin
                    Concepto.Código := '1534';
                    Concepto."Vigencia Desde" := DMY2Date(4, 2, 2026);
                    Concepto."Orden Cálculo" := 159;
                    Concepto."Fórmula Orden Cálculo" := 'IF((TIPO_LIQ = ''CIERRE_MAREA'' OR TIPO_LIQ = ''DEVENGADOS'') AND (CONVENIO = ''768/19'' OR (CONVENIO = ''ESP'' AND (CATEGORIA = ''FE01'' OR CATEGORIA = ''FE03''))) AND TIPOACTIVIDAD <> 1 AND INC_1534_CANT_CERO = 0 AND INC_1534_IMP_NO_CERO = 0, 451, IF(APLICA_PROD_FIJO > 0 AND TIPOACTIVIDAD = 1 AND PCT_PROD_CAPECA > 0, 471, 159))';
                end;
            8:
                begin
                    Concepto.Código := '1534';
                    Concepto."Vigencia Desde" := DMY2Date(1, 3, 2026);
                    Concepto."Orden Cálculo" := 159;
                    Concepto."Fórmula Orden Cálculo" := 'IF((TIPO_LIQ = ''CIERRE_MAREA'' OR TIPO_LIQ = ''DEVENGADOS'') AND (CONVENIO = ''768/19'' OR (CONVENIO = ''ESP'' AND (CATEGORIA = ''FE01'' OR CATEGORIA = ''FE03''))) AND TIPOACTIVIDAD <> 1 AND INC_1534_CANT_CERO = 0 AND INC_1534_IMP_NO_CERO = 0, 451, IF(APLICA_PROD_FIJO > 0 AND TIPOACTIVIDAD = 1 AND PCT_PROD_CAPECA > 0, 471, 159))';
                end;
            9:
                begin
                    Concepto.Código := '3813';
                    Concepto."Vigencia Desde" := DMY2Date(1, 1, 2026);
                    Concepto."Orden Cálculo" := 470;
                    Concepto."Fórmula Orden Cálculo" := 'IF((TIPO_LIQ = ''LIQ_FINAL'' OR TIPO_LIQ = ''RELIQUIDACION'') AND (ORDEN_SAC_TARDIO > 0 OR (CONVENIO <> ''175/75'' AND CONVENIO <> ''768/19'' AND CONVENIO <> ''ESP'')), 686, 470)';
                end;
            10:
                begin
                    Concepto.Código := '3813';
                    Concepto."Vigencia Desde" := DMY2Date(2, 1, 2026);
                    Concepto."Orden Cálculo" := 470;
                    Concepto."Fórmula Orden Cálculo" := 'IF((TIPO_LIQ = ''LIQ_FINAL'' OR TIPO_LIQ = ''RELIQUIDACION'') AND (ORDEN_SAC_TARDIO > 0 OR (CONVENIO <> ''175/75'' AND CONVENIO <> ''768/19'' AND CONVENIO <> ''ESP'')), 686, 470)';
                end;
            11:
                begin
                    Concepto.Código := '3814';
                    Concepto."Vigencia Desde" := DMY2Date(1, 1, 2026);
                    Concepto."Orden Cálculo" := 478;
                    Concepto."Fórmula Orden Cálculo" := 'IF(TIPO_LIQ = ''LIQ_FINAL'', IF(ORDEN_SAC_TARDIO = 0 AND (CONVENIO = ''175/75'' OR CONVENIO = ''768/19'' OR CONVENIO = ''ESP''), 669, 687), 478)';
                end;
            else
                Error('Índice de fórmula de orden de prueba fuera de 1..11.');
        end;
    end;

    local procedure CrearCasoControlOrden(var Acumulador: Code[20]; var Lector: Code[20]; var Aportante: Code[20])
    begin
        Acumulador := NuevoCodigoControlOrden();
        Lector := NuevoCodigoControlOrden();
        Aportante := NuevoCodigoControlOrden();
        CrearConceptoControlOrden(Acumulador, 0, '', true);
        CrearConceptoControlOrden(Lector, 10, Acumulador, false);
        CrearConceptoControlOrden(Aportante, 20, '100', false);
        CrearFraccionControlOrden(Aportante, Acumulador, DMY2Date(1, 1, 2026), 100, '');
    end;

    local procedure NuevoCodigoControlOrden(): Code[20]
    begin
        exit(CopyStr('T' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
    end;

    local procedure CrearConceptoControlOrden(Codigo: Code[20]; Orden: Integer; Formula: Text; EsAcumulador: Boolean)
    var
        Concepto: Record "Concepto Liquidación";
    begin
        PrepararCatalogosControlOrden();
        Concepto.Código := Codigo;
        Concepto."Vigencia Desde" := DMY2Date(1, 1, 2026);
        Concepto.Activo := true;
        Concepto."Es Acumulador" := EsAcumulador;
        Concepto."Orden Cálculo" := Orden;
        Concepto."Fórmula Orden Cálculo" := Format(Orden, 0, 9);
        Concepto.Fórmula := CopyStr(Formula, 1, MaxStrLen(Concepto.Fórmula));
        Concepto.Insert(false);
    end;

    local procedure PrepararCatalogosControlOrden()
    var
        Tipo: Record "Tipo Liquidación";
        Convenio: Record "Convenio Colectivo";
        Categoria: Record "Categoría CCT";
        Atributo: Record "Tipo Atributo Liq.";
        Valor: Record "Valor Atributo Liq.";
        Variable: Record "Variable Sistema Liq.";
        Tipos: List of [Code[20]];
        Convenios: List of [Code[20]];
        Categorias: List of [Code[20]];
        Codigo: Code[20];
        CodCategoria: Code[20];
    begin
        // La suite debe ser autocontenida en una empresa de prueba vacía.
        Tipos.Add('REGULAR');
        Tipos.Add('LIQ_FINAL');
        Tipos.Add('CIERRE_MAREA');
        Tipos.Add('DEVENGADOS');
        foreach Codigo in Tipos do
            if not Tipo.Get(Codigo) then begin
                Tipo.Init();
                Tipo.Código := Codigo;
                Tipo.Insert(false);
            end;
        if not Variable.Get('TIPO_LIQ') then begin
            Variable."Nombre Variable" := 'TIPO_LIQ';
            Variable."Cód. Cálculo" := 'TIPO_LIQ';
            Variable.Insert(false);
        end;
        Atributo.SetRange("Nombre Variable", 'CONVENIO');
        Atributo.SetRange("Tipo Dato", Atributo."Tipo Dato"::Lista);
        if not Atributo.FindFirst() then begin
            Atributo.Init();
            Atributo.Código := 'TEST_ORD_CONVENIO';
            Atributo."Nombre Variable" := 'CONVENIO';
            Atributo."Tipo Dato" := Atributo."Tipo Dato"::Lista;
            Atributo.Insert(false);
        end;
        Convenios.Add('TEST_ORD_CCT');
        Convenios.Add('TEST_ORD_CCT_A');
        Convenios.Add('TEST_ORD_CCT_B');
        Convenios.Add('TEST_ORD_OTRO_CCT');
        Convenios.Add('372/04');
        Categorias.Add('GENERAL');
        Categorias.Add('CAT_A');
        Categorias.Add('CAT_B');
        Categorias.Add('OTRA_CAT');
        foreach Codigo in Convenios do begin
            if not Convenio.Get(Codigo) then begin
                Convenio.Init();
                Convenio.Código := Codigo;
                Convenio.Insert(false);
            end;
            if not Valor.Get(Atributo.Código, '', Codigo) then begin
                Valor.Init();
                Valor."Cód. Tipo Atributo" := Atributo.Código;
                Valor.Código := Codigo;
                Valor."Valor Numérico" := 1;
                Valor.Insert(false);
            end;
            foreach CodCategoria in Categorias do
                if not Categoria.Get(Codigo, CodCategoria) then begin
                    Categoria.Init();
                    Categoria."Cód. Convenio" := Codigo;
                    Categoria.Código := CodCategoria;
                    Categoria.Insert(false);
                end;
        end;
    end;

    local procedure CrearFraccionControlOrden(Concepto: Code[20]; Acumulador: Code[20]; Desde: Date; Porcentaje: Decimal; FiltroConvenio: Text)
    var
        Fraccion: Record "Fracción Acumulador";
    begin
        Fraccion."Cód. Concepto" := Concepto;
        Fraccion."Vigencia Desde" := Desde;
        Fraccion."Cód. Acumulador" := Acumulador;
        Fraccion.Porcentaje := Porcentaje;
        Fraccion."Filtro Convenio" := CopyStr(FiltroConvenio, 1, MaxStrLen(Fraccion."Filtro Convenio"));
        Fraccion.Insert(false);
    end;

    local procedure CrearRestriccionControlOrden(Concepto: Code[20]; Convenio: Code[20]; Categoria: Code[20])
    var
        Restriccion: Record "Concepto CCT Vigente";
    begin
        Restriccion."Cód. Concepto" := Concepto;
        Restriccion."Vigencia Desde" := DMY2Date(1, 1, 2026);
        Restriccion."Cód. Convenio" := Convenio;
        Restriccion."Cód. Categoría" := Categoria;
        Restriccion.Insert(false);
    end;

    local procedure Assert(Condicion: Boolean; Mensaje: Text)
    begin
        if not Condicion then
            Error(Mensaje);
    end;
}
