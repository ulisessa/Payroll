namespace UAS.Payroll;

page 50137 "Parámetro Vigente Subpag"
{
    ApplicationArea = All;
    Caption = 'Valores Vigentes';
    PageType = ListPart;
    SourceTable = "Parámetro Vigente";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field(Valor; Rec.Valor)
                {
                    ApplicationArea = All;
                    Editable = not Rec."En Uso";
                }
                field(Moneda; Rec.Moneda) { ApplicationArea = All; }
                field("En Uso"; Rec."En Uso")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Style = Attention;
                    StyleExpr = Rec."En Uso";
                }
                field(Descripción; Rec.Descripción)
                {
                    ApplicationArea = All;
                    Caption = 'Descripción Versión';
                }
                field(Notas; Rec.Notas) { ApplicationArea = All; Visible = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(NuevoValor)
            {
                ApplicationArea = All;
                Caption = 'Nuevo Valor';
                Image = NewRow;
                ToolTip = 'Inserta una nueva vigencia preservando el valor anterior para auditoría.';

                trigger OnAction()
                var
                    NuevoParam: Record "Parámetro Vigente";
                begin
                    Rec.TestField("Cód. Parámetro");
                    NuevoParam := Rec;
                    NuevoParam."Vigencia Desde" := WorkDate();
                    NuevoParam."En Uso" := false;
                    NuevoParam.Descripción := '';
                    if NuevoParam.Insert(true) then
                        CurrPage.Update(false);
                end;
            }
        }
    }
}
