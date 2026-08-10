namespace UAS.Payroll;

page 50117 "Ficha Liquidación"
{
    ApplicationArea = All;
    Caption = 'Liquidación';
    PageType = Card;
    SourceTable = "Liquidación";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Cód. Período"; Rec."Cód. Período")
                {
                    ApplicationArea = All;
                    Editable = IsEditable;
                }
                field("Cód. Tipo Liq."; Rec."Cód. Tipo Liq.")
                {
                    ApplicationArea = All;
                    Editable = IsEditable;
                }
                field("No. Liq. Origen"; Rec."No. Liq. Origen")
                {
                    ApplicationArea = All;
                    Editable = IsEditable;
                    Visible = Rec."Cód. Tipo Liq." = 'RELIQUIDACION';
                }
                field(Estado; Rec.Estado)
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = EstadoStyle;
                }
                field("Fecha Liquidación"; Rec."Fecha Liquidación")
                {
                    ApplicationArea = All;
                    Editable = IsEditable;
                }
            }
            group(Empleado)
            {
                Caption = 'Empleado';

                field("No. Empleado"; Rec."No. Empleado")
                {
                    ApplicationArea = All;
                    Editable = IsEditable;
                }
                field("Nombre Empleado"; Rec."Nombre Empleado")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Cód. Convenio"; Rec."Cód. Convenio")
                {
                    ApplicationArea = All;
                    Editable = IsEditable;
                }
                field("Cód. Categoría"; Rec."Cód. Categoría")
                {
                    ApplicationArea = All;
                    Editable = IsEditable;
                }
            }
            group(GrpProyecto)
            {
                Caption = 'Proyecto';

                field("No. Proyecto"; Rec."No. Proyecto")
                {
                    ApplicationArea = All;
                    Editable = IsEditable;
                }
            }
            group(Totales)
            {
                Caption = 'Totales';

                field("Total Haberes"; Rec."Total Haberes")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Total Descuentos"; Rec."Total Descuentos")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Haberes Ordinarios Gravados"; Rec."Haberes Ordinarios Gravados")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Remunerativo normal y habitual del mes (acumulador BASE_IG4), excluyendo extraordinarios. Usado para el cálculo del SAC (mejor remuneración del semestre).';
                }
                field("Total Contribuciones"; Rec."Total Contribuciones")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Neto a Pagar"; Rec."Neto a Pagar")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Style = Strong;
                }
            }
            part(Lineas; "Líneas Liquidación")
            {
                ApplicationArea = All;
                SubPageLink = "No. Liquidación" = FIELD("No.");
                UpdatePropagation = Both;
            }
            part(Acumuladores; "Acumuladores Liq. Sub")
            {
                ApplicationArea = All;
                Caption = 'Acumuladores';
                SubPageLink = "No. Liquidación" = FIELD("No.");
            }
            part(AcumuladoresAnuales; "Resumen Variable Liq. Sub")
            {
                ApplicationArea = All;
                Caption = 'Acumuladores Anuales';
                SubPageLink = "No. Liquidación" = FIELD("No.");
            }
            part(Incidencias; "Incidencias Liquidación Sub")
            {
                ApplicationArea = All;
                Caption = 'Incidencias';
                SubPageLink = "No. Liquidación" = FIELD("No.");
            }
        }
        area(FactBoxes)
        {
            part(DetVariables; "Detalle Variable Línea Sub")
            {
                ApplicationArea = All;
                Caption = 'Variables del Cálculo';
                SubPageLink = "No. Liquidación" = FIELD("No.");
            }
            systempart(Control1; Links) { ApplicationArea = All; }
            systempart(Control2; Notes) { ApplicationArea = All; }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Calcular)
            {
                ApplicationArea = All;
                Caption = 'Calcular';
                Image = Calculate;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Enabled = CanCalcular;

                trigger OnAction()
                var
                    Motor: Codeunit "Motor Liquidación";
                    Registro: Codeunit "Registro Procesos Liq.";
                    RegistroNo: Integer;
                begin
                    if not Motor.LiquidarConRegistro(Rec) then begin
                        // El error ya quedó guardado; se muestra igual que antes, pero ahora con el
                        // número de registro para poder ir al detalle completo.
                        RegistroNo := Registro.UltimoRegistro();
                        CurrPage.Update(false);
                        Error(ErrCalculoConRegistro, Registro.GetResumen(), RegistroNo);
                    end;
                    CurrPage.Update(false);
                    if Motor.GetAdvertencias() <> '' then
                        Message(MsgAdvertenciasParametros, Motor.GetAdvertencias());
                end;
            }
            action(Aprobar)
            {
                ApplicationArea = All;
                Caption = 'Aprobar';
                Image = Approve;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = EsCalculada;

                trigger OnAction()
                var
                    Gestion: Codeunit "Gestión Liquidación";
                begin
                    Gestion.Aprobar(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(Reabrir)
            {
                ApplicationArea = All;
                Caption = 'Reabrir';
                Image = ReOpen;
                Enabled = EsCalculada;

                trigger OnAction()
                var
                    Gestion: Codeunit "Gestión Liquidación";
                begin
                    Gestion.Reabrir(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(RevertirAprobacion)
            {
                ApplicationArea = All;
                Caption = 'Revertir Aprobación';
                Image = Undo;
                Enabled = EsAprobada;
                ToolTip = 'Devuelve la liquidación al estado Calculada para permitir su revisión o corrección.';

                trigger OnAction()
                var
                    Gestion: Codeunit "Gestión Liquidación";
                begin
                    if Gestion.RevertirAprobacion(Rec) then
                        CurrPage.Update(false);
                end;
            }
            action(ImprimirRecibo)
            {
                ApplicationArea = All;
                Caption = 'Imprimir Recibo';
                Image = Print;
                Promoted = true;
                PromotedCategory = Report;
                ToolTip = 'Imprime el recibo de sueldo de esta liquidación.';

                trigger OnAction()
                var
                    Liq: Record "Liquidación";
                begin
                    Liq.SetRange("No.", Rec."No.");
                    Report.RunModal(Report::"Recibo de Sueldo", true, false, Liq);
                end;
            }
            action(VerRegistros)
            {
                ApplicationArea = All;
                Caption = 'Registros de proceso';
                Image = History;
                ToolTip = 'Historial de cálculos, aprobaciones y reaperturas de esta liquidación, con los errores y las acciones de cada uno.';

                trigger OnAction()
                var
                    RegistroRec: Record "Registro Proceso Liq.";
                begin
                    RegistroRec.SetCurrentKey("No. Liquidación", "Fecha Hora Inicio");
                    RegistroRec.SetRange("No. Liquidación", Rec."No.");
                    Page.Run(Page::"Registros Proceso Liq.", RegistroRec);
                end;
            }
            action(VerNovedades)
            {
                ApplicationArea = All;
                Caption = 'Novedades del período';
                Image = Journal;
                ToolTip = 'Muestra las novedades cargadas para el período de esta liquidación, con el estado de cada una. Es dónde mirar cuando una novedad no aparece entre las incidencias: la columna Motivo No Aplicada dice por qué se salteó.';

                trigger OnAction()
                var
                    Nov: Record "Novedad Liquidación";
                begin
                    Nov.SetRange("Cód. Período", Rec."Cód. Período");
                    Page.Run(Page::"Novedades Liquidación", Nov);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        IsEditable := Rec.Estado = Rec.Estado::Borrador;
        EsCalculada := Rec.Estado = Rec.Estado::Calculada;
        EsAprobada := Rec.Estado = Rec.Estado::Aprobada;
        CanCalcular := IsEditable;
        SetEstadoStyle();
    end;


    local procedure SetEstadoStyle()
    begin
        case Rec.Estado of
            Rec.Estado::Borrador:
                EstadoStyle := 'Subordinate';
            Rec.Estado::Calculada:
                EstadoStyle := 'Favorable';
            Rec.Estado::Aprobada:
                EstadoStyle := 'Strong';
            Rec.Estado::Contabilizada:
                EstadoStyle := 'Attention';
        end;
    end;

    var
        IsEditable: Boolean;
        EsCalculada: Boolean;
        EsAprobada: Boolean;
        CanCalcular: Boolean;
        EstadoStyle: Text;
        MsgAdvertenciasParametros: Label 'Atención — parámetros posiblemente desactualizados:\%1';
        ErrCalculoConRegistro: Label 'No se pudo calcular la liquidación:\%1\\El detalle quedó guardado en el registro de proceso No. %2 (acción "Registros de proceso").';
}
