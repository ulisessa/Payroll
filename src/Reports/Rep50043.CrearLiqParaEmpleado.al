namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.Foundation.NoSeries;
using Microsoft.HumanResources.Setup;

report 50043 "Crear Liq. para Empleado"
{
    ApplicationArea = All;
    Caption = 'Crear Liquidación para Empleado';
    UsageCategory = Tasks;
    ProcessingOnly = true;

    dataset
    {
        dataitem(Emp; Employee)
        {
            RequestFilterFields = "No.", "First Name", "Last Name", Status;

            trigger OnPreDataItem()
            begin
                if FCodPeriodo = '' then
                    Error(ErrSinPeriodo);
                // El tipo no se infiere a propósito: sin él la cabecera queda en blanco y el motor
                // filtra mal los conceptos (ConceptoAplicaATipoLiq) sin avisar. Se corta acá, antes
                // de crear nada, en vez de generar liquidaciones con un tipo equivocado en masa.
                if FTipoLiq = '' then
                    Error(ErrSinTipoLiq);
                Periodo.Get(FCodPeriodo);
                if Periodo.Estado = Periodo.Estado::Cerrado then
                    Error(ErrPeriodoCerrado, FCodPeriodo);
                HRSetup.Get();
                if HRSetup."Cód. Serie Liq." = '' then
                    Error(ErrSerieNoConfigurada);
            end;

            trigger OnAfterGetRecord()
            var
                Personal: Record "Personal Proyecto";
            begin
                Personal.SetRange("No. Empleado", Emp."No.");
                Personal.SetRange("Fecha Baja", 0D);
                if not Personal.FindSet() then
                    CurrReport.Skip();
                repeat
                    InsertarLiq(Personal);
                until Personal.Next() = 0;
            end;

            trigger OnPostDataItem()
            begin
                Message(MsgCreadas, Creadas);
            end;
        }
    }

    requestpage
    {
        layout
        {
            area(Content)
            {
                group(Opciones)
                {
                    Caption = 'Opciones';
                    field(CodPeriodo; FCodPeriodo)
                    {
                        ApplicationArea = All;
                        Caption = 'Período';
                        TableRelation = "Período Liquidación".Código;
                    }
                    field(TipoLiq; FTipoLiq)
                    {
                        ApplicationArea = All;
                        Caption = 'Tipo Liquidación';
                        TableRelation = "Tipo Liquidación".Código where(Activo = const(true));
                        ShowMandatory = true;
                        ToolTip = 'Obligatorio: determina qué conceptos aplican. Una liquidación sin tipo no calcula los conceptos restringidos por tipo.';
                    }
                }
            }
        }
    }

    procedure SetPeriodo(CodPeriodo: Code[10])
    begin
        FCodPeriodo := CodPeriodo;
    end;

    local procedure InsertarLiq(Personal: Record "Personal Proyecto")
    var
        Liq: Record "Liquidación";
        ExistLiq: Record "Liquidación";
        NoSeries: Codeunit "No. Series";
    begin
        ExistLiq.SetRange("No. Empleado", Personal."No. Empleado");
        ExistLiq.SetRange("No. Proyecto", Personal."No. Proyecto");
        ExistLiq.SetRange("Cód. Período", FCodPeriodo);
        ExistLiq.SetRange("Cód. Tipo Liq.", FTipoLiq);
        if not ExistLiq.IsEmpty() then
            exit;

        Liq.Init();
        Liq."No." := NoSeries.GetNextNo(HRSetup."Cód. Serie Liq.", WorkDate(), true);
        Liq."No. Empleado" := Personal."No. Empleado";
        Liq."Nombre Empleado" := CopyStr(Emp."First Name" + ' ' + Emp."Last Name", 1, MaxStrLen(Liq."Nombre Empleado"));
        Liq."No. Proyecto" := Personal."No. Proyecto";
        Liq."Cód. Período" := FCodPeriodo;
        Liq."Cód. Convenio" := Personal."Cód. Convenio";
        Liq."Cód. Categoría" := Personal."Cód. Categoría";
        Liq."Fecha Liquidación" := Periodo."Fecha Hasta";
        Liq."Cód. Tipo Liq." := FTipoLiq;
        Liq.Estado := Liq.Estado::Borrador;
        Liq.Insert(true);
        Creadas += 1;
    end;

    var
        Periodo: Record "Período Liquidación";
        HRSetup: Record "Human Resources Setup";
        FCodPeriodo: Code[10];
        FTipoLiq: Code[20];
        Creadas: Integer;
        ErrSinPeriodo: Label 'Debe seleccionar un período.';
        ErrSinTipoLiq: Label 'Debe seleccionar un Tipo de Liquidación: determina qué conceptos aplican, y una liquidación sin tipo no calcula los conceptos restringidos por tipo.';
        ErrPeriodoCerrado: Label 'El período %1 está cerrado.';
        ErrSerieNoConfigurada: Label 'La serie de numeración de liquidaciones no está configurada en Configuración de RR.HH.';
        MsgCreadas: Label '%1 liquidación(es) creada(s) en estado Borrador.';
}
