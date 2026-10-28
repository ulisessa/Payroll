namespace UAS.Payroll;

codeunit 110066 "Unificar Antigüedad Liq."
{
    procedure Aplicar(FechaTexto: Text)
    var
        Desde: Date;
        Trip: Record "Concepto Liquidación";
        Tierra: Record "Concepto Liquidación";
        Otra: Record "Concepto Liquidación";
        Cab: Record "Liquidación";
        Lin: Record "Línea Liquidación";
        Frac: Record "Fracción Acumulador";
        Destino: Record "Fracción Acumulador";
        CCT: Record "Concepto CCT Vigente";
        Variable: Record "Variable Sistema Liq.";
        Formula: Text;
    begin
        if not Evaluate(Desde, FechaTexto, 9) then Error('Indicá una fecha ISO.');
        if Desde <> DMY2Date(1, 1, 2026) then Error('Esta conversión corresponde al 01/01/2026.');
        Trip.LockTable();
        Trip.Get('1053', Desde);
        if not Tierra.Get('1055', Desde) then begin
            if not Trip.Fórmula.Contains('ANTIGÜEDAD_MENS') then Error('Falta 1055 y 1053 no está unificado.');
            exit;
        end;
        Cab.SetRange("Cód. Período", '202601');
        Cab.SetFilter(Estado, '<>%1', Cab.Estado::Borrador);
        if not Cab.IsEmpty() then Error('Reabrí enero completo antes de unificar los conceptos.');
        Otra.SetRange(Código, '1055');
        Otra.SetFilter("Vigencia Desde", '>%1', Desde);
        if not Otra.IsEmpty() then Error('1055 tiene vigencias posteriores; revisar antes de convertir.');
        Lin.SetRange("Cód. Concepto", '1055');
        Lin.SetFilter("Cód. Período", '<>%1', '202601');
        Lin.SetFilter("Vigencia Concepto", '>=%1', Desde);
        if not Lin.IsEmpty() then Error('Hay usos de 1055 fuera de enero que requieren revisión.');
        if (Trip."Par CCT a Usar" <> Tierra."Par CCT a Usar") or
            (Trip.Condición <> Tierra.Condición) or
            (Trip."Tipos Liq. Aplicables" <> Tierra."Tipos Liq. Aplicables") then
            Error('Las condiciones o el contexto de ambos conceptos no son compatibles.');
        Formula := 'IF(CONVENIO = ''372/04'', ' + Tierra.Fórmula + ', ' + Trip.Fórmula + ')';
        if StrLen(Formula) > MaxStrLen(Trip.Fórmula) then Error('La fórmula unificada excede el campo.');
        Trip.Fórmula := CopyStr(Formula, 1, MaxStrLen(Trip.Fórmula));
        Trip."Fórmula Orden Cálculo" := 'IF(CONVENIO = ''372/04'', 50, 100)';
        Trip."Variable Cantidad" := 'IF(CONVENIO=''372/04'',@AÑOS_ANTIGUEDAD*TRAMO(''ANTIGÜEDAD_MENS'',@AÑOS_ANTIGUEDAD),PCT_ANTIG_SOMU)';
        Trip."Unidad Cantidad" := '%';
        Trip."Variable Base" := 'IF(CONVENIO=''372/04'',0,AÑOS_ANTIG_30JUN)';
        Trip.Descripción := 'Antigüedad';
        Trip.Modify(false);
        if not CCT.Get('1053', Desde, '372/04', '') then begin
            CCT.Init();
            CCT."Cód. Concepto" := '1053';
            CCT."Vigencia Desde" := Desde;
            CCT."Cód. Convenio" := '372/04';
            CCT.Insert(false);
        end;
        Frac.SetRange("Cód. Concepto", '1055');
        Frac.SetRange("Vigencia Desde", Desde);
        if Frac.FindSet() then repeat
            Destino.Get('1053', Desde, Frac."Cód. Acumulador");
            if (Destino.Porcentaje <> Frac.Porcentaje) or (Destino."Invertir Signo" <> Frac."Invertir Signo") then
                Error('Las distribuciones difieren en %1.', Frac."Cód. Acumulador");
        until Frac.Next() = 0;
        Destino.Get('1053', Desde, 'BASE_AUSENTISMO');
        Destino."Filtro Convenio" := '<>372/04';
        Destino.Modify(false);
        Destino.Get('1053', Desde, 'BASE_FERIADO');
        Destino."Filtro Convenio" := '<>372/04';
        Destino.Modify(false);
        Otra.Reset();
        Otra.SetFilter("Vigencia Desde", '>=%1', Desde);
        if Otra.FindSet() then repeat
            if Otra.Fórmula.Contains('#1055') then begin
                Otra.Fórmula := Otra.Fórmula.Replace('+ #1055', '');
                if Otra.Fórmula.Contains('#1055') then Error('Revisar la referencia a 1055 en %1.', Otra.Código);
                Otra.Modify(false);
            end;
        until Otra.Next() = 0;
        Variable.SetRange("Cód. Concepto", '1055');
        Variable.ModifyAll("Cód. Concepto", '1053');
        Lin.Reset();
        Lin.SetRange("Cód. Período", '202601');
        Lin.SetRange("Cód. Concepto", '1055');
        Lin.ModifyAll("Vigencia Concepto", Desde);
        Lin.ModifyAll("Cód. Concepto", '1053');
        // Enero está Borrador: los importes conservados se rehacen con la fórmula consolidada.
        Tierra.Delete(false);
        Frac.DeleteAll(false);
        CCT.Reset();
        CCT.SetRange("Cód. Concepto", '1055');
        CCT.SetFilter("Vigencia Desde", '>=%1', Desde);
        CCT.DeleteAll(false);
        Otra.Reset();
        Otra.SetRange(Código, '1055');
        Otra.SetFilter("Vigencia Hasta", '%1|>=%2', 0D, Desde);
        Otra.ModifyAll("Vigencia Hasta", Desde - 1);
    end;
}
