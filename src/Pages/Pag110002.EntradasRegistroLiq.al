namespace UAS.Payroll;

page 110002 "Entradas Registro Liq."
{
    ApplicationArea = All;
    Caption = 'Detalle del proceso';
    PageType = List;
    UsageCategory = None;
    SourceTable = "Entrada Registro Liq.";
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Severidad; Rec.Severidad)
                {
                    ApplicationArea = All;
                    StyleExpr = FilaStyle;
                    Width = 8;
                }
                field(Categoría; Rec.Categoría)
                {
                    ApplicationArea = All;
                    Width = 10;
                }
                field("Nombre Variable"; Rec."Nombre Variable")
                {
                    ApplicationArea = All;
                    Caption = 'Acumulador / Variable';
                    Width = 14;
                    Style = Strong;
                    StyleExpr = true;
                }
                field("Cód. Concepto"; Rec."Cód. Concepto")
                {
                    ApplicationArea = All;
                    Width = 8;

                    trigger OnDrillDown()
                    begin
                        AbrirConcepto();
                    end;
                }
                field(Mensaje; Rec.Mensaje)
                {
                    ApplicationArea = All;
                    StyleExpr = FilaStyle;
                    // Sin MultiLine: en un repeater no crece solo la fila que lo necesita, sino que
                    // reserva la altura de varias líneas en TODAS. Como el acumulador y el concepto
                    // ya viajan en sus columnas, el mensaje entra en un renglón; para los pocos
                    // largos está "Ver texto completo".
                }
                field(Importe; Rec.Importe)
                {
                    ApplicationArea = All;
                    Width = 18;
                    BlankZero = true;
                }
                field(Detalle; Rec.Detalle)
                {
                    ApplicationArea = All;
                    MultiLine = true;
                    Visible = false;
                    ToolTip = 'Texto largo del error, cuando lo hay. Se ve completo con "Ver texto completo".';
                }
                field("Fecha Hora"; Rec."Fecha Hora")
                {
                    ApplicationArea = All;
                    Visible = false;
                    ToolTip = 'Momento de la anotación. Oculta por defecto: dentro de un mismo proceso son todas casi iguales.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(VerCompleto)
            {
                ApplicationArea = All;
                Caption = 'Ver texto completo';
                Image = ViewDetails;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Muestra el mensaje y su detalle largo completos.';

                trigger OnAction()
                begin
                    if Rec.Detalle <> '' then
                        Message('%1\\%2', Rec.Mensaje, Rec.Detalle)
                    else
                        Message(Rec.Mensaje);
                end;
            }
            action(SoloProblemas)
            {
                ApplicationArea = All;
                Caption = 'Solo errores y advertencias';
                Image = FilterLines;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Oculta las acciones informativas y deja solo lo que necesita atención.';

                trigger OnAction()
                begin
                    FiltroProblemas := not FiltroProblemas;
                    if FiltroProblemas then
                        Rec.SetFilter(Severidad, '<>%1', Rec.Severidad::Información)
                    else
                        Rec.SetRange(Severidad);
                    CurrPage.Update(false);
                end;
            }
            action(AbrirConceptoAccion)
            {
                ApplicationArea = All;
                Caption = 'Abrir concepto';
                Image = Card;
                ToolTip = 'Abre la ficha del concepto al que se refiere esta entrada.';

                trigger OnAction()
                begin
                    AbrirConcepto();
                end;
            }
        }
    }

    local procedure AbrirConcepto()
    var
        Concepto: Record "Concepto Liquidación";
    begin
        if Rec."Cód. Concepto" = '' then
            exit;
        Concepto.SetRange(Código, Rec."Cód. Concepto");
        if Concepto.FindLast() then
            Page.Run(Page::"Concepto Liq. Card", Concepto);
    end;

    trigger OnAfterGetRecord()
    begin
        case Rec.Severidad of
            Rec.Severidad::Error:
                FilaStyle := 'Unfavorable';
            Rec.Severidad::Advertencia:
                FilaStyle := 'Ambiguous';
            else
                FilaStyle := 'Subordinate';
        end;
    end;

    var
        FilaStyle: Text[20];
        FiltroProblemas: Boolean;
}
