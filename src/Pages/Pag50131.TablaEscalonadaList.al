namespace UAS.Payroll;

page 50131 "Tabla Escalonada List"
{
    ApplicationArea = All;
    Caption = 'Tablas Escalonadas';
    CardPageId = "Tabla Escalonada Card";
    PageType = List;
    SourceTable = "Tabla Escalonada";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Cant. Tramos"; Rec."Cant. Tramos") { ApplicationArea = All; }
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
                ToolTip = 'Crea una nueva versión de la tabla con los mismos tramos, lista para actualizar los valores.';

                trigger OnAction()
                var
                    NuevaCab: Record "Tabla Escalonada";
                    NuevaDet: Record "Tabla Escalonada Det.";
                    Det: Record "Tabla Escalonada Det.";
                begin
                    Rec.TestField(Código);
                    NuevaCab := Rec;
                    NuevaCab."Vigencia Desde" := WorkDate();
                    NuevaCab.Insert(true);

                    Det.SetRange(Código, Rec.Código);
                    Det.SetRange("Vigencia Desde", Rec."Vigencia Desde");
                    if Det.FindSet() then
                        repeat
                            NuevaDet := Det;
                            NuevaDet."Vigencia Desde" := WorkDate();
                            NuevaDet.Insert(true);
                        until Det.Next() = 0;

                    CurrPage.Update(false);
                end;
            }
        }
    }
}
