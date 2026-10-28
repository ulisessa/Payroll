namespace UAS.Payroll;

codeunit 110074 "Corrección Orden Acum."
{
    // Una propuesta mueve un concepto: crea otra vigencia o actualiza explícitamente su orden.
    // No liquida ni modifica los importes guardados.
    /// <summary>Puente administrativo de sólo lectura para recuperar diagnóstico y propuestas por un único argumento.</summary>
    procedure DiagnosticarOrdenesJson(Peticion: Text)
    var
        Solicitud: JsonObject;
        Resultado: JsonObject;
        Fila: JsonObject;
        Propuesta: JsonObject;
        Filas: JsonArray;
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Origen: Record "Concepto Liquidación";
        Control: Codeunit "Control Orden Acumuladores";
        FechaRef: Date;
        FechaNueva: Date;
        TipoLiq: Code[20];
        Convenio: Code[20];
        Categoria: Code[20];
        Objetivo: Code[20];
        Candidato: Code[20];
        ActualizarVigencia: Boolean;
        IncluirSanos: Boolean;
        IncluirPropuestas: Boolean;
        Disponible: Boolean;
        Pendientes: Integer;
        TotalFilas: Integer;
        NuevoOrden: Integer;
        Explicacion: Text;
        Respuesta: Text;
    begin
        LeerContextoOrdenJson(Peticion, Solicitud, FechaRef, TipoLiq, Convenio, Categoria, ActualizarVigencia);
        Objetivo := LeerCodigoOpcionalOrdenJson(Solicitud, 'objetivo');
        Candidato := LeerCodigoOpcionalOrdenJson(Solicitud, 'candidato');
        if (Candidato <> '') and (Objetivo = '') then
            Error('Para revisar un candidato específico indicá también el objetivo.');
        if Solicitud.Contains('incluirSanos') then
            IncluirSanos := LeerBooleanoOrdenJson(Solicitud, 'incluirSanos');
        IncluirPropuestas := true;
        if Solicitud.Contains('incluirPropuestas') then
            IncluirPropuestas := LeerBooleanoOrdenJson(Solicitud, 'incluirPropuestas');
        IniciarOperacion();
        Pendientes := Control.Analizar(FechaRef, TipoLiq, Convenio, Categoria, Objetivo, Buffer);
        TotalFilas := Buffer.Count();
        if Buffer.FindSet() then
            repeat
                if Buffer.Conflicto or IncluirSanos or (Objetivo <> '') then begin
                    Clear(Fila);
                    Fila.Add('objetivo', Buffer."Cód. Acumulador");
                    if Buffer."Cód. Acumulador" = Buffer."Concepto Mín. Lectura" then
                        Fila.Add('clase', 'referencias')
                    else
                        Fila.Add('clase', 'acumulador');
                    Fila.Add('descripcion', Buffer.Descripción);
                    Fila.Add('conflicto', Buffer.Conflicto);
                    Fila.Add('requiereContexto', Buffer."Requiere Contexto");
                    Fila.Add('ordenMaxAporte', Buffer."Orden Máx. Aporte");
                    Fila.Add('conceptoMaxAporte', Buffer."Concepto Máx. Aporte");
                    Fila.Add('ordenMinLectura', Buffer."Orden Mín. Lectura");
                    Fila.Add('conceptoMinLectura', Buffer."Concepto Mín. Lectura");
                    Fila.Add('cantidadAportes', Buffer."Cant. Aportes");
                    Fila.Add('cantidadLecturas', Buffer."Cant. Lecturas");
                    Fila.Add('aportesEnConflicto', Buffer."Aportes en Conflicto");
                    Fila.Add('codigosEnConflicto', Buffer."Códigos en Conflicto");
                    Fila.Add('observacion', Buffer.Observación);
                    if IncluirPropuestas then begin
                        Disponible := false;
                        Clear(Origen);
                        NuevoOrden := 0;
                        FechaNueva := 0D;
                        Explicacion := '';
                        if not IntentarPropuestaOrdenJson(Buffer, FechaRef, TipoLiq, Convenio, Categoria, ActualizarVigencia, Candidato, Disponible, Origen, NuevoOrden, FechaNueva, Explicacion) then begin
                            Disponible := false;
                            Explicacion := GetLastErrorText();
                        end;
                        Clear(Propuesta);
                        Propuesta.Add('disponible', Disponible);
                        Propuesta.Add('explicacion', Explicacion);
                        if Disponible then
                            CompletarPropuestaOrdenJson(Propuesta, Buffer."Cód. Acumulador", FechaRef, TipoLiq, Convenio, Categoria, ActualizarVigencia, Origen, NuevoOrden, FechaNueva);
                        Fila.Add('propuesta', Propuesta);
                    end;
                    Filas.Add(Fila);
                end;
            until Buffer.Next() = 0;
        Resultado.Add('protocolo', 1);
        AgregarContextoOrdenJson(Resultado, FechaRef, TipoLiq, Convenio, Categoria, ActualizarVigencia);
        Resultado.Add('objetivo', Objetivo);
        Resultado.Add('candidato', Candidato);
        Resultado.Add('totalFilas', TotalFilas);
        Resultado.Add('pendientes', Pendientes);
        Resultado.Add('filas', Filas);
        Resultado.WriteTo(Respuesta);
        // Invoke-NAVCodeunit descarta retornos. El error identificado transporta sólo lectura;
        // este método no llega a Aplicar ni escribe configuración, auditoría o liquidaciones.
        Error('CONTROL_ORDEN_JSON:%1:FIN_CONTROL_ORDEN_JSON', Respuesta);
    end;

    /// <summary>Aplica una única propuesta individual que coincida exactamente con la petición revisada.</summary>
    procedure AplicarOrdenSeguroJson(Peticion: Text)
    var
        Solicitud: JsonObject;
        Actual: Record "Concepto Liquidación";
        Origen: Record "Concepto Liquidación";
        FechaRef: Date;
        Vigencia: Date;
        FechaEsperada: Date;
        FechaPropuesta: Date;
        TipoLiq: Code[20];
        Convenio: Code[20];
        Categoria: Code[20];
        Objetivo: Code[20];
        Codigo: Code[20];
        ActualizarVigencia: Boolean;
        OrdenEsperado: Integer;
        OrdenPropuesto: Integer;
        RevisionEsperada: BigInteger;
        RevisionTexto: Text;
        Explicacion: Text;
    begin
        LeerContextoOrdenJson(Peticion, Solicitud, FechaRef, TipoLiq, Convenio, Categoria, ActualizarVigencia);
        Objetivo := LeerCodigoOrdenJson(Solicitud, 'objetivo');
        Codigo := LeerCodigoOrdenJson(Solicitud, 'codigo');
        if (Objetivo = '') or (Codigo = '') then
            Error('La aplicación requiere un objetivo y un código de concepto explícitos.');
        Vigencia := LeerFechaOrdenJson(Solicitud, 'vigenciaDesde');
        FechaEsperada := LeerFechaOrdenJson(Solicitud, 'fechaNueva');
        OrdenEsperado := LeerEnteroOrdenJson(Solicitud, 'nuevoOrden');
        if OrdenEsperado < 0 then
            Error('El nuevo orden debe ser un entero mayor o igual a cero.');
        RevisionTexto := LeerTextoOrdenJson(Solicitud, 'rowversion');
        if not Evaluate(RevisionEsperada, RevisionTexto, 9) then
            Error('rowversion debe ser una cadena con un entero positivo de 64 bits.');
        if (RevisionEsperada <= 0) or (Format(RevisionEsperada, 0, 9) <> RevisionTexto) then
            Error('rowversion debe ser una cadena con un entero positivo de 64 bits, sin formato adicional.');
        if not Actual.Get(Codigo, Vigencia) then
            Error('No existe la vigencia revisada de %1 desde %2.', Codigo, Vigencia);
        if Actual.SystemRowVersion <> RevisionEsperada then
            Error('La vigencia cambió desde el diagnóstico. Volvé a obtener y revisar la propuesta.');
        // Preparar es individual: no permite que el puente elija otro concepto o mueva una fila
        // distinta de la revisada. Vuelve a comprobar todo el intervalo y las dependencias.
        if not Preparar(Objetivo, FechaRef, TipoLiq, Convenio, Categoria, Codigo, ActualizarVigencia, Origen, OrdenPropuesto, FechaPropuesta, Explicacion) then
            Error('La propuesta ya no es aplicable: %1', Explicacion);
        if (Origen.Código <> Codigo) or (Origen."Vigencia Desde" <> Vigencia) or
           (Origen.SystemRowVersion <> RevisionEsperada) or (OrdenPropuesto <> OrdenEsperado) or
           (FechaPropuesta <> FechaEsperada)
        then
            Error('La propuesta actual difiere del concepto, vigencia, revisión, fecha u orden esperados. No se guardó ningún cambio.');
        // Aplicar relee y valida bajo sus locks existentes; no agregar Commit ni envolver en Try.
        Aplicar(Objetivo, Origen, FechaEsperada, OrdenEsperado, TipoLiq, Convenio, Categoria, ActualizarVigencia);
    end;

    [TryFunction]
    local procedure IntentarPropuestaOrdenJson(Buffer: Record "Diag. Orden Acum. Buffer"; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; ActualizarVigencia: Boolean; Candidato: Code[20]; var Disponible: Boolean; var Origen: Record "Concepto Liquidación"; var NuevoOrden: Integer; var FechaNueva: Date; var Explicacion: Text)
    var
        Movidos: List of [Code[20]];
    begin
        if Candidato <> '' then
            Disponible := PrepararEnOperacion(Buffer."Cód. Acumulador", FechaRef, TipoLiq, Convenio, Categoria, Candidato, ActualizarVigencia, Origen, NuevoOrden, FechaNueva, Explicacion)
        else
            Disponible := ProponerFilaEnOperacion(Buffer, FechaRef, TipoLiq, Convenio, Categoria, false, ActualizarVigencia, Movidos, Origen, NuevoOrden, FechaNueva, Explicacion);
    end;

    local procedure CompletarPropuestaOrdenJson(var Propuesta: JsonObject; Objetivo: Code[20]; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; ActualizarVigencia: Boolean; Origen: Record "Concepto Liquidación"; NuevoOrden: Integer; FechaNueva: Date)
    var
        Motor: Codeunit "Motor Liquidación";
        Aplicacion: JsonObject;
    begin
        Propuesta.Add('codigo', Origen.Código);
        Propuesta.Add('vigenciaDesde', Format(Origen."Vigencia Desde", 0, 9));
        Propuesta.Add('rowversion', Format(Origen.SystemRowVersion, 0, 9));
        Propuesta.Add('ordenActualExpresion', Motor.FormulaOrdenConfigurada(Origen));
        Propuesta.Add('nuevoOrden', NuevoOrden);
        Propuesta.Add('fechaNueva', Format(FechaNueva, 0, 9));
        AgregarContextoOrdenJson(Aplicacion, FechaRef, TipoLiq, Convenio, Categoria, ActualizarVigencia);
        Aplicacion.Add('objetivo', Objetivo);
        Aplicacion.Add('codigo', Origen.Código);
        Aplicacion.Add('vigenciaDesde', Format(Origen."Vigencia Desde", 0, 9));
        Aplicacion.Add('rowversion', Format(Origen.SystemRowVersion, 0, 9));
        Aplicacion.Add('nuevoOrden', NuevoOrden);
        Aplicacion.Add('fechaNueva', Format(FechaNueva, 0, 9));
        Propuesta.Add('peticionAplicar', Aplicacion);
    end;

    local procedure AgregarContextoOrdenJson(var Objeto: JsonObject; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; ActualizarVigencia: Boolean)
    begin
        Objeto.Add('fechaReferencia', Format(FechaRef, 0, 9));
        Objeto.Add('tipo', TipoLiq);
        Objeto.Add('convenio', Convenio);
        Objeto.Add('categoria', Categoria);
        Objeto.Add('actualizarVigencia', ActualizarVigencia);
    end;

    local procedure LeerContextoOrdenJson(Peticion: Text; var Solicitud: JsonObject; var FechaRef: Date; var TipoLiq: Code[20]; var Convenio: Code[20]; var Categoria: Code[20]; var ActualizarVigencia: Boolean)
    var
        Tipo: Record "Tipo Liquidación";
        ConvenioCCT: Record "Convenio Colectivo";
        CategoriaCCT: Record "Categoría CCT";
    begin
        if not Solicitud.ReadFrom(Peticion) then
            Error('La petición debe ser un objeto JSON válido.');
        FechaRef := LeerFechaOrdenJson(Solicitud, 'fechaReferencia');
        TipoLiq := LeerCodigoOrdenJson(Solicitud, 'tipo');
        Convenio := LeerCodigoOrdenJson(Solicitud, 'convenio');
        Categoria := LeerCodigoOrdenJson(Solicitud, 'categoria');
        ActualizarVigencia := LeerBooleanoOrdenJson(Solicitud, 'actualizarVigencia');
        if TipoLiq <> '' then
            if not Tipo.Get(TipoLiq) then
                Error('No existe el tipo de liquidación indicado: %1.', TipoLiq);
        if Convenio <> '' then
            if not ConvenioCCT.Get(Convenio) then
                Error('No existe el convenio indicado: %1.', Convenio);
        if Categoria <> '' then begin
            if Convenio = '' then
                Error('Una categoría requiere un convenio explícito.');
            if not CategoriaCCT.Get(Convenio, Categoria) then
                Error('No existe la categoría %1 del convenio %2.', Categoria, Convenio);
        end;
    end;

    local procedure LeerValorOrdenJson(Solicitud: JsonObject; Campo: Text): JsonValue
    var
        Token: JsonToken;
        Valor: JsonValue;
    begin
        if not Solicitud.Get(Campo, Token) then
            Error('Falta el campo obligatorio %1.', Campo);
        if not Token.IsValue() then
            Error('El campo %1 debe ser un valor simple.', Campo);
        Valor := Token.AsValue();
        if Valor.IsNull() then
            Error('El campo %1 no admite null.', Campo);
        exit(Valor);
    end;

    local procedure LeerTextoOrdenJson(Solicitud: JsonObject; Campo: Text): Text
    var
        Valor: JsonValue;
        Literal: Text;
    begin
        Valor := LeerValorOrdenJson(Solicitud, Campo);
        Valor.WriteTo(Literal);
        if CopyStr(Literal, 1, 1) <> '"' then
            Error('El campo %1 debe ser una cadena JSON.', Campo);
        exit(Valor.AsText());
    end;

    local procedure LeerCodigoOrdenJson(Solicitud: JsonObject; Campo: Text): Code[20]
    var
        Texto: Text;
    begin
        Texto := LeerTextoOrdenJson(Solicitud, Campo);
        if (StrLen(Texto) > 20) or (Texto <> Texto.Trim()) then
            Error('El campo %1 debe tener como máximo 20 caracteres y no contener espacios al principio o al final.', Campo);
        exit(CopyStr(Texto, 1, 20));
    end;

    local procedure LeerCodigoOpcionalOrdenJson(Solicitud: JsonObject; Campo: Text): Code[20]
    begin
        if not Solicitud.Contains(Campo) then
            exit('');
        exit(LeerCodigoOrdenJson(Solicitud, Campo));
    end;

    local procedure LeerFechaOrdenJson(Solicitud: JsonObject; Campo: Text): Date
    var
        Texto: Text;
        Fecha: Date;
    begin
        Texto := LeerTextoOrdenJson(Solicitud, Campo);
        if not Evaluate(Fecha, Texto, 9) then
            Error('El campo %1 debe ser una fecha ISO AAAA-MM-DD.', Campo);
        if (Fecha = 0D) or (StrLen(Texto) <> 10) or (Format(Fecha, 0, 9) <> Texto) then
            Error('El campo %1 debe ser una fecha ISO AAAA-MM-DD válida y no vacía.', Campo);
        exit(Fecha);
    end;

    local procedure LeerBooleanoOrdenJson(Solicitud: JsonObject; Campo: Text): Boolean
    var
        Valor: JsonValue;
        Literal: Text;
    begin
        Valor := LeerValorOrdenJson(Solicitud, Campo);
        Valor.WriteTo(Literal);
        if not (Literal in ['true', 'false']) then
            Error('El campo %1 debe ser un booleano JSON true o false.', Campo);
        exit(Literal = 'true');
    end;

    local procedure LeerEnteroOrdenJson(Solicitud: JsonObject; Campo: Text): Integer
    var
        Valor: JsonValue;
        Literal: Text;
        Entero: Integer;
    begin
        Valor := LeerValorOrdenJson(Solicitud, Campo);
        Valor.WriteTo(Literal);
        if not Evaluate(Entero, Literal, 9) then
            Error('El campo %1 debe ser un entero JSON de 32 bits.', Campo);
        if Format(Entero, 0, 9) <> Literal then
            Error('El campo %1 debe ser un entero JSON, sin comillas ni decimales.', Campo);
        exit(Entero);
    end;

    procedure Proponer(CodAcum: Code[20]; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; var Origen: Record "Concepto Liquidación"; var NuevoOrden: Integer; var FechaNueva: Date; var Explicacion: Text): Boolean
    begin
        exit(Proponer(CodAcum, FechaRef, TipoLiq, Convenio, Categoria, false, Origen, NuevoOrden, FechaNueva, Explicacion));
    end;

    procedure Proponer(CodAcum: Code[20]; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; ActualizarVigencia: Boolean; var Origen: Record "Concepto Liquidación"; var NuevoOrden: Integer; var FechaNueva: Date; var Explicacion: Text): Boolean
    var
        Control: Codeunit "Control Orden Acumuladores";
        Buffer: Record "Diag. Orden Acum. Buffer" temporary;
        Movidos: List of [Code[20]];
    begin
        IniciarOperacion();
        Clear(Origen);
        NuevoOrden := 0;
        FechaNueva := 0D;
        Explicacion := '';
        if FechaRef = 0D then
            FechaRef := WorkDate();
        Control.Analizar(FechaRef, TipoLiq, Convenio, Categoria, CodAcum, Buffer);
        if not Buffer.Get(CodAcum) then begin
            Explicacion := 'No se encontró el objetivo vigente ni dependencias para revisar.';
            exit(false);
        end;
        exit(ProponerFilaEnOperacion(Buffer, FechaRef, TipoLiq, Convenio, Categoria, false, ActualizarVigencia, Movidos, Origen, NuevoOrden, FechaNueva, Explicacion));
    end;

    local procedure ProponerFilaEnOperacion(Buffer: Record "Diag. Orden Acum. Buffer"; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; EnLote: Boolean; ActualizarVigencia: Boolean; Movidos: List of [Code[20]]; var Origen: Record "Concepto Liquidación"; var NuevoOrden: Integer; var FechaNueva: Date; var Explicacion: Text): Boolean
    var
        Candidato: Record "Concepto Liquidación";
        Aportes: List of [Code[20]];
        Lectores: List of [Code[20]];
        Candidatos: List of [Code[20]];
        Elegido: Code[20];
        CodAcum: Code[20];
        Motivos: Text;
        FechaDisponible: Boolean;
    begin
        Clear(Origen);
        NuevoOrden := 0;
        FechaNueva := 0D;
        Explicacion := '';
        CodAcum := Buffer."Cód. Acumulador";
        // Un orden condicional de otro concepto puede tener variantes finitas comprobables.
        // La falta de contexto se evalúa sobre las dependencias de cada movimiento.
        if (Buffer."Cant. Aportes" = 0) or (Buffer."Cant. Lecturas" = 0) then begin
            if Buffer.Observación <> '' then
                Explicacion := Buffer.Observación
            else
                Explicacion := 'Se necesita al menos un aporte y una lectura para proponer un movimiento.';
            exit(false);
        end;
        CargarContexto(FechaRef, TipoLiq, Convenio);
        if not IntentarObtenerAportes(CodAcum, Aportes) then begin
            Explicacion := GetLastErrorText();
            exit(false);
        end;
        if IntentarObtenerLectores(CodAcum, Lectores) then begin
            if EnLote and EsObjetivoAcumulador(CodAcum) then
                if TieneEtapaCompatible(CodAcum, FechaRef, TipoLiq, Convenio, Explicacion) then
                    exit(false);
            CargarContexto(FechaRef, TipoLiq, Convenio);
            if Buffer."Concepto Máx. Aporte" <> '' then
                if ParticipaEnPendiente(Buffer."Concepto Máx. Aporte", true, Lectores) then
                    Candidatos.Add(Buffer."Concepto Máx. Aporte");
            foreach Elegido in Aportes do
                if not Candidatos.Contains(Elegido) then
                    if ParticipaEnPendiente(Elegido, true, Lectores) then
                        Candidatos.Add(Elegido);
            foreach Elegido in Lectores do
                if not Candidatos.Contains(Elegido) then
                    if ParticipaEnPendiente(Elegido, false, Aportes) then
                        Candidatos.Add(Elegido);
        end else begin
            Motivos := GetLastErrorText();
            foreach Elegido in Aportes do
                Candidatos.Add(Elegido);
        end;
        if Candidatos.Count() = 0 then begin
            if Buffer."Requiere Contexto" then
                Explicacion := 'Pendiente de contexto: falta resolver algún orden o el par de un puesto/asignación. Completá tipo, convenio y categoría; un par alternativo requiere revisar una liquidación concreta.'
            else
                Explicacion := 'Cada concepto ya queda del lado correcto de las lecturas o aportes. No se propone crear una vigencia.';
            exit(false);
        end;
        foreach Elegido in Candidatos do begin
            FechaDisponible := not Movidos.Contains(Elegido);
            if not FechaDisponible then
                Explicacion := 'El concepto ya fue corregido en este lote; no se vuelve a mover.';
            if FechaDisponible and EnLote and not ActualizarVigencia then begin
                CargarContexto(FechaRef, TipoLiq, Convenio);
                ObtenerConceptoObligatorio(Elegido, Candidato);
                if Candidato."Vigencia Desde" >= FechaRef then begin
                    FechaDisponible := false;
                    Explicacion := StrSubstNo('La versión de %1 ya comienza el %2. Elegí una fecha posterior para crear otra vigencia; el lote no desplaza la fecha automáticamente.', Elegido, FechaRef);
                end;
            end;
            if FechaDisponible then
                if PrepararEnOperacion(CodAcum, FechaRef, TipoLiq, Convenio, Categoria, Elegido, ActualizarVigencia, Origen, NuevoOrden, FechaNueva, Explicacion) then
                    exit(true);
            // Conservar varios bloqueos concretos, sin devolver una posición ficticia o igual.
            if StrLen(Motivos) < 1800 then
                AgregarLinea(Motivos, Elegido + ': ' + Explicacion);
        end;
        Clear(Origen);
        NuevoOrden := 0;
        FechaNueva := 0D;
        Explicacion := 'No hay un movimiento seguro de un solo concepto para este objetivo.';
        if Motivos <> '' then
            AgregarLinea(Explicacion, Motivos);
        exit(false);
    end;

    /// <summary>Revisa las bases relacionadas con la versión exacta abierta en la ficha, sin escribir.</summary>
    procedure AnalizarConcepto(ConceptoOrigen: Record "Concepto Liquidación"; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; var Buffer: Record "Diag. Orden Acum. Buffer" temporary): Integer
    var
        Actual: Record "Concepto Liquidación";
        Control: Codeunit "Control Orden Acumuladores";
        Acumuladores: List of [Code[20]];
        Hallazgos: Integer;
    begin
        IniciarOperacion();
        if not Buffer.IsTemporary() then
            Error('El resultado del control de orden debe ser una tabla temporal.');
        if FechaRef = 0D then
            FechaRef := WorkDate();
        ValidarVersionConcepto(ConceptoOrigen, FechaRef, TipoLiq, Convenio, Actual);
        ObtenerObjetivosRelacionados(Actual, false, Acumuladores);
        Buffer.Reset();
        Buffer.DeleteAll();
        if Acumuladores.Count() = 0 then
            exit(0);
        // Una sola revisión del contexto; el alcance de ficha se recorta después.
        // Sin bases relacionadas no se afirma haber validado referencias # entre conceptos.
        Control.Analizar(FechaRef, TipoLiq, Convenio, Categoria, Buffer);
        if Buffer.FindSet() then
            repeat
                if not Acumuladores.Contains(Buffer."Cód. Acumulador") then
                    Buffer.Delete()
                else
                    if Buffer.Conflicto then
                        Hallazgos += 1;
            until Buffer.Next() = 0;
        Buffer.Reset();
        if Buffer.FindFirst() then;
        exit(Hallazgos);
    end;

    /// <summary>Propone sólo el concepto de la ficha; un origen o una base ajenos producen error.</summary>
    procedure PrepararConcepto(ConceptoOrigen: Record "Concepto Liquidación"; CodAcum: Code[20]; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; var Origen: Record "Concepto Liquidación"; var NuevoOrden: Integer; var FechaNueva: Date; var Explicacion: Text): Boolean
    begin
        exit(PrepararConcepto(ConceptoOrigen, CodAcum, FechaRef, TipoLiq, Convenio, Categoria, false, Origen, NuevoOrden, FechaNueva, Explicacion));
    end;

    procedure PrepararConcepto(ConceptoOrigen: Record "Concepto Liquidación"; CodAcum: Code[20]; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; ActualizarVigencia: Boolean; var Origen: Record "Concepto Liquidación"; var NuevoOrden: Integer; var FechaNueva: Date; var Explicacion: Text): Boolean
    var
        Actual: Record "Concepto Liquidación";
        Acumulador: Record "Concepto Liquidación";
        Acumuladores: List of [Code[20]];
        Disponible: Boolean;
    begin
        IniciarOperacion();
        Clear(Origen);
        NuevoOrden := 0;
        FechaNueva := 0D;
        Explicacion := '';
        if FechaRef = 0D then
            FechaRef := WorkDate();
        ValidarVersionConcepto(ConceptoOrigen, FechaRef, TipoLiq, Convenio, Actual);
        ObtenerObjetivosRelacionados(Actual, true, Acumuladores);
        if not Acumuladores.Contains(CodAcum) then
            Error('El objetivo %1 no está relacionado con el concepto %2 en la fecha seleccionada.', CodAcum, Actual.Código);
        if not ObtenerConcepto(CodAcum, Acumulador) then
            Error('El objetivo %1 no está vigente en la fecha seleccionada.', CodAcum);
        if Actual."Es Acumulador" then begin
            Explicacion := 'Un acumulador no tiene orden de ejecución propio. Revisá el orden de sus aportantes y lectores en el control de orden.';
            exit(false);
        end;
        Disponible := PrepararEnOperacion(CodAcum, FechaRef, TipoLiq, Convenio, Categoria, Actual.Código, ActualizarVigencia, Origen, NuevoOrden, FechaNueva, Explicacion);
        if Disponible then begin
            if (Origen.Código <> Actual.Código) or (Origen."Vigencia Desde" <> Actual."Vigencia Desde") then
                Error('La propuesta corresponde a otra versión del concepto. Volvé a abrir la revisión desde la ficha.');
            if Origen.SystemRowVersion <> Actual.SystemRowVersion then
                Error('El concepto cambió durante la preparación. Volvé a abrir la revisión desde la ficha.');
        end;
        exit(Disponible);
    end;

    local procedure ValidarVersionConcepto(ConceptoOrigen: Record "Concepto Liquidación"; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; var Actual: Record "Concepto Liquidación")
    var
        Ganadora: Record "Concepto Liquidación";
    begin
        if not Actual.Get(ConceptoOrigen.Código, ConceptoOrigen."Vigencia Desde") then
            Error('La versión del concepto abierta en la ficha no existe. Guardá o volvé a abrir la ficha.');
        if ConceptoOrigen.SystemRowVersion = 0 then
            Error('La revisión necesita una versión guardada del concepto. Volvé a abrir la ficha.');
        if Actual.SystemRowVersion <> ConceptoOrigen.SystemRowVersion then
            Error('La versión del concepto cambió desde que se abrió la revisión. Volvé a abrirla desde la ficha.');
        if not Actual.VigenteA(FechaRef) then
            Error('La versión de %1 desde %2 no está vigente el %3. Elegí una fecha dentro de esta vigencia.', Actual.Código, Actual."Vigencia Desde", FechaRef);
        CargarContexto(FechaRef, TipoLiq, Convenio);
        if not ObtenerConcepto(Actual.Código, Ganadora) then
            Error('No hay una versión vigente de %1 el %2.', Actual.Código, FechaRef);
        if Ganadora."Vigencia Desde" <> Actual."Vigencia Desde" then
            Error('El %1 corresponde a otra vigencia de %2. Cambiá la fecha o abrí la versión que querés revisar.', FechaRef, Actual.Código);
    end;

    local procedure ObtenerObjetivosRelacionados(Concepto: Record "Concepto Liquidación"; ExigirDependencias: Boolean; var Acumuladores: List of [Code[20]])
    var
        Referido: Record "Concepto Liquidación";
        Lector: Record "Concepto Liquidación" temporary;
        Dependencias: Dictionary of [Code[20], Boolean];
        Codigo: Code[20];
        Errores: Text;
    begin
        Clear(Acumuladores);
        if Concepto."Es Acumulador" then begin
            Acumuladores.Add(Concepto.Código);
            exit;
        end;
        ObtenerAcumuladores(Concepto.Código, Acumuladores);
        DependenciasDe(Concepto, Dependencias, Errores);
        if ExigirDependencias and ContextoConcreto and (Errores <> '') then
            Error('No se pueden comprobar todas las bases relacionadas con %1: %2.', Concepto.Código, Errores);
        foreach Codigo in Dependencias.Keys() do
            if ObtenerConcepto(Codigo, Referido) then
                if Referido."Es Acumulador" then
                    if not Acumuladores.Contains(Codigo) then
                        Acumuladores.Add(Codigo);
        // La propia fila resume sus entradas calculadas; las filas de consumidores
        // permiten revisar un concepto productor aun cuando no aporte a una base.
        if not Acumuladores.Contains(Concepto.Código) then
            Acumuladores.Add(Concepto.Código);
        Lector.Copy(Todos, true);
        Lector.Reset();
        if Lector.FindSet() then
            repeat
                if not Lector."Es Acumulador" then
                    if AplicaAlAmbito(Lector) then begin
                        DependenciasDe(Lector, Dependencias, Errores);
                        if Dependencias.ContainsKey(Concepto.Código) then
                            if not Acumuladores.Contains(Lector.Código) then
                                Acumuladores.Add(Lector.Código);
                    end;
            until Lector.Next() = 0;
    end;

    procedure CorregirTodos(FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; var Cambios: Integer; var Pendientes: Integer; var Detalle: Text)
    var
        Resultado: Record "Diag. Orden Acum. Buffer" temporary;
    begin
        CorregirTodos(FechaRef, TipoLiq, Convenio, Categoria, Cambios, Pendientes, Detalle, Resultado);
    end;

    procedure CorregirTodos(FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; var Cambios: Integer; var Pendientes: Integer; var Detalle: Text; var Resultado: Record "Diag. Orden Acum. Buffer" temporary)
    begin
        CorregirTodos(FechaRef, TipoLiq, Convenio, Categoria, false, Cambios, Pendientes, Detalle, Resultado);
    end;

    procedure CorregirTodos(FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; ActualizarVigencia: Boolean; var Cambios: Integer; var Pendientes: Integer; var Detalle: Text)
    var
        Resultado: Record "Diag. Orden Acum. Buffer" temporary;
    begin
        CorregirTodos(FechaRef, TipoLiq, Convenio, Categoria, ActualizarVigencia, Cambios, Pendientes, Detalle, Resultado);
    end;

    procedure CorregirTodos(FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; ActualizarVigencia: Boolean; var Cambios: Integer; var Pendientes: Integer; var Detalle: Text; var Resultado: Record "Diag. Orden Acum. Buffer" temporary)
    var
        Concepto: Record "Concepto Liquidación";
        Fraccion: Record "Fracción Acumulador";
        Restriccion: Record "Concepto CCT Vigente";
        Inicial: Record "Diag. Orden Acum. Buffer" temporary;
        Actual: Record "Diag. Orden Acum. Buffer" temporary;
        Control: Codeunit "Control Orden Acumuladores";
        Codigos: List of [Code[20]];
        Movidos: List of [Code[20]];
        Motivos: Dictionary of [Code[20], Text];
        Codigo: Code[20];
        Motivo: Text;
    begin
        Cambios := 0;
        Pendientes := 0;
        Detalle := '';
        if not Resultado.IsTemporary() then
            Error('El resultado del control de orden debe ser una tabla temporal.');
        if FechaRef = 0D then
            FechaRef := WorkDate();
        // Una sola transacción. Los rechazos de búsqueda no escriben; un error de
        // aplicación revierte también los movimientos anteriores del mismo lote.
        Concepto.LockTable();
        Fraccion.LockTable();
        Restriccion.LockTable();
        IniciarOperacion();
        Control.Analizar(FechaRef, TipoLiq, Convenio, Categoria, Inicial);
        if Inicial.FindSet() then
            repeat
                Codigos.Add(Inicial."Cód. Acumulador");
                Actual := Inicial;
                Actual.Insert();
            until Inicial.Next() = 0;
        // Cada concepto se mueve como máximo una vez en esta fecha. Reintentar los
        // pendientes permite aprovechar una dependencia que otro movimiento liberó.
        while CorregirSiguiente(Actual, Codigos, Movidos, FechaRef, TipoLiq, Convenio, Categoria, ActualizarVigencia, Motivos, Detalle) do
            Cambios += 1;
        Control.Analizar(FechaRef, TipoLiq, Convenio, Categoria, Resultado);
        if Resultado.Count() <> Inicial.Count() then
            Error('El conjunto de objetivos cambió durante el lote. No se guardará ningún cambio. Volvé a verificar la configuración.');
        foreach Codigo in Codigos do begin
            Inicial.Get(Codigo);
            if not Resultado.Get(Codigo) then
                Error('El objetivo %1 dejó de estar disponible durante el lote. No se guardará ningún cambio.', Codigo);
            if (Resultado."Aportes en Conflicto" > Inicial."Aportes en Conflicto") or
               (Resultado."Requiere Contexto" and not Inicial."Requiere Contexto") then
                Error('La revisión final detectó un nuevo conflicto en %1. No se guardará ningún cambio del lote.', Codigo);
            if Resultado.Conflicto then begin
                Pendientes += 1;
                if not Motivos.Get(Codigo, Motivo) then
                    Motivo := 'Requiere revisión individual; no se encontró un movimiento verificable.';
                // El detalle completo por candidato sigue disponible en Corregir orden.
                if StrLen(Motivo) > 600 then
                    Motivo := CopyStr(Motivo, 1, 600) + '… Revisá Corregir orden para ampliar los motivos.';
                AgregarLinea(Detalle, StrSubstNo('Pendiente %1: %2', Codigo, Motivo));
            end;
        end;
        if Categoria <> '' then
            AgregarLinea(Detalle, 'La categoría acota el diagnóstico. Los cambios de orden alcanzan todas las categorías del tipo y convenio elegidos.');
        if ActualizarVigencia and (Cambios > 0) then
            AgregarLinea(Detalle, 'Se actualizó el orden de las vigencias existentes, sin cambiar sus fechas ni los recibos guardados. Sus próximos recálculos, incluidos períodos anteriores, usarán el orden nuevo.');
    end;

    local procedure CorregirSiguiente(var Buffer: Record "Diag. Orden Acum. Buffer" temporary; Codigos: List of [Code[20]]; var Movidos: List of [Code[20]]; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; ActualizarVigencia: Boolean; var Motivos: Dictionary of [Code[20], Text]; var Detalle: Text): Boolean
    var
        Origen: Record "Concepto Liquidación";
        NuevaFila: Record "Diag. Orden Acum. Buffer" temporary;
        Control: Codeunit "Control Orden Acumuladores";
        Codigo: Code[20];
        NuevoOrden: Integer;
        OrdenAnterior: Integer;
        TardiosAntes: Integer;
        FechaNueva: Date;
        Explicacion: Text;
        Disponible: Boolean;
        RequeriaContexto: Boolean;
    begin
        foreach Codigo in Codigos do begin
            Buffer.Get(Codigo);
            if Buffer.Conflicto then begin
                Disponible := false;
                Explicacion := '';
                if not IntentarProponerFilaLote(Buffer, FechaRef, TipoLiq, Convenio, Categoria, ActualizarVigencia, Movidos, Disponible, Origen, NuevoOrden, FechaNueva, Explicacion) then begin
                    Disponible := false;
                    Explicacion := GetLastErrorText();
                end;
                if Disponible then begin
                    if ActualizarVigencia then begin
                        if FechaNueva <> Origen."Vigencia Desde" then
                            Error('La propuesta de %1 no corresponde a su vigencia original.', Origen.Código);
                    end else
                        if FechaNueva <> FechaRef then
                            Error('La propuesta de %1 no corresponde a la fecha del lote.', Origen.Código);
                    if Movidos.Contains(Origen.Código) then
                        Error('El lote intentó mover nuevamente %1 en la misma fecha. No se guardará ningún cambio.', Origen.Código);
                    CargarContexto(FechaRef, TipoLiq, Convenio);
                    OrdenAnterior := ExigirOrden(Origen);
                    TardiosAntes := Buffer."Aportes en Conflicto";
                    RequeriaContexto := Buffer."Requiere Contexto";
                    // Revalidación bajo los mismos locks y con la foto de esta operación.
                    // Nunca envolver esta escritura en TryFunction.
                    AplicarEnOperacion(Codigo, Origen, FechaNueva, NuevoOrden, TipoLiq, Convenio, Categoria, ActualizarVigencia);
                    Control.Analizar(FechaRef, TipoLiq, Convenio, Categoria, Codigo, NuevaFila);
                    if not NuevaFila.Get(Codigo) then
                        Error('No se pudo comprobar la corrección de %1. No se guardará ningún cambio.', Codigo);
                    // Atrasar uno de varios lectores mejora pares de precedencia aunque
                    // el mismo aportante siga figurando como tardío para los demás.
                    if (NuevaFila."Requiere Contexto" and not RequeriaContexto) or (NuevaFila."Aportes en Conflicto" > TardiosAntes) then
                        Error('El cambio de %1 empeora el diagnóstico de %2. No se guardará ningún cambio del lote.', Origen.Código, Codigo);
                    Movidos.Add(Origen.Código);
                    Buffer := NuevaFila;
                    Buffer.Modify();
                    AgregarLinea(Detalle, StrSubstNo('Corregido %1: orden %2 → %3 desde %4 (base %5).', Origen.Código, OrdenAnterior, NuevoOrden, FechaNueva, Codigo));
                    // No usar versiones, órdenes ni aprobaciones anteriores a esta escritura.
                    IniciarOperacion();
                    exit(true);
                end;
                if Motivos.ContainsKey(Codigo) then
                    Motivos.Set(Codigo, Explicacion)
                else
                    Motivos.Add(Codigo, Explicacion);
            end;
        end;
        exit(false);
    end;

    [TryFunction]
    local procedure IntentarProponerFilaLote(Buffer: Record "Diag. Orden Acum. Buffer"; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; ActualizarVigencia: Boolean; Movidos: List of [Code[20]]; var Disponible: Boolean; var Origen: Record "Concepto Liquidación"; var NuevoOrden: Integer; var FechaNueva: Date; var Explicacion: Text)
    begin
        // Sólo preparación: los errores de un candidato no cancelan los demás.
        Disponible := ProponerFilaEnOperacion(Buffer, FechaRef, TipoLiq, Convenio, Categoria, true, ActualizarVigencia, Movidos, Origen, NuevoOrden, FechaNueva, Explicacion);
    end;

    local procedure AgregarLinea(var Texto: Text; Linea: Text)
    var
        Salto: Char;
    begin
        if Texto <> '' then begin
            // Las barras dentro de un argumento %1 no se convierten en saltos al mostrarlo.
            Salto := 10;
            Texto += Format(Salto);
        end;
        Texto += Linea;
    end;

    local procedure ParticipaEnPendiente(Codigo: Code[20]; Aporta: Boolean; Referencias: List of [Code[20]]): Boolean
    var
        Actual: Record "Concepto Liquidación";
        Otro: Record "Concepto Liquidación";
        Referencia: Code[20];
        OrdenActual: Integer;
        OrdenOtro: Integer;
        OrdenesOtros: List of [Integer];
    begin
        ObtenerConceptoObligatorio(Codigo, Actual);
        if not ResolverOrdenContexto(Actual, OrdenActual) then
            exit(true);
        foreach Referencia in Referencias do
            if Referencia <> Codigo then begin
                ObtenerConceptoObligatorio(Referencia, Otro);
                if not ObtenerOrdenesReferencia(Otro, OrdenesOtros) then
                    exit(true);
                foreach OrdenOtro in OrdenesOtros do
                    if Aporta then begin
                        if not Antes(OrdenActual, Codigo, OrdenOtro, Referencia) then
                            exit(true);
                    end else
                        if not Antes(OrdenOtro, Referencia, OrdenActual, Codigo) then
                            exit(true);
            end;
        exit(false);
    end;

    procedure Preparar(CodAcum: Code[20]; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; CodConcepto: Code[20]; var Origen: Record "Concepto Liquidación"; var NuevoOrden: Integer; var FechaNueva: Date; var Explicacion: Text): Boolean
    begin
        exit(Preparar(CodAcum, FechaRef, TipoLiq, Convenio, Categoria, CodConcepto, false, Origen, NuevoOrden, FechaNueva, Explicacion));
    end;

    procedure Preparar(CodAcum: Code[20]; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; CodConcepto: Code[20]; ActualizarVigencia: Boolean; var Origen: Record "Concepto Liquidación"; var NuevoOrden: Integer; var FechaNueva: Date; var Explicacion: Text): Boolean
    begin
        IniciarOperacion();
        exit(PrepararEnOperacion(CodAcum, FechaRef, TipoLiq, Convenio, Categoria, CodConcepto, ActualizarVigencia, Origen, NuevoOrden, FechaNueva, Explicacion));
    end;

    local procedure PrepararEnOperacion(CodAcum: Code[20]; FechaRef: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; CodConcepto: Code[20]; ActualizarVigencia: Boolean; var Origen: Record "Concepto Liquidación"; var NuevoOrden: Integer; var FechaNueva: Date; var Explicacion: Text): Boolean
    var
        Aportes: List of [Code[20]];
        Dependencias: Dictionary of [Code[20], Boolean];
        Errores: Text;
        Aporta: Boolean;
        Lee: Boolean;
        Formula: Text;
        Impacto: Text;
    begin
        Clear(Origen);
        NuevoOrden := 0;
        FechaNueva := 0D;
        Explicacion := '';
        if FechaRef = 0D then
            FechaRef := WorkDate();
        CargarContexto(FechaRef, TipoLiq, Convenio);
        if not ObtenerConcepto(CodConcepto, Origen) then begin
            Explicacion := 'El concepto no tiene una versión vigente en la fecha elegida.';
            exit(false);
        end;
        // La propuesta conserva el rowversion real, no los campos de sistema de su copia temporal.
        Origen.Get(CodConcepto, Origen."Vigencia Desde");
        if Origen."Es Acumulador" then begin
            Explicacion := 'Un acumulador no tiene orden de ejecución propio.';
            exit(false);
        end;
        if ActualizarVigencia then
            FechaNueva := Origen."Vigencia Desde"
        else begin
            FechaNueva := FechaRef;
            if FechaNueva <= Origen."Vigencia Desde" then
                FechaNueva := Origen."Vigencia Desde" + 1;
        end;
        if not IntentarBuscarOrden(CodAcum, Origen, FechaNueva, TipoLiq, Convenio, ActualizarVigencia, NuevoOrden, Explicacion) then begin
            Explicacion := GetLastErrorText();
            NuevoOrden := 0;
            exit(false);
        end;
        if not IntentarValidarPropuesta(CodAcum, Origen, FechaNueva, NuevoOrden, TipoLiq, Convenio, Categoria, ActualizarVigencia, Formula, Impacto) then begin
            Explicacion := GetLastErrorText();
            NuevoOrden := 0;
            exit(false);
        end;
        Explicacion += ' ' + Impacto;
        if Categoria <> '' then
            Explicacion += ' El cambio de orden abarca todas las categorías del convenio.';
        exit(true);
    end;

    [TryFunction]
    local procedure IntentarObtenerAportes(CodAcum: Code[20]; var Aportes: List of [Code[20]])
    begin
        ObtenerAportes(CodAcum, Aportes);
    end;

    [TryFunction]
    local procedure IntentarObtenerLectores(CodAcum: Code[20]; var Lectores: List of [Code[20]])
    begin
        ObtenerLectores(CodAcum, Lectores);
    end;

    [TryFunction]
    local procedure IntentarValidarPropuesta(CodAcum: Code[20]; Origen: Record "Concepto Liquidación"; FechaNueva: Date; NuevoOrden: Integer; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; ActualizarVigencia: Boolean; var Formula: Text; var Impacto: Text)
    begin
        ValidarEnOperacion(CodAcum, Origen, FechaNueva, NuevoOrden, TipoLiq, Convenio, Categoria, ActualizarVigencia, Formula, Impacto);
    end;

    [TryFunction]
    local procedure IntentarBuscarOrden(CodAcum: Code[20]; Origen: Record "Concepto Liquidación"; FechaNueva: Date; TipoLiq: Code[20]; Convenio: Code[20]; ActualizarVigencia: Boolean; var NuevoOrden: Integer; var Explicacion: Text)
    var
        Fronteras: List of [Date];
        Objetivo: Record "Concepto Liquidación";
        Fecha: Date;
        Minimo: Integer;
        Maximo: Integer;
        Preferido: Integer;
        OrdenActual: Integer;
        NecesitaCambio: Boolean;
        Aporta: Boolean;
        LimiteInferior: Text;
        LimiteSuperior: Text;
        ObjetivoEsAcumulador: Boolean;
        Contextos: List of [Text];
        Contexto: Text;
        Motivo: Text;
        TipoAmbito: Code[20];
        ConvenioAmbito: Code[20];
        CategoriaAmbito: Code[20];
        PreferenciaElegida: Boolean;
    begin
        Minimo := 0;
        Maximo := 2147483647;
        RecopilarFronteras(Origen, FechaNueva, Fronteras);
        ObtenerObjetivoDelIntervalo(CodAcum, Fronteras, TipoLiq, Convenio, Objetivo);
        ObjetivoEsAcumulador := Objetivo."Es Acumulador";
        foreach Fecha in Fronteras do begin
            if not ControlDependencias.EnumerarContextosOrden(Fecha, TipoLiq, Convenio, '', Contextos, Motivo) then
                Error('No se pueden comprobar todos los ámbitos alcanzados: %1', Motivo);
            foreach Contexto in Contextos do begin
                ControlDependencias.DesglosarContextoOrden(Contexto, TipoAmbito, ConvenioAmbito, CategoriaAmbito);
                CargarContextoConcreto(Fecha, TipoAmbito, ConvenioAmbito, CategoriaAmbito);
                if AplicaAlAmbito(Origen) then begin
                    ExigirSinCiclos(Origen);
                    if ObtenerConcepto(CodAcum, Objetivo) then begin
                        ValidarTipoObjetivo(CodAcum, ObjetivoEsAcumulador);
                        if AplicaAlAmbito(Objetivo) then
                            ExigirSinCiclos(Objetivo);
                    end;
                    if TieneNecesidadEnContexto(CodAcum, Origen) then begin
                        NecesitaCambio := true;
                        if not PreferenciaElegida then begin
                            OrdenActual := ExigirOrden(Origen);
                            Aporta := EsAportanteObjetivo(CodAcum, Origen);
                            Preferido := PreferenciaOrden(CodAcum, Aporta);
                            PreferenciaElegida := true;
                        end;
                    end;
                    AcotarVentana(CodAcum, Origen, ObjetivoEsAcumulador, Minimo, Maximo, LimiteInferior, LimiteSuperior, Aporta);
                end;
            end;
        end;
        if not NecesitaCambio then
            Error('No se comprobó una precedencia incorrecta de %1 en un ámbito compatible de %2. Puede no necesitar cambio o faltar contexto para resolver sus ramas.', Origen.Código, CodAcum);
        if Minimo > Maximo then
            Error('No hay una ventana segura para %1: debe quedar en orden %2 o mayor por %3, y en orden %4 o menor por %5.', Origen.Código, Minimo, LimiteInferior, Maximo, LimiteSuperior);
        NuevoOrden := Preferido;
        if NuevoOrden < Minimo then
            NuevoOrden := Minimo;
        if NuevoOrden > Maximo then
            NuevoOrden := Maximo;
        if (NuevoOrden = OrdenActual) and not ActualizarVigencia then
            Error('Las dependencias sólo permiten conservar el orden actual %1 de %2; la corrección requiere revisar más de un concepto.', OrdenActual, Origen.Código);
        Explicacion := StrSubstNo('Ventana segura de %1: %2 a %3. Se propone %4.', Origen.Código, Minimo, Maximo, NuevoOrden);
    end;

    local procedure ObtenerObjetivoDelIntervalo(Codigo: Code[20]; Fronteras: List of [Date]; TipoLiq: Code[20]; Convenio: Code[20]; var Objetivo: Record "Concepto Liquidación")
    var
        Fecha: Date;
    begin
        foreach Fecha in Fronteras do begin
            CargarContexto(Fecha, TipoLiq, Convenio);
            if ObtenerConcepto(Codigo, Objetivo) then
                exit;
        end;
        Error('El objetivo %1 no está vigente dentro del intervalo que se quiere modificar.', Codigo);
    end;

    local procedure EsAportanteObjetivo(Codigo: Code[20]; Actual: Record "Concepto Liquidación"): Boolean
    var
        Aportes: List of [Code[20]];
    begin
        ObtenerAportes(Codigo, Aportes);
        exit(Aportes.Contains(Actual.Código));
    end;

    local procedure TieneNecesidadEnContexto(CodObjetivo: Code[20]; Actual: Record "Concepto Liquidación"): Boolean
    var
        Objetivo: Record "Concepto Liquidación";
        Otro: Record "Concepto Liquidación";
        Aportes: List of [Code[20]];
        Lectores: List of [Code[20]];
        Dependencias: Dictionary of [Code[20], Boolean];
        Inicializadas: Dictionary of [Code[20], Boolean];
        Referencias: List of [Code[20]];
        Codigo: Code[20];
        Errores: Text;
        RequiereContexto: Boolean;
        Aporta: Boolean;
        OrdenActual: Integer;
        OrdenOtro: Integer;
        ReferenciaComprobable: Boolean;
        OrdenesOtros: List of [Integer];
        TodasTardias: Boolean;
    begin
        if Actual."Par CCT a Usar" <> Actual."Par CCT a Usar"::Entidad then
            exit(false);
        if not ObtenerConcepto(CodObjetivo, Objetivo) then
            exit(false);
        if not AplicaAlAmbito(Objetivo) or not AplicaAlAmbito(Actual) then
            exit(false);
        if not ResolverOrdenContexto(Actual, OrdenActual) then
            exit(false);
        ObtenerAportes(CodObjetivo, Aportes);
        Aporta := Aportes.Contains(Actual.Código);
        if Aporta then begin
            if not ProduccionComprobada(Actual) then
                exit(false);
            ObtenerLectores(CodObjetivo, Lectores);
            Referencias := Lectores;
        end else begin
            // Una condición falsa o del empleado conserva lecturas MAY para seguridad,
            // pero no demuestra que este lector necesite publicar un resultado.
            if not ProduccionComprobada(Actual) then
                exit(false);
            DependenciasDe(Actual, Dependencias, Inicializadas, Errores, RequiereContexto);
            if (Errores <> '') or RequiereContexto or not EsLectorObjetivo(CodObjetivo, Actual, Dependencias) then
                exit(false);
            Referencias := Aportes;
        end;
        foreach Codigo in Referencias do
            if Codigo <> Actual.Código then begin
                ObtenerConceptoObligatorio(Codigo, Otro);
                // Un par alternativo puede coexistir, pero el contexto de cabecera
                // no demuestra que lo haga. Sigue en los límites MAY de seguridad.
                ReferenciaComprobable := Otro."Par CCT a Usar" = Otro."Par CCT a Usar"::Entidad;
                if ReferenciaComprobable then
                    ReferenciaComprobable := ProduccionComprobada(Otro);
                if Aporta then begin
                    DependenciasDe(Otro, Dependencias, Inicializadas, Errores, RequiereContexto);
                    if (Errores <> '') or RequiereContexto then
                        ReferenciaComprobable := false;
                end;
                if ReferenciaComprobable then
                    if ObtenerOrdenesReferencia(Otro, OrdenesOtros) then begin
                        // Una referencia de orden desconocido sólo prueba necesidad si TODAS
                        // sus posiciones compatibles llegan tarde; una rama posible no basta.
                        TodasTardias := true;
                        foreach OrdenOtro in OrdenesOtros do
                            if Aporta then begin
                                if Antes(OrdenActual, Actual.Código, OrdenOtro, Codigo) then
                                    TodasTardias := false;
                            end else
                                if Antes(OrdenOtro, Codigo, OrdenActual, Actual.Código) then
                                    TodasTardias := false;
                        if TodasTardias then
                            exit(true);
                    end;
            end;
        exit(false);
    end;

    local procedure ProduccionComprobada(Concepto: Record "Concepto Liquidación"): Boolean
    var
        RequiereContexto: Boolean;
    begin
        if not ContextoConcreto then
            exit(false);
        if not ControlDependencias.ConceptoProduceEnContexto(Concepto, FechaContexto, TipoContexto, ConvenioContexto, CategoriaContexto, RequiereContexto) then
            exit(false);
        exit(not RequiereContexto);
    end;

    local procedure PuedeProducirEnAmbito(Concepto: Record "Concepto Liquidación"): Boolean
    var
        RequiereContexto: Boolean;
    begin
        if not ContextoConcreto then
            exit(true);
        exit(ControlDependencias.ConceptoProduceEnContexto(Concepto, FechaContexto, TipoContexto, ConvenioContexto, CategoriaContexto, RequiereContexto));
    end;

    local procedure TieneEtapaCompatible(CodObjetivo: Code[20]; Fecha: Date; TipoLiq: Code[20]; Convenio: Code[20]; var Motivo: Text): Boolean
    var
        Contextos: List of [Text];
        Contexto: Text;
        TipoAmbito: Code[20];
        ConvenioAmbito: Code[20];
        CategoriaAmbito: Code[20];
        Objetivo: Record "Concepto Liquidación";
        Aportes: List of [Code[20]];
        Lectores: List of [Code[20]];
        Codigo: Code[20];
    begin
        if not ControlDependencias.EnumerarContextosOrden(Fecha, TipoLiq, Convenio, '', Contextos, Motivo) then
            Error('No se pueden comprobar las etapas compatibles: %1', Motivo);
        foreach Contexto in Contextos do begin
            ControlDependencias.DesglosarContextoOrden(Contexto, TipoAmbito, ConvenioAmbito, CategoriaAmbito);
            CargarContextoConcreto(Fecha, TipoAmbito, ConvenioAmbito, CategoriaAmbito);
            if ObtenerConcepto(CodObjetivo, Objetivo) then
                if AplicaAlAmbito(Objetivo) then begin
                    ObtenerAportes(CodObjetivo, Aportes);
                    ObtenerLectores(CodObjetivo, Lectores);
                    foreach Codigo in Lectores do
                        if Aportes.Contains(Codigo) then begin
                            Motivo := StrSubstNo('Lectura por etapas compatible: %1 lee y aporta a %2, tipo %3, convenio %4. Requiere revisión individual de su subtotal.', Codigo, CodObjetivo, TipoAmbito, ConvenioAmbito);
                            exit(true);
                        end;
                end;
        end;
        exit(false);
    end;

    local procedure PreferenciaOrden(CodAcum: Code[20]; Aporta: Boolean): Integer
    var
        Referencias: List of [Code[20]];
        Codigo: Code[20];
        Otro: Record "Concepto Liquidación";
        Extremo: Integer;
        Orden: Integer;
        Ordenes: List of [Integer];
    begin
        if Aporta then begin
            Extremo := 2147483647;
            ObtenerLectores(CodAcum, Referencias);
        end else
            ObtenerAportes(CodAcum, Referencias);
        foreach Codigo in Referencias do begin
            ObtenerConceptoObligatorio(Codigo, Otro);
            ExigirOrdenesReferencia(Otro, Ordenes);
            foreach Orden in Ordenes do
                if Aporta then begin
                    if Orden < Extremo then
                        Extremo := Orden;
                end else
                    if Orden > Extremo then
                        Extremo := Orden;
        end;
        // Preferir un entero separado; la ventana permite el empate si el código lo habilita.
        if Aporta then begin
            if Extremo = 0 then
                exit(0);
            exit(Extremo - 1);
        end;
        if Extremo = 2147483647 then
            exit(Extremo);
        exit(Extremo + 1);
    end;

    local procedure AcotarVentana(CodAcum: Code[20]; Actual: Record "Concepto Liquidación"; ObjetivoEsAcumulador: Boolean; var Minimo: Integer; var Maximo: Integer; var LimiteInferior: Text; var LimiteSuperior: Text; var Aporta: Boolean)
    var
        Otro: Record "Concepto Liquidación";
        Lector: Record "Concepto Liquidación" temporary;
        Dependencias: Dictionary of [Code[20], Boolean];
        Inicializadas: Dictionary of [Code[20], Boolean];
        Referencias: Dictionary of [Code[20], Boolean];
        ReferenciasInicializadas: Dictionary of [Code[20], Boolean];
        Aportes: List of [Code[20]];
        Lectores: List of [Code[20]];
        Acumuladores: List of [Code[20]];
        Codigo: Code[20];
        CodigoAporte: Code[20];
        Errores: Text;
        OrdenActual: Integer;
        OrdenOtro: Integer;
        OrdenesOtros: List of [Integer];
        Lee: Boolean;
        LeeConcepto: Boolean;
        LeeInicializada: Boolean;
        LeeOtraBase: Boolean;
        Motivo: Text;
        ObjetivoFormula: Boolean;
        CruceAutorizado: Boolean;
        Objetivo: Record "Concepto Liquidación";
        RevisarObjetivo: Boolean;
    begin
        ObjetivoFormula := not ObjetivoEsAcumulador;
        OrdenActual := ExigirOrden(Actual);
        RevisarObjetivo := ObtenerConcepto(CodAcum, Objetivo);
        if RevisarObjetivo then
            RevisarObjetivo := AplicaAlAmbito(Objetivo);
        if RevisarObjetivo then
            ObtenerAportes(CodAcum, Aportes);
        DependenciasDe(Actual, Dependencias, Inicializadas, Errores);
        if Errores <> '' then
            Error('No se pueden comprobar las entradas de %1: %2.', Actual.Código, Errores);
        Aporta := Aportes.Contains(Actual.Código);
        Lee := false;
        if RevisarObjetivo then
            Lee := EsLectorObjetivo(CodAcum, Actual, Dependencias);
        if Aportes.Count() = 0 then
            Lee := false;
        if Aporta then begin
            ObtenerLectores(CodAcum, Lectores);
            Aporta := Lectores.Count() > 0;
        end;
        // El objetivo puede no tener una contraparte compatible en este ámbito.
        // Allí se conservan las precedencias comunes, sin inventar una lectura.
        if not Aporta and not Lee then
            RevisarObjetivo := false;
        if not ObjetivoFormula and Aporta and Lee then
            Error('%1 lee y aporta a %2: es una lectura por etapas, sin movimiento automático.', Actual.Código, CodAcum);
        if Aporta then begin
            foreach Codigo in Lectores do begin
                ObtenerConceptoObligatorio(Codigo, Otro);
                ExigirOrdenesReferencia(Otro, OrdenesOtros);
                Motivo := StrSubstNo('lectura %1 de %2 desde %3', Codigo, CodAcum, FechaContexto);
                LimitarAntes(Actual.Código, Otro, Motivo, Maximo, LimiteSuperior);
                if ObjetivoEsAcumulador and Aportes.Contains(Codigo) then
                    ConservarLado(Actual, Otro, 'etapa ' + Motivo, Minimo, Maximo, LimiteInferior, LimiteSuperior);
            end;
        end else
            if Lee then begin
            if Aportes.Count() = 0 then
                Error('No hay aportes de %1 desde %2.', CodAcum, FechaContexto);
            foreach Codigo in Aportes do begin
                ObtenerConceptoObligatorio(Codigo, Otro);
                ExigirOrdenesReferencia(Otro, OrdenesOtros);
                Motivo := StrSubstNo('aporte %1 a %2 desde %3', Codigo, CodAcum, FechaContexto);
                LimitarDespues(Actual.Código, Otro, Motivo, Minimo, LimiteInferior);
            end;
        end;
        foreach Codigo in Dependencias.Keys() do begin
            ObtenerConceptoObligatorio(Codigo, Otro);
            if Otro."Es Acumulador" then begin
                if (Codigo <> CodAcum) or not Lee then begin
                    ObtenerAportes(Codigo, Aportes);
                    foreach CodigoAporte in Aportes do
                        if CodigoAporte <> Actual.Código then begin
                            ObtenerConceptoObligatorio(CodigoAporte, Otro);
                            Motivo := StrSubstNo('entrada %1, aporte %2 desde %3', Codigo, CodigoAporte, FechaContexto);
                            LimitarDespues(Actual.Código, Otro, Motivo, Minimo, LimiteInferior);
                            ConservarLado(Actual, Otro, Motivo, Minimo, Maximo, LimiteInferior, LimiteSuperior);
                        end;
                end;
            end else
                if AplicaAlAmbito(Otro) then begin
                    Motivo := StrSubstNo('entrada #%1 desde %2', Codigo, FechaContexto);
                    LimitarDespues(Actual.Código, Otro, Motivo, Minimo, LimiteInferior);
                    if not (ObjetivoFormula and Lee and (Actual.Código = CodAcum)) then
                        ConservarLado(Actual, Otro, Motivo, Minimo, Maximo, LimiteInferior, LimiteSuperior);
                end;
        end;
        // Una clave precargada y publicada después por un concepto tiene dos fases.
        // Su nombre desnudo no exige que el escritor corra antes, pero no puede cruzarse.
        foreach Codigo in Inicializadas.Keys() do
            if Codigo <> Actual.Código then begin
                ObtenerConceptoObligatorio(Codigo, Otro);
                if AplicaAlAmbito(Otro) then begin
                    Motivo := StrSubstNo('fase de entrada %1 desde %2', Codigo, FechaContexto);
                    ConservarLado(Actual, Otro, Motivo, Minimo, Maximo, LimiteInferior, LimiteSuperior);
                end;
            end;
        ObtenerAcumuladores(Actual.Código, Acumuladores);
        Lector.Copy(Todos, true);
        if Lector.FindSet() then
            repeat
                if (Lector.Código <> Actual.Código) and not Lector."Es Acumulador" then
                    if AplicaAlAmbito(Lector) then begin
                        DependenciasDe(Lector, Referencias, ReferenciasInicializadas, Errores);
                        LeeConcepto := Referencias.ContainsKey(Actual.Código);
                        LeeInicializada := ReferenciasInicializadas.ContainsKey(Actual.Código);
                        LeeOtraBase := false;
                        foreach Codigo in Acumuladores do
                            if (Codigo <> CodAcum) or not RevisarObjetivo then
                                if Referencias.ContainsKey(Codigo) then
                                    LeeOtraBase := true;
                        if LeeConcepto or LeeInicializada or LeeOtraBase then begin
                            if Errores <> '' then
                                Error('No se puede comprobar el consumidor %1: %2.', Lector.Código, Errores);
                            Motivo := StrSubstNo('consumidor %1 desde %2', Lector.Código, FechaContexto);
                            CruceAutorizado := RevisarObjetivo and ObjetivoFormula and (Lector.Código = CodAcum) and LeeConcepto and not LeeOtraBase and not LeeInicializada;
                            if not CruceAutorizado then
                                ConservarLado(Actual, Lector, Motivo, Minimo, Maximo, LimiteInferior, LimiteSuperior);
                            if LeeConcepto then
                                LimitarAntes(Actual.Código, Lector, Motivo, Maximo, LimiteSuperior);
                        end;
                    end;
            until Lector.Next() = 0;
    end;

    local procedure ConservarLado(Actual: Record "Concepto Liquidación"; Otro: Record "Concepto Liquidación"; Motivo: Text; var Minimo: Integer; var Maximo: Integer; var LimiteInferior: Text; var LimiteSuperior: Text)
    var
        OrdenActual: Integer;
        OrdenOtro: Integer;
        OrdenesOtros: List of [Integer];
    begin
        OrdenActual := ExigirOrden(Actual);
        ExigirOrdenesReferencia(Otro, OrdenesOtros);
        foreach OrdenOtro in OrdenesOtros do
            if Antes(OrdenActual, Actual.Código, OrdenOtro, Otro.Código) then
                LimitarAntesDeOrden(Actual.Código, OrdenOtro, Otro.Código, Motivo, Maximo, LimiteSuperior)
            else
                LimitarDespuesDeOrden(Actual.Código, OrdenOtro, Otro.Código, Motivo, Minimo, LimiteInferior);
    end;

    local procedure LimitarAntes(Codigo: Code[20]; Otro: Record "Concepto Liquidación"; Motivo: Text; var Maximo: Integer; var LimiteSuperior: Text)
    var
        Orden: Integer;
        Ordenes: List of [Integer];
    begin
        ExigirOrdenesReferencia(Otro, Ordenes);
        foreach Orden in Ordenes do
            LimitarAntesDeOrden(Codigo, Orden, Otro.Código, Motivo, Maximo, LimiteSuperior);
    end;

    local procedure LimitarAntesDeOrden(Codigo: Code[20]; OrdenOtro: Integer; CodigoOtro: Code[20]; Motivo: Text; var Maximo: Integer; var LimiteSuperior: Text)
    var
        Limite: Integer;
    begin
        Limite := OrdenOtro;
        if Codigo >= CodigoOtro then
            Limite -= 1;
        if Limite < Maximo then begin
            Maximo := Limite;
            LimiteSuperior := Motivo;
        end;
    end;

    local procedure LimitarDespues(Codigo: Code[20]; Otro: Record "Concepto Liquidación"; Motivo: Text; var Minimo: Integer; var LimiteInferior: Text)
    var
        Orden: Integer;
        Ordenes: List of [Integer];
    begin
        ExigirOrdenesReferencia(Otro, Ordenes);
        foreach Orden in Ordenes do
            LimitarDespuesDeOrden(Codigo, Orden, Otro.Código, Motivo, Minimo, LimiteInferior);
    end;

    local procedure LimitarDespuesDeOrden(Codigo: Code[20]; OrdenOtro: Integer; CodigoOtro: Code[20]; Motivo: Text; var Minimo: Integer; var LimiteInferior: Text)
    var
        Limite: Integer;
    begin
        Limite := OrdenOtro;
        if Codigo <= CodigoOtro then begin
            if Limite = 2147483647 then
                Error('No hay un orden entero posterior a %1: %2.', CodigoOtro, Motivo);
            Limite += 1;
        end;
        if Limite > Minimo then begin
            Minimo := Limite;
            LimiteInferior := Motivo;
        end;
    end;

    /// <summary>Comprueba la propuesta sin escribir. Sólo el acumulador elegido puede cambiar de subtotal.</summary>
    procedure Validar(CodAcum: Code[20]; Origen: Record "Concepto Liquidación"; FechaNueva: Date; NuevoOrden: Integer; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; var NuevaFormula: Text; var Impacto: Text)
    begin
        Validar(CodAcum, Origen, FechaNueva, NuevoOrden, TipoLiq, Convenio, Categoria, false, NuevaFormula, Impacto);
    end;

    procedure Validar(CodAcum: Code[20]; Origen: Record "Concepto Liquidación"; FechaNueva: Date; NuevoOrden: Integer; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; ActualizarVigencia: Boolean; var NuevaFormula: Text; var Impacto: Text)
    begin
        // Cada revisión pública y la aplicación bajo locks parten de datos físicos actuales.
        IniciarOperacion();
        ValidarEnOperacion(CodAcum, Origen, FechaNueva, NuevoOrden, TipoLiq, Convenio, Categoria, ActualizarVigencia, NuevaFormula, Impacto);
    end;

    local procedure ValidarEnOperacion(CodAcum: Code[20]; Origen: Record "Concepto Liquidación"; FechaNueva: Date; NuevoOrden: Integer; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; ActualizarVigencia: Boolean; var NuevaFormula: Text; var Impacto: Text)
    var
        Actual: Record "Concepto Liquidación";
        Uso: Record "Línea Liquidación";
        Objetivo: Record "Concepto Liquidación";
        Fronteras: List of [Date];
        Fecha: Date;
        FormulaComprobada: Text;
        ImpactoComprobado: Text;
        Motivo: Text;
        CambioEnFecha: Boolean;
        CambioEfectivo: Boolean;
        NecesidadComprobada: Boolean;
        Contextos: List of [Text];
        Contexto: Text;
        TipoAmbito: Code[20];
        ConvenioAmbito: Code[20];
        CategoriaAmbito: Code[20];
    begin
        NuevaFormula := '';
        Impacto := '';
        ValidarOrigen(Origen, FechaNueva, ActualizarVigencia, Actual);
        TipoFormulaOperacion := TipoLiq;
        ConvenioFormulaOperacion := Convenio;
        RecopilarFronteras(Actual, FechaNueva, Fronteras);
        ObtenerObjetivoDelIntervalo(CodAcum, Fronteras, TipoLiq, Convenio, Objetivo);
        foreach Fecha in Fronteras do begin
            if not ControlDependencias.EnumerarContextosOrden(Fecha, TipoLiq, Convenio, '', Contextos, Motivo) then
                Error('No se pueden comprobar todos los ámbitos alcanzados: %1', Motivo);
            foreach Contexto in Contextos do begin
                ControlDependencias.DesglosarContextoOrden(Contexto, TipoAmbito, ConvenioAmbito, CategoriaAmbito);
                CargarContextoConcreto(Fecha, TipoAmbito, ConvenioAmbito, CategoriaAmbito);
                if AplicaAlAmbito(Actual) then begin
                    NecesidadComprobada := NecesidadComprobada or TieneNecesidadEnContexto(CodAcum, Actual);
                    if not IntentarValidarEnFecha(CodAcum, Actual, Fecha, NuevoOrden, TipoAmbito, ConvenioAmbito, CategoriaAmbito, ActualizarVigencia, Objetivo."Es Acumulador", FormulaComprobada, ImpactoComprobado, CambioEnFecha) then begin
                        Motivo := GetLastErrorText();
                        Error('La corrección no es verificable desde %1, tipo %2, convenio %3, categoría %4: %5', Fecha, TipoAmbito, ConvenioAmbito, CategoriaAmbito, Motivo);
                    end;
                    CambioEfectivo := CambioEfectivo or CambioEnFecha;
                    if NuevaFormula = '' then begin
                        NuevaFormula := FormulaComprobada;
                        Impacto := ImpactoComprobado;
                    end;
                end;
            end;
        end;
        if not NecesidadComprobada then
            Error('No hay una precedencia incorrecta comprobada en ámbitos compatibles del objetivo %1. No se guardará un cambio innecesario.', CodAcum);
        if ActualizarVigencia then begin
            if not CambioEfectivo then
                Error('El orden propuesto es igual al actual en todo el intervalo de esta vigencia. No hace falta actualizarla.');
            Impacto := StrSubstNo('Se actualizará el orden de %1 en la misma vigencia, desde %2', Actual.Código, Actual."Vigencia Desde");
            if Actual."Vigencia Hasta" <> 0D then
                Impacto += StrSubstNo(' hasta %1.', Actual."Vigencia Hasta")
            else
                Impacto += ' hasta el fin de su vigencia abierta.';
            if Objetivo."Es Acumulador" then
                Impacto += StrSubstNo(' Sólo se autoriza cambiar el subtotal de %1.', CodAcum)
            else
                Impacto += StrSubstNo(' Sólo se autorizan las precedencias de las entradas calculadas del lector %1; se conservan las otras precedencias de entradas y consumidores y las etapas de los acumuladores.', CodAcum);
            Impacto += ' Se conservan las fechas, la fórmula de importe y los recibos guardados; sus próximos recálculos, incluidos períodos anteriores, usarán el orden nuevo.';
            Uso.SetCurrentKey("Cód. Concepto", "Vigencia Concepto", "Fecha Liquidación");
            Uso.SetRange("Cód. Concepto", Actual.Código);
            Uso.SetRange("Vigencia Concepto", Actual."Vigencia Desde");
            Uso.SetFilter(Estado, '<>%1', Uso.Estado::Borrador);
            if not Uso.IsEmpty() then
                Impacto += ' Esta vigencia ya fue utilizada por liquidaciones calculadas o posteriores; sus importes actuales no se modificarán.';
            if Categoria <> '' then
                Impacto += ' El alcance incluye todas las categorías del convenio.';
        end;
        Impacto += StrSubstNo(' Se comprobaron %1 fechas de configuración ya programadas.', Fronteras.Count());
    end;

    [TryFunction]
    local procedure IntentarValidarEnFecha(CodAcum: Code[20]; Origen: Record "Concepto Liquidación"; Fecha: Date; NuevoOrden: Integer; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; ActualizarVigencia: Boolean; ObjetivoEsAcumulador: Boolean; var NuevaFormula: Text; var Impacto: Text; var CambioEnFecha: Boolean)
    begin
        // Sólo lecturas y copias temporales: ninguna escritura de configuración dentro del Try.
        ValidarEnFecha(CodAcum, Origen, Fecha, NuevoOrden, TipoLiq, Convenio, Categoria, ActualizarVigencia, ObjetivoEsAcumulador, NuevaFormula, Impacto, CambioEnFecha);
    end;

    local procedure ValidarEnFecha(CodAcum: Code[20]; Origen: Record "Concepto Liquidación"; FechaNueva: Date; NuevoOrden: Integer; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; ActualizarVigencia: Boolean; ObjetivoEsAcumulador: Boolean; var NuevaFormula: Text; var Impacto: Text; var CambioEnFecha: Boolean)
    var
        Actual: Record "Concepto Liquidación";
        Acumulador: Record "Concepto Liquidación";
        Comprobacion: Record "Concepto Liquidación";
        Aportes: List of [Code[20]];
        Lectores: List of [Code[20]];
        Dependencias: Dictionary of [Code[20], Boolean];
        Codigo: Code[20];
        Errores: Text;
        OrdenAnterior: Integer;
        OrdenOtro: Integer;
        OrdenesOtros: List of [Integer];
        Aporta: Boolean;
        Lee: Boolean;
        RevisarObjetivo: Boolean;
    begin
        NuevaFormula := '';
        Impacto := '';
        CambioEnFecha := false;
        Actual := Origen;
        if NuevoOrden < 0 then
            Error('El orden debe ser un entero mayor o igual a cero.');
        if Actual."Es Acumulador" then
            Error('Un acumulador no se ejecuta como concepto; seleccioná un aporte o una lectura.');
        if Actual."Fuente Matriz" <> '' then
            Error('No se puede verificar este movimiento: el concepto %1 usa una matriz.', Actual.Código);
        if Actual."Par CCT a Usar" <> Actual."Par CCT a Usar"::Entidad then
            Error('El concepto %1 usa el par de un puesto o asignación. Falta una liquidación concreta para verificarlo.', Actual.Código);
        CargarContextoConcreto(FechaNueva, TipoLiq, Convenio, Categoria);
        RevisarObjetivo := ObtenerConcepto(CodAcum, Acumulador);
        if RevisarObjetivo then begin
            ValidarTipoObjetivo(CodAcum, ObjetivoEsAcumulador);
            RevisarObjetivo := AplicaAlAmbito(Acumulador);
        end;
        ExigirSinCiclos(Actual);
        if RevisarObjetivo then
            ExigirSinCiclos(Acumulador);
        if not AplicaAlAmbito(Actual) then
            Error('El concepto %1 no aplica al tipo o convenio seleccionado.', Actual.Código);
        OrdenAnterior := ExigirOrden(Actual);
        CambioEnFecha := NuevoOrden <> OrdenAnterior;
        if not CambioEnFecha and not ActualizarVigencia then
            Error('El orden propuesto es igual al actual. No hace falta crear una vigencia.');
        if RevisarObjetivo then
            ObtenerAportes(CodAcum, Aportes);
        DependenciasDe(Actual, Dependencias, Errores);
        if Errores <> '' then
            Error('No se pueden comprobar las dependencias de %1: %2', Actual.Código, Errores);
        Aporta := Aportes.Contains(Actual.Código);
        if RevisarObjetivo then
            Lee := EsLectorObjetivo(CodAcum, Actual, Dependencias);
        if Aportes.Count() = 0 then
            Lee := false;
        if Aporta then begin
            ObtenerLectores(CodAcum, Lectores);
            Aporta := Lectores.Count() > 0;
        end;
        if not Aporta and not Lee then
            RevisarObjetivo := false;
        if ActualizarVigencia and Aporta and Lee then
            Error('%1 lee y aporta a %2: es una lectura por etapas. No se puede actualizar su orden automáticamente.', Actual.Código, CodAcum);
        if ActualizarVigencia and not CambioEnFecha then begin
            // Un tramo que conserva la misma precedencia no necesita un movimiento;
            // la operación completa debe cambiar al menos otro tramo de la vigencia.
            ValidarFormulaOrden(Actual, FechaNueva, NuevoOrden, TipoLiq, Convenio, NuevaFormula);
            Impacto := StrSubstNo('%1 conserva el orden %2 desde %3.', Actual.Código, NuevoOrden, FechaNueva);
            exit;
        end;
        if Aporta then begin
            foreach Codigo in Lectores do
                if Codigo <> Actual.Código then begin
                    ObtenerConceptoObligatorio(Codigo, Comprobacion);
                    ExigirOrdenesReferencia(Comprobacion, OrdenesOtros);
                    foreach OrdenOtro in OrdenesOtros do begin
                        if not Antes(NuevoOrden, Actual.Código, OrdenOtro, Codigo) then
                            Error('El aporte %1 debe quedar antes de la lectura %2 (orden posible %3).', Actual.Código, Codigo, OrdenOtro);
                        if ObjetivoEsAcumulador and Aportes.Contains(Codigo) then
                            if Cruza(OrdenAnterior, NuevoOrden, Actual.Código, OrdenOtro, Codigo) then
                                Error('El movimiento cruza la lectura por etapas %1 de %2 y cambiaría ese subtotal.', Codigo, CodAcum);
                    end;
                end;
        end else
            if Lee then begin
            // Sólo se puede atrasar una lectura que no alimente a su vez esta misma base.
            if not Lee then
                Error('El concepto seleccionado no es una lectura verificable.');
            if Aportes.Count() = 0 then
                Error('No hay aportes de %1 para justificar el movimiento de su lectura.', CodAcum);
            foreach Codigo in Aportes do begin
                ObtenerConceptoObligatorio(Codigo, Comprobacion);
                ExigirOrdenesReferencia(Comprobacion, OrdenesOtros);
                foreach OrdenOtro in OrdenesOtros do
                    if not Antes(OrdenOtro, Codigo, NuevoOrden, Actual.Código) then
                        Error('La lectura %1 debe quedar después del aporte %2 (orden posible %3).', Actual.Código, Codigo, OrdenOtro);
            end;
        end;
        ValidarEntradas(Actual, Dependencias, CodAcum, not ObjetivoEsAcumulador, RevisarObjetivo, Lee and not Aporta, OrdenAnterior, NuevoOrden);
        ValidarConsumidores(Actual, CodAcum, not ObjetivoEsAcumulador, RevisarObjetivo, OrdenAnterior, NuevoOrden);
        ValidarFormulaOrden(Actual, FechaNueva, NuevoOrden, TipoLiq, Convenio, NuevaFormula);
        Impacto := StrSubstNo('%1 pasa del orden %2 al %3 desde %4.', Actual.Código, OrdenAnterior, NuevoOrden, FechaNueva);
        if ObjetivoEsAcumulador then
            Impacto += StrSubstNo(' Sólo se autoriza cambiar el subtotal de %1.', CodAcum)
        else
            Impacto += StrSubstNo(' Sólo se autorizan las entradas calculadas del lector %1; se conservan las otras precedencias de entradas y consumidores y las etapas de los acumuladores.', CodAcum);
        Impacto += ' No se recalculan liquidaciones.';
        if Categoria <> '' then
            Impacto += ' El alcance incluye todas las categorías del convenio.';
    end;

    local procedure ValidarFormulaOrden(Actual: Record "Concepto Liquidación"; Fecha: Date; NuevoOrden: Integer; TipoLiq: Code[20]; Convenio: Code[20]; var NuevaFormula: Text)
    var
        Comprobacion: Record "Concepto Liquidación";
        Control: Codeunit "Control Orden Acumuladores";
        OrdenComprobado: Integer;
    begin
        NuevaFormula := FormulaNueva(Actual, NuevoOrden, TipoFormulaOperacion, ConvenioFormulaOperacion);
        Comprobacion := Actual;
        Comprobacion.Validate("Fórmula Orden Cálculo", NuevaFormula);
        if not ControlDependencias.ResolverOrdenEnContexto(Comprobacion, Fecha, TipoLiq, Convenio, OrdenComprobado) then
            Error('La fórmula de orden propuesta necesita un contexto que no está disponible.');
        if OrdenComprobado <> NuevoOrden then
            Error('La fórmula propuesta no produce el orden %1 en el ámbito seleccionado.', NuevoOrden);
    end;

    procedure Aplicar(CodAcum: Code[20]; Origen: Record "Concepto Liquidación"; FechaNueva: Date; NuevoOrden: Integer; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20])
    begin
        Aplicar(CodAcum, Origen, FechaNueva, NuevoOrden, TipoLiq, Convenio, Categoria, false);
    end;

    procedure Aplicar(CodAcum: Code[20]; Origen: Record "Concepto Liquidación"; FechaNueva: Date; NuevoOrden: Integer; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; ActualizarVigencia: Boolean)
    var
        Actual: Record "Concepto Liquidación";
        Fraccion: Record "Fracción Acumulador";
        Restriccion: Record "Concepto CCT Vigente";
    begin
        Actual.LockTable();
        Fraccion.LockTable();
        Restriccion.LockTable();
        IniciarOperacion();
        AplicarEnOperacion(CodAcum, Origen, FechaNueva, NuevoOrden, TipoLiq, Convenio, Categoria, ActualizarVigencia);
    end;

    local procedure AplicarEnOperacion(CodAcum: Code[20]; Origen: Record "Concepto Liquidación"; FechaNueva: Date; NuevoOrden: Integer; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; ActualizarVigencia: Boolean)
    var
        Actual: Record "Concepto Liquidación";
        AntesCambio: Record "Concepto Liquidación";
        Nueva: Record "Concepto Liquidación";
        Historial: Codeunit "Historial Fórmulas Liq.";
        NuevaFormula: Text;
        Impacto: Text;
    begin
        if not Actual.Get(Origen.Código, Origen."Vigencia Desde") then
            Error('La versión seleccionada ya no existe. Volvé a abrir la propuesta.');
        if Actual.SystemRowVersion <> Origen.SystemRowVersion then
            Error('El concepto cambió mientras se preparaba la propuesta. Volvé a verificarlo.');
        ValidarEnOperacion(CodAcum, Actual, FechaNueva, NuevoOrden, TipoLiq, Convenio, Categoria, ActualizarVigencia, NuevaFormula, Impacto);
        AntesCambio := Actual;
        if ActualizarVigencia then begin
            // Sólo el orden de la PK existente. No se cierran ni se insertan vigencias;
            // la autorización permite usos previos, sin tocar sus recibos guardados.
            Actual.Validate("Fórmula Orden Cálculo", NuevaFormula);
            Actual.Modify(true);
            Historial.RegistrarCambioOrden(AntesCambio, Actual);
            exit;
        end;
        Nueva := AntesCambio;
        Nueva."Vigencia Desde" := FechaNueva;
        // Conservar una baja finita; la corrección no reactiva conceptos dados de baja.
        Nueva."Vigencia Hasta" := AntesCambio."Vigencia Hasta";
        Nueva.Validate("Fórmula Orden Cálculo", NuevaFormula);
        // Insert(true) encadena versiones, pero por sí solo no verifica usos posteriores.
        Actual.Validate("Vigencia Hasta", FechaNueva - 1);
        Actual.Modify(true);
        Nueva.Insert(true);
        Historial.RegistrarCambioOrden(AntesCambio, Nueva);
    end;

    procedure FormulaNueva(Origen: Record "Concepto Liquidación"; NuevoOrden: Integer; TipoLiq: Code[20]; Convenio: Code[20]): Text
    var
        Motor: Codeunit "Motor Liquidación";
        Anterior: Text;
        Condicion: Text;
        Resultado: Text;
        TipoTexto: Text;
        ConvenioTexto: Text;
        Numero: Integer;
        Literal: Boolean;
    begin
        if NuevoOrden < 0 then
            Error('El orden debe ser mayor o igual a cero.');
        Anterior := Motor.FormulaOrdenConfigurada(Origen).Trim();
        Literal := false;
        if (Anterior <> '') and (DelChr(Anterior, '=', '0123456789') = '') then
            Literal := Evaluate(Numero, Anterior, 9);
        if not Literal and ((TipoLiq = '') or (Convenio = '')) then
            Error('Para conservar una fórmula de orden condicional, seleccioná tipo de liquidación y convenio.');
        TipoTexto := TipoLiq;
        ConvenioTexto := Convenio;
        if TipoLiq <> '' then
            Condicion := 'TIPO_LIQ = ''' + TipoTexto.Replace('''', '''''') + '''';
        if Convenio <> '' then begin
            if Condicion <> '' then
                Condicion += ' AND ';
            Condicion += 'CONVENIO = ''' + ConvenioTexto.Replace('''', '''''') + '''';
        end;
        Resultado := Format(NuevoOrden, 0, 9);
        if Condicion <> '' then
            Resultado := 'IF(' + Condicion + ', ' + Resultado + ', ' + Anterior + ')';
        if StrLen(Resultado) > MaxStrLen(Origen."Fórmula Orden Cálculo") then
            Error('La fórmula de orden resultante supera los %1 caracteres; revisala en la ficha del concepto.', MaxStrLen(Origen."Fórmula Orden Cálculo"));
        exit(Resultado);
    end;

    local procedure ValidarOrigen(Origen: Record "Concepto Liquidación"; FechaNueva: Date; ActualizarVigencia: Boolean; var Actual: Record "Concepto Liquidación")
    var
        Ganadora: Record "Concepto Liquidación";
        Uso: Record "Línea Liquidación";
    begin
        if not Actual.Get(Origen.Código, Origen."Vigencia Desde") then
            Error('La versión de origen ya no existe.');
        if Actual.SystemRowVersion <> Origen.SystemRowVersion then
            Error('La versión de origen cambió. Volvé a preparar la propuesta.');
        if ActualizarVigencia then begin
            if (FechaNueva = 0D) or (FechaNueva <> Actual."Vigencia Desde") then
                Error('Actualizar la vigencia conserva su fecha inicial %1. No se puede cambiar esa fecha en este modo.', Actual."Vigencia Desde");
        end else
            if (FechaNueva = 0D) or (FechaNueva <= Actual."Vigencia Desde") then
                Error('La nueva vigencia debe comenzar después del %1.', Actual."Vigencia Desde");
        if (Actual."Vigencia Hasta" <> 0D) and (FechaNueva > Actual."Vigencia Hasta") then
            Error('La nueva fecha queda fuera del intervalo de la versión seleccionada.');
        if not ActualizarVigencia then
            if Ganadora.Get(Actual.Código, FechaNueva) then
                Error('Ya existe una versión de %1 desde %2.', Actual.Código, FechaNueva);
        Ganadora.SetRange(Código, Actual.Código);
        Ganadora.SetFilter("Vigencia Desde", '<=%1', FechaNueva);
        if not Ganadora.FindLast() then
            Error('No hay una versión de origen para la fecha nueva.');
        if Ganadora."Vigencia Desde" <> Actual."Vigencia Desde" then
            Error('Hay otra versión anterior a la fecha nueva. No se puede saltar una vigencia.');
        if not Ganadora.VigenteA(FechaNueva) then
            Error('El concepto no está vigente en la fecha nueva.');
        // En este modo no se cierra la versión ni se cambia una fecha usada por un recibo.
        // La actualización del orden, aun con usos, fue autorizada explícitamente.
        if ActualizarVigencia then
            exit;
        Uso.SetCurrentKey("Cód. Concepto", "Vigencia Concepto", "Fecha Liquidación");
        Uso.SetRange("Cód. Concepto", Actual.Código);
        Uso.SetRange("Vigencia Concepto", Actual."Vigencia Desde");
        Uso.SetFilter("Fecha Liquidación", '>=%1', FechaNueva);
        Uso.SetFilter(Estado, '<>%1', Uso.Estado::Borrador);
        if Uso.FindFirst() then
            Error('No se puede cerrar esta versión: la liquidación %1 del %2 ya la usó después del corte propuesto.', Uso."No. Liquidación", Uso."Fecha Liquidación");
    end;

    local procedure RecopilarFronteras(Origen: Record "Concepto Liquidación"; FechaNueva: Date; var Fronteras: List of [Date])
    var
        Concepto: Record "Concepto Liquidación" temporary;
        Fraccion: Record "Fracción Acumulador" temporary;
        Restriccion: Record "Concepto CCT Vigente" temporary;
        Siguiente: Record "Concepto Liquidación" temporary;
        FechaFin: Date;
        Guardadas: List of [Date];
        Fecha: Date;
        Clave: Text;
    begin
        Clear(Fronteras);
        Clave := Origen.Código + '|' + Format(Origen."Vigencia Desde", 0, 9) + '|' + Format(FechaNueva, 0, 9);
        if FronterasCache.Get(Clave, Guardadas) then begin
            foreach Fecha in Guardadas do
                Fronteras.Add(Fecha);
            exit;
        end;
        CargarCatalogos();
        Concepto.Copy(CatalogoConceptos, true);
        Concepto.Reset();
        Fraccion.Copy(CatalogoFracciones, true);
        Fraccion.Reset();
        Restriccion.Copy(CatalogoRestricciones, true);
        Restriccion.Reset();
        Siguiente.Copy(CatalogoConceptos, true);
        Siguiente.Reset();
        Fronteras.Add(FechaNueva);
        FechaFin := Origen."Vigencia Hasta";
        Siguiente.SetRange(Código, Origen.Código);
        Siguiente.SetFilter("Vigencia Desde", '>%1', FechaNueva);
        if Siguiente.FindFirst() then
            if (FechaFin = 0D) or (Siguiente."Vigencia Desde" - 1 < FechaFin) then
                FechaFin := Siguiente."Vigencia Desde" - 1;
        // Cada frontera es finita y conocida. Cambios ajenos se comprueban, pero no se bloquean
        // por existir: sólo un cruce relevante o una dependencia no verificable produce Error.
        if Concepto.FindSet() then
            repeat
                AgregarFrontera(Concepto."Vigencia Desde", FechaNueva, FechaFin, Fronteras);
                if (Concepto."Vigencia Hasta" <> 0D) and (Concepto."Vigencia Hasta" < DMY2Date(31, 12, 9999)) then
                    AgregarFrontera(Concepto."Vigencia Hasta" + 1, FechaNueva, FechaFin, Fronteras);
            until Concepto.Next() = 0;
        Fraccion.SetFilter("Vigencia Desde", '>%1', FechaNueva);
        if Fraccion.FindSet() then
            repeat
                AgregarFrontera(Fraccion."Vigencia Desde", FechaNueva, FechaFin, Fronteras);
            until Fraccion.Next() = 0;
        Restriccion.SetFilter("Vigencia Desde", '>%1', FechaNueva);
        if Restriccion.FindSet() then
            repeat
                AgregarFrontera(Restriccion."Vigencia Desde", FechaNueva, FechaFin, Fronteras);
            until Restriccion.Next() = 0;
        foreach Fecha in Fronteras do
            Guardadas.Add(Fecha);
        FronterasCache.Add(Clave, Guardadas);
    end;

    local procedure AgregarFrontera(Fecha: Date; FechaNueva: Date; FechaFin: Date; var Fronteras: List of [Date])
    begin
        if Fecha <= FechaNueva then
            exit;
        if (FechaFin <> 0D) and (Fecha > FechaFin) then
            exit;
        if not Fronteras.Contains(Fecha) then
            Fronteras.Add(Fecha);
    end;

    local procedure ValidarEntradas(Concepto: Record "Concepto Liquidación"; var Dependencias: Dictionary of [Code[20], Boolean]; CodAcum: Code[20]; ObjetivoFormula: Boolean; RevisarObjetivo: Boolean; MueveLector: Boolean; OrdenAnterior: Integer; NuevoOrden: Integer)
    var
        Entrada: Record "Concepto Liquidación";
        Aportante: Record "Concepto Liquidación";
        Aportes: List of [Code[20]];
        Codigo: Code[20];
        CodigoAporte: Code[20];
        Orden: Integer;
        Ordenes: List of [Integer];
        EntradasObjetivo: Boolean;
        Inicializadas: Dictionary of [Code[20], Boolean];
        Errores: Text;
    begin
        DependenciasDe(Concepto, Dependencias, Inicializadas, Errores);
        if Errores <> '' then
            Error('No se pueden comprobar las entradas de %1: %2.', Concepto.Código, Errores);
        EntradasObjetivo := RevisarObjetivo and ObjetivoFormula and (Concepto.Código = CodAcum);
        foreach Codigo in Dependencias.Keys() do begin
            ObtenerConceptoObligatorio(Codigo, Entrada);
            if Entrada."Es Acumulador" then begin
                if not ((Codigo = CodAcum) and MueveLector) then begin
                    ObtenerAportes(Codigo, Aportes);
                    foreach CodigoAporte in Aportes do
                        if CodigoAporte <> Concepto.Código then begin
                            ObtenerConceptoObligatorio(CodigoAporte, Aportante);
                            ExigirOrdenesReferencia(Aportante, Ordenes);
                            foreach Orden in Ordenes do
                                if not Antes(Orden, CodigoAporte, NuevoOrden, Concepto.Código) or
                                   Cruza(OrdenAnterior, NuevoOrden, Concepto.Código, Orden, CodigoAporte)
                                then
                                    Error('El movimiento de %1 cruza o deja pendiente el aporte %2 de su entrada %3.', Concepto.Código, CodigoAporte, Codigo);
                        end;
                end;
            end else
                if AplicaAlAmbito(Entrada) then begin
                    if Codigo = Concepto.Código then
                        Error('El concepto %1 lee su propio valor calculado; no se puede reordenar automáticamente.', Codigo);
                    ExigirOrdenesReferencia(Entrada, Ordenes);
                    foreach Orden in Ordenes do
                        if not Antes(Orden, Codigo, NuevoOrden, Concepto.Código) or
                           (Cruza(OrdenAnterior, NuevoOrden, Concepto.Código, Orden, Codigo) and not EntradasObjetivo)
                        then
                            Error('El movimiento de %1 cruza o deja pendiente su entrada %2 (orden posible %3).', Concepto.Código, Codigo, Orden);
                end;
        end;
        foreach Codigo in Inicializadas.Keys() do
            if Codigo <> Concepto.Código then begin
                ObtenerConceptoObligatorio(Codigo, Entrada);
                if AplicaAlAmbito(Entrada) then begin
                    ExigirOrdenesReferencia(Entrada, Ordenes);
                    foreach Orden in Ordenes do
                        if Cruza(OrdenAnterior, NuevoOrden, Concepto.Código, Orden, Codigo) then
                            Error('El movimiento de %1 cruza al escritor %2 (orden posible %3) y cambia la fase de una variable inicializada.', Concepto.Código, Codigo, Orden);
                end;
            end;
    end;

    local procedure ValidarConsumidores(Concepto: Record "Concepto Liquidación"; CodAcum: Code[20]; ObjetivoFormula: Boolean; RevisarObjetivo: Boolean; OrdenAnterior: Integer; NuevoOrden: Integer)
    var
        Lector: Record "Concepto Liquidación" temporary;
        Dependencias: Dictionary of [Code[20], Boolean];
        Inicializadas: Dictionary of [Code[20], Boolean];
        Acumuladores: List of [Code[20]];
        Codigo: Code[20];
        OrdenLector: Integer;
        OrdenesLector: List of [Integer];
        Errores: Text;
        LeeConcepto: Boolean;
        LeeInicializada: Boolean;
        LeeOtraBase: Boolean;
        CruceAutorizado: Boolean;
    begin
        ObtenerAcumuladores(Concepto.Código, Acumuladores);
        Lector.Copy(Todos, true);
        if Lector.FindSet() then
            repeat
                if (Lector.Código <> Concepto.Código) and not Lector."Es Acumulador" then
                    if AplicaAlAmbito(Lector) then begin
                        DependenciasDe(Lector, Dependencias, Inicializadas, Errores);
                        LeeConcepto := Dependencias.ContainsKey(Concepto.Código);
                        LeeInicializada := Inicializadas.ContainsKey(Concepto.Código);
                        LeeOtraBase := false;
                        foreach Codigo in Acumuladores do
                            if (Codigo <> CodAcum) or not RevisarObjetivo then
                                if Dependencias.ContainsKey(Codigo) then
                                    LeeOtraBase := true;
                        if LeeConcepto or LeeInicializada or LeeOtraBase then begin
                            if Errores <> '' then
                                Error('No se pueden comprobar los consumidores de %1: %2 (%3).', Concepto.Código, Lector.Código, Errores);
                            if Lector."Fuente Matriz" <> '' then
                                Error('El consumidor %1 usa una matriz y requiere una revisión específica.', Lector.Código);
                            CruceAutorizado := RevisarObjetivo and ObjetivoFormula and (Lector.Código = CodAcum) and LeeConcepto and not LeeOtraBase and not LeeInicializada;
                            ExigirOrdenesReferencia(Lector, OrdenesLector);
                            foreach OrdenLector in OrdenesLector do begin
                                if Cruza(OrdenAnterior, NuevoOrden, Concepto.Código, OrdenLector, Lector.Código) and not CruceAutorizado then
                                    Error('El movimiento cruza al consumidor %1 (orden posible %2) y cambiaría otro resultado o acumulador.', Lector.Código, OrdenLector);
                                if LeeConcepto then
                                    if not Antes(NuevoOrden, Concepto.Código, OrdenLector, Lector.Código) then
                                        Error('El concepto %1 debe seguir antes de su consumidor %2.', Concepto.Código, Lector.Código);
                            end;
                        end;
                    end;
            until Lector.Next() = 0;
    end;

    local procedure DependenciasDe(Concepto: Record "Concepto Liquidación"; var Dependencias: Dictionary of [Code[20], Boolean]; var Errores: Text)
    var
        Inicializadas: Dictionary of [Code[20], Boolean];
    begin
        DependenciasDe(Concepto, Dependencias, Inicializadas, Errores);
    end;

    local procedure DependenciasDe(Concepto: Record "Concepto Liquidación"; var Dependencias: Dictionary of [Code[20], Boolean]; var Inicializadas: Dictionary of [Code[20], Boolean]; var Errores: Text)
    var
        RequiereContexto: Boolean;
    begin
        DependenciasDe(Concepto, Dependencias, Inicializadas, Errores, RequiereContexto);
    end;

    local procedure DependenciasDe(Concepto: Record "Concepto Liquidación"; var Dependencias: Dictionary of [Code[20], Boolean]; var Inicializadas: Dictionary of [Code[20], Boolean]; var Errores: Text; var RequiereContexto: Boolean)
    var
        Vigentes: Record "Concepto Liquidación" temporary;
        Codigos: List of [Code[20]];
        CodigosInicializados: List of [Code[20]];
        Codigo: Code[20];
        Clave: Text;
    begin
        Clear(Dependencias);
        Clear(Inicializadas);
        Errores := '';
        RequiereContexto := false;
        Clave := ClaveConcepto(Concepto);
        if LeerLista(DependenciasCache, Clave, Codigos) then begin
            foreach Codigo in Codigos do
                Dependencias.Add(Codigo, true);
            LeerLista(InicializadasCache, Clave, CodigosInicializados);
            foreach Codigo in CodigosInicializados do
                Inicializadas.Add(Codigo, true);
            Errores := ErroresDependenciasCache.Get(Clave);
            RequiereContexto := ContextoDependenciasCache.Get(Clave);
            exit;
        end;
        Vigentes.Copy(Todos, true);
        Vigentes.Reset();
        ControlDependencias.PrepararCatalogoDependencias();
        if ContextoConcreto then
            ControlDependencias.ExtraerDependenciasConcepto(Concepto, Vigentes, FechaContexto, TipoContexto, ConvenioContexto, CategoriaContexto, Codigos, CodigosInicializados, Errores, RequiereContexto)
        else
            ControlDependencias.ExtraerDependenciasConcepto(Concepto, Vigentes, Codigos, CodigosInicializados, Errores);
        foreach Codigo in Codigos do
            Dependencias.Set(Codigo, true);
        foreach Codigo in CodigosInicializados do
            Inicializadas.Set(Codigo, true);
        GuardarLista(DependenciasCache, Clave, Codigos);
        GuardarLista(InicializadasCache, Clave, CodigosInicializados);
        ErroresDependenciasCache.Add(Clave, Errores);
        ContextoDependenciasCache.Add(Clave, RequiereContexto);
    end;

    local procedure ExigirSinCiclos(Concepto: Record "Concepto Liquidación")
    var
        Vigentes: Record "Concepto Liquidación" temporary;
        Clave: Text;
        Motivo: Text;
        RequiereContexto: Boolean;
        TieneCiclo: Boolean;
    begin
        Clave := ClaveConcepto(Concepto);
        if not CiclosCache.Get(Clave, Motivo) then begin
            Vigentes.Copy(Todos, true);
            Vigentes.Reset();
            ControlDependencias.PrepararCatalogoDependencias();
            if ContextoConcreto then
                TieneCiclo := ControlDependencias.DetectarCicloDependencias(Concepto, Vigentes, FechaContexto, TipoContexto, ConvenioContexto, CategoriaContexto, Motivo, RequiereContexto)
            else
                TieneCiclo := ControlDependencias.DetectarCicloDependencias(Concepto, Vigentes, Motivo);
            if TieneCiclo then begin
                if Motivo = '' then
                    Motivo := 'Dependencia circular o demasiado profunda.';
            end else
                Motivo := '';
            CiclosCache.Add(Clave, Motivo);
        end;
        if Motivo <> '' then
            Error('No se puede corregir el orden de %1: %2', Concepto.Código, Motivo);
    end;

    local procedure EsObjetivoAcumulador(Codigo: Code[20]): Boolean
    var
        Objetivo: Record "Concepto Liquidación";
    begin
        ObtenerConceptoObligatorio(Codigo, Objetivo);
        exit(Objetivo."Es Acumulador");
    end;

    local procedure EsLectorObjetivo(Codigo: Code[20]; Actual: Record "Concepto Liquidación"; Dependencias: Dictionary of [Code[20], Boolean]): Boolean
    begin
        if EsObjetivoAcumulador(Codigo) then
            exit(Dependencias.ContainsKey(Codigo));
        exit(Actual.Código = Codigo);
    end;

    local procedure ValidarTipoObjetivo(Codigo: Code[20]; EsperadoAcumulador: Boolean)
    begin
        if EsObjetivoAcumulador(Codigo) <> EsperadoAcumulador then
            Error('El objetivo %1 cambia entre acumulador y lector desde %2. Revisá sus vigencias antes de corregir el orden.', Codigo, FechaContexto);
    end;

    local procedure ObtenerEntradasCalculadas(Objetivo: Record "Concepto Liquidación"; var Entradas: List of [Code[20]])
    var
        Referido: Record "Concepto Liquidación";
        Dependencias: Dictionary of [Code[20], Boolean];
        Codigo: Code[20];
        Errores: Text;
    begin
        DependenciasDe(Objetivo, Dependencias, Errores);
        if ContextoConcreto and (Errores <> '') then
            Error('No se pueden comprobar las entradas del lector %1: %2.', Objetivo.Código, Errores);
        foreach Codigo in Dependencias.Keys() do
            if ObtenerConcepto(Codigo, Referido) then
                if not Referido."Es Acumulador" then
                    if AplicaAlAmbito(Referido) and PuedeProducirEnAmbito(Referido) then
                        Entradas.Add(Codigo);
    end;

    local procedure ObtenerLectores(CodAcum: Code[20]; var Lectores: List of [Code[20]])
    var
        Concepto: Record "Concepto Liquidación" temporary;
        Objetivo: Record "Concepto Liquidación";
        Dependencias: Dictionary of [Code[20], Boolean];
        Errores: Text;
        Clave: Text;
    begin
        Clear(Lectores);
        Clave := ClaveContexto(CodAcum);
        if LeerLista(LectoresCache, Clave, Lectores) then
            exit;
        ObtenerConceptoObligatorio(CodAcum, Objetivo);
        if not Objetivo."Es Acumulador" then begin
            if AplicaAlAmbito(Objetivo) then
                Lectores.Add(CodAcum);
            GuardarLista(LectoresCache, Clave, Lectores);
            exit;
        end;
        Concepto.Copy(Todos, true);
        if Concepto.FindSet() then
            repeat
                if not Concepto."Es Acumulador" then
                    if AplicaAlAmbito(Concepto) then begin
                        DependenciasDe(Concepto, Dependencias, Errores);
                        if Dependencias.ContainsKey(CodAcum) then begin
                            if Errores <> '' then
                                Error('La lectura %1 tiene dependencias que no se pueden comprobar: %2.', Concepto.Código, Errores);
                            Lectores.Add(Concepto.Código);
                        end;
                    end;
            until Concepto.Next() = 0;
        GuardarLista(LectoresCache, Clave, Lectores);
    end;

    local procedure ObtenerAportes(CodAcum: Code[20]; var Aportes: List of [Code[20]])
    var
        Frac: Record "Fracción Acumulador" temporary;
        Concepto: Record "Concepto Liquidación";
        Objetivo: Record "Concepto Liquidación";
        Ultimas: Dictionary of [Code[20], Date];
        Codigo: Code[20];
        Vigencia: Date;
        Clave: Text;
    begin
        Clear(Aportes);
        Clave := ClaveContexto(CodAcum);
        if LeerLista(AportesCache, Clave, Aportes) then
            exit;
        ObtenerConceptoObligatorio(CodAcum, Objetivo);
        if not Objetivo."Es Acumulador" then begin
            ObtenerEntradasCalculadas(Objetivo, Aportes);
            GuardarLista(AportesCache, Clave, Aportes);
            exit;
        end;
        Frac.Copy(CatalogoFracciones, true);
        Frac.Reset();
        Frac.SetRange("Cód. Acumulador", CodAcum);
        Frac.SetFilter("Vigencia Desde", '<=%1', FechaContexto);
        if Frac.FindSet() then
            repeat
                if not Ultimas.Get(Frac."Cód. Concepto", Vigencia) then
                    Ultimas.Add(Frac."Cód. Concepto", Frac."Vigencia Desde")
                else
                    if Frac."Vigencia Desde" > Vigencia then
                        Ultimas.Set(Frac."Cód. Concepto", Frac."Vigencia Desde");
            until Frac.Next() = 0;
        foreach Codigo in Ultimas.Keys() do
            if ObtenerConcepto(Codigo, Concepto) then
                if not Concepto."Es Acumulador" then
                    if AplicaAlAmbito(Concepto) then
                        if Frac.Get(Codigo, Ultimas.Get(Codigo), CodAcum) then
                            if Frac.Porcentaje <> 0 then
                                if FraccionAplica(Frac, Concepto) and PuedeProducirEnAmbito(Concepto) then
                                    Aportes.Add(Codigo);
        GuardarLista(AportesCache, Clave, Aportes);
    end;

    local procedure ObtenerAcumuladores(CodConcepto: Code[20]; var Acumuladores: List of [Code[20]])
    var
        Frac: Record "Fracción Acumulador" temporary;
        Concepto: Record "Concepto Liquidación";
        Ultimas: Dictionary of [Code[20], Date];
        Codigo: Code[20];
        Vigencia: Date;
        Clave: Text;
    begin
        Clear(Acumuladores);
        Clave := ClaveContexto(CodConcepto);
        if LeerLista(AcumuladoresCache, Clave, Acumuladores) then
            exit;
        ObtenerConceptoObligatorio(CodConcepto, Concepto);
        Frac.Copy(CatalogoFracciones, true);
        Frac.Reset();
        Frac.SetRange("Cód. Concepto", CodConcepto);
        Frac.SetFilter("Vigencia Desde", '<=%1', FechaContexto);
        if Frac.FindSet() then
            repeat
                if not Ultimas.Get(Frac."Cód. Acumulador", Vigencia) then
                    Ultimas.Add(Frac."Cód. Acumulador", Frac."Vigencia Desde")
                else
                    if Frac."Vigencia Desde" > Vigencia then
                        Ultimas.Set(Frac."Cód. Acumulador", Frac."Vigencia Desde");
            until Frac.Next() = 0;
        foreach Codigo in Ultimas.Keys() do
            if Frac.Get(CodConcepto, Ultimas.Get(Codigo), Codigo) then
                if Frac.Porcentaje <> 0 then
                    if FraccionAplica(Frac, Concepto) then
                        Acumuladores.Add(Codigo);
        GuardarLista(AcumuladoresCache, Clave, Acumuladores);
    end;

    local procedure FraccionAplica(Frac: Record "Fracción Acumulador"; Concepto: Record "Concepto Liquidación"): Boolean
    begin
        if ((ConvenioContexto = '') and not ContextoConcreto) or (Concepto."Par CCT a Usar" <> Concepto."Par CCT a Usar"::Entidad) then
            exit(true);
        exit(Frac.AplicaAConvenio(ConvenioContexto));
    end;

    local procedure CargarContexto(Fecha: Date; TipoLiq: Code[20]; Convenio: Code[20])
    begin
        CargarContexto(Fecha, TipoLiq, Convenio, '', false);
    end;

    local procedure CargarContextoConcreto(Fecha: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20])
    begin
        CargarContexto(Fecha, TipoLiq, Convenio, Categoria, true);
    end;

    local procedure CargarContexto(Fecha: Date; TipoLiq: Code[20]; Convenio: Code[20]; Categoria: Code[20]; Concreto: Boolean)
    var
        Concepto: Record "Concepto Liquidación" temporary;
        Version: Date;
        Codigo: Code[20];
        VersionesGuardadas: Dictionary of [Code[20], Date];
    begin
        if ContextoCargado then
            if (FechaContexto = Fecha) and (TipoContexto = TipoLiq) and (ConvenioContexto = Convenio) and
               (CategoriaContexto = Categoria) and (ContextoConcreto = Concreto) then
                exit;
        if ContextoCargado and (FechaContexto = Fecha) then begin
            // Las versiones ganadoras sólo dependen de la fecha. Recorrer otro tipo,
            // convenio o clase de categorías reutiliza el mismo catálogo temporal.
            TipoContexto := TipoLiq;
            ConvenioContexto := Convenio;
            CategoriaContexto := Categoria;
            ContextoConcreto := Concreto;
            Todos.Reset();
            exit;
        end;
        CargarCatalogos();
        ContextoCargado := false;
        FechaContexto := Fecha;
        TipoContexto := TipoLiq;
        ConvenioContexto := Convenio;
        CategoriaContexto := Categoria;
        ContextoConcreto := Concreto;
        Todos.Reset();
        Todos.DeleteAll();
        Clear(Versiones);
        if VersionesPorFecha.Get(Fecha, VersionesGuardadas) then begin
            foreach Codigo in VersionesGuardadas.Keys() do begin
                Version := VersionesGuardadas.Get(Codigo);
                CatalogoConceptos.Get(Codigo, Version);
                Todos := CatalogoConceptos;
                Todos.Insert();
                Versiones.Add(Codigo, Version);
            end;
            Todos.Reset();
            ContextoCargado := true;
            exit;
        end;
        Concepto.Copy(CatalogoConceptos, true);
        Concepto.Reset();
        Concepto.FiltrarVigentesA(Fecha);
        if Concepto.FindSet() then
            repeat
                if Versiones.Get(Concepto.Código, Version) then begin
                    if Concepto."Vigencia Desde" > Version then begin
                        Todos.Get(Concepto.Código, Version);
                        Todos.Delete();
                        Todos := Concepto;
                        Todos.Insert();
                        Versiones.Set(Concepto.Código, Concepto."Vigencia Desde");
                    end;
                end else begin
                    Todos := Concepto;
                    Todos.Insert();
                    Versiones.Add(Concepto.Código, Concepto."Vigencia Desde");
                end;
            until Concepto.Next() = 0;
        foreach Codigo in Versiones.Keys() do begin
            Todos.Get(Codigo, Versiones.Get(Codigo));
            if not Todos.VigenteA(Fecha) then begin
                Todos.Delete();
                Versiones.Remove(Codigo);
            end;
        end;
        foreach Codigo in Versiones.Keys() do
            VersionesGuardadas.Add(Codigo, Versiones.Get(Codigo));
        VersionesPorFecha.Add(Fecha, VersionesGuardadas);
        Todos.Reset();
        ContextoCargado := true;
    end;

    local procedure ObtenerConcepto(Codigo: Code[20]; var Concepto: Record "Concepto Liquidación"): Boolean
    var
        Version: Date;
    begin
        if not Versiones.Get(Codigo, Version) then
            exit(false);
        Todos.Get(Codigo, Version);
        Concepto := Todos;
        exit(true);
    end;

    local procedure ObtenerConceptoObligatorio(Codigo: Code[20]; var Concepto: Record "Concepto Liquidación")
    begin
        if not ObtenerConcepto(Codigo, Concepto) then
            Error('No se encontró la versión vigente de la dependencia %1.', Codigo);
    end;

    local procedure ExigirOrden(Concepto: Record "Concepto Liquidación"): Integer
    var
        Orden: Integer;
    begin
        if not ResolverOrdenContexto(Concepto, Orden) then
            Error('No se puede verificar el orden de %1 con estos filtros. No se guardará ningún cambio.', Concepto.Código);
        exit(Orden);
    end;

    local procedure ExigirOrdenesReferencia(Concepto: Record "Concepto Liquidación"; var Ordenes: List of [Integer])
    begin
        if not ObtenerOrdenesReferencia(Concepto, Ordenes) then
            Error('No se pueden comprobar todos los órdenes posibles de la referencia %1. Falta contexto del empleado, puesto o una fórmula de orden verificable; no se modifica esa dependencia.', Concepto.Código);
    end;

    local procedure ObtenerOrdenesReferencia(Concepto: Record "Concepto Liquidación"; var Ordenes: List of [Integer]): Boolean
    var
        Control: Codeunit "Control Orden Acumuladores";
        Guardadas: List of [Integer];
        Orden: Integer;
        Clave: Text;
        Resuelto: Boolean;
    begin
        Clear(Ordenes);
        Clave := ClaveConcepto(Concepto);
        if OrdenesPosiblesResueltosCache.Get(Clave, Resuelto) then begin
            if not Resuelto then
                exit(false);
            Guardadas := OrdenesPosiblesCache.Get(Clave);
            foreach Orden in Guardadas do
                Ordenes.Add(Orden);
            exit(true);
        end;
        if ContextoConcreto then
            Resuelto := ControlDependencias.ObtenerOrdenesPosiblesEnContexto(Concepto, FechaContexto, TipoContexto, ConvenioContexto, Ordenes)
        else
            Resuelto := Control.ObtenerOrdenesPosibles(Concepto, FechaContexto, TipoContexto, ConvenioContexto, Ordenes);
        if Ordenes.Count() = 0 then
            Resuelto := false;
        OrdenesPosiblesResueltosCache.Add(Clave, Resuelto);
        if Resuelto then begin
            // El llamador conserva su lista; no puede alterar el conjunto de otra referencia.
            foreach Orden in Ordenes do
                Guardadas.Add(Orden);
            OrdenesPosiblesCache.Add(Clave, Guardadas);
        end else
            Clear(Ordenes);
        exit(Resuelto);
    end;

    local procedure AplicaAlAmbito(Concepto: Record "Concepto Liquidación"): Boolean
    var
        Clave: Text;
        Aplica: Boolean;
    begin
        Clave := ClaveConcepto(Concepto);
        if not AlcanceCache.Get(Clave, Aplica) then begin
            Aplica := EvaluarAmbito(Concepto);
            AlcanceCache.Add(Clave, Aplica);
        end;
        exit(Aplica);
    end;

    local procedure EvaluarAmbito(Concepto: Record "Concepto Liquidación"): Boolean
    var
        Restriccion: Record "Concepto CCT Vigente" temporary;
        Declarado: Boolean;
        ParDesconocido: Boolean;
    begin
        if ContextoConcreto then
            exit(ControlDependencias.ConceptoIncluidoEnContexto(Concepto, FechaContexto, TipoContexto, ConvenioContexto, CategoriaContexto, ParDesconocido));
        if TipoContexto <> '' then begin
            Declarado := ('|' + Concepto."Tipos Liq. Aplicables" + '|').Contains('|' + TipoContexto + '|');
            if Concepto."Tipo Concepto" = Concepto."Tipo Concepto"::Informativo then begin
                if (Concepto."Tipos Liq. Aplicables" <> '') and not Declarado then
                    exit(false);
            end else begin
                if TipoExigeDeclarados() and not Declarado then
                    exit(false);
                if (Concepto."Tipos Liq. Aplicables" <> '') and not Declarado then
                    exit(false);
            end;
        end;
        if (ConvenioContexto = '') or (Concepto."Par CCT a Usar" <> Concepto."Par CCT a Usar"::Entidad) then
            exit(true);
        // La fórmula afecta TODO el convenio, aunque el diálogo muestre una categoría.
        // Sólo se excluye lo imposible para todas sus categorías; jamás por una categoría vacía.
        Restriccion.Copy(CatalogoRestricciones, true);
        Restriccion.Reset();
        Restriccion.SetRange("Cód. Concepto", Concepto.Código);
        Restriccion.SetFilter("Vigencia Desde", '<=%1', FechaContexto);
        Restriccion.SetRange("Cód. Convenio", ConvenioContexto);
        Restriccion.SetRange("Cód. Categoría", '');
        Restriccion.SetRange(Excluye, true);
        if not Restriccion.IsEmpty() then
            exit(false);
        Restriccion.SetRange("Cód. Convenio");
        Restriccion.SetRange("Cód. Categoría");
        Restriccion.SetRange(Excluye, false);
        if Restriccion.IsEmpty() then
            exit(true);
        Restriccion.SetRange("Cód. Convenio", ConvenioContexto);
        exit(not Restriccion.IsEmpty());
    end;

    local procedure TipoExigeDeclarados(): Boolean
    var
        Tipo: Record "Tipo Liquidación";
        SoloDeclarados: Boolean;
    begin
        if not TiposDeclaradosCache.Get(TipoContexto, SoloDeclarados) then begin
            if Tipo.Get(TipoContexto) then
                SoloDeclarados := Tipo."Sólo Conceptos Declarados";
            TiposDeclaradosCache.Add(TipoContexto, SoloDeclarados);
        end;
        exit(SoloDeclarados);
    end;

    local procedure ResolverOrdenContexto(Concepto: Record "Concepto Liquidación"; var Orden: Integer): Boolean
    var
        Control: Codeunit "Control Orden Acumuladores";
        Clave: Text;
        Resuelto: Boolean;
    begin
        Orden := 0;
        Clave := ClaveConcepto(Concepto);
        if OrdenResueltoCache.Get(Clave, Resuelto) then begin
            if Resuelto then
                Orden := OrdenesCache.Get(Clave);
            exit(Resuelto);
        end;
        if ContextoConcreto then
            Resuelto := ControlDependencias.ResolverOrdenEnContexto(Concepto, FechaContexto, TipoContexto, ConvenioContexto, Orden)
        else
            Resuelto := Control.ResolverOrden(Concepto, FechaContexto, TipoContexto, ConvenioContexto, Orden);
        OrdenResueltoCache.Add(Clave, Resuelto);
        if Resuelto then
            OrdenesCache.Add(Clave, Orden);
        exit(Resuelto);
    end;

    local procedure ClaveContexto(Codigo: Code[20]): Text
    begin
        // Una operación puede recorrer varios ámbitos compatibles. Nunca mezclar sus cachés.
        exit(Format(FechaContexto, 0, 9) + '|' + Format(ContextoConcreto) + '|' + TipoContexto + '|' + ConvenioContexto + '|' + CategoriaContexto + '|' + Codigo);
    end;

    local procedure ClaveConcepto(Concepto: Record "Concepto Liquidación"): Text
    begin
        exit(ClaveContexto(Concepto.Código) + '|' + Format(Concepto."Vigencia Desde", 0, 9));
    end;

    local procedure LeerLista(var Cache: Dictionary of [Text, List of [Code[20]]]; Clave: Text; var Resultado: List of [Code[20]]): Boolean
    var
        Guardada: List of [Code[20]];
        Codigo: Code[20];
    begin
        Clear(Resultado);
        if not Cache.Get(Clave, Guardada) then
            exit(false);
        // List y Dictionary son referencias. El llamador recibe su propia lista modificable.
        foreach Codigo in Guardada do
            Resultado.Add(Codigo);
        exit(true);
    end;

    local procedure GuardarLista(var Cache: Dictionary of [Text, List of [Code[20]]]; Clave: Text; Resultado: List of [Code[20]])
    var
        Copia: List of [Code[20]];
        Codigo: Code[20];
    begin
        foreach Codigo in Resultado do
            Copia.Add(Codigo);
        Cache.Add(Clave, Copia);
    end;

    local procedure IniciarOperacion()
    begin
        // Nunca conservar una aprobación entre llamadas, ni después de una edición de terceros.
        ContextoCargado := false;
        ContextoConcreto := false;
        Clear(CategoriaContexto);
        Clear(TipoFormulaOperacion);
        Clear(ConvenioFormulaOperacion);
        CatalogosCargados := false;
        Todos.Reset();
        Todos.DeleteAll();
        CatalogoConceptos.Reset();
        CatalogoConceptos.DeleteAll();
        CatalogoFracciones.Reset();
        CatalogoFracciones.DeleteAll();
        CatalogoRestricciones.Reset();
        CatalogoRestricciones.DeleteAll();
        Clear(Versiones);
        Clear(VersionesPorFecha);
        Clear(FronterasCache);
        Clear(ControlDependencias);
        Clear(CiclosCache);
        Clear(DependenciasCache);
        Clear(InicializadasCache);
        Clear(ContextoDependenciasCache);
        Clear(ErroresDependenciasCache);
        Clear(AlcanceCache);
        Clear(AportesCache);
        Clear(AcumuladoresCache);
        Clear(LectoresCache);
        Clear(OrdenesCache);
        Clear(OrdenResueltoCache);
        Clear(OrdenesPosiblesCache);
        Clear(OrdenesPosiblesResueltosCache);
        Clear(TiposDeclaradosCache);
    end;

    local procedure CargarCatalogos()
    var
        Concepto: Record "Concepto Liquidación";
        Fraccion: Record "Fracción Acumulador";
        Restriccion: Record "Concepto CCT Vigente";
    begin
        if CatalogosCargados then
            exit;
        // Una lectura física por catálogo. Las fechas futuras se revisan sobre la misma foto.
        if Concepto.FindSet() then
            repeat
                CatalogoConceptos := Concepto;
                CatalogoConceptos.Insert();
            until Concepto.Next() = 0;
        if Fraccion.FindSet() then
            repeat
                CatalogoFracciones := Fraccion;
                CatalogoFracciones.Insert();
            until Fraccion.Next() = 0;
        if Restriccion.FindSet() then
            repeat
                CatalogoRestricciones := Restriccion;
                CatalogoRestricciones.Insert();
            until Restriccion.Next() = 0;
        CatalogosCargados := true;
    end;

    local procedure Antes(OrdenA: Integer; CodigoA: Code[20]; OrdenB: Integer; CodigoB: Code[20]): Boolean
    begin
        if OrdenA <> OrdenB then
            exit(OrdenA < OrdenB);
        exit(CodigoA < CodigoB);
    end;

    local procedure Cruza(OrdenAnterior: Integer; NuevoOrden: Integer; Codigo: Code[20]; OrdenOtro: Integer; CodigoOtro: Code[20]): Boolean
    begin
        exit(Antes(OrdenAnterior, Codigo, OrdenOtro, CodigoOtro) <> Antes(NuevoOrden, Codigo, OrdenOtro, CodigoOtro));
    end;

    var
        Todos: Record "Concepto Liquidación" temporary;
        CatalogoConceptos: Record "Concepto Liquidación" temporary;
        CatalogoFracciones: Record "Fracción Acumulador" temporary;
        CatalogoRestricciones: Record "Concepto CCT Vigente" temporary;
        Versiones: Dictionary of [Code[20], Date];
        VersionesPorFecha: Dictionary of [Date, Dictionary of [Code[20], Date]];
        FronterasCache: Dictionary of [Text, List of [Date]];
        ControlDependencias: Codeunit "Control Orden Acumuladores";
        CiclosCache: Dictionary of [Text, Text];
        DependenciasCache: Dictionary of [Text, List of [Code[20]]];
        InicializadasCache: Dictionary of [Text, List of [Code[20]]];
        ContextoDependenciasCache: Dictionary of [Text, Boolean];
        ErroresDependenciasCache: Dictionary of [Text, Text];
        AlcanceCache: Dictionary of [Text, Boolean];
        AportesCache: Dictionary of [Text, List of [Code[20]]];
        AcumuladoresCache: Dictionary of [Text, List of [Code[20]]];
        LectoresCache: Dictionary of [Text, List of [Code[20]]];
        OrdenesCache: Dictionary of [Text, Integer];
        OrdenResueltoCache: Dictionary of [Text, Boolean];
        OrdenesPosiblesCache: Dictionary of [Text, List of [Integer]];
        OrdenesPosiblesResueltosCache: Dictionary of [Text, Boolean];
        TiposDeclaradosCache: Dictionary of [Code[20], Boolean];
        CatalogosCargados: Boolean;
        ContextoCargado: Boolean;
        FechaContexto: Date;
        TipoContexto: Code[20];
        ConvenioContexto: Code[20];
        CategoriaContexto: Code[20];
        ContextoConcreto: Boolean;
        TipoFormulaOperacion: Code[20];
        ConvenioFormulaOperacion: Code[20];
}
