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
                    ToolTip = 'Variable del contexto que representa la cantidad (ej: DIAS_VAC, TONELADAS). Se imprime junto al importe en el recibo.';
                }
                field("Unidad Cantidad"; Rec."Unidad Cantidad")
                {
                    ApplicationArea = All;
                    ToolTip = 'Texto de la unidad (ej: días, tn). Acompaña la cantidad en el recibo.';
                }
                field("Variable Base"; Rec."Variable Base")
                {
                    ApplicationArea = All;
                    ToolTip = 'Variable del contexto cuyo valor se muestra como Base de cálculo en el recibo (ej: SUELDO_BASICO, REMUNERATIVO).';
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
                field(Activo; Rec.Activo) { ApplicationArea = All; }
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
                        FEditorListo := true;
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
                Enabled = TieneHistorial;
                ToolTip = 'Quién cambió la fórmula o la condición de este concepto, cuándo, y de qué texto a qué texto. Permite además restaurar una versión anterior. Se habilita cuando el concepto tiene al menos un cambio registrado.';

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

    trigger OnAfterGetRecord()
    begin
        // Al moverse entre conceptos hay que reenviarle al editor la fórmula del nuevo registro; si
        // no, sigue mostrando la del anterior.
        PushEstadoAlEditor();
        TieneHistorial := HayHistorialDeCambios();
        // La subpágina necesita saber contra qué fecha evaluar qué distribución rige, y eso cambia
        // al moverse entre vigencias del concepto.
        if not Rec."Es Acumulador" then
            CurrPage.Fracciones.Page.SetContexto(Rec.Código, Rec."Vigencia Desde");

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
    local procedure HayHistorialDeCambios(): Boolean
    var
        Historial: Record "Historial Fórmula Concepto";
    begin
        if Rec.Código = '' then
            exit(false);
        Historial.SetCurrentKey("Cód. Concepto", "Vigencia Desde", "Fecha Hora");
        Historial.SetRange("Cód. Concepto", Rec.Código);
        exit(not Historial.IsEmpty());
    end;

    // ── Editor con IntelliSense ───────────────────────────────────────────────

    // El catálogo se arma una sola vez por instancia de página: es el mismo para todos los conceptos
    // y recorrerlo entero en cada OnAfterGetRecord (que corre en cada refresco) sería leer las
    // tablas de configuración completas para no cambiar nada.
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
        CR: Char;
        LF: Char;
    begin
        // Se normaliza igual que NormalizarTexto en Tab60007 (saltos de línea → espacio): el motor
        // solo saltea el espacio simple, así que un salto de línea le daría "token inesperado".
        CR := 13;
        LF := 10;
        Texto := Texto.Replace('' + CR, ' ').Replace('' + LF, ' ');

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
        TieneHistorial: Boolean;
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
