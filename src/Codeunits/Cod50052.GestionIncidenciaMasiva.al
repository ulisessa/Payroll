namespace UAS.Payroll;

codeunit 50052 "Gestión Incidencia Masiva"
{
    // Escribe (Insert/Modify) en Incidencia Liquidación. Vive en un codeunit a propósito:
    // la plataforma no permite escribir en la base dentro de un TryFunction definido
    // directamente en un objeto Report (Rep50044 la llama sin envolverla en TryFunction).

    procedure InsertarIncidencia(
        var Liq: Record "Liquidación";
        CodConcepto: Code[20];
        Cantidad: Decimal;
        UnidadCantidad: Code[10];
        ValorUnitario: Decimal;
        Importe: Decimal;
        Observaciones: Text[250];
        Sobrescribir: Boolean): Boolean
    var
        Incid: Record "Incidencia Liquidación";
        Existe: Boolean;
    begin
        if Liq.Estado <> Liq.Estado::Borrador then
            exit(false);

        Existe := Incid.Get(Liq."No.", CodConcepto);
        if Existe and not Sobrescribir then
            exit(false);

        if not Existe then begin
            Incid.Init();
            Incid."No. Liquidación" := Liq."No.";
            Incid."Cód. Concepto" := CodConcepto;
        end;

        Incid.Cantidad := Cantidad;
        Incid."Unidad Cantidad" := UnidadCantidad;
        Incid."Valor Unitario" := ValorUnitario;
        Incid.Importe := Importe;
        if Observaciones <> '' then
            Incid.Observaciones := Observaciones;

        if Existe then
            Incid.Modify(true)
        else
            Incid.Insert(true);
        exit(true);
    end;
}
