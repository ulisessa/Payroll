namespace UAS.Payroll;

using Microsoft.Finance.Currency;

// Pegar cotizaciones a mano en esta lista iguala el vendedor al comprador, y en el euro el gap no es fijo. Esta acción
// las trae del BNA con las dos columnas bien. La misma carga corre sola como tarea programada (codeunit "Cotizaciones BNA").
pageextension 110035 "Cotizaciones BNA Ext." extends "Currency Exchange Rates"
{
    actions
    {
        addlast(Processing)
        {
            action(TraerCotizacionesBNA)
            {
                ApplicationArea = All;
                Caption = 'Traer cotizaciones del BNA';
                Image = GetEntries;
                ToolTip = 'Baja del Banco Nación las cotizaciones de billetes (compra y venta) del euro y del dólar a partir del día siguiente a la última cotización cargada de cada moneda, y las agrega a la lista.';

                trigger OnAction()
                var
                    Cotizaciones: Codeunit "Cotizaciones BNA";
                    Insertadas: Integer;
                    Actualizadas: Integer;
                begin
                    Cotizaciones.ActualizarMonedas('EUR;USD', Insertadas, Actualizadas);
                    CurrPage.Update(false);
                    Message('Cotizaciones del BNA: %1 filas nuevas y %2 corregidas.', Insertadas, Actualizadas);
                end;
            }
        }
    }
}
