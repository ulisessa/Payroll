namespace UAS.Payroll;

using Microsoft.Foundation.UOM;
using Microsoft.HumanResources.Setup;

table 60007 "Concepto Liquidación"
{
    Caption = 'Concepto Liquidación';
    DataClassification = CustomerContent;
    LookupPageId = "Conceptos Liquidación";
    DrillDownPageId = "Conceptos Liquidación";

    fields
    {
        field(1; Código; Code[20])
        {
            Caption = 'Código';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(2; "Vigencia Desde"; Date)
        {
            Caption = 'Vigencia Desde';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(3; Descripción; Text[100])
        {
            Caption = 'Descripción';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(4; "Nombre Impresión"; Text[50])
        {
            Caption = 'Nombre Impresión';
            DataClassification = CustomerContent;
        }
        field(5; "Tipo Concepto"; Enum "Tipo Concepto Liq.")
        {
            Caption = 'Tipo Concepto';
            DataClassification = CustomerContent;
        }
        field(9; "Grupo Costo Laboral"; Enum "Grupo Costo Laboral Liq.")
        {
            Caption = 'Grupo Costo Laboral';
            DataClassification = CustomerContent;
        }
        field(6; Fórmula; Text[2048])
        {
            Caption = 'Fórmula';
            DataClassification = CustomerContent;
            trigger OnValidate()
            var
                Eval: Codeunit "Evaluador Fórmula";
                Formateador: Codeunit "Formateador Fórmula Liq.";
                KnownCtx: Dictionary of [Text, Decimal];
                Dummy: Decimal;
                ErrTxt: Text;
            begin
                Rec.Fórmula := Formateador.Formatear(Rec.Fórmula);
                if Rec.Fórmula = '' then
                    exit;
                // Pass 1: syntax only (lenient)
                Eval.Init(KnownCtx, Today());
                Eval.SetLenientMode(true);
                if not Eval.TryEvalFormula(Rec.Fórmula, Dummy) then
                    Error(ErrSintaxisFormula, GetLastErrorText());
                // Pass 2: variable existence (strict, known vars = 1 to avoid div/0)
                BuildKnownVarsCtx(KnownCtx);
                Eval.Init(KnownCtx, Today());
                Eval.SetLenientMode(false);
                // Modo validación: tolera lo que depende del valor —dividir por una variable, un
                // tramo inexistente— y a cambio hace que las ramas no elegidas del IF y del CASE se
                // parseen en vez de saltearse. Sin esto, una variable inexistente escondida en la
                // rama falsa no la detecta este paso, que existe justamente para eso.
                Eval.SetModoValidacion(true);
                if not Eval.TryEvalFormula(Rec.Fórmula, Dummy) then begin
                    ErrTxt := GetLastErrorText();
                    if ErrTxt.Contains('Variable desconocida') then
                        Message(ErrVariableDesconocida, ErrTxt);
                end;
            end;
        }
        field(7; Condición; Text[2048])
        {
            Caption = 'Condición';
            DataClassification = CustomerContent;
            trigger OnValidate()
            var
                Eval: Codeunit "Evaluador Fórmula";
                Formateador: Codeunit "Formateador Fórmula Liq.";
                KnownCtx: Dictionary of [Text, Decimal];
                Dummy: Boolean;
                ErrTxt: Text;
            begin
                Rec.Condición := Formateador.Formatear(Rec.Condición);
                if Rec.Condición = '' then
                    exit;
                // Pass 1: syntax only (lenient)
                Eval.Init(KnownCtx, Today());
                Eval.SetLenientMode(true);
                if not Eval.TryEvalCondicion(Rec.Condición, Dummy) then
                    Error(ErrSintaxisCondicion, GetLastErrorText());
                // Pass 2: variable existence (strict)
                BuildKnownVarsCtx(KnownCtx);
                Eval.Init(KnownCtx, Today());
                Eval.SetLenientMode(false);
                // Modo validación: tolera lo que depende del valor —dividir por una variable, un
                // tramo inexistente— y a cambio hace que las ramas no elegidas del IF y del CASE se
                // parseen en vez de saltearse. Sin esto, una variable inexistente escondida en la
                // rama falsa no la detecta este paso, que existe justamente para eso.
                Eval.SetModoValidacion(true);
                if not Eval.TryEvalCondicion(Rec.Condición, Dummy) then begin
                    ErrTxt := GetLastErrorText();
                    if ErrTxt.Contains('Variable desconocida') then
                        Message(ErrVariableDesconocida, ErrTxt);
                end;
            end;
        }
        field(8; "Orden Cálculo"; Integer)
        {
            Caption = 'Orden Cálculo';
            DataClassification = CustomerContent;
            MinValue = 0;
        }
        field(10; "Aplica A"; Enum "Aplica A Liq.")
        {
            Caption = 'Aplica A';
            DataClassification = CustomerContent;
        }
        field(11; Activo; Boolean)
        {
            Caption = 'Activo (sin efecto)';
            DataClassification = CustomerContent;
            InitValue = true;
            ObsoleteState = Pending;
            ObsoleteReason = 'Sin efecto en el cálculo: la baja de un concepto se expresa con "Vigencia Hasta". El campo se conserva solo para poder revisar las versiones que quedaron en false (ver la página "Versiones inactivas a revisar").';
            // Ya no lo lee nadie. Se deja el dato —y no se borra— porque una versión con Activo =
            // false era, hasta ahora, la forma de "apagar" un concepto: esas filas AHORA CALCULAN, y
            // hay que revisarlas una por una antes de recalcular.
        }
        field(12; "Vigencia Hasta"; Date)
        {
            Caption = 'Vigencia Hasta';
            DataClassification = CustomerContent;
            // Último día en que esta versión se aplica. 0D = vigencia abierta.
            //
            // Es el reemplazo de "Activo" como forma de dar de baja un concepto. El booleano no
            // podía hacerlo: una versión con Activo = false no quedaba discontinuada sino
            // invisible, y el motor caía a la versión activa anterior y la seguía usando. Con una
            // fecha no hay ambigüedad ni orden de filtrado que elegir — el intervalo es parte del
            // predicado de selección, así que no se puede aplicar mal.
            //
            // Las versiones se encadenan solas: al insertar una, la anterior se cierra el día
            // previo. Pero el HUECO es legítimo y deliberado — un concepto se puede cerrar en
            // marzo y recién volver a hacer falta en julio — así que la superposición se valida
            // y se rechaza, nunca se corrige sola pisando una fecha de fin puesta a mano.
            trigger OnValidate()
            begin
                ValidarIntervalo();
                ValidarSinUsoPosteriorA("Vigencia Hasta");
                ValidarNoPisaSiguiente();
            end;
        }
        field(13; "Es Acumulador"; Boolean)
        {
            Caption = 'Es Acumulador';
            DataClassification = CustomerContent;
            // Marks this concept as a named accumulator (no formula; receives values from others).
        }
        field(14; "Aplica Tipo Liq."; Enum "Aplica Tipo Liq. Concepto")
        {
            Caption = 'Aplica a Tipo Liq. (obsoleto)';
            DataClassification = CustomerContent;
            ObsoleteState = Pending;
            ObsoleteReason = 'Reemplazado por "Tipos Liq. Aplicables" que permite selección múltiple.';
        }
        field(22; "Tipos Liq. Aplicables"; Text[250])
        {
            Caption = 'Aplica a Tipo Liq.';
            DataClassification = CustomerContent;
        }
        field(15; "Vigencia CCT Más Reciente"; Date)
        {
            Caption = 'Vigencia CCT Más Reciente';
            FieldClass = FlowField;
            CalcFormula = Max("Concepto CCT Vigente"."Vigencia Desde" WHERE("Cód. Concepto" = FIELD(Código)));
            Editable = false;
            // 0D = no CCT restriction records exist → the concept applies to every CCT.
            // Non-zero = the latest restriction batch's Vigencia Desde; combine with the
            // current Convenio code to determine applicability via "Concepto CCT Vigente".
        }
        field(16; "Variable Cantidad"; Code[100])
        {
            Caption = 'Variable Cantidad';
            DataClassification = CustomerContent;
            // Un nombre de variable o una EXPRESIÓN: PCT_ANTIG_SOMU*100, DIAS_PROYECTO+DIAS_PUERTO.
            // Lo resuelve ResolverExpresionLinea (Cod50014), que primero prueba el nombre y recién
            // después evalúa. Por eso el campo es más largo que un nombre.

            trigger OnValidate()
            begin
                ValidarExpresionPresentacion("Variable Cantidad", FieldCaption("Variable Cantidad"));
            end;
        }
        field(17; "Unidad Cantidad"; Code[10])
        {
            Caption = 'Unidad Cantidad';
            DataClassification = CustomerContent;
            TableRelation = "Unit of Measure".Code;
        }
        field(21; "Variable Base"; Code[100])
        {
            Caption = 'Variable Base';
            DataClassification = CustomerContent;
            // Igual que "Variable Cantidad": nombre o expresión.

            trigger OnValidate()
            begin
                ValidarExpresionPresentacion("Variable Base", FieldCaption("Variable Base"));
            end;
        }
        field(18; "Etiqueta Det. Ganancias"; Text[100])
        {
            Caption = 'Etiqueta en Det. Ganancias';
            DataClassification = CustomerContent;
            // When non-empty, the concept result is written as a "Paso" row in
            // Detalle Ganancias Liq. at calculation time, showing this label
            // in the ganancias detail section of the payslip.
        }
        field(19; "Imprime en Recibo"; Boolean)
        {
            Caption = 'Imprime en Recibo';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(20; "Es Devengo"; Boolean)
        {
            Caption = 'Es Devengo';
            DataClassification = CustomerContent;
        }
        field(25; "Cód. Tipo Atributo Detalle"; Code[20])
        {
            Caption = 'Detalle de atributo';
            DataClassification = CustomerContent;
            TableRelation = "Tipo Atributo Liq.".Código;
            // QUÉ ATRIBUTO EXPLICA ESTA LÍNEA. Cargado, la línea muestra al lado del importe la
            // descripción del valor que el empleado tenía en ese atributo a la fecha de la
            // liquidación: la cuota sindical dice de qué gremio sale, el aporte de obra social a
            // cuál va.
            //
            // Va acá y no cableado en la pantalla porque la pregunta "¿por qué este importe y no
            // otro?" se responde distinto en cada concepto, y quién la responde es un dato del
            // concepto. Con 8522 y 6030 escritos en la página, agregar el tercero seria tocar AL.
            //
            // No interviene en el cálculo. Es una columna que se lee.
        }
        field(24; "Par CCT a Usar"; Enum "Par CCT Liq.")
        {
            Caption = 'Convenio/Categoría a usar';
            DataClassification = CustomerContent;
            // Con qué par se resuelven los parámetros de ESTE concepto. El valor por defecto es el
            // del empleado, así que un concepto que nadie tocó no cambia de comportamiento.
            //
            // Con "el de la asignación", el motor recarga los parámetros con el convenio y la
            // categoría del proyecto de la liquidación justo para evaluar este concepto, y los
            // vuelve a dejar como estaban. Es para lo que se paga por el embarque y no por el
            // encuadre: la producción de una marea, que se liquida con la categoría con la que el
            // tripulante salió a navegar.
            //
            // Sin proyecto en la liquidación, o si el empleado no está asignado a ese proyecto, no
            // hay par alternativo y el concepto resuelve con el del empleado.
        }
        field(23; "Rol Franco"; Enum "Rol Franco Liq.")
        {
            Caption = 'Rol Franco';
            DataClassification = CustomerContent;
            // Devengo: this concept accrues franco days (use with Es Devengo = true).
            // Consumo: this concept pays enjoyed francos (importe = PAGO_FRANCOS_FIFO, valued per lot category).
            // The franco engine identifies ledger lines in Línea Liquidación by this role.
        }
    }

    keys
    {
        key(PK; Código, "Vigencia Desde")
        {
            Clustered = true;
        }
        key(K2; "Orden Cálculo", Código)
        {
        }
        // Acompaña al filtro de SelectConceptos (Cod50014): tipo de empleado + intervalo de
        // vigencia. Tenía "Activo" en el lugar de las fechas, de cuando la baja era un booleano;
        // ningún SetCurrentKey la pedía por nombre, así que se puede reacomodar sin romper nada.
        key(K3; "Aplica A", "Vigencia Desde", "Vigencia Hasta")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Código, Descripción, "Tipo Concepto") { }
        fieldgroup(Brick; Código, Descripción) { }
    }

    // El historial de fórmulas se lleva desde los triggers de la tabla y no desde la ficha, para que
    // cubra TODOS los caminos de edición: la ficha, el editor con IntelliSense, el asistente de
    // fórmulas, "Copiar como...", la nueva vigencia y cualquier carga de configuración.
    trigger OnInsert()
    var
        HistorialMgt: Codeunit "Historial Fórmulas Liq.";
    begin
        ValidarIntervalo();
        ValidarNoSuperponeConAnterior();
        // Va ANTES de ValidarNoPisaSiguiente: al intercalar una versión entre otras dos, la fecha
        // de fin llega en blanco y es la sincronización la que la cierra contra la que sigue. Al
        // revés, la validación rechazaría una versión que en realidad está bien.
        SincronizarContiguidad();
        ValidarNoPisaSiguiente();
        HistorialMgt.RegistrarAlta(Rec);
    end;

    trigger OnModify()
    var
        HistorialMgt: Codeunit "Historial Fórmulas Liq.";
    begin
        if "Vigencia Hasta" <> xRec."Vigencia Hasta" then begin
            ValidarIntervalo();
            // La restricción es direccional: correr el fin hacia adelante siempre es seguro, lo que
            // rompe la reproducibilidad es ponerlo ANTES de una liquidación que ya usó esta versión.
            ValidarSinUsoPosteriorA("Vigencia Hasta");
            ValidarNoPisaSiguiente();
        end;
        HistorialMgt.RegistrarModificacion(Rec, xRec);
    end;

    trigger OnDelete()
    var
        HistorialMgt: Codeunit "Historial Fórmulas Liq.";
    begin
        ValidarSinUsoAlguno(Código, "Vigencia Desde");
        // Con la última versión se va el código entero: recién ahí hay que mirar quién lo nombraba y
        // limpiar lo que quede colgando. Borrar una vigencia intermedia no cambia nada de eso.
        if EsUltimaVigencia() then begin
            ValidarNoReferenciadoEnFormulas();
            ValidarNoReferenciadoPorConfiguracion();
            BorrarFraccionesHuerfanas();
            BorrarConveniosHuerfanos();
        end;
        // La anterior recupera el tramo que deja libre ésta; si no, borrar la última versión mataría
        // el concepto desde la fecha en que ésta arrancaba, sin que nada lo delate.
        ReabrirAnteriorAlBorrar();
        // Antes de borrar es la última oportunidad de conservar el texto que se va con la vigencia.
        HistorialMgt.RegistrarBaja(Rec);
    end;

    // Editar "Vigencia Desde" en la ficha es un rename, porque es parte de la clave primaria. Mover
    // el inicio reordena la cadena de versiones, así que hay que revalidar contra las vecinas nuevas.
    //
    // Cambiar el CÓDIGO, en cambio, no se permite. La plataforma arrastra el código nuevo a las diez
    // tablas que lo referencian por relación, pero hay dos lugares donde no puede llegar:
    //
    //   · el TEXTO de las fórmulas —@1052, #1052, o el nombre del acumulador escrito pelado— que es
    //     texto libre y no lo actualiza nadie. Una fórmula que nombra un concepto inexistente no da
    //     error: resuelve la variable como CERO y sigue. Es el mismo agujero que dejaron BASE_SS y
    //     BASE_OS al borrarse, y que costó encontrar porque los importes salían bajos, no rotos;
    //   · las líneas ya liquidadas, que guardan el código para poder reproducir un cálculo viejo con
    //     la versión de concepto que se usó en su momento.
    //
    // El camino correcto es "Copiar como...", que crea el concepto con el código nuevo llevándose
    // fraccionamientos y convenios, y después dar de baja el viejo cerrando su vigencia.
    trigger OnRename()
    begin
        if Código <> xRec.Código then
            Error(ErrRenombrarCodigo, xRec.Código, Código);

        ValidarSinUsoAlguno(xRec.Código, xRec."Vigencia Desde");
        ValidarIntervalo();
        ValidarNoSuperponeConAnterior();
        ValidarNoPisaSiguiente();
        ReencadenarAnterior(xRec."Vigencia Desde");
        SincronizarContiguidad();
    end;

    procedure CopiarEn(NuevoCodigo: Code[20])
    var
        NuevoConc: Record "Concepto Liquidación";
        FracOrig: Record "Fracción Acumulador";
        FracNueva: Record "Fracción Acumulador";
        CCTOrig: Record "Concepto CCT Vigente";
        CCTNueva: Record "Concepto CCT Vigente";
    begin
        NuevoConc := Rec;
        NuevoConc.Código := NuevoCodigo;
        NuevoConc.Insert(true);

        // Se copian TODAS las vigencias de la distribución, no solo las que coinciden con la vigencia
        // del concepto en la que uno está parado. La fracción se resuelve por su propia fecha —
        // Cod50014 BuildFractionCache toma la última <= fecha de liquidación, sin mirar qué versión
        // del concepto corre — así que filtrar por la vigencia del concepto dejaba la copia sin la
        // distribución que venía en vigor desde antes.
        FracOrig.SetRange("Cód. Concepto", Código);
        if FracOrig.FindSet() then
            repeat
                FracNueva := FracOrig;
                FracNueva."Cód. Concepto" := NuevoCodigo;
                FracNueva.Insert(true);
            until FracOrig.Next() = 0;

        // Las restricciones de convenio no se copiaban. Y como "sin filas" significa "aplica a todos
        // los convenios", copiar un concepto restringido a uno producía una copia que le liquida a
        // toda la nómina — silenciosamente, sin ningún error.
        CCTOrig.SetRange("Cód. Concepto", Código);
        if CCTOrig.FindSet() then
            repeat
                CCTNueva := CCTOrig;
                CCTNueva."Cód. Concepto" := NuevoCodigo;
                CCTNueva.Insert(true);
            until CCTOrig.Next() = 0;
    end;

    // ── Resolución de vigencia ────────────────────────────────────────────────
    // Los dos únicos lugares donde se decide si una versión está en vigor. Todo el resto del
    // sistema pasa por acá para que la regla no se pueda escribir mal en cada consumidor.

    procedure VigenteA(FechaRef: Date): Boolean
    begin
        if "Vigencia Desde" > FechaRef then
            exit(false);
        if ("Vigencia Hasta" <> 0D) and ("Vigencia Hasta" < FechaRef) then
            exit(false);
        // Solo el intervalo. "Activo" ya no participa: la baja de un concepto se expresa con
        // "Vigencia Hasta", que dice DESDE CUÁNDO deja de aplicarse, y un booleano no podía decir
        // eso — apagaba la versión en todo el tiempo, incluidas las liquidaciones ya calculadas que
        // la habían usado.
        exit(true);
    end;

    // Deja Rec filtrado a las versiones CANDIDATAS a FechaRef: las que ya arrancaron. El final de
    // vigencia NO se filtra acá y lo decide VigenteA sobre el registro elegido.
    //
    // Podría filtrarse, pero "en blanco O >= fecha" sobre un campo Date obliga a un token de fecha
    // vacía en el SetFilter, y esa forma no tiene ningún precedente en este proyecto: todos los
    // demás filtros de fecha son sobre campos obligatorios. Un filtro que no se comporte como uno
    // espera acá no falla ruidosamente — devuelve menos filas, ningún acumulador se inicializa, y
    // el cálculo revienta lejos del origen. Escanear unas filas de más es barato; esto no.
    //
    // Por eso TODO consumidor tiene que cerrar con VigenteA sobre el registro que eligió. Los que
    // arman un mapa (BuildLatestVersionCache, CargarVersionesVigentes) lo hacen al final, sobre la
    // versión ganadora; los que hacen FindLast lo hacen sobre el resultado.
    procedure FiltrarVigentesA(FechaRef: Date)
    begin
        SetFilter("Vigencia Desde", '<=%1', FechaRef);
    end;

    // ── Contigüidad y validación de la cadena de versiones ────────────────────

    local procedure ValidarIntervalo()
    begin
        if ("Vigencia Hasta" <> 0D) and ("Vigencia Hasta" < "Vigencia Desde") then
            Error(ErrIntervaloInvertido, "Vigencia Hasta", "Vigencia Desde");
    end;

    local procedure BuscarAnterior(var Anterior: Record "Concepto Liquidación"): Boolean
    begin
        Anterior.SetRange(Código, Código);
        Anterior.SetFilter("Vigencia Desde", '<%1', "Vigencia Desde");
        exit(Anterior.FindLast());
    end;

    local procedure BuscarSiguiente(var Siguiente: Record "Concepto Liquidación"): Boolean
    begin
        Siguiente.SetRange(Código, Código);
        Siguiente.SetFilter("Vigencia Desde", '>%1', "Vigencia Desde");
        exit(Siguiente.FindFirst());
    end;

    local procedure ValidarNoSuperponeConAnterior()
    var
        Anterior: Record "Concepto Liquidación";
    begin
        if not BuscarAnterior(Anterior) then
            exit;
        // Abierta: esta versión la releva, y SincronizarContiguidad la cierra el día previo.
        if Anterior."Vigencia Hasta" = 0D then
            exit;
        if Anterior."Vigencia Hasta" >= "Vigencia Desde" then
            Error(ErrSuperponeAnterior, Anterior."Vigencia Desde", Anterior."Vigencia Hasta", "Vigencia Desde");
    end;

    local procedure ValidarNoPisaSiguiente()
    var
        Siguiente: Record "Concepto Liquidación";
    begin
        if not BuscarSiguiente(Siguiente) then
            exit;
        // Dejarla abierta teniendo una posterior la haría pisar a esa y a todas las que vengan.
        if "Vigencia Hasta" = 0D then
            Error(ErrAbiertaConSiguiente, Siguiente."Vigencia Desde");
        if "Vigencia Hasta" >= Siguiente."Vigencia Desde" then
            Error(ErrSuperponeSiguiente, "Vigencia Hasta", Siguiente."Vigencia Desde");
    end;

    local procedure SincronizarContiguidad()
    var
        Anterior: Record "Concepto Liquidación";
        Siguiente: Record "Concepto Liquidación";
    begin
        // La versión nueva releva a la anterior solo si estaba abierta. Si ya tenía fecha de fin se
        // respeta tal cual: ese hueco es una decisión (cerrar en marzo, retomar en julio) y pisarlo
        // sería borrarla.
        if BuscarAnterior(Anterior) then
            if Anterior."Vigencia Hasta" = 0D then begin
                Anterior."Vigencia Hasta" := "Vigencia Desde" - 1;
                // Modify sin disparar triggers a propósito: es una fecha derivada, y pasar por
                // OnModify metería una entrada en el historial de fórmulas por un cambio que no
                // tocó ninguna fórmula.
                Anterior.Modify();
            end;

        // Versión intercalada entre otras dos: se cierra contra la que sigue, salvo que traiga una
        // fecha de fin propia.
        if "Vigencia Hasta" = 0D then
            if BuscarSiguiente(Siguiente) then
                "Vigencia Hasta" := Siguiente."Vigencia Desde" - 1;
    end;

    local procedure ReabrirAnteriorAlBorrar()
    var
        Anterior: Record "Concepto Liquidación";
        Siguiente: Record "Concepto Liquidación";
        NuevoFin: Date;
    begin
        if not BuscarAnterior(Anterior) then
            exit;
        // Solo se reabre la que ESTA versión había cerrado. Una fecha de fin anterior a nuestro
        // inicio es un cierre con intención propia y no se toca.
        if Anterior."Vigencia Hasta" <> "Vigencia Desde" - 1 then
            exit;
        if BuscarSiguiente(Siguiente) then
            NuevoFin := Siguiente."Vigencia Desde" - 1
        else
            NuevoFin := 0D;
        Anterior."Vigencia Hasta" := NuevoFin;
        Anterior.Modify();
    end;

    // Al mover el inicio de una versión, la anterior lo sigue solo si venía pegada al inicio viejo:
    // eso la identifica como cerrada por nosotros. Con cualquier otra fecha hay un hueco a mano.
    local procedure ReencadenarAnterior(InicioViejo: Date)
    var
        Anterior: Record "Concepto Liquidación";
    begin
        if not BuscarAnterior(Anterior) then
            exit;
        if Anterior."Vigencia Hasta" <> InicioViejo - 1 then
            exit;
        Anterior."Vigencia Hasta" := "Vigencia Desde" - 1;
        Anterior.Modify();
    end;

    // ── Verificación de uso ───────────────────────────────────────────────────

    local procedure ValidarSinUsoPosteriorA(FechaCorte: Date)
    var
        LinLiq: Record "Línea Liquidación";
    begin
        // Sin fecha de fin la versión sigue abierta: no hay nada que pueda quedar afuera.
        if FechaCorte = 0D then
            exit;
        if BuscarUso(LinLiq, Código, "Vigencia Desde", FechaCorte) then
            Error(ErrUsoPosterior, Código, "Vigencia Desde", FechaCorte,
                  LinLiq."No. Liquidación", LinLiq."Fecha Liquidación");
    end;

    /// <summary>
    /// Si al borrar esta versión el código deja de existir por completo.
    /// </summary>
    /// <remarks>
    /// Un concepto son varias versiones con la misma clave de código. Borrar UNA vigencia no borra el
    /// concepto, así que la limpieza de fraccionamientos y los controles de referencias sólo tienen
    /// sentido cuando se va la última: las fracciones tienen su propia línea de tiempo y no se
    /// corresponden una a una con las vigencias del concepto.
    /// </remarks>
    local procedure EsUltimaVigencia(): Boolean
    var
        Otra: Record "Concepto Liquidación";
    begin
        Otra.SetRange(Código, Código);
        Otra.SetFilter("Vigencia Desde", '<>%1', "Vigencia Desde");
        exit(Otra.IsEmpty());
    end;

    /// <summary>
    /// Impide borrar un concepto que otra fórmula o condición todavía nombra.
    /// </summary>
    /// <remarks>
    /// Ésta es la mitad cara del problema. Una fórmula que nombra una variable inexistente NO falla:
    /// el contexto la resuelve como cero y el concepto se calcula igual, con un número menor. Pasó
    /// con BASE_SS: se borró por obsoleto y la fórmula del acumulador de contribuciones patronales
    /// —round(MAX(0, BASE_SS - DED_CONT_PATR))— quedó dando cero, sin error y sin nada que lo delate
    /// hasta que alguien compare un recibo.
    ///
    /// Se valida al borrar y no al calcular porque acá se sabe qué se está sacando y se puede nombrar
    /// quién lo usa. En el cálculo ya es tarde: el valor cero es indistinguible de un cero legítimo.
    /// </remarks>
    local procedure ValidarNoReferenciadoEnFormulas()
    var
        Otro: Record "Concepto Liquidación";
    begin
        Otro.SetFilter(Código, '<>%1', Código);
        Otro.SetLoadFields(Código, "Vigencia Desde", Fórmula, Condición);
        if not Otro.FindSet() then
            exit;
        repeat
            if NombraAlCodigo(Otro.Fórmula) or NombraAlCodigo(Otro.Condición) then
                Error(ErrReferenciadoEnFormula, Código, Otro.Código, Otro."Vigencia Desde");
        until Otro.Next() = 0;
    end;

    /// <remarks>
    /// Compara el código como IDENTIFICADOR completo y no como texto suelto: buscar "BASE_SS" dentro
    /// de "BASE_SS_TRAB" daría un falso positivo y bloquearía borrados legítimos. Los caracteres que
    /// cortan un identificador son los mismos que reconoce el evaluador.
    /// </remarks>
    local procedure NombraAlCodigo(Texto: Text): Boolean
    var
        Pos: Integer;
        Largo: Integer;
    begin
        if (Texto = '') or (Código = '') then
            exit(false);
        Texto := UpperCase(Texto);
        Largo := StrLen(Código);
        Pos := StrPos(Texto, Código);
        while Pos > 0 do begin
            if not EsCaracterDeIdentificador(CopyStr(Texto, Pos - 1, 1)) then
                if not EsCaracterDeIdentificador(CopyStr(Texto, Pos + Largo, 1)) then
                    exit(true);
            Texto := CopyStr(Texto, Pos + Largo);
            Pos := StrPos(Texto, Código);
        end;
        exit(false);
    end;

    local procedure EsCaracterDeIdentificador(C: Text): Boolean
    begin
        if C = '' then
            exit(false);
        exit((C >= 'A') and (C <= 'Z') or ((C >= '0') and (C <= '9')) or (C = '_') or
             (C in ['Á', 'É', 'Í', 'Ó', 'Ú', 'Ñ', 'Ü']));
    end;

    /// <summary>
    /// Borra los fraccionamientos que quedan huérfanos al desaparecer el concepto.
    /// </summary>
    /// <remarks>
    /// Son dos roles distintos y hay que limpiar los dos: las fracciones por las que este concepto
    /// APORTA a otros acumuladores, y —si es acumulador— las de todos los conceptos que lo alimentan.
    /// El segundo caso es el que dejaba basura: borrar BASE_SS dejaba 144 filas apuntando a un
    /// acumulador inexistente, que seguían apareciendo en las exportaciones y en la subpágina de cada
    /// concepto como si la configuración siguiera viva.
    ///
    /// Se hace después de las validaciones: si alguna fórmula todavía lo nombra, el error corta antes
    /// y no se borra nada.
    /// </remarks>
    local procedure BorrarFraccionesHuerfanas()
    var
        Fraccion: Record "Fracción Acumulador";
    begin
        Fraccion.SetRange("Cód. Concepto", Código);
        Fraccion.DeleteAll();

        Fraccion.Reset();
        Fraccion.SetCurrentKey("Cód. Acumulador", "Vigencia Desde");
        Fraccion.SetRange("Cód. Acumulador", Código);
        Fraccion.DeleteAll();
    end;

    /// <summary>
    /// Se lleva las restricciones de convenio del concepto que se va.
    /// </summary>
    /// <remarks>
    /// La relación de tabla valida al insertar y al modificar, no al borrar: el concepto desaparece y
    /// sus filas de "Concepto CCT Vigente" quedan apuntando a un código que ya no existe. Sobrevivían
    /// calladas hasta que alguien intentaba importar el ConfigPackage, que sí valida la relación y
    /// rechaza la fila entera.
    ///
    /// Es el mismo agujero que dejaba el fraccionamiento antes de la 1.0.0.374, sólo que en la otra
    /// tabla: el concepto 1052 se borró y quedaron seis filas de convenio, dos de ellas además
    /// duplicadas entre sí.
    /// </remarks>
    local procedure BorrarConveniosHuerfanos()
    var
        CCTVig: Record "Concepto CCT Vigente";
    begin
        CCTVig.SetRange("Cód. Concepto", Código);
        CCTVig.DeleteAll();
    end;

    /// <summary>
    /// Impide borrar un concepto que alguna configuración nombra por código: variables de sistema,
    /// novedades sin liquidar, préstamos y los punteros de Config. Recursos Humanos.
    /// </summary>
    /// <remarks>
    /// Acá se BLOQUEA en vez de limpiar, al revés que con las fracciones y los convenios. La
    /// diferencia es de quién es el dato: una fracción o una restricción de convenio no significan
    /// nada sin su concepto, pero una variable de sistema, una novedad pendiente o el puntero del
    /// grossing-up son configuración que alguien cargó a propósito y que hay que reapuntar, no tirar.
    ///
    /// Sin esto el daño es el de siempre en este motor: silencioso. Un PERIODO_ACUM sobre un
    /// acumulador borrado devuelve cero y la fórmula sigue; el puntero de Config. RRHH apuntando a la
    /// nada apaga el grossing-up sin avisar.
    /// </remarks>
    local procedure ValidarNoReferenciadoPorConfiguracion()
    var
        VarSis: Record "Variable Sistema Liq.";
        Novedad: Record "Novedad Liquidación";
        Prestamo: Record "Préstamo Empleado";
        HRSetup: Record "Human Resources Setup";
    begin
        VarSis.SetRange("Cód. Acumulador", Código);
        if VarSis.FindFirst() then
            Error(ErrReferenciadoPorVarSis, Código, VarSis."Nombre Variable");

        Novedad.SetRange("Cód. Concepto", Código);
        if Novedad.FindFirst() then
            Error(ErrReferenciadoPorNovedad, Código, Novedad."Cód. Período");

        Prestamo.SetRange("Cód. Concepto Descuento", Código);
        if Prestamo.FindFirst() then
            Error(ErrReferenciadoPorPrestamo, Código, Prestamo."No.");

        if HRSetup.Get() then
            if Código in [HRSetup."Cód. Concepto Neto Garantizado", HRSetup."Cód. Acum. Haberes Gravados"] then
                Error(ErrReferenciadoPorSetup, Código);
    end;

    local procedure ValidarSinUsoAlguno(CodConcepto: Code[20]; Vig: Date)
    var
        LinLiq: Record "Línea Liquidación";
    begin
        if BuscarUso(LinLiq, CodConcepto, Vig, 0D) then
            Error(ErrVersionEnUso, CodConcepto, Vig, LinLiq."No. Liquidación");
    end;

    /// <summary>
    /// Valida la sintaxis de "Variable Cantidad" / "Variable Base" al cargarlas.
    /// </summary>
    /// <remarks>
    /// Los dos campos aceptan un nombre o una expresión, y se resuelven en modo tolerante para que un
    /// error de tipeo no corte una liquidación entera por un dato de presentación. El precio de esa
    /// tolerancia es que una expresión mal escrita se convierte en un cero silencioso, así que la
    /// sintaxis se revisa acá, cuando todavía hay alguien mirando la pantalla.
    ///
    /// Solo SINTAXIS: los nombres se validan solos —modo tolerante— porque el campo se carga muchas
    /// veces antes de que exista la variable o el concepto al que apunta.
    /// </remarks>
    local procedure ValidarExpresionPresentacion(Texto: Text; Etiqueta: Text)
    var
        Eval: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Dummy: Decimal;
    begin
        if Texto.Trim() = '' then
            exit;
        Eval.Init(Ctx, Today());
        Eval.SetLenientMode(true);
        if not Eval.TryEvalFormula(Texto, Dummy) then
            Error(ErrExpresionPresentacion, Etiqueta, GetLastErrorText());
    end;

    local procedure BuscarUso(var LinLiq: Record "Línea Liquidación"; CodConcepto: Code[20]; Vig: Date; PosteriorA: Date): Boolean
    begin
        LinLiq.SetCurrentKey("Cód. Concepto", "Vigencia Concepto", "Fecha Liquidación");
        LinLiq.SetRange("Cód. Concepto", CodConcepto);
        LinLiq.SetRange("Vigencia Concepto", Vig);
        if PosteriorA <> 0D then
            LinLiq.SetFilter("Fecha Liquidación", '>%1', PosteriorA);
        // Mismo criterio que Estado Empleado: una liquidación en Borrador se puede recalcular, así
        // que no bloquea. La línea replica el estado de la cabecera —Cod50019 lo sincroniza al
        // aprobar y al reabrir— por eso alcanza con mirar la línea y no hace falta el join.
        LinLiq.SetFilter(Estado, '<>%1', LinLiq.Estado::Borrador);
        exit(LinLiq.FindFirst());
    end;

    var
        ErrRenombrarCodigo: Label 'No se puede cambiar el código de un concepto (%1 → %2).\El código viaja en el texto de las fórmulas —@%1, #%1, o el nombre del acumulador— y ahí ningún renombre llega: las fórmulas que lo nombran pasarían a resolver CERO sin dar error. Además las liquidaciones ya calculadas lo guardan para poder reproducirse.\Usá "Copiar como..." para crear %2 con los mismos fraccionamientos y convenios, corregí las fórmulas que nombran a %1, y recién entonces dá de baja %1 cerrando su vigencia. Si %1 es un concepto recién creado y todavía no lo usa nada, es más simple borrarlo y crearlo con el código definitivo.', Comment = '%1 = código actual, %2 = código nuevo';
        ErrExpresionPresentacion: Label '%1 no se entiende como nombre de variable ni como expresión: %2', Comment = '%1=nombre del campo, %2=error del evaluador';
        ErrSintaxisFormula: Label 'La fórmula contiene un error de sintaxis: %1';
        ErrSintaxisCondicion: Label 'La condición contiene un error de sintaxis: %1';
        ErrVariableDesconocida: Label 'La fórmula hace referencia a variables que no existen en el sistema: %1';
        ErrIntervaloInvertido: Label 'La fecha de fin de vigencia (%1) no puede ser anterior al inicio (%2).';
        ErrSuperponeAnterior: Label 'La versión que arranca el %1 está vigente hasta el %2 y se superpone con la nueva vigencia del %3. Cerrá antes la versión anterior.';
        ErrSuperponeSiguiente: Label 'La fecha de fin %1 se superpone con la versión que arranca el %2.';
        ErrAbiertaConSiguiente: Label 'Esta versión no puede quedar con la vigencia abierta: existe una versión posterior que arranca el %1.';
        ErrUsoPosterior: Label 'No se puede cerrar el concepto %1 (versión %2) el %3: la liquidación %4, del %5, usó esta versión después de esa fecha. Cerralo en una fecha posterior o revertí esa liquidación.';
        ErrVersionEnUso: Label 'No se puede borrar ni mover la versión %2 del concepto %1: la usó la liquidación %3. Cerrá su vigencia en lugar de borrarla.';
        ErrReferenciadoEnFormula: Label 'No se puede borrar el concepto %1: la fórmula o la condición del concepto %2 (versión %3) todavía lo nombra.\\Si se borra igual, esa fórmula no da error: resuelve la variable como cero y el concepto se calcula de menos, sin que nada lo delate. Corregí primero esa fórmula.', Comment = '%1=concepto a borrar, %2=concepto que lo referencia, %3=vigencia';
        ErrReferenciadoPorVarSis: Label 'No se puede borrar el concepto %1: la variable de sistema %2 lo usa como acumulador.\\Si se borra igual, esa variable devuelve cero en toda formula que la nombre, sin dar error. Reapunta la variable primero.', Comment = '%1=concepto, %2=nombre de variable';
        ErrReferenciadoPorNovedad: Label 'No se puede borrar el concepto %1: hay novedades sin liquidar que lo usan (periodo %2).\\Al materializarse, esas novedades quedarian apuntando a un concepto inexistente. Borralas o cambiales el concepto.', Comment = '%1=concepto, %2=periodo';
        ErrReferenciadoPorPrestamo: Label 'No se puede borrar el concepto %1: el prestamo %2 lo tiene como concepto de descuento.\\Sus cuotas pendientes no se podrian aplicar. Cambia el concepto de descuento del prestamo primero.', Comment = '%1=concepto, %2=No. de prestamo';
        ErrReferenciadoPorSetup: Label 'No se puede borrar el concepto %1: Config. Recursos Humanos lo tiene cargado como Concepto Neto Garantizado o como Acumulador Haberes Gravados.\\Sin el, el grossing-up deja de aplicarse o Haberes Ordinarios Gravados queda en cero, en los dos casos sin avisar. Cambia primero el puntero en la configuracion.', Comment = '%1=concepto';

    // Builds a context dictionary with all currently configured variable names set to 1.
    // Used in pass-2 formula validation to detect unknown variable references at save time.
    local procedure BuildKnownVarsCtx(var Ctx: Dictionary of [Text, Decimal])
    var
        Param: Record "Parámetro";
        VarSis: Record "Variable Sistema Liq.";
        Fuente: Record "Fuente Datos Liquidación";
        Acum: Record "Concepto Liquidación";
    begin
        Clear(Ctx);
        Param.SetFilter("Nombre Variable", '<>%1', '');
        if Param.FindSet() then
            repeat
                if not Ctx.ContainsKey(Param."Nombre Variable") then
                    Ctx.Add(Param."Nombre Variable", 1);
                if not Ctx.ContainsKey(Param."Nombre Variable" + '_ESFCY') then
                    Ctx.Add(Param."Nombre Variable" + '_ESFCY', 1);
            until Param.Next() = 0;

        VarSis.SetRange(Activo, true);
        if VarSis.FindSet() then
            repeat
                if not Ctx.ContainsKey(VarSis."Nombre Variable") then
                    Ctx.Add(VarSis."Nombre Variable", 1);
            until VarSis.Next() = 0;

        Fuente.SetRange(Activo, true);
        if Fuente.FindSet() then
            repeat
                if not Ctx.ContainsKey(Fuente."Nombre Variable") then
                    Ctx.Add(Fuente."Nombre Variable", 1);
            until Fuente.Next() = 0;

        Acum.SetRange("Es Acumulador", true);
        if Acum.FindSet() then
            repeat
                if not Ctx.ContainsKey(Acum.Código) then
                    Ctx.Add(Acum.Código, 1);
            until Acum.Next() = 0;

        if not Ctx.ContainsKey('COD_ZONA') then Ctx.Add('COD_ZONA', 1);
        if not Ctx.ContainsKey('CANT_INCIDENCIA') then Ctx.Add('CANT_INCIDENCIA', 1);
        if not Ctx.ContainsKey('ES_JUBILADO') then Ctx.Add('ES_JUBILADO', 1);

        // Grossing-up variables injected at runtime by MotorLiquidación.InjectGUVariables
        if not Ctx.ContainsKey('ES_GROSSING_UP') then Ctx.Add('ES_GROSSING_UP', 1);
        if not Ctx.ContainsKey('NETO_GARANTIZADO') then Ctx.Add('NETO_GARANTIZADO', 1);
        if not Ctx.ContainsKey('NETO_GARANTIZADO_ESFCY') then Ctx.Add('NETO_GARANTIZADO_ESFCY', 1);
        if not Ctx.ContainsKey('COMPLEMENTO_GU') then Ctx.Add('COMPLEMENTO_GU', 1);
    end;

}
