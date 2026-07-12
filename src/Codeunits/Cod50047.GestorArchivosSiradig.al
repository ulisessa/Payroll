namespace UAS.Payroll;

using System.IO;

codeunit 50023 "Gestor Archivos SIRADIG"
{
    Caption = 'Gestor Archivos SIRADIG';
    Access = Internal;

    var
        ErrorCarpetaNoExiste: Label 'La carpeta especificada no existe: %1';
        ErrorNombreArchivoInvalido: Label 'El nombre del archivo no cumple el formato esperado CUIL_PERIODO_presentacion_NRO.xml.zip';
        ErrorExtractionFailed: Label 'Error al descomprimir el archivo ZIP: %1. Si es posible, descomprima manualmente el archivo ZIP en una carpeta temporal y utilice la ruta al archivo .xml';
        WarningExtractionManual: Label 'No se pudo extraer automáticamente el ZIP. Descomprima manualmente el archivo en una carpeta temporal e indique la ruta al archivo XML extraído.';

    procedure BuscarArchivosZip(var CarpetaOrigen: Text) ArchivosEncontrados: List of [Text]
    var
        DirInfo: DirectoryInfo;
        FileInfo: FileInfo;
    begin
        Clear(ArchivosEncontrados);

        if not Directory.Exists(CarpetaOrigen) then
            Error(ErrorCarpetaNoExiste, CarpetaOrigen);

        DirInfo := DirectoryInfo.DirectoryInfo(CarpetaOrigen);

        foreach FileInfo in DirInfo.GetFiles('*.xml.zip') do begin
            if ValidarPatronNombreArchivo(FileInfo.Name) then
                ArchivosEncontrados.Add(FileInfo.FullName);
        end;
        exit(ArchivosEncontrados);
    end;

    procedure BuscarArchivosXml(var CarpetaOrigen: Text) ArchivosEncontrados: List of [Text]
    var
        DirInfo: DirectoryInfo;
        FileInfo: FileInfo;
    begin
        Clear(ArchivosEncontrados);

        if not Directory.Exists(CarpetaOrigen) then
            Error(ErrorCarpetaNoExiste, CarpetaOrigen);

        DirInfo := DirectoryInfo.DirectoryInfo(CarpetaOrigen);

        foreach FileInfo in DirInfo.GetFiles('*.xml') do
            ArchivosEncontrados.Add(FileInfo.FullName);

        exit(ArchivosEncontrados);
    end;

    procedure ExtraerCuilDelNombreArchivo(var NombreArchivo: Text) Cuil: Code[20]
    var
        CuilValue: Text;
    begin
        // Formato esperado: CUIL_PERIODO_presentacion_NRO.xml.zip o CUIL_PERIODO_presentacion_NRO.xml
        // Ej: 20666666667_2024_presentacion_001.xml.zip

        if not (ValidarPatronNombreArchivo(NombreArchivo) or ValidarPatronNombreArchivoXml(NombreArchivo)) then
            Error(ErrorNombreArchivoInvalido);

        // Extraer la primera parte (CUIL)
        CuilValue := ExtractPartFromFilename(NombreArchivo, 1);
        exit(CopyStr(CuilValue, 1, 20));
    end;

    procedure DescomprimirArchivoZip(var RutaZip: Text; var RutaCarpetaTemporal: Text) RutaXmlExtraido: Text
    var
        NombreArchivoXml: Text;
        RutaDestino: Text;
    begin
        if not File.Exists(RutaZip) then
            Error('El archivo ZIP no existe: %1', RutaZip);

        // Crear carpeta temporal si no existe
        if not Directory.Exists(RutaCarpetaTemporal) then
            Directory.CreateDirectory(RutaCarpetaTemporal);

        // Intenta extraer usando el método nativo
        NombreArchivoXml := IntentarExtraerZip(RutaZip, RutaCarpetaTemporal);

        if NombreArchivoXml <> '' then begin
            RutaDestino := Path.Combine(RutaCarpetaTemporal, NombreArchivoXml);
            if File.Exists(RutaDestino) then
                exit(RutaDestino);
        end;

        // Si la extracción automática falla, solicitar archivo manual
        Error(ErrorExtractionFailed, 'Ver documentación para descomprimir manualmente');
    end;

    procedure ObtenerCarpetaTemporal() RutaTemporal: Text
    var
        GuidValue: Guid;
    begin
        GuidValue := CreateGuid();
        RutaTemporal := Path.Combine(
            Path.GetTempPath(),
            'SIRADIG_' + DelChr(Format(GuidValue), '=', '{}-')
        );
    end;

    procedure LimpiarCarpetaTemporal(var RutaCarpeta: Text)
    begin
        if Directory.Exists(RutaCarpeta) then
            Directory.Delete(RutaCarpeta, true);
    end;

    local procedure ValidarPatronNombreArchivo(NombreArchivo: Text): Boolean
    var
        i: Integer;
        UnderscoreCount: Integer;
        Char: Char;
    begin
        // Esperado: CUIL_PERIODO_presentacion_NRO.xml.zip
        if not NombreArchivo.EndsWith('.xml.zip') then
            exit(false);

        // Contar guiones bajos (debe haber al menos 3)
        UnderscoreCount := 0;
        for i := 1 to StrLen(NombreArchivo) do begin
            if NombreArchivo[i] = '_' then
                UnderscoreCount += 1;
        end;

        if UnderscoreCount < 3 then
            exit(false);

        // Validar que la primera parte es numérica y de 11 caracteres (CUIL)
        exit(IsNumeric(ExtractPartFromFilename(NombreArchivo, 1)) and StrLen(ExtractPartFromFilename(NombreArchivo, 1)) = 11);
    end;

    local procedure ValidarPatronNombreArchivoXml(NombreArchivo: Text): Boolean
    var
        i: Integer;
        UnderscoreCount: Integer;
        Char: Char;
    begin
        // Esperado: CUIL_PERIODO_presentacion_NRO.xml (sin .zip)
        if not NombreArchivo.EndsWith('.xml') then
            exit(false);

        UnderscoreCount := 0;
        for i := 1 to StrLen(NombreArchivo) do begin
            if NombreArchivo[i] = '_' then
                UnderscoreCount += 1;
        end;

        if UnderscoreCount < 3 then
            exit(false);

        exit(IsNumeric(ExtractPartFromFilename(NombreArchivo, 1)) and StrLen(ExtractPartFromFilename(NombreArchivo, 1)) = 11);
    end;

    local procedure ExtractPartFromFilename(NombreArchivo: Text; PartNumber: Integer): Text
    var
        i: Integer;
        PartIndex: Integer;
        Char: Char;
        PartValue: Text;
    begin
        PartIndex := 1;
        PartValue := '';

        for i := 1 to StrLen(NombreArchivo) do begin
            Char := NombreArchivo[i];
            if Char = '_' then begin
                if PartIndex = PartNumber then
                    exit(PartValue);
                PartIndex += 1;
                PartValue := '';
            end else if (Char <> '.') then begin
                PartValue += Format(Char);
            end else begin
                if PartIndex = PartNumber then
                    exit(PartValue);
            end;
        end;

        if PartIndex = PartNumber then
            exit(PartValue);
        exit('');
    end;

    local procedure IsNumeric(Value: Text): Boolean
    var
        i: Integer;
        Char: Char;
    begin
        if Value = '' then
            exit(false);
        for i := 1 to StrLen(Value) do begin
            Char := Value[i];
            if (Char < '0') or (Char > '9') then
                exit(false);
        end;
        exit(true);
    end;

    local procedure IntentarExtraerZip(var RutaZip: Text; var RutaDestino: Text): Text
    var
        TempBlob: Codeunit "Temp Blob";
        FileInStream: InStream;
        XmlFileName: Text;
    begin
        // Attempt 1: Try using Temp Blob if available
        begin
            // This is a placeholder - Temp Blob may not be available
            // If it is, it would handle ZIP extraction
        end;

        // If all else fails, return empty and let caller handle manually
        exit('');
    end;
}
