namespace UAS.Payroll;

codeunit 50051 "Gestión Préstamos"
{
    // Manages salary loans and advances (Préstamos / Anticipos).
    // Hooks into the liquidation lifecycle:
    //   AplicarCuotasEnLiquidacion  ← called from motor (Borrador state only)
    //   MarcarCuotasAplicadas       ← called from Aprobar
    //   RevertirCuotasLiquidacion   ← called from Reabrir and RevertirAprobacion

    procedure GenerarCuotas(Prestamo: Record "Préstamo Empleado")
    var
        Cuota: Record "Cuota Préstamo";
        ImporteCuota: Decimal;
        i: Integer;
    begin
        Prestamo.TestField("No. Empleado");
        Prestamo.TestField("Importe Total");
        Prestamo.TestField("Cant. Cuotas");
        Prestamo.TestField("Cód. Concepto Descuento");

        // Remove existing pending cuotas before regenerating
        Cuota.SetRange("No. Préstamo", Prestamo."No.");
        Cuota.SetRange(Estado, Cuota.Estado::Pendiente);
        Cuota.DeleteAll();

        ImporteCuota := Round(Prestamo."Importe Total" / Prestamo."Cant. Cuotas", 0.01);

        for i := 1 to Prestamo."Cant. Cuotas" do begin
            Clear(Cuota);
            Cuota."No. Préstamo" := Prestamo."No.";
            Cuota."No. Cuota" := 0;  // AutoIncrement
            if i < Prestamo."Cant. Cuotas" then
                Cuota.Importe := ImporteCuota
            else
                // Last cuota absorbs rounding
                Cuota.Importe := Prestamo."Importe Total" - ImporteCuota * (Prestamo."Cant. Cuotas" - 1);
            Cuota.Estado := Cuota.Estado::Pendiente;
            Cuota.Insert(true);
        end;
    end;

    // Called from the motor during liquidation calculation (Borrador state only).
    // Creates or updates Incidencias for pending cuotas matching this liquidation.
    procedure AplicarCuotasEnLiquidacion(var Liq: Record "Liquidación")
    var
        Cuota: Record "Cuota Préstamo";
        Prestamo: Record "Préstamo Empleado";
        Incid: Record "Incidencia Liquidación";
        CodCuota: Code[30];
    begin
        if Liq.Estado <> Liq.Estado::Borrador then
            exit;

        Cuota.SetRange("No. Empleado", Liq."No. Empleado");
        Cuota.SetRange(Estado, Cuota.Estado::Pendiente);
        if not Cuota.FindSet() then exit;

        repeat
            if CuotaAplicaALiquidacion(Cuota, Liq) then
                if Prestamo.Get(Cuota."No. Préstamo") then
                    if Prestamo."Cód. Concepto Descuento" <> '' then begin
                        CodCuota := CopyStr(Cuota."No. Préstamo" + '|' + Format(Cuota."No. Cuota"), 1, 30);
                        if not Incid.Get(Liq."No.", Prestamo."Cód. Concepto Descuento") then begin
                            Clear(Incid);
                            Incid."No. Liquidación" := Liq."No.";
                            Incid."Cód. Concepto" := Prestamo."Cód. Concepto Descuento";
                            Incid.Importe := Cuota.Importe;
                            Incid."Cód. Cuota Préstamo" := CodCuota;
                            Incid.Observaciones := CopyStr('Cuota ' + Format(Cuota."No. Cuota") + ' — ' + Prestamo.Descripción, 1, 250);
                            Incid.Insert();
                        end else begin
                            Incid.Importe += Cuota.Importe;
                            if Incid."Cód. Cuota Préstamo" = '' then
                                Incid."Cód. Cuota Préstamo" := CodCuota;
                            Incid.Modify();
                        end;
                        Cuota."No. Liquidación" := Liq."No.";
                        Cuota.Modify();
                    end;
        until Cuota.Next() = 0;
    end;

    // Called from GestionLiquidacion.Aprobar.
    // Marks cuotas linked to this liquidation as Aplicada.
    procedure MarcarCuotasAplicadas(LiqNo: Code[20]; FechaLiq: Date)
    var
        Cuota: Record "Cuota Préstamo";
    begin
        Cuota.SetRange("No. Liquidación", LiqNo);
        Cuota.SetRange(Estado, Cuota.Estado::Pendiente);
        if Cuota.FindSet(true) then
            repeat
                Cuota.Estado := Cuota.Estado::Aplicada;
                Cuota."No. Liquidación Aplicada" := LiqNo;
                Cuota."Fecha Aplicada" := FechaLiq;
                Cuota.Modify();
            until Cuota.Next() = 0;
    end;

    // Called from the motor before AplicarCuotasEnLiquidacion on every recalculation.
    // Resets only the Borrador-run state so AplicarCuotasEnLiquidacion can start fresh:
    //   - clears No. Liquidación on Pendiente cuotas linked to this run
    //   - deletes loan-generated incidencias
    // Does NOT touch Aplicada cuotas (those belong to already-approved liquidations).
    procedure LimpiarParaRecalculo(LiqNo: Code[20])
    var
        Cuota: Record "Cuota Préstamo";
        Incid: Record "Incidencia Liquidación";
    begin
        Cuota.SetRange("No. Liquidación", LiqNo);
        Cuota.SetRange(Estado, Cuota.Estado::Pendiente);
        if Cuota.FindSet(true) then
            repeat
                Cuota."No. Liquidación" := '';
                Cuota.Modify();
            until Cuota.Next() = 0;

        Incid.SetRange("No. Liquidación", LiqNo);
        Incid.SetFilter("Cód. Cuota Préstamo", '<>%1', '');
        Incid.DeleteAll();
    end;

    // Called from GestionLiquidacion.Reabrir and RevertirAprobacion.
    // Reverts cuotas to Pendiente and removes loan-generated Incidencias.
    procedure RevertirCuotasLiquidacion(LiqNo: Code[20])
    var
        Cuota: Record "Cuota Préstamo";
        Incid: Record "Incidencia Liquidación";
    begin
        // Revert Aplicada cuotas (from Aprobar)
        Cuota.SetRange("No. Liquidación Aplicada", LiqNo);
        Cuota.SetRange(Estado, Cuota.Estado::Aplicada);
        if Cuota.FindSet(true) then
            repeat
                Cuota.Estado := Cuota.Estado::Pendiente;
                Cuota."No. Liquidación Aplicada" := '';
                Cuota."Fecha Aplicada" := 0D;
                Cuota."No. Liquidación" := '';
                Cuota.Modify();
            until Cuota.Next() = 0;

        // Revert Pendiente cuotas linked to this liq (from AplicarCuotasEnLiquidacion)
        Cuota.Reset();
        Cuota.SetRange("No. Liquidación", LiqNo);
        Cuota.SetRange(Estado, Cuota.Estado::Pendiente);
        if Cuota.FindSet(true) then
            repeat
                Cuota."No. Liquidación" := '';
                Cuota.Modify();
            until Cuota.Next() = 0;

        // Delete loan-generated Incidencias (identified by Cód. Cuota Préstamo)
        Incid.SetRange("No. Liquidación", LiqNo);
        Incid.SetFilter("Cód. Cuota Préstamo", '<>%1', '');
        Incid.DeleteAll();
    end;

    local procedure CuotaAplicaALiquidacion(Cuota: Record "Cuota Préstamo"; Liq: Record "Liquidación"): Boolean
    begin
        // Explicit liquidation target
        if Cuota."No. Liquidación" <> '' then
            exit(Cuota."No. Liquidación" = Liq."No.");

        // Period target: any liquidation for this employee in this period
        if Cuota."Cód. Período" <> '' then
            exit(Cuota."Cód. Período" = Liq."Cód. Período");

        // No target defined → not auto-applied
        exit(false);
    end;
}
