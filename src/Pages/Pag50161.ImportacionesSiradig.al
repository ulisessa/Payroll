namespace UAS.Payroll;

page 50161 "Importaciones SIRADIG"
{
    ApplicationArea = All;
    Caption = 'Importaciones SIRADIG';
    PageType = List;
    SourceTable = "Importación SIRADIG";
    UsageCategory = Tasks;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("No."; Rec."No.")
                {
                    ToolTip = 'Especifica el número de la importación.';
                }
                field("CUIL Empleado"; Rec."CUIL Empleado")
                {
                    ToolTip = 'Especifica el CUIL del empleado.';
                }
                field("No. Empleado"; Rec."No. Empleado")
                {
                    ToolTip = 'Especifica el número del empleado.';
                }
                field("Período"; Rec."Período")
                {
                    ToolTip = 'Especifica el período de la presentación SIRADIG.';
                }
                field("Nro. Presentación"; Rec."Nro. Presentación")
                {
                    ToolTip = 'Especifica el número secuencial de presentación.';
                }
                field("Fecha Presentación"; Rec."Fecha Presentación")
                {
                    ToolTip = 'Especifica la fecha de presentación SIRADIG.';
                }
                field("Deducciones Importadas"; Rec."Deducciones Importadas")
                {
                    ToolTip = 'Especifica la cantidad de deducciones importadas.';
                }
                field("Cargas Familia Importadas"; Rec."Cargas Familia Importadas")
                {
                    ToolTip = 'Especifica la cantidad de cargas familiares importadas.';
                }
                field(Estado; Rec.Estado)
                {
                    ToolTip = 'Especifica el estado de la importación.';
                }
                field("Fecha Importación"; Rec."Fecha Importación")
                {
                    ToolTip = 'Especifica la fecha de importación.';
                }
                field("Usuario Importación"; Rec."Usuario Importación")
                {
                    ToolTip = 'Especifica el usuario que realizó la importación.';
                }
                field("Mensajes Error"; Rec."Mensajes Error")
                {
                    ToolTip = 'Especifica los mensajes de error si los hay.';
                }
            }
        }
        area(FactBoxes)
        {
        }
    }

    actions
    {
        area(Processing)
        {
            action("Importar Archivos SIRADIG")
            {
                ApplicationArea = All;
                Caption = 'Importar Archivos SIRADIG';
                Image = Import;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Importa archivos SIRADIG desde una carpeta específica.';

                trigger OnAction()
                begin
                    ImportarArchivosSiradig();
                end;
            }
            action("Procesar Importación")
            {
                ApplicationArea = All;
                Caption = 'Procesar Importación';
                Image = Process;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Procesa la importación seleccionada y actualiza los datos del empleado.';
                Enabled = (Rec.Estado = "Estado Importación SIRADIG"::"Pendiente Procesar");

                trigger OnAction()
                begin
                    ProcesarImportacionActual();
                end;
            }
            action("Eliminar")
            {
                ApplicationArea = All;
                Caption = 'Eliminar';
                Image = Delete;
                ToolTip = 'Elimina la importación seleccionada.';
                Enabled = (Rec.Estado <> "Estado Importación SIRADIG"::"Procesado Exitosamente");

                trigger OnAction()
                begin
                    if Confirm('¿Desea eliminar esta importación?') then
                        Rec.Delete();
                end;
            }
        }
    }

    local procedure ImportarArchivosSiradig()
    var
        Orquestador: Codeunit "Orquestador SIRADIG";
        CarpetaOrigen: Text;
        ProcesarAutomaticamente: Boolean;
    begin
        // Solicitar carpeta origen (alternativa: campo de entrada)
        CarpetaOrigen := GetInputFolder();
        if CarpetaOrigen = '' then
            exit;

        // Preguntar si desea procesar automáticamente
        ProcesarAutomaticamente := Confirm('¿Desea procesar automáticamente las importaciones encontradas?');

        // Importar y procesar
        Orquestador.ImportarYProcesarCarpeta(CarpetaOrigen, ProcesarAutomaticamente);
    end;

    local procedure ProcesarImportacionActual()
    var
        ProcesadorSiradig: Codeunit "Procesador Importación SIRADIG";
        GestorArchivos: Codeunit "Gestor Archivos SIRADIG";
        RutaTemporal: Text;
        RutaXml: Text;
    begin
        // Obtener ruta del archivo original
        if Rec."Archivo Origen" = '' then begin
            Message('No se encontró la ruta del archivo origen.');
            exit;
        end;

        // Crear carpeta temporal
        RutaTemporal := GestorArchivos.ObtenerCarpetaTemporal();

        try
            // Descomprimir archivo ZIP
            RutaXml := GestorArchivos.DescomprimirArchivoZip(Rec."Archivo Origen", RutaTemporal);

            // Procesar importación
            ProcesadorSiradig.ProcesarImportacionSiradig(Rec, RutaXml);
        finally
            // Limpiar carpeta temporal
            GestorArchivos.LimpiarCarpetaTemporal(RutaTemporal);
        end;
    end;

    local procedure GetInputFolder(): Text
    var
        CarpetaOrigen: Text;
    begin
        // Ejemplo: C:\SIRADIG\Importaciones\
        // El usuario debe proporcionar la ruta manualmente o vía parámetro
        CarpetaOrigen := InputBox('Ingrese la ruta de la carpeta con archivos SIRADIG:', 'Carpeta SIRADIG');
        exit(CarpetaOrigen);
    end;
}
