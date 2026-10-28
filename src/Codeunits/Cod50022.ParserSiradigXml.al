namespace UAS.Payroll;

codeunit 50022 "Parser SIRADIG XML"
{
    Access = Internal;

    var
        GestorArchivos: Codeunit "Gestor Archivos SIRADIG";
        ErrorXmlInvalido: Label 'El archivo XML no tiene estructura válida de SIRADIG: %1';
        ErrorCuilNoEncontrado: Label 'No se encontró CUIL en el elemento empleado';

    procedure ExtraerDatosDelXml(var XmlContent: Text; var DatosExtraidos: Record "Importación SIRADIG")
    begin
        if XmlContent = '' then
            Error(ErrorXmlInvalido, 'Archivo vacío');

        if not XmlContent.Contains('<presentacion') then
            Error(ErrorXmlInvalido, 'Elemento raíz debe ser "presentacion"');

        ExtractPresentacionData(XmlContent, DatosExtraidos);
    end;

    procedure ObtenerDeduccionesDelXml(var XmlContent: Text): Text
    begin
        exit(ExtractDeduccionesJson(XmlContent));
    end;

    procedure ObtenerCargasFamiliaDelXml(var XmlContent: Text): Text
    begin
        exit(ExtractCargasJson(XmlContent));
    end;

    local procedure ExtractPresentacionData(var XmlContent: Text; var DatosExtraidos: Record "Importación SIRADIG")
    var
        Periodo: Text;
        NroPresentacion: Text;
        FechaPresentacion: Text;
        CuilValue: Text;
    begin
        // Extraer período
        Periodo := ExtractXmlValue(XmlContent, 'periodo');
        if Periodo <> '' then
            if Evaluate(DatosExtraidos."Período", Periodo) then;

        // Extraer número de presentación
        NroPresentacion := ExtractXmlValue(XmlContent, 'nroPresentacion');
        if NroPresentacion <> '' then
            if Evaluate(DatosExtraidos."Nro. Presentación", NroPresentacion) then;

        // Extraer fecha de presentación
        FechaPresentacion := ExtractXmlValue(XmlContent, 'fechaPresentacion');
        if FechaPresentacion <> '' then
            if Evaluate(DatosExtraidos."Fecha Presentación", FechaPresentacion) then;

        // Extraer CUIL (puede venir con guiones, 23-28454586-9, o sin guiones, 23284545869;
        // se normaliza a solo dígitos para que coincida con el valor tomado del nombre de archivo)
        CuilValue := ExtractXmlValue(XmlContent, 'cuit');
        if CuilValue <> '' then
            DatosExtraidos."CUIL Empleado" := GestorArchivos.NormalizarCuil(CuilValue)
        else
            Error(ErrorCuilNoEncontrado);

        // Contar deducciones
        DatosExtraidos."Deducciones Importadas" := CountXmlElements(XmlContent, 'deduccion');

        // Contar cargas de familia
        DatosExtraidos."Cargas Familia Importadas" := CountXmlElements(XmlContent, 'cargaFamilia');
    end;

    local procedure ExtractDeduccionesJson(var XmlContent: Text): Text
    var
        JsonText: Text;
        SearchPos: Integer;
        StartPos: Integer;
        EndPos: Integer;
        DeduccionText: Text;
        TipoValue: Text;
        MontoValue: Text;
    begin
        JsonText := '[';
        SearchPos := 1;

        while true do begin
            StartPos := XmlContent.IndexOf('<deduccion ', SearchPos);
            if StartPos = 0 then
                break;

            EndPos := XmlContent.IndexOf('</deduccion>', StartPos);
            if EndPos = 0 then
                break;

            DeduccionText := XmlContent.Substring(StartPos, EndPos - StartPos + 12);

            TipoValue := ExtractAttributeValue(DeduccionText, 'tipo');
            MontoValue := ExtractXmlValue(DeduccionText, 'montoTotal');

            if MontoValue = '' then
                MontoValue := '0';
            if JsonText <> '[' then
                JsonText += ',';
            JsonText += StrSubstNo('{"tipo":%1,"monto":%2,"descripcion":"%3","periodos":%4}',
                TipoValue, MontoValue, EscaparJson(DescripcionDeduccion(DeduccionText)), ExtractPeriodosJson(DeduccionText));

            SearchPos := EndPos + 12;
        end;

        JsonText += ']';
        exit(JsonText);
    end;

    // A quién o a qué corresponde la deducción: "<CUIT> - <proveedor>" (descBasica) y, en el gasto educativo, el
    // familiar que va en <detalle nombre="apellidoNombreFamiliar" valor="..."/>. El nroDoc/denominacion del
    // <deduccion> es el del proveedor y no el de un familiar: no sirve para vincular con Employee Relative.
    local procedure DescripcionDeduccion(var DeduccionText: Text): Text
    var
        Descripcion: Text;
        Familiar: Text;
        Pos: Integer;
        Etiqueta: Text;
    begin
        Descripcion := DesescaparXml(ExtractXmlValue(DeduccionText, 'descBasica'));
        Etiqueta := 'nombre="apellidoNombreFamiliar"';
        Pos := DeduccionText.IndexOf(Etiqueta);
        if Pos > 0 then begin
            Familiar := DeduccionText.Substring(Pos);
            if Familiar.IndexOf('/>') > 0 then
                Familiar := Familiar.Substring(1, Familiar.IndexOf('/>'));
            Familiar := DesescaparXml(ExtractAttributeValue(Familiar, 'valor'));
            if Familiar <> '' then
                if Descripcion = '' then
                    Descripcion := Familiar
                else
                    Descripcion += ' · ' + Familiar;
        end;
        exit(Descripcion);
    end;

    local procedure DesescaparXml(Texto: Text): Text
    begin
        exit(Texto.Replace('&quot;', '"').Replace('&apos;', '''').Replace('&lt;', '<').Replace('&gt;', '>').Replace('&amp;', '&'));
    end;

    local procedure EscaparJson(Texto: Text): Text
    begin
        exit(Texto.Replace('\', '\\').Replace('"', '\"'));
    end;

    // El detalle mensual de una deducción: <periodo mesDesde="1" mesHasta="12" montoMensual="45000"/>.
    // "montoTotal" es la suma de todos los meses; lo que el motor necesita es el importe de cada mes.
    local procedure ExtractPeriodosJson(var DeduccionText: Text): Text
    var
        JsonText: Text;
        SearchPos: Integer;
        StartPos: Integer;
        EndPos: Integer;
        PeriodoText: Text;
        MesDesde: Text;
        MesHasta: Text;
        Monto: Text;
    begin
        JsonText := '[';
        SearchPos := 1;

        while true do begin
            // Con el espacio: "<periodos>" también empieza con "<periodo".
            StartPos := DeduccionText.IndexOf('<periodo ', SearchPos);
            if StartPos = 0 then
                break;

            EndPos := DeduccionText.IndexOf('/>', StartPos);
            if EndPos = 0 then
                break;

            PeriodoText := DeduccionText.Substring(StartPos, EndPos - StartPos + 2);
            MesDesde := ExtractAttributeValue(PeriodoText, 'mesDesde');
            MesHasta := ExtractAttributeValue(PeriodoText, 'mesHasta');
            Monto := ExtractAttributeValue(PeriodoText, 'montoMensual');
            if MesDesde = '' then
                MesDesde := '0';
            if MesHasta = '' then
                MesHasta := '0';
            if Monto = '' then
                Monto := '0';

            if JsonText <> '[' then
                JsonText += ',';
            JsonText += StrSubstNo('{"d":%1,"h":%2,"m":%3}', MesDesde, MesHasta, Monto);

            SearchPos := EndPos + 2;
        end;

        JsonText += ']';
        exit(JsonText);
    end;

    local procedure ExtractCargasJson(var XmlContent: Text): Text
    var
        JsonText: Text;
        SearchPos: Integer;
        StartPos: Integer;
        EndPos: Integer;
        CargaText: Text;
        TipoDoc, NroDoc, Apellido, Nombre, FechaNac, Parentesco : Text;
    begin
        JsonText := '[';
        SearchPos := 1;

        while true do begin
            StartPos := XmlContent.IndexOf('<cargaFamilia>', SearchPos);
            if StartPos = 0 then
                break;

            EndPos := XmlContent.IndexOf('</cargaFamilia>', StartPos);
            if EndPos = 0 then
                break;

            CargaText := XmlContent.Substring(StartPos, EndPos - StartPos + 15);

            TipoDoc := ExtractXmlValue(CargaText, 'tipoDoc');
            NroDoc := ExtractXmlValue(CargaText, 'nroDoc');
            Apellido := ExtractXmlValue(CargaText, 'apellido');
            Nombre := ExtractXmlValue(CargaText, 'nombre');
            FechaNac := ExtractXmlValue(CargaText, 'fechaNac');
            Parentesco := ExtractXmlValue(CargaText, 'parentesco');

            if JsonText <> '[' then
                JsonText += ',';
            JsonText += StrSubstNo('{"tipoDoc":"%1","nroDoc":"%2","apellido":"%3","nombre":"%4","fechaNac":"%5","parentesco":"%6"}',
                TipoDoc, NroDoc, Apellido, Nombre, FechaNac, Parentesco);

            SearchPos := EndPos + 15;
        end;

        JsonText += ']';
        exit(JsonText);
    end;

    local procedure ExtractXmlValue(var XmlText: Text; ElementName: Text): Text
    var
        StartTag: Text;
        EndTag: Text;
        StartPos: Integer;
        EndPos: Integer;
        ValueText: Text;
    begin
        StartTag := '<' + ElementName + '>';
        EndTag := '</' + ElementName + '>';

        StartPos := XmlText.IndexOf(StartTag);
        if StartPos = 0 then
            exit('');

        EndPos := XmlText.IndexOf(EndTag);
        if EndPos = 0 then
            exit('');

        ValueText := XmlText.Substring(StartPos + StrLen(StartTag), EndPos - StartPos - StrLen(StartTag));
        exit(ValueText.Trim());
    end;

    local procedure ExtractAttributeValue(var XmlText: Text; AttributeName: Text): Text
    var
        Pattern: Text;
        StartPos: Integer;
        EndPos: Integer;
        ValueText: Text;
    begin
        Pattern := AttributeName + '="';
        StartPos := XmlText.IndexOf(Pattern);
        if StartPos = 0 then
            exit('');

        StartPos += StrLen(Pattern);
        EndPos := XmlText.IndexOf('"', StartPos);
        if EndPos = 0 then
            exit('');

        ValueText := XmlText.Substring(StartPos, EndPos - StartPos);
        exit(ValueText.Trim());
    end;

    local procedure CountXmlElements(var XmlContent: Text; ElementName: Text): Integer
    var
        Count: Integer;
        StartTag: Text;
        StartPos: Integer;
    begin
        StartTag := '<' + ElementName;
        Count := 0;
        StartPos := 1;

        while true do begin
            StartPos := XmlContent.IndexOf(StartTag, StartPos);
            if StartPos = 0 then
                break;
            Count += 1;
            StartPos += StrLen(StartTag);
        end;

        exit(Count);
    end;
}
