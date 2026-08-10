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
                field("Cód. Categoría"; Rec."Cód. Categoría")
                {
                    ApplicationArea = All;
                    ToolTip = 'Opcional. Vacío = aplica a todas las categorías de este convenio. Cargada = restringe el concepto solo a esa categoría.';
                }
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

    // Al alta, se propone la vigencia del lote CCT más reciente del concepto — que es el que el
    // motor consulta realmente — para que agregar un convenio faltante caiga en ese lote y no en
    // uno viejo que ya no tiene efecto. Si el concepto no tiene ninguna restricción todavía, se
    // usa la fecha de trabajo.
    trigger OnNewRecord(BelowxRec: Boolean)
    var
        Existentes: Record "Concepto CCT Vigente";
    begin
        if Rec."Vigencia Desde" <> 0D then
            exit;
        Existentes.SetRange("Cód. Concepto", Rec."Cód. Concepto");
        if Existentes.FindLast() then
            Rec."Vigencia Desde" := Existentes."Vigencia Desde"
        else
            Rec."Vigencia Desde" := WorkDate();
    end;
}
