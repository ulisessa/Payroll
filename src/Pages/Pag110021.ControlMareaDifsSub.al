namespace UAS.Payroll;

// Quién cobró distinto que la mayoría de su misma categoría.
//
// Es la lista corta que hace falta para cerrar una marea. La matriz de arriba tiene la misma
// información, pero repartida en cientos de celdas: el ojo no encuentra ahí al que cobró cien pesos
// de más. Acá el que se apartó está nombrado, con el concepto y la diferencia.
//
// Vacía es una respuesta, no una ausencia de datos: significa que todos los tripulantes de cada
// categoría cobraron lo mismo, y entonces la matriz se puede leer categoría por categoría.
page 110021 "Control Marea Difs. Sub"
{
    ApplicationArea = All;
    Caption = 'Diferencias dentro de la misma categoría';
    PageType = ListPart;
    SourceTable = "Control Marea Buffer";
    SourceTableTemporary = true;
    SourceTableView = sorting(Sección, "No. Empleado", "Orden Cálculo", "Cód. Concepto") where(Sección = const(Diferencia));
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                ShowCaption = false;

                field("No. Empleado"; Rec."No. Empleado") { ApplicationArea = All; }
                field("Nombre Empleado"; Rec."Nombre Empleado") { ApplicationArea = All; }
                field("Categoría Empleado"; Rec."Categoría Empleado")
                {
                    ApplicationArea = All;
                    ToolTip = 'Categoría contra la que se lo comparó: la de su encuadre, no la de la línea.';
                }
                field("Cód. Concepto"; Rec."Cód. Concepto") { ApplicationArea = All; }
                field("Nombre Impresión"; Rec."Nombre Impresión") { ApplicationArea = All; Caption = 'Concepto'; }
                field(Importe; Rec.Importe)
                {
                    ApplicationArea = All;
                    Caption = 'Cobró';
                    ToolTip = 'Lo que cobró este tripulante por el concepto, sumando todas sus líneas.';
                }
                field("Importe Habitual"; Rec."Importe Habitual")
                {
                    ApplicationArea = All;
                    ToolTip = 'Lo que cobró la mayoría de su categoría por ese concepto. Es el número contra el que se mide el apartamiento.';
                }
                field(Diferencia; Rec.Diferencia)
                {
                    ApplicationArea = All;
                    Style = Attention;
                    ToolTip = 'Cuánto se apartó. Hacé clic en el encabezado para ordenar por este valor y empezar por lo que más plata mueve.';
                }
                field("No. Liquidación"; Rec."No. Liquidación")
                {
                    ApplicationArea = All;
                    ToolTip = 'Abre la liquidación del tripulante para ver la fórmula con valores y el detalle de variables del concepto.';

                    trigger OnDrillDown()
                    var
                        Liq: Record "Liquidación";
                    begin
                        if Liq.Get(Rec."No. Liquidación") then
                            Page.Run(Page::"Ficha Liquidación", Liq);
                    end;
                }
            }
        }
    }

    /// <summary>Carga las diferencias del buffer, ya restringidas al filtro de convenio y categoría.</summary>
    procedure Cargar(var Origen: Record "Control Marea Buffer" temporary; Convenio: Code[20]; Categoria: Code[20])
    begin
        Rec.Reset();
        Rec.DeleteAll();
        FCuantas := 0;
        Origen.Reset();
        Origen.SetRange(Sección, Origen.Sección::Diferencia);
        if Convenio <> '' then
            Origen.SetRange("Convenio Empleado", Convenio);
        if Categoria <> '' then
            Origen.SetRange("Categoría Empleado", Categoria);
        if Origen.FindSet() then
            repeat
                Rec := Origen;
                Rec.Insert();
                FCuantas += 1;
            until Origen.Next() = 0;
        Origen.Reset();
        CurrPage.Update(false);
    end;

    /// <remarks>
    /// El contador se lleva al cargar y no se cuenta al preguntarlo: contar exigiría un Reset sobre
    /// Rec, y eso le sacaría a la grilla el filtro de sección que trae del SourceTableView.
    /// </remarks>
    procedure Cuantas(): Integer
    begin
        exit(FCuantas);
    end;

    var
        FCuantas: Integer;
}
