namespace UAS.Payroll;

// Corre la suite AL entera sin abrir el cliente.
//
// POR QUE EXISTE. Hasta ahora la suite sólo se podía correr a mano desde el AL Test Tool, así que en
// la práctica no se corría: el compilador la validaba y nadie sabía si pasaba. Un TestRunner se puede
// invocar desde el servidor con Invoke-NAVCodeunit, y eso la vuelve parte del ciclo de publicar.
//
// COMO SE LEE EL RESULTADO. Un codeunit invocado así no tiene dónde escribir: lo único que vuelve al
// que lo llama es el error. Entonces la convención es al revés de lo habitual —**terminar en
// silencio significa que pasó todo**— y cualquier otra cosa se informa con un Error que trae el
// detalle. Fallar también cuando no se ejecutó NINGUNA prueba es parte de eso: sin ese control, un
// runner que no encuentra nada que correr se ve exactamente igual que uno que corrió y pasó.
//
// TestIsolation = Function: cada prueba corre en su propia transacción y se revierte. Las pruebas
// usan tablas temporales o datos sintéticos que se revierten; el aislamiento permite seguir con
// la siguiente cuando una falla, en vez de cortar la corrida entera.
//
// El runner de Cuenta Francos (110062) se deja como está: afirma además una cantidad exacta de
// pruebas, que es un control de que no se borró ninguna sin darse cuenta.
codeunit 110070 "Runner Tests Liq."
{
    Subtype = TestRunner;
    TestIsolation = Function;

    trigger OnRun()
    begin
        Clear(Ejecutadas);
        Clear(Fallidas);
        Clear(Fallos);
        Clear(EjecutadasPorCodeunit);
        if SoloComparador then
            Codeunit.Run(Codeunit::"Test Correcciones Rend. Liq.")
        else if SoloPuertoCobertura then
            Codeunit.Run(Codeunit::"Test Correcciones Rend. Liq.")
        else if SoloControlPrevio then
            Codeunit.Run(Codeunit::"Test Control Previo Liq.")
        else if SoloValidadorOrden then
            Codeunit.Run(Codeunit::"Test Detalle Calculo")
        else if SoloLecturasParciales then begin
            Codeunit.Run(Codeunit::"Test Correcciones Rend. Liq.");
            Codeunit.Run(Codeunit::"Test Cache Liquidacion");
            Codeunit.Run(Codeunit::"Test Cuenta Francos");
        end else if SoloAvisosOrden then begin
            Codeunit.Run(Codeunit::"Test Escritura Auditoria");
            Codeunit.Run(Codeunit::"Test Cache Liquidacion");
            Codeunit.Run(Codeunit::"Test Detalle Calculo");
            Codeunit.Run(Codeunit::"Test Corrección Orden Acum.");
        end else if SoloCorreccionOrden then begin
            Codeunit.Run(Codeunit::"Test Detalle Calculo");
            Codeunit.Run(Codeunit::"Test Corrección Orden Acum.");
        end else if SoloControlOrden then
            Codeunit.Run(Codeunit::"Test Detalle Calculo")
        else if SoloOficialesParametricos then begin
            Codeunit.Run(Codeunit::"Test Detalle Calculo");
            Codeunit.Run(Codeunit::"Test Uso Parametros");
            Codeunit.Run(Codeunit::"Test Evaluador Fórmula");
            Codeunit.Run(Codeunit::"Test Formateador Fórmula");
        end else if SoloUsoParametros then
            Codeunit.Run(Codeunit::"Test Uso Parametros")
        else if SoloAusentismo then begin
            Codeunit.Run(Codeunit::"Test Fin Efectivo Liq.");
            Codeunit.Run(Codeunit::"Test Promedio Enfermedad");
        end else begin
            Codeunit.Run(Codeunit::"Test Evaluador Fórmula");
            Codeunit.Run(Codeunit::"Test Formateador Fórmula");
            Codeunit.Run(Codeunit::"Test Fin Efectivo Liq.");
            Codeunit.Run(Codeunit::"Test Correcciones Rend. Liq.");
            Codeunit.Run(Codeunit::"Test Cache Liquidacion");
            Codeunit.Run(Codeunit::"Test Escritura Auditoria");
            Codeunit.Run(Codeunit::"Test Detalle Calculo");
            Codeunit.Run(Codeunit::"Test Cuenta Francos");
            Codeunit.Run(Codeunit::"Test Claves Parámetro Liq.");
            Codeunit.Run(Codeunit::"Test Promedio Enfermedad");
            Codeunit.Run(Codeunit::"Test Uso Parametros");
            Codeunit.Run(Codeunit::"Test Corrección Orden Acum.");
            Codeunit.Run(Codeunit::"Test Control Previo Liq.");
            Codeunit.Run(Codeunit::"Test Cotizaciones BNA");
            Codeunit.Run(Codeunit::"Test Valor Franco Fórmula");
            Codeunit.Run(Codeunit::"Test Variables Guardadas");
        end;
        ValidarResultado();
    end;

    procedure EjecComparador()
    var
        Runner: Codeunit "Runner Tests Liq.";
    begin
        Runner.SeleccionarComparador();
        Runner.Run();
    end;

    internal procedure SeleccionarComparador()
    begin
        if CompanyName() <> 'TEST_ORDEN_20261017' then
            Error(ErrEmpresaComparador);
        SoloComparador := true;
        SoloPuertoCobertura := false;
        SoloControlPrevio := false;
        SoloValidadorOrden := false;
        SoloLecturasParciales := false;
        SoloAvisosOrden := false;
        SoloAusentismo := false;
        SoloUsoParametros := false;
        SoloOficialesParametricos := false;
        SoloControlOrden := false;
        SoloCorreccionOrden := false;
    end;

    procedure EjecPuertoCobertura()
    var
        Runner: Codeunit "Runner Tests Liq.";
        Empresa: Text;
    begin
        Empresa := CompanyName();
        if not Empresa.StartsWith('TEST_') then
            Error('Las pruebas de cobertura de puerto sólo se ejecutan en una empresa aislada TEST_.');
        Runner.SeleccionarPuertoCobertura();
        Runner.Run();
    end;

    internal procedure SeleccionarPuertoCobertura()
    begin
        SoloComparador := false;
        SoloPuertoCobertura := true;
        SoloControlPrevio := false;
        SoloValidadorOrden := false;
        SoloLecturasParciales := false;
        SoloAvisosOrden := false;
        SoloAusentismo := false;
        SoloUsoParametros := false;
        SoloOficialesParametricos := false;
        SoloControlOrden := false;
        SoloCorreccionOrden := false;
    end;

    procedure EjecControlPrevio()
    var
        Runner: Codeunit "Runner Tests Liq.";
        Empresa: Text;
    begin
        Empresa := CompanyName();
        if not Empresa.StartsWith('TEST_') then
            Error('Las pruebas del control previo sólo se ejecutan en una empresa aislada TEST_. Empresa actual: %1.', Empresa);
        Runner.SeleccionarControlPrevio();
        Runner.Run();
    end;

    internal procedure SeleccionarControlPrevio()
    begin
        SoloComparador := false;
        SoloPuertoCobertura := false;
        SoloControlPrevio := true;
        SoloValidadorOrden := false;
        SoloLecturasParciales := false;
        SoloAvisosOrden := false;
        SoloAusentismo := false;
        SoloUsoParametros := false;
        SoloOficialesParametricos := false;
        SoloControlOrden := false;
        SoloCorreccionOrden := false;
    end;

    procedure EjecutarValidadorOrden()
    var
        Runner: Codeunit "Runner Tests Liq.";
        Empresa: Text;
    begin
        Empresa := CompanyName();
        if not Empresa.StartsWith('TEST_') then
            Error('Las pruebas del validador de orden sólo se ejecutan en una empresa aislada TEST_. Empresa actual: %1.', Empresa);
        Runner.SeleccionarValidadorOrden();
        Runner.Run();
    end;

    internal procedure SeleccionarValidadorOrden()
    begin
        SoloComparador := false;
        SoloPuertoCobertura := false;
        SoloControlPrevio := false;
        SoloValidadorOrden := true;
        SoloLecturasParciales := false;
        SoloAvisosOrden := false;
        SoloAusentismo := false;
        SoloUsoParametros := false;
        SoloOficialesParametricos := false;
        SoloControlOrden := false;
        SoloCorreccionOrden := false;
    end;

    procedure EjecutarLecturasParciales()
    var
        Runner: Codeunit "Runner Tests Liq.";
        Empresa: Text;
    begin
        Empresa := CompanyName();
        if not Empresa.StartsWith('TEST_') then
            Error('Las pruebas de lecturas parciales sólo se ejecutan en una empresa aislada TEST_. Empresa actual: %1.', Empresa);
        Runner.SeleccionarLecturasParciales();
        Runner.Run();
    end;

    internal procedure SeleccionarLecturasParciales()
    begin
        SoloComparador := false;
        SoloPuertoCobertura := false;
        SoloControlPrevio := false;
        SoloValidadorOrden := false;
        SoloLecturasParciales := true;
        SoloAvisosOrden := false;
        SoloAusentismo := false;
        SoloUsoParametros := false;
        SoloOficialesParametricos := false;
        SoloControlOrden := false;
        SoloCorreccionOrden := false;
    end;

    procedure EjecutarAusentismo()
    var
        Runner: Codeunit "Runner Tests Liq.";
    begin
        // Los callbacks de TestRunner se activan al ejecutar OnRun, no al invocar este método.
        // La instancia tipada conserva la selección y recibe los eventos de sus propias pruebas.
        Runner.SeleccionarAusentismo();
        Runner.Run();
    end;

    internal procedure SeleccionarAusentismo()
    begin
        SoloComparador := false;
        SoloPuertoCobertura := false;
        SoloControlPrevio := false;
        SoloValidadorOrden := false;
        SoloLecturasParciales := false;
        SoloAvisosOrden := false;
        SoloAusentismo := true;
        SoloUsoParametros := false;
        SoloOficialesParametricos := false;
        SoloControlOrden := false;
        SoloCorreccionOrden := false;
    end;

    procedure EjecutarUsoParametros()
    var
        Runner: Codeunit "Runner Tests Liq.";
        Empresa: Text;
    begin
        Empresa := CompanyName();
        if not Empresa.StartsWith('TEST_') then
            Error('Las pruebas de uso de parámetros sólo se ejecutan en una empresa aislada TEST_. Empresa actual: %1.', Empresa);
        Runner.SeleccionarUsoParametros();
        Runner.Run();
    end;

    internal procedure SeleccionarUsoParametros()
    begin
        SoloComparador := false;
        SoloPuertoCobertura := false;
        SoloControlPrevio := false;
        SoloValidadorOrden := false;
        SoloLecturasParciales := false;
        SoloAvisosOrden := false;
        SoloUsoParametros := true;
        SoloAusentismo := false;
        SoloOficialesParametricos := false;
        SoloControlOrden := false;
        SoloCorreccionOrden := false;
    end;

    procedure EjecutarOficialesParametricos()
    var
        Runner: Codeunit "Runner Tests Liq.";
    begin
        // Ejecutar por OnRun activa los callbacks que cuentan y acumulan los fallos del TestRunner.
        Runner.SeleccionarOficialesParametricos();
        Runner.Run();
    end;

    internal procedure SeleccionarOficialesParametricos()
    begin
        SoloComparador := false;
        SoloPuertoCobertura := false;
        SoloControlPrevio := false;
        SoloValidadorOrden := false;
        SoloLecturasParciales := false;
        SoloAvisosOrden := false;
        SoloOficialesParametricos := true;
        SoloAusentismo := false;
        SoloUsoParametros := false;
        SoloControlOrden := false;
        SoloCorreccionOrden := false;
    end;

    procedure EjecutarControlOrden()
    var
        Runner: Codeunit "Runner Tests Liq.";
    begin
        Runner.SeleccionarControlOrden();
        Runner.Run();
    end;

    internal procedure SeleccionarControlOrden()
    begin
        SoloComparador := false;
        SoloPuertoCobertura := false;
        SoloControlPrevio := false;
        SoloValidadorOrden := false;
        SoloLecturasParciales := false;
        SoloAvisosOrden := false;
        SoloControlOrden := true;
        SoloOficialesParametricos := false;
        SoloAusentismo := false;
        SoloUsoParametros := false;
        SoloCorreccionOrden := false;
    end;

    procedure EjecutarCorreccionOrden()
    var
        Runner: Codeunit "Runner Tests Liq.";
    begin
        Runner.SeleccionarCorreccionOrden();
        Runner.Run();
    end;

    internal procedure SeleccionarCorreccionOrden()
    begin
        SoloComparador := false;
        SoloPuertoCobertura := false;
        SoloControlPrevio := false;
        SoloValidadorOrden := false;
        SoloLecturasParciales := false;
        SoloAvisosOrden := false;
        SoloCorreccionOrden := true;
        SoloControlOrden := false;
        SoloOficialesParametricos := false;
        SoloAusentismo := false;
        SoloUsoParametros := false;
    end;

    procedure EjecutarAvisosYOrden()
    var
        Runner: Codeunit "Runner Tests Liq.";
    begin
        Runner.SeleccionarAvisosYOrden();
        Runner.Run();
    end;

    procedure GenerarVistaAvisos(): Text
    var
        Pruebas: Codeunit "Test Escritura Auditoria";
    begin
        exit(Pruebas.GenerarVistaInforme());
    end;

    internal procedure SeleccionarAvisosYOrden()
    begin
        SoloComparador := false;
        SoloPuertoCobertura := false;
        SoloControlPrevio := false;
        SoloValidadorOrden := false;
        SoloLecturasParciales := false;
        SoloAvisosOrden := true;
        SoloCorreccionOrden := false;
        SoloControlOrden := false;
        SoloOficialesParametricos := false;
        SoloAusentismo := false;
        SoloUsoParametros := false;
    end;

    local procedure ValidarResultado()
    begin
        if Ejecutadas = 0 then
            Error(ErrNingunaPrueba);
        if SoloComparador then begin
            ExigirCantidadMinima(Codeunit::"Test Correcciones Rend. Liq.", 'Contadores del comparador sobre buffers temporales', 6);
            if Ejecutadas <> 6 then
                Error(ErrCantidadComparador, Ejecutadas);
        end;
        if SoloPuertoCobertura then begin
            ExigirCantidadMinima(Codeunit::"Test Correcciones Rend. Liq.", 'Cobertura de puerto y fecha de valoración', 10);
            if Ejecutadas <> 10 then
                Error('La cobertura de puerto debe ejecutar exactamente diez pruebas; ejecutó %1.', Ejecutadas);
        end;
        if SoloControlPrevio then begin
            ExigirCantidadMinima(Codeunit::"Test Control Previo Liq.", 'Control previo de configuración sin cálculo', 60);
            if Ejecutadas <> 60 then
                Error('El control previo debe ejecutar exactamente 60 pruebas aisladas; ejecutó %1.', Ejecutadas);
        end;
        if SoloValidadorOrden then
            ExigirCantidadMinima(Codeunit::"Test Detalle Calculo", 'Validador real de orden y rechazos conservados', 18);
        if SoloLecturasParciales then begin
            ExigirCantidadMinima(Codeunit::"Test Correcciones Rend. Liq.", 'Lecturas SUM, selección y trazabilidad', 21);
            ExigirCantidadMinima(Codeunit::"Test Cache Liquidacion", 'Acumulados, indicadores y caché', 25);
            ExigirCantidadMinima(Codeunit::"Test Cuenta Francos", 'Lectura de cuenta de francos', 15);
        end;
        if SoloUsoParametros then
            ExigirCantidadMinima(Codeunit::"Test Uso Parametros", 'Uso de parámetros y precarga de versiones', 35);

        if SoloAvisosOrden then begin
            ExigirCantidadMinima(Codeunit::"Test Escritura Auditoria", 'Avisos, controles e informe', 10);
            ExigirCantidadMinima(Codeunit::"Test Cache Liquidacion", 'Motor y contexto de cálculo', 25);
            ExigirCantidadMinima(Codeunit::"Test Detalle Calculo", 'Control de orden', 12);
            ExigirCantidadMinima(Codeunit::"Test Corrección Orden Acum.", 'Corrección de orden', 24);
        end;
        if SoloControlOrden then begin
            ExigirCodeunitEjecutado(Codeunit::"Test Detalle Calculo", 'Test Detalle Calculo');
            if Ejecutadas < 12 then
                Error(ErrControlOrdenIncompleto, Ejecutadas);
        end;
        if SoloCorreccionOrden then begin
            ExigirCantidadMinima(Codeunit::"Test Detalle Calculo", 'Control de orden', 12);
            ExigirCantidadMinima(Codeunit::"Test Corrección Orden Acum.", 'Corrección de orden', 105);
            if Ejecutadas < 117 then
                Error(ErrCorreccionOrdenIncompleta, 'Corrección de orden y diagnóstico', 117, Ejecutadas);
        end;
        if Fallos <> '' then
            Error(ErrFallaron, Fallidas, Ejecutadas, Fallos);
        if SoloOficialesParametricos then begin
            ExigirCodeunitEjecutado(Codeunit::"Test Detalle Calculo", 'Test Detalle Calculo');
            ExigirCodeunitEjecutado(Codeunit::"Test Uso Parametros", 'Test Uso Parametros');
            ExigirCodeunitEjecutado(Codeunit::"Test Evaluador Fórmula", 'Test Evaluador Fórmula');
            ExigirCodeunitEjecutado(Codeunit::"Test Formateador Fórmula", 'Test Formateador Fórmula');
        end;
    end;

    local procedure ExigirCodeunitEjecutado(CodeunitId: Integer; Nombre: Text)
    var
        Cantidad: Integer;
    begin
        if not EjecutadasPorCodeunit.Get(CodeunitId, Cantidad) then
            Error(ErrCodeunitSinPruebas, Nombre);
        if Cantidad = 0 then
            Error(ErrCodeunitSinPruebas, Nombre);
    end;

    local procedure ExigirCantidadMinima(CodeunitId: Integer; Nombre: Text; Minimo: Integer)
    var
        Cantidad: Integer;
    begin
        if not EjecutadasPorCodeunit.Get(CodeunitId, Cantidad) then
            Cantidad := 0;
        if Cantidad < Minimo then
            Error(ErrCorreccionOrdenIncompleta, Nombre, Minimo, Cantidad);
    end;

    // Se acumulan TODOS los fallos en vez de cortar en el primero: con una sola corrida se quiere
    // saber qué quedó roto, no cuál se rompió primero.
    trigger OnBeforeTestRun(CodeunitId: Integer; CodeunitName: Text; FunctionName: Text; Permissions: TestPermissions): Boolean
    begin
        if SoloComparador then begin
            if CompanyName() <> 'TEST_ORDEN_20261017' then
                Error(ErrEmpresaComparador);
            if CodeunitId <> Codeunit::"Test Correcciones Rend. Liq." then
                exit(false);
            if (FunctionName = '') or (UpperCase(FunctionName) = 'ONRUN') then
                exit(true);
            exit(FunctionName.StartsWith('ComparadorContador'));
        end;
        if SoloPuertoCobertura then begin
            if (FunctionName = '') or (UpperCase(FunctionName) = 'ONRUN') then
                exit(true);
            exit((CodeunitId = Codeunit::"Test Correcciones Rend. Liq.") and FunctionName.StartsWith('PuertoCobertura'));
        end;
        if SoloControlPrevio then
            exit(CodeunitId = Codeunit::"Test Control Previo Liq.");
        if SoloValidadorOrden then
            exit(EsPruebaValidadorOrden(CodeunitId, FunctionName));
        if SoloLecturasParciales then
            exit(EsPruebaLecturasParciales(CodeunitId, FunctionName));
        if SoloAvisosOrden then
            exit(EsPruebaAvisosYOrden(CodeunitId, FunctionName));
        if not (SoloControlOrden or SoloCorreccionOrden) then
            exit(true);
        if (FunctionName = '') or (UpperCase(FunctionName) = 'ONRUN') then
            exit(true);
        if SoloCorreccionOrden and (CodeunitId = Codeunit::"Test Corrección Orden Acum.") then
            exit(true);
        exit((CodeunitId = Codeunit::"Test Detalle Calculo") and FunctionName.StartsWith('ControlOrden'));
    end;

    trigger OnAfterTestRun(CodeunitId: Integer; CodeunitName: Text; FunctionName: Text; Permissions: TestPermissions; Success: Boolean)
    var
        Cantidad: Integer;
    begin
        if (FunctionName = '') or (UpperCase(FunctionName) = 'ONRUN') then
            exit;
        if SoloComparador then
            if (CodeunitId <> Codeunit::"Test Correcciones Rend. Liq.") or not FunctionName.StartsWith('ComparadorContador') then
                exit;
        if SoloPuertoCobertura then
            if (CodeunitId <> Codeunit::"Test Correcciones Rend. Liq.") or not FunctionName.StartsWith('PuertoCobertura') then
                exit;
        if SoloControlPrevio then
            if CodeunitId <> Codeunit::"Test Control Previo Liq." then
                exit;
        if SoloValidadorOrden then
            if not EsPruebaValidadorOrden(CodeunitId, FunctionName) then
                exit;
        if SoloLecturasParciales then
            if not EsPruebaLecturasParciales(CodeunitId, FunctionName) then
                exit;
        if SoloAvisosOrden then
            if not EsPruebaAvisosYOrden(CodeunitId, FunctionName) then
                exit;
        if SoloControlOrden or SoloCorreccionOrden then
            if not (SoloCorreccionOrden and (CodeunitId = Codeunit::"Test Corrección Orden Acum.")) then
                if not FunctionName.StartsWith('ControlOrden') then
                    exit;
        Ejecutadas += 1;
        if EjecutadasPorCodeunit.Get(CodeunitId, Cantidad) then
            EjecutadasPorCodeunit.Set(CodeunitId, Cantidad + 1)
        else
            EjecutadasPorCodeunit.Add(CodeunitId, 1);
        if not Success then begin
            Fallidas += 1;
            Fallos += '\' + CodeunitName + '.' + FunctionName + ': ' + CopyStr(GetLastErrorText(), 1, 250);
        end;
    end;

    local procedure EsPruebaValidadorOrden(CodeunitId: Integer; FunctionName: Text): Boolean
    begin
        if (FunctionName = '') or (UpperCase(FunctionName) = 'ONRUN') then
            exit(true);
        // Sólo evaluación de órdenes y fixtures sintéticas; no selecciona pruebas de Liquidar.
        exit((CodeunitId = Codeunit::"Test Detalle Calculo") and
            (FunctionName.StartsWith('ControlOrdenValidador') or FunctionName.StartsWith('Orden') or
                (FunctionName = 'FormulaOrdenTienePrioridadSobreConfiguracionAnterior')));
    end;

    local procedure EsPruebaLecturasParciales(CodeunitId: Integer; FunctionName: Text): Boolean
    begin
        if (FunctionName = '') or (UpperCase(FunctionName) = 'ONRUN') then
            exit(true);
        if CodeunitId = Codeunit::"Test Cuenta Francos" then
            // Lista explícita: los tests históricos de este codeunit requieren ArbuTest
            // y recalculan recibos reales; no pertenecen a esta suite aislada.
            exit(FunctionName in [
                'ComponentesCompartenDiasYReversionEsIdempotente',
                'SaldoAlCorteNoIncluyeDevengosNiConsumosFuturos',
                'SaldoAlCorteSinCuentaRespetaFechasYDocumento',
                'MatrizSeleccionaParcialSinEscribirConsumos',
                'DevengoUtilizadoBloqueaReversion',
                'EliminarDocumentoConservaCuentaCorriente',
                'ReabrirPeriodoOrdenaDependenciasYRespetaExternos',
                'TotalVirtualRespetaRolVigenciaFechaYDocumento',
                'TotalNoDuplicaLineaAsentadaYReconoceReversion',
                'MatrizVirtualConservaOrigenYTraza',
                'TotalOptimizadoEquivaleAlAnteriorEnFasesYCortes',
                'TotalOptimizadoRespetaReversionGlobalYOrigen',
                'TotalOptimizadoRefrescaLineasAsientosRolesYFase',
                'TotalOptimizadoSeparaRolExactoFallbackYFecha',
                'TotalOptimizadoConservaPrecisionYTrazabilidad'
            ]);
        exit(CodeunitId in [Codeunit::"Test Correcciones Rend. Liq.", Codeunit::"Test Cache Liquidacion"]);
    end;

    local procedure EsPruebaAvisosYOrden(CodeunitId: Integer; FunctionName: Text): Boolean
    begin
        if (FunctionName = '') or (UpperCase(FunctionName) = 'ONRUN') then
            exit(true);
        if CodeunitId = Codeunit::"Test Detalle Calculo" then
            exit(FunctionName.StartsWith('ControlOrden'));
        exit(CodeunitId in [Codeunit::"Test Escritura Auditoria", Codeunit::"Test Cache Liquidacion", Codeunit::"Test Corrección Orden Acum."]);
    end;

    var
        SoloComparador: Boolean;
        SoloPuertoCobertura: Boolean;
        SoloControlPrevio: Boolean;
        SoloValidadorOrden: Boolean;
        SoloLecturasParciales: Boolean;
        SoloAusentismo: Boolean;
        SoloUsoParametros: Boolean;
        SoloOficialesParametricos: Boolean;
        SoloControlOrden: Boolean;
        SoloCorreccionOrden: Boolean;
        SoloAvisosOrden: Boolean;
        EjecutadasPorCodeunit: Dictionary of [Integer, Integer];
        Ejecutadas: Integer;
        Fallidas: Integer;
        Fallos: Text;
        ErrNingunaPrueba: Label 'No se ejecutó ninguna prueba. El runner corrió pero no encontró nada que correr: revisá que los codeunits de test sigan existiendo y con Subtype = Test.';
        ErrEmpresaComparador: Label 'Las pruebas del comparador sólo se ejecutan en la empresa aislada TEST_ORDEN_20261017.';
        ErrCantidadComparador: Label 'El comparador debe ejecutar exactamente seis pruebas temporales; ejecutó %1.', Comment = '%1=cantidad de pruebas ejecutadas';
        ErrFallaron: Label 'Fallaron %1 de %2 pruebas:%3', Comment = '%1=fallidas, %2=ejecutadas, %3=detalle';
        ErrCodeunitSinPruebas: Label 'No se ejecutó ninguna prueba de %1. La selección de oficiales paramétricos debe ejecutar los cuatro codeunits completos.', Comment = '%1=nombre del codeunit';
        ErrControlOrdenIncompleto: Label 'Se ejecutaron %1 pruebas de control de orden; deben ejecutarse al menos las doce pruebas nuevas.', Comment = '%1=cantidad de pruebas';
        ErrCorreccionOrdenIncompleta: Label '%1 debe ejecutar al menos %2 pruebas; se ejecutaron %3.', Comment = '%1=grupo de pruebas, %2=mínimo, %3=ejecutadas';
}
