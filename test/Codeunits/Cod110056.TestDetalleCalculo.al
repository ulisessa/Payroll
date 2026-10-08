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

    local procedure Assert(Condicion: Boolean; Mensaje: Text)
    begin
        if not Condicion then
            Error(Mensaje);
    end;
}
