namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

codeunit 50053 "Gestión Francos"
{
    // FIFO ledger for compensatory days off (francos). The ledger lives in Línea Liquidación:
    //   • Accrual lots  — concept with "Rol Franco" = Devengo (Es Devengo lines). Each lot carries the
    //     Cantidad of days accrued and is sealed with the convenio/categoría it was earned under.
    //   • Consumption   — concept with "Rol Franco" = Consumo. Pays enjoyed francos.
    // Francos are non-fungible: a consumed day is valued at its lot's category, not the employee's current
    // one. Consumption follows FIFO (oldest lots first). The per-day value comes from the reserved
    // parameter VALOR_FRANCO, looked up as VALOR_FRANCO_<CONVENIO>_<CATEGORÍA> at the pay date.

    var
        ParamValorFranco: Label 'VALOR_FRANCO', Locked = true;

    // Total amount to pay for consuming up to DiasSolicitados francos, FIFO, valuing each lot-slice at its
    // own category as of FechaPago. Capped at the available balance. LiqActual is excluded from the netting.
    procedure ValorPagoFrancosFIFO(EmployeeNo: Code[20]; DiasSolicitados: Decimal; FechaPago: Date; LiqActual: Code[20]): Decimal
    var
        Monto: Decimal;
        DiasConsumidos: Decimal;
    begin
        CaminarFIFO(EmployeeNo, DiasSolicitados, FechaPago, LiqActual, Monto, DiasConsumidos);
        exit(Monto);
    end;

    // Francos actually consumed this liquidation = min(DiasSolicitados, saldo disponible). Use as the
    // Cantidad of the consumption line so quantity and amount stay consistent.
    procedure FrancosConsumidos(EmployeeNo: Code[20]; DiasSolicitados: Decimal; FechaPago: Date; LiqActual: Code[20]): Decimal
    var
        Monto: Decimal;
        DiasConsumidos: Decimal;
    begin
        CaminarFIFO(EmployeeNo, DiasSolicitados, FechaPago, LiqActual, Monto, DiasConsumidos);
        exit(DiasConsumidos);
    end;

    // Pending franco balance (accrued − consumed) for the employee, excluding LiqActual.
    procedure SaldoFrancos(EmployeeNo: Code[20]; LiqActual: Code[20]): Decimal
    begin
        exit(TotalDevengado(EmployeeNo, LiqActual) - TotalConsumido(EmployeeNo, LiqActual));
    end;

    // Francos available to enjoy starting on Fecha: accrued on/before Fecha minus consumed strictly before
    // Fecha. Stable across the consumption that happens during the Francos period itself (it excludes it),
    // so it gives a fixed duration for the state — the day the francos run out is Fecha + this balance.
    procedure SaldoFrancosAFecha(EmployeeNo: Code[20]; Fecha: Date): Decimal
    begin
        exit(TotalPorRolHasta(EmployeeNo, "Rol Franco Liq."::Devengo, Fecha, true) -
             TotalPorRolHasta(EmployeeNo, "Rol Franco Liq."::Consumo, Fecha, false));
    end;

    // Sum of Cantidad for lines of the given franco role with Fecha Liquidación up to Fecha (Inclusivo=true
    // → <=; false → <).
    local procedure TotalPorRolHasta(EmployeeNo: Code[20]; Rol: Enum "Rol Franco Liq."; Fecha: Date; Inclusivo: Boolean): Decimal
    var
        Lin: Record "Línea Liquidación";
        Codigos: List of [Code[20]];
        Total: Decimal;
    begin
        if not CodigosPorRol(Codigos, Rol) then exit(0);
        Lin.SetCurrentKey("No. Empleado", "Fecha Liquidación", "Tipo Concepto");
        Lin.SetRange("No. Empleado", EmployeeNo);
        // EL CONJUNTO DE CONCEPTOS VA COMO FILTRO. Antes se traían TODAS las líneas del empleado
        // —todos sus años, todos sus conceptos— para sumar las de dos, y el descarte se hacía con un
        // Contains adentro del bucle, que además es otro barrido lineal por fila. El predicado es
        // exactamente el mismo; lo único que cambia es dónde se evalúa. FiltrarLotes ya lo hacía así.
        Lin.SetFilter("Cód. Concepto", ConstruirFiltroCodigos(Codigos));
        if Inclusivo then
            Lin.SetFilter("Fecha Liquidación", '<=%1', Fecha)
        else
            Lin.SetFilter("Fecha Liquidación", '<%1', Fecha);
        Lin.SetLoadFields(Cantidad);
        if Lin.FindSet() then
            repeat
                Total += Lin.Cantidad;
            until Lin.Next() = 0;
        exit(Total);
    end;

    /// <summary>
    /// Llena Buffer con el saldo de francos abierto por tripulante y categoría, valuado a Fecha.
    /// </summary>
    /// <remarks>
    /// Es la herramienta de control del ledger. Contesta la única pregunta que no se puede contestar
    /// mirando una liquidación: cuántos francos tiene cada tripulante pendientes, ganados en qué
    /// categoría, y cuánto costaría pagarlos hoy.
    ///
    /// La atribución del consumo a una categoría no está guardada en ningún lado —la línea de consumo
    /// no dice de qué lote salió—, así que se deduce recorriendo los lotes del más viejo al más nuevo
    /// y descontando el total consumido. Es EL MISMO recorrido que hace CaminarFIFO al liquidar: si
    /// este informe usara otro criterio, mostraría un saldo por categoría que el motor no va a pagar.
    ///
    /// FiltroEmpleado en blanco recorre a todos los que tengan algún lote. Los que nunca devengaron no
    /// generan fila: una grilla llena de ceros esconde a los pocos que sí tienen saldo.
    /// </remarks>
    procedure ResumenPorCategoria(FiltroEmpleado: Text; Fecha: Date; var Buffer: Record "Francos Buffer Liq." temporary)
    var
        Lin: Record "Línea Liquidación";
        Empleados: List of [Code[20]];
        Codigos: List of [Code[20]];
        EmployeeNo: Code[20];
    begin
        Buffer.Reset();
        Buffer.DeleteAll();
        if Fecha = 0D then
            Fecha := WorkDate();

        // Se parte de los LOTES y no del maestro de empleados: preguntarle el saldo a cada empleado
        // de la empresa recorrería el ledger una vez por persona, la mayoría para devolver cero.
        if not CodigosPorRol(Codigos, "Rol Franco Liq."::Devengo) then
            exit;
        Lin.SetCurrentKey("No. Empleado", "Fecha Liquidación", "Tipo Concepto");
        Lin.SetFilter("Cód. Concepto", ConstruirFiltroCodigos(Codigos));
        Lin.SetFilter("Fecha Liquidación", '<=%1', Fecha);
        if FiltroEmpleado <> '' then
            Lin.SetFilter("No. Empleado", FiltroEmpleado);
        Lin.SetLoadFields("No. Empleado");
        if Lin.FindSet() then
            repeat
                if not Empleados.Contains(Lin."No. Empleado") then
                    Empleados.Add(Lin."No. Empleado");
            until Lin.Next() = 0;

        foreach EmployeeNo in Empleados do
            AcumularFrancosEmpleado(Buffer, EmployeeNo, Fecha);

        Buffer.Reset();
        if Buffer.FindFirst() then;
    end;

    local procedure AcumularFrancosEmpleado(var Buffer: Record "Francos Buffer Liq." temporary; EmployeeNo: Code[20]; Fecha: Date)
    var
        Lin: Record "Línea Liquidación";
        Emp: Record Employee;
        CatCCT: Record "Categoría CCT";
        Codigos: List of [Code[20]];
        PorConsumir: Decimal;
        DelLote: Decimal;
    begin
        if not CodigosPorRol(Codigos, "Rol Franco Liq."::Devengo) then
            exit;
        if not Emp.Get(EmployeeNo) then
            Clear(Emp);

        // Consumo estrictamente ANTERIOR a la fecha de corte, igual que SaldoFrancosAFecha: lo que se
        // consume el día del corte pertenece al período que arranca ahí, no al saldo que se controla.
        PorConsumir := TotalPorRolHasta(EmployeeNo, "Rol Franco Liq."::Consumo, Fecha, false);

        Lin.SetCurrentKey("No. Empleado", "Fecha Liquidación", "Tipo Concepto");
        Lin.Ascending(true);
        Lin.SetRange("No. Empleado", EmployeeNo);
        Lin.SetFilter("Cód. Concepto", ConstruirFiltroCodigos(Codigos));
        Lin.SetFilter("Fecha Liquidación", '<=%1', Fecha);
        if not Lin.FindSet() then
            exit;

        repeat
            // FIFO: el consumo pendiente de atribuir se come los lotes más viejos primero.
            DelLote := 0;
            if PorConsumir > 0 then begin
                DelLote := Lin.Cantidad;
                if DelLote > PorConsumir then
                    DelLote := PorConsumir;
                PorConsumir -= DelLote;
            end;

            if not Buffer.Get(EmployeeNo, Lin."Cód. Convenio", Lin."Cód. Categoría") then begin
                Buffer.Init();
                Buffer."No. Empleado" := EmployeeNo;
                Buffer."Cód. Convenio" := Lin."Cód. Convenio";
                Buffer."Cód. Categoría" := Lin."Cód. Categoría";
                Buffer."Nombre Empleado" := CopyStr(Emp.FullName(), 1, MaxStrLen(Buffer."Nombre Empleado"));
                if CatCCT.Get(Lin."Cód. Convenio", Lin."Cód. Categoría") then
                    Buffer."Descripción Categoría" := CatCCT.Descripción;
                Buffer."Lote Más Antiguo" := Lin."Fecha Liquidación";
                Buffer.Insert();
            end;
            Buffer.Devengados += Lin.Cantidad;
            Buffer.Consumidos += DelLote;
            Buffer.Lotes += 1;
            Buffer."Lote Más Reciente" := Lin."Fecha Liquidación";
            Buffer.Modify();
        until Lin.Next() = 0;

        // Recién con todos los lotes vistos se puede saldar y valuar.
        Buffer.Reset();
        Buffer.SetRange("No. Empleado", EmployeeNo);
        if Buffer.FindSet() then
            repeat
                Buffer.Saldo := Buffer.Devengados - Buffer.Consumidos;
                Buffer."Valor Franco" := ValorFrancoDia(Buffer."Cód. Convenio", Buffer."Cód. Categoría", Fecha);
                Buffer."Importe Saldo" := Round(Buffer.Saldo * Buffer."Valor Franco", 0.01);
                Buffer.Modify();
            until Buffer.Next() = 0;
        Buffer.Reset();
    end;

    // Walks the accrual lots oldest-first, skips the already-consumed days, then consumes up to
    // DiasSolicitados more, accumulating amount valued at each lot's category.
    local procedure CaminarFIFO(EmployeeNo: Code[20]; DiasSolicitados: Decimal; FechaPago: Date; LiqActual: Code[20]; var Monto: Decimal; var DiasConsumidos: Decimal)
    var
        Lin: Record "Línea Liquidación";
        YaConsumido: Decimal;
        Saltar: Decimal;
        Restantes: Decimal;
        DiasLote: Decimal;
        DispLote: Decimal;
        Tomar: Decimal;
        ValorDia: Decimal;
    begin
        Monto := 0;
        DiasConsumidos := 0;
        if DiasSolicitados <= 0 then exit;

        YaConsumido := TotalConsumido(EmployeeNo, LiqActual);
        Saltar := YaConsumido;
        Restantes := DiasSolicitados;

        FiltrarLotes(Lin, EmployeeNo, LiqActual);
        if not Lin.FindSet() then exit;
        repeat
            DiasLote := Lin.Cantidad;
            if Saltar >= DiasLote then begin
                Saltar -= DiasLote;
            end else begin
                DispLote := DiasLote - Saltar;
                Saltar := 0;
                Tomar := DispLote;
                if Tomar > Restantes then Tomar := Restantes;

                ValorDia := ValorFrancoDia(Lin."Cód. Convenio", Lin."Cód. Categoría", FechaPago);
                Monto += Tomar * ValorDia;
                DiasConsumidos += Tomar;
                Restantes -= Tomar;
                if Restantes <= 0 then
                    exit;
            end;
        until Lin.Next() = 0;
    end;

    // FIFO consumption broken down by category: fills TempSlice with one row per (convenio, categoría)
    // consumed, each with Cantidad = days and Importe = days × VALOR_FRANCO of that lot's category at
    // FechaPago. Lets the recibo show one line per category/price. Capped at the available balance.
    procedure CalcularConsumoDesglosado(EmployeeNo: Code[20]; DiasSolicitados: Decimal; FechaPago: Date; LiqActual: Code[20]; var TempSlice: Record "Línea Liquidación" temporary)
    var
        Lin: Record "Línea Liquidación";
        Saltar: Decimal;
        Restantes: Decimal;
        DiasLote: Decimal;
        DispLote: Decimal;
        Tomar: Decimal;
        Linea: Integer;
    begin
        TempSlice.Reset();
        TempSlice.DeleteAll();
        if DiasSolicitados <= 0 then exit;

        Saltar := TotalConsumido(EmployeeNo, LiqActual);
        Restantes := DiasSolicitados;

        FiltrarLotes(Lin, EmployeeNo, LiqActual);
        if Lin.FindSet() then
            repeat
                if Restantes > 0 then begin
                    DiasLote := Lin.Cantidad;
                    if Saltar >= DiasLote then
                        Saltar -= DiasLote
                    else begin
                        DispLote := DiasLote - Saltar;
                        Saltar := 0;
                        Tomar := DispLote;
                        if Tomar > Restantes then Tomar := Restantes;
                        AcumularSlice(TempSlice, Lin."Cód. Convenio", Lin."Cód. Categoría", Tomar, Linea);
                        Restantes -= Tomar;
                    end;
                end;
            until (Lin.Next() = 0) or (Restantes <= 0);

        // Value each category slice at its own VALOR_FRANCO (lot category, pay date).
        TempSlice.Reset();
        if TempSlice.FindSet() then
            repeat
                TempSlice.Importe := TempSlice.Cantidad * ValorFrancoDia(TempSlice."Cód. Convenio", TempSlice."Cód. Categoría", FechaPago);
                TempSlice.Modify();
            until TempSlice.Next() = 0;
    end;

    local procedure AcumularSlice(var TempSlice: Record "Línea Liquidación" temporary; Convenio: Code[20]; Categoria: Code[20]; Dias: Decimal; var Linea: Integer)
    begin
        TempSlice.Reset();
        TempSlice.SetRange("Cód. Convenio", Convenio);
        TempSlice.SetRange("Cód. Categoría", Categoria);
        if TempSlice.FindFirst() then begin
            TempSlice.Cantidad += Dias;
            TempSlice.Modify();
        end else begin
            Linea += 10000;
            TempSlice.Reset();
            TempSlice.Init();
            TempSlice."No. Línea" := Linea;
            TempSlice."Cód. Convenio" := Convenio;
            TempSlice."Cód. Categoría" := Categoria;
            TempSlice.Cantidad := Dias;
            TempSlice.Insert();
        end;
    end;

    local procedure TotalDevengado(EmployeeNo: Code[20]; LiqActual: Code[20]): Decimal
    var
        Lin: Record "Línea Liquidación";
        Total: Decimal;
    begin
        // FiltrarLotes ya acota los conceptos en la base; acá sólo se evita traer el registro
        // entero para leerle un campo.
        FiltrarLotes(Lin, EmployeeNo, LiqActual);
        Lin.SetLoadFields(Cantidad);
        if Lin.FindSet() then
            repeat
                Total += Lin.Cantidad;
            until Lin.Next() = 0;
        exit(Total);
    end;

    local procedure TotalConsumido(EmployeeNo: Code[20]; LiqActual: Code[20]): Decimal
    var
        Lin: Record "Línea Liquidación";
        Codigos: List of [Code[20]];
        Total: Decimal;
    begin
        if not CodigosPorRol(Codigos, "Rol Franco Liq."::Consumo) then exit(0);
        Lin.SetCurrentKey("No. Empleado", "Fecha Liquidación", "Tipo Concepto");
        Lin.SetRange("No. Empleado", EmployeeNo);
        Lin.SetFilter("No. Liquidación", '<>%1', LiqActual);
        // Mismo cambio que en TotalPorRolHasta: el filtro de conceptos se evalúa en la base.
        Lin.SetFilter("Cód. Concepto", ConstruirFiltroCodigos(Codigos));
        Lin.SetLoadFields(Cantidad);
        if Lin.FindSet() then
            repeat
                Total += Lin.Cantidad;
            until Lin.Next() = 0;
        exit(Total);
    end;

    // Accrual lots for the employee, oldest first, excluding LiqActual. Filtered by concept role = Devengo.
    local procedure FiltrarLotes(var Lin: Record "Línea Liquidación"; EmployeeNo: Code[20]; LiqActual: Code[20])
    var
        Codigos: List of [Code[20]];
    begin
        Lin.SetCurrentKey("No. Empleado", "Fecha Liquidación", "Tipo Concepto");
        Lin.Ascending(true);
        Lin.SetRange("No. Empleado", EmployeeNo);
        Lin.SetFilter("No. Liquidación", '<>%1', LiqActual);
        if CodigosPorRol(Codigos, "Rol Franco Liq."::Devengo) then
            Lin.SetFilter("Cód. Concepto", ConstruirFiltroCodigos(Codigos))
        else
            Lin.SetRange("Cód. Concepto", '');  // no devengo concepts configured → empty set
    end;

    // Collects the distinct concept codes flagged with the given franco role (across all vigencias).
    local procedure CodigosPorRol(var Codigos: List of [Code[20]]; Rol: Enum "Rol Franco Liq."): Boolean
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Clear(Codigos);
        Concepto.SetRange("Rol Franco", Rol);
        if Concepto.FindSet() then
            repeat
                if not Codigos.Contains(Concepto.Código) then
                    Codigos.Add(Concepto.Código);
            until Concepto.Next() = 0;
        exit(Codigos.Count() > 0);
    end;

    /// <summary>Los códigos como filtro de BC: 'A'|'B'|'C'.</summary>
    /// <remarks>
    /// CADA CÓDIGO VA ENTRE COMILLAS. Sin ellas, un código con un carácter que el parser de filtros
    /// interpreta —&amp;, |, *, .., &lt;, &gt;, @— dejaría de buscarse a sí mismo y pasaría a ser sintaxis:
    /// el filtro seguiría siendo válido y devolvería otro conjunto, sin error. Hoy ningún concepto
    /// tiene esos caracteres, así que esto no cambia nada; existe para que siga siendo cierto el día
    /// que alguien cree uno.
    /// </remarks>
    internal procedure ConstruirFiltroCodigos(Codigos: List of [Code[20]]): Text
    var
        Filtro: TextBuilder;
        Cod: Code[20];
        CodigoTexto: Text;
    begin
        foreach Cod in Codigos do begin
            if Filtro.Length() > 0 then
                Filtro.Append('|');
            CodigoTexto := Cod;
            Filtro.Append('''' + CodigoTexto.Replace('''', '''''') + '''');
        end;
        exit(Filtro.ToText());
    end;

    // Per-day franco value for a category = parameter VALOR_FRANCO_<CONVENIO>_<CATEGORÍA> at FechaPago.
    local procedure ValorFrancoDia(Convenio: Code[20]; Categoria: Code[20]; FechaPago: Date): Decimal
    var
        ParamVig: Record "Parámetro Vigente";
        Cod: Code[50];
    begin
        if (Convenio = '') or (Categoria = '') then exit(0);
        Cod := CopyStr(ParamValorFranco + '_' + Convenio + '_' + Categoria, 1, MaxStrLen(Cod));
        ParamVig.SetCurrentKey("Cód. Parámetro", "Vigencia Desde");
        ParamVig.SetRange("Cód. Parámetro", Cod);
        ParamVig.SetFilter("Vigencia Desde", '<=%1', FechaPago);
        if ParamVig.FindLast() then
            exit(ParamVig.Valor);
        exit(0);
    end;
}
