namespace UAS.Payroll;

using Microsoft.Projects.Project.Job;

pageextension 50351 "Proyecto Pesca Card Ext." extends "Job Card"
{
    layout
    {
        addafter("Ending Date")
        {
            field("Hora ingreso a puerto"; Rec."Hora ingreso a puerto")
            {
                ApplicationArea = All;
                Caption = 'Hora de arribo';
                ToolTip = 'Hora de entrada a puerto. AM (antes de las 12:00) = día de puerto; PM (12:00 o después) = día de navegación.';
            }
            field("Hora de zarpada"; Rec."Hora de zarpada")
            {
                ApplicationArea = All;
                Caption = 'Hora de zarpada';
                ToolTip = 'Hora de salida del puerto. AM (antes de las 12:00) = día de navegación; PM (12:00 o después) = día de puerto.';
            }
            field("Estado Liq. Personal Predet."; Rec."Estado Liq. Personal Predet.")
            {
                ApplicationArea = All;
                ToolTip = 'Estado que se asigna automáticamente en el historial del empleado al darlo de alta en este proyecto (campo "Fecha Alta Asignación" en Personal Proyecto). Si se deja en blanco, no se realiza ninguna asignación automática.';
            }
            field("Zona Desfavorable"; Rec."Zona Desfavorable")
            {
                ApplicationArea = All;
                ToolTip = 'Zona desfavorable (adicional patagónico) del viaje. La comparte toda la dotación de la marea. Si es 0, el motor usa la zona de la ficha de cada empleado.';
            }
            field("Proyecto Inactividad Nómina"; Rec."Proyecto Inactividad Nómina")
            {
                ApplicationArea = All;
                ToolTip = 'Proyecto al que se asigna automáticamente un empleado de esta marea cuando pasa de un estado activo a uno inactivo (ej. NV → FR). Si está en blanco, se usa el "Proyecto Nómina" de Configuración RR.HH.';
            }
        }
        addlast(FactBoxes)
        {
            part(Personal; "Personal Proyecto")
            {
                ApplicationArea = All;
                Caption = 'Personal';
                SubPageLink = "No. Proyecto" = FIELD("No.");
                Visible = true;
            }
        }
    }

    actions
    {
        addlast(navigation)
        {
            group(GrpPesca)
            {
                Caption = 'Personal';

                action(VerTripulacion)
                {
                    ApplicationArea = All;
                    Caption = 'Personal Asignado';
                    Image = Resource;
                    RunObject = Page "Personal Proyecto";
                    RunPageLink = "No. Proyecto" = FIELD("No.");
                }
                action(CopiarPersonal)
                {
                    ApplicationArea = All;
                    Caption = 'Copiar Personal de Proyecto';
                    Image = CopyToTask;
                    ToolTip = 'Copia la tripulación de otro proyecto (marea) a éste. Útil para repetir la dotación de una marea anterior. Las fechas se toman de este proyecto; los empleados ya asignados se omiten.';

                    trigger OnAction()
                    var
                        JobOrigen: Record Job;
                        PersOrigen: Record "Personal Proyecto";
                        PersNueva: Record "Personal Proyecto";
                        Copiados: Integer;
                        Omitidos: Integer;
                    begin
                        Rec.TestField("No.");
                        JobOrigen.SetFilter("No.", '<>%1', Rec."No.");
                        if Page.RunModal(Page::"Job List", JobOrigen) <> Action::LookupOK then
                            exit;

                        PersOrigen.SetRange("No. Proyecto", JobOrigen."No.");
                        if not PersOrigen.FindSet() then begin
                            Message(MsgSinPersonal, JobOrigen."No.");
                            exit;
                        end;
                        repeat
                            if PersNueva.Get(PersOrigen."No. Empleado", Rec."No.") then
                                Omitidos += 1
                            else begin
                                PersNueva.Init();
                                PersNueva."No. Empleado" := PersOrigen."No. Empleado";
                                PersNueva."No. Proyecto" := Rec."No.";
                                PersNueva."Cód. Convenio" := PersOrigen."Cód. Convenio";
                                PersNueva."Cód. Categoría" := PersOrigen."Cód. Categoría";
                                PersNueva."Rol en Proyecto" := PersOrigen."Rol en Proyecto";
                                PersNueva.Observaciones := PersOrigen.Observaciones;
                                // Re-derives Buque/Marea and defaults the dates from THIS project.
                                PersNueva.Validate("No. Proyecto");
                                PersNueva.Insert(true);
                                Copiados += 1;
                            end;
                        until PersOrigen.Next() = 0;
                        Message(MsgCopiados, Copiados, Omitidos, JobOrigen."No.");
                        CurrPage.Update(false);
                    end;
                }
                action(VerLiquidaciones)
                {
                    ApplicationArea = All;
                    Caption = 'Liquidaciones';
                    Image = PaymentJournal;
                    RunObject = Page "Lista Liquidaciones";
                    RunPageLink = "No. Proyecto" = FIELD("No.");
                    ToolTip = 'Muestra todas las liquidaciones generadas para este proyecto.';
                }
                action(LiquidarMarea)
                {
                    ApplicationArea = All;
                    Caption = 'Liquidar Personal (Regular)';
                    Image = Calculate;
                    Promoted = true;
                    PromotedCategory = Process;
                    ToolTip = 'Crea liquidaciones Regular en borrador para el personal activo que aún no tenga una para este proyecto.';

                    trigger OnAction()
                    var
                        Periodo: Record "Período Liquidación";
                        ProcLiq: Codeunit "Proceso Liq. Por Lote";
                        TipoLiquidacion: Code[20];
                        Creadas: Integer;
                    begin
                        if Page.RunModal(Page::"Períodos Liquidación", Periodo) <> Action::LookupOK then
                            exit;
                        TipoLiquidacion := 'REGULAR';
                        Creadas := ProcLiq.CrearPorProyecto(Rec, Periodo.Código, TipoLiquidacion);
                        Message(MsgCreadosFmt, Creadas, Periodo.Código);
                    end;
                }
                action(LiquidarDevengados)
                {
                    ApplicationArea = All;
                    Caption = 'Crear Devengados';
                    Image = PaymentPeriod;
                    Promoted = true;
                    PromotedCategory = Process;
                    ToolTip = 'Crea liquidaciones de Devengados (fijos mensuales sin producción) para el personal activo en este proyecto.';

                    trigger OnAction()
                    var
                        Periodo: Record "Período Liquidación";
                        ProcLiq: Codeunit "Proceso Liq. Por Lote";
                        TipoLiquidacion: Code[20];
                        Creadas: Integer;
                    begin
                        if Page.RunModal(Page::"Períodos Liquidación", Periodo) <> Action::LookupOK then
                            exit;
                        TipoLiquidacion := 'DEVENGADOS';
                        Creadas := ProcLiq.CrearPorProyecto(Rec, Periodo.Código, TipoLiquidacion);
                        Message(MsgCreadosFmt, Creadas, Periodo.Código);
                    end;
                }
                action(LiquidarCierreMarea)
                {
                    ApplicationArea = All;
                    Caption = 'Crear Cierre Marea';
                    Image = Approval;
                    Promoted = true;
                    PromotedCategory = Process;
                    ToolTip = 'Crea la liquidación de Cierre Marea (navegación + producción) para todo el personal del viaje. El período se deriva automáticamente de la fecha de arribo.';
                    Enabled = HasEndingDate;

                    trigger OnAction()
                    var
                        ProcLiq: Codeunit "Proceso Liq. Por Lote";
                        Creadas: Integer;
                    begin
                        Creadas := ProcLiq.CrearCierreMarea(Rec);
                        Message(MsgCierreMareaFmt, Creadas, Rec."Ending Date");
                    end;
                }
                action(CrearNuevaMarea)
                {
                    ApplicationArea = All;
                    Caption = 'Crear Nueva Marea';
                    Image = NewItem;
                    Promoted = true;
                    PromotedCategory = Process;
                    ToolTip = 'Genera un nuevo proyecto (marea) copiando tareas, personal, parámetros y dimensiones de éste, incrementando la Marea (Dim. Global 2) en uno. La fecha de inicio se toma de la fecha de arribo de esta marea.';

                    trigger OnAction()
                    var
                        GestionMarea: Codeunit "Gestión Marea";
                        NuevaJob: Record Job;
                        NuevoNo: Code[20];
                    begin
                        if not Confirm(QstNuevaMarea, true, Rec."No.") then
                            exit;
                        NuevoNo := GestionMarea.CrearNuevaMarea(Rec);
                        Message(MsgNuevaMarea, NuevoNo);
                        if NuevaJob.Get(NuevoNo) then
                            Page.Run(Page::"Job Card", NuevaJob);
                    end;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        HasEndingDate := Rec."Ending Date" <> 0D;
    end;

    var
        HasEndingDate: Boolean;
        MsgCreadosFmt: Label '%1 liquidación(es) creada(s) en borrador para el período %2.';
        MsgCierreMareaFmt: Label '%1 liquidación(es) de Cierre Marea creada(s) en borrador (arribo %2).';
        MsgCopiados: Label '%1 empleado(s) copiado(s), %2 omitido(s) (ya asignados), desde el proyecto %3.';
        MsgSinPersonal: Label 'El proyecto %1 no tiene personal asignado para copiar.';
        QstNuevaMarea: Label 'Crear una nueva marea copiando tareas, personal, parámetros y dimensiones de %1. ¿Continuar?';
        MsgNuevaMarea: Label 'Nueva marea creada: %1.';
}
