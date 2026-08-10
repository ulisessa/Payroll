namespace UAS.Payroll;

page 50014 "Control Orden Acumuladores"
{
    ApplicationArea = All;
    Caption = 'Control de Orden de Cálculo';
    PageType = List;
    UsageCategory = Administration;
    SourceTable = "Diag. Orden Acum. Buffer";
    SourceTableTemporary = true;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(GrpFiltros)
            {
                ShowCaption = false;

                field(FechaRef; FechaRef)
                {
                    ApplicationArea = All;
                    Caption = 'Fecha de referencia';
                    ToolTip = 'Fecha con la que se resuelve qué vigencia de cada concepto está activa. Cambiala para verificar una configuración que entra a regir más adelante.';

                    trigger OnValidate()
                    begin
                        Analizar();
                    end;
                }
                field(SoloConflictos; SoloConflictos)
                {
                    ApplicationArea = All;
                    Caption = 'Solo conflictos';
                    ToolTip = 'Oculta los acumuladores cuyo orden de cálculo ya es correcto.';

                    trigger OnValidate()
                    begin
                        AplicarFiltro();
                        CurrPage.Update(false);
                    end;
                }
                field(Resumen; Resumen)
                {
                    ApplicationArea = All;
                    Caption = 'Resultado';
                    Editable = false;
                    StyleExpr = ResumenStyle;
                    MultiLine = true;
                }
            }
            repeater(Lines)
            {
                field("Cód. Acumulador"; Rec."Cód. Acumulador")
                {
                    ApplicationArea = All;
                    StyleExpr = FilaStyle;
                }
                field(Descripción; Rec.Descripción)
                {
                    ApplicationArea = All;
                    StyleExpr = FilaStyle;
                }
                field("Orden Máx. Aporte"; Rec."Orden Máx. Aporte")
                {
                    ApplicationArea = All;
                    ToolTip = 'Orden Cálculo del concepto que alimenta este acumulador más tarde en la corrida.';
                }
                field("Concepto Máx. Aporte"; Rec."Concepto Máx. Aporte")
                {
                    ApplicationArea = All;
                    ToolTip = 'Concepto que aporta último.';
                }
                field("Orden Mín. Lectura"; Rec."Orden Mín. Lectura")
                {
                    ApplicationArea = All;
                    ToolTip = 'Orden Cálculo del primer concepto que lee este acumulador. Si es menor o igual al orden del último aporte, ese concepto está leyendo un subtotal en vez del total.';
                    StyleExpr = FilaStyle;
                }
                field("Concepto Mín. Lectura"; Rec."Concepto Mín. Lectura")
                {
                    ApplicationArea = All;
                    ToolTip = 'Concepto que lee primero. Es el que se calcula con el acumulador incompleto.';
                    StyleExpr = FilaStyle;
                }
                field("Aportes en Conflicto"; Rec."Aportes en Conflicto")
                {
                    ApplicationArea = All;
                    StyleExpr = FilaStyle;
                }
                field("Códigos en Conflicto"; Rec."Códigos en Conflicto")
                {
                    ApplicationArea = All;
                    ToolTip = 'Conceptos que aportan tarde, con su Orden Cálculo entre paréntesis. Son los que hay que adelantar — o, alternativamente, mover las lecturas al Orden Sugerido.';
                    StyleExpr = FilaStyle;
                }
                field("Orden Sugerido"; Rec."Orden Sugerido")
                {
                    ApplicationArea = All;
                    ToolTip = 'Primer Orden Cálculo desde el cual una lectura ve el acumulador completo.';
                }
                field("Cant. Aportes"; Rec."Cant. Aportes") { ApplicationArea = All; }
                field("Cant. Lecturas"; Rec."Cant. Lecturas") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Recalcular)
            {
                ApplicationArea = All;
                Caption = 'Verificar';
                Image = Refresh;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Vuelve a analizar la configuración. Corré esto después de cambiar Orden Cálculo, fórmulas o fracciones de acumulador.';

                trigger OnAction()
                begin
                    Analizar();
                end;
            }
            action(VerConcepto)
            {
                ApplicationArea = All;
                Caption = 'Abrir concepto que lee';
                Image = Document;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Abre la ficha del concepto que lee este acumulador primero — el que se está calculando con el subtotal.';

                trigger OnAction()
                begin
                    AbrirConcepto(Rec."Concepto Mín. Lectura");
                end;
            }
            action(VerAporte)
            {
                ApplicationArea = All;
                Caption = 'Abrir concepto que aporta último';
                Image = Document;
                ToolTip = 'Abre la ficha del concepto que alimenta este acumulador más tarde.';

                trigger OnAction()
                begin
                    AbrirConcepto(Rec."Concepto Máx. Aporte");
                end;
            }
            action(VerAlimentadores)
            {
                ApplicationArea = All;
                Caption = 'Ver todos los aportes';
                Image = List;
                ToolTip = 'Muestra todos los conceptos que alimentan este acumulador, con su porcentaje y vigencia.';

                trigger OnAction()
                var
                    Frac: Record "Fracción Acumulador";
                begin
                    Rec.TestField("Cód. Acumulador");
                    Frac.SetRange("Cód. Acumulador", Rec."Cód. Acumulador");
                    Page.Run(Page::"Alimentadores Acumulador Sub", Frac);
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        FechaRef := WorkDate();
        SoloConflictos := true;
        Analizar();
    end;

    trigger OnAfterGetRecord()
    begin
        if Rec.Conflicto then
            FilaStyle := 'Unfavorable'
        else
            FilaStyle := 'Favorable';
    end;

    local procedure Analizar()
    var
        Control: Codeunit "Control Orden Acumuladores";
        Conflictos: Integer;
    begin
        Rec.Reset();
        Conflictos := Control.Analizar(FechaRef, Rec);
        if Conflictos = 0 then begin
            Resumen := SinConflictosTxt;
            ResumenStyle := 'Favorable';
        end else begin
            Resumen := CopyStr(StrSubstNo(ConConflictosTxt, Conflictos), 1, MaxStrLen(Resumen));
            ResumenStyle := 'Unfavorable';
        end;
        AplicarFiltro();
        CurrPage.Update(false);
    end;

    local procedure AplicarFiltro()
    begin
        if SoloConflictos then
            Rec.SetRange(Conflicto, true)
        else
            Rec.SetRange(Conflicto);
        if Rec.FindFirst() then;
    end;

    local procedure AbrirConcepto(CodConcepto: Code[20])
    var
        Concepto: Record "Concepto Liquidación";
    begin
        if CodConcepto = '' then
            exit;
        Concepto.SetRange(Código, CodConcepto);
        if Concepto.FindLast() then
            Page.Run(Page::"Concepto Liq. Card", Concepto);
    end;

    var
        FechaRef: Date;
        SoloConflictos: Boolean;
        FilaStyle: Text[20];
        ResumenStyle: Text[20];
        Resumen: Text[250];
        SinConflictosTxt: Label 'Sin conflictos: todos los acumuladores reciben sus aportes antes de que algún concepto los lea.';
        ConConflictosTxt: Label '%1 acumulador(es) con conflicto. Los conceptos marcados leen un subtotal, no el total: el importe sale menor sin dar ningún error.';
}
