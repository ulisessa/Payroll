namespace UAS.Payroll;

using System.IO;
using System.Utilities;
using Microsoft.Utilities;

codeunit 50047 "Gestor Archivos SIRADIG"
{
    Access = Internal;

    var
        ErrorCarpetaNoExiste: Label 'La carpeta especificada no existe: %1';
        ErrorNombreArchivoInvalido: Label 'El nombre del archivo no cumple el formato esperado CUIL_PERIODO_presentacion_NRO.xml.zip';
        ErrorSinXmlEnZip: Label 'No se encontró ningún archivo .xml dentro del ZIP: %1';

    procedure BuscarArchivosZip(var CarpetaOrigen: Text) ArchivosEncontrados: List of [Text]
    var
        FileMgt: Codeunit "File Management";
        TempNameValueBuffer: Record "Name/Value Buffer" temporary;
    begin
        Clear(ArchivosEncontrados);

        if not FileMgt.ServerDirectoryExists(CarpetaOrigen) then
            Error(ErrorCarpetaNoExiste, CarpetaOrigen);

        FileMgt.GetServerDirectoryFilesList(TempNameValueBuffer, CarpetaOrigen);
        if TempNameValueBuffer.FindSet() then
            repeat
                if TempNameValueBuffer.Name.EndsWith('.xml.zip') then
                    if ValidarPatronNombreArchivo(FileMgt.GetFileName(TempNameValueBuffer.Name)) then
                        ArchivosEncontrados.Add(TempNameValueBuffer.Name);
            until TempNameValueBuffer.Next() = 0;
    end;

    procedure BuscarArchivosXml(var CarpetaOrigen: Text) ArchivosEncontrados: List of [Text]
    var
        FileMgt: Codeunit "File Management";
        TempNameValueBuffer: Record "Name/Value Buffer" temporary;
    begin
        Clear(ArchivosEncontrados);

        if not FileMgt.ServerDirectoryExists(CarpetaOrigen) then
            Error(ErrorCarpetaNoExiste, CarpetaOrigen);

        FileMgt.GetServerDirectoryFilesList(TempNameValueBuffer, CarpetaOrigen);
        if TempNameValueBuffer.FindSet() then
            repeat
                if TempNameValueBuffer.Name.EndsWith('.xml') and not TempNameValueBuffer.Name.EndsWith('.xml.zip') then
                    if ValidarPatronNombreArchivoXml(FileMgt.GetFileName(TempNameValueBuffer.Name)) then
                        ArchivosEncontrados.Add(TempNameValueBuffer.Name);
            until TempNameValueBuffer.Next() = 0;
    end;

    procedure ExtraerCuilDelNombreArchivo(NombreArchivo: Text) Cuil: Code[20]
    var
        CuilValue: Text;
    begin
        // Formato esperado: CUIL_PERIODO_presentacion_NRO.xml.zip o CUIL_PERIODO_presentacion_NRO.xml
        // El CUIL puede venir con guiones (23-28454586-9) o sin guiones (23284545869); se normaliza
        // a solo dígitos para que coincida sin importar el formato de origen.
        // Ej: 20666666667_2024_presentacion_001.xml.zip

        if not (ValidarPatronNombreArchivo(NombreArchivo) or ValidarPatronNombreArchivoXml(NombreArchivo)) then
            Error(ErrorNombreArchivoInvalido);

        // Extraer la primera parte (CUIL)
        CuilValue := ExtractPartFromFilename(NombreArchivo, 1);
        exit(NormalizarCuil(CuilValue));
    end;

    // Quita guiones (y cualquier otro carácter no numérico) de un CUIL, para poder comparar
    // "23-28454586-9" y "23284545869" como el mismo valor a lo largo de todo el flujo SIRADIG.
    procedure NormalizarCuil(Cuil: Text) CuilNormalizado: Code[20]
    var
        i: Integer;
        Resultado: Text;
        Char: Char;
    begin
        for i := 1 to StrLen(Cuil) do begin
            Char := Cuil[i];
            if (Char >= '0') and (Char <= '9') then
                Resultado += Format(Char);
        end;
        exit(CopyStr(Resultado, 1, 20));
    end;

    procedure DescomprimirArchivoZip(var RutaZip: Text) XmlContent: Text
    var
        FileMgt: Codeunit "File Management";
        ZipTempBlob: Codeunit "Temp Blob";
        ZipInStream: InStream;
    begin
        if not FileMgt.ServerFileExists(RutaZip) then
            Error('El archivo ZIP no existe: %1', RutaZip);

        FileMgt.BLOBImportFromServerFile(ZipTempBlob, RutaZip);
        ZipTempBlob.CreateInStream(ZipInStream);
        exit(DescomprimirArchivoZipDesdeStream(ZipInStream));
    end;

    procedure LeerArchivoXml(var RutaXml: Text) XmlContent: Text
    var
        FileMgt: Codeunit "File Management";
        XmlTempBlob: Codeunit "Temp Blob";
        XmlInStream: InStream;
    begin
        if not FileMgt.ServerFileExists(RutaXml) then
            Error('El archivo XML no existe: %1', RutaXml);

        FileMgt.BLOBImportFromServerFile(XmlTempBlob, RutaXml);
        XmlTempBlob.CreateInStream(XmlInStream, TextEncoding::UTF8);
        exit(LeerArchivoXmlDesdeStream(XmlInStream));
    end;

    // Variantes desde InStream — para archivos subidos desde la PC del usuario (UploadIntoStream),
    // sin pasar por una ruta de servidor. Las de arriba (por ruta) las reusan.
    procedure DescomprimirArchivoZipDesdeStream(var ZipInStream: InStream) XmlContent: Text
    var
        DataCompression: Codeunit "Data Compression";
        XmlTempBlob: Codeunit "Temp Blob";
        XmlInStream: InStream;
        EntryList: List of [Text];
        EntryName: Text;
        EntryEncontrada: Boolean;
    begin
        DataCompression.OpenZipArchive(ZipInStream, false);
        DataCompression.GetEntryList(EntryList);

        foreach EntryName in EntryList do
            if EntryName.EndsWith('.xml') then begin
                DataCompression.ExtractEntry(EntryName, XmlTempBlob);
                EntryEncontrada := true;
                break;
            end;

        DataCompression.CloseZipArchive();

        if not EntryEncontrada then
            Error(ErrorSinXmlEnZip, '(archivo subido)');

        XmlTempBlob.CreateInStream(XmlInStream, TextEncoding::UTF8);
        XmlContent := ReadStreamAsText(XmlInStream);
    end;

    /// <summary>
    /// Todos los XML de un ZIP: el nombre de cada uno (sin la carpeta) y su contenido.
    /// </summary>
    /// <remarks>
    /// Es el ZIP que baja AFIP con las presentaciones de todos los trabajadores (por ejemplo
    /// resultadosXML.zip): un XML por trabajador, cada uno con el nombre CUIL_PERIODO_presentacion_NRO.xml.
    /// A diferencia de DescomprimirArchivoZipDesdeStream —que toma el PRIMER xml y saca el CUIL del nombre
    /// del ZIP—, acá el CUIL sale del nombre de cada entrada.
    ///
    /// Se devuelve el TEXTO y no el stream: el que importa lo corre un Codeunit.Run por archivo, y los
    /// streams de las entradas no sobreviven al cierre del ZIP. Los XML de una presentación son chicos
    /// (unos pocos KB), así que tenerlos todos en memoria no cuesta nada.
    /// </remarks>
    procedure ExtraerXmlsDelZip(var ZipInStream: InStream; var Nombres: List of [Text]; var Contenidos: List of [Text])
    var
        DataCompression: Codeunit "Data Compression";
        XmlTempBlob: Codeunit "Temp Blob";
        XmlInStream: InStream;
        EntryList: List of [Text];
        EntryName: Text;
        Encontrados: Integer;
    begin
        DataCompression.OpenZipArchive(ZipInStream, false);
        DataCompression.GetEntryList(EntryList);

        foreach EntryName in EntryList do
            if EntryName.ToLower().EndsWith('.xml') and not EntryName.StartsWith('__MACOSX') then begin
                Clear(XmlTempBlob);
                DataCompression.ExtractEntry(EntryName, XmlTempBlob);
                XmlTempBlob.CreateInStream(XmlInStream, TextEncoding::UTF8);
                Nombres.Add(NombreSinCarpeta(EntryName));
                Contenidos.Add(ReadStreamAsText(XmlInStream));
                Encontrados += 1;
            end;

        DataCompression.CloseZipArchive();

        if Encontrados = 0 then
            Error(ErrorSinXmlEnZip, '(archivo subido)');
    end;

    local procedure NombreSinCarpeta(Entrada: Text) Nombre: Text
    var
        Pos: Integer;
    begin
        // Un ZIP armado desde una carpeta guarda la ruta ("2026-01/2023...xml"), con barra o contrabarra.
        Nombre := Entrada.Replace('\', '/');
        Pos := Nombre.LastIndexOf('/');
        if Pos > 0 then
            Nombre := Nombre.Substring(Pos + 1);
    end;

    procedure LeerArchivoXmlDesdeStream(var XmlInStream: InStream) XmlContent: Text
    begin
        XmlContent := ReadStreamAsText(XmlInStream);
    end;

    local procedure ReadStreamAsText(var InStr: InStream) Result: Text
    var
        Linea: Text;
    begin
        while not InStr.EOS do begin
            InStr.ReadText(Linea);
            Result += Linea;
        end;
    end;

    local procedure ValidarPatronNombreArchivo(NombreArchivo: Text): Boolean
    var
        i: Integer;
        UnderscoreCount: Integer;
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

        // La primera parte es el CUIL, con o sin guiones (23-28454586-9 o 23284545869):
        // una vez sacados los guiones debe quedar en 11 dígitos numéricos.
        exit(EsCuilValido(ExtractPartFromFilename(NombreArchivo, 1)));
    end;

    local procedure ValidarPatronNombreArchivoXml(NombreArchivo: Text): Boolean
    var
        i: Integer;
        UnderscoreCount: Integer;
    begin
        // Esperado: CUIL_PERIODO_presentacion_NRO.xml (sin .zip)
        if not NombreArchivo.EndsWith('.xml') then
            exit(false);

        if NombreArchivo.EndsWith('.xml.zip') then
            exit(false);

        UnderscoreCount := 0;
        for i := 1 to StrLen(NombreArchivo) do begin
            if NombreArchivo[i] = '_' then
                UnderscoreCount += 1;
        end;

        if UnderscoreCount < 3 then
            exit(false);

        exit(EsCuilValido(ExtractPartFromFilename(NombreArchivo, 1)));
    end;

    local procedure EsCuilValido(Parte: Text): Boolean
    begin
        exit(IsNumeric(NormalizarCuil(Parte)) and (StrLen(NormalizarCuil(Parte)) = 11));
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
}
