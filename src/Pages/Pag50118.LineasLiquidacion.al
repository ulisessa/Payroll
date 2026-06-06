namespace UAS.Payroll;

page 50118 "Líneas Liquidación"
{
    ApplicationArea = All;
    Caption = 'Líneas Liquidación';
    PageType = ListPart;
    SourceTable = "Línea Liquidación";
    Editable = false;
    DelayedInsert = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Orden Cálculo"; Rec."Orden Cálculo")
                {
                    ApplicationArea = All;
                }
                field("Cód. Concepto"; Rec."Cód. Concepto")
                {
                    ApplicationArea = All;
                }
                field("Nombre Impresión"; Rec."Nombre Impresión")
                {
                    ApplicationArea = All;
                }
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
                field(Importe; Rec.Importe)
                {
                    ApplicationArea = All;
                    Style = Strong;
                }
                field("Vigencia Concepto"; Rec."Vigencia Concepto")
                {
                    ApplicationArea = All;
                }
                field("Fórmula Aplicada"; Rec."Fórmula Aplicada")
                {
                    ApplicationArea = All;
                }
                field("Fórmula Evaluada"; Rec."Fórmula Evaluada")
                {
                    ApplicationArea = All;
                    ToolTip = 'Fórmula con los valores del contexto sustituidos al momento del cálculo.';
                }
                field("Fuente Parámetros"; Rec."Fuente Parámetros")
                {
                    ApplicationArea = All;
                    Visible = false;
                }
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
                ToolTip = 'Muestra u oculta los conceptos con importe cero.';
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
            action(VerVariables)
            {
                ApplicationArea = All;
                Caption = 'Variables del cálculo';
                Image = Table;
                ToolTip = 'Muestra las variables que se utilizaron al calcular esta línea.';
                trigger OnAction()
                var
                    Det: Record "Detalle Variable Línea Liq.";
                    VarPage: Page "Variables Cálculo Línea";
                begin
                    Det.SetRange("No. Liquidación", Rec."No. Liquidación");
                    Det.SetRange("No. Línea", Rec."No. Línea");
                    VarPage.SetTableView(Det);
                    VarPage.Caption := Rec."Descripción Concepto";
                    VarPage.RunModal();
                end;
            }
            action(AbrirDetalle)
            {
                ApplicationArea = All;
                Caption = 'Abrir con Variables';
                Image = AllLines;
                ToolTip = 'Abre la lista de líneas en una vista completa con las variables del cálculo por línea en el panel lateral.';
                trigger OnAction()
                var
                    LinLiq: Record "Línea Liquidación";
                begin
                    LinLiq.SetRange("No. Liquidación", Rec."No. Liquidación");
                    LinLiq := Rec;
                    Page.Run(Page::"Líneas Liq. con Variables", LinLiq);
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
            Rec."Tipo Concepto"::"Descuento Empleado",
            Rec."Tipo Concepto"::Retención:
                TipoStyle := 'Unfavorable';
            Rec."Tipo Concepto"::"Contribución Patronal":
                TipoStyle := 'Attention';
        end;
    end;

    var
        TipoStyle: Text;
        OcultarCero: Boolean;
}
