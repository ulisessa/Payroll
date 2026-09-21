namespace UAS.Payroll;

using Microsoft.Projects.Project.Job;
using Microsoft.HumanResources.Employee;
using Microsoft.HumanResources.Setup;
using Microsoft.Foundation.NoSeries;

codeunit 50050 "Proceso Liq. Por Lote"
{
    // Batch creation and calculation of liquidations.
    // Called from Job Card actions (per-project) and from Lanzador Liquidaciones page (multi-project).

    procedure CrearPorProyecto(var Job: Record Job; CodPeriodo: Code[10]; TipoLiq: Code[20]): Integer
    var
        Periodo: Record "Período Liquidación";
        Personal: Record "Personal Proyecto";
        Creadas: Integer;
    begin
        Periodo.Get(CodPeriodo);
        if Periodo.Estado = Periodo.Estado::Cerrado then
            Error(ErrPeriodoCerrado, CodPeriodo);

        AplicarFiltroPersonal(Personal, Job, TipoLiq, CodPeriodo);
        if not Personal.FindSet() then
            exit(0);

        repeat
            if not EstuvoEnLaEmpresa(Personal."No. Empleado", Periodo) then
                OmitidosSinFase += 1
            else
                if CrearSiFalta(Personal, CodPeriodo, TipoLiq) <> '' then
                    Creadas += 1;
        until Personal.Next() = 0;

        exit(Creadas);
    end;

    /// <summary>
    /// Crea la liquidación según la agrupación de su tipo. Devuelve su No., o '' si ya existe.
    /// </summary>
    /// <remarks>
    /// Comparte la regla entre el lanzador, la ficha del proyecto y Personal Proyecto.
    /// Para tipos agrupados busca por empleado, período y tipo, sin limitar por proyecto.
    /// La consulta a la base también evita duplicados entre corridas sucesivas.
    /// </remarks>
    local procedure CrearSiFalta(Personal: Record "Personal Proyecto"; CodPeriodo: Code[10]; TipoLiq: Code[20]): Code[20]
    var
        TipoLiqRec: Record "Tipo Liquidación";
    begin
        if TipoLiqRec.Get(TipoLiq) and TipoLiqRec."Agrupa por Empleado" then begin
            if LiqExisteEmpleado(Personal."No. Empleado", CodPeriodo, TipoLiq) then
                exit('');
            exit(InsertarLiquidacionEmpleado(Personal."No. Empleado", CodPeriodo, TipoLiq));
        end;

        if LiqExiste(Personal."No. Empleado", Personal."No. Proyecto", CodPeriodo, TipoLiq) then
            exit('');
        exit(InsertarLiquidacion(Personal, CodPeriodo, TipoLiq));
    end;

    /// <summary>
    /// La pregunta que faltaba: ¿esta persona pertenecía a la empresa durante el período?
    /// </summary>
    /// <remarks>
    /// La selección del lote mira "Personal Proyecto" y nada más. Esa tabla tiene una fila por par
    /// empleado+proyecto —así lo fija su clave primaria— así que la asignación de alguien que estuvo
    /// en el mismo barco en dos temporadas es UNA sola, con la fecha del primer embarque y la del
    /// último desembarque, atravesando los meses en que la persona estaba dada de baja. No hay forma
    /// de arreglar eso en el dato: la fila no puede partirse en dos. Se arregla acá.
    ///
    /// Medido sobre enero de 2026: 46 empleados entraban al lote sin una fase que cubriera el mes,
    /// 42 de ellos por este motivo exacto —baja entre julio y diciembre de 2025, reingreso entre
    /// febrero y mayo de 2026—. Las 47 liquidaciones que se generaron salieron las 47 sin una sola
    /// línea, que es lo que pasa cuando no hay días que liquidar.
    /// </remarks>
    local procedure EstuvoEnLaEmpresa(EmpNo: Code[20]; Periodo: Record "Período Liquidación"): Boolean
    var
        Fase: Record "Fase Alta Empleado";
    begin
        exit(Fase.EstuvoActivoEntre(EmpNo, Periodo."Fecha Desde", Periodo."Fecha Hasta"));
    end;

    /// <summary>
    /// Cuántos empleados se saltearon por no tener fase en el período.
    /// </summary>
    /// <remarks>
    /// El contador NO se reinicia en ningún lado y no hace falta: esta codeunit no es SingleInstance,
    /// así que cada acción que la declara como variable local arranca con una instancia nueva y el
    /// contador en cero. Que se acumule dentro de una misma corrida es justo lo que se quiere — el
    /// lanzador llama a CrearPorPeriodo y después a CrearRegularEmpleadosEnFrancos sobre la misma
    /// instancia, y el aviso tiene que sumar los dos.
    /// </remarks>
    procedure OmitidosPorFase(): Integer
    begin
        exit(OmitidosSinFase);
    end;

    /// <summary>
    /// Avisa de los omitidos, si hubo. No hace nada si no hubo.
    /// </summary>
    /// <remarks>
    /// Va aparte del "se crearon N" y no mezclado en él: son dos hechos distintos y el segundo pide
    /// una acción. Y va SIEMPRE, porque un descarte que no se ve es el peor de los dos mundos — es
    /// el mismo problema que dejó a "Crear Devengados" devolviendo 0 sin decir por qué.
    /// </remarks>
    procedure AvisarOmitidos()
    begin
        if OmitidosSinFase = 0 then
            exit;
        Message(MsgOmitidosSinFase, OmitidosSinFase);
    end;

    /// <summary>
    /// Crea la liquidación de UNA asignación de personal. Devuelve su No., o '' si ya existía.
    /// </summary>
    /// <remarks>
    /// Usa la misma regla de agrupación y duplicados que la creación por proyecto para el alta de a
    /// uno desde la lista de Personal Proyecto. Esa acción armaba la cabecera a mano y se le
    /// escapaban el período, el tipo y el nombre del empleado: las liquidaciones nacían sin tipo, y
    /// sin tipo el motor filtra mal los conceptos restringidos por tipo sin avisar de nada.
    /// </remarks>
    procedure CrearParaAsignacion(Personal: Record "Personal Proyecto"; CodPeriodo: Code[10]; TipoLiq: Code[20]): Code[20]
    var
        Periodo: Record "Período Liquidación";
    begin
        Periodo.Get(CodPeriodo);
        if Periodo.Estado = Periodo.Estado::Cerrado then
            Error(ErrPeriodoCerrado, CodPeriodo);
        // Acá corta con error y no salteando en silencio como el lote: esto es un alta de a uno,
        // pedida a propósito sobre un empleado concreto. Si no se puede, hay que decir por qué.
        if not EstuvoEnLaEmpresa(Personal."No. Empleado", Periodo) then
            Error(ErrSinFaseEnPeriodo, Personal."No. Empleado", CodPeriodo);
        exit(CrearSiFalta(Personal, CodPeriodo, TipoLiq));
    end;

    // Creates Cierre Marea liquidations for a voyage, deriving the reporting period from the
    // voyage arrival date (project Ending Date). No period prompt: a tide settles at arrival.
    procedure CrearCierreMarea(var Job: Record Job): Integer
    var
        TipoLiqRec: Record "Tipo Liquidación";
        CodPeriodo: Code[10];
    begin
        if Job."Ending Date" = 0D then
            Error(ErrSinArribo, Job."No.");
        CodPeriodo := DerivarPeriodoPorFecha(Job."Ending Date");
        exit(CrearPorProyecto(Job, CodPeriodo, TipoLiqRec.CodigoArribo()));
    end;

    // Returns the period whose [Fecha Desde, Fecha Hasta] range contains the given date.
    local procedure DerivarPeriodoPorFecha(Fecha: Date): Code[10]
    var
        Periodo: Record "Período Liquidación";
    begin
        Periodo.SetFilter("Fecha Desde", '<=%1', Fecha);
        Periodo.SetFilter("Fecha Hasta", '>=%1', Fecha);
        if not Periodo.FindFirst() then
            Error(ErrSinPeriodo, Fecha);
        exit(Periodo.Código);
    end;

    // Creates Regular liquidations (per-employee, no project) for employees who were in a Francos state
    // during the period. Francos are enjoyed in port between mareas, so these employees have no project
    // assignment and are not reached by the project-based creation. Skips employees who already have a
    // Regular for the period (e.g. a project-based one).
    procedure CrearRegularEmpleadosEnFrancos(CodPeriodo: Code[10]): Integer
    var
        Periodo: Record "Período Liquidación";
        Estado: Record "Estado Empleado";
        CodEst: Record "Cód. Estado Empleado";
        TipoLiqRec: Record "Tipo Liquidación";
        CodTipoLiq: Code[20];
        Procesados: List of [Code[20]];
        Creadas: Integer;
    begin
        Periodo.Get(CodPeriodo);
        if Periodo.Estado = Periodo.Estado::Cerrado then
            Error(ErrPeriodoCerrado, CodPeriodo);

        CodTipoLiq := TipoLiqRec.CodigoFrancosPuerto();
        if CodTipoLiq = '' then exit(0);

        Estado.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
        Estado.SetFilter("Fecha Inicio", '<=%1', Periodo."Fecha Hasta");
        if Estado.FindSet() then
            repeat
                if not Procesados.Contains(Estado."No. Empleado") then
                    if CodEst.Get(Estado."Cód. Estado") and (CodEst."Tipo Estado" = CodEst."Tipo Estado"::Francos) then
                        if Estado.FechaFinEfectiva() >= Periodo."Fecha Desde" then begin
                            Procesados.Add(Estado."No. Empleado");
                            // Misma guarda que la creación por proyecto, y acá hace todavía más
                            // falta: este camino entra por un estado ABIERTO, y un estado que nunca
                            // se cerró se solapa con cualquier período posterior. El legajo 02678
                            // tiene un Franco abierto desde marzo de 2001.
                            if not EstuvoEnLaEmpresa(Estado."No. Empleado", Periodo) then
                                OmitidosSinFase += 1
                            else
                                if not LiqExisteEmpleado(Estado."No. Empleado", CodPeriodo, CodTipoLiq) then begin
                                    InsertarLiquidacionEmpleado(Estado."No. Empleado", CodPeriodo, CodTipoLiq);
                                    Creadas += 1;
                                end;
                        end;
            until Estado.Next() = 0;

        exit(Creadas);
    end;

    procedure CrearPorPeriodo(CodPeriodo: Code[10]; TipoLiq: Code[20]): Integer
    var
        Periodo: Record "Período Liquidación";
        TipoLiqRec: Record "Tipo Liquidación";
        Job: Record Job;
        Creadas: Integer;
    begin
        Periodo.Get(CodPeriodo);
        if Periodo.Estado = Periodo.Estado::Cerrado then
            Error(ErrPeriodoCerrado, CodPeriodo);

        AplicarFiltroJobs(Job, TipoLiq, Periodo);
        if not Job.FindSet() then begin
            Message(MsgNinguno);
            exit(0);
        end;

        repeat
            Creadas += CrearPorProyecto(Job, CodPeriodo, TipoLiq);
        until Job.Next() = 0;

        exit(Creadas);
    end;

    procedure CalcularPorPeriodo(CodPeriodo: Code[10]; TipoLiq: Code[20]): Integer
    var
        Liq: Record "Liquidación";
        LiqAct: Record "Liquidación";
        Motor: Codeunit "Motor Liquidación";
        Registro: Codeunit "Registro Procesos Liq.";
        Numeros: List of [Code[20]];
        Numero: Code[20];
        Progreso: Codeunit "Progreso Liq.";
        Calculadas: Integer;
        Total: Integer;
    begin
        Liq.SetRange("Cód. Período", CodPeriodo);
        Liq.SetRange("Cód. Tipo Liq.", TipoLiq);
        // Solo Borrador, igual que el cálculo por selección: lo ya calculado o aprobado no se rehace
        // en un proceso masivo. Para recalcular hay que reabrir, que es la forma explícita de pedirlo.
        Liq.SetRange(Estado, Liq.Estado::Borrador);
        Total := Liq.Count();
        if Total = 0 then
            exit(0);
        // Las claves se juntan ANTES de calcular, y el bucle recorre la lista y no el registro.
        // Iterando directo, el lote se comía TODA la tabla: LiquidarConRegistro resuelve con
        // Ejecutor.Run(Liq), y un Codeunit.Run con parámetro de registro devuelve el registro tal
        // como quedó en el Rec del codeunit — sin filtros. Después de la primera vuelta se perdían
        // los filtros de período y tipo, y el Next() seguía por liquidaciones de otros períodos.
        Liq.FindSet();
        repeat
            Numeros.Add(Liq."No.");
        until Liq.Next() = 0;

        Progreso.Abrir(Total);
        // Toda la corrida comparte sesión: desde cualquier registro se puede ver el lote completo.
        Registro.IniciarSesion();
        foreach Numero in Numeros do begin
            if LiqAct.Get(Numero) then begin
                Calculadas += 1;
                Progreso.Registro(LiqAct."No.", LiqAct."No. Empleado" + '  ' + LiqAct."Nombre Empleado");
                // Sin relanzar: una liquidación que falla queda anotada en su registro y el lote
                // sigue, en vez de abortar y perder todo lo calculado hasta ese punto.
                if Motor.LiquidarConRegistro(LiqAct) then;
            end;
            Progreso.FinalizarRegistro();
        end;
        Registro.CerrarSesion();
        Progreso.Cerrar();
        exit(Calculadas);
    end;

    local procedure AplicarFiltroJobs(var Job: Record Job; TipoLiq: Code[20]; Periodo: Record "Período Liquidación")
    var
        TipoLiqRec: Record "Tipo Liquidación";
        TipoProyecto: Integer;
        SoloEnCurso: Boolean;
    begin
        Job.Reset();

        // La clase de proyecto la declara el TIPO, no la elige quien corre el proceso. Los ordinales
        // son los de Job.Tipo: 0=Todos, 1=Productivo, 2=Improductivo.
        //
        // El Get y la lectura del campo van en sentencias separadas a propósito: AL no cortocircuita,
        // así que un "Get(...) and Campo" evalúa igual el lado derecho, y con el registro sin
        // encontrar eso lee lo que haya quedado adentro.
        if TipoLiqRec.Get(TipoLiq) then begin
            TipoProyecto := TipoLiqRec."Tipo Proyecto";
            SoloEnCurso := TipoLiqRec."Sólo Proyectos en Curso";
        end;
        if TipoProyecto > 0 then
            Job.SetRange(Tipo, TipoProyecto);

        if TipoLiqRec.EsArribo(TipoLiq) then
            // Voyages whose return date falls within the period
            Job.SetRange("Ending Date", Periodo."Fecha Desde", Periodo."Fecha Hasta")
        else begin
            // EL Status DEL PROYECTO NO SE USA MÁS. No se mantiene, y en enero de 2026 estaba mal en
            // las dos direcciones: dos mareas en Open que habían arribado hacía meses, y las tres que
            // realmente estaban navegando el 31 —90 tripulantes— marcadas como Completed. El filtro
            // por Status devolvía exactamente el conjunto equivocado.
            //
            // Lo que queda es la fecha, que sí es un dato: el proyecto arrancó antes de que el
            // período terminara. Quién entra de verdad lo termina de decidir AplicarFiltroPersonal,
            // que pide una asignación vigente — por eso los proyectos viejos sin nadie asignado no
            // generan nada aunque pasen este filtro.
            //
            // La fecha de inicio EN BLANCO pasa a propósito: los proyectos de nómina no tienen, y son
            // los que la Regular necesita recorrer para encontrar a su gente.
            Job.SetFilter("Starting Date", '<=%1', Periodo."Fecha Hasta");
            // Y si el tipo lo pide, sólo los que al cierre todavía no arribaron.
            if SoloEnCurso then
                Job.SetFilter("Ending Date", '%1|>%2', 0D, Periodo."Fecha Hasta");
        end;
    end;

    /// <remarks>
    /// El criterio es "estuvo asignado durante lo que se liquida", no "sigue asignado hoy".
    ///
    /// Antes, para los tipos que no son de arribo, se pedía la asignación ABIERTA (Fecha Baja en
    /// blanco). Eso alcanzaba mientras nada cerrara las asignaciones solo, pero desde que cargar la
    /// fecha de arribo cierra las del proyecto, una marea terminada se quedaba sin nadie: "Crear
    /// Devengados" devolvía 0 sin explicar por qué, y los Devengados son justamente lo que se liquida
    /// DESPUÉS de que la marea cerró.
    ///
    /// Ahora entra la asignación que estuvo vigente en algún momento del período: dada de baja en el
    /// período o después, y dada de alta antes de que el período terminara.
    /// </remarks>
    local procedure AplicarFiltroPersonal(var Personal: Record "Personal Proyecto"; var Job: Record Job; TipoLiq: Code[20]; CodPeriodo: Code[10])
    var
        TipoLiqRec: Record "Tipo Liquidación";
        Periodo: Record "Período Liquidación";
    begin
        Personal.Reset();
        Personal.SetRange("No. Proyecto", Job."No.");
        if TipoLiqRec.EsArribo(TipoLiq) then begin
            // Discharge before voyage start → excluded; still active or discharged on/after start → included.
            Personal.SetFilter("Fecha Baja", '%1|>=%2', 0D, Job."Starting Date");
            exit;
        end;

        if not Periodo.Get(CodPeriodo) then begin
            Personal.SetRange("Fecha Baja", 0D);
            exit;
        end;
        Personal.SetFilter("Fecha Baja", '%1|>=%2', 0D, Periodo."Fecha Desde");
        if Periodo."Fecha Hasta" <> 0D then
            Personal.SetFilter("Fecha Alta Asignación", '<=%1', Periodo."Fecha Hasta");
    end;

    local procedure LiqExiste(EmpNo: Code[20]; JobNo: Code[20]; CodPeriodo: Code[10]; TipoLiq: Code[20]): Boolean
    var
        Liq: Record "Liquidación";
    begin
        Liq.SetRange("No. Empleado", EmpNo);
        Liq.SetRange("No. Proyecto", JobNo);
        Liq.SetRange("Cód. Período", CodPeriodo);
        Liq.SetRange("Cód. Tipo Liq.", TipoLiq);
        exit(not Liq.IsEmpty());
    end;

    // Any liquidation of this type for the employee+period, regardless of project (avoids a duplicate
    // project-less liquidation when a project-based one already covers the employee this period).
    local procedure LiqExisteEmpleado(EmpNo: Code[20]; CodPeriodo: Code[10]; TipoLiq: Code[20]): Boolean
    var
        Liq: Record "Liquidación";
    begin
        Liq.SetRange("No. Empleado", EmpNo);
        Liq.SetRange("Cód. Período", CodPeriodo);
        Liq.SetRange("Cód. Tipo Liq.", TipoLiq);
        exit(not Liq.IsEmpty());
    end;

    // Creates a project-less liquidation for an employee. El par sale de los ATRIBUTOS; la ficha del
    // empleado queda como respaldo para cuando todavía no los tenga cargados — un convenio en blanco
    // descartaría todos los conceptos restringidos por CCT.
    //
    // Antes el respaldo era la última asignación a proyecto, que también llevaba convenio y categoría.
    // Esos campos dejaron de existir: el par vive en los atributos y el puesto en el suyo.
    local procedure InsertarLiquidacionEmpleado(EmpNo: Code[20]; CodPeriodo: Code[10]; TipoLiq: Code[20]): Code[20]
    var
        Liq: Record "Liquidación";
        Emp: Record Employee;
        Periodo: Record "Período Liquidación";
        Convenio: Code[20];
        Categoria: Code[20];
    begin
        Periodo.Get(CodPeriodo);

        Liq.Init();
        Liq."No." := NextLiqNo();
        Liq."No. Empleado" := EmpNo;
        if Emp.Get(EmpNo) then begin
            Liq."Nombre Empleado" := CopyStr(Emp."First Name" + ' ' + Emp."Last Name", 1, MaxStrLen(Liq."Nombre Empleado"));
            if Convenio = '' then Convenio := Emp."Cód. Convenio";
            if Categoria = '' then Categoria := Emp."Cód. Categoría";
        end;
        Liq."Cód. Convenio" := Convenio;
        Liq."Cód. Categoría" := Categoria;
        Liq."Cód. Período" := CodPeriodo;
        if Periodo."Fecha Hasta" <> 0D then
            Liq."Fecha Liquidación" := Periodo."Fecha Hasta"
        else
            Liq."Fecha Liquidación" := WorkDate();
        Liq."Cód. Tipo Liq." := TipoLiq;
        Liq.Estado := Liq.Estado::Borrador;
        // El par de la cabecera es el de los ATRIBUTOS del empleado. Lo de arriba queda como
        // respaldo para cuando todavía no tenga atributos cargados.
        Liq.ResolverParDeAtributos();
        Liq.Insert(true);
        exit(Liq."No.");
    end;

    local procedure InsertarLiquidacion(Personal: Record "Personal Proyecto"; CodPeriodo: Code[10]; TipoLiq: Code[20]): Code[20]
    var
        Liq: Record "Liquidación";
        Emp: Record Employee;
        Periodo: Record "Período Liquidación";
        Job: Record Job;
        TipoLiqRec: Record "Tipo Liquidación";
    begin
        Liq.Init();
        Liq."No." := NextLiqNo();
        Liq."No. Empleado" := Personal."No. Empleado";
        if Emp.Get(Personal."No. Empleado") then
            Liq."Nombre Empleado" := CopyStr(Emp."First Name" + ' ' + Emp."Last Name", 1, MaxStrLen(Liq."Nombre Empleado"));
        Liq."No. Proyecto" := Personal."No. Proyecto";
        Liq."Cód. Período" := CodPeriodo;
        // A Cierre Marea settles at the voyage arrival date; other types at period end.
        if TipoLiqRec.EsArribo(TipoLiq) and Job.Get(Personal."No. Proyecto") and (Job."Ending Date" <> 0D) then
            Liq."Fecha Liquidación" := Job."Ending Date"
        else
            if Periodo.Get(CodPeriodo) then
                Liq."Fecha Liquidación" := Periodo."Fecha Hasta"
            else
                Liq."Fecha Liquidación" := WorkDate();
        Liq."Cód. Tipo Liq." := TipoLiq;
        Liq.Estado := Liq.Estado::Borrador;
        // El par de la cabecera es el de los ATRIBUTOS del empleado. Lo de arriba queda como
        // respaldo para cuando todavía no tenga atributos cargados.
        Liq.ResolverParDeAtributos();
        Liq.Insert(true);
        exit(Liq."No.");
    end;

    procedure NextLiqNo(): Code[20]
    var
        HRSetup: Record "Human Resources Setup";
        NoSeries: Codeunit "No. Series";
    begin
        HRSetup.Get();
        if HRSetup."Cód. Serie Liq." = '' then
            Error(ErrSerieNoConfigurada);
        exit(NoSeries.GetNextNo(HRSetup."Cód. Serie Liq.", WorkDate(), true));
    end;

    var
        OmitidosSinFase: Integer;
        ErrPeriodoCerrado: Label 'El período %1 está cerrado.';
        ErrSerieNoConfigurada: Label 'La serie de numeración de liquidaciones no está configurada. Vaya a Configuración de RR.HH. y complete el campo "Serie Núm. Liquidaciones".';
        MsgNinguno: Label 'No se encontraron proyectos con personal activo para el período y tipo indicados.';
        ErrSinArribo: Label 'El proyecto %1 no tiene fecha de arribo (Ending Date). Cargue la fecha de llegada a puerto antes de crear el Cierre de Marea.';
        ErrSinPeriodo: Label 'No existe un período de liquidación que contenga la fecha de arribo %1. Cree el período de ese mes primero.';
        MsgOmitidosSinFase: Label '%1 empleados quedaron afuera porque ninguna de sus fases de alta cubre el período: según las fases, ese mes no pertenecían a la empresa.\\Suele ser una asignación a proyecto que quedó abierta, o una que abarca dos temporadas y cruza el hueco entre ellas. Si alguno de estos empleados sí trabajó, lo que falta es la fase de alta, no la liquidación.', Comment = '%1 = cantidad de empleados omitidos';
        ErrSinFaseEnPeriodo: Label 'El empleado %1 no tiene ninguna fase de alta que cubra el período %2: según las fases de alta, ese mes no pertenecía a la empresa.\\Si trabajó, cargue la fase de alta antes de liquidarle.', Comment = '%1 = legajo; %2 = código de período';
}
