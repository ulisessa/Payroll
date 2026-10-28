namespace UAS.Payroll;

using Microsoft.HumanResources.Setup;
using System.IO;

page 50171 "Importaciones SIRADIG"
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
                field("AFIP Register Entry No."; Rec."AFIP Register Entry No.")
                {
                    ToolTip = 'Número de entrada en el Registro AFIP WS asociado a esta importación, para trazabilidad.';

                    trigger OnDrillDown()
                    var
                        AfipRegister: Record "AFIP Interface Register";
                    begin
                        if Rec."AFIP Register Entry No." = 0 then
                            exit;
                        AfipRegister.SetRange("Entry no.", Rec."AFIP Register Entry No.");
                        Page.Run(Page::"AFIP WS register", AfipRegister);
                    end;
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
            fileuploadaction("Importar Archivos SIRADIG")
            {
                ApplicationArea = All;
                Caption = 'Importar Archivos SIRADIG';
                Image = Import;
                ToolTip = 'Selecciona uno o varios archivos SIRADIG desde tu PC para importar: .xml, .xml.zip (una presentación) o un .zip con las presentaciones de todos los trabajadores.';
                AllowMultipleFiles = true;

                trigger OnAction(files: List of [FileUpload])
                begin
                    ImportarArchivosSubidos(files);
                end;
            }
            action("Importar desde Carpeta del Servidor")
            {
                ApplicationArea = All;
                Caption = 'Importar desde Carpeta del Servidor';
                Image = ImportCodes;
                ToolTip = 'Avanzado: importa en lote todos los archivos SIRADIG de una carpeta del servidor.';

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
                ToolTip = 'Procesa las importaciones seleccionadas (todas las filas marcadas) que estén pendientes y actualiza los datos de cada empleado.';

                trigger OnAction()
                var
                    Seleccion: Record "Importación SIRADIG";
                    Orquestador: Codeunit "Orquestador SIRADIG";
                begin
                    CurrPage.SetSelectionFilter(Seleccion);
                    Orquestador.ProcesarFiltradas(Seleccion);
                    CurrPage.Update(false);
                end;
            }
            action("Ver por Mes")
            {
                ApplicationArea = All;
                Caption = 'Ver por Mes de Presentación';
                Image = Hierarchy;
                ToolTip = 'Abre las importaciones agrupadas por mes de presentación y estado, para procesar o eliminar de a un mes entero.';
                RunObject = Page "Árbol de Importaciones SIRADIG";
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
            action("Ver Registro AFIP WS")
            {
                ApplicationArea = All;
                Caption = 'Ver Registro AFIP WS';
                Image = ViewDetails;
                ToolTip = 'Abre el registro de interfaz AFIP (Registro AFIP WS y su detalle) asociado a esta importación SIRADIG, para trazabilidad.';
                Enabled = Rec."AFIP Register Entry No." <> 0;

                trigger OnAction()
                var
                    AfipRegister: Record "AFIP Interface Register";
                begin
                    AfipRegister.SetRange("Entry no.", Rec."AFIP Register Entry No.");
                    Page.Run(Page::"AFIP WS register", AfipRegister);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';

                actionref("Importar Archivos SIRADIG_Promoted"; "Importar Archivos SIRADIG")
                {
                }
                actionref("Importar desde Carpeta del Servidor_Promoted"; "Importar desde Carpeta del Servidor")
                {
                }
                actionref("Procesar Importación_Promoted"; "Procesar Importación")
                {
                }
                actionref("Ver por Mes_Promoted"; "Ver por Mes")
                {
                }
            }
            group(Category_Navigate)
            {
                Caption = 'Navegar';

                actionref("Ver Registro AFIP WS_Promoted"; "Ver Registro AFIP WS")
                {
                }
            }
        }
    }

    local procedure ImportarArchivosSubidos(var Files: List of [FileUpload])
    var
        Orquestador: Codeunit "Orquestador SIRADIG";
        ProcesarAutomaticamente: Boolean;
    begin
        if Files.Count = 0 then
            exit;
        ProcesarAutomaticamente := Confirm('¿Desea procesar automáticamente las importaciones?');
        Orquestador.ImportarArchivosSubidos(Files, ProcesarAutomaticamente);
    end;

    local procedure ImportarArchivosSiradig()
    var
        Orquestador: Codeunit "Orquestador SIRADIG";
        CarpetaOrigen: Text;
        ProcesarAutomaticamente: Boolean;
    begin
        // Solicitar carpeta de origen de los archivos SIRADIG
        CarpetaOrigen := GetInputFolder();
        if CarpetaOrigen = '' then
            exit;

        // La recordamos ya acá (antes de importar) para que la próxima vez el diálogo arranque
        // en esta misma carpeta, aunque algún archivo individual falle más abajo.
        GuardarUltimaCarpeta(CarpetaOrigen);

        // Preguntar si desea procesar automáticamente
        ProcesarAutomaticamente := Confirm('¿Desea procesar automáticamente las importaciones?');

        // Buscar, descomprimir (si corresponde) e importar todos los archivos de la carpeta
        Orquestador.ImportarYProcesarCarpeta(CarpetaOrigen, ProcesarAutomaticamente);
    end;

    local procedure GuardarUltimaCarpeta(CarpetaOrigen: Text)
    var
        HumanResourcesSetup: Record "Human Resources Setup";
    begin
        if not HumanResourcesSetup.Get() then
            exit;
        if HumanResourcesSetup."Carpeta Importación SIRADIG" = CarpetaOrigen then
            exit;
        HumanResourcesSetup."Carpeta Importación SIRADIG" := CopyStr(CarpetaOrigen, 1, MaxStrLen(HumanResourcesSetup."Carpeta Importación SIRADIG"));
        HumanResourcesSetup.Modify();
    end;


    local procedure GetInputFolder(): Text
    var
        HumanResourcesSetup: Record "Human Resources Setup";
        CarpetaDialog: Page "Carpeta SIRADIG Dialog";
    begin
        HumanResourcesSetup.Get();
        CarpetaDialog.SetCarpeta(HumanResourcesSetup."Carpeta Importación SIRADIG");
        if CarpetaDialog.RunModal() = Action::OK then
            exit(CarpetaDialog.GetCarpeta());
        exit('');
    end;
}
