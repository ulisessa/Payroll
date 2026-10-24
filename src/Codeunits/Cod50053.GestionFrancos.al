namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.HumanResources.Setup;
using Microsoft.Projects.Project.Job;

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
        FCuenta: Codeunit "Cuenta Corriente Francos";
        FCfgCargada: Boolean;
        FFechaConfig: Date;
        FParamValor: Code[250];
        FIdentificadores: List of [Text];
        FCacheValor: Dictionary of [Text, Decimal];
        FTipoPorDocumento: Dictionary of [Code[20], Code[20]];
        FEvaluador: Codeunit "Evaluador Fórmula";
        FTipoAtrPrecio: Code[20];
        FDivisorValor: Integer;
        FConceptoConsumo: Code[20];
        FCtxTC: Dictionary of [Text, Decimal];
        ErrSinParametroValor: Label 'El concepto %1 paga francos pero no tiene cargado "Parámetro del valor", así que el motor no sabe de dónde sacar el precio del franco.\\El precio de un franco NO sale de la fórmula del concepto —que devuelve días—: lo pone el motor, con el convenio y la categoría de cada lote.\\En la ficha del concepto, cargá "Parámetro del valor" (por ejemplo VALOR_FRANCO). Si además el precio depende de dónde se devengó el franco, cargá "Atributo que afina el precio" y "Divisor del valor".', Comment = '%1 = código del concepto de consumo de francos';
        ErrSinConceptoConsumo: Label 'No hay ningún concepto con Rol Franco = Consumo, así que no se puede valuar un pago de francos.';
        ErrSinPrecioFranco: Label 'No hay precio para un franco de %3 / %4 al %5, así que valdría cero.\\La fórmula del valor (%1) da cero. Cada nombre se busca como NOMBRE_%2_%3_%4 —por pesquería— y después como NOMBRE_%3_%4, y ninguno tiene un valor vigente a esa fecha.\\Cargá el valor que falte en el parámetro que nombra %1.', Comment = '%1 = fórmula del valor; %2 = sufijo de pesquería; %3 = convenio del lote; %4 = categoría del lote; %5 = fecha de pago';
        ErrFormulaValor: Label 'La fórmula del "Parámetro del valor" del concepto %1 (%2) no se pudo evaluar: %3', Comment = '%1 = concepto de consumo de francos; %2 = fórmula; %3 = detalle del error';
        ErrFrancoSinVariableTC: Label 'El precio del franco %1 está en %2 pero su fila no declara "Variable Tipo de Cambio", así que el motor no sabe a cuánto convertirlo.\\Cargá la variable en esa fila de Parámetro Vigente —normalmente TC_COMPRADOR—, o sacale la Moneda si el valor ya está en pesos.', Comment = '%1 = código del parámetro; %2 = moneda de la fila';
        ErrFrancoTCInexistente: Label 'El precio del franco %2 pide la cotización %1, que no existe en el contexto de la liquidación.\\Las cotizaciones del franco se toman de las variables TC_*: revisá que %1 esté definida como Fuente de Datos y que el nombre coincida.', Comment = '%1 = nombre de la variable de tipo de cambio; %2 = código del parámetro';
        ErrFrancoTCEnCero: Label 'La cotización %1 vale cero el día en que se paga el franco %2, así que el precio quedaría en cero.\\Cargá la cotización de esa fecha antes de liquidar.', Comment = '%1 = nombre de la variable de tipo de cambio; %2 = código del parámetro';

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
        exit(SaldoFrancos(EmployeeNo, LiqActual, DMY2Date(31, 12, 9999)));
    end;

    // El cálculo histórico debe pedir el mismo corte que la matriz: un lote posterior todavía
    // no está disponible, aunque su liquidación ya haya sido calculada. La sobrecarga anterior
    // conserva la consulta global de la cuenta para los llamadores sin fecha.
    procedure SaldoFrancos(EmployeeNo: Code[20]; LiqActual: Code[20]; FechaCorte: Date): Decimal
    begin
        exit(TotalDevengado(EmployeeNo, LiqActual, FechaCorte) - TotalConsumido(EmployeeNo, LiqActual, FechaCorte));
    end;

    // Francos available to enjoy starting on Fecha: accrued on/before Fecha minus consumed strictly before
    // Fecha. Stable across the consumption that happens during the Francos period itself (it excludes it),
    // so it gives a fixed duration for the state — the day the francos run out is Fecha + this balance.
    /// <summary>
    /// El precio de UN día de franco para el par que paga esta liquidación.
    /// </summary>
    /// <remarks>
    /// Para valorizar francos que todavía NO tienen lote: el devengo del último tramo antes de una
    /// baja se calcula en la fórmula, no se lee del ledger, porque las variables de sistema se
    /// precalculan en LoadScalars —antes del bucle de conceptos— y para entonces el lote del 1062 ni
    /// existe. Ése fue el error que costó tres publicaciones: el código estaba bien y lo que estaba
    /// mal era CUÁNDO se evaluaba.
    ///
    /// Los francos CON lote siguen saliendo del FIFO a su propio precio. Esto es sólo para los que
    /// se devengan en el mismo documento que los paga, y su precio es el de hoy porque se devengaron
    /// hoy.
    ///
    /// No corta si falta el precio. Se evalúa para TODAS las liquidaciones —es una variable de
    /// sistema y se precalculan todas—, así que un Error acá voltearía la liquidación de cualquiera
    /// que no tenga nada que ver con los francos.
    /// </remarks>
    procedure ValorFrancoDiaDeLaLiquidacion(EmployeeNo: Code[20]; LiqActual: Code[20]; FechaPago: Date): Decimal
    var
        UltimoLote: Record "Línea Liquidación";
        Convenio: Code[20];
        Categoria: Code[20];
    begin
        EstablecerFechaConfig(FechaPago);
        if (EmployeeNo = '') or (FechaPago = 0D) then
            exit(0);

        // EL SUFIJO SALE DEL ÚLTIMO LOTE REAL, no de una línea armada al vuelo. SufijoDelLote
        // necesita la ENTIDAD —el buque o el proyecto— para buscar el atributo de precio, y una
        // liquidación final no tiene proyecto: el sufijo queda vacío, el parámetro cae a un nivel
        // que no existe y el precio da CERO. Medido: el término del devengo se anulaba entero
        // porque VALOR_FRANCO_DIA valía 0 mientras los lotes del FIFO se valuaban bien a 53.158,67.
        //
        // Se excluye la liquidación actual a propósito: su propio lote tampoco tiene proyecto, y es
        // justo el que no sirve para resolver el sufijo. El anterior —el del cierre de marea— sí lo
        // tiene.
        //
        // El PAR, en cambio, sale de la liquidación actual: el franco se paga al convenio y la
        // categoría de hoy, aunque se haya devengado embarcado en otra.
        FiltrarLotes(UltimoLote, EmployeeNo, LiqActual);
        UltimoLote.SetFilter("Fecha Liquidación", '<=%1', FechaPago);
        if not UltimoLote.FindLast() then
            exit(0);

        ParQuePagaElFranco(LiqActual, UltimoLote, Convenio, Categoria);
        exit(ResolverValorFrancoDia(SufijoDelLote(UltimoLote), Convenio, Categoria, FechaPago, false, TipoDeLaLiquidacion(LiqActual), EmployeeNo));
    end;

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
        if FCuenta.Activa(EmployeeNo) then exit(FCuenta.Total(EmployeeNo, Rol, '', Fecha, Inclusivo));
        if not CodigosPorRol(Codigos, Rol) then exit(0);
        Lin.SetCurrentKey("No. Empleado", "Fecha Liquidación", "Tipo Concepto");
        Lin.SetRange("No. Empleado", EmployeeNo);
        // EL CONJUNTO DE CONCEPTOS VA COMO FILTRO. Antes se traían TODAS las líneas del empleado
        // —todos sus años, todos sus conceptos— para sumar las de dos, y el descarte se hacía con un
        // Contains adentro del bucle, que además es otro barrido lineal por fila. El predicado es
        // exactamente el mismo; lo único que cambia es dónde se evalúa. FiltrarLotes ya lo hacía así.
        FiltrarCodigos(Lin, Codigos);
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
        FiltrarCodigos(Lin, Codigos);
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
        LoteCuenta: Record "Movimiento Franco Liq.";
        SaldoCuenta: Decimal;
        Lin: Record "Línea Liquidación";
        Emp: Record Employee;
        CatCCT: Record "Categoría CCT";
        Codigos: List of [Code[20]];
        PorConsumir: Decimal;
        DelLote: Decimal;
    begin
        EstablecerFechaConfig(Fecha);
        if FCuenta.Activa(EmployeeNo) then begin
            Emp.Get(EmployeeNo);
            LoteCuenta.SetRange("No. Empleado", EmployeeNo);
            LoteCuenta.SetRange(Tipo, LoteCuenta.Tipo::Devengo);
            LoteCuenta.SetFilter("Fecha Devengamiento", '<=%1', Fecha);
            if LoteCuenta.FindSet() then repeat
                // El control conserva la semántica anterior: consumo estrictamente anterior al corte.
                SaldoCuenta := FCuenta.SaldoAlInicio(LoteCuenta."No. Lote", Fecha);
                if SaldoCuenta > 0 then begin
                    if not Buffer.Get(EmployeeNo, LoteCuenta."Cód. Convenio", LoteCuenta."Cód. Categoría") then begin
                        Buffer.Init();
                        Buffer."No. Empleado" := EmployeeNo;
                        Buffer."Cód. Convenio" := LoteCuenta."Cód. Convenio";
                        Buffer."Cód. Categoría" := LoteCuenta."Cód. Categoría";
                        Buffer."Nombre Empleado" := CopyStr(Emp.FullName(), 1, MaxStrLen(Buffer."Nombre Empleado"));
                        if CatCCT.Get(LoteCuenta."Cód. Convenio", LoteCuenta."Cód. Categoría") then Buffer."Descripción Categoría" := CatCCT.Descripción;
                        Buffer."Lote Más Antiguo" := LoteCuenta."Fecha Devengamiento";
                        Buffer.Insert();
                    end;
                    Buffer.Devengados += LoteCuenta.Cantidad;
                    Buffer.Consumidos += LoteCuenta.Cantidad - SaldoCuenta;
                    Buffer.Saldo += SaldoCuenta;
                    Buffer.Lotes += 1;
                    Buffer."Lote Más Reciente" := LoteCuenta."Fecha Devengamiento";
                    Buffer."Valor Franco" := ValorFrancoDiaParaMostrar('', Buffer."Cód. Convenio", Buffer."Cód. Categoría", Fecha);
                    Buffer."Importe Saldo" := Round(Buffer.Saldo * Buffer."Valor Franco", 0.01);
                    Buffer.Modify();
                end;
            until LoteCuenta.Next() = 0;
            exit;
        end;

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
        FiltrarCodigos(Lin, Codigos);
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
                Buffer."Valor Franco" := ValorFrancoDiaParaMostrar('', Buffer."Cód. Convenio", Buffer."Cód. Categoría", Fecha);
                Buffer."Importe Saldo" := Round(Buffer.Saldo * Buffer."Valor Franco", 0.01);
                Buffer.Modify();
            until Buffer.Next() = 0;
        Buffer.Reset();
    end;

    procedure ValuarMatriz(var Filas: Record "Lote Franco Buffer Liq." temporary; Documento: Code[20]; Fecha: Date)
    var
        Lin: Record "Línea Liquidación";
        Convenio: Code[20];
        Categoria: Code[20];
        Pleno: Decimal;
    begin
        EstablecerFechaConfig(Fecha);
        if Filas.FindSet() then
            repeat
                Lin.Init();
                Lin."No. Empleado" := Filas."No. Empleado";
                Lin."No. Liquidación" := Filas."No. Liquidación Origen";
                Lin."Fecha Liquidación" := Filas."Fecha Lote";
                Lin."No. Proyecto" := Filas."No. Proyecto";
                Lin."Cód. Convenio" := Filas."Cód. Convenio";
                Lin."Cód. Categoría" := Filas."Cód. Categoría";
                Filas."Tipo Buque" := SufijoDelLote(Lin);
                ParQuePagaElFranco(Documento, Lin, Convenio, Categoria);
                Filas."Valor Franco" := ValorFrancoDia(Filas."Tipo Buque", Convenio, Categoria, Fecha, Documento, Filas."No. Empleado");
                Pleno := ValorFrancoDiaParaMostrar('', Convenio, Categoria, Fecha);
                Filas.Coeficiente := 1;
                if Pleno <> 0 then Filas.Coeficiente := Filas."Valor Franco" / Pleno;
                Filas.Importe := Filas."Días Tomados" * Filas."Valor Franco";
                Filas.Modify();
            until Filas.Next() = 0;
        Filas.Reset();
    end;

    // Walks the accrual lots oldest-first, skips the already-consumed days, then consumes up to
    // DiasSolicitados more, accumulating amount valued at each lot's category.
    local procedure CaminarFIFO(EmployeeNo: Code[20]; DiasSolicitados: Decimal; FechaPago: Date; LiqActual: Code[20]; var Monto: Decimal; var DiasConsumidos: Decimal)
    var
        MatrizFilas: Record "Lote Franco Buffer Liq." temporary;
        SaldoCuenta: Decimal;
        Lin: Record "Línea Liquidación";
        YaConsumido: Decimal;
        Saltar: Decimal;
        Restantes: Decimal;
        DiasLote: Decimal;
        DispLote: Decimal;
        Tomar: Decimal;
        ValorDia: Decimal;
        ConvPago: Code[20];
        CatPago: Code[20];
    begin
        EstablecerFechaConfig(FechaPago);
        if FCuenta.Activa(EmployeeNo) then begin
            Monto := 0;
            DiasConsumidos := 0;
            SaldoCuenta := SaldoFrancos(EmployeeNo, LiqActual, FechaPago);
            if DiasSolicitados > SaldoCuenta then DiasSolicitados := SaldoCuenta;
            if DiasSolicitados <= 0 then exit;
            FCuenta.Matriz(EmployeeNo, FechaPago, LiqActual, DiasSolicitados, false, MatrizFilas);
            ValuarMatriz(MatrizFilas, LiqActual, FechaPago);
            if MatrizFilas.FindSet() then repeat
                Monto += MatrizFilas.Importe;
                DiasConsumidos += MatrizFilas."Días Tomados";
            until MatrizFilas.Next() = 0;
            exit;
        end;

        Monto := 0;
        DiasConsumidos := 0;
        if DiasSolicitados <= 0 then exit;

        YaConsumido := TotalConsumido(EmployeeNo, LiqActual, FechaPago);
        Saltar := YaConsumido;
        Restantes := DiasSolicitados;

        FiltrarLotes(Lin, EmployeeNo, LiqActual);
        Lin.SetFilter("Fecha Liquidación", '<=%1', FechaPago);
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

                // La PESQUERÍA es del lote: un franco ganado en un tangonero se paga al 30% aunque hoy
                // el tripulante esté en un potero. Sin atributo cargado vale 1 y esto se comporta como
                // antes. La CATEGORÍA, en cambio, es la de la liquidación que paga (ver
                // ParQuePagaElFranco).
                ParQuePagaElFranco(LiqActual, Lin, ConvPago, CatPago);
                ValorDia := ValorFrancoDia(SufijoDelLote(Lin), ConvPago, CatPago, FechaPago, LiqActual, EmployeeNo);
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
        MatrizFilas: Record "Lote Franco Buffer Liq." temporary;
        SaldoCuenta: Decimal;
        Lin: Record "Línea Liquidación";
        Saltar: Decimal;
        Restantes: Decimal;
        DiasLote: Decimal;
        DispLote: Decimal;
        Tomar: Decimal;
        Linea: Integer;
        ConvPago: Code[20];
        CatPago: Code[20];
    begin
        EstablecerFechaConfig(FechaPago);
        if FCuenta.Activa(EmployeeNo) then begin
            TempSlice.Reset();
            TempSlice.DeleteAll();
            if DiasSolicitados <= 0 then exit;
            FCuenta.Matriz(EmployeeNo, FechaPago, LiqActual, DiasSolicitados, false, MatrizFilas);
            ValuarMatriz(MatrizFilas, LiqActual, FechaPago);
            if MatrizFilas.FindSet() then repeat
                TempSlice.Init();
                TempSlice."No. Línea" := MatrizFilas."No. Línea";
                TempSlice."Cód. Convenio" := MatrizFilas."Cód. Convenio";
                TempSlice."Cód. Categoría" := MatrizFilas."Cód. Categoría";
                TempSlice.Cantidad := MatrizFilas."Días Tomados";
                TempSlice.Importe := MatrizFilas.Importe;
                TempSlice."No. Lote Franco" := MatrizFilas."No. Lote";
                TempSlice."Id. Selección Francos" := MatrizFilas."Id. Selección";
                TempSlice.Insert();
            until MatrizFilas.Next() = 0;
            exit;
        end;

        TempSlice.Reset();
        TempSlice.DeleteAll();
        if DiasSolicitados <= 0 then exit;

        Saltar := TotalConsumido(EmployeeNo, LiqActual, FechaPago);
        Restantes := DiasSolicitados;

        FiltrarLotes(Lin, EmployeeNo, LiqActual);
        Lin.SetFilter("Fecha Liquidación", '<=%1', FechaPago);
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
                        // El importe se acumula LOTE POR LOTE y no se valúa al final sobre el slice ya
                        // agrupado. Dos lotes de la misma categoría pueden traer coeficientes distintos
                        // —uno devengado en tangonero y otro en potero—, así que valuar después de
                        // agrupar les aplicaría a los dos el de cualquiera de ellos.
                        //
                        // El slice se sigue AGRUPANDO por la categoría del lote —el recibo muestra de
                        // dónde salió cada franco—, pero el precio ya no sale de ahí: lo pone el par
                        // de la liquidación que paga (ver ParQuePagaElFranco).
                        ParQuePagaElFranco(LiqActual, Lin, ConvPago, CatPago);
                        AcumularSlice(TempSlice, Lin."Cód. Convenio", Lin."Cód. Categoría", Tomar,
                            Tomar * ValorFrancoDia(SufijoDelLote(Lin), ConvPago, CatPago, FechaPago, LiqActual, EmployeeNo),
                            Linea);
                        Restantes -= Tomar;
                    end;
                end;
            until (Lin.Next() = 0) or (Restantes <= 0);
    end;

    /// <summary>El desglose FIFO lote por lote, sin agrupar: qué se tomó de cada uno y a qué precio.</summary>
    /// <remarks>
    /// Es el mismo recorrido que CalcularConsumoDesglosado, que agrupa por categoría porque eso es lo
    /// que necesita la línea del recibo. Acá no se agrupa: la pregunta que contesta es "de dónde salió
    /// este importe", y para eso hace falta ver cada lote con su fecha, su marea y su precio.
    ///
    /// Se reconstruye en el momento y no se guarda. Como excluye la liquidación en curso igual que el
    /// cálculo, y los lotes anteriores ya no se mueven, devuelve lo mismo que se pagó. Persistirlo
    /// obligaría a mantenerlo sincronizado con cada recálculo y anulación, y un desglose desactualizado
    /// es peor que no tenerlo: se ve igual de creíble.
    /// </remarks>
    procedure DetallePorLote(EmployeeNo: Code[20]; DiasSolicitados: Decimal; FechaPago: Date; LiqActual: Code[20]; var Buffer: Record "Lote Franco Buffer Liq." temporary)
    var
        MatrizFilas: Record "Lote Franco Buffer Liq." temporary;
        SaldoCuenta: Decimal;
        Lin: Record "Línea Liquidación";
        Cat: Record "Categoría CCT";
        Saltar: Decimal;
        Restantes: Decimal;
        DiasLote: Decimal;
        DispLote: Decimal;
        Tomar: Decimal;
        Linea: Integer;
        ValorPleno: Decimal;
        ConvPago: Code[20];
        CatPago: Code[20];
    begin
        EstablecerFechaConfig(FechaPago);
        if FCuenta.Activa(EmployeeNo) then begin
            FCuenta.Matriz(EmployeeNo, FechaPago, LiqActual, DiasSolicitados, false, Buffer);
            ValuarMatriz(Buffer, LiqActual, FechaPago);
            exit;
        end;

        Buffer.Reset();
        Buffer.DeleteAll();
        if DiasSolicitados <= 0 then
            exit;

        Saltar := TotalConsumido(EmployeeNo, LiqActual, FechaPago);
        Restantes := DiasSolicitados;

        FiltrarLotes(Lin, EmployeeNo, LiqActual);
        Lin.SetFilter("Fecha Liquidación", '<=%1', FechaPago);
        if not Lin.FindSet() then
            exit;
        repeat
            if Restantes > 0 then begin
                DiasLote := Lin.Cantidad;
                if Saltar >= DiasLote then
                    Saltar -= DiasLote
                else begin
                    DispLote := DiasLote - Saltar;
                    Saltar := 0;
                    Tomar := DispLote;
                    if Tomar > Restantes then
                        Tomar := Restantes;

                    Linea += 1;
                    Buffer.Init();
                    Buffer."No. Línea" := Linea;
                    Buffer."Fecha Lote" := Lin."Fecha Liquidación";
                    Buffer."No. Liquidación Origen" := Lin."No. Liquidación";
                    Buffer."No. Proyecto" := Lin."No. Proyecto";
                    Buffer."Cód. Convenio" := Lin."Cód. Convenio";
                    Buffer."Cód. Categoría" := Lin."Cód. Categoría";
                    Buffer."Cód. Concepto Lote" := Lin."Cód. Concepto";
                    if Cat.Get(Lin."Cód. Convenio", Lin."Cód. Categoría") then
                        Buffer."Descripción Categoría" := Cat.Descripción;
                    Buffer."Días del Lote" := DiasLote;
                    Buffer."Días Disponibles" := DispLote;
                    Buffer."Días Tomados" := Tomar;
                    Buffer."Tipo Buque" := SufijoDelLote(Lin);
                    // La categoría del precio es la de la liquidación que paga; el lote conserva la
                    // suya en Cód. Categoría, que es lo que el desglose muestra.
                    ParQuePagaElFranco(LiqActual, Lin, ConvPago, CatPago);
                    Buffer."Valor Franco" := ValorFrancoDia(Buffer."Tipo Buque", ConvPago, CatPago, FechaPago, LiqActual, EmployeeNo);
                    // El coeficiente ya no multiplica nada: el valor viene resuelto por la terna. Se
                    // muestra igual, como la proporción contra el valor pleno de la categoría, porque
                    // es la pregunta que se hace quien mira el recibo — "¿por qué éste cobra menos?".
                    ValorPleno := ValorFrancoDiaParaMostrar('', ConvPago, CatPago, FechaPago);
                    if ValorPleno <> 0 then
                        Buffer.Coeficiente := Round(Buffer."Valor Franco" / ValorPleno, 0.0001)
                    else
                        Buffer.Coeficiente := 1;
                    Buffer.Importe := Tomar * Buffer."Valor Franco";
                    Buffer.Insert();

                    Restantes -= Tomar;
                end;
            end;
        until (Lin.Next() = 0) or (Restantes <= 0);
    end;

    /// <summary>La proporción del valor que se paga por los francos de ESTE lote.</summary>
    /// <remarks>
    /// Sale de la pesquería en la que se devengó el lote, no de la liquidación que lo paga: un franco
    /// ganado en un tangonero se paga al 30% aunque hoy el tripulante esté en un potero. Por eso se
    /// resuelve contra el buque del proyecto del lote y no contra el contexto de la liquidación.
    ///
    /// El valor vive en un atributo del buque, igual que la veda: el motor sabe que hay un coeficiente
    /// y dónde buscarlo, y cuánto vale para cada buque lo dice la configuración. Sin atributo cargado
    /// devuelve 1 —se paga entero—, que es exactamente lo que hacía antes de existir esta función.
    /// </remarks>
    /// <summary>El tipo de buque en el que se devengó el lote: PO potero, TA tangonero. Vacío si no se sabe.</summary>
    /// <remarks>
    /// El valor del franco depende de la terna TIPO DE BUQUE + CONVENIO + CATEGORÍA, y no de una sola
    /// de las tres. Medido contra enero de 2026: la marinería 729/15 en tangonero cobra el 30% del
    /// valor pleno, pero los oficiales 175/75 embarcados en ESOS MISMOS buques cobran el 100%, igual
    /// que la marinería en potero. Resolverlo sólo por el buque le bajaba el franco a los oficiales, y
    /// sólo por el convenio se lo bajaba a la marinería de los poteros.
    ///
    /// Se toma del lote, no de la liquidación que paga: un franco ganado en un tangonero vale lo que
    /// valía ahí aunque hoy el tripulante esté en un potero.
    /// </remarks>
    /// <summary>Lee del concepto de consumo cómo hay que valuar un lote. Se cachea por sesión.</summary>
    /// <remarks>
    /// Antes esto estaba escrito en el motor: el nombre del parámetro, que la pesquería sale de
    /// TIPOACTIVIDAD, que PO significa CAL y TA significa LAN, y que hay que dividir por 30. Son
    /// decisiones del CCT y el CCT cambia sin que cambie el código, así que viven en el concepto.
    ///
    /// No hay valor por omisión. Sin configuración el motor no inventa un parámetro: corta con un
    /// error que dice qué cargar. Un nombre de parámetro escrito acá adentro es exactamente lo que
    /// hizo falta sacar, y un cero silencioso sería peor —el franco se pagaría en cero y el recibo
    /// saldría igual de creíble.
    /// </remarks>
    local procedure EstablecerFechaConfig(Fecha: Date)
    begin
        if FFechaConfig = Fecha then
            exit;
        FFechaConfig := Fecha;
        FCfgCargada := false;
        Clear(FParamValor);
        Clear(FIdentificadores);
        Clear(FCacheValor);
        Clear(FTipoAtrPrecio);
        Clear(FDivisorValor);
        Clear(FConceptoConsumo);
    end;

    local procedure CargarConfigValuacion()
    var
        Concepto: Record "Concepto Liquidación";
    begin
        if FCfgCargada then
            exit;
        FCfgCargada := true;

        // Se recorren todos y gana el primero configurado: si hay varios conceptos de consumo, basta
        // con que uno diga cómo se valúa, porque el precio del franco es del lote y no del concepto.
        Concepto.SetRange("Rol Franco", "Rol Franco Liq."::Consumo);
        Concepto.SetRange(Activo, true);
        Concepto.SetFilter("Vigencia Desde", '<=%1', FFechaConfig);
        Concepto.SetFilter("Vigencia Hasta", '%1|>=%2', 0D, FFechaConfig);
        if not Concepto.FindSet() then
            Error(ErrSinConceptoConsumo);
        FConceptoConsumo := Concepto.Código;
        repeat
            if Concepto."Cód. Parámetro Valor" <> '' then begin
                FConceptoConsumo := Concepto.Código;
                FParamValor := Concepto."Cód. Parámetro Valor";
                IdentificadoresDeValor(FParamValor, FIdentificadores);
                FTipoAtrPrecio := Concepto."Cód. Tipo Atributo Precio";
                FDivisorValor := Concepto."Divisor Valor";
                exit;
            end;
        until Concepto.Next() = 0;
    end;

    /// <summary>El sufijo que el lote le agrega al código del parámetro. Vacío si no corresponde.</summary>
    /// <remarks>
    /// El atributo lo nombra el concepto, la entidad a la que se le pregunta sale del propio tipo de
    /// atributo, y el texto del sufijo lo pone el valor. Nada de eso está acá: el motor sólo arma la
    /// pregunta y concatena la respuesta.
    ///
    /// Se resuelve a la fecha del LOTE. Un franco ganado en un tangonero vale lo que valía ahí aunque
    /// hoy el tripulante esté en un potero.
    /// </remarks>
    local procedure SufijoDelLote(Lin: Record "Línea Liquidación"): Code[10]
    var
        TipoAtr: Record "Tipo Atributo Liq.";
        Atributo: Record "Atributo Entidad Liq.";
        ValorAtr: Record "Valor Atributo Liq.";
        CodEntidad: Code[20];
    begin
        CargarConfigValuacion();
        if FTipoAtrPrecio = '' then
            exit('');
        if not TipoAtr.Get(FTipoAtrPrecio) then
            exit('');

        CodEntidad := EntidadDelLote(Lin, TipoAtr."Tipo Entidad");
        if CodEntidad = '' then
            exit('');
        if not Atributo.Vigente(FTipoAtrPrecio, TipoAtr."Tipo Entidad", CodEntidad, Lin."Fecha Liquidación") then
            exit('');

        ValorAtr.SetRange("Cód. Tipo Atributo", FTipoAtrPrecio);
        ValorAtr.SetRange(Código, Atributo."Cód. Valor");
        if not ValorAtr.FindFirst() then
            exit('');
        exit(ValorAtr."Sufijo Parámetro");
    end;

    local procedure EntidadDelLote(Lin: Record "Línea Liquidación"; TipoEntidad: Enum "Tipo Entidad Estado"): Code[20]
    begin
        case TipoEntidad of
            TipoEntidad::Empleado:
                exit(Lin."No. Empleado");
            TipoEntidad::Buque:
                exit(BuqueDelLote(Lin));
            TipoEntidad::Proyecto:
                exit(Lin."No. Proyecto");
        end;
        exit('');
    end;

    /// <summary>El buque en el que se devengó el lote. Vacío si no hay forma de saberlo.</summary>
    /// <remarks>
    /// Normalmente sale del proyecto del lote. Pero LOS SALDOS INICIALES NO TIENEN PROYECTO: se
    /// migraron con empleado, categoría, fecha y días, y nada más. Son 74 lotes con 4.279 días contra
    /// 90 lotes con proyecto y 1.143 días, o sea la mayor parte del saldo del sistema. Quedarse en el
    /// primer camino dejaba sin coeficiente justo a los que más pesan, y el franco se seguía pagando
    /// entero sin que nada lo indicara.
    ///
    /// El segundo camino los recupera: a la fecha del lote el empleado estaba en algún estado, y ese
    /// estado sí tiene proyecto —incluso los de nómina, que llevan el buque en la dimensión global 1—.
    /// Reconstruye el buque para los 74, sin excepción.
    ///
    /// No es lo mismo que preguntar por el buque de HOY: se busca el estado vigente a la fecha en que
    /// se devengó el franco, que es la que decide el coeficiente.
    /// </remarks>
    local procedure BuqueDelLote(Lin: Record "Línea Liquidación"): Code[20]
    var
        EstadoEmp: Record "Estado Empleado";
        Job: Record Job;
    begin
        if (Lin."No. Proyecto" <> '') and Job.Get(Lin."No. Proyecto") then
            if Job."Global Dimension 1 Code" <> '' then
                exit(Job."Global Dimension 1 Code");

        if Lin."No. Empleado" = '' then
            exit('');

        EstadoEmp.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        EstadoEmp.SetRange("Tipo Entidad", EstadoEmp."Tipo Entidad"::Empleado);
        EstadoEmp.SetRange("No. Empleado", Lin."No. Empleado");
        EstadoEmp.SetFilter("Fecha Inicio", '<=%1', Lin."Fecha Liquidación");
        EstadoEmp.SetFilter("No. Proyecto", '<>%1', '');
        EstadoEmp.Ascending(false);
        if EstadoEmp.FindSet() then
            repeat
                if EstadoEmp.FechaFinEfectiva() >= Lin."Fecha Liquidación" then
                    if Job.Get(EstadoEmp."No. Proyecto") then
                        if Job."Global Dimension 1 Code" <> '' then
                            exit(Job."Global Dimension 1 Code");
            until EstadoEmp.Next() = 0;

        exit('');
    end;

    local procedure AcumularSlice(var TempSlice: Record "Línea Liquidación" temporary; Convenio: Code[20]; Categoria: Code[20]; Dias: Decimal; Importe: Decimal; var Linea: Integer)
    begin
        TempSlice.Reset();
        TempSlice.SetRange("Cód. Convenio", Convenio);
        TempSlice.SetRange("Cód. Categoría", Categoria);
        if TempSlice.FindFirst() then begin
            TempSlice.Cantidad += Dias;
            TempSlice.Importe += Importe;
            TempSlice.Modify();
        end else begin
            Linea += 10000;
            TempSlice.Reset();
            TempSlice.Init();
            TempSlice."No. Línea" := Linea;
            TempSlice."Cód. Convenio" := Convenio;
            TempSlice."Cód. Categoría" := Categoria;
            TempSlice.Cantidad := Dias;
            TempSlice.Importe := Importe;
            TempSlice.Insert();
        end;
    end;

    local procedure TotalDevengado(EmployeeNo: Code[20]; LiqActual: Code[20]; FechaCorte: Date): Decimal
    var
        Lin: Record "Línea Liquidación";
        Total: Decimal;
    begin
        if FCuenta.Activa(EmployeeNo) then exit(FCuenta.Total(EmployeeNo, "Rol Franco Liq."::Devengo, LiqActual, FechaCorte, true));
        // FiltrarLotes ya acota los conceptos en la base; acá sólo se evita traer el registro
        // entero para leerle un campo.
        FiltrarLotes(Lin, EmployeeNo, LiqActual);
        Lin.SetFilter("Fecha Liquidación", '<=%1', FechaCorte);
        Lin.SetLoadFields(Cantidad);
        if Lin.FindSet() then
            repeat
                Total += Lin.Cantidad;
            until Lin.Next() = 0;
        exit(Total);
    end;

    local procedure TotalConsumido(EmployeeNo: Code[20]; LiqActual: Code[20]; FechaCorte: Date): Decimal
    var
        Lin: Record "Línea Liquidación";
        Codigos: List of [Code[20]];
        Total: Decimal;
    begin
        if FCuenta.Activa(EmployeeNo) then exit(FCuenta.Total(EmployeeNo, "Rol Franco Liq."::Consumo, LiqActual, FechaCorte, true));
        if not CodigosPorRol(Codigos, "Rol Franco Liq."::Consumo) then exit(0);
        Lin.SetCurrentKey("No. Empleado", "Fecha Liquidación", "Tipo Concepto");
        Lin.SetRange("No. Empleado", EmployeeNo);
        Lin.SetFilter("No. Liquidación", '<>%1', LiqActual);
        Lin.SetFilter("Fecha Liquidación", '<=%1', FechaCorte);
        // Mismo cambio que en TotalPorRolHasta: el filtro de conceptos se evalúa en la base.
        FiltrarCodigos(Lin, Codigos);
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
        // EL FILTRO SÓLO SI HAY LIQUIDACIÓN QUE EXCLUIR. Pasar '' NO lo desactiva: deja puesto
        // "<>''", que descarta las líneas sin número —ninguna— pero también impide que el llamador
        // pida el conjunto COMPLETO. La indemnización de francos no gozados lo necesita completo,
        // porque el devengo del último tramo nace en el mismo documento que lo paga, y con el filtro
        // puesto ese lote quedaba afuera: el importe salía por 12 días en vez de 13, sin un solo
        // error a la vista.
        if LiqActual <> '' then
            Lin.SetFilter("No. Liquidación", '<>%1', LiqActual);
        CodigosPorRol(Codigos, "Rol Franco Liq."::Devengo);
        FiltrarCodigos(Lin, Codigos);  // sin conceptos configurados, tampoco incluir líneas de código vacío
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

    /// <summary>Selecciona los códigos literales, sin interpretar sus caracteres como operadores.</summary>
    /// <remarks>
    /// Reemplaza la selección de conceptos y las marcas de esta instancia. Conserva los demás
    /// filtros, grupos y clave, incluido el orden FIFO. Sólo los códigos numéricos usan OR en SQL;
    /// para los demás, SetRange compara cada literal y MarkedOnly reúne las coincidencias.
    /// Las marcas son de la variable, no escrituras de líneas ni movimientos de francos.
    /// </remarks>
    internal procedure FiltrarCodigos(var Lin: Record "Línea Liquidación"; Codigos: List of [Code[20]])
    var
        Cod: Code[20];
        SoloNumericos: Boolean;
    begin
        Lin.MarkedOnly(false);
        Lin.ClearMarks();
        Lin.SetRange("Cód. Concepto");
        if Codigos.Count() = 0 then begin
            Lin.MarkedOnly(true);
            exit;
        end;

        SoloNumericos := true;
        foreach Cod in Codigos do
            if (Cod = '') or (DelChr(Cod, '=', '0123456789') <> '') then
                SoloNumericos := false;
        if SoloNumericos then begin
            Lin.SetFilter("Cód. Concepto", ConstruirFiltroNumerico(Codigos));
            exit;
        end;

        foreach Cod in Codigos do begin
            Lin.SetRange("Cód. Concepto", Cod);
            if Lin.FindSet() then
                repeat
                    Lin.Mark(true);
                until Lin.Next() = 0;
        end;
        Lin.SetRange("Cód. Concepto");
        Lin.MarkedOnly(true);
    end;

    local procedure ConstruirFiltroNumerico(Codigos: List of [Code[20]]): Text
    var
        Filtro: TextBuilder;
        Cod: Code[20];
    begin
        foreach Cod in Codigos do begin
            if Filtro.Length() > 0 then
                Filtro.Append('|');
            Filtro.Append('''' + Cod + '''');
        end;
        exit(Filtro.ToText());
    end;

    /// <summary>Valor por día de un franco, según el tipo de buque, el convenio y la categoría del lote.</summary>
    /// <remarks>
    /// Se busca en dos pasos, del más específico al más general:
    ///
    ///   1. VALOR_FRANCO_&lt;CAL|LAN&gt;_&lt;CONVENIO&gt;_&lt;CATEGORÍA&gt;   — p.ej. VALOR_FRANCO_LAN_729/15_MR05
    ///   2. VALOR_FRANCO_&lt;CONVENIO&gt;_&lt;CATEGORÍA&gt;               — el que ya existía
    ///
    /// **Las dos unidades no son la misma.** El parámetro de pesquería está en pesos del MES y hay que
    /// dividirlo por 30; el genérico está en pesos del DÍA y se usa tal cual. Es la convención con la
    /// que ya estaban cargados —VALOR_FRANCO_LAN_729/15_MR05 = 1.708.670 contra el genérico
    /// 56.955,6667, que es exactamente 1.708.670/30—, y se respeta en lugar de rehacerla para no
    /// tocar los parámetros existentes ni las vigencias que se mantienen mes a mes.
    ///
    /// El segundo paso es lo que mantiene andando todo lo cargado: sólo hace falta declarar el primero
    /// donde la pesquería cambia el valor. Sin pesquería —un lote que no se puede rastrear a ninguna
    /// marea— se va al genérico, que es el valor pleno; el descuento hay que poder justificarlo.
    /// </remarks>
    /// <summary>El par con el que se le pone precio a un franco: el de la liquidación que lo paga.</summary>
    /// <remarks>
    /// Un franco no gozado se salda como las vacaciones o el SAC: a la remuneración vigente cuando se
    /// paga, no a la de cuando se ganó. Antes cada lote se valuaba con SU categoría, y eso sólo se
    /// notaba cuando alguien bajaba de categoría: en enero de 2026 eran 5 líneas de 33, las cinco
    /// descensos, y BC pagaba 135.174,26 de más que Meta4 (03985 devengó 18 francos como MR05 y hoy es
    /// MR08: 56.955,67 contra 53.158,67 por día).
    ///
    /// Lo que SIGUE saliendo del lote es la pesquería (ver SufijoDelLote): el 30% del tangonero contra
    /// el 100% del potero depende de dónde se devengó el franco, no de dónde está hoy el tripulante.
    /// Acá cambia la categoría del precio, no de qué buque venía el franco.
    ///
    /// Si la liquidación no resuelve —no existe todavía, o vino sin par— se cae al par del lote, que
    /// es el comportamiento anterior: es preferible valuar por el lote que no valuar nada.
    /// </remarks>
    local procedure ParQuePagaElFranco(LiqActual: Code[20]; Lin: Record "Línea Liquidación"; var Convenio: Code[20]; var Categoria: Code[20])
    var
        Liq: Record "Liquidación";
    begin
        Convenio := Lin."Cód. Convenio";
        Categoria := Lin."Cód. Categoría";
        if LiqActual = '' then
            exit;
        if not Liq.Get(LiqActual) then
            exit;
        if (Liq."Cód. Convenio" = '') or (Liq."Cód. Categoría" = '') then
            exit;
        Convenio := Liq."Cód. Convenio";
        Categoria := Liq."Cód. Categoría";
    end;

    local procedure ValorFrancoDia(Sufijo: Code[10]; Convenio: Code[20]; Categoria: Code[20]; FechaPago: Date; Documento: Code[20]; Empleado: Code[20]): Decimal
    begin
        exit(ResolverValorFrancoDia(Sufijo, Convenio, Categoria, FechaPago, true, TipoDeLaLiquidacion(Documento), Empleado));
    end;

    /// <summary>El mismo precio, pero para MOSTRAR: si no hay, devuelve cero en vez de cortar.</summary>
    /// <remarks>
    /// LAS DOS PANTALLAS PREGUNTAN A PROPÓSITO POR UN PRECIO QUE PUEDE NO EXISTIR: piden el valor
    /// SIN sufijo —el "valor pleno" de la categoría— y hoy NINGUNA fila de VALOR_FRANCO está cargada
    /// sin sufijo: todas son _CAL_ o _LAN_. Con el corte de "un franco no puede valer cero" esas dos
    /// consultas rompían la página de CUALQUIER tripulante, no sólo de los casos raros:
    ///
    /// - DetallePorLote lo usa de REFERENCIA del coeficiente, que es una proporción y no un importe.
    ///   Sin referencia la proporción es 1, que es lo que ya hacía el `else`.
    /// - AcumularFrancosEmpleado (Francos por Tripulante) valúa el SALDO con él. Devuelve cero, que
    ///   es lo que mostraba antes del 6/10/2026. OJO: el importe del saldo sigue saliendo en cero,
    ///   porque el buffer agrupa por convenio+categoría y no sabe de qué buque viene cada lote, así
    ///   que no tiene sufijo que pedir. Es un defecto de esa pantalla, anterior a esto, y se arregla
    ///   agrupando también por buque —no tapando el corte del cálculo—.
    ///
    /// El corte sigue valiendo donde importa —el cálculo—, porque ahí un cero se paga y nadie lo ve.
    /// </remarks>
    local procedure ValorFrancoDiaParaMostrar(Sufijo: Code[10]; Convenio: Code[20]; Categoria: Code[20]; FechaPago: Date): Decimal
    begin
        exit(ResolverValorFrancoDia(Sufijo, Convenio, Categoria, FechaPago, false, '', ''));
    end;

    local procedure ResolverValorFrancoDia(Sufijo: Code[10]; Convenio: Code[20]; Categoria: Code[20]; FechaPago: Date; CortarSiFalta: Boolean; TipoLiq: Code[20]; Empleado: Code[20]): Decimal
    var
        Valor: Decimal;
    begin
        if (Convenio = '') or (Categoria = '') then exit(0);
        CargarConfigValuacion();
        if FParamValor = '' then
            Error(ErrSinParametroValor, FConceptoConsumo);

        Valor := ValorDeFormula(Sufijo, Convenio, Categoria, FechaPago, TipoLiq, Empleado);
        // UN FRANCO NO PUEDE VALER CERO. Hasta acá, no encontrar el parámetro devolvía cero y el
        // franco se pagaba en nada, sin aviso: el importe salía bajo y cuadraba con la cantidad de
        // días, así que ningún control de importe lo veía. Es más barato cortar y nombrar el lote
        // que no tiene precio.
        //
        // ...PERO SÓLO DONDE EL CERO SE PAGA. Ver ValorFrancoDiaParaMostrar: las dos pantallas
        // preguntan a propósito por un precio que puede no existir, y ahí cortar es peor que un cero.
        if Valor = 0 then begin
            if CortarSiFalta then
                Error(ErrSinPrecioFranco, FParamValor, Sufijo, Convenio, Categoria, FechaPago);
            exit(0);
        end;
        exit(AplicarDivisor(Valor));
    end;

    /// <summary>El valor mensual de UN franco, evaluando la fórmula del "Parámetro del valor" con el contexto de ese lote.</summary>
    /// <remarks>
    /// EL CAMPO ES UNA FÓRMULA. Sus identificadores son nombres de parámetro y se resuelven para el
    /// par del lote: primero con el sufijo de pesquería (NOMBRE_CAL_175/75_OF02) y si no hay, sin él
    /// (NOMBRE_175/75_OF02). Un nombre solo (VALOR_FRANCO) vale lo de siempre; una expresión
    /// (IFZERO(VALOR_FRANCO_EMP, VALOR_FRANCO)) deja que el convenio decida con qué valor de empresa
    /// se paga. Para distinguir el tipo de liquidación se compara TIPO_LIQ por código, como en
    /// cualquier fórmula: IF(TIPO_LIQ = 'LIQ_FINAL', IFZERO(VALOR_FRANCO_EMP, VALOR_FRANCO), VALOR_FRANCO).
    ///
    /// No se resuelve con el contexto de la liquidación porque el precio es del LOTE, no del empleado:
    /// cada lote trae su convenio, su categoría y su pesquería (ver ValorParametro).
    ///
    /// Se recuerda por lote-par-fecha-tipo: un FIFO largo pide el mismo precio decenas de veces.
    /// </remarks>
    local procedure ValorDeFormula(Sufijo: Code[10]; Convenio: Code[20]; Categoria: Code[20]; FechaPago: Date; TipoLiq: Code[20]; Empleado: Code[20]): Decimal
    var
        Ctx: Dictionary of [Text, Decimal];
        Codigos: Dictionary of [Text, Text];
        Clave: Text;
        Nombre: Text;
        NombreTipoLiq: Text;
        Valor: Decimal;
    begin
        Clave := StrSubstNo('%1|%2|%3|%4|%5|%6', Sufijo, Convenio, Categoria, Format(FechaPago, 0, 9), TipoLiq, Empleado);
        if FCacheValor.Get(Clave, Valor) then
            exit(Valor);

        foreach Nombre in FIdentificadores do
            Ctx.Add(Nombre, ValorParametroDelLote(Nombre, Sufijo, Convenio, Categoria, FechaPago, Empleado));

        // La comparación por código necesita el nombre configurado de TIPO_LIQ en el contexto y el
        // código actual en los códigos de atributo; el valor numérico no se usa.
        NombreTipoLiq := NombreVariableTipoLiq();
        if NombreTipoLiq <> '' then begin
            Ctx.Add(NombreTipoLiq, 0);
            Codigos.Add(NombreTipoLiq, TipoLiq);
        end;

        FEvaluador.Init(Ctx, FechaPago);
        FEvaluador.SetCodigosAtributos(Codigos);
        if not FEvaluador.TryEvalFormula(FParamValor, Valor) then
            Error(ErrFormulaValor, FConceptoConsumo, FParamValor, GetLastErrorText());
        FCacheValor.Add(Clave, Valor);
        exit(Valor);
    end;

    local procedure ValorParametroDelLote(Nombre: Text; Sufijo: Code[10]; Convenio: Code[20]; Categoria: Code[20]; FechaPago: Date; Empleado: Code[20]): Decimal
    var
        Valor: Decimal;
    begin
        // EL ACUERDO PERSONAL MANDA: un valor cargado para el empleado (NOMBRE_<empleado>) le gana al del par del lote, igual
        // que en el resto de los parámetros. Es cómo se representa una decisión puntual, por ejemplo el precio que Meta4 cargó
        // como incidencia en las finales del 23/4/2026. Hace falta que el parámetro tenga 'Sufijo Empleado'.
        if Empleado <> '' then begin
            Valor := ValorParametro(Nombre + '_' + Empleado, FechaPago);
            if Valor <> 0 then
                exit(Valor);
        end;
        if Sufijo <> '' then begin
            Valor := ValorParametro(Nombre + '_' + Sufijo + '_' + Convenio + '_' + Categoria, FechaPago);
            if Valor <> 0 then
                exit(Valor);
        end;
        exit(ValorParametro(Nombre + '_' + Convenio + '_' + Categoria, FechaPago));
    end;

    // El nombre de la variable TIPO_LIQ es configurable: se busca por su Cód. Cálculo, como hace el evaluador.
    local procedure NombreVariableTipoLiq(): Text
    var
        VarSis: Record "Variable Sistema Liq.";
    begin
        VarSis.SetRange("Cód. Cálculo", 'TIPO_LIQ');
        if VarSis.FindFirst() then
            exit(VarSis."Nombre Variable");
        exit('');
    end;

    // El tipo de liquidación del documento, recordado: se pide por cada lote de cada pasada.
    local procedure TipoDeLaLiquidacion(Documento: Code[20]): Code[20]
    var
        Liq: Record "Liquidación";
        Tipo: Code[20];
    begin
        if Documento = '' then
            exit('');
        if FTipoPorDocumento.Get(Documento, Tipo) then
            exit(Tipo);
        if Liq.Get(Documento) then
            Tipo := Liq."Cód. Tipo Liq.";
        FTipoPorDocumento.Set(Documento, Tipo);
        exit(Tipo);
    end;

    /// <summary>
    /// Los nombres de parámetro que usa la fórmula del valor: identificadores que no son funciones,
    /// palabras reservadas, la variable TIPO_LIQ ni texto entre comillas.
    /// </summary>
    procedure IdentificadoresDeValor(Formula: Text; var Nombres: List of [Text])
    var
        Texto: Text;
        Nombre: Text;
        NombreTipoLiq: Text;
        Pos: Integer;
        Largo: Integer;
        Inicio: Integer;
        Siguiente: Integer;
        Letra: Text;
    begin
        Clear(Nombres);
        Texto := Formula.ToUpper();
        NombreTipoLiq := NombreVariableTipoLiq().ToUpper();
        Largo := StrLen(Texto);
        Pos := 1;
        while Pos <= Largo do begin
            Letra := CopyStr(Texto, Pos, 1);
            if Letra = '''' then begin
                // Texto entre comillas: no es un nombre.
                Pos += 1;
                while (Pos <= Largo) and (CopyStr(Texto, Pos, 1) <> '''') do
                    Pos += 1;
                Pos += 1;
            end else
                if EsInicioDeNombre(Letra) then begin
                    Inicio := Pos;
                    while (Pos <= Largo) and EsLetraDeNombre(CopyStr(Texto, Pos, 1)) do
                        Pos += 1;
                    Nombre := CopyStr(Texto, Inicio, Pos - Inicio);
                    Siguiente := Pos;
                    while (Siguiente <= Largo) and (CopyStr(Texto, Siguiente, 1) = ' ') do
                        Siguiente += 1;
                    if not ((Siguiente <= Largo) and (CopyStr(Texto, Siguiente, 1) = '(')) then
                        if not (Nombre in ['AND', 'OR', 'NOT', NombreTipoLiq]) then
                            if not Nombres.Contains(Nombre) then
                                Nombres.Add(Nombre);
                end else
                    Pos += 1;
        end;
    end;

    local procedure EsInicioDeNombre(Letra: Text): Boolean
    begin
        exit((Letra = '_') or ((Letra >= 'A') and (Letra <= 'Z')));
    end;

    local procedure EsLetraDeNombre(Letra: Text): Boolean
    begin
        exit(EsInicioDeNombre(Letra) or ((Letra >= '0') and (Letra <= '9')));
    end;

    /// <summary>El valor del parámetro está en un mes comercial; acá se lo pasa a día.</summary>
    /// <remarks>
    /// El divisor es fijo y no los días del mes: con los días reales el mismo franco valdría distinto
    /// en febrero que en marzo.
    ///
    /// SE APLICA EN LAS DOS RAMAS. Hasta el 6/10/2026 sólo dividía la del sufijo, y como no existe
    /// ninguna fila `VALOR_FRANCO_&lt;sufijo&gt;_&lt;convenio&gt;_&lt;categoría&gt;` la rama que dividía NUNCA
    /// corría: todo salía por el fallback sin dividir, así que el "Divisor del valor" del concepto
    /// era configuración muerta y los valores estaban cargados por día para compensar. Al unificar
    /// el parámetro en mensual —que es como lo declara el propio Divisor del valor y como está
    /// escrito el acuerdo de los oficiales— las dos ramas tienen que dividir o el franco sale
    /// treinta veces más caro.
    /// </remarks>
    local procedure AplicarDivisor(Valor: Decimal): Decimal
    begin
        if FDivisorValor > 0 then
            exit(Valor / FDivisorValor);
        exit(Valor);
    end;

    /// <summary>La moneda en que están cargados los precios del franco, o '' si están en pesos.</summary>
    /// <remarks>
    /// ES PARA EL CAMINO DE LAS PÁGINAS. La Fuente de Datos `TC_COMPRADOR` filtra la cotización por
    /// `{MONEDA}`, y ese token lo llena `LoadParametros`, que sólo corre dentro de un cálculo. Una
    /// página que reconstruye el desglose no lo tiene, y con el filtro vacío la fuente devuelve la
    /// cotización de CUALQUIER divisa —un número válido y ajeno— o cero. Así que la moneda se
    /// pregunta acá, que es donde se sabe de qué parámetro sale el precio, en vez de adivinarla.
    ///
    /// Busca con comodín porque las variantes por pesquería son BASES DISTINTAS, no sufijos de una
    /// misma: `VALOR_FRANCO_CAL_175/75_OF04` no cuelga de `VALOR_FRANCO`. Alcanza la primera fila en
    /// divisa: el token admite una sola moneda por liquidación, igual que `FMoneda` en el contexto.
    /// </remarks>
    procedure MonedaDelPrecio(FechaPago: Date): Code[10]
    var
        ParamVig: Record "Parámetro Vigente";
        Nombre: Text;
    begin
        EstablecerFechaConfig(FechaPago);
        CargarConfigValuacion();
        if FParamValor = '' then
            exit('');
        ParamVig.SetFilter("Vigencia Desde", '<=%1', FechaPago);
        ParamVig.SetFilter(Moneda, '<>%1', '');
        foreach Nombre in FIdentificadores do begin
            ParamVig.SetFilter("Cód. Parámetro", Nombre + '*');
            if ParamVig.FindFirst() then
                exit(ParamVig.Moneda);
        end;
        exit('');
    end;

    /// <summary>
    /// El contexto le presta sus cotizaciones al ledger antes de usarlo.
    /// </summary>
    /// <remarks>
    /// POR QUÉ HACE FALTA. `ValorParametro` lee `Parámetro Vigente` DIRECTO, sin pasar por el
    /// contexto, porque el precio se busca con el convenio y la categoría SELLADOS EN CADA LOTE y no
    /// con el par de la liquidación —es lo que hace al franco no fungible—. Esa lectura se saltea
    /// `ConvertirParametrosEnDivisa` (`Cod50016`), así que una fila en divisa se usaría como si
    /// fueran pesos: un número válido, mil cuatrocientas veces más chico, que ningún control de
    /// importe detecta.
    ///
    /// Es la única dirección posible: el contexto ya es dueño de este codeunit, así que el ledger no
    /// puede llamarlo de vuelta sin armar un ciclo.
    ///
    /// Se copian sólo las variables `TC_*` y no el contexto entero, que son cientos de entradas por
    /// liquidación. Si alguna vez una cotización se llama de otra forma, la conversión corta con
    /// `ErrFrancoTCInexistente` en vez de pagar en divisa.
    /// </remarks>
    procedure PublicarTiposCambio(var Ctx: Dictionary of [Text, Decimal])
    var
        Nombre: Text;
    begin
        Clear(FCtxTC);
        foreach Nombre in Ctx.Keys() do
            if Nombre.StartsWith('TC_') then
                FCtxTC.Add(Nombre, Ctx.Get(Nombre));
    end;

    local procedure ValorParametro(CodigoParametro: Text; FechaPago: Date): Decimal
    var
        ParamVig: Record "Parámetro Vigente";
        Cod: Code[50];
    begin
        Cod := CopyStr(CodigoParametro, 1, MaxStrLen(Cod));
        ParamVig.SetCurrentKey("Cód. Parámetro", "Vigencia Desde");
        ParamVig.SetRange("Cód. Parámetro", Cod);
        ParamVig.SetFilter("Vigencia Desde", '<=%1', FechaPago);
        if ParamVig.FindLast() then
            exit(ParamVig.Valor * TipoCambioDeLaFila(ParamVig));
        exit(0);
    end;

    /// <summary>Cuánto hay que multiplicar el valor de esa fila para que quede en pesos.</summary>
    /// <remarks>
    /// Devuelve 1 cuando la fila ya está en pesos o cuando la llave de paso de Config. RRHH está
    /// apagada, que es lo que vuelve al comportamiento viejo sin publicar. Los dos casos que no
    /// pueden convertir CORTAN, por el mismo motivo que cortan en `Cod50016`: dejar el importe en
    /// divisa es la peor de las opciones y convertir por 1 es lo mismo.
    /// </remarks>
    local procedure TipoCambioDeLaFila(ParamVig: Record "Parámetro Vigente"): Decimal
    var
        HRSetup: Record "Human Resources Setup";
        TipoCambio: Decimal;
    begin
        if ParamVig.Moneda = '' then
            exit(1);
        if not HRSetup.Get() then
            exit(1);
        if not HRSetup."Convertir Param. por TC" then
            exit(1);

        if ParamVig."Cód. Variable TC" = '' then
            Error(ErrFrancoSinVariableTC, ParamVig."Cód. Parámetro", ParamVig.Moneda);
        if not FCtxTC.ContainsKey(ParamVig."Cód. Variable TC") then
            Error(ErrFrancoTCInexistente, ParamVig."Cód. Variable TC", ParamVig."Cód. Parámetro");
        TipoCambio := FCtxTC.Get(ParamVig."Cód. Variable TC");
        if TipoCambio <= 0 then
            Error(ErrFrancoTCEnCero, ParamVig."Cód. Variable TC", ParamVig."Cód. Parámetro");
        exit(TipoCambio);
    end;
}
