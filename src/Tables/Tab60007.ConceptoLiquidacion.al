namespace UAS.Payroll;

using Microsoft.Foundation.UOM;

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
                KnownCtx: Dictionary of [Text, Decimal];
                Dummy: Decimal;
                ErrTxt: Text;
            begin
                Rec.Fórmula := NormalizarTexto(Rec.Fórmula);
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
                KnownCtx: Dictionary of [Text, Decimal];
                Dummy: Boolean;
                ErrTxt: Text;
            begin
                Rec.Condición := NormalizarTexto(Rec.Condición);
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
            Caption = 'Activo';
            DataClassification = CustomerContent;
            InitValue = true;
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
        field(16; "Variable Cantidad"; Code[30])
        {
            Caption = 'Variable Cantidad';
            DataClassification = CustomerContent;
            // Name of the context variable that represents the quantity for this concept
            // (e.g. DIAS_VAC, TONELADAS, PROD_KN_L1). Printed alongside the amount on the payslip.
            // Leave blank when no quantity applies.
        }
        field(17; "Unidad Cantidad"; Code[10])
        {
            Caption = 'Unidad Cantidad';
            DataClassification = CustomerContent;
            TableRelation = "Unit of Measure".Code;
        }
        field(21; "Variable Base"; Code[30])
        {
            Caption = 'Variable Base';
            DataClassification = CustomerContent;
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
        // La anterior recupera el tramo que deja libre ésta; si no, borrar la última versión mataría
        // el concepto desde la fecha en que ésta arrancaba, sin que nada lo delate.
        ReabrirAnteriorAlBorrar();
        // Antes de borrar es la última oportunidad de conservar el texto que se va con la vigencia.
        HistorialMgt.RegistrarBaja(Rec);
    end;

    // Editar "Vigencia Desde" en la ficha es un rename, porque es parte de la clave primaria. Mover
    // el inicio reordena la cadena de versiones, así que hay que revalidar contra las vecinas nuevas.
    trigger OnRename()
    begin
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
        // "Activo" se evalúa acá, DESPUÉS de haber elegido la versión, y nunca en un SetRange antes
        // de elegirla: filtrado de entrada, una versión inactiva no daba de baja el concepto sino
        // que se volvía invisible, y el motor caía a la versión activa anterior y la seguía
        // ejecutando. Es transitorio — cuando "Activo" se retire queda solo el intervalo.
        exit(Activo);
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

    local procedure ValidarSinUsoAlguno(CodConcepto: Code[20]; Vig: Date)
    var
        LinLiq: Record "Línea Liquidación";
    begin
        if BuscarUso(LinLiq, CodConcepto, Vig, 0D) then
            Error(ErrVersionEnUso, CodConcepto, Vig, LinLiq."No. Liquidación");
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
        ErrSintaxisFormula: Label 'La fórmula contiene un error de sintaxis: %1';
        ErrSintaxisCondicion: Label 'La condición contiene un error de sintaxis: %1';
        ErrVariableDesconocida: Label 'La fórmula hace referencia a variables que no existen en el sistema: %1';
        ErrIntervaloInvertido: Label 'La fecha de fin de vigencia (%1) no puede ser anterior al inicio (%2).';
        ErrSuperponeAnterior: Label 'La versión que arranca el %1 está vigente hasta el %2 y se superpone con la nueva vigencia del %3. Cerrá antes la versión anterior.';
        ErrSuperponeSiguiente: Label 'La fecha de fin %1 se superpone con la versión que arranca el %2.';
        ErrAbiertaConSiguiente: Label 'Esta versión no puede quedar con la vigencia abierta: existe una versión posterior que arranca el %1.';
        ErrUsoPosterior: Label 'No se puede cerrar el concepto %1 (versión %2) el %3: la liquidación %4, del %5, usó esta versión después de esa fecha. Cerralo en una fecha posterior o revertí esa liquidación.';
        ErrVersionEnUso: Label 'No se puede borrar ni mover la versión %2 del concepto %1: la usó la liquidación %3. Cerrá su vigencia en lugar de borrarla.';

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
        if not Ctx.ContainsKey('ES_JUBILADO') then Ctx.Add('ES_JUBILADO', 1);

        // Grossing-up variables injected at runtime by MotorLiquidación.InjectGUVariables
        if not Ctx.ContainsKey('ES_GROSSING_UP') then Ctx.Add('ES_GROSSING_UP', 1);
        if not Ctx.ContainsKey('NETO_GARANTIZADO') then Ctx.Add('NETO_GARANTIZADO', 1);
        if not Ctx.ContainsKey('NETO_GARANTIZADO_ESFCY') then Ctx.Add('NETO_GARANTIZADO_ESFCY', 1);
        if not Ctx.ContainsKey('COMPLEMENTO_GU') then Ctx.Add('COMPLEMENTO_GU', 1);
    end;

    // Strips newlines and collapses extra spaces so the evaluator (single-line only) can parse the text.
    local procedure NormalizarTexto(Texto: Text): Text
    var
        CR: Char;
        LF: Char;
    begin
        CR := 13;
        LF := 10;
        Texto := Texto.Replace('' + CR + LF, ' ').Replace('' + CR, ' ').Replace('' + LF, ' ');
        while Texto.Contains('  ') do
            Texto := Texto.Replace('  ', ' ');
        exit(Texto.Trim());
    end;
}
