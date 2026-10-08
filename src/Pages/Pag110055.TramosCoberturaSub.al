namespace UAS.Payroll;

/// <summary>Los tramos de días que esta liquidación cubre, y de dónde salió cada uno.</summary>
page 110055 "Tramos Cobertura Sub"
{
    PageType = ListPart;
    SourceTable = "Tramo Cobertura Liq.";
    Caption = 'Días que cubre';
    Editable = false;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Desde; Rec.Desde) { ApplicationArea = All; }
                field(Hasta; Rec.Hasta) { ApplicationArea = All; }
                field(Días; Rec.Días) { ApplicationArea = All; }
                field(Origen; Rec.Origen)
                {
                    ApplicationArea = All;
                    ToolTip = 'Por qué estos días son de esta liquidación: el estado que los justifica, la marea, o el resto del período que ninguna otra reclamó.';
                }
            }
        }
    }
}
