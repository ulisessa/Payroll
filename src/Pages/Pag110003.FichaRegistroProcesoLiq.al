namespace UAS.Payroll;

page 110003 "Ficha Registro Proceso Liq."
{
    ApplicationArea = All;
    Caption = 'Registro de Proceso';
    PageType = Card;
    UsageCategory = None;
    SourceTable = "Registro Proceso Liq.";
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            group(GrpProceso)
            {
                Caption = 'Proceso';

                field("No. Registro"; Rec."No. Registro") { ApplicationArea = All; }
                field("Tipo Proceso"; Rec."Tipo Proceso") { ApplicationArea = All; }
                field(Resultado; Rec.Resultado)
                {
                    ApplicationArea = All;
                    StyleExpr = ResultadoStyle;
                }
                field(Mensaje; Rec.Mensaje)
                {
                    ApplicationArea = All;
                    MultiLine = true;
                    StyleExpr = ResultadoStyle;
                }
                field("Cant. Errores"; Rec."Cant. Errores") { ApplicationArea = All; }
                field("Cant. Advertencias"; Rec."Cant. Advertencias") { ApplicationArea = All; }
            }
            group(GrpContexto)
            {
                Caption = 'Contexto';

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
                field("Cód. Tipo Liq."; Rec."Cód. Tipo Liq.") { ApplicationArea = All; }
            }
            group(GrpEjecucion)
            {
                Caption = 'Ejecución';

                field("Fecha Hora Inicio"; Rec."Fecha Hora Inicio") { ApplicationArea = All; }
                field("Fecha Hora Fin"; Rec."Fecha Hora Fin") { ApplicationArea = All; }
                field("Duración (ms)"; Rec."Duración (ms)") { ApplicationArea = All; }
                field(Usuario; Rec.Usuario) { ApplicationArea = All; }
            }
            part(Entradas; "Entradas Registro Liq. Sub")
            {
                ApplicationArea = All;
                Caption = 'Errores, advertencias y acciones';
                SubPageLink = "No. Registro" = FIELD("No. Registro");
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec.Resultado of
            Rec.Resultado::Error:
                ResultadoStyle := 'Unfavorable';
            Rec.Resultado::Advertencia:
                ResultadoStyle := 'Ambiguous';
            else
                ResultadoStyle := 'Favorable';
        end;
    end;

    var
        ResultadoStyle: Text[20];
}
