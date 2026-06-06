namespace UAS.Payroll;

page 50136 "Estado Empleado FactBox"
{
    ApplicationArea = All;
    Caption = 'Estado Empleado';
    PageType = CardPart;
    SourceTable = "Estado Empleado";

    layout
    {
        area(Content)
        {
            field("Cód. Estado"; Rec."Cód. Estado")
            {
                ApplicationArea = All;
                Caption = 'Estado Actual';
                Style = Strong;
            }
            field("Descripción Estado"; Rec."Descripción Estado")
            {
                ApplicationArea = All;
                Caption = 'Descripción';
            }
            field("Fecha Inicio"; Rec."Fecha Inicio")
            {
                ApplicationArea = All;
                Caption = 'Desde';
            }
        }
    }

    trigger OnFindRecord(Which: Text): Boolean
    var
        EstadoMgt: Codeunit "Gestión Estado Empleado";
    begin
        exit(EstadoMgt.GetEstadoActual(Rec."No. Empleado", Rec));
    end;
}
