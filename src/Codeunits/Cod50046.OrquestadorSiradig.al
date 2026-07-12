namespace UAS.Payroll;

using System.IO;

codeunit 50025 "Orquestador SIRADIG"
{
    Caption = 'Orquestador SIRADIG';
    Access = Public;

    var
        GestorArchivos: Codeunit "Gestor Archivos SIRADIG";
        ParserXml: Codeunit "Parser SIRADIG XML";
        ProcesadorSiradig: Codeunit "Procesador Importación SIRADIG";

    procedure ImportarYProcesarCarpeta(var CarpetaOrigen: Text; AutoProcesar: Boolean)
    var
        ArchivosZip: List of [Text];
        ArchivosXml: List of [Text];
        RutaArchivo: Text;
        RegistrosImportados: Integer;
        RegistrosProcesados: Integer;
    begin
        // Buscar archivos ZIP en la carpeta
        ArchivosZip := GestorArchivos.BuscarArchivosZip(CarpetaOrigen);

        // Buscar también archivos XML directamente (descomprimidos manualmente)
        ArchivosXml := GestorArchivos.BuscarArchivosXml(CarpetaOrigen);

        if (ArchivosZip.Count = 0) and (ArchivosXml.Count = 0) then begin
            Message('No se encontraron archivos SIRADIG en la carpeta especificada.');
            exit;
        end;

        // Procesar archivos ZIP
        foreach RutaArchivo in ArchivosZip do begin
            if ImportarArchivoSiradig(RutaArchivo, AutoProcesar) then begin
                RegistrosImportados += 1;
                if AutoProcesar then
                    RegistrosProcesados += 1;
            end;
        end;

        // Procesar archivos XML directos
        foreach RutaArchivo in ArchivosXml do begin
            if ImportarArchivoXmlDirecto(RutaArchivo, AutoProcesar) then begin
                RegistrosImportados += 1;
                if AutoProcesar then
                    RegistrosProcesados += 1;
            end;
        end;

        if AutoProcesar then
            Message('Se importaron y procesaron %1 archivo(s) SIRADIG exitosamente.', RegistrosProcesados)
        else
            Message('Se importaron %1 archivo(s) SIRADIG. Puede procesarlos desde la lista de importaciones.', RegistrosImportados);
    end;

    procedure ImportarArchivoSiradig(var RutaZip: Text; ProcesarAutomaticamente: Boolean): Boolean
    var
        RegistroImportacion: Record "Importación SIRADIG";
        RutaTemporal: Text;
        RutaXml: Text;
        Cuil: Code[20];
    begin
        // Validar que el archivo ZIP existe
        if not File.Exists(RutaZip) then begin
            Message('El archivo no existe: %1', RutaZip);
            exit(false);
        end;

        try
            // Crear carpeta temporal
            RutaTemporal := GestorArchivos.ObtenerCarpetaTemporal();

            // Descomprimir archivo
            RutaXml := GestorArchivos.DescomprimirArchivoZip(RutaZip, RutaTemporal);

            // Extraer CUIL del nombre del archivo
            Cuil := GestorArchivos.ExtraerCuilDelNombreArchivo(Path.GetFileName(RutaZip));

            // Crear registro de importación y extraer datos básicos del XML
            RegistroImportacion.Init();
            RegistroImportacion."CUIL Empleado" := Cuil;
            RegistroImportacion."Archivo Origen" := RutaZip;

            // Parsear XML y extraer metadatos
            ParserXml.ExtraerDatosDelXml(RutaXml, RegistroImportacion);

            // Insertar registro de importación
            if not RegistroImportacion.Insert() then begin
                Message('El archivo ya ha sido importado anteriormente.');
                exit(false);
            end;

            // Procesar automáticamente si se solicita
            if ProcesarAutomaticamente then begin
                ProcesadorSiradig.ProcesarImportacionSiradig(RegistroImportacion, RutaXml);
            end;

            exit(true);
        catch E: Exception do begin
            Message('Error al importar archivo %1: %2', RutaZip, E.Message);
            exit(false);
        end
        finally
            // Limpiar carpeta temporal
            if RutaTemporal <> '' then
                GestorArchivos.LimpiarCarpetaTemporal(RutaTemporal);
        end;
    end;

    procedure ImportarArchivoXmlDirecto(var RutaXml: Text; ProcesarAutomaticamente: Boolean): Boolean
    var
        RegistroImportacion: Record "Importación SIRADIG";
        Cuil: Code[20];
    begin
        // Validar que el archivo XML existe
        if not File.Exists(RutaXml) then begin
            Message('El archivo no existe: %1', RutaXml);
            exit(false);
        end;

        try
            // Extraer CUIL del nombre del archivo
            Cuil := GestorArchivos.ExtraerCuilDelNombreArchivo(Path.GetFileName(RutaXml));

            // Crear registro de importación y extraer datos básicos del XML
            RegistroImportacion.Init();
            RegistroImportacion."CUIL Empleado" := Cuil;
            RegistroImportacion."Archivo Origen" := RutaXml;

            // Parsear XML y extraer metadatos
            ParserXml.ExtraerDatosDelXml(RutaXml, RegistroImportacion);

            // Insertar registro de importación
            if not RegistroImportacion.Insert() then begin
                Message('El archivo ya ha sido importado anteriormente.');
                exit(false);
            end;

            // Procesar automáticamente si se solicita
            if ProcesarAutomaticamente then begin
                ProcesadorSiradig.ProcesarImportacionSiradig(RegistroImportacion, RutaXml);
            end;

            exit(true);
        catch E: Exception do begin
            Message('Error al importar archivo %1: %2', RutaXml, E.Message);
            exit(false);
        end;
    end;

    procedure ProcesarImportacionesPendientes()
    var
        RegistroImportacion: Record "Importación SIRADIG";
        RutaTemporal: Text;
        RutaXml: Text;
        RegistrosProcesados: Integer;
    begin
        // Procesar todas las importaciones pendientes
        RegistroImportacion.SetRange(Estado, "Estado Importación SIRADIG"::"Pendiente Procesar");

        if not RegistroImportacion.FindSet() then begin
            Message('No hay importaciones pendientes de procesar.');
            exit;
        end;

        repeat
            try
                RutaTemporal := GestorArchivos.ObtenerCarpetaTemporal();

                // Descomprimir archivo
                RutaXml := GestorArchivos.DescomprimirArchivoZip(
                    RegistroImportacion."Archivo Origen",
                    RutaTemporal
                );

                // Procesar importación
                ProcesadorSiradig.ProcesarImportacionSiradig(RegistroImportacion, RutaXml);
                RegistrosProcesados += 1;
            catch E: Exception do begin
                RegistroImportacion.Estado := "Estado Importación SIRADIG"::"Error en Procesamiento";
                RegistroImportacion."Mensajes Error" := CopyStr(E.Message, 1, 500);
                RegistroImportacion.Modify();
            end
            finally
                if RutaTemporal <> '' then
                    GestorArchivos.LimpiarCarpetaTemporal(RutaTemporal);
            end;
        until RegistroImportacion.Next() = 0;

        Message('Se procesaron %1 importación(es) pendiente(s) exitosamente.', RegistrosProcesados);
    end;
}
