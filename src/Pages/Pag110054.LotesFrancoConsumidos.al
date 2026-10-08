namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

page 110054 "Lotes Franco Consumidos"
{
    // De dónde salió el importe de un pago de francos.
    //
    // El 1063 muestra una cantidad de días y un importe, y hasta ahora no había forma de ver por qué
    // ese importe: el precio no sale del concepto sino del ledger FIFO, que consume lotes viejos
    // primero y valúa cada uno con el convenio y la categoría que el empleado tenía CUANDO LO DEVENGÓ.
    // Un tripulante que ascendió cobra sus francos viejos al valor viejo, y eso es correcto aunque en
    // el recibo parezca un error.
    //
    // Se abre desde la línea del concepto de franco. No guarda nada: reconstruye el recorrido con la
    // misma exclusión de la liquidación en curso que usó el cálculo.

    Caption = 'Lotes de franco consumidos';
    PageType = List;
    SourceTable = "Lote Franco Buffer Liq.";
    SourceTableTemporary = true;
    Editable = false;
    UsageCategory = None;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(Encabezado)
            {
                ShowCaption = false;

                field(Empleado; FEmpleado)
                {
                    Caption = 'Empleado';
                    Editable = false;
                    ToolTip = 'Empleado al que se le están pagando los francos.';
                }
                field(DiasPagados; FDiasPagados)
                {
                    Caption = 'Días pagados';
                    DecimalPlaces = 0 : 2;
                    Editable = false;
                    ToolTip = 'Días de franco que paga esta línea. Es lo que el FIFO repartió entre los lotes de abajo.';
                }
                field(ImporteLinea; FImporteLinea)
                {
                    Caption = 'Importe de la línea';
                    Editable = false;
                    ToolTip = 'Importe de la línea de liquidación. Si no coincide con el total del desglose, el cálculo y este detalle están mirando saldos distintos: conviene recalcular.';
                    StyleExpr = FEstiloImporte;
                }
            }

            repeater(Lotes)
            {
                field("No. Línea"; Rec."No. Línea") { ApplicationArea = All; }
                field("Fecha Lote"; Rec."Fecha Lote") { ApplicationArea = All; }
                field("No. Liquidación Origen"; Rec."No. Liquidación Origen") { ApplicationArea = All; }
                field("No. Proyecto"; Rec."No. Proyecto") { ApplicationArea = All; }
                field("Tipo Buque"; Rec."Tipo Buque") { ApplicationArea = All; }
                field("Cód. Convenio"; Rec."Cód. Convenio") { ApplicationArea = All; }
                field("Cód. Categoría"; Rec."Cód. Categoría") { ApplicationArea = All; }
                field("Descripción Categoría"; Rec."Descripción Categoría") { ApplicationArea = All; }
                field("Días del Lote"; Rec."Días del Lote") { ApplicationArea = All; Visible = false; }
                field("Días Disponibles"; Rec."Días Disponibles") { ApplicationArea = All; Visible = false; }
                field("Días Tomados"; Rec."Días Tomados") { ApplicationArea = All; }
                field("Valor Franco"; Rec."Valor Franco") { ApplicationArea = All; }
                field(Coeficiente; Rec.Coeficiente) { ApplicationArea = All; }
                field(Importe; Rec.Importe) { ApplicationArea = All; }
                field("Cód. Concepto Lote"; Rec."Cód. Concepto Lote") { ApplicationArea = All; Visible = false; }
            }

            group(Totales)
            {
                ShowCaption = false;

                field(TotalDias; FTotalDias)
                {
                    Caption = 'Total días';
                    DecimalPlaces = 0 : 2;
                    Editable = false;
                    ToolTip = 'Suma de los días tomados de todos los lotes.';
                }
                field(TotalImporte; FTotalImporte)
                {
                    Caption = 'Total importe';
                    Editable = false;
                    ToolTip = 'Suma de los importes de los lotes. Tiene que dar igual al importe de la línea.';
                    StyleExpr = FEstiloImporte;
                }
            }
        }
    }

    var
        FEmpleado: Text[120];
        FDiasPagados: Decimal;
        FImporteLinea: Decimal;
        FTotalDias: Decimal;
        FTotalImporte: Decimal;
        FEstiloImporte: Text;

    /// <summary>Carga el desglose de una línea de consumo de francos.</summary>
    /// <remarks>
    /// La fecha de pago y la liquidación a excluir salen de la línea, no de la fecha de trabajo: el
    /// desglose tiene que reproducir el momento del cálculo, no el de hoy.
    /// </remarks>
    procedure CargarDesde(LinLiq: Record "Línea Liquidación")
    var
        FrancosMgt: Codeunit "Gestión Francos";
        CtxBuilder: Codeunit "Contexto Liquidación";
        Empl: Record Employee;
        TiposCambioFrancos: Dictionary of [Text, Decimal];
    begin
        Rec.Reset();
        Rec.DeleteAll();

        // SIN ESTO EL DETALLE NO ABRE. Esta instancia del ledger nace con el diccionario de
        // cotizaciones vacío, así que el primer lote cuyo precio esté en divisa corta con
        // "la cotización TC_COMPRADOR no existe en el contexto de la liquidación" —visto al abrir
        // el detalle de un OF04 con VALOR_FRANCO_CAL—. Una instancia de Gestión Francos no ve lo
        // que se le publicó a otra, y acá no hay contexto que lo haya hecho: la liquidación ya está
        // calculada y lo único que se reconstruye es el desglose.
        CtxBuilder.TiposCambioFrancosAFecha(
            LinLiq."No. Empleado",
            LinLiq."Fecha Liquidación",
            FrancosMgt.MonedaDelPrecio(LinLiq."Fecha Liquidación"),
            TiposCambioFrancos);
        FrancosMgt.PublicarTiposCambio(TiposCambioFrancos);

        FEmpleado := LinLiq."No. Empleado";
        if Empl.Get(LinLiq."No. Empleado") then
            FEmpleado := CopyStr(LinLiq."No. Empleado" + ' — ' + Empl."First Name" + ' ' + Empl."Last Name", 1, MaxStrLen(FEmpleado));
        FDiasPagados := LinLiq.Cantidad;
        FImporteLinea := LinLiq.Importe;

        FrancosMgt.DetallePorLote(LinLiq."No. Empleado", LinLiq.Cantidad, LinLiq."Fecha Liquidación", LinLiq."No. Liquidación", Rec);

        FTotalDias := 0;
        FTotalImporte := 0;
        if Rec.FindSet() then
            repeat
                FTotalDias += Rec."Días Tomados";
                FTotalImporte += Rec.Importe;
            until Rec.Next() = 0;

        // Que el desglose no cierre contra la línea no es cosmético: significa que el saldo de lotes
        // cambió después del cálculo, y entonces el recibo está apoyado en algo que ya no existe.
        if Abs(FTotalImporte - FImporteLinea) > 0.01 then
            FEstiloImporte := 'Unfavorable'
        else
            FEstiloImporte := 'Favorable';

        if Rec.FindFirst() then;
    end;
}
