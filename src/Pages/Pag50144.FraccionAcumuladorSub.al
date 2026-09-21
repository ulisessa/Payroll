namespace UAS.Payroll;

page 50144 "Fracción Acumulador Sub"
{
    ApplicationArea = All;
    Caption = 'Distribución en acumuladores';
    PageType = ListPart;
    SourceTable = "Fracción Acumulador";
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Vigente; Vigente)
                {
                    ApplicationArea = All;
                    Caption = 'Vigente';
                    Editable = false;
                    Width = 7;
                    // Marca las filas que el motor aplicaría para ESTA versión del concepto: por cada
                    // acumulador, la de mayor Vigencia Desde que no supere la fecha de evaluación
                    // (misma regla que BuildFractionCache en Cod50014). Las demás son historia o
                    // configuración futura.
                    ToolTip = 'Tildado = es la fila que el motor usaría para este acumulador. Si la versión del concepto sigue abierta se evalúa a la fecha de trabajo; si está cerrada, a su último día. Sin tildar = quedó desplazada por una posterior, o todavía no entró en vigor.';
                }
                field("Vigencia Desde"; Rec."Vigencia Desde")
                {
                    ApplicationArea = All;
                    StyleExpr = FilaStyle;
                    ToolTip = 'Desde cuándo rige esta distribución. Se versiona por separado de la vigencia del concepto: cambiar la fórmula no obliga a redeclarar la distribución.';
                }
                field("Cód. Acumulador"; Rec."Cód. Acumulador")
                {
                    ApplicationArea = All;
                    StyleExpr = FilaStyle;
                }
                field(DescAccumulator; AccumDesc)
                {
                    ApplicationArea = All;
                    Caption = 'Descripción';
                    Editable = false;
                    StyleExpr = FilaStyle;
                }
                field(Porcentaje; Rec.Porcentaje)
                {
                    ApplicationArea = All;
                    Caption = '% Importe';
                    StyleExpr = FilaStyle;
                }
                field(InvertirSigno; Rec."Invertir Signo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Si está activo, el importe se resta del acumulador en lugar de sumarse. Útil para conceptos de descuento que deben cancelar base de cálculo.';
                }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
            }
        }
    }

    /// <summary>
    /// Concepto e INTERVALO de la versión contra la que se evalúa qué filas están vigentes.
    /// </summary>
    /// <remarks>
    /// La ficha ya no filtra la subpágina por la vigencia del concepto: la distribución tiene su
    /// propia línea de tiempo y el motor la resuelve por separado, así que filtrar por fecha exacta
    /// mostraba vacío justo después de crear una vigencia nueva — mientras el motor seguía aplicando
    /// la distribución anterior. Ahora se listan todas y se marca cuál rige.
    /// </remarks>
    procedure SetContexto(CodConcepto: Code[20]; VigenciaDesde: Date; VigenciaHasta: Date)
    begin
        FCodConcepto := CodConcepto;
        FFechaRef := FechaEvaluacion(VigenciaDesde, VigenciaHasta);
        // El default de una fila nueva sigue siendo el inicio de la versión, no la fecha de
        // evaluación: al declarar la distribución de una vigencia recién creada, lo que se quiere es
        // que arranque con ella.
        FFechaVersion := VigenciaDesde;
        CurrPage.Update(false);
    end;

    /// <summary>
    /// La fecha que representa a esta versión del concepto para resolver la distribución.
    /// </summary>
    /// <remarks>
    /// Evaluar contra el INICIO de la versión era una foto del pasado: una distribución cargada
    /// después salía "no vigente" aunque el concepto siguiera abierto y el motor la estuviera
    /// aplicando en cada liquidación. Las dos líneas de tiempo son independientes justamente para
    /// eso — cambiar la distribución en 2026 no obliga a versionar el concepto.
    ///
    ///  · Versión abierta → la fecha de trabajo: lo que el motor usaría al liquidar hoy.
    ///  · Versión cerrada → su último día, que es lo último que esa versión llegó a aplicar.
    ///  · Versión que todavía no empezó → su inicio; antes de esa fecha no hay nada que mostrar.
    /// </remarks>
    local procedure FechaEvaluacion(VigenciaDesde: Date; VigenciaHasta: Date): Date
    begin
        if VigenciaHasta <> 0D then
            exit(VigenciaHasta);
        if VigenciaDesde > WorkDate() then
            exit(VigenciaDesde);
        exit(WorkDate());
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        // Antes la venía completando el SubPageLink; sin él hay que ponerla, o la fila nueva queda
        // con fecha vacía y no entra en ninguna resolución del motor.
        if Rec."Vigencia Desde" = 0D then
            Rec."Vigencia Desde" := FFechaVersion;
    end;

    trigger OnAfterGetRecord()
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Concepto.SetRange(Código, Rec."Cód. Acumulador");
        if Concepto.FindLast() then
            AccumDesc := Concepto.Descripción
        else
            AccumDesc := '';

        Vigente := EsVigenteAFecha();
        if Vigente then
            FilaStyle := 'Strong'
        else
            FilaStyle := 'Subordinate';
    end;

    // Misma regla que BuildFractionCache (Cod50014): por cada par concepto+acumulador rige la fila
    // de mayor Vigencia Desde que no supere la fecha de referencia. Una fila queda desplazada si
    // existe otra posterior que tampoco la supere.
    local procedure EsVigenteAFecha(): Boolean
    var
        Posterior: Record "Fracción Acumulador";
    begin
        if FFechaRef = 0D then
            exit(true);
        if Rec."Vigencia Desde" > FFechaRef then
            exit(false);

        Posterior.SetRange("Cód. Concepto", Rec."Cód. Concepto");
        Posterior.SetRange("Cód. Acumulador", Rec."Cód. Acumulador");
        Posterior.SetFilter("Vigencia Desde", '>%1&<=%2', Rec."Vigencia Desde", FFechaRef);
        exit(Posterior.IsEmpty());
    end;

    var
        AccumDesc: Text[100];
        FCodConcepto: Code[20];
        FFechaRef: Date;
        FFechaVersion: Date;
        Vigente: Boolean;
        FilaStyle: Text[20];
}
