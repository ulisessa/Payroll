namespace UAS.Payroll;

page 50074 "Convenios por Concepto"
{
    // Assign convenios to one or more concepts in bulk. Tick the target convenios in the side panel,
    // choose what to show (available / assigned / all), and use Asignar / Quitar on the (multi-)selected
    // concepts — the whole set of ticked convenios is added/removed at once.
    //
    // A diferencia de "Conceptos por Tipo Liq." (que escribe un campo de texto en el concepto), acá la
    // asignación son filas de "Concepto CCT Vigente". Reglas que se respetan:
    //   · Un concepto SIN ninguna fila aplica a TODOS los convenios (por eso se muestra "(todos)").
    //   · El versionado es POR CONVENIO: cada convenio conserva su propia Vigencia Desde y agregar uno
    //     nuevo no revoca a los demás (ver CCTAplicaAConcepto en "Motor Liquidación").
    //   · Por eso "Quitar" borra TODAS las vigencias de ese convenio: dejar una vieja lo seguiría
    //     aplicando.
    //   · Las filas se crean con Cód. Categoría en blanco = aplica a todas las categorías del convenio.
    //     Para restringir por categoría se usa la subpágina de la ficha del concepto.
    PageType = Card;
    Caption = 'Convenios por Concepto';
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
                ToolTip = 'Disponibles: no están restringidos a todos los convenios tildados. Asignados: sí lo están. Todos: sin filtrar (los asignados quedan resaltados).';
                trigger OnValidate()
                begin
                    RecomputarLista();
                end;
            }
            field(FVigencia; FVigencia)
            {
                ApplicationArea = All;
                Caption = 'Vigencia Desde (para nuevas filas)';
                ToolTip = 'Fecha con la que se crean las filas nuevas al asignar. Si el concepto ya tiene ese convenio cargado, no se toca nada.';
            }
            part(Lista; "Conceptos Convenio Sub")
            {
                ApplicationArea = All;
                Caption = 'Conceptos';
            }
        }
        area(FactBoxes)
        {
            part(ConveniosSel; "Convenio Selección Sub")
            {
                ApplicationArea = All;
                Caption = 'Convenios (tildar)';
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
                Caption = 'Asignar convenios';
                Image = Add;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Restringe los conceptos seleccionados a TODOS los convenios tildados en el panel. Atención: un concepto que hoy no tiene ninguna restricción aplica a todos los convenios; al asignarle uno pasa a aplicar SOLO a los asignados.';
                trigger OnAction()
                begin
                    AplicarSeleccion(true);
                end;
            }
            action(Quitar)
            {
                ApplicationArea = All;
                Caption = 'Quitar convenios';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Quita TODOS los convenios tildados en el panel de los conceptos seleccionados (borra todas sus vigencias). Si el concepto queda sin ninguna restricción, vuelve a aplicar a todos los convenios.';
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
                ToolTip = 'Refresca la lista y el resaltado según los convenios tildados ahora mismo en el panel.';
                trigger OnAction()
                begin
                    RecomputarLista();
                end;
            }
            action(RecargarConvenios)
            {
                ApplicationArea = All;
                Caption = 'Recargar convenios';
                Image = RefreshLines;
                ToolTip = 'Vuelve a leer los Convenios Colectivos (por si se agregó uno nuevo).';
                trigger OnAction()
                begin
                    CurrPage.ConveniosSel.Page.Recargar();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        if FVigencia = 0D then
            FVigencia := WorkDate();
        RecomputarLista();
    end;

    local procedure AplicarSeleccion(Asignar: Boolean)
    var
        Sel: Record "Concepto Liquidación" temporary;
        Convenios: List of [Code[20]];
        Convenio: Code[20];
        Contador: Integer;
    begin
        Convenios := CurrPage.ConveniosSel.Page.GetSeleccionados();
        if Convenios.Count() = 0 then
            Error(ErrSinConvenios);
        if Asignar and (FVigencia = 0D) then
            Error(ErrSinVigencia);

        CurrPage.Lista.Page.GetSeleccionados(Sel);
        if not Sel.FindSet() then exit;
        repeat
            foreach Convenio in Convenios do
                if Asignar then
                    AgregarConvenio(Sel.Código, Convenio)
                else
                    QuitarConvenio(Sel.Código, Convenio);
            Contador += 1;
        until Sel.Next() = 0;

        RecomputarLista();
        Message(MsgMovidos, Contador);
    end;

    // Idempotente: si el concepto ya tiene alguna fila para ese convenio (en cualquier vigencia), no se
    // agrega nada — el convenio ya está contemplado y crear otra vigencia solo agregaría ruido.
    local procedure AgregarConvenio(Codigo: Code[20]; Convenio: Code[20])
    var
        CCTVig: Record "Concepto CCT Vigente";
        Nuevo: Record "Concepto CCT Vigente";
    begin
        CCTVig.SetRange("Cód. Concepto", Codigo);
        CCTVig.SetRange("Cód. Convenio", Convenio);
        if not CCTVig.IsEmpty() then
            exit;

        Nuevo.Init();
        Nuevo."Cód. Concepto" := Codigo;
        Nuevo."Vigencia Desde" := FVigencia;
        Nuevo."Cód. Convenio" := Convenio;
        Nuevo."Cód. Categoría" := '';
        if Nuevo.Insert() then;
    end;

    // Borra TODAS las vigencias del convenio para ese concepto: con versionado por convenio, dejar una
    // fila vieja haría que el concepto siga aplicando a ese convenio.
    local procedure QuitarConvenio(Codigo: Code[20]; Convenio: Code[20])
    var
        CCTVig: Record "Concepto CCT Vigente";
    begin
        CCTVig.SetRange("Cód. Concepto", Codigo);
        CCTVig.SetRange("Cód. Convenio", Convenio);
        CCTVig.DeleteAll();
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

        CurrPage.Lista.Page.SetConvenios(PipeConvenios());
        CurrPage.Lista.Page.CargarLista(TempLista);
    end;

    local procedure PipeConvenios(): Text
    var
        Convenios: List of [Code[20]];
        Convenio: Code[20];
        Resultado: Text;
    begin
        Convenios := CurrPage.ConveniosSel.Page.GetSeleccionados();
        foreach Convenio in Convenios do begin
            if Resultado <> '' then Resultado += '|';
            Resultado += Convenio;
        end;
        exit(Resultado);
    end;

    local procedure ClasificarConcepto(var C: Record "Concepto Liquidación")
    var
        Aplica: Boolean;
        HayConvenios: Boolean;
    begin
        // Accumulators never go through the CCT gate (the motor skips them) → not manageable here.
        if C."Es Acumulador" then exit;

        HayConvenios := CurrPage.ConveniosSel.Page.GetSeleccionados().Count() > 0;
        Aplica := AsignadoATodos(C.Código);

        // No convenios ticked → the Disponibles/Asignados split is meaningless; show everything.
        case FMostrar of
            FMostrar::Disponibles:
                if HayConvenios and Aplica then
                    exit;
            FMostrar::Asignados:
                if HayConvenios and (not Aplica) then
                    exit;
        end;

        TempLista := C;
        TempLista.Insert();
    end;

    // True when the concept has an explicit row for EVERY ticked convenio.
    local procedure AsignadoATodos(CodConcepto: Code[20]): Boolean
    var
        CCTVig: Record "Concepto CCT Vigente";
        Convenios: List of [Code[20]];
        Convenio: Code[20];
    begin
        Convenios := CurrPage.ConveniosSel.Page.GetSeleccionados();
        if Convenios.Count() = 0 then exit(true);
        foreach Convenio in Convenios do begin
            CCTVig.SetRange("Cód. Concepto", CodConcepto);
            CCTVig.SetRange("Cód. Convenio", Convenio);
            if CCTVig.IsEmpty() then exit(false);
        end;
        exit(true);
    end;

    var
        TempLista: Record "Concepto Liquidación" temporary;
        FMostrar: Option Disponibles,Asignados,Todos;
        FVigencia: Date;
        ErrSinConvenios: Label 'Tildá al menos un convenio en el panel antes de asignar o quitar.';
        ErrSinVigencia: Label 'Indicá la Vigencia Desde con la que se crearán las filas nuevas.';
        MsgMovidos: Label '%1 concepto(s) actualizados.';
}
