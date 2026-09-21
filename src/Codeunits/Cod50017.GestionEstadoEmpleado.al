namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.HumanResources.Setup;
using Microsoft.Projects.Project.Job;
using Microsoft.Finance.Dimension;

codeunit 50017 "Gestión Estado Empleado"
{
    // Enforces the no-gap, no-overlap invariant on Estado Empleado.
    // All state changes must go through SetEstado — never insert directly.

    procedure SetSkipConflicts(Skip: Boolean)
    begin
        FSkipConflicts := Skip;
    end;

    // Creates/updates/removes the Estado Empleado linked to a Personal Proyecto assignment,
    // driven by the project's default state and the assignment's Fecha Alta/Baja. The one state
    // per (empleado, proyecto) is found via the "No. Proyecto" link, so it is updated in place
    // rather than duplicated. Insert/Modify run the state validations (overlap and non-reverted
    // liquidations), so any conflict surfaces as an error — never silently skipped.
    procedure SincronizarEstadoDesdeProyecto(PersProy: Record "Personal Proyecto")
    var
        Job: Record Job;
        Estado: Record "Estado Empleado";
        CodEstado: Code[20];
    begin
        if (PersProy."No. Empleado" = '') or (PersProy."No. Proyecto" = '') then
            exit;
        if Job.Get(PersProy."No. Proyecto") then
            CodEstado := Job."Estado Liq. Personal Predet.";

        Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
        Estado.SetRange("No. Empleado", PersProy."No. Empleado");
        Estado.SetRange("No. Proyecto", PersProy."No. Proyecto");

        // Incomplete assignment (no default state or no start date) → remove the linked state.
        if (CodEstado = '') or (PersProy."Fecha Alta Asignación" = 0D) then begin
            if Estado.FindFirst() then
                Estado.Delete(true);
            exit;
        end;

        // Effective-dated: the assignment maps to a single state that starts at Fecha Alta and
        // runs until the next state. The arrival/end transition (Fecha Baja → Francos/Órdenes) is
        // handled by the Cierre Marea automation via "Estado Siguiente", not stored here.
        if Estado.FindFirst() then begin
            // Skip when nothing state-relevant changed, so editing an unrelated assignment field
            // (e.g. Rol) doesn't touch the state and trip its liquidation guard.
            if (Estado."Cód. Estado" = CodEstado) and
               (Estado."Fecha Inicio" = PersProy."Fecha Alta Asignación") and
               (Estado."Fecha Fin" = PersProy."Fecha Baja")
            then
                exit;
            Estado."Cód. Estado" := CodEstado;
            Estado."Fecha Inicio" := PersProy."Fecha Alta Asignación";
            Estado."Fecha Fin" := PersProy."Fecha Baja";
            Estado.Modify(true);
        end else begin
            Estado.Init();
            Estado."Tipo Entidad" := Estado."Tipo Entidad"::Empleado;
            Estado."No. Empleado" := PersProy."No. Empleado";
            Estado."No. Proyecto" := PersProy."No. Proyecto";
            Estado."Cód. Estado" := CodEstado;
            Estado."Fecha Inicio" := PersProy."Fecha Alta Asignación";
            // La baja de la asignación es el fin del estado. Antes solo viajaba la fecha de alta y
            // el estado quedaba abierto: se cerraba recién cuando algo posterior lo empujaba, o no
            // se cerraba nunca. En blanco sigue significando abierto, que es lo correcto mientras la
            // asignación no tenga fecha de baja.
            Estado."Fecha Fin" := PersProy."Fecha Baja";
            Estado.Insert(true);
        end;
    end;

    /// <summary>
    /// Al cerrar una asignación, encadena la siguiente: estado que sigue, proyecto que le
    /// corresponde y alta del empleado ahí al día siguiente.
    /// </summary>
    /// <remarks>
    /// El caso real: un tripulante termina la navegación el 30/06. Su estado de navegación se cierra
    /// ese día, el 01/07 tiene que empezar Francos, y para que Francos exista en el historial el
    /// empleado tiene que estar asignado a un proyecto cuyo estado predeterminado sea Francos. Los
    /// tres pasos son uno solo: cerrar sin abrir lo siguiente deja al empleado sin estado desde el
    /// 01/07, y el motor no liquida a alguien sin estado.
    ///
    /// La cadena la declara "Estado Siguiente" en la ficha del estado, que es donde ya vivía para la
    /// transición de vacaciones. En blanco significa terminal: el estado no encadena y no se hace
    /// nada, que es lo correcto para una baja definitiva.
    ///
    /// El estado nuevo NO se escribe acá: se crea la asignación y el alta dispara la sincronización
    /// de siempre, que es la que traduce asignación → estado. Un solo lugar que sepa hacer eso.
    /// </remarks>
    procedure EncadenarSiguienteAsignacion(PersProy: Record "Personal Proyecto")
    var
        JobActual: Record Job;
        JobSiguiente: Record Job;
        CodEstadoActual: Record "Cód. Estado Empleado";
        PersSiguiente: Record "Personal Proyecto";
        FechaAlta: Date;
        Cuantos: Integer;
    begin
        if PersProy."Fecha Baja" = 0D then
            exit;
        if not JobActual.Get(PersProy."No. Proyecto") then
            exit;
        if JobActual."Estado Liq. Personal Predet." = '' then
            exit;
        if not CodEstadoActual.Get(JobActual."Estado Liq. Personal Predet.") then
            exit;
        if CodEstadoActual."Estado Siguiente" = '' then
            exit;

        // El proyecto de destino es el que declara ese estado como predeterminado. Sin proyecto no
        // hay a dónde asignar y el estado siguiente no se podría crear: se corta la operación entera
        // en vez de dejar la asignación cerrada y al empleado sin continuidad.
        JobSiguiente.SetRange("Estado Liq. Personal Predet.", CodEstadoActual."Estado Siguiente");
        Cuantos := JobSiguiente.Count();
        if Cuantos = 0 then
            Error(ErrSinProyectoParaEstado, CodEstadoActual."Estado Siguiente", CodEstadoActual.Código);
        if Cuantos > 1 then
            Error(ErrVariosProyectosParaEstado, Cuantos, CodEstadoActual."Estado Siguiente");
        JobSiguiente.FindFirst();

        FechaAlta := PersProy."Fecha Baja" + 1;

        if PersSiguiente.Get(PersProy."No. Empleado", JobSiguiente."No.") then begin
            // Ya estaba asignado a ese proyecto —vuelve a francos, por ejemplo—: se corre el alta al
            // día siguiente del cierre y la sincronización mueve el estado con ella.
            if PersSiguiente."Fecha Alta Asignación" = FechaAlta then
                exit;
            PersSiguiente."Fecha Alta Asignación" := FechaAlta;
            PersSiguiente."Fecha Baja" := 0D;
            PersSiguiente.Modify(true);
            exit;
        end;

        PersSiguiente.Init();
        PersSiguiente."No. Empleado" := PersProy."No. Empleado";
        PersSiguiente."No. Proyecto" := JobSiguiente."No.";
        PersSiguiente."Fecha Alta Asignación" := FechaAlta;
        PersSiguiente.Insert(true);
    end;

    // Removes the Estado Empleado linked to a Personal Proyecto assignment (on assignment delete).
    procedure EliminarEstadoDeProyecto(EmployeeNo: Code[20]; JobNo: Code[20])
    var
        Estado: Record "Estado Empleado";
    begin
        if (EmployeeNo = '') or (JobNo = '') then
            exit;
        Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
        Estado.SetRange("No. Empleado", EmployeeNo);
        Estado.SetRange("No. Proyecto", JobNo);
        if Estado.FindFirst() then
            Estado.Delete(true);
    end;

    procedure SetEstado(EmployeeNo: Code[20]; StateCode: Code[20]; StartDate: Date)
    begin
        SetEstadoEntidad("Tipo Entidad Estado"::Empleado, EmployeeNo, StateCode, StartDate);
    end;

    /// <summary>
    /// Al cerrar una marea, pone la fecha de baja en las asignaciones abiertas de ese proyecto.
    /// Devuelve cuántas cerró.
    /// </summary>
    /// <remarks>
    /// Cargar la fecha de arribo ES cerrar la marea, y hasta ahora eso no arrastraba nada: las
    /// asignaciones quedaban abiertas y, con ellas, los estados de navegación. El tripulante seguía
    /// "navegando" en un buque que ya estaba en puerto, y el control de días liquidados lo mostraba
    /// pidiendo liquidación de un mes entero de navegación que nunca ocurrió.
    ///
    /// No cierra los estados por su cuenta: pone la baja en la asignación y deja que el OnModify de
    /// Personal Proyecto haga lo suyo —cerrar el estado y encadenar el siguiente—, que es el camino
    /// que ya existía y el único que sabe qué viene después de navegar. Si esa cadena no se puede
    /// armar, el error revierte también el cierre de la marea: es preferible que la fecha de arribo
    /// no se guarde a que se guarde dejando a la tripulación sin estado desde el día siguiente.
    ///
    /// Junta las claves antes de escribir: el bucle no puede recorrer un filtro por "Fecha Baja" en
    /// blanco y a la vez completar ese campo, porque el primer registro que se cierra se sale del
    /// conjunto y el recorrido corta ahí.
    /// </remarks>
    procedure CerrarAsignacionesDeProyecto(NoProyecto: Code[20]; FechaCierre: Date) Cerradas: Integer
    var
        PersProy: Record "Personal Proyecto";
        Empleados: List of [Code[20]];
        EmpNo: Code[20];
    begin
        if (NoProyecto = '') or (FechaCierre = 0D) then
            exit(0);

        PersProy.SetRange("No. Proyecto", NoProyecto);
        PersProy.SetRange("Fecha Baja", 0D);
        PersProy.SetLoadFields("No. Empleado");
        if PersProy.FindSet() then
            repeat
                Empleados.Add(PersProy."No. Empleado");
            until PersProy.Next() = 0;

        foreach EmpNo in Empleados do
            if PersProy.Get(EmpNo, NoProyecto) then begin
                // Una asignación que arrancó DESPUÉS del arribo no es de esta marea cerrándose: es
                // alguien que ya fue reasignado. Cerrarla con una baja anterior a su alta dejaría un
                // rango invertido.
                if PersProy."Fecha Alta Asignación" <= FechaCierre then begin
                    PersProy.Validate("Fecha Baja", FechaCierre);
                    PersProy.Modify(true);
                    Cerradas += 1;
                end;
            end;
    end;

    // Effective-dated insert: a state is active from StartDate until the next state's Fecha Inicio.
    // Inserting is enough — the previous state's coverage shrinks automatically (its effective end is
    // derived, not stored). Only guards against overwriting a period already covered by a non-reverted
    // liquidation, and confirms when replacing a manual state that starts on the exact same date.
    procedure SetEstadoEntidad(TipoEntidad: Enum "Tipo Entidad Estado"; EntidadNo: Code[20]; StateCode: Code[20]; StartDate: Date)
    var
        EstadoEmp: Record "Estado Empleado";
        CodEstado: Record "Cód. Estado Empleado";
    begin
        if EntidadNo = '' then Error(ErrEmpleado);
        if StartDate = 0D then Error(ErrFechaVacia);
        CodEstado.Get(StateCode);

        if TipoEntidad = TipoEntidad::Empleado then
            ValidarNoHayLiquidacionesBloqueantes(EntidadNo, StartDate, 0D);

        // Ya hay un estado que arranca ESE MISMO DÍA → se reemplaza, no se agrega otro.
        //
        // El filtro NO incluye "No. Proyecto" a propósito. La clave única es (entidad, empleado,
        // proyecto, fecha), así que un estado creado por la asignación a un proyecto y otro creado
        // desde acá —que nace sin proyecto— pueden convivir el mismo día sin chocar. Y convivían: el
        // historial mostraba dos filas idénticas, salvo por un campo que la grilla ni siquiera
        // mostraba, y GetEstado elegía una de las dos sin criterio.
        //
        // Dos estados que empiezan el mismo día se contradicen, sin importar de dónde vino cada uno.
        EstadoEmp.SetRange("Tipo Entidad", TipoEntidad);
        EstadoEmp.SetRange("No. Empleado", EntidadNo);
        EstadoEmp.SetRange("Fecha Inicio", StartDate);
        if EstadoEmp.FindFirst() then begin
            if EstadoEmp."Cód. Estado" <> StateCode then begin
                if not FSkipConflicts then
                    if not Confirm(QstReemplazarEstadoActual, false, EstadoEmp."Cód. Estado", StartDate, StateCode) then
                        exit;
                EstadoEmp."Cód. Estado" := StateCode;
                EstadoEmp.Modify(true);
            end;
        end else begin
            Clear(EstadoEmp);
            EstadoEmp."Tipo Entidad" := TipoEntidad;
            EstadoEmp."No. Empleado" := EntidadNo;
            EstadoEmp."Fecha Inicio" := StartDate;
            EstadoEmp."Cód. Estado" := StateCode;
            EstadoEmp.Insert(true);
        end;
    end;

    // Called from Estado Empleado's OnInsert so the auto-transition fires no matter how the state was
    // entered (grid, SetEstado dialog, batch, cascade). For a Vacaciones state with an "Estado Siguiente",
    // materializes the return state at StartDate + LCT entitlement days.
    procedure AplicarAutoTransicion(EstadoEmp: Record "Estado Empleado")
    var
        CodEstado: Record "Cód. Estado Empleado";
    begin
        if EstadoEmp."Tipo Entidad" <> EstadoEmp."Tipo Entidad"::Empleado then exit;
        if not CodEstado.Get(EstadoEmp."Cód. Estado") then exit;
        AutoInsertarSiguienteVacaciones(EstadoEmp."No. Empleado", CodEstado, EstadoEmp."Fecha Inicio");
    end;

    // Materializes the return/next state in the history at StartDate + LCT entitlement days, so the
    // vacation window is explicitly bounded to the days of derecho. Skipped if another state already
    // interrupts the window (it already bounds the vacation — the count caps at entitlement anyway).
    local procedure AutoInsertarSiguienteVacaciones(EntidadNo: Code[20]; CodEstado: Record "Cód. Estado Empleado"; StartDate: Date)
    var
        CodSiguiente: Record "Cód. Estado Empleado";
        Interrupcion: Record "Estado Empleado";
        DiasDerecho: Integer;
        FechaRetorno: Date;
    begin
        if CodEstado."Tipo Estado" <> CodEstado."Tipo Estado"::Vacaciones then exit;
        if (CodEstado."Estado Siguiente" = '') or (CodEstado."Estado Siguiente" = CodEstado.Código) then exit;
        if not CodSiguiente.Get(CodEstado."Estado Siguiente") then exit;
        // A return-from-vacation must be a working state; skip vacation→vacation to avoid endless chains.
        if CodSiguiente."Tipo Estado" = CodSiguiente."Tipo Estado"::Vacaciones then exit;

        DiasDerecho := CalcDiasVacaciones(EntidadNo, StartDate);
        if DiasDerecho <= 0 then exit;
        FechaRetorno := StartDate + DiasDerecho;

        // Only inject when nothing already starts within (StartDate, FechaRetorno] — i.e. the vacation
        // would otherwise run open past the entitlement.
        Interrupcion.SetRange("Tipo Entidad", Interrupcion."Tipo Entidad"::Empleado);
        Interrupcion.SetRange("No. Empleado", EntidadNo);
        Interrupcion.SetRange("Fecha Inicio", StartDate + 1, FechaRetorno);
        if not Interrupcion.IsEmpty() then exit;

        SetEstadoEntidad("Tipo Entidad Estado"::Empleado, EntidadNo, CodEstado."Estado Siguiente", FechaRetorno);
    end;

    // On an active → inactive transition (a state that does NOT accrue francos, right after one that does),
    // assigns the employee to the marea's "Proyecto Inactividad Nómina" (or the HR Setup "Proyecto Nómina"
    // fallback) and links the inactive state to that project. Called from Estado Empleado's OnInsert; sets
    // Rec."No. Proyecto", which persists as part of the insert.
    procedure ResolverProyectoInactividad(var EstadoEmp: Record "Estado Empleado")
    var
        CodEstNuevo: Record "Cód. Estado Empleado";
        CodEstPrev: Record "Cód. Estado Empleado";
        EstadoPrev: Record "Estado Empleado";
        MareaJob: Record Job;
        HRSetup: Record "Human Resources Setup";
        PersMarea: Record "Personal Proyecto";
        PersInact: Record "Personal Proyecto";
        NoProyMarea: Code[20];
        NoProyInact: Code[20];
    begin
        if EstadoEmp."Tipo Entidad" <> EstadoEmp."Tipo Entidad"::Empleado then exit;
        if EstadoEmp."No. Proyecto" <> '' then exit;  // already linked to a project → nothing to resolve
        if not CodEstNuevo.Get(EstadoEmp."Cód. Estado") then exit;
        // "Transcurre en Marea" y no "Devenga Francos": la pregunta acá es si el estado SIGUE a bordo,
        // no si se trabaja. Con la bandera vieja, guardia en puerto, dique y pilotaje —que devengan
        // francos sin estar embarcados— nunca bajaban al proyecto de nómina y quedaban colgados de la
        // marea que acababa de terminar. En la migración eso dejó 12.324 guardias sobre el proyecto
        // anterior, una de ellas 3.904 días después del arribo.
        if CodEstNuevo."Transcurre en Marea" then exit;

        // El estado anterior tiene que haber estado EN MAREA para que esto sea una salida de la marea.
        if not GetEstadoEntidad(EstadoEmp."Tipo Entidad"::Empleado, EstadoEmp."No. Empleado", EstadoEmp."Fecha Inicio" - 1, EstadoPrev) then exit;
        if not CodEstPrev.Get(EstadoPrev."Cód. Estado") then exit;
        if not CodEstPrev."Transcurre en Marea" then exit;

        // Marea project = the previous (active) state's project, or the employee's active assignment.
        NoProyMarea := EstadoPrev."No. Proyecto";
        if NoProyMarea = '' then
            NoProyMarea := ProyectoActivoDe(EstadoEmp."No. Empleado", EstadoEmp."Fecha Inicio" - 1);
        if NoProyMarea = '' then exit;

        // Inactivity project: the marea's own, else the HR Setup fallback.
        if MareaJob.Get(NoProyMarea) then
            NoProyInact := MareaJob."Proyecto Inactividad Nómina";
        if NoProyInact = '' then
            if HRSetup.Get() then
                NoProyInact := HRSetup."Proyecto Nómina";
        if NoProyInact = '' then exit;

        // Assign the employee to the inactivity project so he keeps having a state.
        //
        // Antes esto además exigía que la asignación a la marea trajera convenio y categoría, y las
        // copiaba. El par ya no vive en la asignación —sale de los atributos del empleado, con su
        // historial— así que no hay nada que copiar. Se conserva el requisito de que la asignación a
        // la marea EXISTA, que es lo que dice "este empleado viene de navegar"; lo que se cae es una
        // condición que hoy sólo podría fallar por un dato vestigial.
        if not PersInact.Get(EstadoEmp."No. Empleado", NoProyInact) then
            if PersMarea.Get(EstadoEmp."No. Empleado", NoProyMarea) then begin
                PersInact.Init();
                PersInact."No. Empleado" := EstadoEmp."No. Empleado";
                PersInact."No. Proyecto" := NoProyInact;
                PersInact."Fecha Alta Asignación" := EstadoEmp."Fecha Inicio";
                PersInact.Insert(true);
            end;

        // Link the inactive state to the inactivity project.
        EstadoEmp."No. Proyecto" := NoProyInact;
    end;

    local procedure ProyectoActivoDe(EmpNo: Code[20]; Fecha: Date): Code[20]
    var
        PersProy: Record "Personal Proyecto";
        Job: Record Job;
    begin
        PersProy.SetRange("No. Empleado", EmpNo);
        if PersProy.FindSet() then
            repeat
                if Job.Get(PersProy."No. Proyecto") and (Job."Starting Date" <> 0D) and (Job."Starting Date" <= Fecha) then
                    if (Job."Ending Date" = 0D) or (Job."Ending Date" >= Fecha) then
                        exit(PersProy."No. Proyecto");
            until PersProy.Next() = 0;
        exit('');
    end;

    // Bounds an employee's Francos state to the franco balance available: when the francos run out on or
    // before FechaRef (they don't cover the period), materializes the state's "Estado Siguiente" (e.g.
    // Francos → Órdenes) at Fecha Inicio + saldo. Called before calculating a liquidation so the state
    // history — and thus DIAS_FRANCOS_PERIODO — reflects the transition.
    procedure AjustarEstadoFrancos(EmployeeNo: Code[20]; FechaRef: Date)
    var
        Estado: Record "Estado Empleado";
        CodEst: Record "Cód. Estado Empleado";
        Siguiente: Record "Estado Empleado";
        FrancosMgt: Codeunit "Gestión Francos";
        DiasDisp: Decimal;
        FechaTransicion: Date;
        PrevSkip: Boolean;
    begin
        if not GetEstadoEntidad("Tipo Entidad Estado"::Empleado, EmployeeNo, FechaRef, Estado) then exit;
        if not CodEst.Get(Estado."Cód. Estado") then exit;
        if CodEst."Tipo Estado" <> CodEst."Tipo Estado"::Francos then exit;
        if (CodEst."Estado Siguiente" = '') or (CodEst."Estado Siguiente" = CodEst.Código) then exit;

        DiasDisp := FrancosMgt.SaldoFrancosAFecha(EmployeeNo, Estado."Fecha Inicio");
        if DiasDisp <= 0 then exit;
        FechaTransicion := Estado."Fecha Inicio" + (DiasDisp div 1);

        // Francos still cover through the reference date → not exhausted yet, leave as is.
        if FechaTransicion > FechaRef then exit;

        // Already bounded within the balance (a state starts inside the window) → nothing to do.
        Siguiente.SetRange("Tipo Entidad", Siguiente."Tipo Entidad"::Empleado);
        Siguiente.SetRange("No. Empleado", EmployeeNo);
        Siguiente.SetRange("Fecha Inicio", Estado."Fecha Inicio" + 1, FechaTransicion);
        if not Siguiente.IsEmpty() then exit;

        PrevSkip := FSkipConflicts;
        FSkipConflicts := true;
        SetEstadoEntidad("Tipo Entidad Estado"::Empleado, EmployeeNo, CodEst."Estado Siguiente", FechaTransicion);
        FSkipConflicts := PrevSkip;
    end;

    // --- Vessel states & propagation to linked employees ---

    // Sets a vessel state and cascades to the employees on its active projects. Two behaviours:
    //   • Productive → improductive (e.g. arrival): each employee advances to their OWN current state's
    //     "Estado Siguiente" (e.g. embarcado → Francos), effective the day after — this is how francos
    //     start accruing consumption. Per-employee chain keeps it flexible across convenios.
    //   • Any other change: the vessel's own state code is propagated to the employees (shared states).
    procedure SetEstadoBuque(BuqueCode: Code[20]; StateCode: Code[20]; StartDate: Date)
    var
        CodEstadoNuevo: Record "Cód. Estado Empleado";
        CodEstadoPrev: Record "Cód. Estado Empleado";
        EstadoPrev: Record "Estado Empleado";
        EraProductivo: Boolean;
    begin
        CodEstadoNuevo.Get(StateCode);
        if not (CodEstadoNuevo."Ámbito" in [CodEstadoNuevo."Ámbito"::Buque, CodEstadoNuevo."Ámbito"::Ambos]) then
            Error(ErrAmbitoBuque, StateCode);

        if GetEstadoEntidad("Tipo Entidad Estado"::Buque, BuqueCode, StartDate - 1, EstadoPrev) then
            if CodEstadoPrev.Get(EstadoPrev."Cód. Estado") then
                EraProductivo := CodEstadoPrev."Devenga Francos";

        SetEstadoEntidad("Tipo Entidad Estado"::Buque, BuqueCode, StateCode, StartDate);

        if EraProductivo and not CodEstadoNuevo."Devenga Francos" then
            AvanzarEmpleadosAEstadoSiguiente(BuqueCode, StartDate + 1)
        else
            PropagarEstadoAEmpleadosDeBuque(BuqueCode, StateCode, StartDate);
    end;

    // On a productive → improductive vessel transition, moves each related employee to their current
    // state's "Estado Siguiente" (blank = no change), effective FechaTransicion (day after arrival).
    procedure AvanzarEmpleadosAEstadoSiguiente(BuqueCode: Code[20]; FechaTransicion: Date)
    var
        Job: Record Job;
        PersProy: Record "Personal Proyecto";
        EstadoActual: Record "Estado Empleado";
        CodEst: Record "Cód. Estado Empleado";
        PrevSkip: Boolean;
    begin
        PrevSkip := FSkipConflicts;
        FSkipConflicts := true;

        Job.SetRange("Global Dimension 1 Code", BuqueCode);
        Job.SetFilter("Starting Date", '<=%1', FechaTransicion - 1);
        Job.SetFilter("Ending Date", '%1|>=%2', 0D, FechaTransicion - 1);
        if Job.FindSet() then
            repeat
                PersProy.SetRange("No. Proyecto", Job."No.");
                if PersProy.FindSet() then
                    repeat
                        if PersProy."No. Empleado" <> '' then
                            if GetEstado(PersProy."No. Empleado", FechaTransicion - 1, EstadoActual) then
                                if CodEst.Get(EstadoActual."Cód. Estado") and (CodEst."Estado Siguiente" <> '') then
                                    SetEstado(PersProy."No. Empleado", CodEst."Estado Siguiente", FechaTransicion);
                    until PersProy.Next() = 0;
            until Job.Next() = 0;

        FSkipConflicts := PrevSkip;
    end;

    // Applies StateCode/StartDate to every employee assigned to a project of BuqueCode that is active on
    // StartDate. Only cascades states whose Ámbito includes Empleado; existing employee states on the same
    // date are left untouched.
    procedure PropagarEstadoAEmpleadosDeBuque(BuqueCode: Code[20]; StateCode: Code[20]; StartDate: Date)
    var
        Job: Record Job;
        PersProy: Record "Personal Proyecto";
        CodEstado: Record "Cód. Estado Empleado";
        PrevSkip: Boolean;
    begin
        if not CodEstado.Get(StateCode) then exit;
        if not (CodEstado."Ámbito" in [CodEstado."Ámbito"::Empleado, CodEstado."Ámbito"::Ambos]) then
            exit;

        PrevSkip := FSkipConflicts;
        FSkipConflicts := true;

        Job.SetRange("Global Dimension 1 Code", BuqueCode);
        Job.SetFilter("Starting Date", '<=%1', StartDate);
        Job.SetFilter("Ending Date", '%1|>=%2', 0D, StartDate);
        if Job.FindSet() then
            repeat
                PersProy.SetRange("No. Proyecto", Job."No.");
                if PersProy.FindSet() then
                    repeat
                        if PersProy."No. Empleado" <> '' then
                            SetEstado(PersProy."No. Empleado", StateCode, StartDate);
                    until PersProy.Next() = 0;
            until Job.Next() = 0;

        FSkipConflicts := PrevSkip;
    end;

    // Batch: apply StateCode/StartDate to a set of employees (typically a page selection). Returns the count.
    procedure SetEstadoEnLoteEmpleados(var Empleado: Record Employee; StateCode: Code[20]; StartDate: Date): Integer
    var
        PrevSkip: Boolean;
        Contador: Integer;
    begin
        if not Empleado.FindSet() then exit(0);
        PrevSkip := FSkipConflicts;
        FSkipConflicts := true;
        repeat
            SetEstado(Empleado."No.", StateCode, StartDate);
            Contador += 1;
        until Empleado.Next() = 0;
        FSkipConflicts := PrevSkip;
        exit(Contador);
    end;

    // Batch: apply a vessel state (with employee cascade) to a set of vessels (Global Dim. 1 values).
    // Recibe entidades y ya no valores de dimensión: la entidad es el maestro operativo, y así el
    // lote solo alcanza a lo que está clasificado. Un valor de dimensión sin entidad no es un buque
    // ni una planta todavía, y darle un estado no significaría nada.
    //
    // Las claves se juntan primero: SetEstadoBuque escribe estados y propaga a la tripulación, y no
    // conviene que un recorrido abierto dependa de lo que eso deje tocado.
    procedure SetEstadoEnLoteEntidades(var Entidad: Record "Entidad Liq."; StateCode: Code[20]; StartDate: Date): Integer
    var
        Codigos: List of [Code[20]];
        Codigo: Code[20];
        Contador: Integer;
    begin
        if not Entidad.FindSet() then exit(0);
        repeat
            Codigos.Add(Entidad.Código);
        until Entidad.Next() = 0;

        foreach Codigo in Codigos do begin
            SetEstadoBuque(Codigo, StateCode, StartDate);
            Contador += 1;
        end;
        exit(Contador);
    end;

    procedure GetEstado(EmployeeNo: Code[20]; AsOfDate: Date; var EstadoEmp: Record "Estado Empleado"): Boolean
    begin
        exit(GetEstadoEntidad("Tipo Entidad Estado"::Empleado, EmployeeNo, AsOfDate, EstadoEmp));
    end;

    // El estado vigente a una fecha es el de mayor Fecha Inicio <= AsOfDate, siempre que esa fecha no
    // haya pasado su Fecha Fin. El historial es contiguo, así que el corte solo se da al final: un
    // estado cerrado sin uno posterior (una baja) deja al empleado sin estado desde el día siguiente.
    procedure GetEstadoEntidad(TipoEntidad: Enum "Tipo Entidad Estado"; EntidadNo: Code[20]; AsOfDate: Date; var EstadoEmp: Record "Estado Empleado"): Boolean
    begin
        EstadoEmp.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        EstadoEmp.SetRange("Tipo Entidad", TipoEntidad);
        EstadoEmp.SetRange("No. Empleado", EntidadNo);
        EstadoEmp.SetFilter("Fecha Inicio", '<=%1', AsOfDate);
        if not EstadoEmp.FindLast() then
            exit(false);
        exit(AsOfDate <= EstadoEmp.FechaFinEfectiva());
    end;

    procedure GetEstadoActual(EmployeeNo: Code[20]; var EstadoEmp: Record "Estado Empleado"): Boolean
    begin
        EstadoEmp.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        EstadoEmp.SetRange("Tipo Entidad", EstadoEmp."Tipo Entidad"::Empleado);
        EstadoEmp.SetRange("No. Empleado", EmployeeNo);
        exit(EstadoEmp.FindLast());
    end;

    procedure TieneEstado(EmployeeNo: Code[20]): Boolean
    var
        EstadoEmp: Record "Estado Empleado";
    begin
        EstadoEmp.SetRange("Tipo Entidad", EstadoEmp."Tipo Entidad"::Empleado);
        EstadoEmp.SetRange("No. Empleado", EmployeeNo);
        exit(not EstadoEmp.IsEmpty());
    end;

    procedure ValidarEstadoExiste(EmployeeNo: Code[20]; AsOfDate: Date)
    var
        EstadoEmp: Record "Estado Empleado";
    begin
        if not GetEstado(EmployeeNo, AsOfDate, EstadoEmp) then
            Error(ErrSinEstado, EmployeeNo, AsOfDate);
    end;

    // Returns total completed years of service as of FechaRef.
    // Sums all Alta→Baja periods plus Antigüedad Reconocida, then calculates full anniversary years.
    procedure CalcAntiguedadAlFecha(EmployeeNo: Code[20]; FechaRef: Date): Decimal
    var
        TotalDias: Integer;
        FechaVirtual: Date;
        AnosCompletos: Integer;
    begin
        TotalDias := CalcDiasAntiguedad(EmployeeNo, FechaRef);
        if TotalDias <= 0 then exit(0);

        FechaVirtual := FechaRef - TotalDias;
        AnosCompletos := Date2DMY(FechaRef, 3) - Date2DMY(FechaVirtual, 3);
        if (Date2DMY(FechaRef, 2) < Date2DMY(FechaVirtual, 2)) or
           ((Date2DMY(FechaRef, 2) = Date2DMY(FechaVirtual, 2)) and
            (Date2DMY(FechaRef, 1) < Date2DMY(FechaVirtual, 1)))
        then
            AnosCompletos -= 1;
        exit(AnosCompletos);
    end;

    // Fractional seniority (whole completed years + fraction of the current year, rounded to
    // 0.1) — used by the AÑOS_ANTIGUEDAD system variable. CalcAntiguedadAlFecha above keeps
    // whole completed years only, on purpose: Art. 164/150 LCT vacation-day brackets need the
    // legally exact completed-year count, not an approximation, so that logic is untouched.
    // This variant is for formulas that want a smoother, prorated antiquity credit instead.
    procedure CalcAntiguedadFraccionAlFecha(EmployeeNo: Code[20]; FechaRef: Date): Decimal
    var
        TotalDias: Integer;
        FechaVirtual: Date;
        AnosCompletos: Integer;
        FechaAniversario: Date;
        FechaProximoAniversario: Date;
        DiasTranscurridos: Integer;
        DiasCiclo: Integer;
    begin
        TotalDias := CalcDiasAntiguedad(EmployeeNo, FechaRef);
        if TotalDias <= 0 then exit(0);

        FechaVirtual := FechaRef - TotalDias;
        AnosCompletos := Date2DMY(FechaRef, 3) - Date2DMY(FechaVirtual, 3);
        if (Date2DMY(FechaRef, 2) < Date2DMY(FechaVirtual, 2)) or
           ((Date2DMY(FechaRef, 2) = Date2DMY(FechaVirtual, 2)) and
            (Date2DMY(FechaRef, 1) < Date2DMY(FechaVirtual, 1)))
        then
            AnosCompletos -= 1;

        // Anniversary marking the last completed year and the next one, reconstructed from
        // FechaVirtual's own day/month — exact calendar dates, no 365.25 approximation drift.
        FechaAniversario := FechaMasAnios(FechaVirtual, AnosCompletos);
        FechaProximoAniversario := FechaMasAnios(FechaVirtual, AnosCompletos + 1);
        DiasTranscurridos := FechaRef - FechaAniversario;
        DiasCiclo := FechaProximoAniversario - FechaAniversario;
        if DiasCiclo <= 0 then exit(AnosCompletos);
        exit(AnosCompletos + Round(DiasTranscurridos / DiasCiclo, 0.1, '<'));
    end;

    /// <summary>Años completos de antigüedad al 30 de junio que rige para FechaRef.</summary>
    /// <remarks>
    /// El corte del Art. 32 del CCT: la antigüedad que se paga durante todo el año es la que el
    /// tripulante tenía al 30 de junio, no la de hoy. De julio en adelante rige el 30/06 de ese
    /// mismo año; de enero a junio, el del año anterior.
    ///
    /// Vive acá y no adentro del contexto de cálculo porque no la usa solo el motor: la consultan
    /// también las vistas de antigüedad, y el día que discrepen —una redondeando y la otra
    /// truncando, por ejemplo— la pantalla diría una cosa y el recibo otra sin que nadie lo note.
    /// </remarks>
    procedure CalcAntiguedadAl30Junio(EmployeeNo: Code[20]; FechaRef: Date): Decimal
    var
        Anio: Integer;
    begin
        if FechaRef = 0D then
            exit(0);
        Anio := Date2DMY(FechaRef, 3);
        if Date2DMY(FechaRef, 2) < 7 then
            Anio -= 1;
        exit(CalcAntiguedadAlFecha(EmployeeNo, DMY2Date(30, 6, Anio)));
    end;

    // Sum of all employment periods (Alta → Baja) + Antigüedad Reconocida, in calendar days.

    // Shared by CalcAntiguedadAlFecha and CalcAntiguedadFraccionAlFecha. Intermediate states
    // (Vacaciones, Enfermedad, Suspensión) are inside a period and included automatically;
    // only Baja states close a period.
    local procedure CalcDiasAntiguedad(EmployeeNo: Code[20]; FechaRef: Date): Integer
    var
        Emp: Record Employee;
        Fase: Record "Fase Alta Empleado";
        TotalDias: Integer;
        DiasReconocidos: Integer;
    begin
        if not Emp.Get(EmployeeNo) then exit(0);

        // LOS TRAMOS SALEN DE "Fase Alta Empleado", no de recorrer el historial de estados.
        //
        // Antes esto abría una fase en cada estado de tipo Alta y la cerraba en cada Baja. Funcionaba
        // mientras altas y bajas vivieran en el historial, pero las obligaba a ocupar un día que el
        // estado operativo también necesitaba: el día que alguien ingresa y embarca, las dos cosas
        // son ciertas y sólo una entraba. Ahora son ejes separados y el tramo ya está escrito.
        //
        // Lo que NO cambia es el criterio: los estados intermedios —vacaciones, enfermedad,
        // suspensión— están adentro del tramo y cuentan igual. Sólo la baja lo corta.
        TotalDias := Fase.CalcDiasHasta(EmployeeNo, FechaRef);

        // Red de seguridad para el empleado que todavía no tiene fase cargada: la ficha de BC trae
        // su fecha de ingreso y es mejor que devolver cero. No reemplaza a la fase —no sabe de
        // bajas ni de reingresos— pero evita que alguien liquide con antigüedad cero sin enterarse.
        if (TotalDias = 0) and (Emp."Employment Date" <> 0D) then
            TotalDias := FechaRef - Emp."Employment Date";

        DiasReconocidos := Round(Emp."Antigüedad Reconocida" * 365.25, 1, '<');
        TotalDias += DiasReconocidos;
        exit(TotalDias);
    end;

    // Advances FechaBase by Anios years, keeping the same day/month. 29/Feb in a target year
    // that isn't leap falls back to 28/Feb (same criterion a real anniversary would use).
    local procedure FechaMasAnios(FechaBase: Date; Anios: Integer): Date
    var
        Dia: Integer;
        Mes: Integer;
        Anio: Integer;
    begin
        Dia := Date2DMY(FechaBase, 1);
        Mes := Date2DMY(FechaBase, 2);
        Anio := Date2DMY(FechaBase, 3) + Anios;
        if (Dia = 29) and (Mes = 2) and not EsBisiesto(Anio) then
            Dia := 28;
        exit(DMY2Date(Dia, Mes, Anio));
    end;

    local procedure EsBisiesto(Anio: Integer): Boolean
    begin
        exit((Anio mod 4 = 0) and ((Anio mod 100 <> 0) or (Anio mod 400 = 0)));
    end;

    // Returns the number of vacation days the employee is entitled to per Art. 150 LCT,
    // based on seniority as of Dec 31 of the year in which FechaInicio falls (Art. 164 LCT).
    procedure CalcDiasVacaciones(EmployeeNo: Code[20]; FechaInicio: Date): Integer
    var
        Anios: Decimal;
        Fecha31Dic: Date;
    begin
        Fecha31Dic := DMY2Date(31, 12, Date2DMY(FechaInicio, 3));
        Anios := CalcAntiguedadAlFecha(EmployeeNo, Fecha31Dic);
        case true of
            Anios < 5:  exit(14);
            Anios < 10: exit(21);
            Anios < 20: exit(28);
            else        exit(35);
        end;
    end;

    local procedure ValidarNoHayLiquidacionesBloqueantes(EmployeeNo: Code[20]; FechaDesde: Date; FechaHasta: Date)
    var
        Liq: Record "Liquidación";
        Periodo: Record "Período Liquidación";
    begin
        Liq.SetRange("No. Empleado", EmployeeNo);
        Liq.SetFilter(Estado, '<>%1', Liq.Estado::Borrador);
        if not Liq.FindSet() then exit;
        repeat
            if Periodo.Get(Liq."Cód. Período") then
                if (CoberturaHasta(Liq, Periodo) >= FechaDesde) and
                   ((FechaHasta = 0D) or (Periodo."Fecha Desde" <= FechaHasta))
                then
                    Error(ErrLiquidacionesBloqueantes, Liq."Cód. Período", Liq."No.", Format(Liq.Estado));
        until Liq.Next() = 0;
    end;

    // Upper bound of what a liquidation actually settled. A Cierre de Marea settles at the arrival date
    // (Fecha Liquidación), not the full period end — so it doesn't block state changes made after arrival.
    local procedure CoberturaHasta(Liq: Record "Liquidación"; Periodo: Record "Período Liquidación"): Date
    var
        TipoLiqRec: Record "Tipo Liquidación";
    begin
        if TipoLiqRec.EsArribo(Liq."Cód. Tipo Liq.") and (Liq."Fecha Liquidación" <> 0D) then
            exit(Liq."Fecha Liquidación");
        exit(Periodo."Fecha Hasta");
    end;

    var
        FSkipConflicts: Boolean;
        ErrEmpleado: Label 'Debe especificar un empleado.';
        ErrFechaVacia: Label 'Debe especificar la fecha de inicio del nuevo estado.';
        ErrSinEstado: Label 'El empleado %1 no tiene un estado definido para la fecha %2.';
        ErrAmbitoBuque: Label 'El estado %1 no aplica a buques (su Ámbito debe ser Buque o Ambos).';
        ErrLiquidacionesBloqueantes: Label 'Existe una liquidación no revertida para el período %1 (Liq. %2, estado: %3). Revertí la liquidación antes de modificar el historial de estados.';
        AvisoAltaSinBaja: Label 'Esta fase quedó sin baja y hay un alta posterior. El cálculo de antigüedad pisa la fecha de inicio con la del alta siguiente, así que este tramo entero no cuenta.';
        AvisoBajaSinAlta: Label 'Baja sin un alta previa que cerrar. El cálculo de antigüedad la ignora.';
        QstReemplazarEstadoActual: Label 'El estado %1 que comienza el %2 será reemplazado por %3. ¿Confirmás el reemplazo?';
        ErrSinProyectoParaEstado: Label 'No hay ningún proyecto con "%1" como Estado Liq. Personal Predet., que es el estado que sigue a %2. Sin ese proyecto el empleado quedaría sin estado desde el día siguiente al cierre, así que no se guarda la fecha de baja. Cargá el proyecto de %1 y volvé a intentar.', Comment = '%1=estado siguiente, %2=estado actual';
        ErrVariosProyectosParaEstado: Label 'Hay %1 proyectos con "%2" como Estado Liq. Personal Predet. y no hay forma de saber a cuál asignar al empleado. Dejá uno solo con ese estado predeterminado, o asignalo a mano.', Comment = '%1=cantidad, %2=estado siguiente';
}
