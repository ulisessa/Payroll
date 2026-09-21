namespace UAS.Payroll;

page 50145 "Concepto Liq. Card"
{
    ApplicationArea = All;
    Caption = 'Concepto Liquidación';
    PageType = Card;
    SourceTable = "Concepto Liquidación";

    layout
    {
        area(Content)
        {
            group(GrpGeneral)
            {
                Caption = 'General';
                field(Código; Rec.Código) { ApplicationArea = All; }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field("Vigencia Hasta"; Rec."Vigencia Hasta")
                {
                    ApplicationArea = All;
                    ToolTip = 'Último día en que esta versión se aplica. En blanco = vigencia abierta. Cargar una fecha da de baja el concepto desde ese día sin alterar lo ya liquidado.';
                }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Nombre Impresión"; Rec."Nombre Impresión") { ApplicationArea = All; }
                field("Variable Cantidad"; Rec."Variable Cantidad")
                {
                    ApplicationArea = All;
                    ToolTip = 'La cantidad que se imprime junto al importe en el recibo. Acepta el nombre de una variable (DIAS_VAC, TONELADAS) o una expresión (PCT_ANTIG_SOMU*100). No cambia lo que se paga: es lo que se muestra.';
                }
                field("Unidad Cantidad"; Rec."Unidad Cantidad")
                {
                    ApplicationArea = All;
                    ToolTip = 'Texto de la unidad (ej: días, tn). Acompaña la cantidad en el recibo.';
                }
                field("Variable Base"; Rec."Variable Base")
                {
                    ApplicationArea = All;
                    ToolTip = 'El valor que se muestra como Base de cálculo en el recibo. Acepta el nombre de una variable (BASICO, REMUNERATIVO) o una expresión (DIAS_PROYECTO+DIAS_PUERTO). No cambia lo que se paga: es lo que se muestra.';
                }
                field("Tipo Concepto"; Rec."Tipo Concepto")
                {
                    ApplicationArea = All;
                    StyleExpr = TipoStyle;
                }
                field("Grupo Costo Laboral"; Rec."Grupo Costo Laboral")
                {
                    ApplicationArea = All;
                    ToolTip = 'Rubro del costo laboral al que pertenece este concepto (Sindical, Seguridad Social, Obra Social, INSSJP, ART, SCVO). Se usa para el detalle de composición del costo laboral en el recibo de sueldo.';
                }
                field("Aplica A"; Rec."Aplica A") { ApplicationArea = All; }
                field("Par CCT a Usar"; Rec."Par CCT a Usar")
                {
                    ApplicationArea = All;
                    Caption = 'Convenio/Categoría a usar';
                    ToolTip = 'Con qué par se resuelven los parámetros de este concepto. Por defecto, el del empleado (sus atributos). Con "el de la asignación al proyecto", este concepto —y solo este— se calcula con el convenio y la categoría con los que el empleado está asignado al proyecto de la liquidación: es lo que corresponde a lo que se paga por el embarque y no por el encuadre.';
                }
                field("Tipos Liq. Aplicables"; Rec."Tipos Liq. Aplicables")
                {
                    ApplicationArea = All;
                    ToolTip = 'Tipos de liquidación a los que aplica este concepto. Vacío = todos los tipos.';
                    Editable = false;

                    trigger OnAssistEdit()
                    var
                        Selector: Page "Selector Tipos Liq.";
                    begin
                        Selector.SetSeleccion(Rec."Tipos Liq. Aplicables");
                        Selector.RunModal();
                        if Selector.Confirmado() then begin
                            Rec."Tipos Liq. Aplicables" := Selector.GetSeleccion();
                            CurrPage.Update(true);
                        end;
                    end;
                }
                field("Orden Cálculo"; Rec."Orden Cálculo") { ApplicationArea = All; }
                // "Activo" ya no se muestra: dejó de tener efecto en el cálculo y verlo en No sobre
                // un concepto que igual se liquida es peor que no verlo. La baja va por "Vigencia
                // Hasta"; las versiones que quedaron en false se revisan desde su propia página.
                field("Es Acumulador"; Rec."Es Acumulador") { ApplicationArea = All; }
                field("Etiqueta Det. Ganancias"; Rec."Etiqueta Det. Ganancias")
                {
                    ApplicationArea = All;
                    ToolTip = 'Si se completa, el resultado de este concepto aparece como un paso de cálculo en el detalle de Ganancias del recibo de sueldo.';
                }
                field("Imprime en Recibo"; Rec."Imprime en Recibo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Si está desactivado, el concepto no aparece en el recibo de sueldo aunque tenga importe. Por defecto activo (imprime).';
                }
                field("Es Devengo"; Rec."Es Devengo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Marca el concepto como devengado. Los conceptos devengados se calculan pero no se incluyen en los totales del recibo ni afectan el neto a pagar.';
                }
                field("Rol Franco"; Rec."Rol Franco")
                {
                    ApplicationArea = All;
                    ToolTip = 'Rol del concepto en el ledger FIFO de francos. Devengo: acumula días de franco (usar con Es Devengo). Consumo: paga francos disfrutados (importe = PAGO_FRANCOS_FIFO, valuado por la categoría de cada lote).';
                }
                field("Cód. Tipo Atributo Detalle"; Rec."Cód. Tipo Atributo Detalle")
                {
                    ApplicationArea = All;
                    ToolTip = 'Qué atributo del empleado explica esta línea. Cargado, la liquidación muestra al lado del importe la descripción del valor que el empleado tenía en ese atributo a esa fecha: en la cuota sindical, el gremio; en el aporte de obra social, la obra social. No interviene en el cálculo.';
                }
            }
            group(GrpFormula)
            {
                Caption = 'Fórmula y Condición';

                // Mismo editor que el Asistente de Fórmulas: autocompletado, ayuda de firma y
                // diagnóstico en vivo sin salir de la ficha. El asistente sigue existiendo para
                // probar contra un empleado y período reales; acá los valores son orientativos.
                usercontrol(Editor; "Editor Fórmula Liq.")
                {
                    ApplicationArea = All;

                    trigger ControlAddInReady()
                    begin
                        // Sin CurrPage.Update() acá, y esa ausencia es el punto. Refrescar la página
                        // desde adentro de un evento del propio add-in hace que BC destruya el control
                        // y lo vuelva a crear; el que nace de esa recreación no siempre vuelve a avisar
                        // que está listo. Cuando no avisa queda lo peor de los dos mundos: un recuadro
                        // en blanco, el texto plano ya escondido porque el flag quedó en true, y la
                        // ficha empujándole fórmula y catálogo a un control que no existe. Es la
                        // explicación más probable de los blancos intermitentes, y era autoinfligida.
                        //
                        // El precio de no refrescar: el grupo 'Texto plano' se sigue viendo hasta el
                        // próximo redibujo natural de la ficha. Barato — es un fallback útil, no un
                        // estorbo, y desaparece solo en cuanto el usuario toca cualquier otra cosa.
                        FEditorListo := true;
                        FTextoPlanoVisible := false;
                        PushEstadoAlEditor();
                    end;

                    // Sin CurrPage.Update(): redibujar mientras se escribe le saca el foco y el
                    // cursor al usuario. La devolución va por SetDiagnostico, que el editor pinta en
                    // su propia barra.
                    trigger OnTextoCambiado(Campo: Text; Texto: Text)
                    begin
                        GuardarTextoDeEditor(Campo, Texto);
                        EnviarDiagnostico(Campo);
                    end;
                }
            }
            group(GrpTextoPlano)
            {
                Caption = 'Texto plano';
                Visible = FTextoPlanoVisible;

                field(Fórmula; Rec.Fórmula)
                {
                    ApplicationArea = All;
                    MultiLine = true;
                    ToolTip = 'La misma fórmula como campo de texto común, para copiar y pegar o para seguir trabajando si el editor con IntelliSense no cargara.';

                    trigger OnValidate()
                    begin
                        PushEstadoAlEditor();
                    end;
                }
                field(Condición; Rec.Condición)
                {
                    ApplicationArea = All;
                    MultiLine = true;
                    ToolTip = 'Expresión booleana. Vacía = el concepto siempre aplica.';

                    trigger OnValidate()
                    begin
                        PushEstadoAlEditor();
                    end;
                }
            }
            part(Fracciones; "Fracción Acumulador Sub")
            {
                ApplicationArea = All;
                Caption = 'Distribución en acumuladores — todas las vigencias';
                // A propósito NO se filtra por "Vigencia Desde" del concepto, igual que la subpágina
                // de convenios: la distribución se versiona por separado y el motor elige la última
                // Vigencia Desde <= fecha de liquidación (ver BuildFractionCache). Filtrando por
                // fecha exacta, crear una vigencia nueva del concepto mostraba la distribución vacía
                // mientras el motor seguía aplicando la anterior. La columna "Vigente" marca cuál
                // rige para esta versión.
                SubPageLink = "Cód. Concepto" = FIELD(Código);
                Visible = not Rec."Es Acumulador";
            }
            part(Alimentadores; "Alimentadores Acumulador Sub")
            {
                ApplicationArea = All;
                Caption = 'Conceptos que alimentan este acumulador';
                SubPageLink = "Cód. Acumulador" = FIELD(Código);
                Visible = Rec."Es Acumulador";
            }
            part(ConveniosCCT; "Concepto CCT Sub")
            {
                ApplicationArea = All;
                Caption = 'Convenios aplicables (vacío = todos) — todas las vigencias';
                // A propósito NO se filtra por "Vigencia Desde" del concepto: las restricciones CCT
                // se versionan por separado, y el motor elige el lote con la Vigencia Desde más
                // reciente <= fecha de la liquidación (ver CCTAplicaAConcepto). Si acá se filtrara
                // por la vigencia del concepto, un lote CCT más nuevo — que es el que realmente
                // manda — quedaría invisible, y el concepto parecería aplicar a convenios que en
                // realidad ya no aplica.
                SubPageLink = "Cód. Concepto" = FIELD(Código);
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(FormatearFormula)
            {
                ApplicationArea = All;
                Caption = 'Formatear';
                Image = Splitlines;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Reescribe la fórmula y la condición en su forma canónica: sangría y saltos de línea donde no entran en el ancho. No cambia lo que calculan. De paso las parsea y avisa si alguna tiene un error de sintaxis.';

                trigger OnAction()
                var
                    Formateador: Codeunit "Formateador Fórmula Liq.";
                    HistorialMgt: Codeunit "Historial Fórmulas Liq.";
                    FormulaAnterior: Text;
                    CondicionAnterior: Text;
                    NuevaFormula: Text;
                    NuevaCondicion: Text;
                    Problema: Text;
                begin
                    Rec.TestField(Código);
                    // Primero se guarda lo que el usuario tenga a medio editar en la ficha, por el
                    // camino normal. Si no, el Modify de más abajo escribe la fila por detrás de esos
                    // cambios pendientes y BC corta el guardado siguiente con "hay información que no
                    // está actualizada" — que obliga a cerrar la ficha y perder lo que estaba escrito.
                    CurrPage.SaveRecord();
                    // El control de sintaxis va SIEMPRE, no sólo cuando el formateo no cambia nada.
                    // Antes vivía adentro de esa rama, y con la fórmula rota y la condición
                    // reformateable se salía por la otra: formateaba, guardaba y no decía una
                    // palabra. El formateador tampoco es el que tiene que dictaminar —"Reconoce"
                    // dice QUE no entendió, no QUÉ está mal—, así que el diagnóstico lo da el
                    // evaluador, que es el mismo que después va a fallar el cálculo.
                    Problema := ErrorDeSintaxis();

                    NuevaFormula := Formateador.Formatear(Rec.Fórmula);
                    NuevaCondicion := Formateador.Formatear(Rec.Condición);
                    if (NuevaFormula = Rec.Fórmula) and (NuevaCondicion = Rec.Condición) then begin
                        // Que no cambie nada tiene tres causas, y cada mensaje dice una sola:
                        // hay un error de sintaxis; o está bien escrita pero el formateador no la
                        // maneja; o ya estaba en forma canónica y no había nada que hacer.
                        if Problema <> '' then
                            Message(MsgFormatoConError, Problema)
                        else
                            if Formateador.Reconoce(Rec.Fórmula) and Formateador.Reconoce(Rec.Condición) then
                                Message(MsgYaCanonica)
                            else
                                Message(MsgNoReconocida);
                        exit;
                    end;
                    FormulaAnterior := Rec.Fórmula;
                    CondicionAnterior := Rec.Condición;
                    Rec.Fórmula := CopyStr(NuevaFormula, 1, MaxStrLen(Rec.Fórmula));
                    Rec.Condición := CopyStr(NuevaCondicion, 1, MaxStrLen(Rec.Condición));
                    // Sin disparadores —pasar por OnModify lo registraría como Modificación, y decir
                    // que la fórmula cambió cuando no cambió es peor que no decir nada— pero el rastro
                    // se escribe igual, con su propio tipo.
                    Rec.Modify(false);
                    HistorialMgt.RegistrarFormato(Rec, FormulaAnterior, CondicionAnterior);
                    // Y se relee: Modify(false) mueve la fila en la base, pero la página se queda con
                    // la imagen que había leído. Sin esto, el desfasaje lo paga el próximo cambio de
                    // cualquier otro campo, que ya no se puede guardar.
                    Rec.Get(Rec.Código, Rec."Vigencia Desde");
                    PushEstadoAlEditor();
                    CurrPage.Update(false);

                    // Formateó bien, pero eso no dice nada de la sintaxis: el formateador deja
                    // intacto lo que no entiende, así que puede haber reordenado la condición y
                    // dejado la fórmula rota tal cual.
                    if Problema <> '' then
                        Message(MsgFormatoConError, Problema);
                end;
            }
            action(NuevaVigencia)

            {
                ApplicationArea = All;
                Caption = 'Nueva Vigencia';
                Image = NewRow;
                Promoted = true;
                PromotedCategory = New;
                ToolTip = 'Crea una nueva versión del concepto con la misma fórmula a partir de la fecha indicada. La versión anterior se conserva para el recálculo de períodos previos.';
                trigger OnAction()
                var
                    NuevoConcepto: Record "Concepto Liquidación";
                    DupCheck: Record "Concepto Liquidación";
                    Dlg: Page "Nueva Vigencia Dialog";
                    FechaNueva: Date;
                begin
                    Rec.TestField(Código);
                    Dlg.SetFecha(WorkDate());
                    if Dlg.RunModal() <> Action::OK then exit;
                    FechaNueva := Dlg.GetFecha();
                    if FechaNueva = 0D then exit;
                    if DupCheck.Get(Rec.Código, FechaNueva) then
                        Error(ErrVigenciaExiste, Rec.Código, FechaNueva);
                    NuevoConcepto := Rec;
                    NuevoConcepto."Vigencia Desde" := FechaNueva;
                    // La copia no puede arrastrar la fecha de fin de la versión que reemplaza: nace
                    // abierta, y es el insert el que cierra a la anterior contra este inicio.
                    NuevoConcepto."Vigencia Hasta" := 0D;
                    NuevoConcepto.Insert(true);
                    CurrPage.SetRecord(NuevoConcepto);
                    CurrPage.Update(false);
                end;
            }
            action(HistorialCambios)
            {
                ApplicationArea = All;
                Caption = 'Historial de Cambios';
                Image = ChangeLog;
                Promoted = true;
                PromotedCategory = Process;
                // Sin Enabled. Estaba atado a una bandera que se calcula al cargar la ficha, y el
                // guardado desde el editor no refresca la página a propósito —redibujar mientras se
                // escribe le saca el foco al usuario—. El resultado era que después de editar una
                // fórmula el botón seguía gris, y eso se lee como "el cambio no se registró" cuando
                // en realidad se registró: lo viejo era la bandera, no el dato.
                //
                // Abrir la pantalla y encontrarla vacía dice lo mismo con menos ambigüedad.
                ToolTip = 'Quién cambió la fórmula o la condición de este concepto, cuándo, y de qué texto a qué texto. Permite además restaurar una versión anterior.';

                trigger OnAction()
                var
                    Historial: Record "Historial Fórmula Concepto";
                begin
                    Rec.TestField(Código);
                    Historial.SetCurrentKey("Cód. Concepto", "Vigencia Desde", "Fecha Hora");
                    Historial.SetRange("Cód. Concepto", Rec.Código);
                    Page.Run(Page::"Historial Fórmulas Concepto", Historial);
                end;
            }
            action(HistorialFórmulas)
            {
                ApplicationArea = All;
                Caption = 'Vigencias del Concepto';
                Image = History;
                ToolTip = 'Muestra todas las versiones vigentes de este concepto con su fórmula y su fecha de vigencia. Es el versionado por fecha, no el historial de quién editó qué — para eso está "Historial de Cambios".';
                trigger OnAction()
                var
                    Historial: Record "Concepto Liquidación";
                    HistorialPage: Page "Conceptos Liquidación";
                begin
                    Rec.TestField(Código);
                    Historial.SetRange(Código, Rec.Código);
                    HistorialPage.SetTableView(Historial);
                    HistorialPage.Run();
                end;
            }
            action(AsistenteFórmula)
            {
                ApplicationArea = All;
                Caption = 'Asistente de Formulación';
                Image = PreviewChecks;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Abre el Asistente de Fórmulas con la Fórmula y Condición actuales. "Aplicar y Cerrar" en el asistente vuelca los cambios acá; cerrarlo de otra forma no modifica el concepto.';
                trigger OnAction()
                var
                    Asistente: Page "Asistente Fórmula Liq.";
                    NuevaFormula: Text[2048];
                    NuevaCondicion: Text[2048];
                begin
                    Asistente.SetFormula(Rec.Fórmula, Rec.Condición);
                    Asistente.SetOrigenConcepto();
                    Asistente.RunModal();
                    if Asistente.Confirmado() then begin
                        Asistente.GetFormula(NuevaFormula, NuevaCondicion);
                        Rec.Fórmula := NuevaFormula;
                        Rec.Condición := NuevaCondicion;
                        Rec.Modify(true);
                        PushEstadoAlEditor();
                        CurrPage.Update(false);
                    end;
                end;
            }
            action(ReiniciarEditor)
            {
                ApplicationArea = All;
                Caption = 'Reiniciar editor';
                Image = Restore;
                ToolTip = 'Cuando el editor aparece en blanco: devuelve los campos de texto plano para poder seguir trabajando ya, y le pide a BC que vuelva a armar el control. Si después de esto sigue vacío, el problema está en los archivos del add-in y hay que recargar con Ctrl+F5, que saltea el caché del navegador.';

                trigger OnAction()
                begin
                    // Lo que hay que deshacer es el 'ya está listo'. Mientras ese flag siga en true la
                    // ficha esconde el texto plano y le manda el estado a un control que puede no
                    // existir, así que el usuario se queda sin editor Y sin alternativa. Bajarlo
                    // devuelve la alternativa con certeza; que además BC reconstruya el add-in es
                    // probable, no seguro, y por eso el fallback va primero.
                    FEditorListo := false;
                    FTextoPlanoVisible := true;
                    CurrPage.Update(false);
                end;
            }
            action(VerTextoPlano)
            {
                ApplicationArea = All;
                Caption = 'Ver texto plano';
                Image = Text;
                ToolTip = 'Muestra la Fórmula y la Condición como campos de texto comunes, para copiar y pegar o para seguir trabajando si el editor con IntelliSense no cargara.';

                trigger OnAction()
                begin
                    FTextoPlanoVisible := not FTextoPlanoVisible;
                    CurrPage.Update(false);
                end;
            }
            action(Copiar)
            {
                ApplicationArea = All;
                Caption = 'Copiar como...';
                Image = Copy;
                Promoted = true;
                PromotedCategory = Process;
                trigger OnAction()
                var
                    Dlg: Page "Nuevo Codigo Dialog";
                    NuevoCodigo: Code[20];
                begin
                    Dlg.SetCodigo(CopyStr(Rec.Código + '_2', 1, 100));
                    if Dlg.RunModal() <> Action::OK then exit;
                    NuevoCodigo := CopyStr(Dlg.GetCodigo(), 1, 20);
                    if NuevoCodigo = '' then exit;
                    Rec.CopiarEn(NuevoCodigo);
                    Message(MsgCopiado, NuevoCodigo);
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        // Visible hasta que el editor con IntelliSense diga que arrancó. Es al revés de como estaba
        // —oculto por defecto— y el motivo es que el add-in a veces no carga: antes eso dejaba la
        // ficha sin ninguna forma de editar la fórmula hasta descubrir la acción del menú.
        FTextoPlanoVisible := true;
    end;

    /// <remarks>
    /// El control de sintaxis del campo (OnValidate en Concepto Liquidación) NO corre por el camino
    /// del editor: el add-in guarda con asignación directa y Modify, que dispara el trigger de la
    /// tabla y no el del campo. Y tiene que ser así — el editor emite mientras se tipea, con medio
    /// segundo de debounce, y un error duro ahí reventaría la ficha en la mitad de cada fórmula.
    ///
    /// El precio de eso era que una fórmula rota se guardaba igual y no la miraba nadie hasta que
    /// fallaba una liquidación, con el concepto ya versionado y en producción. Acá es el momento en
    /// que sí se puede preguntar: el usuario terminó de escribir.
    ///
    /// Pregunta y no corta: bloquear la salida deja a alguien encerrado en una ficha que quizás
    /// abrió para mirar otra cosa. Lo que no puede pasar es que se vaya sin enterarse.
    /// </remarks>
    trigger OnQueryClosePage(CloseAction: Action): Boolean
    var
        Problema: Text;
    begin
        Problema := ErrorDeSintaxis();
        if Problema = '' then
            exit(true);
        exit(Confirm(QstSalirConError, false, Rec.Código, Problema));
    end;

    /// <summary>El error de sintaxis de la fórmula o la condición del concepto abierto, o vacío.</summary>
    /// <remarks>
    /// Solo la pasada de SINTAXIS, la misma que el OnValidate hace primero: una variable que todavía
    /// no existe es una advertencia legítima mientras se configura —el parámetro puede cargarse
    /// después— pero un paréntesis sin cerrar no se arregla solo nunca.
    /// </remarks>
    local procedure ErrorDeSintaxis(): Text
    var
        Eval: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Dummy: Decimal;
        DummyBool: Boolean;
    begin
        if Rec.Código = '' then
            exit('');

        if Rec.Fórmula <> '' then begin
            Eval.Init(Ctx, Today());
            Eval.SetLenientMode(true);
            if not Eval.TryEvalFormula(Rec.Fórmula, Dummy) then
                exit(StrSubstNo(TxtErrEnFormula, GetLastErrorText()));
        end;

        if Rec.Condición <> '' then begin
            Eval.Init(Ctx, Today());
            Eval.SetLenientMode(true);
            if not Eval.TryEvalCondicion(Rec.Condición, DummyBool) then
                exit(StrSubstNo(TxtErrEnCondicion, GetLastErrorText()));
        end;

        exit('');
    end;

    trigger OnAfterGetRecord()
    begin
        // Al moverse entre conceptos hay que reenviarle al editor la fórmula del nuevo registro; si
        // no, sigue mostrando la del anterior.
        PushEstadoAlEditor();
        // La subpágina necesita el INTERVALO de esta versión, no solo su inicio: mientras la versión
        // siga abierta, la distribución que rige es la última cargada, aunque sea muy posterior.
        if not Rec."Es Acumulador" then
            CurrPage.Fracciones.Page.SetContexto(Rec.Código, Rec."Vigencia Desde", Rec."Vigencia Hasta");

        case Rec."Tipo Concepto" of
            Rec."Tipo Concepto"::"Haber Remunerativo":
                TipoStyle := 'Favorable';
            Rec."Tipo Concepto"::"Haber No Remunerativo":
                TipoStyle := 'Subordinate';
            Rec."Tipo Concepto"::"Descuento Empleado",
            Rec."Tipo Concepto"::Retención:
                TipoStyle := 'Unfavorable';
            Rec."Tipo Concepto"::"Contribución Patronal":
                TipoStyle := 'Attention';
        end;
    end;

    // El historial arranca vacío para todo concepto anterior a que existiera el registro de cambios,
    // así que el botón llevaría a una lista en blanco. IsEmpty y no Count: solo interesa si hay al
    // menos una fila, y esto corre en cada refresco de la ficha.
    // ── Editor con IntelliSense ───────────────────────────────────────────────

    // El catálogo se arma una sola vez por instancia de página: es el mismo para todos los conceptos
    // y recorrerlo entero en cada OnAfterGetRecord (que corre en cada refresco) sería leer las
    // tablas de configuración completas para no cambiar nada.
    var
        MsgYaCanonica: Label 'La fórmula ya está en su forma canónica: no hay nada que reacomodar.';
        QstSalirConError: Label 'La fórmula del concepto %1 tiene un error de sintaxis y NO se va a poder calcular:\%2\Se guardó igual. ¿Salir de todos modos?', Comment = '%1=código de concepto, %2=el error';
        TxtErrEnFormula: Label 'En la fórmula: %1', Comment = '%1=mensaje del evaluador';
        TxtErrEnCondicion: Label 'En la condición: %1', Comment = '%1=mensaje del evaluador';
        MsgFormatoConError: Label 'Ojo: este concepto NO se va a poder calcular.\%1\El formato se aplicó igual; corregí el texto y volvé a formatear.', Comment = '%1=el error del evaluador';
        MsgNoReconocida: Label 'La fórmula quedó como estaba: tiene algo que el formateador no reconoce —un paréntesis sin cerrar, una comilla sin cerrar o un carácter raro— y ante la duda no la tocó. Revisala en el editor, que marca en rojo lo que no entiende.';

    local procedure PushEstadoAlEditor()
    var
        Catalogo: Codeunit "Catálogo Variables Liq.";
    begin
        if not FEditorListo then
            exit;
        if FCatalogoJson = '' then
            FCatalogoJson := Catalogo.BuildCatalogoCompletoJson('', '', '');
        CurrPage.Editor.SetCatalogo(FCatalogoJson);
        CurrPage.Editor.SetValores(Rec.Fórmula, Rec.Condición);
        EnviarDiagnostico(CampoFormulaTok);
        EnviarDiagnostico(CampoCondicionTok);
    end;

    local procedure GuardarTextoDeEditor(Campo: Text; Texto: Text)
    var
        Formateador: Codeunit "Formateador Fórmula Liq.";
    begin
        // Este camino asigna el campo DIRECTO —sin Validate— así que el formateo del OnValidate de la
        // tabla no corre. Va acá, o el editor con IntelliSense sería la única vía por la que una
        // fórmula se guardaría sin forma canónica, justo la que más se usa.
        //
        // No se devuelve el texto formateado al editor mientras se escribe: reacomodar los renglones
        // debajo del cursor es de las cosas más molestas que puede hacer un editor. Se ve formateado
        // al volver a abrir la ficha, que es como se comporta cualquier formateador al guardar.
        Texto := Formateador.Formatear(Texto);
        if Campo = CampoCondicionTok then begin
            if Rec.Condición = CopyStr(Texto, 1, MaxStrLen(Rec.Condición)) then
                exit;
            Rec.Condición := CopyStr(Texto, 1, MaxStrLen(Rec.Condición));
        end else begin
            if Rec.Fórmula = CopyStr(Texto, 1, MaxStrLen(Rec.Fórmula)) then
                exit;
            Rec.Fórmula := CopyStr(Texto, 1, MaxStrLen(Rec.Fórmula));
        end;

        // El add-in es un control más de la ficha y puede recibir texto antes de que el registro
        // exista en la base (alta recién empezada). Modify ahí sería un error duro en medio del
        // tipeo: se guarda en cuanto el concepto esté insertado.
        if not RegistroGuardado() then
            exit;
        Rec.Modify(true);
    end;

    local procedure RegistroGuardado(): Boolean
    var
        Existente: Record "Concepto Liquidación";
    begin
        if Rec.Código = '' then
            exit(false);
        exit(Existente.Get(Rec.Código, Rec."Vigencia Desde"));
    end;

    // Evalúa contra el catálogo y devuelve resultado o error al editor, que lo muestra en su barra
    // inferior. Llega con debounce desde el navegador, no en cada tecla.
    local procedure EnviarDiagnostico(Campo: Text)
    var
        Evaluador: Codeunit "Evaluador Fórmula";
        Diag: JsonObject;
        Texto: Text;
        Json: Text;
        ValorDec: Decimal;
        ValorBool: Boolean;
    begin
        if not FEditorListo then
            exit;

        if Campo = CampoCondicionTok then
            Texto := Rec.Condición
        else
            Texto := Rec.Fórmula;

        Diag.Add('campo', Campo);
        if Texto.Trim() = '' then
            AgregarDiag(Diag, 'neutro', '', '')
        else begin
            AsegurarContexto();
            Evaluador.Init(FCtxCatalogo, WorkDate());
            if Campo = CampoCondicionTok then begin
                if Evaluador.TryEvalCondicion(Texto, ValorBool) then
                    AgregarDiag(Diag, 'ok', ValoresOrientativosMsg, Format(ValorBool))
                else
                    AgregarDiag(Diag, 'error', GetLastErrorText(), '');
            end else
                if Evaluador.TryEvalFormula(Texto, ValorDec) then
                    AgregarDiag(Diag, 'ok', ValoresOrientativosMsg, Format(ValorDec, 0, '<Precision,2:6><Standard Format,0>'))
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

    // El contexto de evaluación es el mismo para todos los conceptos, y el diagnóstico se pide dos
    // veces por refresco (fórmula y condición). Sin cachearlo, cada movimiento entre conceptos
    // releería entera la configuración de parámetros, variables y fuentes de datos.
    local procedure AsegurarContexto()
    var
        Catalogo: Codeunit "Catálogo Variables Liq.";
    begin
        if FCtxCargado then
            exit;
        Catalogo.BuildContextoCatalogo('', '', '', FCtxCatalogo);
        FCtxCargado := true;
    end;

    var
        TipoStyle: Text;
        FEditorListo: Boolean;
        FTextoPlanoVisible: Boolean;
        FCatalogoJson: Text;
        FCtxCatalogo: Dictionary of [Text, Decimal];
        FCtxCargado: Boolean;
        ErrVigenciaExiste: Label 'Ya existe una vigencia del concepto %1 con fecha %2. Insertá manualmente la nueva versión con otra fecha.';
        MsgCopiado: Label 'Concepto copiado como ''%1''.';
        CampoFormulaTok: Label 'formula', Locked = true;
        CampoCondicionTok: Label 'condicion', Locked = true;
        ValoresOrientativosMsg: Label 'Valor orientativo: los parámetros valen su vigente y el resto 0. Usá el Asistente para probar con un empleado y período reales.';
}
