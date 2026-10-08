namespace UAS.Payroll;

using Microsoft.Projects.Project.Job;

/// <summary>
/// Reparte los días del período entre las liquidaciones de un empleado, sin que ninguno caiga dos veces.
/// </summary>
/// <remarks>
/// LA REGLA: un día de estado se liquida UNA vez. Hoy se cumple sólo para el cierre de marea, que es
/// el único tipo que recorta su cobertura; la Regular, Vacaciones y Devengados reclaman los 31 días
/// del mes y se pisan entre sí. En enero de 2026 eso hizo que 133 empleados cobraran dos veces el
/// SAC devengado, la ART, las contribuciones, la jubilación y hasta Ganancias.
///
/// CÓMO SE REPARTE. Cada tipo declara en "Estado Tipo Liq." qué estados lo justifican; esos mismos
/// estados son los que define qué días cubre. Los tipos que no declaran ninguno se quedan con lo que
/// sobra, que es lo que hace la Regular: recoge los días que ninguna otra liquidación del empleado
/// reclamó.
///
/// EL ORDEN LO DECIDE EL ORDEN DEL TIPO, que ya existe y ya es único. Vacaciones (30) reclama antes
/// que la Regular (100), así que cuando la Regular pregunta qué queda, las vacaciones ya están
/// tomadas. Sin un orden determinista el reparto dependería de quién se calculó primero.
/// </remarks>
codeunit 110054 "Cobertura Tramos Liq."
{
    Access = Public;

    /// <summary>
    /// Recalcula los tramos de una liquidación. Devuelve cuántos días le quedaron.
    /// </summary>
    /// <remarks>
    /// Liq va por REFERENCIA y sale con "Cobertura Desde/Hasta" ajustados al envolvente de los
    /// tramos, pero SIN grabar: el que llama es el dueño del registro y lo persiste con su propio
    /// Modify. Hacerlo acá con un Get+Modify aparte le cambia el timestamp por debajo a la instancia
    /// que el motor ya tiene abierta, y el Modify del final del cálculo muere con "hay información
    /// que no está actualizada, cierre la página y vuelva a intentarlo".
    /// </remarks>
    procedure Recalcular(var Liq: Record "Liquidación") Dias: Integer
    var
        Tramo: Record "Tramo Cobertura Liq.";
        TipoLiqRec: Record "Tipo Liquidación";
        Linea: Record "Estado Tipo Liq.";
        Dia: Date;
        Desde: Date;
        Hasta: Date;
        MiosPorDia: Dictionary of [Integer, Text];
        Tomado: Dictionary of [Integer, Boolean];
        Motivo: Text;
        Inicio: Date;
        Fin: Date;
        Linea2: Integer;
    begin
        Tramo.SetRange("No. Liquidación", Liq."No.");
        Tramo.DeleteAll();

        Liq.Cobertura(Desde, Hasta);
        if (Desde = 0D) or (Hasta = 0D) then
            exit(0);

        // UN TIPO CON DISPARADOR DE MAREA YA VIENE RECORTADO por su cobertura: los días del viaje
        // son suyos y no se discuten con nadie. Se guarda tal cual, en un solo tramo.
        if TipoLiqRec.EsArribo(Liq."Cód. Tipo Liq.") then begin
            GuardarTramo(Liq."No.", Linea2, Desde, Hasta, 'Marea');
            exit(Hasta - Desde + 1);
        end;

        // LOS DÍAS QUE OTRAS YA RECLAMARON, una sola vez y para todos los caminos. Que los tipos con
        // estados declarados NO los consultaran fue el bug de la primera versión: el Cierre de Marea
        // se quedaba con el viaje y Devengados volvía a tomar esos mismos días de navegación, y
        // Vacaciones y la Regular se peleaban los días de AU9 —196 solapamientos en enero de 2026—.
        // Declarar un estado dice CUÁLES días te interesan, no que sean tuyos si ya son de otro.
        CargarTomados(Liq, Tomado);

        Linea.SetRange("Cód. Tipo Liq.", Liq."Cód. Tipo Liq.");
        Linea.SetRange(Modo, Linea.Modo::Exige);
        if Linea.FindSet() then
            // Con estados declarados, los días que cubre son los que esos estados ocupan y nadie tomó.
            repeat
                MarcarDiasDelEstado(Liq, Linea, Desde, Hasta, Tomado, MiosPorDia);
            until Linea.Next() = 0
        else
            // Sin estados declarados se queda con lo que sobra. Es el papel de la Regular.
            MarcarDiasLibres(Desde, Hasta, Tomado, MiosPorDia);

        // De días sueltos a tramos: se recorre el período y se corta cada vez que el día deja de ser
        // suyo o cambia el motivo. Guardar un tramo por día sería correcto y también ilegible.
        for Dia := Desde to Hasta do
            if MiosPorDia.ContainsKey(DiaEntero(Dia)) then begin
                if Inicio = 0D then begin
                    Inicio := Dia;
                    Motivo := MiosPorDia.Get(DiaEntero(Dia));
                end else
                    if MiosPorDia.Get(DiaEntero(Dia)) <> Motivo then begin
                        GuardarTramo(Liq."No.", Linea2, Inicio, Fin, Motivo);
                        Dias += Fin - Inicio + 1;
                        Inicio := Dia;
                        Motivo := MiosPorDia.Get(DiaEntero(Dia));
                    end;
                Fin := Dia;
            end else
                if Inicio <> 0D then begin
                    GuardarTramo(Liq."No.", Linea2, Inicio, Fin, Motivo);
                    Dias += Fin - Inicio + 1;
                    Inicio := 0D;
                end;
        if Inicio <> 0D then begin
            GuardarTramo(Liq."No.", Linea2, Inicio, Fin, Motivo);
            Dias += Fin - Inicio + 1;
        end;

        AjustarCabeceraAlEnvolvente(Liq);
    end;

    /// <summary>Lleva el "Cobertura Desde/Hasta" de la cabecera al envolvente de los tramos.</summary>
    /// <remarks>
    /// El cálculo mira los TRAMOS, así que esto no mueve ningún importe: mueve lo que la ficha dice.
    /// Y lo que decía era el mes entero para todos los tipos que no recortan —una liquidación de
    /// Vacaciones de alguien que se fue el 5 anunciaba "del 1 al 31" mientras su único tramo era del
    /// 5 al 31—, que es justo el dato con el que uno compara contra el recibo de Meta4.
    ///
    /// Escribe en el registro del llamador y NO graba: ver la nota de Recalcular.
    ///
    /// No realimenta el reparto: Cobertura() deriva la ventana del PERÍODO y no lee estos campos, así
    /// que un segundo Recalcular vuelve a partir del mes entero y puede recuperar días que antes cedió.
    ///
    /// Sin tramos no se toca nada. Una liquidación que no cubre ningún día es un problema en sí misma
    /// —el control de cobertura la muestra— y vaciarle las fechas sólo la haría más difícil de mirar.
    /// </remarks>
    local procedure AjustarCabeceraAlEnvolvente(var Liq: Record "Liquidación")
    var
        Tramo: Record "Tramo Cobertura Liq.";
        Desde: Date;
        Hasta: Date;
    begin
        Tramo.SetRange("No. Liquidación", Liq."No.");
        if not Tramo.FindSet() then
            exit;
        Desde := Tramo.Desde;
        Hasta := Tramo.Hasta;
        repeat
            if Tramo.Desde < Desde then Desde := Tramo.Desde;
            if Tramo.Hasta > Hasta then Hasta := Tramo.Hasta;
        until Tramo.Next() = 0;

        Liq."Cobertura Desde" := Desde;
        Liq."Cobertura Hasta" := Hasta;
    end;

    /// <summary>Los días que las OTRAS liquidaciones del empleado en el período ya reclamaron.</summary>
    /// <remarks>
    /// Mira los tramos, no el "Cobertura Desde/Hasta" de la cabecera: el envolvente de una
    /// liquidación con huecos se comería los días de los huecos, que son justamente los que se
    /// buscan. Y sólo cuentan las que YA tienen tramos: una que todavía no se calculó no reclamó
    /// nada, y por eso el Orden del tipo importa.
    /// </remarks>
    local procedure CargarTomados(Liq: Record "Liquidación"; var Tomado: Dictionary of [Integer, Boolean])
    var
        Otra: Record "Liquidación";
        Tramo: Record "Tramo Cobertura Liq.";
        Dia: Date;
    begin
        Otra.SetRange("Cód. Período", Liq."Cód. Período");
        Otra.SetRange("No. Empleado", Liq."No. Empleado");
        Otra.SetFilter("No.", '<>%1', Liq."No.");
        if not Otra.FindSet() then
            exit;
        repeat
            Tramo.SetRange("No. Liquidación", Otra."No.");
            if Tramo.FindSet() then
                repeat
                    for Dia := Tramo.Desde to Tramo.Hasta do
                        if not Tomado.ContainsKey(DiaEntero(Dia)) then
                            Tomado.Add(DiaEntero(Dia), true);
                until Tramo.Next() = 0;
        until Otra.Next() = 0;
    end;

    /// <summary>Los días libres en que el empleado tiene el estado que la línea exige.</summary>
    local procedure MarcarDiasDelEstado(Liq: Record "Liquidación"; Linea: Record "Estado Tipo Liq."; Desde: Date; Hasta: Date; var Tomado: Dictionary of [Integer, Boolean]; var MiosPorDia: Dictionary of [Integer, Text])
    var
        Estado: Record "Estado Empleado";
        Job: Record Job;
        Dia: Date;
        FinEstado: Date;
        Cuenta: Boolean;
        TipoJob: Integer;
    begin
        Estado.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
        Estado.SetRange("No. Empleado", Liq."No. Empleado");
        Estado.SetFilter("Fecha Inicio", '<=%1', Hasta);
        Estado.SetFilter("Fecha Fin", '%1|>=%2', 0D, Desde);
        // Filtro, no código suelto: ver el campo en "Estado Tipo Liq.". Va directo a SQL.
        if Linea."Cód. Estado" <> '' then
            Estado.SetFilter("Cód. Estado", Linea."Cód. Estado");
        if not Estado.FindSet() then
            exit;

        repeat
            // MISMO CRITERIO QUE LA GUARDA QUE DECIDE SI CREAR: un estado sin proyecto cuenta como
            // improductivo —son los días de tierra—, y un proyecto con Tipo = Todos, o que no
            // existe, NO bloquea. "Todos" es sin clasificar, no "ninguno". Compararlo estricto dejó
            // al 04901 sin liquidación: sus proyectos de nómina no tienen fila en la extensión, así
            // que su Tipo se lee cero.
            Cuenta := Linea."Tipo Proyecto" = Linea."Tipo Proyecto"::Todos;
            if not Cuenta then
                if Estado."No. Proyecto" = '' then
                    Cuenta := Linea."Tipo Proyecto" = Linea."Tipo Proyecto"::Improductivo
                else
                    if not Job.Get(Estado."No. Proyecto") then
                        Cuenta := true
                    else begin
                        // Por el ordinal: la opción cero del Tipo del Job no tiene nombre.
                        TipoJob := Job.Tipo;
                        Cuenta := (TipoJob = 0) or (TipoJob = Linea."Tipo Proyecto");
                    end;

            if Cuenta then begin
                FinEstado := Estado."Fecha Fin";
                if (FinEstado = 0D) or (FinEstado > Hasta) then
                    FinEstado := Hasta;
                for Dia := Estado."Fecha Inicio" to FinEstado do
                    if (Dia >= Desde) and (Dia <= Hasta) then
                        if not Tomado.ContainsKey(DiaEntero(Dia)) then
                            if not MiosPorDia.ContainsKey(DiaEntero(Dia)) then
                                MiosPorDia.Add(DiaEntero(Dia), Estado."Cód. Estado");
            end;
        until Estado.Next() = 0;
    end;

    /// <summary>Los días del período que ninguna OTRA liquidación del empleado reclamó. El resto.</summary>
    local procedure MarcarDiasLibres(Desde: Date; Hasta: Date; var Tomado: Dictionary of [Integer, Boolean]; var MiosPorDia: Dictionary of [Integer, Text])
    var
        Dia: Date;
    begin
        for Dia := Desde to Hasta do
            if not Tomado.ContainsKey(DiaEntero(Dia)) then
                MiosPorDia.Add(DiaEntero(Dia), 'Resto del período');
    end;

    local procedure GuardarTramo(NoLiq: Code[20]; var Linea: Integer; Desde: Date; Hasta: Date; Origen: Text)
    var
        Tramo: Record "Tramo Cobertura Liq.";
    begin
        Linea += 10000;
        Tramo.Init();
        Tramo."No. Liquidación" := NoLiq;
        Tramo."No. Línea" := Linea;
        Tramo.Desde := Desde;
        Tramo.Hasta := Hasta;
        Tramo.Origen := CopyStr(Origen, 1, MaxStrLen(Tramo.Origen));
        Tramo.Insert(true);
    end;

    // Los días como entero para poder usarlos de clave. El origen es arbitrario: sólo importa que
    // sea el mismo para todos los diccionarios que se comparan.
    local procedure DiaEntero(D: Date): Integer
    begin
        exit(D - DMY2Date(1, 1, 2000));
    end;
}
