namespace UAS.Payroll;

page 50172 "Carpeta SIRADIG Dialog"
{
    Caption = 'Carpeta SIRADIG';
    PageType = StandardDialog;

    layout
    {
        area(Content)
        {
            field(CarpetaOrigen; CarpetaOrigen)
            {
                ApplicationArea = All;
                Caption = 'Carpeta de archivos SIRADIG';
                ToolTip = 'Especifica la carpeta del servidor donde se encuentran los archivos SIRADIG (.xml.zip o .xml).';
            }
        }
    }

    var
        CarpetaOrigen: Text;

    procedure SetCarpeta(NuevaCarpeta: Text)
    begin
        CarpetaOrigen := NuevaCarpeta;
    end;

    procedure GetCarpeta(): Text
    begin
        exit(CarpetaOrigen);
    end;
}
