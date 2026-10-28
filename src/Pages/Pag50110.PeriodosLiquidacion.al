namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

page 50110 "Períodos Liquidación"
{
    ApplicationArea = All;
    Caption = 'Períodos Liquidación';
    PageType = List;
    SourceTable = "Período Liquidación";
    UsageCategory = Administration;
    // El más reciente arriba: en una lista que crece un renglón por mes, el que se trabaja es
    // siempre el último. Ordena por Código y no por Año/Mes porque desde el 26/9/2026 el código es
    // aaaamm y su orden alfabético YA es el cronológico — con el formato viejo, MENSmmaaaa, esto
    // habría mezclado los años.
    SourceTableView = sorting(Código) order(descending);

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Año; Rec.Año) { ApplicationArea = All; }
                field(Mes; Rec.Mes) { ApplicationArea = All; }
                field("Fecha Desde"; Rec."Fecha Desde") { ApplicationArea = All; }
                field("Fecha Hasta"; Rec."Fecha Hasta") { ApplicationArea = All; }
                field(Estado; Rec.Estado)
                {
                    ApplicationArea = All;
                    StyleExpr = EstadoStyle;
                    // NO EDITABLE: el estado se cambia con las acciones, que preguntan antes y, en
                    // el caso de Reabrir, revisan que no haya liquidaciones que lo impidan. Tipeado
                    // en la grilla, esos controles no corren.
                    Editable = false;
                }
                field("Cód. Calendario"; Rec."Cód. Calendario")
                {
                    ApplicationArea = All;
                    ToolTip = 'Calendario base que define los días no laborables. Vacío = se cuentan días lunes a viernes.';
                }
                field("Cant. Liquidaciones"; Rec."Cant. Liquidaciones")
                {
                    ApplicationArea = All;
                    // Hidden by default: this is a Count FlowField that triggers a
                    // SELECT COUNT(*) per visible row. Users can enable via personalization.
                    Visible = false;
                }
                field("Fecha Cierre"; Rec."Fecha Cierre") { ApplicationArea = All; Editable = false; }
                field("Usuario Cierre"; Rec."Usuario Cierre") { ApplicationArea = All; Editable = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            // Las acciones siguen el ciclo de vida del período: se arman las liquidaciones, se
            // calculan, se corrigen si hace falta, y recién al final se cierra. Antes las siete
            // estaban promovidas planas en un mismo desplegable, sin orden ni relación visible.
            group(GrpPreparar)
            {
                Caption = 'Preparar';
                Image = NewDocument;
                ToolTip = 'Genera las liquidaciones del período, para todos los empleados o para uno solo.';

                action(RevisarPreparacion)
                {
                    ApplicationArea = All;
                    Caption = 'Revisar preparación';
                    Image = Check;
                    ToolTip = 'Abre la revisión manual de parámetros y datos del período antes de crear o calcular liquidaciones.';

                    trigger OnAction()
                    var
                        Control: Page "Control Previo Liquidación";
                    begin
                        Control.SetPeriodo(Rec.Código);
                        Control.Run();
                    end;
                }
                action(CrearLiquidaciones)
                {
                    ApplicationArea = All;
                    Caption = 'Crear Liquidaciones';
                    Image = CreateDocuments;
                    Enabled = Rec.Estado = Rec.Estado::Abierto;
                    ToolTip = 'Crea en borrador las liquidaciones de todos los tipos que entran en la corrida completa (cierres de marea, vacaciones, finales, devengados, regulares…), en su orden, sin calcularlas. Las que ya existen no se duplican.';

                    trigger OnAction()
                    var
                        ProcLiq: Codeunit "Proceso Liq. Por Lote";
                        Creadas: Integer;
                    begin
                        if not Confirm(QstCrearLiqs, true, Rec.Código) then
                            exit;
                        // El tipo en blanco: todos los que entran en la corrida completa, en su Orden, igual que "Crear y Calcular"
                        // pero sin calcular. Antes estaba fijo en REGULAR y el período quedaba sin cierres, vacaciones, finales ni
                        // devengados. Lo que ya existe no se duplica: el creador lo saltea.
                        Creadas := ProcLiq.CrearPorPeriodo(Rec.Código, '');
                        Message(MsgCreadas, Creadas, Rec.Código);
                        ProcLiq.AvisarOmitidos();
                        CurrPage.Update(false);
                    end;
                }
                action(CrearYCalcular)
                {
                    ApplicationArea = All;
                    Caption = 'Crear y Calcular Liquidaciones';
                    Image = CalculateSalesTax;
                    Enabled = Rec.Estado = Rec.Estado::Abierto;
                    ToolTip = 'Crea y calcula en una sola pasada TODOS los tipos activos, en su orden, y descarta las liquidaciones que salgan vacías sin quemarles el número. Una liquidación sin ninguna línea con importe no aporta nada y estorba: así no llega a quedar.';

                    trigger OnAction()
                    var
                        ProcLiq: Codeunit "Proceso Liq. Por Lote";
                        Creadas: Integer;
                    begin
                        if not Confirm(QstCrearYCalcular, true, Rec.Código) then
                            exit;
                        // El tipo va en blanco a propósito: son todos, en el Orden del tipo.
                        // Sin carteles: el resumen y los omitidos los escribe el propio proceso en
                        // el registro de la sesión, así que salen en el informe y después quedan
                        // en "Registros de proceso". Antes esto terminaba en hasta cinco Message
                        // encadenados que había que cerrar uno por uno y que no dejaban rastro.
                        Creadas := ProcLiq.CrearYCalcularPorPeriodo(Rec.Código, '');
                        CurrPage.Update(false);
                    end;
                }
                action(CrearLiqEmpleado)
                {
                    ApplicationArea = All;
                    Caption = 'Crear Liq. para Empleado';
                    Image = Employee;
                    Enabled = Rec.Estado = Rec.Estado::Abierto;
    
                    trigger OnAction()
                    var
                        CrearLiqRpt: Report "Crear Liq. para Empleado";
                    begin
                        CrearLiqRpt.SetPeriodo(Rec.Código);
                        CrearLiqRpt.RunModal();
                        CurrPage.Update(false);
                    end;
                }
            }
            group(GrpProcesar)
            {
                Caption = 'Procesar';
                Image = Calculate;
                ToolTip = 'Calcula las liquidaciones del período.';

                action(CalcularPeriodo)
                {
                    ApplicationArea = All;
                    Caption = 'Calcular Período';
                    Image = Calculate;
                    Enabled = Rec.Estado = Rec.Estado::Abierto;
                    ToolTip = 'Calcula las liquidaciones en borrador de todos los tipos que entran en la corrida completa, tipo por tipo en su orden (cierres de marea antes que regulares).';

                    trigger OnAction()
                    var
                        ProcLiq: Codeunit "Proceso Liq. Por Lote";
                        Progreso: Codeunit "Progreso Liq.";
                        Calculadas: Integer;
                    begin
                        if not Confirm(QstCalcular, true, Rec.Código) then
                            exit;
                        // El tipo en blanco: todos los de la corrida completa, en su Orden. Antes estaba fijo en REGULAR y los
                        // cierres, vacaciones, finales y devengados del período quedaban sin calcular.
                        Calculadas := ProcLiq.CalcularPorPeriodo(Rec.Código, '');
                        // El tiempo sale del progreso, que lo congeló al cerrar: acá la ventana ya no está.
                        Message(MsgCalculadas, Calculadas, Rec.Código, Progreso.TranscurridoTexto());
                        CurrPage.Update(false);
                    end;
                }
            }
            group(GrpCorregir)
            {
                Caption = 'Corregir';
                Image = Undo;
                ToolTip = 'Deshace cálculos o limpia borradores sin tocar el estado del período.';

                action(RevertirCalculadas)
                {
                    ApplicationArea = All;
                    Caption = 'Revertir Calculadas';
                    Image = Undo;
                    Enabled = Rec.Estado = Rec.Estado::Abierto;
    
                    trigger OnAction()
                    var
                        Liq: Record "Liquidación";
                        GestionLiq: Codeunit "Gestión Liquidación";
                        Revertidas: Integer;
                        Bloqueadas: Integer;
                    begin
                        Liq.SetRange("Cód. Período", Rec.Código);
                        Liq.SetRange(Estado, Liq.Estado::Calculada);
                        if Liq.IsEmpty() then begin
                            Message(MsgSinCalculadas);
                            exit;
                        end;
    
                        if not Confirm(QstRevertirCalculadas, false, Rec.Código) then
                            exit;
    
                        GestionLiq.ReabrirPeriodo(Rec.Código, Revertidas, Bloqueadas);

                        CurrPage.Update(false);
                        if Bloqueadas > 0 then
                            Message(MsgRevertidasBloqueadas, Revertidas, Rec.Código, Bloqueadas)
                        else
                            Message(MsgRevertidas, Revertidas, Rec.Código);
                    end;
                }
                action(EliminarBorradores)
                {
                    ApplicationArea = All;
                    Caption = 'Eliminar Borradores';
                    Image = Delete;
                    Enabled = Rec.Estado = Rec.Estado::Abierto;
    
                    trigger OnAction()
                    var
                        Liq: Record "Liquidación";
                        Eliminadas: Integer;
                    begin
                        Liq.SetRange("Cód. Período", Rec.Código);
                        Liq.SetRange(Estado, Liq.Estado::Borrador);
                        Eliminadas := Liq.Count();
                        if Eliminadas = 0 then begin
                            Message(MsgSinBorradores);
                            exit;
                        end;
    
                        if not Confirm(QstEliminarBorradores, false, Eliminadas, Rec.Código) then
                            exit;
    
                        Liq.FindSet();
                        repeat
                            Liq.Delete(true);
                        until Liq.Next() = 0;
    
                        CurrPage.Update(false);
                        Message(MsgEliminadas, Eliminadas, Rec.Código);
                    end;
                }
            }
            group(GrpEstado)
            {
                Caption = 'Estado del período';
                Image = Close;
                ToolTip = 'Abre el período, lo cierra o lo vuelve a abrir. Los períodos Creados no se muestran salvo que se pida.';

                action(AbrirPeriodo)
                {
                    ApplicationArea = All;
                    Caption = 'Abrir Período';
                    Image = ReleaseDoc;
                    Enabled = Rec.Estado = Rec.Estado::Creado;
                    ToolTip = 'Pasa el período de Creado a Abierto: desde ahí se le pueden cargar novedades y crear liquidaciones.';

                    trigger OnAction()
                    begin
                        Rec.Estado := Rec.Estado::Abierto;
                        Rec.Modify(true);
                        CurrPage.Update(false);
                    end;
                }
                action(PasarACreado)
                {
                    ApplicationArea = All;
                    Caption = 'Pasar a Creado';
                    Image = Undo;
                    ToolTip = 'Devuelve a Creado los períodos Abiertos seleccionados para esconderlos. Sólo los que no tienen liquidaciones. Las novedades precargadas se conservan.';

                    trigger OnAction()
                    var
                        Seleccion: Record "Período Liquidación";
                        Actual: Record "Período Liquidación";
                        Codigos: List of [Code[10]];
                        Codigo: Code[10];
                        Pasados: Integer;
                        ConLiquidaciones: Integer;
                    begin
                        // Por selección y sobre registros propios, no sobre Rec: modificar Rec cambia
                        // el Estado que filtra la página y el registro desaparece de la lista a mitad
                        // de la acción. Códigos primero, por la misma razón.
                        CurrPage.SetSelectionFilter(Seleccion);
                        if Seleccion.FindSet() then
                            repeat
                                if Seleccion.Estado = Seleccion.Estado::Abierto then
                                    Codigos.Add(Seleccion.Código);
                            until Seleccion.Next() = 0;
                        foreach Codigo in Codigos do
                            if Actual.Get(Codigo) then
                                if VolverACreado(Actual) then
                                    Pasados += 1
                                else
                                    ConLiquidaciones += 1;
                        if Pasados = 0 then
                            Error(ErrNoSePuedeOcultar, Rec.Código);
                        CurrPage.Update(false);
                        if ConLiquidaciones > 0 then
                            Message(MsgSeleccionParcial, Pasados, ConLiquidaciones);
                    end;
                }
                action(OcultarPosteriores)
                {
                    ApplicationArea = All;
                    Caption = 'Pasar a Creado los posteriores';
                    Image = Hierarchy;
                    ToolTip = 'Pasa a Creado todos los períodos Abiertos posteriores al seleccionado que no tengan liquidaciones. Es la forma de ordenar de una vez los que se cargaron por adelantado.';

                    trigger OnAction()
                    var
                        Posterior: Record "Período Liquidación";
                        Actual: Record "Período Liquidación";
                        Codigos: List of [Code[10]];
                        Codigo: Code[10];
                        Pasados: Integer;
                    begin
                        if not Confirm(QstOcultarPosteriores, false, Rec.Código) then
                            exit;
                        // Códigos primero: VolverACreado modifica Estado, que es el campo filtrado, y el
                        // registro se cae del filtro cortando el Next() en el primero.
                        Posterior.SetFilter("Fecha Desde", '>%1', Rec."Fecha Hasta");
                        Posterior.SetRange(Estado, Posterior.Estado::Abierto);
                        if Posterior.FindSet() then
                            repeat
                                Codigos.Add(Posterior.Código);
                            until Posterior.Next() = 0;
                        foreach Codigo in Codigos do
                            if Actual.Get(Codigo) then
                                if VolverACreado(Actual) then
                                    Pasados += 1;
                        CurrPage.Update(false);
                        Message(MsgOcultados, Pasados, Rec.Código);
                    end;
                }
                action(MostrarCreadosAccion)
                {
                    ApplicationArea = All;
                    Caption = 'Mostrar Creados';
                    Image = ShowList;
                    Visible = not MostrarCreados;

                    trigger OnAction()
                    begin
                        MostrarCreados := true;
                        AplicarFiltroCreados();
                        CurrPage.Update(false);
                    end;
                }
                action(OcultarCreadosAccion)
                {
                    ApplicationArea = All;
                    Caption = 'Ocultar Creados';
                    Image = HideList;
                    Visible = MostrarCreados;

                    trigger OnAction()
                    begin
                        MostrarCreados := false;
                        AplicarFiltroCreados();
                        CurrPage.Update(false);
                    end;
                }
                action(CerrarPeriodo)
                {
                    ApplicationArea = All;
                    Caption = 'Cerrar Período';
                    Image = Close;
                    Enabled = Rec.Estado = Rec.Estado::Abierto;
    
                    trigger OnAction()
                    var
                        Periodo: Record "Período Liquidación";
                        Codigos: List of [Code[10]];
                        Codigo: Code[10];
                        Cerrados: Integer;
                    begin
                        // TOMA LA SELECCIÓN, no la fila del cursor. Antes trabajaba sobre Rec, así
                        // que marcar varios períodos y cerrar cerraba uno solo, sin decir nada.
                        CurrPage.SetSelectionFilter(Periodo);
                        Periodo.SetRange(Estado, Periodo.Estado::Abierto);
                        if not Periodo.FindSet() then
                            exit;

                        // LOS CÓDIGOS PRIMERO Y EL CIERRE DESPUÉS. El bucle modifica el mismo campo
                        // por el que filtra: recorriendo y cerrando a la vez, la primera fila sale
                        // del filtro y el Next() no encuentra a las demás.
                        repeat
                            Codigos.Add(Periodo.Código);
                        until Periodo.Next() = 0;

                        if not Confirm(QstCerrarPeriodos, false, Codigos.Count()) then
                            exit;

                        foreach Codigo in Codigos do
                            if Periodo.Get(Codigo) then begin
                                // Validate y no asignación directa: el sello de fecha y usuario lo
                                // pone el OnValidate del Estado, en la tabla.
                                Periodo.Validate(Estado, Periodo.Estado::Cerrado);
                                Periodo.Modify(true);
                                Cerrados += 1;
                            end;

                        CurrPage.Update(false);
                        Message(MsgCerrados, Cerrados);
                    end;
                }
                action(ReabrirPeriodo)
                {
                    ApplicationArea = All;
                    Caption = 'Reabrir Período';
                    Image = ReOpen;
                    Enabled = Rec.Estado = Rec.Estado::Cerrado;
    
                    trigger OnAction()
                    var
                        Liq: Record "Liquidación";
                        LiqAct: Record "Liquidación";
                        GestionLiq: Codeunit "Gestión Liquidación";
                        Posterior: Record "Liquidación";
                        Numeros: List of [Code[20]];
                        Numero: Code[20];
                        Revertidas: Integer;
                        Bloqueadas: Integer;
                    begin
                        if not Confirm(QstReabrirPeriodo, false, Rec.Código) then
                            exit;
    
                        Liq.SetRange("Cód. Período", Rec.Código);
                        Liq.SetRange(Estado, Liq.Estado::Contabilizada);
                        if not Liq.IsEmpty() then
                            Error(ErrContabilizadas, Rec.Código);
    
                        // Claves primero, por lo mismo que en Revertir Calculadas: Reabrir deja el
                        // registro en Borrador, fuera de este filtro, y el recorrido se cortaba en la
                        // primera liquidación dejando el período "reabierto" a medias.
                        Liq.SetFilter(Estado, '%1|%2', Liq.Estado::Aprobada, Liq.Estado::Calculada);
                        if Liq.FindSet() then
                            repeat
                                Numeros.Add(Liq."No.");
                            until Liq.Next() = 0;
    
                        foreach Numero in Numeros do
                            if LiqAct.Get(Numero) then
                                // La pregunta va ANTES de bajar el estado: si tiene posteriores no se
                                // reabre, y una Aprobada degradada a Calculada que después no se
                                // reabre queda peor que como estaba, sin que nadie lo haya pedido.
                                if not GestionLiq.PuedeReabrir(LiqAct, Posterior) then
                                    Bloqueadas += 1
                                else begin
                                    // Aprobada baja primero a Calculada, que es lo único que Reabrir acepta.
                                    if LiqAct.Estado = LiqAct.Estado::Aprobada then begin
                                        LiqAct.Estado := LiqAct.Estado::Calculada;
                                        LiqAct.Modify(true);
                                    end;
                                    if LiqAct.Estado = LiqAct.Estado::Calculada then begin
                                        GestionLiq.Reabrir(LiqAct);
                                        Revertidas += 1;
                                    end;
                                end;

                        Rec.Estado := Rec.Estado::Abierto;
                        Rec."Fecha Cierre" := 0D;
                        Rec."Usuario Cierre" := '';
                        Rec.Modify(true);
                        CurrPage.Update(false);
                        if Bloqueadas > 0 then
                            Message(MsgPeriodoReabiertoBloqueadas, Rec.Código, Revertidas, Bloqueadas)
                        else
                            Message(MsgPeriodoReabierto, Rec.Código, Revertidas);
                    end;
                }
            }
        }
        area(Navigation)
        {
            action(VerLiquidaciones)
            {
                ApplicationArea = All;
                Caption = 'Liquidaciones';
                Image = List;
                ToolTip = 'Abre las liquidaciones de este período.';
                RunObject = Page "Lista Liquidaciones";
                RunPageLink = "Cód. Período" = field(Código);
            }
            action(ControlPeriodo)
            {
                ApplicationArea = All;
                Caption = 'Control de liquidación';
                Image = AnalysisView;
                ToolTip = 'Abre el control de este período: los conceptos por empleado en una matriz y la lista de quién se apartó de su categoría. Se acota por empleado, concepto, proyecto, tipo, fechas y encuadre.';
                trigger OnAction()
                var
                    Control: Page "Control Liquidación Período";
                begin
                    // Se abre con SetPeriodo y no con RunPageOnRec: la página dejó de tener
                    // SourceTable, así que no hay registro que pasarle — el período es un filtro.
                    Control.SetPeriodo(Rec."Código");
                    Control.Run();
                end;
            }
            action(PreviaAsiento)
            {
                ApplicationArea = All;
                Caption = 'Previa del asiento';
                Image = PreviewChecks;
                ToolTip = 'Arma el asiento de sueldos de este período por cuenta y proyecto, con los avisos de lo que no entró. No escribe el diario.';
                trigger OnAction()
                var
                    Previa: Page "Asiento Sueldos Previa";
                begin
                    Previa.SetPeriodo(Rec."Código");
                    Previa.Run();
                end;
            }
        }
        // La promoción se declara acá y no con Promoted/PromotedCategory en cada acción: así el
        // lugar donde vive la acción y el lugar donde aparece en la cinta son decisiones separadas,
        // y las categorías llevan un nombre propio en vez de amontonarse todas en la misma.
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';

                actionref(RevisarPreparacionProm; RevisarPreparacion) { }
                actionref(CrearYCalcularProm; CrearYCalcular) { }
                actionref(CrearLiquidacionesProm; CrearLiquidaciones) { }
                actionref(CalcularPeriodoProm; CalcularPeriodo) { }
                actionref(VerLiquidacionesProm; VerLiquidaciones) { }
                actionref(ControlPeriodoProm; ControlPeriodo) { }
            }
            group(Category_Category4)
            {
                Caption = 'Corregir';

                actionref(RevertirCalculadasProm; RevertirCalculadas) { }
                actionref(EliminarBorradoresProm; EliminarBorradores) { }
            }
            group(Category_Category5)
            {
                Caption = 'Período';

                actionref(AbrirPeriodoProm; AbrirPeriodo) { }
                actionref(MostrarCreadosProm; MostrarCreadosAccion) { }
                actionref(OcultarCreadosProm; OcultarCreadosAccion) { }
                actionref(CerrarPeriodoProm; CerrarPeriodo) { }
                actionref(ReabrirPeriodoProm; ReabrirPeriodo) { }
            }
        }
    }

    // Esta página es también el selector de período de las acciones y los lookups, así que el filtro
    // se pone acá y lo heredan todos: un período Creado no aparece en ningún lado salvo que se pida.
    trigger OnOpenPage()
    begin
        AplicarFiltroCreados();
    end;

    trigger OnAfterGetRecord()
    begin
        case Rec.Estado of
            Rec.Estado::Cerrado:
                EstadoStyle := 'Subordinate';
            Rec.Estado::Creado:
                EstadoStyle := 'Standard';
            else
                EstadoStyle := 'Favorable';
        end;
    end;

    // Para quien necesita elegir también entre los Creados —la hoja de novedades, que precarga por
    // adelantado—. Se llama antes de Run/RunModal.
    procedure SetMostrarCreados(Mostrar: Boolean)
    begin
        MostrarCreados := Mostrar;
    end;

    local procedure AplicarFiltroCreados()
    begin
        if MostrarCreados then
            Rec.SetRange(Estado)
        else
            Rec.SetFilter(Estado, '<>%1', Rec.Estado::Creado);
    end;

    // Devuelve el período a Creado si no tiene liquidaciones: con liquidaciones, esconderlo dejaría
    // trabajo a la vista de nadie, así que se rechaza. Las novedades no cuentan, porque justamente se
    // precargan en períodos Creados y se conservan al volver.
    local procedure VolverACreado(var Periodo: Record "Período Liquidación"): Boolean
    var
        Liq: Record "Liquidación";
    begin
        Liq.SetRange("Cód. Período", Periodo.Código);
        if not Liq.IsEmpty() then
            exit(false);
        Periodo.Estado := Periodo.Estado::Creado;
        Periodo.Modify(true);
        exit(true);
    end;

    var
        MostrarCreados: Boolean;
        ErrNoSePuedeOcultar: Label 'No se pasó ningún período a Creado. Sólo se pueden pasar los Abiertos que no tienen liquidaciones, y el %1 no cumple.', Comment = '%1 = código del período donde está el cursor';
        MsgSeleccionParcial: Label '%1 período(s) pasaron a Creado. %2 quedaron como estaban porque tienen liquidaciones.', Comment = '%1 = pasados, %2 = con liquidaciones';
        QstOcultarPosteriores: Label '¿Pasar a Creado los períodos Abiertos posteriores a %1 que no tengan liquidaciones?', Comment = '%1 = código de período';
        MsgOcultados: Label '%1 período(s) posterior(es) a %2 pasaron a Creado.', Comment = '%1 = cantidad, %2 = código de período';
        EstadoStyle: Text;
        QstEliminarBorradores: Label '¿Eliminar %1 liquidación(es) en estado Borrador del período %2? Esta acción no se puede deshacer.';
        MsgSinBorradores: Label 'No hay liquidaciones en estado Borrador en este período.';
        MsgEliminadas: Label '%1 liquidación(es) eliminada(s) del período %2.';
        QstRevertirCalculadas: Label '¿Revertir todas las liquidaciones calculadas del período %1 a Borrador?';
        MsgSinCalculadas: Label 'No hay liquidaciones en estado Calculada en este período.';
        MsgRevertidas: Label '%1 liquidación(es) revertida(s) a Borrador en el período %2.';
        MsgRevertidasBloqueadas: Label '%1 liquidación(es) revertida(s) a Borrador en el período %2.\\%3 quedaron como estaban porque el empleado tiene liquidaciones posteriores: reabrirlas liberaría novedades y cuotas que la posterior volvería a tomar. Usá "Recalcular en cadena" sobre cada una.', Comment = '%1=revertidas, %2=período, %3=bloqueadas';
        QstReabrirPeriodo: Label '¿Confirma la reapertura del período %1? Todas las liquidaciones calculadas/aprobadas volverán a estado Borrador.';
        ErrContabilizadas: Label 'Existen liquidaciones contabilizadas en el período %1. Revierta la contabilización antes de reabrir.';
        MsgPeriodoReabierto: Label 'Período %1 reabierto. %2 liquidación(es) revertida(s) a Borrador.';
        MsgPeriodoReabiertoBloqueadas: Label 'Período %1 reabierto. %2 liquidación(es) revertida(s) a Borrador.\\%3 quedaron con su estado original porque el empleado tiene liquidaciones posteriores: reabrirlas liberaría novedades y cuotas que la posterior volvería a tomar. Usá "Recalcular en cadena" sobre cada una.', Comment = '%1=período, %2=revertidas, %3=bloqueadas';
        QstCrearLiqs: Label '¿Crear las liquidaciones de todos los tipos que corresponden en el período %1? Las que ya existen no se duplican.';
        QstCrearYCalcular: Label '¿Crear y calcular las liquidaciones de TODOS los tipos activos del período %1?\\Las que salgan sin ninguna línea con importe se descartan solas, y su número queda libre para la siguiente.', Comment = '%1 = código de período';
        QstCalcular: Label '¿Calcular todas las liquidaciones del período %1?';
        QstCerrarPeriodos: Label '¿Confirma el cierre de %1 período(s)? Sólo se cierran los que están Abiertos, y la acción no se puede deshacer.', Comment = '%1 = cuántos períodos abiertos hay en la selección';
        MsgCerrados: Label '%1 período(s) cerrado(s).', Comment = '%1 = cuántos se cerraron';
        MsgCreadas: Label '%1 liquidación(es) creada(s) en el período %2.';
        MsgCalculadas: Label '%1 liquidación(es) calculada(s) en el período %2.\\Tiempo total: %3.', Comment = '%1=cantidad, %2=período, %3=duración del lote';
}
