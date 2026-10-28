namespace UAS.Payroll;

page 110065 "Cuenta Corriente Francos"
{
    Caption = 'Cuenta corriente de francos';
    PageType = List;
    SourceTable = "Movimiento Franco Liq.";
    ApplicationArea = All;
    UsageCategory = History;
    Editable = false;
    SourceTableView = sorting("No. Movimiento") order(descending);
    layout
    {
        area(Content)
        {
            repeater(Movimientos)
            {
                field("No. Movimiento"; Rec."No. Movimiento") { }
                field("No. Empleado"; Rec."No. Empleado") { }
                field(Tipo; Rec.Tipo) { }
                field("No. Lote"; Rec."No. Lote") { }
                field("Fecha Devengamiento"; Rec."Fecha Devengamiento") { }
                field(Cantidad; Rec.Cantidad) { }
                field("No. Liquidación"; Rec."No. Liquidación") { }
                field("No. Línea Origen"; Rec."No. Línea Origen") { }
                field("Revierte Movimiento"; Rec."Revierte Movimiento") { }
                field("Cód. Convenio"; Rec."Cód. Convenio") { }
                field("Cód. Categoría"; Rec."Cód. Categoría") { }
                field("Cód. Puesto"; Rec."Cód. Puesto") { }
                field("Cód. Estado"; Rec."Cód. Estado") { }
                field("No. Proyecto"; Rec."No. Proyecto") { }
                field("Cód. Período"; Rec."Cód. Período") { }
                field(Reconstruido; Rec.Reconstruido) { }
                field(SystemCreatedAt; Rec.SystemCreatedAt) { Caption = 'Registrado el'; }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(Inicializar)
            {
                Caption = 'Reconstruir cuenta del empleado';
                Image = Calculate;
                ToolTip = 'Reconstruye lotes y consumos FIFO de recibos vigentes. Activa la cuenta sólo si todos los consumos tienen respaldo. No modifica los recibos.';
                trigger OnAction()
                var
                    Cuenta: Codeunit "Cuenta Corriente Francos";
                    Empleado: Code[20];
                begin
                    Empleado := FEmpleado;
                    if Empleado = '' then Empleado := Rec."No. Empleado";
                    if Empleado = '' then Error('Abrí la cuenta desde la ficha de un empleado.');
                    Cuenta.Inicializar(Empleado);
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted) { actionref(InicializarPromoted; Inicializar) { } }
    }
    var
        FEmpleado: Code[20];

    procedure SetEmpleado(Empleado: Code[20])
    begin
        FEmpleado := Empleado;
        Rec.FilterGroup(2);
        Rec.SetRange("No. Empleado", Empleado);
        Rec.FilterGroup(0);
    end;

}
