namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

/// <summary>
/// Arma el análisis de vacaciones: el promedio del art. 49 desarmado paso a paso, por empleado y por
/// mes.
/// </summary>
/// <remarks>
/// NO RECALCULA NADA. Lee lo mismo que lee el motor —la ventana sale de "Contexto Liquidación", las
/// bases de las líneas de liquidación— y lo muestra separado. Una vista que recalculara por su
/// cuenta mostraría lo que *debería* pasar en vez de lo que pasa, y en una conciliación contra un
/// sistema legado eso es peor que no tener vista: confirma la hipótesis equivocada.
///
/// Por eso la ventana viene de VentanaPromedioVacacionesPara y no de una copia local, aunque la
/// cuenta sea de dos líneas.
/// </remarks>
codeunit 110057 "Análisis Vacaciones"
{
    var
        ConceptoVacNoGozadas: Label '3973', Locked = true;
        ConceptoBasePromedio: Label 'BASE_PROMEDIO', Locked = true;
        ObsSinBase: Label 'El divisor lo cuenta pero no aporta base: hueco en la historia.';
        ObsParcial: Label 'Mes parcial (%1 de %2 días): aporta una fracción y pesa un mes entero.', Comment = '%1=días con alta, %2=días del mes';
        ObsFueraDeFase: Label 'Fuera de la fase vigente.';

    /// <summary>Una fila por empleado con el cálculo del promedio desarmado.</summary>
    procedure Resumen(FiltroEmpleado: Text; CodPeriodo: Code[20]; var Buffer: Record "Vacaciones Buffer Liq." temporary)
    var
        Liq: Record "Liquidación";
        Empleado: Record Employee;
    begin
        Buffer.Reset();
        Buffer.DeleteAll();

        // Se parte de las LIQUIDACIONES del período y no de la nómina entera: el análisis es sobre lo
        // que se liquidó, y recorrer 4.810 empleados para mostrar 8 es trabajo puro de descarte.
        Liq.SetCurrentKey("Cód. Período", "No. Empleado");
        Liq.SetRange("Cód. Período", CodPeriodo);
        if FiltroEmpleado <> '' then
            Liq.SetFilter("No. Empleado", FiltroEmpleado);
        Liq.SetLoadFields("No. Empleado", "Cód. Convenio", "Cód. Categoría");
        if not Liq.FindSet() then
            exit;

        repeat
            if not Buffer.Get(Liq."No. Empleado") then begin
                Buffer.Init();
                Buffer."No. Empleado" := Liq."No. Empleado";
                Buffer."Cód. Período" := CodPeriodo;
                Buffer."Cód. Convenio" := Liq."Cód. Convenio";
                Buffer."Cód. Categoría" := Liq."Cód. Categoría";
                if Empleado.Get(Liq."No. Empleado") then
                    Buffer."Nombre Empleado" := CopyStr(Empleado.FullName(), 1, MaxStrLen(Buffer."Nombre Empleado"));
                CargarFila(Buffer, CodPeriodo);
                Buffer.Insert();
            end;
        until Liq.Next() = 0;
    end;

    /// <summary>El detalle mes a mes de la ventana de UN empleado.</summary>
    procedure DetalleMeses(EmployeeNo: Code[20]; CodPeriodo: Code[20]; var Buffer: Record "Vac. Mes Buffer Liq." temporary)
    var
        Ctx: Codeunit "Contexto Liquidación";
        Desde: Date;
        Hasta: Date;
        MesDesde: Date;
        MesHasta: Date;
        Meses: Integer;
        Linea: Integer;
        Cubiertos: Integer;
        DelMes: Integer;
    begin
        Buffer.Reset();
        Buffer.DeleteAll();
        if EmployeeNo = '' then
            exit;

        Ctx.VentanaPromedioVacacionesPara(EmployeeNo, FechaRefDe(EmployeeNo, CodPeriodo), Desde, Hasta, Meses);
        if (Desde = 0D) or (Hasta = 0D) then
            exit;

        MesDesde := Desde;
        while MesDesde <= Hasta do begin
            MesHasta := CalcDate('<CM>', MesDesde);
            DelMes := MesHasta - CalcDate('<-CM>', MesDesde) + 1;
            Cubiertos := DiasConAltaEnMes(EmployeeNo, MesDesde, MesHasta);

            Linea += 1;
            Buffer.Init();
            Buffer."No. Empleado" := EmployeeNo;
            Buffer."No. Línea" := Linea;
            Buffer."Cód. Período" := PeriodoDeFecha(MesDesde);
            Buffer."Mes Desde" := MesDesde;
            Buffer."Mes Hasta" := MesHasta;
            Buffer.Base := BaseDelMes(EmployeeNo, PeriodoDeFecha(MesDesde));
            Buffer."Días Cubiertos" := Cubiertos;
            Buffer."Días del Mes" := DelMes;
            Buffer.Completo := Cubiertos >= DelMes;
            Buffer."Cuenta en el Divisor" := Cubiertos > 0;

            case true of
                Cubiertos = 0:
                    Buffer.Observación := ObsFueraDeFase;
                (Buffer.Base = 0):
                    Buffer.Observación := ObsSinBase;
                not Buffer.Completo:
                    Buffer.Observación := StrSubstNo(ObsParcial, Cubiertos, DelMes);
            end;

            Buffer.Insert();
            MesDesde := CalcDate('<+1M>', MesDesde);
        end;
    end;

    local procedure CargarFila(var Buffer: Record "Vacaciones Buffer Liq."; CodPeriodo: Code[20])
    var
        Ctx: Codeunit "Contexto Liquidación";
        Fase: Record "Fase Alta Empleado";
        Desde: Date;
        Hasta: Date;
        Meses: Integer;
        FechaRef: Date;
    begin
        FechaRef := FechaRefDe(Buffer."No. Empleado", CodPeriodo);
        Buffer.Tripulante := EsTripulante(Buffer."No. Empleado");

        // La fase VIGENTE: la última que arrancó en o antes de la fecha de referencia. Es la que
        // manda, porque el promedio no puede cruzar hacia la relación laboral anterior.
        Fase.SetCurrentKey("No. Empleado", "Fecha Alta");
        Fase.SetRange("No. Empleado", Buffer."No. Empleado");
        Fase.SetFilter("Fecha Alta", '<=%1', FechaRef);
        if Fase.FindLast() then begin
            Buffer."Fecha Alta Fase" := Fase."Fecha Alta";
            Buffer."Fecha Baja" := Fase."Fecha Baja";
            if Fase."Fecha Baja" <> 0D then
                Buffer."Días Prestación" := Fase."Fecha Baja" - Fase."Fecha Alta" + 1
            else
                Buffer."Días Prestación" := FechaRef - Fase."Fecha Alta" + 1;
        end;

        Ctx.VentanaPromedioVacacionesPara(Buffer."No. Empleado", FechaRef, Desde, Hasta, Meses);
        Buffer."Ventana Desde" := Desde;
        Buffer."Ventana Hasta" := Hasta;
        Buffer."Días Prestación Ventana" := Ctx.DiasPrestacionPromedioVacPara(Buffer."No. Empleado", FechaRef);
        Buffer."Ventana es Fracción" := (FechaRef >= Desde) and (FechaRef <= Hasta);

        AcumularBase(Buffer, Desde, Hasta);

        // base / días * 30: un "período mensual" del art. 49 son treinta días, no un mes del
        // calendario. Así un mes trabajado a medias pesa los días que pesa.
        if Buffer."Días Prestación Ventana" > 0 then
            Buffer."Promedio Mensual" := Buffer."Base Acumulada" / Buffer."Días Prestación Ventana" * 30;
        // El divisor 25 del art. 49: "para establecer el valor diario de la licencia, se dividirá
        // dicho valor mensual por el divisor veinticinco (25)".
        Buffer."Valor Día" := Buffer."Promedio Mensual" / 25;

        Buffer."Días Art. 150" := Ctx.DiasVacacionesPorAntiguedadPara(Buffer."No. Empleado", FechaRef);
        Buffer."Días Proporcionales" := DiasQueCorresponden(Buffer);
        Buffer."Días Gozados" := DiasGozados(Buffer."No. Empleado", Desde, FechaRef);
        Buffer."Días No Gozados" := Buffer."Días Proporcionales" - Buffer."Días Gozados";
        if Buffer."Días No Gozados" < 0 then
            Buffer."Días No Gozados" := 0;
        Buffer."Importe No Gozadas" := Buffer."Valor Día" * Buffer."Días No Gozados";
        Buffer."Liquidado 3973" := LiquidadoEnElPeriodo(Buffer."No. Empleado", CodPeriodo);
    end;

    /// <summary>
    /// Los días que corresponden: art. 49 del CCT para tripulantes, con el corte de los 181 días.
    /// </summary>
    /// <remarks>
    /// "Para tener derecho a este beneficio, el tripulante deberá haber prestado servicios como
    /// mínimo la cantidad de ciento ochenta y un (181) días corridos en el año... Si no reuniere
    /// este tiempo mínimo, gozará de un período de descanso anual a razón de un (1) día de
    /// vacaciones por cada veinte (20) días corridos de prestación de servicios."
    ///
    /// El artículo rige SÓLO para tripulantes; el personal de tierra va por LCT. Se deja explícito
    /// porque los dos regímenes dan números muy distintos para los mismos días.
    /// </remarks>
    local procedure DiasQueCorresponden(var Buffer: Record "Vacaciones Buffer Liq."): Decimal
    begin
        if Buffer."Días Prestación" >= 181 then
            exit(Buffer."Días Art. 150");
        exit(Round(Buffer."Días Prestación" / 20, 1, '<'));
    end;

    local procedure AcumularBase(var Buffer: Record "Vacaciones Buffer Liq."; Desde: Date; Hasta: Date)
    var
        MesDesde: Date;
        Base: Decimal;
    begin
        if (Desde = 0D) or (Hasta = 0D) then
            exit;
        MesDesde := Desde;
        while MesDesde <= Hasta do begin
            Base := BaseDelMes(Buffer."No. Empleado", PeriodoDeFecha(MesDesde));
            Buffer."Base Acumulada" += Base;
            if Base <> 0 then
                Buffer."Meses con Dato" += 1;
            MesDesde := CalcDate('<+1M>', MesDesde);
        end;
    end;

    local procedure BaseDelMes(EmployeeNo: Code[20]; CodPeriodo: Code[20]): Decimal
    var
        Lin: Record "Línea Liquidación";
        Total: Decimal;
    begin
        if CodPeriodo = '' then
            exit(0);
        Lin.SetRange("No. Empleado", EmployeeNo);
        Lin.SetRange("Cód. Período", CodPeriodo);
        Lin.SetRange("Cód. Concepto", ConceptoBasePromedio);
        Lin.SetLoadFields(Importe);
        if Lin.FindSet() then
            repeat
                Total += Lin.Importe;
            until Lin.Next() = 0;
        exit(Total);
    end;

    local procedure LiquidadoEnElPeriodo(EmployeeNo: Code[20]; CodPeriodo: Code[20]): Decimal
    var
        Lin: Record "Línea Liquidación";
        Total: Decimal;
    begin
        Lin.SetRange("No. Empleado", EmployeeNo);
        Lin.SetRange("Cód. Período", CodPeriodo);
        Lin.SetRange("Cód. Concepto", ConceptoVacNoGozadas);
        Lin.SetLoadFields(Importe);
        if Lin.FindSet() then
            repeat
                Total += Lin.Importe;
            until Lin.Next() = 0;
        exit(Total);
    end;

    local procedure DiasGozados(EmployeeNo: Code[20]; Desde: Date; Hasta: Date): Decimal
    var
        Estado: Record "Estado Empleado";
        CodEst: Record "Cód. Estado Empleado";
        Total: Decimal;
        DesdeEf: Date;
        HastaEf: Date;
    begin
        if (Desde = 0D) or (Hasta = 0D) then
            exit(0);
        Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
        Estado.SetRange("No. Empleado", EmployeeNo);
        Estado.SetFilter("Fecha Inicio", '<=%1', Hasta);
        if Estado.FindSet() then
            repeat
                // El Get en su propio if: AL evalúa los dos lados de un and, así que un código de
                // estado inexistente haría fallar la lectura de la bandera igual.
                if CodEst.Get(Estado."Cód. Estado") then
                    if CodEst."Tipo Estado" = CodEst."Tipo Estado"::Vacaciones then begin
                        DesdeEf := Estado."Fecha Inicio";
                        HastaEf := Estado.FechaFinEfectiva();
                        if DesdeEf < Desde then
                            DesdeEf := Desde;
                        if HastaEf > Hasta then
                            HastaEf := Hasta;
                        if HastaEf >= DesdeEf then
                            Total += HastaEf - DesdeEf + 1;
                    end;
            until Estado.Next() = 0;
        exit(Total);
    end;

    local procedure DiasConAltaEnMes(EmployeeNo: Code[20]; MesDesde: Date; MesHasta: Date): Integer
    var
        Fase: Record "Fase Alta Empleado";
        D: Date;
        H: Date;
        Total: Integer;
    begin
        Fase.SetRange("No. Empleado", EmployeeNo);
        Fase.SetFilter("Fecha Alta", '<=%1', MesHasta);
        if Fase.FindSet() then
            repeat
                if (Fase."Fecha Baja" = 0D) or (Fase."Fecha Baja" >= MesDesde) then begin
                    D := Fase."Fecha Alta";
                    H := Fase."Fecha Baja";
                    if H = 0D then
                        H := MesHasta;
                    if D < MesDesde then
                        D := MesDesde;
                    if H > MesHasta then
                        H := MesHasta;
                    if H >= D then
                        Total += H - D + 1;
                end;
            until Fase.Next() = 0;
        exit(Total);
    end;

    /// <summary>Tiene movimientos de franco, que es lo que distingue a un embarcado.</summary>
    local procedure EsTripulante(EmployeeNo: Code[20]): Boolean
    var
        Lin: Record "Línea Liquidación";
        Concepto: Record "Concepto Liquidación";
        Codigos: Text;
    begin
        Concepto.SetFilter("Rol Franco", '<>%1', Concepto."Rol Franco"::Ninguno);
        Concepto.SetLoadFields(Código);
        if Concepto.FindSet() then
            repeat
                if Codigos <> '' then
                    Codigos += '|';
                Codigos += Concepto.Código;
            until Concepto.Next() = 0;
        if Codigos = '' then
            exit(false);

        Lin.SetRange("No. Empleado", EmployeeNo);
        Lin.SetFilter("Cód. Concepto", Codigos);
        Lin.SetFilter(Cantidad, '<>%1', 0);
        exit(not Lin.IsEmpty());
    end;

    /// <summary>La fecha hasta la que se mira: la baja si egresó en el período, si no el fin.</summary>
    local procedure FechaRefDe(EmployeeNo: Code[20]; CodPeriodo: Code[20]): Date
    var
        Periodo: Record "Período Liquidación";
        Fase: Record "Fase Alta Empleado";
        Fin: Date;
    begin
        if Periodo.Get(CodPeriodo) then
            Fin := Periodo."Fecha Hasta";
        if Fin = 0D then
            Fin := WorkDate();

        // Una baja dentro del período manda sobre el fin de mes: la cobertura de una final corta en
        // la baja, y el promedio tiene que mirar lo mismo que miró el cálculo.
        Fase.SetRange("No. Empleado", EmployeeNo);
        Fase.SetRange("Fecha Baja", CalcDate('<-CM>', Fin), Fin);
        if Fase.FindLast() then
            exit(Fase."Fecha Baja");
        exit(Fin);
    end;

    local procedure PeriodoDeFecha(Fecha: Date): Code[20]
    var
        Periodo: Record "Período Liquidación";
    begin
        if Fecha = 0D then
            exit('');
        Periodo.SetFilter("Fecha Desde", '<=%1', Fecha);
        Periodo.SetFilter("Fecha Hasta", '>=%1', Fecha);
        if Periodo.FindFirst() then
            exit(Periodo.Código);
        exit('');
    end;
}
