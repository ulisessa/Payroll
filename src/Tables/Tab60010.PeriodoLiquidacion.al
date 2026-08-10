namespace UAS.Payroll;

using Microsoft.Foundation.Calendar;

table 60010 "Período Liquidación"
{
    Caption = 'Período Liquidación';
    DataClassification = CustomerContent;
    LookupPageId = "Períodos Liquidación";
    DrillDownPageId = "Períodos Liquidación";

    fields
    {
        field(1; Código; Code[10])
        {
            Caption = 'Código';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(2; Año; Integer)
        {
            Caption = 'Año';
            DataClassification = CustomerContent;
            MinValue = 2000;
        }
        field(3; Mes; Integer)
        {
            Caption = 'Mes';
            DataClassification = CustomerContent;
            MinValue = 1;
            MaxValue = 12;
            trigger OnValidate()
            begin
                if (Rec.Mes >= 1) and (Rec.Mes <= 12) and (Rec.Año >= 2000) then begin
                    if Rec."Fecha Desde" = 0D then
                        Rec."Fecha Desde" := DMY2Date(1, Rec.Mes, Rec.Año);
                    if Rec."Fecha Hasta" = 0D then
                        Rec."Fecha Hasta" := CalcDate('<CM>', Rec."Fecha Desde");
                end;
            end;
        }
        field(4; "Fecha Desde"; Date)
        {
            Caption = 'Fecha Desde';
            DataClassification = CustomerContent;
        }
        field(5; "Fecha Hasta"; Date)
        {
            Caption = 'Fecha Hasta';
            DataClassification = CustomerContent;
        }
        field(6; Estado; Enum "Estado Período Liq.")
        {
            Caption = 'Estado';
            DataClassification = CustomerContent;
        }
        field(7; "Fecha Cierre"; Date)
        {
            Caption = 'Fecha Cierre';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(8; "Usuario Cierre"; Code[50])
        {
            Caption = 'Usuario Cierre';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
        }
        field(9; "Cant. Liquidaciones"; Integer)
        {
            Caption = 'Cant. Liquidaciones';
            FieldClass = FlowField;
            CalcFormula = Count(Liquidación WHERE("Cód. Período" = FIELD(Código)));
            Editable = false;
        }
        field(10; "Cód. Calendario"; Code[10])
        {
            Caption = 'Cód. Calendario';
            DataClassification = CustomerContent;
            TableRelation = "Base Calendar";
            // Optional. When set, DIAS_HAB respects this calendar's nonworking days.
            // When blank, DIAS_HAB falls back to a plain Mon–Fri count.
        }
    }

    keys
    {
        key(PK; Código)
        {
            Clustered = true;
        }
        key(K2; Año, Mes)
        {
        }
    }

    trigger OnInsert()
    begin
        if Código = '' then
            Código := Format(Año) + Format(Mes, 2, '<Integer,2>');
        if (Mes >= 1) and (Mes <= 12) and (Año >= 2000) then begin
            if "Fecha Desde" = 0D then
                "Fecha Desde" := DMY2Date(1, Mes, Año);
            if "Fecha Hasta" = 0D then
                "Fecha Hasta" := CalcDate('<CM>', "Fecha Desde");
        end;
    end;

    trigger OnDelete()
    var
        Liq: Record Liquidación;
    begin
        if Estado = Estado::Cerrado then
            Error(ErrCerrado);
        Liq.SetRange("Cód. Período", Código);
        if not Liq.IsEmpty() then
            Error(ErrConLiquidaciones);
    end;

    // Período que toda pantalla debería proponer sin que el usuario lo tipee: el que contiene la
    // fecha de trabajo. Si la fecha de trabajo cae fuera de todo período, el último abierto es el que
    // se está por liquidar; y si no hay ninguno abierto, el último cargado — mejor uno viejo que
    // ninguno. Vive acá para que la hoja de novedades y el asistente de fórmulas no lo repitan.
    procedure PeriodoPorDefecto(): Code[10]
    var
        Periodo: Record "Período Liquidación";
    begin
        Periodo.SetFilter("Fecha Desde", '<=%1', WorkDate());
        Periodo.SetFilter("Fecha Hasta", '>=%1', WorkDate());
        if Periodo.FindFirst() then
            exit(Periodo.Código);

        Periodo.Reset();
        Periodo.SetCurrentKey("Fecha Desde");
        Periodo.SetRange(Estado, Periodo.Estado::Abierto);
        if Periodo.FindLast() then
            exit(Periodo.Código);

        Periodo.SetRange(Estado);
        if Periodo.FindLast() then
            exit(Periodo.Código);
        exit('');
    end;

    // Período inmediatamente anterior por fecha de inicio. No se usa Año/Mes porque un período puede
    // no ser mensual (quincenas, períodos especiales) y ahí la resta de meses miente.
    procedure PeriodoAnterior(CodPeriodo: Code[10]): Code[10]
    var
        Actual: Record "Período Liquidación";
        Previo: Record "Período Liquidación";
    begin
        if not Actual.Get(CodPeriodo) then
            exit('');
        Previo.SetCurrentKey("Fecha Desde");
        Previo.SetFilter("Fecha Desde", '<%1', Actual."Fecha Desde");
        if Previo.FindLast() then
            exit(Previo.Código);
        exit('');
    end;

    procedure ContieneFecha(Fecha: Date): Boolean
    begin
        exit((Fecha >= "Fecha Desde") and (Fecha <= "Fecha Hasta"));
    end;

    var
        ErrCerrado: Label 'No se puede eliminar un período cerrado.';
        ErrConLiquidaciones: Label 'No se puede eliminar un período que contiene liquidaciones.';
}
