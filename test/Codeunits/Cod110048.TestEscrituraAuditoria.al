namespace UAS.Payroll;

using System.IO;

codeunit 110048 "Test Escritura Auditoria"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure DetalleConservaPrimeroTramosYCeros()
    var
        Motor: Codeunit "Motor Liquidación";
        Evaluador: Codeunit "Evaluador Fórmula";
        Det: Record "Detalle Variable Línea Liq.";
        Ctx: Dictionary of [Text, Decimal];
        LiqNo: Code[20];
        Prefijo: Text;
    begin
        LiqNo := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20);
        Prefijo := PadStr('COLISION', 50, 'X');
        Ctx.Add(Prefijo + 'A', 12);
        Ctx.Add(Prefijo + 'B', 34);
        Ctx.Add('TRAMO(T)', 7);
        Evaluador.Init(Ctx, Today());
        Motor.WriteVariableDetail(LiqNo, 10000,
            'VAR:' + Prefijo + 'A|VAR:' + Prefijo + 'B|VAR:TRAMO(T)|TRAMO:T~5~primero|TRAMO:T~5~primero|TRAMO:T~6~segundo|VAR:AUSENTE',
            Ctx, Evaluador);
        Det.Get(LiqNo, 10000, Prefijo);
        Assert(Det.Valor = 12, 'La colisión truncada debe conservar el primer valor.');
        Det.Get(LiqNo, 10000, 'TRAMO(T)');
        Assert(Det.Valor = 7, 'La variable debe conservar su nombre frente al tramo posterior.');
        Det.Get(LiqNo, 10000, 'TRAMO(T) #2');
        Assert((Det.Valor = 5) and (Det.Detalle = 'primero'), 'Debe conservar el primer tramo y su detalle.');
        Det.Get(LiqNo, 10000, 'TRAMO(T) #3');
        Assert((Det.Valor = 6) and (Det.Detalle = 'segundo'), 'El tramo distinto debe tener otro sufijo.');
        Det.Get(LiqNo, 10000, 'AUSENTE');
        Assert((Det.Valor = 0) and (Det.Detalle = ''), 'La variable ausente debe quedar en cero sin heredar detalle.');
        Det.SetRange("No. Liquidación", LiqNo);
        Assert(Det.Count() = 5, 'La entrada TRAMO idéntica no debe repetirse.');
        Motor.WriteVariableDetail(LiqNo, 20000, 'VAR:AUSENTE', Ctx, Evaluador);
        Det.Get(LiqNo, 20000, 'AUSENTE');
        Det.DeleteAll();
    end;

    [Test]
    procedure ResumenConservaUltimoTrasTruncar()
    var
        Motor: Codeunit "Motor Liquidación";
        Builder: Codeunit "Contexto Liquidación";
        Resumen: Record "Resumen Variable Liq.";
        Ctx: Dictionary of [Text, Decimal];
        LiqNo: Code[20];
        Prefijo: Text;
        Nombre: Text;
        Ultimo: Decimal;
    begin
        LiqNo := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20);
        Prefijo := PadStr('TESTAUDITORIA', 30, 'X');
        Ctx.Add(Prefijo + 'A', 12);
        Ctx.Add(Prefijo + 'B', 34);
        foreach Nombre in Ctx.Keys() do
            Ultimo := Ctx.Get(Nombre);
        Motor.SaveResumenVariables(LiqNo, Ctx, Builder);
        Resumen.Get(LiqNo, Prefijo);
        Assert(Resumen.Valor = Ultimo, 'Debe persistir el último valor de la clave truncada.');
        Resumen.SetRange("No. Liquidación", LiqNo);
        Assert(Resumen.Count() = 1, 'Debe persistir una sola fila por clave normalizada.');
        Resumen.DeleteAll();
    end;

    local procedure Assert(Condition: Boolean; Message: Text)
    begin
        if not Condition then
            Error(Message);
    end;

    [Test]
    procedure AvisoLargoConservaTextoYDetalle()
    var
        Registro: Codeunit "Registro Procesos Liq.";
        Entrada: Record "Entrada Registro Liq.";
        Mensaje: Text;
    begin
        Registro.IniciarSesion();
        Registro.IniciarProceso("Tipo Proceso Liq."::Cálculo, 'TSTAUD');
        Mensaje := PadStr('AVISO COMPLETO ', 700, 'X');
        Registro.AdvertirVariable("Categoría Registro Liq."::Parámetro, Mensaje, 'TEST_AVISO', '');
        Registro.Finalizar();
        Entrada.SetRange("No. Registro", Registro.UltimoRegistro());
        Assert(Entrada.FindFirst(), 'Debe persistir el aviso largo.');
        Assert(Entrada.Mensaje = CopyStr(Mensaje, 1, 250), 'El título debe conservar su longitud configurada.');
        Assert(Entrada.Detalle = Mensaje, 'El detalle debe conservar el mensaje completo, sin perder su final.');
        Assert(Entrada."Nombre Variable" = 'TEST_AVISO', 'Conservar texto largo no debe cambiar la identidad del aviso.');
        Registro.CerrarSesion();
    end;

    [Test]
    procedure AvisosSeparadosConservanEntradas()
    var
        Registro: Codeunit "Registro Procesos Liq.";
        Entrada: Record "Entrada Registro Liq.";
    begin
        Registro.IniciarSesion();
        Registro.IniciarProceso("Tipo Proceso Liq."::Cálculo, 'TSTAUD');
        Registro.AgregarTexto("Severidad Registro Liq."::Advertencia, "Categoría Registro Liq."::Parámetro,
            'Primera variable\Segunda variable\Tercera variable');
        Registro.Finalizar();
        Entrada.SetRange("No. Registro", Registro.UltimoRegistro());
        Entrada.SetRange(Severidad, Entrada.Severidad::Advertencia);
        Assert(Entrada.Count() = 3, 'Cada aviso separado debe conservarse en una entrada individual.');
        Registro.CerrarSesion();
    end;

    [Test]
    procedure InformeResumeLoteCompletoYFiltraInformacion()
    var
        Reporte: Report "Avisos del Cálculo";
        Filtro: Record "Registro Proceso Liq.";
        Sesion: Guid;
        Avisos: Integer;
        Procesos: Integer;
        Liquidaciones: Integer;
        Alcance: Text;
        Totales: Text;
    begin
        Sesion := CreateGuid();
        CrearRegistroAvisos(Sesion, 'TSTAUD-A', '202601', 2, 0);
        CrearRegistroAvisos(Sesion, 'TSTAUD-B', '202602', 1, 0);
        CrearRegistroAvisos(Sesion, 'TSTAUD-SIN', '202603', 0, 4);
        CrearRegistroAvisos(CreateGuid(), 'TSTAUD-OTRA', '202604', 5, 0);
        Filtro.SetRange("No. Sesión", Sesion);
        Reporte.CalcularResumen(Filtro);
        Reporte.ObtenerResumen(Avisos, Procesos, Liquidaciones, Alcance, Totales);
        Assert((Avisos = 3) and (Procesos = 2) and (Liquidaciones = 2), 'El informe debe resumir todos y sólo los procesos con avisos de la selección.');
        Assert((StrPos(Alcance, '202601') > 0) and (StrPos(Alcance, '202602') > 0), 'El alcance debe mostrar todos los períodos incluidos.');
        Assert((StrPos(Alcance, '202603') = 0) and (StrPos(Alcance, 'TSTAUD-A') = 0), 'Un lote no debe atribuirse a su primer documento ni incluir períodos sin avisos.');
        Assert(StrPos(Totales, '3') > 0, 'El resumen debe contener la cantidad total de avisos.');
    end;

    [Test]
    procedure InformeCuentaDocumentosDistintosYRespetaFiltro()
    var
        Reporte: Report "Avisos del Cálculo";
        Filtro: Record "Registro Proceso Liq.";
        Sesion: Guid;
        Avisos: Integer;
        Procesos: Integer;
        Liquidaciones: Integer;
        Alcance: Text;
        Totales: Text;
    begin
        Sesion := CreateGuid();
        CrearRegistroAvisos(Sesion, 'TSTAUD-UNICO', '202601', 2, 0);
        CrearRegistroAvisos(Sesion, 'TSTAUD-UNICO', '202601', 1, 0);
        CrearRegistroAvisos(Sesion, 'TSTAUD-OTRO', '202602', 4, 0);
        Filtro.SetRange("No. Sesión", Sesion);
        Filtro.SetRange("Cód. Período", '202601');
        Reporte.CalcularResumen(Filtro);
        Reporte.ObtenerResumen(Avisos, Procesos, Liquidaciones, Alcance, Totales);
        Assert((Avisos = 3) and (Procesos = 2) and (Liquidaciones = 1), 'Dos procesos del mismo documento no son dos liquidaciones.');
        Assert(StrPos(Alcance, '202602') = 0, 'El resumen debe respetar los filtros de la petición.');
        Filtro.SetRange("Cód. Período", '202602');
        Reporte.CalcularResumen(Filtro);
        Reporte.ObtenerResumen(Avisos, Procesos, Liquidaciones, Alcance, Totales);
        Assert((Avisos = 4) and (Procesos = 1) and (Liquidaciones = 1), 'Volver a preparar el informe no debe arrastrar contadores anteriores.');
        Assert(StrPos(Alcance, 'TSTAUD-OTRO') > 0, 'Un único proceso debe identificar su documento.');
    end;

    [Test]
    procedure InformeSinAvisosNoHeredaContadores()
    var
        Reporte: Report "Avisos del Cálculo";
        Filtro: Record "Registro Proceso Liq.";
        Sesion: Guid;
        Avisos: Integer;
        Procesos: Integer;
        Liquidaciones: Integer;
        Alcance: Text;
        Totales: Text;
    begin
        Sesion := CreateGuid();
        CrearRegistroAvisos(Sesion, 'TSTAUD-INFO', '202601', 0, 2);
        Assert(not Reporte.ValeLaPena(Sesion), 'La traza informativa normal no debe abrir el informe.');
        Filtro.SetRange("No. Sesión", Sesion);
        Reporte.CalcularResumen(Filtro);
        Reporte.ObtenerResumen(Avisos, Procesos, Liquidaciones, Alcance, Totales);
        Assert((Avisos = 0) and (Procesos = 0) and (Liquidaciones = 0), 'La traza informativa no es un aviso ni una liquidación afectada.');
    end;

    [Test]
    procedure ControlOrdenInformativoConservaIdentidadYResumen()
    var
        Registro: Codeunit "Registro Procesos Liq.";
        Cabecera: Record "Registro Proceso Liq.";
        Entrada: Record "Entrada Registro Liq.";
        Resumen: Text;
    begin
        Registro.IniciarSesion();
        Registro.IniciarProceso("Tipo Proceso Liq."::Cálculo, 'TSTAUD');
        Registro.Info("Categoría Registro Liq."::General, 'TRAZA NORMAL NO RESUMIDA');
        Registro.InfoVariable("Categoría Registro Liq."::"Orden Cálculo",
            'Lectura parcial en 10; último aporte TEST_APORTE (20). Revisar el alcance del subtotal.',
            'TEST_BASE', 'TEST_LECTOR');
        Registro.Finalizar();
        Cabecera.Get(Registro.UltimoRegistro());
        Assert((Cabecera.Resultado = Cabecera.Resultado::Información) and
            (Cabecera."Cant. Advertencias" = 0) and (Cabecera."Cant. Errores" = 0),
            'Una observación de precedencia no debe convertirse en advertencia o error.');
        Assert(StrPos(Cabecera.Mensaje, 'Control de bases y orden') > 0,
            'El proceso debe informar que dejó controles aunque sólo haya información.');
        Entrada.SetRange("No. Registro", Cabecera."No. Registro");
        Entrada.SetRange(Categoría, Entrada.Categoría::"Orden Cálculo");
        Assert(Entrada.FindFirst(), 'La observación debe quedar guardada.');
        Assert((Entrada.Severidad = Entrada.Severidad::Información) and
            (Entrada."Nombre Variable" = 'TEST_BASE') and (Entrada."Cód. Concepto" = 'TEST_LECTOR'),
            'Deben conservarse la severidad y la identidad de base y lector.');
        Resumen := Registro.GetResumen();
        Assert((StrPos(Resumen, 'Control de bases y orden') > 0) and
            (StrPos(Resumen, 'TEST_LECTOR lee TEST_BASE') > 0) and (StrPos(Resumen, 'TEST_APORTE (20)') > 0),
            'El resumen debe conservar base, lector y aporte posterior, sin ocultar el control.');
        Assert(StrPos(Resumen, 'TRAZA NORMAL') = 0, 'La traza habitual no debe duplicarse en el resumen.');
        Registro.CerrarSesion();
    end;

    [Test]
    procedure InformeAbreConSoloControlOrdenYExcluyeTraza()
    var
        Reporte: Report "Avisos del Cálculo";
        Filtro: Record "Registro Proceso Liq.";
        Entrada: Record "Entrada Registro Liq.";
        Sesion: Guid;
        NoRegistro: Integer;
        Avisos: Integer;
        Procesos: Integer;
        Liquidaciones: Integer;
        Errores: Integer;
        Advertencias: Integer;
        Controles: Integer;
        Alcance: Text;
        Totales: Text;
    begin
        Sesion := CreateGuid();
        NoRegistro := CrearRegistroAvisos(Sesion, 'TSTAUD-ORDEN', '202601', 0, 3);
        Entrada.Get(NoRegistro, 10000);
        Entrada.Categoría := Entrada.Categoría::"Orden Cálculo";
        Entrada.Modify();
        CrearRegistroAvisos(Sesion, 'TSTAUD-TRAZA', '202602', 0, 2);
        CrearRegistroAvisos(CreateGuid(), 'TSTAUD-AJENO', '202603', 2, 0);
        Assert(Reporte.ValeLaPena(Sesion), 'Un único control informativo debe abrir automáticamente el informe.');
        Filtro.SetRange("No. Sesión", Sesion);
        Reporte.CalcularResumen(Filtro);
        Reporte.ObtenerResumen(Avisos, Procesos, Liquidaciones, Alcance, Totales);
        Reporte.ObtenerTotalesSecciones(Errores, Advertencias, Controles);
        Assert((Avisos = 1) and (Procesos = 1) and (Liquidaciones = 1),
            'Sólo el control de orden pertenece al informe; la traza y otras sesiones quedan fuera.');
        Assert((Errores = 0) and (Advertencias = 0) and (Controles = 1),
            'El control debe contarse por separado de errores y advertencias.');
        Assert((StrPos(Alcance, '202601') > 0) and (StrPos(Alcance, '202602') = 0),
            'El alcance debe incluir el proceso con control y excluir el que sólo tiene traza.');
        Entrada.Reset();
        Entrada.SetRange("No. Registro", NoRegistro);
        Reporte.FiltrarEntradasVisibles(Entrada);
        Assert(Entrada.Count() = 1, 'La selección del dataset debe incluir información sólo de orden.');
    end;

    [Test]
    procedure InformeSeparaErroresAdvertenciasYControles()
    var
        Reporte: Report "Avisos del Cálculo";
        Registro: Codeunit "Registro Procesos Liq.";
        Filtro: Record "Registro Proceso Liq.";
        Entrada: Record "Entrada Registro Liq.";
        Sesion: Guid;
        Avisos: Integer;
        Procesos: Integer;
        Liquidaciones: Integer;
        Errores: Integer;
        Advertencias: Integer;
        Controles: Integer;
        Alcance: Text;
        Totales: Text;
        Resumen: Text;
        LineaLegacy: Integer;
        VersionLegacy: BigInteger;
    begin
        Sesion := Registro.IniciarSesion();
        Registro.IniciarProceso("Tipo Proceso Liq."::Cálculo, 'TSTAUD');
        Registro.Info("Categoría Registro Liq."::General, 'TRAZA SIN RELEVANCIA PARA EL INFORME');
        Registro.InfoVariable("Categoría Registro Liq."::"Orden Cálculo", 'Control de lectura parcial.', 'TEST_BASE', 'TEST_LECTOR');
        Registro.AdvertirVariable("Categoría Registro Liq."::"Orden Cálculo", 'CONTROL HISTORICO', 'TEST_BASE', 'TEST_LECTOR');
        Registro.Advertir("Categoría Registro Liq."::Parámetro, 'ADVERTENCIA REAL');
        Registro.RegistrarError("Categoría Registro Liq."::"Orden Cálculo", 'ERROR REAL', 'Detalle del error sintético.');
        Registro.Finalizar();
        Entrada.SetRange("No. Registro", Registro.UltimoRegistro());
        Entrada.SetRange(Severidad, Entrada.Severidad::Advertencia);
        Entrada.SetRange(Categoría, Entrada.Categoría::"Orden Cálculo");
        Assert(Entrada.FindFirst(), 'El fixture histórico debe existir como advertencia de orden.');
        LineaLegacy := Entrada."No. Línea";
        VersionLegacy := Entrada.SystemRowVersion;
        Resumen := Registro.GetResumen();
        Assert((StrPos(Resumen, 'Advertencias y errores') > 0) and
            (StrPos(Resumen, 'Control de bases y orden') > StrPos(Resumen, 'ERROR REAL')),
            'Las advertencias y errores deben separarse de las observaciones informativas.');
        Assert((StrPos(Resumen, 'ADVERTENCIA REAL') > 0) and (StrPos(Resumen, 'ERROR REAL') > 0) and
            (StrPos(Resumen, 'TRAZA SIN RELEVANCIA') = 0), 'El resumen conserva incidencias reales y excluye la traza normal.');
        Filtro.SetRange("No. Sesión", Sesion);
        Reporte.CalcularResumen(Filtro);
        Reporte.ObtenerResumen(Avisos, Procesos, Liquidaciones, Alcance, Totales);
        Reporte.ObtenerTotalesSecciones(Errores, Advertencias, Controles);
        Assert((Avisos = 4) and (Procesos = 1) and (Errores = 1) and (Advertencias = 1) and (Controles = 2),
            'El aviso histórico de orden se presenta como control; el error de orden sigue siendo un error.');
        Entrada.Reset();
        Entrada.Get(Registro.UltimoRegistro(), LineaLegacy);
        Assert((Entrada.Severidad = Entrada.Severidad::Advertencia) and (Entrada.SystemRowVersion = VersionLegacy),
            'Preparar el informe no debe reescribir la severidad ni los metadatos del registro histórico.');
        Entrada.Reset();
        Entrada.SetRange("No. Registro", Registro.UltimoRegistro());
        Reporte.FiltrarEntradasVisibles(Entrada);
        Assert(Entrada.Count() = 4, 'El dataset debe conservar controles, errores y advertencias de cualquier categoría.');
        Registro.CerrarSesion();
    end;

    // Previsualización con datos sintéticos. No calcula nómina ni deja registros de prueba.
    procedure GenerarVistaInforme(): Text
    var
        Registro: Record "Registro Proceso Liq.";
        Entrada: Record "Entrada Registro Liq.";
        Archivos: Codeunit "File Management";
        Sesion: Guid;
        Numero: Integer;
        NoRegistro: Integer;
        Archivo: Text;
    begin
        Sesion := CreateGuid();
        for Numero := 1 to 570 do begin
            NoRegistro := CrearRegistroAvisos(Sesion, CopyStr('AVISO-PRUEBA-' + Format(Numero), 1, 20), '202601', 1, 0);
            Entrada.Get(NoRegistro, 10000);
            if Numero <= 69 then begin
                Entrada.Mensaje := 'Aviso sintético largo: el detalle conserva el texto completo.';
                Entrada.Detalle := PadStr('Texto completo para comprobar la lectura del informe. ', 700, 'X');
            end else if Numero = 570 then begin
                Entrada.Categoría := Entrada.Categoría::Novedad;
                Entrada.Mensaje := 'La novedad quedó pendiente porque ya existe una incidencia del concepto.';
                Entrada."Cód. Concepto" := '8870';
            end else begin
                Entrada.Severidad := Entrada.Severidad::Información;
                Entrada.Categoría := Entrada.Categoría::"Orden Cálculo";
                Entrada.Mensaje := 'Lectura con aportes efectivos posteriores. Revisar la definición de la base: no demuestra una diferencia de importe.';
                Entrada."Cód. Concepto" := 'TST_BASE';
                Entrada."Nombre Variable" := 'TST_ACUM';
            end;
            Entrada.Modify();
        end;
        Registro.SetRange("No. Sesión", Sesion);
        Archivo := Archivos.ServerTempFileName('pdf');
        Report.SaveAsPdf(Report::"Avisos del Cálculo", Archivo, Registro);
        if Registro.FindSet() then
            repeat
                Entrada.SetRange("No. Registro", Registro."No. Registro");
                Entrada.DeleteAll();
            until Registro.Next() = 0;
        Registro.DeleteAll();
        exit(Archivo);
    end;

    local procedure CrearRegistroAvisos(Sesion: Guid; Documento: Code[20]; Periodo: Code[10]; Avisos: Integer; Informaciones: Integer): Integer
    var
        Registro: Record "Registro Proceso Liq.";
        Entrada: Record "Entrada Registro Liq.";
        Numero: Integer;
    begin
        Registro.Init();
        Registro."No. Sesión" := Sesion;
        Registro."No. Liquidación" := Documento;
        Registro."No. Empleado" := 'TSTAUD';
        Registro."Cód. Período" := Periodo;
        Registro."Fecha Hora Inicio" := CurrentDateTime();
        Registro.Insert();
        for Numero := 1 to Avisos + Informaciones do begin
            Entrada.Init();
            Entrada."No. Registro" := Registro."No. Registro";
            Entrada."No. Línea" := Numero * 10000;
            Entrada.Categoría := Entrada.Categoría::Parámetro;
            if Numero <= Avisos then
                Entrada.Severidad := Entrada.Severidad::Advertencia
            else
                Entrada.Severidad := Entrada.Severidad::Información;
            Entrada.Mensaje := 'Aviso sintético';
            Entrada.Insert();
        end;
        exit(Registro."No. Registro");
    end;
}
