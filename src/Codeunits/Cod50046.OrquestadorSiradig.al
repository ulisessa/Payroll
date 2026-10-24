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
        ErrTipoArchivo: Label 'El archivo debe ser .xml, .xml.zip o un .zip con las presentaciones: %1', Comment = '%1=nombre del archivo';
        ErrEmpleadoSinCuil: Label 'No hay un empleado con el CUIL %1: no se pudo procesar.', Comment = '%1=CUIL';
        MsgResumenProcesadas: Label 'Se procesaron %1 importación(es). %2 sin empleado en BC (quedaron con error).%3', Comment = '%1=procesadas, %2=sin empleado, %3=detalle';
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
        Nombres: List of [Text];
        Contenidos: List of [Text];
        NombreArchivo: Text;
        Errores: Text;
        Resumen: Text;
        i: Integer;
        ImportadosOk: Integer;
        ImportadosError: Integer;
        Deducciones: Integer;
        Cargas: Integer;
        TotalDeducciones: Integer;
        TotalCargas: Integer;
    begin
        // Un solo resumen al final: ni el detalle por archivo ni los errores se muestran de a uno,
        // porque con una selección grande obligaba a cerrar un cuadro de diálogo por archivo.
        //
        // Primero se LEE todo lo subido a una lista de (nombre, XML): un ZIP con las presentaciones de
        // todos los trabajadores (resultadosXML.zip) se abre acá y cada XML pasa a ser un archivo más.
        // Un archivo ilegible se anota como error y no frena a los demás.
        foreach ArchivoActual in Files do begin
            NombreArchivo := ArchivoActual.FileName();
            ArchivoActual.CreateInStream(InStreamArchivo);
            if not TryLeerArchivoSubido(NombreArchivo, InStreamArchivo, Nombres, Contenidos) then begin
                ImportadosError += 1;
                Errores += '\· ' + NombreArchivo + ': ' + GetLastErrorText();
            end;
        end;

        for i := 1 to Nombres.Count() do begin
            NombreArchivo := Nombres.Get(i);
            Clear(Importador);
            Importador.SetContenido(NombreArchivo, Contenidos.Get(i), AutoProcesar);

            // Commit antes del Run: BC no deja leer el valor de retorno de Codeunit.Run() con una
            // transacción de escritura abierta, y acá ese valor es lo que separa el archivo que
            // importó del que hay que contar como error. El primer archivo pasa porque todavía no
            // se escribió nada; del SEGUNDO en adelante, lo que importó el anterior deja la
            // transacción abierta y el Run falla con "OK := Codeunit.Run() no está permitido".
            // O sea: con un archivo anda y con varios no, que es el caso de uso de este bucle.
            //
            // Cada archivo ya era su propia unidad de trabajo —si falla, se anota y se sigue— así
            // que confirmarlo no cambia la semántica, la hace cierta.
            Commit();

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

    // Qué XML trae cada archivo subido. Un .xml.zip es UNA presentación (el CUIL sale del nombre del
    // zip, como siempre); un .zip a secas trae muchas, y el CUIL sale del nombre de cada entrada.
    // Sólo lee —no escribe nada en la base—, así que puede ser TryFunction.
    [TryFunction]
    local procedure TryLeerArchivoSubido(NombreArchivo: Text; var InStreamArchivo: InStream; var Nombres: List of [Text]; var Contenidos: List of [Text])
    var
        Minusculas: Text;
    begin
        Minusculas := NombreArchivo.ToLower();
        case true of
            Minusculas.EndsWith('.xml.zip'):
                begin
                    Nombres.Add(NombreArchivo);
                    Contenidos.Add(GestorArchivos.DescomprimirArchivoZipDesdeStream(InStreamArchivo));
                end;
            Minusculas.EndsWith('.zip'):
                GestorArchivos.ExtraerXmlsDelZip(InStreamArchivo, Nombres, Contenidos);
            Minusculas.EndsWith('.xml'):
                begin
                    Nombres.Add(NombreArchivo);
                    Contenidos.Add(GestorArchivos.LeerArchivoXmlDesdeStream(InStreamArchivo));
                end;
            else
                Error(ErrTipoArchivo, NombreArchivo);
        end;
    end;

    // Procesa las importaciones PENDIENTES del conjunto que llegue filtrado o marcado, en una sola
    // pasada y con un único resumen. Devuelve cuántas se procesaron.
    //
    // Se arma primero la lista de números y después se recorre con Get: procesar cambia el Estado, y un
    // bucle que modifica el campo con el que se filtra deja de recorrer sin avisar.
    //
    // La importación de alguien que no existe en BC (el CUIL no aparece) queda en "Error en
    // Procesamiento" con el motivo, y el resto sigue. Cualquier otro error inesperado corta todo y
    // deshace la pasada completa —no queda nada a medias—, con el mensaje del error.
    procedure ProcesarFiltradas(var Filtradas: Record "Importación SIRADIG") Procesadas: Integer
    var
        Imp: Record "Importación SIRADIG";
        Numeros: List of [Integer];
        Numero: Integer;
        Errores: Text;
        XmlContent: Text;
        SinEmpleado: Integer;
    begin
        if Filtradas.FindSet() then
            repeat
                if Filtradas.Estado = Filtradas.Estado::"Pendiente Procesar" then
                    Numeros.Add(Filtradas."No.");
            until Filtradas.Next() = 0;

        if Numeros.Count() = 0 then begin
            Message('No hay importaciones pendientes de procesar.');
            exit(0);
        end;

        // Un solo resumen al final.
        ProcesadorSiradig.SetSilencioso(true);

        foreach Numero in Numeros do
            if Imp.Get(Numero) then
                if not ProcesadorSiradig.ExisteEmpleado(Imp."CUIL Empleado") then begin
                    Imp.Estado := "Estado Importación SIRADIG"::"Error en Procesamiento";
                    Imp."Mensajes Error" := CopyStr(StrSubstNo(ErrEmpleadoSinCuil, Imp."CUIL Empleado"), 1, MaxStrLen(Imp."Mensajes Error"));
                    Imp.Modify();
                    SinEmpleado += 1;
                    Errores += '\· ' + Imp."CUIL Empleado";
                end else begin
                    XmlContent := LeerXmlDeLaImportacion(Imp);
                    ProcesadorSiradig.ProcesarImportacionSiradig(Imp, XmlContent);
                    Procesadas += 1;
                end;

        Message(MsgResumenProcesadas, Procesadas, SinEmpleado, Errores);
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

    // El XML de una importación: primero el que se guardó al importar (en el registro de auditoría), que
    // es el único que existe para los archivos subidos desde la PC —de ésos sólo se conserva el
    // nombre—, y si no está, el archivo del servidor de la importación por carpeta.
    procedure LeerXmlDeLaImportacion(var RegistroImportacion: Record "Importación SIRADIG") XmlContent: Text
    var
        RutaArchivo: Text;
    begin
        XmlContent := AuditoriaAfip.LeerXmlRegistrado(RegistroImportacion."AFIP Register Entry No.");
        if XmlContent <> '' then
            exit;

        RutaArchivo := RegistroImportacion."Archivo Origen";
        if RutaArchivo.EndsWith('.zip') then
            XmlContent := GestorArchivos.DescomprimirArchivoZip(RutaArchivo)
        else
            XmlContent := GestorArchivos.LeerArchivoXml(RutaArchivo);
    end;

    [TryFunction]
    local procedure TryProcesarImportacionPendiente(var RegistroImportacion: Record "Importación SIRADIG")
    var
        XmlContent: Text;
    begin
        XmlContent := LeerXmlDeLaImportacion(RegistroImportacion);

        // Procesar importación
        ProcesadorSiradig.ProcesarImportacionSiradig(RegistroImportacion, XmlContent);
    end;
}
