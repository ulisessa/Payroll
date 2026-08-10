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
                    ToolTip = 'Abre la ficha del concepto (la versión/vigencia que se usó en esta línea).';
                    trigger OnDrillDown()
                    begin
                        AbrirConcepto();
                    end;
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
                field("Base Cálculo"; Rec."Base Cálculo") { ApplicationArea = All; }
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
                Caption = 'Mostrar importes cero';
                Image = Filter;
                ToolTip = 'Muestra u oculta los conceptos con importe cero.';
                trigger OnAction()
                begin
                    OcultarCero := not OcultarCero;
                    ApplyFilters();
                end;
            }
            action(ToggleNoImprimibles)
            {
                ApplicationArea = All;
                Caption = 'Mostrar no imprimibles';
                Image = PrintReport;
                ToolTip = 'Muestra u oculta los conceptos que no se imprimen en el recibo.';
                trigger OnAction()
                begin
                    OcultarNoImprimibles := not OcultarNoImprimibles;
                    ApplyFilters();
                end;
            }
            action(ToggleAcumuladores)
            {
                ApplicationArea = All;
                Caption = 'Mostrar acumuladores';
                Image = Totals;
                ToolTip = 'Muestra u oculta los acumuladores (tipo Informativo) en la lista de líneas.';
                trigger OnAction()
                begin
                    OcultarAcumuladores := not OcultarAcumuladores;
                    ApplyFilters();
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
            action(VerAcumulador)
            {
                ApplicationArea = All;
                Caption = 'Detalle Acumulador';
                Image = Totals;
                ToolTip = 'Muestra los conceptos que componen este acumulador y sus importes aportados.';
                Enabled = EsAcumulador;
                trigger OnAction()
                var
                    DetPage: Page "Detalle Acumulador Liq.";
                begin
                    DetPage.LoadFromLiquidacion(Rec."No. Liquidación", Rec."Cód. Concepto");
                    // Acá se abre desde la línea DEL acumulador, así que su propio Importe es el
                    // valor final: contra la suma de los aportes detecta que el total y el detalle
                    // se calculan por caminos distintos y pueden discrepar.
                    DetPage.SetValorUsado(Rec.Importe);
                    DetPage.Caption := Rec."Cód. Concepto" + ' - ' + Rec."Descripción Concepto";
                    DetPage.RunModal();
                end;
            }
            action(AbrirConceptoAction)
            {
                ApplicationArea = All;
                Caption = 'Abrir Concepto';
                Image = Card;
                ToolTip = 'Abre la ficha del concepto (la versión/vigencia que se usó en esta línea).';
                trigger OnAction()
                begin
                    AbrirConcepto();
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

    trigger OnOpenPage()
    begin
        OcultarCero := true;
        OcultarNoImprimibles := true;
        OcultarAcumuladores := true;
        ApplyFilters();
    end;

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
        EsAcumulador := IsAcumulador();
    end;

    // "Es Acumulador" del concepto real, no "Tipo Concepto = Informativo" — un concepto puede
    // ser Informativo (ej. un crédito fiscal no pagable) sin ser él mismo un acumulador, y
    // "Ver Acumulador" solo tiene sentido cuando el código de esta línea es un acumulador de verdad.
    local procedure IsAcumulador(): Boolean
    var
        Concepto: Record "Concepto Liquidación";
    begin
        if Rec."Cód. Concepto" = '' then exit(false);
        if Concepto.Get(Rec."Cód. Concepto", Rec."Vigencia Concepto") then
            exit(Concepto."Es Acumulador");
        Concepto.SetRange(Código, Rec."Cód. Concepto");
        Concepto.SetRange("Es Acumulador", true);
        exit(not Concepto.IsEmpty());
    end;

    // Opens the exact concept version used for this line (matched by Vigencia Concepto), not just
    // whatever version happens to be latest today — concepts have their own version history, and an
    // old liquidación should link back to the version that was actually in effect when it calculated.
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

    local procedure ApplyFilters()
    begin
        if OcultarCero then
            Rec.SetFilter(Importe, '<>0')
        else
            Rec.SetRange(Importe);

        if OcultarNoImprimibles then
            Rec.SetRange("Imprime en Recibo", true)
        else
            Rec.SetRange("Imprime en Recibo");

        if OcultarAcumuladores then
            Rec.SetFilter("Tipo Concepto", '<>%1', Rec."Tipo Concepto"::Informativo)
        else
            Rec.SetRange("Tipo Concepto");

        CurrPage.Update(false);
    end;

    var
        TipoStyle: Text;
        EsAcumulador: Boolean;
        OcultarCero: Boolean;
        OcultarNoImprimibles: Boolean;
        OcultarAcumuladores: Boolean;
        MsgConceptoNoEncontrado: Label 'No se encontró el concepto %1.';
}
