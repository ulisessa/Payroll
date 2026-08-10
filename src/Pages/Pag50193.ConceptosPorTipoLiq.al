namespace UAS.Payroll;

page 50193 "Conceptos por Tipo Liq."
{
    // Assign concepts to one or more liquidation types. Tick the target types in the side panel, choose
    // what to show (available / assigned / all), and use Asignar / Quitar on the (multi-)selected concepts
    // — the whole set of ticked types is added/removed at once. Assignment is stored per concept in "Tipos
    // Liq. Aplicables" (empty = applies to all types); every version of a concept code is updated together.
    // Fully data-driven off the "Tipo Liquidación" table — adding a type needs no change to this page.
    PageType = Card;
    Caption = 'Conceptos por Tipo de Liquidación';
    UsageCategory = Administration;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            field(FMostrar; FMostrar)
            {
                ApplicationArea = All;
                Caption = 'Mostrar';
                ToolTip = 'Disponibles: no aplican a todos los tipos tildados. Asignados: aplican a todos. Todos: sin filtrar (los asignados quedan resaltados).';
                trigger OnValidate() begin RecomputarLista(); end;
            }
            part(Lista; "Conceptos Tipo Liq. Sub")
            {
                ApplicationArea = All;
                Caption = 'Conceptos';
            }
        }
        area(FactBoxes)
        {
            part(TiposSel; "Tipo Liq. Selección Sub")
            {
                ApplicationArea = All;
                Caption = 'Tipos de Liquidación (tildar)';
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Asignar)
            {
                ApplicationArea = All;
                Caption = 'Asignar tipos';
                Image = Add;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Asigna TODOS los tipos tildados en el panel a los conceptos seleccionados en la lista.';
                trigger OnAction()
                begin
                    AplicarSeleccion(true);
                end;
            }
            action(Quitar)
            {
                ApplicationArea = All;
                Caption = 'Quitar tipos';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Quita TODOS los tipos tildados en el panel de los conceptos seleccionados en la lista.';
                trigger OnAction()
                begin
                    AplicarSeleccion(false);
                end;
            }
            action(AplicarFiltro)
            {
                ApplicationArea = All;
                Caption = 'Aplicar tildado';
                Image = FilterLines;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Refresca la lista y el resaltado según los tipos tildados ahora mismo en el panel.';
                trigger OnAction()
                begin
                    RecomputarLista();
                end;
            }
            action(RecargarTipos)
            {
                ApplicationArea = All;
                Caption = 'Recargar tipos';
                Image = RefreshLines;
                ToolTip = 'Vuelve a leer los Tipos de Liquidación activos (por si se agregó uno nuevo).';
                trigger OnAction()
                begin
                    CurrPage.TiposSel.Page.Recargar();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        RecomputarLista();
    end;

    local procedure AplicarSeleccion(Asignar: Boolean)
    var
        Sel: Record "Concepto Liquidación" temporary;
        Tipos: List of [Code[20]];
        Tipo: Code[20];
        Contador: Integer;
    begin
        Tipos := CurrPage.TiposSel.Page.GetSeleccionados();
        if Tipos.Count() = 0 then
            Error(ErrSinTipos);

        CurrPage.Lista.Page.GetSeleccionados(Sel);
        if not Sel.FindSet() then exit;
        repeat
            foreach Tipo in Tipos do
                if Asignar then
                    AgregarTipo(Sel.Código, Tipo)
                else
                    QuitarTipo(Sel.Código, Tipo);
            Contador += 1;
        until Sel.Next() = 0;

        RecomputarLista();
        Message(MsgMovidos, Contador);
    end;

    local procedure AgregarTipo(Codigo: Code[20]; Tipo: Code[20])
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Concepto.SetRange(Código, Codigo);
        if Concepto.FindSet(true) then
            repeat
                if not ContieneTipo(Concepto."Tipos Liq. Aplicables", Tipo) then begin
                    Concepto."Tipos Liq. Aplicables" := AgregarToken(Concepto."Tipos Liq. Aplicables", Tipo);
                    Concepto.Modify();
                end;
            until Concepto.Next() = 0;
    end;

    local procedure QuitarTipo(Codigo: Code[20]; Tipo: Code[20])
    var
        Concepto: Record "Concepto Liquidación";
        Nuevo: Text[250];
    begin
        Concepto.SetRange(Código, Codigo);
        if Concepto.FindSet(true) then
            repeat
                Nuevo := QuitarToken(Concepto."Tipos Liq. Aplicables", Tipo);
                if Nuevo <> Concepto."Tipos Liq. Aplicables" then begin
                    Concepto."Tipos Liq. Aplicables" := Nuevo;
                    Concepto.Modify();
                end;
            until Concepto.Next() = 0;
    end;

    local procedure RecomputarLista()
    var
        Concepto: Record "Concepto Liquidación";
        Latest: Record "Concepto Liquidación";
        HayLatest: Boolean;
    begin
        TempLista.Reset();
        TempLista.DeleteAll();

        // PK is (Código, Vigencia Desde) ascending → the last row per code is its latest version.
        if Concepto.FindSet() then
            repeat
                if HayLatest and (Concepto.Código <> Latest.Código) then
                    ClasificarConcepto(Latest);
                Latest := Concepto;
                HayLatest := true;
            until Concepto.Next() = 0;
        if HayLatest then
            ClasificarConcepto(Latest);

        CurrPage.Lista.Page.SetTipos(PipeTipos());
        CurrPage.Lista.Page.CargarLista(TempLista);
    end;

    local procedure PipeTipos(): Text
    var
        Tipos: List of [Code[20]];
        Tipo: Code[20];
        Resultado: Text;
    begin
        Tipos := CurrPage.TiposSel.Page.GetSeleccionados();
        foreach Tipo in Tipos do begin
            if Resultado <> '' then Resultado += '|';
            Resultado += Tipo;
        end;
        exit(Resultado);
    end;

    local procedure ClasificarConcepto(var C: Record "Concepto Liquidación")
    var
        Aplica: Boolean;
        HayTipos: Boolean;
    begin
        // Accumulators never apply to a liquidation type (the motor skips them) → not manageable here.
        if C."Es Acumulador" then exit;

        HayTipos := CurrPage.TiposSel.Page.GetSeleccionados().Count() > 0;
        Aplica := AplicaATodos(C."Tipos Liq. Aplicables");

        // No types ticked → the Disponibles/Asignados split is meaningless; show everything.
        case FMostrar of
            FMostrar::Disponibles:
                if HayTipos and Aplica then exit;
            FMostrar::Asignados:
                if HayTipos and (not Aplica) then exit;
        end;

        TempLista := C;
        TempLista.Insert();
    end;

    // True when the concept applies to EVERY ticked type (empty field = applies to all).
    local procedure AplicaATodos(Texto: Text): Boolean
    var
        Tipos: List of [Code[20]];
        Tipo: Code[20];
    begin
        Tipos := CurrPage.TiposSel.Page.GetSeleccionados();
        if Tipos.Count() = 0 then exit(true);
        foreach Tipo in Tipos do
            if not ContieneTipo(Texto, Tipo) then exit(false);
        exit(true);
    end;

    local procedure ContieneTipo(Texto: Text; Tipo: Code[20]): Boolean
    begin
        // Empty = no explicit assignment → treated as "not assigned" in the tool (available, not highlighted).
        if Texto = '' then exit(false);
        exit(('|' + Texto + '|').Contains('|' + Tipo + '|'));
    end;

    local procedure AgregarToken(Texto: Text[250]; Tipo: Code[20]): Text[250]
    begin
        if Texto <> '' then
            Texto += '|';
        Texto += Tipo;
        exit(CopyStr(Texto, 1, 250));
    end;

    local procedure QuitarToken(Texto: Text[250]; Tipo: Code[20]): Text[250]
    var
        Resultado: Text;
        Actual: Text;
    begin
        if Texto = '' then exit('');
        foreach Actual in Texto.Split('|') do
            if Actual <> Tipo then begin
                if Resultado <> '' then Resultado += '|';
                Resultado += Actual;
            end;
        exit(CopyStr(Resultado, 1, 250));
    end;

    var
        TempLista: Record "Concepto Liquidación" temporary;
        FMostrar: Option Disponibles,Asignados,Todos;
        ErrSinTipos: Label 'Tildá al menos un tipo de liquidación en el panel antes de asignar o quitar.';
        MsgMovidos: Label '%1 concepto(s) actualizados.';
}
