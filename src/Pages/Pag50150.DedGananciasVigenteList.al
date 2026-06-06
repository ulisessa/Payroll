namespace UAS.Payroll;

page 50150 "Ded. Ganancias Vigente"
{
    ApplicationArea = All;
    Caption = 'Tabla Deducciones Ganancias (AFIP)';
    PageType = List;
    SourceTable = "Ded. Ganancias Vigente";
    UsageCategory = Administration;
    CardPageId = "Ded. Ganancias Vigente Card";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Importe Anual"; Rec."Importe Anual") { ApplicationArea = All; }
                field("Aplica Cantidad"; Rec."Aplica Cantidad") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(NuevaVigencia)
            {
                ApplicationArea = All;
                Caption = 'Nueva Vigencia';
                Image = NewRow;
                Promoted = true;
                PromotedCategory = New;
                ToolTip = 'Copia el tipo seleccionado con una nueva fecha de vigencia para reflejar la actualización de AFIP.';

                trigger OnAction()
                var
                    Nueva: Record "Ded. Ganancias Vigente";
                begin
                    Rec.TestField(Código);
                    Nueva := Rec;
                    Nueva."Vigencia Desde" := WorkDate();
                    if Nueva.Insert(true) then
                        CurrPage.Update(false);
                end;
            }
        }
    }
}
