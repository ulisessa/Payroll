namespace UAS.Payroll;

codeunit 50058 "Importador Archivo SIRADIG"
{
    // Ejecuta la importación de UN archivo subido por el usuario vía Codeunit.Run(), en vez de
    // un procedimiento [TryFunction]. Necesario porque el runtime rechaza cualquier escritura a
    // base de datos ("NavNclTryFunctionWriteException") dentro de un [TryFunction] cuando éste
    // corre en el mismo call frame que la transferencia de archivo del cliente (fileuploadaction).
    // Codeunit.Run() sí soporta escrituras con rollback automático si falla, por eso lo usamos acá.

    trigger OnRun()
    var
        RegistroImportacion: Record "Importación SIRADIG";
        XmlContent: Text;
        Cuil: Code[20];
    begin
        if FUsaContenido then
            // El orquestador ya leyó el archivo (un XML suelto, un .xml.zip o una entrada de un ZIP
            // con todas las presentaciones): FNombreArchivo es el del XML que corresponde al CUIL.
            XmlContent := FContenido
        else if FNombreArchivo.EndsWith('.xml.zip') then
            XmlContent := GestorArchivos.DescomprimirArchivoZipDesdeStream(FInStreamArchivo)
        else if FNombreArchivo.EndsWith('.xml') then
            XmlContent := GestorArchivos.LeerArchivoXmlDesdeStream(FInStreamArchivo)
        else
            Error('El archivo debe ser .xml o .xml.zip: %1', FNombreArchivo);

        Cuil := GestorArchivos.ExtraerCuilDelNombreArchivo(FNombreArchivo);

        RegistroImportacion.Init();
        RegistroImportacion."CUIL Empleado" := Cuil;
        RegistroImportacion."Archivo Origen" := CopyStr(FNombreArchivo, 1, MaxStrLen(RegistroImportacion."Archivo Origen"));
        ParserXml.ExtraerDatosDelXml(XmlContent, RegistroImportacion);

        if not RegistroImportacion.Insert() then
            Error(ErrorArchivoYaImportado);

        AuditoriaAfip.RegistrarImportacionSiradig(RegistroImportacion, XmlContent);
        RegistroImportacion.Modify();

        if FAutoProcesar then begin
            // El llamador (ImportarArchivosSubidos) informa un solo resumen al final: sin esto
            // aparecería un cuadro de diálogo por cada archivo de la selección.
            ProcesadorSiradig.SetSilencioso(true);
            ProcesadorSiradig.ProcesarImportacionSiradig(RegistroImportacion, XmlContent);
            FDeducciones := RegistroImportacion."Deducciones Importadas";
            FCargas := RegistroImportacion."Cargas Familia Importadas";
        end;
    end;

    // Totales del último archivo procesado, para que el llamador arme el resumen acumulado.
    procedure GetContadores(var Deducciones: Integer; var Cargas: Integer)
    begin
        Deducciones := FDeducciones;
        Cargas := FCargas;
    end;

    procedure SetParametros(NombreArchivo: Text; var InStreamArchivo: InStream; AutoProcesar: Boolean)
    begin
        FNombreArchivo := NombreArchivo;
        FInStreamArchivo := InStreamArchivo;
        FAutoProcesar := AutoProcesar;
        FUsaContenido := false;
    end;

    // Variante con el XML ya leído, para los ZIP que traen muchas presentaciones: los streams de las
    // entradas no sobreviven al cierre del ZIP, así que se importa desde el texto.
    procedure SetContenido(NombreArchivo: Text; XmlContent: Text; AutoProcesar: Boolean)
    begin
        FNombreArchivo := NombreArchivo;
        FContenido := XmlContent;
        FAutoProcesar := AutoProcesar;
        FUsaContenido := true;
    end;

    var
        GestorArchivos: Codeunit "Gestor Archivos SIRADIG";
        ParserXml: Codeunit "Parser SIRADIG XML";
        ProcesadorSiradig: Codeunit "Procesador Importación SIRADIG";
        AuditoriaAfip: Codeunit "Auditoria AFIP Interface";
        FInStreamArchivo: InStream;
        FNombreArchivo: Text;
        FContenido: Text;
        FUsaContenido: Boolean;
        FAutoProcesar: Boolean;
        FDeducciones: Integer;
        FCargas: Integer;
        ErrorArchivoYaImportado: Label 'El archivo ya ha sido importado anteriormente.';
}
