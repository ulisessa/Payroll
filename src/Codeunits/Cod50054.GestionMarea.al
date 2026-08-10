namespace UAS.Payroll;

using Microsoft.Projects.Project.Job;
using Microsoft.Finance.Dimension;
using Microsoft.Finance.GeneralLedger.Setup;

codeunit 50054 "Gestión Marea"
{
    // Creates the next marea from a closed one: copies the project header + tasks + default dimensions +
    // crew, increments the "Marea" global dimension (2) by one, and starts it at the closed marea's arrival.

    procedure CrearNuevaMarea(SourceJob: Record Job): Code[20]
    var
        NewJob: Record Job;
        NuevoNo: Code[20];
        NuevaMarea: Code[20];
    begin
        SourceJob.TestField("No.");
        // The project code ends in the marea number → increment it preserving format/length (IncStr).
        NuevoNo := CopyStr(IncStr(SourceJob."No."), 1, MaxStrLen(NuevoNo));
        if NuevoNo = '' then
            Error(ErrNoDerivar, SourceJob."No.");
        if ExisteJob(NuevoNo) then
            Error(ErrYaExiste, NuevoNo);

        NewJob := SourceJob;
        NewJob."No." := NuevoNo;
        NewJob.Status := NewJob.Status::Open;
        NewJob."Ending Date" := 0D;
        // New marea starts the day after the previous one's arrival.
        if SourceJob."Ending Date" <> 0D then
            NewJob."Starting Date" := SourceJob."Ending Date" + 1;

        // Can't open a marea inside a period that already has (non-draft) liquidations.
        ValidarPeriodoNoCalculado(NewJob."Starting Date");

        NewJob."Hora de zarpada" := 0T;
        NewJob."Hora ingreso a puerto" := 0T;

        // Set the incremented marea shortcut dimension directly (no Validate) to avoid the "¿actualizar
        // líneas?" prompt and the default-dimension-for-a-not-yet-inserted-job error. The matching Default
        // Dimension record is updated when copying dimensions below.
        NuevaMarea := IncrementarMarea(SourceJob."Global Dimension 2 Code");
        if (NuevaMarea <> '') and (NuevaMarea <> SourceJob."Global Dimension 2 Code") then
            NewJob."Global Dimension 2 Code" := NuevaMarea;

        NewJob.Insert(true);

        // Copy dimensions BEFORE tasks: changing a dimension after lines exist triggers the "¿actualizar
        // las líneas?" prompt.
        CopiarDefaultDimensions(SourceJob."No.", NuevoNo, NuevaMarea);
        CopiarTareas(SourceJob."No.", NuevoNo);
        CopiarPersonal(SourceJob."No.", NewJob);
        exit(NuevoNo);
    end;

    local procedure ExisteJob(No: Code[20]): Boolean
    var
        Job: Record Job;
    begin
        exit(Job.Get(No));
    end;

    // Blocks creating a marea whose start falls in a period that already has non-draft liquidations —
    // those states/dates are already settled and must not be altered by a new project.
    local procedure ValidarPeriodoNoCalculado(FechaInicio: Date)
    var
        Periodo: Record "Período Liquidación";
        Liq: Record "Liquidación";
    begin
        if FechaInicio = 0D then exit;
        Periodo.SetFilter("Fecha Desde", '<=%1', FechaInicio);
        Periodo.SetFilter("Fecha Hasta", '>=%1', FechaInicio);
        if not Periodo.FindFirst() then exit;

        Liq.SetRange("Cód. Período", Periodo.Código);
        Liq.SetFilter(Estado, '<>%1', Liq.Estado::Borrador);
        if not Liq.IsEmpty() then
            Error(ErrPeriodoCalculado, Periodo.Código, FechaInicio);
    end;

    // Increments the marea code preserving its format/length (IncStr); creates the new dimension value
    // if it does not exist. Codes with no number are kept as-is.
    local procedure IncrementarMarea(Actual: Code[20]): Code[20]
    var
        Nuevo: Code[20];
    begin
        if Actual = '' then exit('');
        Nuevo := CopyStr(IncStr(Actual), 1, MaxStrLen(Nuevo));
        if Nuevo = '' then exit(Actual);
        AsegurarDimValueMarea(Nuevo, Actual);
        exit(Nuevo);
    end;

    local procedure AsegurarDimValueMarea(NuevoCod: Code[20]; ModeloCod: Code[20])
    var
        GLSetup: Record "General Ledger Setup";
        DimVal: Record "Dimension Value";
        Modelo: Record "Dimension Value";
        DimCod: Code[20];
    begin
        GLSetup.Get();
        DimCod := GLSetup."Global Dimension 2 Code";
        if DimCod = '' then exit;
        if DimVal.Get(DimCod, NuevoCod) then exit;
        if not Modelo.Get(DimCod, ModeloCod) then exit;
        DimVal := Modelo;
        DimVal.Code := NuevoCod;
        DimVal.Name := CopyStr('Marea ' + NuevoCod, 1, MaxStrLen(DimVal.Name));
        DimVal.Insert(true);
    end;

    local procedure CopiarTareas(SourceNo: Code[20]; TargetNo: Code[20])
    var
        Src: Record "Job Task";
        Tgt: Record "Job Task";
    begin
        Src.SetRange("Job No.", SourceNo);
        if Src.FindSet() then
            repeat
                Tgt := Src;
                Tgt."Job No." := TargetNo;
                if Tgt.Insert(true) then;
            until Src.Next() = 0;
    end;

    local procedure CopiarDefaultDimensions(SourceNo: Code[20]; TargetNo: Code[20]; NuevaMarea: Code[20])
    var
        Src: Record "Default Dimension";
        Tgt: Record "Default Dimension";
        GLSetup: Record "General Ledger Setup";
        DimCod: Code[20];
    begin
        GLSetup.Get();
        DimCod := GLSetup."Global Dimension 2 Code";
        Src.SetRange("Table ID", Database::Job);
        Src.SetRange("No.", SourceNo);
        if Src.FindSet() then
            repeat
                Tgt := Src;
                Tgt."No." := TargetNo;
                // Keep the marea default dimension in sync with the incremented header value.
                if (DimCod <> '') and (NuevaMarea <> '') and (Tgt."Dimension Code" = DimCod) then
                    Tgt."Dimension Value Code" := NuevaMarea;
                if Tgt.Insert(true) then;
            until Src.Next() = 0;
    end;


    local procedure CopiarPersonal(SourceNo: Code[20]; var TargetJob: Record Job)
    var
        Src: Record "Personal Proyecto";
        Tgt: Record "Personal Proyecto";
    begin
        Src.SetRange("No. Proyecto", SourceNo);
        if Src.FindSet() then
            repeat
                if not Tgt.Get(Src."No. Empleado", TargetJob."No.") then begin
                    Tgt.Init();
                    Tgt."No. Empleado" := Src."No. Empleado";
                    Tgt."No. Proyecto" := TargetJob."No.";
                    Tgt."Cód. Convenio" := Src."Cód. Convenio";
                    Tgt."Cód. Categoría" := Src."Cód. Categoría";
                    Tgt."Rol en Proyecto" := Src."Rol en Proyecto";
                    Tgt.Observaciones := Src.Observaciones;
                    // Re-derives Buque/Marea and defaults dates from the new project.
                    Tgt.Validate("No. Proyecto");
                    Tgt.Insert(true);
                end;
            until Src.Next() = 0;
    end;

    var
        ErrNoDerivar: Label 'No se pudo derivar el número de la nueva marea a partir de %1. El código debe terminar en un número (la marea) para incrementarlo.';
        ErrYaExiste: Label 'Ya existe un proyecto con el número %1.';
        ErrPeriodoCalculado: Label 'No se puede crear la marea: el período %1 (que contiene la fecha de inicio %2) ya tiene liquidaciones calculadas. Revertí esas liquidaciones o iniciá la marea en un período no liquidado.';
}
