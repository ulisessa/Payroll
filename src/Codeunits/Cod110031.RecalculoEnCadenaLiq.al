namespace UAS.Payroll;

/// <summary>
/// Rehace una liquidación y todos los períodos posteriores del mismo empleado, en orden.
/// </summary>
/// <remarks>
/// Es la salida del control de orden cronológico, y sin ella ese control sería una trampa: bloquea
/// recalcular marzo cuando abril ya tiene líneas, pero no hay forma de sacar del medio las líneas de
/// abril sin recalcularlo, y recalcular abril no arregla marzo.
///
/// La secuencia correcta es una sola: borrar las líneas de TODOS los posteriores, calcular el
/// período viejo, y volver a calcular los posteriores del más viejo al más nuevo. Cada uno vuelve a
/// leer el ledger tal como quedó después del anterior, que es la única forma de que los números
/// coincidan con los que habrían salido si se hubieran hecho en orden desde el principio.
///
/// Todo corre dentro de la misma transacción: si un período de la cadena falla, se revierte la
/// cadena entera. Dejarla a medio rehacer sería peor que el problema original — quedarían períodos
/// sin líneas y nadie sabría cuáles.
/// </remarks>
codeunit 110031 "Recálculo En Cadena Liq."
{
    Access = Public;

    /// <summary>Devuelve cuántas liquidaciones se recalcularon, contando la de partida.</summary>
    procedure Ejecutar(var Liq: Record "Liquidación"): Integer
    var
        Motor: Codeunit "Motor Liquidación";
        Posterior: Record "Liquidación";
        Actual: Record "Liquidación";
        Cadena: List of [Code[20]];
        NoLiq: Code[20];
        Recalculadas: Integer;
    begin
        Liq.TestField("No.");
        ArmarCadena(Liq, Cadena);

        // Primero se validan TODOS los estados y recién después se toca la primera. Cortar en el
        // medio porque el tercer período estaba aprobado deja los dos primeros sin líneas.
        Actual.Get(Liq."No.");
        if Actual.Estado in [Actual.Estado::Aprobada, Actual.Estado::Contabilizada] then
            Error(ErrPosteriorCerrada, Actual."No.", Actual."Cód. Período", Format(Actual.Estado));
        foreach NoLiq in Cadena do begin
            Posterior.Get(NoLiq);
            if Posterior.Estado in [Posterior.Estado::Aprobada, Posterior.Estado::Contabilizada] then
                Error(ErrPosteriorCerrada, Posterior."No.", Posterior."Cód. Período", Format(Posterior.Estado));
        end;

        // Se limpian todas las posteriores ANTES de calcular la de partida: son justamente sus líneas
        // las que el control de orden no deja pasar.
        foreach NoLiq in Cadena do begin
            Posterior.Get(NoLiq);
            Reabrir(Posterior);
            Motor.LimpiarLineas(NoLiq);
        end;

        Reabrir(Actual);
        Motor.LiquidarRecord(Actual);
        Recalculadas += 1;

        // Del más viejo al más nuevo: cada uno tiene que ver el ledger como lo dejó el anterior.
        foreach NoLiq in Cadena do begin
            Posterior.Get(NoLiq);
            Motor.LiquidarRecord(Posterior);
            Recalculadas += 1;
        end;

        exit(Recalculadas);
    end;

    /// <summary>
    /// Reabre la liquidación si está Calculada, usando el flujo normal de reapertura.
    /// </summary>
    /// <remarks>
    /// Pasa por "Gestión Liquidación".Reabrir y no cambia el estado a mano: Reabrir además libera los
    /// parámetros marcados En Uso, revierte las cuotas de préstamo y —lo que más se nota— devuelve
    /// las novedades a disponibles. Sin eso quedarían marcadas Aplicada contra un cálculo que se está
    /// deshaciendo, y el recálculo de la cadena no las volvería a tomar: el empleado perdería sus
    /// horas extras y sus ajustes justo en el proceso que existe para corregirle un error.
    /// </remarks>
    local procedure Reabrir(var Liq: Record "Liquidación")
    var
        Gestion: Codeunit "Gestión Liquidación";
    begin
        if Liq.Estado <> Liq.Estado::Calculada then
            exit;
        // Reabrir por su cuenta no deja tocar una liquidación con posteriores, y acá se están
        // reabriendo justamente ésas. Es el único llamador que puede pedir la excepción: la cadena
        // rehace todo lo que queda atrás en el mismo proceso y en la misma transacción, que es lo
        // que el control pide a cambio.
        Gestion.PermitirFueraDeOrden(true);
        Gestion.Reabrir(Liq);
    end;

    /// <summary>
    /// Deja en Posterior la primera liquidación posterior con líneas. False = no hay ninguna.
    /// </summary>
    /// <remarks>
    /// La usan los controles que tienen que nombrar el estorbo en el mensaje —"no se puede reabrir
    /// porque existe LIQ-000123"—. Es la primera en orden cronológico, que es la que conviene
    /// mostrar: si hay varias, es por donde hay que empezar a mirar.
    /// </remarks>
    procedure PrimeraPosterior(var Liq: Record "Liquidación"; var Posterior: Record "Liquidación"): Boolean
    var
        Lin: Record "Línea Liquidación";
    begin
        // FindFirst y no ArmarCadena: los controles solo necesitan saber si hay alguna y cuál nombrar
        // en el mensaje. Armar la lista entera leería todas las líneas de todos los períodos
        // posteriores para descartarlas enseguida, y esto corre una vez por liquidación en un lote.
        if not FiltrarPosteriores(Lin, Liq, false) then
            exit(false);
        if not Lin.FindFirst() then
            exit(false);
        exit(Posterior.Get(Lin."No. Liquidación"));
    end;

    /// <summary>Cuántas liquidaciones posteriores con líneas hay. Cero = no hace falta la cadena.</summary>
    procedure CuantasPosteriores(var Liq: Record "Liquidación"): Integer
    var
        Cadena: List of [Code[20]];
    begin
        ArmarCadena(Liq, Cadena);
        exit(Cadena.Count());
    end;

    /// <summary>
    /// Deja Lin filtrado a las líneas posteriores del empleado. False = no hay nada que buscar.
    /// </summary>
    /// <remarks>
    /// La ÚNICA definición de "liquidación posterior" del sistema: la usan el control de orden del
    /// motor, el control de reapertura y esta cadena. Estaba escrita tres veces y es una regla con
    /// tres sutilezas, cada una de las cuales se puede perder en una copia:
    ///
    /// 1. Se compara contra el fin del PERÍODO y no contra la fecha de referencia: dentro de un mismo
    ///    período conviven la Regular, los Devengados y el Cierre de Marea —éste fechado el día de
    ///    arribo, o sea antes que las otras— y entre ellas no hay un orden establecido.
    /// 2. Se buscan LÍNEAS y no cabeceras: una liquidación puede existir sin haberse calculado nunca,
    ///    y lo que ensucia el cálculo de la anterior son las líneas.
    /// 3. El BORRADOR cuenta o no según para qué se pregunte, y de ahí el parámetro:
    ///
    ///    Para BLOQUEAR (IncluirBorrador = false) no cuenta. Una posterior que existe pero no se
    ///    calculó, o que se reabrió, no aporta a ningún acumulador —anuales y del período ya
    ///    excluyen Borrador con este mismo criterio— y no tiene por qué frenar el trabajo del mes
    ///    anterior, que es lo más común que hay.
    ///
    ///    Para REHACER (IncluirBorrador = true) sí cuenta, y es importante: el ledger de francos lee
    ///    líneas sin mirar el estado, así que las líneas de una posterior reabierta siguen teniendo
    ///    tomados sus lotes. La cadena las borra antes de recalcular; si las dejara afuera, el
    ///    proceso que existe para que los números queden bien los dejaría mal por otro lado.
    ///
    /// Ordenadas por fecha ascendente: es el orden en el que hay que rehacerlas.
    /// </remarks>
    procedure FiltrarPosteriores(var Lin: Record "Línea Liquidación"; var Liq: Record "Liquidación"; IncluirBorrador: Boolean): Boolean
    var
        Periodo: Record "Período Liquidación";
    begin
        if not Periodo.Get(Liq."Cód. Período") then
            exit(false);
        if Periodo."Fecha Hasta" = 0D then
            exit(false);

        Lin.Reset();
        Lin.SetCurrentKey("No. Empleado", "Fecha Liquidación", "Tipo Concepto");
        Lin.Ascending(true);
        Lin.SetRange("No. Empleado", Liq."No. Empleado");
        Lin.SetFilter("Fecha Liquidación", '>%1', Periodo."Fecha Hasta");
        Lin.SetFilter("No. Liquidación", '<>%1', Liq."No.");
        if not IncluirBorrador then
            Lin.SetFilter(Estado, '<>%1', Lin.Estado::Borrador);
        Lin.SetLoadFields("No. Liquidación");
        exit(true);
    end;

    local procedure ArmarCadena(var Liq: Record "Liquidación"; var Cadena: List of [Code[20]])
    var
        Lin: Record "Línea Liquidación";
    begin
        Clear(Cadena);
        if not FiltrarPosteriores(Lin, Liq, true) then
            exit;

        if Lin.FindSet() then
            repeat
                if not Cadena.Contains(Lin."No. Liquidación") then
                    Cadena.Add(Lin."No. Liquidación");
            until Lin.Next() = 0;
    end;

    var
        ErrPosteriorCerrada: Label 'La liquidación %1 (período %2) está %3 y no se puede rehacer. Revertí su aprobación antes de recalcular en cadena.', Comment = '%1=No. liquidación, %2=período, %3=estado';
}
