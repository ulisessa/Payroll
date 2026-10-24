namespace UAS.Payroll;

using Microsoft.Finance.Currency;

codeunit 110091 "Test Cotizaciones BNA"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure CargaCompradorYVendedorPorSeparado()
    var
        Cotizacion: Record "Currency Exchange Rate";
        Cotizaciones: Codeunit "Cotizaciones BNA";
        Insertadas: Integer;
        Actualizadas: Integer;
    begin
        Limpiar();
        Cotizaciones.ProcesarCsv('EUR', Csv(1565, 1665), Insertadas, Actualizadas);
        Assert(Insertadas = 2, 'Las dos fechas del CSV deben insertarse; el encabezado no es una fila.');
        Assert(Actualizadas = 0, 'Una carga nueva no corrige nada.');
        Cotizacion.Get('EUR', DMY2Date(2, 1, 2001));
        Assert(Cotizacion."Relational Exch. Rate Amount" = 1565, 'La compra va al comprador.');
        Assert(Cotizacion."Relational Adjmt Exch Rate Amt" = 1665, 'La venta va al vendedor, sin igualarse al comprador.');
        Assert(Cotizacion."Exchange Rate Amount" = 1, 'Las filas se cargan por 1 unidad de la divisa.');
        Limpiar();
    end;

    [Test]
    procedure CargaRepetidaNoDuplicaYCorrige()
    var
        Cotizacion: Record "Currency Exchange Rate";
        Cotizaciones: Codeunit "Cotizaciones BNA";
        Insertadas: Integer;
        Actualizadas: Integer;
    begin
        Limpiar();
        Cotizaciones.ProcesarCsv('EUR', Csv(1565, 1665), Insertadas, Actualizadas);
        Cotizaciones.ProcesarCsv('EUR', Csv(1565, 1665), Insertadas, Actualizadas);
        Assert((Insertadas = 0) and (Actualizadas = 0), 'Repetir la misma carga no debe insertar ni modificar.');
        Cotizaciones.ProcesarCsv('EUR', Csv(1570, 1680), Insertadas, Actualizadas);
        Assert((Insertadas = 0) and (Actualizadas = 2), 'Un valor rectificado por el BNA debe corregir las dos filas.');
        Cotizacion.Get('EUR', DMY2Date(3, 1, 2001));
        Assert(Cotizacion."Relational Adjmt Exch Rate Amt" = 1680, 'El vendedor corregido debe quedar guardado.');
        Limpiar();
    end;

    local procedure Csv(Compra: Integer; Venta: Integer): Text
    var
        Salto: Text[1];
    begin
        Salto[1] := 10;
        exit('Moneda;Fecha cotizacion;Compra;Venta;' + Salto +
            StrSubstNo('Euro;2/1/2001; %1,0000; %2,0000;', Compra, Venta) + Salto +
            StrSubstNo('Euro;3/1/2001; %1,0000; %2,0000;', Compra, Venta) + Salto);
    end;

    local procedure Limpiar()
    var
        Cotizacion: Record "Currency Exchange Rate";
    begin
        Cotizacion.SetRange("Currency Code", 'EUR');
        Cotizacion.SetRange("Starting Date", DMY2Date(1, 1, 2001), DMY2Date(31, 1, 2001));
        Cotizacion.DeleteAll();
    end;

    local procedure Assert(Condicion: Boolean; Mensaje: Text)
    begin
        if not Condicion then Error(Mensaje);
    end;
}
