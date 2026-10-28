namespace UAS.Payroll;

codeunit 110075 "Test Corrección Orden Acum."
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ProponeAdelantarAporteSinEscribirConfiguracion()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Actual: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Explicacion: Text;
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Actual.Get(Aportante, DMY2Date(1, 1, 2020));
        if not Gestor.Proponer(Acumulador, DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Origen, Orden, Fecha, Explicacion) then
            Error('Debe ofrecer una corrección para un aporte manual sin dependencias. Motivo: %1', Explicacion);
        Assert(Origen.SystemRowVersion = Actual.SystemRowVersion, 'La propuesta debe devolver la versión física de concurrencia antes de que el llamador vuelva a leer el registro.');
        Assert((Origen.Código = Aportante) and (Orden = 19), 'El cambio mínimo coloca el aporte inmediatamente antes del lector20.');
        Assert(Fecha = DMY2Date(15, 1, 2020), 'La fecha propuesta debe corresponder a la referencia elegida.');
        Origen.Get(Aportante, DMY2Date(1, 1, 2020));
        Assert(Origen.SystemRowVersion = Actual.SystemRowVersion, 'Proponer no debe escribir la configuración.');
        Assert(Explicacion <> '', 'La propuesta debe explicar qué cambia.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AsignacionBooleanaYEnvolturaDePaginaConservanPropuesta()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Actual: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Explicacion: Text;
        Disponible: Boolean;
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Actual.Get(Aportante, DMY2Date(1, 1, 2020));
        Disponible := Gestor.Proponer(Acumulador, DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Origen, Orden, Fecha, Explicacion);
        Assert(Disponible, 'La asignación del Boolean debe conservar una propuesta válida. Motivo: ' + Explicacion);
        Assert((Origen.Código = Aportante) and (Orden = 19), 'La llamada asignada debe proponer el aporte en19, sin sustituirlo por su orden actual30.');
        Assert(Origen.SystemRowVersion = Actual.SystemRowVersion, 'La asignación debe devolver el rowversion físico para la guarda de concurrencia.');
        Clear(Origen);
        Clear(Orden);
        Clear(Fecha);
        Clear(Explicacion);
        Disponible := false;
        // La página asigna el Boolean dentro de un TryFunction y comprueba su retorno por separado.
        if not IntentarAsignarPropuestaComoPagina(Acumulador, Disponible, Origen, Orden, Fecha, Explicacion) then
            Error('La envoltura de página falló: %1', GetLastErrorText());
        Assert(Disponible, 'La envoltura de página debe conservar la propuesta. Motivo: ' + Explicacion);
        Assert((Origen.Código = Aportante) and (Orden = 19) and (Fecha = DMY2Date(15, 1, 2020)), 'La envoltura no debe alterar concepto, orden ni fecha.');
        Assert(Origen.SystemRowVersion = Actual.SystemRowVersion, 'La envoltura debe conservar el rowversion físico.');
        Origen.Get(Aportante, DMY2Date(1, 1, 2020));
        Assert(Origen.SystemRowVersion = Actual.SystemRowVersion, 'Ninguna forma de previsualización debe modificar la configuración.');
    end;

    [TryFunction]
    local procedure IntentarAsignarPropuestaComoPagina(Acumulador: Code[20]; var Disponible: Boolean; var Origen: Record "Concepto Liquidación"; var Orden: Integer; var Fecha: Date; var Explicacion: Text)
    var
        Gestor: Codeunit "Corrección Orden Acum.";
    begin
        Disponible := Gestor.Proponer(Acumulador, DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Origen, Orden, Fecha, Explicacion);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ProponeRetrasarLectorCuandoNoHayOrdenAnteriorValido()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Explicacion: Text;
        Prefijo: Code[20];
    begin
        PrepararCatalogos();
        Prefijo := CopyStr(NuevoCodigo(), 1, 15);
        Acumulador := NuevoCodigo();
        Aportante := Prefijo + 'Z';
        Lector := Prefijo + 'A';
        CrearConcepto(Acumulador, 0, '', true, false);
        CrearConcepto(Aportante, 30, '', false, false);
        CrearConcepto(Lector, 0, Acumulador, false, true);
        CrearFraccion(Aportante, Acumulador);
        if not Gestor.Proponer(Acumulador, DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Origen, Orden, Fecha, Explicacion) then
            Error('Un lector virtual en cero debe admitir la alternativa de retrasarse. Motivo: %1', Explicacion);
        Assert((Origen.Código = Lector) and (Orden = 31), 'Sin orden anterior válido, el lector debe ir después del último aporte30.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ProponeEmpateCuandoLaEntradaNoPermiteElEnteroAnterior()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        Entrada: Code[20];
        Prefijo: Code[20];
        Orden: Integer;
        Fecha: Date;
        Explicacion: Text;
        Formula: Text;
        Impacto: Text;
    begin
        PrepararCatalogos();
        Prefijo := CopyStr(NuevoCodigo(), 1, 15);
        Acumulador := NuevoCodigo();
        Entrada := Prefijo + 'A';
        Aportante := Prefijo + 'B';
        Lector := Prefijo + 'C';
        CrearConcepto(Acumulador, 0, '', true, false);
        CrearConcepto(Entrada, 20, '1', false, false);
        CrearConcepto(Aportante, 30, '#' + Entrada, false, false);
        CrearConcepto(Lector, 20, Acumulador, false, true);
        CrearFraccion(Aportante, Acumulador);
        if not Gestor.Preparar(Acumulador, DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Aportante, Origen, Orden, Fecha, Explicacion) then
            Error('Hay una ventana válida en el mismo orden20: entradaA, aporteB, lectorC. Motivo: %1', Explicacion);
        Assert(Orden = 20, 'El orden19 es inválido por la entrada; el20 respeta ambos desempates.');
        Gestor.Validar(Acumulador, Origen, Fecha, Orden, 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Formula, Impacto);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure NoProponeMovimientoCuandoElAporteYaEstaAntes()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Explicacion: Text;
    begin
        CrearCaso(Acumulador, Aportante, Lector, 40);
        Assert(not Gestor.Proponer(Acumulador, DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Origen, Orden, Fecha, Explicacion), 'Sin aporte posterior no hay un arreglo que sugerir.');
        Assert((Orden = 0) and (Origen.Código = ''), 'Una propuesta ausente no debe exponer el orden actual como solución.');
        Assert(Explicacion.Contains('ya queda del lado correcto'), 'La evaluación debe explicar que no hace falta crear una vigencia.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ExplicaVentanaVaciaSinDevolverOrdenActual()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Concepto: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Explicacion: Text;
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Concepto.Get(Aportante, DMY2Date(1, 1, 2020));
        Concepto.Fórmula := '#' + Lector;
        Concepto.Modify(false);
        Assert(not Gestor.Proponer(Acumulador, DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Origen, Orden, Fecha, Explicacion), 'Aporte que depende del lector no admite reordenamiento de un único concepto.');
        Assert((Orden = 0) and (Origen.Código = ''), 'No debe devolver una posición ficticia ni igual al actual.');
        Assert(Explicacion.Contains('ventana segura') and Explicacion.Contains(Lector), 'El bloqueo debe identificar la dependencia que hace imposible la ventana.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PrepararExplicaLecturaPorEtapas()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Concepto: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Explicacion: Text;
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Concepto.Get(Aportante, DMY2Date(1, 1, 2020));
        Concepto.Fórmula := Acumulador;
        Concepto.Modify(false);
        Assert(not Gestor.Preparar(Acumulador, DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Aportante, Origen, Orden, Fecha, Explicacion), 'El lector que aporta a la misma base necesita una revisión de etapas.');
        Assert((Orden = 0) and Explicacion.Contains('lectura por etapas'), 'Debe dejar el orden sin propuesta y explicar el subtotal intencional.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure VentanaConsideraConsumidorProgramadoEnElFuturo()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Consumidor: Record "Concepto Liquidación";
        Acumulador: Code[20];
        OtraBase: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        CodigoConsumidor: Code[20];
        Prefijo: Code[20];
        Orden: Integer;
        Fecha: Date;
        Explicacion: Text;
    begin
        PrepararCatalogos();
        Prefijo := CopyStr(NuevoCodigo(), 1, 15);
        Acumulador := NuevoCodigo();
        OtraBase := NuevoCodigo();
        Aportante := Prefijo + 'A';
        Lector := Prefijo + 'B';
        CodigoConsumidor := Prefijo + 'C';
        CrearConcepto(Acumulador, 0, '', true, false);
        CrearConcepto(OtraBase, 0, '', true, false);
        CrearConcepto(Aportante, 30, '', false, false);
        CrearConcepto(Lector, 20, Acumulador, false, true);
        CrearFraccion(Aportante, Acumulador);
        CrearFraccion(Aportante, OtraBase);
        CrearConcepto(CodigoConsumidor, 40, OtraBase, false, true);
        Consumidor.Get(CodigoConsumidor, DMY2Date(1, 1, 2020));
        Consumidor."Vigencia Desde" := DMY2Date(1, 2, 2020);
        Consumidor."Orden Cálculo" := 25;
        Consumidor."Fórmula Orden Cálculo" := '25';
        Consumidor.Insert(true);
        Assert(not Gestor.Preparar(Acumulador, DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Aportante, Origen, Orden, Fecha, Explicacion), 'Desde febrero conservar la otra base exige el aporte después del consumidor25, incompatible con el lector20 de la base seleccionada.');
        Assert(Explicacion.Contains(CodigoConsumidor), 'La causa debe identificar al consumidor futuro que impide conservar el resultado.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure BuscaLectorAlternativoCuandoElAporteTieneUnaEntradaPosterior()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Concepto: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        Entrada: Code[20];
        Orden: Integer;
        Fecha: Date;
        Explicacion: Text;
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Entrada := NuevoCodigo();
        CrearConcepto(Entrada, 25, '1', false, false);
        Concepto.Get(Aportante, DMY2Date(1, 1, 2020));
        Concepto.Fórmula := '#' + Entrada;
        Concepto.Modify(false);
        if not Gestor.Proponer(Acumulador, DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Origen, Orden, Fecha, Explicacion) then
            Error('La entrada25 impide adelantar el aporte30 al19, pero se puede atrasar la lectura. Motivo: %1', Explicacion);
        Assert((Origen.Código = Lector) and (Orden = 31), 'Debe buscar otra alternativa comprobada en vez de ofrecer la primera propuesta inválida.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure EncuentraVentanaDeUnEnteroEntreAporteYConsumidorFuturo()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Consumidor: Record "Concepto Liquidación";
        Acumulador: Code[20];
        OtraBase: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        CodigoConsumidor: Code[20];
        Prefijo: Code[20];
        Orden: Integer;
        Fecha: Date;
        Explicacion: Text;
    begin
        PrepararCatalogos();
        Prefijo := CopyStr(NuevoCodigo(), 1, 15);
        Acumulador := NuevoCodigo();
        OtraBase := NuevoCodigo();
        Aportante := Prefijo + 'A';
        Lector := Prefijo + 'Z';
        CodigoConsumidor := Prefijo + 'M';
        CrearConcepto(Acumulador, 0, '', true, false);
        CrearConcepto(OtraBase, 0, '', true, false);
        CrearConcepto(Aportante, 30, '', false, false);
        CrearConcepto(Lector, 20, Acumulador, false, true);
        CrearFraccion(Aportante, Acumulador);
        CrearFraccion(Lector, OtraBase);
        CrearConcepto(CodigoConsumidor, 40, OtraBase, false, true);
        Consumidor.Get(CodigoConsumidor, DMY2Date(1, 1, 2020));
        Consumidor."Vigencia Desde" := DMY2Date(1, 2, 2020);
        Consumidor."Orden Cálculo" := 31;
        Consumidor."Fórmula Orden Cálculo" := '31';
        Consumidor.Insert(true);
        if not Gestor.Preparar(Acumulador, DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Lector, Origen, Orden, Fecha, Explicacion) then
            Error('Existe una ventana en30: después del aporteA y antes del consumidorM31 futuro. Motivo: %1', Explicacion);
        Assert(Orden = 30, 'El31 propuesto por max+1 cruza al consumidor futuro; debe encontrar el único entero30.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ValidarNoCreaVigenciasNiAuditoria()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Actual: Record "Concepto Liquidación";
        Historial: Record "Historial Fórmula Concepto";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        CantidadHistorial: Integer;
        Formula: Text;
        Impacto: Text;
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Origen.Get(Aportante, DMY2Date(1, 1, 2020));
        Historial.SetRange("Cód. Concepto", Aportante);
        CantidadHistorial := Historial.Count();
        Gestor.Validar(Acumulador, Origen, DMY2Date(1, 2, 2020), 10, 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Formula, Impacto);
        Actual.Get(Origen.Código, Origen."Vigencia Desde");
        Assert(Actual.SystemRowVersion = Origen.SystemRowVersion, 'Validar no debe modificar el origen.');
        Assert(not Actual.Get(Origen.Código, DMY2Date(1, 2, 2020)), 'Validar no debe crear la nueva vigencia.');
        Assert(Historial.Count() = CantidadHistorial, 'Una revisión no debe generar auditoría de aplicación.');
        Assert((Formula <> '') and (Impacto <> ''), 'La revisión debe devolver la expresión propuesta y su alcance.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AplicarConservaFormulaDeImporteYReciboExistente()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Nueva: Record "Concepto Liquidación";
        Cabecera: Record "Liquidación";
        CabeceraAntes: Record "Liquidación";
        Linea: Record "Línea Liquidación";
        LineaAntes: Record "Línea Liquidación";
        Fraccion: Record "Fracción Acumulador";
        FraccionAntes: Record "Fracción Acumulador";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Origen.Get(Aportante, DMY2Date(1, 1, 2020));
        Origen.Fórmula := '99.875';
        Origen.Condición := '1 = 1';
        Origen."Variable Cantidad" := 'DIAS_CORRECCION_TEST';
        Origen."Variable Base" := 'BASE_CORRECCION_TEST';
        Origen."Nombre Impresión" := 'Importe que debe conservarse';
        Origen.Modify(false);
        Origen.Get(Origen.Código, Origen."Vigencia Desde");
        CrearRecibo(Origen, DMY2Date(15, 1, 2020), Cabecera, Linea);
        CabeceraAntes := Cabecera;
        LineaAntes := Linea;
        Fraccion.Get(Aportante, DMY2Date(1, 1, 2020), Acumulador);
        FraccionAntes := Fraccion;
        Gestor.Aplicar(Acumulador, Origen, DMY2Date(1, 2, 2020), 10, 'REGULAR', 'TEST_CORR_CCT', 'GENERAL');
        Nueva.Get(Aportante, DMY2Date(1, 2, 2020));
        Assert((Nueva.Fórmula = Origen.Fórmula) and (Nueva.Condición = Origen.Condición), 'La acción sólo cambia el orden: fórmula de importe y condición permanecen exactas.');
        Assert((Nueva."Variable Cantidad" = Origen."Variable Cantidad") and (Nueva."Variable Base" = Origen."Variable Base"), 'La cantidad y la base de presentación no deben cambiar.');
        Assert((Nueva."Tipo Concepto" = Origen."Tipo Concepto") and (Nueva."Nombre Impresión" = Origen."Nombre Impresión"), 'La naturaleza y el texto del concepto se conservan.');
        Origen.Get(Aportante, DMY2Date(1, 1, 2020));
        Assert(Origen."Vigencia Hasta" = DMY2Date(31, 1, 2020), 'La versión anterior termina el día previo a la nueva.');
        Cabecera.Get(CabeceraAntes."No.");
        Linea.Get(LineaAntes."No. Liquidación", LineaAntes."No. Línea");
        Assert(Cabecera.SystemRowVersion = CabeceraAntes.SystemRowVersion, 'Aplicar una configuración no debe escribir la cabecera de un recibo calculado.');
        Assert(Linea.SystemRowVersion = LineaAntes.SystemRowVersion, 'El importe, la fórmula aplicada y los demás campos del recibo deben permanecer intactos.');
        Fraccion.Get(Aportante, DMY2Date(1, 1, 2020), Acumulador);
        Assert(Fraccion.SystemRowVersion = FraccionAntes.SystemRowVersion, 'Las fracciones tienen vigencia propia y no deben reescribirse.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FormulaNuevaConservaCondicionDeOrdenFueraDelAmbito()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Motor: Codeunit "Motor Liquidación";
        Origen: Record "Concepto Liquidación";
        Nueva: Record "Concepto Liquidación" temporary;
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        Formula: Text;
        Impacto: Text;
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Origen.Get(Aportante, DMY2Date(1, 1, 2020));
        Origen."Fórmula Orden Cálculo" := 'IF(TIPO_LIQ = ''REGULAR'', 30, 70)';
        Origen.Modify(false);
        Origen.Get(Origen.Código, Origen."Vigencia Desde");
        Gestor.Validar(Acumulador, Origen, DMY2Date(1, 2, 2020), 10, 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Formula, Impacto);
        Assert(Formula.Contains(Origen."Fórmula Orden Cálculo"), 'La rama anterior debe conservarse como expresión, no reemplazarse por la columna numérica.');
        Nueva := Origen;
        Nueva."Fórmula Orden Cálculo" := CopyStr(Formula, 1, MaxStrLen(Nueva."Fórmula Orden Cálculo"));
        Assert(Motor.OrdenEfectivo(Nueva, 'REGULAR', 'TEST_CORR_CCT') = 10, 'El nuevo orden aplica dentro del tipo y convenio elegidos.');
        Assert(Motor.OrdenEfectivo(Nueva, 'LIQ_FINAL', 'TEST_CORR_CCT') = 70, 'Otro tipo conserva la rama condicional anterior.');
        Assert(Motor.OrdenEfectivo(Nueva, 'REGULAR', 'TEST_CORR_OTRO') = 30, 'Otro convenio conserva el orden anterior de su modalidad.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure NuevaVigenciaConservaLaVersionFutura()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Futura: Record "Concepto Liquidación";
        FuturaAntes: Record "Concepto Liquidación";
        Nueva: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Origen.Get(Aportante, DMY2Date(1, 1, 2020));
        Futura := Origen;
        Futura."Vigencia Desde" := DMY2Date(1, 4, 2020);
        Futura."Fórmula Orden Cálculo" := '40';
        Futura."Vigencia Hasta" := 0D;
        Futura.Insert(true);
        Futura.Get(Futura.Código, Futura."Vigencia Desde");
        FuturaAntes := Futura;
        Origen.Get(Origen.Código, Origen."Vigencia Desde");
        Gestor.Aplicar(Acumulador, Origen, DMY2Date(1, 2, 2020), 10, 'REGULAR', 'TEST_CORR_CCT', 'GENERAL');
        Nueva.Get(Aportante, DMY2Date(1, 2, 2020));
        Assert(Nueva."Vigencia Hasta" = DMY2Date(31, 3, 2020), 'La nueva versión debe terminar antes de la ya programada.');
        Futura.Get(FuturaAntes.Código, FuturaAntes."Vigencia Desde");
        Assert(Futura.SystemRowVersion = FuturaAntes.SystemRowVersion, 'La vigencia futura y su expresión no deben modificarse.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure RechazaFechaDeVigenciaYaOcupada()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Existente: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Origen.Get(Aportante, DMY2Date(1, 1, 2020));
        Existente := Origen;
        Existente."Vigencia Desde" := DMY2Date(1, 2, 2020);
        Existente.Insert(true);
        Origen.Get(Origen.Código, Origen."Vigencia Desde");
        asserterror Gestor.Aplicar(Acumulador, Origen, DMY2Date(1, 2, 2020), 10, 'REGULAR', 'TEST_CORR_CCT', 'GENERAL');
        Assert(GetLastErrorText() <> '', 'La fecha ocupada debe bloquearse antes de insertar o pisar una versión.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure RechazaOrigenModificadoDespuesDeRevisar()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Actual: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Origen.Get(Aportante, DMY2Date(1, 1, 2020));
        Actual := Origen;
        Actual.Descripción := 'Cambio concurrente posterior al plan';
        Actual.Modify(false);
        asserterror Gestor.Aplicar(Acumulador, Origen, DMY2Date(1, 2, 2020), 10, 'REGULAR', 'TEST_CORR_CCT', 'GENERAL');
        Assert(GetLastErrorText() <> '', 'Una revisión de una versión antigua no puede sobrescribir una edición posterior.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure RechazaCierreAnteriorAUnUsoCalculado()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Cabecera: Record "Liquidación";
        Linea: Record "Línea Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Origen.Get(Aportante, DMY2Date(1, 1, 2020));
        CrearRecibo(Origen, DMY2Date(15, 2, 2020), Cabecera, Linea);
        asserterror Gestor.Aplicar(Acumulador, Origen, DMY2Date(1, 2, 2020), 10, 'REGULAR', 'TEST_CORR_CCT', 'GENERAL');
        Assert(GetLastErrorText().Contains(Cabecera."No."), 'El bloqueo debe identificar la liquidación que ya usó esa vigencia después del corte.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure RechazaAdelantarPorDelanteDeReferenciaNumeral()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        Dependencia: Code[20];
        Formula: Text;
        Impacto: Text;
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Dependencia := NuevoCodigo();
        CrearConcepto(Dependencia, 25, '1', false, false);
        Origen.Get(Aportante, DMY2Date(1, 1, 2020));
        Origen.Fórmula := '#' + Dependencia;
        Origen.Modify(false);
        Origen.Get(Origen.Código, Origen."Vigencia Desde");
        asserterror Gestor.Validar(Acumulador, Origen, DMY2Date(1, 2, 2020), 10, 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Formula, Impacto);
        Assert(GetLastErrorText() <> '', 'El arreglo de un acumulador no puede hacer que #dependencia todavía no esté calculada.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure RechazaDependenciaCircularPorReevaluacion()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        Dependencia: Code[20];
        Formula: Text;
        Impacto: Text;
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Dependencia := NuevoCodigo();
        CrearConcepto(Dependencia, 25, '#' + Aportante, false, false);
        Origen.Get(Aportante, DMY2Date(1, 1, 2020));
        Origen.Fórmula := '@' + Dependencia;
        Origen.Modify(false);
        Origen.Get(Origen.Código, Origen."Vigencia Desde");
        asserterror Gestor.Validar(Acumulador, Origen, DMY2Date(1, 2, 2020), 10, 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Formula, Impacto);
        Assert(GetLastErrorText() <> '', 'La reevaluación no puede usarse para eludir una dependencia circular con el concepto movido.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure RechazaCambiarSubtotalDeOtroAcumulador()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        OtroAcumulador: Code[20];
        OtroLector: Code[20];
        Formula: Text;
        Impacto: Text;
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        OtroAcumulador := NuevoCodigo();
        OtroLector := NuevoCodigo();
        CrearConcepto(OtroAcumulador, 0, '', true, false);
        CrearConcepto(OtroLector, 20, OtroAcumulador, false, true);
        CrearFraccion(Aportante, OtroAcumulador);
        Origen.Get(Aportante, DMY2Date(1, 1, 2020));
        asserterror Gestor.Validar(Acumulador, Origen, DMY2Date(1, 2, 2020), 10, 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Formula, Impacto);
        Assert(GetLastErrorText() <> '', 'Corregir el acumulador seleccionado no autoriza cambiar el subtotal que ya leía otra fórmula.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure RechazaMatrizSinContextoDeSusFilas()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        Formula: Text;
        Impacto: Text;
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Origen.Get(Aportante, DMY2Date(1, 1, 2020));
        Origen."Fuente Matriz" := 'TEST_MATRIZ_ORD';
        Origen.Modify(false);
        Origen.Get(Origen.Código, Origen."Vigencia Desde");
        asserterror Gestor.Validar(Acumulador, Origen, DMY2Date(1, 2, 2020), 10, 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Formula, Impacto);
        Assert(GetLastErrorText() <> '', 'Sin las filas de la matriz no debe aprobarse un cambio de orden automático.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AuditoriaDistingueOrdenDeFormulaDeImporte()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Nueva: Record "Concepto Liquidación";
        Historial: Record "Historial Fórmula Concepto";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Origen.Get(Aportante, DMY2Date(1, 1, 2020));
        Gestor.Aplicar(Acumulador, Origen, DMY2Date(1, 2, 2020), 10, 'REGULAR', 'TEST_CORR_CCT', 'GENERAL');
        Nueva.Get(Aportante, DMY2Date(1, 2, 2020));
        Historial.SetRange("Cód. Concepto", Aportante);
        Historial.SetRange("Vigencia Desde", Nueva."Vigencia Desde");
        Historial.SetRange("Tipo Cambio", Historial."Tipo Cambio"::Orden);
        Assert(Historial.FindFirst(), 'Debe existir una auditoría específica de orden.');
        Assert(Historial."Fórmula Anterior" = Origen."Fórmula Orden Cálculo", 'El tipo Orden conserva la expresión de orden anterior.');
        Assert(Historial."Fórmula Nueva" = Nueva."Fórmula Orden Cálculo", 'El tipo Orden conserva la expresión nueva completa.');
        Assert((Historial.Usuario <> '') and (Historial."Fecha Hora" <> 0DT), 'Debe quedar registrada la autoría y la fecha de aplicación.');
        Assert(Nueva.Fórmula = Origen.Fórmula, 'La auditoría de orden no debe confundirse con un cambio de la fórmula monetaria.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure RestaurarOrdenNoSobrescribeFormulaMonetaria()
    var
        HistorialMgt: Codeunit "Historial Fórmulas Liq.";
        Historial: Record "Historial Fórmula Concepto";
        Origen: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Origen.Get(Aportante, DMY2Date(1, 1, 2020));
        Origen.Fórmula := '123.45';
        Origen.Modify(false);
        Historial."Cód. Concepto" := Origen.Código;
        Historial."Vigencia Desde" := Origen."Vigencia Desde";
        Historial."Tipo Cambio" := Historial."Tipo Cambio"::Orden;
        Historial."Fórmula Anterior" := '30';
        Historial."Fórmula Nueva" := '10';
        asserterror HistorialMgt.Restaurar(Historial);
        Assert(GetLastErrorText().ToLower().Contains('orden'), 'El tipo Orden debe rechazarse antes del diálogo de confirmación y de escribir el texto30 en la fórmula monetaria.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure RechazaCruceProgramadoDentroDeLaNuevaVigencia()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Futura: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        OtroAcumulador: Code[20];
        OtroLector: Code[20];
        Formula: Text;
        Impacto: Text;
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        OtroAcumulador := NuevoCodigo();
        OtroLector := NuevoCodigo();
        CrearConcepto(OtroAcumulador, 0, '', true, false);
        CrearConcepto(OtroLector, 5, OtroAcumulador, false, true);
        CrearFraccion(Aportante, OtroAcumulador);
        Futura.Get(OtroLector, DMY2Date(1, 1, 2020));
        Futura."Vigencia Desde" := DMY2Date(1, 3, 2020);
        Futura."Orden Cálculo" := 20;
        Futura."Fórmula Orden Cálculo" := '20';
        Futura."Vigencia Hasta" := 0D;
        Futura.Insert(true);
        Origen.Get(Aportante, DMY2Date(1, 1, 2020));
        // El 1/2 tanto30 como10 corren después del lector5. Desde el 1/3 el lector20
        // quedaría entre ambos, y la nueva vigencia del aporte también alcanzaría ese mes.
        asserterror Gestor.Validar(Acumulador, Origen, DMY2Date(1, 2, 2020), 10, 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Formula, Impacto);
        Assert(GetLastErrorText() <> '', 'Validar sólo el primer día no alcanza: una vigencia futura ya programada cambia el subtotal de otra base.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AnalisisDeUnaFilaEquivaleAlGlobalSinArrastrarOtrasFilas()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Global: Record "Diag. Orden Acum. Buffer" temporary;
        Unico: Record "Diag. Orden Acum. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        OtraBase: Code[20];
        OtroAporte: Code[20];
        OtroLector: Code[20];
        Codigo: Code[20];
        Codigos: List of [Code[20]];
        Hallazgos: Integer;
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        CrearCaso(OtraBase, OtroAporte, OtroLector, 40);
        Concepto.Get(OtroAporte, DMY2Date(1, 1, 2020));
        Concepto."Orden Cálculo" := 10;
        Concepto."Fórmula Orden Cálculo" := '10';
        Concepto.Modify(false);
        // Un lector compartido y repetido en fórmula/condición debe contarse una vez por base.
        Concepto.Get(Lector, DMY2Date(1, 1, 2020));
        Concepto.Fórmula := Acumulador + ' + ' + Acumulador + ' + #' + OtraBase;
        Concepto.Condición := Acumulador + ' > 0 AND ' + OtraBase + ' > 0';
        Concepto.Modify(false);
        Control.Analizar(DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Global);
        Global.Get(Acumulador);
        Assert(Global."Cant. Lecturas" = 1, 'Repetir la lectura en fórmula y condición no debe duplicar el concepto lector.');
        Global.Get(OtraBase);
        Assert((Global."Cant. Lecturas" = 2) and not Global.Conflicto, 'Un lector puede pertenecer a dos bases sin contaminar los aportes de la otra.');
        Codigos.Add(Acumulador);
        Codigos.Add(OtraBase);
        Unico.SetRange("Cód. Acumulador", OtraBase);
        foreach Codigo in Codigos do begin
            Hallazgos := Control.Analizar(DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Codigo, Unico);
            Assert(Unico.Count() = 1, 'El análisis acotado debe limpiar los filtros recibidos y devolver exclusivamente la fila solicitada.');
            Unico.Get(Codigo);
            Global.Get(Codigo);
            AssertMismoDiagnostico(Global, Unico);
            if Global.Conflicto then
                Assert(Hallazgos = 1, 'La fila conflictiva cuenta como un hallazgo.')
            else
                Assert(Hallazgos = 0, 'Una fila sin conflicto no cuenta como hallazgo.');
        end;
        Hallazgos := Control.Analizar(DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Aportante, Unico);
        Assert((Hallazgos = 0) and Unico.IsEmpty(), 'Solicitar un concepto normal debe vaciar el diagnóstico anterior.');
        Hallazgos := Control.Analizar(DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', NuevoCodigo(), Unico);
        Assert((Hallazgos = 0) and Unico.IsEmpty(), 'Un acumulador inexistente no debe devolver una fila guardada de otra consulta.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AnalisisReutilizadoRespetaFechaYRegresoALaFechaAnterior()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Futura: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Futura.Get(Lector, DMY2Date(1, 1, 2020));
        Futura."Vigencia Desde" := DMY2Date(1, 2, 2020);
        Futura."Orden Cálculo" := 40;
        Futura."Fórmula Orden Cálculo" := '40';
        Futura.Insert(true);
        Control.Analizar(DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Acumulador, Buffer);
        Buffer.Get(Acumulador);
        Assert(Buffer.Conflicto and (Buffer."Orden Mín. Lectura" = 20), 'Enero debe usar el lector anterior al aporte30.');
        Control.Analizar(DMY2Date(15, 2, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Acumulador, Buffer);
        Buffer.Get(Acumulador);
        Assert(not Buffer.Conflicto and (Buffer."Orden Mín. Lectura" = 40), 'La misma instancia debe seleccionar la vigencia de febrero y resolver de nuevo el orden.');
        Control.Analizar(DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Acumulador, Buffer);
        Buffer.Get(Acumulador);
        Assert(Buffer.Conflicto and (Buffer."Orden Mín. Lectura" = 20), 'Volver a enero no debe conservar ni el lector ni el resultado de febrero.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AnalisisReutilizadoRespetaTipoYConvenioDelOrden()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Concepto.Get(Lector, DMY2Date(1, 1, 2020));
        Concepto."Fórmula Orden Cálculo" := 'IF(TIPO_LIQ = ''REGULAR'' AND CONVENIO = ''TEST_CORR_CCT'', 20, 40)';
        Concepto.Modify(false);
        Control.Analizar(DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Acumulador, Buffer);
        Buffer.Get(Acumulador);
        Assert(Buffer.Conflicto and (Buffer."Orden Mín. Lectura" = 20), 'La rama regular del convenio elegido lee antes del aporte30.');
        Control.Analizar(DMY2Date(15, 1, 2020), 'LIQ_FINAL', 'TEST_CORR_CCT', 'GENERAL', Acumulador, Buffer);
        Buffer.Get(Acumulador);
        Assert(not Buffer.Conflicto and (Buffer."Orden Mín. Lectura" = 40), 'Cambiar solamente el tipo debe invalidar el orden resuelto.');
        Control.Analizar(DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_OTRO', 'GENERAL', Acumulador, Buffer);
        Buffer.Get(Acumulador);
        Assert(not Buffer.Conflicto and (Buffer."Orden Mín. Lectura" = 40), 'Cambiar solamente el convenio también debe invalidar el orden resuelto.');
        Control.Analizar(DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Acumulador, Buffer);
        Buffer.Get(Acumulador);
        Assert(Buffer.Conflicto and (Buffer."Orden Mín. Lectura" = 20), 'El contexto inicial debe recuperar su propia rama, sin heredar la última consulta.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AnalisisReutilizadoRespetaCategoriaYConvenioDeInclusion()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Restriccion: Record "Concepto CCT Vigente";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Restriccion."Cód. Concepto" := Aportante;
        Restriccion."Vigencia Desde" := DMY2Date(1, 1, 2020);
        Restriccion."Cód. Convenio" := 'TEST_CORR_CCT';
        Restriccion."Cód. Categoría" := 'CAT_A';
        Restriccion.Insert(false);
        Control.Analizar(DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'CAT_A', Acumulador, Buffer);
        Buffer.Get(Acumulador);
        Assert(Buffer.Conflicto and (Buffer."Cant. Aportes" = 1), 'La categoría incluida debe conservar el aporte tardío.');
        Control.Analizar(DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'CAT_B', Acumulador, Buffer);
        Buffer.Get(Acumulador);
        Assert(not Buffer.Conflicto and (Buffer."Cant. Aportes" = 0), 'Cambiar sólo la categoría debe volver a seleccionar los conceptos incluidos.');
        Control.Analizar(DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_OTRO', 'CAT_A', Acumulador, Buffer);
        Buffer.Get(Acumulador);
        Assert(not Buffer.Conflicto and (Buffer."Cant. Aportes" = 0), 'Una inclusión de otro convenio no pertenece a esta consulta.');
        Control.Analizar(DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'CAT_A', Acumulador, Buffer);
        Buffer.Get(Acumulador);
        Assert(Buffer.Conflicto and (Buffer."Cant. Aportes" = 1), 'Regresar al par incluido debe reconstruir su aporte.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AnalisisReutilizadoRenuevaFormulaYFraccionModificadas()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Fraccion: Record "Fracción Acumulador";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Control.Analizar(DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Acumulador, Buffer);
        Buffer.Get(Acumulador);
        Assert(Buffer.Conflicto, 'El diagnóstico inicial debe contener el aporte tardío.');
        Concepto.Get(Lector, DMY2Date(1, 1, 2020));
        Concepto.Fórmula := '1';
        Concepto.Modify(false);
        Control.Analizar(DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Acumulador, Buffer);
        Buffer.Get(Acumulador);
        Assert(not Buffer.Conflicto and (Buffer."Cant. Lecturas" = 0), 'Con iguales filtros debe desaparecer una lectura retirada de la configuración.');
        Concepto.Fórmula := Acumulador;
        Concepto.Modify(false);
        Fraccion.Get(Aportante, DMY2Date(1, 1, 2020), Acumulador);
        Fraccion.Porcentaje := 0;
        Fraccion.Modify(false);
        Control.Analizar(DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Acumulador, Buffer);
        Buffer.Get(Acumulador);
        Assert(not Buffer.Conflicto and (Buffer."Cant. Lecturas" = 1) and (Buffer."Cant. Aportes" = 0), 'Debe leer tanto la fórmula restaurada como la fracción anulada en la nueva operación.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure CorrectorReutilizadoEquivaleAInstanciaNuevaAlCambiarContexto()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Concepto: Record "Concepto Liquidación";
        Futura: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        OtraBase: Code[20];
        OtroAporte: Code[20];
        OtroLector: Code[20];
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        CrearCaso(OtraBase, OtroAporte, OtroLector, 40);
        Concepto.Get(Lector, DMY2Date(1, 1, 2020));
        Concepto."Fórmula Orden Cálculo" := 'IF(TIPO_LIQ = ''REGULAR'' AND CONVENIO = ''TEST_CORR_CCT'', 20, 40)';
        Concepto.Modify(false);
        Futura := Concepto;
        Futura."Vigencia Desde" := DMY2Date(1, 2, 2020);
        Futura."Orden Cálculo" := 40;
        Futura."Fórmula Orden Cálculo" := '40';
        Futura.Insert(true);
        AssertPropuestaIgualANuevaInstancia(Gestor, Acumulador, DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', true, Aportante);
        AssertPropuestaIgualANuevaInstancia(Gestor, Acumulador, DMY2Date(15, 1, 2020), 'LIQ_FINAL', 'TEST_CORR_CCT', false, '');
        AssertPropuestaIgualANuevaInstancia(Gestor, Acumulador, DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_OTRO', false, '');
        AssertPropuestaIgualANuevaInstancia(Gestor, Acumulador, DMY2Date(15, 2, 2020), 'REGULAR', 'TEST_CORR_CCT', false, '');
        AssertPropuestaIgualANuevaInstancia(Gestor, OtraBase, DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', false, '');
        AssertPropuestaIgualANuevaInstancia(Gestor, Acumulador, DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', true, Aportante);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PrepararRenuevaDependenciasModificadasDespuesDeProponer()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Concepto: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Explicacion: Text;
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Assert(Gestor.Proponer(Acumulador, DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Origen, Orden, Fecha, Explicacion), 'El caso inicial debe permitir adelantar el aporte.');
        Concepto.Get(Aportante, DMY2Date(1, 1, 2020));
        Concepto.Fórmula := '#' + Lector;
        Concepto.Modify(false);
        Assert(not Gestor.Preparar(Acumulador, DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Aportante, Origen, Orden, Fecha, Explicacion), 'Preparar debe volver a leer la fórmula: el aporte ahora necesita un lector que también depende de él.');
        Assert((Orden = 0) and Explicacion.Contains(Lector), 'La ventana bloqueada debe identificar la dependencia nueva, sin devolver el orden memorizado.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ValidarRenuevaOrdenLectorModificadoDespuesDePreparar()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Concepto: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Explicacion: Text;
        Formula: Text;
        Impacto: Text;
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        Assert(Gestor.Preparar(Acumulador, DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Aportante, Origen, Orden, Fecha, Explicacion), 'Debe prepararse el aporte19 antes del lector20.');
        Assert(Orden = 19, 'El caso debe conservar una propuesta concreta antes de modificar otro concepto.');
        Concepto.Get(Lector, DMY2Date(1, 1, 2020));
        Concepto."Orden Cálculo" := 10;
        Concepto."Fórmula Orden Cálculo" := '10';
        Concepto.Modify(false);
        // El origen físico no cambió: la guarda de rowversion sola no detectaría este cambio.
        asserterror Gestor.Validar(Acumulador, Origen, Fecha, Orden, 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Formula, Impacto);
        Assert(GetLastErrorText().Contains(Lector), 'Validar debe rechazar el aporte19 porque el lector ahora corre en10, aunque ya hubiese validado la propuesta dentro de Preparar.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ValidarRenuevaFraccionAgregadaDespuesDeProponer()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Acumulador: Code[20];
        Aportante: Code[20];
        Lector: Code[20];
        OtraBase: Code[20];
        OtroLector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Explicacion: Text;
        Formula: Text;
        Impacto: Text;
    begin
        CrearCaso(Acumulador, Aportante, Lector, 20);
        OtraBase := NuevoCodigo();
        OtroLector := NuevoCodigo();
        CrearConcepto(OtraBase, 0, '', true, false);
        CrearConcepto(OtroLector, 25, OtraBase, false, true);
        Assert(Gestor.Proponer(Acumulador, DMY2Date(15, 1, 2020), 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Origen, Orden, Fecha, Explicacion), 'Sin la segunda fracción, adelantar el aporte debe ser seguro.');
        Assert((Origen.Código = Aportante) and (Orden = 19), 'Debe revisarse la misma propuesta que cambia de lado respecto del otro lector25.');
        CrearFraccion(Aportante, OtraBase);
        // Cambió otra tabla sin alterar el rowversion del origen ni los filtros de revisión.
        asserterror Gestor.Validar(Acumulador, Origen, Fecha, Orden, 'REGULAR', 'TEST_CORR_CCT', 'GENERAL', Formula, Impacto);
        Assert(GetLastErrorText().Contains(OtroLector), 'Validar debe descubrir la fracción nueva y rechazar que el movimiento cambie el subtotal de la otra base.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure LoteCorrigeVariasBasesYTodosLosAportesDeUnaBase()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Tipo: Code[20];
        BaseA: Code[20];
        AporteA: Code[20];
        LectorA: Code[20];
        BaseB: Code[20];
        AporteB: Code[20];
        LectorB: Code[20];
        OtroAporte: Code[20];
        Cambios: Integer;
        Pendientes: Integer;
        CantidadAntes: Integer;
        Detalle: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, BaseA, AporteA, LectorA, 20);
        CrearCasoLotePrueba(Tipo, BaseB, AporteB, LectorB, 20);
        OtroAporte := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, OtroAporte, 40, '', false, false);
        CrearFraccion(OtroAporte, BaseA);
        CantidadAntes := ContarVersionesLotePrueba(Tipo);
        Gestor.CorregirTodos(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Cambios, Pendientes, Detalle);
        AssertLoteSinConflicto(Tipo, BaseA, DMY2Date(1, 2, 2020));
        AssertLoteSinConflicto(Tipo, BaseB, DMY2Date(1, 2, 2020));
        Assert(Cambios >= 3, 'El lote debe continuar después del primer aporte: son tres movimientos independientes seguros.');
        Assert(ContarVersionesLotePrueba(Tipo) = CantidadAntes + 3, 'Deben existir exactamente tres vigencias nuevas dentro del caso de prueba.');
        Assert((Detalle.Contains(BaseA)) and (Detalle.Contains(BaseB)), 'El resumen debe identificar las dos bases corregidas.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure LoteSinConflictosNoCreaVersionesNiAuditoria()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Historial: Record "Historial Fórmula Concepto";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Cambios: Integer;
        Pendientes: Integer;
        CantidadAntes: Integer;
        HistorialAntes: Integer;
        Detalle: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 40);
        CantidadAntes := ContarVersionesLotePrueba(Tipo);
        Historial.SetRange("Cód. Concepto", Aporte);
        HistorialAntes := Historial.Count();
        Gestor.CorregirTodos(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Cambios, Pendientes, Detalle);
        AssertLoteSinConflicto(Tipo, Base, DMY2Date(1, 2, 2020));
        Assert(ContarVersionesLotePrueba(Tipo) = CantidadAntes, 'Una base completa no necesita otra versión de sus conceptos.');
        Assert(Historial.Count() = HistorialAntes, 'No se debe auditar una corrección que no era necesaria.');
        Assert(Cambios = 0, 'Sin conflictos no se debe anunciar ninguna corrección.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure LoteRepetidoEsIdempotenteEnLaMismaFecha()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Nueva: Record "Concepto Liquidación";
        Antes: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Cambios: Integer;
        Pendientes: Integer;
        CantidadAntes: Integer;
        Detalle: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        Gestor.CorregirTodos(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Cambios, Pendientes, Detalle);
        Nueva.Get(Aporte, DMY2Date(1, 2, 2020));
        Antes := Nueva;
        CantidadAntes := ContarVersionesLotePrueba(Tipo);
        Gestor.CorregirTodos(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Cambios, Pendientes, Detalle);
        Nueva.Get(Aporte, DMY2Date(1, 2, 2020));
        Assert((Cambios = 0) and (ContarVersionesLotePrueba(Tipo) = CantidadAntes), 'Volver a pulsar la acción no debe crear otra vigencia ni repetir el arreglo.');
        Assert(Nueva.SystemRowVersion = Antes.SystemRowVersion, 'La segunda pasada tampoco debe reescribir la versión ya corregida.');
        AssertLoteSinConflicto(Tipo, Base, DMY2Date(1, 2, 2020));
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure LoteNoDifiereOrigenDeLaMismaFechaNiEntraEnBucle()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Concepto: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Cambios: Integer;
        Pendientes: Integer;
        CantidadAntes: Integer;
        Detalle: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        CantidadAntes := ContarVersionesLotePrueba(Tipo);
        Gestor.CorregirTodos(DMY2Date(1, 1, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Cambios, Pendientes, Detalle);
        Assert(ContarVersionesLotePrueba(Tipo) = CantidadAntes, 'La acción de lote no puede pasar silenciosamente la corrección al día siguiente de la fecha elegida.');
        Assert(not Concepto.Get(Aporte, DMY2Date(2, 1, 2020)), 'No debe crear una vigencia de aporte el 02/01 al solicitar el 01/01.');
        Assert(not Concepto.Get(Lector, DMY2Date(2, 1, 2020)), 'Tampoco debe diferir la corrección mediante un lector alternativo.');
        Assert((Pendientes > 0) and Detalle.Contains(Base), 'El conflicto sin fecha disponible debe quedar informado como pendiente.');
        Gestor.CorregirTodos(DMY2Date(1, 1, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Cambios, Pendientes, Detalle);
        Assert(ContarVersionesLotePrueba(Tipo) = CantidadAntes, 'Reintentar un pendiente de fecha ocupada debe terminar sin cambios.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure LoteContinuaConBaseCorregibleAunqueOtraEsteBloqueada()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Concepto: Record "Concepto Liquidación";
        Antes: Record "Concepto Liquidación";
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Tipo: Code[20];
        BaseBloqueada: Code[20];
        AporteBloqueado: Code[20];
        LectorBloqueado: Code[20];
        BaseSegura: Code[20];
        AporteSeguro: Code[20];
        LectorSeguro: Code[20];
        Cambios: Integer;
        Pendientes: Integer;
        Detalle: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, BaseBloqueada, AporteBloqueado, LectorBloqueado, 20);
        CrearCasoLotePrueba(Tipo, BaseSegura, AporteSeguro, LectorSeguro, 20);
        Concepto.Get(AporteBloqueado, DMY2Date(1, 1, 2020));
        Concepto.Fórmula := '#' + LectorBloqueado;
        Concepto.Modify(false);
        Concepto.Get(AporteBloqueado, DMY2Date(1, 1, 2020));
        Antes := Concepto;
        Gestor.CorregirTodos(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Cambios, Pendientes, Detalle);
        AssertLoteSinConflicto(Tipo, BaseSegura, DMY2Date(1, 2, 2020));
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', BaseBloqueada, Buffer);
        Buffer.Get(BaseBloqueada);
        Assert(Buffer.Conflicto and (Pendientes > 0), 'Un ciclo sin ventana segura debe permanecer pendiente sin impedir otra corrección.');
        Concepto.Get(AporteBloqueado, DMY2Date(1, 1, 2020));
        Assert(Concepto.SystemRowVersion = Antes.SystemRowVersion, 'El lote no debe tocar el aporte para el que no se encontró una ventana segura.');
        Assert(Detalle.Contains(BaseBloqueada), 'El resultado debe explicar la base que sigue sin resolver.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure LoteExcluyeTodaLaBasePorEtapasAunqueOtroAporteSeaMovible()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Concepto: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        AporteEtapa: Code[20];
        Lector: Code[20];
        OtroAporte: Code[20];
        Cambios: Integer;
        Pendientes: Integer;
        CantidadAntes: Integer;
        Detalle: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, AporteEtapa, Lector, 20);
        Concepto.Get(AporteEtapa, DMY2Date(1, 1, 2020));
        Concepto.Fórmula := Base;
        Concepto.Modify(false);
        OtroAporte := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, OtroAporte, 40, '', false, false);
        CrearFraccion(OtroAporte, Base);
        CantidadAntes := ContarVersionesLotePrueba(Tipo);
        Gestor.CorregirTodos(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Cambios, Pendientes, Detalle);
        Assert(ContarVersionesLotePrueba(Tipo) = CantidadAntes, 'La protección por etapas corresponde al acumulador completo, no sólo al concepto que lee y aporta.');
        Assert(not Concepto.Get(OtroAporte, DMY2Date(1, 2, 2020)), 'El aporte aparentemente movible tampoco debe adelantarse: alteraría el subtotal de la etapa.');
        Assert((Pendientes > 0) and Detalle.Contains(Base), 'La base por etapas debe quedar para revisión explícita.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure LoteConservaFormulaReciboYFraccionAlVersionarElOrden()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Nueva: Record "Concepto Liquidación";
        Cabecera: Record "Liquidación";
        CabeceraAntes: Record "Liquidación";
        Linea: Record "Línea Liquidación";
        LineaAntes: Record "Línea Liquidación";
        Fraccion: Record "Fracción Acumulador";
        FraccionAntes: Record "Fracción Acumulador";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Cambios: Integer;
        Pendientes: Integer;
        Detalle: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        Origen.Get(Aporte, DMY2Date(1, 1, 2020));
        Origen.Fórmula := '99.875';
        Origen.Condición := '1 = 1';
        Origen."Variable Cantidad" := 'DIAS_CORRECCION_TEST';
        Origen."Variable Base" := 'BASE_CORRECCION_TEST';
        Origen.Modify(false);
        Origen.Get(Aporte, DMY2Date(1, 1, 2020));
        CrearRecibo(Origen, DMY2Date(15, 1, 2020), Cabecera, Linea);
        CabeceraAntes := Cabecera;
        LineaAntes := Linea;
        Fraccion.Get(Aporte, DMY2Date(1, 1, 2020), Base);
        FraccionAntes := Fraccion;
        Gestor.CorregirTodos(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Cambios, Pendientes, Detalle);
        Nueva.Get(Aporte, DMY2Date(1, 2, 2020));
        Assert((Nueva.Fórmula = Origen.Fórmula) and (Nueva.Condición = Origen.Condición), 'Versionar el orden en lote debe conservar fórmula de importe y condición.');
        Assert((Nueva."Variable Cantidad" = Origen."Variable Cantidad") and (Nueva."Variable Base" = Origen."Variable Base"), 'Las variables de cantidad y base deben conservarse.');
        Origen.Get(Aporte, DMY2Date(1, 1, 2020));
        Assert(Origen."Vigencia Hasta" = DMY2Date(31, 1, 2020), 'La vigencia anterior debe cerrarse sólo el día previo a la referencia elegida.');
        Cabecera.Get(CabeceraAntes."No.");
        Linea.Get(LineaAntes."No. Liquidación", LineaAntes."No. Línea");
        Fraccion.Get(Aporte, DMY2Date(1, 1, 2020), Base);
        Assert((Cabecera.SystemRowVersion = CabeceraAntes.SystemRowVersion) and (Linea.SystemRowVersion = LineaAntes.SystemRowVersion), 'El lote no debe recalcular ni reescribir recibos guardados.');
        Assert(Fraccion.SystemRowVersion = FraccionAntes.SystemRowVersion, 'Las fracciones tampoco deben versionarse ni reescribirse al corregir órdenes.');
        AssertLoteSinConflicto(Tipo, Base, DMY2Date(1, 2, 2020));
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure LoteDejaPendienteSiLosCandidatosTienenUsoPosterior()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Cabecera: Record "Liquidación";
        Linea: Record "Línea Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Cambios: Integer;
        Pendientes: Integer;
        CantidadAntes: Integer;
        Detalle: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        Origen.Get(Aporte, DMY2Date(1, 1, 2020));
        CrearRecibo(Origen, DMY2Date(15, 2, 2020), Cabecera, Linea);
        Origen.Get(Lector, DMY2Date(1, 1, 2020));
        CrearRecibo(Origen, DMY2Date(15, 2, 2020), Cabecera, Linea);
        CantidadAntes := ContarVersionesLotePrueba(Tipo);
        Gestor.CorregirTodos(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Cambios, Pendientes, Detalle);
        Assert(ContarVersionesLotePrueba(Tipo) = CantidadAntes, 'No se debe cerrar antes del uso calculado ni el aportante ni el lector alternativo.');
        Assert((Pendientes > 0) and Detalle.Contains(Base), 'El uso posterior debe dejar la base pendiente con un motivo visible.');
        Origen.Get(Aporte, DMY2Date(1, 1, 2020));
        Assert(Origen."Vigencia Hasta" = 0D, 'El rechazo por uso posterior debe conservar abierta la versión usada.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure LoteReintentaBaseBloqueadaDespuesDeCorregirSuEntrada()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Tipo: Code[20];
        Prefijo: Code[20];
        BaseA: Code[20];
        BaseB: Code[20];
        AporteA: Code[20];
        AporteB: Code[20];
        LectorA: Code[20];
        LectorB: Code[20];
        Consumidor: Code[20];
        Nueva: Record "Concepto Liquidación";
        Cambios: Integer;
        Pendientes: Integer;
        Detalle: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        Prefijo := CopyStr(NuevoCodigo(), 1, 15);
        BaseA := Prefijo + 'A';
        BaseB := Prefijo + 'B';
        AporteA := Prefijo + 'C';
        AporteB := Prefijo + 'D';
        LectorA := Prefijo + 'E';
        LectorB := Prefijo + 'F';
        Consumidor := Prefijo + 'G';
        CrearConceptoLotePrueba(Tipo, BaseA, 0, '', true, false);
        CrearConceptoLotePrueba(Tipo, BaseB, 0, '', true, false);
        CrearConceptoLotePrueba(Tipo, AporteA, 50, '#' + AporteB, false, false);
        CrearConceptoLotePrueba(Tipo, AporteB, 40, '', false, false);
        CrearConceptoLotePrueba(Tipo, LectorA, 30, BaseA, false, true);
        CrearConceptoLotePrueba(Tipo, LectorB, 20, BaseB, false, true);
        CrearConceptoLotePrueba(Tipo, Consumidor, 35, '#' + LectorA, false, true);
        CrearFraccion(AporteA, BaseA);
        CrearFraccion(AporteB, BaseB);
        Gestor.CorregirTodos(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Cambios, Pendientes, Detalle);
        AssertLoteSinConflicto(Tipo, BaseA, DMY2Date(1, 2, 2020));
        AssertLoteSinConflicto(Tipo, BaseB, DMY2Date(1, 2, 2020));
        Nueva.Get(AporteA, DMY2Date(1, 2, 2020));
        Assert(Nueva.Fórmula = '#' + AporteB, 'La base inicialmente bloqueada debe habilitarse moviendo su entrada, sin cambiar su fórmula.');
        Assert(Cambios >= 2, 'El lote debe volver a la primera base después de corregir la segunda.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure LoteDejaPendienteLaNecesidadQueDependeDelAportanteDePuesto()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        AporteAntes: Record "Concepto Liquidación";
        LectorAntes: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Cambios: Integer;
        Pendientes: Integer;
        CantidadAntes: Integer;
        Detalle: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        Concepto.Get(Aporte, DMY2Date(1, 1, 2020));
        Concepto."Par CCT a Usar" := Concepto."Par CCT a Usar"::Puesto;
        Concepto.Modify(false);
        Concepto.Get(Aporte, DMY2Date(1, 1, 2020));
        AporteAntes := Concepto;
        LectorAntes.Get(Lector, DMY2Date(1, 1, 2020));
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Base, Buffer);
        Buffer.Get(Base);
        Assert(Buffer."Requiere Contexto", 'El diagnóstico debe reconocer que falta el puesto de una liquidación concreta.');
        CantidadAntes := ContarVersionesLotePrueba(Tipo);
        Gestor.CorregirTodos(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Cambios, Pendientes, Detalle);
        Assert((Cambios = 0) and (Pendientes = 1) and (ContarVersionesLotePrueba(Tipo) = CantidadAntes), 'El aporte de puesto sólo demuestra una coexistencia posible: el lote debe conservar el pendiente sin crear versiones.');
        Concepto.Get(Aporte, DMY2Date(1, 1, 2020));
        Assert(Concepto.SystemRowVersion = AporteAntes.SystemRowVersion, 'El pendiente no debe tocar la fuente que usa puesto.');
        Assert(not Concepto.Get(Aporte, DMY2Date(1, 2, 2020)), 'No debe crearse una versión de la fuente con el par del puesto desconocido.');
        Assert(not Concepto.Get(Lector, DMY2Date(1, 2, 2020)), 'Tampoco debe atrasarse el lector suponiendo que el aporte de puesto necesariamente le aplica.');
        Concepto.Get(Lector, DMY2Date(1, 1, 2020));
        Assert(Concepto.SystemRowVersion = LectorAntes.SystemRowVersion, 'La falta de necesidad comprobada debe conservar la vigencia exacta del lector.');
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Base, Buffer);
        Buffer.Get(Base);
        Assert(Buffer.Conflicto and Buffer."Requiere Contexto", 'La precedencia potencial debe seguir visible para la revisión individual del puesto.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure LoteMueveDosLectoresAunqueElPrimerCambioNoBajeCantidadAportes()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Motor: Codeunit "Motor Liquidación";
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        AporteAntes: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Entrada: Code[20];
        PrimerLector: Code[20];
        SegundoLector: Code[20];
        Cambios: Integer;
        Pendientes: Integer;
        CantidadAntes: Integer;
        Detalle: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        Base := NuevoCodigo();
        Aporte := NuevoCodigo();
        Entrada := NuevoCodigo();
        PrimerLector := NuevoCodigo();
        SegundoLector := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, Base, 0, '', true, false);
        CrearConceptoLotePrueba(Tipo, Entrada, 50, '1', false, false);
        CrearConceptoLotePrueba(Tipo, Aporte, 100, '#' + Entrada, false, false);
        CrearConceptoLotePrueba(Tipo, PrimerLector, 10, Base, false, true);
        CrearConceptoLotePrueba(Tipo, SegundoLector, 20, Base, false, true);
        CrearFraccion(Aporte, Base);
        AporteAntes.Get(Aporte, DMY2Date(1, 1, 2020));
        CantidadAntes := ContarVersionesLotePrueba(Tipo);
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Base, Buffer);
        Buffer.Get(Base);
        Assert((Buffer."Aportes en Conflicto" = 1) and (Buffer."Cant. Lecturas" = 2), 'Hay un único aporte tardío frente a dos lectores; mover sólo uno no reduce el conteo de aportes.');
        Gestor.CorregirTodos(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Cambios, Pendientes, Detalle);
        Assert(Cambios = 2, 'Deben admitirse los dos movimientos de lectores: el progreso del primero conserva un aporte tardío frente al lector restante.');
        Assert(ContarVersionesLotePrueba(Tipo) = CantidadAntes + 2, 'Sólo deben crearse las dos vigencias nuevas de lectores.');
        Concepto.Get(PrimerLector, DMY2Date(1, 2, 2020));
        Assert(Motor.OrdenEfectivo(Concepto, Tipo, 'TEST_CORR_CCT') > 100, 'El primer lector debe quedar después del aporte100.');
        Concepto.Get(SegundoLector, DMY2Date(1, 2, 2020));
        Assert(Motor.OrdenEfectivo(Concepto, Tipo, 'TEST_CORR_CCT') > 100, 'El segundo lector también debe quedar después del aporte100.');
        Assert(not Concepto.Get(Aporte, DMY2Date(1, 2, 2020)), 'La entrada50 impide adelantar el aporte antes de los lectores originales.');
        Concepto.Get(Aporte, DMY2Date(1, 1, 2020));
        Assert((Concepto.SystemRowVersion = AporteAntes.SystemRowVersion) and (Concepto."Fórmula Orden Cálculo" = '100'), 'La fuente debe conservar su versión original y su orden100.');
        AssertLoteSinConflicto(Tipo, Base, DMY2Date(1, 2, 2020));
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ConceptoAcotaDiagnosticoABasesQueLeeOAporta()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Global: Record "Diag. Orden Acum. Buffer" temporary;
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        BaseA: Code[20];
        AporteA: Code[20];
        LectorA: Code[20];
        BaseB: Code[20];
        BaseAjena: Code[20];
        AporteAjeno: Code[20];
        LectorAjeno: Code[20];
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, BaseA, AporteA, LectorA, 20);
        CrearCasoLotePrueba(Tipo, BaseAjena, AporteAjeno, LectorAjeno, 20);
        BaseB := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, BaseB, 0, '', true, false);
        Origen.Get(AporteA, DMY2Date(1, 1, 2020));
        Origen.Fórmula := BaseB;
        Origen.Modify(false);
        Origen.Get(AporteA, DMY2Date(1, 1, 2020));
        Gestor.AnalizarConcepto(Origen, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Buffer);
        Assert(Buffer.Count() = 2, 'El alcance del concepto debe combinar la base aportada y la leída, sin traer otros conflictos globales.');
        Assert(not Buffer.Get(BaseAjena), 'Una base sin relación con el concepto de la ficha debe quedar fuera del diagnóstico.');
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Global);
        Buffer.Get(BaseA);
        Global.Get(BaseA);
        AssertMismoDiagnostico(Global, Buffer);
        Buffer.Get(BaseB);
        Global.Get(BaseB);
        AssertMismoDiagnostico(Global, Buffer);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ConceptoLectorSinFraccionIncluyeSuBase()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Origen: Record "Concepto Liquidación";
        Fraccion: Record "Fracción Acumulador";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Hallazgos: Integer;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        Origen.Get(Lector, DMY2Date(1, 1, 2020));
        Fraccion.SetRange("Cód. Concepto", Lector);
        Assert(Fraccion.IsEmpty(), 'El lector del caso no tiene fracciones propias.');
        Hallazgos := Gestor.AnalizarConcepto(Origen, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Buffer);
        Buffer.Get(Base);
        Assert((Buffer.Count() = 1) and Buffer.Conflicto and (Hallazgos = 1), 'Leer una base basta para incorporarla al control de la ficha, aunque no se la alimente.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ConceptoExpandeLecturasDeAcumuladoresPorArroba()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        BaseA: Code[20];
        BaseB: Code[20];
        BaseAjena: Code[20];
        Codigo: Code[20];
        Intermedio: Code[20];
        Puente: Code[20];
    begin
        Tipo := PrepararTipoLotePrueba();
        BaseA := NuevoCodigo();
        BaseB := NuevoCodigo();
        BaseAjena := NuevoCodigo();
        Codigo := NuevoCodigo();
        Intermedio := NuevoCodigo();
        Puente := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, BaseA, 0, '', true, false);
        CrearConceptoLotePrueba(Tipo, BaseB, 0, '', true, false);
        CrearConceptoLotePrueba(Tipo, BaseAjena, 0, '', true, false);
        CrearConceptoLotePrueba(Tipo, Puente, 10, '#' + BaseB, false, true);
        CrearConceptoLotePrueba(Tipo, Intermedio, 20, BaseA + ' + @' + Puente, false, true);
        CrearConceptoLotePrueba(Tipo, Codigo, 30, '@' + Intermedio, false, false);
        Origen.Get(Codigo, DMY2Date(1, 1, 2020));
        Gestor.AnalizarConcepto(Origen, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Buffer);
        Assert(Buffer.Count() = 2, 'La expansión de dos niveles de @ debe descubrir ambas bases, sin incluir todos los acumuladores del catálogo.');
        Assert(Buffer.Get(BaseA), 'Debe aparecer la base leída dentro de la fórmula reevaluada por @.');
        Assert(Buffer.Get(BaseB), 'Debe aparecer también el acumulador con # que lee el segundo nivel de @.');
        Assert(not Buffer.Get(BaseAjena), 'La expansión de @ no debe ampliar el alcance a una base ajena.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ConceptoHistoricoNoSustituyeLaVersionQueSeSelecciono()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Historico: Record "Concepto Liquidación";
        Futura: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
        CantidadAntes: Integer;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        Historico.Get(Aporte, DMY2Date(1, 1, 2020));
        Futura := Historico;
        Futura."Vigencia Desde" := DMY2Date(1, 2, 2020);
        Futura."Fórmula Orden Cálculo" := '40';
        Futura.Insert(true);
        // Volver a leer evita que el rechazo se deba sólo al rowversion del cierre automático.
        Historico.Get(Aporte, DMY2Date(1, 1, 2020));
        CantidadAntes := ContarVersionesLotePrueba(Tipo);
        Assert(not IntentarAnalizarConceptoSinRevertirFixturePrueba(Gestor, Historico, DMY2Date(15, 2, 2020), Tipo, Buffer), 'El origen histórico debe producir un error de guarda.');
        Assert(GetLastErrorText() <> '', 'Una fecha que selecciona otra vigencia debe rechazar el origen histórico exacto.');
        Assert(not IntentarPrepararConceptoSinRevertirFixturePrueba(Gestor, Historico, Base, DMY2Date(15, 2, 2020), Tipo, false, Origen, Orden, Fecha, Motivo), 'La propuesta histórica debe producir un error de guarda.');
        Assert(GetLastErrorText() <> '', 'Preparar desde la ficha histórica no debe sustituirla silenciosamente por la vigente.');
        Assert(ContarVersionesLotePrueba(Tipo) = CantidadAntes, 'Ambos rechazos deben ser sólo de lectura.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ConceptoRechazaElRegistroObsoletoSinEscribir()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Seleccionado: Record "Concepto Liquidación";
        Actual: Record "Concepto Liquidación";
        Antes: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
        CantidadAntes: Integer;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        Seleccionado.Get(Aporte, DMY2Date(1, 1, 2020));
        Actual := Seleccionado;
        Actual.Descripción := 'Edición posterior a la selección de ficha';
        Actual.Modify(false);
        Actual.Get(Aporte, DMY2Date(1, 1, 2020));
        Antes := Actual;
        CantidadAntes := ContarVersionesLotePrueba(Tipo);
        Assert(not IntentarAnalizarConceptoSinRevertirFixturePrueba(Gestor, Seleccionado, DMY2Date(1, 2, 2020), Tipo, Buffer), 'El origen obsoleto debe producir un error de guarda.');
        Assert(GetLastErrorText() <> '', 'El diagnóstico debe rechazar una foto de ficha anterior a un cambio físico.');
        Assert(not IntentarPrepararConceptoSinRevertirFixturePrueba(Gestor, Seleccionado, Base, DMY2Date(1, 2, 2020), Tipo, false, Origen, Orden, Fecha, Motivo), 'La propuesta obsoleta debe producir un error de guarda.');
        Assert(GetLastErrorText() <> '', 'La propuesta fija también debe comprobar el rowversion seleccionado.');
        Actual.Get(Aporte, DMY2Date(1, 1, 2020));
        Assert((Actual.SystemRowVersion = Antes.SystemRowVersion) and (ContarVersionesLotePrueba(Tipo) = CantidadAntes), 'Rechazar una selección obsoleta no debe tocar el registro ni crear vigencias.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ConceptoPreparaElLectorElegidoAunqueLaPropuestaGeneralElijaElAporte()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Seleccionado: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        Assert(Gestor.Proponer(Base, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Origen, Orden, Fecha, Motivo), 'La base debe admitir la propuesta general de adelantar su aporte.');
        Assert((Origen.Código = Aporte) and (Orden = 19), 'La propuesta general sirve de control: elige adelantar el aportante.');
        Seleccionado.Get(Lector, DMY2Date(1, 1, 2020));
        if not Gestor.PrepararConcepto(Seleccionado, Base, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Origen, Orden, Fecha, Motivo) then
            Error('Debe existir una alternativa válida para el lector seleccionado: %1', Motivo);
        Assert((Origen.Código = Lector) and (Origen."Vigencia Desde" = Seleccionado."Vigencia Desde"), 'La ficha sólo debe proponer mover el concepto exacto seleccionado, no el aportante preferido por el modo general.');
        Assert((Origen.SystemRowVersion = Seleccionado.SystemRowVersion) and (Orden = 31), 'La propuesta fija debe conservar el origen físico y atrasar el lector después del aporte30.');
        Assert(Fecha = DMY2Date(1, 2, 2020), 'La propuesta debe conservar la referencia elegida para esa ficha.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ConceptoRechazaPrepararUnaBaseAjena()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Seleccionado: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        BaseAjena: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
        CantidadAntes: Integer;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        BaseAjena := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, BaseAjena, 0, '', true, false);
        Seleccionado.Get(Aporte, DMY2Date(1, 1, 2020));
        CantidadAntes := ContarVersionesLotePrueba(Tipo);
        Assert(not IntentarPrepararConceptoSinRevertirFixturePrueba(Gestor, Seleccionado, BaseAjena, DMY2Date(1, 2, 2020), Tipo, false, Origen, Orden, Fecha, Motivo), 'La base ajena debe producir un error de guarda.');
        Assert(GetLastErrorText() <> '', 'La API fija debe rechazar una base que el concepto seleccionado no lee ni alimenta.');
        Assert(ContarVersionesLotePrueba(Tipo) = CantidadAntes, 'Una base ajena no debe provocar ninguna escritura.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ConceptoAcumuladorSoloDiagnosticaSuPropiaBaseSinProponerOrden()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Seleccionado: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        OtraBase: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        OtraBase := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, OtraBase, 0, '', true, false);
        Seleccionado.Get(Base, DMY2Date(1, 1, 2020));
        Seleccionado.Fórmula := OtraBase;
        Seleccionado.Modify(false);
        Seleccionado.Get(Base, DMY2Date(1, 1, 2020));
        Gestor.AnalizarConcepto(Seleccionado, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Buffer);
        Assert((Buffer.Count() = 1) and Buffer.Get(Base), 'Desde un acumulador se debe mostrar únicamente su base propia, aunque tenga otros identificadores en su configuración.');
        Orden := 777;
        Assert(not Gestor.PrepararConcepto(Seleccionado, Base, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Origen, Orden, Fecha, Motivo), 'El acumulador no tiene una posición de ejecución propia que pueda corregirse.');
        Assert((Orden = 0) and (Motivo <> ''), 'Debe explicar la falta de orden propio, sin exponer una corrección ficticia.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ConceptoConReferenciaNumeralSinBasesMuestraSuDependencia()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Seleccionado: Record "Concepto Liquidación";
        Tipo: Code[20];
        BaseAjena: Code[20];
        Codigo: Code[20];
        Entrada: Code[20];
        Hallazgos: Integer;
    begin
        Tipo := PrepararTipoLotePrueba();
        BaseAjena := NuevoCodigo();
        Codigo := NuevoCodigo();
        Entrada := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, BaseAjena, 0, '', true, false);
        CrearConceptoLotePrueba(Tipo, Entrada, 40, '1', false, false);
        // La referencia # debe tener una fila propia aunque no participe de ningún acumulador.
        CrearConceptoLotePrueba(Tipo, Codigo, 20, '#' + Entrada, false, false);
        Seleccionado.Get(BaseAjena, DMY2Date(1, 1, 2020));
        Gestor.AnalizarConcepto(Seleccionado, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Buffer);
        Assert(Buffer.Count() = 1, 'La primera consulta llena el temporal para comprobar que la segunda lo descarte.');
        Seleccionado.Get(Codigo, DMY2Date(1, 1, 2020));
        Hallazgos := Gestor.AnalizarConcepto(Seleccionado, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Buffer);
        Assert((Hallazgos = 1) and (Buffer.Count() = 1), 'La segunda consulta debe sustituir la base ajena por la dependencia propia del concepto.');
        Buffer.Get(Codigo);
        Assert(Buffer.Conflicto and (Buffer."Concepto Máx. Aporte" = Entrada) and (Buffer."Concepto Mín. Lectura" = Codigo), 'La entrada40 queda después del concepto20 que la lee: el diagnóstico debe identificar ambos extremos.');
        Assert(not Buffer.Get(BaseAjena), 'No debe quedar la fila de la consulta anterior.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ConceptoSeleccionaFraccionesVigentesYDescartaLaAnulada()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Seleccionado: Record "Concepto Liquidación";
        Fraccion: Record "Fracción Acumulador";
        Tipo: Code[20];
        BaseA: Code[20];
        BaseB: Code[20];
        Codigo: Code[20];
    begin
        Tipo := PrepararTipoLotePrueba();
        BaseA := NuevoCodigo();
        BaseB := NuevoCodigo();
        Codigo := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, BaseA, 0, '', true, false);
        CrearConceptoLotePrueba(Tipo, BaseB, 0, '', true, false);
        CrearConceptoLotePrueba(Tipo, Codigo, 30, '1', false, false);
        CrearFraccion(Codigo, BaseA);
        Fraccion.Get(Codigo, DMY2Date(1, 1, 2020), BaseA);
        Fraccion."Vigencia Desde" := DMY2Date(1, 2, 2020);
        Fraccion.Porcentaje := 0;
        Fraccion.Insert(false);
        Fraccion.Init();
        Fraccion."Cód. Concepto" := Codigo;
        Fraccion."Vigencia Desde" := DMY2Date(1, 2, 2020);
        Fraccion."Cód. Acumulador" := BaseB;
        Fraccion.Porcentaje := 100;
        Fraccion.Insert(false);
        Seleccionado.Get(Codigo, DMY2Date(1, 1, 2020));
        Gestor.AnalizarConcepto(Seleccionado, DMY2Date(15, 1, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Buffer);
        Assert((Buffer.Count() = 1) and Buffer.Get(BaseA), 'En enero sólo debe incluirse la fracción vigente de la baseA.');
        Gestor.AnalizarConcepto(Seleccionado, DMY2Date(15, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Buffer);
        Assert((Buffer.Count() = 1) and Buffer.Get(BaseB), 'En febrero debe ganar la fracción nueva de baseB y desaparecer la baseA anulada, sin arrastrar el alcance anterior.');
        Assert(not Buffer.Get(BaseA), 'Una fracción anterior al 0% vigente no puede incorporar una base al alcance.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ActualizarVigenciaConservaClaveIntervaloFormulaReciboYAuditaOrden()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Motor: Codeunit "Motor Liquidación";
        Origen: Record "Concepto Liquidación";
        Actual: Record "Concepto Liquidación";
        Futura: Record "Concepto Liquidación";
        FuturaAntes: Record "Concepto Liquidación";
        Cabecera: Record "Liquidación";
        CabeceraAntes: Record "Liquidación";
        Linea: Record "Línea Liquidación";
        LineaAntes: Record "Línea Liquidación";
        Fraccion: Record "Fracción Acumulador";
        FraccionAntes: Record "Fracción Acumulador";
        Historial: Record "Historial Fórmula Concepto";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        VersionesAntes: Integer;
        HistorialAntes: Integer;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        Origen.Get(Aporte, DMY2Date(1, 1, 2020));
        Origen.Fórmula := '99.875';
        Origen.Condición := '1 = 1';
        Origen."Variable Cantidad" := 'DIAS_CORRECCION_TEST';
        Origen."Variable Base" := 'BASE_CORRECCION_TEST';
        Origen.Modify(false);
        Futura := Origen;
        Futura."Vigencia Desde" := DMY2Date(1, 4, 2020);
        Futura."Fórmula Orden Cálculo" := '40';
        Futura.Insert(true);
        Futura.Get(Aporte, DMY2Date(1, 4, 2020));
        FuturaAntes := Futura;
        Origen.Get(Aporte, DMY2Date(1, 1, 2020));
        CrearRecibo(Origen, DMY2Date(15, 2, 2020), Cabecera, Linea);
        CabeceraAntes := Cabecera;
        LineaAntes := Linea;
        Fraccion.Get(Aporte, DMY2Date(1, 1, 2020), Base);
        FraccionAntes := Fraccion;
        VersionesAntes := ContarVersionesLotePrueba(Tipo);
        Historial.SetRange("Cód. Concepto", Aporte);
        Historial.SetRange("Vigencia Desde", Origen."Vigencia Desde");
        Historial.SetRange("Tipo Cambio", Historial."Tipo Cambio"::Orden);
        HistorialAntes := Historial.Count();
        Gestor.Aplicar(Base, Origen, Origen."Vigencia Desde", 10, Tipo, 'TEST_CORR_CCT', 'GENERAL', true);
        Actual.Get(Aporte, DMY2Date(1, 1, 2020));
        Assert((Actual."Vigencia Hasta" = Origen."Vigencia Hasta") and (ContarVersionesLotePrueba(Tipo) = VersionesAntes), 'Actualizar la vigencia debe conservar exactamente la clave, su intervalo y la cantidad de versiones.');
        Assert(Motor.OrdenEfectivo(Actual, Tipo, 'TEST_CORR_CCT') = 10, 'La expresión actualizada debe resolver el orden solicitado.');
        Assert((Actual.Fórmula = Origen.Fórmula) and (Actual.Condición = Origen.Condición), 'Actualizar orden no debe modificar fórmula monetaria ni condición.');
        Assert((Actual."Variable Cantidad" = Origen."Variable Cantidad") and (Actual."Variable Base" = Origen."Variable Base"), 'Los campos de cantidad y base deben permanecer iguales.');
        Cabecera.Get(CabeceraAntes."No.");
        Linea.Get(LineaAntes."No. Liquidación", LineaAntes."No. Línea");
        Fraccion.Get(Aporte, DMY2Date(1, 1, 2020), Base);
        Futura.Get(Aporte, DMY2Date(1, 4, 2020));
        Assert((Cabecera.SystemRowVersion = CabeceraAntes.SystemRowVersion) and (Linea.SystemRowVersion = LineaAntes.SystemRowVersion), 'Los usos calculados guardados deben permanecer intactos.');
        Assert((Fraccion.SystemRowVersion = FraccionAntes.SystemRowVersion) and (Futura.SystemRowVersion = FuturaAntes.SystemRowVersion), 'No se deben alterar fracciones ni una vigencia futura del concepto.');
        Assert(Historial.Count() = HistorialAntes + 1, 'La actualización debe generar una auditoría de orden en la misma clave de vigencia.');
        Historial.FindLast();
        Assert((Historial."Fórmula Anterior" = Origen."Fórmula Orden Cálculo") and (Historial."Fórmula Nueva" = Actual."Fórmula Orden Cálculo"), 'La auditoría debe conservar ambas expresiones de orden completas.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ActualizarVigenciaPermiteUsoCalculadoSinRelajarElModoNuevaVersion()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Cabecera: Record "Liquidación";
        Linea: Record "Línea Liquidación";
        LineaAntes: Record "Línea Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        Origen.Get(Aporte, DMY2Date(1, 1, 2020));
        CrearRecibo(Origen, DMY2Date(15, 2, 2020), Cabecera, Linea);
        LineaAntes := Linea;
        Gestor.Aplicar(Base, Origen, Origen."Vigencia Desde", 10, Tipo, 'TEST_CORR_CCT', 'GENERAL', true);
        Linea.Get(LineaAntes."No. Liquidación", LineaAntes."No. Línea");
        Assert(Linea.SystemRowVersion = LineaAntes.SystemRowVersion, 'El permiso de actualizar una versión ya usada no debe provocar un recálculo ni una reescritura de su línea.');
        Origen.Get(Aporte, DMY2Date(1, 1, 2020));
        Assert(Origen."Vigencia Hasta" = 0D, 'La actualización debe conservar el intervalo abierto, sin cerrarlo en enero.');
        // Aplicar toma locks: su rechazo se prueba fuera de TryFunction y al final de la fixture.
        asserterror Gestor.Aplicar(Base, Origen, DMY2Date(1, 2, 2020), 10, Tipo, 'TEST_CORR_CCT', 'GENERAL');
        Assert(GetLastErrorText().Contains(Cabecera."No."), 'La firma anterior debe seguir impidiendo cerrar una versión usada después del corte.');
        AssertRollbackSinVigenciasNiAuditoriaPrueba(Tipo, Aporte);
        Assert(not Cabecera.Get(Cabecera."No."), 'El rollback del rechazo debe retirar también la cabecera sintética, sin dejar escrituras parciales del ensayo.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ActualizarVigenciaProponeSuInicioExactoSinDesplazarloUnDia()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
        VersionesAntes: Integer;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        VersionesAntes := ContarVersionesLotePrueba(Tipo);
        if not Gestor.Proponer(Base, DMY2Date(1, 1, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Origen, Orden, Fecha, Motivo) then
            Error('Debe proponer una actualización desde el mismo inicio de la versión: %1', Motivo);
        Assert((Origen.Código = Aporte) and (Fecha = DMY2Date(1, 1, 2020)), 'El modo actualización debe conservar el 01/01, sin desplazar al 02/01.');
        if not Gestor.Preparar(Base, DMY2Date(15, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Aporte, true, Origen, Orden, Fecha, Motivo) then
            Error('Preparar debe revisar el intervalo de la versión abierta: %1', Motivo);
        Assert(Fecha = DMY2Date(1, 1, 2020), 'Aunque la referencia sea febrero, la actualización debe abarcar el inicio real de enero.');
        Assert(ContarVersionesLotePrueba(Tipo) = VersionesAntes, 'Las dos propuestas deben permanecer sólo en lectura.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ActualizarVigenciaDetectaEntradaAnteriorALaFechaDeReferencia()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Propuesto: Record "Concepto Liquidación";
        Entrada: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        CodigoEntrada: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
        Formula: Text;
        Impacto: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        CodigoEntrada := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, CodigoEntrada, 25, '1', false, false);
        Entrada.Get(CodigoEntrada, DMY2Date(1, 1, 2020));
        Entrada."Vigencia Desde" := DMY2Date(1, 2, 2020);
        Entrada."Fórmula Orden Cálculo" := '5';
        Entrada.Insert(true);
        Origen.Get(Aporte, DMY2Date(1, 1, 2020));
        Origen.Fórmula := '#' + CodigoEntrada;
        Origen.Modify(false);
        Origen.Get(Aporte, DMY2Date(1, 1, 2020));
        // Crear una versión sólo desde febrero admite10; actualizar enero también debe respetar la entrada25 de enero.
        Gestor.Validar(Base, Origen, DMY2Date(15, 2, 2020), 10, Tipo, 'TEST_CORR_CCT', 'GENERAL', Formula, Impacto);
        Assert(not Gestor.Preparar(Base, DMY2Date(15, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Aporte, true, Propuesto, Orden, Fecha, Motivo), 'No hay ventana para mover todo el intervalo: enero exige después25 y la base exige antes20.');
        asserterror Gestor.Validar(Base, Origen, Origen."Vigencia Desde", 10, Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Formula, Impacto);
        Assert(GetLastErrorText() <> '', 'La validación de actualización debe comprobar la frontera anterior a la referencia.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ActualizarVigenciaAdmiteFronteraYaCompletaPeroRechazaNoopGlobal()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Concepto: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        BaseCompleta: Code[20];
        AporteCompleto: Code[20];
        LectorCompleto: Code[20];
        Formula: Text;
        Impacto: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 40);
        Concepto.Get(Lector, DMY2Date(1, 1, 2020));
        Concepto."Vigencia Desde" := DMY2Date(1, 2, 2020);
        Concepto."Fórmula Orden Cálculo" := '20';
        Concepto.Insert(true);
        Origen.Get(Aporte, DMY2Date(1, 1, 2020));
        Gestor.Validar(Base, Origen, Origen."Vigencia Desde", 19, Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Formula, Impacto);
        Assert((Formula <> '') and (Impacto <> ''), 'La frontera de enero ya completa no debe impedir corregir febrero con una posición segura en ambas fechas.');
        CrearCasoLotePrueba(Tipo, BaseCompleta, AporteCompleto, LectorCompleto, 40);
        Origen.Get(AporteCompleto, DMY2Date(1, 1, 2020));
        asserterror Gestor.Validar(BaseCompleta, Origen, Origen."Vigencia Desde", 30, Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Formula, Impacto);
        Assert(GetLastErrorText() <> '', 'Conservar el mismo orden en todo el intervalo no es una corrección y no debe auditarse como tal.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ActualizarVigenciaEnLoteCorrigeVariasBasesSinNuevasFilasNiRepetir()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Resultado: Record "Diag. Orden Acum. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        AntesRepetir: Record "Concepto Liquidación";
        Tipo: Code[20];
        BaseA: Code[20];
        AporteA: Code[20];
        LectorA: Code[20];
        BaseB: Code[20];
        AporteB: Code[20];
        LectorB: Code[20];
        OtroAporte: Code[20];
        Cambios: Integer;
        Pendientes: Integer;
        VersionesAntes: Integer;
        Detalle: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, BaseA, AporteA, LectorA, 20);
        CrearCasoLotePrueba(Tipo, BaseB, AporteB, LectorB, 20);
        OtroAporte := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, OtroAporte, 40, '', false, false);
        CrearFraccion(OtroAporte, BaseA);
        VersionesAntes := ContarVersionesLotePrueba(Tipo);
        Gestor.CorregirTodos(DMY2Date(1, 1, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Cambios, Pendientes, Detalle, Resultado);
        Assert(Cambios = 3, 'El lote debe actualizar tres aportantes en la fecha inicial, sin omitir las versiones que comienzan ese mismo día.');
        AssertLoteSinConflicto(Tipo, BaseA, DMY2Date(1, 1, 2020));
        AssertLoteSinConflicto(Tipo, BaseB, DMY2Date(1, 1, 2020));
        Assert(ContarVersionesLotePrueba(Tipo) = VersionesAntes, 'Actualizar en lote no debe insertar ninguna versión.');
        Concepto.Get(AporteA, DMY2Date(1, 1, 2020));
        AntesRepetir := Concepto;
        Gestor.CorregirTodos(DMY2Date(1, 1, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Cambios, Pendientes, Detalle, Resultado);
        Concepto.Get(AporteA, DMY2Date(1, 1, 2020));
        Assert((Cambios = 0) and (Concepto.SystemRowVersion = AntesRepetir.SystemRowVersion), 'La segunda ejecución debe terminar sin repetir actualizaciones ni quedar en un bucle.');
        Assert(ContarVersionesLotePrueba(Tipo) = VersionesAntes, 'La repetición también debe conservar el censo de vigencias.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ActualizarVigenciaRechazaOrigenModificadoTrasLaPropuesta()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Seleccionado: Record "Concepto Liquidación";
        Actual: Record "Concepto Liquidación";
        Antes: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        VersionesAntes: Integer;
        Formula: Text;
        Impacto: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        Seleccionado.Get(Aporte, DMY2Date(1, 1, 2020));
        Actual := Seleccionado;
        Actual.Descripción := 'Cambio físico posterior a revisar el orden';
        Actual.Modify(false);
        Actual.Get(Aporte, DMY2Date(1, 1, 2020));
        Antes := Actual;
        VersionesAntes := ContarVersionesLotePrueba(Tipo);
        Assert(not IntentarValidarSinRevertirFixturePrueba(Gestor, Base, Seleccionado, Seleccionado."Vigencia Desde", 10, Tipo, true, Formula, Impacto), 'La revisión sin locks también debe rechazar la selección obsoleta.');
        Assert(GetLastErrorText().Contains('cambió'), 'La revisión debe informar la concurrencia detectada.');
        Actual.Get(Aporte, DMY2Date(1, 1, 2020));
        Assert((Actual.SystemRowVersion = Antes.SystemRowVersion) and (ContarVersionesLotePrueba(Tipo) = VersionesAntes), 'El rechazo por concurrencia debe conservar la edición detectada y no crear versiones.');
        asserterror Gestor.Aplicar(Base, Seleccionado, Seleccionado."Vigencia Desde", 10, Tipo, 'TEST_CORR_CCT', 'GENERAL', true);
        Assert(GetLastErrorText().Contains('cambió'), 'La aplicación bajo locks debe rechazar exactamente la edición concurrente, sin un error de infraestructura.');
        AssertRollbackSinVigenciasNiAuditoriaPrueba(Tipo, Aporte);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ActualizarVigenciaMantieneBloqueadasLasEtapasYLosCiclos()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Propuesto: Record "Concepto Liquidación";
        Tipo: Code[20];
        BaseEtapa: Code[20];
        AporteEtapa: Code[20];
        LectorEtapa: Code[20];
        BaseCiclo: Code[20];
        AporteCiclo: Code[20];
        LectorCiclo: Code[20];
        Puente: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, BaseEtapa, AporteEtapa, LectorEtapa, 20);
        Origen.Get(AporteEtapa, DMY2Date(1, 1, 2020));
        Origen.Fórmula := BaseEtapa;
        Origen.Modify(false);
        Origen.Get(AporteEtapa, DMY2Date(1, 1, 2020));
        Assert(not Gestor.Preparar(BaseEtapa, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', AporteEtapa, true, Propuesto, Orden, Fecha, Motivo), 'Actualizar una vigencia no vuelve seguro mover una lectura por etapas.');
        asserterror Gestor.Aplicar(BaseEtapa, Origen, Origen."Vigencia Desde", 10, Tipo, 'TEST_CORR_CCT', 'GENERAL', true);
        Assert(GetLastErrorText() <> '', 'La aplicación directa también debe rechazar la etapa.');
        CrearCasoLotePrueba(Tipo, BaseCiclo, AporteCiclo, LectorCiclo, 20);
        Puente := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, Puente, 25, '#' + AporteCiclo, false, false);
        Origen.Get(AporteCiclo, DMY2Date(1, 1, 2020));
        Origen.Fórmula := '@' + Puente;
        Origen.Modify(false);
        Origen.Get(AporteCiclo, DMY2Date(1, 1, 2020));
        asserterror Gestor.Aplicar(BaseCiclo, Origen, Origen."Vigencia Desde", 10, Tipo, 'TEST_CORR_CCT', 'GENERAL', true);
        Assert(GetLastErrorText() <> '', 'El modo actualización debe seguir rechazando la dependencia de su propio resultado calculado.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ActualizarVigenciaRechazaCruceConConsumidorProgramadoEnElFuturo()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Consumidor: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        OtraBase: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        CodigoConsumidor: Code[20];
        Formula: Text;
        Impacto: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        OtraBase := NuevoCodigo();
        CodigoConsumidor := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, OtraBase, 0, '', true, false);
        CrearFraccion(Aporte, OtraBase);
        CrearConceptoLotePrueba(Tipo, CodigoConsumidor, 5, OtraBase, false, true);
        Consumidor.Get(CodigoConsumidor, DMY2Date(1, 1, 2020));
        Consumidor."Vigencia Desde" := DMY2Date(1, 3, 2020);
        Consumidor."Fórmula Orden Cálculo" := '15';
        Consumidor.Insert(true);
        Origen.Get(Aporte, DMY2Date(1, 1, 2020));
        asserterror Gestor.Validar(Base, Origen, Origen."Vigencia Desde", 10, Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Formula, Impacto);
        Assert(GetLastErrorText() <> '', 'El orden10 conserva el subtotal del otro consumidor5 de enero pero cruza al consumidor15 programado para marzo.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ActualizarVigenciaDesdeFichaMantieneConceptoYOrdenFueraDelAmbito()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Motor: Codeunit "Motor Liquidación";
        Seleccionado: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Actual: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
        VersionesAntes: Integer;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        Seleccionado.Get(Lector, DMY2Date(1, 1, 2020));
        Seleccionado."Fórmula Orden Cálculo" := 'IF(TIPO_LIQ = ''' + Tipo + ''', 20, 70)';
        Seleccionado.Modify(false);
        Seleccionado.Get(Lector, DMY2Date(1, 1, 2020));
        VersionesAntes := ContarVersionesLotePrueba(Tipo);
        if not Gestor.PrepararConcepto(Seleccionado, Base, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Origen, Orden, Fecha, Motivo) then
            Error('La actualización fija debe admitir el lector seleccionado: %1', Motivo);
        Assert((Origen.Código = Lector) and (Fecha = Seleccionado."Vigencia Desde") and (Orden = 31), 'La actualización desde ficha debe mover sólo el lector exacto, desde el inicio de su misma versión.');
        Gestor.Aplicar(Base, Origen, Fecha, Orden, Tipo, 'TEST_CORR_CCT', 'GENERAL', true);
        Actual.Get(Lector, DMY2Date(1, 1, 2020));
        Assert(Motor.OrdenEfectivo(Actual, Tipo, 'TEST_CORR_CCT') = 31, 'El nuevo orden debe regir para el tipo y convenio revisados.');
        Assert(Motor.OrdenEfectivo(Actual, 'LIQ_FINAL', 'TEST_CORR_CCT') = 70, 'Otro tipo debe conservar la expresión de orden anterior.');
        Assert(Motor.OrdenEfectivo(Actual, Tipo, 'TEST_CORR_OTRO') = 20, 'Otro convenio debe mantener el orden previo del tipo.');
        Assert((Actual.Fórmula = Seleccionado.Fórmula) and (ContarVersionesLotePrueba(Tipo) = VersionesAntes), 'La propuesta de orden desde ficha no debe cambiar la fórmula monetaria ni insertar otra vigencia.');
        Actual.Get(Aporte, DMY2Date(1, 1, 2020));
        Assert(Actual."Fórmula Orden Cálculo" = '30', 'La acción fija no debe sustituir el movimiento por el aportante que elegiría el modo general.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenesPosiblesPrefiereContextoExactoYRenuevaLaLista()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Concepto: Record "Concepto Liquidación";
        Ordenes: List of [Integer];
        OrdenExacto: Integer;
    begin
        PrepararCatalogos();
        Concepto."Fórmula Orden Cálculo" := 'IF(TIPO_LIQ = ''REGULAR'', 321, 668)';
        Ordenes.Add(999);
        Assert(Control.ObtenerOrdenesPosibles(Concepto, DMY2Date(1, 2, 2020), 'REGULAR', 'TEST_CORR_CCT', Ordenes), 'El contexto conocido debe conservar la evaluación exacta como primera opción.');
        Assert((Ordenes.Count() = 1) and Ordenes.Contains(321), 'Con tipo regular no se debe tratar la rama668 como activa ni arrastrar la lista anterior.');
        Assert(Control.ObtenerOrdenesPosibles(Concepto, DMY2Date(1, 2, 2020), 'LIQ_FINAL', 'TEST_CORR_CCT', Ordenes), 'La misma instancia debe resolver el segundo contexto.');
        Assert((Ordenes.Count() = 1) and Ordenes.Contains(668), 'La final debe descartar el orden321 de la llamada anterior.');
        Assert(Control.ObtenerOrdenesPosibles(Concepto, DMY2Date(1, 2, 2020), '', 'TEST_CORR_CCT', Ordenes), 'Sin tipo se pueden enumerar las dos hojas enteras sin escoger una rama.');
        Assert((Ordenes.Count() = 2) and Ordenes.Contains(321) and Ordenes.Contains(668), 'Sin contexto completo ambas ramas siguen siendo posibles.');
        Assert(not Control.ResolverOrden(Concepto, DMY2Date(1, 2, 2020), '', 'TEST_CORR_CCT', OrdenExacto), 'Enumerar posibilidades no convierte en exacto un orden que necesita contexto.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenesPosiblesReconoceIfAnidadosComillasYComasSinDuplicarHojas()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Concepto: Record "Concepto Liquidación";
        Ordenes: List of [Integer];
    begin
        PrepararCatalogos();
        Concepto."Fórmula Orden Cálculo" := 'IF(MAX(SIN_CONTEXTO, 2) > 0 AND CONVENIO = ''A,B'', 470, IF(CONVENIO = ''D''''E,F'', 668, 470))';
        Assert(Control.ObtenerOrdenesPosibles(Concepto, DMY2Date(1, 2, 2020), '', '', Ordenes), 'Las comas de una función en la condición y de un literal escapado no deben confundirse con los separadores del IF.');
        Assert((Ordenes.Count() = 2) and Ordenes.Contains(470) and Ordenes.Contains(668), 'El IF anidado debe devolver las dos hojas distintas, sin duplicar470.');
        Concepto."Fórmula Orden Cálculo" := 'IF(SIN_CONTEXTO > 0, 0, 2147483647)';
        Assert(Control.ObtenerOrdenesPosibles(Concepto, DMY2Date(1, 2, 2020), '', '', Ordenes), 'Los límites válidos del entero no negativo deben conservarse.');
        Assert((Ordenes.Count() = 2) and Ordenes.Contains(0) and Ordenes.Contains(2147483647), 'El análisis no debe truncar los extremos ni arrastrar hojas del IF anterior.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenesPosiblesRechazaRamasNoLiteralesNegativasDesbordadasOMalFormadas()
    begin
        PrepararCatalogos();
        AssertOrdenesPosiblesRechazados('IF(SIN_CONTEXTO > 0, 470 + 1, 668)');
        AssertOrdenesPosiblesRechazados('IF(SIN_CONTEXTO > 0, MAX(470, 471), 668)');
        AssertOrdenesPosiblesRechazados('IF(SIN_CONTEXTO > 0, -1, 668)');
        AssertOrdenesPosiblesRechazados('IF(SIN_CONTEXTO > 0, 2147483648, 668)');
        AssertOrdenesPosiblesRechazados('IF(SIN_CONTEXTO > 0, 470, IF(OTRO > 0, 668, 700)');
        AssertOrdenesPosiblesRechazados('IF(CONVENIO = ''A,B, 470, 668)');
        AssertOrdenesPosiblesRechazados('IF(SIN_CONTEXTO > 0, , 668)');
        AssertOrdenesPosiblesRechazados('IF(SIN_CONTEXTO > 0, 470, 668, 700)');
        AssertOrdenesPosiblesRechazados('IF(SIN_CONTEXTO >, 470, 668)');
        AssertOrdenesPosiblesRechazados('IF(#ALGO > 0, 470, 668)');
        AssertOrdenesPosiblesRechazados('IF(TRAMO(''X'', 1) > 0, 470, 668)');
        AssertOrdenesPosiblesRechazados('IF(FILA_EMPLEADO = ''X'', 470, 668)');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ReferenciaIfFinitaPermiteCorreccionSeguraSinCambiarSuFormula()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        LectorAntes: Record "Concepto Liquidación";
        LectorActual: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        EstablecerFormulaOrdenPrueba(Aporte, '700');
        EstablecerFormulaOrdenPrueba(Lector, 'IF(TIPO_LIQ = ''LIQ_FINAL'', 470, 668)');
        EstablecerTiposCompatiblesPrueba(Base, Tipo + '|LIQ_FINAL');
        EstablecerTiposCompatiblesPrueba(Aporte, Tipo + '|LIQ_FINAL');
        EstablecerTiposCompatiblesPrueba(Lector, Tipo + '|LIQ_FINAL');
        LectorAntes.Get(Lector, DMY2Date(1, 1, 2020));
        if not Gestor.Preparar(Base, DMY2Date(1, 2, 2020), '', 'TEST_CORR_CCT', 'GENERAL', Aporte, true, Origen, Orden, Fecha, Motivo) then
            Error('El aporte exacto puede adelantarse antes de ambas posiciones del lector: %1', Motivo);
        Assert((Orden = 469) and (Origen.Código = Aporte), 'La ventana segura debe terminar antes del menor orden posible470, sin escoger un tipo ficticio.');
        Gestor.Aplicar(Base, Origen, Fecha, Orden, '', 'TEST_CORR_CCT', 'GENERAL', true);
        LectorActual.Get(Lector, DMY2Date(1, 1, 2020));
        Assert((LectorActual.SystemRowVersion = LectorAntes.SystemRowVersion) and (LectorActual."Fórmula Orden Cálculo" = LectorAntes."Fórmula Orden Cálculo"), 'Comprobar todas las ramas del lector no debe aplanar ni reescribir su IF.');
        Control.Analizar(DMY2Date(1, 2, 2020), '', 'TEST_CORR_CCT', 'GENERAL', Base, Buffer);
        Buffer.Get(Base);
        Assert(not Buffer.Conflicto and not Buffer."Requiere Contexto", 'El aporte469 queda antes de470y668 para cualquier rama; esa base no debe seguir bloqueada por falta de tipo.');
        Assert(Buffer."Orden Mín. Lectura" = 470, 'El diagnóstico debe mostrar el extremo conservador del lector condicional.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ReferenciaIfBloqueaElMovimientoQueCruzaSoloUnaRama()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Seleccionado: Record "Concepto Liquidación";
        Propuesto: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        OtraBase: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        OtroLector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
        Formula: Text;
        Impacto: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        EstablecerFormulaOrdenPrueba(Aporte, '700');
        EstablecerFormulaOrdenPrueba(Lector, 'IF(TIPO_LIQ = ''LIQ_FINAL'', 470, 668)');
        OtraBase := NuevoCodigo();
        OtroLector := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, OtraBase, 0, '', true, false);
        CrearConceptoLotePrueba(Tipo, OtroLector, 450, OtraBase, false, true);
        EstablecerFormulaOrdenPrueba(OtroLector, 'IF(TIPO_LIQ = ''LIQ_FINAL'', 450, 600)');
        CrearFraccion(Aporte, OtraBase);
        EstablecerTiposCompatiblesPrueba(Base, Tipo + '|LIQ_FINAL');
        EstablecerTiposCompatiblesPrueba(Aporte, Tipo + '|LIQ_FINAL');
        EstablecerTiposCompatiblesPrueba(Lector, Tipo + '|LIQ_FINAL');
        EstablecerTiposCompatiblesPrueba(OtraBase, Tipo + '|LIQ_FINAL');
        EstablecerTiposCompatiblesPrueba(OtroLector, Tipo + '|LIQ_FINAL');
        Seleccionado.Get(Aporte, DMY2Date(1, 1, 2020));
        Assert(not Gestor.Preparar(Base, DMY2Date(1, 2, 2020), '', 'TEST_CORR_CCT', 'GENERAL', Aporte, true, Propuesto, Orden, Fecha, Motivo), 'Para la otra base debe conservarse el aporte después de600; es incompatible con adelantarlo antes de470.');
        asserterror Gestor.Validar(Base, Seleccionado, Seleccionado."Vigencia Desde", 469, '', 'TEST_CORR_CCT', 'GENERAL', true, Formula, Impacto);
        Assert(GetLastErrorText() <> '', '469 conserva la relación con la rama450 pero cruza la rama600: debe bloquearse aunque una variante sea segura.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FuenteIfSinContextoNoSeAplanaAunqueSusOrdenesSeanFinitos()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Control: Codeunit "Control Orden Acumuladores";
        Seleccionado: Record "Concepto Liquidación";
        Propuesto: Record "Concepto Liquidación";
        Ordenes: List of [Integer];
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
        VersionesAntes: Integer;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        EstablecerFormulaOrdenPrueba(Aporte, 'IF(TIPO_LIQ = ''LIQ_FINAL'', 700, 800)');
        EstablecerTiposCompatiblesPrueba(Base, Tipo + '|LIQ_FINAL');
        EstablecerTiposCompatiblesPrueba(Aporte, Tipo + '|LIQ_FINAL');
        EstablecerTiposCompatiblesPrueba(Lector, Tipo + '|LIQ_FINAL');
        Seleccionado.Get(Aporte, DMY2Date(1, 1, 2020));
        VersionesAntes := ContarVersionesLotePrueba(Tipo);
        Assert(Control.ObtenerOrdenesPosibles(Seleccionado, DMY2Date(1, 2, 2020), '', 'TEST_CORR_CCT', Ordenes), 'La referencia tiene dos posiciones finitas conocidas.');
        Assert((Ordenes.Count() = 2) and Ordenes.Contains(700) and Ordenes.Contains(800), 'El diagnóstico no debe perder las dos ramas de la fuente.');
        Assert(not Gestor.Preparar(Base, DMY2Date(1, 2, 2020), '', 'TEST_CORR_CCT', 'GENERAL', Aporte, true, Propuesto, Orden, Fecha, Motivo), 'La fuente que se mueve debe tener un orden exacto; enumerar sus ramas no autoriza a sustituir su IF por un único orden.');
        Assert((Orden = 0) and (Motivo <> '') and (ContarVersionesLotePrueba(Tipo) = VersionesAntes), 'El rechazo debe explicar la falta de contexto y permanecer sin escrituras.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FuentePuestoSigueBloqueadaAunqueSuOrdenSeaLiteral()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Control: Codeunit "Control Orden Acumuladores";
        Seleccionado: Record "Concepto Liquidación";
        Propuesto: Record "Concepto Liquidación";
        Ordenes: List of [Integer];
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        Seleccionado.Get(Aporte, DMY2Date(1, 1, 2020));
        Seleccionado."Par CCT a Usar" := Seleccionado."Par CCT a Usar"::Puesto;
        Seleccionado.Modify(false);
        Seleccionado.Get(Aporte, DMY2Date(1, 1, 2020));
        Assert(Control.ObtenerOrdenesPosibles(Seleccionado, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', Ordenes), 'Una referencia al aporte de puesto puede comprobarse universalmente si su orden es literal.');
        Assert((Ordenes.Count() = 1) and Ordenes.Contains(30), 'El orden literal es30 cualquiera sea el puesto.');
        Assert(not Gestor.PrepararConcepto(Seleccionado, Base, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Propuesto, Orden, Fecha, Motivo), 'Eso no autoriza a mover la propia fuente que usa un puesto sin liquidación concreta.');
        Assert((Orden = 0) and (Motivo <> ''), 'La propuesta fija debe mantener la guarda del par de la fuente.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenDesconocidoDeUnaBaseAjenaNoImpideCorregirLaSeleccionada()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        BaseAjena: Code[20];
        AporteAjeno: Code[20];
        LectorAjeno: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        CrearCasoLotePrueba(Tipo, BaseAjena, AporteAjeno, LectorAjeno, 20);
        EstablecerFormulaOrdenPrueba(LectorAjeno, 'ORDEN_DESCONOCIDO_TEST');
        if not Gestor.Preparar(Base, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Aporte, true, Origen, Orden, Fecha, Motivo) then
            Error('La base ajena sin orden resuelto no debe bloquear el movimiento independiente: %1', Motivo);
        Gestor.Aplicar(Base, Origen, Fecha, Orden, Tipo, 'TEST_CORR_CCT', 'GENERAL', true);
        AssertLoteSinConflicto(Tipo, Base, DMY2Date(1, 2, 2020));
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', BaseAjena, Buffer);
        Buffer.Get(BaseAjena);
        Assert(Buffer."Requiere Contexto", 'La base ajena debe conservar su incertidumbre; no se la resuelve suponiendo un orden ni se la oculta.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OrdenesPosiblesDePuestoNoAsumenConvenioYSoloAlertanSiPuedeLlegarTarde()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Ordenes: List of [Integer];
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        EstablecerFormulaOrdenPrueba(Aporte, '321');
        Concepto.Get(Lector, DMY2Date(1, 1, 2020));
        Concepto."Par CCT a Usar" := Concepto."Par CCT a Usar"::Puesto;
        Concepto."Fórmula Orden Cálculo" := 'IF(CONVENIO = ''TEST_CORR_OTRO'', 320, 668)';
        Concepto.Modify(false);
        Concepto.Get(Lector, DMY2Date(1, 1, 2020));
        Assert(Control.ObtenerOrdenesPosibles(Concepto, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', Ordenes), 'El par de puesto puede tener ramas finitas sin inventar su convenio.');
        Assert((Ordenes.Count() = 2) and Ordenes.Contains(320) and Ordenes.Contains(668), 'El convenio de cabecera no debe reducir el puesto a la rama668.');
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Base, Buffer);
        Buffer.Get(Base);
        Assert(Buffer.Conflicto and Buffer."Requiere Contexto" and (Buffer."Orden Mín. Lectura" = 320), 'El aporte321 puede llegar tarde frente a320: el par desconocido sigue siendo relevante.');
        EstablecerFormulaOrdenPrueba(Lector, 'IF(CONVENIO = ''TEST_CORR_OTRO'', 470, 668)');
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Base, Buffer);
        Buffer.Get(Base);
        Assert(not Buffer.Conflicto and not Buffer."Requiere Contexto", '321 está antes de470y668: el puesto desconocido ya no puede causar una precedencia y no debe dejar un aviso repetitivo.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ReferenciaIfFuturaSeCompruebaEnTodasSusRamas()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Seleccionado: Record "Concepto Liquidación";
        Futuro: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        OtraBase: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        OtroLector: Code[20];
        Formula: Text;
        Impacto: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        EstablecerFormulaOrdenPrueba(Aporte, '700');
        EstablecerFormulaOrdenPrueba(Lector, 'IF(TIPO_LIQ = ''LIQ_FINAL'', 470, 668)');
        OtraBase := NuevoCodigo();
        OtroLector := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, OtraBase, 0, '', true, false);
        CrearConceptoLotePrueba(Tipo, OtroLector, 450, OtraBase, false, true);
        EstablecerFormulaOrdenPrueba(OtroLector, 'IF(TIPO_LIQ = ''LIQ_FINAL'', 450, 460)');
        CrearFraccion(Aporte, OtraBase);
        Seleccionado.Get(Aporte, DMY2Date(1, 1, 2020));
        Gestor.Validar(Base, Seleccionado, Seleccionado."Vigencia Desde", 469, '', 'TEST_CORR_CCT', 'GENERAL', true, Formula, Impacto);
        Futuro.Get(OtroLector, DMY2Date(1, 1, 2020));
        Futuro."Vigencia Desde" := DMY2Date(1, 3, 2020);
        Futuro."Fórmula Orden Cálculo" := 'IF(TIPO_LIQ = ''LIQ_FINAL'', 450, 600)';
        Futuro.Insert(true);
        asserterror Gestor.Validar(Base, Seleccionado, Seleccionado."Vigencia Desde", 469, '', 'TEST_CORR_CCT', 'GENERAL', true, Formula, Impacto);
        Assert(GetLastErrorText() <> '', 'La nueva rama600 de marzo debe bloquear el cruce aunque una revisión anterior de la misma instancia hubiera aprobado469 con450y460.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure DependenciaNumeralSinAcumuladorDiagnosticaYCorrigeElProductor()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        LectorAntes: Record "Concepto Liquidación";
        Actual: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        Productor: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearParDependenciaPrueba(Tipo, Productor, Lector, 30, 20);
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Lector, Buffer);
        Buffer.Get(Lector);
        Assert(Buffer.Conflicto and (Buffer."Cant. Aportes" = 1) and (Buffer."Cant. Lecturas" = 1), 'Una fórmula #productor debe tener su propia fila aunque no haya acumuladores.');
        Assert((Buffer."Concepto Máx. Aporte" = Productor) and (Buffer."Concepto Mín. Lectura" = Lector), 'La clave de la fila es el lector y sus extremos son productor30 y lector20.');
        LectorAntes.Get(Lector, DMY2Date(1, 1, 2020));
        Origen.Get(Productor, DMY2Date(1, 1, 2020));
        Gestor.AnalizarConcepto(Origen, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Buffer);
        Assert((Buffer.Count() = 1) and Buffer.Get(Lector), 'La ficha del productor también debe mostrar la fila del consumidor que usa su resultado, aunque el productor no tenga entradas propias.');
        if not Gestor.Proponer(Lector, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Origen, Orden, Fecha, Motivo) then
            Error('Debe permitir reparar la referencia calculada sin usar una base ficticia: %1', Motivo);
        Assert((Origen.Código = Productor) and (Orden = 19), 'El movimiento mínimo adelanta el productor antes de su lector20.');
        Gestor.Aplicar(Lector, Origen, Fecha, Orden, Tipo, 'TEST_CORR_CCT', 'GENERAL', true);
        AssertDependenciaSinConflicto(Tipo, Lector, DMY2Date(1, 2, 2020));
        Actual.Get(Lector, DMY2Date(1, 1, 2020));
        Assert((Actual.SystemRowVersion = LectorAntes.SystemRowVersion) and (Actual.Fórmula = '#' + Productor), 'Mover el productor no debe escribir la fórmula ni el registro físico del lector.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure DependenciaFijaDelLectorRespetaTodasSusEntradasSinDuplicarlas()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Seleccionado: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Actual: Record "Concepto Liquidación";
        Tipo: Code[20];
        EntradaA: Code[20];
        EntradaC: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearParDependenciaPrueba(Tipo, EntradaA, Lector, 10, 20);
        EntradaC := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, EntradaC, 40, '1', false, false);
        Seleccionado.Get(Lector, DMY2Date(1, 1, 2020));
        Seleccionado.Fórmula := '#' + EntradaA + ' + #' + EntradaC;
        Seleccionado.Condición := 'TIPO_LIQ = ''' + Tipo + ''' OR #' + EntradaA + ' > 0';
        Seleccionado."Variable Cantidad" := '#' + EntradaC;
        Seleccionado.Modify(false);
        Seleccionado.Get(Lector, DMY2Date(1, 1, 2020));
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Lector, Buffer);
        Buffer.Get(Lector);
        Assert(Buffer."Cant. Aportes" = 2, 'La repetición entre fórmula, condición y cantidad no debe duplicar las entradas calculadas.');
        if not Gestor.PrepararConcepto(Seleccionado, Lector, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Origen, Orden, Fecha, Motivo) then
            Error('El lector fijo puede moverse después de las dos entradas: %1', Motivo);
        Assert((Origen.Código = Lector) and (Orden = 41), 'El lector debe respetar el máximo de todas las entradas, no sólo la primera del texto.');
        Gestor.Aplicar(Lector, Origen, Fecha, Orden, Tipo, 'TEST_CORR_CCT', 'GENERAL', true);
        Actual.Get(Lector, DMY2Date(1, 1, 2020));
        Assert((Actual.Fórmula = Seleccionado.Fórmula) and (Actual.Condición = Seleccionado.Condición) and (Actual."Variable Cantidad" = Seleccionado."Variable Cantidad"), 'La corrección debe cambiar sólo el orden de la fórmula seleccionada.');
        AssertDependenciaSinConflicto(Tipo, Lector, DMY2Date(1, 2, 2020));
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure DependenciasEnCadenaConvergenEnLoteYLaRepeticionNoEscribe()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Control: Codeunit "Control Orden Acumuladores";
        Resultado: Record "Diag. Orden Acum. Buffer" temporary;
        Actual: Record "Concepto Liquidación";
        AntesRepetir: Record "Concepto Liquidación";
        Tipo: Code[20];
        Prefijo: Code[20];
        Entrada: Code[20];
        Intermedio: Code[20];
        Final: Code[20];
        Cambios: Integer;
        Pendientes: Integer;
        VersionesAntes: Integer;
        Detalle: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        Prefijo := CopyStr(NuevoCodigo(), 1, 15);
        Entrada := Prefijo + 'A';
        Intermedio := Prefijo + 'B';
        Final := Prefijo + 'C';
        CrearConceptoLotePrueba(Tipo, Entrada, 30, '1', false, false);
        CrearConceptoLotePrueba(Tipo, Intermedio, 20, '#' + Entrada, false, false);
        CrearConceptoLotePrueba(Tipo, Final, 10, '#' + Intermedio, false, true);
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Final, Resultado);
        Resultado.Get(Final);
        Assert((Resultado."Cant. Aportes" = 1) and (Resultado."Concepto Máx. Aporte" = Intermedio), 'Leer #intermedio requiere su resultado guardado; no debe expandir su fórmula y añadir la entrada transitiva como haría @.');
        VersionesAntes := ContarVersionesLotePrueba(Tipo);
        Gestor.CorregirTodos(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Cambios, Pendientes, Detalle, Resultado);
        Assert(Cambios >= 2, 'La cadena necesita corregir las dos relaciones y renovar la configuración entre movimientos.');
        AssertDependenciaSinConflicto(Tipo, Intermedio, DMY2Date(1, 2, 2020));
        AssertDependenciaSinConflicto(Tipo, Final, DMY2Date(1, 2, 2020));
        Assert(ContarVersionesLotePrueba(Tipo) = VersionesAntes, 'La actualización en lote debe conservar las tres claves de vigencia de la cadena.');
        Actual.Get(Entrada, DMY2Date(1, 1, 2020));
        AntesRepetir := Actual;
        Gestor.CorregirTodos(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Cambios, Pendientes, Detalle, Resultado);
        Actual.Get(Entrada, DMY2Date(1, 1, 2020));
        Assert((Cambios = 0) and (Actual.SystemRowVersion = AntesRepetir.SystemRowVersion), 'La segunda ejecución debe terminar sin repetir movimientos ni reescribir una fuente ya ordenada.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure DependenciaPorArrobaAnidadaNoImponeElOrdenDeSusDefiniciones()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Seleccionado: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        InteriorAntes: Record "Concepto Liquidación";
        ExteriorAntes: Record "Concepto Liquidación";
        Actual: Record "Concepto Liquidación";
        Tipo: Code[20];
        Productor: Code[20];
        Interior: Code[20];
        Exterior: Code[20];
        Lector: Code[20];
        AcumuladorVacio: Code[20];
        LectorDefinicionVacia: Code[20];
        Hallazgos: Integer;
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        Productor := NuevoCodigo();
        Interior := NuevoCodigo();
        Exterior := NuevoCodigo();
        Lector := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, Productor, 30, '1', false, false);
        CrearConceptoLotePrueba(Tipo, Interior, 900, '#' + Productor, false, true);
        CrearConceptoLotePrueba(Tipo, Exterior, 800, '@' + Interior, false, true);
        CrearConceptoLotePrueba(Tipo, Lector, 20, '@' + Exterior, false, true);
        InteriorAntes.Get(Interior, DMY2Date(1, 1, 2020));
        ExteriorAntes.Get(Exterior, DMY2Date(1, 1, 2020));
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Lector, Buffer);
        Buffer.Get(Lector);
        Assert((Buffer."Cant. Aportes" = 1) and (Buffer."Concepto Máx. Aporte" = Productor), '@ debe descubrir #productor, sin exigir que se ejecuten antes los conceptos que sólo aportan la definición.');
        Seleccionado.Get(Lector, DMY2Date(1, 1, 2020));
        if not Gestor.PrepararConcepto(Seleccionado, Lector, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Origen, Orden, Fecha, Motivo) then
            Error('El lector sólo necesita quedar después del resultado calculado30: %1', Motivo);
        Assert(Orden = 31, 'Los órdenes800y900 de las definiciones @ no son dependencias de ejecución del lector.');
        Gestor.Aplicar(Lector, Origen, Fecha, Orden, Tipo, 'TEST_CORR_CCT', 'GENERAL', true);
        Actual.Get(Interior, DMY2Date(1, 1, 2020));
        Assert(Actual.SystemRowVersion = InteriorAntes.SystemRowVersion, 'No debe reescribirse la definición interior.');
        Actual.Get(Exterior, DMY2Date(1, 1, 2020));
        Assert(Actual.SystemRowVersion = ExteriorAntes.SystemRowVersion, 'No debe reescribirse la definición exterior.');
        AssertDependenciaSinConflicto(Tipo, Lector, DMY2Date(1, 2, 2020));
        AcumuladorVacio := NuevoCodigo();
        LectorDefinicionVacia := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, AcumuladorVacio, 0, '', true, false);
        CrearConceptoLotePrueba(Tipo, LectorDefinicionVacia, 10, '@' + AcumuladorVacio, false, true);
        Hallazgos := Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', LectorDefinicionVacia, Buffer);
        Assert((Hallazgos = 0) and Buffer.IsEmpty(), '@ACUM con definición vacía no lee el subtotal ni produce una dependencia normal o un error ficticio.');
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', AcumuladorVacio, Buffer);
        Buffer.Get(AcumuladorVacio);
        Assert((Buffer."Cant. Lecturas" = 0) and not Buffer.Conflicto, 'La reevaluación de una definición vacía tampoco debe incorporarse como lectura del subtotal del acumulador.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure DependenciaDeSuPropioResultadoNoAdmiteUnaCorreccionDeOrden()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Seleccionado: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Actual: Record "Concepto Liquidación";
        Tipo: Code[20];
        Codigo: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        Codigo := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, Codigo, 20, '#' + Codigo, false, false);
        Seleccionado.Get(Codigo, DMY2Date(1, 1, 2020));
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Codigo, Buffer);
        Buffer.Get(Codigo);
        Assert(Buffer.Conflicto, 'Un concepto que requiere su propio resultado debe permanecer visible como conflicto.');
        Assert(not Gestor.Preparar(Codigo, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Codigo, true, Origen, Orden, Fecha, Motivo), 'Cambiar la posición de un concepto no puede resolver su autorreferencia calculada.');
        Actual.Get(Codigo, DMY2Date(1, 1, 2020));
        Assert(Actual.SystemRowVersion = Seleccionado.SystemRowVersion, 'El rechazo debe conservar intacto el concepto autorreferente.');
        Actual.Fórmula := '@' + Codigo;
        Actual.Modify(false);
        Seleccionado.Get(Codigo, DMY2Date(1, 1, 2020));
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Codigo, Buffer);
        Buffer.Get(Codigo);
        Assert(Buffer.Conflicto and (Buffer.Observación <> ''), 'El ciclo de reevaluación @ debe conservar una fila de error aunque no produzca dependencias normales completas.');
        Assert(not Gestor.Preparar(Codigo, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Codigo, true, Origen, Orden, Fecha, Motivo), 'La autorreferencia @ tampoco admite una corrección de orden.');
        Actual.Get(Codigo, DMY2Date(1, 1, 2020));
        Assert(Actual.SystemRowVersion = Seleccionado.SystemRowVersion, 'Analizar el ciclo @ y rechazar su propuesta debe permanecer en lectura.');
        Actual.Fórmula := '#' + NuevoCodigo();
        Actual.Modify(false);
        Seleccionado.Get(Codigo, DMY2Date(1, 1, 2020));
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Codigo, Buffer);
        Buffer.Get(Codigo);
        Assert(Buffer.Conflicto and (Buffer.Observación <> ''), 'Una referencia # inexistente no debe desaparecer por carecer de una entrada vigente que incorporar a la lista.');
        Actual.Get(Codigo, DMY2Date(1, 1, 2020));
        Actual.Fórmula := '#' + Codigo;
        Actual.Modify(false);
        Seleccionado.Get(Codigo, DMY2Date(1, 1, 2020));
        asserterror Gestor.Aplicar(Codigo, Seleccionado, Seleccionado."Vigencia Desde", 21, Tipo, 'TEST_CORR_CCT', 'GENERAL', true);
        Assert(GetLastErrorText().Contains(Codigo), 'La aplicación directa debe identificar el concepto autorreferente que impide la corrección.');
        Assert(not GetLastErrorText().Contains('LOCKTABLE'), 'El ensayo debe alcanzar la guarda de autorreferencia, sin envolver los locks en TryFunction.');
        AssertRollbackSinVigenciasNiAuditoriaPrueba(Tipo, Codigo);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure DependenciaCircularNoImpideCorregirUnaRelacionIndependienteEnLote()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        CicloAntesA: Record "Concepto Liquidación";
        CicloAntesB: Record "Concepto Liquidación";
        Actual: Record "Concepto Liquidación";
        Tipo: Code[20];
        CicloA: Code[20];
        CicloB: Code[20];
        Productor: Code[20];
        Lector: Code[20];
        Cambios: Integer;
        Pendientes: Integer;
        VersionesAntes: Integer;
        Detalle: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CicloA := NuevoCodigo();
        CicloB := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, CicloA, 20, '', false, false);
        CrearConceptoLotePrueba(Tipo, CicloB, 30, '#' + CicloA, false, false);
        Actual.Get(CicloA, DMY2Date(1, 1, 2020));
        Actual.Fórmula := '#' + CicloB;
        Actual.Modify(false);
        CicloAntesA.Get(CicloA, DMY2Date(1, 1, 2020));
        CicloAntesB.Get(CicloB, DMY2Date(1, 1, 2020));
        CrearParDependenciaPrueba(Tipo, Productor, Lector, 30, 20);
        VersionesAntes := ContarVersionesLotePrueba(Tipo);
        Gestor.CorregirTodos(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Cambios, Pendientes, Detalle);
        AssertDependenciaSinConflicto(Tipo, Lector, DMY2Date(1, 2, 2020));
        Assert((Cambios >= 1) and (Pendientes > 0), 'El ciclo debe quedar pendiente y permitir que avance una relación independiente verificable.');
        Actual.Get(CicloA, DMY2Date(1, 1, 2020));
        Assert(Actual.SystemRowVersion = CicloAntesA.SystemRowVersion, 'No debe ordenar parcialmente un ciclo de referencias calculadas.');
        Actual.Get(CicloB, DMY2Date(1, 1, 2020));
        Assert(Actual.SystemRowVersion = CicloAntesB.SystemRowVersion, 'Los dos extremos del ciclo deben conservarse.');
        Assert(ContarVersionesLotePrueba(Tipo) = VersionesAntes, 'El lote de actualización debe conservar las claves de configuración.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure DependenciaConProductorIfRespetaElMayorOrdenPosibleSinAplanarlo()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Seleccionado: Record "Concepto Liquidación";
        ProductorAntes: Record "Concepto Liquidación";
        Actual: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        Productor: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearParDependenciaPrueba(Tipo, Productor, Lector, 30, 20);
        EstablecerFormulaOrdenPrueba(Productor, 'IF(TIPO_LIQ = ''LIQ_FINAL'', 30, 50)');
        ProductorAntes.Get(Productor, DMY2Date(1, 1, 2020));
        Seleccionado.Get(Lector, DMY2Date(1, 1, 2020));
        if not Gestor.PrepararConcepto(Seleccionado, Lector, DMY2Date(1, 2, 2020), '', 'TEST_CORR_CCT', 'GENERAL', true, Origen, Orden, Fecha, Motivo) then
            Error('El lector exacto puede colocarse después de todas las ramas del productor: %1', Motivo);
        Assert(Orden = 51, 'Una referencia calculada a30o50 exige quedar después de50, sin elegir una rama desconocida.');
        Gestor.Aplicar(Lector, Origen, Fecha, Orden, '', 'TEST_CORR_CCT', 'GENERAL', true);
        Actual.Get(Productor, DMY2Date(1, 1, 2020));
        Assert((Actual.SystemRowVersion = ProductorAntes.SystemRowVersion) and (Actual."Fórmula Orden Cálculo" = ProductorAntes."Fórmula Orden Cálculo"), 'La corrección del lector debe conservar el IF del productor.');
        AssertDependenciaSinConflicto('', Lector, DMY2Date(1, 2, 2020));
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure DependenciaDeUnaEntradaFuturaSeCompruebaAntesDeActualizarElLector()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Seleccionado: Record "Concepto Liquidación";
        Futura: Record "Concepto Liquidación";
        FuturaAntes: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        Productor: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
        Formula: Text;
        Impacto: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearParDependenciaPrueba(Tipo, Productor, Lector, 10, 20);
        Futura.Get(Productor, DMY2Date(1, 1, 2020));
        Futura."Vigencia Desde" := DMY2Date(1, 3, 2020);
        Futura."Fórmula Orden Cálculo" := '40';
        Futura.Insert(true);
        Futura.Get(Productor, DMY2Date(1, 3, 2020));
        FuturaAntes := Futura;
        Seleccionado.Get(Lector, DMY2Date(1, 1, 2020));
        Assert(not IntentarValidarSinRevertirFixturePrueba(Gestor, Lector, Seleccionado, Seleccionado."Vigencia Desde", 31, Tipo, true, Formula, Impacto), 'La entrada futura debe rechazar la posición31.');
        Assert(GetLastErrorText() <> '', 'El lector31 sería correcto en febrero pero quedaría antes de su productor40 desde marzo.');
        if not Gestor.PrepararConcepto(Seleccionado, Lector, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Origen, Orden, Fecha, Motivo) then
            Error('Debe encontrar una posición que respete también la entrada futura: %1', Motivo);
        Assert(Orden = 41, 'La ventana completa debe colocarlo después del máximo40 de marzo.');
        Gestor.Aplicar(Lector, Origen, Fecha, Orden, Tipo, 'TEST_CORR_CCT', 'GENERAL', true);
        Futura.Get(Productor, DMY2Date(1, 3, 2020));
        Assert(Futura.SystemRowVersion = FuturaAntes.SystemRowVersion, 'La revisión histórica no debe reescribir la vigencia futura de la entrada.');
        AssertDependenciaSinConflicto(Tipo, Lector, DMY2Date(1, 2, 2020));
        AssertDependenciaSinConflicto(Tipo, Lector, DMY2Date(1, 3, 2020));
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure DependenciaNumeralConservaElSubtotalDeOtraBaseYUsaElLectorAlternativo()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        ProductorAntes: Record "Concepto Liquidación";
        Actual: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Fraccion: Record "Fracción Acumulador";
        FraccionAntes: Record "Fracción Acumulador";
        Tipo: Code[20];
        Productor: Code[20];
        Lector: Code[20];
        OtraBase: Code[20];
        OtroLector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
        Formula: Text;
        Impacto: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearParDependenciaPrueba(Tipo, Productor, Lector, 30, 20);
        OtraBase := NuevoCodigo();
        OtroLector := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, OtraBase, 0, '', true, false);
        CrearConceptoLotePrueba(Tipo, OtroLector, 25, OtraBase, false, true);
        CrearFraccion(Productor, OtraBase);
        ProductorAntes.Get(Productor, DMY2Date(1, 1, 2020));
        Fraccion.Get(Productor, DMY2Date(1, 1, 2020), OtraBase);
        FraccionAntes := Fraccion;
        Assert(not Gestor.Preparar(Lector, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Productor, true, Origen, Orden, Fecha, Motivo), 'Adelantar el productor antes del lector20 también lo adelantaría antes del lector25 de otra base y cambiaría ese subtotal.');
        Assert(not IntentarValidarSinRevertirFixturePrueba(Gestor, Lector, ProductorAntes, ProductorAntes."Vigencia Desde", 19, Tipo, true, Formula, Impacto), 'El subtotal ajeno debe impedir el cruce del productor.');
        Assert(GetLastErrorText() <> '', 'La aplicación directa tampoco debe permitir ese cruce ajeno a la dependencia objetivo.');
        if not Gestor.Proponer(Lector, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Origen, Orden, Fecha, Motivo) then
            Error('Debe ofrecer la alternativa segura de atrasar sólo el lector de #productor: %1', Motivo);
        Assert((Origen.Código = Lector) and (Orden = 31), 'El lector31 arregla la referencia sin cambiar el subtotal de la otra base.');
        Gestor.Aplicar(Lector, Origen, Fecha, Orden, Tipo, 'TEST_CORR_CCT', 'GENERAL', true);
        Actual.Get(Productor, DMY2Date(1, 1, 2020));
        Fraccion.Get(Productor, DMY2Date(1, 1, 2020), OtraBase);
        Assert((Actual.SystemRowVersion = ProductorAntes.SystemRowVersion) and (Fraccion.SystemRowVersion = FraccionAntes.SystemRowVersion), 'La fuente y su distribución deben permanecer intactas.');
        AssertDependenciaSinConflicto(Tipo, Lector, DMY2Date(1, 2, 2020));
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure DependenciaEnLoteNuevaVersionConservaElReciboGuardadoYEsIdempotente()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Nueva: Record "Concepto Liquidación";
        Cabecera: Record "Liquidación";
        CabeceraAntes: Record "Liquidación";
        Linea: Record "Línea Liquidación";
        LineaAntes: Record "Línea Liquidación";
        Tipo: Code[20];
        Productor: Code[20];
        Lector: Code[20];
        Cambios: Integer;
        Pendientes: Integer;
        VersionesAntes: Integer;
        Detalle: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearParDependenciaPrueba(Tipo, Productor, Lector, 30, 20);
        Origen.Get(Productor, DMY2Date(1, 1, 2020));
        Origen.Fórmula := '99.875';
        Origen.Modify(false);
        Origen.Get(Productor, DMY2Date(1, 1, 2020));
        CrearRecibo(Origen, DMY2Date(15, 1, 2020), Cabecera, Linea);
        CabeceraAntes := Cabecera;
        LineaAntes := Linea;
        VersionesAntes := ContarVersionesLotePrueba(Tipo);
        // La firma sin Boolean conserva el modo de nueva vigencia.
        Gestor.CorregirTodos(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Cambios, Pendientes, Detalle);
        Nueva.Get(Productor, DMY2Date(1, 2, 2020));
        Origen.Get(Productor, DMY2Date(1, 1, 2020));
        Assert((Origen."Vigencia Hasta" = DMY2Date(31, 1, 2020)) and (ContarVersionesLotePrueba(Tipo) = VersionesAntes + 1), 'El lote sin sobrescritura debe insertar una vigencia nueva y cerrar la anterior en el límite elegido.');
        Assert((Nueva.Fórmula = Origen.Fórmula) and (Origen."Fórmula Orden Cálculo" = '30'), 'El modo de nueva versión debe conservar el importe y el orden anterior de enero.');
        Cabecera.Get(CabeceraAntes."No.");
        Linea.Get(LineaAntes."No. Liquidación", LineaAntes."No. Línea");
        Assert((Cabecera.SystemRowVersion = CabeceraAntes.SystemRowVersion) and (Linea.SystemRowVersion = LineaAntes.SystemRowVersion), 'La corrección de configuración no debe tocar cabecera ni línea del recibo guardado.');
        AssertDependenciaSinConflicto(Tipo, Lector, DMY2Date(1, 2, 2020));
        Gestor.CorregirTodos(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Cambios, Pendientes, Detalle);
        Assert((Cambios = 0) and (ContarVersionesLotePrueba(Tipo) = VersionesAntes + 1), 'La repetición no debe insertar otra vigencia ni intentar corregir otra vez la misma arista.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure DependenciaFijaRechazaUnaFuenteFisicaModificadaTrasSeleccionarla()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Seleccionado: Record "Concepto Liquidación";
        Actual: Record "Concepto Liquidación";
        Antes: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        Productor: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearParDependenciaPrueba(Tipo, Productor, Lector, 30, 20);
        Seleccionado.Get(Productor, DMY2Date(1, 1, 2020));
        Actual := Seleccionado;
        Actual.Descripción := 'Edición concurrente del productor de la fórmula';
        Actual.Modify(false);
        Actual.Get(Productor, DMY2Date(1, 1, 2020));
        Antes := Actual;
        Assert(not IntentarPrepararConceptoSinRevertirFixturePrueba(Gestor, Seleccionado, Lector, DMY2Date(1, 2, 2020), Tipo, true, Origen, Orden, Fecha, Motivo), 'La dependencia debe rechazar la selección física obsoleta.');
        Assert(GetLastErrorText() <> '', 'La nueva clase de objetivo no debe sustituir el origen físico que seleccionó la ficha.');
        Actual.Get(Productor, DMY2Date(1, 1, 2020));
        Assert(Actual.SystemRowVersion = Antes.SystemRowVersion, 'Los rechazos deben conservar la edición concurrente sin nuevas escrituras.');
        asserterror Gestor.Aplicar(Lector, Seleccionado, Seleccionado."Vigencia Desde", 19, Tipo, 'TEST_CORR_CCT', 'GENERAL', true);
        Assert(GetLastErrorText().Contains('cambió'), 'Aplicar una dependencia debe volver a comprobar la edición concurrente bajo locks.');
        AssertRollbackSinVigenciasNiAuditoriaPrueba(Tipo, Productor);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure DependenciaBareNoAmbiguaYCamposAdicionalesIgnoranNombresEnLiterales()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Seleccionado: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        AntesAmbiguedad: Record "Concepto Liquidación";
        Tipo: Code[20];
        Productor: Code[20];
        Lector: Code[20];
        Ajeno: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearParDependenciaPrueba(Tipo, Productor, Lector, 30, 20);
        Ajeno := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, Ajeno, 900, '1', false, false);
        Seleccionado.Get(Lector, DMY2Date(1, 1, 2020));
        Seleccionado.Fórmula := Productor + ' + IF(CONVENIO = ''#' + Ajeno + ''', 1, 0)';
        Seleccionado.Condición := 'TIPO_LIQ = ''' + Tipo + ''' OR #' + Productor + ' > 0';
        Seleccionado."Variable Cantidad" := '#' + Productor;
        Seleccionado."Variable Base" := Productor;
        Seleccionado.Modify(false);
        Seleccionado.Get(Lector, DMY2Date(1, 1, 2020));
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Lector, Buffer);
        Buffer.Get(Lector);
        Assert((Buffer."Cant. Aportes" = 1) and (Buffer."Concepto Máx. Aporte" = Productor), 'La referencia bare no ambigua y las repeticiones de otros campos deben formar una única dependencia, sin incluir el código que sólo aparece entre comillas.');
        if not Gestor.PrepararConcepto(Seleccionado, Lector, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Origen, Orden, Fecha, Motivo) then
            Error('El identificador ordinario debe poder corregirse como la referencia calculada que representa: %1', Motivo);
        Assert(Orden = 31, 'El literal con nombre ajeno no debe arrastrar el orden900 al límite del lector.');
        Gestor.Aplicar(Lector, Origen, Fecha, Orden, Tipo, 'TEST_CORR_CCT', 'GENERAL', true);
        AssertDependenciaSinConflicto(Tipo, Lector, DMY2Date(1, 2, 2020));
        // Homónimo sintético: el contexto inicial se siembra con la variable externa.
        Parametro.Código := NuevoCodigo();
        Parametro."Nombre Variable" := Productor;
        Parametro.Insert(false);
        Seleccionado.Get(Lector, DMY2Date(1, 1, 2020));
        AntesAmbiguedad := Seleccionado;
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Lector, Buffer);
        Buffer.Get(Lector);
        Assert((Buffer."Cant. Aportes" = 1) and not Buffer.Conflicto and not Buffer."Requiere Contexto", 'Los # explícitos deben conservar su dependencia dura y el bare sembrado debe dejar de producir un error ficticio de ambigüedad.');
        Seleccionado.Get(Lector, DMY2Date(1, 1, 2020));
        Assert(Seleccionado.SystemRowVersion = AntesAmbiguedad.SystemRowVersion, 'Reclasificar la lectura sembrada debe permanecer en lectura.');
        Seleccionado.Fórmula := Productor;
        Seleccionado.Condición := '';
        Seleccionado."Variable Cantidad" := '';
        Seleccionado."Variable Base" := '';
        Seleccionado.Modify(false);
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Lector, Buffer);
        Assert(Buffer.IsEmpty(), 'Sin los # explícitos queda sólo una lectura sembrada: no debe inventar una fila dura ni un ciclo.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SemillaPropiaEsBlandaYArrobaLaExpandeSinOcultarCiclosExplicitos()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Gestor: Codeunit "Corrección Orden Acum.";
        Vigentes: Record "Concepto Liquidación" temporary;
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Seleccionado: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Duras: List of [Code[20]];
        Blandas: List of [Code[20]];
        Tipo: Code[20];
        Propio: Code[20];
        Lector: Code[20];
        Reevalua: Code[20];
        Errores: Text;
        Motivo: Text;
        Orden: Integer;
        Fecha: Date;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearParDependenciaPrueba(Tipo, Propio, Lector, 30, 20);
        CrearSistemaSemillaPrueba(Propio);
        Seleccionado.Get(Propio, DMY2Date(1, 1, 2020));
        Seleccionado.Fórmula := 'PISO(' + Propio + ')';
        Seleccionado.Modify(false);
        Seleccionado.Get(Propio, DMY2Date(1, 1, 2020));
        Reevalua := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, Reevalua, 40, '@' + Propio, false, true);
        CargarCatalogoDependenciasPrueba(Tipo, Vigentes);
        Control.ExtraerDependenciasConcepto(Seleccionado, Vigentes, Duras, Blandas, Errores);
        Assert((Duras.Count() = 0) and (Blandas.Count() = 1) and Blandas.Contains(Propio) and (Errores = ''), 'El bare propio sembrado debe informarse como lectura blanda, sin convertirse en una autorreferencia calculada.');
        Assert(not Control.DetectarCicloDependencias(Seleccionado, Vigentes, Motivo), 'PISO(variable propia sembrada) no forma un ciclo duro.');
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Propio, Buffer);
        Assert(Buffer.IsEmpty(), 'La lectura blanda propia no debe crear una fila de conflicto.');
        Origen.Get(Reevalua, DMY2Date(1, 1, 2020));
        Control.ExtraerDependenciasConcepto(Origen, Vigentes, Duras, Blandas, Errores);
        Assert((Duras.Count() = 0) and Blandas.Contains(Propio) and (Errores = ''), '@ debe heredar la lectura blanda en el reloj del llamador, sin exigir la ejecución de la definición.');
        if not Gestor.PrepararConcepto(Seleccionado, Lector, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Origen, Orden, Fecha, Motivo) then
            Error('La lectura blanda propia no debe impedir adelantar su concepto ante un # explícito: %1', Motivo);
        Assert((Origen.Código = Propio) and (Orden = 19), 'La guarda blanda de sí mismo debe omitirse para la fuente que se mueve.');
        Seleccionado.Get(Propio, DMY2Date(1, 1, 2020));
        Seleccionado.Fórmula := '#' + Propio;
        Seleccionado.Modify(false);
        Seleccionado.Get(Propio, DMY2Date(1, 1, 2020));
        CargarCatalogoDependenciasPrueba(Tipo, Vigentes);
        Control.ExtraerDependenciasConcepto(Seleccionado, Vigentes, Duras, Blandas, Errores);
        Assert(Duras.Contains(Propio), 'El # propio debe seguir siendo duro aunque exista una semilla homónima.');
        Assert(Control.DetectarCicloDependencias(Seleccionado, Vigentes, Motivo), '#propio debe conservar su ciclo real.');
        Seleccionado.Fórmula := '@' + Propio;
        Seleccionado.Modify(false);
        Seleccionado.Get(Propio, DMY2Date(1, 1, 2020));
        CargarCatalogoDependenciasPrueba(Tipo, Vigentes);
        Control.ExtraerDependenciasConcepto(Seleccionado, Vigentes, Duras, Blandas, Errores);
        Assert(Errores <> '', 'La recursión explícita @propio tampoco se vuelve una lectura blanda por tener semilla.');
        Assert(Control.DetectarCicloDependencias(Seleccionado, Vigentes, Motivo), 'El ciclo de expansión @ debe seguir detectándose.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure LecturasBlandasConservanLaFaseAlMoverLectoresYProductores()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Seleccionado: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        Blanda: Code[20];
        EntradaLector: Code[20];
        Lector: Code[20];
        Productor: Code[20];
        Consumidor: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        Blanda := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, Blanda, 60, '1', false, false);
        CrearParametroSemillaPrueba(Blanda);
        CrearParDependenciaPrueba(Tipo, EntradaLector, Lector, 70, 50);
        Seleccionado.Get(Lector, DMY2Date(1, 1, 2020));
        Seleccionado.Fórmula := '#' + EntradaLector + ' + ' + Blanda;
        Seleccionado.Modify(false);
        Seleccionado.Get(Lector, DMY2Date(1, 1, 2020));
        Assert(not Gestor.PrepararConcepto(Seleccionado, Lector, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Origen, Orden, Fecha, Motivo), 'El lector50 usa la semilla antes del escritor60; corregir su #entrada70 después de71 no debe cambiar esa fase blanda.');
        CrearParDependenciaPrueba(Tipo, Productor, Consumidor, 70, 40);
        Seleccionado.Get(Productor, DMY2Date(1, 1, 2020));
        Seleccionado.Fórmula := Blanda;
        Seleccionado.Modify(false);
        Seleccionado.Get(Productor, DMY2Date(1, 1, 2020));
        Assert(not Gestor.PrepararConcepto(Seleccionado, Consumidor, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Origen, Orden, Fecha, Motivo), 'El productor70 lee el resultado posterior a60; adelantarlo antes del consumidor40 no debe sustituirlo por la semilla inicial.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure UnaReferenciaDuraYBlandaAlMismoCodigoConservaAmbasGuardas()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Control: Codeunit "Control Orden Acumuladores";
        Vigentes: Record "Concepto Liquidación" temporary;
        ProductorAntes: Record "Concepto Liquidación";
        LectorAntes: Record "Concepto Liquidación";
        Actual: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Duras: List of [Code[20]];
        Blandas: List of [Code[20]];
        Tipo: Code[20];
        Productor: Code[20];
        Lector: Code[20];
        Errores: Text;
        Motivo: Text;
        Orden: Integer;
        Fecha: Date;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearParDependenciaPrueba(Tipo, Productor, Lector, 30, 20);
        CrearParametroSemillaPrueba(Productor);
        Actual.Get(Lector, DMY2Date(1, 1, 2020));
        Actual.Fórmula := '#' + Productor + ' + ' + Productor;
        Actual.Modify(false);
        LectorAntes.Get(Lector, DMY2Date(1, 1, 2020));
        ProductorAntes.Get(Productor, DMY2Date(1, 1, 2020));
        CargarCatalogoDependenciasPrueba(Tipo, Vigentes);
        Control.ExtraerDependenciasConcepto(LectorAntes, Vigentes, Duras, Blandas, Errores);
        Assert(Duras.Contains(Productor) and Blandas.Contains(Productor) and (Errores = ''), '#A y A deben conservarse en listas distintas; ninguna referencia domina ni elimina la otra.');
        Assert(not Gestor.PrepararConcepto(LectorAntes, Lector, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Origen, Orden, Fecha, Motivo), 'Atrasar el lector arreglaría #A pero cambiaría el bareA desde la semilla al importe calculado.');
        Assert(not Gestor.PrepararConcepto(ProductorAntes, Lector, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Origen, Orden, Fecha, Motivo), 'Adelantar el productor tampoco puede cambiar la fase del bareA en el lector objetivo.');
        Actual.Get(Productor, DMY2Date(1, 1, 2020));
        Assert(Actual.SystemRowVersion = ProductorAntes.SystemRowVersion, 'El productor debe permanecer intacto tras el rechazo.');
        Actual.Get(Lector, DMY2Date(1, 1, 2020));
        Assert(Actual.SystemRowVersion = LectorAntes.SystemRowVersion, 'El lector tampoco debe reescribirse.');
        asserterror Gestor.Aplicar(Lector, ProductorAntes, ProductorAntes."Vigencia Desde", 19, Tipo, 'TEST_CORR_CCT', 'GENERAL', true);
        Assert(GetLastErrorText().Contains(Lector) and GetLastErrorText().Contains('consumidor'), 'La aplicación debe bloquear el cruce del consumidor que lee también la semilla, aunque el # autorice su arista dura.');
        AssertRollbackSinVigenciasNiAuditoriaPrueba(Tipo, Productor);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AcumuladorSembradoSigueSiendoUnaDependenciaDura()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Control: Codeunit "Control Orden Acumuladores";
        Vigentes: Record "Concepto Liquidación" temporary;
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Seleccionado: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Duras: List of [Code[20]];
        Blandas: List of [Code[20]];
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Errores: Text;
        Motivo: Text;
        Orden: Integer;
        Fecha: Date;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        CrearParametroSemillaPrueba(Base);
        Seleccionado.Get(Lector, DMY2Date(1, 1, 2020));
        CargarCatalogoDependenciasPrueba(Tipo, Vigentes);
        Control.ExtraerDependenciasConcepto(Seleccionado, Vigentes, Duras, Blandas, Errores);
        Assert(Duras.Contains(Base) and not Blandas.Contains(Base) and (Errores = ''), 'El acumulador se inicializa en cero y se actualiza con sus aportes: su bare debe seguir siendo duro aunque exista una variable homónima sembrada.');
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Base, Buffer);
        Buffer.Get(Base);
        Assert(Buffer.Conflicto and (Buffer."Cant. Lecturas" = 1), 'La semilla externa no debe ocultar una lectura prematura de un acumulador.');
        if not Gestor.Preparar(Base, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Aporte, true, Origen, Orden, Fecha, Motivo) then
            Error('El aporte debe poder adelantarse antes de la lectura dura del acumulador: %1', Motivo);
        Assert(Orden = 19, 'El acumulador sembrado debe conservar la misma corrección segura de sus aportes.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure LimitesBlandosCondicionalesConservanElLadoEnTodasLasRamas()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Seleccionado: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        Blanda: Code[20];
        Entrada: Code[20];
        Lector: Code[20];
        Motivo: Text;
        Orden: Integer;
        Fecha: Date;
    begin
        Tipo := PrepararTipoLotePrueba();
        Blanda := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, Blanda, 30, '1', false, false);
        CrearParametroSemillaPrueba(Blanda);
        EstablecerFormulaOrdenPrueba(Blanda, 'IF(TIPO_LIQ = ''LIQ_FINAL'', 30, 60)');
        CrearParDependenciaPrueba(Tipo, Entrada, Lector, 70, 50);
        Seleccionado.Get(Lector, DMY2Date(1, 1, 2020));
        Seleccionado.Fórmula := '#' + Entrada + ' + ' + Blanda;
        Seleccionado.Modify(false);
        Seleccionado.Get(Lector, DMY2Date(1, 1, 2020));
        Assert(not Gestor.PrepararConcepto(Seleccionado, Lector, DMY2Date(1, 2, 2020), '', 'TEST_CORR_CCT', 'GENERAL', true, Origen, Orden, Fecha, Motivo), 'El lector50 está después de30 pero antes de60: moverlo después de70 cambiaría una sola rama blanda y debe rechazarse.');
        EstablecerFormulaOrdenPrueba(Blanda, 'IF(TIPO_LIQ = ''LIQ_FINAL'', 30, 40)');
        if not Gestor.PrepararConcepto(Seleccionado, Lector, DMY2Date(1, 2, 2020), '', 'TEST_CORR_CCT', 'GENERAL', true, Origen, Orden, Fecha, Motivo) then
            Error('Después del cambio de referencia, ambas ramas blandas quedan antes del lector y permiten corregir su #entrada: %1', Motivo);
        Assert(Orden = 71, 'La instancia reutilizada debe renovar los límites blandos y respetar la entrada dura70.');
        Gestor.Aplicar(Lector, Origen, Fecha, Orden, '', 'TEST_CORR_CCT', 'GENERAL', true);
        AssertDependenciaSinConflicto('', Lector, DMY2Date(1, 2, 2020));
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FormaFiscalConSemillaYReferenciaExplicitaNoFormaUnCicloFalso()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Control: Codeunit "Control Orden Acumuladores";
        Vigentes: Record "Concepto Liquidación" temporary;
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Seleccionado: Record "Concepto Liquidación";
        Duras: List of [Code[20]];
        Blandas: List of [Code[20]];
        Tipo: Code[20];
        Gastos: Code[20];
        Deducciones: Code[20];
        Historico: Code[20];
        RetencionPosterior: Code[20];
        Errores: Text;
        Motivo: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        Gastos := NuevoCodigo();
        Deducciones := NuevoCodigo();
        Historico := NuevoCodigo();
        RetencionPosterior := NuevoCodigo();
        CrearSistemaSemillaPrueba(Deducciones);
        CrearSistemaSemillaPrueba(Historico);
        CrearConceptoLotePrueba(Tipo, Gastos, 0, Deducciones, false, true);
        CrearConceptoLotePrueba(Tipo, Deducciones, 1, '#' + Gastos + ' + ' + Historico, false, true);
        CrearConceptoLotePrueba(Tipo, RetencionPosterior, 935, Deducciones, false, true);
        CargarCatalogoDependenciasPrueba(Tipo, Vigentes);
        Seleccionado.Get(Gastos, DMY2Date(1, 1, 2020));
        Control.ExtraerDependenciasConcepto(Seleccionado, Vigentes, Duras, Blandas, Errores);
        Assert((Duras.Count() = 0) and Blandas.Contains(Deducciones) and (Errores = ''), 'La base fiscal de orden0 lee la semilla de deducciones, no obliga a adelantar el concepto homónimo de orden1.');
        Assert(not Control.DetectarCicloDependencias(Seleccionado, Vigentes, Motivo), 'La realimentación blanda fiscal no debe convertirse en un ciclo duro.');
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Gastos, Buffer);
        Assert(Buffer.IsEmpty(), 'La base que sólo usa la semilla fiscal no necesita una fila normal de orden.');
        Seleccionado.Get(Deducciones, DMY2Date(1, 1, 2020));
        Control.ExtraerDependenciasConcepto(Seleccionado, Vigentes, Duras, Blandas, Errores);
        Assert(Duras.Contains(Gastos) and (Errores = ''), 'La lectura #base del concepto de deducciones sí debe conservar su dependencia calculada.');
        Assert(not Control.DetectarCicloDependencias(Seleccionado, Vigentes, Motivo), '#base seguido de una lectura blanda de deducciones no forma un ciclo duro.');
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Deducciones, Buffer);
        Buffer.Get(Deducciones);
        Assert(not Buffer.Conflicto and (Buffer."Cant. Aportes" = 1) and (Buffer."Concepto Máx. Aporte" = Gastos), 'La única relación dura fiscal debe quedar correctamente ordenada de0a1.');
        Seleccionado.Get(RetencionPosterior, DMY2Date(1, 1, 2020));
        Control.ExtraerDependenciasConcepto(Seleccionado, Vigentes, Duras, Blandas, Errores);
        Assert((Duras.Count() = 0) and Blandas.Contains(Deducciones) and (Errores = ''), 'La lectura fiscal de orden935 es blanda y conserva la fase posterior al escritor de deducciones1, sin añadir una arista dura ficticia.');
        Seleccionado.Get(Gastos, DMY2Date(1, 1, 2020));
        Gestor.AnalizarConcepto(Seleccionado, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Buffer);
        Assert((Buffer.Count() = 1) and Buffer.Get(Deducciones), 'La ficha fiscal debe mostrar su consumidor calculado sano, sin agregar el falso ciclo de la semilla.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ContextoGlobalNoMezclaAntiguedadDeOtroConvenioConSuLector()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Gestor: Codeunit "Corrección Orden Acum.";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Antes: Record "Concepto Liquidación";
        Actual: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 60);
        EstablecerFormulaOrdenPrueba(Aporte, 'IF(CONVENIO = ''TEST_CORR_CCT'', 50, 100)');
        IncluirParContextoPrueba(Lector, DMY2Date(1, 1, 2020), 'TEST_CORR_CCT', '', false);
        Antes.Get(Aporte, DMY2Date(1, 1, 2020));
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, '', '', Base, Buffer);
        Buffer.Get(Base);
        Assert(not Buffer.Conflicto and not Buffer."Requiere Contexto", 'El aporte50 del convenio del lector60 es seguro; su rama100 de otro convenio no debe inventar el conflicto de antigüedad.');
        Assert(not Gestor.Proponer(Base, DMY2Date(1, 2, 2020), Tipo, '', '', true, Origen, Orden, Fecha, Motivo), 'Sin una precedencia posterior compatible no se debe fabricar una corrección.');
        Actual.Get(Aporte, DMY2Date(1, 1, 2020));
        Assert((Actual.SystemRowVersion = Antes.SystemRowVersion) and (Actual."Fórmula Orden Cálculo" = Antes."Fórmula Orden Cálculo"), 'Descartar el falso aviso debe permanecer en lectura y conservar el IF parametrizado.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ContextosDeTiposExcluyentesNoFormanUnSubtotalInconsistente()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Bandera: Code[20];
        ParDesconocido: Boolean;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 470);
        Bandera := NuevoCodigo();
        CrearSistemaSemillaPrueba(Bandera);
        EstablecerFormulaOrdenPrueba(Aporte, 'IF(' + Bandera + ' > 0, 471, 159)');
        EstablecerTiposCompatiblesPrueba(Base, Tipo + '|LIQ_FINAL');
        EstablecerTiposCompatiblesPrueba(Lector, 'LIQ_FINAL');
        Concepto.Get(Aporte, DMY2Date(1, 1, 2020));
        Assert(not Control.ConceptoIncluidoEnContexto(Concepto, DMY2Date(1, 2, 2020), 'LIQ_FINAL', 'TEST_CORR_CCT', 'GENERAL', ParDesconocido), 'Un aporte declarado sólo para devengados no pertenece a una liquidación final.');
        Control.Analizar(DMY2Date(1, 2, 2020), '', 'TEST_CORR_CCT', 'GENERAL', Base, Buffer);
        Buffer.Get(Base);
        Assert(not Buffer.Conflicto and not Buffer."Requiere Contexto", 'Las ramas471/159 no deben compararse con el lector470 de otro tipo de liquidación, aunque falte la bandera del empleado.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure DependenciasIfCaseYArrobaSePodanSoloConElContextoConocido()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Vigentes: Record "Concepto Liquidación" temporary;
        Concepto: Record "Concepto Liquidación";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Duras: List of [Code[20]];
        Blandas: List of [Code[20]];
        Tipo: Code[20];
        Productor: Code[20];
        Lector: Code[20];
        Definicion: Code[20];
        Errores: Text;
        RequiereContexto: Boolean;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearParDependenciaPrueba(Tipo, Productor, Lector, 500, 400);
        EstablecerTiposCompatiblesPrueba(Productor, Tipo + '|LIQ_FINAL');
        EstablecerTiposCompatiblesPrueba(Lector, Tipo + '|LIQ_FINAL');
        Concepto.Get(Lector, DMY2Date(1, 1, 2020));
        Concepto.Fórmula := 'IF(TIPO_LIQ = ''LIQ_FINAL'', #' + Productor + ', 0)';
        Concepto."Fórmula Orden Cálculo" := 'IF(TIPO_LIQ = ''LIQ_FINAL'', 600, 400)';
        Concepto.Modify(false);
        CargarCatalogoPorCodigosContextoPrueba(Productor, Lector, '', Vigentes);
        Control.ExtraerDependenciasConcepto(Concepto, Vigentes, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Duras, Blandas, Errores, RequiereContexto);
        Assert((Duras.Count() = 0) and (Errores = '') and not RequiereContexto, 'La rama regular de3573 no lee3973: no debe exigir que500 preceda a400.');
        Control.ExtraerDependenciasConcepto(Concepto, Vigentes, DMY2Date(1, 2, 2020), 'LIQ_FINAL', 'TEST_CORR_CCT', 'GENERAL', Duras, Blandas, Errores, RequiereContexto);
        Assert((Duras.Count() = 1) and Duras.Contains(Productor) and not RequiereContexto, 'La rama final debe conservar la referencia explícita al productor500.');
        Control.Analizar(DMY2Date(1, 2, 2020), '', 'TEST_CORR_CCT', 'GENERAL', Lector, Buffer);
        Buffer.Get(Lector);
        Assert(not Buffer.Conflicto and not Buffer."Requiere Contexto" and (Buffer."Orden Mín. Lectura" = 600), 'El global debe comparar el productor500 sólo con la lectura600 en la que se utiliza.');
        Definicion := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, Definicion, 999, 'CASE(CONVENIO = ''TEST_CORR_CCT'', #' + Productor + ', 0)', false, true);
        Concepto.Get(Lector, DMY2Date(1, 1, 2020));
        Concepto.Fórmula := '@' + Definicion;
        Concepto.Modify(false);
        CargarCatalogoPorCodigosContextoPrueba(Productor, Lector, Definicion, Vigentes);
        Control.ExtraerDependenciasConcepto(Concepto, Vigentes, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_OTRO', 'GENERAL', Duras, Blandas, Errores, RequiereContexto);
        Assert((Duras.Count() = 0) and (Errores = '') and not RequiereContexto, 'CASE dentro de@ debe podarse con el convenio del llamador, sin imponer el orden999 de la definición.');
        Control.ExtraerDependenciasConcepto(Concepto, Vigentes, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Duras, Blandas, Errores, RequiereContexto);
        Assert((Duras.Count() = 1) and Duras.Contains(Productor) and not RequiereContexto, 'Volver al primer convenio en la misma instancia debe recuperar su dependencia, sin caché del CASE anterior.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure DatosDelEmpleadoDesconocidosNoSeConviertenEnCeroParaPodarRamas()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Gestor: Codeunit "Corrección Orden Acum.";
        Vigentes: Record "Concepto Liquidación" temporary;
        Concepto: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Duras: List of [Code[20]];
        Blandas: List of [Code[20]];
        Tipo: Code[20];
        Productor: Code[20];
        Lector: Code[20];
        Bandera: Code[20];
        Orden: Integer;
        Fecha: Date;
        Errores: Text;
        Motivo: Text;
        RequiereContexto: Boolean;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearParDependenciaPrueba(Tipo, Productor, Lector, 500, 400);
        Bandera := NuevoCodigo();
        CrearSistemaSemillaPrueba(Bandera);
        Concepto.Get(Lector, DMY2Date(1, 1, 2020));
        Concepto.Fórmula := 'IF(' + Bandera + ' > 0, #' + Productor + ', 0)';
        Concepto.Modify(false);
        CargarCatalogoDependenciasPrueba(Tipo, Vigentes);
        Control.ExtraerDependenciasConcepto(Concepto, Vigentes, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Duras, Blandas, Errores, RequiereContexto);
        Assert(Duras.Contains(Productor) and RequiereContexto and (Errores = ''), 'Una variable del empleado sin valor debe unir las referencias posibles y marcar incertidumbre, aunque el preflight la pueda sembrar con cero.');
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Lector, Buffer);
        Buffer.Get(Lector);
        Assert(Buffer.Conflicto and Buffer."Requiere Contexto", 'La lectura potencial de500 antes de400 no se debe ocultar ni demostrar con un empleado inventado.');
        Assert(not Gestor.Preparar(Lector, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Lector, true, Origen, Orden, Fecha, Motivo), 'Una precedencia que depende de datos de empleado no prueba la necesidad de modificar el lector.');
        Concepto.Fórmula := 'IF(' + Bandera + ' > 0, #' + Productor + ', #' + Productor + ')';
        Concepto.Modify(false);
        CargarCatalogoDependenciasPrueba(Tipo, Vigentes);
        Control.ExtraerDependenciasConcepto(Concepto, Vigentes, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Duras, Blandas, Errores, RequiereContexto);
        Assert((Duras.Count() = 1) and Duras.Contains(Productor) and not RequiereContexto, 'Si ambas ramas leen lo mismo, la condición desconocida no debe producir un bloqueo artificial.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure LectorExclusivoDeFinalUsaSuOrden669SinCompararLaRama478()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Gestor: Codeunit "Corrección Orden Acum.";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 669);
        EstablecerTiposCompatiblesPrueba(Base, 'LIQ_FINAL');
        EstablecerTiposCompatiblesPrueba(Aporte, 'LIQ_FINAL');
        EstablecerTiposCompatiblesPrueba(Lector, 'LIQ_FINAL');
        EstablecerFormulaOrdenPrueba(Aporte, '650');
        EstablecerFormulaOrdenPrueba(Lector, 'IF(TIPO_LIQ = ''LIQ_FINAL'', 669, 478)');
        Concepto.Get(Lector, DMY2Date(1, 1, 2020));
        Assert(Control.ResolverOrdenEnContexto(Concepto, DMY2Date(1, 2, 2020), 'LIQ_FINAL', 'TEST_CORR_CCT', Orden) and (Orden = 669), 'La evaluación contextual debe conservar el orden669 de una liquidación final.');
        Control.Analizar(DMY2Date(1, 2, 2020), '', 'TEST_CORR_CCT', 'GENERAL', Base, Buffer);
        Buffer.Get(Base);
        Assert(not Buffer.Conflicto and not Buffer."Requiere Contexto" and (Buffer."Orden Mín. Lectura" = 669), '3814 sólo existe en final: el orden478 de otros tipos no es una lectura compatible.');
        Assert(not Gestor.Proponer(Base, DMY2Date(1, 2, 2020), '', 'TEST_CORR_CCT', 'GENERAL', true, Origen, Orden, Fecha, Motivo), 'No debe corregir el aporte650 que ya precede a669.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PrecedenciaRealCompatibleSeCorrigeSinAplanarLasOtrasRamas()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Gestor: Codeunit "Corrección Orden Acum.";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        LectorAntes: Record "Concepto Liquidación";
        LectorActual: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        EstablecerFormulaOrdenPrueba(Lector, 'IF(CONVENIO = ''TEST_CORR_CCT'', 20, 40)');
        LectorAntes.Get(Lector, DMY2Date(1, 1, 2020));
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, '', '', Base, Buffer);
        Buffer.Get(Base);
        Assert(Buffer.Conflicto and not Buffer."Requiere Contexto", 'El aporte30 sí llega tarde al lector20 en el mismo convenio: debe conservarse el conflicto real.');
        if not Gestor.Preparar(Base, DMY2Date(1, 2, 2020), Tipo, '', '', Aporte, true, Origen, Orden, Fecha, Motivo) then
            Error('Debe poder corregir la precedencia compatible preservando las demás ramas: %1', Motivo);
        Assert((Orden = 19) and (Fecha = DMY2Date(1, 1, 2020)), 'El arreglo mínimo actualiza el aporte a19 desde la misma vigencia; sigue antes del lector40 de los demás convenios.');
        Gestor.Aplicar(Base, Origen, Fecha, Orden, Tipo, '', '', true);
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, '', '', Base, Buffer);
        Buffer.Get(Base);
        Assert(not Buffer.Conflicto and not Buffer."Requiere Contexto", 'La corrección global debe resolver la precedencia real en todos los convenios compatibles.');
        LectorActual.Get(Lector, DMY2Date(1, 1, 2020));
        Assert((LectorActual.SystemRowVersion = LectorAntes.SystemRowVersion) and (LectorActual."Fórmula Orden Cálculo" = LectorAntes."Fórmula Orden Cálculo"), 'Comprobar las ramas no debe reescribir el orden condicional del lector.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure CorreccionGlobalConservaElSubtotalDeOtroConvenioAunqueNoCoexistaConElObjetivo()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        Seleccionado: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        OtraBase: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        OtroLector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
        Formula: Text;
        Impacto: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        IncluirParContextoPrueba(Lector, DMY2Date(1, 1, 2020), 'TEST_CORR_CCT', '', false);
        OtraBase := NuevoCodigo();
        OtroLector := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, OtraBase, 0, '', true, false);
        CrearConceptoLotePrueba(Tipo, OtroLector, 25, OtraBase, false, true);
        IncluirParContextoPrueba(OtroLector, DMY2Date(1, 1, 2020), 'TEST_CORR_OTRO', '', false);
        CrearFraccion(Aporte, OtraBase);
        Seleccionado.Get(Aporte, DMY2Date(1, 1, 2020));
        Assert(not Gestor.Preparar(Base, DMY2Date(1, 2, 2020), Tipo, '', '', Aporte, true, Origen, Orden, Fecha, Motivo), 'Adelantar30 a19 resolvería el convenio objetivo, pero cambiaría el subtotal25 que hoy se lee antes del aporte en otro convenio.');
        asserterror Gestor.Validar(Base, Seleccionado, Seleccionado."Vigencia Desde", 19, Tipo, '', '', true, Formula, Impacto);
        Assert(GetLastErrorText() <> '', 'La seguridad global debe comprobar también los contextos donde el objetivo no participa.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure CompatibilidadFuturaSeRevalidaAlAparecerOtroLectorIncluido()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Seleccionado: Record "Concepto Liquidación";
        Futuro: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        OtraBase: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        OtroLector: Code[20];
        Formula: Text;
        Impacto: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        IncluirParContextoPrueba(Lector, DMY2Date(1, 1, 2020), 'TEST_CORR_CCT', '', false);
        OtraBase := NuevoCodigo();
        OtroLector := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, OtraBase, 0, '', true, false);
        CrearFraccion(Aporte, OtraBase);
        Seleccionado.Get(Aporte, DMY2Date(1, 1, 2020));
        Gestor.Validar(Base, Seleccionado, Seleccionado."Vigencia Desde", 19, Tipo, '', '', true, Formula, Impacto);
        // La baja se expresa por fechas: Activo ya no tiene efecto en los conceptos.
        Futuro.Código := OtroLector;
        Futuro."Vigencia Desde" := DMY2Date(1, 3, 2020);
        Futuro."Tipos Liq. Aplicables" := Tipo;
        Futuro."Tipo Concepto" := Futuro."Tipo Concepto"::Informativo;
        Futuro."Orden Cálculo" := 25;
        Futuro."Fórmula Orden Cálculo" := '25';
        Futuro.Fórmula := OtraBase;
        Futuro.Insert(true);
        IncluirParContextoPrueba(OtroLector, DMY2Date(1, 3, 2020), 'TEST_CORR_OTRO', '', false);
        asserterror Gestor.Validar(Base, Seleccionado, Seleccionado."Vigencia Desde", 19, Tipo, '', '', true, Formula, Impacto);
        Assert(GetLastErrorText().Contains(OtroLector), 'El lector25 que empieza en marzo en otro convenio debe bloquear el cruce global, aunque febrero de la misma instancia lo hubiera considerado seguro.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ContextosEnumeranCategoriasYBlancosSinAsumirElParDePuesto()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Concepto: Record "Concepto Liquidación";
        Contextos: List of [Text];
        Clave: Text;
        Motivo: Text;
        Tipo: Code[20];
        TipoActual: Code[20];
        ConvenioActual: Code[20];
        CategoriaActual: Code[20];
        Codigo: Code[20];
        CantBlancos: Integer;
        CantCategoria: Integer;
        ParDesconocido: Boolean;
    begin
        Tipo := PrepararTipoLotePrueba();
        Codigo := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, Codigo, 30, '1', false, false);
        IncluirParContextoPrueba(Codigo, DMY2Date(1, 1, 2020), 'TEST_CORR_CCT', 'CAT_A', false);
        Assert(Control.EnumerarContextosOrden(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', '', Contextos, Motivo), 'Los maestros y las categorías explícitas deben permitir enumerar el dominio sin consultar empleados.');
        foreach Clave in Contextos do begin
            Control.DesglosarContextoOrden(Clave, TipoActual, ConvenioActual, CategoriaActual);
            Assert((TipoActual = Tipo) and (ConvenioActual = 'TEST_CORR_CCT'), 'El dominio filtrado debe conservar exactamente el tipo y convenio solicitados.');
            if CategoriaActual = '' then
                CantBlancos += 1;
            if CategoriaActual = 'CAT_A' then
                CantCategoria += 1;
        end;
        Assert((CantBlancos = 1) and (CantCategoria = 1), 'La categoría explícita y la clase residual en blanco deben aparecer una sola vez.');
        Concepto.Get(Codigo, DMY2Date(1, 1, 2020));
        Assert(Control.ConceptoIncluidoEnContexto(Concepto, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'CAT_A', ParDesconocido) and not ParDesconocido, 'El par del empleado sí permite demostrar la inclusión exacta.');
        Assert(not Control.ConceptoIncluidoEnContexto(Concepto, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', '', ParDesconocido), 'El blanco concreto no debe interpretarse como todas las categorías incluidas.');
        Concepto."Par CCT a Usar" := Concepto."Par CCT a Usar"::Puesto;
        Concepto.Modify(false);
        Assert(Control.ConceptoIncluidoEnContexto(Concepto, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_OTRO', '', ParDesconocido) and ParDesconocido, 'El par de puesto pendiente no debe descartarse suponiendo el par de la cabecera, aunque allí no figure incluido.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AporteConCondicionDeTipoOConvenioFalsaNoPruebaUnaPrecedencia()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Gestor: Codeunit "Corrección Orden Acum.";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Motivo: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        Concepto.Get(Aporte, DMY2Date(1, 1, 2020));
        Concepto.Condición := 'TIPO_LIQ = ''LIQ_FINAL''';
        Concepto.Modify(false);
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Base, Buffer);
        Buffer.Get(Base);
        Assert((Buffer."Cant. Aportes" = 0) and not Buffer.Conflicto and not Buffer."Requiere Contexto", 'Una condición de tipo demostrablemente falsa impide que el concepto aporte: no debe compararse su orden30 con el lector20.');
        Assert(not Gestor.Preparar(Base, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Aporte, true, Origen, Orden, Fecha, Motivo), 'Un aporte que no se calcula en este tipo no demuestra necesidad de cambio.');
        Concepto.Get(Aporte, DMY2Date(1, 1, 2020));
        Concepto.Condición := 'CONVENIO = ''TEST_CORR_OTRO''';
        Concepto.Modify(false);
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Base, Buffer);
        Buffer.Get(Base);
        Assert((Buffer."Cant. Aportes" = 0) and not Buffer.Conflicto, 'La condición por convenio también debe excluir el aporte cuando es falsa.');
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_OTRO', 'GENERAL', Base, Buffer);
        Buffer.Get(Base);
        Assert((Buffer."Cant. Aportes" = 1) and Buffer.Conflicto and not Buffer."Requiere Contexto", 'Al cambiar al convenio verdadero debe reaparecer el conflicto real, sin arrastrar la condición falsa de la caché.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AporteConCondicionDeEmpleadoDesconocidaQuedaPendienteSinEscribir()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Gestor: Codeunit "Corrección Orden Acum.";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        AporteAntes: Record "Concepto Liquidación";
        LectorAntes: Record "Concepto Liquidación";
        Actual: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Tipo: Code[20];
        Base: Code[20];
        Aporte: Code[20];
        Lector: Code[20];
        Bandera: Code[20];
        Orden: Integer;
        Fecha: Date;
        Cambios: Integer;
        Pendientes: Integer;
        CantidadAntes: Integer;
        Motivo: Text;
        Detalle: Text;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearCasoLotePrueba(Tipo, Base, Aporte, Lector, 20);
        Bandera := NuevoCodigo();
        CrearSistemaSemillaPrueba(Bandera);
        Actual.Get(Aporte, DMY2Date(1, 1, 2020));
        Actual.Condición := Bandera + ' > 0';
        Actual.Modify(false);
        AporteAntes.Get(Aporte, DMY2Date(1, 1, 2020));
        LectorAntes.Get(Lector, DMY2Date(1, 1, 2020));
        CantidadAntes := ContarVersionesLotePrueba(Tipo);
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Base, Buffer);
        Buffer.Get(Base);
        Assert(Buffer.Conflicto and Buffer."Requiere Contexto", 'La condición sin datos del empleado permite un aporte tardío posible; no debe excluirse por cero ni darse por demostrado.');
        Assert(not Gestor.Proponer(Base, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Origen, Orden, Fecha, Motivo), 'Ni adelantar el aporte ni atrasar el lector son necesarios de forma comprobada cuando no se conoce si ese aporte se calcula.');
        Gestor.CorregirTodos(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Cambios, Pendientes, Detalle);
        Assert((Cambios = 0) and (Pendientes = 1) and (ContarVersionesLotePrueba(Tipo) = CantidadAntes), 'El lote debe dejar esa precedencia pendiente, sin cambiar ni crear vigencias.');
        Actual.Get(Aporte, DMY2Date(1, 1, 2020));
        Assert(Actual.SystemRowVersion = AporteAntes.SystemRowVersion, 'El aporte condicionado por datos del empleado debe conservarse intacto.');
        Actual.Get(Lector, DMY2Date(1, 1, 2020));
        Assert(Actual.SystemRowVersion = LectorAntes.SystemRowVersion, 'El lector también debe conservar su orden mientras no haya necesidad comprobada.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure LectorConCondicionFalsaYReferenciaEnLaCondicionNoJustificaCambios()
    begin
        AssertLectorTestigoNoJustificaCambioPrueba(true);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure LectorConCondicionDesconocidaQueRepiteElProductorNoJustificaCambios()
    begin
        AssertLectorTestigoNoJustificaCambioPrueba(false);
    end;

    local procedure AssertLectorTestigoNoJustificaCambioPrueba(CondicionFalsa: Boolean)
    var
        Control: Codeunit "Control Orden Acumuladores";
        Gestor: Codeunit "Corrección Orden Acum.";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Vigentes: Record "Concepto Liquidación" temporary;
        ProductorAntes: Record "Concepto Liquidación";
        LectorAntes: Record "Concepto Liquidación";
        Actual: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        Historial: Record "Historial Fórmula Concepto";
        Duras: List of [Code[20]];
        Blandas: List of [Code[20]];
        Tipo: Code[20];
        Productor: Code[20];
        Lector: Code[20];
        Orden: Integer;
        Fecha: Date;
        Cambios: Integer;
        Pendientes: Integer;
        CantidadAntes: Integer;
        CantidadHistorialAntes: Integer;
        FirmaHistorialAntes: Text;
        Errores: Text;
        Motivo: Text;
        Detalle: Text;
        RequiereContexto: Boolean;
    begin
        Tipo := PrepararTipoLotePrueba();
        CrearParDependenciaPrueba(Tipo, Productor, Lector, 30, 20);
        Actual.Get(Lector, DMY2Date(1, 1, 2020));
        Actual.Condición := '#' + Productor + ' > 0';
        if CondicionFalsa then
            Actual.Condición := 'TIPO_LIQ = ''LIQ_FINAL'' AND #' + Productor + ' > 0';
        Actual.Modify(false);
        LectorAntes.Get(Lector, DMY2Date(1, 1, 2020));
        ProductorAntes.Get(Productor, DMY2Date(1, 1, 2020));
        CantidadAntes := ContarVersionesLotePrueba(Tipo);
        Historial.SetFilter("Cód. Concepto", '%1|%2', Productor, Lector);
        CantidadHistorialAntes := Historial.Count();
        FirmaHistorialAntes := FirmaHistorialContextoPrueba(Productor, Lector);
        Assert(CantidadHistorialAntes > 0, 'Insert(true) registra las altas de las fórmulas sintéticas; ese historial previo debe formar parte de la comparación.');
        CargarCatalogoDependenciasPrueba(Tipo, Vigentes);
        Control.ExtraerDependenciasConcepto(LectorAntes, Vigentes, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Duras, Blandas, Errores, RequiereContexto);
        Assert((Duras.Count() = 1) and Duras.Contains(Productor) and (Errores = ''), 'El # de la condición debe conservarse una vez como guarda: la condición falsa u opaca no autoriza borrar referencias ni fabricar errores.');
        Control.Analizar(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Lector, Buffer);
        Assert(Buffer.Get(Lector), 'La referencia explícita evaluada por la condición debe conservar su fila de control.');
        Assert(not Gestor.Preparar(Lector, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Productor, true, Origen, Orden, Fecha, Motivo), 'Un lector testigo que no produce de forma comprobada no demuestra que deba adelantarse su productor.');
        Assert(not Gestor.Preparar(Lector, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', Lector, true, Origen, Orden, Fecha, Motivo), 'Tampoco demuestra que deba atrasarse el propio lector condicionado.');
        Assert(not Gestor.Proponer(Lector, DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Origen, Orden, Fecha, Motivo), 'La propuesta general debe conservar el caso para revisión y no usar el # repetido para simular una necesidad demostrada.');
        Gestor.CorregirTodos(DMY2Date(1, 2, 2020), Tipo, 'TEST_CORR_CCT', 'GENERAL', true, Cambios, Pendientes, Detalle);
        Assert((Cambios = 0) and (ContarVersionesLotePrueba(Tipo) = CantidadAntes), 'La corrección automática no debe escribir ni crear vigencias a partir de ese lector testigo.');
        Actual.Get(Productor, DMY2Date(1, 1, 2020));
        Assert(Actual.SystemRowVersion = ProductorAntes.SystemRowVersion, 'El productor debe conservar su registro físico.');
        Actual.Get(Lector, DMY2Date(1, 1, 2020));
        Assert(Actual.SystemRowVersion = LectorAntes.SystemRowVersion, 'El lector debe conservar fórmula, condición y orden.');
        Assert((Historial.Count() = CantidadHistorialAntes) and (FirmaHistorialContextoPrueba(Productor, Lector) = FirmaHistorialAntes), 'Sin una necesidad comprobada debe conservarse exactamente el historial previo, sin agregar, borrar ni reescribir entradas.');
        Historial.SetRange("Tipo Cambio", Historial."Tipo Cambio"::Orden);
        Assert(Historial.IsEmpty(), 'Las altas iniciales no son cambios de orden; el corrector bloqueado tampoco debe agregar una auditoría de orden.');
    end;

    local procedure FirmaHistorialContextoPrueba(Productor: Code[20]; Lector: Code[20]): Text
    var
        Historial: Record "Historial Fórmula Concepto";
        Firma: Text;
    begin
        Historial.SetFilter("Cód. Concepto", '%1|%2', Productor, Lector);
        if Historial.FindSet() then
            repeat
                Firma += Format(Historial."No. Entrada", 0, 9) + ':' + Format(Historial.SystemRowVersion, 0, 9) + '|';
            until Historial.Next() = 0;
        exit(Firma);
    end;

    // AssertError revierte también los datos sintéticos anteriores al error. Estas guardas
    // deben poder comprobar que las PK/rowversion siguen intactas después del rechazo.
    [TryFunction]
    local procedure IntentarAnalizarConceptoSinRevertirFixturePrueba(var Gestor: Codeunit "Corrección Orden Acum."; Seleccionado: Record "Concepto Liquidación"; FechaRef: Date; Tipo: Code[20]; var Buffer: Record "Diag. Orden Acum. Buffer" temporary)
    begin
        Gestor.AnalizarConcepto(Seleccionado, FechaRef, Tipo, 'TEST_CORR_CCT', 'GENERAL', Buffer);
    end;

    [TryFunction]
    local procedure IntentarPrepararConceptoSinRevertirFixturePrueba(var Gestor: Codeunit "Corrección Orden Acum."; Seleccionado: Record "Concepto Liquidación"; Objetivo: Code[20]; FechaRef: Date; Tipo: Code[20]; Actualizar: Boolean; var Origen: Record "Concepto Liquidación"; var Orden: Integer; var FechaNueva: Date; var Motivo: Text)
    begin
        if Gestor.PrepararConcepto(Seleccionado, Objetivo, FechaRef, Tipo, 'TEST_CORR_CCT', 'GENERAL', Actualizar, Origen, Orden, FechaNueva, Motivo) then;
    end;

    [TryFunction]
    local procedure IntentarValidarSinRevertirFixturePrueba(var Gestor: Codeunit "Corrección Orden Acum."; Objetivo: Code[20]; Origen: Record "Concepto Liquidación"; FechaNueva: Date; Orden: Integer; Tipo: Code[20]; Actualizar: Boolean; var Formula: Text; var Impacto: Text)
    begin
        Gestor.Validar(Objetivo, Origen, FechaNueva, Orden, Tipo, 'TEST_CORR_CCT', 'GENERAL', Actualizar, Formula, Impacto);
    end;

    local procedure AssertRollbackSinVigenciasNiAuditoriaPrueba(Tipo: Code[20]; Codigo: Code[20])
    var
        Historial: Record "Historial Fórmula Concepto";
    begin
        Assert(ContarVersionesLotePrueba(Tipo) = 0, 'AssertError debe revertir toda la fixture de conceptos, sin dejar versiones parciales del intento bloqueado.');
        Historial.SetRange("Cód. Concepto", Codigo);
        Assert(Historial.IsEmpty(), 'El rollback del rechazo debe conservar la atomicidad sin filas de auditoría parciales.');
    end;

    local procedure CargarCatalogoPorCodigosContextoPrueba(Primero: Code[20]; Segundo: Code[20]; Tercero: Code[20]; var Vigentes: Record "Concepto Liquidación" temporary)
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Vigentes.Reset();
        Vigentes.DeleteAll();
        Concepto.SetFilter(Código, '%1|%2|%3', Primero, Segundo, Tercero);
        if Concepto.FindSet() then
            repeat
                Vigentes := Concepto;
                Vigentes.Insert(false);
            until Concepto.Next() = 0;
        Vigentes.Reset();
    end;

    local procedure EstablecerTiposCompatiblesPrueba(Codigo: Code[20]; Tipos: Text)
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Concepto.Get(Codigo, DMY2Date(1, 1, 2020));
        Concepto."Tipos Liq. Aplicables" := CopyStr(Tipos, 1, MaxStrLen(Concepto."Tipos Liq. Aplicables"));
        Concepto.Modify(false);
    end;

    local procedure IncluirParContextoPrueba(Codigo: Code[20]; Desde: Date; Convenio: Code[20]; Categoria: Code[20]; Excluir: Boolean)
    var
        Restriccion: Record "Concepto CCT Vigente";
    begin
        Restriccion."Cód. Concepto" := Codigo;
        Restriccion."Vigencia Desde" := Desde;
        Restriccion."Cód. Convenio" := Convenio;
        Restriccion."Cód. Categoría" := Categoria;
        Restriccion.Excluye := Excluir;
        Restriccion.Insert(false);
    end;

    local procedure CargarCatalogoDependenciasPrueba(Tipo: Code[20]; var Vigentes: Record "Concepto Liquidación" temporary)
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Vigentes.Reset();
        Vigentes.DeleteAll();
        Concepto.SetRange("Tipos Liq. Aplicables", Tipo);
        if Concepto.FindSet() then
            repeat
                Vigentes := Concepto;
                Vigentes.Insert(false);
            until Concepto.Next() = 0;
        Vigentes.Reset();
    end;

    local procedure CrearParametroSemillaPrueba(Nombre: Code[20])
    var
        Parametro: Record "Parámetro";
    begin
        Parametro.Código := NuevoCodigo();
        Parametro."Nombre Variable" := Nombre;
        Parametro.Insert(false);
    end;

    local procedure CrearSistemaSemillaPrueba(Nombre: Code[20])
    var
        Sistema: Record "Variable Sistema Liq.";
    begin
        Sistema."Nombre Variable" := Nombre;
        Sistema.Activo := true;
        Sistema.Insert(false);
    end;

    local procedure CrearParDependenciaPrueba(Tipo: Code[20]; var Productor: Code[20]; var Lector: Code[20]; OrdenProductor: Integer; OrdenLector: Integer)
    begin
        Productor := NuevoCodigo();
        Lector := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, Productor, OrdenProductor, '1', false, false);
        CrearConceptoLotePrueba(Tipo, Lector, OrdenLector, '#' + Productor, false, true);
    end;

    local procedure AssertDependenciaSinConflicto(Tipo: Code[20]; Lector: Code[20]; Fecha: Date)
    var
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
    begin
        Control.Analizar(Fecha, Tipo, 'TEST_CORR_CCT', 'GENERAL', Lector, Buffer);
        Buffer.Get(Lector);
        Assert((Buffer."Concepto Mín. Lectura" = Lector) and (Buffer."Cant. Lecturas" = 1), 'El lector normal debe conservar su fila de dependencias aun después de corregirse.');
        Assert(not Buffer.Conflicto and not Buffer."Requiere Contexto", 'Todas las entradas calculadas del lector deben quedar antes de su ejecución.');
    end;

    local procedure EstablecerFormulaOrdenPrueba(Codigo: Code[20]; FormulaOrden: Text)
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Concepto.Get(Codigo, DMY2Date(1, 1, 2020));
        Concepto."Fórmula Orden Cálculo" := CopyStr(FormulaOrden, 1, MaxStrLen(Concepto."Fórmula Orden Cálculo"));
        Concepto.Modify(false);
    end;

    local procedure AssertOrdenesPosiblesRechazados(FormulaOrden: Text)
    var
        Control: Codeunit "Control Orden Acumuladores";
        Concepto: Record "Concepto Liquidación";
        Ordenes: List of [Integer];
    begin
        Concepto."Fórmula Orden Cálculo" := CopyStr(FormulaOrden, 1, MaxStrLen(Concepto."Fórmula Orden Cálculo"));
        Ordenes.Add(777);
        Assert(not Control.ObtenerOrdenesPosibles(Concepto, DMY2Date(1, 2, 2020), '', '', Ordenes), 'No debe aproximar hojas que no sean enteros literales ni aceptar un IF mal formado: ' + FormulaOrden);
        Assert(Ordenes.Count() = 0, 'Una fórmula no verificable debe vaciar también las hojas parciales y el resultado de consultas anteriores.');
    end;

    local procedure PrepararTipoLotePrueba(): Code[20]
    var
        Tipo: Record "Tipo Liquidación";
    begin
        PrepararCatalogos();
        Tipo.Código := NuevoCodigo();
        Tipo.Orden := 900003;
        Tipo."Sólo Conceptos Declarados" := true;
        Tipo.Insert(false);
        exit(Tipo.Código);
    end;

    local procedure CrearCasoLotePrueba(Tipo: Code[20]; var Base: Code[20]; var Aporte: Code[20]; var Lector: Code[20]; OrdenLector: Integer)
    begin
        Base := NuevoCodigo();
        Aporte := NuevoCodigo();
        Lector := NuevoCodigo();
        CrearConceptoLotePrueba(Tipo, Base, 0, '', true, false);
        CrearConceptoLotePrueba(Tipo, Aporte, 30, '', false, false);
        CrearConceptoLotePrueba(Tipo, Lector, OrdenLector, Base, false, true);
        CrearFraccion(Aporte, Base);
    end;

    local procedure CrearConceptoLotePrueba(Tipo: Code[20]; Codigo: Code[20]; Orden: Integer; Formula: Text; EsAcumulador: Boolean; EsVirtual: Boolean)
    var
        Concepto: Record "Concepto Liquidación";
    begin
        CrearConcepto(Codigo, Orden, Formula, EsAcumulador, EsVirtual);
        Concepto.Get(Codigo, DMY2Date(1, 1, 2020));
        Concepto."Tipos Liq. Aplicables" := Tipo;
        Concepto.Modify(false);
    end;

    local procedure ContarVersionesLotePrueba(Tipo: Code[20]): Integer
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Concepto.SetRange("Tipos Liq. Aplicables", Tipo);
        exit(Concepto.Count());
    end;

    local procedure AssertLoteSinConflicto(Tipo: Code[20]; Base: Code[20]; Fecha: Date)
    var
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
    begin
        Control.Analizar(Fecha, Tipo, 'TEST_CORR_CCT', 'GENERAL', Base, Buffer);
        Buffer.Get(Base);
        Assert(not Buffer.Conflicto and not Buffer."Requiere Contexto", StrSubstNo('La base %1 debe quedar completa, sin depender de un orden obsoleto en caché.', Base));
    end;

    local procedure AssertMismoDiagnostico(Esperado: Record "Diag. Orden Acum. Buffer"; Actual: Record "Diag. Orden Acum. Buffer")
    begin
        Assert((Actual."Cód. Acumulador" = Esperado."Cód. Acumulador") and (Actual.Descripción = Esperado.Descripción), 'La identidad y descripción de la fila deben coincidir con el análisis global.');
        Assert((Actual."Cant. Aportes" = Esperado."Cant. Aportes") and (Actual."Cant. Lecturas" = Esperado."Cant. Lecturas"), 'El análisis acotado debe conservar ambos conteos del global.');
        Assert((Actual."Orden Máx. Aporte" = Esperado."Orden Máx. Aporte") and (Actual."Concepto Máx. Aporte" = Esperado."Concepto Máx. Aporte"), 'Debe conservar el extremo aportante y su desempate por código.');
        Assert((Actual."Orden Mín. Lectura" = Esperado."Orden Mín. Lectura") and (Actual."Concepto Mín. Lectura" = Esperado."Concepto Mín. Lectura"), 'Debe conservar el extremo lector y su desempate por código.');
        Assert((Actual."Aportes en Conflicto" = Esperado."Aportes en Conflicto") and (Actual."Códigos en Conflicto" = Esperado."Códigos en Conflicto"), 'Debe conservar los aportes posteriores y su detalle.');
        Assert((Actual.Conflicto = Esperado.Conflicto) and (Actual."Requiere Contexto" = Esperado."Requiere Contexto"), 'El alcance de las alertas debe ser idéntico al global.');
        Assert((Actual."Orden Sugerido" = Esperado."Orden Sugerido") and (Actual.Observación = Esperado.Observación), 'El análisis de una fila debe conservar la sugerencia y explicación completas.');
    end;

    local procedure AssertPropuestaIgualANuevaInstancia(var Gestor: Codeunit "Corrección Orden Acum."; Acumulador: Code[20]; FechaRef: Date; Tipo: Code[20]; Convenio: Code[20]; Esperada: Boolean; ConceptoEsperado: Code[20])
    var
        NuevoGestor: Codeunit "Corrección Orden Acum.";
        Origen: Record "Concepto Liquidación";
        NuevoOrigen: Record "Concepto Liquidación";
        Orden: Integer;
        NuevoOrden: Integer;
        Fecha: Date;
        NuevaFecha: Date;
        Explicacion: Text;
        NuevaExplicacion: Text;
        Disponible: Boolean;
        NuevaDisponible: Boolean;
    begin
        Disponible := Gestor.Proponer(Acumulador, FechaRef, Tipo, Convenio, 'GENERAL', Origen, Orden, Fecha, Explicacion);
        NuevaDisponible := NuevoGestor.Proponer(Acumulador, FechaRef, Tipo, Convenio, 'GENERAL', NuevoOrigen, NuevoOrden, NuevaFecha, NuevaExplicacion);
        Assert(Disponible = Esperada, StrSubstNo('Propuesta inesperada para %1/%2/%3/%4: %5', Acumulador, FechaRef, Tipo, Convenio, Explicacion));
        Assert(Disponible = NuevaDisponible, 'La instancia reutilizada debe resolver igual que una nueva para el mismo contexto.');
        Assert((Origen.Código = NuevoOrigen.Código) and (Origen."Vigencia Desde" = NuevoOrigen."Vigencia Desde") and (Origen.SystemRowVersion = NuevoOrigen.SystemRowVersion), 'La propuesta reutilizada debe conservar exactamente la versión física que devuelve una instancia nueva.');
        Assert((Orden = NuevoOrden) and (Fecha = NuevaFecha) and (Explicacion = NuevaExplicacion), 'La decisión, fecha y explicación deben coincidir al cambiar y recuperar el contexto.');
        Assert(Origen.Código = ConceptoEsperado, 'No debe arrastrarse el concepto elegido para otro acumulador o contexto.');
        if Disponible then
            Assert((Orden = 19) and (Fecha = FechaRef), 'El contexto que necesita corrección debe proponer el aporte19 en su fecha de referencia.')
        else
            Assert((Orden = 0) and (Fecha = 0D), 'Una consulta sin propuesta no debe exponer el orden ni la fecha de una consulta previa.');
    end;

    local procedure CrearCaso(var Acumulador: Code[20]; var Aportante: Code[20]; var Lector: Code[20]; OrdenLector: Integer)
    begin
        PrepararCatalogos();
        Acumulador := NuevoCodigo();
        Aportante := NuevoCodigo();
        Lector := NuevoCodigo();
        CrearConcepto(Acumulador, 0, '', true, false);
        CrearConcepto(Aportante, 30, '', false, false);
        CrearConcepto(Lector, OrdenLector, Acumulador, false, true);
        CrearFraccion(Aportante, Acumulador);
    end;

    local procedure PrepararCatalogos()
    var
        TipoAtributo: Record "Tipo Atributo Liq.";
        VariableSistema: Record "Variable Sistema Liq.";
        TipoLiq: Record "Tipo Liquidación";
    begin
        TipoAtributo.SetRange("Nombre Variable", 'CONVENIO');
        TipoAtributo.SetRange("Tipo Dato", TipoAtributo."Tipo Dato"::Lista);
        if not TipoAtributo.FindFirst() then begin
            TipoAtributo.Init();
            TipoAtributo.Código := 'TEST_CORR_CONVENIO';
            TipoAtributo."Nombre Variable" := 'CONVENIO';
            TipoAtributo."Tipo Dato" := TipoAtributo."Tipo Dato"::Lista;
            TipoAtributo.Insert(false);
        end;
        PrepararValorConvenio(TipoAtributo.Código, 'TEST_CORR_CCT');
        PrepararValorConvenio(TipoAtributo.Código, 'TEST_CORR_OTRO');
        PrepararMaestroConvenioContextoPrueba('TEST_CORR_CCT');
        PrepararMaestroConvenioContextoPrueba('TEST_CORR_OTRO');
        if not VariableSistema.Get('TIPO_LIQ') then begin
            VariableSistema.Init();
            VariableSistema."Nombre Variable" := 'TIPO_LIQ';
            VariableSistema."Cód. Cálculo" := 'TIPO_LIQ';
            VariableSistema.Insert(false);
        end;
        if not TipoLiq.Get('REGULAR') then begin
            TipoLiq.Init();
            TipoLiq.Código := 'REGULAR';
            TipoLiq.Orden := 900001;
            TipoLiq.Insert(false);
        end;
        if not TipoLiq.Get('LIQ_FINAL') then begin
            TipoLiq.Init();
            TipoLiq.Código := 'LIQ_FINAL';
            TipoLiq.Orden := 900002;
            TipoLiq.Insert(false);
        end;
    end;

    local procedure PrepararMaestroConvenioContextoPrueba(Codigo: Code[20])
    var
        Convenio: Record "Convenio Colectivo";
        Categoria: Record "Categoría CCT";
        Categorias: List of [Code[20]];
        CodCategoria: Code[20];
    begin
        if not Convenio.Get(Codigo) then begin
            Convenio.Código := Codigo;
            Convenio.Descripción := 'Convenio sintético de control de orden';
            Convenio.Insert(false);
        end;
        Categorias.Add('GENERAL');
        Categorias.Add('CAT_A');
        Categorias.Add('CAT_B');
        foreach CodCategoria in Categorias do
            if not Categoria.Get(Codigo, CodCategoria) then begin
                Categoria.Init();
                Categoria."Cód. Convenio" := Codigo;
                Categoria.Código := CodCategoria;
                Categoria.Descripción := 'Categoría sintética de control de orden';
                Categoria.Insert(false);
            end;
    end;

    local procedure PrepararValorConvenio(Tipo: Code[20]; Codigo: Code[20])
    var
        ValorAtributo: Record "Valor Atributo Liq.";
    begin
        if ValorAtributo.Get(Tipo, '', Codigo) then
            exit;
        ValorAtributo."Cód. Tipo Atributo" := Tipo;
        ValorAtributo.Código := Codigo;
        ValorAtributo."Valor Numérico" := 1;
        ValorAtributo.Insert(false);
    end;

    local procedure CrearConcepto(Codigo: Code[20]; Orden: Integer; Formula: Text; EsAcumulador: Boolean; EsVirtual: Boolean)
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Concepto.Código := Codigo;
        Concepto."Vigencia Desde" := DMY2Date(1, 1, 2020);
        Concepto.Descripción := 'Prueba de corrección de orden';
        Concepto.Activo := true;
        Concepto."Es Acumulador" := EsAcumulador;
        if EsVirtual then
            Concepto."Tipo Concepto" := Concepto."Tipo Concepto"::Informativo;
        Concepto."Orden Cálculo" := Orden;
        Concepto."Fórmula Orden Cálculo" := Format(Orden, 0, 9);
        Concepto.Fórmula := CopyStr(Formula, 1, MaxStrLen(Concepto.Fórmula));
        Concepto.Insert(true);
    end;

    local procedure CrearFraccion(Concepto: Code[20]; Acumulador: Code[20])
    var
        Fraccion: Record "Fracción Acumulador";
    begin
        Fraccion."Cód. Concepto" := Concepto;
        Fraccion."Vigencia Desde" := DMY2Date(1, 1, 2020);
        Fraccion."Cód. Acumulador" := Acumulador;
        Fraccion.Porcentaje := 100;
        Fraccion.Insert(false);
    end;

    local procedure CrearRecibo(Concepto: Record "Concepto Liquidación"; Fecha: Date; var Cabecera: Record "Liquidación"; var Linea: Record "Línea Liquidación")
    begin
        Cabecera.Init();
        Cabecera."No." := NuevoCodigo();
        Cabecera."Fecha Liquidación" := Fecha;
        Cabecera.Estado := Cabecera.Estado::Calculada;
        Cabecera."Total Haberes" := 99.875;
        Cabecera."Total Descuentos" := 9.875;
        Cabecera."Neto a Pagar" := 90;
        Cabecera.Insert(false);
        Cabecera.Get(Cabecera."No.");
        Linea.Init();
        Linea."No. Liquidación" := Cabecera."No.";
        Linea."Cód. Concepto" := Concepto.Código;
        Linea."Vigencia Concepto" := Concepto."Vigencia Desde";
        Linea."Fecha Liquidación" := Fecha;
        Linea.Estado := Linea.Estado::Calculada;
        Linea.Importe := 99.875;
        Linea.Cantidad := 2.5;
        Linea."Orden Cálculo" := Concepto."Orden Cálculo";
        Linea."Fórmula Aplicada" := Concepto.Fórmula;
        Linea.Insert(false);
        Linea.Get(Linea."No. Liquidación", Linea."No. Línea");
    end;

    local procedure NuevoCodigo(): Code[20]
    begin
        exit(CopyStr('T' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
    end;

    local procedure Assert(Condicion: Boolean; Mensaje: Text)
    begin
        if not Condicion then
            Error(Mensaje);
    end;
}
