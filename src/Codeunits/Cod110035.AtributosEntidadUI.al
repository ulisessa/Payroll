namespace UAS.Payroll;

// El comportamiento de la columna "Valor" de los atributos, en un solo lugar.
//
// Los atributos se editan desde dos pantallas —la lista completa y la subpágina de la ficha del
// empleado— y las dos tienen que interpretar lo tipeado igual, ofrecer la misma lista de valores
// válidos y proponer las mismas vigencias. Si cada página armara lo suyo, la deriva no daría un
// error: daría dos pantallas que aceptan cosas distintas para el mismo atributo, y la que quedó
// atrás seguiría ofreciendo valores que el OnValidate de la tabla después rechaza.
//
// Acá vive la parte que es DECISIÓN. Lo que es validación —que el valor exista, que cuelgue del
// padre correcto, que el tipo coincida— sigue en la tabla, donde alcanza también a lo que entra por
// código, por importación o por configuración.
codeunit 110035 "Atributos Entidad UI"
{
    /// <summary>Lo que se muestra en la columna Valor para la fila que se está mirando.</summary>
    /// <remarks>
    /// El CÓDIGO en las de lista y no la descripción, porque esta columna además se edita y el
    /// código es lo que se escribe. El significado ya está al lado, en Descripción.
    /// </remarks>
    procedure ValorParaEditar(var Atr: Record "Atributo Entidad Liq."): Text
    begin
        case Atr."Tipo Dato" of
            Atr."Tipo Dato"::Lista:
                exit(Atr."Cód. Valor");
            Atr."Tipo Dato"::Decimal, Atr."Tipo Dato"::Entero:
                exit(Format(Atr."Valor Decimal"));
            Atr."Tipo Dato"::Texto:
                exit(Atr."Valor Texto");
            Atr."Tipo Dato"::Fecha:
                if Atr."Valor Fecha" <> 0D then
                    exit(Format(Atr."Valor Fecha"));
        end;
        exit('');
    end;

    /// <summary>Vuelca lo tipeado al campo que corresponde al tipo de dato del atributo.</summary>
    /// <remarks>
    /// Cada tipo se valida contra su propio campo, y siempre con Validate: es lo que dispara el
    /// control de tipo, la resolución del padre y el congelado del valor numérico.
    /// </remarks>
    procedure AplicarValor(var Atr: Record "Atributo Entidad Liq."; ValorEntrada: Text)
    var
        Dec: Decimal;
        Fec: Date;
    begin
        Atr.CalcFields("Tipo Dato");
        case Atr."Tipo Dato" of
            Atr."Tipo Dato"::Lista:
                Atr.Validate("Cód. Valor", CopyStr(ValorEntrada, 1, MaxStrLen(Atr."Cód. Valor")));
            Atr."Tipo Dato"::Decimal, Atr."Tipo Dato"::Entero:
                begin
                    if ValorEntrada <> '' then
                        if not Evaluate(Dec, ValorEntrada) then
                            Error(ErrNoEsNumero, ValorEntrada);
                    Atr.Validate("Valor Decimal", Dec);
                end;
            Atr."Tipo Dato"::Texto:
                Atr.Validate("Valor Texto", CopyStr(ValorEntrada, 1, MaxStrLen(Atr."Valor Texto")));
            Atr."Tipo Dato"::Fecha:
                begin
                    if ValorEntrada <> '' then
                        if not Evaluate(Fec, ValorEntrada) then
                            Error(ErrNoEsFecha, ValorEntrada);
                    Atr.Validate("Valor Fecha", Fec);
                end;
        end;
    end;

    /// <summary>Corre la lista de valores válidos del atributo. Devuelve true si el usuario eligió.</summary>
    /// <remarks>
    /// Una sola definición de "qué valores son válidos acá", compartida por el lookup manual y por la
    /// apertura automática, en las dos pantallas.
    ///
    /// TextoTipeado, cuando viene, abre la lista ya acotada a lo que el usuario venía escribiendo. No
    /// es el autocompletado de un TableRelation —la columna Valor es una variable y no un campo, así
    /// que la plataforma no tiene metadatos para filtrar mientras se tipea— pero al menos lo escrito
    /// no se tira. El filtro va en el grupo 0 para que se pueda borrar desde la misma lista si no
    /// encontró nada; los del atributo y el padre van en el 4, que el usuario no puede tocar.
    /// </remarks>
    procedure ElegirValorDeLista(var Atr: Record "Atributo Entidad Liq."; TextoTipeado: Text; var ValorAtr: Record "Valor Atributo Liq."): Boolean
    var
        Busqueda: Text;
    begin
        Atr.TestField("Cód. Tipo Atributo");
        ValorAtr.FilterGroup(4);
        ValorAtr.SetRange("Cód. Tipo Atributo", Atr."Cód. Tipo Atributo");
        // Se acota al padre SÓLO cuando el padre lo deriva la entidad. Si lo trae el valor elegido
        // —PUESTO—, filtrar por el padre derivado esconde justo lo que se viene a buscar: un
        // oficial de 768/19 que embarca de Patrón de Pesca no vería FE01, que cuelga de ESP.
        if not Atr.PadreSegunElValor() then
            ValorAtr.SetRange("Cód. Valor Padre", Atr.ValorPadreVigente());
        ValorAtr.FilterGroup(0);
        if TextoTipeado <> '' then begin
            // El filtro se arma a mano y NO con la sustitución de SetFilter: con '@*%1*' el
            // placeholder se coló sin reemplazar y quedó como filtro literal sobre Código, que no
            // matchea nada. La lista se abría vacía teniendo valores, y el motivo sólo se veía
            // abriendo el filtro de la columna.
            //
            // DelChr saca los metacaracteres de filtro antes de concatenar: un '*' o un '&' que el
            // usuario haya tipeado son texto que busca, no sintaxis.
            Busqueda := DelChr(TextoTipeado, '=', '&|()<>=*?@''"');
            if Busqueda <> '' then begin
                ValorAtr.SetFilter(Código, '@*' + Busqueda + '*');
                // Si lo tipeado no coincide con nada, una lista vacía esconde las opciones reales
                // en vez de ayudar. Se vuelve a mostrar todo, que es a lo que el usuario vino.
                if ValorAtr.IsEmpty() then
                    ValorAtr.SetRange(Código);
            end;
        end;
        if Page.RunModal(Page::"Valores de Atributo", ValorAtr) <> Action::LookupOK then
            exit(false);

        // EL PADRE SE GUARDA ACÁ, no después. Lo que las páginas devuelven de un lookup es un
        // Text, así que de la fila elegida sólo sobrevive el código — y el código solo no la
        // identifica cuando el mismo puesto cuelga de dos convenios: OF01 existe en 175/75 y en
        // 768/19. Sin esto, elegir desde la lista terminaba en "elegilo desde la lista".
        Atr."Cód. Valor Padre" := ValorAtr."Cód. Valor Padre";
        exit(true);
    end;

    /// <summary>Apenas se sabe que el atributo es de lista, abre la lista de valores.</summary>
    procedure AbrirListaSiCorresponde(var Atr: Record "Atributo Entidad Liq."; var ValorEntrada: Text)
    var
        TipoAtr: Record "Tipo Atributo Liq.";
        ValorAtr: Record "Valor Atributo Liq.";
    begin
        if Atr."Cód. Tipo Atributo" = '' then
            exit;
        if Atr."Tipo Dato" <> Atr."Tipo Dato"::Lista then
            exit;
        if not TipoAtr.Get(Atr."Cód. Tipo Atributo") then
            exit;
        // Un atributo encadenado —la categoría cuelga del convenio— necesita saber contra qué padre
        // resolverse, y el padre depende de la fecha: sin vigencia, ValorPadreVigente corta con
        // error. Abrir la lista acá sin ese dato convertiría el atajo en un error cada vez que
        // alguien elige el atributo antes que la fecha. Se sale en silencio y queda el lookup, que
        // sí explica qué falta cuando el usuario lo pide.
        if (TipoAtr."Cód. Tipo Atributo Padre" <> '') and (Atr."Vigencia Desde" = 0D)
           and (not TipoAtr."Padre Según el Valor")
        then
            exit;
        if not ElegirValorDeLista(Atr, '', ValorAtr) then
            exit;
        Atr.Validate("Cód. Valor", ValorAtr.Código);
        ValorEntrada := Atr."Cód. Valor";
    end;

    /// <summary>
    /// Corre la vigencia propuesta al día siguiente de la última que ya tenga ese atributo.
    /// </summary>
    /// <remarks>
    /// Si el atributo ya tiene una vigencia en esa fecha —o posterior— el alta choca contra la clave
    /// primaria y el usuario recibe un "ya existe el registro" sobre una fila que además puede no
    /// estar viendo, porque el filtro de vigentes la deja fuera. Proponer la fecha libre convierte el
    /// error en un dato: se ve desde cuándo puede empezar la vigencia nueva.
    ///
    /// Con la fecha en blanco no interviene. Proponerla ahí sería completarla sola por la puerta de
    /// atrás —elegir el atributo llenaría la vigencia— y es justo lo que se sacó del OnNewRecord:
    /// "Vigencia Desde" es parte de la clave, así que corregirla después no es editar, es renombrar.
    /// </remarks>
    procedure ProponerVigenciaLibre(var Atr: Record "Atributo Entidad Liq.")
    var
        Existente: Record "Atributo Entidad Liq.";
    begin
        if Atr."Cód. Tipo Atributo" = '' then
            exit;
        if Atr."Vigencia Desde" = 0D then
            exit;
        Existente.SetRange("Tipo Entidad", Atr."Tipo Entidad");
        Existente.SetRange("Cód. Entidad", Atr."Cód. Entidad");
        Existente.SetRange("Cód. Tipo Atributo", Atr."Cód. Tipo Atributo");
        if not Existente.FindLast() then
            exit;
        if Atr."Vigencia Desde" > Existente."Vigencia Desde" then
            exit;
        Atr."Vigencia Desde" := Existente."Vigencia Desde" + 1;
    end;

    /// <summary>Deja el filtro en las vigencias que rigen a FechaRef, o lo saca para ver todo.</summary>
    /// <remarks>
    /// Es la misma condición que evalúa VigenteA, escrita como filtro: el "hasta" acepta la abierta
    /// (0D) además de la que todavía no cerró.
    ///
    /// Se filtra, no se marca. La versión anterior recorría las vigencias y marcaba las buenas, y las
    /// marcas no sobreviven a que la plataforma relea el conjunto —insertar una fila alcanza, y con
    /// DelayedInsert eso pasa en cada alta—: la lista se vaciaba sola y atributos perfectamente
    /// vigentes desaparecían de la vista sin que nadie hubiera filtrado nada.
    /// </remarks>
    procedure FiltrarVigentes(var Atr: Record "Atributo Entidad Liq."; SoloActuales: Boolean; FechaRef: Date)
    begin
        // Por si quedaron marcas de una versión anterior de la página viva en la sesión.
        Atr.MarkedOnly(false);
        Atr.ClearMarks();

        // Y el de SystemId, que es el que deja FiltrarUltimaPorTipo: si no se saca, volver al
        // historial completo seguiría mostrando una fila por tipo.
        Atr.SetRange(SystemId);

        if not SoloActuales then begin
            Atr.SetRange("Vigencia Desde");
            Atr.SetRange("Vigencia Hasta");
            exit;
        end;

        Atr.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        Atr.SetFilter("Vigencia Hasta", '%1|>=%2', 0D, FechaRef);
    end;

    /// <summary>
    /// Deja el filtro en la ÚLTIMA vigencia de cada tipo de atributo, esté cerrada o no.
    /// </summary>
    /// <remarks>
    /// "Vigente hoy" no sirve como resumen de una ficha: un atributo cuya última vigencia ya cerró
    /// —el puesto de quien está en tierra, el sindicato de quien se desafilió— desaparecía entero de
    /// la pantalla, y justamente lo que hay que ver es cuál fue el último.
    ///
    /// EL FILTRO VA POR SystemId y no por fecha. La selección es "el máximo Vigencia Desde POR TIPO"
    /// y eso no se puede escribir como filtro de campo. Filtrar por la lista de fechas ganadoras
    /// tampoco: convenio, categoría y puesto se cargan casi siempre el mismo día, así que esa lista
    /// dejaría entrar vigencias viejas de los otros tipos. Y marcar registros menos todavía — las
    /// marcas no sobreviven a que la plataforma relea el conjunto, que con DelayedInsert pasa en
    /// cada alta.
    /// </remarks>
    procedure FiltrarUltimaPorTipo(var Atr: Record "Atributo Entidad Liq.")
    var
        Busca: Record "Atributo Entidad Liq.";
        Ids: TextBuilder;
        TipoActual: Code[20];
        UltimoId: Guid;
        Cuantos: Integer;
    begin
        Atr.MarkedOnly(false);
        Atr.ClearMarks();
        Atr.SetRange("Vigencia Desde");
        Atr.SetRange("Vigencia Hasta");
        Atr.SetRange(SystemId);

        // LOS FILTROS DEL VÍNCULO VIVEN EN EL GRUPO 4, no en el 0, y CopyFilters copia SOLO los del
        // grupo actual. Copiando nada más el 0 —que es lo que hacía— Busca salía sin acotar y
        // recorría la tabla entera: un id por cada par empleado-atributo, y SQL corta a los 2.100
        // parámetros con "The incoming request has too many parameters". La ficha se cerraba sola.
        Busca.CopyFilters(Atr);
        Atr.FilterGroup(4);
        Busca.FilterGroup(4);
        Busca.CopyFilters(Atr);
        Atr.FilterGroup(0);
        Busca.FilterGroup(0);

        // Sin alcance a UNA entidad esto no significa nada: "el último de cada tipo" es por entidad.
        // Antes de recorrer, se exige el filtro; si no está se sale sin filtrar, que muestra de más
        // pero no rompe.
        if Busca.GetFilter("Cód. Entidad") = '' then
            exit;

        Busca.SetCurrentKey("Tipo Entidad", "Cód. Entidad", "Cód. Tipo Atributo", "Vigencia Desde");
        if not Busca.FindSet() then
            exit;
        repeat
            if (TipoActual <> '') and (Busca."Cód. Tipo Atributo" <> TipoActual) then begin
                AgregarId(Ids, UltimoId);
                Cuantos += 1;
                if Cuantos > MaxIdsResumen() then
                    exit;
            end;
            TipoActual := Busca."Cód. Tipo Atributo";
            // Dentro de un tipo la clave viene ascendente por Vigencia Desde, así que el último que
            // se lee es el de la vigencia más nueva.
            UltimoId := Busca.SystemId;
        until Busca.Next() = 0;
        if TipoActual <> '' then
            AgregarId(Ids, UltimoId);

        // Con la lista vacía NO se filtra: un SetFilter con texto vacío no filtra nada y mostraría
        // todo el historial justo cuando se pidió el resumen.
        if Ids.Length() > 0 then
            Atr.SetFilter(SystemId, Ids.ToText());
    end;

    /// <summary>Cuántos ids como máximo entran en el filtro del resumen.</summary>
    /// <remarks>
    /// Cada id es un parámetro de SQL y el server corta en 2.100 para toda la consulta, contando
    /// también los del vínculo y los de permisos. Una entidad de verdad tiene menos de veinte tipos
    /// de atributo; si se pasa de esto es que el alcance falló y lo que corresponde es no filtrar,
    /// no armar una consulta que el server va a rechazar cerrando la página.
    /// </remarks>
    local procedure MaxIdsResumen(): Integer
    begin
        exit(200);
    end;

    /// <summary>
    /// La descripción del valor que la entidad tiene en ese atributo a esa fecha. Vacío si no tiene.
    /// </summary>
    /// <remarks>
    /// Devuelve la DESCRIPCIÓN y no el código porque es para mostrar: "Sindicato Obreros Marítimos
    /// Unidos" dice algo, "SOM" no. Si el valor no está en el catálogo cae al código, que al menos
    /// permite rastrearlo.
    ///
    /// Misma resolución temporal que el motor: la última vigencia que empezó antes de la fecha y que
    /// no cerró antes de ella. No usa la red del rango de ParDeEntidad, que existe para que un cierre
    /// de marea no resuelva en blanco; acá no hay nada que salvar, si no tiene se muestra vacío.
    /// </remarks>
    procedure DescripcionVigente(CodTipoAtributo: Code[20]; TipoEntidad: Enum "Tipo Entidad Estado"; CodEntidad: Code[20]; FechaRef: Date): Text
    var
        Atributo: Record "Atributo Entidad Liq.";
        ValorAtr: Record "Valor Atributo Liq.";
    begin
        if (CodEntidad = '') or (FechaRef = 0D) then
            exit('');
        Atributo.SetRange("Tipo Entidad", TipoEntidad);
        Atributo.SetRange("Cód. Entidad", CodEntidad);
        Atributo.SetRange("Cód. Tipo Atributo", CodTipoAtributo);
        Atributo.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        Atributo.SetFilter("Vigencia Hasta", '%1|>=%2', 0D, FechaRef);
        if not Atributo.FindLast() then
            exit('');
        if ValorAtr.Get(CodTipoAtributo, Atributo."Cód. Valor Padre", Atributo."Cód. Valor") then
            if ValorAtr.Descripción <> '' then
                exit(ValorAtr.Descripción);
        exit(Atributo."Cód. Valor");
    end;

    local procedure AgregarId(var Ids: TextBuilder; Id: Guid)
    begin
        if Ids.Length() > 0 then
            Ids.Append('|');
        Ids.Append(Format(Id));
    end;

    var
        ErrNoEsNumero: Label '"%1" no es un número.', Comment = '%1=lo tipeado';
        ErrNoEsFecha: Label '"%1" no es una fecha.', Comment = '%1=lo tipeado';
}
