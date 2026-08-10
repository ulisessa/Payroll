namespace UAS.Payroll;

page 50192 "Estados de Buque"
{
    // Read-only view of a vessel's state history (Estado Empleado filtered to Tipo Entidad = Buque).
    PageType = List;
    Caption = 'Estados de Buque';
    SourceTable = "Estado Empleado";
    UsageCategory = None;
    ApplicationArea = All;
    Editable = false;
    SourceTableView = sorting("Tipo Entidad", "No. Empleado", "Fecha Inicio") order(descending);

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Buque; Rec."No. Empleado")
                {
                    ApplicationArea = All;
                    Caption = 'Buque';
                }
                field("Fecha Inicio"; Rec."Fecha Inicio")
                {
                    ApplicationArea = All;
                }
                field("Cód. Estado"; Rec."Cód. Estado")
                {
                    ApplicationArea = All;
                }
                field("Descripción Estado"; Rec."Descripción Estado")
                {
                    ApplicationArea = All;
                }
                field("Fecha Fin"; Rec."Fecha Fin")
                {
                    ApplicationArea = All;
                    ToolTip = 'Último día del estado, inclusive. Vacío = estado vigente.';
                }
            }
        }
    }

    procedure SetBuque(BuqueCode: Code[20])
    begin
        FBuque := BuqueCode;
    end;

    trigger OnOpenPage()
    begin
        Rec.FilterGroup(2);
        Rec.SetRange("Tipo Entidad", Rec."Tipo Entidad"::Buque);
        if FBuque <> '' then
            Rec.SetRange("No. Empleado", FBuque);
        Rec.FilterGroup(0);
    end;

    var
        FBuque: Code[20];
}
