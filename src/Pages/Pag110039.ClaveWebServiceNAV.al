namespace UAS.Payroll;

// Pide la clave de acceso a web services y la devuelve al que la llamó. No la guarda ni la muestra:
// de acá sale en memoria hacia "Cliente NAV WS".GuardarClave, que la deja en Isolated Storage.
//
// Es una página y no un campo en la ficha de configuración a propósito. Un campo en la ficha queda
// en el estado de la página, sale en una captura de pantalla, lo puede recordar el navegador y
// tienta a guardarlo "por las dudas" en la tabla. Esto vive lo que dura el diálogo.
page 110039 "Clave Web Service NAV"
{
    ApplicationArea = All;
    Caption = 'Clave de acceso a web services';
    PageType = StandardDialog;
    InstructionalText = 'Pegá la clave de acceso a servicio web del usuario de NAV. No se va a poder volver a leer desde BC: para cambiarla, se carga de nuevo.';

    layout
    {
        area(Content)
        {
            field(Clave; ClaveIngresada)
            {
                ApplicationArea = All;
                Caption = 'Clave';
                ExtendedDatatype = Masked;
                ShowMandatory = true;
                ToolTip = 'La clave de acceso a servicio web, no la contraseña de NAV. Sale de la ficha del usuario en NAV, o del Set-NAVServerUser -CreateWebServicesKey.';
            }
        }
    }

    var
        ClaveIngresada: Text;

    procedure GetClave(): Text
    begin
        exit(ClaveIngresada);
    end;
}
