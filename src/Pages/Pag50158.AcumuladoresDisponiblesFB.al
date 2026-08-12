namespace UAS.Payroll;

page 50158 "Acumuladores Disponibles FB"
{
    ApplicationArea = All;
    Caption = 'Acumuladores disponibles';
    PageType = ListPart;
    SourceTable = "Concepto Liquidación";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.SetRange("Es Acumulador", true);
        // Se elige un acumulador para configurar, así que no tiene sentido ofrecer versiones que
        // todavía no arrancaron. El final de vigencia no se filtra —ver FiltrarVigentesA— así que
        // un acumulador dado de baja puede seguir apareciendo acá: es ruido en un selector, no un
        // error de cálculo, y no justifica meter un filtro de fecha delicado en una página.
        Rec.FiltrarVigentesA(WorkDate());
        Rec.SetRange(Activo, true);
    end;
}
