namespace UAS.Payroll;

page 50014 "Control Orden Acumuladores"
{
    ApplicationArea = All;
    Caption = 'Control de Orden de Cálculo';
    PageType = List;
    UsageCategory = Administration;
    SourceTable = "Diag. Orden Acum. Buffer";
    SourceTableTemporary = true;
    // Los filtros son variables editables; sólo la grilla de diagnóstico es de lectura.
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(ConceptoEnRevision)
            {
                Caption = 'Vigencia en revisión';
                Visible = ModoConcepto;
                field(CodigoEnRevision; ConceptoRevision.Código)
                {
                    ApplicationArea = All;
                    Caption = 'Concepto';
                    Editable = false;
                }
                field(DesdeEnRevision; ConceptoRevision."Vigencia Desde")
                {
                    ApplicationArea = All;
                    Caption = 'Vigencia desde';
                    Editable = false;
                }
                field(HastaEnRevision; ConceptoRevision."Vigencia Hasta")
                {
                    ApplicationArea = All;
                    Caption = 'Vigencia hasta';
                    Editable = false;
                }
                field(AlcanceRevision; AlcanceRevision)
                {
                    ApplicationArea = All;
                    Caption = 'Alcance de la revisión';
                    Editable = false;
                    MultiLine = true;
                }
            }
            group(GrpFiltros)
            {
                ShowCaption = false;

                field(FechaRef; FechaRef)
                {
                    ApplicationArea = All;
                    Caption = 'Fecha de referencia';
                    ToolTip = 'Fecha con la que se resuelve qué vigencia de cada concepto está activa. Cambiala para verificar una configuración que entra a regir más adelante.';

                    trigger OnValidate()
                    begin
                        Analizar();
                    end;
                }
                field(ActualizarVigencia; ActualizarVigencia)
                {
                    ApplicationArea = All;
                    Caption = 'Actualizar esta vigencia';
                    ToolTip = 'Modifica el orden de la vigencia existente, conservando su código y fechas. Los próximos recálculos de cualquier período de su intervalo usarán el nuevo orden. Los recibos guardados no se recalculan. Desactivado crea una nueva vigencia.';
                    trigger OnValidate()
                    begin
                        InvalidarPropuesta();
                        ActualizarSeleccion();
                        CurrPage.Update(false);
                    end;
                }
                field(AvisoActualizarVigencia; AvisoActualizarVigenciaTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Alcance de la actualización';
                    Editable = false;
                    Visible = ActualizarVigencia;
                    MultiLine = true;
                }
                field(SoloConflictos; SoloConflictos)
                {
                    ApplicationArea = All;
                    Caption = 'Solo pendientes de revisión';
                    ToolTip = 'Muestra productores posteriores a una lectura, dependencias entre fórmulas y órdenes que necesitan contexto. Un subtotal puede ser intencional; el aviso no demuestra una diferencia en el recibo.';

                    trigger OnValidate()
                    begin
                        AplicarFiltro();
                        CurrPage.Update(false);
                    end;
                }
                field(TipoLiq; TipoLiq)
                {
                    ApplicationArea = All;
                    Caption = 'Tipo de liquidación';
                    TableRelation = "Tipo Liquidación".Código;
                    ToolTip = 'Limita el análisis a esta modalidad y permite resolver las fórmulas de orden que la utilizan. Vacío incluye todas las modalidades.';
                    trigger OnValidate()
                    begin
                        Analizar();
                    end;
                }
                field(Convenio; Convenio)
                {
                    ApplicationArea = All;
                    Caption = 'Convenio';
                    TableRelation = "Convenio Colectivo".Código;
                    ToolTip = 'Convenio del caso que se está revisando. Completá también la categoría para aplicar las restricciones de conceptos.';
                    trigger OnValidate()
                    begin
                        Categoria := '';
                        Analizar();
                    end;
                }
                field(Categoria; Categoria)
                {
                    ApplicationArea = All;
                    Caption = 'Categoría';
                    TableRelation = "Categoría CCT".Código;
                    ToolTip = 'Categoría dentro del convenio. Las condiciones y novedades de cada empleado se comprueban al calcular su liquidación.';
                    trigger OnLookup(var Text: Text): Boolean
                    var
                        CategoriaCCT: Record "Categoría CCT";
                    begin
                        if Convenio <> '' then
                            CategoriaCCT.SetRange("Cód. Convenio", Convenio);
                        if Page.RunModal(Page::"Categorías CCT", CategoriaCCT) = Action::LookupOK then begin
                            Convenio := CategoriaCCT."Cód. Convenio";
                            Categoria := CategoriaCCT.Código;
                            Text := Categoria;
                            Analizar();
                            exit(true);
                        end;
                    end;
                    trigger OnValidate()
                    begin
                        Analizar();
                    end;
                }
                field(Resumen; Resumen)
                {
                    ApplicationArea = All;
                    Caption = 'Resultado';
                    Editable = false;
                    StyleExpr = ResumenStyle;
                    MultiLine = true;
                }
            }
            group(PropuestaSeleccionada)
            {
                Caption = 'Corrección de la fila seleccionada';
                field(ConceptoPropuesto; ConceptoPropuesto)
                {
                    ApplicationArea = All;
                    Caption = 'Concepto';
                    Editable = false;
                }
                field(OrdenPropuestoTexto; OrdenPropuestoTexto)
                {
                    ApplicationArea = All;
                    Caption = 'Orden propuesto';
                    Editable = false;
                    ToolTip = 'Sólo muestra una posición distinta y comprobada. Vacío significa que falta contexto o no existe un movimiento seguro de un único concepto.';
                }
                field(MotivoPropuesta; MotivoPropuesta)
                {
                    ApplicationArea = All;
                    Caption = 'Evaluación de la propuesta';
                    Editable = false;
                    MultiLine = true;
                }
            }
            repeater(Lines)
            {
                Editable = false;
                field(TipoFila; TipoFila)
                {
                    ApplicationArea = All;
                    Caption = 'Tipo de control';
                    ToolTip = 'Acumulador: compara aportes y lecturas de una base. Fórmula: compara al lector con los resultados calculados que necesita, incluidas las dependencias de llamadas @.';
                }
                field(Observación; Rec.Observación)
                {
                    ApplicationArea = All;
                    StyleExpr = FilaStyle;
                    ToolTip = 'El análisis compara la configuración. Una lectura por etapas puede ser necesaria; para afirmar un error de importe hay que comprobar el contexto y la base esperada.';
                }
                field("Cód. Acumulador"; Rec."Cód. Acumulador")
                {
                    ApplicationArea = All;
                    Caption = 'Base o fórmula lectora';
                    StyleExpr = FilaStyle;
                }
                field(Descripción; Rec.Descripción)
                {
                    ApplicationArea = All;
                    StyleExpr = FilaStyle;
                }
                field("Orden Máx. Aporte"; Rec."Orden Máx. Aporte")
                {
                    ApplicationArea = All;
                    Caption = 'Último orden productor';
                    ToolTip = 'Mayor orden posible entre los aportantes de la base o los resultados calculados que necesita la fórmula.';
                }
                field("Concepto Máx. Aporte"; Rec."Concepto Máx. Aporte")
                {
                    ApplicationArea = All;
                    Caption = 'Último productor';
                    ToolTip = 'Concepto cuyo resultado necesario queda más tarde.';
                }
                field("Orden Mín. Lectura"; Rec."Orden Mín. Lectura")
                {
                    ApplicationArea = All;
                    Caption = 'Primer orden lector';
                    ToolTip = 'Orden de la fórmula lectora o primera lectura de la base. Los órdenes que necesitan datos adicionales se señalan en Evaluación.';
                    StyleExpr = FilaStyle;
                }
                field("Concepto Mín. Lectura"; Rec."Concepto Mín. Lectura")
                {
                    ApplicationArea = All;
                    Caption = 'Lector';
                    ToolTip = 'Fórmula revisada o primer concepto que lee el acumulador.';
                    StyleExpr = FilaStyle;
                }
                field("Aportes en Conflicto"; Rec."Aportes en Conflicto")
                {
                    ApplicationArea = All;
                    Caption = 'Productores posteriores';
                    StyleExpr = FilaStyle;
                }
                field("Códigos en Conflicto"; Rec."Códigos en Conflicto")
                {
                    ApplicationArea = All;
                    Caption = 'Conceptos posteriores';
                    ToolTip = 'Productores posteriores al lector, con su orden entre paréntesis. Revisá las dependencias antes de moverlos.';
                    StyleExpr = FilaStyle;
                }
                field("Orden Sugerido"; Rec."Orden Sugerido")
                {
                    ApplicationArea = All;
                    Visible = false;
                }
                field("Cant. Aportes"; Rec."Cant. Aportes") { ApplicationArea = All; Caption = 'Cant. productores'; }
                field("Cant. Lecturas"; Rec."Cant. Lecturas") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Recalcular)
            {
                ApplicationArea = All;
                Caption = 'Verificar';
                Image = Refresh;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Vuelve a analizar la configuración. Corré esto después de cambiar Orden Cálculo, fórmulas o fracciones de acumulador.';

                trigger OnAction()
                begin
                    Analizar(true);
                end;
            }
            action(VerConcepto)
            {
                ApplicationArea = All;
                Caption = 'Abrir lector';
                Image = Document;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Abre la vigencia de la fórmula lectora o del primer lector de la base a la fecha de referencia.';

                trigger OnAction()
                begin
                    AbrirConcepto(Rec."Concepto Mín. Lectura");
                end;
            }
            action(RecalcularOrdenes)
            {
                ApplicationArea = All;
                Caption = 'Recalcular órdenes';
                Image = Calculate;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                AccessByPermission = tabledata "Concepto Liquidación" = I;
                ToolTip = 'Corrige los conflictos seguros de acumuladores y referencias entre fórmulas, aunque estén ocultos por filtros. Desde una ficha limita el cambio a ese concepto. Según Actualizar esta vigencia, modifica el orden existente o crea otra vigencia. Conserva fórmulas de importe y recibos.';

                trigger OnAction()
                var
                    Gestor: Codeunit "Corrección Orden Acum.";
                    Cambios: Integer;
                    Pendientes: Integer;
                    Detalle: Text;
                    SeleccionAnterior: Code[20];
                    VistaAnterior: Text;
                begin
                    if ModoConcepto then begin
                        CorregirSeleccionado();
                        exit;
                    end;
                    SeleccionAnterior := Rec."Cód. Acumulador";
                    VistaAnterior := Rec.GetView(false);
                    InvalidarPropuesta();
                    AnalisisDisponible := false;
                    Rec.Reset();
                    Gestor.CorregirTodos(FechaRef, TipoLiq, Convenio, Categoria, ActualizarVigencia, Cambios, Pendientes, Detalle, Rec);
                    CompletarAnalisis(Pendientes, SeleccionAnterior, VistaAnterior);
                    Message(ResumenRecalculoTxt, Cambios, Pendientes, Detalle);
                end;
            }
            action(CorregirOrden)
            {
                ApplicationArea = All;
                Caption = 'Corregir orden...';
                Visible = not ModoConcepto;
                Image = Change;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                AccessByPermission = tabledata "Concepto Liquidación" = I;
                ToolTip = 'Prepara una corrección para la fila seleccionada. Permite revisar el concepto, el orden y el alcance antes de actualizar la vigencia existente o crear otra; comprueba las dependencias y conserva los recibos guardados.';
                trigger OnAction()
                begin
                    CorregirSeleccionado();
                end;
            }
            action(VerAporte)
            {
                ApplicationArea = All;
                Caption = 'Abrir último productor';
                Image = Document;
                ToolTip = 'Abre la vigencia del último productor necesario para la base o la fórmula lectora.';

                trigger OnAction()
                begin
                    AbrirConcepto(Rec."Concepto Máx. Aporte");
                end;
            }
            action(VerAlimentadores)
            {
                ApplicationArea = All;
                Caption = 'Ver todos los aportes';
                Enabled = not FilaSeleccionadaFormula;
                Image = List;
                ToolTip = 'Disponible para filas de acumulador: muestra los conceptos que alimentan la base, con su porcentaje y vigencia.';

                trigger OnAction()
                var
                    Frac: Record "Fracción Acumulador";
                begin
                    Rec.TestField("Cód. Acumulador");
                    if EsFilaFormula() then
                        exit;
                    Frac.SetRange("Cód. Acumulador", Rec."Cód. Acumulador");
                    Page.Run(Page::"Alimentadores Acumulador Sub", Frac);
                end;
            }
        }
    }

    procedure ConfigurarConcepto(ConceptoOrigen: Record "Concepto Liquidación")
    begin
        ConceptoOrigen.TestField(Código);
        ConceptoRevision := ConceptoOrigen;
        ModoConcepto := true;
        ActualizarVigencia := true;
        if ConceptoRevision."Es Acumulador" then
            AlcanceRevision := 'Se revisa sólo la base de este acumulador y se proponen cambios en sus aportantes o lectores. El acumulador no tiene un orden propio que corregir.'
        else
            AlcanceRevision := 'Se revisan las dependencias de esta fórmula, sus consumidores y los acumuladores relacionados. La corrección queda limitada a este concepto y su vigencia.';
    end;

    trigger OnOpenPage()
    var
        Tipo: Record "Tipo Liquidación";
        TiposAplicables: Text;
    begin
        FechaRef := WorkDate();
        SoloConflictos := not ModoConcepto;
        if ModoConcepto then begin
            if FechaRef < ConceptoRevision."Vigencia Desde" then
                FechaRef := ConceptoRevision."Vigencia Desde";
            if ConceptoRevision."Vigencia Hasta" <> 0D then
                if FechaRef > ConceptoRevision."Vigencia Hasta" then
                    FechaRef := ConceptoRevision."Vigencia Hasta";
            TiposAplicables := DelChr(ConceptoRevision."Tipos Liq. Aplicables", '<>', ' ');
            if (TiposAplicables <> '') and (StrPos(TiposAplicables, '|') = 0) then
                if StrLen(TiposAplicables) <= MaxStrLen(TipoLiq) then
                    if Tipo.Get(TiposAplicables) then
                        TipoLiq := Tipo.Código;
        end;
        Analizar(true);
        if ModoConcepto then begin
            SeleccionarPrimerConflicto();
            ActualizarPropuesta();
            CurrPage.Update(false);
        end;
    end;

    trigger OnAfterGetRecord()
    begin
        if EsFilaFormula() then
            TipoFila := 'Fórmula'
        else
            TipoFila := 'Acumulador';
        if Rec.Conflicto then
            FilaStyle := 'Ambiguous'
        else
            FilaStyle := 'Standard';
    end;

    trigger OnAfterGetCurrRecord()
    begin
        ActualizarSeleccion();
    end;

    local procedure CorregirSeleccionado()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
        Dialogo: Page "Corregir Orden Acum. Dialog";
        Origen: Record "Concepto Liquidación";
        AcumuladorActual: Record "Concepto Liquidación";
        OrdenNuevo: Integer;
        FechaNueva: Date;
        Explicacion: Text;
        CodAcumulador: Code[20];
        Aviso: Notification;
    begin
        if Rec.IsEmpty() then begin
            if ModoConcepto and not TieneBasesRevision then
                Message('%1', SinBasesConceptoTxt)
            else
                Message('%1', SinFilasVisiblesTxt);
            exit;
        end;
        Rec.TestField("Cód. Acumulador");
        CodAcumulador := Rec."Cód. Acumulador";
        ActualizarPropuesta();
        if not PropuestaDisponible then begin
            Message('%1', MotivoPropuesta);
            exit;
        end;
        Origen := OrigenPropuesta;
        OrdenNuevo := OrdenPropuesta;
        FechaNueva := FechaPropuesta;
        Explicacion := MotivoPropuesta;
        Dialogo.FijarConcepto(ModoConcepto and not ConceptoRevision."Es Acumulador");
        Dialogo.Configurar(CodAcumulador, FechaRef, TipoLiq, Convenio, Categoria, Origen, OrdenNuevo, FechaNueva, Explicacion, ActualizarVigencia);
        if Dialogo.RunModal() <> Action::OK then
            exit;
        Dialogo.GetResultado(Origen, OrdenNuevo, FechaNueva, ActualizarVigencia);
        if ModoConcepto and not ConceptoRevision."Es Acumulador" then
            if Origen.Código <> ConceptoRevision.Código then
                Error('La revisión está limitada al concepto %1.', ConceptoRevision.Código);
        if ModoConcepto and ConceptoRevision."Es Acumulador" then begin
            if not AcumuladorActual.Get(ConceptoRevision.Código, ConceptoRevision."Vigencia Desde") then
                Error('La vigencia del acumulador abierta en la revisión ya no existe. Volvé a abrir la revisión desde la ficha.');
            if AcumuladorActual.SystemRowVersion <> ConceptoRevision.SystemRowVersion then
                Error('El acumulador cambió desde que se abrió la revisión. Volvé a abrirla desde la ficha.');
            if not ActualizarVigencia then
                if not ConceptoRevision.VigenteA(FechaNueva) then
                    Error('La fecha del cambio debe estar dentro de la vigencia del acumulador %1 abierta en la revisión.', ConceptoRevision.Código);
        end;
        Gestor.Aplicar(CodAcumulador, Origen, FechaNueva, OrdenNuevo, TipoLiq, Convenio, Categoria, ActualizarVigencia);
        if ModoConcepto and not ConceptoRevision."Es Acumulador" then
            ConceptoRevision.Get(Origen.Código, FechaNueva);
        if not ActualizarVigencia then
            FechaRef := FechaNueva;
        Analizar(true);
        if ActualizarVigencia then
            Aviso.Message := StrSubstNo('Se actualizó el orden de %1 en su vigencia desde %2, conservando sus fechas. Los próximos recálculos de ese intervalo usarán el nuevo orden; los recibos guardados no se recalcularon.', Origen.Código, FechaNueva)
        else
            Aviso.Message := StrSubstNo('Se creó la nueva vigencia de %1 desde %2. El control fue actualizado; los recibos existentes no se recalcularon.', Origen.Código, FechaNueva);
        Aviso.Scope := NotificationScope::LocalScope;
        Aviso.Send();
    end;

    local procedure InvalidarPropuesta()
    begin
        Clear(OrigenPropuesta);
        Clear(ConceptoPropuesto);
        Clear(OrdenPropuestoTexto);
        Clear(MotivoPropuesta);
        PropuestaDisponible := false;
        PropuestaCalculada := false;
        AcumuladorSeleccionado := '';
    end;

    local procedure ActualizarSeleccion()
    begin
        FilaSeleccionadaFormula := EsFilaFormula();
        if AcumuladorSeleccionado = Rec."Cód. Acumulador" then
            exit;
        InvalidarPropuesta();
        AcumuladorSeleccionado := Rec."Cód. Acumulador";
        if Rec."Cód. Acumulador" = '' then
            exit;
        if not Rec.Conflicto and not (ModoConcepto and not ConceptoRevision."Es Acumulador") then begin
            MotivoPropuesta := 'Sin productores posteriores detectados. No se propone cambiar el orden.';
            exit;
        end;
        if ModoConcepto then
            MotivoPropuesta := 'Elegí Recalcular órdenes para preparar y revisar una propuesta para esta fila.'
        else
            MotivoPropuesta := 'Elegí Corregir orden para preparar y revisar una propuesta para esta fila.';
    end;

    local procedure EsFilaFormula(): Boolean
    begin
        // El código de un lector ordinario no puede ser también el de un acumulador vigente.
        exit((Rec."Cód. Acumulador" <> '') and (Rec."Cód. Acumulador" = Rec."Concepto Mín. Lectura"));
    end;

    local procedure ActualizarPropuesta()
    begin
        if Rec.IsEmpty() then begin
            InvalidarPropuesta();
            if ModoConcepto and not TieneBasesRevision then
                MotivoPropuesta := SinBasesConceptoTxt
            else
                MotivoPropuesta := SinFilasVisiblesTxt;
            exit;
        end;
        ActualizarSeleccion();
        // Redibujar la lista o cancelar el diálogo no vuelve a buscar un plan.
        // Verificar y los cambios de contexto invalidan esta vista; Aplicar valida fresco.
        if PropuestaCalculada then
            exit;
        if Rec."Cód. Acumulador" = '' then
            exit;
        if not Rec.Conflicto and not (ModoConcepto and not ConceptoRevision."Es Acumulador") then
            exit;
        PropuestaCalculada := true;
        if not IntentarPrepararPropuesta() then
            MotivoPropuesta := 'Pendiente de revisión: ' + GetLastErrorText();
        if PropuestaDisponible then begin
            ConceptoPropuesto := OrigenPropuesta.Código;
            OrdenPropuestoTexto := Format(OrdenPropuesta, 0, 9);
        end;
    end;

    [TryFunction]
    local procedure IntentarPrepararPropuesta()
    var
        Gestor: Codeunit "Corrección Orden Acum.";
    begin
        // Desde la ficha sólo se puede proponer el concepto exacto; un acumulador revisa su base.
        if ModoConcepto and not ConceptoRevision."Es Acumulador" then
            PropuestaDisponible := Gestor.PrepararConcepto(ConceptoRevision, Rec."Cód. Acumulador", FechaRef, TipoLiq, Convenio, Categoria, ActualizarVigencia, OrigenPropuesta, OrdenPropuesta, FechaPropuesta, MotivoPropuesta)
        else
            PropuestaDisponible := Gestor.Proponer(Rec."Cód. Acumulador", FechaRef, TipoLiq, Convenio, Categoria, ActualizarVigencia, OrigenPropuesta, OrdenPropuesta, FechaPropuesta, MotivoPropuesta);
    end;

    local procedure Analizar()
    begin
        Analizar(false);
    end;

    local procedure Analizar(Forzar: Boolean)
    var
        Control: Codeunit "Control Orden Acumuladores";
        Gestor: Codeunit "Corrección Orden Acum.";
        Conflictos: Integer;
        SeleccionAnterior: Code[20];
        VistaAnterior: Text;
    begin
        // Lookup y OnValidate pueden notificar el mismo cambio consecutivamente.
        if not Forzar then
            if AnalisisDisponible and (FechaAnalizada = FechaRef) and
               (TipoAnalizado = TipoLiq) and (ConvenioAnalizado = Convenio) and
               (CategoriaAnalizada = Categoria) then
                exit;
        SeleccionAnterior := Rec."Cód. Acumulador";
        VistaAnterior := Rec.GetView(false);
        InvalidarPropuesta();
        AnalisisDisponible := false;
        Rec.Reset();
        if ModoConcepto then
            Conflictos := Gestor.AnalizarConcepto(ConceptoRevision, FechaRef, TipoLiq, Convenio, Categoria, Rec)
        else
            Conflictos := Control.Analizar(FechaRef, TipoLiq, Convenio, Categoria, Rec);
        CompletarAnalisis(Conflictos, SeleccionAnterior, VistaAnterior);
    end;

    local procedure CompletarAnalisis(Conflictos: Integer; SeleccionAnterior: Code[20]; VistaAnterior: Text)
    begin
        if Conflictos = 0 then begin
            Resumen := SinConflictosTxt;
            ResumenStyle := 'Favorable';
        end else begin
            Resumen := CopyStr(StrSubstNo(ConConflictosTxt, Conflictos), 1, MaxStrLen(Resumen));
            ResumenStyle := 'Ambiguous';
        end;
        if ModoConcepto then begin
            TieneBasesRevision := not Rec.IsEmpty();
            if not TieneBasesRevision then begin
                Resumen := CopyStr(SinBasesConceptoTxt, 1, MaxStrLen(Resumen));
                ResumenStyle := 'Ambiguous';
            end;
        end;
        FechaAnalizada := FechaRef;
        TipoAnalizado := TipoLiq;
        ConvenioAnalizado := Convenio;
        CategoriaAnalizada := Categoria;
        AnalisisDisponible := true;
        Rec.SetView(VistaAnterior);
        AplicarFiltro(SeleccionAnterior);
        CurrPage.Update(false);
    end;

    local procedure AplicarFiltro()
    begin
        AplicarFiltro(Rec."Cód. Acumulador");
    end;

    local procedure AplicarFiltro(SeleccionAnterior: Code[20])
    begin
        if SoloConflictos then
            Rec.SetRange(Conflicto, true)
        else
            Rec.SetRange(Conflicto);
        if SeleccionAnterior <> '' then begin
            if SeleccionarFila(SeleccionAnterior, true) then
                exit;
            if SeleccionarFila(SeleccionAnterior, false) then
                exit;
        end;
        if Rec.FindFirst() then;
    end;

    local procedure SeleccionarFila(Codigo: Code[20]; Exacta: Boolean): Boolean
    var
        GrupoAnterior: Integer;
        FiltroAnterior: Text;
        Encontrada: Boolean;
    begin
        // Un filtro separado conserva la vista del usuario al mantener la fila o pasar a la siguiente.
        GrupoAnterior := Rec.FilterGroup();
        Rec.FilterGroup(10);
        FiltroAnterior := Rec.GetFilter("Cód. Acumulador");
        if Exacta then
            Rec.SetRange("Cód. Acumulador", Codigo)
        else
            Rec.SetFilter("Cód. Acumulador", '>%1', Codigo);
        Rec.FilterGroup(GrupoAnterior);
        Encontrada := Rec.FindFirst();
        Rec.FilterGroup(10);
        Rec.SetFilter("Cód. Acumulador", FiltroAnterior);
        Rec.FilterGroup(GrupoAnterior);
        exit(Encontrada);
    end;

    local procedure SeleccionarPrimerConflicto()
    var
        GrupoAnterior: Integer;
        FiltroAnterior: Text;
        SeleccionAnterior: Code[20];
        Encontrada: Boolean;
    begin
        // Se prepara una sola propuesta al entrar, preferentemente la de una base pendiente.
        SeleccionAnterior := Rec."Cód. Acumulador";
        GrupoAnterior := Rec.FilterGroup();
        Rec.FilterGroup(10);
        FiltroAnterior := Rec.GetFilter(Conflicto);
        Rec.SetRange(Conflicto, true);
        Rec.FilterGroup(GrupoAnterior);
        Encontrada := Rec.FindFirst();
        Rec.FilterGroup(10);
        Rec.SetFilter(Conflicto, FiltroAnterior);
        Rec.FilterGroup(GrupoAnterior);
        if not Encontrada then
            AplicarFiltro(SeleccionAnterior);
    end;

    local procedure AbrirConcepto(CodConcepto: Code[20])
    var
        Concepto: Record "Concepto Liquidación";
    begin
        if CodConcepto = '' then
            exit;
        Concepto.SetRange(Código, CodConcepto);
        Concepto.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        if Concepto.FindLast() then
            Page.Run(Page::"Concepto Liq. Card", Concepto);
    end;

    var
        ModoConcepto: Boolean;
        ActualizarVigencia: Boolean;
        TieneBasesRevision: Boolean;
        ConceptoRevision: Record "Concepto Liquidación";
        AlcanceRevision: Text;
        FechaRef: Date;
        OrigenPropuesta: Record "Concepto Liquidación";
        ConceptoPropuesto: Code[20];
        OrdenPropuestoTexto: Text;
        MotivoPropuesta: Text;
        OrdenPropuesta: Integer;
        FechaPropuesta: Date;
        PropuestaDisponible: Boolean;
        PropuestaCalculada: Boolean;
        AcumuladorSeleccionado: Code[20];
        AnalisisDisponible: Boolean;
        FechaAnalizada: Date;
        TipoAnalizado: Code[20];
        ConvenioAnalizado: Code[20];
        CategoriaAnalizada: Code[20];
        TipoLiq: Code[20];
        Convenio: Code[20];
        Categoria: Code[20];
        SoloConflictos: Boolean;
        FilaStyle: Text[20];
        ResumenStyle: Text[20];
        Resumen: Text[250];
        TipoFila: Text[20];
        FilaSeleccionadaFormula: Boolean;
        SinConflictosTxt: Label 'Sin precedencias pendientes detectadas en los acumuladores y dependencias de fórmulas revisados. Las condiciones e incidencias se verifican durante el cálculo.';
        ConConflictosTxt: Label '%1 control(es) de acumuladores o fórmulas para revisar. Incluye precedencias potenciales y contexto insuficiente; esto no demuestra un error de importe. Elegí tipo, convenio y categoría para precisar el análisis.';
        ResumenRecalculoTxt: Label 'Órdenes actualizadas: %1. Pendientes de revisión: %2. Los recibos existentes no se recalcularon.\%3';
        SinBasesConceptoTxt: Label 'No hay acumuladores ni dependencias calculadas relacionados con esta vigencia en el contexto indicado. No se propone un cambio de orden; esto no demuestra que los importes sean correctos.';
        SinFilasVisiblesTxt: Label 'No hay controles de orden visibles para revisar. Quitá los filtros de la lista o cambiá el contexto.';
        AvisoActualizarVigenciaTxt: Label 'Se conservarán el código y las fechas de la vigencia. Todo período de ese intervalo usará el nuevo orden en próximos recálculos. Los recibos guardados no se recalculan.';
}
