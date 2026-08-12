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
                    StyleExpr = FilaStyle;
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
                field("Imprime en Recibo"; Rec."Imprime en Recibo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Indica si esta línea sale impresa en el recibo. Las que no se imprimen se muestran atenuadas.';
                }
                field("Vigencia Concepto"; Rec."Vigencia Concepto")
                {
                    ApplicationArea = All;
                }
                field("Vigencias Distribución"; Rec."Vigencias Distribución")
                {
                    ApplicationArea = All;
                    Visible = false;
                    ToolTip = 'Con qué vigencia de la distribución se acumuló esta línea, un acumulador por entrada. Sirve para detectar si una fracción cargada con fecha retroactiva cambiaría el resultado de un recálculo.';
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
            // Cada alternador son DOS acciones que se turnan la visibilidad, y no una sola con el
            // texto cambiando: en AL, Caption de una acción es constante y no admite expresión, así
            // que es la única forma de que el botón diga siempre lo que va a hacer.
            action(MostrarCeroAction)
            {
                ApplicationArea = All;
                Caption = 'Mostrar importes cero';
                Image = Filter;
                Visible = CeroEstanOcultos;
                ToolTip = 'Muestra también los conceptos con importe cero.';
                trigger OnAction()
                begin
                    OcultarCero := false;
                    ApplyFilters();
                end;
            }
            action(OcultarCeroAction)
            {
                ApplicationArea = All;
                Caption = 'Ocultar importes cero';
                Image = Filter;
                Visible = CeroEstanVisibles;
                ToolTip = 'Oculta los conceptos con importe cero.';
                trigger OnAction()
                begin
                    OcultarCero := true;
                    ApplyFilters();
                end;
            }
            action(MostrarNoImprimiblesAction)
            {
                ApplicationArea = All;
                Caption = 'Mostrar no imprimibles';
                Image = PrintReport;
                Visible = NoImprimiblesEstanOcultos;
                ToolTip = 'Muestra también los conceptos que no salen en el recibo.';
                trigger OnAction()
                begin
                    OcultarNoImprimibles := false;
                    ApplyFilters();
                end;
            }
            action(OcultarNoImprimiblesAction)
            {
                ApplicationArea = All;
                Caption = 'Ocultar no imprimibles';
                Image = PrintReport;
                Visible = NoImprimiblesEstanVisibles;
                ToolTip = 'Oculta los conceptos que no salen en el recibo.';
                trigger OnAction()
                begin
                    OcultarNoImprimibles := true;
                    ApplyFilters();
                end;
            }
            action(MostrarAcumuladoresAction)
            {
                ApplicationArea = All;
                Caption = 'Mostrar acumuladores';
                Image = Totals;
                Visible = AcumuladoresEstanOcultos;
                ToolTip = 'Muestra también los acumuladores (tipo Informativo) en la lista de líneas.';
                trigger OnAction()
                begin
                    OcultarAcumuladores := false;
                    ApplyFilters();
                end;
            }
            action(OcultarAcumuladoresAction)
            {
                ApplicationArea = All;
                Caption = 'Ocultar acumuladores';
                Image = Totals;
                Visible = AcumuladoresEstanVisibles;
                ToolTip = 'Oculta los acumuladores (tipo Informativo) de la lista de líneas.';
                trigger OnAction()
                begin
                    OcultarAcumuladores := true;
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
            Rec."Tipo Concepto"::"Descuento Empleado",
            Rec."Tipo Concepto"::Retención:
                TipoStyle := 'Unfavorable';
            Rec."Tipo Concepto"::"Contribución Patronal":
                TipoStyle := 'Attention';
        end;
        EsAcumulador := IsAcumulador();
        // Cuando se destapan las no imprimibles hay que poder distinguirlas de un vistazo, si no la
        // lista mezcla lo que el empleado ve en el recibo con lo que es interno del cálculo.
        if Rec."Imprime en Recibo" then
            FilaStyle := 'Standard'
        else
            FilaStyle := 'Subordinate';
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
        // Los pares de banderas alimentan la visibilidad de los botones. Se recalculan acá, que es
        // el único lugar por donde pasan los tres alternadores.
        CeroEstanOcultos := OcultarCero;
        CeroEstanVisibles := not OcultarCero;
        NoImprimiblesEstanOcultos := OcultarNoImprimibles;
        NoImprimiblesEstanVisibles := not OcultarNoImprimibles;
        AcumuladoresEstanOcultos := OcultarAcumuladores;
        AcumuladoresEstanVisibles := not OcultarAcumuladores;

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
        FilaStyle: Text;
        EsAcumulador: Boolean;
        OcultarCero: Boolean;
        OcultarNoImprimibles: Boolean;
        OcultarAcumuladores: Boolean;
        CeroEstanOcultos: Boolean;
        CeroEstanVisibles: Boolean;
        NoImprimiblesEstanOcultos: Boolean;
        NoImprimiblesEstanVisibles: Boolean;
        AcumuladoresEstanOcultos: Boolean;
        AcumuladoresEstanVisibles: Boolean;
        MsgConceptoNoEncontrado: Label 'No se encontró el concepto %1.';
}
