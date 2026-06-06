namespace UAS.Payroll;

page 50147 "Concepto CCT Sub"
{
    ApplicationArea = All;
    Caption = 'Convenios Aplicables';
    PageType = ListPart;
    SourceTable = "Concepto CCT Vigente";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field("Cód. Convenio"; Rec."Cód. Convenio") { ApplicationArea = All; }
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
                ToolTip = 'Copia los convenios actuales a una nueva fecha de vigencia para editarlos.';
                trigger OnAction()
                var
                    Nuevos: Record "Concepto CCT Vigente";
                    Existentes: Record "Concepto CCT Vigente";
                begin
                    Rec.TestField("Cód. Concepto");
                    Existentes.SetRange("Cód. Concepto", Rec."Cód. Concepto");
                    Existentes.SetFilter("Vigencia Desde", '<=%1', WorkDate());
                    if Existentes.FindLast() then begin
                        Existentes.SetRange("Vigencia Desde", Existentes."Vigencia Desde");
                        if Existentes.FindSet() then
                            repeat
                                Nuevos := Existentes;
                                Nuevos."Vigencia Desde" := WorkDate();
                                if Nuevos.Insert() then;
                            until Existentes.Next() = 0;
                        CurrPage.Update(false);
                    end;
                end;
            }
        }
    }
}
