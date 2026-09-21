namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

/// <summary>
/// Arma el control de días liquidados: cómo se repartieron los días de cada empleado entre estados y
/// cuáles no quedaron cubiertos por ninguna liquidación.
/// </summary>
/// <remarks>
/// Contesta la pregunta que ninguna liquidación puede contestar sola: a quién le falta liquidar. Una
/// liquidación demuestra que esos días se hicieron; los que no se hicieron no dejan rastro en ningún
/// lado, y hasta ahora la única forma de enterarse era que la persona reclamara.
///
/// La unidad es el DÍA y no el período, y eso no es un refinamiento: es la diferencia entre detectar
/// el problema y no detectarlo. Un tripulante que estuvo en dos mareas del 1 al 20 de julio tiene dos
/// liquidaciones de julio; mirando por período el mes figura cubierto, cuando del 21 al 31 no se le
/// liquidó nada.
///
/// Los días por estado quedan en un diccionario y no en la tabla porque las columnas son dinámicas:
/// hay una por cada Cód. Estado que aparezca en el rango, y eso lo decide la configuración, no este
/// código. La página las arma con el patrón de matriz.
/// </remarks>
codeunit 110030 "Control Cobertura Liq."
{
    Access = Public;

    /// <summary>
    /// Llena Buffer con una fila por empleado. Devuelve cuántos empleados entraron.
    /// </summary>
    /// <remarks>
    /// Se parte de los ESTADOS y no de las liquidaciones: partir de las liquidaciones dejaría afuera
    /// justo al que no tiene ninguna, que es el caso más grave.
    /// </remarks>
    procedure Construir(var Buffer: Record "Cobertura Liq. Buffer" temporary; Desde: Date; Hasta: Date; FiltroEmpleado: Text) Empleados: Integer
    var
        Estado: Record "Estado Empleado";
        Fase: Record "Fase Alta Empleado";
        EnRango: List of [Code[20]];
        Descartados: List of [Code[20]];
        EmpNo: Code[20];
    begin
        Buffer.Reset();
        Buffer.DeleteAll();
        Clear(FDiasEstado);
        Clear(FEstados);
        Clear(FTramos);
        FDesde := Desde;
        FHasta := Hasta;
        if (Desde = 0D) or (Hasta = 0D) or (Desde > Hasta) then
            exit(0);

        Estado.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
        Estado.SetFilter("Fecha Inicio", '<=%1', Hasta);
        if FiltroEmpleado <> '' then
            Estado.SetFilter("No. Empleado", FiltroEmpleado);
        Estado.SetLoadFields("No. Empleado", "Fecha Inicio", "Fecha Fin");
        if not Estado.FindSet() then
            exit(0);
        repeat
            // Un estado cerrado antes del inicio de la consulta no aporta días al rango.
            if (Estado."Fecha Fin" = 0D) or (Estado."Fecha Fin" >= Desde) then
                // Mismo filtro por fase que aplica el lote al crear. Sin él, un estado que nunca se
                // cerró arrastra a su dueño a TODOS los períodos posteriores: el legajo 02678 tiene
                // un Franco abierto desde 2001 y aparecía como pendiente en enero de 2026. El
                // control y el lote tienen que mirar la misma población, o el control marca como
                // faltante lo que el lote nunca va a crear.
                //
                // Dos listas y no una: sin la de descartados, un empleado rechazado vuelve a
                // consultarse en cada una de sus filas de estado.
                if not (EnRango.Contains(Estado."No. Empleado") or Descartados.Contains(Estado."No. Empleado")) then
                    if Fase.EstuvoActivoEntre(Estado."No. Empleado", Desde, Hasta) then
                        EnRango.Add(Estado."No. Empleado")
                    else
                        Descartados.Add(Estado."No. Empleado");
        until Estado.Next() = 0;

        foreach EmpNo in EnRango do
            ArmarEmpleado(Buffer, EmpNo);
        Empleados := EnRango.Count();

        OrdenarEstados();
        Buffer.Reset();
        if Buffer.FindFirst() then;
    end;

    /// <summary>Los Cód. Estado que aparecieron, en orden alfabético. Son las columnas de la matriz.</summary>
    procedure Estados(var Lista: List of [Code[20]])
    begin
        Lista := FEstados;
    end;

    /// <summary>Días que el empleado pasó en ese estado dentro del rango.</summary>
    procedure DiasDe(EmpNo: Code[20]; CodEstado: Code[20]): Integer
    var
        Clave: Text;
    begin
        Clave := EmpNo + '~' + CodEstado;
        if FDiasEstado.ContainsKey(Clave) then
            exit(FDiasEstado.Get(Clave));
        exit(0);
    end;

    /// <summary>Los tramos sin liquidar del empleado, en texto legible.</summary>
    procedure DetalleTramos(EmpNo: Code[20]): Text
    begin
        if FTramos.ContainsKey(EmpNo) then
            exit(FTramos.Get(EmpNo));
        exit('');
    end;

    /// <remarks>
    /// Recorre día por día en vez de intersecar intervalos. Son a lo sumo unos cientos de días por
    /// empleado, y el código se lee de una: para cada día se pregunta qué estado tenía y si alguna
    /// liquidación lo cubre. Con intervalos habría que resolver solapamientos —dos mareas que se
    /// pisan, una marea a caballo de dos meses, un mensual encima de un cierre— y ahí es donde esta
    /// clase de informe se equivoca sin que se note.
    /// </remarks>
    local procedure ArmarEmpleado(var Buffer: Record "Cobertura Liq. Buffer" temporary; EmpNo: Code[20])
    var
        Emp: Record Employee;
        Liq: Record "Liquidación";
        Estado: Record "Estado Empleado";
        Cubierto: Dictionary of [Integer, Boolean];
        EnBorrador: Dictionary of [Integer, Boolean];
        EstadoDelDia: Dictionary of [Integer, Code[20]];
        d: Date;
        Dia: Date;
        Alta: Date;
        Baja: Date;
        InicioHueco: Date;
        FinHueco: Date;
        Detalle: TextBuilder;
        CodEstado: Code[20];
        Tramos: Integer;
        DiasRango: Integer;
        ConEstado: Integer;
        Liquidados: Integer;
        SinLiquidar: Integer;
        DiasBorrador: Integer;
    begin
        if Emp.Get(EmpNo) then;

        // El techo es el alta y la baja: quien entró el 15 no debe la primera quincena, y quien se
        // fue en junio no debe julio. Sin ese recorte el informe marcaría en falta a todo el que no
        // haya estado el rango entero.
        Alta := FDesde;
        if (Emp."Employment Date" <> 0D) and (Emp."Employment Date" > Alta) then
            Alta := Emp."Employment Date";
        Baja := FHasta;
        if (Emp."Termination Date" <> 0D) and (Emp."Termination Date" < Baja) then
            Baja := Emp."Termination Date";

        // Una liquidación en Borrador NO cubre nada: existe el documento, pero no hay importes ni
        // líneas. Se la registra aparte para poder decir "la liquidación está creada, falta
        // calcularla", que es un faltante con otra solución que "no existe".
        Liq.SetCurrentKey("No. Empleado", "No. Proyecto", "Cód. Período", "Cód. Tipo Liq.");
        Liq.SetRange("No. Empleado", EmpNo);
        Liq.SetFilter("Cobertura Hasta", '>=%1', FDesde);
        Liq.SetLoadFields("Cobertura Desde", "Cobertura Hasta", Estado);
        if Liq.FindSet() then
            repeat
                if Liq."Cobertura Desde" <> 0D then
                    for d := Liq."Cobertura Desde" to Liq."Cobertura Hasta" do
                        if Liq.Estado = Liq.Estado::Borrador then
                            EnBorrador.Set(DiaEntero(d), true)
                        else
                            Cubierto.Set(DiaEntero(d), true);
            until Liq.Next() = 0;

        Estado.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
        Estado.SetRange("No. Empleado", EmpNo);
        Estado.SetFilter("Fecha Inicio", '<=%1', FHasta);
        Estado.SetLoadFields("Fecha Inicio", "Fecha Fin", "Cód. Estado");
        if Estado.FindSet() then
            repeat
                for d := Estado."Fecha Inicio" to FinDeEstado(Estado, FHasta) do
                    if (d >= Alta) and (d <= Baja) then
                        EstadoDelDia.Set(DiaEntero(d), Estado."Cód. Estado");
            until Estado.Next() = 0;

        for Dia := Alta to Baja do begin
            DiasRango += 1;
            if EstadoDelDia.ContainsKey(DiaEntero(Dia)) then begin
                ConEstado += 1;
                CodEstado := EstadoDelDia.Get(DiaEntero(Dia));
                SumarDia(EmpNo, CodEstado);
                if Cubierto.ContainsKey(DiaEntero(Dia)) then
                    Liquidados += 1
                else begin
                    SinLiquidar += 1;
                    if EnBorrador.ContainsKey(DiaEntero(Dia)) then
                        DiasBorrador += 1;
                    if InicioHueco = 0D then
                        InicioHueco := Dia;
                    FinHueco := Dia;
                end;
            end;
            // Cierra el tramo en cuanto el día deja de estar sin liquidar. El detalle dice "del 21 al
            // 31", que es como se revisa; una entrada por día lo volvería ilegible.
            if (InicioHueco <> 0D) and (Cubierto.ContainsKey(DiaEntero(Dia)) or not EstadoDelDia.ContainsKey(DiaEntero(Dia))) then begin
                AgregarTramo(Detalle, InicioHueco, FinHueco, EstadoDelDia);
                Tramos += 1;
                InicioHueco := 0D;
            end;
        end;
        if InicioHueco <> 0D then begin
            AgregarTramo(Detalle, InicioHueco, FinHueco, EstadoDelDia);
            Tramos += 1;
        end;

        Buffer.Init();
        Buffer."No. Empleado" := EmpNo;
        Buffer."Nombre Empleado" := CopyStr(Emp.FullName(), 1, MaxStrLen(Buffer."Nombre Empleado"));
        Buffer."Fecha Alta" := Emp."Employment Date";
        Buffer."Fecha Baja" := Emp."Termination Date";
        Buffer."Cód. Convenio" := Emp."Cód. Convenio";
        Buffer."Cód. Categoría" := Emp."Cód. Categoría";
        Buffer."Días del Rango" := DiasRango;
        Buffer."Días con Estado" := ConEstado;
        Buffer."Días Liquidados" := Liquidados;
        Buffer."Días sin Liquidar" := SinLiquidar;
        Buffer."Días en Borrador" := DiasBorrador;
        Buffer."Tramos sin Liquidar" := Tramos;
        Buffer."Detalle Sin Liquidar" := CopyStr(Detalle.ToText(), 1, MaxStrLen(Buffer."Detalle Sin Liquidar"));
        Buffer.Insert();
        FTramos.Set(EmpNo, Detalle.ToText());
    end;

    local procedure AgregarTramo(var Detalle: TextBuilder; Desde: Date; Hasta: Date; var EstadoDelDia: Dictionary of [Integer, Code[20]])
    var
        CodEstado: Code[20];
    begin
        if EstadoDelDia.ContainsKey(DiaEntero(Desde)) then
            CodEstado := EstadoDelDia.Get(DiaEntero(Desde));
        if Detalle.Length() > 0 then
            Detalle.Append('; ');
        if Desde = Hasta then
            Detalle.Append(Format(Desde))
        else
            Detalle.Append(Format(Desde) + '..' + Format(Hasta));
        if CodEstado <> '' then
            Detalle.Append(' ' + CodEstado);
    end;

    local procedure SumarDia(EmpNo: Code[20]; CodEstado: Code[20])
    var
        Clave: Text;
    begin
        Clave := EmpNo + '~' + CodEstado;
        if FDiasEstado.ContainsKey(Clave) then
            FDiasEstado.Set(Clave, FDiasEstado.Get(Clave) + 1)
        else
            FDiasEstado.Add(Clave, 1);
        if not FEstados.Contains(CodEstado) then
            FEstados.Add(CodEstado);
    end;

    local procedure OrdenarEstados()
    var
        Ordenados: List of [Code[20]];
        Cod: Code[20];
        Menor: Code[20];
        i: Integer;
    begin
        while FEstados.Count() > 0 do begin
            Menor := '';
            foreach Cod in FEstados do
                if (Menor = '') or (Cod < Menor) then
                    Menor := Cod;
            Ordenados.Add(Menor);
            for i := 1 to FEstados.Count() do
                if FEstados.Get(i) = Menor then begin
                    FEstados.RemoveAt(i);
                    break;
                end;
        end;
        FEstados := Ordenados;
    end;

    local procedure FinDeEstado(Estado: Record "Estado Empleado"; Tope: Date): Date
    begin
        // Estado abierto = sigue vigente: se corta en el tope de la consulta y no en el infinito.
        if (Estado."Fecha Fin" = 0D) or (Estado."Fecha Fin" > Tope) then
            exit(Tope);
        exit(Estado."Fecha Fin");
    end;

    // Los días como entero para poder usarlos de clave. El origen es arbitrario: sólo importa que sea
    // el mismo para todos los diccionarios que se comparan.
    local procedure DiaEntero(D: Date): Integer
    begin
        exit(D - DMY2Date(1, 1, 2000));
    end;

    /// <summary>
    /// Completa "Cobertura Desde/Hasta" en las liquidaciones que todavía no las tienen. Devuelve
    /// cuántas actualizó.
    /// </summary>
    /// <remarks>
    /// Los dos campos se empezaron a guardar al calcular, así que todo lo liquidado antes los tiene
    /// en blanco. Este control los necesita para saber qué días cubre cada una, y sin el relleno
    /// leería que no cubren ninguno: marcaría a toda la empresa como no liquidada.
    ///
    /// La cobertura se deriva del período, el tipo y el proyecto, que no cambian al recalcular: se
    /// puede completar sin volver a liquidar nada y sin tocar un solo importe.
    /// </remarks>
    procedure CompletarCoberturas(): Integer
    var
        Liq: Record "Liquidación";
        Pendientes: List of [Code[20]];
        NoLiq: Code[20];
        Desde: Date;
        Hasta: Date;
        Actualizadas: Integer;
    begin
        // Primero se juntan las claves y DESPUÉS se escribe. El bucle no puede recorrer un filtro
        // sobre "Cobertura Desde" y a la vez completar ese mismo campo: en cuanto el primer registro
        // deja de valer 0D se sale del conjunto filtrado, el cursor se queda sin lugar de dónde
        // seguir y el proceso corta después de uno solo — que es exactamente lo que pasaba: el
        // contador de pendientes no bajaba y el control mostraba a toda la empresa sin liquidar.
        Liq.SetRange("Cobertura Desde", 0D);
        Liq.SetLoadFields("No.");
        if Liq.FindSet() then
            repeat
                Pendientes.Add(Liq."No.");
            until Liq.Next() = 0;

        foreach NoLiq in Pendientes do
            if Liq.Get(NoLiq) then begin
                Liq.Cobertura(Desde, Hasta);
                if Desde <> 0D then begin
                    Liq."Cobertura Desde" := Desde;
                    Liq."Cobertura Hasta" := Hasta;
                    Liq.Modify();
                    Actualizadas += 1;
                end;
            end;
        exit(Actualizadas);
    end;

    /// <summary>Cuántas liquidaciones siguen sin fechas de cobertura.</summary>
    procedure PendientesDeCobertura(): Integer
    var
        Liq: Record "Liquidación";
    begin
        Liq.SetRange("Cobertura Desde", 0D);
        exit(Liq.Count());
    end;

    var
        FDiasEstado: Dictionary of [Text, Integer];
        FEstados: List of [Code[20]];
        FTramos: Dictionary of [Code[20], Text];
        FDesde: Date;
        FHasta: Date;
}
