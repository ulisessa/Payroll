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
        TipoLiqRec: Record "Tipo Liquidación";
        Creadas: Integer;
    begin
        LimpiarCachesEstados();
        Periodo.Get(CodPeriodo);
        if Periodo.Estado = Periodo.Estado::Cerrado then
            Error(ErrPeriodoCerrado, CodPeriodo);
        Periodo.ErrorSiCreado();

        // El calendario del tipo corta antes que nada: el aguinaldo no tiene por qué mirar a nadie
        // en marzo. Va acá y no en el filtro de proyectos porque depende del período, no del Job.
        if not TipoLiqRec.CorreEnElMes(TipoLiq, Periodo."Fecha Hasta") then
            exit(0);

        AplicarFiltroPersonal(Personal, Job, TipoLiq, CodPeriodo);
        if not Personal.FindSet() then
            exit(0);

        repeat
            // Queda anotado ANTES de las guardas: haya salido liquidación o no, este empleado ya
            // fue considerado para este tipo y el recorrido por estados no tiene que repetirlo.
            if not FIntentados.ContainsKey(Personal."No. Empleado") then
                FIntentados.Add(Personal."No. Empleado", true);

            // Cuatro preguntas, de la más barata a la más cara: ¿el tipo le corresponde a esta clase
            // de empleado?, ¿pertenecía a la empresa?, ¿se dio de baja, si el tipo lo exige?, ¿sus
            // estados lo justifican? La asignación a proyecto ya quedó contestada por los filtros de
            // arriba.
            case true of
                not TipoAplicaAlEmpleado(TipoLiq, Personal."No. Empleado", Periodo):
                    OmitidosPorTipoEmpleado += 1;
                not EstuvoEnLaEmpresa(Personal."No. Empleado", Periodo):
                    OmitidosSinFase += 1;
                TipoLiqRec.EsBajaEmpleado(TipoLiq) and not SeDioDeBajaEnElPeriodo(Personal."No. Empleado", Periodo):
                    OmitidosSinBaja += 1;
                not EstadosJustifican(Personal."No. Empleado", CodPeriodo, TipoLiq, Job."No."):
                    OmitidosSinEstado += 1;
                else
                    if CrearSiFalta(Personal, CodPeriodo, TipoLiq) <> '' then
                        Creadas += 1;
            end;
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
    local procedure CrearSiFalta(Personal: Record "Personal Proyecto"; CodPeriodo: Code[10]; TipoLiq: Code[20]) NoLiq: Code[20]
    var
        TipoLiqRec: Record "Tipo Liquidación";
    begin
        if TipoLiqRec.Get(TipoLiq) and TipoLiqRec."Agrupa por Empleado" then begin
            if LiqExisteEmpleado(Personal."No. Empleado", CodPeriodo, TipoLiq) then
                exit('');
            NoLiq := InsertarLiquidacionEmpleado(Personal."No. Empleado", CodPeriodo, TipoLiq);
        end else begin
            if LiqExiste(Personal."No. Empleado", Personal."No. Proyecto", CodPeriodo, TipoLiq) then
                exit('');
            NoLiq := InsertarLiquidacion(Personal, CodPeriodo, TipoLiq);
        end;

        if FCalcYDesc and (NoLiq <> '') then
            if not CalcularYDescartarSiVacia(NoLiq) then
                exit('');
    end;

    /// <summary>
    /// Calcula la liquidación recién creada. Si salió vacía la borra y devuelve false.
    /// </summary>
    /// <remarks>
    /// VACÍA = NINGUNA LÍNEA CON IMPORTE. No alcanza con "sin líneas": el motor deja igual las
    /// informativas y las de cantidad —días, coeficientes— que no son plata. Lo que decide si la
    /// liquidación sirve de algo es si alguien cobra o le descuentan.
    ///
    /// Hay que REABRIRLA para poder borrarla: el OnDelete de Liquidación se niega si no está en
    /// Borrador, y después de calcular está Calculada. Reabrir es la forma explícita que ya usa el
    /// resto del sistema, así que se pasa por ahí en vez de saltear el trigger con un Delete(false)
    /// que dejaría las líneas huérfanas.
    /// </remarks>
    local procedure CalcularYDescartarSiVacia(NoLiq: Code[20]): Boolean
    var
        Liq: Record "Liquidación";
        LinLiq: Record "Línea Liquidación";
        Motor: Codeunit "Motor Liquidación";
        Gestion: Codeunit "Gestión Liquidación";
    begin
        if not Liq.Get(NoLiq) then
            exit(false);

        FProgreso.Registro(Liq."No.", Liq."No. Empleado" + '  ' + Liq."Nombre Empleado");
        // Sin relanzar: una que falla queda anotada en su registro y el lote sigue. Una que falló no
        // se descarta —no se sabe si está vacía porque no corresponde o porque se rompió—.
        if not Motor.LiquidarConRegistro(Liq) then begin
            // Y queda anotada para que la barrida no se la lleve. Una que falló no tiene líneas, así
            // que EstaVacia dice que sí y BarrerVacias la borraba: el cálculo fallido desaparecía y
            // el único rastro quedaba en el registro de procesos. Así se perdieron de vista 14
            // cierres de marea de enero de 2026 durante toda una revisión.
            if not FFallidas.Contains(NoLiq) then
                FFallidas.Add(NoLiq);
            FProgreso.FinalizarRegistro();
            ConsumirLiqNo();
            exit(true);
        end;

        LinLiq.SetRange("No. Liquidación", NoLiq);
        LinLiq.SetFilter(Importe, '<>%1', 0);
        if not LinLiq.IsEmpty() then begin
            FProgreso.FinalizarRegistro();
            ConsumirLiqNo();
            exit(true);
        end;

        Liq.Get(NoLiq);
        Gestion.Reabrir(Liq);
        Liq.Get(NoLiq);
        Liq.Delete(true);
        FDescartadas += 1;
        FProgreso.FinalizarRegistro();
        exit(false);
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
    /// contador en cero. Que se acumule dentro de una misma corrida es justo lo que se quiere: una
    /// corrida sin tipo recorre varios tipos, y cada tipo recorre primero proyectos y después
    /// estados. El aviso tiene que sumar todo eso.
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
        if OmitidosSinFase > 0 then
            Message(MsgOmitidosSinFase, OmitidosSinFase);
        if OmitidosPorTipoEmpleado > 0 then
            Message(MsgOmitidosPorTipoEmpleado, OmitidosPorTipoEmpleado);
        if OmitidosSinEstado > 0 then
            Message(MsgOmitidosSinEstado, OmitidosSinEstado);
        if OmitidosSinBaja > 0 then
            Message(MsgOmitidosSinBaja, OmitidosSinBaja);
    end;

    /// <summary>Los mismos omitidos que AvisarOmitidos, pero al registro en vez de a un cartel.</summary>
    /// <remarks>
    /// SON DOS PROCEDIMIENTOS Y NO UNO porque se llaman desde lugares distintos: AvisarOmitidos la
    /// invocan las páginas DESPUÉS de que el proceso cerró su sesión del registro, así que desde ahí
    /// ya no hay dónde escribir. Este corre adentro, con la sesión abierta.
    ///
    /// Mientras los dos caminos convivan, el de crear-y-calcular usa éste y las páginas de ese flujo
    /// no llaman al otro: si llamaran a los dos, el mismo omitido saldría en el informe y además en
    /// un cartel.
    /// </remarks>
    local procedure RegistrarOmitidos(var Registro: Codeunit "Registro Procesos Liq.")
    begin
        if OmitidosSinFase > 0 then
            Registro.AgregarTexto(
                "Severidad Registro Liq."::Advertencia, "Categoría Registro Liq."::"Estado Empleado",
                StrSubstNo(MsgOmitidosSinFase, OmitidosSinFase));
        if OmitidosPorTipoEmpleado > 0 then
            Registro.AgregarTexto(
                "Severidad Registro Liq."::Advertencia, "Categoría Registro Liq."::"Estado Empleado",
                StrSubstNo(MsgOmitidosPorTipoEmpleado, OmitidosPorTipoEmpleado));
        if OmitidosSinEstado > 0 then
            Registro.AgregarTexto(
                "Severidad Registro Liq."::Advertencia, "Categoría Registro Liq."::"Estado Empleado",
                StrSubstNo(MsgOmitidosSinEstado, OmitidosSinEstado));
        if OmitidosSinBaja > 0 then
            Registro.AgregarTexto(
                "Severidad Registro Liq."::Advertencia, "Categoría Registro Liq."::"Estado Empleado",
                StrSubstNo(MsgOmitidosSinBaja, OmitidosSinBaja));
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
    /// <summary>
    /// Crea las liquidaciones de UN empleado, con las mismas guardas que el recorrido por proyecto.
    /// </summary>
    /// <remarks>
    /// El gemelo de CrearPorProyecto para quien entra por el empleado y no por el barco. Existe
    /// porque el reporte 50043 armaba la cabecera a mano y se salteaba todo lo que hay acá:
    ///
    ///   • "Agrupa por Empleado". Recorría las asignaciones creando una liquidación por cada una,
    ///     así que a un embarcado con cinco proyectos le hacía cinco mensuales en vez de una.
    ///   • El proyecto. Escribía Personal."No. Proyecto" en vez de pasar por ProyectoNominaDe, que
    ///     es quien lo resuelve desde el estado del empleado.
    ///   • La fecha de la asignación. Sólo exigía "Fecha Baja" = 0, no que la asignación hubiera
    ///     EMPEZADO: a 04916 le tomó una asignación que arranca el 13/5/2026 para liquidar enero, y
    ///     con ella el buque equivocado y la pesquería equivocada.
    ///   • Las cuatro guardas: tipo de empleado, fase de alta, baja en el período y estados que lo
    ///     justifiquen.
    ///
    /// Las omisiones se cuentan en los mismos contadores que el recorrido por proyecto y no cortan:
    /// esto se corre sobre un filtro de empleados, y abortar todo porque a uno le falta la fase
    /// obligaría a ir sacándolos del filtro de a uno.
    /// </remarks>
    procedure CrearParaEmpleado(EmpNo: Code[20]; CodPeriodo: Code[10]; TipoLiq: Code[20]) Creadas: Integer
    var
        Personal: Record "Personal Proyecto";
        Job: Record Job;
        Periodo: Record "Período Liquidación";
        TipoLiqRec: Record "Tipo Liquidación";
    begin
        LimpiarCachesEstados();
        Periodo.Get(CodPeriodo);
        if Periodo.Estado = Periodo.Estado::Cerrado then
            Error(ErrPeriodoCerrado, CodPeriodo);
        Periodo.ErrorSiCreado();
        if not TipoLiqRec.CorreEnElMes(TipoLiq, Periodo."Fecha Hasta") then
            exit(0);

        // Los mismos filtros que AplicarFiltroPersonal, pero por empleado en vez de por proyecto:
        // asignación no dada de baja antes del período, y ya empezada al cierre.
        Personal.SetRange("No. Empleado", EmpNo);
        Personal.SetFilter("Fecha Baja", '%1|>=%2', 0D, Periodo."Fecha Desde");
        if Periodo."Fecha Hasta" <> 0D then
            Personal.SetFilter("Fecha Alta Asignación", '<=%1', Periodo."Fecha Hasta");
        if not Personal.FindSet() then
            exit(0);

        if not FIntentados.ContainsKey(EmpNo) then
            FIntentados.Add(EmpNo, true);

        repeat
            if Job.Get(Personal."No. Proyecto") then
                case true of
                    not TipoAplicaAlEmpleado(TipoLiq, EmpNo, Periodo):
                        OmitidosPorTipoEmpleado += 1;
                    not EstuvoEnLaEmpresa(EmpNo, Periodo):
                        OmitidosSinFase += 1;
                    TipoLiqRec.EsBajaEmpleado(TipoLiq) and not SeDioDeBajaEnElPeriodo(EmpNo, Periodo):
                        OmitidosSinBaja += 1;
                    not EstadosJustifican(EmpNo, CodPeriodo, TipoLiq, Job."No."):
                        OmitidosSinEstado += 1;
                    else
                        // CrearSiFalta es quien respeta "Agrupa por Empleado": para un tipo agrupado
                        // la primera asignación crea la única liquidación y las demás se encuentran
                        // con que ya existe.
                        if CrearSiFalta(Personal, CodPeriodo, TipoLiq) <> '' then
                            Creadas += 1;
                end;
        until Personal.Next() = 0;
    end;

    procedure CrearParaAsignacion(Personal: Record "Personal Proyecto"; CodPeriodo: Code[10]; TipoLiq: Code[20]): Code[20]
    var
        Periodo: Record "Período Liquidación";
    begin
        Periodo.Get(CodPeriodo);
        if Periodo.Estado = Periodo.Estado::Cerrado then
            Error(ErrPeriodoCerrado, CodPeriodo);
        Periodo.ErrorSiCreado();
        // Acá corta con error y no salteando en silencio como el lote: esto es un alta de a uno,
        // pedida a propósito sobre un empleado concreto. Si no se puede, hay que decir por qué.
        if not EstuvoEnLaEmpresa(Personal."No. Empleado", Periodo) then
            Error(ErrSinFaseEnPeriodo, Personal."No. Empleado", CodPeriodo);
        // LA ASIGNACIÓN TIENE QUE HABER EMPEZADO. El recorrido del lote filtra esto en
        // AplicarFiltroPersonal —"Fecha Alta Asignación" <= fin del período— pero el alta de a una
        // entraba por acá y se lo saltaba, así que se podía fundar una liquidación de enero sobre una
        // asignación que arranca en mayo. Y el proyecto no es decorativo: de ahí sale el buque, y del
        // buque la pesquería y todos sus atributos. A 04360 su liquidación de enero de 2026 le quedó
        // sobre PN-802-NOMINA, un potero cuya asignación empieza el 13/5/2026, y la antigüedad se
        // calculó con el coeficiente del potero cuando el hombre estaba en francos de un tangonero.
        if (Periodo."Fecha Hasta" <> 0D) and (Personal."Fecha Alta Asignación" > Periodo."Fecha Hasta") then
            Error(ErrAsignacionPosterior, Personal."No. Proyecto", Personal."No. Empleado",
                  Personal."Fecha Alta Asignación", CodPeriodo, Periodo."Fecha Hasta");
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

    /// <summary>
    /// Crea las liquidaciones del período. Sin tipo, corre TODOS los activos en su Orden.
    /// </summary>
    /// <remarks>
    /// EL TIPO EN BLANCO NO ES UN TIPO. Antes se pasaba tal cual hasta el Insert y salían cientos de
    /// liquidaciones con "Cód. Tipo Liq." vacío, todas fechadas el último día del período. Y no
    /// fallaban: el motor no aplica ningún concepto restringido por tipo y entrega un recibo vacío
    /// sin decir por qué. Peor todavía, el filtro de proyectos sale del tipo —clase de proyecto, sólo
    /// en curso—, así que sin tipo se barren TODOS los proyectos y se mezclan mareas cerradas con
    /// abiertas.
    ///
    /// Dejarlo en blanco significa "todos", que es lo que quiere quien no elige ninguno, y el Orden
    /// del tipo existe justamente para eso: el cierre de marea tiene que correr antes que la mensual
    /// que lo acumula.
    /// </remarks>
    procedure CrearPorPeriodo(CodPeriodo: Code[10]; TipoLiq: Code[20]): Integer
    var
        Periodo: Record "Período Liquidación";
        TipoLiqRec: Record "Tipo Liquidación";
        Creadas: Integer;
        HuboProyectos: Boolean;
    begin
        LimpiarCachesEstados();
        Periodo.Get(CodPeriodo);
        if Periodo.Estado = Periodo.Estado::Cerrado then
            Error(ErrPeriodoCerrado, CodPeriodo);
        Periodo.ErrorSiCreado();

        if TipoLiq = '' then begin
            TipoLiqRec.SetCurrentKey(Orden);
            TipoLiqRec.SetRange(Activo, true);
            // Y ADEMÁS que el tipo haya dicho que entra. "Activo" no alcanza: ver el campo en la tabla.
            TipoLiqRec.SetRange("Entra en Corrida Completa", true);
            if TipoLiqRec.FindSet() then
                repeat
                    Creadas += CrearDeUnTipo(CodPeriodo, Periodo, TipoLiqRec.Código, HuboProyectos);
                until TipoLiqRec.Next() = 0;
        end else
            Creadas += CrearDeUnTipo(CodPeriodo, Periodo, TipoLiq, HuboProyectos);

        // El aviso es "ningún tipo encontró proyectos", no "este tipo no encontró": con varios tipos,
        // uno solo que traiga trabajo ya hace que el proceso haya hecho algo.
        if not HuboProyectos then
            Message(MsgNinguno);

        exit(Creadas);
    end;

    local procedure CrearDeUnTipo(CodPeriodo: Code[10]; Periodo: Record "Período Liquidación"; TipoLiq: Code[20]; var HuboProyectos: Boolean): Integer
    var
        Job: Record Job;
        TipoLiqRec: Record "Tipo Liquidación";
        Creadas: Integer;
    begin
        Clear(FIntentados);

        AplicarFiltroJobs(Job, TipoLiq, Periodo);
        if Job.FindSet() then begin
            HuboProyectos := true;
            repeat
                Creadas += CrearPorProyecto(Job, CodPeriodo, TipoLiq);
            until Job.Next() = 0;
        end;

        // Y después los que no cuelgan de ningún proyecto. Sólo para los tipos agrupados por
        // empleado: en los demás la liquidación ES de un proyecto y sin proyecto no hay qué crear.
        if TipoLiqRec.Get(TipoLiq) then
            if TipoLiqRec."Agrupa por Empleado" then
                Creadas += CrearSinProyecto(CodPeriodo, Periodo, TipoLiq, HuboProyectos);

        exit(Creadas);
    end;

    /// <summary>
    /// Los empleados que el recorrido por proyectos no alcanza: tienen estados en el período pero
    /// ninguna asignación a proyecto que los traiga.
    /// </summary>
    /// <remarks>
    /// POR QUÉ HACE FALTA. El recorrido entra por Job y de ahí baja a "Personal Proyecto", así que un
    /// empleado sin asignación es invisible por más estados que tenga. En enero de 2026 eran nueve
    /// empleados de tierra a los que Meta4 les pagó y BC no les creaba nada: uno arranca el año de
    /// vacaciones —no se le puede asignar un proyecto a alguien que no está trabajando— y el resto
    /// nunca tuvo proyecto porque su trabajo no cuelga de una marea.
    ///
    /// SÓLO PARA LOS TIPOS AGRUPADOS POR EMPLEADO, que son los que producen una liquidación por
    /// empleado y período sin proyecto. Para el cierre de marea, en cambio, la liquidación es DE la
    /// marea: un empleado sin proyecto no tiene cierre que liquidar, y crearle uno vacío sería peor
    /// que no crear nada.
    ///
    /// LAS MISMAS GUARDAS, EN EL MISMO ORDEN que el recorrido por proyectos. La única diferencia es
    /// que el proyecto va en blanco, y por eso "Tipo Proyecto" en las líneas de estado trata a estos
    /// días como improductivos: es lo que corresponde, no cuelgan de ninguna marea.
    ///
    /// NO DUPLICA NI REPITE TRABAJO. FIntentados lleva a quién ya evaluó el recorrido por proyectos
    /// para este tipo, y se consulta acá. Sin eso, en modo crear-y-calcular una liquidación que el
    /// primer camino creó, calculó y descartó por vacía volvería a crearse, a calcularse y a
    /// descartarse — contándose dos veces.
    /// </remarks>
    local procedure CrearSinProyecto(CodPeriodo: Code[10]; Periodo: Record "Período Liquidación"; TipoLiq: Code[20]; var HuboProyectos: Boolean): Integer
    var
        Estado: Record "Estado Empleado";
        TipoLiqRec: Record "Tipo Liquidación";
        Vistos: Dictionary of [Code[20], Boolean];
        EmpNo: Code[20];
        Creadas: Integer;
    begin
        // El calendario del tipo corta antes que nada, igual que en el recorrido por proyectos.
        if not TipoLiqRec.CorreEnElMes(TipoLiq, Periodo."Fecha Hasta") then
            exit(0);

        Estado.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
        Estado.SetFilter("Fecha Inicio", '<=%1', Periodo."Fecha Hasta");
        // Fecha Fin en blanco = estado abierto, que sigue vigente y por lo tanto toca el período.
        Estado.SetFilter("Fecha Fin", '%1|>=%2', 0D, Periodo."Fecha Desde");
        if not Estado.FindSet() then
            exit(0);

        repeat
            EmpNo := Estado."No. Empleado";
            // Un empleado tiene muchos estados en un mes y acá sólo interesa una vez.
            if not Vistos.ContainsKey(EmpNo) then begin
                Vistos.Add(EmpNo, true);
                if not FIntentados.ContainsKey(EmpNo) then
                    if EvaluarYCrearEmpleado(EmpNo, CodPeriodo, Periodo, TipoLiq) then begin
                        HuboProyectos := true;
                        Creadas += 1;
                    end;
            end;
        until Estado.Next() = 0;

        exit(Creadas);
    end;

    /// <summary>
    /// ¿A esta clase de empleado le corresponde este tipo de documento?
    /// </summary>
    /// <remarks>
    /// Mismo eje que el "Aplica A" del concepto, pero decidiendo el DOCUMENTO entero en vez de una
    /// línea. Nació por las vacaciones de tierra: al mensualizado se le emitía el recibo de
    /// Vacaciones con el haber completo Y el Regular con el sueldo completo, y el descuento de días
    /// —4743— no lo corrige porque su condición se apaga justo cuando existe el documento de
    /// Vacaciones. Meta4 no emite ese segundo documento para tierra.
    ///
    /// "Todos" de cualquiera de los dos lados no restringe, igual que en los conceptos. El tipo de
    /// empleado sale del convenio vigente; sin convenio no se filtra, que es el criterio permisivo
    /// de siempre: un documento de más se ve, uno de menos no lo nota nadie.
    /// </remarks>
    local procedure TipoAplicaAlEmpleado(TipoLiq: Code[20]; EmpNo: Code[20]; Periodo: Record "Período Liquidación"): Boolean
    var
        TipoLiqRec: Record "Tipo Liquidación";
        Convenio: Record "Convenio Colectivo";
        ParCCT: Codeunit "Convenio Categoría Liq.";
        Todos: Enum "Aplica A Liq.";
        CodConvenio: Code[20];
        CodCategoria: Code[20];
    begin
        if not TipoLiqRec.Get(TipoLiq) then
            exit(true);
        if TipoLiqRec."Aplica A" = Todos::Todos then
            exit(true);

        // El mismo resolvedor que usa el motor para el encuadre de la liquidación, para que el
        // documento se cree con el criterio con el que después se va a calcular.
        if not ParCCT.ParDeEntidad(EmpNo, Periodo."Fecha Hasta", Periodo."Fecha Desde", Periodo."Fecha Hasta",
                                   CodConvenio, CodCategoria)
        then
            exit(true);
        if CodConvenio = '' then
            exit(true);
        if not Convenio.Get(CodConvenio) then
            exit(true);
        if Convenio."Tipo Empleado" = Todos::Todos then
            exit(true);

        exit(Convenio."Tipo Empleado" = TipoLiqRec."Aplica A");
    end;

    /// <summary>
    /// Las tres guardas y la creación, para un empleado sin proyecto. Devuelve si creó.
    /// </summary>
    local procedure EvaluarYCrearEmpleado(EmpNo: Code[20]; CodPeriodo: Code[10]; Periodo: Record "Período Liquidación"; TipoLiq: Code[20]): Boolean
    var
        TipoLiqRec: Record "Tipo Liquidación";
    begin
        if not FIntentados.ContainsKey(EmpNo) then
            FIntentados.Add(EmpNo, true);

        if not TipoAplicaAlEmpleado(TipoLiq, EmpNo, Periodo) then begin
            OmitidosPorTipoEmpleado += 1;
            exit(false);
        end;

        if not EstuvoEnLaEmpresa(EmpNo, Periodo) then begin
            OmitidosSinFase += 1;
            exit(false);
        end;

        if TipoLiqRec.EsBajaEmpleado(TipoLiq) and not SeDioDeBajaEnElPeriodo(EmpNo, Periodo) then begin
            OmitidosSinBaja += 1;
            exit(false);
        end;

        // Proyecto en blanco: la ventana sale del período y del tipo, no de una marea.
        if not EstadosJustifican(EmpNo, CodPeriodo, TipoLiq, '') then begin
            OmitidosSinEstado += 1;
            exit(false);
        end;

        exit(CrearSiFaltaEmpleado(EmpNo, CodPeriodo, TipoLiq) <> '');
    end;

    /// <summary>
    /// Crea la liquidación por empleado si no existe, y en modo crear-y-calcular la descarta si sale
    /// vacía. El gemelo de CrearSiFalta para el camino que no tiene "Personal Proyecto".
    /// </summary>
    local procedure CrearSiFaltaEmpleado(EmpNo: Code[20]; CodPeriodo: Code[10]; TipoLiq: Code[20]) NoLiq: Code[20]
    begin
        if LiqExisteEmpleado(EmpNo, CodPeriodo, TipoLiq) then
            exit('');

        NoLiq := InsertarLiquidacionEmpleado(EmpNo, CodPeriodo, TipoLiq);

        if FCalcYDesc and (NoLiq <> '') then
            if not CalcularYDescartarSiVacia(NoLiq) then
                exit('');
    end;

    /// <summary>
    /// Crea y calcula en una sola pasada, y descarta las que salgan vacías sin quemarles el número.
    /// </summary>
    /// <remarks>
    /// POR QUÉ JUNTAS Y NO UNA DESPUÉS DE LA OTRA. Si no hay estados ni conceptos con valor, la
    /// liquidación no debería existir — pero eso recién se sabe DESPUÉS de calcular. Creando todo
    /// primero quedan cientos de liquidaciones vacías de SALDO_INICIAL, LIQ_FINAL y AGUINALDO, que
    /// hay que salir a borrar a mano y que además ya se llevaron su número.
    ///
    /// Yendo de a una —crear, calcular, decidir— la vacía se borra en el acto y su número lo toma la
    /// siguiente, porque el número se ESPÍA al crear y sólo se consume si sobrevive (ver NextLiqNo).
    ///
    /// Devuelve las que quedaron; las descartadas se preguntan con Descartadas().
    /// </remarks>
    procedure CrearYCalcularPorPeriodo(CodPeriodo: Code[10]; TipoLiq: Code[20]) Creadas: Integer
    begin
        FCalcYDesc := true;
        FDescartadas := 0;
        FSobrantes := 0;
        // Arranca vacía en cada corrida: lo que falló la vez pasada tiene que poder barrerse si esta
        // vez calcula bien y sale vacío de verdad.
        Clear(FFallidas);
        // El total no se sabe de antemano: se está creando sobre la marcha. La ventana igual sirve
        // para mostrar en cuál va y cuánto lleva, que es lo que uno mira en un lote largo.
        FProgreso.AbrirLote(0);
        Registro.IniciarSesion();
        Creadas := CrearPorPeriodo(CodPeriodo, TipoLiq);
        // La barrida va DESPUÉS de crear y calcular: recién ahí se sabe cuáles quedaron vacías,
        // incluidas las que venían de una corrida anterior con otra configuración.
        BarrerVacias(CodPeriodo, TipoLiq);
        // La ventana de progreso se cierra ANTES del informe: con la ventana abierta el informe
        // queda detrás y parece que el proceso se colgó.
        FProgreso.Cerrar();
        Registro.MostrarAvisosDeLaSesion();
        Registro.CerrarSesion();
        FCalcYDesc := false;
    end;

    /// <summary>Cuántas se descartaron por vacías en la última corrida de CrearYCalcularPorPeriodo.</summary>
    procedure Descartadas(): Integer
    begin
        exit(FDescartadas);
    end;

    /// <summary>Cuántas quedaron con importe aunque la configuración de hoy ya no las sostendría.</summary>
    procedure Sobrantes(): Integer
    begin
        exit(FSobrantes);
    end;

    /// <summary>
    /// Saca del período lo que el proceso ya no sostendría, para que la corrida CONVERJA.
    /// </summary>
    /// <remarks>
    /// SIN ESTO EL PROCESO SÓLO AGREGA. Crear ya era idempotente —LiqExiste corta antes de insertar,
    /// así que una segunda corrida no duplica ni pide número nuevo— y calcular también, porque sólo
    /// toma Borrador. Lo que faltaba es que una corrida DESPUÉS de cambiar la configuración deje el
    /// período como si se hubiera corrido por primera vez con esa configuración. Mientras el proceso
    /// nunca saque nada, el resultado depende de la historia de corridas y no de los datos.
    ///
    /// BORRA SÓLO LAS VACÍAS. Una liquidación sin ninguna línea con importe no aporta nada y su
    /// desaparición no pierde información. Las que TIENEN importe pero que las guardas de hoy ya no
    /// crearían se cuentan y se informan, y no se tocan: pueden haberse creado a mano a propósito, y
    /// borrar plata en silencio porque cambió un parámetro es exactamente lo que no hay que hacer.
    ///
    /// EL ALCANCE ES EL DE LA CORRIDA. Con un tipo elegido barre ese tipo; sin tipo, los que entran
    /// en la corrida completa. Nunca toca un tipo que esta corrida no miró.
    /// </remarks>
    local procedure BarrerVacias(CodPeriodo: Code[10]; TipoLiq: Code[20])
    var
        Liq: Record "Liquidación";
        TipoLiqRec: Record "Tipo Liquidación";
        Numeros: List of [Code[20]];
        Numero: Code[20];
    begin
        Liq.SetRange("Cód. Período", CodPeriodo);
        Liq.SetFilter(Estado, '%1|%2', Liq.Estado::Borrador, Liq.Estado::Calculada);
        if TipoLiq <> '' then
            Liq.SetRange("Cód. Tipo Liq.", TipoLiq)
        else begin
            TipoLiqRec.SetRange("Entra en Corrida Completa", true);
            if TipoLiqRec.IsEmpty() then
                exit;
            Liq.SetFilter("Cód. Tipo Liq.", ConstruirFiltroTipos(TipoLiqRec));
        end;

        // Las claves primero: el bucle borra, y borrar mientras se recorre el mismo registro filtrado
        // es la forma conocida de que el recorrido se corte en la primera.
        if Liq.FindSet() then
            repeat
                Numeros.Add(Liq."No.");
            until Liq.Next() = 0;

        foreach Numero in Numeros do
            // La que fallo NO se barre: esta vacia porque se rompio, no porque no corresponda, y
            // borrarla deja el problema sin evidencia en la unica pantalla donde alguien lo miraria.
            if not FFallidas.Contains(Numero) then
                if Liq.Get(Numero) then
                    if EstaVacia(Numero) then
                        BorrarLiquidacion(Liq)
                    else
                        if not SeguiriaCreandose(Liq) then
                            FSobrantes += 1;
    end;

    local procedure ConstruirFiltroTipos(var TipoLiqRec: Record "Tipo Liquidación") Filtro: Text
    begin
        if TipoLiqRec.FindSet() then
            repeat
                if Filtro <> '' then
                    Filtro += '|';
                Filtro += TipoLiqRec.Código;
            until TipoLiqRec.Next() = 0;
    end;

    /// <summary>Vacía = ninguna línea con importe. Las informativas y las de cantidad no cuentan.</summary>
    local procedure EstaVacia(NoLiq: Code[20]): Boolean
    var
        LinLiq: Record "Línea Liquidación";
    begin
        LinLiq.SetRange("No. Liquidación", NoLiq);
        LinLiq.SetFilter(Importe, '<>%1', 0);
        exit(LinLiq.IsEmpty());
    end;

    /// <summary>¿Las guardas de hoy volverían a crear esta liquidación?</summary>
    local procedure SeguiriaCreandose(Liq: Record "Liquidación"): Boolean
    var
        Periodo: Record "Período Liquidación";
        TipoLiqRec: Record "Tipo Liquidación";
    begin
        if not Periodo.Get(Liq."Cód. Período") then
            exit(true);
        if not TipoLiqRec.CorreEnElMes(Liq."Cód. Tipo Liq.", Periodo."Fecha Hasta") then
            exit(false);
        if not EstuvoEnLaEmpresa(Liq."No. Empleado", Periodo) then
            exit(false);
        if TipoLiqRec.EsBajaEmpleado(Liq."Cód. Tipo Liq.") and not SeDioDeBajaEnElPeriodo(Liq."No. Empleado", Periodo) then
            exit(false);
        exit(EstadosJustifican(Liq."No. Empleado", Liq."Cód. Período", Liq."Cód. Tipo Liq.", Liq."No. Proyecto"));
    end;

    local procedure BorrarLiquidacion(var Liq: Record "Liquidación")
    var
        Gestion: Codeunit "Gestión Liquidación";
    begin
        // Reabrir antes de borrar: el OnDelete se niega si no está en Borrador, y pasa por ahí para
        // que las novedades materializadas vuelvan a estar disponibles.
        if Liq.Estado <> Liq.Estado::Borrador then begin
            Gestion.Reabrir(Liq);
            if not Liq.Get(Liq."No.") then
                exit;
        end;
        Liq.Delete(true);
        FDescartadas += 1;
    end;

    /// <summary>
    /// Calcula las liquidaciones del período. Sin tipo, corre TODOS los activos en su Orden.
    /// </summary>
    /// <remarks>
    /// El orden importa y por eso los números se juntan tipo por tipo en una sola lista en vez de
    /// llamar una vez por tipo: un cierre de marea tiene que estar calculado antes de que la mensual
    /// lea sus acumulados. Una sola lista además deja una sola barra de progreso y una sola sesión de
    /// registro para toda la corrida, que es lo que hace que después se pueda mirar el lote entero
    /// desde cualquiera de sus liquidaciones.
    /// </remarks>
    procedure CalcularPorPeriodo(CodPeriodo: Code[10]; TipoLiq: Code[20]): Integer
    var
        LiqAct: Record "Liquidación";
        TipoLiqRec: Record "Tipo Liquidación";
        Motor: Codeunit "Motor Liquidación";
        Registro: Codeunit "Registro Procesos Liq.";
        Numeros: List of [Code[20]];
        Numero: Code[20];
        Progreso: Codeunit "Progreso Liq.";
        Calculadas: Integer;
        Total: Integer;
    begin
        if TipoLiq = '' then begin
            TipoLiqRec.SetCurrentKey(Orden);
            TipoLiqRec.SetRange(Activo, true);
            // Y ADEMÁS que el tipo haya dicho que entra. "Activo" no alcanza: ver el campo en la tabla.
            TipoLiqRec.SetRange("Entra en Corrida Completa", true);
            if TipoLiqRec.FindSet() then
                repeat
                    JuntarNumerosDeUnTipo(CodPeriodo, TipoLiqRec.Código, Numeros);
                until TipoLiqRec.Next() = 0;
        end else
            JuntarNumerosDeUnTipo(CodPeriodo, TipoLiq, Numeros);

        Total := Numeros.Count();
        if Total = 0 then
            exit(0);

        Progreso.AbrirLote(Total);
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
        Progreso.Cerrar();
        // El resumen y los descartes entran al registro, no a un cartel: el informe los lleva
        // adentro y después quedan consultables desde "Registros de proceso". Va antes de
        // MostrarAvisosDeLaSesion para que ya los incluya, y antes de CerrarSesion, que olvida
        // el Guid. Ver AvisarOmitidos, que escribe los omitidos en esta misma sesión.
        Registro.AgregarTexto(
            "Severidad Registro Liq."::Información, "Categoría Registro Liq."::General,
            StrSubstNo(RegCalculadasTxt, Calculadas, CodPeriodo, Descartadas(), Sobrantes(), Progreso.TranscurridoTexto()));
        RegistrarOmitidos(Registro);
        Registro.MostrarAvisosDeLaSesion();
        Registro.CerrarSesion();
        exit(Calculadas);
    end;

    /// <summary>
    /// Agrega a la lista los números de las liquidaciones en Borrador de ese período y tipo.
    /// </summary>
    /// <remarks>
    /// Las claves se juntan ANTES de calcular, y el bucle recorre la lista y no el registro. Iterando
    /// directo, el lote se comía TODA la tabla: LiquidarConRegistro resuelve con Ejecutor.Run(Liq), y
    /// un Codeunit.Run con parámetro de registro devuelve el registro tal como quedó en el Rec del
    /// codeunit — sin filtros. Después de la primera vuelta se perdían los filtros de período y tipo,
    /// y el Next() seguía por liquidaciones de otros períodos.
    ///
    /// Solo Borrador, igual que el cálculo por selección: lo ya calculado o aprobado no se rehace en
    /// un proceso masivo. Para recalcular hay que reabrir, que es la forma explícita de pedirlo.
    /// </remarks>
    local procedure JuntarNumerosDeUnTipo(CodPeriodo: Code[10]; TipoLiq: Code[20]; var Numeros: List of [Code[20]])
    var
        Liq: Record "Liquidación";
    begin
        Liq.SetRange("Cód. Período", CodPeriodo);
        Liq.SetRange("Cód. Tipo Liq.", TipoLiq);
        Liq.SetRange(Estado, Liq.Estado::Borrador);
        if not Liq.FindSet() then
            exit;
        repeat
            Numeros.Add(Liq."No.");
        until Liq.Next() = 0;
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
            SoloEnCurso := TipoLiqRec.Disparador = TipoLiqRec.Disparador::MareaEnCurso;
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


    /// <summary>
    /// ¿Los estados del empleado justifican esta liquidación, según lo que el tipo exige?
    /// </summary>
    /// <remarks>
    /// LA REGLA: se crea si ALGUNA línea "Exige" encuentra estado y NINGUNA "Excluye" lo encuentra.
    /// Sin líneas cargadas el tipo no tiene condición de estados y pasa — así un tipo nuevo no queda
    /// mudo por olvido, que es el modo de fallar menos costoso de los dos.
    ///
    /// Las "Exige" se combinan con O y no con Y: el caso que lo pide son las vacaciones, que se pagan
    /// si el empleado las toma este mes O si las va a tomar el que viene, y son dos líneas del mismo
    /// tipo en vez de dos tipos duplicados.
    /// </remarks>
    local procedure EstadosJustifican(EmpNo: Code[20]; CodPeriodo: Code[10]; TipoLiq: Code[20]; JobNo: Code[20]): Boolean
    var
        Linea: Record "Estado Tipo Liq.";
        Estado: Record "Estado Empleado";
        HayExige: Boolean;
        EsteJustifica: Boolean;
        EsteExcluido: Boolean;
    begin
        Linea.SetRange("Cód. Tipo Liq.", TipoLiq);
        if not Linea.FindSet() then
            exit(true);

        repeat
            if Linea.Modo = Linea.Modo::Exige then
                HayExige := true;
        until Linea.Next() = 0;

        // SE DECIDE POR ESTADO Y NO POR EMPLEADO. Antes bastaba con que UNA exclusión diera en
        // cualquier punto del período para descartar a la persona entera, y eso dejaba sin Regular a
        // quien navegó parte del mes: el 03062 tuvo guardia en puerto el 1 y el 2, pero como del 3 al
        // 24 estuvo navegando, la exclusión de NV lo sacaba y sus dos días de tierra no los pagaba
        // nadie. Eran 99 empleados y 307 días en enero de 2026.
        //
        // La exclusión existe para que la Regular no se quede con días que ya paga el Cierre, y eso
        // se cumple mirando CADA estado: alcanza con que haya uno que justifique y no esté excluido.
        // Los días de marea los sigue tomando su propio documento, porque la cobertura de cada
        // liquidación ya está recortada a su tramo.
        Estado.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
        Estado.SetRange("No. Empleado", EmpNo);
        if not Estado.FindSet() then
            // Sin estados no hay nada que justifique; sin exigencias tampoco hay nada que pedir.
            exit(not HayExige);

        repeat
            EsteJustifica := not HayExige;
            EsteExcluido := false;
            if Linea.FindSet() then
                repeat
                    if EstadoCumpleLinea(Estado, CodPeriodo, TipoLiq, JobNo, Linea) then
                        case Linea.Modo of
                            Linea.Modo::Exige:
                                EsteJustifica := true;
                            Linea.Modo::Excluye:
                                EsteExcluido := true;
                        end;
                until Linea.Next() = 0;
            if EsteJustifica and not EsteExcluido then
                exit(true);
        until Estado.Next() = 0;

        exit(false);
    end;

    /// <summary>¿Este estado concreto cumple esta línea? Misma semántica que HayEstado, fila a fila.</summary>
    /// <remarks>
    /// HayEstado arma un filtro y pregunta si queda alguno; acá el estado ya está elegido y sólo hay
    /// que comprobarlo. Las dos tienen que coincidir en la semántica, y por eso las dos resuelven la
    /// ventana con VentanaDe y el proyecto con EstadoCumpleProyecto.
    ///
    /// Una diferencia a propósito: sin ventana resoluble, HayEstado devuelve true —no es su trabajo
    /// bloquear sobre datos que no están— y acá devuelve false, porque decir que ESTE estado cumple
    /// una línea cuya ventana no se puede calcular sería inventar. El efecto es el mismo: nada se
    /// descarta por una ventana ausente, sólo que acá se descarta la línea y no el estado.
    /// </remarks>
    local procedure EstadoCumpleLinea(Estado: Record "Estado Empleado"; CodPeriodo: Code[10]; TipoLiq: Code[20]; JobNo: Code[20]; Linea: Record "Estado Tipo Liq."): Boolean
    var
        Desde: Date;
        Hasta: Date;
        Fin: Date;
    begin
        VentanaDe(CodPeriodo, TipoLiq, JobNo, Linea.Ventana, Desde, Hasta);
        if (Desde = 0D) or (Hasta = 0D) then
            exit(false);

        // Filtro, no igualdad: la línea puede decir 'BAJ*' o 'NV|PL|PS'. El blanco coincide con todo.
        if not CoincideEstadoConCache(Linea, Estado."Cód. Estado") then
            exit(false);

        if Linea."Empieza en la Ventana" then begin
            if (Estado."Fecha Inicio" < Desde) or (Estado."Fecha Inicio" > Hasta) then
                exit(false);
        end else begin
            if Estado."Fecha Inicio" > Hasta then
                exit(false);
            // Fecha Fin en blanco = estado abierto, que sigue vigente y por lo tanto toca la ventana.
            Fin := Estado.FechaFinEfectiva();
            if (Fin <> 0D) and (Fin < Desde) then
                exit(false);
        end;

        exit(EstadoCumpleProyecto(Estado, Linea));
    end;

    /// <summary>¿Hay algún estado que cumpla esta línea? Resuelve la ventana y el tipo de proyecto.</summary>
    local procedure HayEstado(EmpNo: Code[20]; CodPeriodo: Code[10]; TipoLiq: Code[20]; JobNo: Code[20]; Linea: Record "Estado Tipo Liq."): Boolean
    var
        Estado: Record "Estado Empleado";
        Job: Record Job;
        Desde: Date;
        Hasta: Date;
    begin
        VentanaDe(CodPeriodo, TipoLiq, JobNo, Linea.Ventana, Desde, Hasta);
        // Sin ventana resoluble no es trabajo de esta guarda decidir sobre datos que no están:
        // bloquear en silencio sería peor que crear de más.
        if (Desde = 0D) or (Hasta = 0D) then
            exit(true);

        Estado.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
        Estado.SetRange("No. Empleado", EmpNo);

        if Linea."Empieza en la Ventana" then
            // ARRANCA dentro de la ventana, no la roza. Es la diferencia entre "se va de vacaciones
            // el mes que viene" —anticipo— y "se fue en enero y vuelve en febrero", que no lo es.
            Estado.SetRange("Fecha Inicio", Desde, Hasta)
        else begin
            Estado.SetFilter("Fecha Inicio", '<=%1', Hasta);
            // Fecha Fin en blanco = estado abierto, que sigue vigente y por lo tanto toca la ventana.
            Estado.SetFilter("Fecha Fin", '%1|>=%2', 0D, Desde);
        end;
        // SetFilter y no SetRange: el campo guarda un filtro ('BAJ*', 'NV|PL|PS') y así viaja tal
        // cual a SQL, sin costo. El blanco no filtra nada, que es lo que significa acá.
        if Linea."Cód. Estado" <> '' then
            Estado.SetFilter("Cód. Estado", Linea."Cód. Estado");

        if Linea."Tipo Proyecto" = Linea."Tipo Proyecto"::Todos then
            exit(not Estado.IsEmpty());

        // Con calificador de proyecto hay que mirar fila por fila: el tipo no está en Estado Empleado
        // sino en el Job al que apunta. Un estado SIN proyecto cuenta como improductivo — es el caso
        // de la Regular, cuyos días de tierra no cuelgan de ninguna marea.
        if not Estado.FindSet() then
            exit(false);
        repeat
            if EstadoCumpleProyecto(Estado, Linea) then
                exit(true);
        until Estado.Next() = 0;
        exit(false);
    end;

    /// <summary>
    /// ¿El proyecto de este estado cumple el calificador de la línea?
    /// </summary>
    /// <remarks>
    /// TRES CASOS Y NINGUNO ES OBVIO:
    ///
    /// · Estado SIN proyecto cuenta como improductivo. Son los días de tierra, que no cuelgan de
    ///   ninguna marea, y es lo que la Regular busca.
    ///
    /// · Proyecto con Tipo = Todos NO BLOQUEA. "Todos" significa sin clasificar, no "ninguno", y así
    ///   lo entiende el resto del motor —AplicarFiltroJobs sólo filtra si el tipo es mayor que cero—.
    ///   Compararlo estricto dejaba afuera al 04901: sus dos proyectos de nómina no tienen fila en la
    ///   tabla de extensión, así que su Tipo se lee 0, y con un calificador Improductivo no matcheaba
    ///   nada. El empleado se quedaba sin liquidación y Meta4 sí se la había pagado.
    ///
    /// · Proyecto que no existe tampoco bloquea, por la misma razón: no es esta guarda la que tiene
    ///   que decidir sobre datos que no están.
    /// </remarks>
    local procedure EstadoCumpleProyecto(Estado: Record "Estado Empleado"; Linea: Record "Estado Tipo Liq."): Boolean
    var
        Job: Record Job;
        TipoJob: Integer;
    begin
        if Linea."Tipo Proyecto" = Linea."Tipo Proyecto"::Todos then
            exit(true);
        if Estado."No. Proyecto" = '' then
            exit(Linea."Tipo Proyecto" = Linea."Tipo Proyecto"::Improductivo);
        if not Job.Get(Estado."No. Proyecto") then
            exit(true);
        // Por el ordinal y no por el miembro: el Tipo del Job lo define la extensión Producción y su
        // opción cero no tiene nombre. Es el mismo criterio que AplicarFiltroJobs, que filtra sólo
        // cuando el tipo es mayor que cero.
        TipoJob := Job.Tipo;
        if TipoJob = 0 then
            exit(true);
        exit(TipoJob = Linea."Tipo Proyecto");
    end;

    local procedure LimpiarCachesEstados()
    begin
        Clear(FVentanas);
        Clear(FCoincide);
    end;

    /// <summary>
    /// CoincideEstado de la línea, recordando la respuesta para el par (filtro, estado).
    /// </summary>
    /// <remarks>
    /// CoincideEstado arma un registro temporal y un filtro en cada llamada, y se la llama por cada
    /// estado de cada empleado contra cada línea del tipo —12.000 veces para unos pocos códigos
    /// distintos—. El resultado sólo depende del texto del filtro y del código.
    /// </remarks>
    local procedure CoincideEstadoConCache(Linea: Record "Estado Tipo Liq."; CodEstado: Code[20]): Boolean
    var
        Clave: Text;
        Resp: Boolean;
    begin
        if Linea."Cód. Estado" = '' then
            exit(true);
        Clave := Linea."Cód. Estado" + '§' + CodEstado;
        if FCoincide.Get(Clave, Resp) then
            exit(Resp);
        Resp := Linea.CoincideEstado(CodEstado);
        FCoincide.Add(Clave, Resp);
        exit(Resp);
    end;

    /// <summary>Los días sobre los que mira una línea, según su ventana.</summary>
    /// <remarks>
    /// Sólo depende de (período, tipo, proyecto, ventana) —el Liq que arma no tiene empleado—, así que
    /// se resuelve una vez y se reparte entre todos los empleados del proyecto. Antes cada estado de
    /// cada empleado volvía a calcular la cobertura, con sus lecturas de Período, Tipo y Job.
    /// </remarks>
    local procedure VentanaDe(CodPeriodo: Code[10]; TipoLiq: Code[20]; JobNo: Code[20]; Ventana: Enum "Ventana Estado Tipo Liq."; var Desde: Date; var Hasta: Date)
    var
        Clave: Text;
        Fechas: List of [Date];
    begin
        Clave := StrSubstNo('%1|%2|%3|%4', CodPeriodo, TipoLiq, JobNo, Ventana.AsInteger());
        if FVentanas.Get(Clave, Fechas) then begin
            Desde := Fechas.Get(1);
            Hasta := Fechas.Get(2);
            exit;
        end;
        CalcularVentana(CodPeriodo, TipoLiq, JobNo, Ventana, Desde, Hasta);
        Fechas.Add(Desde);
        Fechas.Add(Hasta);
        FVentanas.Add(Clave, Fechas);
    end;

    local procedure CalcularVentana(CodPeriodo: Code[10]; TipoLiq: Code[20]; JobNo: Code[20]; Ventana: Enum "Ventana Estado Tipo Liq."; var Desde: Date; var Hasta: Date)
    var
        Liq: Record "Liquidación";
        Periodo: Record "Período Liquidación";
    begin
        Desde := 0D;
        Hasta := 0D;
        case Ventana of
            Ventana::Cobertura:
                begin
                    // La MISMA definición que después guarda el motor y que usa Gestión Novedades
                    // para repartirlas. Se puede resolver antes de insertar porque sólo depende del
                    // período, el tipo y el proyecto.
                    Liq.Init();
                    Liq."Cód. Período" := CodPeriodo;
                    Liq."Cód. Tipo Liq." := TipoLiq;
                    Liq."No. Proyecto" := JobNo;
                    Liq.Cobertura(Desde, Hasta);
                end;
            Ventana::Periodo:
                if Periodo.Get(CodPeriodo) then begin
                    Desde := Periodo."Fecha Desde";
                    Hasta := Periodo."Fecha Hasta";
                end;
            Ventana::MesSiguiente:
                if Periodo.Get(CodPeriodo) then
                    if Periodo."Fecha Hasta" <> 0D then begin
                        Desde := CalcDate('<+1D>', Periodo."Fecha Hasta");
                        Hasta := CalcDate('<CM>', Desde);
                    end;
        end;
    end;

    /// <summary>¿El empleado se dio de baja dentro del período? Para el disparador Baja.</summary>
    /// <remarks>
    /// Mira la fecha de egreso de la ficha. La fase de alta dice si PERTENECÍA a la empresa; esto
    /// dice si DEJÓ de pertenecer, que es otra pregunta y la única que hace que corresponda una
    /// liquidación final.
    /// </remarks>
    local procedure SeDioDeBajaEnElPeriodo(EmpNo: Code[20]; Periodo: Record "Período Liquidación"): Boolean
    var
        Emp: Record Employee;
    begin
        if not Emp.Get(EmpNo) then
            exit(false);
        if Emp."Termination Date" = 0D then
            exit(false);
        exit((Emp."Termination Date" >= Periodo."Fecha Desde") and (Emp."Termination Date" <= Periodo."Fecha Hasta"));
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
        // EL PROYECTO DE NÓMINA DEL ÚLTIMO BUQUE EMBARCADO. Esta liquidación agrupa por empleado y no
        // por proyecto, así que no hay una asignación de dónde sacarlo; sin esto quedaba en blanco.
        // Y en blanco no es inofensivo: el token {BUQUE} resuelve vacío y toda fuente que lea el
        // historial del BUQUE —la veda, por ejemplo— devuelve cero sin decir por qué.
        //
        // Al personal de tierra le sigue quedando en blanco, y está bien: no tiene estados de marea,
        // así que la búsqueda vuelve vacía sola y no hace falta preguntarle el convenio.
        Liq."No. Proyecto" := ProyectoNominaDe(EmpNo, Periodo."Fecha Desde", Liq."Fecha Liquidación");
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

    /// <summary>
    /// El proyecto de nómina del último buque en el que el empleado estuvo embarcado. Vacío si nunca.
    /// </summary>
    /// <remarks>
    /// Se recorre el historial de estados HACIA ATRÁS desde la fecha y se para en el primero que
    /// "Transcurre en Marea": ése dice en qué barco estaba. El buque sale de la dimensión 1 de ese
    /// proyecto, y el proyecto de nómina del atributo PROY_NOMINA del buque, con su vigencia.
    ///
    /// EL ATRIBUTO Y NO EL CAMPO DEL JOB. "Proyecto Inactividad Nómina" vive en cada marea, así que
    /// habría que cargarlo una vez por marea —3.975— y está cargado en 11. Como atributo del buque
    /// son doce filas y además tienen historial.
    ///
    /// SIN RED HACIA HR SETUP a propósito. ResolverProyectoInactividad sí cae al proyecto genérico
    /// cuando la marea no declara el suyo, porque ahí hace falta que el empleado siga teniendo un
    /// estado. Acá no: si la persona nunca navegó, la regular sin proyecto es la respuesta correcta,
    /// y ponerle el proyecto genérico a todo el personal de tierra sería inventar un dato.
    /// </remarks>
    local procedure ProyectoNominaDe(EmpNo: Code[20]; Desde: Date; FechaRef: Date): Code[20]
    var
        Estado: Record "Estado Empleado";
        CodEst: Record "Cód. Estado Empleado";
        Proyecto: Record Job;
        Atributo: Record "Atributo Entidad Liq.";
        Buque: Code[20];
        ProyNoMarea: Code[20];
    begin
        if (EmpNo = '') or (FechaRef = 0D) then
            exit('');

        Estado.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
        Estado.SetRange("No. Empleado", EmpNo);
        Estado.SetFilter("Fecha Inicio", '<=%1', FechaRef);
        if not Estado.FindLast() then
            exit('');

        // EL PROYECTO YA ESTÁ ESCRITO EN EL ESTADO cuando el estado no transcurre en marea: lo puso
        // ResolverProyectoInactividad (Cod50017) al crearlo, tomando el "Proyecto Inactividad Nómina"
        // de LA marea de la que el tripulante venía bajando. Volver a deducirlo desde el último
        // embarque —que es lo que hace el recorrido de más abajo— es una SEGUNDA fuente para el mismo
        // dato, y por otro camino: el atributo PROY_NOMINA del buque. Mientras el empleado pasó por un
        // solo buque las dos coinciden; cuando cambió, no. Del proyecto sale el buque, y del buque
        // TODOS sus atributos: la pesquería, la veda, los precios, lo que venga después.
        //
        // SE BUSCA DENTRO DEL PERÍODO Y NO A SU ÚLTIMO DÍA. Esta liquidación paga justamente los días
        // en que el tripulante NO estuvo navegando, así que el estado que la describe es uno de
        // no-marea del período, no el que esté vigente el 31. 04916 pasó el 1 y el 2 de enero de
        // guardia en la planta (PN-PPM-NOMINA) y el resto del mes navegando en el HF801: al 31 su
        // estado es de marea, y mirando sólo esa fecha la mensual terminaba sobre el proyecto del
        // potero. Con eso el sueldo de puerto tomaba la rama potera —PRECIO_PUERTO_CAL, 1.328.966— y
        // pagaba 88.597,73 donde Meta4 paga 128.094,60 con el precio de la planta.
        //
        // Se recorre hacia atrás desde el final del período y se toma el ÚLTIMO de no-marea: si hubo
        // varios, el que cierra el período es el que describe en qué quedó el mes.
        //
        // Falla sólo con los estados que NO transcurren en marea —francos, guardia, ausencias,
        // órdenes—, porque son los únicos que el recorrido de abajo saltea buscando un embarque.
        if Desde <> 0D then begin
            repeat
                if (Estado."Fecha Inicio" >= Desde) or (Estado.FechaFinEfectiva() >= Desde) then begin
                    if (ProyNoMarea = '') and (Estado."No. Proyecto" <> '') then
                        if CodEst.Get(Estado."Cód. Estado") then
                            if not CodEst."Transcurre en Marea" then
                                ProyNoMarea := Estado."No. Proyecto";
                end else
                    break;
            until Estado.Next(-1) = 0;
            if ProyNoMarea <> '' then
                exit(ProyNoMarea);
            Estado.FindLast();
        end;

        repeat
            if Estado."No. Proyecto" <> '' then
                if CodEst.Get(Estado."Cód. Estado") then
                    if CodEst."Transcurre en Marea" then begin
                        if not Proyecto.Get(Estado."No. Proyecto") then
                            exit('');
                        Buque := Proyecto."Global Dimension 1 Code";
                        if Buque = '' then
                            exit('');
                        exit(Atributo.ValorVigente('PROY_NOMINA', Estado."Tipo Entidad"::Buque, Buque, FechaRef));
                    end;
        until Estado.Next(-1) = 0;

        // EL QUE NUNCA EMBARCÓ. Todo lo de arriba busca el buque del último embarque, y para el
        // personal de tierra ese recorrido vuelve siempre vacío: sin proyecto, el lote —que arranca
        // recorriendo proyectos— no los ve, y se quedan sin liquidación aunque tengan estados, fase
        // de alta y sueldo. Eran nueve en enero de 2026, y Meta4 les pagó a todos.
        //
        // El mismo atributo, cargado sobre el EMPLEADO, cierra ese caso. No hizo falta un tipo de
        // atributo nuevo ni un campo en la ficha: "Tipo Entidad" es parte de la clave de Atributo
        // Entidad Liq. y no se valida contra el del tipo, así que el mismo código admite las dos
        // entidades. Y siendo atributo tiene vigencia, que un campo en la ficha no tendría: quien
        // pasa de planta a administración conserva el proyecto que le correspondía en cada mes.
        exit(Atributo.ValorVigente('PROY_NOMINA', "Tipo Entidad Estado"::Empleado, EmpNo, FechaRef));
    end;

    /// <summary>
    /// El próximo número de liquidación. En modo "crear y calcular" lo ESPÍA en vez de consumirlo.
    /// </summary>
    /// <remarks>
    /// Consumir un número es irreversible, y en el modo que descarta las liquidaciones vacías eso
    /// dejaría un agujero en la numeración por cada una que se tira — que son la mayoría cuando se
    /// corren todos los tipos. Por eso se espía: la liquidación se crea con ese número, y recién si
    /// sobrevive al cálculo se llama a ConsumirLiqNo. Si se descarta, nadie consumió nada y la
    /// siguiente vuelve a tomar el mismo número.
    ///
    /// Funciona porque el lote es de a uno: entre el espiar y el consumir no corre nadie más. Si
    /// alguna vez esto se paraleliza, el espiado deja de ser seguro y hay que volver a consumir
    /// siempre y aceptar los huecos.
    /// </remarks>
    procedure NextLiqNo(): Code[20]
    var
        HRSetup: Record "Human Resources Setup";
        NoSeries: Codeunit "No. Series";
    begin
        HRSetup.Get();
        if HRSetup."Cód. Serie Liq." = '' then
            Error(ErrSerieNoConfigurada);
        if FCalcYDesc then
            exit(NoSeries.PeekNextNo(HRSetup."Cód. Serie Liq.", WorkDate()));
        exit(NoSeries.GetNextNo(HRSetup."Cód. Serie Liq.", WorkDate(), true));
    end;

    local procedure ConsumirLiqNo()
    var
        HRSetup: Record "Human Resources Setup";
        NoSeries: Codeunit "No. Series";
    begin
        HRSetup.Get();
        if NoSeries.GetNextNo(HRSetup."Cód. Serie Liq.", WorkDate(), true) = '' then;
    end;

    var
        FProgreso: Codeunit "Progreso Liq.";
        Registro: Codeunit "Registro Procesos Liq.";
        // A quien ya evaluo el recorrido por proyectos para el tipo en curso. Lo consulta el
        // recorrido por estados para no volver a crear -ni a descartar- lo mismo dos veces.
        FIntentados: Dictionary of [Code[20], Boolean];
        // Caches de la evaluación por estados. Se vacían al arrancar cada recorrido.
        FVentanas: Dictionary of [Text, List of [Date]];
        FCoincide: Dictionary of [Text, Boolean];
        // Las que el motor no pudo calcular en esta corrida. Quedan afuera de la barrida.
        FFallidas: List of [Code[20]];
        FCalcYDesc: Boolean;
        FDescartadas: Integer;
        FSobrantes: Integer;
        OmitidosSinFase: Integer;
        OmitidosSinEstado: Integer;
        OmitidosPorTipoEmpleado: Integer;
        OmitidosSinBaja: Integer;
        ErrPeriodoCerrado: Label 'El período %1 está cerrado.';
        MsgOmitidosSinBaja: Label '%1 asignaciones quedaron afuera porque el empleado no se dio de baja dentro del período, y este tipo se dispara con la baja.', Comment = '%1 = cantidad de asignaciones omitidas';
        MsgOmitidosPorTipoEmpleado: Label '%1 empleados quedaron afuera porque ese tipo de liquidación no le corresponde a su clase de empleado.\Lo dice el campo "Aplica a" del tipo: por ejemplo, Vacaciones no se emite a mensualizados, que cobran el haber y el descuento de días en el mismo recibo mensual.', Comment = '%1 = cantidad de empleados omitidos';
        MsgOmitidosSinEstado: Label '%1 asignaciones quedaron afuera porque el empleado no tiene NINGÚN estado en los días que esa liquidación iba a cubrir: no hay nada que calcular.\\Casi siempre es una asignación a proyecto que quedó abierta después del desembarco. Si alguno sí trabajó esos días, lo que falta es el estado, no la liquidación.', Comment = '%1 = cantidad de asignaciones omitidas';
        ErrSerieNoConfigurada: Label 'La serie de numeración de liquidaciones no está configurada. Vaya a Configuración de RR.HH. y complete el campo "Serie Núm. Liquidaciones".';
        MsgNinguno: Label 'No se encontraron proyectos con personal activo para el período y tipo indicados.';
        ErrSinArribo: Label 'El proyecto %1 no tiene fecha de arribo (Ending Date). Cargue la fecha de llegada a puerto antes de crear el Cierre de Marea.';
        ErrSinPeriodo: Label 'No existe un período de liquidación que contenga la fecha de arribo %1. Cree el período de ese mes primero.';
        RegCalculadasTxt: Label '%1 liquidación(es) calculada(s) en el período %2.\%3 se descartaron por salir vacías.\%4 tienen importe pero la configuración de hoy ya no las crearía: quedaron sin tocar, revisalas.\Tiempo total: %5.', Comment = '%1 = calculadas; %2 = período; %3 = descartadas; %4 = sobrantes con importe; %5 = duración';
        MsgOmitidosSinFase: Label '%1 empleados quedaron afuera porque ninguna de sus fases de alta cubre el período: según las fases, ese mes no pertenecían a la empresa.\\Suele ser una asignación a proyecto que quedó abierta, o una que abarca dos temporadas y cruza el hueco entre ellas. Si alguno de estos empleados sí trabajó, lo que falta es la fase de alta, no la liquidación.', Comment = '%1 = cantidad de empleados omitidos';
        ErrSinFaseEnPeriodo: Label 'El empleado %1 no tiene ninguna fase de alta que cubra el período %2: según las fases de alta, ese mes no pertenecía a la empresa.\\Si trabajó, cargue la fase de alta antes de liquidarle.', Comment = '%1 = legajo; %2 = código de período';
        ErrAsignacionPosterior: Label 'La asignación del empleado %2 al proyecto %1 empieza el %3, después del %5 en que termina el período %4.\\Una liquidación sobre un proyecto donde el empleado todavía no estaba toma el buque equivocado, y de ahí salen la pesquería y todos los atributos del buque.\\Elegí la asignación que corresponde a ese período.', Comment = '%1 = proyecto; %2 = legajo; %3 = fecha de alta de la asignación; %4 = código de período; %5 = fecha hasta del período';
}
