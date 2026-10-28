namespace UAS.Payroll;

/// <summary>
/// La ventana de progreso de los procesos de liquidación, compartida por el lote y el motor.
/// </summary>
/// <remarks>
/// Es SingleInstance por una razón concreta: el lote abre la ventana, pero quien tarda es el motor,
/// y entre los dos hay un Codeunit.Run —LiquidarConRegistro— por el que no se puede pasar un Dialog.
/// Con la ventana acá, el motor la actualiza desde adentro del Run sin que nadie tenga que pasarle
/// nada.
///
/// Y hace falta que la actualice desde adentro: un lote que solo refresca al entrar a cada
/// liquidación se ve congelado justo en las que tardan. Las de Grossing Up recalculan la lista
/// entera de conceptos hasta 21 veces para converger, así que tardan casi un orden de magnitud más
/// que una normal; sin señales intermedias, la pantalla se queda con el último nombre que alcanzó a
/// pintar y parece colgada en el empleado equivocado.
///
/// Todo lo que sigue es inofensivo si nadie abrió la ventana: los procesos que corren en background
/// o desde un job queue llaman igual y no pasa nada.
/// </remarks>
codeunit 110032 "Progreso Liq."
{
    SingleInstance = true;
    Access = Public;

    var
        FVentana: Dialog;
        FAbierta: Boolean;
        FNivel: Integer;
        FTotal: Integer;
        FActual: Integer;
        FProcesadas: Integer;
        FInicio: DateTime;
        FDuracionTotal: Duration;
        DlgProgreso: Label 'Procesando liquidaciones\\Liquidación  #1##################\Empleado     #2##############################################\Paso         #3##############################################\\Avance del lote  #4##############################################\Tiempo           #5##############################################';
        TxtPaso: Label 'Procesando %1 de %2', Comment = '%1=actual, %2=total';
        TxtPasoSinTotal: Label 'Procesando la %1', Comment = '%1=número de orden de la que se está procesando';
        TxtAvance: Label '%1 % (%2 de %3 procesadas)', Comment = '%1=porcentaje, %2=procesadas, %3=total';
        TxtAvanceSinTotal: Label '%1 procesadas', Comment = '%1=cantidad procesada hasta ahora';
        TxtTiempo: Label '%1', Comment = '%1=tiempo transcurrido hh:mm:ss';
        TxtTiempoPromedio: Label '%1  (%2 s por liquidación)', Comment = '%1=tiempo transcurrido hh:mm:ss, %2=segundos por liquidación procesada';

    /// <summary>
    /// Abre la ventana. Cada Abrir necesita su Cerrar.
    /// </summary>
    /// <remarks>
    /// Lleva un nivel de anidamiento porque hay procesos que llaman a otros —el recálculo en cadena
    /// dispara el motor una vez por período— y sin el contador el Cerrar del de adentro apagaría la
    /// ventana del de afuera, que sigue trabajando. El total y el contador son del PRIMERO que abre:
    /// es el que sabe cuántas son en realidad.
    /// </remarks>
    /// <summary>
    /// Arranca un lote. A diferencia de Abrir, declara que es el proceso de AFUERA y descarta lo que
    /// haya quedado de una corrida anterior.
    /// </summary>
    /// <remarks>
    /// Este codeunit es SingleInstance, así que su estado sobrevive a la corrida. Cuando un lote se
    /// DETIENE —el usuario lo corta, o un error se escapa— el Cerrar nunca corre: quedan FAbierta en
    /// true, FNivel en uno o dos, los contadores de la corrida vieja y un FInicio de hace rato. El
    /// Abrir siguiente veía FAbierta encendido y salía sin tocar nada, así que el lote NUEVO pintaba
    /// los números del VIEJO: "519 de 519, 100 %" y un reloj de 36 minutos mientras recién empezaba.
    ///
    /// No se puede distinguir "quedó sucio" de "estoy anidado" mirando el estado, porque los dos se
    /// ven igual. Por eso lo dice el que llama: quien arranca un lote sabe que es el de afuera.
    /// </remarks>
    procedure AbrirLote(Total: Integer)
    begin
        FNivel := 0;
        // El handle viejo apunta a una ventana que la plataforma ya cerró al abortar. Escribirle no
        // hace nada visible, que es de dónde salía la sensación de que el progreso "se colgó".
        Clear(FVentana);
        FAbierta := false;
        FTotal := 0;
        FActual := 0;
        FProcesadas := 0;
        Abrir(Total);
    end;

    procedure Abrir(Total: Integer)
    begin
        FNivel += 1;
        if FAbierta then
            exit;
        // EL RELOJ ARRANCA AUNQUE NO HAYA VENTANA, y por eso va antes del GuiAllowed: un lote
        // lanzado desde un job queue no dibuja nada pero igual tiene que poder decir cuánto tardó.
        // Se condiciona al nivel y no a FAbierta porque sin interfaz FAbierta nunca se enciende, y
        // un proceso anidado le reiniciaría el reloj al de afuera, que es el que sigue trabajando.
        if FNivel = 1 then begin
            FInicio := CurrentDateTime();
            FDuracionTotal := 0;
        end;
        if not GuiAllowed() then
            exit;
        FTotal := Total;
        FActual := 0;
        FProcesadas := 0;
        FVentana.Open(DlgProgreso);
        FAbierta := true;
        ActualizarAvance();
    end;

    /// <summary>Empieza una liquidación: avanza el contador y limpia el paso anterior.</summary>
    procedure Registro(NoLiq: Code[20]; Nombre: Text)
    begin
        if not FAbierta then
            exit;
        FActual := FProcesadas + 1;
        FVentana.Update(1, NoLiq);
        FVentana.Update(2, Nombre);
        if FTotal = 0 then
            FVentana.Update(3, StrSubstNo(TxtPasoSinTotal, FActual))
        else
            FVentana.Update(3, StrSubstNo(TxtPaso, FActual, FTotal));
    end;

    // El lote informa el fin incluso si hubo un error controlado o se omitió el registro.
    // El porcentaje mide elementos procesados, no tiempo estimado ni cálculos exitosos.
    procedure FinalizarRegistro()
    begin
        if not FAbierta then
            exit;
        // El tope sólo aplica cuando SE SABE cuál es. Con total desconocido —FTotal = 0, que es como
        // abre "Crear y Calcular", porque va creando sobre la marcha— la guarda "FProcesadas <
        // FTotal" es falsa desde la primera vuelta y el contador se quedaba clavado en cero.
        if (FTotal = 0) or (FProcesadas < FTotal) then
            FProcesadas += 1;
        ActualizarAvance();
    end;

    local procedure ActualizarAvance()
    var
        Porcentaje: Decimal;
    begin
        // Sin total no hay porcentaje que mostrar: un "0 %" permanente dice menos que el conteo.
        if FTotal = 0 then begin
            FVentana.Update(4, StrSubstNo(TxtAvanceSinTotal, FProcesadas));
            ActualizarTiempo();
            exit;
        end;
        // Redondear hacia abajo evita mostrar 100 % antes del último elemento.
        Porcentaje := Round(FProcesadas / FTotal * 100, 0.1, '<');
        FVentana.Update(4, StrSubstNo(TxtAvance, Porcentaje, FProcesadas, FTotal));
        ActualizarTiempo();
    end;

    /// <summary>
    /// Pinta el tiempo transcurrido y, cuando hay al menos una procesada, el promedio por
    /// liquidación.
    /// </summary>
    /// <remarks>
    /// EL PROMEDIO ES UN HECHO, NO UNA ESTIMACIÓN, y por eso se muestra en vez de un "tiempo
    /// restante". Las liquidaciones no tardan lo mismo: una con Grossing Up recalcula la lista de
    /// conceptos hasta 21 veces y tarda casi un orden de magnitud más que una normal, así que
    /// proyectar el promedio sobre lo que falta daría un número que se mueve solo y no le sirve a
    /// nadie. El avance por elementos ya está en la línea de arriba, con el mismo criterio.
    /// </remarks>
    local procedure ActualizarTiempo()
    var
        Transcurrido: Duration;
        Ms: Decimal;
    begin
        if not FAbierta then
            exit;
        Transcurrido := Transcurrido();
        if FProcesadas > 0 then begin
            Ms := Transcurrido;
            FVentana.Update(5, StrSubstNo(TxtTiempoPromedio, ComoReloj(Transcurrido), Format(Round(Ms / FProcesadas / 1000, 0.1))));
        end else
            FVentana.Update(5, StrSubstNo(TxtTiempo, ComoReloj(Transcurrido)));
    end;

    /// <summary>Cuánto lleva el proceso, como hh:mm:ss. Después de Cerrar, cuánto duró.</summary>
    procedure TranscurridoTexto(): Text
    begin
        exit(ComoReloj(Transcurrido()));
    end;

    /// <summary>Una duración como hh:mm:ss.</summary>
    /// <remarks>
    /// SIN MILISEGUNDOS A PROPÓSITO. En un lote que dura minutos no dicen nada y ensucian la
    /// lectura, que es justo lo que uno mira de reojo mientras el proceso corre. El promedio por
    /// liquidación es el único que lleva un decimal, y no por precisión: ahí la diferencia entre
    /// 2 y 3 segundos es la mitad del tiempo del lote.
    ///
    /// Se arma a mano en vez de con una cadena de Format porque esas expresiones no se validan al
    /// compilar: un token inexistente recién falla al ejecutarse, y sería en medio de un cálculo.
    /// </remarks>
    local procedure ComoReloj(D: Duration): Text
    var
        Ms: Decimal;
        Segs: Integer;
    begin
        Ms := D;
        Segs := Round(Ms / 1000, 1, '<');
        exit(DosDigitos(Segs div 3600) + ':' + DosDigitos((Segs div 60) mod 60) + ':' + DosDigitos(Segs mod 60));
    end;

    local procedure DosDigitos(N: Integer): Text
    begin
        if N < 10 then
            exit('0' + Format(N));
        exit(Format(N));
    end;

    /// <summary>
    /// Cuánto lleva el proceso. Después de Cerrar, cuánto duró.
    /// </summary>
    /// <remarks>
    /// Sirve durante y después a propósito: el lote la usa para poner el tiempo en el mensaje final,
    /// y para entonces la ventana ya se cerró. Por eso Cerrar congela el total en vez de dejar que
    /// el reloj siga corriendo contra un inicio viejo.
    /// </remarks>
    procedure Transcurrido(): Duration
    begin
        if FDuracionTotal > 0 then
            exit(FDuracionTotal);
        if FInicio = 0DT then
            exit(0);
        exit(CurrentDateTime() - FInicio);
    end;

    /// <summary>Qué está haciendo ahora mismo. La llama el motor, desde adentro del cálculo.</summary>
    procedure Paso(Texto: Text)
    begin
        if not FAbierta then
            exit;
        FVentana.Update(3, Texto);
        // El tiempo se refresca acá también, y no solo al terminar cada liquidación: las de Grossing
        // Up informan paso por iteración y son justo las que tardan. Sin esto el reloj se quedaría
        // quieto en la que más importa mirar.
        ActualizarTiempo();
    end;

    procedure Cerrar()
    begin
        if FNivel > 0 then
            FNivel -= 1;
        if FNivel > 0 then
            exit;
        // El total se congela SIEMPRE, haya habido ventana o no: es lo que el lote va a poner en el
        // mensaje final, y para entonces la ventana ya no está.
        if FInicio <> 0DT then
            FDuracionTotal := CurrentDateTime() - FInicio;
        if not FAbierta then
            exit;
        FVentana.Close();
        FAbierta := false;
        FTotal := 0;
        FActual := 0;
        FProcesadas := 0;
    end;
}
