namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

page 50110 "Períodos Liquidación"
{
    ApplicationArea = All;
    Caption = 'Períodos Liquidación';
    PageType = List;
    SourceTable = "Período Liquidación";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Año; Rec.Año) { ApplicationArea = All; }
                field(Mes; Rec.Mes) { ApplicationArea = All; }
                field("Fecha Desde"; Rec."Fecha Desde") { ApplicationArea = All; }
                field("Fecha Hasta"; Rec."Fecha Hasta") { ApplicationArea = All; }
                field(Estado; Rec.Estado)
                {
                    ApplicationArea = All;
                    StyleExpr = EstadoStyle;
                }
                field("Cód. Calendario"; Rec."Cód. Calendario")
                {
                    ApplicationArea = All;
                    ToolTip = 'Calendario base que define los días no laborables. Vacío = se cuentan días lunes a viernes.';
                }
                field("Cant. Liquidaciones"; Rec."Cant. Liquidaciones")
                {
                    ApplicationArea = All;
                    // Hidden by default: this is a Count FlowField that triggers a
                    // SELECT COUNT(*) per visible row. Users can enable via personalization.
                    Visible = false;
                }
                field("Fecha Cierre"; Rec."Fecha Cierre") { ApplicationArea = All; Editable = false; }
                field("Usuario Cierre"; Rec."Usuario Cierre") { ApplicationArea = All; Editable = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CerrarPeriodo)
            {
                ApplicationArea = All;
                Caption = 'Cerrar Período';
                Image = Close;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = Rec.Estado = Rec.Estado::Abierto;

                trigger OnAction()
                begin
                    if not Confirm('¿Confirma el cierre del período %1? Esta acción no se puede deshacer.', false, Rec.Código) then
                        exit;
                    Rec.Estado := Rec.Estado::Cerrado;
                    Rec."Fecha Cierre" := Today();
                    Rec."Usuario Cierre" := CopyStr(UserId(), 1, 50);
                    Rec.Modify(true);
                    CurrPage.Update(false);
                end;
            }
            action(EliminarBorradores)
            {
                ApplicationArea = All;
                Caption = 'Eliminar Borradores';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = Rec.Estado = Rec.Estado::Abierto;

                trigger OnAction()
                var
                    Liq: Record "Liquidación";
                    Eliminadas: Integer;
                begin
                    Liq.SetRange("Cód. Período", Rec.Código);
                    Liq.SetRange(Estado, Liq.Estado::Borrador);
                    Eliminadas := Liq.Count();
                    if Eliminadas = 0 then begin
                        Message(MsgSinBorradores);
                        exit;
                    end;

                    if not Confirm(QstEliminarBorradores, false, Eliminadas, Rec.Código) then
                        exit;

                    Liq.FindSet();
                    repeat
                        Liq.Delete(true);
                    until Liq.Next() = 0;

                    CurrPage.Update(false);
                    Message(MsgEliminadas, Eliminadas, Rec.Código);
                end;
            }
            action(RevertirCalculadas)
            {
                ApplicationArea = All;
                Caption = 'Revertir Calculadas';
                Image = Undo;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = Rec.Estado = Rec.Estado::Abierto;

                trigger OnAction()
                var
                    Liq: Record "Liquidación";
                    GestionLiq: Codeunit "Gestión Liquidación";
                    Revertidas: Integer;
                begin
                    Liq.SetRange("Cód. Período", Rec.Código);
                    Liq.SetRange(Estado, Liq.Estado::Calculada);
                    if Liq.IsEmpty() then begin
                        Message(MsgSinCalculadas);
                        exit;
                    end;

                    if not Confirm(QstRevertirCalculadas, false, Rec.Código) then
                        exit;

                    Liq.FindSet();
                    repeat
                        GestionLiq.Reabrir(Liq);
                        Revertidas += 1;
                    until Liq.Next() = 0;

                    CurrPage.Update(false);
                    Message(MsgRevertidas, Revertidas, Rec.Código);
                end;
            }
            action(ReabrirPeriodo)
            {
                ApplicationArea = All;
                Caption = 'Reabrir Período';
                Image = ReOpen;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = Rec.Estado = Rec.Estado::Cerrado;

                trigger OnAction()
                var
                    Liq: Record "Liquidación";
                    GestionLiq: Codeunit "Gestión Liquidación";
                    Revertidas: Integer;
                begin
                    if not Confirm(QstReabrirPeriodo, false, Rec.Código) then
                        exit;

                    Liq.SetRange("Cód. Período", Rec.Código);
                    Liq.SetRange(Estado, Liq.Estado::Contabilizada);
                    if not Liq.IsEmpty() then
                        Error(ErrContabilizadas, Rec.Código);

                    Liq.SetFilter(Estado, '%1|%2', Liq.Estado::Aprobada, Liq.Estado::Calculada);
                    if Liq.FindSet() then
                        repeat
                            if Liq.Estado = Liq.Estado::Aprobada then begin
                                Liq.Estado := Liq.Estado::Calculada;
                                Liq.Modify(true);
                            end;
                            GestionLiq.Reabrir(Liq);
                            Revertidas += 1;
                        until Liq.Next() = 0;

                    Rec.Estado := Rec.Estado::Abierto;
                    Rec."Fecha Cierre" := 0D;
                    Rec."Usuario Cierre" := '';
                    Rec.Modify(true);
                    CurrPage.Update(false);
                    Message(MsgPeriodoReabierto, Rec.Código, Revertidas);
                end;
            }
            action(CrearLiquidaciones)
            {
                ApplicationArea = All;
                Caption = 'Crear Liquidaciones';
                Image = CreateDocuments;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = Rec.Estado = Rec.Estado::Abierto;

                trigger OnAction()
                var
                    ProcLiq: Codeunit "Proceso Liq. Por Lote";
                    TipoLiquidacion: Code[20];
                    Creadas: Integer;
                begin
                    if not Confirm(QstCrearLiqs, true, Rec.Código) then
                        exit;
                    TipoLiquidacion := 'REGULAR';
                    Creadas := ProcLiq.CrearPorPeriodo(Rec.Código, TipoLiquidacion, 0);
                    Message(MsgCreadas, Creadas, Rec.Código);
                    CurrPage.Update(false);
                end;
            }
            action(CrearLiqEmpleado)
            {
                ApplicationArea = All;
                Caption = 'Crear Liq. para Empleado';
                Image = Employee;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = Rec.Estado = Rec.Estado::Abierto;

                trigger OnAction()
                var
                    CrearLiqRpt: Report "Crear Liq. para Empleado";
                begin
                    CrearLiqRpt.SetPeriodo(Rec.Código);
                    CrearLiqRpt.RunModal();
                    CurrPage.Update(false);
                end;
            }
            action(CalcularPeriodo)
            {
                ApplicationArea = All;
                Caption = 'Calcular Período';
                Image = Calculate;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = Rec.Estado = Rec.Estado::Abierto;

                trigger OnAction()
                var
                    ProcLiq: Codeunit "Proceso Liq. Por Lote";
                    TipoLiquidacion: Code[20];
                    Calculadas: Integer;
                begin
                    if not Confirm(QstCalcular, true, Rec.Código) then
                        exit;
                    TipoLiquidacion := 'REGULAR';
                    Calculadas := ProcLiq.CalcularPorPeriodo(Rec.Código, TipoLiquidacion);
                    Message(MsgCalculadas, Calculadas, Rec.Código);
                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(VerLiquidaciones)
            {
                ApplicationArea = All;
                Caption = 'Liquidaciones';
                Image = List;
                RunObject = Page "Lista Liquidaciones";
                                RunPageLink = "Cód. Período" = FIELD(Código);
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        if Rec.Estado = Rec.Estado::Cerrado then
            EstadoStyle := 'Subordinate'
        else
            EstadoStyle := 'Favorable';
    end;

    var
        EstadoStyle: Text;
        QstEliminarBorradores: Label '¿Eliminar %1 liquidación(es) en estado Borrador del período %2? Esta acción no se puede deshacer.';
        MsgSinBorradores: Label 'No hay liquidaciones en estado Borrador en este período.';
        MsgEliminadas: Label '%1 liquidación(es) eliminada(s) del período %2.';
        QstRevertirCalculadas: Label '¿Revertir todas las liquidaciones calculadas del período %1 a Borrador?';
        MsgSinCalculadas: Label 'No hay liquidaciones en estado Calculada en este período.';
        MsgRevertidas: Label '%1 liquidación(es) revertida(s) a Borrador en el período %2.';
        QstReabrirPeriodo: Label '¿Confirma la reapertura del período %1? Todas las liquidaciones calculadas/aprobadas volverán a estado Borrador.';
        ErrContabilizadas: Label 'Existen liquidaciones contabilizadas en el período %1. Revierta la contabilización antes de reabrir.';
        MsgPeriodoReabierto: Label 'Período %1 reabierto. %2 liquidación(es) revertida(s) a Borrador.';
        QstCrearLiqs: Label '¿Crear liquidaciones para todos los empleados activos del período %1?';
        QstCalcular: Label '¿Calcular todas las liquidaciones del período %1?';
        MsgCreadas: Label '%1 liquidación(es) creada(s) en el período %2.';
        MsgCalculadas: Label '%1 liquidación(es) calculada(s) en el período %2.';
}
