namespace UAS.Payroll;

codeunit 50067 "Control Orden Acumuladores"
{
    // Diagnóstico estático de posibles precedencias, no una comprobación de importes.
    // Sin empleado no se conocen condiciones, incidencias ni todos los datos del orden efectivo.
    procedure Analizar(FechaRef: Date; var Buffer: Record "Diag. Orden Acum. Buffer" temporary): Integer
    begin
        exit(Analizar(FechaRef, '', '', '', Buffer));
    end;

    procedure Analizar(FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; var Buffer: Record "Diag. Orden Acum. Buffer" temporary): Integer
    begin
        exit(Analizar(FechaRef, TipoLiq, Convenio, Categoria, '', Buffer));
    end;

    // El corrector necesita sólo la fila elegida; un código vacío conserva el análisis completo.
    procedure Analizar(FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; CodAcumulador: Code[20]; var Buffer: Record "Diag. Orden Acum. Buffer" temporary): Integer
    var
        Acumulador: Record "Concepto Liquidación" temporary;
        Lector: Record "Concepto Liquidación" temporary;
        Parcial: Record "Diag. Orden Acum. Buffer" temporary;
        VersionMap: Dictionary of [Code[20], Date];
        Contextos: List of [Text];
        ClaveContexto: Text;
        MotivoContextos: Text;
        TipoContexto: Code[20];
        ConvenioContexto: Code[20];
        CategoriaContexto: Code[20];
        Hallazgos: Integer;
    begin
        Buffer.Reset();
        Buffer.DeleteAll();
        Clear(AportesConflictivosAnalisis);
        Clear(AportesTotalesAnalisis);
        Clear(LectoresTotalesAnalisis);
        Clear(FilasEtapasAnalisis);
        Clear(PrioridadesTestigoAnalisis);
        Clear(AmbitosTestigoAnalisis);
        Clear(DependenciasCompatiblesGuardadas);
        Clear(SemillasCompatiblesGuardadas);
        Clear(ErroresCompatiblesGuardados);
        Clear(ExpansionCompatibleGuardada);
        Clear(PendientesCompatiblesGuardados);
        Clear(SensibilidadDependenciasGuardada);
        AnalisisCompatibleEnCurso := false;
        CatalogoDependenciasPreparado := false;
        CatalogoContextosPreparado := false;
        ConceptosAnalisis.Reset();
        ConceptosAnalisis.DeleteAll();
        SoloConceptosDeclarados := false;
        if FechaRef = 0D then
            FechaRef := WorkDate();
        CargarVersionesVigentes(FechaRef, VersionMap);
        PrepararCatalogoDependencias();
        ContextoDependenciasConocido := false;
        InicializarContextoDependencias(ConceptosAnalisis);
        // Se conservan las claves de todas las filas potenciales, aun cuando ninguna rama
        // compatible las lea hoy. El lote puede comparar el mismo conjunto antes y después.
        PrepararFilasEstables(CodAcumulador, Buffer);
        EnumerarContextosOrden(FechaRef, TipoLiq, Convenio, Categoria, Contextos, MotivoContextos);
        PrepararFraccionesAnalisis(FechaRef);
        AnalisisCompatibleEnCurso := true;
        foreach ClaveContexto in Contextos do begin
            DesglosarContextoOrden(ClaveContexto, TipoContexto, ConvenioContexto, CategoriaContexto);
            EstablecerContextoDependencias(FechaRef, TipoContexto, ConvenioContexto, CategoriaContexto);
            InicializarContextoDependencias(ConceptosAnalisis);
            ReiniciarAnalisisContexto();
            PrepararLecturas(FechaRef, TipoContexto, ConvenioContexto, CategoriaContexto);
            Parcial.Reset();
            Parcial.DeleteAll();
            Acumulador.Copy(ConceptosAnalisis, true);
            Acumulador.SetRange("Es Acumulador", true);
            if CodAcumulador <> '' then
                Acumulador.SetRange(Código, CodAcumulador);
            if Acumulador.FindSet() then
                repeat
                    AnalizarAcumulador(Acumulador, FechaRef, TipoContexto, ConvenioContexto, CategoriaContexto, VersionMap, Parcial);
                until Acumulador.Next() = 0;
            Lector.Copy(ConceptosAnalisis, true);
            Lector.SetRange("Es Acumulador", false);
            if CodAcumulador <> '' then
                Lector.SetRange(Código, CodAcumulador);
            if Lector.FindSet() then
                repeat
                    if ConceptosIncluidos.ContainsKey(Lector.Código) then
                        AnalizarReferencias(Lector, FechaRef, TipoContexto, ConvenioContexto, Parcial);
                until Lector.Next() = 0;
            CombinarAnalisisContexto(Parcial, Buffer);
        end;
        CompletarAnalisisCompatible(Buffer, MotivoContextos, Hallazgos);
        ContextoDependenciasConocido := false;
        AnalisisCompatibleEnCurso := false;
        CatalogoDependenciasPreparado := false;
        Buffer.Reset();
        if Buffer.FindFirst() then;
        exit(Hallazgos);
    end;

    local procedure PrepararFilasEstables(CodAcumulador: Code[20]; var Buffer: Record "Diag. Orden Acum. Buffer" temporary)
    var
        Concepto: Record "Concepto Liquidación" temporary;
        Productor: Record "Concepto Liquidación";
        Dependencias: List of [Code[20]];
        Codigo: Code[20];
        Errores: Text;
        TieneFila: Boolean;
    begin
        Concepto.Copy(ConceptosAnalisis, true);
        if CodAcumulador <> '' then
            Concepto.SetRange(Código, CodAcumulador);
        if Concepto.FindSet() then
            repeat
                TieneFila := Concepto."Es Acumulador";
                if not TieneFila then begin
                    ObtenerDependenciasEnContexto(Concepto, Dependencias, Errores);
                    TieneFila := Errores <> '';
                    foreach Codigo in Dependencias do
                        if ObtenerVigenteDependencia(Codigo, Productor) then
                            if not Productor."Es Acumulador" then
                                TieneFila := true;
                end;
                if TieneFila then begin
                    Buffer.Init();
                    Buffer."Cód. Acumulador" := Concepto.Código;
                    Buffer.Descripción := Concepto.Descripción;
                    if not Concepto."Es Acumulador" then
                        Buffer."Concepto Mín. Lectura" := Concepto.Código;
                    Buffer.Insert();
                end;
            until Concepto.Next() = 0;
    end;

    local procedure ReiniciarAnalisisContexto()
    begin
        Clear(OrdenesPosiblesAnalisis);
        Clear(OrdenesPendientes);
        Clear(OrdenesConRamas);
        Clear(ParesPendientes);
        Clear(ConceptosIncluidos);
        Clear(ProduccionesIncluidas);
        Clear(ProduccionesPendientes);
        Clear(LectoresPorAcumulador);
    end;

    local procedure CombinarAnalisisContexto(var Parcial: Record "Diag. Orden Acum. Buffer" temporary; var Buffer: Record "Diag. Orden Acum. Buffer" temporary)
    var
        Prioridad: Integer;
        Anterior: Integer;
    begin
        if Parcial.FindSet() then
            repeat
                Prioridad := 0;
                if (Parcial."Cant. Aportes" > 0) and (Parcial."Cant. Lecturas" > 0) then
                    Prioridad := 1;
                if Parcial."Requiere Contexto" then
                    Prioridad := 2;
                if Parcial."Aportes en Conflicto" > 0 then
                    Prioridad := 3;
                if not Buffer.Get(Parcial."Cód. Acumulador") then begin
                    Buffer := Parcial;
                    Buffer.Insert();
                end;
                Buffer."Requiere Contexto" := Buffer."Requiere Contexto" or Parcial."Requiere Contexto";
                Anterior := -1;
                if not PrioridadesTestigoAnalisis.Get(Parcial."Cód. Acumulador", Anterior) then
                    Anterior := -1;
                if Prioridad > Anterior then begin
                    // Las dos posiciones se copian juntas de un mismo ámbito. Mezclar el
                    // máximo de un convenio y el mínimo de otro inventaría una precedencia.
                    Buffer."Orden Máx. Aporte" := Parcial."Orden Máx. Aporte";
                    Buffer."Concepto Máx. Aporte" := Parcial."Concepto Máx. Aporte";
                    Buffer."Orden Mín. Lectura" := Parcial."Orden Mín. Lectura";
                    Buffer."Concepto Mín. Lectura" := Parcial."Concepto Mín. Lectura";
                    PrioridadesTestigoAnalisis.Set(Parcial."Cód. Acumulador", Prioridad);
                    AmbitosTestigoAnalisis.Set(Parcial."Cód. Acumulador", StrSubstNo('Tipo %1, convenio %2, categoría %3. ', TipoDependencias, ConvenioDependencias, CategoriaDependencias));
                end;
                Buffer.Modify();
            until Parcial.Next() = 0;
    end;

    local procedure CompletarAnalisisCompatible(var Buffer: Record "Diag. Orden Acum. Buffer" temporary; MotivoContextos: Text; var Hallazgos: Integer)
    var
        Lista: List of [Code[20]];
        Codigo: Code[20];
        Codigos: Text;
        Observacion: Text;
        Ambito: Text;
    begin
        Hallazgos := 0;
        if Buffer.FindSet() then
            repeat
                Buffer."Cant. Aportes" := 0;
                Buffer."Cant. Lecturas" := 0;
                Buffer."Aportes en Conflicto" := 0;
                if AportesTotalesAnalisis.Get(Buffer."Cód. Acumulador", Lista) then
                    Buffer."Cant. Aportes" := Lista.Count();
                if LectoresTotalesAnalisis.Get(Buffer."Cód. Acumulador", Lista) then
                    Buffer."Cant. Lecturas" := Lista.Count();
                Codigos := '';
                if AportesConflictivosAnalisis.Get(Buffer."Cód. Acumulador", Lista) then begin
                    Buffer."Aportes en Conflicto" := Lista.Count();
                    foreach Codigo in Lista do begin
                        if Codigos <> '' then
                            Codigos += ', ';
                        Codigos += Codigo;
                    end;
                end;
                if MotivoContextos <> '' then
                    Buffer."Requiere Contexto" := true;
                Buffer."Códigos en Conflicto" := CopyStr(Codigos, 1, MaxStrLen(Buffer."Códigos en Conflicto"));
                Buffer.Conflicto := (Buffer."Aportes en Conflicto" > 0) or Buffer."Requiere Contexto";
                Observacion := 'Se comparan únicamente tipos, convenios, categorías y ramas compatibles. ';
                if AmbitosTestigoAnalisis.Get(Buffer."Cód. Acumulador", Ambito) then
                    Observacion := Ambito + 'Los órdenes corresponden a ese mismo ámbito. ';
                if FilasEtapasAnalisis.ContainsKey(Buffer."Cód. Acumulador") then
                    Observacion += 'Un lector también aporta: posible subtotal por etapas. ';
                if Buffer."Requiere Contexto" then
                    Observacion += 'Hay una precedencia potencial no demostrada por datos o ramas pendientes. '
                else
                    if Buffer.Conflicto then
                        Observacion += 'Hay aportes posteriores en un mismo ámbito compatible. '
                    else
                        Observacion += 'Sin precedencias posteriores en los ámbitos verificados. ';
                Observacion += MotivoContextos;
                Buffer.Observación := CopyStr(Observacion, 1, MaxStrLen(Buffer.Observación));
                Buffer.Modify();
                if Buffer.Conflicto then
                    Hallazgos += 1;
            until Buffer.Next() = 0;
    end;

    local procedure RegistrarCodigoAnalisis(var Indice: Dictionary of [Code[20], List of [Code[20]]]; Fila: Code[20]; Codigo: Code[20])
    var
        Lista: List of [Code[20]];
    begin
        if not Indice.Get(Fila, Lista) then begin
            Lista.Add(Codigo);
            Indice.Add(Fila, Lista);
        end else
            if not Lista.Contains(Codigo) then
                Lista.Add(Codigo);
    end;

    internal procedure EnumerarContextosOrden(FechaRef: Date; TipoFiltro: Code[20]; CCTFiltro: Code[20]; CatFiltro: Code[20]; var Contextos: List of [Text]; var Motivo: Text): Boolean
    var
        Tipo: Record "Tipo Liquidación" temporary;
        Convenio: Record "Convenio Colectivo" temporary;
        Categoria: Record "Categoría CCT" temporary;
        Restriccion: Record "Concepto CCT Vigente" temporary;
        Tipos: List of [Code[20]];
        Convenios: List of [Code[20]];
        Categorias: List of [Code[20]];
        Explicitas: List of [Code[20]];
        TipoCodigo: Code[20];
        ConvenioCodigo: Code[20];
        CategoriaCodigo: Code[20];
        Clave: Text;
        Elemento: Text;
        Guardados: List of [Text];
    begin
        Clear(Contextos);
        Motivo := '';
        PrepararCatalogoContextos();
        Motivo := MotivoCatalogoContextos;
        Clave := Format(FechaRef, 0, 9) + ClaveContextoOrden(TipoFiltro, CCTFiltro, CatFiltro);
        if ContextosOrdenGuardados.Get(Clave, Guardados) then begin
            foreach Elemento in Guardados do
                Contextos.Add(Elemento);
            Motivo := MotivosContextosGuardados.Get(Clave);
            exit(Motivo = '');
        end;
        Tipo.Copy(TiposContextos, true);
        Convenio.Copy(ConveniosContextos, true);
        Categoria.Copy(CategoriasContextos, true);
        Restriccion.Copy(RestriccionesContextos, true);
        if TipoFiltro <> '' then begin
            Tipos.Add(TipoFiltro);
            if not Tipo.Get(TipoFiltro) then
                Motivo := 'Hay tipos sin maestro; no se conoce su valor numérico.';
        end else begin
            Tipos.Add(''); // el blanco es un valor conocido, no una rama elegida por omisión
            if Tipo.FindSet() then
                repeat
                    if not Tipos.Contains(Tipo.Código) then
                        Tipos.Add(Tipo.Código);
                until Tipo.Next() = 0;
            // Una configuración importada puede referir códigos todavía sin maestro.
                    foreach Elemento in TiposReferidosContextos do
                        if (Elemento <> '') and (StrLen(Elemento) <= 20) then begin
                            TipoCodigo := CopyStr(Elemento, 1, 20);
                            if not Tipos.Contains(TipoCodigo) then begin
                                Tipos.Add(TipoCodigo);
                                Motivo := 'Hay tipos referidos sin maestro; su valor numérico queda pendiente.';
                            end;
                        end;
        end;
        if CCTFiltro <> '' then
            Convenios.Add(CCTFiltro)
        else begin
            Convenios.Add('');
            if Convenio.FindSet() then
                repeat
                    if not Convenios.Contains(Convenio.Código) then
                        Convenios.Add(Convenio.Código);
                until Convenio.Next() = 0;
            foreach ConvenioCodigo in ConveniosReferidosContextos do
                if not Convenios.Contains(ConvenioCodigo) then
                    Convenios.Add(ConvenioCodigo);
            Restriccion.SetFilter("Vigencia Desde", '<=%1', FechaRef);
            if Restriccion.FindSet() then
                repeat
                    if not Convenios.Contains(Restriccion."Cód. Convenio") then
                        Convenios.Add(Restriccion."Cód. Convenio");
                until Restriccion.Next() = 0;
        end;
        foreach ConvenioCodigo in Convenios do begin
            Clear(Categorias);
            Clear(Explicitas);
            if CatFiltro <> '' then
                Categorias.Add(CatFiltro)
            else begin
                Categorias.Add('');
                Restriccion.Reset();
                Restriccion.SetRange("Cód. Convenio", ConvenioCodigo);
                Restriccion.SetFilter("Vigencia Desde", '<=%1', FechaRef);
                if Restriccion.FindSet() then
                    repeat
                        CategoriaCodigo := Restriccion."Cód. Categoría";
                        if (CategoriaCodigo <> '') and not Explicitas.Contains(CategoriaCodigo) then begin
                            Explicitas.Add(CategoriaCodigo);
                            Categorias.Add(CategoriaCodigo);
                        end;
                    until Restriccion.Next() = 0;
                Categoria.Reset();
                Categoria.SetRange("Cód. Convenio", ConvenioCodigo);
                if Categoria.FindSet() then
                    repeat
                        if not Explicitas.Contains(Categoria.Código) then begin
                            if not Categorias.Contains(Categoria.Código) then
                                Categorias.Add(Categoria.Código);
                            break; // representante real de la clase residual; no hay restricción que los distinga
                        end;
                    until Categoria.Next() = 0;
            end;
            if CatFiltro = '' then
                AgruparCategoriasEquivalentes(FechaRef, ConvenioCodigo, Categorias);
            foreach TipoCodigo in Tipos do
                foreach CategoriaCodigo in Categorias do
                    Contextos.Add(ClaveContextoOrden(TipoCodigo, ConvenioCodigo, CategoriaCodigo));
        end;
        foreach Elemento in Contextos do
            Guardados.Add(Elemento);
        ContextosOrdenGuardados.Add(Clave, Guardados);
        MotivosContextosGuardados.Add(Clave, Motivo);
        exit(Motivo = '');
    end;

    local procedure AgruparCategoriasEquivalentes(FechaRef: Date; Convenio: Code[20]; var Categorias: List of [Code[20]])
    var
        Entrada: List of [Code[20]];
        Vistas: Dictionary of [Text, Boolean];
        Restriccion: Record "Concepto CCT Vigente" temporary;
        Concepto: Record "Concepto Liquidación";
        Codigos: List of [Code[20]];
        Codigo: Code[20];
        Categoria: Code[20];
        Firma: Text;
        Pendiente: Boolean;
    begin
        foreach Categoria in Categorias do
            Entrada.Add(Categoria);
        Restriccion.Copy(RestriccionesContextos, true);
        Restriccion.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        if Restriccion.FindSet() then
            repeat
                if not Codigos.Contains(Restriccion."Cód. Concepto") then
                    Codigos.Add(Restriccion."Cód. Concepto");
            until Restriccion.Next() = 0;
        Clear(Categorias);
        foreach Categoria in Entrada do begin
            Firma := '';
            foreach Codigo in Codigos do begin
                Concepto.Código := Codigo;
                if ConceptoIncluidoEnContexto(Concepto, FechaRef, '', Convenio, Categoria, Pendiente) then
                    Firma += Format(StrLen(Codigo), 0, 9) + ':' + Codigo + ';';
            end;
            if Categoria = '' then
                Firma := 'BLANCO:' + Firma;
            if not Vistas.ContainsKey(Firma) then begin
                Vistas.Add(Firma, true);
                Categorias.Add(Categoria);
            end;
        end;
    end;

    local procedure ClaveContextoOrden(Tipo: Code[20]; Convenio: Code[20]; Categoria: Code[20]): Text
    var
        Valor: JsonObject;
        Resultado: Text;
    begin
        Valor.Add('t', Tipo);
        Valor.Add('c', Convenio);
        Valor.Add('g', Categoria);
        Valor.WriteTo(Resultado);
        exit(Resultado);
    end;

    internal procedure DesglosarContextoOrden(Clave: Text; var Tipo: Code[20]; var Convenio: Code[20]; var Categoria: Code[20])
    var
        Valor: JsonObject;
        Token: JsonToken;
    begin
        Valor.ReadFrom(Clave);
        Valor.Get('t', Token);
        Tipo := CopyStr(Token.AsValue().AsText(), 1, 20);
        Valor.Get('c', Token);
        Convenio := CopyStr(Token.AsValue().AsText(), 1, 20);
        Valor.Get('g', Token);
        Categoria := CopyStr(Token.AsValue().AsText(), 1, 20);
    end;

    local procedure PrepararCatalogoContextos()
    var
        Tipo: Record "Tipo Liquidación";
        Convenio: Record "Convenio Colectivo";
        Categoria: Record "Categoría CCT";
        Restriccion: Record "Concepto CCT Vigente";
        Fraccion: Record "Fracción Acumulador";
        Definicion: Record "Concepto Liquidación";
        Elemento: Text;
    begin
        if CatalogoContextosPreparado then
            exit;
        TiposContextos.Reset();
        TiposContextos.DeleteAll();
        ConveniosContextos.Reset();
        ConveniosContextos.DeleteAll();
        CategoriasContextos.Reset();
        CategoriasContextos.DeleteAll();
        RestriccionesContextos.Reset();
        RestriccionesContextos.DeleteAll();
        FraccionesContextos.Reset();
        FraccionesContextos.DeleteAll();
        Clear(ContextosOrdenGuardados);
        Clear(MotivosContextosGuardados);
        Clear(AplicabilidadContextosGuardada);
        Clear(TiposReferidosContextos);
        Clear(NombresConceptosContextos);
        Clear(FormulasOrdenAdmisiblesGuardadas);
        Clear(ConveniosReferidosContextos);
        MotivoCatalogoContextos := '';
        if Tipo.FindSet() then
            repeat
                TiposContextos := Tipo;
                TiposContextos.Insert(false);
            until Tipo.Next() = 0;
        if Convenio.FindSet() then
            repeat
                ConveniosContextos := Convenio;
                ConveniosContextos.Insert(false);
            until Convenio.Next() = 0;
        if Categoria.FindSet() then
            repeat
                CategoriasContextos := Categoria;
                CategoriasContextos.Insert(false);
            until Categoria.Next() = 0;
        if Restriccion.FindSet() then
            repeat
                RestriccionesContextos := Restriccion;
                RestriccionesContextos.Insert(false);
            until Restriccion.Next() = 0;
        if Fraccion.FindSet() then
            repeat
                FraccionesContextos := Fraccion;
                FraccionesContextos.Insert(false);
                RecogerConveniosFiltro(Fraccion."Filtro Convenio");
            until Fraccion.Next() = 0;
        Definicion.SetLoadFields(Código, "Tipos Liq. Aplicables", Fórmula, Condición, "Fórmula Orden Cálculo", "Variable Cantidad", "Variable Base", "Factor Importe Consumo", "Cantidad Matriz");
        if Definicion.FindSet() then
            repeat
                NombresConceptosContextos.Set(Definicion.Código, true);
                foreach Elemento in Definicion."Tipos Liq. Aplicables".Split('|') do
                    if not TiposReferidosContextos.Contains(Elemento) then
                        TiposReferidosContextos.Add(Elemento);
                RecogerLiteralesContexto(Definicion.Fórmula + ' ' + Definicion.Condición + ' ' + Definicion."Fórmula Orden Cálculo" + ' ' +
                    Definicion."Variable Cantidad" + ' ' + Definicion."Variable Base" + ' ' + Definicion."Factor Importe Consumo" + ' ' + Definicion."Cantidad Matriz");
            until Definicion.Next() = 0;
        CatalogoContextosPreparado := true;
    end;

    local procedure RecogerConveniosFiltro(Filtro: Text)
    var
        Parte: Text;
        Termino: Text;
        Codigo: Code[20];
    begin
        foreach Parte in Filtro.Split('|') do
            foreach Termino in Parte.Split('&') do begin
                Termino := DelChr(Termino, '=', '()').Trim();
                while CopyStr(Termino, 1, 1) in ['<', '>', '='] do
                    Termino := CopyStr(Termino, 2);
                if Termino <> '' then
                    if Termino.Contains('..') or Termino.Contains('*') or Termino.Contains('?') or Termino.Contains('@') then
                        AnotarErrorDependencia(MotivoCatalogoContextos, 'Hay filtros de convenio con rangos o patrones que requieren confirmar su dominio.')
                    else
                        if StrLen(Termino) <= 20 then begin
                            Codigo := CopyStr(Termino, 1, 20);
                            if not ConveniosReferidosContextos.Contains(Codigo) then
                                ConveniosReferidosContextos.Add(Codigo);
                        end else
                            AnotarErrorDependencia(MotivoCatalogoContextos, 'Hay un convenio referido de más de veinte caracteres.');
            end;
    end;

    local procedure RecogerLiteralesContexto(Texto: Text)
    var
        Posicion: Integer;
        Inicio: Integer;
        Siguiente: Integer;
        Token: Text;
        Literal: Text;
        Caracter: Text;
        Codigo: Code[20];
    begin
        Texto := UpperCase(Texto);
        Posicion := 1;
        while Posicion <= StrLen(Texto) do begin
            Caracter := CopyStr(Texto, Posicion, 1);
            if Caracter = '''' then begin
                Posicion += 1;
                while Posicion <= StrLen(Texto) do begin
                    if CopyStr(Texto, Posicion, 1) = '''' then begin
                        if CopyStr(Texto, Posicion + 1, 1) <> '''' then
                            break;
                        Posicion += 1;
                    end;
                    Posicion += 1;
                end;
                Posicion += 1;
            end else
                if EsLetra(Caracter) or (Caracter = '_') then begin
                    Inicio := Posicion;
                    Posicion += 1;
                    while EsCaracterIdentificador(CopyStr(Texto, Posicion, 1)) do
                        Posicion += 1;
                    Token := CopyStr(Texto, Inicio, Posicion - Inicio);
                    if Token in ['CONVENIO', 'TIPO_LIQ'] then begin
                        Siguiente := Posicion;
                        while EsEspacio(CopyStr(Texto, Siguiente, 1)) do
                            Siguiente += 1;
                        while CopyStr(Texto, Siguiente, 1) in ['=', '<', '>'] do
                            Siguiente += 1;
                        while EsEspacio(CopyStr(Texto, Siguiente, 1)) do
                            Siguiente += 1;
                        if CopyStr(Texto, Siguiente, 1) = '''' then begin
                            Siguiente += 1;
                            Literal := '';
                            while Siguiente <= StrLen(Texto) do begin
                                Caracter := CopyStr(Texto, Siguiente, 1);
                                if Caracter = '''' then begin
                                    if CopyStr(Texto, Siguiente + 1, 1) <> '''' then
                                        break;
                                    Siguiente += 1;
                                end;
                                Literal += Caracter;
                                Siguiente += 1;
                            end;
                            // Un literal más largo que el Code[20] no puede ser un código de
                            // contexto. No truncarlo ni convertir texto ilustrativo en un ámbito.
                            if StrLen(Literal) <= 20 then
                                if Token = 'CONVENIO' then begin
                                    Codigo := CopyStr(Literal, 1, 20);
                                    if not ConveniosReferidosContextos.Contains(Codigo) then
                                        ConveniosReferidosContextos.Add(Codigo);
                                end else
                                    if not TiposReferidosContextos.Contains(Literal) then
                                        TiposReferidosContextos.Add(Literal);
                        end;
                    end;
                end else
                    Posicion += 1;
        end;
    end;

    internal procedure ConceptoIncluidoEnContexto(Concepto: Record "Concepto Liquidación"; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; var ParDesconocido: Boolean): Boolean
    var
        Tipo: Record "Tipo Liquidación" temporary;
        Restriccion: Record "Concepto CCT Vigente" temporary;
        Clave: Text;
        Resultado: Boolean;
        Declarado: Boolean;
        SoloDeclarados: Boolean;
    begin
        ParDesconocido := false;
        PrepararCatalogoContextos();
        Tipo.Copy(TiposContextos, true);
        if Tipo.Get(TipoLiq) then
            SoloDeclarados := Tipo."Sólo Conceptos Declarados";
        Declarado := ('|' + Concepto."Tipos Liq. Aplicables" + '|').Contains('|' + TipoLiq + '|');
        if Concepto."Tipo Concepto" = Concepto."Tipo Concepto"::Informativo then begin
            if (Concepto."Tipos Liq. Aplicables" <> '') and not Declarado then
                exit(false);
        end else
            if SoloDeclarados then begin
                if not Declarado then
                    exit(false);
            end else
                if (Concepto."Tipos Liq. Aplicables" <> '') and not Declarado then
                    exit(false);
        if Concepto."Par CCT a Usar" <> Concepto."Par CCT a Usar"::Entidad then begin
            ParDesconocido := true;
            exit(true);
        end;
        Clave := Concepto.Código + Format(FechaRef, 0, 9) + ClaveContextoOrden('', Convenio, Categoria);
        if AplicabilidadContextosGuardada.Get(Clave, Resultado) then
            exit(Resultado);
        Restriccion.Copy(RestriccionesContextos, true);
        Restriccion.SetRange("Cód. Concepto", Concepto.Código);
        Restriccion.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        Resultado := true;
        if not Restriccion.IsEmpty() then begin
            Restriccion.SetRange(Excluye, true);
            Restriccion.SetRange("Cód. Convenio", Convenio);
            Restriccion.SetFilter("Cód. Categoría", '%1|%2', '', Categoria);
            if not Restriccion.IsEmpty() then
                Resultado := false
            else begin
                Restriccion.SetRange(Excluye, false);
                Restriccion.SetRange("Cód. Convenio");
                Restriccion.SetRange("Cód. Categoría");
                if not Restriccion.IsEmpty() then begin
                    Restriccion.SetRange("Cód. Convenio", Convenio);
                    Restriccion.SetFilter("Cód. Categoría", '%1|%2', '', Categoria);
                    Resultado := not Restriccion.IsEmpty();
                end;
            end;
        end;
        AplicabilidadContextosGuardada.Add(Clave, Resultado);
        exit(Resultado);
    end;

    /// <summary>Elegibilidad para publicar un resultado; las lecturas de su condición se analizan por separado.</summary>
    internal procedure ConceptoProduceEnContexto(Concepto: Record "Concepto Liquidación"; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; var RequiereContexto: Boolean): Boolean
    var
        Estado: Integer;
    begin
        RequiereContexto := false;
        if not ConceptoIncluidoEnContexto(Concepto, FechaRef, TipoLiq, Convenio, Categoria, RequiereContexto) then
            exit(false);
        if Concepto.Condición.Trim() = '' then
            exit(true);
        Estado := CondicionEnContexto(Concepto.Condición, FechaRef, TipoLiq, Convenio, Concepto."Par CCT a Usar" = Concepto."Par CCT a Usar"::Entidad);
        if Estado = 0 then
            exit(false);
        if Estado = -1 then
            RequiereContexto := true;
        exit(true);
    end;

    local procedure AnalizarAcumulador(Acumulador: Record "Concepto Liquidación"; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; var VersionMap: Dictionary of [Code[20], Date]; var Buffer: Record "Diag. Orden Acum. Buffer" temporary): Boolean
    var
        Aportes: List of [Code[20]];
        Lecturas: List of [Code[20]];
        OrdenAportes: Dictionary of [Code[20], Integer];
        OrdenLecturas: Dictionary of [Code[20], Integer];
        CodAporte: Code[20];
        CodLectura: Code[20];
        OrdenAporte: Integer;
        OrdenLectura: Integer;
        ConocidoAporte: Boolean;
        ConocidaLectura: Boolean;
        AporteTardio: Boolean;
        EsEtapa: Boolean;
        UsaRamas: Boolean;
        Codigos: Text;
        Observacion: Text;
        LecturaCondicional: Boolean;
        LectorDependencias: List of [Code[20]];
        LectorErrores: Text;
        LectorConcepto: Record "Concepto Liquidación";
    begin
        BuscarAportes(Acumulador.Código, FechaRef, TipoLiq, Convenio, VersionMap, Aportes, OrdenAportes);
        BuscarLecturas(Acumulador.Código, FechaRef, TipoLiq, Convenio, VersionMap, Lecturas, OrdenLecturas);
        Buffer.Init();
        Buffer."Cód. Acumulador" := Acumulador.Código;
        Buffer.Descripción := Acumulador.Descripción;
        Buffer."Cant. Aportes" := Aportes.Count();
        Buffer."Cant. Lecturas" := Lecturas.Count();
        ExtremoConocido(OrdenAportes, true, Buffer."Orden Máx. Aporte", Buffer."Concepto Máx. Aporte");
        ExtremoConocido(OrdenLecturas, false, Buffer."Orden Mín. Lectura", Buffer."Concepto Mín. Lectura");
        foreach CodLectura in Lecturas do
            begin
                RegistrarCodigoAnalisis(LectoresTotalesAnalisis, Acumulador.Código, CodLectura);
                if Aportes.Contains(CodLectura) then begin
                    EsEtapa := true;
                    FilasEtapasAnalisis.Set(Acumulador.Código, true);
                end;
            end;
        foreach CodLectura in Lecturas do
            if OrdenesConRamas.Contains(CodLectura) then
                UsaRamas := true;
        foreach CodAporte in Aportes do begin
            RegistrarCodigoAnalisis(AportesTotalesAnalisis, Acumulador.Código, CodAporte);
            AporteTardio := false;
            if OrdenesConRamas.Contains(CodAporte) then
                UsaRamas := true;
            ConocidoAporte := OrdenAportes.Get(CodAporte, OrdenAporte);
            foreach CodLectura in Lecturas do
                // La lectura antes del aporte propio es una etapa normal del acumulador.
                if CodAporte <> CodLectura then begin
                    ConocidaLectura := OrdenLecturas.Get(CodLectura, OrdenLectura);
                    if ConocidoAporte and ConocidaLectura then begin
                        if LlegaTarde(OrdenAporte, CodAporte, OrdenLectura, CodLectura) then begin
                            LecturaCondicional := false;
                            if ObtenerVigenteDependencia(CodLectura, LectorConcepto) then begin
                                ObtenerDependenciasEnContexto(LectorConcepto, LectorDependencias, LectorErrores);
                                LecturaCondicional := ContextosDependenciasGuardados.Get(CodLectura);
                            end;
                            LecturaCondicional := LecturaCondicional or not ProduccionesIncluidas.ContainsKey(CodLectura) or ProduccionesPendientes.Contains(CodLectura);
                            if ParesPendientes.Contains(CodAporte) or ParesPendientes.Contains(CodLectura) or
                               OrdenesConRamas.Contains(CodAporte) or OrdenesConRamas.Contains(CodLectura) or LecturaCondicional or ProduccionesPendientes.Contains(CodAporte)
                            then
                                Buffer."Requiere Contexto" := true
                            else
                                AporteTardio := true;
                        end;
                    end else
                        Buffer."Requiere Contexto" := true;
                end;
            if AporteTardio then begin
                RegistrarCodigoAnalisis(AportesConflictivosAnalisis, Acumulador.Código, CodAporte);
                Buffer."Aportes en Conflicto" += 1;
                if Codigos <> '' then
                    Codigos += ', ';
                Codigos += CodAporte + ' (' + Format(OrdenAporte) + ')';
            end;
        end;
        Buffer.Conflicto := (Buffer."Aportes en Conflicto" > 0) or Buffer."Requiere Contexto";
        Buffer."Códigos en Conflicto" := CopyStr(Codigos, 1, MaxStrLen(Buffer."Códigos en Conflicto"));
        // Mover un lector puede cambiar una etapa intencional o crear otra dependencia.
        Buffer."Orden Sugerido" := 0;
        if UsaRamas then
            Observacion := 'Extremos posibles: máximo aporte y mínima lectura entre todas las ramas IF. ';
        if Buffer."Requiere Contexto" then
            Observacion += 'Orden desconocido o par pendiente en una precedencia potencial. ';
        if EsEtapa then
            Observacion += 'Un lector también aporta: puede ser una etapa intencional del acumulador. ';
        if Buffer.Conflicto then
            Observacion += 'Posible precedencia; confirmar condiciones e incidencias en una liquidación.'
        else
            Observacion += 'Sin precedencias posteriores detectadas con los datos disponibles.';
        if (Convenio <> '') and (Categoria = '') then
            Observacion += ' Categoría sin seleccionar: no se excluyen conceptos por categoría.';
        Buffer.Observación := CopyStr(Observacion, 1, MaxStrLen(Buffer.Observación));
        Buffer.Insert();
        exit(Buffer.Conflicto);
    end;

    local procedure AnalizarReferencias(Lector: Record "Concepto Liquidación"; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; var Buffer: Record "Diag. Orden Acum. Buffer" temporary): Boolean
    var
        Productor: Record "Concepto Liquidación";
        Dependencias: List of [Code[20]];
        Productores: List of [Code[20]];
        Ordenes: Dictionary of [Code[20], Integer];
        Pila: List of [Code[20]];
        Codigo: Code[20];
        OrdenProductor: Integer;
        OrdenLector: Integer;
        LectorConocido: Boolean;
        ProductorConocido: Boolean;
        Tardio: Boolean;
        UsaRamas: Boolean;
        Errores: Text;
        Ciclo: Text;
        Codigos: Text;
        Observacion: Text;
        RamaPendiente: Boolean;
    begin
        ObtenerDependenciasEnContexto(Lector, Dependencias, Errores);
        RamaPendiente := ContextosDependenciasGuardados.Get(Lector.Código);
        RamaPendiente := RamaPendiente or not ProduccionesIncluidas.ContainsKey(Lector.Código) or ProduccionesPendientes.Contains(Lector.Código);
        foreach Codigo in Dependencias do
            if ObtenerVigenteDependencia(Codigo, Productor) then
                if not Productor."Es Acumulador" then
                    if ProduccionesIncluidas.ContainsKey(Codigo) then
                        Productores.Add(Codigo);
        if BuscarCicloEnContexto(Lector, Pila, Ciclo) then
            if Errores = '' then
                Errores := Ciclo
            else
                if Errores <> Ciclo then
                    Errores := Ciclo + '; ' + Errores;
        if (Productores.Count() = 0) and (Errores = '') then
            exit(false);
        Buffer.Init();
        // El lector es no acumulador: su código real no colisiona con las filas de bases.
        // Esta igualdad identifica la clase de fila sin campos ni claves sintéticas.
        Buffer."Cód. Acumulador" := Lector.Código;
        Buffer."Concepto Mín. Lectura" := Lector.Código;
        Buffer.Descripción := Lector.Descripción;
        Buffer."Cant. Aportes" := Productores.Count();
        Buffer."Cant. Lecturas" := 1;
        RegistrarCodigoAnalisis(LectoresTotalesAnalisis, Lector.Código, Lector.Código);
        Buffer."Requiere Contexto" := Errores <> '';
        LectorConocido := ResolverOrdenAnalisis(Lector, FechaRef, TipoLiq, Convenio, false, OrdenLector);
        if LectorConocido then
            Buffer."Orden Mín. Lectura" := OrdenLector
        else
            Buffer."Requiere Contexto" := true;
        UsaRamas := OrdenesConRamas.Contains(Lector.Código);
        foreach Codigo in Productores do begin
            RegistrarCodigoAnalisis(AportesTotalesAnalisis, Lector.Código, Codigo);
            ObtenerVigenteDependencia(Codigo, Productor);
            ProductorConocido := ResolverOrdenAnalisis(Productor, FechaRef, TipoLiq, Convenio, true, OrdenProductor);
            if ProductorConocido then
                Ordenes.Add(Codigo, OrdenProductor)
            else
                Buffer."Requiere Contexto" := true;
            if OrdenesConRamas.Contains(Codigo) then
                UsaRamas := true;
            // #propio es un ciclo, no la etapa deliberada de un acumulador.
            Tardio := Codigo = Lector.Código;
            if LectorConocido and ProductorConocido then
                Tardio := Tardio or LlegaTarde(OrdenProductor, Codigo, OrdenLector, Lector.Código);
            if Tardio then begin
                if RamaPendiente or ParesPendientes.Contains(Codigo) or ParesPendientes.Contains(Lector.Código) or
                   OrdenesConRamas.Contains(Codigo) or OrdenesConRamas.Contains(Lector.Código) or ProduccionesPendientes.Contains(Codigo)
                then
                    Buffer."Requiere Contexto" := true
                else begin
                    Buffer."Aportes en Conflicto" += 1;
                    RegistrarCodigoAnalisis(AportesConflictivosAnalisis, Lector.Código, Codigo);
                end;
                if Codigos <> '' then
                    Codigos += ', ';
                Codigos += Codigo;
                if ProductorConocido then
                    Codigos += ' (' + Format(OrdenProductor) + ')';
                if ParesPendientes.Contains(Codigo) or ParesPendientes.Contains(Lector.Código) then
                    Buffer."Requiere Contexto" := true;
            end;
        end;
        ExtremoConocido(Ordenes, true, Buffer."Orden Máx. Aporte", Buffer."Concepto Máx. Aporte");
        Buffer."Códigos en Conflicto" := CopyStr(Codigos, 1, MaxStrLen(Buffer."Códigos en Conflicto"));
        Buffer.Conflicto := (Buffer."Aportes en Conflicto" > 0) or Buffer."Requiere Contexto";
        Observacion := 'Referencias calculadas del lector ' + Lector.Código + '. ';
        if Errores <> '' then
            Observacion += Errores + '. '
        else
            if Buffer."Requiere Contexto" then
                Observacion += 'Orden desconocido o par pendiente de contexto. ';
        if UsaRamas then
            Observacion += 'Se comparan todas las ramas IF mediante extremos posibles. ';
        if Buffer.Conflicto then
            Observacion += 'Revisá productores y lectores antes de cambiar un orden.'
        else
            Observacion += 'Los productores quedan antes del lector en todas las posiciones verificadas.';
        Buffer.Observación := CopyStr(Observacion, 1, MaxStrLen(Buffer.Observación));
        Buffer.Insert();
        exit(Buffer.Conflicto);
    end;

    local procedure BuscarAportes(CodAcumulador: Code[20]; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; var VersionMap: Dictionary of [Code[20], Date]; var Aportes: List of [Code[20]]; var Ordenes: Dictionary of [Code[20], Integer])
    var
        Frac: Record "Fracción Acumulador" temporary;
        Concepto: Record "Concepto Liquidación" temporary;
        Codigos: List of [Code[20]];
        Codigo: Code[20];
        Vigencia: Date;
        Orden: Integer;
    begin
        Concepto.Copy(ConceptosAnalisis, true);
        Frac.Copy(FraccionesVigentesAnalisis, true);
        if not CodigosAportesAnalisis.Get(CodAcumulador, Codigos) then
            exit;
        foreach Codigo in Codigos do
            if ProduccionesIncluidas.ContainsKey(Codigo) then
                if Concepto.Get(Codigo, VersionMap.Get(Codigo)) then
                    if FechasAportesAnalisis.Get(Format(StrLen(Codigo), 0, 9) + ':' + Codigo + CodAcumulador, Vigencia) then
                    if Frac.Get(Codigo, Vigencia, CodAcumulador) then
                        if Frac.Porcentaje <> 0 then
                            if FraccionIncluida(Frac, Concepto, Convenio) then begin
                                Aportes.Add(Codigo);
                                if ResolverOrdenAnalisis(Concepto, FechaRef, TipoLiq, Convenio, true, Orden) then
                                    Ordenes.Add(Codigo, Orden);
                            end;
    end;

    local procedure PrepararFraccionesAnalisis(FechaRef: Date)
    var
        Fraccion: Record "Fracción Acumulador" temporary;
        Clave: Text;
        Anterior: Date;
        Lista: List of [Code[20]];
    begin
        Clear(CodigosAportesAnalisis);
        Clear(FechasAportesAnalisis);
        FraccionesVigentesAnalisis.Reset();
        FraccionesVigentesAnalisis.DeleteAll();
        Fraccion.Copy(FraccionesContextos, true);
        Fraccion.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        if Fraccion.FindSet() then
            repeat
                Clave := Format(StrLen(Fraccion."Cód. Concepto"), 0, 9) + ':' + Fraccion."Cód. Concepto" + Fraccion."Cód. Acumulador";
                if not FechasAportesAnalisis.Get(Clave, Anterior) then begin
                    FechasAportesAnalisis.Add(Clave, Fraccion."Vigencia Desde");
                    FraccionesVigentesAnalisis := Fraccion;
                    FraccionesVigentesAnalisis.Insert(false);
                    RegistrarCodigoAnalisis(CodigosAportesAnalisis, Fraccion."Cód. Acumulador", Fraccion."Cód. Concepto");
                end else
                    if Fraccion."Vigencia Desde" > Anterior then begin
                        FraccionesVigentesAnalisis.Get(Fraccion."Cód. Concepto", Anterior, Fraccion."Cód. Acumulador");
                        FraccionesVigentesAnalisis.Delete(false);
                        FechasAportesAnalisis.Set(Clave, Fraccion."Vigencia Desde");
                        FraccionesVigentesAnalisis := Fraccion;
                        FraccionesVigentesAnalisis.Insert(false);
                    end;
            until Fraccion.Next() = 0;
    end;

    local procedure BuscarLecturas(CodAcumulador: Code[20]; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; var VersionMap: Dictionary of [Code[20], Date]; var Lecturas: List of [Code[20]]; var Ordenes: Dictionary of [Code[20], Integer])
    var
        Concepto: Record "Concepto Liquidación" temporary;
        Codigo: Code[20];
        Orden: Integer;
    begin
        if not LectoresPorAcumulador.Get(CodAcumulador, Lecturas) then
            exit;
        Concepto.Copy(ConceptosAnalisis, true);
        foreach Codigo in Lecturas do
            if Concepto.Get(Codigo, VersionMap.Get(Codigo)) then
                if ResolverOrdenAnalisis(Concepto, FechaRef, TipoLiq, Convenio, false, Orden) then
                    Ordenes.Add(Codigo, Orden);
    end;

    local procedure PrepararLecturas(FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20])
    var
        Concepto: Record "Concepto Liquidación" temporary;
        Tipo: Record "Tipo Liquidación";
        Dependencias: List of [Code[20]];
        Codigo: Code[20];
        Errores: Text;
        ProduccionPendiente: Boolean;
    begin
        if not ContextoDependenciasConocido and (TipoLiq <> '') then
            if Tipo.Get(TipoLiq) then
                SoloConceptosDeclarados := Tipo."Sólo Conceptos Declarados";
        // La selección y los identificadores no cambian entre acumuladores del mismo análisis.
        Concepto.Copy(ConceptosAnalisis, true);
        Concepto.SetRange("Es Acumulador", false);
        if Concepto.FindSet() then
            repeat
                if ConceptoIncluido(Concepto, FechaRef, TipoLiq, Convenio, Categoria) then begin
                    ConceptosIncluidos.Add(Concepto.Código, true);
                    if ConceptoProduceEnContexto(Concepto, FechaRef, TipoLiq, Convenio, Categoria, ProduccionPendiente) then begin
                        ProduccionesIncluidas.Add(Concepto.Código, true);
                        if ProduccionPendiente then
                            ProduccionesPendientes.Add(Concepto.Código);
                    end;
                    ObtenerDependenciasEnContexto(Concepto, Dependencias, Errores);
                    foreach Codigo in Dependencias do
                        IndexarLector(Codigo, Concepto.Código);
                end;
            until Concepto.Next() = 0;
    end;

    local procedure IndexarLector(CodAcumulador: Code[20]; CodConcepto: Code[20])
    var
        Lectores: List of [Code[20]];
    begin
        if LectoresPorAcumulador.Get(CodAcumulador, Lectores) then begin
            if not Lectores.Contains(CodConcepto) then
                Lectores.Add(CodConcepto);
        end else begin
            Lectores.Add(CodConcepto);
            LectoresPorAcumulador.Add(CodAcumulador, Lectores);
        end;
    end;

    /// <summary>Opta por reutilizar sólo el catálogo de nombres durante una operación del llamador.</summary>
    /// <remarks>El llamador debe limpiar esta instancia al iniciar otra operación. Los grafos siempre se reconstruyen con el temporal recibido.</remarks>
    internal procedure PrepararCatalogoDependencias()
    begin
        if CatalogoDependenciasPreparado then
            exit;
        CargarNombresDependencias();
        CatalogoDependenciasPreparado := true;
    end;

    /// <summary>Dependencias calculadas duras; las lecturas precargadas no forman aristas ni ciclos.</summary>
    internal procedure ExtraerDependenciasConcepto(Concepto: Record "Concepto Liquidación"; var Vigentes: Record "Concepto Liquidación" temporary; var Dependencias: List of [Code[20]]; var Errores: Text)
    var
        Inicializadas: List of [Code[20]];
    begin
        ExtraerDependenciasConcepto(Concepto, Vigentes, Dependencias, Inicializadas, Errores);
    end;

    /// <summary>Separa resultados calculados de claves inicializadas cuyo lado debe conservarse al reordenar.</summary>
    /// <remarks>Un mismo código puede aparecer en ambas listas, y las lecturas inicializadas propias se conservan para el llamador.</remarks>
    internal procedure ExtraerDependenciasConcepto(Concepto: Record "Concepto Liquidación"; var Vigentes: Record "Concepto Liquidación" temporary; var Dependencias: List of [Code[20]]; var Inicializadas: List of [Code[20]]; var Errores: Text)
    begin
        ContextoDependenciasConocido := false;
        InicializarContextoDependencias(Vigentes);
        ObtenerDependenciasEnContexto(Concepto, Dependencias, Inicializadas, Errores);
    end;

    internal procedure ExtraerDependenciasConcepto(Concepto: Record "Concepto Liquidación"; var Vigentes: Record "Concepto Liquidación" temporary; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; var Dependencias: List of [Code[20]]; var Inicializadas: List of [Code[20]]; var Errores: Text; var RequiereContexto: Boolean)
    begin
        EstablecerContextoDependencias(FechaRef, TipoLiq, Convenio, Categoria);
        InicializarContextoDependencias(Vigentes);
        ObtenerDependenciasEnContexto(Concepto, Dependencias, Inicializadas, Errores);
        RequiereContexto := ContextosDependenciasGuardados.Get(Concepto.Código);
    end;

    local procedure EstablecerContextoDependencias(FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20])
    begin
        ContextoDependenciasConocido := true;
        FechaDependencias := FechaRef;
        TipoDependencias := TipoLiq;
        ConvenioDependencias := Convenio;
        CategoriaDependencias := Categoria;
        PrepararCatalogoContextos();
    end;

    internal procedure DetectarCicloDependencias(Concepto: Record "Concepto Liquidación"; var Vigentes: Record "Concepto Liquidación" temporary; var Motivo: Text): Boolean
    var
        Pila: List of [Code[20]];
    begin
        Motivo := '';
        ContextoDependenciasConocido := false;
        InicializarContextoDependencias(Vigentes);
        exit(BuscarCicloEnContexto(Concepto, Pila, Motivo));
    end;

    internal procedure DetectarCicloDependencias(Concepto: Record "Concepto Liquidación"; var Vigentes: Record "Concepto Liquidación" temporary; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; var Motivo: Text; var RequiereContexto: Boolean): Boolean
    var
        Pila: List of [Code[20]];
        Resultado: Boolean;
    begin
        Motivo := '';
        EstablecerContextoDependencias(FechaRef, TipoLiq, Convenio, Categoria);
        InicializarContextoDependencias(Vigentes);
        Resultado := BuscarCicloEnContexto(Concepto, Pila, Motivo);
        RequiereContexto := CicloContextoPendiente;
        exit(Resultado);
    end;

    local procedure InicializarContextoDependencias(var Vigentes: Record "Concepto Liquidación" temporary)
    var
        Concepto: Record "Concepto Liquidación" temporary;
        Fecha: Date;
    begin
        if not Vigentes.IsTemporary() then
            Error('El catálogo de conceptos del control de dependencias debe ser temporal.');
        // Sin opt-in explícito se releen los nombres. Nunca aprobar un temporal nuevo con
        // dependencias, ciclos o colisiones conservados de una llamada pública anterior.
        if not CatalogoDependenciasPreparado then
            CargarNombresDependencias();
        VigentesDependencias.Copy(Vigentes, true);
        VigentesDependencias.Reset();
        Clear(FechasVigentesDependencias);
        Concepto.Copy(Vigentes, true);
        Concepto.Reset();
        if Concepto.FindSet() then
            repeat
                if not FechasVigentesDependencias.Get(Concepto.Código, Fecha) then
                    FechasVigentesDependencias.Add(Concepto.Código, Concepto."Vigencia Desde")
                else
                    if Concepto."Vigencia Desde" > Fecha then
                        FechasVigentesDependencias.Set(Concepto.Código, Concepto."Vigencia Desde");
            until Concepto.Next() = 0;
        Clear(DependenciasGuardadas);
        Clear(InicializadasGuardadas);
        Clear(ErroresDependenciasGuardados);
        Clear(CiclosExpansionGuardados);
        Clear(CiclosDependenciasGuardados);
        Clear(ContextosDependenciasGuardados);
        CicloContextoPendiente := false;
        NivelExpresionesDependencias := 0;
    end;

    local procedure CargarNombresDependencias()
    var
        Parametro: Record "Parámetro";
        Fuente: Record "Fuente Datos Liquidación";
        Sistema: Record "Variable Sistema Liq.";
        Atributo: Record "Tipo Atributo Liq.";
    begin
        Clear(NombresExternosDependencias);
        Clear(TokensDependenciasGuardados);
        Clear(ErroresTokensGuardados);
        Parametro.SetLoadFields("Nombre Variable");
        Parametro.SetFilter("Nombre Variable", '<>%1', '');
        if Parametro.FindSet() then
            repeat
                NombresExternosDependencias.Set(Parametro."Nombre Variable", true);
                NombresExternosDependencias.Set(Parametro."Nombre Variable" + '_ESFCY', true);
            until Parametro.Next() = 0;
        Fuente.SetLoadFields("Nombre Variable");
        Fuente.SetRange(Activo, true);
        if Fuente.FindSet() then
            repeat
                NombresExternosDependencias.Set(Fuente."Nombre Variable", true);
            until Fuente.Next() = 0;
        Sistema.SetLoadFields("Nombre Variable");
        Sistema.SetRange(Activo, true);
        Sistema.SetFilter("Nombre Variable", '<>%1', '');
        if Sistema.FindSet() then
            repeat
                NombresExternosDependencias.Set(Sistema."Nombre Variable", true);
            until Sistema.Next() = 0;
        Atributo.SetLoadFields("Nombre Variable", "Publicar Última Marea");
        Atributo.SetFilter("Nombre Variable", '<>%1', '');
        if Atributo.FindSet() then
            repeat
                NombresExternosDependencias.Set(Atributo."Nombre Variable", true);
                if Atributo."Publicar Última Marea" then
                    NombresExternosDependencias.Set(Atributo."Nombre Variable" + '_ULT_MAREA', true);
            until Atributo.Next() = 0;
    end;

    local procedure ObtenerVigenteDependencia(Codigo: Code[20]; var Concepto: Record "Concepto Liquidación"): Boolean
    var
        Busqueda: Record "Concepto Liquidación" temporary;
        Fecha: Date;
    begin
        if not FechasVigentesDependencias.Get(Codigo, Fecha) then
            exit(false);
        Busqueda.Copy(VigentesDependencias, true);
        if not Busqueda.Get(Codigo, Fecha) then
            exit(false);
        Concepto := Busqueda;
        exit(true);
    end;

    local procedure ObtenerDependenciasEnContexto(Concepto: Record "Concepto Liquidación"; var Dependencias: List of [Code[20]]; var Errores: Text)
    var
        Inicializadas: List of [Code[20]];
    begin
        ObtenerDependenciasEnContexto(Concepto, Dependencias, Inicializadas, Errores);
    end;

    local procedure ObtenerDependenciasEnContexto(Concepto: Record "Concepto Liquidación"; var Dependencias: List of [Code[20]]; var Inicializadas: List of [Code[20]]; var Errores: Text)
    var
        Pila: List of [Code[20]];
        Guardadas: List of [Code[20]];
        SemillasGuardadas: List of [Code[20]];
        Codigo: Code[20];
        CicloExpansion: Text;
        ClaveCompatible: Text;
    begin
        Clear(Dependencias);
        Clear(Inicializadas);
        Errores := '';
        if DependenciasGuardadas.Get(Concepto.Código, Guardadas) then begin
            foreach Codigo in Guardadas do
                Dependencias.Add(Codigo);
            SemillasGuardadas := InicializadasGuardadas.Get(Concepto.Código);
            foreach Codigo in SemillasGuardadas do
                Inicializadas.Add(Codigo);
            Errores := ErroresDependenciasGuardados.Get(Concepto.Código);
            exit;
        end;
        if AnalisisCompatibleEnCurso and ContextoDependenciasConocido then begin
            ClaveCompatible := ClaveDependenciasCompatibles(Concepto);
            if DependenciasCompatiblesGuardadas.Get(ClaveCompatible, Guardadas) then begin
                foreach Codigo in Guardadas do
                    Dependencias.Add(Codigo);
                SemillasGuardadas := SemillasCompatiblesGuardadas.Get(ClaveCompatible);
                foreach Codigo in SemillasGuardadas do
                    Inicializadas.Add(Codigo);
                Errores := ErroresCompatiblesGuardados.Get(ClaveCompatible);
                DependenciasGuardadas.Add(Concepto.Código, Guardadas);
                InicializadasGuardadas.Add(Concepto.Código, SemillasGuardadas);
                ErroresDependenciasGuardados.Add(Concepto.Código, Errores);
                CiclosExpansionGuardados.Add(Concepto.Código, ExpansionCompatibleGuardada.Get(ClaveCompatible));
                ContextosDependenciasGuardados.Add(Concepto.Código, PendientesCompatiblesGuardados.Get(ClaveCompatible));
                exit;
            end;
        end;
        Pila.Add(Concepto.Código);
        ConvenioDependenciasConocido := Concepto."Par CCT a Usar" = Concepto."Par CCT a Usar"::Entidad;
        DependenciasContextoPendiente := false;
        RecopilarDefinicionDependencias(Concepto, true, Pila, Dependencias, Inicializadas, Errores, CicloExpansion);
        foreach Codigo in Dependencias do
            Guardadas.Add(Codigo);
        DependenciasGuardadas.Add(Concepto.Código, Guardadas);
        foreach Codigo in Inicializadas do
            SemillasGuardadas.Add(Codigo);
        InicializadasGuardadas.Add(Concepto.Código, SemillasGuardadas);
        ErroresDependenciasGuardados.Add(Concepto.Código, Errores);
        CiclosExpansionGuardados.Add(Concepto.Código, CicloExpansion);
        ContextosDependenciasGuardados.Add(Concepto.Código, DependenciasContextoPendiente);
        if ClaveCompatible <> '' then begin
            DependenciasCompatiblesGuardadas.Add(ClaveCompatible, Guardadas);
            SemillasCompatiblesGuardadas.Add(ClaveCompatible, SemillasGuardadas);
            ErroresCompatiblesGuardados.Add(ClaveCompatible, Errores);
            ExpansionCompatibleGuardada.Add(ClaveCompatible, CicloExpansion);
            PendientesCompatiblesGuardados.Add(ClaveCompatible, DependenciasContextoPendiente);
        end;
    end;

    local procedure ClaveDependenciasCompatibles(Concepto: Record "Concepto Liquidación"): Text
    var
        Sensibilidad: Integer;
        Texto: Text;
        Tipo: Code[20];
        Convenio: Code[20];
    begin
        if not SensibilidadDependenciasGuardada.Get(Concepto.Código, Sensibilidad) then begin
            Texto := UpperCase(Concepto.Fórmula + ' ' + Concepto.Condición + ' ' + Concepto."Variable Cantidad" + ' ' + Concepto."Variable Base" + ' ' +
                Concepto."Factor Importe Consumo" + ' ' + Concepto."Cantidad Matriz");
            // @ puede heredar ambas variables desde otra definición. Conservar ambas en
            // ese caso es conservador; los falsos positivos de texto sólo cuestan caché.
            if Texto.Contains('TIPO_LIQ') or Texto.Contains('@') then
                Sensibilidad += 1;
            if Texto.Contains('CONVENIO') or Texto.Contains('@') then
                Sensibilidad += 2;
            SensibilidadDependenciasGuardada.Add(Concepto.Código, Sensibilidad);
        end;
        if Sensibilidad in [1, 3] then
            Tipo := TipoDependencias;
        if (Sensibilidad in [2, 3]) and (Concepto."Par CCT a Usar" = Concepto."Par CCT a Usar"::Entidad) then
            Convenio := ConvenioDependencias;
        exit(Format(StrLen(Concepto.Código), 0, 9) + ':' + Concepto.Código + ClaveContextoOrden(Tipo, Convenio, ''));
    end;

    local procedure RecopilarDefinicionDependencias(Concepto: Record "Concepto Liquidación"; IncluirCamposLinea: Boolean; var Pila: List of [Code[20]]; var Dependencias: List of [Code[20]]; var Inicializadas: List of [Code[20]]; var Errores: Text; var CicloExpansion: Text)
    var
        DurasCuerpo: List of [Code[20]];
        SemillasCuerpo: List of [Code[20]];
        Estado: Integer;
        PendienteAnterior: Boolean;
        PendienteCuerpo: Boolean;
        AgregaEntradas: Boolean;
        Codigo: Code[20];
    begin
        Estado := 1;
        if ContextoDependenciasConocido then begin
            RecopilarDependenciasTexto(Concepto.Condición, Pila, Dependencias, Inicializadas, Errores, CicloExpansion);
            if Concepto.Condición.Trim() <> '' then
                Estado := CondicionEnContexto(Concepto.Condición, FechaDependencias, TipoDependencias, ConvenioDependencias, ConvenioDependenciasConocido);
            if Estado = 0 then
                exit;
        end;
        PendienteAnterior := DependenciasContextoPendiente;
        DependenciasContextoPendiente := false;
        RecopilarDependenciasTexto(Concepto.Fórmula, Pila, DurasCuerpo, SemillasCuerpo, Errores, CicloExpansion);
        if not ContextoDependenciasConocido then
            RecopilarDependenciasTexto(Concepto.Condición, Pila, DurasCuerpo, SemillasCuerpo, Errores, CicloExpansion);
        if IncluirCamposLinea then begin
            RecopilarDependenciasTexto(Concepto."Variable Cantidad", Pila, DurasCuerpo, SemillasCuerpo, Errores, CicloExpansion);
            RecopilarDependenciasTexto(Concepto."Variable Base", Pila, DurasCuerpo, SemillasCuerpo, Errores, CicloExpansion);
            RecopilarDependenciasTexto(Concepto."Factor Importe Consumo", Pila, DurasCuerpo, SemillasCuerpo, Errores, CicloExpansion);
            RecopilarDependenciasTexto(Concepto."Cantidad Matriz", Pila, DurasCuerpo, SemillasCuerpo, Errores, CicloExpansion);
        end;
        PendienteCuerpo := DependenciasContextoPendiente;
        foreach Codigo in DurasCuerpo do
            if not Dependencias.Contains(Codigo) then
                AgregaEntradas := true;
        foreach Codigo in SemillasCuerpo do
            if not Inicializadas.Contains(Codigo) then
                AgregaEntradas := true;
        DependenciasContextoPendiente := PendienteAnterior or (AgregaEntradas and (PendienteCuerpo or (Estado = -1)));
        UnirCodigos(DurasCuerpo, Dependencias);
        UnirCodigos(SemillasCuerpo, Inicializadas);
    end;

    local procedure RecopilarDependenciasTexto(Texto: Text; var Pila: List of [Code[20]]; var Dependencias: List of [Code[20]]; var Inicializadas: List of [Code[20]]; var Errores: Text; var CicloExpansion: Text)
    var
        Argumentos: List of [Text];
        Inicio: Integer;
        Fin: Integer;
        Nombre: Text;
        ErrorLlamada: Text;
    begin
        if NivelExpresionesDependencias >= 100 then begin
            AnotarErrorDependencia(Errores, 'Expresión demasiado profunda para comprobar sus dependencias.');
            exit;
        end;
        NivelExpresionesDependencias += 1;
        if ContextoDependenciasConocido then
            if BuscarCondicionalTexto(Texto, Inicio, Fin, Nombre, Argumentos, ErrorLlamada) then begin
                RecopilarTokensDependencias(CopyStr(Texto, 1, Inicio - 1), Pila, Dependencias, Inicializadas, Errores, CicloExpansion);
                if Nombre = 'CASE' then
                    RecopilarDependenciasTexto(ConvertirCaseAIf(Argumentos, Errores), Pila, Dependencias, Inicializadas, Errores, CicloExpansion)
                else
                    RecopilarDependenciasIf(Argumentos, Pila, Dependencias, Inicializadas, Errores, CicloExpansion);
                RecopilarDependenciasTexto(CopyStr(Texto, Fin + 1), Pila, Dependencias, Inicializadas, Errores, CicloExpansion);
                NivelExpresionesDependencias -= 1;
                exit;
            end else
                AnotarErrorDependencia(Errores, ErrorLlamada);
        RecopilarTokensDependencias(Texto, Pila, Dependencias, Inicializadas, Errores, CicloExpansion);
        NivelExpresionesDependencias -= 1;
    end;

    local procedure RecopilarDependenciasIf(Argumentos: List of [Text]; var Pila: List of [Code[20]]; var Dependencias: List of [Code[20]]; var Inicializadas: List of [Code[20]]; var Errores: Text; var CicloExpansion: Text)
    var
        DurasSi: List of [Code[20]];
        DurasNo: List of [Code[20]];
        SemillasSi: List of [Code[20]];
        SemillasNo: List of [Code[20]];
        Estado: Integer;
        AnteriorPendiente: Boolean;
        SiPendiente: Boolean;
        NoPendiente: Boolean;
    begin
        if Argumentos.Count() <> 3 then begin
            AnotarErrorDependencia(Errores, 'IF requiere tres argumentos en el control de dependencias');
            exit;
        end;
        // Aunque el resultado lógico sea conocido, el runtime evalúa el texto de la
        // condición. No se ocultan sus referencias, errores ni posibles ciclos.
        RecopilarDependenciasTexto(Argumentos.Get(1), Pila, Dependencias, Inicializadas, Errores, CicloExpansion);
        Estado := CondicionEnContexto(Argumentos.Get(1), FechaDependencias, TipoDependencias, ConvenioDependencias, ConvenioDependenciasConocido);
        case Estado of
            1:
                RecopilarDependenciasTexto(Argumentos.Get(2), Pila, Dependencias, Inicializadas, Errores, CicloExpansion);
            0:
                RecopilarDependenciasTexto(Argumentos.Get(3), Pila, Dependencias, Inicializadas, Errores, CicloExpansion);
            else begin
                AnteriorPendiente := DependenciasContextoPendiente;
                DependenciasContextoPendiente := false;
                RecopilarDependenciasTexto(Argumentos.Get(2), Pila, DurasSi, SemillasSi, Errores, CicloExpansion);
                SiPendiente := DependenciasContextoPendiente;
                DependenciasContextoPendiente := false;
                RecopilarDependenciasTexto(Argumentos.Get(3), Pila, DurasNo, SemillasNo, Errores, CicloExpansion);
                NoPendiente := DependenciasContextoPendiente;
                DependenciasContextoPendiente := AnteriorPendiente or SiPendiente or NoPendiente or
                    not MismosCodigos(DurasSi, DurasNo) or not MismosCodigos(SemillasSi, SemillasNo);
                UnirCodigos(DurasSi, Dependencias);
                UnirCodigos(DurasNo, Dependencias);
                UnirCodigos(SemillasSi, Inicializadas);
                UnirCodigos(SemillasNo, Inicializadas);
            end;
        end;
    end;

    local procedure UnirCodigos(Origen: List of [Code[20]]; var Destino: List of [Code[20]])
    var
        Codigo: Code[20];
    begin
        foreach Codigo in Origen do
            if not Destino.Contains(Codigo) then
                Destino.Add(Codigo);
    end;

    local procedure MismosCodigos(Uno: List of [Code[20]]; Otro: List of [Code[20]]): Boolean
    var
        Codigo: Code[20];
    begin
        if Uno.Count() <> Otro.Count() then
            exit(false);
        foreach Codigo in Uno do
            if not Otro.Contains(Codigo) then
                exit(false);
        exit(true);
    end;

    local procedure ConvertirCaseAIf(Argumentos: List of [Text]; var Errores: Text): Text
    var
        Indice: Integer;
        Resultado: Text;
    begin
        if Argumentos.Count() < 2 then begin
            AnotarErrorDependencia(Errores, 'CASE requiere al menos una condición y un resultado');
            exit('');
        end;
        Indice := Argumentos.Count();
        Resultado := '0';
        if Indice mod 2 <> 0 then begin
            Resultado := Argumentos.Get(Indice);
            Indice -= 1;
        end;
        while Indice >= 2 do begin
            Resultado := 'IF(' + Argumentos.Get(Indice - 1) + ',' + Argumentos.Get(Indice) + ',' + Resultado + ')';
            Indice -= 2;
        end;
        exit(Resultado);
    end;

    local procedure BuscarCondicionalTexto(Texto: Text; var Inicio: Integer; var Fin: Integer; var Nombre: Text; var Argumentos: List of [Text]; var Errores: Text): Boolean
    var
        Posicion: Integer;
        Siguiente: Integer;
        InicioArgumento: Integer;
        Nivel: Integer;
        EnCadena: Boolean;
        Caracter: Text;
    begin
        Clear(Argumentos);
        Errores := '';
        Posicion := 1;
        while Posicion <= StrLen(Texto) do begin
            Caracter := CopyStr(Texto, Posicion, 1);
            if Caracter = '''' then begin
                Posicion += 1;
                while Posicion <= StrLen(Texto) do begin
                    if CopyStr(Texto, Posicion, 1) = '''' then begin
                        if CopyStr(Texto, Posicion + 1, 1) <> '''' then
                            break;
                        Posicion += 1;
                    end;
                    Posicion += 1;
                end;
                Posicion += 1;
            end else
                if EsLetra(UpperCase(Caracter)) or (Caracter in ['_', '#', '@']) then begin
                    Inicio := Posicion;
                    Posicion += 1;
                    while EsCaracterIdentificador(UpperCase(CopyStr(Texto, Posicion, 1))) do
                        Posicion += 1;
                    Nombre := UpperCase(CopyStr(Texto, Inicio, Posicion - Inicio));
                    Siguiente := Posicion;
                    while EsEspacio(CopyStr(Texto, Siguiente, 1)) do
                        Siguiente += 1;
                    if (Nombre in ['IF', 'CASE']) and (CopyStr(Texto, Siguiente, 1) = '(') then begin
                        Posicion := Siguiente;
                        InicioArgumento := Posicion + 1;
                        Nivel := 0;
                        EnCadena := false;
                        while Posicion <= StrLen(Texto) do begin
                            Caracter := CopyStr(Texto, Posicion, 1);
                            if Caracter = '''' then begin
                                if EnCadena and (CopyStr(Texto, Posicion + 1, 1) = '''') then
                                    Posicion += 1
                                else
                                    EnCadena := not EnCadena;
                            end else
                                if not EnCadena then
                                    case Caracter of
                                        '(':
                                            Nivel += 1;
                                        ')':
                                            begin
                                                Nivel -= 1;
                                                if Nivel = 0 then begin
                                                    Argumentos.Add(CopyStr(Texto, InicioArgumento, Posicion - InicioArgumento));
                                                    Fin := Posicion;
                                                    exit(true);
                                                end;
                                            end;
                                        ',':
                                            if Nivel = 1 then begin
                                                Argumentos.Add(CopyStr(Texto, InicioArgumento, Posicion - InicioArgumento));
                                                InicioArgumento := Posicion + 1;
                                            end;
                                    end;
                            Posicion += 1;
                        end;
                        Errores := 'Paréntesis o cadena sin cerrar en ' + Nombre;
                        exit(false);
                    end;
                end else
                    Posicion += 1;
        end;
        exit(false);
    end;

    local procedure RecopilarTokensDependencias(Texto: Text; var Pila: List of [Code[20]]; var Dependencias: List of [Code[20]]; var Inicializadas: List of [Code[20]]; var Errores: Text; var CicloExpansion: Text)
    var
        Referido: Record "Concepto Liquidación";
        Tokens: List of [Text];
        Token: Text;
        Nombre: Text;
        ErrorTokens: Text;
        Codigo: Code[20];
        Explicita: Boolean;
    begin
        ObtenerTokensDependencias(Texto, Tokens, ErrorTokens);
        AnotarErrorDependencia(Errores, ErrorTokens);
        foreach Token in Tokens do begin
            Explicita := Token.StartsWith('#') or Token.StartsWith('@');
            Nombre := Token;
            if Explicita then
                Nombre := CopyStr(Token, 2);
            if Explicita and ((Nombre = '') or (StrLen(Nombre) > MaxStrLen(Codigo))) then
                AnotarErrorDependencia(Errores, 'Referencia inválida o de más de 20 caracteres: ' + Token)
            else
                if StrLen(Nombre) <= MaxStrLen(Codigo) then begin
                    Codigo := CopyStr(Nombre, 1, MaxStrLen(Codigo));
                    if ObtenerVigenteDependencia(Codigo, Referido) then
                        if Token.StartsWith('@') then begin
                            if Pila.Contains(Codigo) or (Pila.Count() >= 50) then begin
                                CicloExpansion := 'Referencia circular o demasiado profunda al expandir ' + Token;
                                AnotarErrorDependencia(Errores, CicloExpansion);
                            end else begin
                                Pila.Add(Codigo);
                                // También en @ACUM se reevalúan sólo fórmula y condición, nunca el subtotal ni el orden.
                                RecopilarDefinicionDependencias(Referido, false, Pila, Dependencias, Inicializadas, Errores, CicloExpansion);
                                Pila.RemoveAt(Pila.Count());
                            end;
                        end else begin
                            // Una clave precargada se puede leer antes o después de que el concepto
                            // homónimo la sobrescriba. No impone precedencia: el corrector conserva ese lado.
                            // # mantiene la intención de leer un resultado calculado. Un acumulador
                            // siempre parte de cero y recibe aportes, aunque exista otra fuente homónima.
                            if not Explicita and not Referido."Es Acumulador" and NombresExternosDependencias.ContainsKey(Nombre) then begin
                                if not Inicializadas.Contains(Codigo) then
                                    Inicializadas.Add(Codigo);
                            end else
                                if not Dependencias.Contains(Codigo) then
                                    Dependencias.Add(Codigo);
                        end
                    else
                        if Explicita then
                            AnotarErrorDependencia(Errores, 'Referencia no vigente: ' + Token);
                end;
        end;
    end;

    local procedure ObtenerTokensDependencias(Texto: Text; var Tokens: List of [Text]; var Errores: Text)
    var
        Guardados: List of [Text];
        Token: Text;
        Caracter: Text;
        Formula: Text;
        Posicion: Integer;
        Inicio: Integer;
        Siguiente: Integer;
        Cerrada: Boolean;
    begin
        Clear(Tokens);
        Errores := '';
        if TokensDependenciasGuardados.Get(Texto, Guardados) then begin
            foreach Token in Guardados do
                Tokens.Add(Token);
            Errores := ErroresTokensGuardados.Get(Texto);
            exit;
        end;
        Formula := UpperCase(Texto);
        Posicion := 1;
        while Posicion <= StrLen(Formula) do begin
            Caracter := CopyStr(Formula, Posicion, 1);
            if Caracter = '''' then begin
                Cerrada := false;
                Posicion += 1;
                while Posicion <= StrLen(Formula) do begin
                    if CopyStr(Formula, Posicion, 1) = '''' then begin
                        if CopyStr(Formula, Posicion + 1, 1) <> '''' then begin
                            Cerrada := true;
                            break;
                        end;
                        Posicion += 1;
                    end;
                    Posicion += 1;
                end;
                if not Cerrada then
                    AnotarErrorDependencia(Errores, 'Cadena entre comillas sin cerrar en una fórmula');
                Posicion += 1;
            end else
                if EsLetra(Caracter) or (Caracter in ['_', '#', '@']) then begin
                    Inicio := Posicion;
                    Posicion += 1;
                    while EsCaracterIdentificador(CopyStr(Formula, Posicion, 1)) do
                        Posicion += 1;
                    Token := CopyStr(Formula, Inicio, Posicion - Inicio);
                    Siguiente := Posicion;
                    while EsEspacio(CopyStr(Formula, Siguiente, 1)) do
                        Siguiente += 1;
                    // El nombre de una función no es una variable; sus argumentos se recorren normalmente.
                    if CopyStr(Formula, Siguiente, 1) <> '(' then begin
                        if not (Token in ['AND', 'OR', 'NOT']) then
                            if not Tokens.Contains(Token) then
                                Tokens.Add(Token);
                    end else
                        if Token.StartsWith('#') or Token.StartsWith('@') then
                            AnotarErrorDependencia(Errores, 'Una referencia calculada no puede invocarse como función: ' + Token);
                end else
                    Posicion += 1;
        end;
        foreach Token in Tokens do
            Guardados.Add(Token);
        TokensDependenciasGuardados.Add(Texto, Guardados);
        ErroresTokensGuardados.Add(Texto, Errores);
    end;

    local procedure BuscarCicloEnContexto(Concepto: Record "Concepto Liquidación"; var Pila: List of [Code[20]]; var Motivo: Text): Boolean
    var
        Dependencia: Record "Concepto Liquidación";
        Dependencias: List of [Code[20]];
        Codigo: Code[20];
        Errores: Text;
        MotivoExpansion: Text;
        ParDesconocido: Boolean;
    begin
        Motivo := '';
        if Concepto."Es Acumulador" then
            exit(false);
        if ContextoDependenciasConocido then begin
            if not ConceptoIncluidoEnContexto(Concepto, FechaDependencias, TipoDependencias, ConvenioDependencias, CategoriaDependencias, ParDesconocido) then
                exit(false);
            if ParDesconocido then
                CicloContextoPendiente := true;
        end;
        if CiclosDependenciasGuardados.Get(Concepto.Código, Motivo) then
            exit(Motivo <> '');
        if Pila.Contains(Concepto.Código) then begin
            Motivo := 'Ciclo de referencias calculadas: ' + FormatearCamino(Pila, Concepto.Código);
            exit(true);
        end;
        if Pila.Count() >= 50 then begin
            Motivo := 'Dependencias calculadas demasiado profundas: ' + FormatearCamino(Pila, Concepto.Código);
            exit(true);
        end;
        ObtenerDependenciasEnContexto(Concepto, Dependencias, Errores);
        if ContextosDependenciasGuardados.Get(Concepto.Código) then
            CicloContextoPendiente := true;
        MotivoExpansion := CiclosExpansionGuardados.Get(Concepto.Código);
        if MotivoExpansion <> '' then begin
            Motivo := MotivoExpansion;
            CiclosDependenciasGuardados.Add(Concepto.Código, Motivo);
            exit(true);
        end;
        Pila.Add(Concepto.Código);
        foreach Codigo in Dependencias do
            if ObtenerVigenteDependencia(Codigo, Dependencia) then
                if not Dependencia."Es Acumulador" then
                    if BuscarCicloDeProductor(Dependencia, Pila, Motivo) then begin
                        Pila.RemoveAt(Pila.Count());
                        CiclosDependenciasGuardados.Add(Concepto.Código, Motivo);
                        exit(true);
                    end;
        Pila.RemoveAt(Pila.Count());
        CiclosDependenciasGuardados.Add(Concepto.Código, '');
        exit(false);
    end;

    local procedure BuscarCicloDeProductor(Concepto: Record "Concepto Liquidación"; var Pila: List of [Code[20]]; var Motivo: Text): Boolean
    var
        Pendiente: Boolean;
    begin
        if ContextoDependenciasConocido then begin
            if not ConceptoProduceEnContexto(Concepto, FechaDependencias, TipoDependencias, ConvenioDependencias, CategoriaDependencias, Pendiente) then
                exit(false);
            if Pendiente then
                CicloContextoPendiente := true;
        end;
        exit(BuscarCicloEnContexto(Concepto, Pila, Motivo));
    end;

    local procedure FormatearCamino(Pila: List of [Code[20]]; Ultimo: Code[20]): Text
    var
        Codigo: Code[20];
        Camino: Text;
    begin
        foreach Codigo in Pila do begin
            if Camino <> '' then
                Camino += ' -> ';
            Camino += Codigo;
        end;
        if Camino <> '' then
            Camino += ' -> ';
        exit(Camino + Ultimo);
    end;

    local procedure AnotarErrorDependencia(var Errores: Text; Mensaje: Text)
    begin
        if (Errores = '') and (Mensaje <> '') then
            Errores := Mensaje;
    end;

    local procedure ConceptoIncluido(var Concepto: Record "Concepto Liquidación"; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]): Boolean
    var
        Motor: Codeunit "Motor Liquidación";
        ParDesconocido: Boolean;
    begin
        if ContextoDependenciasConocido then begin
            if not ConceptoIncluidoEnContexto(Concepto, FechaRef, TipoLiq, Convenio, Categoria, ParDesconocido) then
                exit(false);
            if ParDesconocido then
                if not ParesPendientes.Contains(Concepto.Código) then
                    ParesPendientes.Add(Concepto.Código);
            exit(true);
        end;
        if TipoLiq <> '' then
            if not AplicaATipoLiquidacion(Concepto, TipoLiq) then
                exit(false);
        // El par del puesto/asignación se cambia antes de comprobar CCT y fracciones. Sin una
        // liquidación no conocemos ese par; no se puede excluir usando el de cabecera.
        if Concepto."Par CCT a Usar" <> Concepto."Par CCT a Usar"::Entidad then begin
            if not ParesPendientes.Contains(Concepto.Código) then
                ParesPendientes.Add(Concepto.Código);
            exit(true);
        end;
        // Categoría vacía significa contexto incompleto, no "sólo categoría en blanco".
        if (Convenio <> '') and (Categoria <> '') then
            if not Motor.CCTAplicaAConcepto(Concepto, Convenio, Categoria, FechaRef) then
                exit(false);
        exit(true);
    end;

    local procedure FraccionIncluida(Frac: Record "Fracción Acumulador"; Concepto: Record "Concepto Liquidación"; Convenio: Code[20]): Boolean
    begin
        if Concepto."Par CCT a Usar" <> Concepto."Par CCT a Usar"::Entidad then
            exit(true);
        if (Convenio = '') and not ContextoDependenciasConocido then
            exit(true);
        exit(Frac.AplicaAConvenio(Convenio));
    end;

    local procedure AplicaATipoLiquidacion(Concepto: Record "Concepto Liquidación"; TipoLiq: Code[20]): Boolean
    var
        Declarado: Boolean;
    begin
        // Misma regla que Motor.ConceptoAplicaATipoLiq: informativos y tipos exclusivos.
        Declarado := ('|' + Concepto."Tipos Liq. Aplicables" + '|').Contains('|' + TipoLiq + '|');
        if Concepto."Tipo Concepto" = Concepto."Tipo Concepto"::Informativo then
            exit((Concepto."Tipos Liq. Aplicables" = '') or Declarado);
        if SoloConceptosDeclarados then
            exit(Declarado);
        exit((Concepto."Tipos Liq. Aplicables" = '') or Declarado);
    end;

    /// <summary>Resuelve únicamente órdenes cuyo contexto completo fue suministrado.</summary>
    /// <remarks>False deja Orden en cero; nunca devuelve un orden heredado o basado en datos ficticios.</remarks>
    internal procedure ResolverOrden(Concepto: Record "Concepto Liquidación"; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; var Orden: Integer): Boolean
    var
        Motor: Codeunit "Motor Liquidación";
        Tokens: List of [Text];
        Token: Text;
        Formula: Text;
    begin
        Orden := 0;
        Formula := Motor.FormulaOrdenConfigurada(Concepto);
        Formula := Formula.Trim();
        // La configuración más habitual es un literal. No necesita reconstruir el contexto
        // completo del motor ni consultar todos los conceptos para validar dependencias.
        if Formula <> '' then
            if DelChr(Formula, '=', '0123456789') = '' then
                if Evaluate(Orden, Formula, 9) then
                    if Orden >= 0 then
                        exit(true);
        Orden := 0;
        ExtraerIdentificadores(Formula, Tokens);
        foreach Token in Tokens do
            case Token of
                'ORDEN_BASE', 'MAX', 'MIN', 'ROUND', 'REDONDEAR', 'PISO', 'TECHO', 'ABS',
                'IF', 'IFZERO', 'CASE', 'DIV', 'ERROR', 'AND', 'OR', 'NOT': ;
                'TIPO_LIQ':
                    if TipoLiq = '' then
                        exit(false);
                'CONVENIO':
                    if Convenio = '' then
                        exit(false);
                else
                    exit(false); // parámetro, fuente, atributo, concepto o función no disponible
            end;
        if not IntentarResolverOrden(Concepto, FechaRef, TipoLiq, Convenio, Orden) then begin
            Orden := 0;
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>Los blancos recibidos son valores conocidos del contexto enumerado, nunca filtros vacíos.</summary>
    internal procedure ResolverOrdenEnContexto(Concepto: Record "Concepto Liquidación"; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; var Orden: Integer): Boolean
    var
        Motor: Codeunit "Motor Liquidación";
        Valor: Decimal;
        Formula: Text;
    begin
        Orden := 0;
        Formula := Motor.FormulaOrdenConfigurada(Concepto).Trim();
        if (Formula <> '') and (DelChr(Formula, '=', '0123456789') = '') then
            if Evaluate(Orden, Formula, 9) then
                if Orden >= 0 then
                    exit(true);
        Orden := 0;
        if not EvaluarExpresionPura(Formula, FechaRef, TipoLiq, Convenio,
            Concepto."Par CCT a Usar" = Concepto."Par CCT a Usar"::Entidad, Concepto."Orden Cálculo", true, Valor)
        then
            exit(false);
        if (Valor < 0) or (Valor > 2147483647) or (Valor <> Round(Valor, 1)) then
            exit(false);
        Orden := Valor;
        exit(true);
    end;

    internal procedure ObtenerOrdenesPosiblesEnContexto(Concepto: Record "Concepto Liquidación"; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; var Ordenes: List of [Integer]): Boolean
    var
        Motor: Codeunit "Motor Liquidación";
        Orden: Integer;
        Formula: Text;
        Podada: Text;
    begin
        Clear(Ordenes);
        if ResolverOrdenEnContexto(Concepto, FechaRef, TipoLiq, Convenio, Orden) then begin
            Ordenes.Add(Orden);
            exit(true);
        end;
        Formula := Motor.FormulaOrdenConfigurada(Concepto);
        if not FormulaOrdenAdmisible(Concepto, Formula, FechaRef) then
            exit(false);
        if not PodarArbolOrden(Formula, FechaRef, TipoLiq, Convenio, Concepto."Par CCT a Usar" = Concepto."Par CCT a Usar"::Entidad, 0, Podada) then
            exit(false);
        exit(ExtraerHojasOrden(Podada, 0, Ordenes));
    end;

    local procedure PodarArbolOrden(Formula: Text; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; ConvenioConocido: Boolean; Profundidad: Integer; var Podada: Text): Boolean
    var
        Condicion: Text;
        Si: Text;
        No: Text;
        PodadaSi: Text;
        PodadaNo: Text;
        Estado: Integer;
    begin
        if Profundidad >= 50 then
            exit(false);
        Formula := Formula.Trim();
        if (Formula <> '') and (DelChr(Formula, '=', '0123456789') = '') then begin
            Podada := Formula;
            exit(true);
        end;
        if not SepararRamasIf(Formula, Condicion, Si, No) then
            exit(false);
        Estado := CondicionEnContexto(Condicion, FechaRef, TipoLiq, Convenio, ConvenioConocido);
        if Estado = 1 then
            exit(PodarArbolOrden(Si, FechaRef, TipoLiq, Convenio, ConvenioConocido, Profundidad + 1, Podada));
        if Estado = 0 then
            exit(PodarArbolOrden(No, FechaRef, TipoLiq, Convenio, ConvenioConocido, Profundidad + 1, Podada));
        if not PodarArbolOrden(Si, FechaRef, TipoLiq, Convenio, ConvenioConocido, Profundidad + 1, PodadaSi) then
            exit(false);
        if not PodarArbolOrden(No, FechaRef, TipoLiq, Convenio, ConvenioConocido, Profundidad + 1, PodadaNo) then
            exit(false);
        Podada := 'IF(0,' + PodadaSi + ',' + PodadaNo + ')'; // sólo se enumeran hojas, jamás se elige esta condición
        exit(true);
    end;

    // -1: desconocido; 0: falso demostrado; 1: verdadero demostrado.
    local procedure CondicionEnContexto(Texto: Text; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; ConvenioConocido: Boolean): Integer
    var
        Izquierda: Text;
        Derecha: Text;
        EstadoIzquierdo: Integer;
        EstadoDerecho: Integer;
        Valor: Decimal;
    begin
        Texto := QuitarParentesisExternos(Texto.Trim());
        if SepararOperadorLogico(Texto, 'OR', Izquierda, Derecha) then begin
            EstadoIzquierdo := CondicionEnContexto(Izquierda, FechaRef, TipoLiq, Convenio, ConvenioConocido);
            EstadoDerecho := CondicionEnContexto(Derecha, FechaRef, TipoLiq, Convenio, ConvenioConocido);
            if (EstadoIzquierdo = 1) or (EstadoDerecho = 1) then
                exit(1);
            if (EstadoIzquierdo = 0) and (EstadoDerecho = 0) then
                exit(0);
            exit(-1);
        end;
        if SepararOperadorLogico(Texto, 'AND', Izquierda, Derecha) then begin
            EstadoIzquierdo := CondicionEnContexto(Izquierda, FechaRef, TipoLiq, Convenio, ConvenioConocido);
            EstadoDerecho := CondicionEnContexto(Derecha, FechaRef, TipoLiq, Convenio, ConvenioConocido);
            if (EstadoIzquierdo = 0) or (EstadoDerecho = 0) then
                exit(0);
            if (EstadoIzquierdo = 1) and (EstadoDerecho = 1) then
                exit(1);
            exit(-1);
        end;
        if (UpperCase(CopyStr(Texto, 1, 3)) = 'NOT') and not EsCaracterIdentificador(UpperCase(CopyStr(Texto, 4, 1))) then begin
            EstadoIzquierdo := CondicionEnContexto(CopyStr(Texto, 4), FechaRef, TipoLiq, Convenio, ConvenioConocido);
            if EstadoIzquierdo = -1 then
                exit(-1);
            exit(1 - EstadoIzquierdo);
        end;
        if not EvaluarExpresionPura(Texto, FechaRef, TipoLiq, Convenio, ConvenioConocido, 0, false, Valor) then
            exit(-1);
        if Valor = 0 then
            exit(0);
        exit(1);
    end;

    local procedure SepararOperadorLogico(Texto: Text; Operador: Text; var Izquierda: Text; var Derecha: Text): Boolean
    var
        Posicion: Integer;
        Nivel: Integer;
        EnCadena: Boolean;
        Caracter: Text;
    begin
        Posicion := 1;
        while Posicion <= StrLen(Texto) do begin
            Caracter := CopyStr(Texto, Posicion, 1);
            if Caracter = '''' then begin
                if EnCadena and (CopyStr(Texto, Posicion + 1, 1) = '''') then
                    Posicion += 1
                else
                    EnCadena := not EnCadena;
            end else
                if not EnCadena then
                    case Caracter of
                        '(':
                            Nivel += 1;
                        ')':
                            Nivel -= 1;
                        else
                            if (Posicion > 1) and (Nivel = 0) and (UpperCase(CopyStr(Texto, Posicion, StrLen(Operador))) = Operador) then
                                if not EsCaracterIdentificador(UpperCase(CopyStr(' ' + Texto, Posicion, 1))) and
                                   not EsCaracterIdentificador(UpperCase(CopyStr(Texto, Posicion + StrLen(Operador), 1)))
                                then begin
                                    Izquierda := CopyStr(Texto, 1, Posicion - 1);
                                    Derecha := CopyStr(Texto, Posicion + StrLen(Operador));
                                    exit(true);
                                end;
                    end;
            Posicion += 1;
        end;
        exit(false);
    end;

    local procedure QuitarParentesisExternos(Texto: Text): Text
    var
        Posicion: Integer;
        Nivel: Integer;
        EnCadena: Boolean;
        Completo: Boolean;
        Caracter: Text;
    begin
        while CopyStr(Texto, 1, 1) = '(' do begin
            if CopyStr(Texto, StrLen(Texto), 1) <> ')' then
                break;
            Nivel := 0;
            EnCadena := false;
            Completo := true;
            Posicion := 1;
            while Posicion <= StrLen(Texto) do begin
                Caracter := CopyStr(Texto, Posicion, 1);
                if Caracter = '''' then begin
                    if EnCadena and (CopyStr(Texto, Posicion + 1, 1) = '''') then
                        Posicion += 1
                    else
                        EnCadena := not EnCadena;
                end else
                    if not EnCadena then
                        case Caracter of
                            '(':
                                Nivel += 1;
                            ')':
                                begin
                                    Nivel -= 1;
                                    if (Nivel = 0) and (Posicion < StrLen(Texto)) then
                                        Completo := false;
                                end;
                        end;
                Posicion += 1;
            end;
            if not Completo or EnCadena or (Nivel <> 0) then
                break;
            Texto := CopyStr(Texto, 2, StrLen(Texto) - 2).Trim();
        end;
        exit(Texto);
    end;

    local procedure EvaluarExpresionPura(Texto: Text; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; ConvenioConocido: Boolean; OrdenBase: Integer; AdmiteOrdenBase: Boolean; var Valor: Decimal): Boolean
    var
        Tipo: Record "Tipo Liquidación" temporary;
        Contexto: Dictionary of [Text, Decimal];
        Codigos: Dictionary of [Text, Text];
        Posicion: Integer;
        Inicio: Integer;
        Siguiente: Integer;
        Token: Text;
        Caracter: Text;
    begin
        Valor := 0;
        Texto := UpperCase(Texto);
        if Texto.Contains('#') or Texto.Contains('@') then
            exit(false);
        PrepararCatalogoContextos();
        Tipo.Copy(TiposContextos, true);
        Posicion := 1;
        while Posicion <= StrLen(Texto) do begin
            Caracter := CopyStr(Texto, Posicion, 1);
            if Caracter = '''' then begin
                Posicion += 1;
                while Posicion <= StrLen(Texto) do begin
                    if CopyStr(Texto, Posicion, 1) = '''' then begin
                        if CopyStr(Texto, Posicion + 1, 1) <> '''' then
                            break;
                        Posicion += 1;
                    end;
                    Posicion += 1;
                end;
                Posicion += 1;
            end else
                if EsLetra(Caracter) or (Caracter = '_') then begin
                    Inicio := Posicion;
                    Posicion += 1;
                    while EsCaracterIdentificador(CopyStr(Texto, Posicion, 1)) do
                        Posicion += 1;
                    Token := CopyStr(Texto, Inicio, Posicion - Inicio);
                    // El paréntesis agrupa el operando de AND/OR/NOT; no los convierte en funciones.
                    if not (Token in ['AND', 'OR', 'NOT']) then begin
                        Siguiente := Posicion;
                        while EsEspacio(CopyStr(Texto, Siguiente, 1)) do
                            Siguiente += 1;
                        if CopyStr(Texto, Siguiente, 1) = '(' then begin
                            if not (Token in ['MAX', 'MIN', 'ROUND', 'REDONDEAR', 'PISO', 'TECHO', 'ABS', 'IF', 'IFZERO', 'CASE', 'DIV']) then
                                exit(false);
                        end else
                            case Token of
                                'AND', 'OR', 'NOT': ;
                                'TIPO_LIQ':
                                    if (TipoLiq <> '') and not Tipo.Get(TipoLiq) then
                                        exit(false);
                                'CONVENIO':
                                    if not ConvenioConocido then
                                        exit(false);
                                'ORDEN_BASE':
                                    if not AdmiteOrdenBase then
                                        exit(false);
                                else
                                    exit(false);
                            end;
                    end;
                end else
                    Posicion += 1;
        end;
        Contexto.Add('TIPO_LIQ', 0);
        if Tipo.Get(TipoLiq) then
            Contexto.Set('TIPO_LIQ', Tipo.Orden);
        Contexto.Add('CONVENIO', 0);
        Contexto.Add('ORDEN_BASE', OrdenBase);
        Codigos.Add('TIPO_LIQ', TipoLiq);
        Codigos.Add('CONVENIO', Convenio);
        exit(IntentarEvaluarPuro(Texto, FechaRef, Contexto, Codigos, Valor));
    end;

    [TryFunction]
    local procedure IntentarEvaluarPuro(Texto: Text; FechaRef: Date; var Contexto: Dictionary of [Text, Decimal]; var Codigos: Dictionary of [Text, Text]; var Valor: Decimal)
    var
        Eval: Codeunit "Evaluador Fórmula";
    begin
        Eval.Init(Contexto, FechaRef);
        Eval.SetCodigosAtributos(Codigos);
        Eval.UsarDatosGuardados();
        Valor := Eval.EvalFormula(Texto);
    end;

    /// <summary>Devuelve un orden exacto o todas las hojas enteras de un árbol IF conservador.</summary>
    internal procedure ObtenerOrdenesPosibles(Concepto: Record "Concepto Liquidación"; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; var Ordenes: List of [Integer]): Boolean
    var
        Motor: Codeunit "Motor Liquidación";
        Posibles: List of [Integer];
        Orden: Integer;
        ConvenioOrden: Code[20];
        Formula: Text;
    begin
        Clear(Ordenes);
        ConvenioOrden := Convenio;
        // El par de cabecera no permite elegir una rama del convenio del puesto/asignación.
        if Concepto."Par CCT a Usar" <> Concepto."Par CCT a Usar"::Entidad then
            ConvenioOrden := '';
        if ResolverOrden(Concepto, FechaRef, TipoLiq, ConvenioOrden, Orden) then begin
            Ordenes.Add(Orden);
            exit(true);
        end;
        Formula := Motor.FormulaOrdenConfigurada(Concepto);
        if not FormulaOrdenAdmisible(Concepto, Formula, FechaRef) then
            exit(false);
        if not ExtraerHojasOrden(Formula, 0, Posibles) then
            exit(false);
        if Posibles.Count() = 0 then
            exit(false);
        foreach Orden in Posibles do
            Ordenes.Add(Orden);
        exit(true);
    end;

    local procedure FormulaOrdenAdmisible(Concepto: Record "Concepto Liquidación"; Formula: Text; FechaRef: Date): Boolean
    var
        Clave: Text;
        Resultado: Boolean;
    begin
        PrepararCatalogoContextos();
        Clave := Concepto.Código + ':' + Format(Concepto."Orden Cálculo", 0, 9) + ':' + Format(FechaRef, 0, 9) + ':' + Formula;
        if FormulasOrdenAdmisiblesGuardadas.Get(Clave, Resultado) then
            exit(Resultado);
        Resultado := ComprobarFormulaOrdenAdmisible(Concepto, Formula, FechaRef);
        FormulasOrdenAdmisiblesGuardadas.Add(Clave, Resultado);
        exit(Resultado);
    end;

    local procedure ComprobarFormulaOrdenAdmisible(Concepto: Record "Concepto Liquidación"; Formula: Text; FechaRef: Date): Boolean
    var
        Otro: Record "Concepto Liquidación";
        Motor: Codeunit "Motor Liquidación";
        Eval: Codeunit "Evaluador Fórmula";
        Contexto: Dictionary of [Text, Decimal];
        Codigos: Dictionary of [Text, Text];
        Texto: Text;
        Token: Text;
        Caracter: Text;
        Posicion: Integer;
        Inicio: Integer;
        Siguiente: Integer;
        ComplementoGU: Text;
        Resultado: Decimal;
    begin
        // Misma admisibilidad que el motor: jamás ejecutar consultas desde una fórmula de orden.
        if Formula.Contains('#') or Formula.Contains('@') then
            exit(false);
        ComplementoGU := Motor.VarComplementoGU();
        Texto := UpperCase(Formula);
        Posicion := 1;
        while Posicion <= StrLen(Texto) do begin
            Caracter := CopyStr(Texto, Posicion, 1);
            if Caracter = '''' then begin
                Posicion += 1;
                while Posicion <= StrLen(Texto) do begin
                    if CopyStr(Texto, Posicion, 1) = '''' then begin
                        if CopyStr(Texto, Posicion + 1, 1) <> '''' then
                            break;
                        Posicion += 1;
                    end;
                    Posicion += 1;
                end;
                Posicion += 1;
            end else
                if EsLetra(Caracter) or (Caracter = '_') then begin
                    Inicio := Posicion;
                    Posicion += 1;
                    while EsCaracterIdentificador(CopyStr(Texto, Posicion, 1)) do
                        Posicion += 1;
                    Token := CopyStr(Texto, Inicio, Posicion - Inicio);
                    // El paréntesis agrupa el operando de AND/OR/NOT; no los convierte en funciones.
                    if not (Token in ['AND', 'OR', 'NOT']) then begin
                        Siguiente := Posicion;
                        while EsEspacio(CopyStr(Texto, Siguiente, 1)) do
                            Siguiente += 1;
                        if CopyStr(Texto, Siguiente, 1) = '(' then begin
                            if not (Token in ['MAX', 'MIN', 'ROUND', 'REDONDEAR', 'PISO', 'TECHO', 'ABS', 'IF', 'IFZERO', 'CASE', 'DIV', 'ERROR']) then
                                exit(false);
                        end else begin
                            if Token.StartsWith('FILA_') or (Token = 'CANT_INCIDENCIA') or (Token = ComplementoGU) then
                                exit(false);
                            if StrLen(Token) <= MaxStrLen(Otro.Código) then begin
                                if NombresConceptosContextos.ContainsKey(Token) then
                                    exit(false);
                            end;
                            Contexto.Set(Token, 0);
                            Codigos.Set(Token, '');
                        end;
                    end;
                end else
                    Posicion += 1;
        end;
        Contexto.Set('ORDEN_BASE', Concepto."Orden Cálculo");
        Eval.Init(Contexto, FechaRef);
        Eval.SetCodigosAtributos(Codigos);
        // El modo histórico evita validar códigos contra tablas actuales. Con todas las variables
        // sembradas y sólo funciones puras permitidas, la pasada valida sintaxis sin consultas.
        Eval.UsarDatosGuardados();
        Eval.SetModoValidacion(true);
        Eval.SetLenientMode(true);
        exit(Eval.TryEvalFormula(Formula, Resultado));
    end;

    local procedure EsEspacio(Caracter: Text): Boolean
    var
        C: Char;
    begin
        if Caracter = '' then
            exit(false);
        C := Caracter[1];
        exit((C = ' ') or (C = 9) or (C = 10) or (C = 13));
    end;

    local procedure ExtraerHojasOrden(Formula: Text; Profundidad: Integer; var Ordenes: List of [Integer]): Boolean
    var
        Condicion: Text;
        RamaVerdadera: Text;
        RamaFalsa: Text;
        Orden: Integer;
    begin
        if Profundidad > 50 then
            exit(false);
        Formula := Formula.Trim();
        if Formula = '' then
            exit(false);
        if DelChr(Formula, '=', '0123456789') = '' then begin
            if not Evaluate(Orden, Formula, 9) then
                exit(false);
            if Orden < 0 then
                exit(false);
            if not Ordenes.Contains(Orden) then
                Ordenes.Add(Orden);
            exit(true);
        end;
        if not SepararRamasIf(Formula, Condicion, RamaVerdadera, RamaFalsa) then
            exit(false);
        if not ExtraerHojasOrden(RamaVerdadera, Profundidad + 1, Ordenes) then
            exit(false);
        exit(ExtraerHojasOrden(RamaFalsa, Profundidad + 1, Ordenes));
    end;

    local procedure SepararRamasIf(Formula: Text; var Condicion: Text; var RamaVerdadera: Text; var RamaFalsa: Text): Boolean
    var
        Argumentos: Text;
        Caracter: Text;
        Posicion: Integer;
        Nivel: Integer;
        PrimeraComa: Integer;
        SegundaComa: Integer;
        EnCadena: Boolean;
    begin
        Condicion := '';
        RamaVerdadera := '';
        RamaFalsa := '';
        if UpperCase(CopyStr(Formula, 1, 2)) <> 'IF' then
            exit(false);
        Argumentos := CopyStr(Formula, 3).Trim();
        if CopyStr(Argumentos, 1, 1) <> '(' then
            exit(false);
        Posicion := 1;
        while Posicion <= StrLen(Argumentos) do begin
            Caracter := CopyStr(Argumentos, Posicion, 1);
            if Caracter = '''' then begin
                if EnCadena and (CopyStr(Argumentos, Posicion + 1, 1) = '''') then
                    Posicion += 1
                else
                    EnCadena := not EnCadena;
            end else
                if not EnCadena then
                    case Caracter of
                        '(':
                            Nivel += 1;
                        ')':
                            begin
                                Nivel -= 1;
                                if Nivel < 0 then
                                    exit(false);
                                if (Nivel = 0) and (Posicion <> StrLen(Argumentos)) then
                                    exit(false);
                            end;
                        ',':
                            if Nivel = 1 then
                                if PrimeraComa = 0 then
                                    PrimeraComa := Posicion
                                else
                                    if SegundaComa = 0 then
                                        SegundaComa := Posicion
                                    else
                                        exit(false);
                    end;
            Posicion += 1;
        end;
        if EnCadena or (Nivel <> 0) or (PrimeraComa = 0) or (SegundaComa = 0) then
            exit(false);
        if CopyStr(Argumentos, StrLen(Argumentos), 1) <> ')' then
            exit(false);
        Condicion := CopyStr(Argumentos, 2, PrimeraComa - 2).Trim();
        RamaVerdadera := CopyStr(Argumentos, PrimeraComa + 1, SegundaComa - PrimeraComa - 1).Trim();
        RamaFalsa := CopyStr(Argumentos, SegundaComa + 1, StrLen(Argumentos) - SegundaComa - 1).Trim();
        exit((Condicion <> '') and (RamaVerdadera <> '') and (RamaFalsa <> ''));
    end;

    local procedure ResolverOrdenAnalisis(Concepto: Record "Concepto Liquidación"; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; EsAporte: Boolean; var Orden: Integer): Boolean
    var
        Posibles: List of [Integer];
        Posible: Integer;
        Resuelto: Boolean;
    begin
        Orden := 0;
        if OrdenesPendientes.Contains(Concepto.Código) then
            exit(false);
        // La fecha y el contexto son constantes durante Analizar. Una lista sirve para ambos roles.
        if not OrdenesPosiblesAnalisis.Get(Concepto.Código, Posibles) then begin
            if ContextoDependenciasConocido then
                Resuelto := ObtenerOrdenesPosiblesEnContexto(Concepto, FechaRef, TipoLiq, Convenio, Posibles)
            else
                Resuelto := ObtenerOrdenesPosibles(Concepto, FechaRef, TipoLiq, Convenio, Posibles);
            if not Resuelto then begin
                OrdenesPendientes.Add(Concepto.Código);
                exit(false);
            end;
            OrdenesPosiblesAnalisis.Add(Concepto.Código, Posibles);
            if Posibles.Count() > 1 then
                OrdenesConRamas.Add(Concepto.Código);
        end;
        Orden := Posibles.Get(1);
        foreach Posible in Posibles do
            if EsAporte then begin
                if Posible > Orden then
                    Orden := Posible;
            end else
                if Posible < Orden then
                    Orden := Posible;
        exit(true);
    end;

    [TryFunction]
    local procedure IntentarResolverOrden(Concepto: Record "Concepto Liquidación"; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; var Orden: Integer)
    var
        Motor: Codeunit "Motor Liquidación";
        Contexto: Dictionary of [Text, Decimal];
        Codigos: Dictionary of [Text, Text];
    begin
        Orden := Motor.OrdenEfectivo(Concepto, TipoLiq, Convenio, FechaRef, Contexto, Codigos);
    end;

    local procedure ExtremoConocido(var Ordenes: Dictionary of [Code[20], Integer]; Maximo: Boolean; var OrdenExtremo: Integer; var CodigoExtremo: Code[20])
    var
        Codigo: Code[20];
        Orden: Integer;
        Reemplazar: Boolean;
    begin
        OrdenExtremo := 0;
        CodigoExtremo := '';
        foreach Codigo in Ordenes.Keys() do begin
            Orden := Ordenes.Get(Codigo);
            Reemplazar := CodigoExtremo = '';
            if not Reemplazar then
                if Maximo then
                    Reemplazar := LlegaTarde(Orden, Codigo, OrdenExtremo, CodigoExtremo)
                else
                    Reemplazar := LlegaTarde(OrdenExtremo, CodigoExtremo, Orden, Codigo);
            if Reemplazar then begin
                OrdenExtremo := Orden;
                CodigoExtremo := Codigo;
            end;
        end;
    end;

    local procedure LlegaTarde(OrdenAporte: Integer; CodAporte: Code[20]; OrdenLectura: Integer; CodLectura: Code[20]): Boolean
    begin
        if OrdenAporte <> OrdenLectura then
            exit(OrdenAporte > OrdenLectura);
        exit(CodAporte > CodLectura);
    end;

    /// <summary>Busca un identificador completo, omitiendo literales y respetando letras españolas.</summary>
    /// <remarks>Conserva la coincidencia de nombres con prefijos @/# para los consumidores existentes.</remarks>
    procedure MencionaVariable(Texto: Text; Codigo: Code[20]): Boolean
    var
        Tokens: List of [Text];
        Token: Text;
        Nombre: Text;
    begin
        if Codigo = '' then
            exit(false);
        Nombre := UpperCase(Codigo);
        ExtraerIdentificadores(Texto, Tokens);
        foreach Token in Tokens do
            if (Token = Nombre) or (Token = '@' + Nombre) or (Token = '#' + Nombre) then
                exit(true);
        exit(false);
    end;

    internal procedure ExtraerIdentificadores(Texto: Text; var Tokens: List of [Text])
    var
        Posicion: Integer;
        Inicio: Integer;
        Caracter: Text;
    begin
        Clear(Tokens);
        Texto := UpperCase(Texto);
        Posicion := 1;
        while Posicion <= StrLen(Texto) do begin
            Caracter := CopyStr(Texto, Posicion, 1);
            if Caracter = '''' then begin
                Posicion += 1;
                while Posicion <= StrLen(Texto) do begin
                    if CopyStr(Texto, Posicion, 1) = '''' then begin
                        if CopyStr(Texto, Posicion, 2) <> '''''' then
                            break;
                        Posicion += 1;
                    end;
                    Posicion += 1;
                end;
                Posicion += 1;
            end else
                if EsLetra(Caracter) or (Caracter in ['_', '@', '#']) then begin
                    Inicio := Posicion;
                    Posicion += 1;
                    while EsCaracterIdentificador(CopyStr(Texto, Posicion, 1)) do
                        Posicion += 1;
                    Tokens.Add(CopyStr(Texto, Inicio, Posicion - Inicio));
                end else
                    Posicion += 1;
        end;
    end;

    local procedure EsCaracterIdentificador(Caracter: Text): Boolean
    begin
        if Caracter = '' then
            exit(false);
        exit(EsLetra(Caracter) or ((Caracter >= '0') and (Caracter <= '9')) or (Caracter = '_'));
    end;

    local procedure EsLetra(Caracter: Text): Boolean
    begin
        if Caracter = '' then
            exit(false);
        exit(((Caracter >= 'A') and (Caracter <= 'Z')) or (Caracter in ['Ñ', 'Á', 'É', 'Í', 'Ó', 'Ú', 'Ü']));
    end;

    local procedure CargarVersionesVigentes(FechaRef: Date; var VersionMap: Dictionary of [Code[20], Date])
    var
        Concepto: Record "Concepto Liquidación";
        Ganadora: Record "Concepto Liquidación";
        Codigo: Code[20];
        Vigencia: Date;
    begin
        Clear(VersionMap);
        Concepto.FiltrarVigentesA(FechaRef);
        if Concepto.FindSet() then
            repeat
                if not VersionMap.Get(Concepto.Código, Vigencia) then
                    VersionMap.Add(Concepto.Código, Concepto."Vigencia Desde")
                else
                    if Concepto."Vigencia Desde" > Vigencia then
                        VersionMap.Set(Concepto.Código, Concepto."Vigencia Desde");
            until Concepto.Next() = 0;
        foreach Codigo in VersionMap.Keys() do
            if Ganadora.Get(Codigo, VersionMap.Get(Codigo)) then
                if Ganadora.VigenteA(FechaRef) then begin
                    ConceptosAnalisis := Ganadora;
                    ConceptosAnalisis.Insert(false);
                end else
                    VersionMap.Remove(Codigo);
    end;

    var
        CatalogoDependenciasPreparado: Boolean;
        CatalogoContextosPreparado: Boolean;
        TiposContextos: Record "Tipo Liquidación" temporary;
        ConveniosContextos: Record "Convenio Colectivo" temporary;
        CategoriasContextos: Record "Categoría CCT" temporary;
        RestriccionesContextos: Record "Concepto CCT Vigente" temporary;
        FraccionesContextos: Record "Fracción Acumulador" temporary;
        ContextosOrdenGuardados: Dictionary of [Text, List of [Text]];
        MotivosContextosGuardados: Dictionary of [Text, Text];
        AplicabilidadContextosGuardada: Dictionary of [Text, Boolean];
        ContextoDependenciasConocido: Boolean;
        FechaDependencias: Date;
        TipoDependencias: Code[20];
        ConvenioDependencias: Code[20];
        CategoriaDependencias: Code[20];
        ConvenioDependenciasConocido: Boolean;
        DependenciasContextoPendiente: Boolean;
        CicloContextoPendiente: Boolean;
        ContextosDependenciasGuardados: Dictionary of [Code[20], Boolean];
        AportesConflictivosAnalisis: Dictionary of [Code[20], List of [Code[20]]];
        AportesTotalesAnalisis: Dictionary of [Code[20], List of [Code[20]]];
        LectoresTotalesAnalisis: Dictionary of [Code[20], List of [Code[20]]];
        FilasEtapasAnalisis: Dictionary of [Code[20], Boolean];
        ProduccionesIncluidas: Dictionary of [Code[20], Boolean];
        ProduccionesPendientes: List of [Code[20]];
        PrioridadesTestigoAnalisis: Dictionary of [Code[20], Integer];
        AmbitosTestigoAnalisis: Dictionary of [Code[20], Text];
        TiposReferidosContextos: List of [Text];
        NombresConceptosContextos: Dictionary of [Text, Boolean];
        FormulasOrdenAdmisiblesGuardadas: Dictionary of [Text, Boolean];
        ConveniosReferidosContextos: List of [Code[20]];
        MotivoCatalogoContextos: Text;
        NivelExpresionesDependencias: Integer;
        AnalisisCompatibleEnCurso: Boolean;
        DependenciasCompatiblesGuardadas: Dictionary of [Text, List of [Code[20]]];
        SemillasCompatiblesGuardadas: Dictionary of [Text, List of [Code[20]]];
        ErroresCompatiblesGuardados: Dictionary of [Text, Text];
        ExpansionCompatibleGuardada: Dictionary of [Text, Text];
        PendientesCompatiblesGuardados: Dictionary of [Text, Boolean];
        SensibilidadDependenciasGuardada: Dictionary of [Code[20], Integer];
        FechasVigentesDependencias: Dictionary of [Code[20], Date];
        FraccionesVigentesAnalisis: Record "Fracción Acumulador" temporary;
        CodigosAportesAnalisis: Dictionary of [Code[20], List of [Code[20]]];
        FechasAportesAnalisis: Dictionary of [Text, Date];
        VigentesDependencias: Record "Concepto Liquidación" temporary;
        NombresExternosDependencias: Dictionary of [Text, Boolean];
        TokensDependenciasGuardados: Dictionary of [Text, List of [Text]];
        ErroresTokensGuardados: Dictionary of [Text, Text];
        DependenciasGuardadas: Dictionary of [Code[20], List of [Code[20]]];
        InicializadasGuardadas: Dictionary of [Code[20], List of [Code[20]]];
        ErroresDependenciasGuardados: Dictionary of [Code[20], Text];
        CiclosExpansionGuardados: Dictionary of [Code[20], Text];
        CiclosDependenciasGuardados: Dictionary of [Code[20], Text];
        ConceptosAnalisis: Record "Concepto Liquidación" temporary;
        ConceptosIncluidos: Dictionary of [Code[20], Boolean];
        LectoresPorAcumulador: Dictionary of [Code[20], List of [Code[20]]];
        SoloConceptosDeclarados: Boolean;
        OrdenesPosiblesAnalisis: Dictionary of [Code[20], List of [Integer]];
        OrdenesPendientes: List of [Code[20]];
        OrdenesConRamas: List of [Code[20]];
        ParesPendientes: List of [Code[20]];
}
