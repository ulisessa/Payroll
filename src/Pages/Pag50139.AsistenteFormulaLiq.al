namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.Projects.Project.Job;

page 50139 "Asistente Fórmula Liq."
{
    ApplicationArea = All;
    Caption = 'Asistente de Fórmulas';
    PageType = Card;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            group(GrpContexto)
            {
                Caption = 'Contexto de prueba';
                field(CodEmpleado; CodEmpleado)
                {
                    ApplicationArea = All;
                    Caption = 'No. Empleado';
                    ToolTip = 'Empleado a simular. Al completarlo se traen su Convenio y Categoría (de la asignación al proyecto si hay, si no de la Ficha Empleado) y se recarga el contexto.';
                    trigger OnValidate()
                    begin
                        DerivarConvenioCategoria();
                        RecargarSiHayContexto();
                    end;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Emp: Record Employee;
                    begin
                        if Page.RunModal(Page::"Employee List", Emp) = Action::LookupOK then begin
                            CodEmpleado := Emp."No.";
                            Text := Emp."No.";
                            exit(true);
                        end;
                    end;
                }
                field(CodPeriodo; CodPeriodo)
                {
                    ApplicationArea = All;
                    Caption = 'Período';
                    ToolTip = 'Período a simular. Al abrir el asistente se propone el período que contiene la fecha de trabajo.';
                    trigger OnValidate()
                    begin
                        RecargarSiHayContexto();
                    end;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Per: Record "Período Liquidación";
                    begin
                        if Page.RunModal(Page::"Períodos Liquidación", Per) = Action::LookupOK then begin
                            CodPeriodo := Per.Código;
                            Text := Per.Código;
                            exit(true);
                        end;
                    end;
                }
                field(CodConvenio; CodConvenio)
                {
                    ApplicationArea = All;
                    Caption = 'Cód. Convenio';
                    ToolTip = 'Convenio para resolver parámetros con sufijo. Se completa solo desde el empleado; cambiarlo a mano permite simular otro convenio.';
                    trigger OnValidate()
                    begin
                        CodCategoria := '';
                    end;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Convenio: Record "Convenio Colectivo";
                    begin
                        if Page.RunModal(Page::"Convenios Colectivos", Convenio) = Action::LookupOK then begin
                            CodConvenio := Convenio.Código;
                            CodCategoria := '';
                            Text := Convenio.Código;
                            exit(true);
                        end;
                    end;
                }
                field(CodCategoria; CodCategoria)
                {
                    ApplicationArea = All;
                    Caption = 'Cód. Categoría';
                    ToolTip = 'Categoría para resolver parámetros con Sufijo CCT. Se completa sola desde el empleado; cambiarla a mano permite simular otra categoría.';
                    trigger OnValidate()
                    begin
                        RecargarSiHayContexto();
                    end;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Categoria: Record "Categoría CCT";
                    begin
                        Categoria.SetRange("Cód. Convenio", CodConvenio);
                        if Page.RunModal(Page::"Categorías CCT", Categoria) = Action::LookupOK then begin
                            CodCategoria := Categoria.Código;
                            Text := Categoria.Código;
                            RecargarSiHayContexto();
                            exit(true);
                        end;
                    end;
                }
                field(TipoLiqCtx; TipoLiqCtx)
                {
                    ApplicationArea = All;
                    Caption = 'Tipo Liquidación';
                    TableRelation = "Tipo Liquidación".Código;
                    ToolTip = 'Tipo de liquidación a simular. Si está marcado "Liquida al Arribo" (Cierre Marea), la fecha de referencia pasa a ser el arribo del Proyecto (abajo) en vez del fin de período — igual que en el motor real.';
                    trigger OnValidate()
                    begin
                        RecargarSiHayContexto();
                    end;
                }
                field(CodProyecto; CodProyecto)
                {
                    ApplicationArea = All;
                    Caption = 'No. Proyecto (Marea)';
                    TableRelation = Job."No.";
                    ToolTip = 'Proyecto/marea a simular. Necesario para variables que dependen del viaje (DIAS_PROYECTO, DIAS_PUERTO, DIAS_ENROLAMIENTO, Fuentes de Datos con {JOB_NO}) y para la fecha de arribo en Cierre Marea. Al completarlo se traen Convenio y Categoría de la asignación del empleado.';
                    trigger OnValidate()
                    begin
                        DerivarConvenioCategoria();
                        RecargarSiHayContexto();
                    end;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Job: Record Job;
                    begin
                        if Page.RunModal(Page::"Job List", Job) = Action::LookupOK then begin
                            CodProyecto := Job."No.";
                            Text := Job."No.";
                            exit(true);
                        end;
                    end;
                }
            }
            group(GrpFormula)
            {
                Caption = 'Fórmula';
                usercontrol(Editor; "Editor Fórmula Liq.")
                {
                    ApplicationArea = All;

                    // El add-in puede recrearse cuando la página se refresca, así que este trigger
                    // reenvía SIEMPRE todo el estado en vez de asumir que ya lo tiene.
                    trigger ControlAddInReady()
                    begin
                        FEditorListo := true;
                        AsegurarContextoCargado();
                        PushEstadoAlEditor();
                    end;

                    // Nada de CurrPage.Update() acá: redibujar la página mientras el usuario escribe
                    // le haría perder el foco y el cursor. La devolución (resultado o error) va por
                    // SetDiagnostico, que el editor pinta en su propia barra.
                    trigger OnTextoCambiado(Campo: Text; Texto: Text)
                    begin
                        GuardarTextoDeEditor(Campo, Texto);
                        EnviarDiagnostico(Campo);
                    end;
                }
                group(GrpTextoPlano)
                {
                    Caption = 'Texto plano';
                    Visible = FTextoPlanoVisible;

                    field(FormulaText; FormulaText)
                    {
                        ApplicationArea = All;
                        Caption = 'Fórmula';
                        MultiLine = true;
                        StyleExpr = StyleFormula;
                        ToolTip = 'La misma fórmula como texto editable, para copiar y pegar. Los cambios se reflejan en el editor al validar.';
                        trigger OnValidate()
                        begin
                            ValidarSintaxis(FormulaText, StyleFormula);
                            PushEstadoAlEditor();
                        end;
                    }
                    field(CondicionText; CondicionText)
                    {
                        ApplicationArea = All;
                        Caption = 'Condición (opcional)';
                        MultiLine = true;
                        StyleExpr = StyleCondicion;
                        ToolTip = 'Expresión booleana. Vacía = siempre activo.';
                        trigger OnValidate()
                        begin
                            ValidarSintaxisCondicion(CondicionText, StyleCondicion);
                            PushEstadoAlEditor();
                        end;
                    }
                }
            }
            group(GrpResultado)
            {
                Caption = 'Resultado';
                field(ResultadoImporte; ResultadoImporte)
                {
                    ApplicationArea = All;
                    Caption = 'Importe calculado';
                    Editable = false;
                    DecimalPlaces = 2 : 6;
                    StyleExpr = StyleResultado;
                }
                field(CondicionActiva; CondicionActiva)
                {
                    ApplicationArea = All;
                    Caption = 'Condición activa';
                    Editable = false;
                }
                field(MensajeResultado; MensajeResultado)
                {
                    ApplicationArea = All;
                    Caption = 'Mensaje';
                    Editable = false;
                    MultiLine = true;
                    StyleExpr = StyleMensaje;
                }
            }
            part(Variables; "Variables Liq. Test Sub")
            {
                ApplicationArea = All;
                Caption = 'Variables (doble clic = insertar en fórmula)';
                UpdatePropagation = Both;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CargarVariables)
            {
                ApplicationArea = All;
                Caption = 'Cargar catálogo completo';
                Image = Refresh;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Carga TODAS las variables disponibles: parámetros con Nombre Variable, variables de sistema, fuentes de datos y acumuladores — leídos de las tablas reales, siempre al día. Los valores son orientativos (0 salvo que completes Convenio/Categoría para parámetros); usá "Cargar contexto completo" para valores reales de un empleado/período puntual.';
                trigger OnAction()
                begin
                    CurrPage.Variables.Page.LimpiarFiltro();
                    CargarCatalogoVariables();
                    PushEstadoAlEditor();
                    CurrPage.Update(false);
                end;
            }
            action(CargarContextoCompleto)
            {
                ApplicationArea = All;
                Caption = 'Cargar contexto completo';
                Image = RefreshLines;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Carga todas las variables del contexto real para el empleado y período indicados, incluyendo Fuente Datos (DIAS_VAC, INCID_*, etc.). Requiere No. Empleado y Período.';
                trigger OnAction()
                begin
                    CurrPage.Variables.Page.LimpiarFiltro();
                    DoCargarContextoCompleto();
                    PushEstadoAlEditor();
                    CurrPage.Update(false);
                end;
            }
            action(VerTextoPlano)
            {
                ApplicationArea = All;
                Caption = 'Ver texto plano';
                Image = Text;
                ToolTip = 'Muestra la fórmula y la condición como campos de texto comunes, para copiar y pegar o para seguir trabajando si el editor con IntelliSense no cargara.';
                trigger OnAction()
                begin
                    FTextoPlanoVisible := not FTextoPlanoVisible;
                    CurrPage.Update(false);
                end;
            }
            action(AutoCompletar)
            {
                ApplicationArea = All;
                Caption = 'Auto-completar';
                Image = Find;
                ToolTip = 'Completa la última palabra del texto plano. En el editor con IntelliSense usá Ctrl+Espacio, que completa en la posición del cursor.';
                trigger OnAction()
                begin
                    DoAutoCompletar();
                    PushEstadoAlEditor();
                    CurrPage.Update(false);
                end;
            }
            action(Evaluar)
            {
                ApplicationArea = All;
                Caption = 'Evaluar';
                Image = Calculate;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Evalúa la fórmula y condición con los valores de prueba ingresados.';
                trigger OnAction()
                begin
                    EvaluarFormula();
                    CurrPage.Update(false);
                end;
            }
            action(AplicarYCerrar)
            {
                ApplicationArea = All;
                Caption = 'Aplicar y Cerrar';
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Visible = FInvocadoDesdeConcepto;
                ToolTip = 'Aplica esta Fórmula y Condición al concepto que la abrió, y cierra el asistente.';
                trigger OnAction()
                begin
                    FAceptado := true;
                    CurrPage.Close();
                end;
            }
            group(GrpFunciones)
            {
                Caption = 'Insertar';
                Image = Insert;
                ToolTip = 'Inserta una función u operador al final de la fórmula.';

                group(GrpFnAritmeticas)
                {
                    Caption = 'Funciones';

                    action(InsABS)
                    {
                        ApplicationArea = All;
                        Caption = 'ABS( )';
                        ToolTip = 'Valor absoluto. ABS(valor)';
                        trigger OnAction()
                        begin
                            InsertText('ABS(');
                        end;
                    }
                    action(InsROUND)
                    {
                        ApplicationArea = All;
                        Caption = 'ROUND( , )';
                        ToolTip = 'Redondeo. ROUND(valor, precisión). Ej: ROUND(x, 0.01)';
                        trigger OnAction()
                        begin
                            InsertText('ROUND(');
                        end;
                    }
                    action(InsMAX)
                    {
                        ApplicationArea = All;
                        Caption = 'MAX( , )';
                        ToolTip = 'Máximo de dos valores. MAX(a, b)';
                        trigger OnAction()
                        begin
                            InsertText('MAX(');
                        end;
                    }
                    action(InsMIN)
                    {
                        ApplicationArea = All;
                        Caption = 'MIN( , )';
                        ToolTip = 'Mínimo de dos valores. MIN(a, b)';
                        trigger OnAction()
                        begin
                            InsertText('MIN(');
                        end;
                    }
                    action(InsREDONDEAR)
                    {
                        ApplicationArea = All;
                        Caption = 'REDONDEAR( , )';
                        ToolTip = 'Redondea a N decimales. REDONDEAR(valor, decimales). Ej: REDONDEAR(5473.286, 2) = 5473,29';
                        trigger OnAction()
                        begin
                            InsertText('REDONDEAR(');
                        end;
                    }
                    action(InsPISO)
                    {
                        ApplicationArea = All;
                        Caption = 'PISO( )';
                        ToolTip = 'Entero inmediatamente menor o igual al valor. PISO(valor)';
                        trigger OnAction()
                        begin
                            InsertText('PISO(');
                        end;
                    }
                    action(InsTECHO)
                    {
                        ApplicationArea = All;
                        Caption = 'TECHO( )';
                        ToolTip = 'Entero inmediatamente mayor o igual al valor. TECHO(valor)';
                        trigger OnAction()
                        begin
                            InsertText('TECHO(');
                        end;
                    }
                    action(InsIF)
                    {
                        ApplicationArea = All;
                        Caption = 'IF( , , )';
                        ToolTip = 'Condicional. IF(condición, valor_si_true, valor_si_false). Todos los argumentos se evalúan antes de elegir la rama.';
                        trigger OnAction()
                        begin
                            InsertText('IF(');
                        end;
                    }
                    action(InsDIV)
                    {
                        ApplicationArea = All;
                        Caption = 'DIV( , )';
                        ToolTip = 'División segura: devuelve 0 si el divisor es 0. DIV(a, b)';
                        trigger OnAction()
                        begin
                            InsertText('DIV(');
                        end;
                    }
                    action(InsTRAMO)
                    {
                        ApplicationArea = All;
                        Caption = 'TRAMO( , )';
                        ToolTip = 'Consulta tabla escalonada. TRAMO(''código'', valor). Ej: TRAMO(''TAB_IMP_4CAT'', BASE_IG4 * 12)';
                        trigger OnAction()
                        begin
                            InsertText('TRAMO(');
                        end;
                    }
                }
                group(GrpOperadores)
                {
                    Caption = 'Operadores (Condición)';

                    action(InsAND)
                    {
                        ApplicationArea = All;
                        Caption = 'AND';
                        ToolTip = 'Conjunción lógica. Ej: ANIOS_ANTIGUEDAD >= 2 AND BASE_SS > 0';
                        trigger OnAction()
                        begin
                            InsertText(' AND ');
                        end;
                    }
                    action(InsOR)
                    {
                        ApplicationArea = All;
                        Caption = 'OR';
                        ToolTip = 'Disyunción lógica. Ej: DIAS_MAR = 0 OR BASE_SS = 0';
                        trigger OnAction()
                        begin
                            InsertText(' OR ');
                        end;
                    }
                    action(InsNOT)
                    {
                        ApplicationArea = All;
                        Caption = 'NOT';
                        ToolTip = 'Negación lógica. Ej: NOT DIAS_MAR = 0';
                        trigger OnAction()
                        begin
                            InsertText('NOT ');
                        end;
                    }
                }
            }
        }
    }

    // Sin variables cargadas el asistente no puede validar ni autocompletar nada, y el editor avisa
    // "Cargá el catálogo o el contexto" — había que acordarse de apretar el botón antes de escribir.
    // Se carga solo al abrir.
    trigger OnOpenPage()
    begin
        InicializarContexto();
    end;

    trigger OnAfterGetCurrRecord()
    var
        Pendiente: Text[100];
    begin
        // Pick up any variable inserted from the subpage row action
        Pendiente := CurrPage.Variables.Page.GetAndClearPendingInsert();
        if Pendiente <> '' then begin
            if FormulaText <> '' then
                FormulaText += ' ';
            FormulaText += Pendiente;
            ValidarSintaxis(FormulaText, StyleFormula);
            PushEstadoAlEditor();
        end;
    end;

    var
        FormulaText: Text[2048];
        CondicionText: Text[2048];
        ResultadoImporte: Decimal;
        CondicionActiva: Boolean;
        MensajeResultado: Text[500];
        StyleFormula: Text[50];
        StyleCondicion: Text[50];
        StyleResultado: Text[50];
        StyleMensaje: Text[50];
        CodEmpleado: Code[20];
        CodPeriodo: Code[10];
        CodConvenio: Code[20];
        CodCategoria: Code[20];
        TipoLiqCtx: Code[20];
        CodProyecto: Code[20];
        FAceptado: Boolean;
        FInvocadoDesdeConcepto: Boolean;
        FEditorListo: Boolean;
        FTextoPlanoVisible: Boolean;

    procedure SetFormula(Formula: Text[2048]; Condicion: Text[2048])
    begin
        FormulaText := Formula;
        CondicionText := Condicion;
    end;

    // Call after SetFormula when opening the assistant from a Concepto Card, so "Aplicar y Cerrar"
    // appears and the caller can pull the edited text back out via Confirmado()/GetFormula().
    procedure SetOrigenConcepto()
    begin
        FInvocadoDesdeConcepto := true;
    end;

    // True only if the user explicitly used "Aplicar y Cerrar" — closing via X/Esc leaves this false,
    // so the caller doesn't overwrite its formula with an abandoned scratch edit.
    procedure Confirmado(): Boolean
    begin
        exit(FAceptado);
    end;

    procedure GetFormula(var Formula: Text[2048]; var Condicion: Text[2048])
    begin
        Formula := FormulaText;
        Condicion := CondicionText;
    end;

    // ── Editor con IntelliSense (controladdin) ────────────────────────────────

    // Empuja el catálogo COMPLETO de una sola vez: el filtrado del autocompletado ocurre en el
    // navegador. Consultar al servidor por cada tecla metería una ida y vuelta en el camino crítico
    // del tipeo, que es justamente lo que hace que un autocompletado se sienta mal.
    local procedure PushEstadoAlEditor()
    begin
        if not FEditorListo then
            exit;
        CurrPage.Editor.SetCatalogo(CurrPage.Variables.Page.BuildCatalogoJson());
        CurrPage.Editor.SetValores(FormulaText, CondicionText);
        EnviarDiagnostico(CampoFormulaTok);
        EnviarDiagnostico(CampoCondicionTok);
    end;

    local procedure GuardarTextoDeEditor(Campo: Text; Texto: Text)
    var
        CR: Char;
        LF: Char;
    begin
        // Se normaliza igual que NormalizarTexto en Tab60007 (saltos de línea → espacio): el motor
        // solo saltea el espacio simple, así que un salto de línea le daría "token inesperado".
        // Conviene que el diagnóstico corra sobre exactamente el texto que se va a persistir.
        CR := 13;
        LF := 10;
        Texto := Texto.Replace('' + CR, ' ').Replace('' + LF, ' ');
        if Campo = CampoCondicionTok then
            CondicionText := CopyStr(Texto, 1, MaxStrLen(CondicionText))
        else
            FormulaText := CopyStr(Texto, 1, MaxStrLen(FormulaText));
    end;

    // Evalúa de verdad contra el contexto cargado y devuelve el resultado o el error al editor, que
    // lo muestra en su barra inferior. Llega con debounce desde el navegador, no en cada tecla.
    local procedure EnviarDiagnostico(Campo: Text)
    var
        Evaluador: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Diag: JsonObject;
        Texto: Text;
        Json: Text;
        ValorDec: Decimal;
        ValorBool: Boolean;
    begin
        if not FEditorListo then
            exit;

        if Campo = CampoCondicionTok then
            Texto := CondicionText
        else
            Texto := FormulaText;

        Diag.Add('campo', Campo);
        CurrPage.Variables.Page.GetContext(Ctx);

        if Texto.Trim() = '' then
            AgregarDiag(Diag, 'neutro', '', '')
        else
            if Ctx.Count = 0 then
                // Sin variables cargadas no se puede distinguir "variable inexistente" de "variable
                // que todavía no cargaste", así que se avisa en vez de marcar todo como error.
                AgregarDiag(Diag, 'neutro', SinContextoMsg, '')
            else begin
                Evaluador.Init(Ctx, WorkDate());
                if Campo = CampoCondicionTok then begin
                    if Evaluador.TryEvalCondicion(Texto, ValorBool) then
                        AgregarDiag(Diag, 'ok', '', Format(ValorBool))
                    else
                        AgregarDiag(Diag, 'error', GetLastErrorText(), '');
                end else
                    if Evaluador.TryEvalFormula(Texto, ValorDec) then
                        AgregarDiag(Diag, 'ok', '', Format(ValorDec, 0, '<Precision,2:6><Standard Format,0>'))
                    else
                        AgregarDiag(Diag, 'error', GetLastErrorText(), '');
            end;

        Diag.WriteTo(Json);
        CurrPage.Editor.SetDiagnostico(Json);
    end;

    local procedure AgregarDiag(var Diag: JsonObject; Estado: Text; Mensaje: Text; Valor: Text)
    begin
        Diag.Add('estado', Estado);
        Diag.Add('mensaje', Mensaje);
        Diag.Add('valor', Valor);
    end;

    // El catálogo lo arma "Catálogo Variables Liq." leyendo las tablas de configuración: es el mismo
    // que usa el editor con IntelliSense de la Ficha de Concepto, así que una fuente de datos nueva
    // aparece en las dos pantallas sin tocar ninguna.
    local procedure CargarCatalogoVariables()
    var
        Cat: Record "Variable Liq. Test" temporary;
        Catalogo: Codeunit "Catálogo Variables Liq.";
    begin
        Catalogo.CargarCatalogo(Cat, CodEmpleado, CodConvenio, CodCategoria);
        if Cat.FindSet() then
            repeat
                SetVar(Cat.Nombre, Cat.Valor, Cat.Descripción, Cat.Tipo);
            until Cat.Next() = 0;
    end;

    // Deja la página usable desde el primer segundo. Si el contexto alcanza para una carga real
    // (empleado + período) se cargan los valores del motor; si no, al menos el catálogo completo de
    // nombres, que es lo que necesita el IntelliSense y la validación de sintaxis.
    local procedure InicializarContexto()
    var
        Periodo: Record "Período Liquidación";
    begin
        if CodPeriodo = '' then
            CodPeriodo := Periodo.PeriodoPorDefecto();
        DerivarConvenioCategoria();

        CurrPage.Variables.Page.LimpiarFiltro();
        if (CodEmpleado <> '') and (CodPeriodo <> '') then
            DoCargarContextoCompleto()
        else
            CargarCatalogoVariables();
    end;

    // El add-in avisa que está listo recién cuando la página terminó de armarse, partes incluidas. Si
    // la carga de OnOpenPage no sobrevivió a la inicialización de la parte (tabla temporal), se
    // reintenta acá: con el catálogo vacío el editor no valida ni autocompleta nada.
    local procedure AsegurarContextoCargado()
    var
        Ctx: Dictionary of [Text, Decimal];
    begin
        CurrPage.Variables.Page.GetContext(Ctx);
        if Ctx.Count = 0 then
            InicializarContexto();
    end;

    // Mismo origen que la liquidación real: la Ficha Empleado (Tab60011, OnValidate de No. Empleado)
    // y, si el empleado está asignado al proyecto, la asignación pisa esos valores (Cod50014
    // LiquidarRecord). Así los parámetros con Sufijo CCT/Convenio resuelven acá el mismo valor que en
    // el motor sin que haya que tipearlos. Solo corre al cambiar empleado o proyecto: editar Convenio
    // o Categoría a mano para simular otra escala sigue mandando.
    local procedure DerivarConvenioCategoria()
    var
        Emp: Record Employee;
        PersProy: Record "Personal Proyecto";
    begin
        if CodEmpleado = '' then
            exit;
        if Emp.Get(CodEmpleado) then begin
            CodConvenio := Emp."Cód. Convenio";
            CodCategoria := Emp."Cód. Categoría";
        end;
        if (CodProyecto <> '') and PersProy.Get(CodEmpleado, CodProyecto) then begin
            CodConvenio := PersProy."Cód. Convenio";
            CodCategoria := PersProy."Cód. Categoría";
        end;
    end;

    // Recarga cuando ya hay datos suficientes. Centraliza lo que repetía cada campo del grupo
    // Contexto, y suma el push al editor: sin él, el IntelliSense seguía ofreciendo los valores del
    // contexto anterior después de cambiar de empleado o período.
    local procedure RecargarSiHayContexto()
    begin
        if (CodEmpleado = '') or (CodPeriodo = '') then
            exit;
        CurrPage.Variables.Page.LimpiarFiltro();
        DoCargarContextoCompleto();
        PushEstadoAlEditor();
        CurrPage.Update(false);
    end;

    local procedure DoCargarContextoCompleto()
    var
        CtxBuilder: Codeunit "Contexto Liquidación";
        Periodo: Record "Período Liquidación";
        Job: Record Job;
        TipoLiqRec: Record "Tipo Liquidación";
        Ctx: Dictionary of [Text, Decimal];
        TipoMap: Dictionary of [Text, Text];
        FechaRef: Date;
    begin
        if CodEmpleado = '' then begin
            Message('Ingresá un No. Empleado para cargar el contexto completo.');
            exit;
        end;
        if CodPeriodo = '' then begin
            Message('Ingresá un Período para cargar el contexto completo.');
            exit;
        end;
        if not Periodo.Get(CodPeriodo) then begin
            Message('El período %1 no existe.', CodPeriodo);
            exit;
        end;

        // Mirrors LiquidarRecord (Cod50014): monthly types settle at period end; a type flagged
        // "Liquida al Arribo" (Cierre Marea) settles at the project's arrival date instead. Without
        // No. Proyecto, marea-dependent variables (DIAS_PROYECTO, DIAS_PUERTO, DIAS_ENROLAMIENTO,
        // Fuentes de Datos filtradas por {JOB_NO}) always resolved to 0 — this is what fixes that.
        FechaRef := Periodo."Fecha Hasta";
        if (CodProyecto <> '') and TipoLiqRec.EsArribo(TipoLiqCtx) and Job.Get(CodProyecto) and (Job."Ending Date" <> 0D) then
            FechaRef := Job."Ending Date";

        CtxBuilder.Init(CodEmpleado, CodProyecto, CodPeriodo, FechaRef, CodConvenio, CodCategoria, '', TipoLiqCtx);
        CtxBuilder.BuildContext(Ctx);
        CtxBuilder.GetTipoMap(TipoMap);
        CurrPage.Variables.Page.LoadFromContext(Ctx, TipoMap);
    end;

    local procedure EvaluarFormula()
    var
        Evaluador: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        ImporteResult: Decimal;
        CondResult: Boolean;
    begin
        ResultadoImporte := 0;
        CondicionActiva := false;
        MensajeResultado := '';
        StyleResultado := 'Subordinate';
        StyleMensaje := '';

        if FormulaText.Trim() = '' then begin
            MensajeResultado := 'Ingresá una fórmula.';
            StyleMensaje := 'Attention';
            exit;
        end;

        CurrPage.Variables.Page.GetContext(Ctx);
        Evaluador.Init(Ctx, WorkDate());

        if CondicionText.Trim() <> '' then begin
            if not Evaluador.TryEvalCondicion(CondicionText, CondResult) then begin
                MensajeResultado := 'Error en condición: ' + GetLastErrorText();
                StyleMensaje := 'Unfavorable';
                exit;
            end;
            CondicionActiva := CondResult;
        end else
            CondicionActiva := true;

        if not Evaluador.TryEvalFormula(FormulaText, ImporteResult) then begin
            MensajeResultado := GetLastErrorText();
            StyleMensaje := 'Unfavorable';
            StyleFormula := 'Unfavorable';
            exit;
        end;

        ResultadoImporte := ImporteResult;
        MensajeResultado := 'Sin errores.';
        StyleResultado := 'Favorable';
        StyleMensaje := 'Favorable';
        StyleFormula := 'Favorable';
    end;

    local procedure ValidarSintaxis(Formula: Text; var StyleExprVar: Text[50])
    var
        Evaluador: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Dummy: Decimal;
    begin
        if Formula.Trim() = '' then begin
            StyleExprVar := '';
            exit;
        end;
        CurrPage.Variables.Page.GetContext(Ctx);
        if Ctx.Count = 0 then exit; // no variables loaded yet — skip
        Evaluador.Init(Ctx, WorkDate());
        if Evaluador.TryEvalFormula(Formula, Dummy) then
            StyleExprVar := 'Favorable'
        else
            StyleExprVar := 'Unfavorable';
    end;

    local procedure ValidarSintaxisCondicion(Condicion: Text; var StyleExprVar: Text[50])
    var
        Evaluador: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Dummy: Boolean;
    begin
        if Condicion.Trim() = '' then begin
            StyleExprVar := '';
            exit;
        end;
        CurrPage.Variables.Page.GetContext(Ctx);
        if Ctx.Count = 0 then exit;
        Evaluador.Init(Ctx, WorkDate());
        if Evaluador.TryEvalCondicion(Condicion, Dummy) then
            StyleExprVar := 'Favorable'
        else
            StyleExprVar := 'Unfavorable';
    end;

    // ── Auto-complete ─────────────────────────────────────────────────────────

    local procedure DoAutoCompletar()
    var
        Prefix: Text;
        Matches: List of [Text];
        Selected: Text;
    begin
        Prefix := GetLastPartialWord(FormulaText);
        BuildMatches(Prefix, Matches);

        case Matches.Count of
            0:
                if Prefix <> '' then
                    Message('No hay coincidencias para "%1".', Prefix)
                else
                    Message('Posicioná el cursor al final de una palabra parcial antes de auto-completar.');
            1:
                begin
                    Selected := Matches.Get(1);
                    ReplaceLastWord(FormulaText, Selected);
                    ValidarSintaxis(FormulaText, StyleFormula);
                end;
            else begin
                if PickFromList(Matches, Selected) then begin
                    ReplaceLastWord(FormulaText, Selected);
                    ValidarSintaxis(FormulaText, StyleFormula);
                end;
            end;
        end;
    end;

    local procedure GetLastPartialWord(FullText: Text): Text
    var
        Upper: Text;
        i: Integer;
        C: Char;
        Word: Text;
    begin
        Upper := FullText.ToUpper();
        i := StrLen(Upper);
        while i >= 1 do begin
            C := Upper[i];
            if ((C >= 'A') and (C <= 'Z')) or ((C >= '0') and (C <= '9')) or (C = '_') then begin
                Word := CopyStr(Upper, i, 1) + Word;
                i -= 1;
            end else
                break;
        end;
        exit(Word);
    end;

    local procedure ReplaceLastWord(var FullText: Text[500]; NewWord: Text)
    var
        Partial: Text;
        PrefixLen: Integer;
    begin
        Partial := GetLastPartialWord(FullText);
        PrefixLen := StrLen(FullText) - StrLen(Partial);
        FullText := CopyStr(FullText, 1, PrefixLen) + NewWord;
    end;

    local procedure BuildMatches(Prefix: Text; var Matches: List of [Text])
    var
        Catalogo: Codeunit "Catálogo Variables Liq.";
        Ctx: Dictionary of [Text, Decimal];
        Keys: List of [Text];
        CtxKey: Text;
        Nombre: Text;
    begin
        // Las funciones salen del catálogo, no de una lista escrita acá: cuando estaban duplicadas,
        // REDONDEAR, PISO y TECHO existían en el motor pero no aparecían en el auto-completar.
        foreach Nombre in Catalogo.GetNombresFunciones() do
            AddIfMatch(Nombre, Prefix, Matches);
        foreach Nombre in Catalogo.GetNombresOperadores() do
            AddIfMatch(Nombre, Prefix, Matches);

        // Variables from test context
        CurrPage.Variables.Page.GetContext(Ctx);
        Keys := Ctx.Keys();
        foreach CtxKey in Keys do
            AddIfMatch(CtxKey, Prefix, Matches);
    end;

    local procedure AddIfMatch(Candidate: Text; Prefix: Text; var Matches: List of [Text])
    begin
        if (Prefix = '') or Candidate.StartsWith(Prefix) then
            if not Matches.Contains(Candidate) then
                Matches.Add(Candidate);
    end;

    local procedure PickFromList(var Options: List of [Text]; var Selected: Text): Boolean
    var
        MenuStr: Text;
        i: Integer;
        Idx: Integer;
    begin
        for i := 1 to Options.Count do begin
            if i > 1 then MenuStr += ',';
            MenuStr += Options.Get(i);
        end;
        Idx := StrMenu(MenuStr, 1, 'Seleccioná una variable o función:');
        if Idx = 0 then exit(false);
        Selected := Options.Get(Idx);
        exit(true);
    end;

    // ── Helpers ───────────────────────────────────────────────────────────────

    local procedure SetVar(VarNombre: Text[100]; VarValor: Decimal; VarDesc: Text[100]; VarTipo: Text[20])
    begin
        CurrPage.Variables.Page.SetVariable(VarNombre, VarValor, VarDesc, VarTipo);
    end;

    local procedure InsertText(Token: Text)
    begin
        if FormulaText <> '' then
            FormulaText += ' ';
        FormulaText += CopyStr(Token, 1, MaxStrLen(FormulaText) - StrLen(FormulaText));
        ValidarSintaxis(FormulaText, StyleFormula);
        PushEstadoAlEditor();
        CurrPage.Update(false);
    end;

    var
        CampoFormulaTok: Label 'formula', Locked = true;
        CampoCondicionTok: Label 'condicion', Locked = true;
        SinContextoMsg: Label 'Cargá el catálogo o el contexto para validar.';

}
