namespace UAS.Payroll;

page 110007 "Tipos de Atributo"
{
    ApplicationArea = All;
    Caption = 'Tipos de Atributo';
    PageType = List;
    UsageCategory = Administration;
    SourceTable = "Tipo Atributo Liq.";
    CardPageId = "Ficha Tipo Atributo";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Tipo Dato"; Rec."Tipo Dato")
                {
                    ApplicationArea = All;
                    ToolTip = 'Define en qué columna se carga el valor y cómo llega a una fórmula. "Lista de valores" es la opción preferida para todo lo que decida un cálculo.';
                }
                field("Tipo Entidad"; Rec."Tipo Entidad")
                {
                    ApplicationArea = All;
                    ToolTip = 'A qué maestro se le carga este atributo.';
                }
                field(Obligatorio; Rec.Obligatorio) { ApplicationArea = All; }
                field("Nombre Variable"; Rec."Nombre Variable")
                {
                    ApplicationArea = All;
                    ToolTip = 'Nombre sugerido para la Fuente de Datos que lo lea. El nombre real con el que la fórmula lo ve lo define esa fuente.';
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(VerValores)
            {
                ApplicationArea = All;
                Caption = 'Valores permitidos';
                Image = List;
                ToolTip = 'Lista cerrada contra la que se valida este atributo, y el número que cada valor le pasa a las fórmulas.';
                Enabled = EsLista;
                RunObject = Page "Valores de Atributo";
                RunPageLink = "Cód. Tipo Atributo" = field(Código);
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';
                actionref(VerValoresProm; VerValores) { }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        EsLista := Rec.UsaLista();
    end;

    var
        EsLista: Boolean;
}
