namespace UAS.Payroll;

using Microsoft.HumanResources.Setup;
using System.IO;

// Las importaciones SIRADIG agrupadas por MES DE PRESENTACIÓN y estado, con contadores por nodo.
//
// Las acciones corren sobre el ALCANCE del nodo donde uno esté parado: sobre un mes, todas sus
// importaciones; sobre un estado, las de ese estado; sobre una hoja, esa sola. Procesar toma de cada
// alcance únicamente las que están Pendientes de procesar, de modo que parado en el mes se procesa
// todo lo que falta en una sola pasada, con un único resumen al final.
page 110075 "Árbol de Importaciones SIRADIG"
{
    ApplicationArea = All;
    Caption = 'Árbol de Importaciones SIRADIG';
    PageType = List;
    UsageCategory = Lists;
    SourceTable = "Árbol SIRADIG Buffer";
    SourceTableTemporary = true;
    // El Editable = false va en el repeater y NO acá: a nivel página también apaga las acciones que no
    // son del registro.
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                Editable = false;
                ShowAsTree = true;
                IndentationColumn = Rec.Nivel;
                IndentationControls = Descripción;

                field(Descripción; Rec.Descripción)
                {
                    Caption = 'Mes de presentación / Estado / Importación';
                    StyleExpr = EstiloFila;

                    trigger OnDrillDown()
                    begin
                        Abrir();
                    end;
                }
                field(Cantidad; Rec.Cantidad)
                {
                    Caption = 'Importaciones';
                    BlankZero = true;
                    ToolTip = 'Cuántas importaciones cuelgan de este nodo.';
                }
                field(Pendientes; Rec.Pendientes)
                {
                    BlankZero = true;
                    ToolTip = 'Cuántas están pendientes de procesar: lo que procesa la acción Procesar en este nodo.';
                    StyleExpr = EstiloPendientes;
                }
                field("Con Errores"; Rec."Con Errores")
                {
                    BlankZero = true;
                    StyleExpr = EstiloErrores;
                }
                field(Procesadas; Rec.Procesadas)
                {
                    BlankZero = true;
                }
                field("No. Empleado"; Rec."No. Empleado") { }
                field("Nro. Presentación"; Rec."Nro. Presentación") { BlankZero = true; }
                field("Fecha Presentación"; Rec."Fecha Presentación") { }
                field("Deducciones Importadas"; Rec."Deducciones Importadas") { BlankZero = true; }
                field("Cargas Familia Importadas"; Rec."Cargas Familia Importadas") { BlankZero = true; }
                field(EstadoTxt; EstadoTxt)
                {
                    Caption = 'Estado';
                    StyleExpr = EstiloEstado;
                }
                field("Mensajes Error"; Rec."Mensajes Error") { }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            fileuploadaction(ImportarArchivos)
            {
                Caption = 'Importar Archivos SIRADIG';
                Image = Import;
                ToolTip = 'Selecciona uno o varios archivos SIRADIG desde tu PC para importar: .xml, .xml.zip (una presentación) o un .zip con las presentaciones de todos los trabajadores.';
                AllowMultipleFiles = true;

                trigger OnAction(files: List of [FileUpload])
                begin
                    ImportarArchivosSubidos(files);
                end;
            }
            action(ProcesarNodo)
            {
                Caption = 'Procesar';
                Image = Process;
                ToolTip = 'Procesa las importaciones pendientes de los nodos marcados: parado en un mes de presentación, todas las que falten; parado en una importación, esa sola.';

                trigger OnAction()
                var
                    Imp: Record "Importación SIRADIG";
                    Nodos: Record "Árbol SIRADIG Buffer" temporary;
                    Orquestador: Codeunit "Orquestador SIRADIG";
                    Cuantas: Integer;
                begin
                    Cuantas := PendientesSeleccion(Imp, Nodos);
                    if Cuantas = 0 then begin
                        Message(MsgSinPendientes);
                        exit;
                    end;
                    if Cuantas > 1 then
                        if not Confirm(StrSubstNo(QstProcesar, Cuantas), false) then
                            exit;
                    Orquestador.ProcesarFiltradas(Imp);
                    Cargar();
                end;
            }
            action(EliminarNodo)
            {
                Caption = 'Eliminar';
                Image = Delete;
                ToolTip = 'Elimina las importaciones de los nodos marcados que no estén procesadas exitosamente.';

                trigger OnAction()
                var
                    Imp: Record "Importación SIRADIG";
                    Nodos: Record "Árbol SIRADIG Buffer" temporary;
                    Cuantas: Integer;
                begin
                    Cuantas := EliminablesSeleccion(Imp, Nodos);
                    if Cuantas = 0 then begin
                        Message(MsgSinEliminables);
                        exit;
                    end;
                    if not Confirm(StrSubstNo(QstEliminar, Cuantas), false) then
                        exit;
                    Imp.DeleteAll();
                    Cargar();
                end;
            }
            action(AbrirAccion)
            {
                Caption = 'Abrir lista';
                Image = List;
                ToolTip = 'Abre la lista de importaciones acotada al mes de presentación y estado del nodo, para elegir a mano un subconjunto.';

                trigger OnAction()
                begin
                    Abrir();
                end;
            }
            action(Recargar)
            {
                Caption = 'Actualizar';
                Image = Refresh;
                ToolTip = 'Vuelve a leer las importaciones y recalcula los contadores.';

                trigger OnAction()
                begin
                    Cargar();
                end;
            }
            action(VerRegistroAfip)
            {
                Caption = 'Ver Registro AFIP WS';
                Image = ViewDetails;
                ToolTip = 'Abre el registro de interfaz AFIP asociado a la importación seleccionada, para trazabilidad.';
                Enabled = Rec."No. Importación" <> 0;

                trigger OnAction()
                var
                    Imp: Record "Importación SIRADIG";
                    AfipRegister: Record "AFIP Interface Register";
                begin
                    if not Imp.Get(Rec."No. Importación") then
                        exit;
                    if Imp."AFIP Register Entry No." = 0 then
                        exit;
                    AfipRegister.SetRange("Entry no.", Imp."AFIP Register Entry No.");
                    Page.Run(Page::"AFIP WS register", AfipRegister);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';
                actionref(ImportarProm; ImportarArchivos) { }
                actionref(ProcesarProm; ProcesarNodo) { }
                actionref(EliminarProm; EliminarNodo) { }
                actionref(AbrirProm; AbrirAccion) { }
                actionref(RecargarProm; Recargar) { }
            }
            group(Category_Navigate)
            {
                Caption = 'Navegar';
                actionref(AfipProm; VerRegistroAfip) { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Cargar();
    end;

    trigger OnAfterGetRecord()
    begin
        EstadoTxt := '';
        EstiloEstado := 'Standard';
        EstiloPendientes := 'Standard';
        EstiloErrores := 'Standard';
        if Rec.Nivel = 2 then begin
            EstadoTxt := Format(Rec.Estado);
            case Rec.Estado of
                Rec.Estado::"Procesado Exitosamente":
                    EstiloEstado := 'Favorable';
                Rec.Estado::"Procesado con Advertencias":
                    EstiloEstado := 'Ambiguous';
                Rec.Estado::"Error en Procesamiento":
                    EstiloEstado := 'Unfavorable';
            end;
        end;
        if Rec.Pendientes > 0 then
            EstiloPendientes := 'Attention';
        if Rec."Con Errores" > 0 then
            EstiloErrores := 'Unfavorable';

        case Rec.Nivel of
            0:
                EstiloFila := 'Strong';
            1:
                EstiloFila := 'StrongAccent';
            else
                EstiloFila := 'Standard';
        end;
    end;

    local procedure Cargar()
    var
        Imp: Record "Importación SIRADIG";
        Arbol: Codeunit "Árbol Importaciones SIRADIG";
        ClaveActual: Code[100];
    begin
        ClaveActual := Rec."Clave Orden";

        Arbol.Construir(Rec, Imp);

        // Toda acción termina reconstruyendo el árbol entero porque cambian los contadores de los
        // ancestros. Se vuelve al nodo donde se estaba; si ya no existe —se procesó o se eliminó lo
        // único que tenía— se cae al principio.
        if (ClaveActual = '') or not Rec.Get(ClaveActual) then
            if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;

    // Sobre una hoja, esa importación en la lista; sobre un nodo, la lista acotada al período y estado.
    local procedure Abrir()
    var
        Imp: Record "Importación SIRADIG";
        Arbol: Codeunit "Árbol Importaciones SIRADIG";
    begin
        if Rec."Clave Orden" = '' then
            exit;
        Arbol.AlcanceDeNodo(Rec, Imp);
        Page.Run(Page::"Importaciones SIRADIG", Imp);
    end;

    local procedure ImportarArchivosSubidos(var Files: List of [FileUpload])
    var
        Orquestador: Codeunit "Orquestador SIRADIG";
        ProcesarAutomaticamente: Boolean;
    begin
        if Files.Count = 0 then
            exit;
        ProcesarAutomaticamente := Confirm('¿Desea procesar automáticamente las importaciones?');
        Orquestador.ImportarArchivosSubidos(Files, ProcesarAutomaticamente);
        Cargar();
    end;

    local procedure NodosSeleccionados(var Nodos: Record "Árbol SIRADIG Buffer" temporary): Boolean
    var
        ClaveFoco: Code[100];
    begin
        Nodos.Reset();
        Nodos.DeleteAll();

        ClaveFoco := Rec."Clave Orden";

        CurrPage.SetSelectionFilter(Rec);
        if Rec.FindSet() then
            repeat
                Nodos := Rec;
                if Nodos.Insert() then;
            until Rec.Next() = 0;

        Rec.Reset();
        if ClaveFoco <> '' then
            if Rec.Get(ClaveFoco) then;

        // La clave vacía es el árbol sin ninguna fila: ese alcance no filtraría nada.
        if Nodos.IsEmpty() and (ClaveFoco <> '') then begin
            Nodos := Rec;
            if Nodos.Insert() then;
        end;

        exit(not Nodos.IsEmpty());
    end;

    // Marca las importaciones de los nodos que cumplan el estado pedido (-1 = cualquiera) y devuelve
    // cuántas son. El recorrido es de a una y con Mark: dos nodos solapados —un período y uno de sus
    // estados— no deben contar dos veces la misma importación.
    local procedure MarcarAlcance(var Imp: Record "Importación SIRADIG"; var Nodos: Record "Árbol SIRADIG Buffer" temporary; SoloPendientes: Boolean): Integer
    var
        ImpNodo: Record "Importación SIRADIG";
        Arbol: Codeunit "Árbol Importaciones SIRADIG";
        Cuantas: Integer;
    begin
        Imp.Reset();
        Imp.ClearMarks();

        if not NodosSeleccionados(Nodos) then
            exit(0);

        Nodos.FindSet();
        repeat
            Arbol.AlcanceDeNodo(Nodos, ImpNodo);
            if ImpNodo.FindSet() then
                repeat
                    if SoloPendientes then begin
                        if ImpNodo.Estado = ImpNodo.Estado::"Pendiente Procesar" then
                            if Imp.Get(ImpNodo."No.") then
                                Imp.Mark(true);
                    end else
                        if ImpNodo.Estado <> ImpNodo.Estado::"Procesado Exitosamente" then
                            if Imp.Get(ImpNodo."No.") then
                                Imp.Mark(true);
                until ImpNodo.Next() = 0;
        until Nodos.Next() = 0;

        // Sin Reset() acá: es justo la llamada que se lleva puestas las marcas recién puestas.
        Imp.MarkedOnly(true);

        // Se cuenta recorriendo: Count() trabaja sobre filtros y acá el alcance lo dan las MARCAS.
        if Imp.FindSet() then
            repeat
                Cuantas += 1;
            until Imp.Next() = 0;
        exit(Cuantas);
    end;

    local procedure PendientesSeleccion(var Imp: Record "Importación SIRADIG"; var Nodos: Record "Árbol SIRADIG Buffer" temporary): Integer
    begin
        exit(MarcarAlcance(Imp, Nodos, true));
    end;

    local procedure EliminablesSeleccion(var Imp: Record "Importación SIRADIG"; var Nodos: Record "Árbol SIRADIG Buffer" temporary): Integer
    begin
        exit(MarcarAlcance(Imp, Nodos, false));
    end;

    var
        EstadoTxt: Text;
        EstiloFila: Text;
        EstiloEstado: Text;
        EstiloPendientes: Text;
        EstiloErrores: Text;
        MsgSinPendientes: Label 'Lo marcado no tiene importaciones pendientes de procesar.';
        MsgSinEliminables: Label 'Lo marcado no tiene importaciones que se puedan eliminar.';
        QstProcesar: Label '¿Procesar las %1 importación(es) pendientes de lo marcado?', Comment = '%1=cantidad';
        QstEliminar: Label '¿Eliminar las %1 importación(es) de lo marcado que no están procesadas?', Comment = '%1=cantidad';
}
