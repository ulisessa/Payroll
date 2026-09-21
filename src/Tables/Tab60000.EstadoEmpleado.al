namespace UAS.Payroll;

using Microsoft.Projects.Project.Job;

table 60000 "Estado Empleado"
{
    Caption = 'Estado Empleado';
    DataClassification = CustomerContent;
    LookupPageId = "Estados Empleado";
    DrillDownPageId = "Estados Empleado";

    fields
    {
        field(7; "No. Mov."; Integer)
        {
            Caption = 'No. Mov.';
            AutoIncrement = true;
            DataClassification = CustomerContent;
        }
        field(1; "No. Empleado"; Code[20])
        {
            Caption = 'Cód. Entidad';
            NotBlank = true;
            DataClassification = CustomerContent;
            // Employee no. when "Tipo Entidad" = Empleado; vessel code when = Buque.
            // No TableRelation here because it points to two different tables depending on "Tipo Entidad".
        }
        field(2; "Fecha Inicio"; Date)
        {
            Caption = 'Fecha Inicio';
            NotBlank = true;
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                AutoCalcFechaFinVacaciones();
            end;
        }
        field(3; "Cód. Estado"; Code[20])
        {
            Caption = 'Cód. Estado';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Cód. Estado Empleado".Código;

            trigger OnValidate()
            begin
                AutoCalcFechaFinVacaciones();
            end;
        }
        field(4; "Fecha Fin"; Date)
        {
            Caption = 'Fecha Fin';
            DataClassification = CustomerContent;
            // Fin del estado, inclusive. En blanco = abierto (sigue vigente).
            //
            // El historial es contiguo por construcción: mientras exista un estado posterior de la
            // misma entidad, este campo se mantiene solo en "Fecha Inicio del siguiente − 1", así
            // nunca queda un día sin estado. Editarlo a mano con un estado posterior cargado corre
            // el inicio de ese siguiente (ver EmpujarSiguienteEstado), que es la forma de acortar o
            // alargar un estado sin abrir un hueco.

            trigger OnValidate()
            begin
                ValidarOrdenFechas();
            end;
        }
        field(5; "Descripción Estado"; Text[100])
        {
            Caption = 'Descripción Estado';
            FieldClass = FlowField;
            CalcFormula = Lookup("Cód. Estado Empleado".Descripción WHERE(Código = FIELD("Cód. Estado")));
            Editable = false;
        }
        field(6; Observaciones; Text[250])
        {
            Caption = 'Observaciones';
            DataClassification = CustomerContent;
        }
        field(8; "No. Proyecto"; Code[20])
        {
            Caption = 'No. Proyecto';
            DataClassification = CustomerContent;
            TableRelation = Job."No.";
            Editable = false;
            // Non-blank when this state was auto-generated from a Personal Proyecto assignment;
            // blank for manually entered states. Part of K1 so there is one state per assignment.
        }
        field(9; "Tipo Entidad"; Enum "Tipo Entidad Estado")
        {
            Caption = 'Tipo Entidad';
            DataClassification = CustomerContent;
            // Empleado (default) → "Cód. Entidad" holds the employee no.; Buque → the vessel code.
            // Lets one history serve both employees and vessels.
        }
    }

    keys
    {
        key(PK; "No. Mov.")
        {
            Clustered = true;
        }
        key(K1; "Tipo Entidad", "No. Empleado", "No. Proyecto", "Fecha Inicio")
        {
            Unique = true;
        }
        key(K2; "Tipo Entidad", "No. Empleado", "Fecha Inicio")
        {
        }
    }

    trigger OnInsert()
    var
        EstadoMgt: Codeunit "Gestión Estado Empleado";
    begin
        TestField("No. Empleado");
        TestField("Fecha Inicio");
        TestField("Cód. Estado");
        ValidarNoEsAltaNiBaja();
        ValidarDentroDeFaseDeAlta();
        ValidarDentroDelProyecto();
        ValidarOrdenFechas();
        ValidarUnEstadoPorFecha();
        ValidarNoHayLiquidacionesBloqueantes("Fecha Inicio", FechaFinEfectiva());
        // Materializes the follow-up state (e.g. Vacaciones → return) regardless of entry path.
        EstadoMgt.AplicarAutoTransicion(Rec);
        // On an active → inactive transition, assign/link the inactivity project.
        EstadoMgt.ResolverProyectoInactividad(Rec);
        // Va último a propósito. AplicarAutoTransicion puede insertar el estado de retorno, y ese
        // insert corre con éste todavía sin escribir en la base: no nos ve como su anterior, así que
        // cierra al que estaba antes que nosotros con SU fecha. Sincronizar acá deja las dos puntas
        // bien: el anterior cerrado contra nuestro inicio, y el nuestro contra el retorno.
        SincronizarContiguidad();
    end;

    trigger OnModify()
    var
        FechaMin: Date;
        FechaMax: Date;
        FinAnterior: Date;
    begin
        ValidarNoEsAltaNiBaja();
        ValidarDentroDeFaseDeAlta();
        ValidarDentroDelProyecto();
        ValidarOrdenFechas();
        ValidarUnEstadoPorFecha();
        FechaMin := xRec."Fecha Inicio";
        if "Fecha Inicio" < FechaMin then FechaMin := "Fecha Inicio";

        // El tramo que cambia de manos abarca el fin viejo y el nuevo: acortar un estado le pasa esos
        // días al siguiente, y también tienen que estar libres de liquidaciones. Mirar solo el fin
        // nuevo dejaría pasar justamente el caso de acortar.
        FechaMax := FechaFinEfectiva();
        FinAnterior := xRec."Fecha Fin";
        if FinAnterior = 0D then
            FinAnterior := FechaFinDerivada();
        if FinAnterior > FechaMax then
            FechaMax := FinAnterior;
        ValidarNoHayLiquidacionesBloqueantes(FechaMin, FechaMax);

        // Acortar o alargar un estado a mano arrastra el inicio del siguiente, para no dejar días
        // sin estado ni pisar el estado que sigue.
        if ("Fecha Fin" <> xRec."Fecha Fin") and ("Fecha Fin" <> 0D) then
            EmpujarSiguienteEstado();
        SincronizarContiguidad();
    end;

    trigger OnDelete()
    begin
        ValidarNoHayLiquidacionesBloqueantes("Fecha Inicio", FechaFinEfectiva());
        // El anterior absorbe el tramo que deja libre este estado, si no el borrado abriría un hueco.
        ReabrirAnteriorAlBorrar();
    end;

    /// <summary>
    /// Fin efectivo del estado: la Fecha Fin cargada; si está en blanco, el día anterior al inicio del
    /// estado siguiente de la misma entidad, o 31/12/9999 si es el último.
    /// </summary>
    /// <remarks>
    /// La derivación se conserva como respaldo para filas anteriores a la migración de Fecha Fin y
    /// para el instante entre el insert y la sincronización de contigüidad. Todo el motor lee el fin
    /// por acá, así que ninguno de esos dos casos cambia un cálculo.
    /// </remarks>
    procedure FechaFinEfectiva(): Date
    begin
        if "Fecha Fin" <> 0D then
            exit("Fecha Fin");
        exit(FechaFinDerivada());
    end;

    local procedure FechaFinDerivada(): Date
    var
        Siguiente: Record "Estado Empleado";
    begin
        if BuscarSiguiente(Siguiente) then
            exit(Siguiente."Fecha Inicio" - 1);
        exit(DMY2Date(31, 12, 9999));
    end;

    // Cierra el estado anterior contra el inicio de éste, y toma el propio fin del estado siguiente.
    // Es lo que sostiene la contigüidad del historial en todos los caminos de alta: grilla, diálogo
    // SetEstado, carga en lote, cascada de buque y transición automática de vacaciones.
    local procedure SincronizarContiguidad()
    var
        Anterior: Record "Estado Empleado";
        Siguiente: Record "Estado Empleado";
    begin
        if BuscarAnterior(Anterior) then
            // Dos estados que arrancan el mismo día (posible con distinto No. Proyecto) no se pueden
            // encadenar sin generar un intervalo invertido: se deja el anterior como está.
            if Anterior."Fecha Inicio" < "Fecha Inicio" then
                if Anterior."Fecha Fin" <> "Fecha Inicio" - 1 then begin
                    Anterior."Fecha Fin" := "Fecha Inicio" - 1;
                    Anterior.Modify();
                end;

        if BuscarSiguiente(Siguiente) then
            "Fecha Fin" := Siguiente."Fecha Inicio" - 1;
    end;

    local procedure EmpujarSiguienteEstado()
    var
        Siguiente: Record "Estado Empleado";
        Subsiguiente: Record "Estado Empleado";
        NuevoInicio: Date;
    begin
        if not BuscarSiguiente(Siguiente) then
            exit;
        NuevoInicio := "Fecha Fin" + 1;
        if Siguiente."Fecha Inicio" = NuevoInicio then
            exit;

        // No se puede empujar más allá del estado que viene después del siguiente: ahí habría que
        // decidir cuál se pisa, y esa decisión es del usuario, no de un trigger.
        if BuscarSiguienteDe(Siguiente, Subsiguiente) then
            if NuevoInicio >= Subsiguiente."Fecha Inicio" then
                Error(ErrEmpujeInvalido, "Fecha Fin", Siguiente."Cód. Estado", Subsiguiente."Fecha Inicio");

        // Y tampoco se puede empujar el inicio más allá del fin DEL PROPIO siguiente. El guard de
        // arriba mira al sub-siguiente y deja pasar este otro caso, que es el que dejó tres filas
        // con Fecha Inicio 1/7 y Fecha Fin 30/6: alguien cerró un estado el 30/6, el siguiente se
        // corrió al 1/7, y ese siguiente ya terminaba el 30/6.
        //
        // Se corta en vez de arreglar solo porque el estado empujado se quedó sin días, y qué hacer
        // con él —borrarlo, correrle también el fin, o mover otra cosa— es una decisión de nómina.
        // Modify() sin validación no vuelve a pasar por ValidarOrdenFechas, así que si esto no
        // estuviera, el rango invertido se escribe sin que nada avise.
        if (Siguiente."Fecha Fin" <> 0D) and (Siguiente."Fecha Fin" < NuevoInicio) then
            Error(ErrEmpujeSinDias, Siguiente."Cód. Estado", Siguiente."Fecha Inicio",
                  Siguiente."Fecha Fin", NuevoInicio);

        Siguiente."Fecha Inicio" := NuevoInicio;
        Siguiente.Modify();
    end;

    local procedure ReabrirAnteriorAlBorrar()
    var
        Anterior: Record "Estado Empleado";
        Siguiente: Record "Estado Empleado";
    begin
        if not BuscarAnterior(Anterior) then
            exit;
        if BuscarSiguiente(Siguiente) then
            Anterior."Fecha Fin" := Siguiente."Fecha Inicio" - 1
        else
            // Éste era el último: el anterior pasa a ser el vigente y queda abierto.
            Anterior."Fecha Fin" := 0D;
        Anterior.Modify();
    end;

    local procedure BuscarAnterior(var Anterior: Record "Estado Empleado"): Boolean
    begin
        Anterior.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        Anterior.SetRange("Tipo Entidad", "Tipo Entidad");
        Anterior.SetRange("No. Empleado", "No. Empleado");
        Anterior.SetFilter("Fecha Inicio", '<=%1', "Fecha Inicio");
        Anterior.SetFilter("No. Mov.", '<>%1', "No. Mov.");
        exit(Anterior.FindLast());
    end;

    local procedure BuscarSiguiente(var Siguiente: Record "Estado Empleado"): Boolean
    begin
        Siguiente.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        Siguiente.SetRange("Tipo Entidad", "Tipo Entidad");
        Siguiente.SetRange("No. Empleado", "No. Empleado");
        Siguiente.SetFilter("Fecha Inicio", '>%1', "Fecha Inicio");
        Siguiente.SetFilter("No. Mov.", '<>%1', "No. Mov.");
        exit(Siguiente.FindFirst());
    end;

    local procedure BuscarSiguienteDe(Desde: Record "Estado Empleado"; var Siguiente: Record "Estado Empleado"): Boolean
    begin
        Siguiente.Reset();
        Siguiente.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        Siguiente.SetRange("Tipo Entidad", Desde."Tipo Entidad");
        Siguiente.SetRange("No. Empleado", Desde."No. Empleado");
        Siguiente.SetFilter("Fecha Inicio", '>%1', Desde."Fecha Inicio");
        Siguiente.SetFilter("No. Mov.", '<>%1', Desde."No. Mov.");
        exit(Siguiente.FindFirst());
    end;

    local procedure ValidarOrdenFechas()
    begin
        if ("Fecha Fin" <> 0D) and ("Fecha Inicio" <> 0D) and ("Fecha Fin" < "Fecha Inicio") then
            Error(ErrFinAntesDeInicio, "Fecha Fin", "Fecha Inicio");
    end;

    /// <summary>
    /// Un empleado no puede tener dos estados que arranquen el mismo día.
    /// </summary>
    /// <remarks>
    /// La clave única es (entidad, empleado, PROYECTO, fecha), así que dos estados del mismo día
    /// entran sin chocar mientras vengan de proyectos distintos —o uno con proyecto y otro sin—. Y
    /// entraban: hay dos generadores, la sincronización desde la asignación al proyecto crea el
    /// estado CON número de proyecto y SetEstadoEntidad lo crea sin, y ninguno miraba al otro.
    ///
    /// El resultado no es una fila de más: es un historial contradictorio. GetEstado hace FindLast
    /// sobre la fecha y elige uno de los dos sin criterio, así que el motor podía estar liquidando
    /// con Franco a alguien que ese día estaba navegando. Y la contigüidad tampoco se puede sostener:
    /// SincronizarContiguidad no puede cerrar al anterior contra un estado que arranca el mismo día
    /// sin generar un intervalo invertido, así que los dejaba pisados.
    ///
    /// Con esta validación puesta, un solo estado por fecha alcanza para que NO PUEDA haber
    /// solapamientos: la contigüidad se encarga del resto —al insertar uno en el medio, el anterior
    /// se cierra contra su inicio; al correr una fecha de fin, el siguiente se empuja—.
    /// </remarks>

    /// <summary>
    /// El historial de estados no admite altas ni bajas: ésas viven en "Fase Alta Empleado".
    /// </summary>
    /// <remarks>
    /// POR QUÉ SE SEPARARON. Son dos ejes ortogonales —cuándo la persona pertenece a la empresa, y
    /// qué estaba haciendo cada día— y esta tabla admite UN estado por empleado por fecha. Metidos
    /// juntos, compiten por el mismo día: el día que alguien ingresa y embarca, las dos cosas son
    /// ciertas y sólo una entra. En la migración de enero de 2026 eso fueron 153 filas, y no por
    /// datos sucios: por el modelo. Meta4 lo tiene separado desde siempre, en dos tablas.
    ///
    /// La validación es activa y no un comentario porque el error es cómodo de cometer: los códigos
    /// de alta y baja siguen existiendo en el catálogo —son los motivos de la fase— y se eligen del
    /// mismo desplegable que los operativos. Sin esto, alguien vuelve a cargar un ALT acá dentro de
    /// seis meses y la antigüedad de esa persona deja de salir de donde tiene que salir.
    /// </remarks>
    /// <summary>
    /// Un estado operativo tiene que caer adentro de una fase de alta del empleado.
    /// </summary>
    /// <remarks>
    /// REEMPLAZA A ValidarSecuenciaDespuesDeBaja, que quedó sin efecto al separar las tablas: miraba
    /// que no hubiera estados después de una baja, y ya no hay bajas en este historial. La misma
    /// protección, ahora expresada donde vive el dato.
    ///
    /// Cubre dos cosas que antes eran una sola:
    ///   · El empleado sin ninguna fase. Hoy eso no da error en ninguna liquidación: da antigüedad
    ///     cero, y los conceptos que dependen de ella salen en cero o no salen. Es el modo de falla
    ///     más caro de todos porque es invisible.
    ///   · El estado fuera de sus fases — antes del ingreso, o después de la baja. Alguien no puede
    ///     estar navegando un día en que no pertenece a la empresa.
    ///
    /// NO CREA LA FASE SOLA, y es deliberado. La fecha de alta es un hecho contractual: deducirla
    /// del primer día que tenemos registro de que la persona trabajó acierta casi siempre y falla en
    /// silencio el resto de las veces —quien ingresa un lunes y embarca el jueves pierde tres días
    /// de antigüedad, para siempre y sin que nadie lo note—. El error dice qué falta; cargarlo son
    /// dos campos en "Fases de Alta".
    /// </remarks>
    local procedure ValidarDentroDeFaseDeAlta()
    var
        Fase: Record "Fase Alta Empleado";
    begin
        // Sólo aplica a personas. Los estados de buque no tienen relación laboral.
        if "Tipo Entidad" <> "Tipo Entidad"::Empleado then
            exit;
        if ("No. Empleado" = '') or ("Fecha Inicio" = 0D) then
            exit;

        Fase.SetRange("No. Empleado", "No. Empleado");
        if Fase.IsEmpty() then
            Error(ErrSinFaseDeAlta, "No. Empleado", "Fecha Inicio");

        // La fase abierta llega hasta el infinito; la cerrada, hasta su baja inclusive.
        Fase.SetFilter("Fecha Alta", '<=%1', "Fecha Inicio");
        Fase.SetFilter("Fecha Baja", '%1|>=%2', 0D, "Fecha Inicio");
        if Fase.IsEmpty() then
            Error(ErrFueraDeFase, "Fecha Inicio", "No. Empleado");
    end;

    /// <summary>
    /// Un estado que transcurre a bordo no puede empezar después de que el buque llegó a puerto.
    /// </summary>
    /// <remarks>
    /// DE DÓNDE SALE. El 17/7/2026 alguien corrió el flujo de asignar tripulación con el WorkDate
    /// adelantado y quedaron 29 estados NV en PP-119-000308 —una marea que había vuelto el 3/6—
    /// fechados el 13/10/2026. El daño no se quedó ahí: el historial es contiguo, así que insertar
    /// un estado el 13/10 cerró el 12/10 lo que cada uno tuviera abierto. A veintidós les cerró la
    /// navegación de la marea siguiente; a uno, la licencia por enfermedad; a otro, la asignación de
    /// nómina abierta desde 2001. Dos meses después la migración derivó "Personal Proyecto" del
    /// MIN/MAX de esos estados y lo horneó en las asignaciones, y de ahí salió como "el legajo 00794
    /// tiene mal la fecha de baja". Tres tablas y dos meses para un error de un día al cargar.
    ///
    /// POR QUÉ ESTRICTO, SIN MARGEN. Sobre 58.947 estados NV con proyecto cerrado, los que empiezan
    /// después del arribo son 63, y son TODOS anomalías: los 29 de arriba más un puñado de proyectos
    /// viejos con Ending Date basura. Cero casos entre uno y tres días, o sea que no hay una práctica
    /// legítima de estirar la navegación un día por el amarre. Con una zona gris habría que elegir un
    /// umbral arbitrario; sin ella, la regla es la regla.
    ///
    /// POR QUÉ SÓLO LOS DE A BORDO. Sin filtrar por "Transcurre en Marea" esto rompería cientos de
    /// estados legítimos: los francos y las guardias que arrancan justo al día siguiente del arribo y
    /// que la migración dejó colgados del proyecto de la marea en vez del de nómina. Ésos son un
    /// problema de a qué proyecto pertenecen, no de fecha, y se arreglan moviéndolos —no prohibiéndolos.
    ///
    /// Un proyecto sin Ending Date no restringe nada: la marea sigue en curso, o es un PN- de nómina,
    /// que por definición no termina.
    /// </remarks>
    local procedure ValidarDentroDelProyecto()
    var
        Job: Record Job;
        CodEst: Record "Cód. Estado Empleado";
    begin
        if ("No. Proyecto" = '') or ("Fecha Inicio" = 0D) or ("Cód. Estado" = '') then
            exit;
        if not CodEst.Get("Cód. Estado") then
            exit;
        if not CodEst."Transcurre en Marea" then
            exit;
        if not Job.Get("No. Proyecto") then
            exit;
        if Job."Ending Date" = 0D then
            exit;

        if "Fecha Inicio" > Job."Ending Date" then
            Error(ErrEstadoDespuesDelArribo,
                  "Cód. Estado", "Fecha Inicio", "No. Proyecto", Job."Ending Date");
    end;

    local procedure ValidarNoEsAltaNiBaja()
    var
        CodEst: Record "Cód. Estado Empleado";
    begin
        if "Cód. Estado" = '' then
            exit;
        if not CodEst.Get("Cód. Estado") then
            exit;

        case CodEst."Tipo Estado" of
            CodEst."Tipo Estado"::Alta:
                Error(ErrAltaEnHistorial, "Cód. Estado");
            CodEst."Tipo Estado"::Baja:
                Error(ErrBajaEnHistorial, "Cód. Estado");
        end;
    end;

    local procedure ValidarUnEstadoPorFecha()
    var
        Otro: Record "Estado Empleado";
        Descripcion: Text;
    begin
        if ("Fecha Inicio" = 0D) or ("No. Empleado" = '') then
            exit;

        Otro.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        Otro.SetRange("Tipo Entidad", "Tipo Entidad");
        Otro.SetRange("No. Empleado", "No. Empleado");
        Otro.SetRange("Fecha Inicio", "Fecha Inicio");
        // En OnInsert el autoincremental todavía no está asignado, así que este filtro no excluye
        // nada y está bien: el registro propio tampoco está escrito todavía.
        Otro.SetFilter("No. Mov.", '<>%1', "No. Mov.");
        if not Otro.FindFirst() then
            exit;

        Descripcion := Otro."Cód. Estado";
        if Otro."No. Proyecto" <> '' then
            Descripcion += ' (' + Otro."No. Proyecto" + ')'
        else
            Descripcion += TxtSinProyecto;
        Error(ErrEstadoMismaFecha, "No. Empleado", "Fecha Inicio", Descripcion, "Cód. Estado");
    end;

    // Propuesta de fin para un estado de Vacaciones: los días que le corresponden por LCT. Queda
    // editable — si el empleado vuelve antes, se corrige y el estado siguiente se corre solo.
    local procedure AutoCalcFechaFinVacaciones()
    var
        CodEst: Record "Cód. Estado Empleado";
        EstadoMgt: Codeunit "Gestión Estado Empleado";
        DiasDerecho: Integer;
    begin
        if "Tipo Entidad" <> "Tipo Entidad"::Empleado then
            exit;
        if ("No. Empleado" = '') or ("Fecha Inicio" = 0D) or ("Cód. Estado" = '') then
            exit;
        if not CodEst.Get("Cód. Estado") then
            exit;
        if CodEst."Tipo Estado" <> CodEst."Tipo Estado"::Vacaciones then
            exit;
        DiasDerecho := EstadoMgt.CalcDiasVacaciones("No. Empleado", "Fecha Inicio");
        if DiasDerecho > 0 then
            "Fecha Fin" := "Fecha Inicio" + DiasDerecho - 1;
    end;

    local procedure ValidarNoHayLiquidacionesBloqueantes(FechaDesde: Date; FechaHasta: Date)
    var
        Liq: Record "Liquidación";
        Periodo: Record "Período Liquidación";
    begin
        // Vessel states never block employee liquidations.
        if "Tipo Entidad" <> "Tipo Entidad"::Empleado then
            exit;

        Liq.SetRange("No. Empleado", "No. Empleado");
        Liq.SetFilter(Estado, '<>%1', Liq.Estado::Borrador);
        if not Liq.FindSet() then exit;
        repeat
            if Periodo.Get(Liq."Cód. Período") then
                if (CoberturaHasta(Liq, Periodo) >= FechaDesde) and
                   (Periodo."Fecha Desde" <= FechaHasta)
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
        ErrLiquidacionesBloqueantes: Label 'Existe una liquidación no revertida para el período %1 (Liq. %2, estado: %3). Revertí la liquidación antes de modificar el historial de estados.';
        ErrFinAntesDeInicio: Label 'La Fecha Fin (%1) no puede ser anterior a la Fecha Inicio (%2).';
        ErrSinFaseDeAlta: Label 'El legajo %1 no tiene ninguna fase de alta, así que no puede tener un estado el %2: no pertenece a la empresa en ninguna fecha. Cargá el alta en "Fases de Alta" y volvé. No se crea sola a propósito — la fecha de ingreso es un dato contractual, no algo que se pueda deducir del primer día que aparece trabajando.', Comment = '%1 = legajo; %2 = fecha del estado';
        ErrFueraDeFase: Label 'El %1 cae fuera de las fases de alta del legajo %2: es anterior a su ingreso, o posterior a su baja. Si la fecha del estado está bien, lo que falta corregir es la fase.', Comment = '%1 = fecha del estado; %2 = legajo';
        ErrAltaEnHistorial: Label 'El código %1 es un alta, y las altas ya no van en el historial de estados: se cargan en "Fases de Alta". Este historial guarda qué hacía la persona cada día; la fase guarda desde cuándo pertenece a la empresa. Separadas, las dos pueden ocupar el mismo día.', Comment = '%1 = código de estado';
        ErrBajaEnHistorial: Label 'El código %1 es una baja, y las bajas ya no van en el historial de estados: se cierra la fase en "Fases de Alta", donde además va el motivo.', Comment = '%1 = código de estado';
        ErrEstadoMismaFecha: Label '%1 ya tiene un estado que arranca el %2: %3. No se puede agregar %4 el mismo día.\\Un empleado tiene un solo estado por vez. Corregí la fecha, o cerrá el estado que ya está antes de abrir el nuevo.', Comment = '%1=empleado, %2=fecha, %3=estado existente y su proyecto, %4=estado nuevo';
        TxtSinProyecto: Label ' (cargado a mano)';
        ErrEstadoDespuesDelArribo: Label 'El estado %1 no puede empezar el %2: el proyecto %3 llegó a puerto el %4.\\Un estado que transcurre a bordo termina cuando termina la marea. Si la persona siguió en el buque después del arribo, eso va contra el proyecto de nómina, no contra la marea. Y si la fecha está bien, lo que falta corregir es la fecha de arribo del proyecto.', Comment = '%1=código de estado; %2=fecha de inicio; %3=proyecto; %4=fin del proyecto';
        ErrEmpujeSinDias: Label 'Con esa fecha de fin, el estado siguiente (%1, del %2 al %3) tendría que empezar el %4 y se quedaría sin ningún día.\Decidí primero qué pasa con ese estado: borralo, corré también su fecha de fin, o elegí otra fecha de cierre para éste.', Comment = '%1=estado siguiente; %2=su inicio; %3=su fin; %4=el inicio que tendría';
        ErrEmpujeInvalido: Label 'Con Fecha Fin %1 el estado siguiente (%2) tendría que empezar después del estado que ya existe al %3. Ajustá primero ese estado.';
}
