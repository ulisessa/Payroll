namespace UAS.Payroll;

using System.Reflection;

page 50142 "Tabla Liq. Lookup"
{
    ApplicationArea = All;
    Caption = 'Seleccionar Tabla';
    PageType = List;
    SourceTable = AllObjWithCaption;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Object ID"; Rec."Object ID")
                {
                    ApplicationArea = All;
                    Caption = 'ID';
                    Width = 8;
                }
                field("Object Caption"; Rec."Object Caption")
                {
                    ApplicationArea = All;
                    Caption = 'Nombre';
                }
                field("Object Name"; Rec."Object Name")
                {
                    ApplicationArea = All;
                    Caption = 'Objeto';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.SetRange("Object Type", Rec."Object Type"::Table);
        Rec.SetFilter("Object ID", '>0');
    end;
}
