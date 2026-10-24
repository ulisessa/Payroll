namespace UAS.Payroll;

using Microsoft.Finance.Currency;
using System.Threading;

// Trae las cotizaciones de billetes del Banco Nación y las carga en "Currency Exchange Rate".
//
// El BNA publica el histórico en un CSV que baja con un GET sin sesión ni token:
//   /Cotizador/DescargarPorFecha?id=billetes&fechaDesde=dd/MM/aaaa&fechaHasta=dd/MM/aaaa&idMonedaDescarga=<id>
// Compra va al TC comprador ("Relational Exch. Rate Amount") y Venta al vendedor ("Relational Adjmt Exch Rate Amt"),
// que es lo que ya tienen las filas del USD (el gap no es fijo: 50 en el dólar, 100 y 110 en el euro).
//
// Se carga con asignación directa y no con Validate: el OnValidate de la tabla iguala el vendedor al comprador, que es
// lo que pasa al pegar valores a mano. Los días sin cotización (fines de semana y feriados) no se cargan: la liquidación
// toma la última fila con fecha menor o igual.
//
// Como tarea programada (Job Queue Entry, codeunit 110090): "Parameter String" = monedas separadas por punto y coma, y
// opcionalmente DESDE=aaaa-mm-dd; vacío = "EUR;USD", y cada moneda se trae a partir del día siguiente a la última
// cotización cargada (sin ninguna, de los últimos 15 días). DESDE= fuerza el inicio y sirve para corregir días ya
// cargados. Requiere "Permitir solicitudes HttpClient" para esta extensión y salida del servicio a
// www.bna.com.ar.
codeunit 110090 "Cotizaciones BNA"
{
    TableNo = "Job Queue Entry";
    Permissions = tabledata "Currency Exchange Rate" = RIM;

    trigger OnRun()
    var
        Insertadas: Integer;
        Actualizadas: Integer;
    begin
        ActualizarMonedas(Rec."Parameter String", Insertadas, Actualizadas);
    end;

    /// <summary>
    /// Actualiza las monedas del texto ("EUR;USD", "EUR;DESDE=2026-04-01") y devuelve cuántas filas insertó y cuántas corrigió.
    /// </summary>
    procedure ActualizarMonedas(Parametros: Text; var Insertadas: Integer; var Actualizadas: Integer)
    var
        Elemento: Text;
        Monedas: List of [Text];
        Desde: Date;
        Fecha: Date;
        Moneda: Text;
        DesdeMoneda: Date;
        Ins: Integer;
        Act: Integer;
    begin
        Insertadas := 0;
        Actualizadas := 0;
        if Parametros = '' then Parametros := 'EUR;USD';
        foreach Elemento in Parametros.Split(';') do begin
            Elemento := Elemento.Trim().ToUpper();
            if Elemento.StartsWith('DESDE=') then begin
                if not Evaluate(Fecha, Elemento.Substring(7), 9) then
                    Error('DESDE debe ser una fecha aaaa-mm-dd (recibí "%1").', Elemento.Substring(7));
                Desde := Fecha;
            end else
                if Elemento <> '' then Monedas.Add(Elemento);
        end;
        foreach Moneda in Monedas do begin
            DesdeMoneda := Desde;
            if DesdeMoneda = 0D then DesdeMoneda := DiaSiguienteAlUltimo(CopyStr(Moneda, 1, 10));
            // Al día: no hay nada nuevo que pedirle al BNA.
            if DesdeMoneda <= Today() then begin
                ProcesarCsv(CopyStr(Moneda, 1, 10), Descargar(IdBna(Moneda), DesdeMoneda, Today()), Ins, Act);
                Insertadas += Ins;
                Actualizadas += Act;
            end;
        end;
    end;

    /// <summary>
    /// Carga el texto del CSV del BNA (Moneda;Fecha cotizacion;Compra;Venta;) para la moneda de BC indicada.
    /// </summary>
    procedure ProcesarCsv(Moneda: Code[10]; Csv: Text; var Insertadas: Integer; var Actualizadas: Integer)
    var
        Cotizacion: Record "Currency Exchange Rate";
        RetornoCarro: Text[1];
        SaltoLinea: Text[1];
        Linea: Text;
        Campos: List of [Text];
        Partes: List of [Text];
        Fecha: Date;
        Compra: Decimal;
        Venta: Decimal;
        Dia: Integer;
        Mes: Integer;
        Anio: Integer;
    begin
        Insertadas := 0;
        Actualizadas := 0;
        RetornoCarro[1] := 13;
        SaltoLinea[1] := 10;
        Csv := Csv.Replace(RetornoCarro, '');
        foreach Linea in Csv.Split(SaltoLinea) do begin
            Campos := Linea.Split(';');
            if Campos.Count() >= 4 then begin
                Partes := Campos.Get(2).Trim().Split('/');
                // El encabezado ("Fecha cotizacion") no se evalúa como fecha y se saltea solo.
                if Partes.Count() = 3 then
                    if Evaluate(Dia, Partes.Get(1)) and Evaluate(Mes, Partes.Get(2)) and Evaluate(Anio, Partes.Get(3)) then
                        if Evaluate(Compra, Campos.Get(3).Trim().Replace(',', '.'), 9) and Evaluate(Venta, Campos.Get(4).Trim().Replace(',', '.'), 9) then begin
                            Fecha := DMY2Date(Dia, Mes, Anio);
                            if Cotizacion.Get(Moneda, Fecha) then begin
                                if (Cotizacion."Relational Exch. Rate Amount" <> Compra) or (Cotizacion."Relational Adjmt Exch Rate Amt" <> Venta) then begin
                                    Cotizacion."Relational Exch. Rate Amount" := Compra;
                                    Cotizacion."Relational Adjmt Exch Rate Amt" := Venta;
                                    Cotizacion.Modify();
                                    Actualizadas += 1;
                                end;
                            end else begin
                                Cotizacion.Init();
                                Cotizacion."Currency Code" := Moneda;
                                Cotizacion."Starting Date" := Fecha;
                                Cotizacion."Exchange Rate Amount" := 1;
                                Cotizacion."Adjustment Exch. Rate Amount" := 1;
                                Cotizacion."Relational Exch. Rate Amount" := Compra;
                                Cotizacion."Relational Adjmt Exch Rate Amt" := Venta;
                                Cotizacion.Insert();
                                Insertadas += 1;
                            end;
                        end;
            end;
        end;
    end;

    local procedure DiaSiguienteAlUltimo(Moneda: Code[10]): Date
    var
        Cotizacion: Record "Currency Exchange Rate";
    begin
        Cotizacion.SetRange("Currency Code", Moneda);
        if Cotizacion.FindLast() then exit(Cotizacion."Starting Date" + 1);
        exit(Today() - 15);
    end;

    local procedure Descargar(IdMoneda: Integer; Desde: Date; Hasta: Date): Text
    var
        Cliente: HttpClient;
        Respuesta: HttpResponseMessage;
        Contenido: Text;
    begin
        Cliente.Timeout(30000);
        if not Cliente.Get(StrSubstNo('https://www.bna.com.ar/Cotizador/DescargarPorFecha?id=billetes&fechaDesde=%1&fechaHasta=%2&idMonedaDescarga=%3',
                FechaBna(Desde), FechaBna(Hasta), IdMoneda), Respuesta)
        then
            Error('No se pudo conectar con el BNA: %1. Revisá que la extensión tenga permitidas las solicitudes HttpClient y que el servicio llegue a www.bna.com.ar.', GetLastErrorText());
        if not Respuesta.IsSuccessStatusCode() then
            Error('El BNA respondió %1 %2.', Respuesta.HttpStatusCode(), Respuesta.ReasonPhrase());
        Respuesta.Content().ReadAs(Contenido);
        exit(Contenido);
    end;

    // Los id son los del formulario del BNA (idMonedaDescarga): 12 euro, 22 dólar U.S.A.
    local procedure IdBna(Moneda: Text): Integer
    begin
        case Moneda of
            'EUR':
                exit(12);
            'USD':
                exit(22);
            else
                Error('La moneda %1 no está habilitada para el BNA (sólo EUR y USD).', Moneda);
        end;
    end;

    local procedure FechaBna(Fecha: Date): Text
    begin
        exit(StrSubstNo('%1/%2/%3', DosDigitos(Date2DMY(Fecha, 1)), DosDigitos(Date2DMY(Fecha, 2)), Date2DMY(Fecha, 3)));
    end;

    local procedure DosDigitos(Numero: Integer): Text
    begin
        if Numero < 10 then exit('0' + Format(Numero));
        exit(Format(Numero));
    end;
}
