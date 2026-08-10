namespace UAS.Payroll;

page 50183 "Nueva Vigencia Dialog"
{
    PageType = StandardDialog;
    Caption = 'Nueva Vigencia';

    layout
    {
        area(Content)
        {
            group(g)
            {
                ShowCaption = false;
                field(FechaVigencia; FechaVigencia)
                {
                    ApplicationArea = All;
                    Caption = 'Vigencia Desde';
                    NotBlank = true;
                    ToolTip = 'Fecha a partir de la cual rige la nueva versión de la fórmula. La versión anterior se conserva para el recálculo de períodos previos.';
                }
            }
        }
    }

    procedure SetFecha(Fecha: Date)
    begin
        FechaVigencia := Fecha;
    end;

    procedure GetFecha(): Date
    begin
        exit(FechaVigencia);
    end;

    var
        FechaVigencia: Date;
}
