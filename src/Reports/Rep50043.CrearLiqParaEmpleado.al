namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
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
                Periodo.ErrorSiCreado();
                HRSetup.Get();
                if HRSetup."Cód. Serie Liq." = '' then
                    Error(ErrSerieNoConfigurada);
            end;

            trigger OnAfterGetRecord()
            var
                Lotes: Codeunit "Proceso Liq. Por Lote";
            begin
                // TODA la lógica de creación vive en el codeunit del lote: cuántas liquidaciones
                // corresponden según "Agrupa por Empleado", de dónde sale el proyecto, qué
                // asignaciones cuentan y las cuatro guardas. Este reporte la duplicaba a mano y se
                // salteaba las cuatro, así que creaba una liquidación por asignación —incluidas las
                // que todavía no habían empezado— con el proyecto de la asignación en vez del que
                // resuelve el estado del empleado.
                Creadas += Lotes.CrearParaEmpleado(Emp."No.", FCodPeriodo, FTipoLiq);
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
