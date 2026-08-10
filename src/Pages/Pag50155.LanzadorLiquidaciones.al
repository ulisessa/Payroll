namespace UAS.Payroll;

page 50155 "Lanzador Liquidaciones"
{
    PageType = Card;
    Caption = 'Lanzador de Liquidaciones';
    UsageCategory = Tasks;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(GrpParametros)
            {
                Caption = 'Parámetros';

                field(FCodPeriodo; FCodPeriodo)
                {
                    Caption = 'Período';
                    ApplicationArea = All;
                    TableRelation = "Período Liquidación".Código;
                    ToolTip = 'Período de liquidación sobre el que se operará.';
                }
                field(FTipoLiq; FTipoLiq)
                {
                    Caption = 'Tipo Liquidación';
                    ApplicationArea = All;
                    TableRelation = "Tipo Liquidación".Código;
                    ToolTip = 'Devengados: fijos mensuales durante la marea. Cierre Marea: liquidación completa al regreso.';
                }
                field(FTipoProyecto; FTipoProyecto)
                {
                    Caption = 'Tipo Proyecto';
                    ApplicationArea = All;
                    OptionCaption = 'Todos,Productivo,Improductivo';
                    ToolTip = 'Filtra los proyectos incluidos en el proceso. Dejar en Todos para ambos tipos.';
                }
            }
            group(GrpInfo)
            {
                Caption = 'Información';
                Editable = false;

                field(FDescPeriodo; FDescPeriodo)
                {
                    Caption = 'Período';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(FUltimoResultado; FUltimoResultado)
                {
                    Caption = 'Último resultado';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Favorable;
                    StyleExpr = FUltimoResultado <> '';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ACrear)
            {
                Caption = 'Crear Liquidaciones';
                ApplicationArea = All;
                Image = CreateDocuments;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Crea borradores de liquidación para todos los empleados activos en los proyectos que coincidan con los parámetros.';

                trigger OnAction()
                var
                    ProcLiq: Codeunit "Proceso Liq. Por Lote";
                    TipoLiqRec: Record "Tipo Liquidación";
                    Creadas: Integer;
                begin
                    if FCodPeriodo = '' then
                        Error(ErrSinPeriodo);
                    if not Confirm(MsgConfirmarCrear, true, Format(FTipoLiq), FCodPeriodo) then
                        exit;
                    Creadas := ProcLiq.CrearPorPeriodo(FCodPeriodo, FTipoLiq, FTipoProyecto);
                    // El tipo con "Incluye Francos Puerto" también cubre a los empleados en Francos (en
                    // puerto, sin proyecto).
                    if FTipoLiq = TipoLiqRec.CodigoFrancosPuerto() then
                        Creadas += ProcLiq.CrearRegularEmpleadosEnFrancos(FCodPeriodo);
                    FUltimoResultado := StrSubstNo(MsgCreadas, Creadas);
                    CurrPage.Update(false);
                end;
            }
            action(ACalcular)
            {
                Caption = 'Calcular Todo';
                ApplicationArea = All;
                Image = Calculate;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Calcula todas las liquidaciones en estado Borrador o Calculada para el período y tipo seleccionados.';

                trigger OnAction()
                var
                    ProcLiq: Codeunit "Proceso Liq. Por Lote";
                    Calculadas: Integer;
                begin
                    if FCodPeriodo = '' then
                        Error(ErrSinPeriodo);
                    if not Confirm(MsgConfirmarCalcular, true, Format(FTipoLiq), FCodPeriodo) then
                        exit;
                    Calculadas := ProcLiq.CalcularPorPeriodo(FCodPeriodo, FTipoLiq);
                    FUltimoResultado := StrSubstNo(MsgCalculadas, Calculadas);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    var
        Periodo: Record "Período Liquidación";
    begin
        if (FCodPeriodo <> '') and Periodo.Get(FCodPeriodo) then
            FDescPeriodo := Format(Periodo."Fecha Desde") + ' – ' + Format(Periodo."Fecha Hasta")
        else
            FDescPeriodo := '';
    end;

    var
        FCodPeriodo: Code[10];
        FTipoLiq: Code[20];
        FTipoProyecto: Option Todos,Productivo,Improductivo;
        FDescPeriodo: Text;
        FUltimoResultado: Text;
        ErrSinPeriodo: Label 'Debe seleccionar un período antes de continuar.';
        MsgConfirmarCrear: Label 'Crear liquidaciones de tipo ''%1'' para el período %2. ¿Continuar?';
        MsgConfirmarCalcular: Label 'Calcular todas las liquidaciones de tipo ''%1'' para el período %2. ¿Continuar?';
        MsgCreadas: Label '%1 liquidación(es) creada(s) en estado Borrador.';
        MsgCalculadas: Label '%1 liquidación(es) calculada(s).';
}
