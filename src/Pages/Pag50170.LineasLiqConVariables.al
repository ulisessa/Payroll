namespace UAS.Payroll;

page 50170 "Líneas Liq. con Variables"
{
    ApplicationArea = All;
    Caption = 'Líneas de Liquidación';
    PageType = List;
    SourceTable = "Línea Liquidación";
    Editable = false;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Orden Cálculo"; Rec."Orden Cálculo") { ApplicationArea = All; }
                field("Cód. Concepto"; Rec."Cód. Concepto")
                {
                    ApplicationArea = All;
                    ToolTip = 'Abre la ficha del concepto (la versión/vigencia que se usó en esta línea).';
                    trigger OnDrillDown()
                    begin
                        AbrirConcepto();
                    end;
                }
                field("Nombre Impresión"; Rec."Nombre Impresión") { ApplicationArea = All; }
                field("Tipo Concepto"; Rec."Tipo Concepto")
                {
                    ApplicationArea = All;
                    StyleExpr = TipoStyle;
                }
                field(Cantidad; Rec.Cantidad)
                {
                    ApplicationArea = All;
                    DecimalPlaces = 0 : 4;
                }
                field("Unidad Cantidad"; Rec."Unidad Cantidad") { ApplicationArea = All; }
                field("Base Cálculo"; Rec."Base Cálculo") { ApplicationArea = All; }
                field(Importe; Rec.Importe)
                {
                    ApplicationArea = All;
                    Style = Strong;
                }
                field("Vigencia Concepto"; Rec."Vigencia Concepto") { ApplicationArea = All; }
                field("Fórmula Aplicada"; Rec."Fórmula Aplicada") { ApplicationArea = All; }
                field("Fórmula Evaluada"; Rec."Fórmula Evaluada")
                {
                    ApplicationArea = All;
                    ToolTip = 'Fórmula con los valores del contexto sustituidos al momento del cálculo.';
                }
            }
        }
        area(FactBoxes)
        {
            // SubPageLink uses FIELD("No. Línea") from the LIST source table, so the FactBox
            // updates automatically whenever the user navigates to a different line.
            part(DetVariables; "Detalle Variable Línea Sub")
            {
                ApplicationArea = All;
                Caption = 'Variables del Concepto';
                SubPageLink = "No. Liquidación" = FIELD("No. Liquidación"),
                              "No. Línea" = FIELD("No. Línea");
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ToggleSinCero)
            {
                ApplicationArea = All;
                Caption = 'Ocultar importes cero';
                Image = Filter;
                trigger OnAction()
                begin
                    OcultarCero := not OcultarCero;
                    if OcultarCero then
                        Rec.SetFilter(Importe, '<>0')
                    else
                        Rec.SetRange(Importe);
                    CurrPage.Update(false);
                end;
            }
            action(AbrirConceptoAction)
            {
                ApplicationArea = All;
                Caption = 'Abrir Concepto';
                Image = Card;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Abre la ficha del concepto (la versión/vigencia que se usó en esta línea).';
                trigger OnAction()
                begin
                    AbrirConcepto();
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec."Tipo Concepto" of
            Rec."Tipo Concepto"::"Haber Remunerativo":
                TipoStyle := 'Favorable';
            Rec."Tipo Concepto"::"Haber No Remunerativo":
                TipoStyle := 'Subordinate';
            Rec."Tipo Concepto"::"Deducción Remunerativa":
                TipoStyle := 'Ambiguous';
            Rec."Tipo Concepto"::"Descuento Empleado",
            Rec."Tipo Concepto"::Retención:
                TipoStyle := 'Unfavorable';
            Rec."Tipo Concepto"::"Contribución Patronal":
                TipoStyle := 'Attention';
        end;
    end;

    local procedure AbrirConcepto()
    var
        Concepto: Record "Concepto Liquidación";
    begin
        if Rec."Cód. Concepto" = '' then exit;
        if not Concepto.Get(Rec."Cód. Concepto", Rec."Vigencia Concepto") then begin
            Concepto.SetRange(Código, Rec."Cód. Concepto");
            if not Concepto.FindLast() then begin
                Message(MsgConceptoNoEncontrado, Rec."Cód. Concepto");
                exit;
            end;
        end;
        Page.Run(Page::"Concepto Liq. Card", Concepto);
    end;

    var
        TipoStyle: Text;
        OcultarCero: Boolean;
        MsgConceptoNoEncontrado: Label 'No se encontró el concepto %1.';
}
