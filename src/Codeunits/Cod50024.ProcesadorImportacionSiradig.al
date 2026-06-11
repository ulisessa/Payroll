namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

codeunit 50024 "Procesador Importación SIRADIG"
{
    Caption = 'Procesador Importación SIRADIG';
    Access = Internal;

    var
        ErrorEmpleadoNoEncontrado: Label 'No se encontró empleado con CUIL: %1';
        ErrorDeduccionInvalida: Label 'Código de deducción SIRADIG no válido: %1';
        WarningDeduccionIgnorada: Label 'Deducción tipo %1 no será importada (tipo no soportado)';
        MsgProcesadoExitosamente: Label 'Importación procesada exitosamente. %1 deducciones, %2 cargas familiares.';
        ParserSiradig: Codeunit "Parser SIRADIG XML";

    procedure ProcesarImportacionSiradig(var RegistroImportacion: Record "Importación SIRADIG"; var RutaXml: Text)
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
        DeduccionesJson := ParserSiradig.ObtenerDeduccionesDelXml(RutaXml);
        ProcesarDeduccionesDelJson(DeduccionesJson, RegistroImportacion."No. Empleado", RegistroImportacion);

        // Procesar cargas de familia
        CargasJson := ParserSiradig.ObtenerCargasFamiliaDelXml(RutaXml);
        ProcesarCargasFamiliaDelJson(CargasJson, RegistroImportacion."No. Empleado", RegistroImportacion);

        // Marcar como procesado
        RegistroImportacion.Estado := "Estado Importación SIRADIG"::"Procesado Exitosamente";
        RegistroImportacion."Fecha Importación" := CurrentDateTime();
        RegistroImportacion."Usuario Importación" := CopyStr(UserId(), 1, 50);
        RegistroImportacion.Modify();

        Message(MsgProcesadoExitosamente,
            RegistroImportacion."Deducciones Importadas",
            RegistroImportacion."Cargas Familia Importadas");
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
        i: Integer;
        CountDeduccionesImportadas: Integer;
    begin
        if not JsonArray.ReadFrom(JsonText) then
            exit;

        CountDeduccionesImportadas := 0;

        for i := 0 to JsonArray.Length() - 1 do begin
            if not JsonArray.Get(i, JsonToken) then
                continue;

            if not JsonToken.IsObject() then
                continue;

            JsonObj := JsonToken.AsObject();

            TipoDeduccion := ExtractJsonValue(JsonObj, 'tipo');
            Monto := ExtractJsonValue(JsonObj, 'monto');

            if (TipoDeduccion = '') or (Monto = '') then
                continue;

            if not Evaluate(MontoDecimal, Monto) then
                MontoDecimal := 0;

            if ValidarTipoDeduccionSiradig(TipoDeduccion) then begin
                DedGananciasEmp.SetRange("No. Empleado", NoEmpleado);
                DedGananciasEmp.SetRange("Cód. Tipo", TipoDeduccion);
                if DedGananciasEmp.FindFirst() then begin
                    DedGananciasEmp."Importe Fijo" := MontoDecimal;
                    DedGananciasEmp.Modify();
                end else begin
                    DedGananciasEmp.Init();
                    DedGananciasEmp."No. Empleado" := NoEmpleado;
                    DedGananciasEmp."Vigencia Desde" := Today();
                    DedGananciasEmp."Cód. Tipo" := CopyStr(TipoDeduccion, 1, 5);
                    DedGananciasEmp."Importe Fijo" := MontoDecimal;
                    if DedGananciasEmp.Insert() then ;
                end;
                CountDeduccionesImportadas += 1;
            end;
        end;

        RegistroImportacion."Deducciones Importadas" := CountDeduccionesImportadas;
    end;

    local procedure ProcesarCargasFamiliaDelJson(var JsonText: Text; NoEmpleado: Code[20]; var RegistroImportacion: Record "Importación SIRADIG")
    var
        Empleado: Record Employee;
        EmpleadoRelativo: Record "Employee Relative";
        JsonArray: JsonArray;
        JsonObj: JsonObject;
        JsonToken: JsonToken;
        TipoDoc, NroDoc, Apellido, Nombre, FechaNacText, Parentesco: Text;
        FechaNac: Date;
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

        for i := 0 to JsonArray.Length() - 1 do begin
            if not JsonArray.Get(i, JsonToken) then
                continue;

            if not JsonToken.IsObject() then
                continue;

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

                EmpleadoRelativo.Init();
                EmpleadoRelativo."Employee No." := NoEmpleado;
                EmpleadoRelativo."Line No." := LineNo;
                EmpleadoRelativo."First Name" := CopyStr(Nombre, 1, 30);
                EmpleadoRelativo."Last Name" := CopyStr(Apellido, 1, 30);
                if FechaNac <> 0D then
                    EmpleadoRelativo."Date of Birth" := FechaNac;

                EmpleadoRelativo."Relationship Code" := CopyStr(MapearCodigoParentesco(Parentesco), 1, 10);

                if EmpleadoRelativo.Insert() then
                    CountCargasImportadas += 1;

                LineNo += 10000;
            end;
        end;

        RegistroImportacion."Cargas Familia Importadas" := CountCargasImportadas;
    end;

    local procedure EncontrarEmpleadoPorCuil(Cuil: Code[20]; var Empleado: Record Employee): Boolean
    begin
        Empleado.SetRange("Social Security No.", Cuil);
        if Empleado.FindFirst() then
            exit(true);

        Empleado.Reset();
        exit(false);
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

    local procedure ExtractJsonValue(var JsonObj: JsonObject; Key: Text): Text
    var
        JsonToken: JsonToken;
    begin
        if JsonObj.Get(Key, JsonToken) then
            exit(JsonToken.AsValue().AsText());
        exit('');
    end;
}
