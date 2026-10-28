namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.Projects.Project.Job;

/// <summary>
/// Calcula una liquidación de prueba y la revierte entera: lo único que sobrevive es lo que el cálculo dejó anotado en esta instancia.
/// </summary>
/// <remarks>
/// La usa el control previo para encontrar lo que sólo aparece calculando: un precio que una fórmula leyó sin fila (vale cero y no da
/// error), o un error del cálculo. Se invoca con Codeunit.Run sobre la variable: OnRun arma una cabecera, corre el motor completo
/// (LiquidarRecord, sin registro de procesos ni Commit) y termina SIEMPRE con un Error, que revierte cabecera, líneas, resumen, uso
/// de parámetros y movimientos de francos. Las variables de la instancia no se revierten, y de ahí se leen los resultados.
///
/// Requiere que quien llama no tenga escrituras pendientes (lo exige Codeunit.Run con valor de retorno). El control previo sólo
/// escribe tablas temporales, así que no hace falta ningún Commit.
/// </remarks>
codeunit 110095 "Simulación Liq."
{
    trigger OnRun()
    var
        Liq: Record "Liquidación";
        Motor: Codeunit "Motor Liquidación";
    begin
        FCompleta := false;
        Clear(FPreciosFaltantes);
        FAdvertencias := '';
        ArmarCabecera(Liq);
        Motor.LiquidarRecord(Liq);
        Motor.GetPreciosFaltantes(FPreciosFaltantes);
        FAdvertencias := Motor.GetAdvertencias();
        FCompleta := true;
        // Revierte todo lo que escribió el cálculo. No es un error: es la forma de no dejar rastro.
        Error(MarcaSimulacionTxt);
    end;

    /// <summary>Qué liquidación simular. Va antes de Run.</summary>
    procedure Preparar(Empleado: Code[20]; Proyecto: Code[20]; TipoLiq: Code[20]; CodPeriodo: Code[10])
    begin
        FEmpleado := Empleado;
        FProyecto := Proyecto;
        FTipoLiq := TipoLiq;
        FCodPeriodo := CodPeriodo;
        FCompleta := false;
        Clear(FPreciosFaltantes);
        FAdvertencias := '';
    end;

    /// <summary>True si el cálculo llegó al final. Si es false, el motivo está en GetLastErrorText() de quien llamó a Run.</summary>
    procedure Completa(): Boolean
    begin
        exit(FCompleta);
    end;

    procedure GetPreciosFaltantes(var Faltantes: Dictionary of [Text, Text])
    begin
        Faltantes := FPreciosFaltantes;
    end;

    procedure GetAdvertencias(): Text
    begin
        exit(FAdvertencias);
    end;

    // La misma cabecera que arma el creador por lotes (Proceso Liq. Por Lote): fecha de liquidación al arribo en las de arribo y al
    // fin del período en las demás, y el par convenio/categoría de los atributos. El número es fijo: la fila no llega a existir.
    local procedure ArmarCabecera(var Liq: Record "Liquidación")
    var
        Emp: Record Employee;
        Periodo: Record "Período Liquidación";
        Job: Record Job;
        TipoLiqRec: Record "Tipo Liquidación";
    begin
        Periodo.Get(FCodPeriodo);
        Liq.Init();
        Liq."No." := NumeroSimulacionTxt;
        Liq."No. Empleado" := FEmpleado;
        if Emp.Get(FEmpleado) then
            Liq."Nombre Empleado" := CopyStr(Emp."First Name" + ' ' + Emp."Last Name", 1, MaxStrLen(Liq."Nombre Empleado"));
        Liq."No. Proyecto" := FProyecto;
        Liq."Cód. Período" := FCodPeriodo;
        Liq."Cód. Tipo Liq." := FTipoLiq;
        if TipoLiqRec.EsArribo(FTipoLiq) and Job.Get(FProyecto) and (Job."Ending Date" <> 0D) then
            Liq."Fecha Liquidación" := Job."Ending Date"
        else
            Liq."Fecha Liquidación" := Periodo."Fecha Hasta";
        Liq.Estado := Liq.Estado::Borrador;
        Liq.ResolverParDeAtributos();
        Liq.Insert(true);
    end;

    var
        FEmpleado: Code[20];
        FProyecto: Code[20];
        FTipoLiq: Code[20];
        FCodPeriodo: Code[10];
        FCompleta: Boolean;
        FPreciosFaltantes: Dictionary of [Text, Text];
        FAdvertencias: Text;
        MarcaSimulacionTxt: Label 'Simulación terminada: se revierte el cálculo de prueba.';
        NumeroSimulacionTxt: Label 'SIMULACION', Locked = true;
}
