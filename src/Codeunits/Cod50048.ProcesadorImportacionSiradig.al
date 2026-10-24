namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.HumanResources.Setup;

codeunit 50048 "Procesador Importación SIRADIG"
{
    Access = Internal;

    var
        ErrorEmpleadoNoEncontrado: Label 'No se encontró empleado con CUIL: %1. Se buscó en "Nº seguridad social" y en "CIF/NIF" del empleado, con y sin guiones, e ignorando cualquier otro formato. Verificá que alguno de esos campos tenga ese CUIL.';
        ErrorDeduccionInvalida: Label 'Código de deducción SIRADIG no válido: %1';
        WarningDeduccionIgnorada: Label 'Deducción tipo %1 no será importada (tipo no soportado)';
        MsgProcesadoExitosamente: Label 'Importación procesada exitosamente. %1 deducciones, %2 cargas familiares.';
        ParserSiradig: Codeunit "Parser SIRADIG XML";
        AuditoriaAfip: Codeunit "Auditoria AFIP Interface";
        // En importaciones de varios archivos el llamador muestra UN resumen al final; sin esto
        // saldría un cuadro de diálogo por cada archivo procesado.
        FSilencioso: Boolean;

    procedure ProcesarImportacionSiradig(var RegistroImportacion: Record "Importación SIRADIG"; var XmlContent: Text)
    var
        Empleado: Record Employee;
        DeduccionesJson: Text;
        CargasJson: Text;
    begin
        // Validar que el empleado exista
        if not EncontrarEmpleadoPorCuil(RegistroImportacion."CUIL Empleado", Empleado) then
            Error(ErrorEmpleadoNoEncontrado, RegistroImportacion."CUIL Empleado");

        RegistroImportacion."No. Empleado" := Empleado."No.";

        // Procesar deducciones
        DeduccionesJson := ParserSiradig.ObtenerDeduccionesDelXml(XmlContent);
        ProcesarDeduccionesDelJson(DeduccionesJson, RegistroImportacion."No. Empleado", RegistroImportacion);

        // Procesar cargas de familia
        CargasJson := ParserSiradig.ObtenerCargasFamiliaDelXml(XmlContent);
        ProcesarCargasFamiliaDelJson(CargasJson, RegistroImportacion."No. Empleado", RegistroImportacion);

        // Marcar como procesado
        RegistroImportacion.Estado := "Estado Importación SIRADIG"::"Procesado Exitosamente";
        RegistroImportacion."Fecha Importación" := CurrentDateTime();
        RegistroImportacion."Usuario Importación" := CopyStr(UserId(), 1, 50);
        RegistroImportacion.Modify();

        if not FSilencioso then
            Message(MsgProcesadoExitosamente,
                RegistroImportacion."Deducciones Importadas",
                RegistroImportacion."Cargas Familia Importadas");
    end;

    // ¿Hay un empleado con ese CUIL? Lo usa el proceso por lote para dejar marcada como error la
    // importación de alguien que no existe en vez de abortar todo el lote.
    procedure ExisteEmpleado(Cuil: Code[20]): Boolean
    var
        Empleado: Record Employee;
    begin
        exit(EncontrarEmpleadoPorCuil(Cuil, Empleado));
    end;

    // Silencia el mensaje por registro: lo usan los procesos por lote, que informan un único
    // resumen al final en vez de un cuadro de diálogo por archivo.
    procedure SetSilencioso(Valor: Boolean)
    begin
        FSilencioso := Valor;
    end;

    // LAS DEDUCCIONES SE CARGAN MES A MES, con la vigencia del mes en que empiezan.
    //
    // Cada <deduccion> trae sus <periodo mesDesde mesHasta montoMensual>: el importe de CADA mes, no
    // un total anual. "Ded. Ganancias Empleado.Importe Fijo" es un importe MENSUAL y el motor lee sólo
    // el conjunto de la vigencia más reciente, así que la declaración se arma como una línea de
    // tiempo: una vigencia (día 1 del mes) por cada mes en que el conjunto de deducciones activas
    // cambia, con TODAS las activas ese mes. Cuando una deducción termina y no queda ninguna activa,
    // se escribe la línea en cero de lo que dejó de valer: sin ella el motor seguiría leyendo el
    // conjunto anterior hasta la próxima vigencia.
    //
    // Antes se cargaba el total (montoTotal) con vigencia = HOY: un importe anual leído como mensual
    // y con una fecha que no coincidía con la del período declarado, así que un recálculo de enero ni
    // siquiera lo veía.
    local procedure ProcesarDeduccionesDelJson(var JsonText: Text; NoEmpleado: Code[20]; var RegistroImportacion: Record "Importación SIRADIG")
    var
        JsonObj: JsonObject;
        JsonArray: JsonArray;
        JsonToken: JsonToken;
        PeriodosArray: JsonArray;
        PeriodoToken: JsonToken;
        PeriodoObj: JsonObject;
        ValorToken: JsonToken;
        MontosPorMes: Dictionary of [Text, Decimal];
        TiposPresentes: List of [Text];
        Descripciones: Dictionary of [Text, Text];
        Ocurrencias: Dictionary of [Text, Integer];
        ClaveDeduccion: Text;
        TipoDeduccion: Text;
        Monto: Text;
        MontoDecimal: Decimal;
        MontoMes: Decimal;
        MesDesde: Integer;
        MesHasta: Integer;
        Mes: Integer;
        Anio: Integer;
        Activos: List of [Text];
        ActivosAnteriores: List of [Text];
        Tipo: Text;
        Clave: Text;
        Cambio: Boolean;
        i: Integer;
        j: Integer;
        CountDeduccionesImportadas: Integer;
    begin
        if not JsonArray.ReadFrom(JsonText) then
            exit;

        Anio := RegistroImportacion."Período";
        if Anio = 0 then
            Anio := Date2DMY(Today(), 3);

        for i := 0 to JsonArray.Count() - 1 do
            if JsonArray.Get(i, JsonToken) and JsonToken.IsObject() then begin
                JsonObj := JsonToken.AsObject();
                TipoDeduccion := ExtractJsonValue(JsonObj, 'tipo');
                if (TipoDeduccion <> '') and ValidarTipoDeduccionSiradig(TipoDeduccion) then begin
                    // Cada <deduccion> es una línea propia: la repetición de un tipo (dos hijos con gasto educativo,
                    // dos prepagas) se numera desde 0, y el 0 es lo que ya tenían las filas de una sola por tipo.
                    if not Ocurrencias.ContainsKey(TipoDeduccion) then
                        Ocurrencias.Add(TipoDeduccion, 0)
                    else
                        Ocurrencias.Set(TipoDeduccion, Ocurrencias.Get(TipoDeduccion) + 1);
                    ClaveDeduccion := StrSubstNo('%1#%2', TipoDeduccion, Ocurrencias.Get(TipoDeduccion));
                    TiposPresentes.Add(ClaveDeduccion);
                    Descripciones.Add(ClaveDeduccion, ExtractJsonValue(JsonObj, 'descripcion'));

                    if JsonObj.Get('periodos', JsonToken) and JsonToken.IsArray() then
                        PeriodosArray := JsonToken.AsArray()
                    else
                        Clear(PeriodosArray);

                    if PeriodosArray.Count() > 0 then
                        for j := 0 to PeriodosArray.Count() - 1 do begin
                            if PeriodosArray.Get(j, PeriodoToken) and PeriodoToken.IsObject() then begin
                                PeriodoObj := PeriodoToken.AsObject();
                                MesDesde := 0;
                                MesHasta := 0;
                                MontoMes := 0;
                                if PeriodoObj.Get('d', ValorToken) then
                                    MesDesde := ValorToken.AsValue().AsInteger();
                                if PeriodoObj.Get('h', ValorToken) then
                                    MesHasta := ValorToken.AsValue().AsInteger();
                                if PeriodoObj.Get('m', ValorToken) then
                                    MontoMes := ValorToken.AsValue().AsDecimal();
                                if (MesDesde >= 1) and (MesDesde <= 12) and (MesHasta >= MesDesde) then
                                    for Mes := MesDesde to MinMes(MesHasta) do
                                        GuardarMonto(MontosPorMes, Mes, ClaveDeduccion, MontoMes);
                            end;
                        end
                    else begin
                        // Presentación sin detalle por mes: el total declarado rige desde el mes en
                        // que se presentó, hasta que otra presentación lo cambie.
                        Monto := ExtractJsonValue(JsonObj, 'monto');
                        if not Evaluate(MontoDecimal, Monto) then
                            MontoDecimal := 0;
                        MesDesde := 1;
                        if RegistroImportacion."Fecha Presentación" <> 0D then
                            MesDesde := Date2DMY(RegistroImportacion."Fecha Presentación", 2);
                        for Mes := MesDesde to 12 do
                            GuardarMonto(MontosPorMes, Mes, ClaveDeduccion, MontoDecimal);
                    end;

                    CountDeduccionesImportadas += 1;
                end;
            end;

        // La línea de tiempo: por cada mes, el conjunto activo; se escribe cuando cambia.
        for Mes := 1 to 12 do begin
            Clear(Activos);
            foreach Tipo in TiposPresentes do
                if MontosPorMes.ContainsKey(ClaveMes(Mes, Tipo)) then
                    Activos.Add(Tipo);

            Cambio := Activos.Count() <> ActivosAnteriores.Count();
            if not Cambio then
                foreach Tipo in Activos do
                    if not ActivosAnteriores.Contains(Tipo) then
                        Cambio := true
                    else begin
                        // Mismo tipo: cambia si el importe del mes no es el del mes anterior.
                        Clave := ClaveMes(Mes, Tipo);
                        if (Mes = 1) or not MontosPorMes.ContainsKey(ClaveMes(Mes - 1, Tipo)) then
                            Cambio := true
                        else
                            if MontosPorMes.Get(Clave) <> MontosPorMes.Get(ClaveMes(Mes - 1, Tipo)) then
                                Cambio := true;
                    end;

            if Cambio then begin
                if Activos.Count() > 0 then
                    foreach Tipo in Activos do
                        EscribirDeduccion(NoEmpleado, DMY2Date(1, Mes, Anio), Tipo, MontosPorMes.Get(ClaveMes(Mes, Tipo)), DescripcionDe(Descripciones, Tipo), RegistroImportacion)
                else
                    foreach Tipo in ActivosAnteriores do
                        EscribirDeduccion(NoEmpleado, DMY2Date(1, Mes, Anio), Tipo, 0, DescripcionDe(Descripciones, Tipo), RegistroImportacion);
            end;

            Clear(ActivosAnteriores);
            foreach Tipo in Activos do
                ActivosAnteriores.Add(Tipo);
        end;

        RegistroImportacion."Deducciones Importadas" := CountDeduccionesImportadas;
    end;

    local procedure MinMes(Mes: Integer): Integer
    begin
        if Mes > 12 then
            exit(12);
        exit(Mes);
    end;

    local procedure ClaveMes(Mes: Integer; Tipo: Text): Text
    begin
        exit(StrSubstNo('%1|%2', Format(Mes, 0, '<Integer,2><Filler Character,0>'), Tipo));
    end;

    local procedure GuardarMonto(var MontosPorMes: Dictionary of [Text, Decimal]; Mes: Integer; Tipo: Text; Monto: Decimal)
    var
        Clave: Text;
    begin
        Clave := ClaveMes(Mes, Tipo);
        if MontosPorMes.ContainsKey(Clave) then
            MontosPorMes.Set(Clave, Monto)
        else
            MontosPorMes.Add(Clave, Monto);
    end;

    local procedure DescripcionDe(var Descripciones: Dictionary of [Text, Text]; Clave: Text): Text
    var
        Valor: Text;
    begin
        if Descripciones.Get(Clave, Valor) then
            exit(Valor);
        exit('');
    end;

    // Una línea de Ded. Ganancias Empleado por (empleado, vigencia, tipo, línea): si ya está —reimportar la
    // misma presentación— se actualiza en su lugar, así que no se duplica ni se pisa otra vigencia.
    // Clave es "tipo#línea" (ver ProcesarDeduccionesDelJson).
    local procedure EscribirDeduccion(NoEmpleado: Code[20]; Vigencia: Date; Clave: Text; Importe: Decimal; Descripcion: Text; var RegistroImportacion: Record "Importación SIRADIG")
    var
        DedGananciasEmp: Record "Ded. Ganancias Empleado";
        Tipo: Code[20];
        Linea: Integer;
        MontoAnterior: Decimal;
        EsNuevo: Boolean;
    begin
        Tipo := CopyStr(Clave.Substring(1, Clave.IndexOf('#') - 1), 1, MaxStrLen(Tipo));
        Evaluate(Linea, Clave.Substring(Clave.IndexOf('#') + 1));
        EsNuevo := not DedGananciasEmp.Get(NoEmpleado, Vigencia, Tipo, Linea);
        if EsNuevo then begin
            MontoAnterior := 0;
            DedGananciasEmp.Init();
            DedGananciasEmp."No. Empleado" := NoEmpleado;
            DedGananciasEmp."Vigencia Desde" := Vigencia;
            DedGananciasEmp."Cód. Tipo" := Tipo;
            DedGananciasEmp."No. Línea" := Linea;
            DedGananciasEmp."Importe Fijo" := Importe;
            DedGananciasEmp.Descripción := CopyStr(Descripcion, 1, MaxStrLen(DedGananciasEmp.Descripción));
            DedGananciasEmp.Insert();
        end else begin
            MontoAnterior := DedGananciasEmp."Importe Fijo";
            DedGananciasEmp."Importe Fijo" := Importe;
            // Sólo si la presentación trae descripción: una línea cargada a mano no se pisa con vacío.
            if Descripcion <> '' then
                DedGananciasEmp.Descripción := CopyStr(Descripcion, 1, MaxStrLen(DedGananciasEmp.Descripción));
            DedGananciasEmp.Modify();
        end;

        RegistrarDetalleDeduccion(RegistroImportacion."AFIP Register Entry No.", DedGananciasEmp, EsNuevo, MontoAnterior, Importe);
    end;

    local procedure RegistrarDetalleDeduccion(RegisterEntryNo: Integer; var DedGananciasEmp: Record "Ded. Ganancias Empleado"; EsNuevo: Boolean; MontoAnterior: Decimal; MontoNuevo: Decimal)
    var
        TipoCambio: Option Insertion,Modification,Deletion,"No change";
    begin
        if EsNuevo then
            TipoCambio := TipoCambio::Insertion
        else
            TipoCambio := TipoCambio::Modification;

        AuditoriaAfip.RegistrarDetalle(
            RegisterEntryNo, Database::"Ded. Ganancias Empleado", DedGananciasEmp.FieldNo("Importe Fijo"), TipoCambio,
            Format(MontoAnterior), Format(MontoNuevo),
            StrSubstNo('%1|%2|%3', DedGananciasEmp."No. Empleado", DedGananciasEmp."Cód. Tipo", DedGananciasEmp."No. Línea"));
    end;

    local procedure TipoCambioInsertion() Resultado: Option Insertion,Modification,Deletion,"No change"
    begin
        Resultado := Resultado::Insertion;
    end;

    local procedure TipoCambioFamiliar(EsNuevo: Boolean) Resultado: Option Insertion,Modification,Deletion,"No change"
    begin
        if EsNuevo then
            Resultado := Resultado::Insertion
        else
            Resultado := Resultado::Modification;
    end;

    // Busca una carga de familia ya cargada para el empleado, de la clave más confiable a la menos:
    //   1. Número de documento. SIRADIG informa el CUIL del familiar (11 dígitos) y BC guarda el DNI (8):
    //      el DNI son los dígitos 3 a 10 del CUIL, así que se prueba con los dos.
    //   2. Fecha de nacimiento, si dentro del empleado identifica a UN solo familiar. En la presentación de
    //      enero de 2026 identificó a 36 de 37 cargas; apellido y nombre, sólo a 4 (BC y SIRADIG no los
    //      escriben igual).
    //   3. Apellido y nombre, que es lo único que queda cuando no hay nada de lo anterior.
    // Sin esto el importador creaba un familiar nuevo por cada carga en vez de reconocer el que ya estaba.
    local procedure EncontrarFamiliar(NoEmpleado: Code[20]; NroDoc: Text; Apellido: Text; Nombre: Text; FechaNac: Date; var EmpleadoRelativo: Record "Employee Relative"): Boolean
    var
        Dni: Text;
        Candidatos: Integer;
    begin
        EmpleadoRelativo.Reset();
        EmpleadoRelativo.SetRange("Employee No.", NoEmpleado);

        if NroDoc <> '' then begin
            EmpleadoRelativo.SetRange("Nro. Documento", CopyStr(NroDoc, 1, MaxStrLen(EmpleadoRelativo."Nro. Documento")));
            if EmpleadoRelativo.FindFirst() then
                exit(true);
            Dni := DniDelDocumento(NroDoc);
            if Dni <> NroDoc then begin
                EmpleadoRelativo.SetRange("Nro. Documento", CopyStr(Dni, 1, MaxStrLen(EmpleadoRelativo."Nro. Documento")));
                if EmpleadoRelativo.FindFirst() then
                    exit(true);
            end;
            EmpleadoRelativo.SetRange("Nro. Documento");
        end;

        if FechaNac <> 0D then begin
            EmpleadoRelativo.SetRange("Birth Date", FechaNac);
            Candidatos := EmpleadoRelativo.Count();
            if Candidatos = 1 then begin
                EmpleadoRelativo.FindFirst();
                exit(true);
            end;
            EmpleadoRelativo.SetRange("Birth Date");
        end;

        EmpleadoRelativo.SetRange("First Family Name", CopyStr(Apellido, 1, 30));
        EmpleadoRelativo.SetRange(Name, CopyStr(Nombre, 1, 30));
        exit(EmpleadoRelativo.FindFirst());
    end;

    // El DNI de un documento de SIRADIG: si es un CUIL/CUIT de 11 dígitos, los 8 del medio; si no, tal cual.
    local procedure DniDelDocumento(NroDoc: Text): Text
    begin
        if (StrLen(NroDoc) = 11) and (CopyStr(NroDoc, 1, 1) = '2') then
            exit(CopyStr(NroDoc, 3, 8));
        exit(NroDoc);
    end;

    // LAS CARGAS DE FAMILIA. Un familiar que ya está en BC NO se pisa: sus datos vienen de Meta4 y de la
    // carga manual (código de parentesco, tipo y número de documento, tipo de deducción, fechas del
    // impuesto, % de deducción), y SIRADIG los escribe de otra forma (parentesco 3 en vez de H, el CUIL
    // en lugar del DNI). Sólo se completan los datos que falten. Un familiar nuevo se crea con los
    // códigos de BC, y queda SIN tipo de deducción ni fecha de alta del impuesto: no deduce hasta que
    // alguien se los cargue (ver familiar-alta-impuesto).
    local procedure ProcesarCargasFamiliaDelJson(var JsonText: Text; NoEmpleado: Code[20]; var RegistroImportacion: Record "Importación SIRADIG")
    var
        Empleado: Record Employee;
        EmpleadoRelativo: Record "Employee Relative";
        JsonArray: JsonArray;
        JsonObj: JsonObject;
        JsonToken: JsonToken;
        TipoDoc, NroDoc, Apellido, Nombre, FechaNacText, Parentesco : Text;
        FechaNac: Date;
        ValorAnterior: Text;
        EsNuevo: Boolean;
        Escrito: Boolean;
        Cambio: Boolean;
        CountCargasImportadas: Integer;
        LineNo: Integer;
        i: Integer;
    begin
        if not Empleado.Get(NoEmpleado) then
            exit;

        if not JsonArray.ReadFrom(JsonText) then
            exit;

        CountCargasImportadas := 0;

        // Obtener el siguiente número de línea
        EmpleadoRelativo.SetRange("Employee No.", NoEmpleado);
        if EmpleadoRelativo.FindLast() then
            LineNo := EmpleadoRelativo."Line No." + 10000
        else
            LineNo := 10000;

        for i := 0 to JsonArray.Count() - 1 do begin
            if JsonArray.Get(i, JsonToken) and JsonToken.IsObject() then begin
                JsonObj := JsonToken.AsObject();

                TipoDoc := ExtractJsonValue(JsonObj, 'tipoDoc');
                NroDoc := ExtractJsonValue(JsonObj, 'nroDoc');
                Apellido := ExtractJsonValue(JsonObj, 'apellido');
                Nombre := ExtractJsonValue(JsonObj, 'nombre');
                FechaNacText := ExtractJsonValue(JsonObj, 'fechaNac');
                Parentesco := ExtractJsonValue(JsonObj, 'parentesco');

                if (Apellido <> '') and (Nombre <> '') then begin
                    if not Evaluate(FechaNac, FechaNacText, 9) then
                        FechaNac := 0D;

                    EsNuevo := not EncontrarFamiliar(NoEmpleado, NroDoc, Apellido, Nombre, FechaNac, EmpleadoRelativo);
                    Cambio := false;
                    if EsNuevo then begin
                        EmpleadoRelativo.Init();
                        EmpleadoRelativo."Employee No." := NoEmpleado;
                        EmpleadoRelativo."Line No." := LineNo;
                        ValorAnterior := '';
                        EmpleadoRelativo.Name := CopyStr(Nombre, 1, 30);
                        EmpleadoRelativo."First Family Name" := CopyStr(Apellido, 1, 30);
                        Cambio := true;
                    end else
                        ValorAnterior := StrSubstNo('%1 %2', EmpleadoRelativo."First Family Name", EmpleadoRelativo.Name);

                    if (FechaNac <> 0D) and (EmpleadoRelativo."Birth Date" = 0D) then begin
                        EmpleadoRelativo."Birth Date" := FechaNac;
                        Cambio := true;
                    end;
                    if EmpleadoRelativo."Nro. Documento" = '' then begin
                        EmpleadoRelativo."Nro. Documento" := CopyStr(DniDelDocumento(NroDoc), 1, MaxStrLen(EmpleadoRelativo."Nro. Documento"));
                        Cambio := true;
                    end;
                    if (EmpleadoRelativo."Tipo Documento" = '') and (EmpleadoRelativo."Nro. Documento" <> '') then begin
                        // SIRADIG informa el CUIL del familiar (tipoDoc 80/86); BC lleva el DNI.
                        EmpleadoRelativo."Tipo Documento" := 'DNI';
                        Cambio := true;
                    end;
                    if EmpleadoRelativo."Relative Code" = '' then begin
                        EmpleadoRelativo."Relative Code" := MapearCodigoParentesco(Parentesco);
                        Cambio := true;
                    end;

                    Escrito := true;
                    if Cambio then
                        if EsNuevo then
                            Escrito := EmpleadoRelativo.Insert()
                        else
                            Escrito := EmpleadoRelativo.Modify();

                    if Escrito then begin
                        if Cambio then
                            AuditoriaAfip.RegistrarDetalle(
                                RegistroImportacion."AFIP Register Entry No.", Database::"Employee Relative", EmpleadoRelativo.FieldNo(Name),
                                TipoCambioFamiliar(EsNuevo), CopyStr(ValorAnterior, 1, 250),
                                StrSubstNo('%1 %2', EmpleadoRelativo."First Family Name", EmpleadoRelativo.Name),
                                StrSubstNo('%1|%2', EmpleadoRelativo."Employee No.", EmpleadoRelativo."Line No."));
                        CountCargasImportadas += 1;
                        if EsNuevo then
                            LineNo += 10000;
                    end;
                end;
            end;
        end;

        RegistroImportacion."Cargas Familia Importadas" := CountCargasImportadas;
    end;

    // SIRADIG identifica al empleado por CUIL, que es el número de seguridad social — por eso se
    // busca contra "Social Security No." y no contra "CIF/NIF" (ese guarda el CUIT, identificador
    // fiscal). El CUIL en "Importación SIRADIG" ya llega normalizado (solo dígitos), pero el
    // Empleado puede tenerlo cargado con guiones (23-28454586-9) o sin ellos (23284545869) según
    // cómo lo haya tipeado cada usuario; se prueban ambos formatos.
    local procedure EncontrarEmpleadoPorCuil(Cuil: Code[20]; var Empleado: Record Employee): Boolean
    var
        CuilConGuiones: Code[20];
    begin
        CuilConGuiones := FormatearCuilConGuiones(Cuil);

        // Camino rápido: match exacto por filtro, en los dos formatos habituales y en los dos campos
        // donde puede estar cargado el CUIL.
        if BuscarPorCampo(Empleado, Empleado.FieldNo("Social Security No."), Cuil, CuilConGuiones) then
            exit(true);
        if BuscarPorCampo(Empleado, Empleado.FieldNo("CIF/NIF"), Cuil, CuilConGuiones) then
            exit(true);

        // Último recurso: comparar normalizado (solo dígitos) recorriendo los empleados. Cubre
        // cualquier formato que el filtro exacto no contempla — espacios intercalados, puntos,
        // guiones en posiciones distintas, etc. Solo corre si todo lo anterior falló.
        exit(BuscarPorCuilNormalizado(Empleado, Cuil));
    end;

    local procedure BuscarPorCampo(var Empleado: Record Employee; NoCampo: Integer; Cuil: Code[20]; CuilConGuiones: Code[20]): Boolean
    var
        CampoFiltro: FieldRef;
        RegistroRef: RecordRef;
    begin
        RegistroRef.GetTable(Empleado);
        CampoFiltro := RegistroRef.Field(NoCampo);

        CampoFiltro.SetRange(Cuil);
        if RegistroRef.FindFirst() then begin
            RegistroRef.SetTable(Empleado);
            exit(true);
        end;

        if CuilConGuiones <> '' then begin
            CampoFiltro.SetRange(CuilConGuiones);
            if RegistroRef.FindFirst() then begin
                RegistroRef.SetTable(Empleado);
                exit(true);
            end;
        end;

        exit(false);
    end;

    local procedure BuscarPorCuilNormalizado(var Empleado: Record Employee; Cuil: Code[20]): Boolean
    var
        GestorArchivos: Codeunit "Gestor Archivos SIRADIG";
    begin
        Empleado.Reset();
        if Empleado.FindSet() then
            repeat
                if (GestorArchivos.NormalizarCuil(Empleado."Social Security No.") = Cuil) or
                   (GestorArchivos.NormalizarCuil(Empleado."CIF/NIF") = Cuil)
                then
                    exit(true);
            until Empleado.Next() = 0;

        Empleado.Reset();
        exit(false);
    end;

    local procedure FormatearCuilConGuiones(Cuil: Code[20]): Code[20]
    begin
        if StrLen(Cuil) <> 11 then
            exit('');
        exit(CopyStr(Cuil, 1, 2) + '-' + CopyStr(Cuil, 3, 8) + '-' + CopyStr(Cuil, 11, 1));
    end;

    local procedure ValidarTipoDeduccionSiradig(TipoDeduccion: Text): Boolean
    begin
        case TipoDeduccion of
            '1', '2', '3', '4', '5', '7', '8', '9', '10', '11', '21', '22', '23', '24', '25', '32', '33', '34', '99':
                exit(true);
            else
                exit(false);
        end;
    end;

    // El código de parentesco de un familiar NUEVO. La tabla Relative ya trae los códigos de SIRADIG
    // (1, 3, 30, 31, 32, 103) además de los propios (C, CC, H, HI...): si el de SIRADIG existe, se usa; el
    // 51 (conviviente) no está y equivale al CC que ya llevan los familiares cargados. Cualquier otro,
    // "Otros". Los familiares que ya estaban no se tocan: conservan su código.
    local procedure MapearCodigoParentesco(CodigoSiradig: Text): Code[10]
    var
        Parentesco: Record Relative;
    begin
        if (CodigoSiradig <> '') and Parentesco.Get(CopyStr(CodigoSiradig, 1, MaxStrLen(Parentesco.Code))) then
            exit(Parentesco.Code);
        if CodigoSiradig = '51' then
            exit('CC');
        exit('O');
    end;
    local procedure ExtractJsonValue(var JsonObj: JsonObject; PropName: Text): Text
    var
        JsonToken: JsonToken;
    begin
        if JsonObj.Get(PropName, JsonToken) then
            exit(JsonToken.AsValue().AsText());
        exit('');
    end;
}
