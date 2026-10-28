namespace UAS.Payroll;

codeunit 110063 "Migrar Matriz Francos"
{
    // Migración de configuración; no forma parte del cálculo ni agrega conceptos o fracciones.
    procedure Convertir(FechaTexto: Text)
    var
        Desde: Date;
        Anterior: Record "Concepto Liquidación";
        Nueva: Record "Concepto Liquidación";
        Factor: Text;
        Importe: Text;
    begin
        if not Evaluate(Desde, FechaTexto, 9) then Error('Usá una fecha ISO, por ejemplo 2026-01-04.');
        Anterior.LockTable();
        if Nueva.Get('1063', Desde) then begin
            Nueva.TestField("Fuente Matriz", 'FRANCOS_FIFO');
            exit;
        end;
        Anterior.SetRange(Código, '1063');
        if not Anterior.FindLast() then Error('No existe el concepto 1063.');
        if Anterior."Vigencia Desde" >= Desde then Error('La nueva vigencia debe ser posterior a la última versión de 1063.');
        Anterior.TestField("Rol Franco", Anterior."Rol Franco"::Consumo);
        Anterior.TestField(Fórmula);
        if Anterior."Fuente Matriz" <> '' then Error('1063 ya usa una matriz; revisá su versión en lugar de reconvertirla.');
        Factor := Anterior."Factor Importe Consumo";
        Importe := 'FILA_CANTIDAD * FILA_VALOR_FRANCO';
        if Factor <> '' then
            Importe := 'IF((' + Factor + ') = 1, ' + Importe + ', ROUND(' + Importe + ' * (' + Factor + '), PRECISION_REDONDEO))';
        Nueva := Anterior;
        Nueva."Vigencia Desde" := Desde;
        Nueva."Vigencia Hasta" := 0D;
        Nueva."Fuente Matriz" := 'FRANCOS_FIFO';
        Nueva."Cantidad Matriz" := Anterior.Fórmula;
        Nueva."Factor Importe Consumo" := '';
        Nueva.Validate(Fórmula, CopyStr(Importe, 1, MaxStrLen(Nueva.Fórmula)));
        // Cierre derivado: se conservan los textos y las líneas históricas de la versión anterior.
        Anterior."Vigencia Hasta" := Desde - 1;
        Anterior.Modify(false);
        Nueva.Insert(true);
    end;

    procedure ReconstruirPeriodo(Periodo: Code[10])
    var
        Lin: Record "Línea Liquidación";
        Concepto: Record "Concepto Liquidación";
        Cuenta: Codeunit "Cuenta Corriente Francos";
        Empleados: List of [Code[20]];
        Empleado: Code[20];
    begin
        Lin.SetRange("Cód. Período", Periodo);
        Lin.SetFilter(Cantidad, '>0');
        Lin.SetFilter(Estado, '<>%1', Lin.Estado::Borrador);
        if Lin.FindSet() then repeat
            if Concepto.Get(Lin."Cód. Concepto", Lin."Vigencia Concepto") then
                if Concepto."Rol Franco" = Concepto."Rol Franco"::Consumo then
                    if not Empleados.Contains(Lin."No. Empleado") then Empleados.Add(Lin."No. Empleado");
        until Lin.Next() = 0;
        foreach Empleado in Empleados do Cuenta.Inicializar(Empleado);
    end;
}
