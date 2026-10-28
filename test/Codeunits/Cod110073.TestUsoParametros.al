namespace UAS.Payroll;

codeunit 110073 "Test Uso Parametros"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure LiberaHuerfanaAunqueNoHayaRegistroAnterior()
    var
        Version: Record "Parámetro Vigente";
        Gestion: Codeunit "Gestión Liquidación";
    begin
        CrearVersion(Version);
        Gestion.ReconciliarEnUso(Version."No. Empleado");
        VerificarMarca(Version, false);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ConservaVersionCompartidaPorLiquidacionActiva()
    var
        Version: Record "Parámetro Vigente";
        Gestion: Codeunit "Gestión Liquidación";
        Numero: Code[20];
    begin
        CrearVersion(Version);
        Numero := CrearLiquidacion(Version, "Estado Liq."::Aprobada);
        CrearUso(Version, Numero);
        Gestion.ReconciliarEnUso(Version."No. Empleado");
        VerificarMarca(Version, true);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure RegistroDeBorradorNoBloquea()
    var
        Version: Record "Parámetro Vigente";
        Gestion: Codeunit "Gestión Liquidación";
        Numero: Code[20];
    begin
        CrearVersion(Version);
        Numero := CrearLiquidacion(Version, "Estado Liq."::Borrador);
        CrearUso(Version, Numero);
        Gestion.ReconciliarEnUso(Version."No. Empleado");
        VerificarMarca(Version, false);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ConservaTrazaHistoricaSinRegistro()
    var
        Version: Record "Parámetro Vigente";
        Gestion: Codeunit "Gestión Liquidación";
        Numero: Code[20];
        Cabecera: Record "Liquidación";
        Linea: Record "Línea Liquidación";
        Uso: Record "Uso Parámetro Liq.";
    begin
        CrearVersion(Version);
        Numero := CrearLiquidacion(Version, "Estado Liq."::Contabilizada);
        CrearLinea(Version, Numero, 'VAR:' + Version."Cód. Parámetro Base" + '|OTRO');
        Cabecera.Get(Numero);
        Linea.Get(Numero, 1);
        Uso.SetRange("No. Liquidación", Numero);
        if (Cabecera.Estado <> Cabecera.Estado::Contabilizada) or
           (Linea."No. Empleado" <> Version."No. Empleado") or not Uso.IsEmpty()
        then
            Error('La fixture histórica requiere cabecera contabilizada, mismo empleado y ausencia de registro de uso.');
        if not Gestion.TieneUsoActivo(Version) then
            Error('No reconoce la traza sintética previa a reconciliar. Cabecera %1; estado %2; empleado línea %3; variable %4; traza %5.',
                Numero, Cabecera.Estado, Linea."No. Empleado", Version."Cód. Parámetro Base", Linea."Fuente Parámetros");
        Gestion.ReconciliarEnUso(Version."No. Empleado");
        VerificarMarca(Version, true);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure NoConfundePrefijosEnTrazas()
    var
        Version: Record "Parámetro Vigente";
        Gestion: Codeunit "Gestión Liquidación";
        Numero: Code[20];
    begin
        CrearVersion(Version);
        Numero := CrearLiquidacion(Version, "Estado Liq."::Calculada);
        CrearLinea(Version, Numero, 'VAR:' + Version."Cód. Parámetro Base" + '_OTRA');
        Gestion.ReconciliarEnUso(Version."No. Empleado");
        VerificarMarca(Version, false);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure LiberaVersionViejaYRespetaEmpleadoAjeno()
    var
        Vieja: Record "Parámetro Vigente";
        Nueva: Record "Parámetro Vigente";
        Ajena: Record "Parámetro Vigente";
        Gestion: Codeunit "Gestión Liquidación";
        Numero: Code[20];
    begin
        CrearVersion(Vieja);
        Nueva := Vieja;
        Nueva."Vigencia Desde" += 1;
        Nueva.Insert(false);
        CrearVersion(Ajena);
        Numero := CrearLiquidacion(Nueva, "Estado Liq."::Calculada);
        CrearUso(Nueva, Numero);
        CrearLinea(Nueva, Numero, 'VAR:' + Nueva."Cód. Parámetro Base");
        Gestion.ReconciliarEnUso(Vieja."No. Empleado");
        VerificarMarca(Vieja, false);
        VerificarMarca(Nueva, true);
        VerificarMarca(Ajena, true);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ReconciliacionEquivaleAlOraculoPorAlcanceYEstado()
    var
        Calculada: Record "Parámetro Vigente";
        AprobadaGeneral: Record "Parámetro Vigente";
        Contabilizada: Record "Parámetro Vigente";
        Borrador: Record "Parámetro Vigente";
        Huerfana: Record "Parámetro Vigente";
        GeneralSinUso: Record "Parámetro Vigente";
        Ajena: Record "Parámetro Vigente";
        Desmarcada: Record "Parámetro Vigente";
        Candidatas: Record "Parámetro Vigente" temporary;
        Empleado: Code[20];
    begin
        Empleado := NuevoCodigo();
        CrearVersionEnAlcance(Calculada, Empleado);
        CrearUso(Calculada, CrearLiquidacion(Calculada, "Estado Liq."::Calculada));
        AgregarCandidata(Candidatas, Calculada);
        CrearVersionEnAlcance(AprobadaGeneral, '');
        CrearUso(AprobadaGeneral, CrearLiquidacion(Calculada, "Estado Liq."::Aprobada));
        AgregarCandidata(Candidatas, AprobadaGeneral);
        CrearVersionEnAlcance(Contabilizada, Empleado);
        CrearUso(Contabilizada, CrearLiquidacion(Contabilizada, "Estado Liq."::Contabilizada));
        AgregarCandidata(Candidatas, Contabilizada);
        CrearVersionEnAlcance(Borrador, Empleado);
        CrearUso(Borrador, CrearLiquidacion(Borrador, "Estado Liq."::Borrador));
        AgregarCandidata(Candidatas, Borrador);
        CrearVersionEnAlcance(Huerfana, Empleado);
        CrearUso(Huerfana, NuevoCodigo());
        AgregarCandidata(Candidatas, Huerfana);
        CrearVersionEnAlcance(GeneralSinUso, '');
        AgregarCandidata(Candidatas, GeneralSinUso);
        CrearVersion(Ajena);
        AgregarCandidata(Candidatas, Ajena);
        CrearVersionEnAlcance(Desmarcada, Empleado);
        Desmarcada."En Uso" := false;
        Desmarcada.Modify(false);
        CrearUso(Desmarcada, CrearLiquidacion(Desmarcada, "Estado Liq."::Calculada));
        AgregarCandidata(Candidatas, Desmarcada);

        ReconciliarYCompararConOraculo(Candidatas, Empleado);
        VerificarMarca(Calculada, true);
        VerificarMarca(AprobadaGeneral, true);
        VerificarMarca(Contabilizada, true);
        VerificarMarca(Borrador, false);
        VerificarMarca(Huerfana, false);
        VerificarMarca(GeneralSinUso, false);
        VerificarMarca(Ajena, true);
        VerificarMarca(Desmarcada, false);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure UsoExigeBaseClaveYVigenciaExactas()
    var
        Exacta: Record "Parámetro Vigente";
        OtraBase: Record "Parámetro Vigente";
        OtraClave: Record "Parámetro Vigente";
        OtraVigencia: Record "Parámetro Vigente";
        Candidatas: Record "Parámetro Vigente" temporary;
    begin
        CrearVersion(Exacta);
        CrearUso(Exacta, CrearLiquidacion(Exacta, "Estado Liq."::Calculada));
        AgregarCandidata(Candidatas, Exacta);
        OtraBase := Exacta;
        OtraBase."Cód. Parámetro Base" := NuevoCodigo();
        OtraBase.Insert(false);
        AgregarCandidata(Candidatas, OtraBase);
        OtraClave := Exacta;
        OtraClave."Cód. Parámetro" := NuevoCodigo();
        OtraClave.Insert(false);
        AgregarCandidata(Candidatas, OtraClave);
        OtraVigencia := Exacta;
        OtraVigencia."Vigencia Desde" += 1;
        OtraVigencia.Insert(false);
        AgregarCandidata(Candidatas, OtraVigencia);

        ReconciliarYCompararConOraculo(Candidatas, Exacta."No. Empleado");
        VerificarMarca(Exacta, true);
        VerificarMarca(OtraBase, false);
        VerificarMarca(OtraClave, false);
        VerificarMarca(OtraVigencia, false);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure HistoricoRespetaNombreActualBaseYSufijoMoneda()
    var
        Actual: Record "Parámetro Vigente";
        ActualMoneda: Record "Parámetro Vigente";
        BaseAnterior: Record "Parámetro Vigente";
        BaseMoneda: Record "Parámetro Vigente";
        OtroEmpleado: Record "Parámetro Vigente";
        Candidatas: Record "Parámetro Vigente" temporary;
        Empleado: Code[20];
        Nombre: Code[30];
        Numero: Code[20];
        Linea: Record "Línea Liquidación";
    begin
        Empleado := NuevoCodigo();
        CrearVersionEnAlcance(Actual, Empleado);
        Nombre := RenombrarVariable(Actual);
        CrearLinea(Actual, CrearLiquidacion(Actual, "Estado Liq."::Calculada), 'VAR:' + Nombre);
        AgregarCandidata(Candidatas, Actual);
        CrearVersionEnAlcance(ActualMoneda, Empleado);
        Nombre := RenombrarVariable(ActualMoneda);
        CrearLinea(ActualMoneda, CrearLiquidacion(ActualMoneda, "Estado Liq."::Aprobada), 'VAR:' + Nombre + '_ESFCY');
        AgregarCandidata(Candidatas, ActualMoneda);
        CrearVersionEnAlcance(BaseAnterior, Empleado);
        Nombre := RenombrarVariable(BaseAnterior);
        CrearLinea(BaseAnterior, CrearLiquidacion(BaseAnterior, "Estado Liq."::Contabilizada), 'VAR:' + BaseAnterior."Cód. Parámetro Base");
        AgregarCandidata(Candidatas, BaseAnterior);
        CrearVersionEnAlcance(BaseMoneda, Empleado);
        Nombre := RenombrarVariable(BaseMoneda);
        CrearLinea(BaseMoneda, CrearLiquidacion(BaseMoneda, "Estado Liq."::Calculada), 'VAR:' + BaseMoneda."Cód. Parámetro Base" + '_ESFCY');
        AgregarCandidata(Candidatas, BaseMoneda);
        CrearVersionEnAlcance(OtroEmpleado, Empleado);
        Numero := CrearLiquidacion(OtroEmpleado, "Estado Liq."::Calculada);
        CrearLinea(OtroEmpleado, Numero, 'VAR:' + OtroEmpleado."Cód. Parámetro Base");
        Linea.Get(Numero, 1);
        Linea."No. Empleado" := NuevoCodigo();
        Linea.Modify(false);
        AgregarCandidata(Candidatas, OtroEmpleado);

        ReconciliarYCompararConOraculo(Candidatas, Empleado);
        VerificarMarca(Actual, true);
        VerificarMarca(ActualMoneda, true);
        VerificarMarca(BaseAnterior, true);
        VerificarMarca(BaseMoneda, true);
        VerificarMarca(OtroEmpleado, false);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure UnRegistroAjenoExcluyeTrazaSinModificarla()
    var
        Version: Record "Parámetro Vigente";
        OtraVersion: Record "Parámetro Vigente";
        Candidatas: Record "Parámetro Vigente" temporary;
        Linea: Record "Línea Liquidación";
        Uso: Record "Uso Parámetro Liq.";
        Numero: Code[20];
        Traza: Text;
    begin
        CrearVersion(Version);
        CrearVersion(OtraVersion);
        Numero := CrearLiquidacion(Version, "Estado Liq."::Calculada);
        Traza := 'VAR:' + Version."Cód. Parámetro Base" + '|VAR:' + Version."Cód. Parámetro Base" + '_ESFCY|OTRO';
        CrearLinea(Version, Numero, Traza);
        // Cualquier registro vuelve exacta la auditoría del documento: no se completa con la traza.
        CrearUso(OtraVersion, Numero);
        AgregarCandidata(Candidatas, Version);

        ReconciliarYCompararConOraculo(Candidatas, Version."No. Empleado");
        VerificarMarca(Version, false);
        Linea.Get(Numero, 1);
        if Linea."Fuente Parámetros" <> Traza then
            Error('La reconciliación modificó la traza histórica.');
        Uso.SetRange("No. Liquidación", Numero);
        if Uso.Count() <> 1 then
            Error('La reconciliación agregó o quitó registros de uso.');
        Uso.Get(Numero, OtraVersion."Cód. Parámetro Base");
        if (Uso."Cód. Parámetro Base" <> OtraVersion."Cód. Parámetro Base") or
           (Uso."Cód. Parámetro" <> OtraVersion."Cód. Parámetro") or
           (Uso."Vigencia Desde" <> OtraVersion."Vigencia Desde")
        then
            Error('La reconciliación modificó la versión registrada.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure HistoricoUsaEstadoDeCabeceraEIgnoraHuerfanas()
    var
        Activa: Record "Parámetro Vigente";
        Borrador: Record "Parámetro Vigente";
        Huerfana: Record "Parámetro Vigente";
        Candidatas: Record "Parámetro Vigente" temporary;
        Cabecera: Record "Liquidación";
        Linea: Record "Línea Liquidación";
        Empleado: Code[20];
        Numero: Code[20];
    begin
        Empleado := NuevoCodigo();
        CrearVersionEnAlcance(Activa, Empleado);
        Numero := CrearLiquidacion(Activa, "Estado Liq."::Calculada);
        CrearLinea(Activa, Numero, 'VAR:' + Activa."Cód. Parámetro Base");
        Linea.Get(Numero, 1);
        Linea.Estado := Linea.Estado::Borrador;
        Linea.Modify(false);
        // La pertenencia histórica se decide por la línea, no por el empleado de la cabecera.
        Cabecera.Get(Numero);
        Cabecera."No. Empleado" := NuevoCodigo();
        Cabecera.Modify(false);
        AgregarCandidata(Candidatas, Activa);
        CrearVersionEnAlcance(Borrador, Empleado);
        Numero := CrearLiquidacion(Borrador, "Estado Liq."::Borrador);
        CrearLinea(Borrador, Numero, 'VAR:' + Borrador."Cód. Parámetro Base");
        Linea.Get(Numero, 1);
        Linea.Estado := Linea.Estado::Calculada;
        Linea.Modify(false);
        AgregarCandidata(Candidatas, Borrador);
        CrearVersionEnAlcance(Huerfana, Empleado);
        Numero := CrearLiquidacion(Huerfana, "Estado Liq."::Calculada);
        CrearLinea(Huerfana, Numero, 'VAR:' + Huerfana."Cód. Parámetro Base");
        Cabecera.Get(Numero);
        Cabecera.Delete(false);
        AgregarCandidata(Candidatas, Huerfana);

        ReconciliarYCompararConOraculo(Candidatas, Empleado);
        VerificarMarca(Activa, true);
        VerificarMarca(Borrador, false);
        VerificarMarca(Huerfana, false);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ReconciliacionNoReutilizaEstadosEntreLlamadas()
    var
        Version: Record "Parámetro Vigente";
        Gestion: Codeunit "Gestión Liquidación";
        Cabecera: Record "Liquidación";
        Numero: Code[20];
    begin
        CrearVersion(Version);
        Numero := CrearLiquidacion(Version, "Estado Liq."::Borrador);
        CrearUso(Version, Numero);
        Gestion.ReconciliarEnUso(Version."No. Empleado");
        VerificarMarca(Version, false);

        Cabecera.Get(Numero);
        Cabecera.Estado := Cabecera.Estado::Calculada;
        Cabecera.Modify(false);
        Version.Get(Version."Cód. Parámetro Base", Version."Cód. Parámetro", Version."Vigencia Desde");
        Version."En Uso" := true;
        Version.Modify(false);
        // La misma instancia debe ver la nueva activación, como sucede al calcular otro documento.
        if not Gestion.TieneUsoActivo(Version) then Error('El oráculo no reconoció la nueva cabecera activa.');
        Gestion.ReconciliarEnUso(Version."No. Empleado");
        VerificarMarca(Version, true);

        Cabecera.Estado := Cabecera.Estado::Borrador;
        Cabecera.Modify(false);
        Gestion.ReconciliarEnUso(Version."No. Empleado");
        VerificarMarca(Version, false);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ReconciliacionAdmiteVariosUsosDeLaMismaVersion()
    var
        Version: Record "Parámetro Vigente";
        Candidatas: Record "Parámetro Vigente" temporary;
        Uso: Record "Uso Parámetro Liq.";
        Cabecera: Record "Liquidación";
        Numero: Code[20];
    begin
        CrearVersion(Version);
        Numero := CrearLiquidacion(Version, "Estado Liq."::Calculada);
        CrearUso(Version, Numero);
        Uso.Get(Numero, Version."Cód. Parámetro Base");
        Uso."Nombre Variable" := NuevoCodigo();
        Uso.Insert(false);
        CrearUso(Version, CrearLiquidacion(Version, "Estado Liq."::Aprobada));
        Numero := CrearLiquidacion(Version, "Estado Liq."::Contabilizada);
        CrearUso(Version, Numero);
        // El registro exacto protege la versión aunque la cabecera pertenezca a otro empleado.
        Cabecera.Get(Numero);
        Cabecera."No. Empleado" := NuevoCodigo();
        Cabecera.Modify(false);
        AgregarCandidata(Candidatas, Version);

        ReconciliarYCompararConOraculo(Candidatas, Version."No. Empleado");
        VerificarMarca(Version, true);
        Uso.Reset();
        Uso.SetRange("Cód. Parámetro Base", Version."Cód. Parámetro Base");
        if Uso.Count() <> 4 then
            Error('La reconciliación no debe alterar los cuatro usos originales.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure HistoricoComparteAliasSinMezclarAlcance()
    var
        Primera: Record "Parámetro Vigente";
        OtraVigencia: Record "Parámetro Vigente";
        OtraBase: Record "Parámetro Vigente";
        General: Record "Parámetro Vigente";
        Personal: Record "Parámetro Vigente";
        Candidatas: Record "Parámetro Vigente" temporary;
        Parametro: Record "Parámetro";
        Linea: Record "Línea Liquidación";
        Empleado: Code[20];
        Nombre: Code[30];
        Numero: Code[20];
    begin
        Empleado := NuevoCodigo();
        CrearVersionEnAlcance(Primera, Empleado);
        Nombre := RenombrarVariable(Primera);
        CrearLinea(Primera, CrearLiquidacion(Primera, "Estado Liq."::Calculada), 'VAR:' + Nombre);
        AgregarCandidata(Candidatas, Primera);
        // Una traza sin auditoría exacta conserva todas las vigencias que comparten el nombre.
        OtraVigencia := Primera;
        OtraVigencia."Vigencia Desde" := DMY2Date(1, 2, 2026);
        OtraVigencia.Insert(false);
        AgregarCandidata(Candidatas, OtraVigencia);
        CrearVersionEnAlcance(OtraBase, Empleado);
        Parametro.Get(OtraBase."Cód. Parámetro Base");
        Parametro."Nombre Variable" := Nombre;
        Parametro.Modify(false);
        AgregarCandidata(Candidatas, OtraBase);

        CrearVersionEnAlcance(General, '');
        Nombre := RenombrarVariable(General);
        Numero := CrearLiquidacion(General, "Estado Liq."::Aprobada);
        CrearLinea(General, Numero, 'VAR:' + Nombre + '_ESFCY');
        Linea.Get(Numero, 1);
        Linea."No. Empleado" := NuevoCodigo();
        Linea.Modify(false);
        AgregarCandidata(Candidatas, General);
        CrearVersionEnAlcance(Personal, Empleado);
        Parametro.Get(Personal."Cód. Parámetro Base");
        Parametro."Nombre Variable" := Nombre;
        Parametro.Modify(false);
        AgregarCandidata(Candidatas, Personal);

        ReconciliarYCompararConOraculo(Candidatas, Empleado);
        VerificarMarca(Primera, true);
        VerificarMarca(OtraVigencia, true);
        VerificarMarca(OtraBase, true);
        VerificarMarca(General, true);
        VerificarMarca(Personal, false);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure HistoricoNoReutilizaEstadosEntreLlamadas()
    var
        Version: Record "Parámetro Vigente";
        Gestion: Codeunit "Gestión Liquidación";
        Cabecera: Record "Liquidación";
        Numero: Code[20];
    begin
        CrearVersion(Version);
        Numero := CrearLiquidacion(Version, "Estado Liq."::Borrador);
        CrearLinea(Version, Numero, 'VAR:' + Version."Cód. Parámetro Base");
        Gestion.ReconciliarEnUso(Version."No. Empleado");
        VerificarMarca(Version, false);

        Cabecera.Get(Numero);
        Cabecera.Estado := Cabecera.Estado::Calculada;
        Cabecera.Modify(false);
        Version.Get(Version."Cód. Parámetro Base", Version."Cód. Parámetro", Version."Vigencia Desde");
        Version."En Uso" := true;
        Version.Modify(false);
        if not Gestion.TieneUsoActivo(Version) then Error('El oráculo no reconoció la nueva traza activa.');
        Gestion.ReconciliarEnUso(Version."No. Empleado");
        VerificarMarca(Version, true);

        Cabecera.Estado := Cabecera.Estado::Borrador;
        Cabecera.Modify(false);
        Gestion.ReconciliarEnUso(Version."No. Empleado");
        VerificarMarca(Version, false);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PrecargaActivaEquivaleAlOraculoYVersionExacta()
    begin
        ProbarPrecargaActiva("Estado Liq."::Calculada);
        ProbarPrecargaActiva("Estado Liq."::Aprobada);
        ProbarPrecargaActiva("Estado Liq."::Contabilizada);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PrecargaInvalidaConservaConsultaGeneral()
    begin
        ProbarDocumentoSinPrecarga(1); // Cabecera en borrador.
        ProbarDocumentoSinPrecarga(2); // Uso huérfano, sin cabecera.
        ProbarDocumentoSinPrecarga(3); // Cabecera activa de otro empleado.
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PrecargaNoReutilizaEstadoUsosNiDocumento()
    var
        Primera: Record "Parámetro Vigente";
        Segunda: Record "Parámetro Vigente";
        Candidatas: Record "Parámetro Vigente" temporary;
        Cabecera: Record "Liquidación";
        Uso: Record "Uso Parámetro Liq.";
        Gestion: Codeunit "Gestión Liquidación";
        Actual: Code[20];
        Siguiente: Code[20];
    begin
        CrearVersion(Primera);
        Segunda := Primera;
        Segunda."Vigencia Desde" += 1;
        Segunda.Insert(false);
        AgregarCandidata(Candidatas, Primera);
        AgregarCandidata(Candidatas, Segunda);
        Actual := CrearLiquidacion(Primera, "Estado Liq."::Borrador);
        CrearUso(Primera, Actual);

        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Primera."No. Empleado", Actual);
        VerificarMarca(Primera, false);
        VerificarMarca(Segunda, false);

        Cabecera.Get(Actual);
        Cabecera.Estado := Cabecera.Estado::Calculada;
        Cabecera.Modify(false);
        MarcarParaReconciliar(Primera);
        MarcarParaReconciliar(Segunda);
        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Primera."No. Empleado", Actual);
        VerificarMarca(Primera, true);
        VerificarMarca(Segunda, false);

        Uso.Get(Actual, Primera."Cód. Parámetro Base");
        Uso."Vigencia Desde" := Segunda."Vigencia Desde";
        Uso.Modify(false);
        MarcarParaReconciliar(Primera);
        MarcarParaReconciliar(Segunda);
        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Primera."No. Empleado", Actual);
        VerificarMarca(Primera, false);
        VerificarMarca(Segunda, true);

        Uso.Delete(false);
        MarcarParaReconciliar(Primera);
        MarcarParaReconciliar(Segunda);
        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Primera."No. Empleado", Actual);
        VerificarMarca(Primera, false);
        VerificarMarca(Segunda, false);

        Siguiente := CrearLiquidacion(Primera, "Estado Liq."::Aprobada);
        CrearUso(Primera, Siguiente);
        MarcarParaReconciliar(Primera);
        MarcarParaReconciliar(Segunda);
        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Primera."No. Empleado", Siguiente);
        VerificarMarca(Primera, true);
        VerificarMarca(Segunda, false);

        Cabecera.Get(Siguiente);
        Cabecera.Estado := Cabecera.Estado::Borrador;
        Cabecera.Modify(false);
        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Primera."No. Empleado", Siguiente);
        VerificarMarca(Primera, false);
        VerificarMarca(Segunda, false);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PrecargaConservaHistoricoUsosYTrazas()
    var
        Exacta: Record "Parámetro Vigente";
        Historica: Record "Parámetro Vigente";
        Excluida: Record "Parámetro Vigente";
        OtroDocumento: Record "Parámetro Vigente";
        Candidatas: Record "Parámetro Vigente" temporary;
        Linea: Record "Línea Liquidación";
        Uso: Record "Uso Parámetro Liq.";
        Gestion: Codeunit "Gestión Liquidación";
        Actual: Code[20];
        Anterior: Code[20];
        Otro: Code[20];
        TrazaActual: Text;
        TrazaAnterior: Text;
    begin
        CrearVersion(Exacta);
        CrearVersionEnAlcance(Historica, Exacta."No. Empleado");
        CrearVersionEnAlcance(Excluida, Exacta."No. Empleado");
        CrearVersionEnAlcance(OtroDocumento, Exacta."No. Empleado");
        Actual := CrearLiquidacion(Exacta, "Estado Liq."::Calculada);
        CrearUso(Exacta, Actual);
        TrazaActual := 'VAR:' + Excluida."Cód. Parámetro Base";
        CrearLinea(Excluida, Actual, TrazaActual);
        Anterior := CrearLiquidacion(Historica, "Estado Liq."::Contabilizada);
        TrazaAnterior := 'VAR:' + RenombrarVariable(Historica) + '_ESFCY';
        CrearLinea(Historica, Anterior, TrazaAnterior);
        Otro := CrearLiquidacion(OtroDocumento, "Estado Liq."::Aprobada);
        CrearUso(OtroDocumento, Otro);
        AgregarCandidata(Candidatas, Exacta);
        AgregarCandidata(Candidatas, Historica);
        AgregarCandidata(Candidatas, Excluida);
        AgregarCandidata(Candidatas, OtroDocumento);

        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Exacta."No. Empleado", Actual);
        VerificarMarca(Exacta, true);
        VerificarMarca(Historica, true);
        VerificarMarca(Excluida, false); // Cualquier registro de uso excluye el fallback de esa cabecera.
        VerificarMarca(OtroDocumento, true);
        VerificarUsoSinCambios(Exacta, Actual);
        VerificarUsoSinCambios(OtroDocumento, Otro);
        Uso.SetRange("No. Liquidación", Anterior);
        if not Uso.IsEmpty() then Error('La conciliación creó usos para una traza histórica.');
        Linea.Get(Actual, 1);
        if Linea."Fuente Parámetros" <> TrazaActual then Error('La conciliación modificó la traza actual.');
        Linea.Get(Anterior, 1);
        if Linea."Fuente Parámetros" <> TrazaAnterior then Error('La conciliación modificó la traza histórica.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure TestigosNoMezclanComponentesDeVersiones()
    var
        Primera: Record "Parámetro Vigente";
        Segunda: Record "Parámetro Vigente";
        Compartida: Record "Parámetro Vigente";
        CrucePrimero: Record "Parámetro Vigente";
        CruceSegundo: Record "Parámetro Vigente";
        OtraVigencia: Record "Parámetro Vigente";
        Candidatas: Record "Parámetro Vigente" temporary;
        Gestion: Codeunit "Gestión Liquidación";
        DocumentoPrimero: Code[20];
        DocumentoSegundo: Code[20];
        DocumentoBorrador: Code[20];
        TrazaPrimera: Text;
        TrazaSegunda: Text;
        TrazaBorrador: Text;
    begin
        CrearVersion(Primera);
        Segunda := Primera;
        Segunda."Cód. Parámetro Base" := NuevoCodigo();
        Segunda."Cód. Parámetro" := NuevoCodigo();
        Segunda."Vigencia Desde" += 1;
        Segunda.Insert(false);
        CrearVersionEnAlcance(Compartida, Primera."No. Empleado");
        CrucePrimero := Primera;
        CrucePrimero."Cód. Parámetro" := Segunda."Cód. Parámetro";
        CrucePrimero."Vigencia Desde" := Segunda."Vigencia Desde";
        CrucePrimero.Insert(false);
        CruceSegundo := Segunda;
        CruceSegundo."Cód. Parámetro" := Primera."Cód. Parámetro";
        CruceSegundo."Vigencia Desde" := Primera."Vigencia Desde";
        CruceSegundo.Insert(false);
        OtraVigencia := Primera;
        OtraVigencia."Vigencia Desde" := Segunda."Vigencia Desde";
        OtraVigencia.Insert(false);
        DocumentoPrimero := CrearLiquidacion(Primera, "Estado Liq."::Calculada);
        DocumentoSegundo := CrearLiquidacion(Segunda, "Estado Liq."::Aprobada);
        DocumentoBorrador := CrearLiquidacion(OtraVigencia, "Estado Liq."::Borrador);
        CrearUso(Primera, DocumentoPrimero);
        CrearUso(Compartida, DocumentoPrimero);
        CrearUso(Segunda, DocumentoSegundo);
        CrearUso(OtraVigencia, DocumentoBorrador);
        TrazaPrimera := 'VAR:' + Primera."Cód. Parámetro Base" + '|VAR:' + Compartida."Cód. Parámetro Base";
        TrazaSegunda := 'VAR:' + Segunda."Cód. Parámetro Base";
        TrazaBorrador := 'VAR:' + OtraVigencia."Cód. Parámetro Base" + '_ESFCY';
        CrearLinea(Primera, DocumentoPrimero, TrazaPrimera);
        CrearLinea(Segunda, DocumentoSegundo, TrazaSegunda);
        CrearLinea(OtraVigencia, DocumentoBorrador, TrazaBorrador);
        AgregarCandidata(Candidatas, Primera);
        AgregarCandidata(Candidatas, Compartida);
        AgregarCandidata(Candidatas, Segunda);
        AgregarCandidata(Candidatas, CrucePrimero);
        AgregarCandidata(Candidatas, CruceSegundo);
        AgregarCandidata(Candidatas, OtraVigencia);

        // El actual está en Borrador: dos bases comparten otro testigo y una tercera tiene otro.
        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Primera."No. Empleado", DocumentoBorrador);
        VerificarMarca(Primera, true);
        VerificarMarca(Compartida, true);
        VerificarMarca(Segunda, true);
        VerificarMarca(CrucePrimero, false);
        VerificarMarca(CruceSegundo, false);
        VerificarMarca(OtraVigencia, false);
        VerificarDosUsosSinCambios(Primera, Compartida, DocumentoPrimero);
        VerificarUsoSinCambios(Segunda, DocumentoSegundo);
        VerificarUsoSinCambios(OtraVigencia, DocumentoBorrador);
        VerificarTrazaSinCambios(DocumentoPrimero, TrazaPrimera);
        VerificarTrazaSinCambios(DocumentoSegundo, TrazaSegunda);
        VerificarTrazaSinCambios(DocumentoBorrador, TrazaBorrador);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure TestigosConservanUsoDeOtroEmpleado()
    var
        Personal: Record "Parámetro Vigente";
        General: Record "Parámetro Vigente";
        GeneralSinUso: Record "Parámetro Vigente";
        Ajena: Record "Parámetro Vigente";
        Candidatas: Record "Parámetro Vigente" temporary;
        Gestion: Codeunit "Gestión Liquidación";
        DocumentoPersonal: Code[20];
        DocumentoGeneral: Code[20];
        TrazaPersonal: Text;
        TrazaGeneral: Text;
    begin
        CrearVersion(Personal);
        CrearVersionEnAlcance(General, '');
        CrearVersionEnAlcance(GeneralSinUso, '');
        CrearVersion(Ajena);
        // El empleado de la cabecera no limita el consumo exacto de una versión candidata.
        DocumentoPersonal := CrearLiquidacion(Ajena, "Estado Liq."::Calculada);
        DocumentoGeneral := CrearLiquidacion(Ajena, "Estado Liq."::Contabilizada);
        CrearUso(Personal, DocumentoPersonal);
        CrearUso(General, DocumentoGeneral);
        TrazaPersonal := 'VAR:' + Personal."Cód. Parámetro Base";
        TrazaGeneral := 'VAR:' + General."Cód. Parámetro Base" + '_ESFCY';
        CrearLinea(Personal, DocumentoPersonal, TrazaPersonal);
        CrearLinea(General, DocumentoGeneral, TrazaGeneral);
        AgregarCandidata(Candidatas, Personal);
        AgregarCandidata(Candidatas, General);
        AgregarCandidata(Candidatas, GeneralSinUso);
        AgregarCandidata(Candidatas, Ajena);

        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Personal."No. Empleado", '');
        VerificarMarca(Personal, true);
        VerificarMarca(General, true);
        VerificarMarca(GeneralSinUso, false);
        VerificarMarca(Ajena, true); // Fuera del alcance, aunque no tenga consumo propio.
        VerificarUsoSinCambios(Personal, DocumentoPersonal);
        VerificarUsoSinCambios(General, DocumentoGeneral);
        VerificarTrazaSinCambios(DocumentoPersonal, TrazaPersonal);
        VerificarTrazaSinCambios(DocumentoGeneral, TrazaGeneral);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure TestigosSinEmpleadoSoloGenerales()
    var
        General: Record "Parámetro Vigente";
        Historica: Record "Parámetro Vigente";
        SinUso: Record "Parámetro Vigente";
        Personal: Record "Parámetro Vigente";
        Desmarcada: Record "Parámetro Vigente";
        Candidatas: Record "Parámetro Vigente" temporary;
        Gestion: Codeunit "Gestión Liquidación";
        Uso: Record "Uso Parámetro Liq.";
        Documento: Code[20];
        DocumentoHistorico: Code[20];
        Traza: Text;
        TrazaHistorica: Text;
    begin
        CrearVersionEnAlcance(General, '');
        CrearVersionEnAlcance(Historica, '');
        CrearVersionEnAlcance(SinUso, '');
        CrearVersion(Personal);
        CrearVersionEnAlcance(Desmarcada, Personal."No. Empleado");
        Desmarcada."En Uso" := false;
        Desmarcada.Modify(false);
        Documento := CrearLiquidacion(Personal, "Estado Liq."::Aprobada);
        CrearUso(General, Documento);
        Traza := 'VAR:' + General."Cód. Parámetro Base";
        CrearLinea(General, Documento, Traza);
        DocumentoHistorico := CrearLiquidacion(Personal, "Estado Liq."::Contabilizada);
        TrazaHistorica := 'VAR:' + RenombrarVariable(Historica) + '_ESFCY';
        CrearLinea(Historica, DocumentoHistorico, TrazaHistorica);
        AgregarCandidata(Candidatas, General);
        AgregarCandidata(Candidatas, Historica);
        AgregarCandidata(Candidatas, SinUso);
        AgregarCandidata(Candidatas, Personal);
        AgregarCandidata(Candidatas, Desmarcada);

        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, '', '');
        VerificarMarca(General, true);
        VerificarMarca(Historica, true);
        VerificarMarca(SinUso, false);
        VerificarMarca(Personal, true);
        VerificarMarca(Desmarcada, false);
        VerificarUsoSinCambios(General, Documento);
        Uso.SetRange("No. Liquidación", DocumentoHistorico);
        if not Uso.IsEmpty() then Error('La conciliación creó un registro para el consumo histórico general.');
        VerificarTrazaSinCambios(Documento, Traza);
        VerificarTrazaSinCambios(DocumentoHistorico, TrazaHistorica);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure TestigosRenuevanEntreEmpleadosYLlamadas()
    var
        Primera: Record "Parámetro Vigente";
        Segunda: Record "Parámetro Vigente";
        Candidatas: Record "Parámetro Vigente" temporary;
        Gestion: Codeunit "Gestión Liquidación";
        Cabecera: Record "Liquidación";
        Uso: Record "Uso Parámetro Liq.";
        DocumentoPrimero: Code[20];
        DocumentoSegundo: Code[20];
        DocumentoNuevo: Code[20];
        TrazaPrimera: Text;
        TrazaSegunda: Text;
    begin
        CrearVersion(Primera);
        CrearVersion(Segunda);
        DocumentoPrimero := CrearLiquidacion(Primera, "Estado Liq."::Calculada);
        DocumentoSegundo := CrearLiquidacion(Segunda, "Estado Liq."::Borrador);
        CrearUso(Primera, DocumentoPrimero);
        CrearUso(Segunda, DocumentoSegundo);
        TrazaPrimera := 'VAR:' + Primera."Cód. Parámetro Base";
        TrazaSegunda := 'VAR:' + Segunda."Cód. Parámetro Base";
        CrearLinea(Primera, DocumentoPrimero, TrazaPrimera);
        CrearLinea(Segunda, DocumentoSegundo, TrazaSegunda);
        AgregarCandidata(Candidatas, Primera);
        AgregarCandidata(Candidatas, Segunda);

        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Primera."No. Empleado", '');
        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Segunda."No. Empleado", '');
        VerificarMarca(Primera, true);
        VerificarMarca(Segunda, false);
        // Esta llamada no tiene candidatas de la fixture; no debe conservar filtros/respuestas.
        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, '', '');
        VerificarUsoSinCambios(Primera, DocumentoPrimero);
        VerificarUsoSinCambios(Segunda, DocumentoSegundo);
        VerificarTrazaSinCambios(DocumentoPrimero, TrazaPrimera);
        VerificarTrazaSinCambios(DocumentoSegundo, TrazaSegunda);

        Cabecera.Get(DocumentoPrimero);
        Cabecera.Estado := Cabecera.Estado::Borrador;
        Cabecera.Modify(false);
        Cabecera.Get(DocumentoSegundo);
        Cabecera.Estado := Cabecera.Estado::Aprobada;
        Cabecera.Modify(false);
        MarcarParaReconciliar(Segunda);
        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Segunda."No. Empleado", '');
        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Primera."No. Empleado", '');
        VerificarMarca(Primera, false);
        VerificarMarca(Segunda, true);
        VerificarUsoSinCambios(Primera, DocumentoPrimero);
        VerificarUsoSinCambios(Segunda, DocumentoSegundo);

        Uso.Get(DocumentoSegundo, Segunda."Cód. Parámetro Base");
        Uso.Delete(false);
        // Sin registros, la traza anterior pasa a ser histórica y sigue protegiendo la versión.
        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Segunda."No. Empleado", '');
        VerificarMarca(Segunda, true);
        Cabecera.Get(DocumentoSegundo);
        Cabecera.Estado := Cabecera.Estado::Borrador;
        Cabecera.Modify(false);
        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Segunda."No. Empleado", '');
        VerificarMarca(Segunda, false);
        DocumentoNuevo := CrearLiquidacion(Primera, "Estado Liq."::Contabilizada);
        CrearUso(Segunda, DocumentoNuevo);
        CrearLinea(Segunda, DocumentoNuevo, TrazaSegunda);
        MarcarParaReconciliar(Segunda);
        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Segunda."No. Empleado", '');
        VerificarMarca(Segunda, true);
        VerificarUsoSinCambios(Primera, DocumentoPrimero);
        VerificarUsoSinCambios(Segunda, DocumentoNuevo);
        Uso.Reset();
        Uso.SetRange("No. Liquidación", DocumentoSegundo);
        if not Uso.IsEmpty() then Error('La conciliación repuso un registro de uso retirado por la fixture.');
        VerificarTrazaSinCambios(DocumentoPrimero, TrazaPrimera);
        VerificarTrazaSinCambios(DocumentoSegundo, TrazaSegunda);
        VerificarTrazaSinCambios(DocumentoNuevo, TrazaSegunda);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PendientesConservanVigenciasYAliasDeMismaBase()
    var
        Primera: Record "Parámetro Vigente";
        Segunda: Record "Parámetro Vigente";
        OtraClave: Record "Parámetro Vigente";
        SinConsumo: Record "Parámetro Vigente";
        Candidatas: Record "Parámetro Vigente" temporary;
        UsosEsperados: Record "Uso Parámetro Liq." temporary;
        Gestion: Codeunit "Gestión Liquidación";
        Documento: Code[20];
        Traza: Text;
    begin
        CrearVersion(Primera);
        Segunda := Primera;
        Segunda."Vigencia Desde" += 1;
        Segunda.Insert(false);
        OtraClave := Primera;
        OtraClave."Cód. Parámetro" += '-B';
        OtraClave.Insert(false);
        SinConsumo := Primera;
        SinConsumo."Vigencia Desde" += 2;
        SinConsumo.Insert(false);
        Documento := CrearLiquidacion(Primera, "Estado Liq."::Calculada);
        CrearUso(Primera, Documento);
        // Documento+nombre es la PK del uso: una base puede acreditar varias triples distintas.
        CrearUsoConAlias(Segunda, Documento, NuevoCodigo());
        CrearUsoConAlias(OtraClave, Documento, NuevoCodigo());
        CrearUsoConAlias(Primera, Documento, NuevoCodigo());
        Traza := 'VAR:' + Primera."Cód. Parámetro Base" + '|OTRO';
        CrearLinea(Primera, Documento, Traza);
        CapturarUsosEsperados(UsosEsperados, Documento);
        AgregarCandidata(Candidatas, Primera);
        AgregarCandidata(Candidatas, Segunda);
        AgregarCandidata(Candidatas, OtraClave);
        AgregarCandidata(Candidatas, SinConsumo);

        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Primera."No. Empleado", '');
        VerificarMarca(Primera, true);
        VerificarMarca(Segunda, true);
        VerificarMarca(OtraClave, true);
        VerificarMarca(SinConsumo, false);
        VerificarUsosEsperados(UsosEsperados);
        VerificarTrazaSinCambios(Documento, Traza);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure UltimaPendienteConservaConsumoExacto()
    begin
        ProbarUltimaPendiente(1);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure UltimaPendienteConservaAusenciaYHistorico()
    begin
        ProbarUltimaPendiente(2);
        ProbarUltimaPendiente(3);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure BaseSinAporteSigueConsultandoCadaVersion()
    var
        Primera: Record "Parámetro Vigente";
        Segunda: Record "Parámetro Vigente";
        Tercera: Record "Parámetro Vigente";
        SinUso: Record "Parámetro Vigente";
        Candidatas: Record "Parámetro Vigente" temporary;
        UsosEsperados: Record "Uso Parámetro Liq." temporary;
        Gestion: Codeunit "Gestión Liquidación";
        PrimerTestigo: Code[20];
        SegundoTestigo: Code[20];
        Traza: Text;
    begin
        CrearVersion(Primera);
        Segunda := Primera;
        Segunda."Vigencia Desde" += 1;
        Segunda.Insert(false);
        Tercera := Primera;
        Tercera."Vigencia Desde" += 2;
        Tercera.Insert(false);
        SinUso := Primera;
        SinUso."Vigencia Desde" += 3;
        SinUso.Insert(false);
        PrimerTestigo := CrearLiquidacion(Primera, "Estado Liq."::Calculada);
        CrearUso(Primera, PrimerTestigo);
        CrearUsoConAlias(Primera, PrimerTestigo, NuevoCodigo());
        SegundoTestigo := CrearLiquidacion(Segunda, "Estado Liq."::Contabilizada);
        CrearUso(Segunda, SegundoTestigo);
        CrearUsoConAlias(Tercera, SegundoTestigo, NuevoCodigo());
        Traza := 'VAR:' + Primera."Cód. Parámetro Base";
        CrearLinea(Primera, PrimerTestigo, Traza);
        CrearLinea(Segunda, SegundoTestigo, Traza);
        CapturarUsosEsperados(UsosEsperados, PrimerTestigo);
        CapturarUsosEsperados(UsosEsperados, SegundoTestigo);
        AgregarCandidata(Candidatas, Primera);
        AgregarCandidata(Candidatas, Segunda);
        AgregarCandidata(Candidatas, Tercera);
        AgregarCandidata(Candidatas, SinUso);

        // El primer testigo no aporta ninguna de las tres vigencias todavía pendientes.
        // Omitir otras precargas de esa base nunca puede omitir sus comprobaciones exactas.
        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Primera."No. Empleado", '');
        VerificarMarca(Primera, true);
        VerificarMarca(Segunda, true);
        VerificarMarca(Tercera, true);
        VerificarMarca(SinUso, false);
        VerificarUsosEsperados(UsosEsperados);
        VerificarTrazaSinCambios(PrimerTestigo, Traza);
        VerificarTrazaSinCambios(SegundoTestigo, Traza);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure OtraBaseConservaPendientesDeOtroEmpleado()
    var
        Primera: Record "Parámetro Vigente";
        OtraBase: Record "Parámetro Vigente";
        OtraVigencia: Record "Parámetro Vigente";
        GeneralSinUso: Record "Parámetro Vigente";
        Ajena: Record "Parámetro Vigente";
        Param: Record "Parámetro";
        Candidatas: Record "Parámetro Vigente" temporary;
        UsosEsperados: Record "Uso Parámetro Liq." temporary;
        Gestion: Codeunit "Gestión Liquidación";
        PrimerTestigo: Code[20];
        SegundoTestigo: Code[20];
        TrazaPrimera: Text;
        TrazaSegunda: Text;
    begin
        CrearVersion(Primera);
        OtraBase := Primera;
        // NuevoCodigo termina en un dígito hexadecimal: Z garantiza la segunda base en la PK.
        OtraBase."Cód. Parámetro Base" := CopyStr(Primera."Cód. Parámetro Base", 1, 19) + 'Z';
        Param.Código := OtraBase."Cód. Parámetro Base";
        Param."Nombre Variable" := Param.Código;
        Param.Insert(false);
        OtraBase.Insert(false);
        OtraVigencia := OtraBase;
        OtraVigencia."Vigencia Desde" += 1;
        OtraVigencia.Insert(false);
        GeneralSinUso := OtraBase;
        GeneralSinUso."Vigencia Desde" += 2;
        GeneralSinUso."No. Empleado" := '';
        GeneralSinUso.Insert(false);
        CrearVersion(Ajena);
        PrimerTestigo := CrearLiquidacion(Primera, "Estado Liq."::Calculada);
        CrearUso(Primera, PrimerTestigo);
        SegundoTestigo := CrearLiquidacion(Ajena, "Estado Liq."::Aprobada);
        CrearUso(OtraBase, SegundoTestigo);
        CrearUsoConAlias(OtraVigencia, SegundoTestigo, NuevoCodigo());
        TrazaPrimera := 'VAR:' + Primera."Cód. Parámetro Base";
        TrazaSegunda := 'VAR:' + OtraBase."Cód. Parámetro Base" + '_ESFCY';
        CrearLinea(Primera, PrimerTestigo, TrazaPrimera);
        CrearLinea(OtraBase, SegundoTestigo, TrazaSegunda);
        CapturarUsosEsperados(UsosEsperados, PrimerTestigo);
        CapturarUsosEsperados(UsosEsperados, SegundoTestigo);
        AgregarCandidata(Candidatas, Primera);
        AgregarCandidata(Candidatas, OtraBase);
        AgregarCandidata(Candidatas, OtraVigencia);
        AgregarCandidata(Candidatas, GeneralSinUso);
        AgregarCandidata(Candidatas, Ajena);

        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Primera."No. Empleado", '');
        VerificarMarca(Primera, true);
        VerificarMarca(OtraBase, true);
        VerificarMarca(OtraVigencia, true);
        VerificarMarca(GeneralSinUso, false);
        VerificarMarca(Ajena, true);
        VerificarUsosEsperados(UsosEsperados);
        VerificarTrazaSinCambios(PrimerTestigo, TrazaPrimera);
        VerificarTrazaSinCambios(SegundoTestigo, TrazaSegunda);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AcumCCTPonderaHistoricosYRegistraVigencias()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Eval: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Fuente: Code[30];
        Parametro: Code[20];
        Cantidad: Code[30];
        Actual: Code[20];
        Enero: Code[20];
        Febrero: Code[20];
        Valor: Decimal;
        Uso: Record "Uso Parámetro Liq.";
        Version: Record "Parámetro Vigente";
        Personal: Record "Parámetro Vigente";
        LogAntes: Text;
    begin
        CrearHistoricosCCT(Contexto, Fuente, Parametro, Cantidad, Actual, Enero, Febrero);
        Ctx.Add('MARCA_ACTUAL', 123);
        Eval.Init(Ctx, DMY2Date(31, 3, 2026));
        Eval.SetContextoLiquidacion(Contexto);
        if not Eval.TryEvalFormula(FormulaAcumCCT(Fuente, Parametro, Cantidad, 30), Valor) then
            Error('No se pudo acumular el CCT histórico: %1.', GetLastErrorText());
        // Enero100USD*1100*3/30 + febrero200USD*1300*6/30. El precio personal999
        // debe ignorarse; usar precio/TC de la última cabecera para ambas también daría mal.
        VerificarImporteHist(63000, Valor);
        LogAntes := Eval.GetParamLog();
        if not LogAntes.Contains('ACUMCCT:') then Error('Falta la referencia histórica en el log del evaluador.');
        Contexto.MarkEnUso(LogAntes);
        Uso.SetRange("No. Liquidación", Actual);
        Uso.SetRange("Cód. Parámetro Base", Parametro);
        if Uso.Count() <> 2 then
            Error('Debe registrarse cada vigencia histórica desde la instancia enlazada.');
        Uso.SetRange("Vigencia Desde", DMY2Date(1, 1, 2026));
        if Uso.Count() <> 1 then Error('Falta el registro de la vigencia de enero.');
        Uso.SetRange("Vigencia Desde", DMY2Date(1, 2, 2026));
        if Uso.Count() <> 1 then Error('Falta el registro de la vigencia de febrero.');
        Version.SetRange("Cód. Parámetro Base", Parametro);
        Version.SetRange("No. Empleado", '');
        Version.SetFilter("Cód. Categoría", '<>%1', '');
        if Version.FindSet() then repeat if not Version."En Uso" then Error('La vigencia histórica usada quedó sin proteger.'); until Version.Next() = 0;
        Personal.SetRange("Cód. Parámetro Base", Parametro);
        Personal.SetFilter("No. Empleado", '<>%1', '');
        Personal.FindFirst();
        if Personal."En Uso" then Error('No debe protegerse un precio personal que no se usó.');
        if Eval.GetParamLog() <> LogAntes then Error('MarkEnUso no debe alterar el log del evaluador.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AcumCCTNoModificaSeleccionActual()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Fuente: Record "Fuente Datos Liquidación";
        Nombre: Code[30];
        Parametro: Code[20];
        Cantidad: Code[30];
        Actual: Code[20];
        Enero: Code[20];
        Febrero: Code[20];
        Valor: Decimal;
    begin
        CrearHistoricosCCT(Contexto, Nombre, Parametro, Cantidad, Actual, Enero, Febrero);
        Valor := Contexto.AcumularParametroCCT(Nombre, Parametro, Cantidad, 30);
        Fuente.Get(Nombre);
        VerificarImporteHist(2, Contexto.ResolveFuente(Fuente));
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AcumCCTExigeCantidadHistorica()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Resumen: Record "Resumen Variable Liq.";
        Fuente: Code[30];
        Parametro: Code[20];
        Cantidad: Code[30];
        Actual: Code[20];
        Enero: Code[20];
        Febrero: Code[20];
        Valor: Decimal;
    begin
        CrearHistoricosCCT(Contexto, Fuente, Parametro, Cantidad, Actual, Enero, Febrero);
        Resumen.Get(Enero, Cantidad); Resumen.Delete(false);
        asserterror Valor := Contexto.AcumularParametroCCT(Fuente, Parametro, Cantidad, 30);
        if not GetLastErrorText().Contains('variable histórica') then Error('Se esperaba un diagnóstico por cantidad histórica faltante.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AcumCCTExigeDivisorPositivo()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Fuente: Code[30];
        Parametro: Code[20];
        Cantidad: Code[30];
        Actual: Code[20];
        Enero: Code[20];
        Febrero: Code[20];
        Valor: Decimal;
    begin
        CrearHistoricosCCT(Contexto, Fuente, Parametro, Cantidad, Actual, Enero, Febrero);
        asserterror Valor := Contexto.AcumularParametroCCT(Fuente, Parametro, Cantidad, 0);
        if not GetLastErrorText().Contains('divisor positivo') then Error('Se esperaba un divisor positivo.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AcumCCTExigeTCHistorico()
    var
        Contexto: Codeunit "Contexto Liquidación";
        Resumen: Record "Resumen Variable Liq.";
        Fuente: Code[30];
        Parametro: Code[20];
        Cantidad: Code[30];
        Actual: Code[20];
        Enero: Code[20];
        Febrero: Code[20];
        Valor: Decimal;
    begin
        // Un asserterror revierte la transacción de la fixture: cada diagnóstico usa la propia.
        CrearHistoricosCCT(Contexto, Fuente, Parametro, Cantidad, Actual, Enero, Febrero);
        Resumen.Get(Enero, 'TC_HIST_TEST'); Resumen.Delete(false);
        asserterror Valor := Contexto.AcumularParametroCCT(Fuente, Parametro, Cantidad, 30);
        if not GetLastErrorText().Contains('tipo de cambio histórico') then Error('Se esperaba un diagnóstico por TC histórico faltante.');
    end;

    [Test]
    procedure AcumCCTHistoricoUsaMemoSinConfiguracionActual()
    var
        Eval: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Valor: Decimal;
    begin
        Eval.Init(Ctx, DMY2Date(31, 3, 2026));
        Eval.UsarDatosGuardados();
        Eval.SembrarAcumParametroCCTGuardado('FUENTE_RETIRADA', 'PARAM_RETIRADO', 'CANT_RETIRADA', 30, 976350);
        if not Eval.TryEvalFormula(FormulaAcumCCT('FUENTE_RETIRADA', 'PARAM_RETIRADO', 'CANT_RETIRADA', 30), Valor) then
            Error('El memo histórico debe evitar toda consulta de configuración actual: %1.', GetLastErrorText());
        VerificarImporteHist(976350, Valor);
        if not Eval.GetParamLog().Contains('ACUMCCT:FUENTE_RETIRADA~PARAM_RETIRADO~CANT_RETIRADA~30~976350') then
            Error('El log debe conservar la clave completa y el resultado histórico.');
    end;

    [Test]
    procedure AcumCCTHistoricoSinMemoNoRecalcula()
    var
        Eval: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Valor: Decimal;
    begin
        Eval.Init(Ctx, DMY2Date(31, 3, 2026));
        Eval.UsarDatosGuardados();
        if Eval.TryEvalFormula(FormulaAcumCCT('FUENTE_RETIRADA', 'PARAM_RETIRADO', 'CANT_RETIRADA', 30), Valor) then
            Error('No debe recalcularse un histórico sin resultado guardado.');
        if not GetLastErrorText().Contains('resultado guardado') then Error('Falta diagnóstico de memo histórico.');
    end;

    local procedure CrearHistoricosCCT(var Contexto: Codeunit "Contexto Liquidación"; var NombreFuente: Code[30]; var CodigoParametro: Code[20]; var Cantidad: Code[30]; var Actual: Code[20]; var Enero: Code[20]; var Febrero: Code[20])
    var
        Param: Record "Parámetro";
        Fuente: Record "Fuente Datos Liquidación";
        Variable: Record "Variable Sistema Liq.";
        Liq: Record "Liquidación";
        Empleado: Code[20];
        Proyecto: Code[20];
    begin
        Empleado := NuevoCodigo(); Proyecto := NuevoCodigo();
        CodigoParametro := NuevoCodigo(); NombreFuente := NuevoCodigo(); Cantidad := NuevoCodigo();
        Param.Código := CodigoParametro; Param."Nombre Variable" := CodigoParametro; Param.Insert(false);
        Variable."Nombre Variable" := Cantidad; Variable."Cód. Cálculo" := 'DIAS_MAREA'; Variable.Insert(false);
        CrearPrecioHist(CodigoParametro, Empleado, 999, DMY2Date(1, 1, 2026), true);
        CrearPrecioHist(CodigoParametro, '', 100, DMY2Date(1, 1, 2026), false);
        CrearPrecioHist(CodigoParametro, '', 200, DMY2Date(1, 2, 2026), false);
        Fuente."Nombre Variable" := NombreFuente; Fuente."Id. Tabla" := Database::"Liquidación";
        Fuente."Función Agregado" := Fuente."Función Agregado"::COUNT; Fuente.Activo := true; Fuente.Insert(false);
        FiltroHist(NombreFuente, Liq.FieldNo("No. Empleado"), '{EMP_NO}');
        FiltroHist(NombreFuente, Liq.FieldNo("No. Proyecto"), '{JOB_NO}');
        FiltroHist(NombreFuente, Liq.FieldNo("Fecha Liquidación"), '<{FECHA_REF}');
        FiltroHist(NombreFuente, Liq.FieldNo(Estado), '<>0');
        Enero := CabeceraHist(Empleado, Proyecto, DMY2Date(31, 1, 2026), "Estado Liq."::Calculada);
        Febrero := CabeceraHist(Empleado, Proyecto, DMY2Date(28, 2, 2026), "Estado Liq."::Calculada);
        ResumenHist(Enero, Cantidad, 3); ResumenHist(Enero, 'TC_HIST_TEST', 1100);
        ResumenHist(Febrero, Cantidad, 6); ResumenHist(Febrero, 'TC_HIST_TEST', 1300);
        Actual := CabeceraHist(Empleado, Proyecto, DMY2Date(31, 3, 2026), "Estado Liq."::Borrador);
        Contexto.Init(Empleado, Proyecto, '', DMY2Date(31, 3, 2026), 'CCT_TEST', 'CAT_TEST', Actual, 'CIERRE_MAREA', DMY2Date(1, 3, 2026));
    end;

    local procedure CrearPrecioHist(Base: Code[20]; Empleado: Code[20]; Precio: Decimal; Desde: Date; Personal: Boolean)
    var
        Version: Record "Parámetro Vigente";
    begin
        Version."Cód. Parámetro Base" := Base; Version."Vigencia Desde" := Desde;
        Version.Valor := Precio; Version.Moneda := 'USD'; Version."Cód. Variable TC" := 'TC_HIST_TEST';
        if Personal then begin Version."No. Empleado" := Empleado; Version."Cód. Parámetro" := Base + '_' + Empleado; end
        else begin Version."Cód. Convenio" := 'CCT_TEST'; Version."Cód. Categoría" := 'CAT_TEST'; Version."Cód. Parámetro" := Base + '_CCT_TEST_CAT_TEST'; end;
        Version.Insert(false);
    end;

    local procedure CabeceraHist(Empleado: Code[20]; Proyecto: Code[20]; Fecha: Date; Estado: Enum "Estado Liq."): Code[20]
    var
        Liq: Record "Liquidación";
    begin
        Liq."No." := NuevoCodigo(); Liq."No. Empleado" := Empleado; Liq."No. Proyecto" := Proyecto;
        Liq."Cód. Convenio" := 'CCT_TEST'; Liq."Cód. Categoría" := 'CAT_TEST'; Liq."Fecha Liquidación" := Fecha;
        Liq.Estado := Estado; Liq.Insert(false); exit(Liq."No.");
    end;

    local procedure ResumenHist(Documento: Code[20]; Nombre: Code[30]; Valor: Decimal)
    var Resumen: Record "Resumen Variable Liq.";
    begin
        Resumen."No. Liquidación" := Documento; Resumen."Nombre Variable" := Nombre; Resumen.Valor := Valor; Resumen.Insert(false);
    end;

    local procedure FiltroHist(Fuente: Code[30]; Campo: Integer; Valor: Text)
    var Filtro: Record "Filtro Fuente Datos Liq.";
    begin
        Filtro."Nombre Variable" := Fuente; Filtro."No. Campo" := Campo; Filtro."Filtro Valor" := CopyStr(Valor, 1, MaxStrLen(Filtro."Filtro Valor")); Filtro.Insert(false);
    end;

    local procedure FormulaAcumCCT(Fuente: Code[30]; Parametro: Code[20]; Cantidad: Code[30]; Divisor: Decimal): Text
    begin
        exit('ACUM_PARAM_CCT(''' + Fuente + ''',''' + Parametro + ''',''' + Cantidad + ''',' + Format(Divisor, 0, 9) + ')');
    end;

    local procedure VerificarImporteHist(Esperado: Decimal; Actual: Decimal)
    begin
        if Abs(Esperado - Actual) > 0.00001 then Error('Importe histórico esperado %1; obtenido %2.', Esperado, Actual);
    end;

    local procedure CrearVersionEnAlcance(var Version: Record "Parámetro Vigente"; Empleado: Code[20])
    begin
        CrearVersion(Version);
        Version."No. Empleado" := Empleado;
        Version.Modify(false);
    end;

    local procedure AgregarCandidata(var Candidatas: Record "Parámetro Vigente" temporary; Version: Record "Parámetro Vigente")
    begin
        Candidatas := Version;
        Candidatas.Insert(false);
    end;

    local procedure ReconciliarYCompararConOraculo(var Candidatas: Record "Parámetro Vigente" temporary; Empleado: Code[20])
    var
        Gestion: Codeunit "Gestión Liquidación";
    begin
        // Sólo la fixture se usa para las aserciones: la compañía puede tener otros parámetros.
        // Se captura la respuesta anterior antes de cambiar las marcas de la tabla real.
        if Candidatas.FindSet() then
            repeat
                if Candidatas."En Uso" then
                    if (Candidatas."No. Empleado" = '') or (Candidatas."No. Empleado" = Empleado) then begin
                        Candidatas."En Uso" := Gestion.TieneUsoActivo(Candidatas);
                        Candidatas.Modify(false);
                    end;
            until Candidatas.Next() = 0;
        Gestion.ReconciliarEnUso(Empleado);
        if Candidatas.FindSet() then
            repeat
                VerificarMarca(Candidatas, Candidatas."En Uso");
            until Candidatas.Next() = 0;
    end;

    local procedure ProbarPrecargaActiva(Estado: Enum "Estado Liq.")
    var
        Exacta: Record "Parámetro Vigente";
        General: Record "Parámetro Vigente";
        OtraBase: Record "Parámetro Vigente";
        OtraClave: Record "Parámetro Vigente";
        OtraVigencia: Record "Parámetro Vigente";
        Ajena: Record "Parámetro Vigente";
        Desmarcada: Record "Parámetro Vigente";
        Candidatas: Record "Parámetro Vigente" temporary;
        Uso: Record "Uso Parámetro Liq.";
        Gestion: Codeunit "Gestión Liquidación";
        Actual: Code[20];
        AliasDuplicado: Code[30];
    begin
        CrearVersion(Exacta);
        CrearVersionEnAlcance(General, '');
        CrearVersion(Ajena);
        CrearVersionEnAlcance(Desmarcada, Exacta."No. Empleado");
        Desmarcada."En Uso" := false;
        Desmarcada.Modify(false);
        OtraBase := Exacta;
        OtraBase."Cód. Parámetro Base" := NuevoCodigo();
        OtraBase.Insert(false);
        OtraClave := Exacta;
        OtraClave."Cód. Parámetro" := NuevoCodigo();
        OtraClave.Insert(false);
        OtraVigencia := Exacta;
        OtraVigencia."Vigencia Desde" += 1;
        OtraVigencia.Insert(false);
        Actual := CrearLiquidacion(Exacta, Estado);
        CrearUso(Exacta, Actual);
        CrearUso(General, Actual);
        CrearUso(Desmarcada, Actual);
        Uso.Get(Actual, Exacta."Cód. Parámetro Base");
        AliasDuplicado := NuevoCodigo();
        Uso."Nombre Variable" := AliasDuplicado;
        Uso.Insert(false);
        AgregarCandidata(Candidatas, Exacta);
        AgregarCandidata(Candidatas, General);
        AgregarCandidata(Candidatas, OtraBase);
        AgregarCandidata(Candidatas, OtraClave);
        AgregarCandidata(Candidatas, OtraVigencia);
        AgregarCandidata(Candidatas, Ajena);
        AgregarCandidata(Candidatas, Desmarcada);

        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Exacta."No. Empleado", Actual);
        VerificarMarca(Exacta, true);
        VerificarMarca(General, true);
        VerificarMarca(OtraBase, false);
        VerificarMarca(OtraClave, false);
        VerificarMarca(OtraVigencia, false);
        VerificarMarca(Ajena, true);
        VerificarMarca(Desmarcada, false);
        Uso.SetRange("No. Liquidación", Actual);
        if Uso.Count() <> 4 then Error('La precarga modificó la cantidad de usos.');
        Uso.Get(Actual, AliasDuplicado);
        if (Uso."Cód. Parámetro Base" <> Exacta."Cód. Parámetro Base") or
           (Uso."Cód. Parámetro" <> Exacta."Cód. Parámetro") or
           (Uso."Vigencia Desde" <> Exacta."Vigencia Desde") then
            Error('La precarga modificó el uso duplicado de la versión.');
    end;

    local procedure ProbarDocumentoSinPrecarga(Caso: Integer)
    var
        ActualVersion: Record "Parámetro Vigente";
        OtraVersion: Record "Parámetro Vigente";
        SinUso: Record "Parámetro Vigente";
        Candidatas: Record "Parámetro Vigente" temporary;
        Cabecera: Record "Liquidación";
        Gestion: Codeunit "Gestión Liquidación";
        Actual: Code[20];
    begin
        CrearVersion(ActualVersion);
        CrearVersionEnAlcance(OtraVersion, ActualVersion."No. Empleado");
        CrearVersionEnAlcance(SinUso, ActualVersion."No. Empleado");
        case Caso of
            1:
                Actual := CrearLiquidacion(ActualVersion, "Estado Liq."::Borrador);
            2:
                Actual := NuevoCodigo();
            3:
                begin
                    Actual := CrearLiquidacion(ActualVersion, "Estado Liq."::Calculada);
                    Cabecera.Get(Actual);
                    Cabecera."No. Empleado" := NuevoCodigo();
                    Cabecera.Modify(false);
                end;
        end;
        CrearUso(ActualVersion, Actual);
        CrearUso(OtraVersion, CrearLiquidacion(OtraVersion, "Estado Liq."::Aprobada));
        AgregarCandidata(Candidatas, ActualVersion);
        AgregarCandidata(Candidatas, OtraVersion);
        AgregarCandidata(Candidatas, SinUso);

        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, ActualVersion."No. Empleado", Actual);
        // El fallback exacto anterior acepta cualquier cabecera activa, incluso de otro empleado.
        VerificarMarca(ActualVersion, Caso = 3);
        VerificarMarca(OtraVersion, true);
        VerificarMarca(SinUso, false);
        VerificarUsoSinCambios(ActualVersion, Actual);
    end;

    local procedure ReconciliarActualYCompararConOraculo(var Gestion: Codeunit "Gestión Liquidación"; var Candidatas: Record "Parámetro Vigente" temporary; Empleado: Code[20]; Actual: Code[20])
    var
        Version: Record "Parámetro Vigente";
    begin
        // Se relee la marca porque las pruebas reutilizan la misma instancia entre llamadas.
        // El oráculo se evalúa antes de conciliar y sólo se comparan las filas de la fixture.
        if Candidatas.FindSet() then
            repeat
                Version.Get(Candidatas."Cód. Parámetro Base", Candidatas."Cód. Parámetro", Candidatas."Vigencia Desde");
                Candidatas."En Uso" := Version."En Uso";
                if Version."En Uso" then
                    if (Version."No. Empleado" = '') or (Version."No. Empleado" = Empleado) then
                        Candidatas."En Uso" := Gestion.TieneUsoActivo(Version);
                Candidatas.Modify(false);
            until Candidatas.Next() = 0;
        Gestion.ReconciliarEnUso(Empleado, Actual);
        if Candidatas.FindSet() then
            repeat
                VerificarMarca(Candidatas, Candidatas."En Uso");
            until Candidatas.Next() = 0;
    end;

    local procedure MarcarParaReconciliar(var Version: Record "Parámetro Vigente")
    begin
        Version.Get(Version."Cód. Parámetro Base", Version."Cód. Parámetro", Version."Vigencia Desde");
        Version."En Uso" := true;
        Version.Modify(false);
    end;

    local procedure VerificarUsoSinCambios(Version: Record "Parámetro Vigente"; Documento: Code[20])
    var
        Uso: Record "Uso Parámetro Liq.";
    begin
        Uso.SetRange("No. Liquidación", Documento);
        if Uso.Count() <> 1 then Error('La conciliación cambió la cantidad de usos del documento.');
        Uso.Get(Documento, Version."Cód. Parámetro Base");
        if (Uso."Cód. Parámetro Base" <> Version."Cód. Parámetro Base") or
           (Uso."Cód. Parámetro" <> Version."Cód. Parámetro") or
           (Uso."Vigencia Desde" <> Version."Vigencia Desde") then
            Error('La conciliación cambió la versión del uso registrado.');
    end;

    local procedure VerificarDosUsosSinCambios(Primera: Record "Parámetro Vigente"; Segunda: Record "Parámetro Vigente"; Documento: Code[20])
    var
        Uso: Record "Uso Parámetro Liq.";
    begin
        Uso.SetRange("No. Liquidación", Documento);
        if Uso.Count() <> 2 then Error('La conciliación cambió los usos del testigo compartido.');
        Uso.Get(Documento, Primera."Cód. Parámetro Base");
        if (Uso."Cód. Parámetro Base" <> Primera."Cód. Parámetro Base") or
           (Uso."Cód. Parámetro" <> Primera."Cód. Parámetro") or
           (Uso."Vigencia Desde" <> Primera."Vigencia Desde") then
            Error('La conciliación modificó el primer uso del testigo compartido.');
        Uso.Get(Documento, Segunda."Cód. Parámetro Base");
        if (Uso."Cód. Parámetro Base" <> Segunda."Cód. Parámetro Base") or
           (Uso."Cód. Parámetro" <> Segunda."Cód. Parámetro") or
           (Uso."Vigencia Desde" <> Segunda."Vigencia Desde") then
            Error('La conciliación modificó el segundo uso del testigo compartido.');
    end;

    local procedure VerificarTrazaSinCambios(Documento: Code[20]; Esperada: Text)
    var
        Linea: Record "Línea Liquidación";
    begin
        Linea.SetRange("No. Liquidación", Documento);
        if Linea.Count() <> 1 then Error('La conciliación cambió las líneas de la fixture.');
        Linea.Get(Documento, 1);
        if Linea."Fuente Parámetros" <> Esperada then Error('La conciliación modificó la traza del documento.');
    end;

    local procedure ProbarUltimaPendiente(Caso: Integer)
    var
        Propia: Record "Parámetro Vigente";
        Ultima: Record "Parámetro Vigente";
        Candidatas: Record "Parámetro Vigente" temporary;
        UsosEsperados: Record "Uso Parámetro Liq." temporary;
        Uso: Record "Uso Parámetro Liq.";
        Gestion: Codeunit "Gestión Liquidación";
        Actual: Code[20];
        OtroDocumento: Code[20];
        TrazaPropia: Text;
        OtraTraza: Text;
    begin
        CrearVersion(Propia);
        Ultima := Propia;
        Ultima."Cód. Parámetro" += '-Z';
        Ultima.Insert(false);
        Actual := CrearLiquidacion(Propia, "Estado Liq."::Calculada);
        CrearUso(Propia, Actual);
        TrazaPropia := 'VAR:' + Propia."Cód. Parámetro Base";
        CrearLinea(Propia, Actual, TrazaPropia);
        CapturarUsosEsperados(UsosEsperados, Actual);
        case Caso of
            1:
                begin
                    OtroDocumento := CrearLiquidacion(Ultima, "Estado Liq."::Aprobada);
                    CrearUso(Ultima, OtroDocumento);
                    OtraTraza := 'VAR:' + Ultima."Cód. Parámetro Base";
                end;
            2:
                begin
                    OtroDocumento := CrearLiquidacion(Ultima, "Estado Liq."::Borrador);
                    CrearUso(Ultima, OtroDocumento);
                    OtraTraza := 'VAR:' + Ultima."Cód. Parámetro Base";
                end;
            3:
                begin
                    OtroDocumento := CrearLiquidacion(Ultima, "Estado Liq."::Contabilizada);
                    OtraTraza := 'VAR:' + RenombrarVariable(Ultima) + '_ESFCY';
                end;
        end;
        CrearLinea(Ultima, OtroDocumento, OtraTraza);
        CapturarUsosEsperados(UsosEsperados, OtroDocumento);
        AgregarCandidata(Candidatas, Propia);
        AgregarCandidata(Candidatas, Ultima);

        // Propia queda resuelta por la precarga. Ultima debe consultar exacto/histórico
        // aunque retirarla del conjunto pendiente deje cero candidatas por ayudar.
        ReconciliarActualYCompararConOraculo(Gestion, Candidatas, Propia."No. Empleado", Actual);
        VerificarMarca(Propia, true);
        VerificarMarca(Ultima, Caso <> 2);
        VerificarUsosEsperados(UsosEsperados);
        if Caso = 3 then begin
            Uso.SetRange("No. Liquidación", OtroDocumento);
            if not Uso.IsEmpty() then Error('La conciliación creó usos para la última candidata histórica.');
        end;
        VerificarTrazaSinCambios(Actual, TrazaPropia);
        VerificarTrazaSinCambios(OtroDocumento, OtraTraza);
    end;

    local procedure CrearUsoConAlias(Version: Record "Parámetro Vigente"; Documento: Code[20]; Nombre: Code[30])
    var
        Uso: Record "Uso Parámetro Liq.";
    begin
        Uso."No. Liquidación" := Documento;
        Uso."Nombre Variable" := Nombre;
        Uso."Cód. Parámetro Base" := Version."Cód. Parámetro Base";
        Uso."Cód. Parámetro" := Version."Cód. Parámetro";
        Uso."Vigencia Desde" := Version."Vigencia Desde";
        Uso.Insert(false);
    end;

    local procedure CapturarUsosEsperados(var Esperados: Record "Uso Parámetro Liq." temporary; Documento: Code[20])
    var
        Uso: Record "Uso Parámetro Liq.";
    begin
        Uso.SetRange("No. Liquidación", Documento);
        if Uso.FindSet() then
            repeat
                Esperados := Uso;
                Esperados.Insert(false);
            until Uso.Next() = 0;
    end;

    local procedure VerificarUsosEsperados(var Esperados: Record "Uso Parámetro Liq." temporary)
    var
        Actual: Record "Uso Parámetro Liq.";
        Conteo: Record "Uso Parámetro Liq." temporary;
        Documento: Code[20];
    begin
        Conteo.Copy(Esperados, true);
        if Esperados.FindSet() then
            repeat
                Actual.Get(Esperados."No. Liquidación", Esperados."Nombre Variable");
                if (Actual."Cód. Parámetro Base" <> Esperados."Cód. Parámetro Base") or
                   (Actual."Cód. Parámetro" <> Esperados."Cód. Parámetro") or
                   (Actual."Vigencia Desde" <> Esperados."Vigencia Desde") then
                    Error('La conciliación modificó una triple registrada bajo su alias.');
                if Documento <> Esperados."No. Liquidación" then begin
                    Documento := Esperados."No. Liquidación";
                    Actual.SetRange("No. Liquidación", Documento);
                    Conteo.SetRange("No. Liquidación", Documento);
                    if Actual.Count() <> Conteo.Count() then
                        Error('La conciliación agregó o quitó usos registrados del documento.');
                end;
            until Esperados.Next() = 0;
    end;

    local procedure RenombrarVariable(Version: Record "Parámetro Vigente"): Code[30]
    var
        Param: Record "Parámetro";
    begin
        Param.Get(Version."Cód. Parámetro Base");
        Param."Nombre Variable" := NuevoCodigo();
        Param.Modify(false);
        exit(Param."Nombre Variable");
    end;

    local procedure CrearVersion(var Version: Record "Parámetro Vigente")
    // Los datos sintéticos se revierten por AutoRollback y aislamiento del runner.
    var
        Param: Record "Parámetro";
    begin
        Param.Código := NuevoCodigo();
        Param."Nombre Variable" := Param.Código;
        Param.Insert(false);
        Version.Init();
        Version."Cód. Parámetro Base" := Param.Código;
        Version."Cód. Parámetro" := Param.Código;
        Version."Vigencia Desde" := DMY2Date(1, 1, 2026);
        Version."No. Empleado" := NuevoCodigo();
        Version."En Uso" := true;
        Version.Insert(false);
    end;

    local procedure CrearLiquidacion(Version: Record "Parámetro Vigente"; Estado: Enum "Estado Liq."): Code[20]
    var
        Liq: Record "Liquidación";
    begin
        Liq."No." := NuevoCodigo();
        Liq."No. Empleado" := Version."No. Empleado";
        Liq.Estado := Estado;
        Liq."Fecha Liquidación" := DMY2Date(31, 1, 2026);
        Liq.Insert(false);
        exit(Liq."No.");
    end;

    local procedure CrearUso(Version: Record "Parámetro Vigente"; Numero: Code[20])
    var
        Uso: Record "Uso Parámetro Liq.";
    begin
        Uso."No. Liquidación" := Numero;
        Uso."Nombre Variable" := Version."Cód. Parámetro Base";
        Uso."Cód. Parámetro Base" := Version."Cód. Parámetro Base";
        Uso."Cód. Parámetro" := Version."Cód. Parámetro";
        Uso."Vigencia Desde" := Version."Vigencia Desde";
        Uso.Insert(false);
    end;

    local procedure CrearLinea(Version: Record "Parámetro Vigente"; Numero: Code[20]; Traza: Text)
    var
        Linea: Record "Línea Liquidación";
        Cabecera: Record "Liquidación";
    begin
        Cabecera.Get(Numero);
        Linea."No. Liquidación" := Numero;
        Linea."No. Línea" := 1;
        Linea."No. Empleado" := Version."No. Empleado";
        Linea.Estado := Cabecera.Estado;
        Linea."Fecha Liquidación" := Cabecera."Fecha Liquidación";
        Linea."Fuente Parámetros" := CopyStr(Traza, 1, MaxStrLen(Linea."Fuente Parámetros"));
        Linea.Insert(false);
    end;

    local procedure VerificarMarca(Version: Record "Parámetro Vigente"; Esperada: Boolean)
    var
        Actual: Record "Parámetro Vigente";
    begin
        Actual.Get(Version."Cód. Parámetro Base", Version."Cód. Parámetro", Version."Vigencia Desde");
        if Actual."En Uso" <> Esperada then
            Error('Marca En Uso incorrecta: esperado %1.', Esperada);
    end;

    local procedure NuevoCodigo(): Code[20]
    begin
        exit(CopyStr('T' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
    end;
}
