namespace UAS.Payroll;

page 110010 "Valores de Atributo"
{
    ApplicationArea = All;
    Caption = 'Valores de Atributo';
    PageType = List;
    UsageCategory = Administration;
    SourceTable = "Valor Atributo Liq.";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Cód. Tipo Atributo"; Rec."Cód. Tipo Atributo") { ApplicationArea = All; }
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Valor Numérico"; Rec."Valor Numérico")
                {
                    ApplicationArea = All;
                    ToolTip = 'El número que ve la fórmula cuando una entidad tiene este valor asignado.';
                }
            }
        }
    }
}
