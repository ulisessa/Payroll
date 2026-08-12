namespace UAS.Payroll;

page 50174 "Detalle Acumulador Liq."
{
    ApplicationArea = All;
    Caption = 'Detalle Acumulador';
    PageType = List;
    SourceTable = "Detalle Acumulador Liq.";
    SourceTableTemporary = true;
    Editable = false;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Cód. Concepto"; Rec."Cód. Concepto") { ApplicationArea = All; }
                field("Descripción Concepto"; Rec."Descripción Concepto") { ApplicationArea = All; }
                field("Importe Concepto"; Rec."Importe Concepto") { ApplicationArea = All; }
                field(Porcentaje; Rec.Porcentaje) { ApplicationArea = All; }
                field(InvertirSigno; Rec."Invertir Signo") { ApplicationArea = All; }
                field("Importe Aportado"; Rec."Importe Aportado")
                {
                    ApplicationArea = All;
                    Style = Strong;
                    StyleExpr = true;
                }
            }
            group(GrpTotales)
            {
                Caption = 'Control';

                field(TotalSuman; TotalSuman)
                {
                    ApplicationArea = All;
                    Caption = 'Aportes que suman';
                    Editable = false;
                    DecimalPlaces = 2 : 6;
                    ToolTip = 'Total de los conceptos que entran sumando.';
                }
                field(TotalRestan; TotalRestan)
                {
                    ApplicationArea = All;
                    Caption = 'Aportes que restan';
                    Editable = false;
                    DecimalPlaces = 2 : 6;
                    StyleExpr = RestanStyle;
                    ToolTip = 'Total de los conceptos con "Invertir signo" tildado. El signo con el que un concepto entra al acumulador NO sale del Tipo Concepto: sale de este flag, y se configura por acumulador. Un concepto puede restar en uno y sumar en otro. Si esperabas que algo descontara y acá ves 0,00, falta tildar "Invertir signo" en su fila de Fracción Acumulador.';
                }
                field(TotalDetalle; TotalDetalle)
                {
                    ApplicationArea = All;
                    Caption = 'Suma del detalle';
                    Editable = false;
                    DecimalPlaces = 2 : 6;
                    Style = Strong;
                    StyleExpr = true;
                    ToolTip = 'Neto de los aportes, con todos sus decimales. Las filas de arriba se muestran redondeadas a 2 decimales, así que sumarlas a ojo da una diferencia de centavos que no es un error.';
                }
                field(ValorUsado; ValorUsado)
                {
                    ApplicationArea = All;
                    Caption = 'Valor usado en el cálculo';
                    Editable = false;
                    Visible = TieneValorUsado;
                    DecimalPlaces = 2 : 6;
                    ToolTip = 'Valor que tenía el acumulador cuando se calculó la línea desde la que abriste este detalle.';
                }
                field(Diferencia; Diferencia)
                {
                    ApplicationArea = All;
                    Caption = 'Diferencia';
                    Editable = false;
                    Visible = TieneValorUsado;
                    DecimalPlaces = 2 : 6;
                    StyleExpr = DiferenciaStyle;
                    ToolTip = 'Suma del detalle menos el valor usado. Distinto de cero significa que la línea se calculó con un acumulador incompleto: hay conceptos que aportan DESPUÉS, en el Orden Cálculo, de que esta línea lo leyera. Verificalo con el Control de Orden de Cálculo.';
                }
                field(Diagnostico; Diagnostico)
                {
                    ApplicationArea = All;
                    ShowCaption = false;
                    Editable = false;
                    Visible = TieneValorUsado;
                    MultiLine = true;
                    StyleExpr = DiferenciaStyle;
                }
            }
        }
    }

    procedure LoadFromLiquidacion(LiqNo: Code[20]; CodAcumulador: Code[20])
    var
        Liq: Record "Liquidación";
        Lin: Record "Línea Liquidación";
        Frac: Record "Fracción Acumulador";
        FechaRef: Date;
        ImporteAportado: Decimal;
    begin
        Rec.Reset();
        Rec.DeleteAll();
        TotalDetalle := 0;
        TotalSuman := 0;
        TotalRestan := 0;

        if not Liq.Get(LiqNo) then exit;
        FechaRef := Liq."Fecha Liquidación";

        // No se filtra por "Tipo Concepto" — un concepto puede estar clasificado como
        // Informativo (ej. un crédito fiscal que no es un haber pagable) y aun así alimentar
        // legítimamente este acumulador. Lo único que nunca debe aparecer como origen es un
        // acumulador propiamente dicho, pero eso ya está garantizado por diseño: un concepto
        // con "Es Acumulador" = true nunca tiene fila propia en Fracción Acumulador como origen.
        Lin.SetRange("No. Liquidación", LiqNo);
        if not Lin.FindSet() then
            exit;

        repeat
            Frac.SetRange("Cód. Concepto", Lin."Cód. Concepto");
            Frac.SetRange("Cód. Acumulador", CodAcumulador);
            Frac.SetFilter("Vigencia Desde", '<=%1', FechaRef);
            if Frac.FindLast() then begin
                if Frac."Invertir Signo" then
                    ImporteAportado := -(Lin.Importe * Frac.Porcentaje / 100)
                else
                    ImporteAportado := Lin.Importe * Frac.Porcentaje / 100;

                if ImporteAportado <> 0 then begin
                    Rec.Init();
                    Rec."Cód. Concepto" := Lin."Cód. Concepto";
                    Rec."Descripción Concepto" := Lin."Descripción Concepto";
                    Rec."Importe Concepto" := Lin.Importe;
                    Rec.Porcentaje := Frac.Porcentaje;
                    Rec."Invertir Signo" := Frac."Invertir Signo";
                    Rec."Importe Aportado" := ImporteAportado;
                    Rec.Insert();
                    TotalDetalle += ImporteAportado;
                    // Se agrupa por el signo REAL del aporte y no por el flag "Invertir signo".
                    // Desde que el importe de la línea lleva signo propio, las dos cosas dejaron de
                    // coincidir: una línea negativa sin el flag tildado resta, y agrupada por flag
                    // habría caído en "Suman" dejando ese total en un número negativo.
                    if ImporteAportado < 0 then
                        TotalRestan += ImporteAportado
                    else
                        TotalSuman += ImporteAportado;
                end;
            end;
        until Lin.Next() = 0;

        ActualizarDiagnostico();
        if Rec.FindFirst() then;
    end;

    /// <summary>
    /// Valor que tenía el acumulador cuando se calculó la línea desde la que se abre este detalle.
    /// </summary>
    /// <remarks>
    /// Comparado contra la suma real de los aportes, delata en el acto el error de orden de cálculo:
    /// si la línea leyó el acumulador antes de que todos los conceptos hubieran aportado, usó un
    /// subtotal y acá se ve la diferencia. Sin esto había que sumar la grilla a mano — y como las
    /// filas se muestran a 2 decimales, esa suma nunca cierra del todo y no se distingue el
    /// redondeo de un aporte faltante.
    /// </remarks>
    procedure SetValorUsado(Valor: Decimal)
    begin
        ValorUsado := Valor;
        TieneValorUsado := true;
        ActualizarDiagnostico();
    end;

    local procedure ActualizarDiagnostico()
    begin
        // Resaltado cuando NADIE resta: es el caso en que alguien esperaba un descuento y la fila de
        // Fracción Acumulador quedó sin tildar "Invertir signo". El acumulador da de más y no hay ningún
        // error que lo delate.
        if TotalRestan = 0 then
            RestanStyle := 'Attention'
        else
            RestanStyle := 'Unfavorable';

        Diferencia := 0;
        Diagnostico := '';
        DiferenciaStyle := 'Subordinate';
        if not TieneValorUsado then
            exit;

        Diferencia := TotalDetalle - ValorUsado;
        // Un centavo de tolerancia: las fórmulas redondean a 0,0001, así que sumar quince aportes
        // deja siempre unas milésimas de diferencia que no significan nada.
        if Abs(Diferencia) <= 0.01 then begin
            Diagnostico := CoincideTxt;
            DiferenciaStyle := 'Favorable';
        end else begin
            Diagnostico := FaltanAportesTxt;
            DiferenciaStyle := 'Unfavorable';
        end;
    end;

    var
        TotalDetalle: Decimal;
        TotalSuman: Decimal;
        TotalRestan: Decimal;
        RestanStyle: Text[20];
        ValorUsado: Decimal;
        Diferencia: Decimal;
        TieneValorUsado: Boolean;
        DiferenciaStyle: Text[20];
        Diagnostico: Text[250];
        CoincideTxt: Label 'El cálculo usó el acumulador completo. La diferencia de centavos es el redondeo de mostrar las filas a 2 decimales.';
        FaltanAportesTxt: Label 'El cálculo usó un acumulador incompleto: hay conceptos que aportan más tarde en el Orden Cálculo que la línea que lo leyó. Corré el Control de Orden de Cálculo.';
}
