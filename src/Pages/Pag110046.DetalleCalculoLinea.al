namespace UAS.Payroll;

/// <summary>
/// El paso a paso del cálculo de una línea de liquidación: cada término de la
/// fórmula con su signo, su valor y el total corriente.
///
/// Sirve para CUALQUIER concepto, no sólo para ganancias. El orden y el signo
/// salen de la fórmula, así que no hay nada que configurar: un concepto nuevo
/// queda explicado el día que se escribe su fórmula.
/// </summary>
page 110046 "Detalle Cálculo Línea"
{
    Caption = 'Detalle del Cálculo';
    PageType = List;
    SourceTable = "Paso Cálculo Línea";
    SourceTableTemporary = true;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            group(Encabezado)
            {
                Caption = 'Línea';
                ShowCaption = false;

                field(ConceptoTxt; ConceptoTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Concepto';
                    Editable = false;
                }
                field(ImporteTxt; ImporteTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Importe de la línea';
                    Editable = false;
                }
                field(FormulaTxt; FormulaTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Fórmula aplicada';
                    Editable = false;
                    MultiLine = true;
                }
            }

            repeater(Pasos)
            {
                // SANGRÍA NATIVA, PERO NO ÁRBOL. El árbol exige que el padre venga antes que sus
                // hijos, y acá el orden es el del CÁLCULO: el TRAMO va después de la base, que es
                // donde realmente se resuelve. Se gana fidelidad y se pierde el plegado; con los
                // subtotales cerrando cada bloque, el plegado deja de hacer falta.
                IndentationColumn = Rec.Nivel;
                IndentationControls = Término;

                field(Nivel; Rec.Nivel)
                {
                    ApplicationArea = All;
                    ToolTip = 'Profundidad del término: 0 es la suma más externa, y cada nivel más es una suma anidada dentro de una función, como la base que se arma dentro de TRAMO().';
                    Visible = false;
                }
                field(Signo; Rec.Signo)
                {
                    ApplicationArea = All;
                    Caption = '';
                    ToolTip = 'Si el término suma o resta.';
                    Style = Strong;
                }
                field(Término; Rec.Término)
                {
                    ApplicationArea = All;
                    ToolTip = 'El término tal como está escrito en la fórmula.';
                    StyleExpr = EstiloFila;
                }
                field(Descripción; Rec.Descripción)
                {
                    ApplicationArea = All;
                    ToolTip = 'Qué es el término, cuando se lo puede identificar como un concepto, un parámetro o una variable de sistema.';
                    StyleExpr = EstiloFila;
                }
                field(Valor; Rec.Valor)
                {
                    ApplicationArea = All;
                    ToolTip = 'Cuánto valió el término.';
                    StyleExpr = EstiloFila;
                }
                field(Acumulado; Rec.Acumulado)
                {
                    ApplicationArea = All;
                    ToolTip = 'El total corriente: cómo se va armando el resultado término a término.';
                    StyleExpr = EstiloFila;
                }
                field(Detalle; Rec.Detalle)
                {
                    ApplicationArea = All;
                    ToolTip = 'Detalle de auditoría del término. Para TRAMO() dice qué tramo aplicó, de qué vigencia y con qué porcentaje.';
                }
            }
        }
    }

    var
        ConceptoTxt: Text;
        ImporteTxt: Text;
        FormulaTxt: Text;
        EstiloFila: Text;

    trigger OnAfterGetRecord()
    begin
        // La fila del total va resaltada, y en rojo si la reconstrucción NO coincide con el
        // importe guardado. Que se vea de lejos: una explicación que no corresponde al número
        // que se pagó es peor que no tener explicación.
        EstiloFila := 'Standard';
        // El subtotal de un bloque va en itálica: cierra la cadena de adentro y avisa que el
        // Acumulado de la fila siguiente vuelve a ser el de la cadena de afuera.
        if Rec."Es Subtotal" then
            EstiloFila := 'StrongAccent';
        if Rec."Es Total" then
            if StrPos(Rec.Descripción, 'NO COINCIDE') > 0 then
                EstiloFila := 'Unfavorable'
            else
                EstiloFila := 'Favorable';
    end;

    /// <summary>
    /// Carga la página para una línea. La llama la acción "Detalle del cálculo".
    /// </summary>
    procedure CargarDesdeLinea(LinLiq: Record "Línea Liquidación")
    var
        Constructor: Codeunit "Detalle Cálculo Línea";
    begin
        ConceptoTxt := LinLiq."Cód. Concepto" + ' · ' + LinLiq."Nombre Impresión";
        ImporteTxt := Format(LinLiq.Importe);
        FormulaTxt := LinLiq."Fórmula Aplicada";
        Constructor.Construir(LinLiq, Rec);
        Rec.Reset();
        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;
}
