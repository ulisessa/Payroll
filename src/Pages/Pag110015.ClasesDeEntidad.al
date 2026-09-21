namespace UAS.Payroll;

page 110015 "Clases de Entidad"
{
    ApplicationArea = All;
    Caption = 'Clases de Entidad';
    PageType = List;
    UsageCategory = Administration;
    SourceTable = "Clase Entidad Liq.";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Cant. Atributos"; Rec."Cant. Atributos")
                {
                    ApplicationArea = All;
                    ToolTip = 'Tipos de atributo definidos para esta clase. Los marcados como obligatorios son los que la plantilla crea al clasificar una entidad.';
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(VerAtributos)
            {
                ApplicationArea = All;
                Caption = 'Tipos de atributo';
                Image = List;
                ToolTip = 'Tipos de atributo que corresponden a esta clase.';
                RunObject = Page "Tipos de Atributo";
                RunPageLink = "Cód. Clase" = field(Código);
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';
                actionref(VerAtributosProm; VerAtributos) { }
            }
        }
    }
}
