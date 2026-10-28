namespace UAS.Payroll;

page 50106 "Categorías CCT"
{
    ApplicationArea = All;
    Caption = 'Categorías CCT';
    PageType = List;
    SourceTable = "Categoría CCT";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Cód. Convenio"; Rec."Cód. Convenio") { ApplicationArea = All; }
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("% Escala"; Rec."% Escala") { ApplicationArea = All; }
                field(Observaciones; Rec.Observaciones) { ApplicationArea = All; Visible = false; }
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
                Caption = 'Parámetros de la categoría';
                Image = Setup;
                Promoted = true; PromotedCategory = Process;
                ToolTip = 'Consulta, modifica y agrega valores de parámetros vinculados al registro seleccionado, con sus vigencias.';
                trigger OnAction()
                var
                    UI: Codeunit "Atributos Entidad UI";
                begin
                    UI.AbrirParametrosOrigen('', Rec."Cód. Convenio", Rec.Código);
                end;
            }
        }
    }
}
