namespace UAS.Payroll;

page 50152 "Ded. Ganancias Empleado Sub"
{
    ApplicationArea = All;
    Caption = 'Deducciones Ganancias';
    PageType = ListPart;
    SourceTable = "Ded. Ganancias Empleado";
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field("Cód. Tipo"; Rec."Cód. Tipo") { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field(Cantidad; Rec.Cantidad)
                {
                    ApplicationArea = All;
                    ToolTip = 'Cantidad de personas para tipos familiares (hijos, ascendientes). Para montos fijos dejar en 1.';
                }
                field("Importe Fijo"; Rec."Importe Fijo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Importe anual documentado (prepaga, hipoteca, servicio doméstico). Deja en 0 para usar el importe AFIP por la cantidad declarada.';
                }
                field(Observaciones; Rec.Observaciones) { ApplicationArea = All; Visible = false; }
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
                Caption = 'Nueva Declaración';
                Image = NewRow;
                ToolTip = 'Copia todas las deducciones actuales con la fecha de hoy como nueva vigencia. Modificar las líneas para reflejar el cambio.';

                trigger OnAction()
                var
                    Src: Record "Ded. Ganancias Empleado";
                    Nueva: Record "Ded. Ganancias Empleado";
                    NuevaVig: Date;
                begin
                    Rec.TestField("No. Empleado");
                    // Find current latest version
                    Src.SetRange("No. Empleado", Rec."No. Empleado");
                    Src.SetFilter("Vigencia Desde", '<=%1', WorkDate());
                    if not Src.FindLast() then exit;

                    NuevaVig := WorkDate();
                    Src.SetRange("Vigencia Desde", Src."Vigencia Desde");
                    if Src.FindSet() then
                        repeat
                            Nueva := Src;
                            Nueva."Vigencia Desde" := NuevaVig;
                            if Nueva.Insert() then;
                        until Src.Next() = 0;

                    CurrPage.Update(false);
                end;
            }
        }
    }
}
