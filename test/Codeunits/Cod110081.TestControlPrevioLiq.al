namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.HumanResources.Setup;
using Microsoft.Finance.Currency;
using Microsoft.Projects.Project.Job;
using System.Utilities;

codeunit 110081 "Test Control Previo Liq."
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ParametroCeroEsPresenteYAusenciaEsDistinta()
    var
        Control: Codeunit "Control Previo Liq.";
        Parametro: Record "Parámetro";
        Version: Record "Parámetro Vigente";
        Encontrada: Record "Parámetro Vigente";
        Motivo: Text;
        Revision: BigInteger;
    begin
        CrearParametro(Parametro);
        CrearVersion(Parametro.Código, DMY2Date(1, 1, 2026), 0, '', '', '', '', Version);
        Version.Get(Version."Cód. Parámetro Base", Version."Cód. Parámetro", Version."Vigencia Desde");
        Revision := Version.SystemRowVersion;
        Assert(Control.ResolverParametro(Parametro.Código, '', '', '', '', DMY2Date(31, 1, 2026), Encontrada, Motivo), 'Una fila con cero está cargada, no falta.');
        Assert((Encontrada.Valor = 0) and (Encontrada."Vigencia Desde" = Version."Vigencia Desde"), 'Debe conservar valor cero y versión física.');
        Assert(not Control.ResolverParametro(NuevoCodigo(), '', '', '', '', DMY2Date(31, 1, 2026), Encontrada, Motivo), 'Una base inexistente debe distinguirse de un cero cargado.');
        Version.Get(Version."Cód. Parámetro Base", Version."Cód. Parámetro", Version."Vigencia Desde");
        Assert((Version.SystemRowVersion = Revision) and not Version."En Uso", 'Consultar presencia no marca uso ni reescribe la versión.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ParametroRespetaFechaExplicitaYNoUsaFuturo()
    var
        Control: Codeunit "Control Previo Liq.";
        Parametro: Record "Parámetro";
        Version: Record "Parámetro Vigente";
        Encontrada: Record "Parámetro Vigente";
        Motivo: Text;
    begin
        CrearParametro(Parametro);
        CrearVersion(Parametro.Código, DMY2Date(1, 1, 2026), 10, '', '', '', '', Version);
        CrearVersion(Parametro.Código, DMY2Date(1, 2, 2026), 20, '', '', '', '', Version);
        Assert(Control.ResolverParametro(Parametro.Código, '', '', '', '', DMY2Date(31, 1, 2026), Encontrada, Motivo), 'Debe existir la versión de enero.');
        Assert(Encontrada.Valor = 10, 'La consulta no usa WorkDate ni la versión futura de febrero.');
        Assert(Control.ResolverParametro(Parametro.Código, '', '', '', '', DMY2Date(1, 2, 2026), Encontrada, Motivo), 'La nueva versión comienza el día exacto.');
        Assert(Encontrada.Valor = 20, 'Debe cambiar en la frontera, sin sumar un día.');
        Assert(not Control.ResolverParametro(Parametro.Código, '', '', '', '', DMY2Date(31, 12, 2025), Encontrada, Motivo), 'Sólo tener versiones futuras no acredita presencia anterior.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ParametroCascadaRespetaFechaYEspecificidad()
    var
        Control: Codeunit "Control Previo Liq.";
        Parametro: Record "Parámetro";
        Version: Record "Parámetro Vigente";
        Encontrada: Record "Parámetro Vigente";
        Motivo: Text;
    begin
        CrearParametro(Parametro);
        CrearVersion(Parametro.Código, DMY2Date(1, 1, 2026), 1, '', '', '', '', Version);
        CrearVersion(Parametro.Código, DMY2Date(1, 1, 2026), 2, '', 'CP_CCT', '', '', Version);
        CrearVersion(Parametro.Código, DMY2Date(1, 1, 2026), 3, 'CP_EMP', '', '', '', Version);
        Assert(Control.ResolverParametro(Parametro.Código, 'CP_EMP', '', 'CP_CCT', '', DMY2Date(31, 1, 2026), Encontrada, Motivo), 'La cascada debe encontrar una fila aplicable.');
        Assert(Encontrada.Valor = 3, 'A igual fecha gana el empleado.');
        CrearVersion(Parametro.Código, DMY2Date(1, 2, 2026), 4, '', '', '', '', Version);
        Assert(Control.ResolverParametro(Parametro.Código, 'CP_EMP', '', 'CP_CCT', '', DMY2Date(28, 2, 2026), Encontrada, Motivo), 'La genérica posterior también es candidata.');
        Assert(Encontrada.Valor = 4, 'La fecha posterior vence la especificidad anterior.');
        CrearVersion(Parametro.Código, DMY2Date(1, 2, 2026), 0, 'CP_EMP', '', '', '', Version);
        Assert(Control.ResolverParametro(Parametro.Código, 'CP_EMP', '', 'CP_CCT', '', DMY2Date(28, 2, 2026), Encontrada, Motivo), 'El cero específico está presente.');
        Assert((Encontrada.Valor = 0) and (Encontrada."No. Empleado" = 'CP_EMP'), 'El desempate no debe descartar el cero.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ParametroEjeUsaAtributoDeLaEntidadCorrecta()
    var
        Control: Codeunit "Control Previo Liq.";
        Parametro: Record "Parámetro";
        Version: Record "Parámetro Vigente";
        Encontrada: Record "Parámetro Vigente";
        Tipo: Record "Tipo Atributo Liq.";
        Valor: Record "Valor Atributo Liq.";
        Motivo: Text;
    begin
        CrearParametro(Parametro);
        CrearTipoAtributo(Tipo, "Tipo Entidad Estado"::Empleado);
        Tipo."Tipo Dato" := Tipo."Tipo Dato"::Lista;
        Tipo.Modify(false);
        Parametro."Cód. Tipo Atributo 1" := Tipo.Código;
        Parametro.Modify(false);
        Valor."Cód. Tipo Atributo" := Tipo.Código;
        Valor.Código := 'LAN';
        Valor."Sufijo Parámetro" := 'LAN';
        Valor.Insert(false);
        CrearAtributo(Tipo.Código, "Tipo Entidad Estado"::Empleado, 'CP_EMP', DMY2Date(1, 1, 2026), 0D, 'LAN', 0);
        CrearVersion(Parametro.Código, DMY2Date(1, 1, 2026), 7, '', 'CP_CCT', '', 'LAN', Version);
        CrearVersion(Parametro.Código, DMY2Date(1, 1, 2026), 99, '', 'CP_CCT', '', 'CAL', Version);
        Assert(Control.ResolverParametro(Parametro.Código, 'CP_EMP', '', 'CP_CCT', '', DMY2Date(31, 1, 2026), Encontrada, Motivo), 'El eje debe integrarse a la misma cascada del motor.');
        Assert(Encontrada.Valor = 7, 'No puede tomar el otro sufijo sólo por tener una fila.');
        Assert(not Control.ResolverParametro(Parametro.Código, 'CP_OTRO', '', 'CP_CCT', '', DMY2Date(31, 1, 2026), Encontrada, Motivo), 'Un empleado sin eje no hereda el atributo de otro.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AtributoCeroRespetaIntervaloInclusivo()
    var
        Control: Codeunit "Control Previo Liq.";
        Tipo: Record "Tipo Atributo Liq.";
    begin
        CrearTipoAtributo(Tipo, "Tipo Entidad Estado"::Empleado);
        CrearAtributo(Tipo.Código, "Tipo Entidad Estado"::Empleado, 'CP_EMP', DMY2Date(1, 1, 2026), DMY2Date(31, 1, 2026), '', 0);
        Assert(Control.AtributoPresente(Tipo.Código, "Tipo Entidad Estado"::Empleado, 'CP_EMP', DMY2Date(1, 1, 2026)), 'El inicio con valor cero es una asignación real.');
        Assert(Control.AtributoPresente(Tipo.Código, "Tipo Entidad Estado"::Empleado, 'CP_EMP', DMY2Date(31, 1, 2026)), 'El día final todavía está incluido.');
        Assert(not Control.AtributoPresente(Tipo.Código, "Tipo Entidad Estado"::Empleado, 'CP_EMP', DMY2Date(1, 2, 2026)), 'La asignación cerrada no cubre febrero.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AtributoNoSeCruzaEntreEmpleadoYProyecto()
    var
        Control: Codeunit "Control Previo Liq.";
        Tipo: Record "Tipo Atributo Liq.";
    begin
        CrearTipoAtributo(Tipo, "Tipo Entidad Estado"::Proyecto);
        CrearAtributo(Tipo.Código, "Tipo Entidad Estado"::Proyecto, 'CP_ENTIDAD', DMY2Date(1, 1, 2026), 0D, '', 0);
        Assert(Control.AtributoPresente(Tipo.Código, "Tipo Entidad Estado"::Proyecto, 'CP_ENTIDAD', DMY2Date(31, 1, 2026)), 'El atributo existe en el proyecto.');
        Assert(not Control.AtributoPresente(Tipo.Código, "Tipo Entidad Estado"::Empleado, 'CP_ENTIDAD', DMY2Date(31, 1, 2026)), 'El mismo código bajo otro tipo de entidad no acredita presencia.');
        Assert(not Control.AtributoPresente(Tipo.Código, "Tipo Entidad Estado"::Proyecto, 'CP_OTRO', DMY2Date(31, 1, 2026)), 'Tampoco puede reutilizar el proyecto anterior.');
    end;

    [Test]
    procedure LexerNoInventaVariablesDesdeTextosNiReferencias()
    var
        Control: Codeunit "Control Previo Liq.";
        Nombres: List of [Text];
    begin
        ExigirEmpresaTest();
        Control.ExtraerVariables('MAX(P, 1) + #OTRO + @FORMULA + IF(TIPO_LIQ = ''P TRAMO(''''X'''')'', Q, 0)', Nombres);
        Assert(Nombres.Contains('P') and Nombres.Contains('Q') and Nombres.Contains('TIPO_LIQ'), 'Debe conservar las variables reales.');
        Assert(not Nombres.Contains('MAX') and not Nombres.Contains('IF') and not Nombres.Contains('TRAMO'), 'Los nombres de funciones y los textos no son datos faltantes.');
        Assert(not Nombres.Contains('OTRO') and not Nombres.Contains('FORMULA'), 'Las referencias calculadas no son parámetros del empleado.');
        Control.ExtraerVariables('1', Nombres);
        Assert(Nombres.Count() = 0, 'Cada extracción limpia su salida y no arrastra otro concepto.');
    end;

    [Test]
    procedure UsoDirectoCondicionalYFallbackSonDistintos()
    var
        Control: Codeunit "Control Previo Liq.";
    begin
        ExigirEmpresaTest();
        Assert(Control.ClasificarUso('P+1', 'P') = 1, 'La referencia directa es demostrable.');
        Assert(Control.ClasificarUso('IF(FLAG>0,P,0)', 'P') = 2, 'Una rama no demostrada no debe producir un error definitivo.');
        Assert(Control.ClasificarUso('IFZERO(P,1)', 'P') = 3, 'El primer argumento de IFZERO tiene fallback explícito.');
        Assert(Control.ClasificarUso('IFZERO(1,P)', 'P') = 2, 'El fallback puede necesitar P y no lo protege a su vez.');
        Assert(Control.ClasificarUso('IF(FLAG,P,0)+P', 'P') = 1, 'Un uso directo adicional prevalece sobre la rama opcional.');
        Assert(Control.ClasificarUso('IF(FLAG,P,0)+IF(P<>0,P,1)', 'P') = 2, 'Una alternativa protegida no debe degradar otro uso condicional de la misma variable.');
        Assert(Control.ClasificarUso('IF(P<>0,P,1)+P', 'P') = 1, 'Un uso directo adicional prevalece también sobre una alternativa explícita.');
        Assert(Control.ClasificarUso('MAX(1,2)+#P+@P', 'P') = 0, 'No debe confundir un concepto referido con una variable base.');
        Assert(Control.ClasificarUso('IF(TIPO_LIQ=''P'',1,0)', 'P') = 0, 'Un literal no es un uso de la variable que nombra.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FuenteValidaCountSinCampoYRechazaCampoInexistente()
    var
        Prevuelo: Codeunit "Prevuelo Fuentes Liq.";
        Fuente: Record "Fuente Datos Liquidación";
        Incidencia: Record "Incidencia Liquidación";
        Motivo: Text;
    begin
        ExigirEmpresaTest();
        Fuente."Nombre Variable" := CopyStr(NuevoCodigo(), 1, 30);
        Fuente."Id. Tabla" := Database::"Incidencia Liquidación";
        Fuente.Activo := true;
        Fuente."Función Agregado" := Fuente."Función Agregado"::COUNT;
        Assert(Prevuelo.ConfiguracionValida(Fuente, Motivo), 'COUNT no exige campo de valor.');
        Fuente."Tipo Dato" := Fuente."Tipo Dato"::Texto;
        Assert(not Prevuelo.ConfiguracionValida(Fuente, Motivo), 'COUNT no exime del campo de valor a una fuente declarada de texto.');
        Fuente."Tipo Dato" := Fuente."Tipo Dato"::Decimal;
        Fuente."No. Filtro 1" := 999999;
        Fuente."Filtro Valor 1" := 'NULL';
        Assert(Prevuelo.ConfiguracionValida(Fuente, Motivo), 'Los filtros legacy no se ejecutan en el contexto actual y no deben crear errores falsos.');
        Fuente."Función Agregado" := Fuente."Función Agregado"::SUM;
        Fuente."No. Campo Valor" := Incidencia.FieldNo(Cantidad);
        Assert(Prevuelo.ConfiguracionValida(Fuente, Motivo), 'SUM con campo numérico existente es una configuración válida.');
        Fuente."No. Campo Fecha Inicio" := Incidencia.FieldNo(SystemCreatedAt);
        Assert(not Prevuelo.ConfiguracionValida(Fuente, Motivo), 'Una fecha y hora no puede darse por válida como fecha de inicio si el motor sólo convierte Date.');
        Fuente."No. Campo Fecha Inicio" := 0;
        Fuente."No. Campo Valor" := 999999;
        Assert(not Prevuelo.ConfiguracionValida(Fuente, Motivo), 'Un campo inexistente debe informarse antes de consultar datos.');
        Fuente."Id. Tabla" := 0;
        Assert(not Prevuelo.ConfiguracionValida(Fuente, Motivo), 'Una tabla ausente no es una fuente vacía válida.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure CotizacionUsaMonedaFechaYUltimaFilaAplicable()
    var
        Prevuelo: Codeunit "Prevuelo Fuentes Liq.";
        Fuente: Record "Fuente Datos Liquidación";
        Filtro: Record "Filtro Fuente Datos Liq.";
        Moneda: Code[10];
        Valor: Decimal;
        Motivo: Text;
    begin
        CrearFuenteCotizacion(Fuente, Moneda);
        CrearCotizacion(Moneda, DMY2Date(1, 1, 2026), 10);
        CrearCotizacion(Moneda, DMY2Date(1, 2, 2026), 20);
        CrearCotizacion('CP_OTRA', DMY2Date(31, 1, 2026), 999);
        Assert(Prevuelo.ResolverCotizacion(Fuente."Nombre Variable", Moneda, DMY2Date(31, 1, 2026), Valor, Motivo), 'La cotización debe resolverse sólo con contexto seguro de fecha y moneda.');
        Assert(Valor = 10, 'No puede tomar el futuro ni otra moneda.');
        Assert(Prevuelo.ResolverCotizacion(Fuente."Nombre Variable", Moneda, DMY2Date(1, 2, 2026), Valor, Motivo), 'La nueva cotización empieza en su fecha.');
        Assert(Valor = 20, 'Debe respetar la frontera.');
        Assert(Prevuelo.ResolverCotizacionFechas(Fuente."Nombre Variable", Moneda, DMY2Date(31, 1, 2026), DMY2Date(1, 2, 2026), Valor, Motivo), 'La fecha de referencia y la de cotización pueden ser distintas.');
        Assert(Valor = 10, 'Un filtro FECHA_REF conserva la fecha de referencia aunque exista una fecha TC posterior.');
        Filtro.Get(Fuente."Nombre Variable", 2);
        Filtro."Filtro Valor" := '..{FECHA_TC}';
        Filtro.Modify(false);
        Assert(Prevuelo.ResolverCotizacionFechas(Fuente."Nombre Variable", Moneda, DMY2Date(31, 1, 2026), DMY2Date(1, 2, 2026), Valor, Motivo), 'Un filtro FECHA_TC debe usar la fecha TC explícita.');
        Assert(Valor = 20, 'No debe sustituir la fecha TC por el cierre del período.');
        Assert(Prevuelo.ResolverCotizacionFechas(Fuente."Nombre Variable", Moneda, DMY2Date(28, 2, 2026), DMY2Date(31, 1, 2026), Valor, Motivo), 'También debe admitir una fecha TC anterior al período.');
        Assert(Valor = 10, 'Cambiar referencias no debe reutilizar la cotización anterior.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure CotizacionAusenteYCeroNoSonUnaConversionValida()
    var
        Prevuelo: Codeunit "Prevuelo Fuentes Liq.";
        Fuente: Record "Fuente Datos Liquidación";
        Moneda: Code[10];
        Valor: Decimal;
        Motivo: Text;
        AusenciaConfirmada: Boolean;
    begin
        CrearFuenteCotizacion(Fuente, Moneda);
        Assert(not Prevuelo.ResolverCotizacion(Fuente."Nombre Variable", Moneda, DMY2Date(31, 1, 2026), Valor, Motivo), 'No tener fila de cotización debe informarse.');
        Assert(Motivo <> '', 'La ausencia necesita explicación.');
        Assert(not Prevuelo.ResolverCotizacionFechas(Fuente."Nombre Variable", Moneda, DMY2Date(31, 1, 2026), DMY2Date(31, 1, 2026), Valor, Motivo, AusenciaConfirmada), 'La lectura segura sin filas tampoco puede certificar una conversión.');
        Assert(AusenciaConfirmada, 'Una lectura segura terminada sin filas sí demuestra ausencia de cotización para ese alcance.');
        CrearCotizacion(Moneda, DMY2Date(1, 1, 2026), 0);
        Assert(not Prevuelo.ResolverCotizacion(Fuente."Nombre Variable", Moneda, DMY2Date(31, 1, 2026), Valor, Motivo), 'El cero existe, pero no es una cotización positiva para convertir.');
        Assert(Motivo <> '', 'Un valor inválido también necesita explicación.');
        AusenciaConfirmada := false;
        Assert(not Prevuelo.ResolverCotizacionFechas(Fuente."Nombre Variable", Moneda, DMY2Date(31, 1, 2026), DMY2Date(31, 1, 2026), Valor, Motivo, AusenciaConfirmada), 'La tasa cero encontrada por lectura segura tampoco permite convertir.');
        Assert(AusenciaConfirmada, 'Una fila de cotización encontrada pero no positiva acredita el defecto de tasa, sin confundirlo con contexto pendiente.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure CotizacionConTokenEmpleadoNoHaceConsultaGlobal()
    var
        Prevuelo: Codeunit "Prevuelo Fuentes Liq.";
        Fuente: Record "Fuente Datos Liquidación";
        Filtro: Record "Filtro Fuente Datos Liq.";
        Cambio: Record "Currency Exchange Rate";
        Moneda: Code[10];
        Valor: Decimal;
        Motivo: Text;
        AusenciaConfirmada: Boolean;
    begin
        CrearFuenteCotizacion(Fuente, Moneda);
        CrearCotizacion(Moneda, DMY2Date(1, 1, 2026), 123);
        Filtro.Init();
        Filtro."Nombre Variable" := Fuente."Nombre Variable";
        Filtro."No. Línea" := 3;
        Filtro."No. Campo" := Cambio.FieldNo("Currency Code");
        Filtro."Filtro Valor" := '{EMP_NO}';
        Filtro.Insert(false);
        Assert(not Prevuelo.ResolverCotizacion(Fuente."Nombre Variable", Moneda, DMY2Date(31, 1, 2026), Valor, Motivo), 'Un contexto que no está disponible no permite ignorar el filtro y tomar cualquier fila positiva.');
        Assert(Motivo <> '', 'Debe quedar explícito el contexto que no pudo resolverse.');
        Assert(Valor = 0, 'No debe devolver un resultado leído fuera del alcance.');
        AusenciaConfirmada := true;
        Assert(not Prevuelo.ResolverCotizacionFechas(Fuente."Nombre Variable", Moneda, DMY2Date(31, 1, 2026), DMY2Date(31, 1, 2026), Valor, Motivo, AusenciaConfirmada), 'El token de empleado no disponible impide efectuar una lectura segura.');
        Assert(not AusenciaConfirmada, 'La salida debe limpiar un true anterior: un token pendiente no demuestra que falte la tasa.');
        Filtro.SetRange("Nombre Variable", Fuente."Nombre Variable");
        Filtro.DeleteAll(false);
        Assert(not Prevuelo.ResolverCotizacion(Fuente."Nombre Variable", Moneda, DMY2Date(31, 1, 2026), Valor, Motivo), 'Sin ningún filtro no debe consultar una cotización global accidentalmente.');
        Assert((Valor = 0) and (Motivo <> ''), 'La consulta no efectuada queda sin valor y con explicación.');
        AusenciaConfirmada := true;
        Assert(not Prevuelo.ResolverCotizacionFechas(Fuente."Nombre Variable", Moneda, DMY2Date(31, 1, 2026), DMY2Date(31, 1, 2026), Valor, Motivo, AusenciaConfirmada), 'La ausencia de filtros debe impedir la lectura amplia también en la firma que distingue certeza.');
        Assert(not AusenciaConfirmada, 'Una consulta no efectuada debe limpiar un true previo y conservar la falta de contexto, no inventar una tasa ausente.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AnalizarDistingueFaltanteDirectoDeCeroCargado()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Version: Record "Parámetro Vigente";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CrearParametro(Parametro);
        Concepto.Fórmula := Parametro."Nombre Variable";
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayAdvertenciaVariable(Buffer, Parametro."Nombre Variable"), 'Un parámetro directo sin fila debe quedar visible como revisión, sin inventar una obligación económica.');
        CrearVersion(Parametro.Código, DMY2Date(1, 1, 2026), 0, '', '', '', '', Version);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Parametro."Nombre Variable"), 'Al cargar cero debe desaparecer la observación por ausencia, sin calcular recibos.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AnalizarRamaOpcionalNoAseguraUnErrorDePago()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
        Tabulador: Char;
        Retorno: Char;
        Salto: Char;
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CrearParametro(Parametro);
        Concepto.Fórmula := 'IF(1,0,' + Parametro."Nombre Variable" + ')';
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Parametro."Nombre Variable"), 'La rama falsa conocida no debe producir una observación sobre el parámetro.');
        Concepto.Fórmula := 'IFZERO(' + Parametro."Nombre Variable" + ',1)';
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Parametro."Nombre Variable"), 'Un fallback explícito demostrado no debe generar un pendiente por el parámetro ausente.');
        Tabulador := 9;
        Retorno := 13;
        Salto := 10;
        Concepto.Fórmula := 'IF' + Format(Tabulador) + '(' + Format(Retorno) + Format(Salto) + '0,' + Parametro."Nombre Variable" + ',' + Format(Tabulador) + '0)';
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Parametro."Nombre Variable"), 'TAB, CR y LF no deben ocultar que la rama del parámetro está descartada por una condición falsa conocida.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AnalizarNoIncluyeFasePosteriorAlPeriodo()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Fase: Record "Fase Alta Empleado";
        CodigoEstado: Record "Cód. Estado Empleado";
        Estado: Record "Estado Empleado";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
        HayInfoFase: Boolean;
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CrearParametro(Parametro);
        Concepto.Fórmula := Parametro."Nombre Variable";
        Concepto.Modify(false);
        Fase.Get(Empleado, 1);
        Fase."Fecha Alta" := DMY2Date(1, 2, 2026);
        Fase.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Parametro."Nombre Variable"), 'Una fase que sólo empieza en febrero no genera observaciones del parámetro de enero.');
        Fase."Fecha Alta" := DMY2Date(31, 1, 2026);
        Fase.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayAdvertenciaVariable(Buffer, Parametro."Nombre Variable"), 'El último día del mes sí produce una revisión visible del contexto elegible.');
        Fase.Delete(false);
        CodigoEstado.Código := 'CP_ACTIVO';
        CodigoEstado.Insert(false);
        Estado."Tipo Entidad" := Estado."Tipo Entidad"::Empleado;
        Estado."No. Empleado" := Empleado;
        Estado."Cód. Estado" := CodigoEstado.Código;
        Estado."Fecha Inicio" := DMY2Date(1, 1, 2026);
        Estado.Insert(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayVariable(Buffer, Parametro."Nombre Variable"), 'Sin fases modeladas, un estado vigente debe conservar la ruta compatible del creador e inspeccionar sus entradas.');
        Buffer.Reset();
        Buffer.SetRange("No. Empleado", Empleado);
        Buffer.SetRange(Severidad, Buffer.Severidad::Información);
        if Buffer.FindSet() then
            repeat
                if StrPos(UpperCase(Buffer.Mensaje + ' ' + Buffer.Detalle), 'FASE') > 0 then
                    HayInfoFase := true;
            until Buffer.Next() = 0;
        Assert(HayInfoFase, 'La inclusión compatible debe conservar visible que no se conoce la fase, sin inventar una.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AnalizarRespetaTipoYFiltroDeEmpleado()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CrearParametro(Parametro);
        Concepto.Fórmula := Parametro."Nombre Variable";
        Concepto."Tipos Liq. Aplicables" := 'CP_OTRO_TIPO';
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Parametro."Nombre Variable"), 'Un concepto de otro tipo no debe introducir observaciones de sus parámetros aquí.');
        Concepto."Tipos Liq. Aplicables" := Tipo;
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, NuevoCodigo(), '', Buffer);
        Assert(not HayVariable(Buffer, Parametro."Nombre Variable"), 'Un filtro sin empleados coincidentes no puede ampliar el análisis a todos.');
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayAdvertenciaVariable(Buffer, Parametro."Nombre Variable"), 'Al restaurar el alcance debe reaparecer la revisión por la fila realmente ausente.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AnalizarFuenteLiqNoQuedaPendienteDeContexto()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Fuente: Record "Fuente Datos Liquidación";
        Incidencia: Record "Incidencia Liquidación";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        Fuente."Nombre Variable" := NuevoCodigo();
        Fuente."Id. Tabla" := Database::"Incidencia Liquidación";
        Fuente."Función Agregado" := Fuente."Función Agregado"::COUNT;
        Fuente.Activo := true;
        Fuente.Insert(false);
        CrearFiltro(Fuente."Nombre Variable", 1, Incidencia.FieldNo("No. Liquidación"), '{LIQ_NO}');
        Concepto.Fórmula := Fuente."Nombre Variable";
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayErrorVariable(Buffer, Fuente."Nombre Variable"), 'Antes de crear el recibo no puede declarar una fuente vacía como error monetario.');
        Assert(HayVariable(Buffer, Fuente."Nombre Variable"), 'Debe conservar visible la limitación de contexto en vez de afirmar que quedó verificada.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AnalizarAtributoAsignadoEnCeroNoFalta()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Atributo: Record "Tipo Atributo Liq.";
        ObligatorioA: Record "Tipo Atributo Liq.";
        ObligatorioB: Record "Tipo Atributo Liq.";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CrearTipoAtributo(Atributo, "Tipo Entidad Estado"::Empleado);
        Concepto.Fórmula := Atributo."Nombre Variable";
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayVariable(Buffer, Atributo."Nombre Variable"), 'La asignación ausente debe informarse para el concepto que la usa.');
        CrearAtributo(Atributo.Código, "Tipo Entidad Estado"::Empleado, Empleado, DMY2Date(1, 1, 2026), 0D, '', 0);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayErrorVariable(Buffer, Atributo."Nombre Variable"), 'Una asignación numérica cero no es un valor faltante.');
        CrearTipoAtributo(ObligatorioA, "Tipo Entidad Estado"::Empleado);
        ObligatorioA."Nombre Variable" := '';
        ObligatorioA.Obligatorio := true;
        ObligatorioA.Modify(false);
        CrearTipoAtributo(ObligatorioB, "Tipo Entidad Estado"::Empleado);
        ObligatorioB."Nombre Variable" := '';
        ObligatorioB.Obligatorio := true;
        ObligatorioB.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Buffer.Reset();
        Buffer.SetRange("No. Empleado", Empleado);
        Buffer.SetRange("Cód. Tipo Atributo", ObligatorioA.Código);
        Assert(Buffer.Count() = 1, 'El primer atributo obligatorio sin nombre de variable conserva su propio diagnóstico.');
        Buffer.FindFirst();
        Assert(Buffer.Severidad = Buffer.Severidad::Advertencia, 'La obligatoriedad global sin una necesidad operativa demostrada es una revisión, también cuando no hay nombre de variable.');
        Buffer.SetRange("Cód. Tipo Atributo", ObligatorioB.Código);
        Assert(Buffer.Count() = 1, 'El segundo atributo obligatorio sin nombre no debe colapsar con el primero por deduplicación.');
        Buffer.FindFirst();
        Assert(Buffer.Severidad = Buffer.Severidad::Advertencia, 'El segundo faltante administrativo también debe conservar su revisión sin afirmar un bloqueo económico.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AnalizarConservaDocumentosUsosYConfiguracion()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Version: Record "Parámetro Vigente";
        Cabecera: Record "Liquidación";
        Linea: Record "Línea Liquidación";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
        Conteos: Text;
        RevisionConcepto: BigInteger;
        RevisionParametro: BigInteger;
        RevisionCabecera: BigInteger;
        RevisionLinea: BigInteger;
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CrearParametro(Parametro);
        CrearVersion(Parametro.Código, DMY2Date(1, 1, 2026), 10, '', '', '', '', Version);
        Concepto.Fórmula := Parametro."Nombre Variable";
        Concepto.Modify(false);
        Cabecera."No." := NuevoCodigo();
        Cabecera."No. Empleado" := Empleado;
        Cabecera."Cód. Período" := Periodo;
        Cabecera."Cód. Tipo Liq." := Tipo;
        Cabecera."Fecha Liquidación" := DMY2Date(31, 1, 2026);
        Cabecera.Estado := Cabecera.Estado::Calculada;
        Cabecera.Insert(false);
        Linea."No. Liquidación" := Cabecera."No.";
        Linea."No. Línea" := 1;
        Linea."Cód. Concepto" := Concepto.Código;
        Linea.Importe := 123.456;
        Linea.Insert(false);
        Concepto.Get(Concepto.Código, Concepto."Vigencia Desde");
        Version.Get(Version."Cód. Parámetro Base", Version."Cód. Parámetro", Version."Vigencia Desde");
        Cabecera.Get(Cabecera."No.");
        Linea.Get(Linea."No. Liquidación", Linea."No. Línea");
        RevisionConcepto := Concepto.SystemRowVersion;
        RevisionParametro := Version.SystemRowVersion;
        RevisionCabecera := Cabecera.SystemRowVersion;
        RevisionLinea := Linea.SystemRowVersion;
        Conteos := CapturarConteos();
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(CapturarConteos() = Conteos, 'El informe no crea recibos, líneas, usos, movimientos, incidencias ni registros de proceso.');
        Concepto.Get(Concepto.Código, Concepto."Vigencia Desde");
        Version.Get(Version."Cód. Parámetro Base", Version."Cód. Parámetro", Version."Vigencia Desde");
        Cabecera.Get(Cabecera."No.");
        Linea.Get(Linea."No. Liquidación", Linea."No. Línea");
        Assert((Concepto.SystemRowVersion = RevisionConcepto) and (Version.SystemRowVersion = RevisionParametro) and not Version."En Uso", 'No puede reescribir configuración ni marcar parámetros usados.');
        Assert((Cabecera.SystemRowVersion = RevisionCabecera) and (Linea.SystemRowVersion = RevisionLinea) and (Linea.Importe = 123.456), 'Los recibos calculados y sus importes se conservan idénticos.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AnalizarRepiteSinDuplicarNiArrastrarOtroPeriodo()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Version: Record "Parámetro Vigente";
        SegundoPeriodo: Record "Período Liquidación";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
        Primera: Text;
        Conteos: Text;
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CrearParametro(Parametro);
        CrearVersion(Parametro.Código, DMY2Date(1, 2, 2026), 0, '', '', '', '', Version);
        Concepto.Fórmula := Parametro."Nombre Variable";
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayAdvertenciaVariable(Buffer, Parametro."Nombre Variable"), 'Enero debe conservar visible que no tiene todavía su valor.');
        Primera := ResumenBuffer(Buffer);
        Conteos := CapturarConteos();
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(ResumenBuffer(Buffer) = Primera, 'La segunda pasada debe reemplazar el buffer con el mismo conjunto.');
        SegundoPeriodo.Código := CopyStr(NuevoCodigo(), 1, 10);
        SegundoPeriodo."Fecha Desde" := DMY2Date(1, 2, 2026);
        SegundoPeriodo."Fecha Hasta" := DMY2Date(28, 2, 2026);
        SegundoPeriodo.Insert(false);
        Control.Analizar(SegundoPeriodo.Código, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Parametro."Nombre Variable"), 'Febrero tiene un cero cargado y no hereda la observación de enero.');
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(ResumenBuffer(Buffer) = Primera, 'Al volver a enero debe recuperarse el diagnóstico correcto.');
        Assert(CapturarConteos() = Conteos, 'Repetir el control no crea contenido operativo.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ParametroFCYNoUsadoSinTCSeDetectaAntesDelCalculo()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Version: Record "Parámetro Vigente";
        Setup: Record "Human Resources Setup";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        Assert(Concepto.Fórmula = '1', 'La fixture no debe leer el parámetro: se prueba la conversión global del contexto.');
        CrearParametro(Parametro);
        CrearVersion(Parametro.Código, DMY2Date(1, 1, 2026), 10, '', '', '', '', Version);
        Version.Moneda := 'USD';
        Version."Cód. Variable TC" := '';
        Version.Modify(false);
        if Setup.Get() then begin
            Setup."Convertir Param. por TC" := true;
            Setup.Modify(false);
        end else begin
            Setup.Init();
            Setup."Convertir Param. por TC" := true;
            Setup.Insert(false);
        end;
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayErrorVariable(Buffer, Parametro."Nombre Variable"), 'La conversión automática requiere TC incluso para un parámetro FCY que ninguna fórmula lee.');
        Setup."Convertir Param. por TC" := false;
        Setup.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayErrorVariable(Buffer, Parametro."Nombre Variable"), 'Con conversión automática desactivada no puede afirmar un bloqueo por TC de un parámetro que no se lee.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SelectorPositivoAusenteNoExigeLaFormulaDesactivada()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Selector: Record "Parámetro";
        Precio: Record "Parámetro";
        Version: Record "Parámetro Vigente";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CrearParametro(Selector);
        CrearParametro(Precio);
        Concepto.Condición := Selector."Nombre Variable" + ' > 0';
        Concepto.Fórmula := Precio."Nombre Variable";
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Selector."Nombre Variable"), 'El selector ausente que deja demostrada la condición falsa no debe generar un pendiente.');
        Assert(not HayErrorVariable(Buffer, Selector."Nombre Variable"), 'El selector ausente que desactiva una condición positiva no demuestra un fallo de cálculo.');
        Assert(not HayVariable(Buffer, Precio."Nombre Variable"), 'No debe exigir una entrada de importe cuando el selector ausente deja la condición falsa.');
        CrearVersion(Selector.Código, DMY2Date(1, 1, 2026), 0, '', '', '', '', Version);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Precio."Nombre Variable"), 'Un cero real también mantiene desactivada la fórmula.');
        Version.Valor := 1;
        Version.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayAdvertenciaVariable(Buffer, Precio."Nombre Variable"), 'Al activar el concepto debe reaparecer el faltante directo, visible y sin inventar un precio.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ColisionConProductorNoDescartaUnaRamaPosible()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Lector: Record "Concepto Liquidación";
        Productor: Record "Concepto Liquidación";
        Selector: Record "Parámetro";
        Precio: Record "Parámetro";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Lector);
        CrearParametro(Selector);
        CrearParametro(Precio);
        Productor := Lector;
        Productor.Código := Selector."Nombre Variable";
        Productor."Orden Cálculo" := 10;
        Productor."Fórmula Orden Cálculo" := '10';
        Productor.Fórmula := '1';
        Productor.Insert(false);
        Lector."Orden Cálculo" := 20;
        Lector."Fórmula Orden Cálculo" := '20';
        Lector.Fórmula := 'IF(' + Selector."Nombre Variable" + '>0,' + Precio."Nombre Variable" + ',0)';
        Lector.Modify(false);

        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);

        Assert(HayAdvertenciaVariable(Buffer, Precio."Nombre Variable"), 'El concepto productor anterior puede dar valor al selector: su parámetro sin fila no permite descartar la rama ni ocultar la entrada Q.');
        Buffer.Reset();
        Buffer.SetRange("Nombre Variable", Selector."Nombre Variable");
        Buffer.SetRange(Área, 'Contexto');
        Buffer.SetRange(Severidad, Buffer.Severidad::Advertencia);
        Assert(not Buffer.IsEmpty(), 'La colisión entre parámetro y concepto debe quedar visible como advertencia de contexto, sin presumir P igual a cero.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AlternativaIFNoOcultaUnUsoDirectoAdicional()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CrearParametro(Parametro);
        Concepto.Fórmula := 'IF(' + Parametro."Nombre Variable" + ' <> 0,' + Parametro."Nombre Variable" + ',1)';
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Parametro."Nombre Variable"), 'El IF con alternativa expresa demostrada no debe generar un pendiente, igual que IFZERO.');
        Assert(not HayAdvertenciaVariable(Buffer, Parametro."Nombre Variable"), 'El selector del propio fallback no debe volver obligatoria la entrada.');
        Concepto.Fórmula += '+' + Parametro."Nombre Variable";
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayAdvertenciaVariable(Buffer, Parametro."Nombre Variable"), 'La protección sólo alcanza su subárbol; un uso directo adicional debe seguir visible como revisión.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SelectorSinAcuerdoNoSeConvierteEnUnPrecioObligatorio()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CrearParametro(Parametro);
        Concepto.Fórmula := 'IF(' + Parametro."Nombre Variable" + ' = 0,1,2)';
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Parametro."Nombre Variable"), 'Comparar la ausencia con cero para elegir una rama conocida no debe generar un pendiente de acuerdo.');
        Concepto.Fórmula := Parametro."Nombre Variable" + '*2';
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayAdvertenciaVariable(Buffer, Parametro."Nombre Variable"), 'La misma variable usada como valor debe volver a quedar pendiente de revisión.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AuxiliarInformativoNoOcultaLaEntradaDeUnHaber()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Auxiliar: Record "Concepto Liquidación";
        Haber: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Auxiliar);
        CrearParametro(Parametro);
        Auxiliar."Tipo Concepto" := Auxiliar."Tipo Concepto"::Informativo;
        Auxiliar.Fórmula := Parametro."Nombre Variable";
        Auxiliar.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayAdvertenciaVariable(Buffer, Parametro."Nombre Variable"), 'El uso directo de un auxiliar debe seguir en revisión: su tipo informativo no demuestra que el dato sea opcional.');
        Haber := Auxiliar;
        Haber.Código := NuevoCodigo();
        Haber."Tipo Concepto" := Haber."Tipo Concepto"::"Haber Remunerativo";
        Haber.Insert(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayAdvertenciaVariable(Buffer, Parametro."Nombre Variable"), 'El uso directo del haber no debe degradarse por compartir nombre con un auxiliar.');
        Buffer.Reset();
        Buffer.SetRange("Nombre Variable", Parametro."Nombre Variable");
        Assert(Buffer.Count() = 1, 'Dos usos directos del mismo dato y alcance deben compartir una revisión sin inventar una opcionalidad para el auxiliar.');
        Buffer.FindFirst();
        Assert(Buffer.Repeticiones = 2, 'La revisión debe conservar las dos ocurrencias, aunque una provenga de un auxiliar informativo.');
        Assert((StrPos(Buffer."Conceptos relacionados", Auxiliar.Código) > 0) and (StrPos(Buffer."Conceptos relacionados", Haber.Código) > 0), 'La revisión compartida debe conservar el auxiliar y el haber que consumen la entrada.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AgruparSumaRepeticionesYConservaConceptosSinDuplicarlos()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Fila: Record "Control Previo Liq. Buffer" temporary;
        Resultado: Text;
    begin
        ExigirEmpresaTest();
        PrepararFilaAgrupacion(Fila);
        Fila."No. Línea" := 1;
        Fila."Cód. Concepto" := 'CP_C1';
        Fila.Repeticiones := 0;
        Buffer := Fila;
        Buffer.Insert();
        Fila."No. Línea" := 2;
        Fila."Cód. Concepto" := 'CP_C2';
        Buffer := Fila;
        Buffer.Insert();
        Fila."No. Línea" := 3;
        Fila.Repeticiones := 3;
        Fila."Conceptos relacionados" := 'CP_C2|CP_C3';
        Buffer := Fila;
        Buffer.Insert();
        Control.AgruparResultados(Buffer);
        Buffer.Reset();
        Assert(Buffer.Count() = 1, 'Tres observaciones del mismo dato y alcance deben ocupar una fila.');
        Buffer.FindFirst();
        Assert(Buffer.Repeticiones = 5, 'Los ceros legacy cuentan uno cada uno y una fila ya agregada conserva sus tres repeticiones.');
        Assert(StrPos(Buffer."Conceptos relacionados", 'CP_C1') > 0, 'Debe conservar el primer consumidor.');
        Assert(StrPos(Buffer."Conceptos relacionados", 'CP_C2') > 0, 'Debe conservar el segundo consumidor.');
        Assert(StrPos(Buffer."Conceptos relacionados", 'CP_C3') > 0, 'Debe conservar consumidores de una fila previamente agregada.');
        Resultado := ResumenBuffer(Buffer);
        Control.AgruparResultados(Buffer);
        Assert(ResumenBuffer(Buffer) = Resultado, 'Agrupar dos veces no debe volver a sumar repeticiones ni duplicar consumidores.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AgruparNoMezclaAlcancesDatosNiSeveridades()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Fila: Record "Control Previo Liq. Buffer" temporary;
        Variante: Integer;
    begin
        ExigirEmpresaTest();
        for Variante := 1 to 20 do begin
            PrepararFilaAgrupacion(Fila);
            Fila."No. Línea" := Variante;
            case Variante of
                2: Fila."No. Empleado" := 'CP_EMP_B';
                3: Fila."No. Proyecto" := 'CP_PROY_B';
                4: Fila."Cód. Tipo Liq." := 'CP_TIPO_B';
                5: Fila."Cód. Convenio" := 'CP_CCT_B';
                6: Fila."Cód. Categoría" := 'CP_CAT_B';
                7: Fila."Fecha Desde" := DMY2Date(2, 1, 2026);
                8: Fila."Fecha Hasta" := DMY2Date(30, 1, 2026);
                9: Fila."Vigencia Desde" := DMY2Date(2, 1, 2026);
                10: Fila."Cód. Parámetro" := 'CP_PARAM_B';
                11: Fila.Severidad := Fila.Severidad::Información;
                12: Fila.Mensaje := 'Otra observación';
                13: Fila.Detalle := 'Otra causa';
                14: Fila."Cód. Tipo Atributo" := 'CP_ATR_B';
                15: Fila."Nombre Fuente" := 'CP_FUENTE_B';
                16: Fila."Clave Parámetro" := 'CP_CLAVE_B';
                17: Fila."Nombre Variable" := 'CP_VARIABLE_B';
                18: Fila."Cód. Entidad" := 'CP_ENT_B';
                19: Fila."Tipo Entidad" := Fila."Tipo Entidad"::Buque;
                20: Fila.Área := 'Atributos';
            end;
            Buffer := Fila;
            Buffer.Insert();
        end;
        Control.AgruparResultados(Buffer);
        Buffer.Reset();
        Assert(Buffer.Count() = 20, 'Cada diferencia de alcance, identidad del dato, severidad o causa debe conservar una fila independiente.');
        if Buffer.FindSet() then
            repeat
                Assert(Buffer.Repeticiones = 1, 'Una observación única no debe recibir repeticiones de otro alcance.');
            until Buffer.Next() = 0;
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AtributoEmpleadoConClaseSeRevisaSinInventarObligatoriedad()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Atributo: Record "Tipo Atributo Liq.";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CrearTipoAtributo(Atributo, Atributo."Tipo Entidad"::Empleado);
        Atributo."Cód. Clase" := 'CP_CLASE_BUQUE';
        Atributo.Modify(false);
        Concepto.Fórmula := Atributo."Nombre Variable";
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayInformacionVariable(Buffer, Atributo."Nombre Variable"), 'La clase no debe silenciar un atributo de empleado; si es opcional su ausencia es informativa.');
        Assert(not HayAdvertenciaVariable(Buffer, Atributo."Nombre Variable"), 'No puede inventar obligatoriedad para un atributo opcional de empleado.');
        Atributo.Obligatorio := true;
        Atributo.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayAdvertenciaVariable(Buffer, Atributo."Nombre Variable"), 'La marca Obligatorio acredita una revisión administrativa del dato, sin demostrar por sí sola un pago incorrecto.');
        Assert(not HayErrorVariable(Buffer, Atributo."Nombre Variable"), 'El uso directo no convierte la obligatoriedad global del atributo en un fallo operativo comprobado.');
        Concepto.Fórmula := 'IF(CP_FLAG>0,' + Atributo."Nombre Variable" + ',0)';
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayAdvertenciaVariable(Buffer, Atributo."Nombre Variable"), 'La referencia condicional conserva visible la revisión del atributo sin probar que deba pagarse.');
        Assert(not HayErrorVariable(Buffer, Atributo."Nombre Variable"), 'Una rama no demostrada tampoco debe heredar un error por la obligatoriedad global.');
        CrearAtributo(Atributo.Código, Atributo."Tipo Entidad"::Empleado, Empleado, DMY2Date(1, 1, 2026), 0D, '', 0);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Atributo."Nombre Variable"), 'Una fila numérica cero cumple el atributo obligatorio y no debe dejar observaciones.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AtributoDeOtraClaseNoSeExigeAEntidadAdministrativa()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        AtributoBuque: Record "Tipo Atributo Liq.";
        AtributoAdmin: Record "Tipo Atributo Liq.";
        ClaseBuque: Record "Clase Entidad Liq.";
        ClaseAdmin: Record "Clase Entidad Liq.";
        Entidad: Record "Entidad Liq.";
        Proyecto: Record Job;
        CodigoEstado: Record "Cód. Estado Empleado";
        Estado: Record "Estado Empleado";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        ClaseBuque.Código := NuevoCodigo();
        ClaseBuque.Descripción := 'Buque de prueba';
        ClaseBuque.Insert(false);
        ClaseAdmin.Código := NuevoCodigo();
        ClaseAdmin.Descripción := 'Administración de prueba';
        ClaseAdmin.Insert(false);
        Entidad.Código := NuevoCodigo();
        Entidad."Cód. Clase" := ClaseAdmin.Código;
        Entidad.Insert(false);
        Proyecto."No." := NuevoCodigo();
        Proyecto."Global Dimension 1 Code" := Entidad.Código;
        Proyecto.Insert(false);
        CodigoEstado.Código := NuevoCodigo();
        CodigoEstado."Transcurre en Marea" := false;
        CodigoEstado.Insert(false);
        Estado."Tipo Entidad" := Estado."Tipo Entidad"::Empleado;
        Estado."No. Empleado" := Empleado;
        Estado."Cód. Estado" := CodigoEstado.Código;
        Estado."No. Proyecto" := Proyecto."No.";
        Estado."Fecha Inicio" := DMY2Date(1, 1, 2026);
        Estado.Insert(false);
        CrearTipoAtributo(AtributoBuque, AtributoBuque."Tipo Entidad"::Buque);
        AtributoBuque."Cód. Clase" := ClaseBuque.Código;
        AtributoBuque.Obligatorio := true;
        AtributoBuque.Modify(false);
        CrearTipoAtributo(AtributoAdmin, AtributoAdmin."Tipo Entidad"::Buque);
        AtributoAdmin."Cód. Clase" := ClaseAdmin.Código;
        AtributoAdmin.Modify(false);
        Concepto.Fórmula := AtributoBuque."Nombre Variable" + '+' + AtributoAdmin."Nombre Variable";
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, AtributoBuque."Nombre Variable"), 'Un atributo exclusivo de otra clase no debe exigirse al proyecto administrativo.');
        Assert(HayInformacionVariable(Buffer, AtributoAdmin."Nombre Variable"), 'El atributo opcional de la clase correcta sí debe quedar visible como información.');
        Buffer.Reset();
        Buffer.SetRange("Nombre Variable", AtributoAdmin."Nombre Variable");
        Buffer.FindFirst();
        Assert((Buffer."No. Proyecto" = Proyecto."No.") and (Buffer."Cód. Entidad" = Entidad.Código), 'La información debe conservar el proyecto y la entidad realmente resueltos.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AnalizarAgrupaConsumidoresSinPerderLaRevisionDirecta()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        ConceptoA: Record "Concepto Liquidación";
        ConceptoB: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
        Primera: Text;
    begin
        PrepararCaso(Periodo, Tipo, Empleado, ConceptoA);
        CrearParametro(Parametro);
        ConceptoA.Fórmula := Parametro."Nombre Variable";
        ConceptoA.Modify(false);
        ConceptoB := ConceptoA;
        ConceptoB.Código := NuevoCodigo();
        ConceptoB.Insert(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Buffer.Reset();
        Buffer.SetRange("Nombre Variable", Parametro."Nombre Variable");
        Assert(Buffer.Count() = 1, 'La captura del análisis debe agrupar una entrada ausente compartida por dos conceptos.');
        Buffer.FindFirst();
        Assert(Buffer.Severidad = Buffer.Severidad::Advertencia, 'Agrupar consumidores no debe ocultar la revisión del uso directo.');
        Assert(Buffer.Repeticiones = 2, 'Debe conservar las dos observaciones que originaron la fila agrupada.');
        Assert((StrPos(Buffer."Conceptos relacionados", ConceptoA.Código) > 0) and (StrPos(Buffer."Conceptos relacionados", ConceptoB.Código) > 0), 'Debe poder identificarse cada concepto consumidor desde el resultado agrupado.');
        Primera := ResumenBuffer(Buffer);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(ResumenBuffer(Buffer) = Primera, 'Revisar de nuevo debe reemplazar la captura, sin acumular consumidores o repeticiones.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FuenteIncompatibleAdviertePeroFiltroInvalidoSigueBloqueando()
    var
        Prevuelo: Codeunit "Prevuelo Fuentes Liq.";
        Fuente: Record "Fuente Datos Liquidación";
        Empleado: Record Employee;
        Concepto: Record "Concepto Liquidación";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Periodo: Code[10];
        Tipo: Code[20];
        CodigoEmpleado: Code[20];
        Motivo: Text;
        Bloqueante: Boolean;
        Valor: Decimal;
    begin
        PrepararCaso(Periodo, Tipo, CodigoEmpleado, Concepto);
        Fuente."Nombre Variable" := NuevoCodigo();
        Fuente."Id. Tabla" := Database::Employee;
        Fuente."No. Campo Valor" := Empleado.FieldNo("No.");
        Fuente."Tipo Dato" := Fuente."Tipo Dato"::Decimal;
        Fuente."Función Agregado" := Fuente."Función Agregado"::LOOKUP;
        Fuente.Activo := true;
        Fuente.Insert(false);
        Assert(not Prevuelo.ConfiguracionValida(Fuente, Motivo, Bloqueante), 'Un campo Code no debe aceptarse como valor decimal válido.');
        Assert(not Bloqueante, 'La conversión silenciosa a cero no demuestra por sí sola que la ejecución se bloquee.');
        Prevuelo.RevisarConfiguracion(DMY2Date(1, 1, 2026), DMY2Date(31, 1, 2026), Buffer);
        Buffer.SetRange("Nombre Fuente", Fuente."Nombre Variable");
        Buffer.SetRange(Severidad, Buffer.Severidad::Advertencia);
        Assert(Buffer.Count() = 0, 'Una incompatibilidad de conversión silenciosa sin lectores no debe generar una tarea operativa ficticia.');
        Concepto.Fórmula := Fuente."Nombre Variable";
        Concepto.Modify(false);
        Buffer.Reset();
        Buffer.DeleteAll();
        Prevuelo.RevisarConfiguracion(DMY2Date(1, 1, 2026), DMY2Date(31, 1, 2026), Buffer);
        Buffer.SetRange("Nombre Fuente", Fuente."Nombre Variable");
        Buffer.SetRange(Severidad, Buffer.Severidad::Advertencia);
        Assert(Buffer.Count() = 1, 'La misma incompatibilidad con un lector real sí debe conservar una revisión visible.');
        Assert(not Prevuelo.ResolverCotizacion(Fuente."Nombre Variable", 'USD', DMY2Date(31, 1, 2026), Valor, Motivo), 'Una incompatibilidad no bloqueante sigue siendo inválida para certificar una cotización.');
        Assert(Valor = 0, 'No debe devolver una cotización leída de un campo Code.');
        Concepto.Fórmula := '1';
        Concepto.Modify(false);
        CrearFiltro(Fuente."Nombre Variable", 1, 999999, 'X');
        Assert(not Prevuelo.ConfiguracionValida(Fuente, Motivo, Bloqueante), 'La validación debe continuar y detectar el filtro inválido.');
        Assert(Bloqueante, 'Un filtro inválido sí debe prevalecer como error bloqueante, aunque antes se haya encontrado un mismatch no bloqueante.');
        Buffer.Reset();
        Buffer.DeleteAll();
        Prevuelo.RevisarConfiguracion(DMY2Date(1, 1, 2026), DMY2Date(31, 1, 2026), Buffer);
        Buffer.SetRange("Nombre Fuente", Fuente."Nombre Variable");
        Buffer.SetRange(Severidad, Buffer.Severidad::Error);
        Assert(Buffer.Count() = 1, 'El diagnóstico no puede degradar el filtro inválido a la advertencia anterior.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ListaMantieneCodigoYNumeroParaElegirLaRama()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Atributo: Record "Tipo Atributo Liq.";
        Valor: Record "Valor Atributo Liq.";
        Precio: Record "Parámetro";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CrearParametro(Precio);
        CrearTipoAtributo(Atributo, Atributo."Tipo Entidad"::Empleado);
        Atributo."Tipo Dato" := Atributo."Tipo Dato"::Lista;
        Atributo.Modify(false);
        Valor."Cód. Tipo Atributo" := Atributo.Código;
        Valor.Código := 'PO';
        Valor."Valor Numérico" := 1;
        Valor.Insert(false);
        // El motor lee la proyección numérica congelada de la asignación, no convierte el código PO.
        CrearAtributo(Atributo.Código, Atributo."Tipo Entidad", Empleado, DMY2Date(1, 1, 2026), 0D, 'PO', 1);
        Concepto.Fórmula := 'IF(' + Atributo."Nombre Variable" + '=1,1,' + Precio."Nombre Variable" + ')';
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Precio."Nombre Variable"), 'La lista PO con proyección numérica uno debe descartar el precio situado sólo en la rama ELSE de la comparación numérica.');

        Concepto.Fórmula := 'IF(' + Atributo."Nombre Variable" + '=''PO'',1,' + Precio."Nombre Variable" + ')';
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Precio."Nombre Variable"), 'La misma lista debe conservar PO para comparar códigos, sin sustituirlo por el texto del número uno.');

        Concepto.Fórmula := 'IF(' + Atributo."Nombre Variable" + '=2,1,' + Precio."Nombre Variable" + ')';
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayAdvertenciaVariable(Buffer, Precio."Nombre Variable"), 'Una comparación numérica falsa debe mantener visible el precio que ahora sí pertenece a la rama elegida.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SelectorCompuestoNoOcultaUsosDirectosNiFuentesInactivas()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Selector: Record "Parámetro";
        Precio: Record "Parámetro";
        Fuente: Record "Fuente Datos Liquidación";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CrearParametro(Selector);
        CrearParametro(Precio);
        Concepto.Fórmula := 'IF(' + Selector."Nombre Variable" + '=0 AND CP_FLAG>0,' + Precio."Nombre Variable" + ',0)';
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Selector."Nombre Variable"), 'Un parámetro utilizado sólo como selector con cero admitido dentro de AND no debe generar un pendiente.');
        Assert(not HayAdvertenciaVariable(Buffer, Selector."Nombre Variable"), 'La incertidumbre del otro operando no convierte el selector en un precio obligatorio.');
        Assert(HayAdvertenciaVariable(Buffer, Precio."Nombre Variable"), 'No debe asumir el valor del otro operando ni ocultar el precio de una rama todavía posible.');

        Concepto.Fórmula := 'IF(' + Selector."Nombre Variable" + '=0 OR CP_FLAG>0,1,0)';
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Selector."Nombre Variable"), 'El selector con cero admitido dentro de OR tampoco debe generar un pendiente, sin suponer cortocircuito.');

        Concepto.Fórmula += '+' + Selector."Nombre Variable";
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayAdvertenciaVariable(Buffer, Selector."Nombre Variable"), 'Un uso de importe fuera del IF debe seguir visible aunque el mismo dato participe en un selector protegido.');

        Fuente."Nombre Variable" := NuevoCodigo();
        Fuente."Id. Tabla" := Database::Employee;
        Fuente."Función Agregado" := Fuente."Función Agregado"::COUNT;
        Fuente.Activo := false;
        Fuente.Insert(false);
        Concepto.Fórmula := 'IF(' + Fuente."Nombre Variable" + '=0 AND CP_FLAG>0,1,0)';
        Concepto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayErrorVariable(Buffer, Fuente."Nombre Variable"), 'La excepción del parámetro sin fila no convierte una fuente inactiva en un selector disponible ni oculta su error.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AgruparAtributoConservaErrorLectoresYDistintasCausas()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Fila: Record "Control Previo Liq. Buffer" temporary;
        Primera: Text;
    begin
        ExigirEmpresaTest();
        PrepararFilaAgrupacion(Fila);
        Fila.Área := 'Atributos';
        Fila."Cód. Parámetro" := '';
        Fila."Clave Parámetro" := '';
        Fila."Cód. Tipo Atributo" := 'CP_ATR';
        Fila."No. Línea" := 1;
        Fila."Cód. Concepto" := 'CP_C1';
        Buffer := Fila;
        Buffer.Insert();
        Fila."No. Línea" := 2;
        Fila."Cód. Concepto" := 'CP_C2';
        Fila.Severidad := Fila.Severidad::Error;
        Fila.Repeticiones := 2;
        Fila."Conceptos relacionados" := 'CP_C2|CP_C3';
        Buffer := Fila;
        Buffer.Insert();
        Fila."No. Línea" := 3;
        Fila."Cód. Concepto" := 'CP_C4';
        Fila.Severidad := Fila.Severidad::Advertencia;
        Fila.Repeticiones := 1;
        Fila."Conceptos relacionados" := '';
        Fila.Detalle := 'Otra causa del mismo atributo';
        Buffer := Fila;
        Buffer.Insert();

        Control.AgruparResultados(Buffer);
        Buffer.Reset();
        Assert(Buffer.Count() = 2, 'El mismo atributo y alcance puede compartir una causa, pero una causa diferente debe conservar su fila independiente.');
        Buffer.SetRange(Detalle, 'Misma causa');
        Assert(Buffer.Count() = 1, 'La advertencia y el error de la misma ausencia deben agruparse sin ocultar lectores.');
        Buffer.FindFirst();
        Assert(Buffer.Severidad = Buffer.Severidad::Error, 'La severidad máxima debe prevalecer cuando un atributo obligatorio comparte lectores condicionales.');
        Assert(Buffer.Repeticiones = 3, 'La agrupación debe conservar una ocurrencia legacy y las dos ya agregadas, sin sumar la causa diferente.');
        Assert((StrPos(Buffer."Conceptos relacionados", 'CP_C1') > 0) and (StrPos(Buffer."Conceptos relacionados", 'CP_C2') > 0) and (StrPos(Buffer."Conceptos relacionados", 'CP_C3') > 0), 'El error agrupado debe conservar todos sus lectores.');
        Assert(StrPos(Buffer."Conceptos relacionados", 'CP_C4') = 0, 'El lector de otra causa no pertenece a esta observación.');
        Buffer.SetRange(Detalle, 'Otra causa del mismo atributo');
        Buffer.FindFirst();
        Assert((Buffer.Severidad = Buffer.Severidad::Advertencia) and (Buffer.Repeticiones = 1), 'La severidad y la cuenta de la causa diferente deben conservarse.');
        Primera := ResumenBuffer(Buffer);
        Control.AgruparResultados(Buffer);
        Assert(ResumenBuffer(Buffer) = Primera, 'Agrupar otra vez no puede duplicar repeticiones ni perder la severidad máxima o los lectores.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure VistaPredeterminadaConservaErroresSinBorrarDiagnosticos()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Fila: Record "Control Previo Liq. Buffer" temporary;
        Vista: Integer;
        Numero: Integer;
        Antes: Text;
    begin
        ExigirEmpresaTest();
        for Numero := 1 to 3 do begin
            PrepararFilaAgrupacion(Fila);
            Fila."No. Línea" := Numero;
            case Numero of
                1: Fila.Severidad := Fila.Severidad::Error;
                2: Fila.Severidad := Fila.Severidad::Advertencia;
                3: Fila.Severidad := Fila.Severidad::Información;
            end;
            Buffer := Fila;
            Buffer.Insert();
        end;
        Antes := ResumenBuffer(Buffer);
        Control.FiltrarVista(Buffer, Vista);
        Assert(Buffer.Count() = 1, 'El perfil cero por defecto sólo debe mostrar errores operativos, sin reclasificar ni borrar avisos.');
        Buffer.FindFirst();
        Assert(Buffer.Severidad = Buffer.Severidad::Error, 'La vista inicial debe conservar el error comprobado.');
        Control.FiltrarVista(Buffer, 1);
        Assert(Buffer.Count() = 2, 'El perfil de revisión debe mostrar errores y advertencias sin arrastrar información.');
        Control.FiltrarVista(Buffer, 2);
        Assert(Buffer.Count() = 3, 'El diagnóstico completo debe recuperar la información original.');
        Assert(ResumenBuffer(Buffer) = Antes, 'Alternar perfiles debe conservar todas las severidades, mensajes, alcances y repeticiones originales.');
        Control.FiltrarVista(Buffer, 0);
        Assert(Buffer.Count() = 1, 'Volver al perfil inicial no puede dejar el filtro de la vista completa ni duplicar filas.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure VistaIntersecaFiltrosUsuarioYConservaGrupoOriginal()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Fila: Record "Control Previo Liq. Buffer" temporary;
        Numero: Integer;
        FiltrosUsuario: Text;
        FiltrosEnlace: Text;
    begin
        ExigirEmpresaTest();
        for Numero := 1 to 4 do begin
            PrepararFilaAgrupacion(Fila);
            Fila."No. Línea" := Numero;
            Fila."No. Empleado" := 'CP_EMP_A';
            case Numero of
                1: Fila.Severidad := Fila.Severidad::Error;
                2:
                    begin
                        Fila.Severidad := Fila.Severidad::Error;
                        Fila."No. Empleado" := 'CP_EMP_B';
                    end;
                3: Fila.Severidad := Fila.Severidad::Advertencia;
                4: Fila.Severidad := Fila.Severidad::Información;
            end;
            Buffer := Fila;
            Buffer.Insert();
        end;
        Buffer.FilterGroup(0);
        Buffer.SetRange("No. Empleado", 'CP_EMP_A');
        Buffer.SetRange(Severidad, Buffer.Severidad::Información);
        FiltrosUsuario := Buffer.GetFilters();
        Buffer.FilterGroup(4);
        Buffer.SetRange("No. Proyecto", 'CP_PROY');
        FiltrosEnlace := Buffer.GetFilters();
        Control.FiltrarVista(Buffer, 0);
        Assert(Buffer.FilterGroup() = 4, 'La selección de vista debe devolver el grupo de filtros que tenía el llamador.');
        Assert(Buffer.GetFilters() = FiltrosEnlace, 'El filtro de enlace debe conservarse completo.');
        Assert(Buffer.Count() = 0, 'La vista de errores y el filtro de información del usuario deben intersectarse, sin ampliar el alcance para inventar coincidencias.');
        Buffer.FilterGroup(0);
        Assert(Buffer.GetFilters() = FiltrosUsuario, 'El perfil no puede reemplazar los filtros visibles del usuario.');
        Buffer.FilterGroup(4);
        Control.FiltrarVista(Buffer, 1);
        Assert(Buffer.Count() = 0, 'El perfil de revisión tampoco debe borrar el filtro explícito de información del usuario.');
        Control.FiltrarVista(Buffer, 2);
        Assert(Buffer.FilterGroup() = 4, 'La vista completa también conserva el grupo actual.');
        Assert(Buffer.Count() = 1, 'Quitar sólo el filtro de perfil debe respetar empleado, severidad de usuario y proyecto.');
        Buffer.FindFirst();
        Assert((Buffer."No. Línea" = 4) and (Buffer."No. Empleado" = 'CP_EMP_A'), 'La vista completa no puede mostrar un empleado excluido por el usuario.');
        Buffer.FilterGroup(0);
        Assert(Buffer.GetFilters() = FiltrosUsuario, 'Todos los perfiles deben dejar intacto el filtro original del usuario.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure FuenteActivaInvalidaSinLectoresConservaErrorOperativo()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Fuente: Record "Fuente Datos Liquidación";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        Fuente."Nombre Variable" := NuevoCodigo();
        Fuente."Id. Tabla" := Database::Employee;
        Fuente."Función Agregado" := Fuente."Función Agregado"::COUNT;
        Fuente.Activo := true;
        Fuente.Insert(false);
        CrearFiltro(Fuente."Nombre Variable", 1, 999999, 'X');
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Buffer.Reset();
        Buffer.SetRange("Nombre Fuente", Fuente."Nombre Variable");
        Buffer.SetRange(Severidad, Buffer.Severidad::Error);
        Assert(Buffer.Count() = 1, 'Un campo de filtro inexistente en una fuente activa sigue siendo un fallo estructural aunque ningún concepto lea su nombre.');
        Control.FiltrarVista(Buffer, 0);
        Assert(Buffer.Count() = 1, 'El perfil operativo no puede esconder el error comprobado de una fuente activa por no tener consumidores léxicos.');
        Fuente.Activo := false;
        Fuente.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Buffer.Reset();
        Buffer.SetRange("Nombre Fuente", Fuente."Nombre Variable");
        Assert(Buffer.Count() = 0, 'Una fuente inactiva y no referida no debe inventar un bloqueo al reconstruir la captura.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure InformeXmlRespetaVistaYFiltroSinReanalizarCaptura()
    var
        Control: Codeunit "Control Previo Liq.";
        Informe: Report "Preparación de Liquidaciones";
        Blob: Codeunit "Temp Blob";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Copia: Record "Control Previo Liq. Buffer" temporary;
        Fila: Record "Control Previo Liq. Buffer" temporary;
        Periodo: Record "Período Liquidación";
        CodigoPeriodo: Code[10];
        Salida: OutStream;
        Xml: Text;
        Antes: Text;
        FiltroUsuario: Text;
        FiltroPerfil: Text;
        Numero: Integer;
        PosicionMensaje: Integer;
    begin
        ExigirEmpresaTest();
        CodigoPeriodo := CopyStr(NuevoCodigo(), 1, MaxStrLen(CodigoPeriodo));
        Assert(not Periodo.Get(CodigoPeriodo), 'El período inexistente de la captura debe hacer fallar cualquier intento accidental de reanalizar.');
        for Numero := 1 to 4 do begin
            PrepararFilaAgrupacion(Fila);
            Fila."No. Línea" := Numero;
            Fila.Área := 'CP_XML_VISIBLE';
            case Numero of
                1:
                    begin
                        Fila.Severidad := Fila.Severidad::Error;
                        Fila.Mensaje := 'CP_XML_VISIBLE_ERROR';
                    end;
                2:
                    begin
                        Fila.Severidad := Fila.Severidad::Advertencia;
                        Fila.Mensaje := 'CP_XML_WARNING';
                    end;
                3:
                    begin
                        Fila.Severidad := Fila.Severidad::Información;
                        Fila.Mensaje := 'CP_XML_INFO';
                    end;
                4:
                    begin
                        Fila.Severidad := Fila.Severidad::Error;
                        Fila.Área := 'CP_XML_EXCLUIDA';
                        Fila.Mensaje := 'CP_XML_ERROR_EXCLUIDO';
                    end;
            end;
            Buffer := Fila;
            Buffer.Insert();
        end;
        Antes := ResumenBuffer(Buffer);
        Buffer.SetRange(Área, 'CP_XML_VISIBLE');
        FiltroUsuario := Buffer.GetFilters();
        Control.FiltrarVista(Buffer, 0);
        Buffer.FilterGroup(2);
        FiltroPerfil := Buffer.GetFilters();
        Buffer.FilterGroup(0);
        Assert(Buffer.Count() = 1, 'La captura de partida debe tener sólo el error del área elegida visible.');
        Informe.SetVista(0);
        Informe.SetBuffer(Buffer, CodigoPeriodo, '', '', '', CurrentDateTime());
        Blob.CreateOutStream(Salida, TextEncoding::UTF8);
        Assert(Informe.SaveAs('', ReportFormat::Xml, Salida), 'El informe debe generar su dataset XML desde la captura temporal en memoria.');
        Xml := LeerXmlTemporal(Blob);
        PosicionMensaje := StrPos(Xml, 'CP_XML_VISIBLE_ERROR');
        Assert(PosicionMensaje > 0, 'El dataset impreso debe conservar el error visible de la captura recibida.');
        Assert(StrPos(CopyStr(Xml, PosicionMensaje + StrLen('CP_XML_VISIBLE_ERROR')), 'CP_XML_VISIBLE_ERROR') = 0, 'La captura no debe duplicar el único mensaje de error visible.');
        Assert((StrPos(Xml, 'CP_XML_WARNING') = 0) and (StrPos(Xml, 'CP_XML_INFO') = 0), 'Imprimir la vista de errores no puede recuperar advertencias ni información ocultas.');
        Assert(StrPos(Xml, 'CP_XML_ERROR_EXCLUIDO') = 0, 'SetBuffer no puede quitar el filtro del usuario y recuperar errores de otra área.');
        Assert(Buffer.FilterGroup() = 0, 'Imprimir no debe cambiar el grupo de filtros del origen.');
        Assert(Buffer.GetFilters() = FiltroUsuario, 'Imprimir no puede modificar el filtro visible del usuario.');
        Buffer.FilterGroup(2);
        Assert(Buffer.GetFilters() = FiltroPerfil, 'El perfil del grupo dos debe conservarse en la captura original.');
        Buffer.FilterGroup(0);
        Assert(Buffer.Count() = 1, 'La captura original debe seguir mostrando exactamente la misma fila.');
        Copia.Copy(Buffer, true);
        Assert(ResumenBuffer(Copia) = Antes, 'La generación del XML no puede borrar, insertar ni reclasificar los datos temporales de origen.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure InformeXmlVacioMuestraResumenSinRecuperarFilasOcultas()
    var
        Control: Codeunit "Control Previo Liq.";
        Informe: Report "Preparación de Liquidaciones";
        Blob: Codeunit "Temp Blob";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Copia: Record "Control Previo Liq. Buffer" temporary;
        Fila: Record "Control Previo Liq. Buffer" temporary;
        Periodo: Record "Período Liquidación";
        CodigoPeriodo: Code[10];
        Salida: OutStream;
        Xml: Text;
        Antes: Text;
        FiltroUsuario: Text;
        FiltroPerfil: Text;
        Numero: Integer;
    begin
        ExigirEmpresaTest();
        CodigoPeriodo := CopyStr(NuevoCodigo(), 1, MaxStrLen(CodigoPeriodo));
        Assert(not Periodo.Get(CodigoPeriodo), 'El informe debe usar el buffer incluso cuando el período no existe en la configuración.');
        for Numero := 1 to 2 do begin
            PrepararFilaAgrupacion(Fila);
            Fila."No. Línea" := Numero;
            Fila.Área := 'CP_XML_RESUMEN';
            if Numero = 1 then begin
                Fila.Severidad := Fila.Severidad::Advertencia;
                Fila.Mensaje := 'CP_XML_RESUMEN_WARNING';
            end else begin
                Fila.Severidad := Fila.Severidad::Información;
                Fila.Mensaje := 'CP_XML_RESUMEN_INFO';
            end;
            Buffer := Fila;
            Buffer.Insert();
        end;
        Antes := ResumenBuffer(Buffer);
        Buffer.SetRange(Área, 'CP_XML_RESUMEN');
        FiltroUsuario := Buffer.GetFilters();
        Control.FiltrarVista(Buffer, 0);
        Buffer.FilterGroup(2);
        FiltroPerfil := Buffer.GetFilters();
        Buffer.FilterGroup(0);
        Assert(Buffer.IsEmpty(), 'La captura de partida no debe tener errores visibles.');
        Informe.SetVista(0);
        Informe.SetBuffer(Buffer, CodigoPeriodo, '', '', '', CurrentDateTime());
        Blob.CreateOutStream(Salida, TextEncoding::UTF8);
        Assert(Informe.SaveAs('', ReportFormat::Xml, Salida), 'Una vista vacía debe producir un XML de resumen, sin ejecutar de nuevo el control.');
        Xml := LeerXmlTemporal(Blob);
        Assert(StrPos(Xml, 'No se detectaron errores comprobados') > 0, 'El resumen debe salir aunque el filtro de severidad oculte toda fila de diagnóstico.');
        Assert((StrPos(Xml, 'CP_XML_RESUMEN_WARNING') = 0) and (StrPos(Xml, 'CP_XML_RESUMEN_INFO') = 0), 'El resumen vacío no puede recuperar las revisiones o información excluidas por el perfil.');
        Assert(Buffer.FilterGroup() = 0, 'El informe vacío debe conservar el grupo original del llamador.');
        Assert(Buffer.GetFilters() = FiltroUsuario, 'La fila de presentación no debe eliminar el filtro de área de la captura original.');
        Buffer.FilterGroup(2);
        Assert(Buffer.GetFilters() = FiltroPerfil, 'El resumen debe dejar intacto el perfil de errores del origen.');
        Buffer.FilterGroup(0);
        Assert(Buffer.IsEmpty(), 'La inserción del resumen de impresión no puede aparecer en la captura original.');
        Copia.Copy(Buffer, true);
        Assert(ResumenBuffer(Copia) = Antes, 'Las dos filas ocultas deben conservarse sin una fila de resumen añadida al buffer de origen.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ReglaVigenciaSinLectorVenceEnMarzoYAbril()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Version: Record "Parámetro Vigente";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CrearParametroConRegla(Parametro, '<-30D>');
        CrearVersion(Parametro.Código, DMY2Date(1, 1, 2026), 10, '', '', '', '', Version);
        Assert(Concepto.Fórmula = '1', 'La regla debe inspeccionarse sin inventar un lector léxico del parámetro.');
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Parametro."Nombre Variable"), 'El valor del 1 de enero está exactamente en el límite del 31 de enero y no está vencido.');
        CambiarMesPeriodo(Periodo, 3);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayErrorVariable(Buffer, Parametro."Nombre Variable"), 'Marzo debe mostrar el incumplimiento de su regla de vigencia en la vista de errores.');
        Assert(Buffer.FindFirst(), 'El error de marzo debe conservar su fila de evidencia.');
        Assert((Buffer."Clave Parámetro" = Version."Cód. Parámetro") and (Buffer."Vigencia Desde" = Version."Vigencia Desde"), 'El diagnóstico debe identificar la fila física seleccionada.');
        CambiarMesPeriodo(Periodo, 4);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayErrorVariable(Buffer, Parametro."Nombre Variable"), 'Abril también debe inspeccionar la regla aunque la fórmula del concepto no cambie.');
        Buffer.Reset();
        Buffer.SetRange("Nombre Variable", Parametro."Nombre Variable");
        Assert(Buffer.FindFirst(), 'Debe conservarse la evidencia de abril.');
        Assert(Buffer."Fecha Hasta" = DMY2Date(30, 4, 2026), 'La captura no puede arrastrar las fechas del período anterior.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ReglaVigenciaCeroEnLimiteEsDatoVigente()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Version: Record "Parámetro Vigente";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CambiarMesPeriodo(Periodo, 3);
        CrearParametroConRegla(Parametro, '<-30D>');
        CrearVersion(Parametro.Código, DMY2Date(1, 1, 2026), 10, '', '', '', '', Version);
        CrearVersion(Parametro.Código, DMY2Date(1, 3, 2026), 0, '', '', '', '', Version);
        CrearVersion(Parametro.Código, DMY2Date(1, 4, 2026), 20, '', '', '', '', Version);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Parametro."Nombre Variable"), 'La fila con cero del límite exacto resuelve marzo; ni el cero ni una versión futura la vuelven ausente.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ReglaVigenciaSoloFuturoNoCompletaMarzo()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Version: Record "Parámetro Vigente";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CrearParametroConRegla(Parametro, '<-30D>');
        CrearVersion(Parametro.Código, DMY2Date(1, 4, 2026), 0, '', '', '', '', Version);
        CambiarMesPeriodo(Periodo, 3);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayErrorVariable(Buffer, Parametro."Nombre Variable"), 'Una fila únicamente futura no acredita valor vigente para marzo.');
        CambiarMesPeriodo(Periodo, 4);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Parametro."Nombre Variable"), 'Al llegar abril la fila existe, su cero es válido y debe desaparecer el faltante anterior.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ReglaVigenciaSinFilasEsErrorAunqueNadieLaLea()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CrearParametroConRegla(Parametro, '<-1M>');
        CambiarMesPeriodo(Periodo, 3);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(ContarErroresParametro(Buffer, Parametro.Código) = 1, 'La regla explícita sin ninguna fila debe producir un solo error de base, aun sin lector directo.');
        Control.FiltrarVista(Buffer, 0);
        Assert(not Buffer.IsEmpty(), 'El faltante acreditado por la regla debe ser visible en la vista inicial.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ReglaVigenciaNoExigeUnaClaveDeOtroEmpleado()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Version: Record "Parámetro Vigente";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CrearParametroConRegla(Parametro, '<-1M>');
        CrearVersion(Parametro.Código, DMY2Date(1, 1, 2026), 10, NuevoCodigo(), '', '', '', Version);
        CambiarMesPeriodo(Periodo, 3);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Parametro."Nombre Variable"), 'Tener una regla no convierte una clave exclusiva de otro empleado en una carga exigida al candidato.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ReglaVigenciaResuelveLaGenericaMasReciente()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Version: Record "Parámetro Vigente";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CrearParametroConRegla(Parametro, '<-30D>');
        CrearVersion(Parametro.Código, DMY2Date(1, 1, 2026), 10, Empleado, '', '', '', Version);
        CrearVersion(Parametro.Código, DMY2Date(1, 3, 2026), 0, '', '', '', '', Version);
        CambiarMesPeriodo(Periodo, 3);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Parametro."Nombre Variable"), 'La genérica más reciente vence a la específica anterior; inspeccionar la fila vieja daría un error falso.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ReglaVigenciaQueAvanzaEsErrorDeConfiguracion()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Version: Record "Parámetro Vigente";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        // Una carga histórica/directa pudo omitir OnValidate: el informe no debe silenciarla.
        CrearParametroConRegla(Parametro, '<1M>');
        CrearVersion(Parametro.Código, DMY2Date(1, 1, 2026), 0, '', '', '', '', Version);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(ContarErroresParametro(Buffer, Parametro.Código) = 1, 'Una fecha límite futura es configuración inválida, no un faltante repetido por empleado.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ReglaVigenciaAnclaIgualALaFechaEsAdmitida()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Version: Record "Parámetro Vigente";
        RegistroPeriodo: Record "Período Liquidación";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        RegistroPeriodo.Get(Periodo);
        RegistroPeriodo."Fecha Desde" := DMY2Date(1, 3, 2026);
        RegistroPeriodo."Fecha Hasta" := DMY2Date(1, 3, 2026);
        RegistroPeriodo.Modify(false);
        CrearParametroConRegla(Parametro, '<-CM>');
        CrearVersion(Parametro.Código, DMY2Date(1, 3, 2026), 0, '', '', '', '', Version);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Parametro."Nombre Variable"), 'Una fórmula anclada al comienzo del mes puede devolver la misma fecha y la fila de ese día cumple la regla.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AusenciaSinReglaDeFechaSigueSiendoRevision()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CrearParametro(Parametro);
        Concepto.Fórmula := Parametro."Nombre Variable";
        Concepto.Modify(false);
        CambiarMesPeriodo(Periodo, 3);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayAdvertenciaVariable(Buffer, Parametro."Nombre Variable"), 'Sin obligatoriedad temporal explícita, la ausencia directa conserva la revisión de aplicación.');
        Assert(not HayErrorVariable(Buffer, Parametro."Nombre Variable"), 'La corrección de fechas no debe volver errores todas las entradas opcionales.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ReglaVigenciaAgrupaClaveSinMezclarOtroAlcance()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Version: Record "Parámetro Vigente";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
        SegundoEmpleado: Code[20];
        TercerEmpleado: Code[20];
        ClavePersonal: Code[50];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        SegundoEmpleado := CrearEmpleadoDelCaso();
        TercerEmpleado := CrearEmpleadoDelCaso();
        CrearParametroConRegla(Parametro, '<-1M>');
        CrearVersion(Parametro.Código, DMY2Date(1, 1, 2026), 10, '', '', '', '', Version);
        CrearVersion(Parametro.Código, DMY2Date(1, 1, 2026), 20, TercerEmpleado, '', '', '', Version);
        ClavePersonal := Version."Cód. Parámetro";
        CambiarMesPeriodo(Periodo, 3);
        Control.Analizar(Periodo, Tipo, Empleado + '|' + SegundoEmpleado + '|' + TercerEmpleado, '', Buffer);
        Assert(ContarErroresParametro(Buffer, Parametro.Código) = 2, 'Dos lectores de la misma fila genérica son una tarea; otra clave física es otra tarea.');
        Buffer.SetRange("Clave Parámetro", ClavePersonal);
        Assert(Buffer.FindFirst(), 'La corrección específica debe conservar una fila separada.');
        Assert(Buffer."No. Empleado" = TercerEmpleado, 'El alcance de la tarea es el de la fila de parámetro, no el primer candidato que se recorrió.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ReglaVigenciaNoEscribeYSeReiniciaEntrePeriodos()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Version: Record "Parámetro Vigente";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
        Conteos: Text;
        RevisionConcepto: BigInteger;
        RevisionParametro: BigInteger;
        RevisionVersion: BigInteger;
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CrearParametroConRegla(Parametro, '<-30D>');
        CrearVersion(Parametro.Código, DMY2Date(1, 1, 2026), 10, '', '', '', '', Version);
        Concepto.Get(Concepto.Código, Concepto."Vigencia Desde");
        Parametro.Get(Parametro.Código);
        Version.Get(Version."Cód. Parámetro Base", Version."Cód. Parámetro", Version."Vigencia Desde");
        RevisionConcepto := Concepto.SystemRowVersion;
        RevisionParametro := Parametro.SystemRowVersion;
        RevisionVersion := Version.SystemRowVersion;
        Conteos := CapturarConteos();
        CambiarMesPeriodo(Periodo, 3);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(HayErrorVariable(Buffer, Parametro."Nombre Variable"), 'La primera captura debe incluir la vigencia vencida.');
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(ContarErroresParametro(Buffer, Parametro.Código) = 1, 'Repetir la inspección no duplica la tarea ni conserva deduplicadores de otra captura.');
        CambiarMesPeriodo(Periodo, 1);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Parametro."Nombre Variable"), 'Volver a enero debe quitar el vencimiento de marzo.');
        Assert(CapturarConteos() = Conteos, 'El control no debe crear recibos, líneas, usos, incidencias ni procesos.');
        Concepto.Get(Concepto.Código, Concepto."Vigencia Desde");
        Parametro.Get(Parametro.Código);
        Version.Get(Version."Cód. Parámetro Base", Version."Cód. Parámetro", Version."Vigencia Desde");
        Assert((Concepto.SystemRowVersion = RevisionConcepto) and (Parametro.SystemRowVersion = RevisionParametro), 'La revisión no puede cambiar fórmulas ni reglas del catálogo.');
        Assert((Version.SystemRowVersion = RevisionVersion) and not Version."En Uso", 'Consultar la vigencia no modifica el valor ni lo marca usado.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ReglaVigenciaDistingueEjesAlFinYALaBaja()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Version: Record "Parámetro Vigente";
        Eje: Record "Tipo Atributo Liq.";
        Valor: Record "Valor Atributo Liq.";
        Fase: Record "Fase Alta Empleado";
        TipoOriginal: Record "Tipo Liquidación";
        TipoAdicional: Record "Tipo Liquidación";
        Primero: Record "Tipo Liquidación";
        Segundo: Record "Tipo Liquidación";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
        ClaveBaja: Code[50];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CambiarMesPeriodo(Periodo, 3);
        Fase.Get(Empleado, 1);
        Fase."Fecha Baja" := DMY2Date(15, 3, 2026);
        Fase.Modify(false);
        CrearTipoAtributo(Eje, "Tipo Entidad Estado"::Empleado);
        Eje."Tipo Dato" := Eje."Tipo Dato"::Lista;
        Eje.Modify(false);
        Valor."Cód. Tipo Atributo" := Eje.Código;
        Valor.Código := 'ANT';
        Valor."Sufijo Parámetro" := 'ANT';
        Valor.Insert(false);
        Valor.Init();
        Valor."Cód. Tipo Atributo" := Eje.Código;
        Valor.Código := 'NUE';
        Valor."Sufijo Parámetro" := 'NUE';
        Valor.Insert(false);
        CrearAtributo(Eje.Código, "Tipo Entidad Estado"::Empleado, Empleado, DMY2Date(1, 1, 2026), DMY2Date(15, 3, 2026), 'ANT', 1);
        CrearAtributo(Eje.Código, "Tipo Entidad Estado"::Empleado, Empleado, DMY2Date(16, 3, 2026), 0D, 'NUE', 2);
        CrearParametroConRegla(Parametro, '<-1M>');
        Parametro."Cód. Tipo Atributo 1" := Eje.Código;
        Parametro.Modify(false);
        CrearVersion(Parametro.Código, DMY2Date(1, 1, 2026), 10, '', '', '', 'ANT', Version);
        ClaveBaja := Version."Cód. Parámetro";
        CrearVersion(Parametro.Código, DMY2Date(1, 3, 2026), 0, '', '', '', 'NUE', Version);
        TipoOriginal.Get(Tipo);
        TipoAdicional.Código := NuevoCodigo();
        TipoAdicional.Activo := true;
        TipoAdicional."Agrupa por Empleado" := true;
        TipoAdicional."Entra en Corrida Completa" := true;
        TipoAdicional.Insert(false);
        // FindSet recorre por código: probar mensual antes de final y después al revés.
        if TipoOriginal.Código < TipoAdicional.Código then begin
            Primero := TipoOriginal;
            Segundo := TipoAdicional;
        end else begin
            Primero := TipoAdicional;
            Segundo := TipoOriginal;
        end;
        Primero.Disparador := Primero.Disparador::Ninguno;
        Primero.Modify(false);
        Segundo.Disparador := Segundo.Disparador::BajaEmpleado;
        Segundo.Modify(false);
        Control.Analizar(Periodo, '', Empleado, '', Buffer);
        Assert(ContarErroresParametro(Buffer, Parametro.Código) = 1, 'El mensual resuelve el eje nuevo vigente, pero no puede ocultar la fila vencida que la final elige al día de baja.');
        Assert(Buffer.FindFirst(), 'Debe conservar la evidencia de la fila elegida por la final.');
        Assert(Buffer."Clave Parámetro" = ClaveBaja, 'La regla incumplida corresponde al eje de la baja, no al eje posterior del fin de mes.');
        Primero.Disparador := Primero.Disparador::BajaEmpleado;
        Primero.Modify(false);
        Segundo.Disparador := Segundo.Disparador::Ninguno;
        Segundo.Modify(false);
        Control.Analizar(Periodo, '', Empleado, '', Buffer);
        Assert(ContarErroresParametro(Buffer, Parametro.Código) = 1, 'La captura debe ser igual al inspeccionar primero la final: ni el orden de tipos ni una caché anterior cambian el diagnóstico.');
        Assert(Buffer.FindFirst(), 'El segundo recorrido también debe conservar su fila de evidencia.');
        Assert(Buffer."Clave Parámetro" = ClaveBaja, 'Repetir en otro orden debe seguir señalando la misma clave física.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ReglaVigenciaAdmiteFilaGenericaLegacyConCero()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Concepto: Record "Concepto Liquidación";
        Parametro: Record "Parámetro";
        Version: Record "Parámetro Vigente";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        CambiarMesPeriodo(Periodo, 3);
        CrearParametroConRegla(Parametro, '<-30D>');
        Version."Cód. Parámetro Base" := '';
        Version."Cód. Parámetro" := Parametro.Código;
        Version."Vigencia Desde" := DMY2Date(1, 3, 2026);
        Version.Valor := 0;
        Version.Insert(false);
        Control.Analizar(Periodo, Tipo, Empleado, '', Buffer);
        Assert(not HayVariable(Buffer, Parametro."Nombre Variable"), 'La fila genérica histórica sin base explícita resuelve el parámetro; no puede informarse una ausencia total de versiones.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure MareaCandidataSinNominaEsRevisionOpcionalDeProyecto()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Proyecto: Record Job;
        Personal: Record "Personal Proyecto";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
        SegundoEmpleado: Code[20];
        Conteos: Text;
    begin
        PrepararMareaCandidata(Periodo, Tipo, Empleado, Proyecto);
        SegundoEmpleado := CrearEmpleadoDelCaso();
        Personal."No. Empleado" := SegundoEmpleado;
        Personal."No. Proyecto" := Proyecto."No.";
        Personal."Fecha Alta Asignación" := DMY2Date(1, 1, 2026);
        Personal.Insert(false);
        Conteos := CapturarConteos();
        Control.Analizar(Periodo, Tipo, Empleado + '|' + SegundoEmpleado, Proyecto."No.", Buffer);
        FiltrarProyectoNomina(Buffer, Proyecto."No.");
        Assert(Buffer.Count() = 1, 'Dos empleados de la misma marea deben dejar una sola tarea de configuración.');
        Buffer.FindFirst();
        Assert(Buffer.Severidad = Buffer.Severidad::Advertencia, 'Una eventual transición de estados requiere contexto; no prueba un error del cálculo de la marea.');
        Assert((Buffer."No. Empleado" = '') and (Buffer."Cód. Tipo Liq." = ''), 'El dato pertenece al proyecto, no al primer empleado o tipo inspeccionado.');
        Assert((Buffer."Tipo Entidad" = Buffer."Tipo Entidad"::Proyecto) and (Buffer."Cód. Entidad" = Proyecto."No."), 'La fila debe conservar la clave que permite abrir la ficha del proyecto.');
        Assert(CapturarConteos() = Conteos, 'La revisión no crea recibos, incidencias, consumos ni marcas de uso.');
        Control.FiltrarVista(Buffer, 0);
        Assert(Buffer.IsEmpty(), 'Errores comprobados no debe mostrar la revisión contextual del destino.');
        Control.FiltrarVista(Buffer, 1);
        Assert(Buffer.Count() = 1, 'La vista opcional debe recuperar la revisión sin duplicarla.');
        Control.Analizar(Periodo, Tipo, Empleado, Proyecto."No.", Buffer);
        FiltrarProyectoNomina(Buffer, Proyecto."No.");
        Assert(Buffer.Count() = 1, 'Una nueva captura debe revisar otra vez el proyecto sin arrastrar el deduplicador.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure MareaConProyectoNominaNoDejaFaltante()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Proyecto: Record Job;
        Destino: Record Job;
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararMareaCandidata(Periodo, Tipo, Empleado, Proyecto);
        Destino."No." := NuevoCodigo();
        Destino.Tipo := 2;
        Destino.Insert(false);
        Proyecto."Proyecto Inactividad Nómina" := Destino."No.";
        Proyecto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, Proyecto."No.", Buffer);
        FiltrarProyectoNomina(Buffer, Proyecto."No.");
        Assert(Buffer.IsEmpty(), 'Un destino específico ya cargado no debe aparecer como faltante.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AtributoNominaBuqueNoExigeCopiaEnMarea()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Proyecto: Record Job;
        Destino: Record Job;
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
        Revision: BigInteger;
    begin
        PrepararMareaCandidata(Periodo, Tipo, Empleado, Proyecto);
        Destino."No." := NuevoCodigo();
        Destino.Tipo := 2;
        Destino.Insert(false);
        Proyecto."Global Dimension 1 Code" := NuevoCodigo();
        Proyecto.Modify(false);
        CrearAtributo('PROY_NOMINA', "Tipo Entidad Estado"::Buque, Proyecto."Global Dimension 1 Code", DMY2Date(1, 1, 2026), 0D, Destino."No.", 0);
        Proyecto.Get(Proyecto."No.");
        Revision := Proyecto.SystemRowVersion;
        Control.Analizar(Periodo, Tipo, Empleado, Proyecto."No.", Buffer);
        FiltrarProyectoNomina(Buffer, Proyecto."No.");
        Assert(Buffer.IsEmpty(), 'PROY_NOMINA vigente hacia un proyecto de nómina válido ya está parametrizado; no debe exigir una copia en Job.');
        Proyecto.Get(Proyecto."No.");
        Assert((Proyecto."Proyecto Inactividad Nómina" = '') and (Proyecto.SystemRowVersion = Revision), 'El control no completa el campo duplicado ni modifica el proyecto.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure RespaldoGeneralValidoNoInventaFaltanteDeMarea()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Proyecto: Record Job;
        Destino: Record Job;
        HRSetup: Record "Human Resources Setup";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararMareaCandidata(Periodo, Tipo, Empleado, Proyecto);
        Destino."No." := NuevoCodigo();
        Destino.Tipo := 2;
        Destino.Insert(false);
        HRSetup.Get();
        HRSetup."Proyecto Nómina" := Destino."No.";
        HRSetup.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, Proyecto."No.", Buffer);
        FiltrarProyectoNomina(Buffer, Proyecto."No.");
        Assert(Buffer.IsEmpty(), 'La ruta legacy de estados tiene un destino general válido; la candidatura no demuestra un faltante en Job.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure DestinoNominaDebeExistirSerImproductivoYDistinto()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Proyecto: Record Job;
        Destino: Record Job;
        Atributo: Record "Atributo Entidad Liq.";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararMareaCandidata(Periodo, Tipo, Empleado, Proyecto);
        Proyecto."Global Dimension 1 Code" := NuevoCodigo();
        Proyecto.Modify(false);
        CrearAtributo('PROY_NOMINA', "Tipo Entidad Estado"::Buque, Proyecto."Global Dimension 1 Code", DMY2Date(1, 1, 2026), 0D, NuevoCodigo(), 0);
        Control.Analizar(Periodo, Tipo, Empleado, Proyecto."No.", Buffer);
        FiltrarProyectoNomina(Buffer, Proyecto."No.");
        Assert(Buffer.FindFirst(), 'Un código de proyecto inexistente en PROY_NOMINA no acredita un destino válido.');
        Assert(Buffer.Severidad = Buffer.Severidad::Advertencia, 'El destino inválido sólo prueba configuración a revisar, no un error del importe candidato.');
        Destino."No." := NuevoCodigo();
        Destino.Tipo := 1;
        Destino.Insert(false);
        Assert(Atributo.Vigente('PROY_NOMINA', "Tipo Entidad Estado"::Buque, Proyecto."Global Dimension 1 Code", DMY2Date(15, 1, 2026)), 'Debe existir la vigencia de prueba.');
        Atributo."Cód. Valor" := Destino."No.";
        Atributo.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, Proyecto."No.", Buffer);
        FiltrarProyectoNomina(Buffer, Proyecto."No.");
        Assert(Buffer.Count() = 1, 'Un proyecto productivo existente tampoco es un destino de nómina válido.');
        Atributo."Cód. Valor" := Proyecto."No.";
        Atributo.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, Proyecto."No.", Buffer);
        FiltrarProyectoNomina(Buffer, Proyecto."No.");
        Assert(Buffer.Count() = 1, 'Una autorreferencia de la marea no debe suprimir la revisión.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure NominaBuqueDebeEstarVigenteEnReferenciaDeMarea()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Proyecto: Record Job;
        Destino: Record Job;
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararMareaCandidata(Periodo, Tipo, Empleado, Proyecto);
        Destino."No." := NuevoCodigo();
        Destino.Tipo := 2;
        Destino.Insert(false);
        Proyecto."Global Dimension 1 Code" := NuevoCodigo();
        Proyecto.Modify(false);
        CrearAtributo('PROY_NOMINA', "Tipo Entidad Estado"::Buque, Proyecto."Global Dimension 1 Code", DMY2Date(16, 1, 2026), 0D, Destino."No.", 0);
        Control.Analizar(Periodo, Tipo, Empleado, Proyecto."No.", Buffer);
        FiltrarProyectoNomina(Buffer, Proyecto."No.");
        Assert(Buffer.Count() = 1, 'La vigencia posterior al arribo no cubre el 15 de enero aunque esté dentro del período.');
        CrearAtributo('PROY_NOMINA', "Tipo Entidad Estado"::Buque, Proyecto."Global Dimension 1 Code", DMY2Date(15, 1, 2026), DMY2Date(15, 1, 2026), Destino."No.", 0);
        Control.Analizar(Periodo, Tipo, Empleado, Proyecto."No.", Buffer);
        FiltrarProyectoNomina(Buffer, Proyecto."No.");
        Assert(Buffer.IsEmpty(), 'La vigencia que cubre exactamente la fecha de arribo debe resolver el destino.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ProyectoNominaNoExigeMareasFueraDeSeleccion()
    var
        Control: Codeunit "Control Previo Liq.";
        Buffer: Record "Control Previo Liq. Buffer" temporary;
        Proyecto: Record Job;
        TipoRec: Record "Tipo Liquidación";
        Periodo: Code[10];
        Tipo: Code[20];
        Empleado: Code[20];
    begin
        PrepararMareaCandidata(Periodo, Tipo, Empleado, Proyecto);
        Control.Analizar(Periodo, Tipo, Empleado, NuevoCodigo(), Buffer);
        FiltrarProyectoNomina(Buffer, Proyecto."No.");
        Assert(Buffer.IsEmpty(), 'Un filtro de proyecto excluyente no puede dejar avisos de otra marea.');
        Proyecto."Ending Date" := DMY2Date(31, 12, 2025);
        Proyecto.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, Proyecto."No.", Buffer);
        FiltrarProyectoNomina(Buffer, Proyecto."No.");
        Assert(Buffer.IsEmpty(), 'Una marea arribada antes del período no puede incorporarse por barrer el histórico.');
        Proyecto.Tipo := 2;
        Proyecto."Ending Date" := DMY2Date(15, 1, 2026);
        Proyecto.Modify(false);
        TipoRec.Get(Tipo);
        TipoRec.Disparador := TipoRec.Disparador::Ninguno;
        TipoRec."Tipo Proyecto" := 0;
        TipoRec.Modify(false);
        Control.Analizar(Periodo, Tipo, Empleado, Proyecto."No.", Buffer);
        FiltrarProyectoNomina(Buffer, Proyecto."No.");
        Assert(Buffer.IsEmpty(), 'Un proyecto administrativo candidato no debe necesitar un destino de inactividad de marea.');
    end;

    local procedure PrepararMareaCandidata(var Periodo: Code[10]; var Tipo: Code[20]; var Empleado: Code[20]; var Proyecto: Record Job)
    var
        Concepto: Record "Concepto Liquidación";
        TipoRec: Record "Tipo Liquidación";
        Personal: Record "Personal Proyecto";
        HRSetup: Record "Human Resources Setup";
    begin
        PrepararCaso(Periodo, Tipo, Empleado, Concepto);
        TipoRec.Get(Tipo);
        TipoRec."Agrupa por Empleado" := false;
        TipoRec.Disparador := TipoRec.Disparador::Arribo;
        TipoRec."Tipo Proyecto" := 1;
        TipoRec.Modify(false);
        Proyecto."No." := NuevoCodigo();
        Proyecto.Tipo := 1;
        Proyecto."Starting Date" := DMY2Date(1, 1, 2026);
        Proyecto."Ending Date" := DMY2Date(15, 1, 2026);
        Proyecto.Insert(false);
        Personal."No. Empleado" := Empleado;
        Personal."No. Proyecto" := Proyecto."No.";
        Personal."Fecha Alta Asignación" := DMY2Date(1, 1, 2026);
        Personal.Insert(false);
        if not HRSetup.Get() then begin
            HRSetup.Init();
            HRSetup.Insert(false);
        end;
        HRSetup."Proyecto Nómina" := '';
        HRSetup.Modify(false);
    end;

    local procedure FiltrarProyectoNomina(var Buffer: Record "Control Previo Liq. Buffer" temporary; Proyecto: Code[20])
    begin
        Buffer.Reset();
        Buffer.SetRange(Área, 'Proyectos');
        Buffer.SetRange("No. Proyecto", Proyecto);
    end;

    local procedure CrearParametroConRegla(var Parametro: Record "Parámetro"; Regla: Text)
    begin
        CrearParametro(Parametro);
        Evaluate(Parametro."Antigüedad Máxima Vigencia", Regla);
        Parametro.Modify(false);
    end;

    local procedure CambiarMesPeriodo(Codigo: Code[10]; Mes: Integer)
    var
        Periodo: Record "Período Liquidación";
    begin
        Periodo.Get(Codigo);
        Periodo."Fecha Desde" := DMY2Date(1, Mes, 2026);
        Periodo."Fecha Hasta" := CalcDate('<CM>', Periodo."Fecha Desde");
        Periodo.Modify(false);
    end;

    local procedure CrearEmpleadoDelCaso(): Code[20]
    var
        Empleado: Record Employee;
        Fase: Record "Fase Alta Empleado";
    begin
        ExigirEmpresaTest();
        Empleado."No." := NuevoCodigo();
        Empleado."Employment Date" := DMY2Date(1, 1, 2026);
        Empleado.Insert(false);
        Fase."No. Empleado" := Empleado."No.";
        Fase."No. Fase" := 1;
        Fase."Fecha Alta" := DMY2Date(1, 1, 2026);
        Fase.Insert(false);
        CrearAtributo('CP_CONVENIO', "Tipo Entidad Estado"::Empleado, Empleado."No.", DMY2Date(1, 1, 2026), 0D, 'CP_CCT', 0);
        exit(Empleado."No.");
    end;

    local procedure ContarErroresParametro(var Buffer: Record "Control Previo Liq. Buffer" temporary; Parametro: Code[20]): Integer
    begin
        Buffer.Reset();
        Buffer.SetRange("Cód. Parámetro", Parametro);
        Buffer.SetRange(Severidad, Buffer.Severidad::Error);
        exit(Buffer.Count());
    end;

    local procedure LeerXmlTemporal(var Blob: Codeunit "Temp Blob") Xml: Text
    var
        Entrada: InStream;
        Linea: Text;
    begin
        Blob.CreateInStream(Entrada, TextEncoding::UTF8);
        while not Entrada.EOS do begin
            Entrada.ReadText(Linea);
            Xml += Linea;
        end;
    end;

    local procedure PrepararFilaAgrupacion(var Fila: Record "Control Previo Liq. Buffer" temporary)
    begin
        Fila.Init();
        Fila.Severidad := Fila.Severidad::Advertencia;
        Fila.Área := 'Parámetros';
        Fila."Nombre Variable" := 'CP_VARIABLE';
        Fila."Cód. Parámetro" := 'CP_PARAM';
        Fila."Cód. Concepto" := 'CP_C1';
        Fila."No. Empleado" := 'CP_EMP';
        Fila."No. Proyecto" := 'CP_PROY';
        Fila."Cód. Convenio" := 'CP_CCT';
        Fila."Cód. Categoría" := 'CP_CAT';
        Fila."Cód. Tipo Liq." := 'CP_TIPO';
        Fila."Fecha Desde" := DMY2Date(1, 1, 2026);
        Fila."Fecha Hasta" := DMY2Date(31, 1, 2026);
        Fila."Vigencia Desde" := DMY2Date(1, 1, 2026);
        Fila.Mensaje := 'Revisar un dato';
        Fila.Detalle := 'Misma causa';
        Fila."Tipo Entidad" := Fila."Tipo Entidad"::Empleado;
        Fila."Cód. Entidad" := 'CP_ENT';
        Fila."Cód. Tipo Atributo" := '';
        Fila."Nombre Fuente" := '';
        Fila."Clave Parámetro" := 'CP_CLAVE';
        Fila.Repeticiones := 0;
        Fila."Conceptos relacionados" := '';
    end;

    local procedure PrepararCaso(var CodPeriodo: Code[10]; var CodTipo: Code[20]; var CodEmpleado: Code[20]; var Concepto: Record "Concepto Liquidación")
    var
        Periodo: Record "Período Liquidación";
        Tipo: Record "Tipo Liquidación";
        Empleado: Record Employee;
        Fase: Record "Fase Alta Empleado";
        Atributo: Record "Tipo Atributo Liq.";
        Valor: Record "Valor Atributo Liq.";
        Convenio: Record "Convenio Colectivo";
    begin
        ExigirEmpresaTest();
        CodPeriodo := CopyStr(NuevoCodigo(), 1, 10);
        CodTipo := NuevoCodigo();
        CodEmpleado := NuevoCodigo();
        Periodo.Código := CodPeriodo;
        Periodo."Fecha Desde" := DMY2Date(1, 1, 2026);
        Periodo."Fecha Hasta" := DMY2Date(31, 1, 2026);
        Periodo.Insert(false);
        Tipo.Código := CodTipo;
        Tipo.Activo := true;
        Tipo."Agrupa por Empleado" := true;
        Tipo."Entra en Corrida Completa" := true;
        Tipo.Insert(false);
        Empleado."No." := CodEmpleado;
        Empleado."Employment Date" := DMY2Date(1, 1, 2026);
        Empleado.Insert(false);
        Fase."No. Empleado" := CodEmpleado;
        Fase."No. Fase" := 1;
        Fase."Fecha Alta" := DMY2Date(1, 1, 2026);
        Fase.Insert(false);
        Convenio.Código := 'CP_CCT';
        if not Convenio.Get(Convenio.Código) then
            Convenio.Insert(false);
        Atributo.Código := 'CP_CONVENIO';
        Atributo."Tipo Dato" := Atributo."Tipo Dato"::Lista;
        Atributo."Tipo Entidad" := Atributo."Tipo Entidad"::Empleado;
        Atributo."Nombre Variable" := 'CONVENIO';
        Atributo."Espejo De" := Atributo."Espejo De"::"Convenio Colectivo";
        Atributo.Insert(false);
        Valor."Cód. Tipo Atributo" := Atributo.Código;
        Valor.Código := Convenio.Código;
        Valor.Insert(false);
        CrearAtributo(Atributo.Código, "Tipo Entidad Estado"::Empleado, CodEmpleado, DMY2Date(1, 1, 2026), 0D, Convenio.Código, 0);
        Concepto.Código := NuevoCodigo();
        Concepto."Vigencia Desde" := DMY2Date(1, 1, 2026);
        Concepto.Activo := true;
        Concepto."Tipos Liq. Aplicables" := CodTipo;
        Concepto.Fórmula := '1';
        Concepto.Insert(false);
    end;

    local procedure CrearParametro(var Parametro: Record "Parámetro")
    begin
        ExigirEmpresaTest();
        Parametro.Init();
        Parametro.Código := NuevoCodigo();
        Parametro."Nombre Variable" := Parametro.Código;
        Parametro.Insert(false);
    end;

    local procedure CrearVersion(Base: Code[20]; Desde: Date; Valor: Decimal; Empleado: Code[20]; Convenio: Code[20]; Categoria: Code[20]; Eje: Code[10]; var Version: Record "Parámetro Vigente")
    var
        Claves: Codeunit "Claves Parámetro Liq.";
    begin
        Version.Init();
        Version."Cód. Parámetro Base" := Base;
        Version."Vigencia Desde" := Desde;
        Version.Valor := Valor;
        Version."No. Empleado" := Empleado;
        Version."Cód. Convenio" := Convenio;
        Version."Cód. Categoría" := Categoria;
        Version."Sufijo Atributo 1" := Eje;
        Version."Cód. Parámetro" := Claves.ArmarDeFila(Version);
        Version.Insert(false);
    end;

    local procedure CrearTipoAtributo(var Tipo: Record "Tipo Atributo Liq."; Entidad: Enum "Tipo Entidad Estado")
    begin
        ExigirEmpresaTest();
        Tipo.Código := NuevoCodigo();
        Tipo."Nombre Variable" := Tipo.Código;
        Tipo."Tipo Dato" := Tipo."Tipo Dato"::Decimal;
        Tipo."Tipo Entidad" := Entidad;
        Tipo.Insert(false);
    end;

    local procedure CrearAtributo(Tipo: Code[20]; Entidad: Enum "Tipo Entidad Estado"; CodigoEntidad: Code[20]; Desde: Date; Hasta: Date; CodigoValor: Code[20]; ValorDecimal: Decimal)
    var
        Atributo: Record "Atributo Entidad Liq.";
    begin
        Atributo."Tipo Entidad" := Entidad;
        Atributo."Cód. Entidad" := CodigoEntidad;
        Atributo."Cód. Tipo Atributo" := Tipo;
        Atributo."Vigencia Desde" := Desde;
        Atributo."Vigencia Hasta" := Hasta;
        Atributo."Cód. Valor" := CodigoValor;
        Atributo."Valor Decimal" := ValorDecimal;
        Atributo."Valor Numérico" := ValorDecimal;
        Atributo.Insert(false);
    end;

    local procedure CrearFuenteCotizacion(var Fuente: Record "Fuente Datos Liquidación"; var Moneda: Code[10])
    var
        Cambio: Record "Currency Exchange Rate";
    begin
        ExigirEmpresaTest();
        Moneda := CopyStr(NuevoCodigo(), 1, 10);
        Fuente."Nombre Variable" := NuevoCodigo();
        Fuente."Id. Tabla" := Database::"Currency Exchange Rate";
        Fuente."No. Campo Valor" := Cambio.FieldNo("Exchange Rate Amount");
        Fuente."No. Campo Fecha Inicio" := Cambio.FieldNo("Starting Date");
        Fuente."Función Agregado" := Fuente."Función Agregado"::LOOKUP;
        Fuente.Activo := true;
        Fuente.Insert(false);
        CrearFiltro(Fuente."Nombre Variable", 1, Cambio.FieldNo("Currency Code"), '{MONEDA}');
        CrearFiltro(Fuente."Nombre Variable", 2, Cambio.FieldNo("Starting Date"), '..{FECHA_REF}');
    end;

    local procedure CrearCotizacion(Moneda: Code[10]; Desde: Date; Valor: Decimal)
    var
        Cambio: Record "Currency Exchange Rate";
    begin
        Cambio."Currency Code" := Moneda;
        Cambio."Starting Date" := Desde;
        Cambio."Exchange Rate Amount" := Valor;
        Cambio.Insert(false);
    end;

    local procedure CrearFiltro(Nombre: Code[30]; Numero: Integer; Campo: Integer; Valor: Text)
    var
        Filtro: Record "Filtro Fuente Datos Liq.";
    begin
        Filtro."Nombre Variable" := Nombre;
        Filtro."No. Línea" := Numero;
        Filtro."No. Campo" := Campo;
        Filtro."Filtro Valor" := CopyStr(Valor, 1, MaxStrLen(Filtro."Filtro Valor"));
        Filtro.Insert(false);
    end;

    local procedure HayErrorVariable(var Buffer: Record "Control Previo Liq. Buffer" temporary; Nombre: Text): Boolean
    begin
        Buffer.Reset();
        Buffer.SetRange("Nombre Variable", Nombre);
        Buffer.SetRange(Severidad, Buffer.Severidad::Error);
        exit(not Buffer.IsEmpty());
    end;

    local procedure HayVariable(var Buffer: Record "Control Previo Liq. Buffer" temporary; Nombre: Text): Boolean
    begin
        Buffer.Reset();
        Buffer.SetRange("Nombre Variable", Nombre);
        exit(not Buffer.IsEmpty());
    end;

    local procedure HayAdvertenciaVariable(var Buffer: Record "Control Previo Liq. Buffer" temporary; Nombre: Text): Boolean
    begin
        Buffer.Reset();
        Buffer.SetRange("Nombre Variable", Nombre);
        Buffer.SetRange(Severidad, Buffer.Severidad::Advertencia);
        exit(not Buffer.IsEmpty());
    end;

    local procedure HayInformacionVariable(var Buffer: Record "Control Previo Liq. Buffer" temporary; Nombre: Text): Boolean
    begin
        Buffer.Reset();
        Buffer.SetRange("Nombre Variable", Nombre);
        Buffer.SetRange(Severidad, Buffer.Severidad::Información);
        exit(not Buffer.IsEmpty());
    end;

    local procedure ResumenBuffer(var Buffer: Record "Control Previo Liq. Buffer" temporary) Texto: Text
    var
        Salida: TextBuilder;
    begin
        Buffer.Reset();
        if Buffer.FindSet() then
            repeat
                Salida.AppendLine(Format(Buffer.Severidad) + '|' + Buffer."Área" + '|' + Buffer."Nombre Variable" + '|' + Buffer."Cód. Concepto" + '|' + Buffer."No. Empleado" + '|' + Buffer.Mensaje + '|' + Buffer.Detalle + '|' + Format(Buffer.Repeticiones) + '|' + Buffer."Conceptos relacionados");
            until Buffer.Next() = 0;
        exit(Salida.ToText());
    end;

    local procedure CapturarConteos(): Text
    var
        Cabecera: Record "Liquidación";
        Linea: Record "Línea Liquidación";
        Incidencia: Record "Incidencia Liquidación";
        Novedad: Record "Novedad Liquidación";
        Movimiento: Record "Movimiento Franco Liq.";
        Uso: Record "Uso Parámetro Liq.";
        Registro: Record "Registro Proceso Liq.";
        Detalle: Record "Detalle Variable Línea Liq.";
        Version: Record "Parámetro Vigente";
    begin
        Version.SetRange("En Uso", true);
        exit(StrSubstNo('%1|%2|%3|%4|%5|%6|%7|%8|%9', Cabecera.Count(), Linea.Count(), Incidencia.Count(), Novedad.Count(), Movimiento.Count(), Uso.Count(), Registro.Count(), Detalle.Count(), Version.Count()));
    end;

    local procedure NuevoCodigo(): Code[20]
    begin
        exit(CopyStr('CP' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
    end;

    local procedure ExigirEmpresaTest()
    var
        Empresa: Text;
    begin
        Empresa := CompanyName();
        if not Empresa.StartsWith('TEST_') then
            Error('Control previo: las fixtures sólo pueden ejecutarse en una empresa aislada TEST_.');
    end;

    local procedure Assert(Condicion: Boolean; Mensaje: Text)
    begin
        if not Condicion then
            Error(Mensaje);
    end;
}
