namespace UAS.Payroll;

codeunit 110047 "Test Cache Liquidacion"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure IncidenciasConservanDatosYSeRenuevan()
    var
        Motor: Codeunit "Motor Liquidación";
        Origen: Record "Incidencia Liquidación";
        Copia: Record "Incidencia Liquidación" temporary;
        LiqNo: Code[20];
    begin
        LiqNo := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20);
        Origen."No. Liquidación" := LiqNo;
        Origen."Cód. Concepto" := 'CANTIDAD';
        Origen.Importe := 0;
        Origen.Cantidad := 21;
        Origen."Unidad Cantidad" := 'H';
        Origen."Valor Unitario" := 7;
        Origen."Desde Novedad" := true;
        Origen.Observaciones := 'Conservar datos completos';
        Origen.Insert(false);

        Motor.ReiniciarCachesLiquidacion();
        Motor.CargarIncidencias(LiqNo);
        Motor.CompartirIncidencias(Copia);
        Copia.Get(LiqNo, 'CANTIDAD');
        Assert((Copia.Importe = 0) and (Copia.Cantidad = 21) and
            (Copia."Unidad Cantidad" = 'H') and (Copia."Valor Unitario" = 7) and
            Copia."Desde Novedad" and (Copia.Observaciones = Origen.Observaciones),
            'La instantánea debe conservar la incidencia de cantidad y su información.');

        Origen.Cantidad := 30;
        Origen.Modify(false);
        Copia.Get(LiqNo, 'CANTIDAD');
        Assert(Copia.Cantidad = 21, 'Las iteraciones deben usar la misma instantánea.');
        Motor.ReiniciarCachesLiquidacion();
        Motor.CargarIncidencias(LiqNo);
        Motor.CompartirIncidencias(Copia);
        Copia.Get(LiqNo, 'CANTIDAD');
        Assert(Copia.Cantidad = 30, 'El recálculo debe leer la incidencia actualizada.');
        Motor.CargarIncidencias('');
        Motor.CompartirIncidencias(Copia);
        Assert(Copia.IsEmpty(), 'No deben quedar incidencias del empleado anterior.');
        Origen.Delete(false);
    end;

    [Test]
    procedure CCTSeparaCategoriaFechaYReinicio()
    var
        Motor: Codeunit "Motor Liquidación";
        Concepto: Record "Concepto Liquidación" temporary;
        Restriccion: Record "Concepto CCT Vigente";
        Fecha: Date;
    begin
        Fecha := DMY2Date(1, 1, 2026);
        Concepto.Código := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20);
        Concepto."Vigencia Desde" := Fecha;
        Restriccion."Cód. Concepto" := Concepto.Código;
        Restriccion."Vigencia Desde" := Fecha;
        Restriccion."Cód. Convenio" := 'CONV';
        Restriccion."Cód. Categoría" := 'A';
        Restriccion.Insert(false);
        Motor.ReiniciarCachesLiquidacion();
        Assert(Motor.CCTAplicaAConcepto(Concepto, 'CONV', 'A', Fecha), 'Categoría incluida.');
        Assert(not Motor.CCTAplicaAConcepto(Concepto, 'CONV', 'B', Fecha), 'Categoría no incluida.');
        Assert(Motor.CCTAplicaAConcepto(Concepto, 'CONV', 'B', Fecha - 1), 'Antes de la restricción aplica.');
        Assert(not Motor.CCTAplicaAConcepto(Concepto, 'OTRO', 'A', Fecha), 'Otro convenio no incluido.');
        Restriccion.Excluye := true;
        Restriccion.Modify(false);
        Assert(Motor.CCTAplicaAConcepto(Concepto, 'CONV', 'A', Fecha), 'La decisión permanece durante la liquidación.');
        Motor.ReiniciarCachesLiquidacion();
        Assert(not Motor.CCTAplicaAConcepto(Concepto, 'CONV', 'A', Fecha), 'El recálculo toma la exclusión nueva.');
        Assert(Motor.CCTAplicaAConcepto(Concepto, 'CONV', 'B', Fecha), 'Sin inclusiones, aplica a las no excluidas.');
        Restriccion.Delete(false);
    end;

    local procedure Assert(Condicion: Boolean; Mensaje: Text)
    begin
        if not Condicion then
            Error(Mensaje);
    end;
}
