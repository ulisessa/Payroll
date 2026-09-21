namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

/// <summary>
/// Aplica la carga inicial de francos: convierte cada fila en un lote del ledger, y sabe deshacerlo.
/// </summary>
/// <remarks>
/// El ledger de francos vive en Línea Liquidación y no tiene tabla propia, así que un saldo inicial
/// no se puede "escribir" en ningún lado: hay que generarlo como lotes. Este proceso crea UNA
/// liquidación por tripulante —el continente— y le cuelga una línea por cada fila de la carga.
///
/// Esa liquidación no se calcula ni se recalcula nunca: nace Aprobada, con importes en cero, y existe
/// solamente para que las líneas tengan cabecera. Si quedara en Borrador, el primer Calcular por lote
/// que la tomara le borraría las líneas —DeleteLineas arranca por ahí— y el saldo inicial de toda la
/// empresa desaparecería sin que nadie lo notara hasta que alguien pidiera francos.
///
/// La línea lleva su PROPIA "Fecha Liquidación", la del lote, que puede no ser la de la cabecera: es
/// la fecha por la que el FIFO ordena los lotes, y ponerle a todos la fecha de la carga los volvería
/// indistinguibles justo en lo que decide a qué precio se paga el próximo franco.
/// </remarks>
codeunit 110029 "Saldo Inicial Francos Liq."
{
    Access = Public;

    /// <summary>
    /// Genera los lotes de las filas todavía no aplicadas. Devuelve cuántas se aplicaron.
    /// </summary>
    procedure Aplicar(var Carga: Record "Saldo Inicial Francos Liq."): Integer
    var
        Concepto: Record "Concepto Liquidación";
        Empleados: List of [Code[20]];
        EmpNo: Code[20];
        Aplicadas: Integer;
    begin
        if not ConceptoDevengo(Concepto) then
            Error(ErrSinConceptoDevengo);
        VerificarPeriodo();

        Carga.SetRange(Aplicado, false);
        if not Carga.FindSet() then
            Error(ErrNadaQueAplicar);
        repeat
            ValidarFila(Carga);
            if not Empleados.Contains(Carga."No. Empleado") then
                Empleados.Add(Carga."No. Empleado");
        until Carga.Next() = 0;

        // Se valida TODO antes de escribir nada. Aplicar la mitad de una carga y cortar en la fila
        // mala deja el ledger a medio armar, que es peor que no haber empezado.
        foreach EmpNo in Empleados do
            Aplicadas += AplicarEmpleado(Carga, Concepto, EmpNo);

        Carga.SetRange(Aplicado);
        exit(Aplicadas);
    end;

    /// <summary>
    /// Borra los lotes generados por las filas indicadas y las vuelve a dejar editables.
    /// </summary>
    /// <remarks>
    /// Borra la línea por su clave exacta —la que quedó anotada al aplicar— y no "los francos del
    /// tripulante": si alguien ya devengó francos liquidando, ésos no los puso este proceso y no le
    /// corresponde tocarlos. Cuando una liquidación generada se queda sin líneas, se borra también:
    /// una cabecera vacía en la lista de liquidaciones es ruido que nadie sabe de dónde salió.
    /// </remarks>
    procedure Revertir(var Carga: Record "Saldo Inicial Francos Liq."): Integer
    var
        Lin: Record "Línea Liquidación";
        Liq: Record "Liquidación";
        Restantes: Record "Línea Liquidación";
        Generadas: List of [Code[20]];
        NoLiq: Code[20];
        Revertidas: Integer;
    begin
        Carga.SetRange(Aplicado, true);
        if not Carga.FindSet() then
            Error(ErrNadaQueRevertir);
        repeat
            if Lin.Get(Carga."No. Liquidación Generada", Carga."No. Línea Generada") then
                Lin.Delete(true);
            if not Generadas.Contains(Carga."No. Liquidación Generada") then
                Generadas.Add(Carga."No. Liquidación Generada");
            Carga.Aplicado := false;
            Carga."No. Liquidación Generada" := '';
            Carga."No. Línea Generada" := 0;
            Carga.Modify();
            Revertidas += 1;
        until Carga.Next() = 0;
        Carga.SetRange(Aplicado);

        foreach NoLiq in Generadas do begin
            Restantes.SetRange("No. Liquidación", NoLiq);
            if Restantes.IsEmpty() then
                if Liq.Get(NoLiq) then begin
                    Liq.Estado := Liq.Estado::Borrador;
                    Liq.Modify();
                    Liq.Delete(true);
                end;
        end;
        exit(Revertidas);
    end;

    local procedure AplicarEmpleado(var Carga: Record "Saldo Inicial Francos Liq."; Concepto: Record "Concepto Liquidación"; EmpNo: Code[20]): Integer
    var
        Fila: Record "Saldo Inicial Francos Liq.";
        Liq: Record "Liquidación";
        Aplicadas: Integer;
    begin
        CrearCabecera(Liq, EmpNo);

        Fila.SetRange(Aplicado, false);
        Fila.SetRange("No. Empleado", EmpNo);
        if Fila.FindSet() then
            repeat
                Fila."No. Línea Generada" := CrearLote(Liq, Concepto, Fila);
                Fila."No. Liquidación Generada" := Liq."No.";
                Fila.Aplicado := true;
                Fila.Modify();
                Aplicadas += 1;
            until Fila.Next() = 0;

        // Aprobada al final y no al crearla: mientras se le cuelgan las líneas tiene que poder
        // recibirlas, y una vez cerrada ningún proceso del motor la vuelve a tocar.
        Liq.Estado := Liq.Estado::Aprobada;
        Liq.Modify();
        exit(Aplicadas);
    end;

    local procedure CrearCabecera(var Liq: Record "Liquidación"; EmpNo: Code[20])
    var
        Emp: Record Employee;
        ProcLote: Codeunit "Proceso Liq. Por Lote";
    begin
        Liq.Init();
        Liq."No." := ProcLote.NextLiqNo();
        Liq."No. Empleado" := EmpNo;
        if Emp.Get(EmpNo) then
            Liq."Nombre Empleado" := CopyStr(Emp.FullName(), 1, MaxStrLen(Liq."Nombre Empleado"));
        Liq."Cód. Período" := FPeriodo;
        Liq."Cód. Tipo Liq." := FTipoLiq;
        Liq."Fecha Liquidación" := FFechaCabecera;
        Liq.Estado := Liq.Estado::Borrador;
        // El par de la cabecera no se usa para valuar nada acá —cada lote lleva el suyo— pero se
        // resuelve igual para que la liquidación no quede sin encuadre en las listas.
        Liq.ResolverParDeAtributos();
        Liq.Insert(true);
    end;

    local procedure CrearLote(var Liq: Record "Liquidación"; Concepto: Record "Concepto Liquidación"; Fila: Record "Saldo Inicial Francos Liq."): Integer
    var
        Lin: Record "Línea Liquidación";
    begin
        Lin.Init();
        Lin."No. Liquidación" := Liq."No.";
        Lin."No. Empleado" := Liq."No. Empleado";
        Lin."Cód. Período" := Liq."Cód. Período";
        Lin."Cód. Tipo Liq." := Liq."Cód. Tipo Liq.";
        Lin."Cód. Concepto" := Concepto.Código;
        Lin."Descripción Concepto" := Concepto.Descripción;
        Lin."Nombre Impresión" := Concepto."Nombre Impresión";
        Lin."Tipo Concepto" := Concepto."Tipo Concepto";
        Lin."Grupo Costo Laboral" := Concepto."Grupo Costo Laboral";
        Lin."Orden Cálculo" := Concepto."Orden Cálculo";
        Lin."Vigencia Concepto" := Concepto."Vigencia Desde";
        Lin."Es Devengo" := true;
        Lin.Estado := Lin.Estado::Aprobada;
        // El par DEL LOTE, que es todo el punto de la carga: estos francos se van a pagar al valor de
        // esta categoría aunque el tripulante hoy esté encuadrado en otra.
        Lin."Cód. Convenio" := Fila."Cód. Convenio";
        Lin."Cód. Categoría" := Fila."Cód. Categoría";
        // La fecha del LOTE, no la de la cabecera: es por la que el FIFO los ordena.
        Lin."Fecha Liquidación" := Fila."Fecha Devengo";
        Lin.Cantidad := Fila.Días;
        Lin."Unidad Cantidad" := Concepto."Unidad Cantidad";
        // Importe cero a propósito: un lote no es plata todavía. El franco se valúa el día que se
        // consume, con el VALOR_FRANCO de su categoría vigente entonces. Ponerle un importe acá lo
        // haría figurar como un haber pagado que nadie cobró.
        Lin.Importe := 0;
        Lin."Fórmula Aplicada" := TxtOrigenCarga;
        Lin."Fórmula Evaluada" := CopyStr(StrSubstNo(TxtOrigenDetalle, Fila.Días, Fila."Cód. Convenio", Fila."Cód. Categoría", Fila."Fecha Devengo"), 1, MaxStrLen(Lin."Fórmula Evaluada"));
        Lin.Insert(true);
        exit(Lin."No. Línea");
    end;

    local procedure ValidarFila(var Carga: Record "Saldo Inicial Francos Liq.")
    var
        Emp: Record Employee;
        CatCCT: Record "Categoría CCT";
    begin
        if Carga.Días <= 0 then
            Error(ErrDiasCero, Carga."No. Empleado", Carga."Cód. Categoría");
        if Carga."Fecha Devengo" = 0D then
            Error(ErrSinFecha, Carga."No. Empleado");
        if not Emp.Get(Carga."No. Empleado") then
            Error(ErrSinEmpleado, Carga."No. Empleado");
        if not CatCCT.Get(Carga."Cód. Convenio", Carga."Cód. Categoría") then
            Error(ErrSinCategoria, Carga."Cód. Convenio", Carga."Cód. Categoría", Carga."No. Empleado");
    end;

    /// <summary>Configura período, tipo de liquidación y fecha de las cabeceras. Obligatorio antes de Aplicar.</summary>
    procedure SetDestino(CodPeriodo: Code[10]; TipoLiq: Code[20]; FechaCabecera: Date)
    begin
        FPeriodo := CodPeriodo;
        FTipoLiq := TipoLiq;
        FFechaCabecera := FechaCabecera;
    end;

    local procedure VerificarPeriodo()
    var
        Periodo: Record "Período Liquidación";
        TipoLiq: Record "Tipo Liquidación";
    begin
        if FPeriodo = '' then
            Error(ErrSinPeriodo);
        if not Periodo.Get(FPeriodo) then
            Error(ErrSinPeriodo);
        if FTipoLiq = '' then
            Error(ErrSinTipoLiq);
        if not TipoLiq.Get(FTipoLiq) then
            Error(ErrSinTipoLiq);
        if FFechaCabecera = 0D then
            FFechaCabecera := Periodo."Fecha Hasta";
        if FFechaCabecera = 0D then
            FFechaCabecera := WorkDate();
    end;

    /// <remarks>
    /// Si hay más de un concepto marcado como Devengo la carga no puede elegir por su cuenta cuál es
    /// el bueno: los lotes de uno y de otro conviven en el mismo ledger y el error recién se vería
    /// meses después, en un franco pagado al precio equivocado.
    /// </remarks>
    procedure ConceptoDevengo(var Concepto: Record "Concepto Liquidación"): Boolean
    var
        Codigos: List of [Code[20]];
    begin
        Concepto.Reset();
        Concepto.SetRange("Rol Franco", "Rol Franco Liq."::Devengo);
        if not Concepto.FindSet() then
            exit(false);
        repeat
            if not Codigos.Contains(Concepto.Código) then
                Codigos.Add(Concepto.Código);
        until Concepto.Next() = 0;
        if Codigos.Count() > 1 then
            Error(ErrVariosConceptos, Codigos.Count());
        Concepto.FindLast();
        exit(true);
    end;

    var
        FPeriodo: Code[10];
        FTipoLiq: Code[20];
        FFechaCabecera: Date;
        TxtOrigenCarga: Label 'Carga de saldo inicial de francos', Locked = false;
        TxtOrigenDetalle: Label '%1 día(s) de franco devengados como %2 / %3 el %4, cargados como saldo inicial.', Comment = '%1=días, %2=convenio, %3=categoría, %4=fecha';
        ErrSinConceptoDevengo: Label 'No hay ningún concepto marcado con Rol Franco = Devengo. Marcá el concepto que devenga francos antes de cargar el saldo inicial.';
        ErrVariosConceptos: Label 'Hay %1 conceptos marcados con Rol Franco = Devengo. La carga inicial no puede decidir con cuál generar los lotes: dejá uno solo.', Comment = '%1=cantidad';
        ErrNadaQueAplicar: Label 'No hay filas pendientes de aplicar.';
        ErrNadaQueRevertir: Label 'No hay filas aplicadas para revertir.';
        ErrDiasCero: Label 'La carga de %1 en la categoría %2 tiene días en cero o negativos.', Comment = '%1=empleado, %2=categoría';
        ErrSinFecha: Label 'La carga de %1 no tiene fecha de devengo. Es la que decide el orden FIFO en que se van a consumir esos francos.', Comment = '%1=empleado';
        ErrSinEmpleado: Label 'El empleado %1 no existe.', Comment = '%1=No. empleado';
        ErrSinCategoria: Label 'La categoría %1 / %2 de la carga de %3 no existe en el convenio.', Comment = '%1=convenio, %2=categoría, %3=empleado';
        ErrSinPeriodo: Label 'Elegí el período de liquidación en el que se van a crear las cabeceras del saldo inicial.';
        ErrSinTipoLiq: Label 'Elegí el tipo de liquidación con el que se van a crear las cabeceras del saldo inicial. Conviene uno propio (por ejemplo SALDO INICIAL) para poder distinguirlas después.';
}
