namespace UAS.Payroll;

using System.IO;

codeunit 50022 "Parser SIRADIG XML"
{
    Access = Internal;

    var
        ErrorXmlInvalido: Label 'El archivo XML no tiene estructura válida de SIRADIG: %1';
        ErrorCuilNoEncontrado: Label 'No se encontró CUIL en el elemento empleado';

    procedure ExtraerDatosDelXml(var ArchivoXmlPath: Text; var DatosExtraidos: Record "Importación SIRADIG")
    var
        XmlContent: Text;
    begin
        if not File.Exists(ArchivoXmlPath) then
            Error('El archivo XML no existe: %1', ArchivoXmlPath);

        XmlContent := ReadFileAsText(ArchivoXmlPath);

        if XmlContent = '' then
            Error(ErrorXmlInvalido, 'Archivo vacío');

        if not XmlContent.Contains('<presentacion') then
            Error(ErrorXmlInvalido, 'Elemento raíz debe ser "presentacion"');

        ExtractPresentacionData(XmlContent, DatosExtraidos);
    end;

    procedure ObtenerDeduccionesDelXml(var ArchivoXmlPath: Text): Text
    var
        XmlContent: Text;
    begin
        if not File.Exists(ArchivoXmlPath) then
            exit('[]');

        XmlContent := ReadFileAsText(ArchivoXmlPath);
        exit(ExtractDeduccionesJson(XmlContent));
    end;

    procedure ObtenerCargasFamiliaDelXml(var ArchivoXmlPath: Text): Text
    var
        XmlContent: Text;
    begin
        if not File.Exists(ArchivoXmlPath) then
            exit('[]');

        XmlContent := ReadFileAsText(ArchivoXmlPath);
        exit(ExtractCargasJson(XmlContent));
    end;

    local procedure ReadFileAsText(var FilePath: Text): Text
    var
        FileObject: File;
        InStream: InStream;
        TextContent: Text;
        Char: Char;
    begin
        if FileObject.Open(FilePath) then begin
            FileObject.CreateInStream(InStream);
            while InStream.Read(Char) > 0 do
                TextContent += Format(Char);
            FileObject.Close();
        end;
        exit(TextContent);
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
            if Evaluate(DatosExtraidos."Período", Periodo) then ;

        // Extraer número de presentación
        NroPresentacion := ExtractXmlValue(XmlContent, 'nroPresentacion');
        if NroPresentacion <> '' then
            if Evaluate(DatosExtraidos."Nro. Presentación", NroPresentacion) then ;

        // Extraer fecha de presentación
        FechaPresentacion := ExtractXmlValue(XmlContent, 'fechaPresentacion');
        if FechaPresentacion <> '' then
            if Evaluate(DatosExtraidos."Fecha Presentación", FechaPresentacion) then ;

        // Extraer CUIL
        CuilValue := ExtractXmlValue(XmlContent, 'cuit');
        if CuilValue <> '' then
            DatosExtraidos."CUIL Empleado" := CopyStr(CuilValue, 1, 20)
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

            if JsonText <> '[' then
                JsonText += ',';
            JsonText += StrSubstNo('{"tipo":%1,"monto":%2}', TipoValue, MontoValue);

            SearchPos := EndPos + 12;
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
        TipoDoc, NroDoc, Apellido, Nombre, FechaNac, Parentesco: Text;
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
