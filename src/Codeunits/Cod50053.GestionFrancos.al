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
        FCfgCargada: Boolean;
        FParamValor: Code[30];
        FTipoAtrPrecio: Code[20];
        FDivisorValor: Integer;
        FConceptoConsumo: Code[20];
        FCtxTC: Dictionary of [Text, Decimal];
        ErrSinParametroValor: Label 'El concepto %1 paga francos pero no tiene cargado "Parámetro del valor", así que el motor no sabe de dónde sacar el precio del franco.\\El precio de un franco NO sale de la fórmula del concepto —que devuelve días—: lo pone el motor, con el convenio y la categoría de cada lote.\\En la ficha del concepto, cargá "Parámetro del valor" (por ejemplo VALOR_FRANCO). Si además el precio depende de dónde se devengó el franco, cargá "Atributo que afina el precio" y "Divisor del valor".', Comment = '%1 = código del concepto de consumo de francos';
        ErrSinConceptoConsumo: Label 'No hay ningún concepto con Rol Franco = Consumo, así que no se puede valuar un pago de francos.';
        ErrSinPrecioFranco: Label 'No hay precio para un franco de %3 / %4 al %5, así que valdría cero.\\El motor buscó %1_%2_%3_%4 —por pesquería— y después %1_%3_%4, y ninguno tiene un valor vigente a esa fecha.\\Cargá el valor que falte en el parámetro %1.', Comment = '%1 = parámetro base; %2 = sufijo de pesquería; %3 = convenio del lote; %4 = categoría del lote; %5 = fecha de pago';
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
                Buffer."Valor Franco" := ValorFrancoDia('', Buffer."Cód. Convenio", Buffer."Cód. Categoría", Fecha);
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
        ConvPago: Code[20];
        CatPago: Code[20];
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

                // La PESQUERÍA es del lote: un franco ganado en un tangonero se paga al 30% aunque hoy
                // el tripulante esté en un potero. Sin atributo cargado vale 1 y esto se comporta como
                // antes. La CATEGORÍA, en cambio, es la de la liquidación que paga (ver
                // ParQuePagaElFranco).
                ParQuePagaElFranco(LiqActual, Lin, ConvPago, CatPago);
                ValorDia := ValorFrancoDia(SufijoDelLote(Lin), ConvPago, CatPago, FechaPago);
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
        ConvPago: Code[20];
        CatPago: Code[20];
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
                            Tomar * ValorFrancoDia(SufijoDelLote(Lin), ConvPago, CatPago, FechaPago),
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
        Buffer.Reset();
        Buffer.DeleteAll();
        if DiasSolicitados <= 0 then
            exit;

        Saltar := TotalConsumido(EmployeeNo, LiqActual);
        Restantes := DiasSolicitados;

        FiltrarLotes(Lin, EmployeeNo, LiqActual);
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
                    Buffer."Valor Franco" := ValorFrancoDia(Buffer."Tipo Buque", ConvPago, CatPago, FechaPago);
                    // El coeficiente ya no multiplica nada: el valor viene resuelto por la terna. Se
                    // muestra igual, como la proporción contra el valor pleno de la categoría, porque
                    // es la pregunta que se hace quien mira el recibo — "¿por qué éste cobra menos?".
                    ValorPleno := ValorFrancoDia('', ConvPago, CatPago, FechaPago);
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
        if not Concepto.FindSet() then
            Error(ErrSinConceptoConsumo);
        FConceptoConsumo := Concepto.Código;
        repeat
            if Concepto."Cód. Parámetro Valor" <> '' then begin
                FConceptoConsumo := Concepto.Código;
                FParamValor := Concepto."Cód. Parámetro Valor";
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

    local procedure ValorFrancoDia(Sufijo: Code[10]; Convenio: Code[20]; Categoria: Code[20]; FechaPago: Date): Decimal
    var
        Valor: Decimal;
    begin
        if (Convenio = '') or (Categoria = '') then exit(0);
        CargarConfigValuacion();
        if FParamValor = '' then
            Error(ErrSinParametroValor, FConceptoConsumo);

        if Sufijo <> '' then begin
            Valor := ValorParametro(FParamValor + '_' + Sufijo + '_' + Convenio + '_' + Categoria, FechaPago);
            if Valor <> 0 then
                exit(AplicarDivisor(Valor));
        end;
        Valor := ValorParametro(FParamValor + '_' + Convenio + '_' + Categoria, FechaPago);
        // UN FRANCO NO PUEDE VALER CERO. Hasta acá, no encontrar el parámetro devolvía cero y el
        // franco se pagaba en nada, sin aviso: el importe salía bajo y cuadraba con la cantidad de
        // días, así que ningún control de importe lo veía. Es más barato cortar y nombrar el lote
        // que no tiene precio.
        if Valor = 0 then
            Error(ErrSinPrecioFranco, FParamValor, Sufijo, Convenio, Categoria, FechaPago);
        exit(AplicarDivisor(Valor));
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
    begin
        CargarConfigValuacion();
        if FParamValor = '' then
            exit('');
        ParamVig.SetFilter("Cód. Parámetro", FParamValor + '*');
        ParamVig.SetFilter("Vigencia Desde", '<=%1', FechaPago);
        ParamVig.SetFilter(Moneda, '<>%1', '');
        if ParamVig.FindFirst() then
            exit(ParamVig.Moneda);
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
