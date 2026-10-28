namespace UAS.Payroll;

/// <summary>
/// De dónde sale una línea de la previa del asiento: las líneas de liquidación, partidas de
/// provisión y lotes de francos que le aportaron, con su importe. Se abre con el drilldown de la
/// previa.
/// </summary>
page 110069 "Origen Asiento Previa"
{
    ApplicationArea = All;
    Caption = 'Origen de la línea del asiento';
    DeleteAllowed = false;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    PageType = List;
    SourceTable = "Línea Asiento Buffer Liq.";
    SourceTableTemporary = true;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(NoLiquidacion; Rec."No. Liquidación")
                {
                    ApplicationArea = All;
                    ToolTip = 'La liquidación de origen. Abre su ficha.';

                    trigger OnDrillDown()
                    begin
                        AbrirLiquidacion();
                    end;
                }
                field(NoEmpleado; Rec."No. Empleado")
                {
                    ApplicationArea = All;
                    ToolTip = 'Empleado de la liquidación.';
                }
                field(CodTipoLiq; Rec."Cód. Tipo Liq.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Tipo de la liquidación.';
                }
                field(NoProyecto; Rec."No. Proyecto")
                {
                    ApplicationArea = All;
                    ToolTip = 'Proyecto de la liquidación.';
                }
                field(CodConcepto; Rec."Cód. Concepto")
                {
                    ApplicationArea = All;
                    ToolTip = 'El concepto que aportó. Abre la línea de liquidación con su fórmula y sus variables.';

                    trigger OnDrillDown()
                    begin
                        AbrirLinea();
                    end;
                }
                field(DescripcionConcepto; Rec."Descripción Concepto")
                {
                    ApplicationArea = All;
                    ToolTip = 'Descripción del concepto.';
                }
                field(Origen; Rec.Origen)
                {
                    ApplicationArea = All;
                    ToolTip = 'Línea es el importe de una línea de liquidación. En las provisiones, Devengado es lo que el concepto devengó en la liquidación, Reversión lo que se revierte al liquidarse y Lote de francos la variación de un lote de la cuenta corriente.';
                }
                field(Detalle; Rec.Mensaje)
                {
                    ApplicationArea = All;
                    Caption = 'Detalle';
                    ToolTip = 'En una reversión, de qué período era el devengado; en un lote, cuántos días tenía al cierre anterior y al de este y a qué valor por día.';
                }
                field(Debe; Rec.Debe)
                {
                    ApplicationArea = All;
                    ToolTip = 'Lo que aportó al debe de la cuenta.';
                }
                field(Haber; Rec.Haber)
                {
                    ApplicationArea = All;
                    ToolTip = 'Lo que aportó al haber de la cuenta.';
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(Liquidacion)
            {
                ApplicationArea = All;
                Caption = 'Liquidación';
                Image = Document;
                ToolTip = 'Abre la ficha de la liquidación de origen.';

                trigger OnAction()
                begin
                    AbrirLiquidacion();
                end;
            }
            action(Linea)
            {
                ApplicationArea = All;
                Caption = 'Línea de liquidación';
                Image = Line;
                ToolTip = 'Abre la línea de origen con su fórmula aplicada y las variables con que se calculó.';

                trigger OnAction()
                begin
                    AbrirLinea();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(Liquidacion_Promoted; Liquidacion) { }
                actionref(Linea_Promoted; Linea) { }
            }
        }
    }

    /// <summary>
    /// Carga los orígenes y pone en el título la línea de la previa y la suma, que tiene que dar
    /// su importe.
    /// </summary>
    procedure Cargar(var Origen: Record "Línea Asiento Buffer Liq." temporary; Titulo: Text)
    var
        Total: Decimal;
    begin
        Rec.Reset();
        Rec.DeleteAll();
        if Origen.FindSet() then
            repeat
                Rec := Origen;
                Rec.Insert();
                Total += Origen.Importe;
            until Origen.Next() = 0;
        FTitulo := StrSubstNo(TxtTitulo, Titulo, Rec.Count(), Format(Total, 0, '<Precision,2:2><Standard Format,0>'));
        if Rec.FindFirst() then;
    end;

    trigger OnOpenPage()
    begin
        if FTitulo <> '' then
            CurrPage.Caption := FTitulo;
    end;

    local procedure AbrirLiquidacion()
    var
        Liq: Record "Liquidación";
    begin
        if Rec."No. Liquidación" = '' then
            exit;
        Liq.Get(Rec."No. Liquidación");
        Page.Run(Page::"Ficha Liquidación", Liq);
    end;

    // La línea exacta cuando el origen la tiene; si no (una partida de provisión o un lote sin
    // liquidación de origen), las líneas del concepto en esa liquidación.
    local procedure AbrirLinea()
    var
        Lin: Record "Línea Liquidación";
    begin
        if Rec."No. Liquidación" = '' then
            exit;
        Lin.SetRange("No. Liquidación", Rec."No. Liquidación");
        if Rec."No. Línea Liq." <> 0 then
            Lin.SetRange("No. Línea", Rec."No. Línea Liq.")
        else
            if Rec."Cód. Concepto" <> '' then
                Lin.SetRange("Cód. Concepto", Rec."Cód. Concepto");
        Page.Run(Page::"Líneas Liq. con Variables", Lin);
    end;

    var
        FTitulo: Text;
        TxtTitulo: Label 'Origen de %1 · %2 líneas · total %3', Comment = '%1=cuenta y proyecto o aviso, %2=cantidad, %3=total';
}
