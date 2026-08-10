namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

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

    // Silencia el mensaje por registro: lo usan los procesos por lote, que informan un único
    // resumen al final en vez de un cuadro de diálogo por archivo.
    procedure SetSilencioso(Valor: Boolean)
    begin
        FSilencioso := Valor;
    end;

    local procedure ProcesarDeduccionesDelJson(var JsonText: Text; NoEmpleado: Code[20]; var RegistroImportacion: Record "Importación SIRADIG")
    var
        DedGananciasEmp: Record "Ded. Ganancias Empleado";
        JsonObj: JsonObject;
        JsonArray: JsonArray;
        JsonToken: JsonToken;
        TipoDeduccion: Text;
        Monto: Text;
        MontoDecimal: Decimal;
        MontoAnterior: Decimal;
        EsNuevo: Boolean;
        i: Integer;
        CountDeduccionesImportadas: Integer;
    begin
        if not JsonArray.ReadFrom(JsonText) then
            exit;

        CountDeduccionesImportadas := 0;

        for i := 0 to JsonArray.Count() - 1 do begin
            if JsonArray.Get(i, JsonToken) and JsonToken.IsObject() then begin
                JsonObj := JsonToken.AsObject();

                TipoDeduccion := ExtractJsonValue(JsonObj, 'tipo');
                Monto := ExtractJsonValue(JsonObj, 'monto');

                if (TipoDeduccion <> '') and (Monto <> '') then begin
                    if not Evaluate(MontoDecimal, Monto) then
                        MontoDecimal := 0;

                    if ValidarTipoDeduccionSiradig(TipoDeduccion) then begin
                        DedGananciasEmp.SetRange("No. Empleado", NoEmpleado);
                        DedGananciasEmp.SetRange("Cód. Tipo", TipoDeduccion);
                        EsNuevo := not DedGananciasEmp.FindFirst();
                        if not EsNuevo then begin
                            MontoAnterior := DedGananciasEmp."Importe Fijo";
                            DedGananciasEmp."Importe Fijo" := MontoDecimal;
                            DedGananciasEmp.Modify();
                        end else begin
                            MontoAnterior := 0;
                            DedGananciasEmp.Init();
                            DedGananciasEmp."No. Empleado" := NoEmpleado;
                            DedGananciasEmp."Vigencia Desde" := Today();
                            DedGananciasEmp."Cód. Tipo" := CopyStr(TipoDeduccion, 1, 5);
                            DedGananciasEmp."Importe Fijo" := MontoDecimal;
                            if DedGananciasEmp.Insert() then;
                        end;

                        RegistrarDetalleDeduccion(RegistroImportacion."AFIP Register Entry No.", DedGananciasEmp, EsNuevo, MontoAnterior, MontoDecimal);

                        CountDeduccionesImportadas += 1;
                    end;
                end;
            end;
        end;

        RegistroImportacion."Deducciones Importadas" := CountDeduccionesImportadas;
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
            StrSubstNo('%1|%2', DedGananciasEmp."No. Empleado", DedGananciasEmp."Cód. Tipo"));
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

    // Busca una carga de familia ya cargada para el empleado. El número de documento es la clave
    // confiable entre presentaciones; si SIRADIG no lo informa se cae a apellido+nombre, que es lo
    // único que queda para no duplicar (aunque sea más frágil ante diferencias de tipeo).
    local procedure EncontrarFamiliar(NoEmpleado: Code[20]; NroDoc: Text; Apellido: Text; Nombre: Text; var EmpleadoRelativo: Record "Employee Relative"): Boolean
    begin
        EmpleadoRelativo.Reset();
        EmpleadoRelativo.SetRange("Employee No.", NoEmpleado);

        if NroDoc <> '' then begin
            EmpleadoRelativo.SetRange("Nro. Documento", CopyStr(NroDoc, 1, MaxStrLen(EmpleadoRelativo."Nro. Documento")));
            if EmpleadoRelativo.FindFirst() then
                exit(true);
            EmpleadoRelativo.SetRange("Nro. Documento");
        end;

        EmpleadoRelativo.SetRange("First Family Name", CopyStr(Apellido, 1, 30));
        EmpleadoRelativo.SetRange(Name, CopyStr(Nombre, 1, 30));
        exit(EmpleadoRelativo.FindFirst());
    end;

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
                    if not Evaluate(FechaNac, FechaNacText) then
                        FechaNac := 0D;

                    // Reimportar la misma presentación (o una posterior) no debe duplicar la carga:
                    // si ya existe se reemplaza conservando su No. de línea y los datos impositivos
                    // cargados a mano (Cód. Tipo Ded., fechas, % Deducción), que SIRADIG no informa.
                    EsNuevo := not EncontrarFamiliar(NoEmpleado, NroDoc, Apellido, Nombre, EmpleadoRelativo);
                    if EsNuevo then begin
                        EmpleadoRelativo.Init();
                        EmpleadoRelativo."Employee No." := NoEmpleado;
                        EmpleadoRelativo."Line No." := LineNo;
                        ValorAnterior := '';
                    end else
                        ValorAnterior := StrSubstNo('%1 %2', EmpleadoRelativo."First Family Name", EmpleadoRelativo.Name);

                    EmpleadoRelativo.Name := CopyStr(Nombre, 1, 30);
                    EmpleadoRelativo."First Family Name" := CopyStr(Apellido, 1, 30);
                    if FechaNac <> 0D then
                        EmpleadoRelativo."Birth Date" := FechaNac;
                    EmpleadoRelativo."Tipo Documento" := CopyStr(TipoDoc, 1, MaxStrLen(EmpleadoRelativo."Tipo Documento"));
                    EmpleadoRelativo."Nro. Documento" := CopyStr(NroDoc, 1, MaxStrLen(EmpleadoRelativo."Nro. Documento"));

                    EmpleadoRelativo."Relative Code" := MapearCodigoParentesco(Parentesco);

                    if EsNuevo then
                        Escrito := EmpleadoRelativo.Insert()
                    else
                        Escrito := EmpleadoRelativo.Modify();

                    if Escrito then begin
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

    local procedure MapearCodigoParentesco(CodigoSiradig: Text): Code[10]
    begin
        exit(CopyStr(CodigoSiradig, 1, 10));
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
