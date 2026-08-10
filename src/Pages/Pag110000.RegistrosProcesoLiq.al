namespace UAS.Payroll;

page 110000 "Registros Proceso Liq."
{
    ApplicationArea = All;
    Caption = 'Registros de Proceso';
    PageType = List;
    UsageCategory = History;
    SourceTable = "Registro Proceso Liq.";
    SourceTableView = sorting("No. Registro") order(descending);
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    CardPageId = "Ficha Registro Proceso Liq.";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Fecha Hora Inicio"; Rec."Fecha Hora Inicio")
                {
                    ApplicationArea = All;
                    StyleExpr = FilaStyle;
                }
                field("Tipo Proceso"; Rec."Tipo Proceso")
                {
                    ApplicationArea = All;
                    StyleExpr = FilaStyle;
                }
                field(Resultado; Rec.Resultado)
                {
                    ApplicationArea = All;
                    StyleExpr = FilaStyle;
                }
                field("No. Liquidación"; Rec."No. Liquidación")
                {
                    ApplicationArea = All;

                    trigger OnDrillDown()
                    var
                        Liq: Record "Liquidación";
                    begin
                        if Liq.Get(Rec."No. Liquidación") then
                            Page.Run(Page::"Ficha Liquidación", Liq);
                    end;
                }
                field("No. Empleado"; Rec."No. Empleado") { ApplicationArea = All; }
                field("Nombre Empleado"; Rec."Nombre Empleado") { ApplicationArea = All; }
                field("Cód. Período"; Rec."Cód. Período") { ApplicationArea = All; }
                field(Mensaje; Rec.Mensaje)
                {
                    ApplicationArea = All;
                    StyleExpr = FilaStyle;
                }
                field("Cant. Errores"; Rec."Cant. Errores")
                {
                    ApplicationArea = All;
                    StyleExpr = ErroresStyle;
                }
                field("Cant. Advertencias"; Rec."Cant. Advertencias") { ApplicationArea = All; }
                field("Duración (ms)"; Rec."Duración (ms)") { ApplicationArea = All; }
                field(Usuario; Rec.Usuario) { ApplicationArea = All; }
                field("Cód. Tipo Liq."; Rec."Cód. Tipo Liq.") { ApplicationArea = All; Visible = false; }
            }
        }
        area(FactBoxes)
        {
            part(Entradas; "Entradas Registro Liq. Sub")
            {
                ApplicationArea = All;
                Caption = 'Detalle';
                SubPageLink = "No. Registro" = FIELD("No. Registro");
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(VerDetalle)
            {
                ApplicationArea = All;
                Caption = 'Ver detalle';
                Image = ViewDetails;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ShortcutKey = 'Return';
                ToolTip = 'Abre todas las entradas de este proceso: errores, advertencias y acciones realizadas.';

                trigger OnAction()
                begin
                    Rec.MostrarEntradas();
                end;
            }
            action(VerSesion)
            {
                ApplicationArea = All;
                Caption = 'Ver toda la corrida';
                Image = History;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Muestra todos los registros generados en la misma corrida por lote que éste.';

                trigger OnAction()
                var
                    Registro: Record "Registro Proceso Liq.";
                begin
                    if IsNullGuid(Rec."No. Sesión") then
                        Error(ErrSinSesion);
                    Registro.SetCurrentKey("No. Sesión");
                    Registro.SetRange("No. Sesión", Rec."No. Sesión");
                    Page.Run(Page::"Registros Proceso Liq.", Registro);
                end;
            }
            action(SoloConError)
            {
                ApplicationArea = All;
                Caption = 'Solo con error';
                Image = FilterLines;
                ToolTip = 'Deja a la vista únicamente los procesos que terminaron con error o advertencia.';

                trigger OnAction()
                begin
                    FiltroProblemas := not FiltroProblemas;
                    if FiltroProblemas then
                        Rec.SetFilter(Resultado, '<>%1', Rec.Resultado::Información)
                    else
                        Rec.SetRange(Resultado);
                    CurrPage.Update(false);
                end;
            }
        }
        area(Reporting)
        {
            action(Depurar)
            {
                ApplicationArea = All;
                Caption = 'Depurar registros antiguos';
                Image = Delete;
                ToolTip = 'Elimina los registros anteriores a la fecha que indiques. El histórico crece con cada cálculo, así que conviene depurarlo cada tanto.';

                trigger OnAction()
                var
                    Registro: Record "Registro Proceso Liq.";
                    FechaCorte: Date;
                    Borrados: Integer;
                begin
                    FechaCorte := CalcDate('<-3M>', Today());
                    if not Confirm(QstDepurar, false, FechaCorte) then
                        exit;
                    Registro.SetFilter("Fecha Hora Inicio", '<%1', CreateDateTime(FechaCorte, 0T));
                    Borrados := Registro.Count();
                    // DeleteAll con trigger: cada cabecera arrastra sus entradas (ver Tab60036).
                    Registro.DeleteAll(true);
                    Message(MsgDepurado, Borrados);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec.Resultado of
            Rec.Resultado::Error:
                FilaStyle := 'Unfavorable';
            Rec.Resultado::Advertencia:
                FilaStyle := 'Ambiguous';
            else
                FilaStyle := 'Favorable';
        end;
        if Rec."Cant. Errores" > 0 then
            ErroresStyle := 'Unfavorable'
        else
            ErroresStyle := 'Subordinate';
    end;

    var
        FilaStyle: Text[20];
        ErroresStyle: Text[20];
        FiltroProblemas: Boolean;
        ErrSinSesion: Label 'Este registro no formó parte de una corrida por lote.';
        QstDepurar: Label '¿Eliminar los registros de proceso anteriores al %1?';
        MsgDepurado: Label 'Se eliminaron %1 registro(s).';
}
