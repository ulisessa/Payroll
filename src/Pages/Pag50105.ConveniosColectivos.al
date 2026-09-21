namespace UAS.Payroll;

page 50105 "Convenios Colectivos"
{
    ApplicationArea = All;
    Caption = 'Convenios Colectivos';
    PageType = List;
    SourceTable = "Convenio Colectivo";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("No. CCT"; Rec."No. CCT") { ApplicationArea = All; }
                field("Tipo Empleado"; Rec."Tipo Empleado")
                {
                    ApplicationArea = All;
                    ToolTip = 'Qué población encuadra este convenio. Decide qué conceptos le aplican a su gente: se compara contra el campo "Aplica A" de cada concepto. En blanco equivale a Todos y no filtra nada, así que un tripulante bajo un convenio sin configurar recibe también los conceptos de mensualizado.';
                }
                field("Cód. Calendario"; Rec."Cód. Calendario")
                {
                    ApplicationArea = All;
                    ToolTip = 'Calendario de feriados de este convenio. En blanco usa el del período. Hace falta porque los CCT tienen listas distintas: el 768/19 suma el 8 y 9 de febrero y el 20 de noviembre en su fecha, y los dos de flota suman el 29 de diciembre, Día del Pescador, que no es feriado nacional.';
                }
                field(Sindicato; Rec.Sindicato) { ApplicationArea = All; }
                field(Cámara; Rec.Cámara) { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(Categorías)
            {
                ApplicationArea = All;
                Caption = 'Categorías';
                Image = Category;
                RunObject = Page "Categorías CCT";
                RunPageLink = "Cód. Convenio" = FIELD(Código);
            }
            action(Conceptos)
            {
                ApplicationArea = All;
                Caption = 'Conceptos';
                Image = ItemLines;
                RunObject = Page "Conceptos Liquidación";
            }
        }
    }
}
