namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using System.Environment;

// El tablero de la sincronización con NAV 2013R2. Una fila por entidad, y de un vistazo las dos
// mitades del mecanismo: cuándo se trajo del origen y cuándo aplicó el Job Queue de BC.
//
// Si algo no llegó a BC, la respuesta está en esta pantalla y en un solo orden:
//   1. "Última Traída" vieja o vacía  → el problema es de la traída (job del Agent, o los web services).
//   2. Hay pendientes hace rato       → el Job Queue no está corriendo.
//   3. Hay filas con error            → el dato llegó y no se pudo aplicar; el motivo está en cada fila.
page 110032 "Control Sinc. NAV"
{
    ApplicationArea = All;
    Caption = 'Sincronización con NAV';
    PageType = List;
    UsageCategory = Administration;
    SourceTable = "Ctrl Sinc NAV";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Entidades)
            {
                field(Entidad; Rec.Entidad)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Qué se sincroniza. El orden de la lista es el orden en que se aplican: un proyecto tiene que existir antes que su descarga.';
                }
                field(Habilitada; Rec.Habilitada)
                {
                    ApplicationArea = All;
                    ToolTip = 'Destildarla corta la sincronización de esta entidad sin desarmar el job de SQL ni la entrada de proyecto. Lo que ya está en espera queda donde está.';
                }
                field(Pendientes; Pendientes)
                {
                    ApplicationArea = All;
                    Caption = 'Pendientes';
                    Editable = false;
                    StyleExpr = EstiloPendientes;
                    ToolTip = 'Filas traídas de NAV que todavía no se aplicaron. Con el proceso corriendo cada 15 minutos, un número que no baja significa que la entrada de proyecto no está activa.';

                    trigger OnDrillDown()
                    begin
                        AbrirStaging();
                    end;
                }
                field(ConError; ConError)
                {
                    ApplicationArea = All;
                    Caption = 'Con Error';
                    Editable = false;
                    StyleExpr = EstiloError;
                    ToolTip = 'Filas que llegaron y no se pudieron aplicar. Cada una tiene el motivo anotado; no se reintentan solas.';

                    trigger OnDrillDown()
                    begin
                        AbrirStaging();
                    end;
                }
                field("Traido El"; Rec."Traido El")
                {
                    ApplicationArea = All;
                    ToolTip = 'Cuándo se trajeron por última vez filas de NAV. Con transporte SQL lo escribe el job del Agent; con web services, la propia entrada de proyecto. Si está viejo, el problema es de la traída y no de BC.';
                }
                field("Filas Traidas"; Rec."Filas Traidas")
                {
                    ApplicationArea = All;
                    ToolTip = 'Cuántas filas trajo la última corrida. Cero es lo normal cuando en NAV no se creó ni modificó nada.';
                }
                field("Procesado El"; Rec."Procesado El")
                {
                    ApplicationArea = All;
                    ToolTip = 'Cuándo aplicó por última vez el proceso de BC.';
                }
                field("Ultima Observacion"; Rec."Ultima Observacion")
                {
                    ApplicationArea = All;
                    ToolTip = 'Cómo salió el último proceso: cuántas se aplicaron, cuántas quedaron esperando y cuántas fallaron.';
                }
                field("Marca Agua"; Rec."Marca Agua")
                {
                    ApplicationArea = All;
                    ToolTip = 'Hasta qué punto del origen se leyó. NO significa lo mismo en los dos transportes: con SQL es el rowversion de la tabla, con web services es el Entry_No del registro de cambios. Al cambiar de transporte hay que vaciarla: un rowversion leído como Entry_No no da error, deja todo afuera. Vaciarla hace que la próxima corrida vuelva a ofrecer todo el origen; no borra nada en BC.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(TraerAhora)
            {
                ApplicationArea = All;
                Caption = 'Traer ahora de NAV';
                Image = Import;
                ToolTip = 'Pide al origen lo que cambió desde la última marca de agua y lo deja en el staging, sin aplicarlo. Sólo con transporte por web services: con SQL la traída la hace el job del Agent.';

                trigger OnAction()
                var
                    Traedor: Codeunit "Traer NAV WS";
                    Filas: Integer;
                begin
                    // Sólo la entidad seleccionada, no todas: traer las 240.000 líneas de descarga
                    // sin querer, desde una pantalla, es demasiado fácil.
                    Filas := Traedor.TraerEntidad(CopyStr(CompanyName(), 1, 30), Rec.Entidad);
                    if Filas < 0 then
                        Message(MsgFalloTraida, Traedor.GetUltimoError())
                    else
                        Message(MsgTraidas, Filas);
                    CurrPage.Update(false);
                end;
            }
            action(ProcesarTodo)
            {
                ApplicationArea = All;
                Caption = 'Procesar pendientes';
                Image = Apply;
                ToolTip = 'Aplica ahora todo lo que esté pendiente, en orden de dependencia. Es lo mismo que hace la entrada de proyecto cada 15 minutos.';

                trigger OnAction()
                var
                    Sinc: Codeunit "Sinc NAV Liq.";
                    Aplicadas: Integer;
                begin
                    Aplicadas := Sinc.ProcesarTodo();
                    Message(MsgProcesado, Aplicadas);
                    CurrPage.Update(false);
                end;
            }
            action(ProcesarEntidad)
            {
                ApplicationArea = All;
                Caption = 'Procesar sólo esta entidad';
                Image = ApplyEntries;
                ToolTip = 'Aplica lo pendiente de la entidad seleccionada. Útil para desatascar una sola cosa sin correr todo.';

                trigger OnAction()
                var
                    Sinc: Codeunit "Sinc NAV Liq.";
                begin
                    Message(MsgProcesado, Sinc.ProcesarEntidad(Rec.Entidad));
                    CurrPage.Update(false);
                end;
            }
            action(VerFilas)
            {
                ApplicationArea = All;
                Caption = 'Ver filas traídas';
                Image = List;
                ToolTip = 'Abre las filas que trajo NAV para esta entidad, con su estado y el motivo de las que no se aplicaron.';

                trigger OnAction()
                begin
                    AbrirStaging();
                end;
            }
            action(ReprocesarErrores)
            {
                ApplicationArea = All;
                Caption = 'Reintentar las que fallaron';
                Image = Restore;
                ToolTip = 'Devuelve a pendiente las filas en error de esta entidad para que el próximo proceso las vuelva a intentar. Antes hay que haber corregido lo que las hacía fallar.';

                trigger OnAction()
                var
                    Sinc: Codeunit "Sinc NAV Liq.";
                begin
                    Message(MsgReabiertas, Sinc.ReprocesarErrores(Rec.Entidad));
                    CurrPage.Update(false);
                end;
            }
            action(ForzarResincronizacion)
            {
                ApplicationArea = All;
                Caption = 'Volver a traer todo';
                Image = RefreshLines;
                ToolTip = 'Vacía la marca de agua: la próxima corrida del job de SQL vuelve a ofrecer TODAS las filas del origen, no sólo las nuevas. No borra nada en BC, pero puede ser un lote grande.';

                trigger OnAction()
                begin
                    if not Confirm(ConfirmResinc, false, Rec.Entidad) then
                        exit;
                    Rec."Marca Agua" := '';
                    Rec.Modify(true);
                end;
            }
        }
        area(Navigation)
        {
            action(Configuracion)
            {
                ApplicationArea = All;
                Caption = 'Configuración';
                Image = Setup;
                RunObject = page "Config Sinc NAV";
                ToolTip = 'Dónde está NAV y a qué empresa de BC le corresponde: linked server, base y empresa de origen. Es lo único que hay que cargar para que la sincronización sepa de dónde traer.';
            }
            action(EmpleadosPendientes)
            {
                ApplicationArea = All;
                Caption = 'Empleados a completar';
                Image = Employee;
                RunObject = page "Employee List";
                RunPageView = where("Cód. Convenio" = filter(''));
                ToolTip = 'Los empleados que todavía no tienen convenio: los que llegaron de NAV nacen así, porque el convenio y la categoría se definen en BC. Hasta que los tengan, el motor no les arma ninguna liquidación. Es la misma lista que la vista "Pendientes de completar (Sinc.)".';
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(ProcesarTodo_Promoted; ProcesarTodo) { }
                actionref(VerFilas_Promoted; VerFilas) { }
                actionref(ReprocesarErrores_Promoted; ReprocesarErrores) { }
                actionref(EmpleadosPendientes_Promoted; EmpleadosPendientes) { }
            }
        }
    }

    var
        Pendientes: Integer;
        ConError: Integer;
        EstiloPendientes: Text;
        EstiloError: Text;
        MsgProcesado: Label '%1 filas aplicadas.', Comment = '%1 = cantidad';
        MsgReabiertas: Label '%1 filas vuelven a estar pendientes.', Comment = '%1 = cantidad';
        MsgTraidas: Label '%1 fila(s) traídas al staging. Todavía no se aplicaron.', Comment = '%1 = cantidad';
        MsgFalloTraida: Label 'No se pudo traer.\%1', Comment = '%1 = motivo';
        ConfirmResinc: Label '¿Volver a traer todo el historial de %1 desde NAV en la próxima corrida?', Comment = '%1 = entidad';

    trigger OnOpenPage()
    begin
        Rec.AsegurarFilas();
    end;

    trigger OnAfterGetRecord()
    begin
        ContarFilas();
        EstiloPendientes := '';
        if Pendientes > 0 then
            EstiloPendientes := 'Ambiguous';
        EstiloError := '';
        if ConError > 0 then
            EstiloError := 'Unfavorable';
    end;

    local procedure ContarFilas()
    var
        StgEmp: Record "Stg Empleado NAV";
        StgProy: Record "Stg Proyecto NAV";
        StgCab: Record "Stg Descarga Cab NAV";
        StgLin: Record "Stg Descarga Lin NAV";
        StgDim: Record "Stg Valor Dim NAV";
        StgICC: Record "Stg Informe Cap Cab NAV";
        StgICL: Record "Stg Informe Cap Lin NAV";
        StgDAC: Record "Stg Dia Abordo Cab NAV";
        StgDAL: Record "Stg Dia Abordo Lin NAV";
    begin
        Pendientes := 0;
        ConError := 0;
        case Rec.Entidad of
            "Entidad Sinc NAV"::"Valor Dimension":
                begin
                    StgDim.SetRange("Estado Sinc", "Estado Sinc NAV"::Pendiente);
                    Pendientes := StgDim.Count();
                    StgDim.SetRange("Estado Sinc", "Estado Sinc NAV"::Error);
                    ConError := StgDim.Count();
                end;
            "Entidad Sinc NAV"::Empleado:
                begin
                    StgEmp.SetRange("Estado Sinc", "Estado Sinc NAV"::Pendiente);
                    Pendientes := StgEmp.Count();
                    StgEmp.SetRange("Estado Sinc", "Estado Sinc NAV"::Error);
                    ConError := StgEmp.Count();
                end;
            "Entidad Sinc NAV"::Proyecto:
                begin
                    StgProy.SetRange("Estado Sinc", "Estado Sinc NAV"::Pendiente);
                    Pendientes := StgProy.Count();
                    StgProy.SetRange("Estado Sinc", "Estado Sinc NAV"::Error);
                    ConError := StgProy.Count();
                end;
            "Entidad Sinc NAV"::"Descarga Cabecera":
                begin
                    StgCab.SetRange("Estado Sinc", "Estado Sinc NAV"::Pendiente);
                    Pendientes := StgCab.Count();
                    StgCab.SetRange("Estado Sinc", "Estado Sinc NAV"::Error);
                    ConError := StgCab.Count();
                end;
            "Entidad Sinc NAV"::"Descarga Linea":
                begin
                    StgLin.SetRange("Estado Sinc", "Estado Sinc NAV"::Pendiente);
                    Pendientes := StgLin.Count();
                    StgLin.SetRange("Estado Sinc", "Estado Sinc NAV"::Error);
                    ConError := StgLin.Count();
                end;
            "Entidad Sinc NAV"::"Informe Cap Cabecera":
                begin
                    StgICC.SetRange("Estado Sinc", "Estado Sinc NAV"::Pendiente);
                    Pendientes := StgICC.Count();
                    StgICC.SetRange("Estado Sinc", "Estado Sinc NAV"::Error);
                    ConError := StgICC.Count();
                end;
            "Entidad Sinc NAV"::"Informe Cap Linea":
                begin
                    StgICL.SetRange("Estado Sinc", "Estado Sinc NAV"::Pendiente);
                    Pendientes := StgICL.Count();
                    StgICL.SetRange("Estado Sinc", "Estado Sinc NAV"::Error);
                    ConError := StgICL.Count();
                end;
            "Entidad Sinc NAV"::"Dia Abordo Cabecera":
                begin
                    StgDAC.SetRange("Estado Sinc", "Estado Sinc NAV"::Pendiente);
                    Pendientes := StgDAC.Count();
                    StgDAC.SetRange("Estado Sinc", "Estado Sinc NAV"::Error);
                    ConError := StgDAC.Count();
                end;
            "Entidad Sinc NAV"::"Dia Abordo Linea":
                begin
                    StgDAL.SetRange("Estado Sinc", "Estado Sinc NAV"::Pendiente);
                    Pendientes := StgDAL.Count();
                    StgDAL.SetRange("Estado Sinc", "Estado Sinc NAV"::Error);
                    ConError := StgDAL.Count();
                end;
        end;
    end;

    local procedure AbrirStaging()
    var
        StgEmp: Record "Stg Empleado NAV";
        StgProy: Record "Stg Proyecto NAV";
        StgCab: Record "Stg Descarga Cab NAV";
        StgLin: Record "Stg Descarga Lin NAV";
        StgDim: Record "Stg Valor Dim NAV";
        StgICC: Record "Stg Informe Cap Cab NAV";
        StgICL: Record "Stg Informe Cap Lin NAV";
        StgDAC: Record "Stg Dia Abordo Cab NAV";
        StgDAL: Record "Stg Dia Abordo Lin NAV";
    begin
        case Rec.Entidad of
            "Entidad Sinc NAV"::"Valor Dimension":
                Page.Run(Page::"Sinc. Valores Dim. NAV", StgDim);
            "Entidad Sinc NAV"::Empleado:
                Page.Run(Page::"Sinc. Empleados NAV", StgEmp);
            "Entidad Sinc NAV"::Proyecto:
                Page.Run(Page::"Sinc. Proyectos NAV", StgProy);
            "Entidad Sinc NAV"::"Descarga Cabecera":
                Page.Run(Page::"Sinc. Cab. Descargas NAV", StgCab);
            "Entidad Sinc NAV"::"Descarga Linea":
                Page.Run(Page::"Sinc. Lín. Descargas NAV", StgLin);
            "Entidad Sinc NAV"::"Informe Cap Cabecera":
                Page.Run(Page::"Sinc. Informe Cap. Cab NAV", StgICC);
            "Entidad Sinc NAV"::"Informe Cap Linea":
                Page.Run(Page::"Sinc. Informe Cap. Lin NAV", StgICL);
            "Entidad Sinc NAV"::"Dia Abordo Cabecera":
                Page.Run(Page::"Sinc. Dia Abordo Cab NAV", StgDAC);
            "Entidad Sinc NAV"::"Dia Abordo Linea":
                Page.Run(Page::"Sinc. Dia Abordo Lin NAV", StgDAL);
        end;
    end;
}
