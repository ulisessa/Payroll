namespace UAS.Payroll;

page 110046 "Detalle Cálculo Línea"
{
    Caption = 'Detalle del cálculo';
    PageType = Card;
    Editable = false;
    UsageCategory = None;
    ApplicationArea = All;
    layout
    {
        area(Content)
        {
            group(Resumen)
            {
                Caption = 'Resultado de la liquidación';
                field(Concepto; ConceptoTxt) { Caption = 'Concepto'; }
                field(Importe; ImporteLinea) { Caption = 'Importe guardado'; DecimalPlaces = 2 : 2; Style = Strong; Visible = not DevengoFranco; }
                field(DiasDevengados; Linea.Cantidad) { Caption = 'Días de franco devengados'; Visible = DevengoFranco; }
                field(ConvenioDevengo; Linea."Cód. Convenio") { Caption = 'Convenio de origen'; Visible = DevengoFranco; }
                field(CategoriaDevengo; Linea."Cód. Categoría") { Caption = 'Categoría de origen'; Visible = DevengoFranco; }
                field(Estado; EstadoTxt) { Caption = 'Comprobación'; MultiLine = true; StyleExpr = EstadoStyle; }
            }
            group(Formula)
            {
                Caption = 'Cómo se aplicó la fórmula';
                Visible = not CalculoInterno;
                field(FormulaOriginal; FormulaTxt) { Caption = 'Fórmula utilizada'; MultiLine = true; }
                field(FormulaValores; ValoresTxt) { Caption = 'La misma fórmula con los valores utilizados'; MultiLine = true; }
            }
            group(BaseGanancias)
            {
                Caption = '1. Formación de la base imponible';
                Visible = Ganancias;
                part(Base; "Pasos Cálculo Sub") { Caption = 'Detalle'; }
            }
            group(EscalaGanancias)
            {
                Caption = '2. Aplicación de la escala';
                Visible = Ganancias;
                part(Escala; "Pasos Cálculo Sub") { Caption = 'Detalle'; }
            }
            group(RetencionGanancias)
            {
                Caption = '3. Retención de esta liquidación';
                Visible = Ganancias;
                part(Retencion; "Pasos Cálculo Sub") { Caption = 'Detalle'; }
            }
            group(DatosFormula)
            {
                Caption = 'Datos utilizados';
                Visible = not Ganancias;
                part(Datos; "Pasos Cálculo Sub") { Caption = 'Detalle'; }
            }
            group(PasosFormula)
            {
                Caption = 'Desarrollo y resultado';
                Visible = not Ganancias;
                part(Pasos; "Pasos Cálculo Sub") { Caption = 'Detalle'; }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(Deducciones)
            {
                Caption = 'Desglose de deducciones';
                Image = List;
                Visible = Ganancias;
                trigger OnAction()
                var
                    Det: Record "Detalle Ganancias Liq.";
                begin
                    Det.SetRange("No. Liquidación", Linea."No. Liquidación");
                    Det.SetFilter(Tipo, '%1|%2', Det.Tipo::Familiar, Det.Tipo::Gasto);
                    Page.RunModal(Page::"Deducciones Aplicadas Liq.", Det);
                end;
            }
        }
    }
    var
        Linea: Record "Línea Liquidación";
        Datos: Record "Paso Cálculo Línea" temporary;
        Pasos: Record "Paso Cálculo Línea" temporary;
        Base: Record "Paso Cálculo Línea" temporary;
        Escala: Record "Paso Cálculo Línea" temporary;
        Retencion: Record "Paso Cálculo Línea" temporary;
        ConceptoTxt: Text;
        FormulaTxt: Text;
        ValoresTxt: Text;
        EstadoTxt: Text;
        EstadoStyle: Text;
        ImporteLinea: Decimal;
        Ganancias: Boolean;
        DevengoFranco: Boolean;
        CalculoInterno: Boolean;

    procedure CargarDesdeLinea(LinLiq: Record "Línea Liquidación")
    var
        Constructor: Codeunit "Detalle Cálculo Línea";
        Presentacion: Codeunit "Presentación Cálculo Liq.";
        Concepto: Record "Concepto Liquidación";
        LineaComprobacion: Record "Línea Liquidación";
    begin
        Clear(FormulaTxt);
        Clear(ValoresTxt);
        DevengoFranco := false;
        Linea := LinLiq;
        ConceptoTxt := Linea."Cód. Concepto" + ' · ' + Linea."Descripción Concepto";
        ImporteLinea := Linea.Importe;
        Ganancias := Presentacion.EsGanancias(Linea);
        if Concepto.Get(Linea."Cód. Concepto", Linea."Vigencia Concepto") then
            DevengoFranco := Concepto."Rol Franco" = Concepto."Rol Franco"::Devengo;
        CalculoInterno := Ganancias or DevengoFranco;
        if Ganancias then
            CurrPage.Caption := 'Detalle de Ganancias'
        else if not CalculoInterno then begin
            FormulaTxt := Linea."Fórmula Aplicada";
            ValoresTxt := Linea."Fórmula Evaluada";
        end;
        LineaComprobacion := Linea;
        if DevengoFranco then begin
            CurrPage.Caption := 'Detalle del devengo de francos';
            LineaComprobacion.Importe := Linea.Cantidad;
        end;
        Constructor.Construir(LineaComprobacion, Pasos);
        EstadoTxt := 'No comprobado: no hay información suficiente para reconstruir el cálculo.';
        EstadoStyle := 'Attention';
        if Pasos.FindLast() then begin
            EstadoTxt := Pasos.Descripción;
            if Pasos."Es Total" then
                if Abs(Pasos.Valor - LineaComprobacion.Importe) <= 0.01 then
                    EstadoStyle := 'Favorable'
                else
                    EstadoStyle := 'Unfavorable';
        end;
        if DevengoFranco then
            EstadoTxt := EstadoTxt.Replace('importe de la línea', 'cantidad de días guardada');
        Presentacion.CargarDatos(Linea, Datos);
        if Ganancias then
            Presentacion.CargarGanancias(Linea, Pasos, Datos, Base, Escala, Retencion);
        // El aviso ya figura en la cabecera; no presentarlo otra vez como una cuenta de cero.
        if not Pasos."Es Total" then
            if not Ganancias then
                Pasos.DeleteAll();
        CurrPage.Datos.Page.Cargar(Datos, not CalculoInterno, false);
        CurrPage.Pasos.Page.Cargar(Pasos, not CalculoInterno, true);
        CurrPage.Base.Page.Cargar(Base, false, true);
        CurrPage.Escala.Page.Cargar(Escala, false, false);
        CurrPage.Retencion.Page.Cargar(Retencion, false, true);
    end;
}
