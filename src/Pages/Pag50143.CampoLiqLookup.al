namespace UAS.Payroll;

using System.Reflection;

page 50143 "Campo Liq. Lookup"
{
    ApplicationArea = All;
    Caption = 'Seleccionar Campo';
    PageType = List;
    SourceTable = Field;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    Caption = 'No.';
                    Width = 6;
                }
                field(FieldName; Rec.FieldName)
                {
                    ApplicationArea = All;
                    Caption = 'Nombre';
                }
                field(Type; Rec.Type)
                {
                    ApplicationArea = All;
                    Caption = 'Tipo';
                    Width = 10;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.SetRange(Class, Rec.Class::Normal);
        Rec.SetFilter(ObsoleteState, '%1|%2',
            Rec.ObsoleteState::No,
            Rec.ObsoleteState::Pending);
    end;
}
