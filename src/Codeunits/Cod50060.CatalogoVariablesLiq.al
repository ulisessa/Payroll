namespace UAS.Payroll;

codeunit 50064 "Catálogo Variables Liq."
{
    // Fuente ÚNICA de verdad sobre "qué puede referenciar una fórmula".
    //
    // Antes esto vivía repartido: la lista de funciones estaba escrita tres veces (BuildMatches y el
    // menú Insertar de la Pág. 50139, más el case de CallFunction en Cod50015) y ya se habían
    // desincronizado — REDONDEAR, PISO y TECHO existen en el motor pero no aparecían en el asistente.
    // Acá viven los metadatos de las funciones (firma, ayuda, plantilla de inserción) y el armado del
    // catálogo JSON que consume el editor con IntelliSense (controladdin "Editor Fórmula Liq.").
    //
    // Las VARIABLES no se leen de las tablas acá: se toman de la temporal "Variable Liq. Test" que ya
    // cargó la subpágina (Pág. 50140), que es exactamente el mismo diccionario que GetContext le pasa
    // al Evaluador. Así el valor que muestra el autocompletado nunca puede diferir del que usa el
    // cálculo — si se leyeran las tablas por separado, tarde o temprano divergen.

    var
        FFuncNombres: List of [Text];
        FFuncFirma: Dictionary of [Text, Text];
        FFuncAyuda: Dictionary of [Text, Text];
        FFuncArgs: Dictionary of [Text, Text]; // argumentos separados por '|'
        FFuncPrimerArgTexto: Dictionary of [Text, Boolean];
        FOpNombres: List of [Text];
        FOpAyuda: Dictionary of [Text, Text];
        FInicializado: Boolean;

    // ── API de funciones/operadores ───────────────────────────────────────────

    procedure GetNombresFunciones(): List of [Text]
    begin
        Inicializar();
        exit(FFuncNombres);
    end;

    procedure GetNombresOperadores(): List of [Text]
    begin
        Inicializar();
        exit(FOpNombres);
    end;

    procedure GetFirmaFuncion(Nombre: Text): Text
    begin
        Inicializar();
        if FFuncFirma.ContainsKey(Nombre.ToUpper()) then
            exit(FFuncFirma.Get(Nombre.ToUpper()));
        exit('');
    end;

    // ── Catálogo de variables ─────────────────────────────────────────────────

    /// <summary>
    /// Carga en Cat el catálogo completo de variables que una fórmula puede referenciar, leído de las
    /// tablas de configuración reales (nunca de una lista escrita a mano, así no se desactualiza al
    /// agregar parámetros, variables de sistema o fuentes de datos).
    /// </summary>
    /// <remarks>
    /// Vive en el codeunit y no en la página del asistente porque hay más de una pantalla con el
    /// editor con IntelliSense (asistente y ficha de concepto): duplicado, agregar una Fuente de
    /// Datos nueva la haría aparecer en una y no en la otra.
    /// Los valores son orientativos: reales para los parámetros que resuelvan con el
    /// convenio/categoría/empleado recibidos, 0 para todo lo que necesite una corrida del motor.
    /// </remarks>
    procedure CargarCatalogo(var Cat: Record "Variable Liq. Test" temporary; CodEmpleado: Code[20]; CodConvenio: Code[20]; CodCategoria: Code[20])
    var
        Param: Record "Parámetro";
        VarSis: Record "Variable Sistema Liq.";
        Fuente: Record "Fuente Datos Liquidación";
        Concepto: Record "Concepto Liquidación";
    begin
        // 1. Constantes que el motor inyecta por código (Cod50014 Inject*), no son dato de tabla.
        SetVarCat(Cat, 'COD_ZONA', 0, 'Zona desfavorable aplicada (de Proyecto, o Ficha Empleado si el proyecto no la tiene)', 'Sistema');
        SetVarCat(Cat, 'ES_JUBILADO', 0, 'Empleado jubilado a la fecha de referencia (1) o no (0)', 'Sistema');
        SetVarCat(Cat, 'ES_GROSSING_UP', 0, 'Liquidación con grossing-up activo (1) o no (0)', 'Sistema');
        SetVarCat(Cat, 'NETO_GARANTIZADO', 0, 'Neto garantizado objetivo del grossing-up', 'Sistema');
        SetVarCat(Cat, 'COMPLEMENTO_GU', 0, 'Complemento de grossing-up (se autoconverge en la liquidación real)', 'Sistema');
        SetVarCat(Cat, 'NETO_GARANTIZADO_ESFCY', 0, 'El neto garantizado está cargado en moneda extranjera (1) o local (0)', 'Sistema');

        // 2. Parámetros con Nombre Variable: valor vigente para el contexto recibido, si alcanza.
        Param.SetFilter("Nombre Variable", '<>%1', '');
        if Param.FindSet() then
            repeat
                SetVarCat(Cat, Param."Nombre Variable", GetParamConSufijo(Param, CodEmpleado, CodConvenio, CodCategoria), Param.Descripción, 'Parámetro');
                // Cada parámetro expone además un compañero <VAR>_ESFCY, que el motor inyecta al
                // lado del valor (ver Cod50016) para que la fórmula decida si multiplicar por el
                // tipo de cambio: IF(BASICO_ESFCY, BASICO * TC_CERCANO, BASICO).
                //
                // Faltaban en el catálogo, así que el editor los pintaba como variable desconocida
                // aunque el motor los resuelve perfecto. Es el mismo desajuste que el aviso de
                // mayúsculas en las funciones: el editor era más estricto que el evaluador.
                SetVarCat(Cat, Param."Nombre Variable" + SufijoMonedaTok,
                    GetParamEsFCY(Param, CodEmpleado, CodConvenio, CodCategoria),
                    StrSubstNo(TxtDescEsFCY, Param."Nombre Variable"), 'Parámetro');
            until Param.Next() = 0;

        // 3-5. Variables de sistema, fuentes de datos y acumuladores: necesitan una corrida del motor
        // para tener valor, así que se listan en 0 (el asistente los completa con "Cargar contexto").
        VarSis.SetRange(Activo, true);
        VarSis.SetFilter("Nombre Variable", '<>%1', '');
        if VarSis.FindSet() then
            repeat
                SetVarCat(Cat, VarSis."Nombre Variable", 0, VarSis.Descripción, 'Sistema');
            until VarSis.Next() = 0;

        Fuente.SetRange(Activo, true);
        if Fuente.FindSet() then
            repeat
                SetVarCat(Cat, Fuente."Nombre Variable", 0, Fuente.Descripción, 'Fuente Datos');
            until Fuente.Next() = 0;

        // Sin filtro de vigencia a propósito. Esto es un diccionario de NOMBRES, no el conjunto que
        // se ejecuta: lo consumen el IntelliSense y "Variables del cálculo", y esa segunda pantalla
        // resuelve las variables de liquidaciones viejas. Recortarlo a lo vigente hoy dejaba sin
        // descripción a los acumuladores discontinuados justo cuando se mira el cálculo que los usó.
        Concepto.SetRange("Es Acumulador", true);
        if Concepto.FindSet() then
            repeat
                SetVarCat(Cat, Concepto.Código, 0, 'Acumulador: ' + Concepto.Descripción, 'Acumulador');
            until Concepto.Next() = 0;
    end;

    /// <summary>Catálogo completo ya serializado, para pantallas que solo alimentan al editor.</summary>
    procedure BuildCatalogoCompletoJson(CodEmpleado: Code[20]; CodConvenio: Code[20]; CodCategoria: Code[20]): Text
    var
        Cat: Record "Variable Liq. Test" temporary;
    begin
        CargarCatalogo(Cat, CodEmpleado, CodConvenio, CodCategoria);
        exit(BuildCatalogoJson(Cat));
    end;

    /// <summary>Contexto de evaluación armado con los valores orientativos del catálogo.</summary>
    procedure BuildContextoCatalogo(CodEmpleado: Code[20]; CodConvenio: Code[20]; CodCategoria: Code[20]; var Ctx: Dictionary of [Text, Decimal])
    var
        Cat: Record "Variable Liq. Test" temporary;
    begin
        Clear(Ctx);
        CargarCatalogo(Cat, CodEmpleado, CodConvenio, CodCategoria);
        if Cat.FindSet() then
            repeat
                if not Ctx.ContainsKey(Cat.Nombre) then
                    Ctx.Add(Cat.Nombre, Cat.Valor);
            until Cat.Next() = 0;
    end;

    // Los tres textos se recortan ACÁ y no en cada llamada. Las descripciones se arman concatenando
    // datos de configuración —nombre de variable, descripción del concepto— que por sí solos ya
    // llegan al largo del campo, así que cualquier prefijo o plantilla los pasa. Con los parámetros
    // tipados el desborde explotaba en runtime desde el punto de llamada ("the length of the string
    // is 119..."), lejos del campo que en realidad desbordaba.
    //
    // La descripción es texto de ayuda: recortarla no pierde nada que no se pueda ver en la ficha
    // del parámetro o del concepto.
    local procedure SetVarCat(var Cat: Record "Variable Liq. Test" temporary; VarNombre: Text; VarValor: Decimal; VarDesc: Text; VarTipo: Text)
    var
        Nombre: Text[100];
        Desc: Text[100];
        Tipo: Text[20];
    begin
        Nombre := CopyStr(VarNombre, 1, MaxStrLen(Nombre));
        Desc := CopyStr(VarDesc, 1, MaxStrLen(Desc));
        Tipo := CopyStr(VarTipo, 1, MaxStrLen(Tipo));

        if Cat.Get(Nombre) then begin
            Cat.Valor := VarValor;
            Cat.Descripción := Desc;
            Cat.Tipo := Tipo;
            Cat.Modify();
        end else begin
            Cat.Init();
            Cat.Nombre := Nombre;
            Cat.Valor := VarValor;
            Cat.Descripción := Desc;
            Cat.Tipo := Tipo;
            Cat.Insert();
        end;
    end;

    // Réplica de la prioridad de sufijos del motor (Cod50016 LoadParametros): Sufijo Empleado →
    // Código_EMP, Sufijo CCT → Código_CONVENIO_CATEGORÍA, Sufijo Convenio → Código_CONVENIO, si no
    // el Código pelado. Devuelve 0 cuando el contexto recibido no tiene el sufijo que el parámetro
    // necesita — el nombre igual entra al catálogo, que es lo que le importa al autocompletado.
    // El armado del código efectivo está acá y no repetido en cada consumidor: el valor y la bandera
    // de moneda tienen que salir SIEMPRE de la misma fila de Parámetro Vigente, si no el catálogo
    // podría mostrar el importe de un sufijo y la moneda de otro.
    local procedure CodigoEfectivoParam(Param: Record "Parámetro"; CodEmpleado: Code[20]; CodConvenio: Code[20]; CodCategoria: Code[20]): Code[50]
    begin
        if Param."Sufijo Empleado" then begin
            if CodEmpleado = '' then exit('');
            exit(Param.Código + '_' + CodEmpleado);
        end;
        if Param."Sufijo CCT" then begin
            if (CodConvenio = '') or (CodCategoria = '') then exit('');
            exit(Param.Código + '_' + CodConvenio + '_' + CodCategoria);
        end;
        if Param."Sufijo Convenio" then begin
            if CodConvenio = '' then exit('');
            exit(Param.Código + '_' + CodConvenio);
        end;
        exit(Param.Código);
    end;

    local procedure GetParamConSufijo(Param: Record "Parámetro"; CodEmpleado: Code[20]; CodConvenio: Code[20]; CodCategoria: Code[20]): Decimal
    var
        CodigoEfectivo: Code[50];
    begin
        CodigoEfectivo := CodigoEfectivoParam(Param, CodEmpleado, CodConvenio, CodCategoria);
        if CodigoEfectivo = '' then
            exit(0);
        exit(GetParamVigente(CodigoEfectivo));
    end;

    // 1 = el valor vigente está cargado en moneda extranjera. Mismo criterio que Cod50016: lo define
    // que la fila de Parámetro Vigente tenga Moneda.
    local procedure GetParamEsFCY(Param: Record "Parámetro"; CodEmpleado: Code[20]; CodConvenio: Code[20]; CodCategoria: Code[20]): Decimal
    var
        ParamVig: Record "Parámetro Vigente";
        CodigoEfectivo: Code[50];
    begin
        CodigoEfectivo := CodigoEfectivoParam(Param, CodEmpleado, CodConvenio, CodCategoria);
        if CodigoEfectivo = '' then
            exit(0);
        ParamVig.SetCurrentKey("Cód. Parámetro", "Vigencia Desde");
        ParamVig.SetRange("Cód. Parámetro", CodigoEfectivo);
        ParamVig.SetFilter("Vigencia Desde", '<=%1', WorkDate());
        if ParamVig.FindLast() then
            if ParamVig.Moneda <> '' then
                exit(1);
        exit(0);
    end;

    local procedure GetParamVigente(CodigoEfectivo: Code[50]): Decimal
    var
        ParamVig: Record "Parámetro Vigente";
    begin
        // El Cód. Parámetro solo ya identifica la fila (por convención es base + sufijo); filtrar
        // además por Cód. Parámetro Base solo encontraría los parámetros sin sufijo.
        ParamVig.SetCurrentKey("Cód. Parámetro", "Vigencia Desde");
        ParamVig.SetRange("Cód. Parámetro", CodigoEfectivo);
        ParamVig.SetFilter("Vigencia Desde", '<=%1', WorkDate());
        if ParamVig.FindLast() then
            exit(ParamVig.Valor);
        exit(0);
    end;

    // ── Catálogo JSON para el control add-in ──────────────────────────────────

    procedure BuildCatalogoJson(var VarTest: Record "Variable Liq. Test" temporary): Text
    var
        Raiz: JsonObject;
        Json: Text;
    begin
        Inicializar();
        Raiz.Add('funciones', BuildFuncionesJson());
        Raiz.Add('operadores', BuildOperadoresJson());
        Raiz.Add('variables', BuildVariablesJson(VarTest));
        Raiz.Add('conceptos', BuildConceptosJson());
        Raiz.WriteTo(Json);
        exit(Json);
    end;

    local procedure BuildFuncionesJson(): JsonArray
    var
        Arr: JsonArray;
        Obj: JsonObject;
        ArgsArr: JsonArray;
        Nombre: Text;
        Arg: Text;
        Args: List of [Text];
    begin
        foreach Nombre in FFuncNombres do begin
            Clear(Obj);
            Clear(ArgsArr);
            Args := FFuncArgs.Get(Nombre).Split('|');
            foreach Arg in Args do
                if Arg <> '' then
                    ArgsArr.Add(Arg);
            Obj.Add('nombre', Nombre);
            Obj.Add('firma', FFuncFirma.Get(Nombre));
            Obj.Add('ayuda', FFuncAyuda.Get(Nombre));
            Obj.Add('args', ArgsArr);
            Obj.Add('primerArgTexto', FFuncPrimerArgTexto.ContainsKey(Nombre));
            Arr.Add(Obj);
        end;
        exit(Arr);
    end;

    local procedure BuildOperadoresJson(): JsonArray
    var
        Arr: JsonArray;
        Obj: JsonObject;
        Nombre: Text;
    begin
        foreach Nombre in FOpNombres do begin
            Clear(Obj);
            Obj.Add('nombre', Nombre);
            Obj.Add('ayuda', FOpAyuda.Get(Nombre));
            Arr.Add(Obj);
        end;
        exit(Arr);
    end;

    local procedure BuildVariablesJson(var VarTest: Record "Variable Liq. Test" temporary): JsonArray
    var
        Todas: Record "Variable Liq. Test" temporary;
        Arr: JsonArray;
        Obj: JsonObject;
    begin
        // El editor tiene que conocer TODAS las variables, pero la subpágina puede tener puesto un
        // filtro de búsqueda del usuario. Copy con ShareTable comparte los datos temporales y deja
        // limpiar filtros y marks sobre esta vista propia, sin tocar la del usuario.
        Todas.Copy(VarTest, true);
        Todas.Reset();
        Todas.MarkedOnly(false);
        if Todas.FindSet() then
            repeat
                Clear(Obj);
                Obj.Add('nombre', Todas.Nombre);
                Obj.Add('tipo', Todas.Tipo);
                Obj.Add('valor', Format(Todas.Valor, 0, '<Precision,2:2><Standard Format,0>'));
                Obj.Add('desc', Todas.Descripción);
                Arr.Add(Obj);
            until Todas.Next() = 0;
        exit(Arr);
    end;

    // Conceptos activos para autocompletar @CÓDIGO (reevalúa la fórmula del otro concepto) y
    // #CÓDIGO (lee el importe ya calculado). La clave primaria es (Código, Vigencia Desde), así que
    // recorriendo en orden natural la última descripción que se escribe por código es la de la
    // vigencia más reciente.
    local procedure BuildConceptosJson(): JsonArray
    var
        Concepto: Record "Concepto Liquidación";
        Descs: Dictionary of [Text, Text];
        Orden: List of [Text];
        Arr: JsonArray;
        Obj: JsonObject;
        Cod: Text;
    begin
        // Igual que arriba: es un mapa código → descripción y conviene que esté completo.
        if Concepto.FindSet() then
            repeat
                if Descs.ContainsKey(Concepto.Código) then
                    Descs.Set(Concepto.Código, Concepto.Descripción)
                else begin
                    Descs.Add(Concepto.Código, Concepto.Descripción);
                    Orden.Add(Concepto.Código);
                end;
            until Concepto.Next() = 0;

        foreach Cod in Orden do begin
            Clear(Obj);
            Obj.Add('codigo', Cod);
            Obj.Add('desc', Descs.Get(Cod));
            Arr.Add(Obj);
        end;
        exit(Arr);
    end;

    // ── Definición de funciones ───────────────────────────────────────────────

    // Espejo exacto del case de CallFunction (Cod50015). Si se agrega una función al motor, va acá:
    // el editor, el autocompletado y la ayuda de firma salen todos de esta lista.
    local procedure Inicializar()
    begin
        if FInicializado then
            exit;
        FInicializado := true;

        DefFunc('TRAMO', 'TRAMO(código, valor)', 'código|valor', AyudaTramo, true);
        DefFunc('ROUND', 'ROUND(valor, precisión)', 'valor|precisión', AyudaRound, false);
        DefFunc('REDONDEAR', 'REDONDEAR(valor, decimales)', 'valor|decimales', AyudaRedondear, false);
        DefFunc('ABS', 'ABS(valor)', 'valor', AyudaAbs, false);
        DefFunc('PISO', 'PISO(valor)', 'valor', AyudaPiso, false);
        DefFunc('TECHO', 'TECHO(valor)', 'valor', AyudaTecho, false);
        DefFunc('MIN', 'MIN(a, b)', 'a|b', AyudaMin, false);
        DefFunc('MAX', 'MAX(a, b)', 'a|b', AyudaMax, false);
        DefFunc('IF', 'IF(condición, si_verdadero, si_falso)', 'condición|si_verdadero|si_falso', AyudaIf, false);
        DefFunc('DIV', 'DIV(a, b)', 'a|b', AyudaDiv, false);

        DefOp('AND', AyudaAnd);
        DefOp('OR', AyudaOr);
        DefOp('NOT', AyudaNot);
    end;

    local procedure DefFunc(Nombre: Text; Firma: Text; Args: Text; Ayuda: Text; PrimerArgTexto: Boolean)
    begin
        FFuncNombres.Add(Nombre);
        FFuncFirma.Add(Nombre, Firma);
        FFuncArgs.Add(Nombre, Args);
        FFuncAyuda.Add(Nombre, Ayuda);
        if PrimerArgTexto then
            FFuncPrimerArgTexto.Add(Nombre, true);
    end;

    local procedure DefOp(Nombre: Text; Ayuda: Text)
    begin
        FOpNombres.Add(Nombre);
        FOpAyuda.Add(Nombre, Ayuda);
    end;

    var
        AyudaTramo: Label 'Consulta una tabla escalonada vigente. El código va entre comillas simples. Ej: TRAMO(''TAB_IMP_4CAT'', BASE_IG4 * 12)';
        AyudaRound: Label 'Redondea al múltiplo indicado. Ej: ROUND(x, 0.01) redondea a centavos.';
        AyudaRedondear: Label 'Redondea a la cantidad de decimales indicada. Ej: REDONDEAR(5473.286, 2) = 5473,29';
        AyudaAbs: Label 'Valor absoluto.';
        AyudaPiso: Label 'Entero inmediatamente menor o igual al valor.';
        AyudaTecho: Label 'Entero inmediatamente mayor o igual al valor.';
        AyudaMin: Label 'El menor de los dos valores.';
        AyudaMax: Label 'El mayor de los dos valores.';
        AyudaIf: Label 'Condicional. Solo se evalúa la rama elegida, así que un error en la rama descartada no se dispara.';
        AyudaDiv: Label 'División segura: devuelve 0 si el divisor es 0, en vez de error.';
        AyudaAnd: Label 'Conjunción lógica. Debe escribirse en mayúsculas.';
        AyudaOr: Label 'Disyunción lógica. Debe escribirse en mayúsculas.';
        AyudaNot: Label 'Negación lógica. Debe escribirse en mayúsculas.';
        SufijoMonedaTok: Label '_ESFCY', Locked = true;
        // Lo esencial va primero: si un nombre de variable largo hace que SetVarCat recorte, lo que
        // se pierde es el ejemplo, no el significado.
        TxtDescEsFCY: Label '1 = %1 está en moneda extranjera. Ej: IF(%1_ESFCY, %1 * TC_CERCANO, %1)';
}
