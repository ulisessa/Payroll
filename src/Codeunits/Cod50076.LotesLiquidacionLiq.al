namespace UAS.Payroll;

/// <summary>
/// Las operaciones de lote sobre Liquidación —calcular, reabrir, aprobar, eliminar— en un solo lugar.
/// </summary>
/// <remarks>
/// Estaban escritas dentro de Lista Liquidaciones. Cuando el Árbol de Liquidaciones necesitó las
/// mismas acciones sobre el nodo donde uno está parado, copiarlas habría sido otra copia de una
/// lógica que ya hubo que arreglar varias veces: el bucle que se cortaba al modificar el campo
/// filtrado, el Codeunit.Run que devuelve el registro sin filtros, la sesión de registro compartida.
///
/// Cada procedimiento recibe un Record "Liquidación" YA FILTRADO al alcance que se quiere procesar y
/// NO le toca los filtros. No es una cuestión de estilo: cuando el alcance viene de
/// CurrPage.SetSelectionFilter, la plataforma puede expresar la selección copiando los filtros de la
/// página, y volver a filtrar acá un campo que la página ya filtraba REEMPLAZA ese filtro en vez de
/// acotarlo — la selección se ensancharía sola. El estado se verifica registro por registro.
/// </remarks>
codeunit 50076 "Lotes Liquidación Liq."
{
    Access = Public;

    /// <summary>
    /// Calcula las liquidaciones del alcance que estén en Borrador, Calculada o Aprobada.
    /// </summary>
    procedure Calcular(var Origen: Record "Liquidación")
    var
        Liq: Record "Liquidación";
        Motor: Codeunit "Motor Liquidación";
        Registro: Codeunit "Registro Procesos Liq.";
        Progreso: Codeunit "Progreso Liq.";
        Numeros: List of [Code[20]];
        Numero: Code[20];
        Total: Integer;
        Procesadas: Integer;
        Calculadas: Integer;
        Fallidas: Integer;
        Omitidas: Integer;
    begin
        if not RecolectarNumeros(Origen, Numeros) then begin
            Message(MsgSinSeleccion);
            exit;
        end;
        Total := Numeros.Count();

        // Una corrida = una sesión: los registros quedan agrupados y se pueden mirar todos juntos
        // desde cualquiera de ellos.
        Registro.IniciarSesion();
        Progreso.Abrir(Total);
        foreach Numero in Numeros do begin
            if Liq.Get(Numero) then begin
                Procesadas += 1;
                // El nombre sale del campo desnormalizado de la propia liquidación: en un lote de
                // cientos, un Get contra Employee por vuelta sería una lectura de más por nada.
                Progreso.Registro(Liq."No.", Liq."No. Empleado" + '  ' + Liq."Nombre Empleado");

                // Solo Borrador. Una liquidación ya calculada —o aprobada— se omite: recalcular en
                // lote lo que ya estaba listo es trabajo perdido cuando el alcance son cientos, y
                // sobre todo es silencioso, porque nada distingue en el resultado lo que hacía falta
                // recalcular de lo que ya estaba bien. Para rehacer una, se la reabre y vuelve a
                // Borrador, que es la forma explícita de decir "esta hay que calcularla de nuevo".
                if Liq.Estado = Liq.Estado::Borrador then begin
                    if Motor.LiquidarConRegistro(Liq) then
                        Calculadas += 1
                    else
                        Fallidas += 1;
                end else
                    Omitidas += 1;
            end;
            Progreso.FinalizarRegistro();
        end;
        Progreso.Cerrar();
        Registro.CerrarSesion();

        if Omitidas > 0 then
            Message(MsgOmitidas, Omitidas);

        // Una liquidación que falla ya no aborta el lote: queda anotada y el proceso sigue. Antes,
        // un error en la número 50 se llevaba puestas las 49 anteriores.
        if Fallidas > 0 then
            Message(MsgCalculadasConFallas, Calculadas, Fallidas)
        else
            if Motor.GetAdvertencias() <> '' then
                Message(MsgCalculadasConAdvertencias, Calculadas, Motor.GetAdvertencias())
            else
                Message(MsgCalculadas, Calculadas);
    end;

    /// <summary>
    /// Devuelve a Borrador las liquidaciones del alcance que estén en Calculada.
    /// </summary>
    procedure Reabrir(var Origen: Record "Liquidación")
    var
        Liq: Record "Liquidación";
        Gestion: Codeunit "Gestión Liquidación";
        Registro: Codeunit "Registro Procesos Liq.";
        Posterior: Record "Liquidación";
        Numeros: List of [Code[20]];
        Numero: Code[20];
        Reabiertas: Integer;
        Bloqueadas: Integer;
    begin
        if not RecolectarNumeros(Origen, Numeros) then begin
            Message(MsgSinSeleccionReabrir);
            exit;
        end;

        Registro.IniciarSesion();
        foreach Numero in Numeros do
            if Liq.Get(Numero) then
                // Se revalida el estado porque entre el armado de la lista y este punto el registro
                // pudo cambiar; Reabrir tira Error si no está Calculada.
                if Liq.Estado = Liq.Estado::Calculada then
                    // Las que tienen posteriores se saltean en vez de cortar el lote: en un alcance
                    // grande —un mes entero del árbol— siempre hay alguna, y un Error acá revierte
                    // también las que sí se reabrieron. Se cuentan y se informan al final.
                    if Gestion.PuedeReabrir(Liq, Posterior) then begin
                        Gestion.Reabrir(Liq);
                        Reabiertas += 1;
                    end else
                        Bloqueadas += 1;
        Registro.CerrarSesion();

        if Bloqueadas > 0 then
            Message(MsgReabiertasBloqueadas, Reabiertas, Numeros.Count(), Bloqueadas)
        else
            Message(MsgReabiertas, Reabiertas, Numeros.Count());
    end;

    /// <summary>
    /// Aprueba las liquidaciones del alcance que estén en Calculada.
    /// </summary>
    /// <remarks>
    /// A diferencia de Gestión Liquidación.Aprobar —que tira Error si el estado no es el esperado—
    /// acá las que no están en Calculada se omiten y se informan al final: en un lote es normal que
    /// convivan estados, y abortar por la primera dejaría el resto sin aprobar.
    /// </remarks>
    procedure Aprobar(var Origen: Record "Liquidación")
    var
        Liq: Record "Liquidación";
        Gestion: Codeunit "Gestión Liquidación";
        Registro: Codeunit "Registro Procesos Liq.";
        Numeros: List of [Code[20]];
        Numero: Code[20];
        Aprobadas: Integer;
    begin
        if not RecolectarNumeros(Origen, Numeros) then begin
            Message(MsgSinSeleccionAprobar);
            exit;
        end;

        Registro.IniciarSesion();
        foreach Numero in Numeros do
            if Liq.Get(Numero) then
                if Liq.Estado = Liq.Estado::Calculada then begin
                    Gestion.Aprobar(Liq);
                    Aprobadas += 1;
                end;
        Registro.CerrarSesion();

        Message(MsgAprobadas, Aprobadas, Numeros.Count());
    end;

    /// <summary>
    /// Elimina las liquidaciones del alcance que estén en Borrador. Pide confirmación.
    /// </summary>
    procedure Eliminar(var Origen: Record "Liquidación")
    var
        Liq: Record "Liquidación";
        Numeros: List of [Code[20]];
        Numero: Code[20];
        Eliminadas: Integer;
        Omitidas: Integer;
    begin
        if not RecolectarNumeros(Origen, Numeros) then
            exit;

        // La pregunta lleva el tamaño del alcance: desde el árbol se puede estar parado en un nodo
        // de período, y "las seleccionadas" no da ninguna idea de si son tres o trescientas.
        if not Confirm(StrSubstNo(QstEliminar, Numeros.Count())) then
            exit;

        foreach Numero in Numeros do
            if Liq.Get(Numero) then
                if Liq.Estado = Liq.Estado::Borrador then begin
                    Liq.Delete(true);
                    Eliminadas += 1;
                end else
                    Omitidas += 1;

        Message(MsgEliminadas, Eliminadas, Omitidas);
    end;

    /// <summary>
    /// Los números de liquidación del alcance, en una lista.
    /// </summary>
    /// <remarks>
    /// Las claves se juntan ANTES de tocar nada, y todos los bucles de este codeunit recorren la
    /// lista y no el registro. Hay dos razones distintas y las dos muerden:
    ///
    ///  · Reabrir y Eliminar cambian el Estado, que suele ser justo el campo por el que la página
    ///    está filtrada: al modificarlo el registro se cae del filtro y el Next() siguiente devuelve
    ///    0, así que el lote procesaba solo el primero y se cortaba sin avisar.
    ///  · Calcular resuelve con Ejecutor.Run(Liq), y un Codeunit.Run con parámetro de registro
    ///    devuelve el registro sin filtros ni marcas: después de la primera vuelta el recorrido se
    ///    escapaba del alcance y seguía por liquidaciones de otros períodos.
    /// </remarks>
    local procedure RecolectarNumeros(var Origen: Record "Liquidación"; var Numeros: List of [Code[20]]): Boolean
    begin
        Clear(Numeros);
        Origen.SetLoadFields("No.");
        // Solo se junta la clave: el registro completo se relee después, uno por uno.
        if not Origen.FindSet() then
            exit(false);
        repeat
            Numeros.Add(Origen."No.");
        until Origen.Next() = 0;
        exit(true);
    end;

    var
        MsgSinSeleccion: Label 'No hay liquidaciones en el alcance seleccionado.';
        MsgCalculadas: Label '%1 liquidación(es) calculada(s).';
        MsgCalculadasConFallas: Label '%1 liquidación(es) calculada(s), %2 con error.\\Las que fallaron quedaron sin calcular; el motivo de cada una está en Registros de Proceso.';
        MsgCalculadasConAdvertencias: Label '%1 liquidación(es) calculada(s).\\Atención — parámetros posiblemente desactualizados:\%2';
        MsgOmitidas: Label '%1 liquidación(es) del alcance quedaron sin calcular porque no están en Borrador. Las que ya están calculadas o aprobadas no se rehacen solas: reabrilas si querés recalcularlas.';
        MsgSinSeleccionReabrir: Label 'No hay liquidaciones en el alcance seleccionado.';
        MsgReabiertas: Label '%1 liquidación(es) reabierta(s) sobre %2 del alcance. El resto no estaba en estado Calculada.';
        MsgReabiertasBloqueadas: Label '%1 liquidación(es) reabierta(s) sobre %2 del alcance.\\%3 no se reabrieron porque el empleado tiene liquidaciones posteriores: reabrirlas liberaría novedades y cuotas que la posterior volvería a tomar. Usá "Recalcular en cadena" sobre cada una para rehacerla junto con sus posteriores.', Comment = '%1=reabiertas, %2=alcance, %3=bloqueadas';
        MsgSinSeleccionAprobar: Label 'No hay liquidaciones en el alcance seleccionado.';
        MsgAprobadas: Label '%1 liquidación(es) aprobada(s) sobre %2 del alcance. El resto no estaba en estado Calculada.';
        QstEliminar: Label '¿Eliminar las liquidaciones en estado Borrador del alcance seleccionado (%1 en total)? Las que no estén en Borrador se omitirán.';
        MsgEliminadas: Label '%1 liquidación(es) eliminada(s). %2 omitida(s) por no estar en Borrador.';
        // Los #n# son campos de texto y el @n@ es la barra de avance, que va de 0 a 10000.
        // El campo del empleado va más ancho que el resto: lleva número y nombre, y recortado a 20
        // caracteres el apellido quedaba cortado justo en los casos que uno quiere reconocer.
}
