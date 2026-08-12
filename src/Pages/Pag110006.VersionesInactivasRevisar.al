namespace UAS.Payroll;

// Pantalla de transición, para usar UNA vez: antes de que el reemplazo de "Activo" por
// "Vigencia Hasta" llegue a producción.
//
// Hasta ahora, una versión con Activo = false no daba de baja el concepto: lo volvía INVISIBLE.
// El motor filtraba Activo antes de elegir la versión, así que caía a la versión activa anterior
// y la seguía ejecutando. Desde el cambio, la misma fila significa lo que todos creían que
// significaba: el concepto se discontinúa desde la fecha de esa versión.
//
// Esa diferencia no se puede migrar sola —"invisible" no se traduce a un intervalo de fechas, y
// convertirla automáticamente sería codificar el malentendido—, así que esta página no migra
// nada. Diagnostica caso por caso qué venía haciendo el motor y qué va a hacer, y deja que la
// decisión la tome una persona.
page 110006 "Versiones Inactivas a Revisar"
{
    ApplicationArea = All;
    Caption = 'Versiones inactivas a revisar';
    PageType = List;
    UsageCategory = Administration;
    SourceTable = "Concepto Liquidación";
    SourceTableView = where(Activo = const(false));
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field(Impacto; Impacto)
                {
                    ApplicationArea = All;
                    Caption = 'Impacto';
                    StyleExpr = ImpactoStyle;
                    ToolTip = 'Qué cambia para este concepto ahora que la baja se resuelve por fecha y no por el booleano.';
                }
                field(Diagnóstico; Diagnóstico)
                {
                    ApplicationArea = All;
                    Caption = 'Detalle';
                    ToolTip = 'Qué venía ejecutando el motor con esta fila y qué va a ejecutar ahora.';
                }
                field(Sugerencia; Sugerencia)
                {
                    ApplicationArea = All;
                    Caption = 'Qué hacer';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AbrirConcepto)
            {
                ApplicationArea = All;
                Caption = 'Abrir concepto';
                Image = Card;
                trigger OnAction()
                begin
                    Page.Run(Page::"Concepto Liq. Card", Rec);
                end;
            }
            action(VerTodasLasVigencias)
            {
                ApplicationArea = All;
                Caption = 'Ver todas las vigencias';
                Image = History;
                ToolTip = 'Muestra la cadena completa de versiones del concepto, para decidir con el contexto a la vista.';
                trigger OnAction()
                var
                    Todas: Record "Concepto Liquidación";
                begin
                    Todas.SetRange(Código, Rec.Código);
                    Page.Run(Page::"Conceptos Liquidación", Todas);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        Diagnosticar();
    end;

    // Tres situaciones distintas, y solo la primera cambia algo. Distinguirlas es todo el punto de
    // esta pantalla: una lista plana de "versiones inactivas" no dice cuáles importan.
    local procedure Diagnosticar()
    var
        Posterior: Record "Concepto Liquidación";
        Anterior: Record "Concepto Liquidación";
        Hoy: Date;
    begin
        Hoy := WorkDate();

        // 1. Hay una versión posterior. La inactiva nunca ganó la resolución y sigue sin ganarla:
        //    es una fila muerta en los dos modelos.
        Posterior.SetRange(Código, Rec.Código);
        Posterior.SetFilter("Vigencia Desde", '>%1', Rec."Vigencia Desde");
        if not Posterior.IsEmpty() then begin
            Posterior.FindFirst();
            Impacto := ImpNinguno;
            ImpactoStyle := 'Subordinate';
            Diagnóstico := StrSubstNo(DiagPosterior, Posterior."Vigencia Desde");
            Sugerencia := SugBorrar;
            exit;
        end;

        // 2. Es la última versión y hay una anterior. ACÁ está el cambio de comportamiento: hasta
        //    ahora el motor se caía a la anterior y seguía liquidando; ahora el concepto queda dado
        //    de baja desde esta fecha.
        Anterior.SetRange(Código, Rec.Código);
        Anterior.SetFilter("Vigencia Desde", '<%1', Rec."Vigencia Desde");
        if Anterior.FindLast() then begin
            Impacto := ImpDejaDeLiquidar;
            ImpactoStyle := 'Unfavorable';
            Diagnóstico := StrSubstNo(DiagCaidaAAnterior, Anterior."Vigencia Desde", Rec."Vigencia Desde");
            if Rec."Vigencia Desde" <= Hoy then
                Sugerencia := StrSubstNo(SugCerrarAnterior, Anterior."Vigencia Desde", Rec."Vigencia Desde" - 1)
            else
                Sugerencia := StrSubstNo(SugCerrarAnteriorFutura, Rec."Vigencia Desde");
            exit;
        end;

        // 3. Única versión: el concepto no liquidaba antes y no liquida ahora.
        Impacto := ImpNinguno;
        ImpactoStyle := 'Subordinate';
        Diagnóstico := DiagUnica;
        Sugerencia := SugUnica;
    end;

    var
        Diagnóstico: Text;
        Sugerencia: Text;
        Impacto: Text;
        ImpactoStyle: Text;
        ImpDejaDeLiquidar: Label 'Deja de liquidar';
        ImpNinguno: Label 'Sin cambio';
        DiagPosterior: Label 'No tiene efecto: existe una versión posterior, vigente desde el %1, que es la que el motor resuelve. Esta fila nunca se aplicó.';
        DiagCaidaAAnterior: Label 'Es la última versión. Hasta ahora el motor la salteaba y seguía liquidando con la versión del %1; desde el cambio, el concepto queda dado de baja a partir del %2.';
        DiagUnica: Label 'Es la única versión del concepto, así que nunca llegó a liquidar. El comportamiento no cambia.';
        SugBorrar: Label 'Se puede borrar sin consecuencias, o dejar como está.';
        SugUnica: Label 'Si el concepto no se usa más, borralo. Si tenía que liquidar, era esta fila la que lo impedía.';
        SugCerrarAnterior: Label 'Si la baja era la intención: poné Vigencia Hasta = %2 en la versión del %1 y borrá esta fila. Si el concepto tenía que seguir liquidando, borrá esta fila y listo.';
        SugCerrarAnteriorFutura: Label 'La baja empieza el %1, todavía no ocurrió. Decidí antes de esa fecha si el concepto se discontinúa o si esta fila hay que borrarla.';
}
