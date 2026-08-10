namespace UAS.Payroll;

page 50179 "Nuevo Codigo Dialog"
{
    PageType = StandardDialog;
    Caption = 'Copiar como...';

    layout
    {
        area(Content)
        {
            group(g)
            {
                ShowCaption = false;
                field(NuevoCodigo; NuevoCodigo)
                {
                    ApplicationArea = All;
                    Caption = 'Nuevo Código';
                    NotBlank = true;
                }
            }
        }
    }

    procedure SetCodigo(Codigo: Text[100])
    begin
        NuevoCodigo := Codigo;
    end;

    procedure GetCodigo(): Text[100]
    begin
        exit(NuevoCodigo);
    end;

    var
        NuevoCodigo: Text[100];
}
