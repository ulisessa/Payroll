namespace UAS.Payroll;

using System.IO;

codeunit 50046 "Orquestador SIRADIG"
{
    Access = Public;

    var
        GestorArchivos: Codeunit "Gestor Archivos SIRADIG";
        ParserXml: Codeunit "Parser SIRADIG XML";
        ProcesadorSiradig: Codeunit "Procesador Importación SIRADIG";
        AuditoriaAfip: Codeunit "Auditoria AFIP Interface";
        ErrorArchivoYaImportado: Label 'El archivo ya ha sido importado anteriormente.';
        MsgResumenImportacion: Label 'Se importaron %1 archivo(s) SIRADIG. %2 archivo(s) con errores.';
        MsgResumenProcesado: Label '\Se procesaron %1 deducción(es) y %2 carga(s) de familia.';
        MsgResumenErrores: Label '\\Errores:%1';
        ProgressMsg: Label 'Procesando archivo #1###### de #2######\n@3@@@@@@@@@@@@@';

    procedure ImportarYProcesarCarpeta(var CarpetaOrigen: Text; AutoProcesar: Boolean)
    var
        FileMgt: Codeunit "File Management";
        ProgressDialog: Dialog;
        ArchivosZip: List of [Text];
        ArchivosXml: List of [Text];
        RutaArchivo: Text;
        TotalArchivos: Integer;
        ArchivoActual: Integer;
        ImportadosOk: Integer;
        ImportadosError: Integer;
    begin
        if not FileMgt.ServerDirectoryExists(CarpetaOrigen) then begin
            Message('La carpeta especificada no existe: %1', CarpetaOrigen);
            exit;
        end;

        // Igual que en la importación por selección de archivos: un único resumen al final.
        ProcesadorSiradig.SetSilencioso(true);

        ArchivosZip := GestorArchivos.BuscarArchivosZip(CarpetaOrigen);
        ArchivosXml := GestorArchivos.BuscarArchivosXml(CarpetaOrigen);

        TotalArchivos := ArchivosZip.Count() + ArchivosXml.Count();

        if TotalArchivos = 0 then begin
            Message('No se encontraron archivos SIRADIG (.xml.zip o .xml) en la carpeta: %1', CarpetaOrigen);
            exit;
        end;

        ProgressDialog.Open(ProgressMsg);

        foreach RutaArchivo in ArchivosZip do begin
            ArchivoActual += 1;
            ProgressDialog.Update(1, ArchivoActual);
            ProgressDialog.Update(2, TotalArchivos);
            ProgressDialog.Update(3, Round(ArchivoActual / TotalArchivos * 10000, 1));

            if TryImportarArchivo(RutaArchivo, true, AutoProcesar) then
                ImportadosOk += 1
            else
                ImportadosError += 1;
        end;

        foreach RutaArchivo in ArchivosXml do begin
            ArchivoActual += 1;
            ProgressDialog.Update(1, ArchivoActual);
            ProgressDialog.Update(2, TotalArchivos);
            ProgressDialog.Update(3, Round(ArchivoActual / TotalArchivos * 10000, 1));

            if TryImportarArchivo(RutaArchivo, false, AutoProcesar) then
                ImportadosOk += 1
            else
                ImportadosError += 1;
        end;

        ProgressDialog.Close();

        Message('Se importaron %1 archivo(s) SIRADIG. %2 archivo(s) con errores.', ImportadosOk, ImportadosError);
    end;

    [TryFunction]
    local procedure TryImportarArchivo(RutaArchivo: Text; EsZip: Boolean; AutoProcesar: Boolean)
    var
        FileMgt: Codeunit "File Management";
        RegistroImportacion: Record "Importación SIRADIG";
        XmlContent: Text;
        Cuil: Code[20];
    begin
        if EsZip then
            XmlContent := GestorArchivos.DescomprimirArchivoZip(RutaArchivo)
        else
            XmlContent := GestorArchivos.LeerArchivoXml(RutaArchivo);

        // Extraer CUIL del nombre del archivo
        Cuil := GestorArchivos.ExtraerCuilDelNombreArchivo(FileMgt.GetFileName(RutaArchivo));

        // Crear registro de importación y extraer datos básicos del XML
        RegistroImportacion.Init();
        RegistroImportacion."CUIL Empleado" := Cuil;
        RegistroImportacion."Archivo Origen" := CopyStr(RutaArchivo, 1, MaxStrLen(RegistroImportacion."Archivo Origen"));

        // Parsear XML y extraer metadatos
        ParserXml.ExtraerDatosDelXml(XmlContent, RegistroImportacion);

        // Insertar registro de importación
        if not RegistroImportacion.Insert() then
            Error(ErrorArchivoYaImportado);

        AuditoriaAfip.RegistrarImportacionSiradig(RegistroImportacion, XmlContent);
        RegistroImportacion.Modify();

        // Procesar automáticamente si se solicita
        if AutoProcesar then
            ProcesadorSiradig.ProcesarImportacionSiradig(RegistroImportacion, XmlContent);
    end;

    // Selector de archivos nativo de la PC del usuario (selección múltiple real vía
    // fileuploadaction/AllowMultipleFiles), en vez de escribir a mano una ruta de carpeta
    // del servidor. Un archivo con error no corta el resto — se importan todos los que se
    // puedan y al final se informa cuántos fallaron.
    procedure ImportarArchivosSubidos(var Files: List of [FileUpload]; AutoProcesar: Boolean)
    var
        Importador: Codeunit "Importador Archivo SIRADIG";
        ArchivoActual: FileUpload;
        InStreamArchivo: InStream;
        NombreArchivo: Text;
        Errores: Text;
        Resumen: Text;
        ImportadosOk: Integer;
        ImportadosError: Integer;
        Deducciones: Integer;
        Cargas: Integer;
        TotalDeducciones: Integer;
        TotalCargas: Integer;
    begin
        // Un solo resumen al final: ni el detalle por archivo ni los errores se muestran de a uno,
        // porque con una selección grande obligaba a cerrar un cuadro de diálogo por archivo.
        foreach ArchivoActual in Files do begin
            NombreArchivo := ArchivoActual.FileName();
            ArchivoActual.CreateInStream(InStreamArchivo);
            Clear(Importador);
            Importador.SetParametros(NombreArchivo, InStreamArchivo, AutoProcesar);
            if Importador.Run() then begin
                ImportadosOk += 1;
                Importador.GetContadores(Deducciones, Cargas);
                TotalDeducciones += Deducciones;
                TotalCargas += Cargas;
            end else begin
                ImportadosError += 1;
                Errores += '\· ' + NombreArchivo + ': ' + GetLastErrorText();
            end;
        end;

        if ImportadosOk + ImportadosError = 0 then
            exit;

        Resumen := StrSubstNo(MsgResumenImportacion, ImportadosOk, ImportadosError);
        if AutoProcesar and (ImportadosOk > 0) then
            Resumen += StrSubstNo(MsgResumenProcesado, TotalDeducciones, TotalCargas);
        if Errores <> '' then
            Resumen += StrSubstNo(MsgResumenErrores, Errores);
        Message(Resumen);
    end;

    procedure ProcesarImportacionesPendientes()
    var
        RegistroImportacion: Record "Importación SIRADIG";
        RegistrosProcesados: Integer;
    begin
        // Procesar todas las importaciones pendientes
        RegistroImportacion.SetRange(Estado, "Estado Importación SIRADIG"::"Pendiente Procesar");

        if not RegistroImportacion.FindSet() then begin
            Message('No hay importaciones pendientes de procesar.');
            exit;
        end;

        // Un solo resumen al final, no un cuadro de diálogo por importación pendiente.
        ProcesadorSiradig.SetSilencioso(true);

        repeat
            if TryProcesarImportacionPendiente(RegistroImportacion) then
                RegistrosProcesados += 1
            else begin
                RegistroImportacion.Estado := "Estado Importación SIRADIG"::"Error en Procesamiento";
                RegistroImportacion."Mensajes Error" := CopyStr(GetLastErrorText(), 1, 500);
                RegistroImportacion.Modify();
            end;
        until RegistroImportacion.Next() = 0;

        Message('Se procesaron %1 importación(es) pendiente(s) exitosamente.', RegistrosProcesados);
    end;

    [TryFunction]
    local procedure TryProcesarImportacionPendiente(var RegistroImportacion: Record "Importación SIRADIG")
    var
        RutaArchivo: Text;
        XmlContent: Text;
    begin
        RutaArchivo := RegistroImportacion."Archivo Origen";

        if RutaArchivo.EndsWith('.zip') then
            XmlContent := GestorArchivos.DescomprimirArchivoZip(RutaArchivo)
        else
            XmlContent := GestorArchivos.LeerArchivoXml(RutaArchivo);

        // Procesar importación
        ProcesadorSiradig.ProcesarImportacionSiradig(RegistroImportacion, XmlContent);
    end;
}
