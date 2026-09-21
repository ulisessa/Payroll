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
        DlgProgreso: Label 'Procesando liquidaciones\\Liquidación  #1##################\Empleado     #2##############################################\Paso         #3##############################################\\Avance del lote  #4##############################################';
        TxtPaso: Label 'Procesando %1 de %2', Comment = '%1=actual, %2=total';
        TxtAvance: Label '%1 % (%2 de %3 procesadas)', Comment = '%1=porcentaje, %2=procesadas, %3=total';

    /// <summary>
    /// Abre la ventana. Cada Abrir necesita su Cerrar.
    /// </summary>
    /// <remarks>
    /// Lleva un nivel de anidamiento porque hay procesos que llaman a otros —el recálculo en cadena
    /// dispara el motor una vez por período— y sin el contador el Cerrar del de adentro apagaría la
    /// ventana del de afuera, que sigue trabajando. El total y el contador son del PRIMERO que abre:
    /// es el que sabe cuántas son en realidad.
    /// </remarks>
    procedure Abrir(Total: Integer)
    begin
        FNivel += 1;
        if FAbierta then
            exit;
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
        FVentana.Update(3, StrSubstNo(TxtPaso, FActual, FTotal));

    end;

    // El lote informa el fin incluso si hubo un error controlado o se omitió el registro.
    // El porcentaje mide elementos procesados, no tiempo estimado ni cálculos exitosos.
    procedure FinalizarRegistro()
    begin
        if not FAbierta then
            exit;
        if FProcesadas < FTotal then
            FProcesadas += 1;
        ActualizarAvance();
    end;

    local procedure ActualizarAvance()
    var
        Porcentaje: Decimal;
    begin
        if FTotal > 0 then
            // Redondear hacia abajo evita mostrar 100 % antes del último elemento.
            Porcentaje := Round(FProcesadas / FTotal * 100, 0.1, '<');
        FVentana.Update(4, StrSubstNo(TxtAvance, Porcentaje, FProcesadas, FTotal));
    end;

    /// <summary>Qué está haciendo ahora mismo. La llama el motor, desde adentro del cálculo.</summary>
    procedure Paso(Texto: Text)
    begin
        if not FAbierta then
            exit;
        FVentana.Update(3, Texto);
    end;

    procedure Cerrar()
    begin
        if FNivel > 0 then
            FNivel -= 1;
        if FNivel > 0 then
            exit;
        if not FAbierta then
            exit;
        FVentana.Close();
        FAbierta := false;
        FTotal := 0;
        FActual := 0;
        FProcesadas := 0;
    end;
}
