namespace UAS.Payroll;

codeunit 50055 "Gestión Tipo Liq."
{
    // Seeds the Tipo Liquidación master. Idempotent: safe to run on install and on upgrade.
    // The enum→code migration (EnumACodigo, Liq/Lin conversion) that used to live here was removed once
    // the old Enum "Tipos Liquidación" and its Liquidación/Línea fields were deleted — run this BEFORE
    // that deletion ships if any data hasn't been migrated yet, or it's lost.

    procedure Sembrar()
    begin
        Agregar('REGULAR', 'Regular', 10, false, true);
        Agregar('AGUINALDO', 'Aguinaldo', 20, false, false);
        Agregar('VACACIONES', 'Vacaciones', 30, false, false);
        Agregar('LIQ_FINAL', 'Liquidación Final', 40, false, false);
        Agregar('RELIQUIDACION', 'Reliquidación', 50, false, false);
        Agregar('DEVENGADOS', 'Devengados', 60, false, false);
        Agregar('CIERRE_MAREA', 'Cierre Marea', 70, true, false);
    end;

    local procedure Agregar(Codigo: Code[20]; Desc: Text[50]; Orden: Integer; LiquidaArribo: Boolean; IncluyeFrancos: Boolean)
    var
        TipoLiq: Record "Tipo Liquidación";
    begin
        if TipoLiq.Get(Codigo) then
            exit;
        TipoLiq.Init();
        TipoLiq.Código := Codigo;
        TipoLiq.Descripción := Desc;
        TipoLiq.Orden := Orden;
        TipoLiq."Liquida al Arribo" := LiquidaArribo;
        TipoLiq."Incluye Francos Puerto" := IncluyeFrancos;
        TipoLiq.Activo := true;
        TipoLiq.Insert();
    end;

    // Keeps any stray old-format (enum caption) text in Concepto."Tipos Liq. Aplicables" migrated to
    // codes. Harmless/idempotent to rerun — codes never match the caption text being replaced.
    procedure MigrarDatos()
    var
        Concepto: Record "Concepto Liquidación";
        NuevoTexto: Text[250];
    begin
        if Concepto.FindSet(true) then
            repeat
                NuevoTexto := NombresACodigos(Concepto."Tipos Liq. Aplicables");
                if NuevoTexto <> Concepto."Tipos Liq. Aplicables" then begin
                    Concepto."Tipos Liq. Aplicables" := NuevoTexto;
                    Concepto.Modify();
                end;
            until Concepto.Next() = 0;
    end;

    // Replaces the old enum captions with the new codes in a pipe-delimited "Tipos Liq. Aplicables" string.
    // Case-sensitive replace makes it idempotent (already-migrated codes don't match the captions).
    local procedure NombresACodigos(Texto: Text[250]): Text[250]
    begin
        if Texto = '' then exit('');
        Texto := Texto.Replace('Cierre Marea', 'CIERRE_MAREA');
        Texto := Texto.Replace('Liquidación Final', 'LIQ_FINAL');
        Texto := Texto.Replace('Reliquidación', 'RELIQUIDACION');
        Texto := Texto.Replace('Aguinaldo', 'AGUINALDO');
        Texto := Texto.Replace('Vacaciones', 'VACACIONES');
        Texto := Texto.Replace('Devengados', 'DEVENGADOS');
        Texto := Texto.Replace('Regular', 'REGULAR');
        exit(Texto);
    end;
}
