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
                field("Cód. Valor Padre"; Rec."Cód. Valor Padre")
                {
                    ApplicationArea = All;
                    Caption = 'Cuelga de';
                    ToolTip = 'Valor del atributo padre del que cuelga éste. Vacío en los atributos que no dependen de otro.';
                }
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
    actions
    {
        area(Processing)
        {
            action(ParametrosOrigen)
            {
                ApplicationArea = All;
                Caption = 'Parámetros del valor';
                Image = Setup;
                Promoted = true; PromotedCategory = Process;
                ToolTip = 'Consulta, modifica y agrega valores de parámetros vinculados al registro seleccionado, con sus vigencias.';
                trigger OnAction()
                var
                    UI: Codeunit "Atributos Entidad UI";
                begin
                    UI.AbrirParametrosValor(Rec."Cód. Tipo Atributo", Rec."Cód. Valor Padre", Rec.Código);
                end;
            }
        }
    }
}
