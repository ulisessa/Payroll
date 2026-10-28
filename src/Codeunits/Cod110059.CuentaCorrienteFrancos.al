namespace UAS.Payroll;

codeunit 110059 "Cuenta Corriente Francos"
{
    Permissions = tabledata "Movimiento Franco Liq." = RI;

    procedure Activa(Empleado: Code[20]): Boolean
    var
        Mov: Record "Movimiento Franco Liq.";
    begin
        Mov.SetRange("No. Empleado", Empleado);
        Mov.SetRange(Tipo, Mov.Tipo::Inicio);
        exit(not Mov.IsEmpty());
    end;

    // Reconstrucción explícita: no cambia recibos ni activa parcialmente una cuenta si falla.
    procedure Inicializar(Empleado: Code[20])
    var
        Mov: Record "Movimiento Franco Liq.";
        Lin: Record "Línea Liquidación";
        Cab: Record "Liquidación";
    begin
        Mov.LockTable();
        if Activa(Empleado) then exit;
        Lin.SetRange("No. Empleado", Empleado);
        Lin.SetCurrentKey("No. Empleado", "Fecha Liquidación", "Tipo Concepto");
        if Lin.FindSet() then
            repeat
                if Cab.Get(Lin."No. Liquidación") then
                    if Cab.Estado <> Cab.Estado::Borrador then
                        if Rol(Lin) = "Rol Franco Liq."::Devengo then
                            RegistrarDevengo(Lin, true);
            until Lin.Next() = 0;
        if Lin.FindSet() then
            repeat
                if Cab.Get(Lin."No. Liquidación") then
                    if Cab.Estado <> Cab.Estado::Borrador then
                        if Rol(Lin) = "Rol Franco Liq."::Consumo then
                            RegistrarConsumo(Lin, true);
            until Lin.Next() = 0;
        Mov.Init();
        Mov."No. Empleado" := Empleado;
        Mov.Tipo := Mov.Tipo::Inicio;
        Mov.Insert(true);
    end;

    procedure RegistrarLiquidacion(Liq: Record "Liquidación")
    var
        Lin: Record "Línea Liquidación";
        Mov: Record "Movimiento Franco Liq.";
        HayMatriz: Boolean;
        HayTradicional: Boolean;
        Concepto: Record "Concepto Liquidación";
    begin
        if not Activa(Liq."No. Empleado") then exit;
        Mov.LockTable();
        Lin.SetRange("No. Liquidación", Liq."No.");
        if Lin.FindSet() then repeat
            if Concepto.Get(Lin."Cód. Concepto", Lin."Vigencia Concepto") then begin
                if Concepto."Fuente Matriz" <> '' then HayMatriz := true
                else if Concepto."Rol Franco" = Concepto."Rol Franco"::Consumo then HayTradicional := true;
            end;
        until Lin.Next() = 0;
        if HayMatriz and HayTradicional then Error('No mezcles consumo tradicional y FRANCOS_FIFO en el mismo recibo: convertí todos sus componentes para compartir los días.');
        if Lin.FindSet() then
            repeat
                if Rol(Lin) = "Rol Franco Liq."::Devengo then
                    RegistrarDevengo(Lin, false);
            until Lin.Next() = 0;
        if Lin.FindSet() then
            repeat
                if Rol(Lin) = "Rol Franco Liq."::Consumo then
                    RegistrarConsumo(Lin, false);
            until Lin.Next() = 0;
    end;

    procedure Revertir(Documento: Code[20])
    begin
        RevertirOrigen(Documento, 0);
    end;

    /// <summary>Consulta las dependencias vigentes sin retirar movimientos.</summary>
    procedure PuedeRevertir(Documento: Code[20]; var Consumidor: Code[20]): Boolean
    var
        Original: Record "Movimiento Franco Liq.";
        Dependiente: Record "Movimiento Franco Liq.";
    begin
        Consumidor := '';
        Original.SetRange("No. Liquidación", Documento);
        Original.SetRange(Tipo, Original.Tipo::Devengo);
        if Original.FindSet() then repeat
            if not Revertido(Original."No. Movimiento") then begin
                Dependiente.SetRange("No. Lote", Original."No. Lote");
                Dependiente.SetRange(Tipo, Dependiente.Tipo::Consumo);
                Dependiente.SetFilter("No. Liquidación", '<>%1', Documento);
                if Dependiente.FindSet() then repeat
                    if not Revertido(Dependiente."No. Movimiento") then begin
                        Consumidor := Dependiente."No. Liquidación";
                        exit(false);
                    end;
                until Dependiente.Next() = 0;
            end;
        until Original.Next() = 0;
        exit(true);
    end;

    procedure RevertirOrigen(Documento: Code[20]; LineaOrigen: Integer)
    var
        Original: Record "Movimiento Franco Liq.";
        Contra: Record "Movimiento Franco Liq.";
        Dependiente: Record "Movimiento Franco Liq.";
        Claves: List of [Integer];
        Numero: Integer;
    begin
        Original.LockTable();
        Original.SetRange("No. Liquidación", Documento);
        if LineaOrigen <> 0 then Original.SetRange("No. Línea Origen", LineaOrigen);
        Original.SetFilter(Tipo, '%1|%2', Original.Tipo::Devengo, Original.Tipo::Consumo);
        if Original.FindSet() then
            repeat
                if not Revertido(Original."No. Movimiento") then begin
                    if Original.Tipo = Original.Tipo::Devengo then begin
                        Dependiente.SetRange("No. Lote", Original."No. Lote");
                        Dependiente.SetRange(Tipo, Dependiente.Tipo::Consumo);
                        Dependiente.SetFilter("No. Liquidación", '<>%1', Documento);
                        if Dependiente.FindSet() then
                            repeat
                                if not Revertido(Dependiente."No. Movimiento") then
                                    Error('El lote de %1 fue consumido por %2. Reabrí primero esa liquidación.', Documento, Dependiente."No. Liquidación");
                            until Dependiente.Next() = 0;
                    end;
                    Claves.Add(Original."No. Movimiento");
                end;
            until Original.Next() = 0;
        foreach Numero in Claves do begin
            Original.Get(Numero);
            Contra := Original;
            Contra."No. Movimiento" := 0;
            Contra.Tipo := Contra.Tipo::Reversion;
            Contra.Cantidad := -Original.Cantidad;
            Contra."Revierte Movimiento" := Numero;
            Contra.Insert(true);
        end;
    end;

    procedure Matriz(Empleado: Code[20]; Fecha: Date; Documento: Code[20]; Cantidad: Decimal; IncluirPropios: Boolean; var Filas: Record "Lote Franco Buffer Liq." temporary)
    var
        Lote: Record "Movimiento Franco Liq.";
        Lin: Record "Línea Liquidación";
        Disponible: Decimal;
        Restante: Decimal;
        Seleccion: Guid;
        Numero: Integer;
        InicioFase: Date;
    begin
        if not Activa(Empleado) then
            Error('Inicializá la cuenta corriente de francos del empleado antes de usar FRANCOS_FIFO.');
        if Cantidad < 0 then Error('La cantidad de francos no puede ser negativa.');
        Filas.Reset();
        Filas.DeleteAll();
        Restante := Cantidad;
        Seleccion := CreateGuid();
        Lote.SetCurrentKey("No. Empleado", Tipo, "Fecha Devengamiento", "No. Movimiento");
        Lote.SetRange("No. Empleado", Empleado);
        Lote.SetRange(Tipo, Lote.Tipo::Devengo);
        InicioFase := InicioDeFase(Empleado, Fecha);
        Lote.SetRange("Fecha Devengamiento", InicioFase, Fecha);
        if Documento <> '' then Lote.SetFilter("No. Liquidación", '<>%1', Documento);
        if Lote.FindSet() then
            repeat
                Disponible := SaldoLote(Lote."No. Lote", Fecha);
                if (Disponible > 0) and (Restante > 0) then begin
                    Numero += 1;
                    Filas.Init();
                    Filas."No. Línea" := Numero;
                    Filas."No. Lote" := Lote."No. Lote";
                    Filas."No. Empleado" := Empleado;
                    Filas."Fecha Lote" := Lote."Fecha Devengamiento";
                    Filas."No. Liquidación Origen" := Lote."No. Liquidación";
                    Filas."No. Línea Origen" := Lote."No. Línea Origen";
                    Filas."No. Proyecto" := Lote."No. Proyecto";
                    Filas."Cód. Convenio" := Lote."Cód. Convenio";
                    Filas."Cód. Categoría" := Lote."Cód. Categoría";
                    Filas."Cód. Puesto" := Lote."Cód. Puesto";
                    Filas."Cód. Estado" := Lote."Cód. Estado";
                    Filas."Cód. Período" := Lote."Cód. Período";
                    Filas."Cód. Concepto Lote" := Lote."Cód. Concepto";
                    Filas."Días del Lote" := Lote.Cantidad;
                    Filas."Días Disponibles" := Disponible;
                    Filas."Días Tomados" := Disponible;
                    if Restante < Disponible then Filas."Días Tomados" := Restante;
                    Filas."Id. Selección" := Seleccion;
                    Restante -= Filas."Días Tomados";
                    Filas.Insert();
                end;
            until Lote.Next() = 0;
        // Créditos de la pasada actual: son virtuales hasta cerrar el cálculo, sin movimientos de GU.
        if (IncluirPropios or (Documento = '')) and (Restante > 0) then begin
            // CopiarOrigen y el buffer consumen estos ocho campos; la clave y los filtros
            // se cargan automáticamente. Las fórmulas y trazas siguen guardadas en la línea.
            Lin.SetLoadFields(Cantidad, "Cód. Concepto", "Vigencia Concepto", "Fecha Liquidación",
                "No. Proyecto", "Cód. Convenio", "Cód. Categoría", "Cód. Período");
            if Documento <> '' then Lin.SetRange("No. Liquidación", Documento);
            Lin.SetRange("No. Empleado", Empleado);
            Lin.SetRange(Estado, Lin.Estado::Calculada);
            Lin.SetRange("Fecha Liquidación", InicioFase, Fecha);
            if Lin.FindSet() then
                repeat
                    if (Rol(Lin) = "Rol Franco Liq."::Devengo) and (Lin.Cantidad > 0) and (Restante > 0) and (not ExisteLinea(Lin, Lote.Tipo::Devengo)) then begin
                        CopiarOrigen(Lin, Lote);
                        Numero += 1;
                        Filas.Init();
                        Filas."No. Línea" := Numero;
                        Filas."No. Lote" := -Lin."No. Línea";
                        Filas."No. Empleado" := Empleado;
                        Filas."No. Liquidación Origen" := Lin."No. Liquidación";
                        Filas."No. Línea Origen" := Lin."No. Línea";
                        Filas."Fecha Lote" := Lin."Fecha Liquidación";
                        Filas."No. Proyecto" := Lin."No. Proyecto";
                        Filas."Cód. Convenio" := Lin."Cód. Convenio";
                        Filas."Cód. Categoría" := Lin."Cód. Categoría";
                        Filas."Cód. Puesto" := Lote."Cód. Puesto";
                        Filas."Cód. Estado" := Lote."Cód. Estado";
                        Filas."Cód. Período" := Lin."Cód. Período";
                        Filas."Cód. Concepto Lote" := Lin."Cód. Concepto";
                        Filas."Días del Lote" := Lin.Cantidad;
                        Filas."Días Disponibles" := Lin.Cantidad;
                        Filas."Días Tomados" := Lin.Cantidad;
                        if Restante < Lin.Cantidad then Filas."Días Tomados" := Restante;
                        Filas."Id. Selección" := Seleccion;
                        Restante -= Filas."Días Tomados";
                        Filas.Insert();
                    end;
                until Lin.Next() = 0;
        end;
        if Restante > 0 then Error('La matriz pide %1 días de franco y faltan %2.', Cantidad, Restante);
        Filas.Reset();
    end;

    procedure Total(Empleado: Code[20]; RolFranco: Enum "Rol Franco Liq."; ExcluirDocumento: Code[20]; Fecha: Date; Inclusivo: Boolean): Decimal
    var
        Mov: Record "Movimiento Franco Liq.";
        Lin: Record "Línea Liquidación";
        RolesLeidos: Dictionary of [Text, Enum "Rol Franco Liq."];
        VersionesAusentes: Dictionary of [Text, Boolean];
        Resultado: Decimal;
        InicioFase: Date;
    begin
        InicioFase := InicioDeFase(Empleado, Fecha);
        // SQL descarta los movimientos revertidos en la misma lectura. Conserva la
        // búsqueda global por ID: una reversión no se limita a la fecha ni al empleado.
        Mov.SetLoadFields(Cantidad);
        Mov.SetRange(Revertido, false);
        Mov.SetRange("No. Empleado", Empleado);
        if RolFranco = RolFranco::Devengo then Mov.SetRange(Tipo, Mov.Tipo::Devengo)
        else Mov.SetRange(Tipo, Mov.Tipo::Consumo);
        if ExcluirDocumento <> '' then Mov.SetFilter("No. Liquidación", '<>%1', ExcluirDocumento);
        if Inclusivo then Mov.SetRange("Fecha Devengamiento", InicioFase, Fecha)
        else Mov.SetRange("Fecha Devengamiento", InicioFase, Fecha - 1);
        if Mov.FindSet() then
            repeat
                Resultado += Mov.Cantidad;
            until Mov.Next() = 0;
        if RolFranco = RolFranco::Consumo then exit(-Resultado);
        // Devengos virtuales de la pasada actual y saldos iniciales todavía no asentados.
        // Las memorias son locales a esta llamada: otro Total debe ver las líneas, asientos,
        // reversiones y vigencias que hayan cambiado durante el cálculo.
        Lin.SetLoadFields(Cantidad, "Cód. Concepto", "Vigencia Concepto", "Fecha Liquidación");
        Lin.SetRange("No. Empleado", Empleado);
        Lin.SetRange(Estado, Lin.Estado::Calculada);
        if ExcluirDocumento <> '' then Lin.SetFilter("No. Liquidación", '<>%1', ExcluirDocumento);
        if Inclusivo then Lin.SetRange("Fecha Liquidación", InicioFase, Fecha)
        else Lin.SetRange("Fecha Liquidación", InicioFase, Fecha - 1);
        if Lin.FindSet() then
            repeat
                if RolParaTotal(Lin, RolesLeidos, VersionesAusentes) = RolFranco::Devengo then
                    if not LineaAsentadaParaTotal(Lin) then Resultado += Lin.Cantidad;
            until Lin.Next() = 0;
        exit(Resultado);
    end;

    local procedure RolParaTotal(Lin: Record "Línea Liquidación"; var RolesLeidos: Dictionary of [Text, Enum "Rol Franco Liq."]; var VersionesAusentes: Dictionary of [Text, Boolean]): Enum "Rol Franco Liq."
    var
        Concepto: Record "Concepto Liquidación";
        Clave: Text;
        RolLeido: Enum "Rol Franco Liq.";
    begin
        // Una versión exacta no depende de la fecha de la línea. La longitud evita
        // que separadores dentro del código colisionen con la clave.
        Clave := Format(StrLen(Lin."Cód. Concepto")) + ':' + Lin."Cód. Concepto" + '|' +
            Format(Lin."Vigencia Concepto", 0, 9);
        if RolesLeidos.Get(Clave, RolLeido) then exit(RolLeido);
        if not VersionesAusentes.ContainsKey(Clave) then begin
            Concepto.SetLoadFields("Rol Franco", "Fuente Matriz");
            if Concepto.Get(Lin."Cód. Concepto", Lin."Vigencia Concepto") then begin
                RolLeido := Concepto."Rol Franco";
                if Concepto."Fuente Matriz" <> '' then RolLeido := "Rol Franco Liq."::Consumo;
                RolesLeidos.Add(Clave, RolLeido);
                exit(RolLeido);
            end;
            VersionesAusentes.Add(Clave, true);
        end;
        // Sólo el fallback depende de la fecha, y conserva el rol sin reinterpretar matriz.
        Clave += '|' + Format(Lin."Fecha Liquidación", 0, 9);
        if RolesLeidos.Get(Clave, RolLeido) then exit(RolLeido);
        RolLeido := RolPorFecha(Lin."Cód. Concepto", Lin."Fecha Liquidación");
        RolesLeidos.Add(Clave, RolLeido);
        exit(RolLeido);
    end;

    local procedure LineaAsentadaParaTotal(Lin: Record "Línea Liquidación"): Boolean
    var
        Mov: Record "Movimiento Franco Liq.";
    begin
        // Conserva el ámbito de ExisteLinea, sin limitar empleado ni fecha. SQL comprueba
        // origen y reversión juntos, sin recorrer movimientos ni leer campos de la línea.
        Mov.SetRange("No. Liquidación", Lin."No. Liquidación");
        Mov.SetRange("No. Línea Origen", Lin."No. Línea");
        Mov.SetRange(Tipo, Mov.Tipo::Devengo);
        Mov.SetRange(Revertido, false);
        exit(not Mov.IsEmpty());
    end;

    procedure SaldoAlInicio(Numero: Integer; Fecha: Date): Decimal
    var
        Lote: Record "Movimiento Franco Liq.";
        Consumo: Record "Movimiento Franco Liq.";
        Saldo: Decimal;
    begin
        Lote.Get(Numero);
        if Revertido(Numero) then exit(0);
        if Lote."Fecha Devengamiento" > Fecha then exit(0);
        Saldo := Lote.Cantidad;
        Consumo.SetRange("No. Lote", Numero);
        Consumo.SetRange(Tipo, Consumo.Tipo::Consumo);
        Consumo.SetFilter("Fecha Devengamiento", '<%1', Fecha);
        if Consumo.FindSet() then repeat
            if not Revertido(Consumo."No. Movimiento") then Saldo += Consumo.Cantidad;
        until Consumo.Next() = 0;
        exit(Saldo);
    end;

    procedure SaldoLote(Numero: Integer; Fecha: Date): Decimal
    var
        Mov: Record "Movimiento Franco Liq.";
    begin
        Mov.SetRange("No. Lote", Numero);
        Mov.SetRange("Fecha Devengamiento", 0D, Fecha);
        Mov.CalcSums(Cantidad);
        exit(Mov.Cantidad);
    end;

    // La cuenta corriente se corta en el alta de la fase vigente a la fecha: la baja paga el saldo
    // (2803) y lo que queda en el ledger de la fase anterior no es de la fase nueva. Meta4 reinicia el
    // saldo en cada alta; BC lo arrastraba (04139: 33 días de la fase que cerró el 9/2; 04889: 25).
    local procedure InicioDeFase(Empleado: Code[20]; Fecha: Date): Date
    var
        Fase: Record "Fase Alta Empleado";
    begin
        Fase.SetLoadFields("Fecha Alta");
        Fase.SetCurrentKey("No. Empleado", "Fecha Alta");
        Fase.SetRange("No. Empleado", Empleado);
        Fase.SetRange("Fecha Alta", 0D, Fecha);
        if Fase.FindLast() then exit(Fase."Fecha Alta");
        exit(0D);
    end;

    local procedure Revertido(Numero: Integer): Boolean
    var
        Mov: Record "Movimiento Franco Liq.";
    begin
        Mov.SetRange("Revierte Movimiento", Numero);
        exit(not Mov.IsEmpty());
    end;

    local procedure ExisteLinea(Lin: Record "Línea Liquidación"; Tipo: Option): Boolean
    var
        Mov: Record "Movimiento Franco Liq.";
    begin
        Mov.SetRange("No. Liquidación", Lin."No. Liquidación");
        Mov.SetRange("No. Línea Origen", Lin."No. Línea");
        Mov.SetRange(Tipo, Tipo);
        if Mov.FindSet() then
            repeat
                if not Revertido(Mov."No. Movimiento") then exit(true);
            until Mov.Next() = 0;
        exit(false);
    end;

    local procedure RegistrarDevengo(Lin: Record "Línea Liquidación"; Historico: Boolean)
    var
        Mov: Record "Movimiento Franco Liq.";
    begin
        if ExisteLinea(Lin, Mov.Tipo::Devengo) then exit;
        if Lin.Cantidad = 0 then exit;
        if Lin.Cantidad < 0 then Error('Devengo negativo de francos en %1. Revisalo antes de inicializar la cuenta.', Lin."No. Liquidación");
        CopiarOrigen(Lin, Mov);
        Mov.Tipo := Mov.Tipo::Devengo;
        Mov.Cantidad := Lin.Cantidad;
        Mov.Reconstruido := Historico;
        // Asignación bajo LockTable: el lote y el movimiento nacen con la misma clave, sin Modify.
        Mov."No. Movimiento" := SiguienteNumero();
        Mov."No. Lote" := Mov."No. Movimiento";
        Mov.Insert(true);
    end;

    local procedure SiguienteNumero(): Integer
    var
        Mov: Record "Movimiento Franco Liq.";
    begin
        Mov.LockTable();
        if Mov.FindLast() then exit(Mov."No. Movimiento" + 1);
        exit(1);
    end;

    local procedure RegistrarConsumo(Lin: Record "Línea Liquidación"; Historico: Boolean)
    var
        Lote: Record "Movimiento Franco Liq.";
        Existente: Record "Movimiento Franco Liq.";
        Restante: Decimal;
        Tomar: Decimal;
        NumeroLote: Integer;
    begin
        if Lin.Cantidad = 0 then exit;
        if Lin.Cantidad < 0 then Error('Consumo negativo de francos en %1. Revisalo antes de inicializar la cuenta.', Lin."No. Liquidación");
        if ExisteLinea(Lin, Existente.Tipo::Consumo) then exit;
        NumeroLote := Lin."No. Lote Franco";
        if NumeroLote < 0 then begin
            Lote.SetRange("No. Liquidación", Lin."No. Liquidación");
            Lote.SetRange("No. Línea Origen", -NumeroLote);
            Lote.SetRange(Tipo, Lote.Tipo::Devengo);
            Lote.FindLast();
            NumeroLote := Lote."No. Lote";
            Lin."No. Lote Franco" := NumeroLote;
            Lin.Modify(false);
            Lote.Reset();
        end;
        if NumeroLote <> 0 then begin
            if not IsNullGuid(Lin."Id. Selección Francos") then begin
                Existente.SetRange("Id. Selección", Lin."Id. Selección Francos");
                Existente.SetRange("No. Lote", NumeroLote);
                Existente.SetRange(Tipo, Existente.Tipo::Consumo);
                if Existente.FindSet() then
                    repeat
                        if not Revertido(Existente."No. Movimiento") then begin
                            if Existente.Cantidad <> -Lin.Cantidad then Error('Los componentes de la matriz no coinciden en días.');
                            exit;
                        end;
                    until Existente.Next() = 0;
            end;
            InsertarConsumo(Lin, NumeroLote, Lin.Cantidad, Historico);
            exit;
        end;
        // Líneas históricas agrupadas: reconstrucción FIFO identificada como tal.
        Restante := Lin.Cantidad;
        Lote.SetCurrentKey("No. Empleado", Tipo, "Fecha Devengamiento", "No. Movimiento");
        Lote.SetRange("No. Empleado", Lin."No. Empleado");
        Lote.SetRange(Tipo, Lote.Tipo::Devengo);
        Lote.SetRange("Fecha Devengamiento", 0D, Lin."Fecha Liquidación");
        if Lote.FindSet() then
            repeat
                Tomar := SaldoLote(Lote."No. Lote", Lin."Fecha Liquidación");
                if Tomar > Restante then Tomar := Restante;
                if Tomar > 0 then begin
                    InsertarConsumo(Lin, Lote."No. Lote", Tomar, Historico);
                    Restante -= Tomar;
                end;
            until (Lote.Next() = 0) or (Restante = 0);
        if Restante <> 0 then Error('La liquidación %1 consume francos sin devengo suficiente a su fecha. No se activó parcialmente la cuenta.', Lin."No. Liquidación");
    end;

    local procedure InsertarConsumo(Lin: Record "Línea Liquidación"; NumeroLote: Integer; Dias: Decimal; Historico: Boolean)
    var
        Mov: Record "Movimiento Franco Liq.";
        Lote: Record "Movimiento Franco Liq.";
    begin
        Lote.Get(NumeroLote);
        Lote.TestField("No. Empleado", Lin."No. Empleado");
        if Lote.Tipo <> Lote.Tipo::Devengo then Error('El movimiento %1 no es un lote.', NumeroLote);
        if SaldoLote(NumeroLote, DMY2Date(31, 12, 9999)) < Dias then Error('El lote %1 no tiene saldo para consumir %2 días.', NumeroLote, Dias);
        if Lote."Fecha Devengamiento" > Lin."Fecha Liquidación" then Error('No se pueden consumir francos de un devengo futuro.');
        CopiarOrigen(Lin, Mov);
        Mov.Tipo := Mov.Tipo::Consumo;
        Mov."No. Lote" := NumeroLote;
        Mov.Cantidad := -Dias;
        Mov."Id. Selección" := Lin."Id. Selección Francos";
        Mov.Reconstruido := Historico;
        Mov.Insert(true);
    end;

    local procedure CopiarOrigen(Lin: Record "Línea Liquidación"; var Mov: Record "Movimiento Franco Liq.")
    var
        Estado: Record "Estado Empleado";
        Atr: Record "Atributo Entidad Liq.";
    begin
        Mov.Init();
        Mov."No. Movimiento" := 0;
        Mov."No. Empleado" := Lin."No. Empleado";
        Mov."No. Liquidación" := Lin."No. Liquidación";
        Mov."No. Línea Origen" := Lin."No. Línea";
        Mov."Fecha Devengamiento" := Lin."Fecha Liquidación";
        Mov."Cód. Convenio" := Lin."Cód. Convenio";
        Mov."Cód. Categoría" := Lin."Cód. Categoría";
        Mov."No. Proyecto" := Lin."No. Proyecto";
        Mov."Cód. Período" := Lin."Cód. Período";
        Mov."Cód. Concepto" := Lin."Cód. Concepto";
        Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
        Estado.SetRange("No. Empleado", Lin."No. Empleado");
        Estado.SetFilter("Fecha Inicio", '<=%1', Lin."Fecha Liquidación");
        if Estado.FindLast() then
            if Estado.FechaFinEfectiva() >= Lin."Fecha Liquidación" then Mov."Cód. Estado" := Estado."Cód. Estado";
        Atr.SetRange("Tipo Entidad", Atr."Tipo Entidad"::Empleado);
        Atr.SetRange("Cód. Entidad", Lin."No. Empleado");
        Atr.SetRange("Cód. Tipo Atributo", 'PUESTO');
        Atr.SetFilter("Vigencia Desde", '<=%1', Lin."Fecha Liquidación");
        if Atr.FindLast() then
            if (Atr."Vigencia Hasta" = 0D) or (Atr."Vigencia Hasta" >= Lin."Fecha Liquidación") then Mov."Cód. Puesto" := Atr."Cód. Valor";
    end;

    local procedure Rol(Lin: Record "Línea Liquidación"): Enum "Rol Franco Liq."
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Concepto.SetLoadFields("Rol Franco", "Fuente Matriz");
        if Concepto.Get(Lin."Cód. Concepto", Lin."Vigencia Concepto") then begin
            if Concepto."Fuente Matriz" <> '' then exit("Rol Franco Liq."::Consumo);
            exit(Concepto."Rol Franco");
        end;
        exit(RolPorFecha(Lin."Cód. Concepto", Lin."Fecha Liquidación"));
    end;

    local procedure RolPorFecha(Codigo: Code[20]; Fecha: Date): Enum "Rol Franco Liq."
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Concepto.SetLoadFields("Rol Franco");
        Concepto.SetRange(Código, Codigo);
        Concepto.SetFilter("Vigencia Desde", '<=%1', Fecha);
        if Concepto.FindLast() then exit(Concepto."Rol Franco");
        exit("Rol Franco Liq."::Ninguno);
    end;
}
