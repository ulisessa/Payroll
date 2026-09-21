namespace UAS.Payroll;
using Microsoft.Finance.GeneralLedger.Setup;

/// <summary>
/// Llena las tablas de staging desde los web services de NAV. Es el equivalente del procedimiento
/// SQL SincNAV_Traer, y como él, no escribe una sola fila en Job, Employee ni las descargas: eso
/// sigue siendo tarea de "Sinc NAV Liq.".
/// </summary>
/// <remarks>
/// EL RELOJ ES EL CHANGE LOG DE NAV, y no se parece al del transporte por SQL. Allá la marca de agua
/// es el rowversion de cada tabla; acá es el `Entry_No` del registro de cambios, que es uno solo
/// para todas las tablas. Se guarda igual en "Ctrl Sinc NAV"."Marca Agua", pero significa otra cosa,
/// así que cambiar de transporte exige vaciarla: un rowversion leído como Entry_No no da error, da
/// un número enorme que deja todo afuera.
///
/// EL ORDEN DEL FILTRO NO ES ESTÉTICO. El Change Log tiene 14,5 millones de filas y no hay índice
/// útil por `Table_No`: filtrar primero por tabla tarda más de dos minutos y a veces no vuelve.
/// Filtrando primero por `Entry_No gt (marca)` la clave primaria acota el conjunto y recién ahí el
/// `Table_No` elige. Por eso la marca de agua no es sólo el reloj: es lo que hace viable la consulta.
///
/// Y POR ESO LA MARCA INICIAL SE PLANTA ANTES DEL BARRIDO. Al empezar de cero se lee el `Entry_No`
/// máximo —consulta por clave primaria, instantánea—, se guarda, y DESPUÉS se hace la carga
/// completa. Al revés, todo lo que cambie durante el barrido queda entre la foto y la marca, y no
/// lo trae ni esa corrida ni la siguiente: faltan filas y nada lo avisa.
///
/// LO QUE NO PUEDE HACER: traer lo que pasó antes de que el Change Log estuviera activo para esa
/// tabla. Para eso está la carga inicial, que ignora el registro de cambios y barre el entity set
/// entero.
/// </remarks>
codeunit 110041 "Traer NAV WS"
{
    Access = Internal;

    var
        Cliente: Codeunit "Cliente NAV WS";
        Cfg: Record "Config Sinc NAV";
        UltimoError: Text;
        MotivoFila: Text;
        TxtSinEntidad: Label 'La entidad %1 no tiene entity set configurado, así que no se trae por web services.', Comment = '%1 = entidad';
        TxtSinTabla: Label 'La entidad %1 no tiene número de tabla de NAV configurado: sin eso no se puede leer su registro de cambios.', Comment = '%1 = entidad';
        TxtEstadoDesconocido: Label 'NAV devolvió el estado "%1" para el proyecto %2 y no está en la lista de equivalencias. Si la instancia de NAV cambió de idioma, hay que actualizar EstadoProyectoDesdeTexto.', Comment = '%1 = texto; %2 = proyecto';
        TxtTipoDesconocido: Label 'NAV devolvió el tipo "%1" para el proyecto %2 y no está en la lista de equivalencias.', Comment = '%1 = texto; %2 = proyecto';

    procedure GetUltimoError(): Text
    begin
        exit(UltimoError);
    end;

    /// <summary>
    /// Trae una entidad. Devuelve cuántas filas quedaron en staging; -1 si falló.
    /// </summary>
    procedure TraerEntidad(EmpresaBC: Text[30]; Entidad: Enum "Entidad Sinc NAV") Filas: Integer
    var
        Ctrl: Record "Ctrl Sinc NAV";
        Claves: List of [Text];
        Bajas: List of [Text];
        MarcaDesde: BigInteger;
        MarcaNueva: BigInteger;
        EntitySet: Text;
    begin
        UltimoError := '';

        if not Cliente.SetEmpresa(EmpresaBC) then begin
            UltimoError := Cliente.GetUltimoError();
            exit(-1);
        end;
        Cfg.Get(EmpresaBC);

        if not Ctrl.ObtenerHabilitada(Entidad) then
            exit(0);

        // LAS DOS ENTIDADES DE DESCARGA SE TRAEN DE UN SOLO PEDIDO. DetalleDescargas devuelve
        // cabecera y línea juntas en una fila plana, así que pedirlas por separado sería traer las
        // mismas 240.000 filas dos veces. La cabecera hace todo el trabajo —incluido leer el
        // registro de cambios de las DOS tablas de NAV, porque una línea puede cambiar sin que
        // cambie su cabecera— y mueve las dos marcas de agua.
        if Entidad = Entidad::"Descarga Linea" then
            exit(0);

        EntitySet := EntitySetDe(Entidad);
        if EntitySet = '' then begin
            UltimoError := StrSubstNo(TxtSinEntidad, Entidad);
            exit(-1);
        end;

        MarcaDesde := 0;
        if Ctrl."Marca Agua" <> '' then
            if not Evaluate(MarcaDesde, Ctrl."Marca Agua") then
                MarcaDesde := 0;

        if MarcaDesde = 0 then
            Filas := CargaInicial(Entidad, EntitySet, MarcaNueva)
        else
            Filas := Delta(Entidad, EntitySet, MarcaDesde, MarcaNueva, Claves, Bajas);

        if Filas < 0 then
            exit(-1);

        // La marca se mueve SÓLO si todo salió bien. Si algo falló a mitad de camino queda donde
        // estaba y la corrida siguiente vuelve a pedir lo mismo: repetir es inofensivo —el llenado
        // del staging es idempotente— y saltear no lo es.
        RegistrarTraida(Entidad, MarcaNueva, Filas);
        exit(Filas);
    end;

    // ────────────────────────────────────────────────────────────────────────────────────────────
    //  Los dos modos
    // ────────────────────────────────────────────────────────────────────────────────────────────

    local procedure CargaInicial(Entidad: Enum "Entidad Sinc NAV"; EntitySet: Text; var MarcaNueva: BigInteger) Filas: Integer
    var
        Datos: JsonArray;
    begin
        // Primero la marca, después los datos. Ver el remarks de la codeunit: al revés se pierden
        // en silencio los cambios ocurridos durante el barrido.
        if not LeerMarcaMaxima(MarcaNueva) then
            exit(-1);

        if not Cliente.ObtenerTodo(EntitySet + FiltroInicialDe(Entidad), Datos) then begin
            UltimoError := Cliente.GetUltimoError();
            exit(-1);
        end;

        exit(Volcar(Entidad, Datos));
    end;

    /// <summary>
    /// Filtro que acota el barrido inicial de una entidad. Vacío significa traer todo.
    /// </summary>
    /// <remarks>
    /// Sólo los valores de dimensión lo necesitan, y no es una optimización: el catálogo de NAV
    /// tiene dimensiones que a BC no le corresponden —CARPETA IMPORTACION, entre otras— y traerlas
    /// sería importar dimensiones que nadie pidió.
    ///
    /// Los tres códigos salen de la configuración contable de BC, no escritos acá: atarlos a que la
    /// dimensión se llame DEPARTAMENTO y MAREA/CIUDAD es el supuesto que falla en la empresa número
    /// dos. El filtro va por Dimension_Code, que es texto plano y no depende del idioma; el tipo
    /// (Estándar) se descarta después, al volcar.
    /// </remarks>
    local procedure FiltroInicialDe(Entidad: Enum "Entidad Sinc NAV"): Text
    var
        GLSetup: Record "General Ledger Setup";
        Filtro: Text;
    begin
        if Entidad <> Entidad::"Valor Dimension" then
            exit('');

        GLSetup.Get();
        Filtro := CondicionDim(GLSetup."Global Dimension 1 Code");
        Filtro := UnirO(Filtro, CondicionDim(GLSetup."Global Dimension 2 Code"));
        Filtro := UnirO(Filtro, CondicionDim(GLSetup."Shortcut Dimension 3 Code"));

        if Filtro = '' then
            exit('');
        exit('?$filter=' + Filtro);
    end;

    local procedure CondicionDim(Codigo: Code[20]): Text
    begin
        if Codigo = '' then
            exit('');
        exit(StrSubstNo('Dimension_Code eq ''%1''', Escapar(Codigo)));
    end;

    local procedure UnirO(Acumulado: Text; Nuevo: Text): Text
    begin
        if Nuevo = '' then
            exit(Acumulado);
        if Acumulado = '' then
            exit(Nuevo);
        exit(Acumulado + ' or ' + Nuevo);
    end;

    local procedure Delta(Entidad: Enum "Entidad Sinc NAV"; EntitySet: Text; MarcaDesde: BigInteger; var MarcaNueva: BigInteger; var Claves: List of [Text]; var Bajas: List of [Text]) Filas: Integer
    var
        Datos: JsonArray;
    begin
        if not ClavesCambiadas(Entidad, MarcaDesde, Claves, Bajas, MarcaNueva) then
            exit(-1);

        if Claves.Count() = 0 then
            exit(0);

        if not TraerPorClaves(EntitySet, Entidad, Claves, Datos) then
            exit(-1);

        exit(Volcar(Entidad, Datos));
    end;

    // ────────────────────────────────────────────────────────────────────────────────────────────
    //  El Change Log
    // ────────────────────────────────────────────────────────────────────────────────────────────

    local procedure LeerMarcaMaxima(var Marca: BigInteger): Boolean
    var
        Filas: JsonArray;
        Fila: JsonToken;
        Siguiente: Text;
    begin
        Marca := 0;

        // Por clave primaria descendente: es instantáneo aunque la tabla tenga 14 millones de filas.
        if not Cliente.ObtenerPagina(Cfg."Entidad Change Log" + '?$top=1&$orderby=Entry_No desc', Filas, Siguiente) then begin
            UltimoError := Cliente.GetUltimoError();
            exit(false);
        end;

        if Filas.Count() = 0 then
            exit(true);

        Filas.Get(0, Fila);
        Marca := EnteroGrandeDe(Fila.AsObject(), 'Entry_No');
        exit(true);
    end;

    local procedure ClavesCambiadas(Entidad: Enum "Entidad Sinc NAV"; MarcaDesde: BigInteger; var Claves: List of [Text]; var Bajas: List of [Text]; var MarcaNueva: BigInteger): Boolean
    var
        Movs: JsonArray;
        Mov: JsonToken;
        Obj: JsonObject;
        TablaNo: Integer;
        Clave: Text;
        Entrada: BigInteger;
        i: Integer;
    begin
        Clear(Claves);
        Clear(Bajas);
        MarcaNueva := MarcaDesde;

        TablaNo := TablaNAVDe(Entidad);
        if TablaNo = 0 then begin
            UltimoError := StrSubstNo(TxtSinTabla, Entidad);
            exit(false);
        end;

        // EL Entry_No VA PRIMERO EN EL FILTRO. Ver el remarks: al revés la consulta escanea la tabla
        // entera y tarda minutos.
        if not Cliente.ObtenerTodo(
               StrSubstNo('%1?$filter=Entry_No gt %2 and (%3)&$orderby=Entry_No',
                          Cfg."Entidad Change Log", MarcaDesde, CondicionTablas(Entidad)), Movs) then begin
            UltimoError := Cliente.GetUltimoError();
            exit(false);
        end;

        for i := 0 to Movs.Count() - 1 do begin
            Movs.Get(i, Mov);
            Obj := Mov.AsObject();

            Entrada := EnteroGrandeDe(Obj, 'Entry_No');
            if Entrada > MarcaNueva then
                MarcaNueva := Entrada;

            // El Change Log registra UN MOVIMIENTO POR CAMPO, así que una modificación de tres
            // campos deja tres filas con la misma clave. Lo que interesa es el conjunto de claves
            // tocadas, no cuántas veces: de ahí el control de repetidos.
            // LA CLAVE PUEDE SER COMPUESTA. El Change Log la parte en Primary_Key_Field_1..3, y
            // cuántas partes miramos depende de la entidad: para valores de dimensión hacen falta
            // las dos (dimensión + código), porque el mismo código existe en dimensiones distintas
            // y filtrar sólo por código traería valores de dimensiones que nadie pidió. Para las
            // descargas alcanza el proyecto: se vuelve a pedir la descarga entera, que es lo que
            // queremos igual.
            Clave := TextoDe(Obj, 'Primary_Key_Field_1_Value');
            if ClaveEsCompuesta(Entidad) then
                Clave := Clave + SeparadorClave() + TextoDe(Obj, 'Primary_Key_Field_2_Value');

            if Clave <> '' then
                if EsBaja(TextoDe(Obj, 'Type_of_Change')) then begin
                    if not Bajas.Contains(Clave) then
                        Bajas.Add(Clave);
                end else
                    if not Claves.Contains(Clave) then
                        Claves.Add(Clave);
        end;

        exit(true);
    end;

    /// <summary>
    /// Pide al origen las filas de las claves indicadas, de a tandas.
    /// </summary>
    /// <remarks>
    /// De a tandas y no de a una porque una llamada HTTP por clave, con doscientos cambios, son
    /// doscientos viajes. Y de a tandas y no todas juntas porque el filtro viaja en la URL y una URL
    /// muy larga la rechaza el servidor con un 400 que no explica nada.
    /// </remarks>
    local procedure TraerPorClaves(EntitySet: Text; Entidad: Enum "Entidad Sinc NAV"; Claves: List of [Text]; var Datos: JsonArray): Boolean
    var
        Tanda: JsonArray;
        Token: JsonToken;
        Filtro: Text;
        Clave: Text;
        EnTanda: Integer;
        i: Integer;
        j: Integer;
    begin
        Clear(Datos);

        foreach Clave in Claves do begin
            if Filtro <> '' then
                Filtro += ' or ';
            Filtro += CondicionDeClave(Entidad, Clave);
            EnTanda += 1;

            if EnTanda >= TamanoTanda() then begin
                if not PedirTanda(EntitySet, Filtro, Tanda) then
                    exit(false);
                for i := 0 to Tanda.Count() - 1 do begin
                    Tanda.Get(i, Token);
                    Datos.Add(Token);
                end;
                Filtro := '';
                EnTanda := 0;
            end;
        end;

        if Filtro <> '' then begin
            if not PedirTanda(EntitySet, Filtro, Tanda) then
                exit(false);
            for j := 0 to Tanda.Count() - 1 do begin
                Tanda.Get(j, Token);
                Datos.Add(Token);
            end;
        end;

        exit(true);
    end;

    local procedure PedirTanda(EntitySet: Text; Filtro: Text; var Tanda: JsonArray): Boolean
    begin
        if not Cliente.ObtenerTodo(EntitySet + '?$filter=' + Filtro, Tanda) then begin
            UltimoError := Cliente.GetUltimoError();
            exit(false);
        end;
        exit(true);
    end;

    local procedure TamanoTanda(): Integer
    begin
        exit(25);
    end;

    // ────────────────────────────────────────────────────────────────────────────────────────────
    //  Volcado a staging
    // ────────────────────────────────────────────────────────────────────────────────────────────

    local procedure Volcar(Entidad: Enum "Entidad Sinc NAV"; Datos: JsonArray) Filas: Integer
    begin
        case Entidad of
            Entidad::Proyecto:
                exit(VolcarProyectos(Datos));
            Entidad::Empleado:
                exit(VolcarEmpleados(Datos));
            Entidad::"Valor Dimension":
                exit(VolcarValoresDim(Datos));
            Entidad::"Descarga Cabecera":
                exit(VolcarDescargas(Datos));
            Entidad::"Informe Cap Cabecera":
                exit(VolcarInformeCapCab(Datos));
            Entidad::"Informe Cap Linea":
                exit(VolcarInformeCapLin(Datos));
            Entidad::"Dia Abordo Cabecera":
                exit(VolcarDiaAbordoCab(Datos));
            Entidad::"Dia Abordo Linea":
                exit(VolcarDiaAbordoLin(Datos));
        end;
        exit(0);
    end;

    local procedure VolcarDiaAbordoCab(Datos: JsonArray) Filas: Integer
    var
        Stg: Record "Stg Dia Abordo Cab NAV";
        Token: JsonToken;
        Obj: JsonObject;
        NoProyecto: Code[20];
        i: Integer;
    begin
        for i := 0 to Datos.Count() - 1 do begin
            Datos.Get(i, Token);
            Obj := Token.AsObject();

            NoProyecto := CopyStr(TextoDe(Obj, 'Cód_Proyecto'), 1, MaxStrLen(Stg."No Proyecto"));
            if NoProyecto <> '' then begin
                if not Stg.Get(NoProyecto) then begin
                    Stg.Init();
                    Stg."No Proyecto" := NoProyecto;
                    Stg.Insert();
                end;

                Stg.Buque := CopyStr(TextoDe(Obj, 'Buque'), 1, MaxStrLen(Stg.Buque));
                Stg.Marea := CopyStr(TextoDe(Obj, 'Marea'), 1, MaxStrLen(Stg.Marea));
                Stg.Patron := CopyStr(TextoDe(Obj, 'Patrón'), 1, MaxStrLen(Stg.Patron));
                Stg."Zona Pesca" := CopyStr(TextoDe(Obj, 'Zona_de_pesca'), 1, MaxStrLen(Stg."Zona Pesca"));
                Stg."Fecha Salida" := FechaDe(Obj, 'Fecha_Salida');
                Stg.Historico := FechaDe(Obj, 'Histórico');

                Stg."Estado Sinc" := "Estado Sinc NAV"::Pendiente;
                Stg.Observacion := '';
                Stg.Intentos := 0;
                Stg."Traido El" := CurrentDateTime();
                Stg.Modify();
                Filas += 1;
            end;
        end;
    end;

    /// <summary>
    /// La producción día por día del parte de pesca.
    /// </summary>
    /// <remarks>
    /// UN DÍA EN PUERTO TRAE CANTIDAD Y KILOS EN CERO, y eso no es una fila vacía que convenga
    /// descartar: es la afirmación de que ese día no se produjo. Descartarla haría que el día
    /// desapareciera del parte, y quien después sume producción entre dos fechas no notaría la
    /// diferencia entre "no pescó" y "no hay dato".
    /// </remarks>
    local procedure VolcarDiaAbordoLin(Datos: JsonArray) Filas: Integer
    var
        Stg: Record "Stg Dia Abordo Lin NAV";
        Token: JsonToken;
        Obj: JsonObject;
        NoProyecto: Code[20];
        LineNo: Integer;
        i: Integer;
    begin
        for i := 0 to Datos.Count() - 1 do begin
            Datos.Get(i, Token);
            Obj := Token.AsObject();

            NoProyecto := CopyStr(TextoDe(Obj, 'Cód_proyecto'), 1, MaxStrLen(Stg."No Proyecto"));
            LineNo := EnteroDe(Obj, 'No_línea');
            if NoProyecto <> '' then begin
                if not Stg.Get(NoProyecto, LineNo) then begin
                    Stg.Init();
                    Stg."No Proyecto" := NoProyecto;
                    Stg."Line No" := LineNo;
                    Stg.Insert();
                end;

                Stg."Fecha Registro" := FechaDe(Obj, 'Fecha_registro');
                Stg.Concepto := CopyStr(TextoDe(Obj, 'Concepto'), 1, MaxStrLen(Stg.Concepto));
                // El "No." del producto: el símbolo de ordinal no vale como identificador y NAV lo
                // codifica. Los acentos, en cambio, viajan tal cual.
                Stg.Producto := CopyStr(TextoDe(Obj, 'N_x00BA_'), 1, MaxStrLen(Stg.Producto));
                Stg.Descripcion := CopyStr(TextoDe(Obj, 'Descripción'), 1, MaxStrLen(Stg.Descripcion));
                Stg.Cantidad := DecimalDe(Obj, 'Cantidad');
                Stg.Kilos := DecimalDe(Obj, 'Kilos');
                Stg."Unidad Medida Desc" := CopyStr(TextoDe(Obj, 'Descripción_Unidad_Medida'), 1, MaxStrLen(Stg."Unidad Medida Desc"));
                Stg."Zona Pesca" := CopyStr(TextoDe(Obj, 'Zona_de_pesca'), 1, MaxStrLen(Stg."Zona Pesca"));
                Stg.Enviado := BooleanoDe(Obj, 'Enviado');

                Stg."Estado Sinc" := "Estado Sinc NAV"::Pendiente;
                Stg.Observacion := '';
                Stg.Intentos := 0;
                Stg."Traido El" := CurrentDateTime();
                Stg.Modify();
                Filas += 1;
            end;
        end;
    end;

    /// <summary>
    /// La cabecera del informe del capitán: una por marea.
    /// </summary>
    /// <remarks>
    /// EL SIGNO N° VIAJA CODIFICADO. El campo se llama "N°. proyecto" en NAV y OData lo expone como
    /// `N_x00B0__proyecto` — B0 es el código del carácter de grado. Buscarlo por su nombre legible
    /// devuelve vacío sin fallar, que acá significaría cero filas y ningún error.
    ///
    /// `Cantidad` es un FlowField en NAV: la suma de las líneas. Se guarda igual, como control — si
    /// después no coincide con lo que suman las líneas que llegaron, es que faltaron líneas.
    /// </remarks>
    local procedure VolcarInformeCapCab(Datos: JsonArray) Filas: Integer
    var
        Stg: Record "Stg Informe Cap Cab NAV";
        Token: JsonToken;
        Obj: JsonObject;
        NoProyecto: Code[20];
        i: Integer;
    begin
        for i := 0 to Datos.Count() - 1 do begin
            Datos.Get(i, Token);
            Obj := Token.AsObject();

            NoProyecto := CopyStr(TextoDe(Obj, 'N_x00B0__proyecto'), 1, MaxStrLen(Stg."No Proyecto"));
            if NoProyecto <> '' then begin
                if not Stg.Get(NoProyecto) then begin
                    Stg.Init();
                    Stg."No Proyecto" := NoProyecto;
                    Stg.Insert();
                end;

                Stg.Capitan := CopyStr(TextoDe(Obj, 'Capitán'), 1, MaxStrLen(Stg.Capitan));
                Stg.Actividad := CopyStr(TextoDe(Obj, 'Actividad'), 1, MaxStrLen(Stg.Actividad));
                Stg."Fecha Inicio Descarga" := FechaDe(Obj, 'Fecha_de_inicio_de_descarga');
                Stg.Cantidad := DecimalDe(Obj, 'Cantidad');

                Stg."Estado Sinc" := "Estado Sinc NAV"::Pendiente;
                Stg.Observacion := '';
                Stg.Intentos := 0;
                Stg."Traido El" := CurrentDateTime();
                Stg.Modify();
                Filas += 1;
            end;
        end;
    end;

    /// <summary>
    /// El detalle del informe: una fila por clasificación declarada en la marea.
    /// </summary>
    local procedure VolcarInformeCapLin(Datos: JsonArray) Filas: Integer
    var
        Stg: Record "Stg Informe Cap Lin NAV";
        Token: JsonToken;
        Obj: JsonObject;
        NoProyecto: Code[20];
        LineNo: Integer;
        i: Integer;
    begin
        for i := 0 to Datos.Count() - 1 do begin
            Datos.Get(i, Token);
            Obj := Token.AsObject();

            NoProyecto := CopyStr(TextoDe(Obj, 'N_x00B0__proyecto'), 1, MaxStrLen(Stg."No Proyecto"));
            LineNo := EnteroDe(Obj, 'N_x00B0__línea');
            if NoProyecto <> '' then begin
                if not Stg.Get(NoProyecto, LineNo) then begin
                    Stg.Init();
                    Stg."No Proyecto" := NoProyecto;
                    Stg."Line No" := LineNo;
                    Stg.Insert();
                end;

                Stg.Clasificacion := CopyStr(TextoDe(Obj, 'Clasificación'), 1, MaxStrLen(Stg.Clasificacion));
                Stg.Descripcion := CopyStr(TextoDe(Obj, 'Descripción'), 1, MaxStrLen(Stg.Descripcion));
                Stg."Unidad Medida" := CopyStr(TextoDe(Obj, 'Unidad_medida'), 1, MaxStrLen(Stg."Unidad Medida"));
                Stg.Cantidad := DecimalDe(Obj, 'Cantidad');

                Stg."Estado Sinc" := "Estado Sinc NAV"::Pendiente;
                Stg.Observacion := '';
                Stg.Intentos := 0;
                Stg."Traido El" := CurrentDateTime();
                Stg.Modify();
                Filas += 1;
            end;
        end;
    end;

    /// <summary>
    /// Parte la fila plana de DetalleDescargas en cabecera y línea.
    /// </summary>
    /// <remarks>
    /// CUIDADO CON LOS CAMPOS DUPLICADOS. La Query trae Buque, Marea, Puerto, Location y Actividad
    /// DOS veces: sin sufijo son los de la CABECERA y con sufijo "Detalle" los de la LÍNEA. Usar los
    /// de cabecera para la línea no da error —son códigos válidos y casi siempre coinciden— pero el
    /// día que una línea tenga otra cámara o otra actividad, queda mal y nadie lo ve.
    ///
    /// La cabecera se escribe una sola vez por proyecto aunque vengan ochenta líneas: la clave de
    /// Cab. descarga es sólo el proyecto. Escribirla en cada línea daría el mismo resultado y
    /// ochenta veces el trabajo.
    /// </remarks>
    local procedure VolcarDescargas(Datos: JsonArray) Filas: Integer
    var
        Cab: Record "Stg Descarga Cab NAV";
        Lin: Record "Stg Descarga Lin NAV";
        Token: JsonToken;
        Obj: JsonObject;
        Hechas: List of [Text];
        NoProyecto: Code[20];
        LineNo: Integer;
        i: Integer;
    begin
        for i := 0 to Datos.Count() - 1 do begin
            Datos.Get(i, Token);
            Obj := Token.AsObject();

            NoProyecto := CopyStr(TextoDe(Obj, 'N_proyecto'), 1, MaxStrLen(Cab."No Proyecto"));
            if NoProyecto <> '' then begin
                if not Hechas.Contains(NoProyecto) then begin
                    Hechas.Add(NoProyecto);

                    if not Cab.Get(NoProyecto) then begin
                        Cab.Init();
                        Cab."No Proyecto" := NoProyecto;
                        Cab.Insert();
                    end;

                    Cab.Capitan := CopyStr(TextoDe(Obj, 'Capitán'), 1, MaxStrLen(Cab.Capitan));
                    Cab.Actividad := CopyStr(TextoDe(Obj, 'Actividad'), 1, MaxStrLen(Cab.Actividad));
                    Cab."Fecha Inicio Descarga" := FechaDe(Obj, 'Fecha_de_inicio_de_descarga');
                    Cab.Buque := CopyStr(TextoDe(Obj, 'Buque'), 1, MaxStrLen(Cab.Buque));
                    Cab.Marea := CopyStr(TextoDe(Obj, 'Marea'), 1, MaxStrLen(Cab.Marea));
                    Cab."Cod Camara" := CopyStr(TextoDe(Obj, 'Location'), 1, MaxStrLen(Cab."Cod Camara"));
                    Cab."Libro Diario" := CopyStr(TextoDe(Obj, 'Libro_Diario'), 1, MaxStrLen(Cab."Libro Diario"));
                    Cab.Puerto := CopyStr(TextoDe(Obj, 'Puerto'), 1, MaxStrLen(Cab.Puerto));
                    Cab."Hora Inicio Descarga" := HoraDe(Obj, 'Hora_inicio_descarga');
                    Cab."Hora Fin Descarga" := HoraDe(Obj, 'Hora_fin_descarga');
                    Cab."Cod Balanza" := CopyStr(TextoDe(Obj, 'Scale_code'), 1, MaxStrLen(Cab."Cod Balanza"));
                    Cab.Registrado := BooleanoDe(Obj, 'Registrado');
                    Cab."Origen Carton" := OpcionDe(Obj, 'Origen_del_cartón');

                    // "Pallets Desde" y "Pallets Hasta" quedan como estén: la Query no los trae. Es
                    // lo único que el transporte por web services no cubre de lo que sí cubre el de
                    // SQL. Se completan agregando dos columnas a DetalleDescargas en NAV.

                    Cab."Estado Sinc" := "Estado Sinc NAV"::Pendiente;
                    Cab.Observacion := '';
                    Cab.Intentos := 0;
                    Cab."Traido El" := CurrentDateTime();
                    Cab.Modify();
                end;

                LineNo := EnteroDe(Obj, 'Line_no');
                if not Lin.Get(NoProyecto, LineNo) then begin
                    Lin.Init();
                    Lin."No Proyecto" := NoProyecto;
                    Lin."Line No" := LineNo;
                    Lin.Insert();
                end;

                Lin."No Remito" := CopyStr(TextoDe(Obj, 'No_remito'), 1, MaxStrLen(Lin."No Remito"));
                Lin."Item No" := CopyStr(TextoDe(Obj, 'Item_no'), 1, MaxStrLen(Lin."Item No"));
                Lin.Descripcion := CopyStr(TextoDe(Obj, 'Description'), 1, MaxStrLen(Lin.Descripcion));
                Lin."Unidad Medida" := CopyStr(TextoDe(Obj, 'Unidad_medida'), 1, MaxStrLen(Lin."Unidad Medida"));
                Lin.Cantidad := DecimalDe(Obj, 'Cantidad');
                Lin."Peso Neto" := DecimalDe(Obj, 'Net_weight');
                Lin."Peso Bruto" := DecimalDe(Obj, 'Gross_weight');
                Lin."Fecha Remito" := FechaDe(Obj, 'Fecha_remito');
                Lin."Licencia Transporte" := CopyStr(TextoDe(Obj, 'Transport_s_license'), 1, MaxStrLen(Lin."Licencia Transporte"));
                Lin.Temperatura := DecimalDe(Obj, 'Temperatura');
                Lin."Hora Ingreso" := HoraDe(Obj, 'Hora_de_ingreso');
                Lin."Tipo Amparo Sanitario" := OpcionDe(Obj, 'Tipo_de_amparo_sanitario');
                Lin."No Amparo Sanitario" := CopyStr(TextoDe(Obj, 'No_amparo_sanitario'), 1, MaxStrLen(Lin."No Amparo Sanitario"));
                Lin.Destino := CopyStr(TextoDe(Obj, 'Destino'), 1, MaxStrLen(Lin.Destino));
                Lin."No Pallet" := CopyStr(TextoDe(Obj, 'No_Pallet'), 1, MaxStrLen(Lin."No Pallet"));

                // Los "Detalle" son los de la LÍNEA. Ver el remarks.
                Lin."Cod Camara" := CopyStr(TextoDe(Obj, 'LocationDetalle'), 1, MaxStrLen(Lin."Cod Camara"));
                Lin.Buque := CopyStr(TextoDe(Obj, 'BuqueDetalle'), 1, MaxStrLen(Lin.Buque));
                Lin.Marea := CopyStr(TextoDe(Obj, 'MareaDetalle'), 1, MaxStrLen(Lin.Marea));
                Lin.Puerto := CopyStr(TextoDe(Obj, 'PuertoDetalle'), 1, MaxStrLen(Lin.Puerto));
                Lin.Actividad := CopyStr(TextoDe(Obj, 'ActividadDetalle'), 1, MaxStrLen(Lin.Actividad));

                Lin.Promedio := DecimalDe(Obj, 'Promedio');
                Lin."Bin Code" := CopyStr(TextoDe(Obj, 'Bin_code'), 1, MaxStrLen(Lin."Bin Code"));
                Lin.Tara := DecimalDe(Obj, 'Tare');
                Lin."Bruto Mas Tara" := DecimalDe(Obj, 'Gross_Tare');
                Lin."Fecha Hora Pesaje" := FechaHoraDe(Obj, 'Weighing_Date_and_Time');
                Lin.Confirmado := OpcionDe(Obj, 'Confirmed');
                Lin."Estado Origen" := CopyStr(TextoDe(Obj, 'Status'), 1, MaxStrLen(Lin."Estado Origen"));
                Lin.Familia := CopyStr(TextoDe(Obj, 'Familia'), 1, MaxStrLen(Lin.Familia));
                Lin.Subfamilia := CopyStr(TextoDe(Obj, 'Subfamilia'), 1, MaxStrLen(Lin.Subfamilia));
                Lin."Unidad Medida Manual" := CopyStr(TextoDe(Obj, 'Manual_unit_of_measure'), 1, MaxStrLen(Lin."Unidad Medida Manual"));
                Lin."Peso Manual" := DecimalDe(Obj, 'Manual_weight');

                Lin."Estado Sinc" := "Estado Sinc NAV"::Pendiente;
                Lin.Observacion := '';
                Lin.Intentos := 0;
                Lin."Traido El" := CurrentDateTime();
                Lin.Modify();
                Filas += 1;
            end;
        end;
    end;

    local procedure VolcarEmpleados(Datos: JsonArray) Filas: Integer
    var
        Stg: Record "Stg Empleado NAV";
        Token: JsonToken;
        Obj: JsonObject;
        NoEmpleado: Code[20];
        i: Integer;
    begin
        for i := 0 to Datos.Count() - 1 do begin
            Datos.Get(i, Token);
            Obj := Token.AsObject();

            NoEmpleado := CopyStr(TextoDe(Obj, 'No'), 1, MaxStrLen(Stg."No Empleado"));
            if NoEmpleado <> '' then begin
                if not Stg.Get(NoEmpleado) then begin
                    Stg.Init();
                    Stg."No Empleado" := NoEmpleado;
                    Stg.Insert();
                end;

                // LOS DOS APELLIDOS VAN JUNTOS EN "Apellido", igual que en el transporte por SQL. La
                // localización española parte el nombre en tres campos y "Segundo Nombre" del staging
                // termina en el "Middle Name" de BC, que es un NOMBRE de pila, no un apellido: poner
                // ahí el segundo apellido deja al empleado llamándose "WALDO DAVID RODRIGUEZ ROJAS".
                Stg.Apellido := CopyStr(
                    DelChr(TextoDe(Obj, 'First_Family_Name') + ' ' + TextoDe(Obj, 'Second_Family_Name'), '>', ' '),
                    1, MaxStrLen(Stg.Apellido));
                Stg.Nombre := CopyStr(TextoDe(Obj, 'Name'), 1, MaxStrLen(Stg.Nombre));
                Stg."Segundo Nombre" := '';

                Stg.Iniciales := CopyStr(TextoDe(Obj, 'Initials'), 1, MaxStrLen(Stg.Iniciales));
                Stg."Puesto Titulo" := CopyStr(TextoDe(Obj, 'Job_Title'), 1, MaxStrLen(Stg."Puesto Titulo"));
                Stg."Fecha Ingreso" := FechaDe(Obj, 'Employment_Date');
                Stg."No Seguridad Social" := CopyStr(TextoDe(Obj, 'Social_Security_No'), 1, MaxStrLen(Stg."No Seguridad Social"));
                Stg."CIF NIF" := CopyStr(TextoDe(Obj, 'CIF_NIF'), 1, MaxStrLen(Stg."CIF NIF"));

                // La ficha de NAV muestra el campo del add-in de sueldos, no el "Birth Date" estándar.
                Stg."Fecha Nacimiento" := FechaDe(Obj, 'pat_Fecha_nacimiento');

                Stg.Direccion := CopyStr(TextoDe(Obj, 'Address'), 1, MaxStrLen(Stg.Direccion));
                Stg."Direccion 2" := CopyStr(TextoDe(Obj, 'Address_2'), 1, MaxStrLen(Stg."Direccion 2"));
                Stg.Ciudad := CopyStr(TextoDe(Obj, 'City'), 1, MaxStrLen(Stg.Ciudad));
                Stg."Cod Postal" := CopyStr(TextoDe(Obj, 'Post_Code'), 1, MaxStrLen(Stg."Cod Postal"));
                Stg.Telefono := CopyStr(TextoDe(Obj, 'Phone_No'), 1, MaxStrLen(Stg.Telefono));
                Stg.Email := CopyStr(TextoDe(Obj, 'E_Mail'), 1, MaxStrLen(Stg.Email));
                Stg."Convenio Origen" := CopyStr(TextoDe(Obj, 'pat_Cod_convenio'), 1, MaxStrLen(Stg."Convenio Origen"));
                Stg."Categoria Origen" := CopyStr(TextoDe(Obj, 'Categoría'), 1, MaxStrLen(Stg."Categoria Origen"));

                Stg."Estado Sinc" := "Estado Sinc NAV"::Pendiente;
                Stg.Observacion := '';
                Stg.Intentos := 0;
                Stg."Traido El" := CurrentDateTime();
                Stg.Modify();
                Filas += 1;
            end;
        end;
    end;

    /// <summary>
    /// Vuelca los valores de dimensión, descartando los que no son de tipo estándar.
    /// </summary>
    /// <remarks>
    /// EL TIPO LLEGA COMO TEXTO LOCALIZADO ("Estándar"), no como el ordinal 0 que usaba el filtro
    /// del transporte por SQL. Por eso el descarte se hace acá y no en la URL: en la URL sería una
    /// comparación contra una palabra en castellano metida en un filtro de OData, y el día que la
    /// instancia cambie de idioma dejaría de traer todo sin un solo error. Acá, al menos, está en un
    /// lugar y se ve.
    ///
    /// Encabezados y totales no se traen porque en BC no se pueden asignar a un proyecto: crearlos
    /// como estándar sería peor que no tenerlos.
    /// </remarks>
    local procedure VolcarValoresDim(Datos: JsonArray) Filas: Integer
    var
        Stg: Record "Stg Valor Dim NAV";
        Token: JsonToken;
        Obj: JsonObject;
        CodDim: Code[20];
        Codigo: Code[20];
        i: Integer;
    begin
        for i := 0 to Datos.Count() - 1 do begin
            Datos.Get(i, Token);
            Obj := Token.AsObject();

            CodDim := CopyStr(TextoDe(Obj, 'Dimension_Code'), 1, MaxStrLen(Stg."Cod Dimension"));
            Codigo := CopyStr(TextoDe(Obj, 'Code'), 1, MaxStrLen(Stg.Codigo));

            // El origen tiene filas con la dimensión vacía. Son basura y no se tocan.
            if (CodDim <> '') and (Codigo <> '') and EsTipoEstandar(TextoDe(Obj, 'Dimension_Value_Type')) then begin
                if not Stg.Get(CodDim, Codigo) then begin
                    Stg.Init();
                    Stg."Cod Dimension" := CodDim;
                    Stg.Codigo := Codigo;
                    Stg.Insert();
                end;

                Stg.Nombre := CopyStr(TextoDe(Obj, 'Name'), 1, MaxStrLen(Stg.Nombre));
                Stg.Bloqueado := BooleanoDe(Obj, 'Blocked');

                Stg."Estado Sinc" := "Estado Sinc NAV"::Pendiente;
                Stg.Observacion := '';
                Stg.Intentos := 0;
                Stg."Traido El" := CurrentDateTime();
                Stg.Modify();
                Filas += 1;
            end;
        end;
    end;

    local procedure EsTipoEstandar(Texto: Text): Boolean
    begin
        exit((Texto = 'Estándar') or (Texto = 'Standard') or (Texto = ''));
    end;

    local procedure VolcarProyectos(Datos: JsonArray) Filas: Integer
    var
        Stg: Record "Stg Proyecto NAV";
        Token: JsonToken;
        Obj: JsonObject;
        NoProyecto: Code[20];
        i: Integer;
    begin
        for i := 0 to Datos.Count() - 1 do begin
            Datos.Get(i, Token);
            Obj := Token.AsObject();

            NoProyecto := CopyStr(TextoDe(Obj, 'No'), 1, MaxStrLen(Stg."No Proyecto"));
            MotivoFila := '';
            if NoProyecto <> '' then begin
                if not Stg.Get(NoProyecto) then begin
                    Stg.Init();
                    Stg."No Proyecto" := NoProyecto;
                    Stg.Insert();
                end;

                Stg.Descripcion := CopyStr(TextoDe(Obj, 'Description'), 1, MaxStrLen(Stg.Descripcion));
                Stg."Descripcion 2" := CopyStr(TextoDe(Obj, 'Description_2'), 1, MaxStrLen(Stg."Descripcion 2"));
                Stg."Fecha Inicio" := FechaDe(Obj, 'Starting_Date');
                Stg."Fecha Fin" := FechaDe(Obj, 'Ending_Date');

                // LAS DIMENSIONES 2 Y 3 VAN CRUZADAS: en NAV la 2 es la actividad y la 3 es la marea;
                // en BC es al revés. Acá el cruce es explícito, que es lo que evita el error
                // silencioso de copiar posicionalmente y dejar todos los proyectos con marea LAN o CAL.
                Stg.Buque := CopyStr(TextoDe(Obj, 'Global_Dimension_1_Code'), 1, MaxStrLen(Stg.Buque));
                Stg.Marea := CopyStr(TextoDe(Obj, 'Global_Dimension_3_Code'), 1, MaxStrLen(Stg.Marea));
                Stg.Actividad := CopyStr(TextoDe(Obj, 'Global_Dimension_2_Code'), 1, MaxStrLen(Stg.Actividad));

                Stg.Estado := EstadoProyectoDesdeTexto(TextoDe(Obj, 'Status'), NoProyecto);
                Stg."Tipo Proyecto" := TipoProyectoDesdeTexto(TextoDe(Obj, 'Tipo'), NoProyecto);

                Stg.Patron := CopyStr(TextoDe(Obj, 'Patron'), 1, MaxStrLen(Stg.Patron));
                Stg."Hora Zarpada" := HoraDe(Obj, 'Hora_de_zarpada');
                Stg."Hora Ingreso Puerto" := HoraDe(Obj, 'Hora_ingreso_a_puerto');
                Stg."Fecha Llegada Prevista" := FechaDe(Obj, 'Fecha_llegada_prevista');
                Stg."Puerto Zarpada" := CopyStr(TextoDe(Obj, 'Puerto_zarpada'), 1, MaxStrLen(Stg."Puerto Zarpada"));
                Stg."Puerto Descarga" := CopyStr(TextoDe(Obj, 'Puerto_Descarga'), 1, MaxStrLen(Stg."Puerto Descarga"));
                Stg."Anio Marea" := EnteroDe(Obj, 'Año_marea');

                // UNA FILA RARA NO TUMBA EL LOTE. Si algo no se pudo interpretar, esa fila queda en
                // Error con el motivo y las otras 4476 entran igual. Abortar la traída entera por un
                // proyecto con un tipo que nadie mapeó es peor que dejarlo señalado: no se aplica
                // —el estado Error lo saca del proceso— y alguien lo mira.
                if MotivoFila = '' then begin
                    Stg."Estado Sinc" := "Estado Sinc NAV"::Pendiente;
                    Stg.Observacion := '';
                end else begin
                    Stg."Estado Sinc" := "Estado Sinc NAV"::Error;
                    Stg.Observacion := CopyStr(MotivoFila, 1, MaxStrLen(Stg.Observacion));
                end;

                Stg.Intentos := 0;
                Stg."Traido El" := CurrentDateTime();
                Stg.Modify();
                Filas += 1;
            end;
        end;
    end;

    // ────────────────────────────────────────────────────────────────────────────────────────────
    //  Opciones que llegan como texto
    // ────────────────────────────────────────────────────────────────────────────────────────────

    /// <summary>
    /// Convierte el Status del proyecto, que OData devuelve como caption localizada, en el ordinal
    /// que guarda el staging.
    /// </summary>
    /// <remarks>
    /// POR SQL ESTE CAMPO VENÍA COMO NÚMERO; por OData viene como la palabra que se ve en pantalla,
    /// traducida al idioma de la instancia de NAV. No hay forma de pedir el ordinal.
    ///
    /// Un valor desconocido FALLA la fila en vez de asumir cero. Asumir cero sería marcar como
    /// "Planificación" un proyecto que quizá esté cerrado, y nadie lo notaría hasta que alguien
    /// filtre por estado y falten mareas.
    /// </remarks>
    local procedure EstadoProyectoDesdeTexto(Texto: Text; NoProyecto: Code[20]): Integer
    var
        N: Integer;
    begin
        // SI YA ES UN NÚMERO, ES EL ORDINAL. OData devuelve la caption cuando la opción tiene texto
        // y el ordinal pelado cuando no lo tiene, y las dos formas conviven en el mismo campo: el
        // mismo Tipo llega como "Productivo" en un proyecto y como "0" en otro. Probar primero el
        // número evita tener que mapear captions vacías, que es lo que no se puede escribir.
        if Evaluate(N, Texto) then
            exit(N);

        case Texto of
            '':
                exit(0);
            'Planificación', 'Planning':
                exit(0);
            'Presupuesto', 'Quote':
                exit(1);
            'Pedido', 'Order':
                exit(2);
            'Terminado', 'Completed':
                exit(3);
        end;

        MotivoFila := StrSubstNo(TxtEstadoDesconocido, Texto, NoProyecto);
        exit(0);
    end;

    /// <summary>
    /// Convierte el Tipo del proyecto de caption a ordinal.
    /// </summary>
    /// <remarks>
    /// EL PRIMER MIEMBRO DE LA OPCIÓN ESTÁ EN BLANCO. En la personalización de NAV el campo se
    /// declara `OptionMembers = ,Productivo,Improductivo`, así que Productivo es el 1 y no el 0.
    ///
    /// Mapearlo a 0 no da error: deja el proyecto con el tipo VACÍO, que es un valor legítimo. El
    /// síntoma aparece lejos y disfrazado — la "TableRelation" de "Lín. descarga" está filtrada por
    /// tipo Productivo, así que las líneas fallan con "el proyecto contiene un valor que no se puede
    /// encontrar en la tabla relacionada", sobre proyectos que existen perfectamente.
    ///
    /// Verificado el 13/9/2026 contra el tableextension 50245, campo 50806.
    /// </remarks>
    local procedure TipoProyectoDesdeTexto(Texto: Text; NoProyecto: Code[20]): Integer
    var
        N: Integer;
    begin
        // Un número ya es el ordinal: OData devuelve la caption cuando la opción tiene texto y el
        // número pelado cuando no lo tiene — y el miembro 0 de éste es justamente el que no lo tiene.
        if Evaluate(N, Texto) then
            exit(N);

        case Texto of
            '':
                exit(0);        // en blanco
            'Productivo':
                exit(1);
            'Improductivo':
                exit(2);
        end;

        MotivoFila := StrSubstNo(TxtTipoDesconocido, Texto, NoProyecto);
        exit(0);
    end;

    local procedure EsBaja(TipoCambio: Text): Boolean
    begin
        exit((TipoCambio = 'Eliminación') or (TipoCambio = 'Deletion'));
    end;

    // ────────────────────────────────────────────────────────────────────────────────────────────
    //  Lectura de JSON
    // ────────────────────────────────────────────────────────────────────────────────────────────

    local procedure TextoDe(Obj: JsonObject; Campo: Text): Text
    var
        Token: JsonToken;
    begin
        if not Obj.Get(Campo, Token) then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    /// <summary>
    /// Fecha de un campo OData. La fecha vacía de NAV llega como 0001-01-01, no como nulo.
    /// </summary>
    /// <remarks>
    /// Y hay que interceptarla: convertida tal cual da el 1 de enero del año 1, que en BC es una
    /// fecha válida. Un proyecto con fecha de arribo 01/01/0001 no da error en ningún lado — se
    /// comporta como una marea cerrada hace dos mil años.
    /// </remarks>
    local procedure FechaDe(Obj: JsonObject; Campo: Text): Date
    var
        Valor: Text;
        D: Date;
    begin
        Valor := TextoDe(Obj, Campo);
        if (Valor = '') or (Valor = '0001-01-01') then
            exit(0D);
        if Evaluate(D, Valor, 9) then
            exit(D);
        exit(0D);
    end;

    local procedure HoraDe(Obj: JsonObject; Campo: Text): Time
    var
        Valor: Text;
        H: Time;
    begin
        Valor := TextoDe(Obj, Campo);
        if Valor = '' then
            exit(0T);
        if Evaluate(H, Valor, 9) then
            exit(H);
        exit(0T);
    end;

    local procedure EnteroDe(Obj: JsonObject; Campo: Text): Integer
    var
        Token: JsonToken;
    begin
        if not Obj.Get(Campo, Token) then
            exit(0);
        if Token.AsValue().IsNull() then
            exit(0);
        exit(Token.AsValue().AsInteger());
    end;

    local procedure DecimalDe(Obj: JsonObject; Campo: Text): Decimal
    var
        Token: JsonToken;
    begin
        if not Obj.Get(Campo, Token) then
            exit(0);
        if Token.AsValue().IsNull() then
            exit(0);
        exit(Token.AsValue().AsDecimal());
    end;

    local procedure FechaHoraDe(Obj: JsonObject; Campo: Text): DateTime
    var
        Valor: Text;
        DH: DateTime;
    begin
        Valor := TextoDe(Obj, Campo);
        // La fecha/hora vacía de NAV llega como el año 1, no como nulo. Mismo caso que FechaDe.
        if (Valor = '') or (Valor.StartsWith('0001-01-01')) then
            exit(0DT);
        if Evaluate(DH, Valor, 9) then
            exit(DH);
        exit(0DT);
    end;

    /// <summary>
    /// Campo de opción de NAV que OData devuelve como texto, convertido al ordinal que guarda el
    /// staging.
    /// </summary>
    /// <remarks>
    /// A diferencia del Status del proyecto, acá un valor no reconocido NO falla la fila. La
    /// diferencia es qué se pierde: el estado de un proyecto decide si una marea está abierta, y
    /// equivocarlo cambia una liquidación; estos —origen del cartón, tipo de amparo, confirmado— no
    /// los usa el motor. Frenar 240.000 líneas de descarga por una opción cosmética sería el peor de
    /// los dos errores.
    ///
    /// El caso normal es que llegue vacío (' ' o '') o un número como texto. Cualquier otra cosa
    /// queda en cero — si algún día importa, el valor está en el origen y se puede volver a traer.
    /// </remarks>
    local procedure OpcionDe(Obj: JsonObject; Campo: Text): Integer
    var
        Valor: Text;
        N: Integer;
    begin
        Valor := DelChr(TextoDe(Obj, Campo), '<>', ' ');
        if Valor = '' then
            exit(0);
        if Evaluate(N, Valor) then
            exit(N);
        exit(0);
    end;

    local procedure BooleanoDe(Obj: JsonObject; Campo: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not Obj.Get(Campo, Token) then
            exit(false);
        if Token.AsValue().IsNull() then
            exit(false);
        exit(Token.AsValue().AsBoolean());
    end;

    local procedure EnteroGrandeDe(Obj: JsonObject; Campo: Text): BigInteger
    var
        Token: JsonToken;
    begin
        if not Obj.Get(Campo, Token) then
            exit(0);
        if Token.AsValue().IsNull() then
            exit(0);
        exit(Token.AsValue().AsBigInteger());
    end;

    // ────────────────────────────────────────────────────────────────────────────────────────────
    //  De entidad a configuración
    // ────────────────────────────────────────────────────────────────────────────────────────────

    local procedure EntitySetDe(Entidad: Enum "Entidad Sinc NAV"): Text
    begin
        case Entidad of
            Entidad::Proyecto:
                exit(Cfg."Entidad Proyectos");
            Entidad::Empleado:
                exit(Cfg."Entidad Empleados");
            Entidad::"Descarga Cabecera", Entidad::"Descarga Linea":
                exit(Cfg."Entidad Descargas");
            Entidad::"Valor Dimension":
                exit(Cfg."Entidad Valores Dim");
            Entidad::"Informe Cap Cabecera":
                exit(Cfg."Entidad Informe Cap Cab");
            Entidad::"Informe Cap Linea":
                exit(Cfg."Entidad Informe Cap Lin");
            Entidad::"Dia Abordo Cabecera":
                exit(Cfg."Entidad Dia Abordo Cab");
            Entidad::"Dia Abordo Linea":
                exit(Cfg."Entidad Dia Abordo Lin");
        end;
    end;

    /// <summary>
    /// Condición OData sobre Table_No para una entidad. La cabecera de descarga mira DOS tablas.
    /// </summary>
    /// <remarks>
    /// Una línea de descarga puede cambiar sin que se toque su cabecera —un peso corregido, un
    /// pallet reasignado—, y en ese caso el registro de cambios sólo anota la 50562. Mirando nada
    /// más que la 50561, esa corrección no llega nunca a BC: no falla, falta.
    /// </remarks>
    local procedure CondicionTablas(Entidad: Enum "Entidad Sinc NAV"): Text
    begin
        if Entidad = Entidad::"Descarga Cabecera" then
            exit(StrSubstNo('Table_No eq %1 or Table_No eq %2',
                            Cfg."Tabla NAV Descarga Cab", Cfg."Tabla NAV Descarga Lin"));

        exit(StrSubstNo('Table_No eq %1', TablaNAVDe(Entidad)));
    end;

    local procedure TablaNAVDe(Entidad: Enum "Entidad Sinc NAV"): Integer
    begin
        case Entidad of
            Entidad::Proyecto:
                exit(Cfg."Tabla NAV Proyecto");
            Entidad::Empleado:
                exit(Cfg."Tabla NAV Empleado");
            Entidad::"Descarga Cabecera":
                exit(Cfg."Tabla NAV Descarga Cab");
            Entidad::"Descarga Linea":
                exit(Cfg."Tabla NAV Descarga Lin");
            Entidad::"Valor Dimension":
                exit(Cfg."Tabla NAV Valor Dim");
            Entidad::"Informe Cap Cabecera":
                exit(Cfg."Tabla NAV Informe Cap Cab");
            Entidad::"Informe Cap Linea":
                exit(Cfg."Tabla NAV Informe Cap Lin");
            Entidad::"Dia Abordo Cabecera":
                exit(Cfg."Tabla NAV Dia Abordo Cab");
            Entidad::"Dia Abordo Linea":
                exit(Cfg."Tabla NAV Dia Abordo Lin");
        end;
    end;

    /// <summary>
    /// Arma la condición OData que identifica una clave dentro del entity set.
    /// </summary>
    /// <remarks>
    /// Va entre paréntesis siempre. Sin ellos, un `A eq x and B eq y or A eq z and B eq w` lo agrupa
    /// el servidor a su manera y el filtro deja pasar combinaciones que nadie pidió — y no falla:
    /// devuelve de más, que es la clase de error que aparece tres meses después como un valor de
    /// dimensión que nadie sabe de dónde salió.
    /// </remarks>
    local procedure CondicionDeClave(Entidad: Enum "Entidad Sinc NAV"; Clave: Text): Text
    var
        Partes: List of [Text];
        C1: Text;
        C2: Text;
    begin
        if not ClaveEsCompuesta(Entidad) then
            exit(StrSubstNo('(%1 eq ''%2'')', CampoClave1De(Entidad), Escapar(Clave)));

        Partes := Clave.Split(SeparadorClave());
        if Partes.Count() >= 1 then
            C1 := Partes.Get(1);
        if Partes.Count() >= 2 then
            C2 := Partes.Get(2);

        exit(StrSubstNo('(%1 eq ''%2'' and %3 eq ''%4'')',
                        CampoClave1De(Entidad), Escapar(C1),
                        CampoClave2De(Entidad), Escapar(C2)));
    end;

    local procedure Escapar(Valor: Text): Text
    begin
        // En OData un apóstrofe dentro de un literal se duplica, igual que en SQL.
        exit(Valor.Replace('''', ''''''));
    end;

    local procedure SeparadorClave(): Text
    begin
        // Un carácter que no puede aparecer en un código de NAV, para que partir la clave no parta
        // también un valor.
        exit('|');
    end;

    local procedure ClaveEsCompuesta(Entidad: Enum "Entidad Sinc NAV"): Boolean
    begin
        exit(Entidad = Entidad::"Valor Dimension");
    end;

    local procedure CampoClave1De(Entidad: Enum "Entidad Sinc NAV"): Text
    begin
        case Entidad of
            Entidad::Proyecto, Entidad::Empleado:
                exit('No');
            Entidad::"Descarga Cabecera", Entidad::"Descarga Linea":
                exit('N_proyecto');
            Entidad::"Valor Dimension":
                exit('Dimension_Code');
            // El grado del signo N° viaja codificado en el nombre OData: N_x00B0__proyecto.
            Entidad::"Informe Cap Cabecera", Entidad::"Informe Cap Linea":
                exit('N_x00B0__proyecto');
            // ACÁ EL ACENTO VA TAL CUAL. NAV codifica sólo lo que no sirve como identificador —el
            // grado y el ordinal, de ahí N_x00B0__proyecto y N_x00BA_— pero las vocales acentuadas
            // las deja: es "Cód_Proyecto", no "C_x00F3_d_Proyecto". Con la forma codificada el
            // servidor contesta 400 sin decir qué campo no entendió.
            //
            // Y la P va en mayúscula en la cabecera y en minúscula en las líneas. No es un
            // descuido: es como están escritos los campos en NAV.
            Entidad::"Dia Abordo Cabecera":
                exit('Cód_Proyecto');
            Entidad::"Dia Abordo Linea":
                exit('Cód_proyecto');
        end;
    end;

    local procedure CampoClave2De(Entidad: Enum "Entidad Sinc NAV"): Text
    begin
        case Entidad of
            Entidad::"Valor Dimension":
                exit('Code');
        end;
    end;

    local procedure RegistrarTraida(Entidad: Enum "Entidad Sinc NAV"; Marca: BigInteger; Filas: Integer)
    var
        Ctrl: Record "Ctrl Sinc NAV";
    begin
        if not Ctrl.Get(Entidad) then
            exit;
        Ctrl."Marca Agua" := CopyStr(Format(Marca, 0, 9), 1, MaxStrLen(Ctrl."Marca Agua"));
        Ctrl."Traido El" := CurrentDateTime();
        Ctrl."Filas Traidas" := Filas;
        Ctrl.Modify(true);

        // La cabecera de descarga también trajo las líneas, así que su fila de control tiene que
        // reflejarlo. Si no, la pantalla muestra las líneas con una traída vieja y la marca de agua
        // sin mover: la próxima corrida las volvería a pedir desde el principio.
        if Entidad = Entidad::"Descarga Cabecera" then
            if Ctrl.Get(Entidad::"Descarga Linea") then begin
                Ctrl."Marca Agua" := CopyStr(Format(Marca, 0, 9), 1, MaxStrLen(Ctrl."Marca Agua"));
                Ctrl."Traido El" := CurrentDateTime();
                Ctrl."Filas Traidas" := Filas;
                Ctrl.Modify(true);
            end;
    end;
}
