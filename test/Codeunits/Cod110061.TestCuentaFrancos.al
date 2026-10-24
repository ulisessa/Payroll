namespace UAS.Payroll;

codeunit 110061 "Test Cuenta Francos"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ComponentesCompartenDiasYReversionEsIdempotente()
    var
        Cuenta: Codeunit "Cuenta Corriente Francos";
        Cab: Record "Liquidación";
        Lin: Record "Línea Liquidación";
        Concepto: Record "Concepto Liquidación";
        Mov: Record "Movimiento Franco Liq.";
        Credito: Record "Movimiento Franco Liq.";
        Empleado: Code[20];
        Seleccion: Guid;
    begin
        Empleado := NuevoCodigo();
        PrepararCuenta(Empleado, Credito);
        Concepto.Código := NuevoCodigo();
        Concepto."Vigencia Desde" := Today();
        Concepto."Fuente Matriz" := 'FRANCOS_FIFO';
        Concepto.Insert(false);
        Cab."No." := NuevoCodigo();
        Cab."No. Empleado" := Empleado;
        Seleccion := CreateGuid();
        Lin."No. Liquidación" := Cab."No.";
        Lin."No. Empleado" := Empleado;
        Lin."Cód. Concepto" := Concepto.Código;
        Lin."Vigencia Concepto" := Today();
        Lin."Fecha Liquidación" := Today();
        Lin."No. Lote Franco" := Credito."No. Lote";
        Lin."Id. Selección Francos" := Seleccion;
        Lin.Cantidad := 3;
        Lin."No. Línea" := 1;
        Lin.Insert(false);
        Lin."No. Línea" := 2;
        Lin.Insert(false);
        Cuenta.RegistrarLiquidacion(Cab);
        Cuenta.RegistrarLiquidacion(Cab);
        Comprobar(Cuenta.SaldoLote(Credito."No. Lote", Today()) = 7, 'Dos componentes deben consumir tres días una sola vez.');
        Mov.SetRange("No. Liquidación", Cab."No.");
        Mov.SetRange(Tipo, Mov.Tipo::Consumo);
        Comprobar(Mov.Count() = 1, 'Asentar otra vez el mismo cálculo no duplica movimientos.');
        Cuenta.Revertir(Cab."No.");
        Cuenta.Revertir(Cab."No.");
        Comprobar(Cuenta.SaldoLote(Credito."No. Lote", Today()) = 10, StrSubstNo('Reabrir dos veces debe devolver tres días; saldo obtenido %1.', Cuenta.SaldoLote(Credito."No. Lote", Today())));
        Cuenta.RegistrarLiquidacion(Cab);
        Comprobar(Cuenta.SaldoLote(Credito."No. Lote", Today()) = 7, 'Recalcular después de reabrir debe registrar una nueva aplicación sin duplicar días.');
        Cuenta.Revertir(Cab."No.");
        Cuenta.Revertir(Credito."No. Liquidación");
        Comprobar(Cuenta.SaldoLote(Credito."No. Lote", Today()) = 0, 'Una vez revertido el pago, se puede revertir el devengo.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SaldoAlCorteNoIncluyeDevengosNiConsumosFuturos()
    var
        Cuenta: Codeunit "Cuenta Corriente Francos";
        Francos: Codeunit "Gestión Francos";
        Credito: Record "Movimiento Franco Liq.";
        Futuro: Record "Movimiento Franco Liq.";
        Consumo: Record "Movimiento Franco Liq.";
        Filas: Record "Lote Franco Buffer Liq." temporary;
        Empleado: Code[20];
        Corte: Date;
    begin
        // Ejecutar exclusivamente en una empresa de pruebas aislada.
        Empleado := NuevoCodigo();
        Corte := DMY2Date(18, 2, 2026);
        PrepararCuenta(Empleado, Credito);
        Credito.Cantidad := 17;
        Credito."Fecha Devengamiento" := DMY2Date(31, 1, 2026);
        Credito.Modify(false);
        Futuro := Credito;
        Futuro."No. Movimiento" := Credito."No. Movimiento" + 1;
        Futuro."No. Lote" := Futuro."No. Movimiento";
        Futuro."No. Liquidación" := NuevoCodigo();
        Futuro."Fecha Devengamiento" := DMY2Date(28, 2, 2026);
        Futuro.Cantidad := 5;
        Futuro.Insert(false);

        Comprobar(Francos.SaldoFrancos(Empleado, '', Corte) = 17, 'El cierre no puede pedir los cinco días del devengado posterior.');
        Comprobar(Francos.SaldoFrancos(Empleado, '') = 22, 'La consulta global conserva los dos lotes.');
        Comprobar(Francos.SaldoFrancos(Empleado, '', Futuro."Fecha Devengamiento") = 22, 'El lote entra el día exacto de su devengo.');
        Comprobar(Francos.SaldoFrancos(Empleado, Futuro."No. Liquidación", Futuro."Fecha Devengamiento") = 17, 'El saldo excluye el documento actual incluso en la fecha de corte.');
        Cuenta.Matriz(Empleado, Corte, '', Francos.SaldoFrancos(Empleado, '', Corte), false, Filas);
        Comprobar(Filas.Count() = 1, 'La matriz histórica sólo selecciona el lote anterior.');
        Filas.FindFirst();
        Comprobar(Filas."Días Tomados" = 17, 'Saldo y matriz deben tener el mismo corte.');

        Consumo := Credito;
        Consumo."No. Movimiento" := Futuro."No. Movimiento" + 1;
        Consumo."No. Liquidación" := NuevoCodigo();
        Consumo.Tipo := Consumo.Tipo::Consumo;
        Consumo."Fecha Devengamiento" := DMY2Date(20, 2, 2026);
        Consumo.Cantidad := -4;
        Consumo.Insert(false);
        Comprobar(Francos.SaldoFrancos(Empleado, '', Corte) = 17, 'Un consumo futuro tampoco reduce el saldo histórico.');
        Comprobar(Francos.SaldoFrancos(Empleado, '', Futuro."Fecha Devengamiento") = 18, 'Al alcanzar el corte posterior deben descontarse los consumos ocurridos.');
        Cuenta.Revertir(Consumo."No. Liquidación");
        Comprobar(Francos.SaldoFrancos(Empleado, '', Corte) = 17, 'Revertir el consumo posterior conserva el saldo histórico.');
        Comprobar(Francos.SaldoFrancos(Empleado, '') = 22, 'El contramovimiento devuelve los días sin duplicar devengos.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure SaldoAlCorteSinCuentaRespetaFechasYDocumento()
    var
        Francos: Codeunit "Gestión Francos";
        Concepto: Record "Concepto Liquidación";
        Lin: Record "Línea Liquidación";
        Empleado: Code[20];
        DocumentoFuturo: Code[20];
        Corte: Date;
    begin
        // Camino anterior a inicializar la cuenta; sólo en una empresa de pruebas aislada.
        Empleado := NuevoCodigo();
        Corte := DMY2Date(18, 2, 2026);
        Concepto.Código := NuevoCodigo();
        Concepto."Vigencia Desde" := DMY2Date(1, 1, 2026);
        Concepto."Rol Franco" := Concepto."Rol Franco"::Devengo;
        Concepto.Insert(false);
        Lin."No. Liquidación" := NuevoCodigo();
        Lin."No. Línea" := 1;
        Lin."No. Empleado" := Empleado;
        Lin."Cód. Concepto" := Concepto.Código;
        Lin."Fecha Liquidación" := DMY2Date(31, 1, 2026);
        Lin.Cantidad := 17;
        Lin.Insert(false);
        DocumentoFuturo := NuevoCodigo();
        Lin."No. Liquidación" := DocumentoFuturo;
        Lin."Fecha Liquidación" := DMY2Date(28, 2, 2026);
        Lin.Cantidad := 5;
        Lin.Insert(false);
        Comprobar(Francos.SaldoFrancos(Empleado, '', Corte) = 17, 'El saldo anterior a la cuenta también excluye lotes futuros.');
        Comprobar(Francos.SaldoFrancos(Empleado, '') = 22, 'La consulta global anterior a la cuenta conserva todos los lotes.');
        Comprobar(Francos.SaldoFrancos(Empleado, DocumentoFuturo, DMY2Date(28, 2, 2026)) = 17, 'La exclusión del propio documento se conserva sin cuenta activa.');

        Concepto.Init();
        Concepto.Código := NuevoCodigo();
        Concepto."Vigencia Desde" := DMY2Date(1, 1, 2026);
        Concepto."Rol Franco" := Concepto."Rol Franco"::Consumo;
        Concepto.Insert(false);
        Lin."No. Liquidación" := NuevoCodigo();
        Lin."Cód. Concepto" := Concepto.Código;
        Lin."Fecha Liquidación" := DMY2Date(20, 2, 2026);
        Lin.Cantidad := 4;
        Lin.Insert(false);
        Comprobar(Francos.SaldoFrancos(Empleado, '', Corte) = 17, 'El consumo futuro no reduce el saldo anterior a la cuenta.');
        Comprobar(Francos.SaldoFrancos(Empleado, '', DMY2Date(28, 2, 2026)) = 18, 'El consumo se resta al llegar a su fecha.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure MatrizSeleccionaParcialSinEscribirConsumos()
    var
        Cuenta: Codeunit "Cuenta Corriente Francos";
        Credito: Record "Movimiento Franco Liq.";
        Filas: Record "Lote Franco Buffer Liq." temporary;
        Empleado: Code[20];
    begin
        Empleado := NuevoCodigo();
        PrepararCuenta(Empleado, Credito);
        Cuenta.Matriz(Empleado, Today(), '', 4, false, Filas);
        Filas.FindFirst();
        Comprobar(Filas."Días Disponibles" = 10, 'La matriz debe mostrar el saldo completo del lote.');
        Comprobar(Filas."Días Tomados" = 4, 'La selección debe poder tomar una parte del lote.');
        Comprobar(Cuenta.SaldoLote(Credito."No. Lote", Today()) = 10, 'Armar una matriz no debe consumir días.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure DevengoUtilizadoBloqueaReversion()
    var
        Cuenta: Codeunit "Cuenta Corriente Francos";
        Credito: Record "Movimiento Franco Liq.";
        Cab: Record "Liquidación";
        Concepto: Record "Concepto Liquidación";
        Lin: Record "Línea Liquidación";
        Empleado: Code[20];
    begin
        Empleado := NuevoCodigo();
        PrepararCuenta(Empleado, Credito);
        Concepto.Código := NuevoCodigo();
        Concepto."Vigencia Desde" := Today();
        Concepto."Fuente Matriz" := 'FRANCOS_FIFO';
        Concepto.Insert(false);
        Cab."No." := NuevoCodigo();
        Cab."No. Empleado" := Empleado;
        Lin."No. Liquidación" := Cab."No.";
        Lin."No. Línea" := 1;
        Lin."No. Empleado" := Empleado;
        Lin."Cód. Concepto" := Concepto.Código;
        Lin."Vigencia Concepto" := Today();
        Lin."Fecha Liquidación" := Today();
        Lin."No. Lote Franco" := Credito."No. Lote";
        Lin."Id. Selección Francos" := CreateGuid();
        Lin.Cantidad := 3;
        Lin.Insert(false);
        Cuenta.RegistrarLiquidacion(Cab);
        // El error esperado va al final: asserterror revierte el ámbito de escritura del test.
        asserterror Cuenta.Revertir(Credito."No. Liquidación");
        Comprobar(GetLastErrorText().Contains('consumido'), 'El bloqueo debe identificar la liquidación dependiente.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure EliminarDocumentoConservaCuentaCorriente()
    var
        Cuenta: Codeunit "Cuenta Corriente Francos";
        Credito: Record "Movimiento Franco Liq.";
        Cab: Record "Liquidación";
        Concepto: Record "Concepto Liquidación";
        Lin: Record "Línea Liquidación";
        Mov: Record "Movimiento Franco Liq.";
        Empleado: Code[20];
        Documento: Code[20];
    begin
        Empleado := NuevoCodigo();
        PrepararCuenta(Empleado, Credito);
        Concepto.Código := NuevoCodigo();
        Concepto."Vigencia Desde" := Today();
        Concepto."Fuente Matriz" := 'FRANCOS_FIFO';
        Concepto.Insert(false);
        Cab."No." := NuevoCodigo();
        Documento := Cab."No.";
        Cab."No. Empleado" := Empleado;
        Cab.Insert(false);
        Lin."No. Liquidación" := Documento;
        Lin."No. Línea" := 1;
        Lin."No. Empleado" := Empleado;
        Lin."Cód. Concepto" := Concepto.Código;
        Lin."Vigencia Concepto" := Today();
        Lin."Fecha Liquidación" := Today();
        Lin."No. Lote Franco" := Credito."No. Lote";
        Lin."Id. Selección Francos" := CreateGuid();
        Lin.Cantidad := 3;
        Lin.Insert(false);
        Cuenta.RegistrarLiquidacion(Cab);
        Cab.Delete(true);
        Comprobar(not Cab.Get(Documento), 'La cabecera debe haberse eliminado.');
        Lin.SetRange("No. Liquidación", Documento);
        Comprobar(Lin.IsEmpty(), 'No deben quedar líneas del documento eliminado.');
        Comprobar(Cuenta.SaldoLote(Credito."No. Lote", Today()) = 10, 'Eliminar debe devolver los días.');
        Mov.SetRange("No. Liquidación", Documento);
        Comprobar(Mov.Count() = 2, 'La cuenta debe conservar consumo y contramovimiento aun sin cabecera.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure HistoriaEneroRespaldaSusConsumos()
    var
        Migracion: Codeunit "Migrar Matriz Francos";
    begin
        if CompanyName() <> 'ArbuTest' then Error('La prueba de integración sólo corresponde a ArbuTest.');
        Migracion.ReconstruirPeriodo('202601');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure Matriz1063ConservaRecibosEnero()
    var
        Migracion: Codeunit "Migrar Matriz Francos";
        Francos: Codeunit "Gestión Francos";
        Cadena: Codeunit "Recálculo En Cadena Liq.";
        Lin: Record "Línea Liquidación";
        Cab: Record "Liquidación";
        Posterior: Record "Liquidación";
        Vigente: Record "Concepto Liquidación";
        Documentos: List of [Code[20]];
        EmpleadosProbados: List of [Code[20]];
        Documento: Code[20];
        Antes: Dictionary of [Text, Decimal];
        Despues: Dictionary of [Text, Decimal];
        Clave: Text;
        ValorAntes: Decimal;
        ValorDespues: Decimal;
        SaldoAntes: Decimal;
        Haberes: Decimal;
        Descuentos: Decimal;
        Contribuciones: Decimal;
        Neto: Decimal;
        DiasAntes: Decimal;
        Probados: Integer;
    begin
        if CompanyName() <> 'ArbuTest' then Error('La prueba de integración sólo corresponde a ArbuTest.');
        Lin.SetRange("Cód. Período", '202601');
        Lin.SetRange("Cód. Concepto", '1063');
        Lin.SetFilter(Cantidad, '>0');
        if Lin.FindSet() then repeat
            if not Documentos.Contains(Lin."No. Liquidación") then Documentos.Add(Lin."No. Liquidación");
        until Lin.Next() = 0;
        Cab.SetRange("Cód. Período", '202601');
        Cab.SetRange("Cód. Tipo Liq.", 'LIQ_FINAL');
        Cab.SetRange(Estado, Cab.Estado::Calculada);
        if Cab.FindSet() then repeat
            if not Documentos.Contains(Cab."No.") then Documentos.Add(Cab."No.");
        until Cab.Next() = 0;
        Cab.Reset();
        // La nueva vigencia y todos los recibos se revierten al terminar el test.
        Vigente.SetRange(Código, '1063');
        Vigente.SetFilter("Vigencia Desde", '<=%1', DMY2Date(31, 1, 2026));
        Comprobar(Vigente.FindLast(), 'Debe existir 1063.');
        if Vigente."Fuente Matriz" <> 'FRANCOS_FIFO' then Migracion.Convertir('2026-01-04');
        foreach Documento in Documentos do begin
            Cab.Get(Documento);
            if (not Cadena.PrimeraPosterior(Cab, Posterior)) and (not EmpleadosProbados.Contains(Cab."No. Empleado")) then begin
                // Se compara un mes íntegro repetido: recalcular un recibo aislado lee los topes
                // ya usados por los demás y no es una operación equivalente.
                Cadena.EjecutarMesEmpleado(Documento);
                Cab.Get(Documento);
                EmpleadosProbados.Add(Cab."No. Empleado");
                TotalesPorConcepto(Documento, Antes);
                DiasAntes := 0;
                foreach Clave in Antes.Keys() do
                    if Clave.StartsWith('Q|1063|') then begin
                        Antes.Get(Clave, ValorAntes);
                        DiasAntes += ValorAntes;
                    end;
                Clear(Francos);
                SaldoAntes := Francos.SaldoFrancos(Cab."No. Empleado", '');
                Haberes := Cab."Total Haberes";
                Descuentos := Cab."Total Descuentos";
                Contribuciones := Cab."Total Contribuciones";
                Neto := Cab."Neto a Pagar";
                Cadena.EjecutarMesEmpleado(Documento);
                Cab.Get(Documento);
                TotalesPorConcepto(Documento, Despues);
                foreach Clave in Antes.Keys() do begin
                    Antes.Get(Clave, ValorAntes);
                    ValorDespues := 0;
                    if not Despues.Get(Clave, ValorDespues) then ValorDespues := 0;
                    if not Clave.StartsWith('Q|') then begin
                        ValorAntes := Round(ValorAntes, 0.01);
                        ValorDespues := Round(ValorDespues, 0.01);
                    end;
                    Comprobar(ValorAntes = ValorDespues, StrSubstNo('Cambió %1 en %2: anterior %3, matriz %4.', Clave, Documento, ValorAntes, ValorDespues));
                end;
                foreach Clave in Despues.Keys() do
                    if not Antes.ContainsKey(Clave) then begin
                        Despues.Get(Clave, ValorDespues);
                        Comprobar(ValorDespues = 0, StrSubstNo('La matriz agregó una base o importe: %1.', Clave));
                    end;
                Comprobar((Haberes = Cab."Total Haberes") and (Descuentos = Cab."Total Descuentos") and
                    (Contribuciones = Cab."Total Contribuciones") and (Neto = Cab."Neto a Pagar"), 'Los totales de cabecera deben conservarse.');
                Clear(Francos);
                Comprobar(SaldoAntes = Francos.SaldoFrancos(Cab."No. Empleado", ''), 'La matriz debe conservar el saldo de días.');
                Lin.Reset();
                Lin.SetRange("No. Liquidación", Documento);
                Lin.SetRange("Cód. Concepto", '1063');
                Vigente.Reset();
                Vigente.SetRange(Código, '1063');
                Vigente.SetFilter("Vigencia Desde", '<=%1', Cab."Fecha Liquidación");
                Vigente.SetFilter("Vigencia Hasta", '%1|>=%2', 0D, Cab."Fecha Liquidación");
                Comprobar(Vigente.FindLast(), 'Debe existir una vigencia de 1063 para la fecha del recibo.');
                Vigente.TestField("Fuente Matriz", 'FRANCOS_FIFO');
                Lin.SetRange("Vigencia Concepto", Vigente."Vigencia Desde");
                Lin.SetFilter("No. Lote Franco", '>0');
                if DiasAntes > 0 then
                    Comprobar(not Lin.IsEmpty(), 'El motor debe haber ejecutado la nueva fórmula y enlazado el lote.')
                else Comprobar(Lin.IsEmpty(), 'Sin días no deben crearse filas ni aplicaciones ficticias.');
                Probados += 1;
            end;
        end;
        Comprobar(Probados > 0, 'No se encontró ningún recibo de enero para probar la matriz.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure PrecioRespetaVigenciaSinCambiarDias()
    var
        Francos: Codeunit "Gestión Francos";
        Filas: Record "Lote Franco Buffer Liq." temporary;
        Anterior: Decimal;
        Actual: Decimal;
        Config: Record "Concepto Liquidación";
        Prueba: Record "Concepto Liquidación";
    begin
        if CompanyName() <> 'ArbuTest' then Error('La prueba de integración sólo corresponde a ArbuTest.');
        // Fechas de prueba explícitas, independientes de las vigencias productivas de enero.
        Config.SetRange(Código, '1063');
        Config.SetFilter("Vigencia Desde", '<=%1', DMY2Date(31, 1, 2026));
        Config.FindLast();
        // La configuración consolidada de enero también cubre las fechas del fixture:
        // cerrarla antes evita que el lector encuentre primero esa fila superpuesta.
        Config."Vigencia Hasta" := DMY2Date(3, 1, 2026);
        Config.Modify(false);
        if not Prueba.Get('1063', DMY2Date(4, 1, 2026)) then begin
            Prueba := Config;
            Prueba."Vigencia Desde" := DMY2Date(4, 1, 2026);
            Prueba."Vigencia Hasta" := DMY2Date(4, 1, 2026);
            Prueba.Insert(false);
        end;
        Prueba.Get('1063', DMY2Date(4, 1, 2026));
        Prueba."Vigencia Hasta" := DMY2Date(4, 1, 2026);
        Prueba."Cód. Tipo Atributo Precio" := 'TIPOACTIVIDAD';
        Prueba.Modify(false);
        if not Prueba.Get('1063', DMY2Date(5, 1, 2026)) then begin
            Prueba := Config;
            Prueba."Vigencia Desde" := DMY2Date(5, 1, 2026);
            Prueba."Vigencia Hasta" := DMY2Date(31, 1, 2026);
            Prueba.Insert(false);
        end;
        Prueba.Get('1063', DMY2Date(5, 1, 2026));
        Prueba."Vigencia Hasta" := DMY2Date(31, 1, 2026);
        Prueba."Cód. Tipo Atributo Precio" := 'PESQ_FRANCO';
        Prueba.Modify(false);
        Filas."No. Línea" := 1;
        Filas."No. Empleado" := '04495';
        Filas."No. Proyecto" := 'PN-MAY-NOMINA';
        Filas."Fecha Lote" := DMY2Date(31, 12, 2025);
        Filas."Cód. Convenio" := '729/15';
        Filas."Cód. Categoría" := 'MR08';
        Filas."Días Tomados" := 3;
        Filas.Insert();
        Francos.ValuarMatriz(Filas, 'LIQ-00051995', DMY2Date(4, 1, 2026));
        Filas.FindFirst();
        Anterior := Filas."Valor Franco";
        Francos.ValuarMatriz(Filas, 'LIQ-00051995', DMY2Date(5, 1, 2026));
        Filas.FindFirst();
        Actual := Filas."Valor Franco";
        Comprobar(Anterior > 0, 'La tarifa histórica debe existir.');
        Comprobar(Actual > Anterior, 'La vigencia nueva debe tomar la tarifa plena de Merluza.');
        Comprobar(Round(Actual * 0.3, 0.01) = Round(Anterior, 0.01), 'Sólo debe cambiar la proporción del precio.');
        Comprobar((Filas.Count() = 1) and (Filas."Días Tomados" = 3), 'Valuar no modifica filas ni días seleccionados.');
        Francos.ValuarMatriz(Filas, 'LIQ-00051995', DMY2Date(4, 1, 2026));
        Filas.FindFirst();
        Comprobar(Filas."Valor Franco" = Anterior, 'Volver a la fecha histórica debe invalidar la configuración de precio en caché.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure RecalculoMensualConservaTopeYTotales()
    var
        Cadena: Codeunit "Recálculo En Cadena Liq.";
        Cab: Record "Liquidación";
        Lin: Record "Línea Liquidación";
        Variable: Record "Resumen Variable Liq.";
        VariablesGuardadas: Codeunit "Variables Guardadas Liq.";
        Haberes: Decimal;
        Descuentos: Decimal;
        Neto: Decimal;
    begin
        if CompanyName() <> 'ArbuTest' then Error('La prueba de integración sólo corresponde a ArbuTest.');
        Cadena.EjecutarMesEmpleado('LIQ-00051517');
        if not VariablesGuardadas.Obtener('LIQ-00051517', 'TOPE_SIPA', Variable) then Error('Falta TOPE_SIPA en LIQ-00051517.');
        Lin.SetRange("No. Empleado", '04868');
        Lin.SetRange("Cód. Período", '202601');
        Lin.SetFilter("Cód. Concepto", '6000|6010|6030|6002|6012|6034');
        Lin.CalcSums(Importe);
        Comprobar(Round(Lin.Importe, 0.01) = Round(Variable.Valor * 0.17, 0.01),
            'Recalcular un mes con varios recibos debe conservar el aporte mensual completo hasta el tope.');
        Cab.SetRange("No. Empleado", '04868');
        Cab.SetRange("Cód. Período", '202601');
        Cab.CalcSums("Total Haberes", "Total Descuentos", "Neto a Pagar");
        Haberes := Cab."Total Haberes";
        Descuentos := Cab."Total Descuentos";
        Neto := Cab."Neto a Pagar";
        Cadena.EjecutarMesEmpleado('LIQ-00051517');
        Cab.CalcSums("Total Haberes", "Total Descuentos", "Neto a Pagar");
        Comprobar((Haberes = Cab."Total Haberes") and (Descuentos = Cab."Total Descuentos") and
            (Neto = Cab."Neto a Pagar"), 'Repetir el recálculo mensual debe conservar bruto, descuentos y neto.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    [HandlerFunctions('MensajeReapertura')]
    procedure ReabrirPeriodoOrdenaDependenciasYRespetaExternos()
    var
        Cuenta: Codeunit "Cuenta Corriente Francos";
        Gestion: Codeunit "Gestión Liquidación";
        Lotes: Codeunit "Lotes Liquidación Liq.";
        Credito: Record "Movimiento Franco Liq.";
        Consumo: Record "Movimiento Franco Liq.";
        Cab: Record "Liquidación";
        Empleado: Code[20];
        Periodo: Code[10];
        Consumidor: Code[20];
        Revertidas: Integer;
        Bloqueadas: Integer;
    begin
        Empleado := NuevoCodigo();
        Periodo := CopyStr(NuevoCodigo(), 1, 10);
        PrepararCuenta(Empleado, Credito);
        // El devengo se visita antes que el consumo por PK y ambos tienen la misma fecha.
        Credito."No. Liquidación" := 'A' + CopyStr(Periodo, 1, 19);
        Credito.Modify(false);
        Cab."No." := Credito."No. Liquidación";
        Cab."No. Empleado" := Empleado;
        Cab."Cód. Período" := Periodo;
        Cab.Estado := Cab.Estado::Calculada;
        Cab.Insert(false);
        Cab."No." := 'Z' + CopyStr(Periodo, 1, 19);
        Cab."Cód. Período" := CopyStr(NuevoCodigo(), 1, 10);
        Cab.Insert(false);
        Consumo."No. Lote" := Credito."No. Lote";
        Consumo."No. Liquidación" := Cab."No.";
        Consumo."No. Empleado" := Empleado;
        Consumo.Tipo := Consumo.Tipo::Consumo;
        Consumo.Cantidad := -3;
        Consumo.Insert(true);
        Comprobar(not Cuenta.PuedeRevertir(Credito."No. Liquidación", Consumidor), 'El consumidor externo debe impedir revertir el devengo.');
        Gestion.ReabrirPeriodo(Periodo, Revertidas, Bloqueadas);
        Comprobar((Revertidas = 0) and (Bloqueadas = 1), 'Un consumidor fuera del período debe dejar el origen bloqueado sin error ni reversión.');
        Cab.Get(Consumo."No. Liquidación");
        Cab."Cód. Período" := Periodo;
        Cab.Modify(false);
        Cab.Reset();
        Cab.SetRange("Cód. Período", Periodo);
        Lotes.Reabrir(Cab);
        Comprobar(Cuenta.SaldoLote(Credito."No. Lote", Today()) = 0, 'Devengo y consumo deben quedar compensados por sus contramovimientos.');
        Cab.Get(Credito."No. Liquidación");
        Cab.TestField(Estado, Cab.Estado::Borrador);
        Cab.Get(Consumo."No. Liquidación");
        Cab.TestField(Estado, Cab.Estado::Borrador);
        Gestion.ReabrirPeriodo(Periodo, Revertidas, Bloqueadas);
        Comprobar((Revertidas = 0) and (Bloqueadas = 0), 'Repetir la reapertura no debe duplicar contramovimientos.');
    end;

    [MessageHandler]
    procedure MensajeReapertura(Mensaje: Text[1024])
    begin
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure AntiguedadUnificadaConservaTotalesYBases()
    var
        Conversion: Codeunit "Unificar Antigüedad Liq.";
        Gestion: Codeunit "Gestión Liquidación";
        Cadena: Codeunit "Recálculo En Cadena Liq.";
        Motor: Codeunit "Motor Liquidación";
        Cab: Record "Liquidación";
        Frac: Record "Fracción Acumulador";
        Concepto: Record "Concepto Liquidación";
        Empleados: List of [Code[20]];
        Documentos: List of [Code[20]];
        Antes: Dictionary of [Text, Decimal];
        Empleado: Code[20];
        Documento: Code[20];
        Primero: Code[20];
        FechaPrimero: Date;
        LinAntig: Record "Línea Liquidación";
        VarBase: Record "Resumen Variable Liq.";
        VariablesGuardadas: Codeunit "Variables Guardadas Liq.";
    begin
        if CompanyName() <> 'ArbuTest' then Error('La prueba corresponde a ArbuTest.');
        Empleados.Add('80344');
        Empleados.Add('04921');
        Empleados.Add('04190');
        foreach Empleado in Empleados do begin
            Cab.Reset();
            Cab.SetRange("No. Empleado", Empleado);
            Cab.SetRange("Cód. Período", '202601');
            Cab.SetRange(Estado, Cab.Estado::Calculada);
            Comprobar(Cab.FindFirst(), 'El mes debe estar calculado antes de la prueba.');
            Cadena.EjecutarMesEmpleado(Cab."No.");
            Cab.CalcSums("Total Haberes", "Total Descuentos", "Neto a Pagar");
            Antes.Add(Empleado + '|H', Cab."Total Haberes");
            Antes.Add(Empleado + '|D', Cab."Total Descuentos");
            Antes.Add(Empleado + '|N', Cab."Neto a Pagar");
            if Cab.FindSet() then repeat Documentos.Add(Cab."No."); until Cab.Next() = 0;
        end;
        Gestion.ReabrirPeriodoPorCodigo('202601');
        Conversion.Aplicar('2026-01-01');
        Concepto.Get('1053', DMY2Date(1, 1, 2026));
        Comprobar(not Concepto.Get('1055', DMY2Date(1, 1, 2026)), 'No debe quedar una vigencia 1055 en enero.');
        Frac.Get('1053', DMY2Date(1, 1, 2026), 'BASE_FERIADO');
        Comprobar(not Frac.AplicaAConvenio('372/04'), 'Tierra no debe agregar antigüedad a la base de feriado.');
        Comprobar(Frac.AplicaAConvenio('729/15'), 'Tripulación debe conservar la base de feriado.');
        while Documentos.Count() > 0 do begin
            Primero := '';
            foreach Documento in Documentos do begin
                Cab.Get(Documento);
                if (Primero = '') or (Cab."Fecha Liquidación" < FechaPrimero) or
                    ((Cab."Fecha Liquidación" = FechaPrimero) and (Documento < Primero)) then begin
                    Primero := Documento;
                    FechaPrimero := Cab."Fecha Liquidación";
                end;
            end;
            Cab.Get(Primero);
            Clear(Motor);
            Motor.LiquidarRecord(Cab);
            Documentos.Remove(Primero);
        end;
        foreach Empleado in Empleados do begin
            Cab.Reset();
            Cab.SetRange("No. Empleado", Empleado);
            Cab.SetRange("Cód. Período", '202601');
            Cab.CalcSums("Total Haberes", "Total Descuentos", "Neto a Pagar");
            Comprobar((Cab."Total Haberes" = Antes.Get(Empleado + '|H')) and
                (Cab."Total Descuentos" = Antes.Get(Empleado + '|D')) and
                (Cab."Neto a Pagar" = Antes.Get(Empleado + '|N')), 'Unificar antigüedad no debe cambiar los importes del mes.');
        end;
        LinAntig.SetRange("No. Empleado", '80344');
        LinAntig.SetRange("Cód. Período", '202601');
        LinAntig.SetRange("Cód. Concepto", '1053');
        Comprobar(LinAntig.FindFirst(), 'Debe existir antigüedad unificada para Alimentación.');
        LinAntig.TestField("Unidad Cantidad", '%');
        if not VariablesGuardadas.Obtener(LinAntig."No. Liquidación", 'BASICO', VarBase) then Error('Falta BASICO en %1.', LinAntig."No. Liquidación");
        Comprobar(Round(LinAntig.Importe, 0.01) = Round(LinAntig.Cantidad * VarBase.Valor / 100, 0.01),
            'La cantidad presentada debe ser el porcentaje que realmente se aplicó al básico.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure TotalVirtualRespetaRolVigenciaFechaYDocumento()
    var
        Cuenta: Codeunit "Cuenta Corriente Francos";
        Concepto: Record "Concepto Liquidación";
        Matriz: Record "Concepto Liquidación";
        Empleado: Code[20];
        Excluido: Code[20];
        Corte: Date;
    begin
        // Sólo ejecutar en una empresa/BD aislada: AutoRollback no aísla otros lectores.
        Empleado := NuevoCodigo();
        Corte := DMY2Date(31, 1, 2026);
        Concepto.Código := NuevoCodigo();
        Concepto."Vigencia Desde" := DMY2Date(1, 1, 2026);
        Concepto."Rol Franco" := Concepto."Rol Franco"::Devengo;
        Concepto.Insert(false);
        Concepto."Vigencia Desde" := DMY2Date(15, 1, 2026);
        Concepto."Rol Franco" := Concepto."Rol Franco"::Consumo;
        Concepto.Insert(false);
        CrearLineaTotalFranco(Empleado, Concepto.Código, DMY2Date(1, 1, 2026), DMY2Date(10, 1, 2026), 3, "Estado Liq."::Calculada);
        Excluido := CrearLineaTotalFranco(Empleado, Concepto.Código, DMY2Date(1, 1, 2026), DMY2Date(20, 1, 2026), 5, "Estado Liq."::Calculada);
        // Sin versión guardada se resuelve por fecha: la de enero temprano devenga y la posterior consume.
        CrearLineaTotalFranco(Empleado, Concepto.Código, 0D, DMY2Date(10, 1, 2026), 7, "Estado Liq."::Calculada);
        CrearLineaTotalFranco(Empleado, Concepto.Código, 0D, DMY2Date(20, 1, 2026), 11, "Estado Liq."::Calculada);
        CrearLineaTotalFranco(Empleado, Concepto.Código, DMY2Date(15, 1, 2026), DMY2Date(20, 1, 2026), 13, "Estado Liq."::Calculada);
        CrearLineaTotalFranco(Empleado, NuevoCodigo(), 0D, DMY2Date(10, 1, 2026), 17, "Estado Liq."::Calculada);
        Matriz.Código := NuevoCodigo();
        Matriz."Vigencia Desde" := DMY2Date(1, 1, 2026);
        Matriz."Rol Franco" := Matriz."Rol Franco"::Devengo;
        Matriz."Fuente Matriz" := 'FRANCOS_FIFO';
        Matriz.Insert(false);
        CrearLineaTotalFranco(Empleado, Matriz.Código, Matriz."Vigencia Desde", DMY2Date(10, 1, 2026), 19, "Estado Liq."::Calculada);
        CrearLineaTotalFranco(Empleado, Concepto.Código, DMY2Date(1, 1, 2026), DMY2Date(10, 1, 2026), 23, "Estado Liq."::Borrador);
        CrearLineaTotalFranco(NuevoCodigo(), Concepto.Código, DMY2Date(1, 1, 2026), DMY2Date(10, 1, 2026), 29, "Estado Liq."::Calculada);
        CrearLineaTotalFranco(Empleado, Concepto.Código, DMY2Date(1, 1, 2026), DMY2Date(1, 2, 2026), 31, "Estado Liq."::Calculada);

        Comprobar(Cuenta.Total(Empleado, "Rol Franco Liq."::Devengo, '', Corte, true) = 15,
            'Deben devengar 3+5+7: manda la versión guardada; sin ella, la fecha. Una matriz representa consumo.');
        Comprobar(Cuenta.Total(Empleado, "Rol Franco Liq."::Devengo, Excluido, Corte, true) = 10,
            'Excluir el documento debe quitar sólo sus cinco días.');
        Comprobar(Cuenta.Total(Empleado, "Rol Franco Liq."::Devengo, '', DMY2Date(10, 1, 2026), true) = 10,
            'El corte inclusivo debe conservar los dos devengos del día exacto.');
        Comprobar(Cuenta.Total(Empleado, "Rol Franco Liq."::Devengo, '', DMY2Date(10, 1, 2026), false) = 0,
            'El corte exclusivo debe dejar fuera los devengos del día exacto.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure TotalNoDuplicaLineaAsentadaYReconoceReversion()
    var
        Cuenta: Codeunit "Cuenta Corriente Francos";
        Credito: Record "Movimiento Franco Liq.";
        Concepto: Record "Concepto Liquidación";
        Linea: Record "Línea Liquidación";
        Empleado: Code[20];
        Corte: Date;
    begin
        Empleado := NuevoCodigo();
        Corte := DMY2Date(31, 1, 2026);
        PrepararCuenta(Empleado, Credito);
        Credito."Fecha Devengamiento" := DMY2Date(10, 1, 2026);
        Credito."No. Línea Origen" := 1;
        Credito.Modify(false);
        Concepto.Código := NuevoCodigo();
        Concepto."Vigencia Desde" := DMY2Date(1, 1, 2026);
        Concepto."Rol Franco" := Concepto."Rol Franco"::Devengo;
        Concepto.Insert(false);
        Linea."No. Liquidación" := Credito."No. Liquidación";
        Linea."No. Línea" := 1;
        Linea."No. Empleado" := Empleado;
        Linea."Cód. Concepto" := Concepto.Código;
        Linea."Vigencia Concepto" := Concepto."Vigencia Desde";
        Linea."Fecha Liquidación" := Credito."Fecha Devengamiento";
        Linea.Cantidad := 10;
        Linea.Estado := Linea.Estado::Calculada;
        Linea.Insert(false);
        // Mismo documento, otra línea: todavía virtual. Otra cabecera con línea1 también es independiente.
        Linea."No. Línea" := 2;
        Linea.Cantidad := 2;
        Linea.Insert(false);
        CrearLineaTotalFranco(Empleado, Concepto.Código, Concepto."Vigencia Desde", Credito."Fecha Devengamiento", 3, "Estado Liq."::Calculada);

        Comprobar(Cuenta.Total(Empleado, "Rol Franco Liq."::Devengo, '', Corte, true) = 15,
            'Diez días asentados más cinco virtuales deben sumarse una vez por documento y línea.');
        Comprobar(Cuenta.Total(Empleado, "Rol Franco Liq."::Devengo, Credito."No. Liquidación", Corte, true) = 3,
            'La exclusión debe quitar tanto el movimiento como la línea virtual del mismo documento.');
        Cuenta.Revertir(Credito."No. Liquidación");
        Comprobar(Cuenta.Total(Empleado, "Rol Franco Liq."::Devengo, '', Corte, true) = 15,
            'Al revertir el asiento, la línea Calculada vuelve a ser virtual sin duplicar los diez días.');
        Linea.Get(Credito."No. Liquidación", 1);
        Comprobar(Linea.Cantidad = 10, 'La consulta y el contramovimiento no deben modificar los días de la línea original.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure MatrizVirtualConservaOrigenYTraza()
    var
        Cuenta: Codeunit "Cuenta Corriente Francos";
        Credito: Record "Movimiento Franco Liq.";
        Movimientos: Record "Movimiento Franco Liq.";
        Concepto: Record "Concepto Liquidación";
        Linea: Record "Línea Liquidación";
        Filas: Record "Lote Franco Buffer Liq." temporary;
        Empleado: Code[20];
        Documento: Code[20];
        Corte: Date;
        Antes: Integer;
        Pasada: Integer;
    begin
        Empleado := NuevoCodigo();
        Corte := Today();
        PrepararCuenta(Empleado, Credito);
        Credito.Cantidad := 0;
        Credito.Modify(false);
        Concepto.Código := NuevoCodigo();
        Concepto."Vigencia Desde" := Corte;
        Concepto."Rol Franco" := Concepto."Rol Franco"::Devengo;
        Concepto.Insert(false);
        Documento := CrearLineaTotalFranco(Empleado, Concepto.Código, Corte, Corte, 7.25, "Estado Liq."::Calculada);
        Linea.Get(Documento, 1);
        Linea."No. Proyecto" := 'PROY-PRUEBA';
        Linea."Cód. Convenio" := 'CCT-PRUEBA';
        Linea."Cód. Categoría" := 'CAT-PRUEBA';
        Linea."Cód. Período" := 'PER-PRUEBA';
        Linea."Fórmula Aplicada" := 'TRAZA-FORMULA';
        Linea."Fuente Parámetros" := 'TRAZA-PARAMETROS';
        Linea."Vigencias Distribución" := 'TRAZA-VIGENCIAS';
        Linea.Modify(false);
        CrearLineaTotalFranco(Empleado, Concepto.Código, Corte, Corte + 1, 99, "Estado Liq."::Calculada);
        CrearLineaTotalFranco(Empleado, Concepto.Código, Corte, Corte, 99, "Estado Liq."::Borrador);
        Movimientos.SetRange("No. Empleado", Empleado);
        Antes := Movimientos.Count();

        // Validar las dos variantes SQL: documento exacto y todos los documentos.
        for Pasada := 1 to 2 do begin
            if Pasada = 1 then
                Cuenta.Matriz(Empleado, Corte, Documento, 2.5, true, Filas)
            else
                Cuenta.Matriz(Empleado, Corte, '', 2.5, false, Filas);
            Comprobar(Filas.Count() = 1, 'Sólo corresponde el devengo virtual calculado a la fecha.');
            Filas.FindFirst();
            Filas.TestField("No. Empleado", Empleado);
            Filas.TestField("No. Liquidación Origen", Documento);
            Filas.TestField("No. Línea Origen", 1);
            Filas.TestField("No. Lote", -1);
            Filas.TestField("Fecha Lote", Corte);
            Filas.TestField("Cód. Concepto Lote", Concepto.Código);
            Filas.TestField("No. Proyecto", Linea."No. Proyecto");
            Filas.TestField("Cód. Convenio", Linea."Cód. Convenio");
            Filas.TestField("Cód. Categoría", Linea."Cód. Categoría");
            Filas.TestField("Cód. Período", Linea."Cód. Período");
            Filas.TestField("Días del Lote", 7.25);
            Filas.TestField("Días Disponibles", 7.25);
            Filas.TestField("Días Tomados", 2.5);
            Comprobar(not IsNullGuid(Filas."Id. Selección"), 'La selección debe conservar su identificador de trazabilidad.');
        end;
        Comprobar(Movimientos.Count() = Antes, 'La matriz no debe asentar ni consumir movimientos.');
        Linea.Get(Documento, 1);
        Linea.TestField(Cantidad, 7.25);
        Linea.TestField("Fórmula Aplicada", 'TRAZA-FORMULA');
        Linea.TestField("Fuente Parámetros", 'TRAZA-PARAMETROS');
        Linea.TestField("Vigencias Distribución", 'TRAZA-VIGENCIAS');
    end;

    local procedure CrearLineaTotalFranco(Empleado: Code[20]; Concepto: Code[20]; Vigencia: Date; Fecha: Date; Cantidad: Decimal; Estado: Enum "Estado Liq."): Code[20]
    var
        Linea: Record "Línea Liquidación";
    begin
        Linea."No. Liquidación" := NuevoCodigo();
        Linea."No. Línea" := 1;
        Linea."No. Empleado" := Empleado;
        Linea."Cód. Concepto" := Concepto;
        Linea."Vigencia Concepto" := Vigencia;
        Linea."Fecha Liquidación" := Fecha;
        Linea.Cantidad := Cantidad;
        Linea.Estado := Estado;
        Linea.Insert(false);
        exit(Linea."No. Liquidación");
    end;

    local procedure TotalesPorConcepto(Documento: Code[20]; var Totales: Dictionary of [Text, Decimal])
    var
        Lin: Record "Línea Liquidación";
        Clave: Text;
    begin
        Clear(Totales);
        Lin.SetRange("No. Liquidación", Documento);
        if Lin.FindSet() then repeat
            Clave := Lin."Cód. Concepto" + '|' + Lin."Cód. Convenio" + '|' + Lin."Cód. Categoría";
            SumarTotal(Totales, 'Q|' + Clave, Lin.Cantidad);
            SumarTotal(Totales, 'I|' + Clave, Lin.Importe);
            SumarTotal(Totales, 'B|' + Clave, Lin."Base Cálculo");
        until Lin.Next() = 0;
    end;

    local procedure SumarTotal(var Totales: Dictionary of [Text, Decimal]; Clave: Text; Importe: Decimal)
    var
        Anterior: Decimal;
    begin
        if not Totales.Get(Clave, Anterior) then Anterior := 0;
        Totales.Set(Clave, Anterior + Importe);
    end;

    local procedure PrepararCuenta(Empleado: Code[20]; var Credito: Record "Movimiento Franco Liq.")
    var
        Inicio: Record "Movimiento Franco Liq.";
        Ultimo: Record "Movimiento Franco Liq.";
        Numero: Integer;
    begin
        Inicio."No. Empleado" := Empleado;
        Inicio.Tipo := Inicio.Tipo::Inicio;
        Inicio.Insert(false);
        Ultimo.LockTable();
        Ultimo.FindLast();
        Numero := Ultimo."No. Movimiento" + 1;
        Credito.Init();
        Credito."No. Movimiento" := Numero;
        Credito."No. Lote" := Numero;
        Credito."No. Empleado" := Empleado;
        Credito."No. Liquidación" := NuevoCodigo();
        Credito.Tipo := Credito.Tipo::Devengo;
        Credito."Fecha Devengamiento" := Today();
        Credito.Cantidad := 10;
        Credito.Insert(false);
    end;

    local procedure NuevoCodigo(): Code[20]
    begin
        exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
    end;

    local procedure Comprobar(Condicion: Boolean; Mensaje: Text)
    begin
        if not Condicion then Error(Mensaje);
    end;
}
