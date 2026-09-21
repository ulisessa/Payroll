namespace UAS.Payroll;

// Las liquidaciones agrupadas por mes, fecha, tipo y proyecto, con subtotales por nodo.
//
// Las acciones de lote —Calcular, Reabrir, Aprobar, Eliminar, Imprimir— corren sobre el ALCANCE del
// nodo donde uno esté parado: sobre un mes, todas las de ese mes; sobre un proyecto, las de
// ese proyecto; sobre una hoja, esa sola. La lógica no está acá: vive en Lotes Liquidación Liq., el
// mismo codeunit que usa la Lista de Liquidaciones. Copiarla habría sido otra copia de algo que ya
// hubo que arreglar varias veces.
//
// Abrir sigue existiendo y lleva a la Lista ya filtrada por el nodo, para cuando hace falta elegir a
// mano un subconjunto en vez de operar sobre el nodo entero.
page 110017 "Árbol de Liquidaciones"
{
    ApplicationArea = All;
    Caption = 'Árbol de Liquidaciones';
    PageType = List;
    UsageCategory = Lists;
    SourceTable = "Árbol Liquidaciones Buffer";
    SourceTableTemporary = true;
    // El Editable = false va en el repeater y NO acá: a nivel página también apaga los controles que
    // no son del registro, y el check de presentación deja de responder. Es lo mismo que hace la
    // página base de Matriz de Cuentas: la lista de solo lectura, la cabecera viva.
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(Presentacion)
            {
                ShowCaption = false;

                field(AgrupaPorProyecto; AgrupaPorProyecto)
                {
                    ApplicationArea = All;
                    Caption = 'Agrupar por proyecto';
                    ToolTip = 'Tildado: Mes → Fecha → Tipo → Proyecto → Liquidación, para revisar una marea contra otra. Sin tildar: Mes → Fecha → Tipo → Liquidación, la secuencia de trabajo del mes leída de arriba hacia abajo en el orden en que se liquidó.';

                    trigger OnValidate()
                    begin
                        Cargar();
                    end;
                }
            }
            repeater(Lines)
            {
                Editable = false;
                ShowAsTree = true;
                IndentationColumn = Rec.Nivel;
                IndentationControls = Descripción;

                field(Descripción; Rec.Descripción)
                {
                    ApplicationArea = All;
                    Caption = 'Mes / Fecha / Tipo / Proyecto / Liquidación';
                    StyleExpr = EstiloFila;

                    trigger OnDrillDown()
                    begin
                        Abrir();
                    end;
                }
                field(Cantidad; Rec.Cantidad)
                {
                    ApplicationArea = All;
                    Caption = 'Liq.';
                    BlankZero = true;
                    ToolTip = 'Cuántas liquidaciones cuelgan de este nodo.';
                }
                field(Estado; Rec.Estado)
                {
                    ApplicationArea = All;
                    Visible = false;
                }
                field(EstadoTxt; EstadoTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Estado';
                    StyleExpr = EstiloEstado;
                }
                field("Total Haberes"; Rec."Total Haberes") { ApplicationArea = All; BlankZero = true; }
                field("Total Descuentos"; Rec."Total Descuentos") { ApplicationArea = All; BlankZero = true; }
                field("Neto a Pagar"; Rec."Neto a Pagar")
                {
                    ApplicationArea = All;
                    Style = Strong;
                    BlankZero = true;
                }
                field("No. Empleado"; Rec."No. Empleado") { ApplicationArea = All; }
                field("No. Liquidación"; Rec."No. Liquidación") { ApplicationArea = All; Visible = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AbrirAccion)
            {
                ApplicationArea = All;
                Caption = 'Abrir';
                Image = Card;
                ToolTip = 'Sobre una liquidación abre su ficha; sobre un nodo, la lista filtrada a ese período, tipo o proyecto.';
                trigger OnAction()
                begin
                    Abrir();
                end;
            }
            action(Recargar)
            {
                ApplicationArea = All;
                Caption = 'Actualizar';
                Image = Refresh;
                ToolTip = 'Vuelve a leer las liquidaciones y recalcula los subtotales.';
                trigger OnAction()
                begin
                    Cargar();
                end;
            }
            action(TodosLosPeriodos)
            {
                ApplicationArea = All;
                Caption = 'Ver todos los períodos';
                Image = ExpandAll;
                Visible = HayFiltroPeriodo;
                ToolTip = 'Quita el filtro de período y muestra el árbol completo. Sólo aparece si la página se abrió acotada a un período.';
                trigger OnAction()
                begin
                    FCodPeriodo := '';
                    Cargar();
                end;
            }
            action(CalcularNodo)
            {
                ApplicationArea = All;
                Caption = 'Calcular';
                Image = Calculate;
                ToolTip = 'Calcula todas las liquidaciones que cuelgan de los nodos marcados y estén en Borrador, Calculada o Aprobada.';

                trigger OnAction()
                var
                    Liq: Record "Liquidación";
                    Nodos: Record "Árbol Liquidaciones Buffer" temporary;
                    Lotes: Codeunit "Lotes Liquidación Liq.";
                begin
                    if not ConfirmarAlcance(AlcanceSeleccion(Liq, Nodos), Nodos, TxtVerboCalcular) then
                        exit;
                    Lotes.Calcular(Liq);
                    Cargar();
                end;
            }
            action(AprobarNodo)
            {
                ApplicationArea = All;
                Caption = 'Aprobar';
                Image = Approve;
                ToolTip = 'Aprueba las liquidaciones de los nodos marcados que estén en estado Calculada.';

                trigger OnAction()
                var
                    Liq: Record "Liquidación";
                    Nodos: Record "Árbol Liquidaciones Buffer" temporary;
                    Lotes: Codeunit "Lotes Liquidación Liq.";
                begin
                    if not ConfirmarAlcance(AlcanceSeleccion(Liq, Nodos), Nodos, TxtVerboAprobar) then
                        exit;
                    Lotes.Aprobar(Liq);
                    Cargar();
                end;
            }
            action(ReabrirNodo)
            {
                ApplicationArea = All;
                Caption = 'Reabrir';
                Image = ReOpen;
                ToolTip = 'Devuelve a Borrador las liquidaciones de los nodos marcados que estén en estado Calculada.';

                trigger OnAction()
                var
                    Liq: Record "Liquidación";
                    Nodos: Record "Árbol Liquidaciones Buffer" temporary;
                    Lotes: Codeunit "Lotes Liquidación Liq.";
                begin
                    if not ConfirmarAlcance(AlcanceSeleccion(Liq, Nodos), Nodos, TxtVerboReabrir) then
                        exit;
                    Lotes.Reabrir(Liq);
                    Cargar();
                end;
            }
            action(EliminarNodo)
            {
                ApplicationArea = All;
                Caption = 'Eliminar';
                Image = Delete;
                ToolTip = 'Elimina las liquidaciones de los nodos marcados que estén en estado Borrador.';

                trigger OnAction()
                var
                    Liq: Record "Liquidación";
                    Nodos: Record "Árbol Liquidaciones Buffer" temporary;
                    Lotes: Codeunit "Lotes Liquidación Liq.";
                begin
                    // Sin ConfirmarAlcance: Eliminar ya pregunta, y su pregunta incluye el tamaño
                    // del alcance. Dos diálogos seguidos para lo mismo se contestan sin leer.
                    if AlcanceSeleccion(Liq, Nodos) = 0 then begin
                        Message(MsgNodoVacio);
                        exit;
                    end;
                    Lotes.Eliminar(Liq);
                    Cargar();
                end;
            }
        }
        area(Reporting)
        {
            action(ImprimirRecibos)
            {
                ApplicationArea = All;
                Caption = 'Imprimir Recibos';
                Image = Print;
                ToolTip = 'Imprime los recibos de sueldo de lo marcado: sobre una liquidación, el suyo; sobre un nodo, los de todas las que cuelgan de él.';

                trigger OnAction()
                var
                    Liq: Record "Liquidación";
                    Nodos: Record "Árbol Liquidaciones Buffer" temporary;
                begin
                    if AlcanceSeleccion(Liq, Nodos) = 0 then begin
                        Message(MsgNodoVacio);
                        exit;
                    end;
                    Report.RunModal(Report::"Recibo de Sueldo", true, false, Liq);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';
                actionref(AbrirProm; AbrirAccion) { }
                actionref(RecargarProm; Recargar) { }
                actionref(TodosProm; TodosLosPeriodos) { }
                actionref(CalcularProm; CalcularNodo) { }
                actionref(AprobarProm; AprobarNodo) { }
                actionref(ReabrirProm; ReabrirNodo) { }
                actionref(EliminarProm; EliminarNodo) { }
            }
            group(Category_Report)
            {
                Caption = 'Informe';
                actionref(ImprimirProm; ImprimirRecibos) { }
            }
        }
    }

    // Abre con el árbol completo. Antes arrancaba acotado al último período con liquidaciones, pero
    // el orden ya resuelve lo que ese filtro buscaba: la clave de los nodos de mes se arma por
    // complemento (ClaveDescendente en Cod50074), así que el más reciente queda arriba igual. El
    // filtro sólo agregaba una pantalla que podía verse vacía sin que se entendiera por qué.
    //
    // FCodPeriodo sigue existiendo para quien abra la página con SetPeriodo; en ese caso el árbol
    // se acota y aparece "Ver todos los períodos" para salir del filtro.
    trigger OnOpenPage()
    begin
        AgrupaPorProyecto := true;
        Cargar();
    end;

    trigger OnAfterGetRecord()
    begin
        EstadoTxt := '';
        EstiloEstado := 'Standard';
        // Por el número de liquidación y NO por el nivel: la hoja está en el nivel 3 sólo cuando el
        // árbol no agrupa por proyecto; agrupando, la hoja es el 4 y el 3 es el proyecto. Escrito
        // contra el nivel, agrupar por proyecto dejaba a TODAS las liquidaciones sin estado y le
        // pintaba a cada nodo de proyecto el estado por defecto del enum, que no significa nada.
        if Rec."No. Liquidación" <> '' then begin
            EstadoTxt := Format(Rec.Estado);
            case Rec.Estado of
                Rec.Estado::Borrador:
                    EstiloEstado := 'Subordinate';
                Rec.Estado::Calculada:
                    EstiloEstado := 'Ambiguous';
                Rec.Estado::Aprobada, Rec.Estado::Contabilizada:
                    EstiloEstado := 'Favorable';
            end;
        end;

        // El peso visual baja con la profundidad: el período se lee primero y la liquidación
        // individual queda como detalle.
        case Rec.Nivel of
            0:
                EstiloFila := 'Strong';
            1:
                EstiloFila := 'StrongAccent';
            else
                EstiloFila := 'Standard';
        end;
    end;

    local procedure Cargar()
    var
        Liq: Record "Liquidación";
        Arbol: Codeunit "Árbol Liquidaciones Liq.";
        ClaveActual: Code[100];
    begin
        ClaveActual := Rec."Clave Orden";

        HayFiltroPeriodo := FCodPeriodo <> '';
        if FCodPeriodo <> '' then
            Liq.SetRange("Cód. Período", FCodPeriodo);
        Arbol.AgruparPorProyecto(AgrupaPorProyecto);
        Arbol.Construir(Rec, Liq);

        // Toda acción de lote termina reconstruyendo el árbol entero, porque cambia los subtotales
        // de los tres ancestros. Sin esto el foco volvía al primer nodo y había que bajar otra vez
        // hasta donde uno estaba. Si el nodo ya no existe —se eliminaron todas sus liquidaciones—
        // se cae al principio, que es lo único que queda.
        if (ClaveActual = '') or not Rec.Get(ClaveActual) then
            if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;

    // Sobre una hoja abre la ficha; si no, la lista acotada a lo que esté marcado. La ficha solo
    // sabe mostrar una liquidación, así que con varios nodos el camino es la lista.
    local procedure Abrir()
    var
        Liq: Record "Liquidación";
        Nodos: Record "Árbol Liquidaciones Buffer" temporary;
    begin
        if Rec."No. Liquidación" <> '' then
            if Liq.Get(Rec."No. Liquidación") then begin
                Page.Run(Page::"Ficha Liquidación", Liq);
                exit;
            end;

        if AlcanceSeleccion(Liq, Nodos) > 0 then
            Page.Run(Page::"Lista Liquidaciones", Liq);
    end;

    /// <summary>
    /// Deja Nodos con los nodos marcados en la página. Falso si no quedó ninguno.
    /// </summary>
    /// <remarks>
    /// La tabla origen de esta página es TEMPORAL, y ahí SetSelectionFilter no hace lo mismo que en
    /// una lista común: no existe una tabla de la base que filtrar, así que la plataforma COPIA los
    /// registros marcados en el parámetro —por eso tiene que ser temporal— y no siempre copia el
    /// registro entero. Un nodo copiado a medias —con la clave pero sin período, tipo ni proyecto—
    /// da un alcance vacío, y toda acción termina en "Lo marcado no tiene liquidaciones" aunque el
    /// nodo tenga cientos de liquidaciones colgando.
    ///
    /// Por eso lo que llega se usa solo como lista de CLAVES y cada nodo se relee del buffer de la
    /// página: Todos comparte la tabla temporal de Rec —el segundo parámetro de Copy— así que ve
    /// exactamente las mismas filas que se están mostrando y su Get no mueve el cursor de la página.
    ///
    /// Si no llega nada se opera sobre el nodo donde está parado el cursor, que es lo que el usuario
    /// ve seleccionado. La confirmación nombra el nodo y dice cuántas liquidaciones abarca, así que
    /// un alcance más chico del esperado se ve antes de aceptar.
    /// </remarks>
    /// <remarks>
    /// SetSelectionFilter va sobre Rec y NO sobre otra variable temporal, que es como estaba. La
    /// página tiene la tabla de origen TEMPORAL, y dos variables temporales de la misma tabla son
    /// dos tablas distintas: la variable aparte nacía vacía, SetSelectionFilter no encontraba nada
    /// que marcar, el FindSet daba falso y la selección entera se perdía. El síntoma engaña, porque
    /// no fallaba: caía en la red de abajo y operaba sobre el nodo donde estaba el cursor. Marcabas
    /// seis proyectos y eliminaba UNO, el último que habías tocado — sin error y con la pregunta
    /// diciendo "1 liquidación", que es la única pista que quedaba.
    ///
    /// El filtro sobre Rec se pone y se saca dentro de la misma llamada, así que el cliente nunca
    /// llega a dibujar el árbol filtrado. Lo único que hay que reponer es el foco, porque el
    /// recorrido deja el registro en la última fila.
    /// </remarks>
    local procedure NodosSeleccionados(var Nodos: Record "Árbol Liquidaciones Buffer" temporary): Boolean
    var
        ClaveFoco: Code[100];
    begin
        Nodos.Reset();
        Nodos.DeleteAll();

        ClaveFoco := Rec."Clave Orden";

        CurrPage.SetSelectionFilter(Rec);
        if Rec.FindSet() then
            repeat
                Nodos := Rec;
                if Nodos.Insert() then;
            until Rec.Next() = 0;

        Rec.Reset();
        if ClaveFoco <> '' then
            if Rec.Get(ClaveFoco) then;

        // La clave vacía es el árbol sin ninguna fila. Insertarla sería un nodo de nivel 0 sin
        // período, y ese alcance no filtra nada: un Calcular ahí se llevaría puesta la tabla entera.
        if Nodos.IsEmpty() and (ClaveFoco <> '') then begin
            Nodos := Rec;
            if Nodos.Insert() then;
        end;

        exit(not Nodos.IsEmpty());
    end;

    /// <summary>
    /// Deja Liq apuntando a las liquidaciones de TODOS los nodos marcados, y Nodos con esos nodos.
    /// </summary>
    /// <remarks>
    /// El árbol tiene multiselección —las tildes de la izquierda— y las acciones tienen que
    /// respetarla. Leer Rec directo era operar sobre el nodo donde estaba el cursor e ignorar todo
    /// lo demás: con seis períodos marcados, Eliminar preguntaba por una sola liquidación.
    ///
    /// La unión se arma con MARCAS y no con filtros. Los nodos marcados pueden ser de ramas
    /// distintas —un período entero y un proyecto suelto de otro— y eso no se puede expresar como
    /// un SetFilter sobre campos: cada nodo aporta su propia combinación de período, tipo y
    /// proyecto. Marcar tampoco tiene el tope de longitud que tendría un filtro '%1|%2|...' con
    /// cientos de números, y resuelve gratis el solapamiento: si alguien marca un período y además
    /// una hoja de adentro, la liquidación queda marcada una sola vez.
    /// </remarks>
    local procedure AlcanceSeleccion(var Liq: Record "Liquidación"; var Nodos: Record "Árbol Liquidaciones Buffer" temporary): Integer
    var
        LiqNodo: Record "Liquidación";
        Cuantas: Integer;
    begin
        Liq.Reset();
        Liq.ClearMarks();

        if not NodosSeleccionados(Nodos) then
            exit(0);

        Nodos.FindSet();
        repeat
            AlcanceDeNodo(Nodos, LiqNodo);
            if LiqNodo.FindSet() then
                repeat
                    if Liq.Get(LiqNodo."No.") then
                        Liq.Mark(true);
                until LiqNodo.Next() = 0;
        until Nodos.Next() = 0;

        // Sin Reset() acá: Liq nunca llevó filtros —el recorrido fue todo Get— así que no hay nada
        // que limpiar, y Reset es justo la llamada que puede llevarse puestas las marcas que se
        // acaban de poner. Con las marcas perdidas, MarkedOnly deja el registro en cero y toda
        // acción muere con "Lo marcado no tiene liquidaciones".
        Liq.MarkedOnly(true);

        // El total se cuenta recorriendo. No con Count() ni IsEmpty(): esos trabajan sobre los
        // filtros, y acá el alcance lo dan las MARCAS. Con nodos solapados el número además tiene
        // que ser el de liquidaciones distintas, no la suma de lo que aportó cada nodo — y este
        // número es el que sale en la pregunta de un Eliminar.
        if Liq.FindSet() then
            repeat
                Cuantas += 1;
            until Liq.Next() = 0;
        exit(Cuantas);
    end;

    /// <summary>
    /// Deja Liq filtrado a las liquidaciones que cuelgan de un nodo.
    /// </summary>
    /// <remarks>
    /// El nivel manda, no si el campo está vacío: en el nivel 2 el proyecto vacío es un alcance
    /// legítimo —el nodo "(sin proyecto)"— y filtrarlo por 'no vacío' se llevaría puestas justo esas
    /// liquidaciones. Por eso el SetRange de proyecto se hace igual con "No. Proyecto" = ''.
    /// </remarks>
    local procedure AlcanceDeNodo(Nodo: Record "Árbol Liquidaciones Buffer"; var Liq: Record "Liquidación")
    begin
        Liq.Reset();
        if Nodo."No. Liquidación" <> '' then begin
            Liq.SetRange("No.", Nodo."No. Liquidación");
            exit;
        end;

        // El filtro y no el código: un nodo de mes abarca todos los períodos de ese mes, y con un
        // SetRange sobre uno solo el lote operaría sobre menos de lo que el nodo muestra.
        if Nodo."Filtro Período" <> '' then
            Liq.SetFilter("Cód. Período", Nodo."Filtro Período")
        else
            if Nodo."Cód. Período" <> '' then
                Liq.SetRange("Cód. Período", Nodo."Cód. Período");
        if Nodo.Nivel >= 1 then
            Liq.SetRange("Fecha Liquidación", Nodo."Fecha Liquidación");
        if Nodo.Nivel >= 2 then
            Liq.SetRange("Cód. Tipo Liq.", Nodo."Cód. Tipo Liq.");
        if Nodo.Nivel >= 3 then
            Liq.SetRange("No. Proyecto", Nodo."No. Proyecto");
    end;

    /// <summary>
    /// Pregunta antes de operar, diciendo cuántas liquidaciones abarca lo marcado.
    /// </summary>
    /// <remarks>
    /// En la Lista uno marca filas y ve una por una lo que eligió. Acá no: un solo nodo de período
    /// alcanza cientos de liquidaciones sin ninguna señal previa. Una hoja sola no se pregunta —es
    /// una y está a la vista— y Eliminar no pasa por acá porque ya trae su propia confirmación.
    /// </remarks>
    local procedure ConfirmarAlcance(Cuantas: Integer; var Nodos: Record "Árbol Liquidaciones Buffer" temporary; Verbo: Text): Boolean
    var
        CuantosNodos: Integer;
    begin
        if Cuantas = 0 then begin
            Message(MsgNodoVacio);
            exit(false);
        end;

        CuantosNodos := Nodos.Count();
        if CuantosNodos > 1 then
            exit(Confirm(StrSubstNo(QstAlcanceVarios, Verbo, Cuantas, CuantosNodos), false));

        // El bucle de AlcanceSeleccion dejó el registro al final; para nombrar el nodo hay que
        // volver a pararse en él.
        Nodos.FindFirst();
        // Una hoja sola no se pregunta, y la hoja es la que TIENE número de liquidación. Preguntar
        // por el nivel daba el resultado exacto al revés cuando el árbol agrupa por proyecto: el
        // nodo de proyecto —que puede alcanzar cientos— se saltaba la confirmación, y la
        // liquidación suelta, que es una y está a la vista, la pedía.
        if Nodos."No. Liquidación" <> '' then
            exit(true);
        exit(Confirm(StrSubstNo(QstAlcance, Verbo, Cuantas, Nodos.Descripción), false));
    end;

    procedure SetPeriodo(CodPeriodo: Code[10])
    begin
        FCodPeriodo := CodPeriodo;
    end;

    var
        FCodPeriodo: Code[10];
        // Arranca tildado: la presentación con proyecto es la que se venía usando.
        AgrupaPorProyecto: Boolean;
        EstadoTxt: Text;
        EstiloFila: Text;
        EstiloEstado: Text;
        HayFiltroPeriodo: Boolean;
        MsgNodoVacio: Label 'Lo marcado no tiene liquidaciones.';
        QstAlcance: Label '¿%1 las %2 liquidación(es) que cuelgan de "%3"?', Comment = '%1=verbo (Calcular/Aprobar/Reabrir), %2=cantidad, %3=descripción del nodo';
        QstAlcanceVarios: Label '¿%1 las %2 liquidación(es) de los %3 nodos marcados?', Comment = '%1=verbo (Calcular/Aprobar/Reabrir), %2=cantidad de liquidaciones, %3=cantidad de nodos marcados';
        TxtVerboCalcular: Label 'Calcular';
        TxtVerboAprobar: Label 'Aprobar';
        TxtVerboReabrir: Label 'Reabrir';
}
