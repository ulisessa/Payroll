namespace UAS.Payroll;

page 50076 "Conceptos por Convenio"
{
    // Vista inversa de "Convenios por Concepto": se parte de UN convenio (opcionalmente acotado a una
    // categoría) y se tildan/destildan los conceptos que le aplican. Cada tilde escribe o borra una
    // fila de "Concepto CCT Vigente" en el acto.
    //
    // Reglas del modelo que se respetan (ver CCTAplicaAConcepto en "Motor Liquidación"):
    //   · Un concepto SIN ninguna fila aplica a TODOS los convenios (columna Estado lo avisa).
    //   · El versionado es POR CONVENIO: cada convenio conserva su Vigencia Desde y agregar otro
    //     convenio no revoca a los demás. Por eso destildar borra todas las vigencias de la
    //     combinación, no solo la más reciente.
    //   · Categoría en blanco = la fila aplica a todas las categorías del convenio.
    PageType = Card;
    Caption = 'Conceptos por Convenio';
    UsageCategory = Administration;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(Contexto)
            {
                Caption = 'Convenio';

                field(FConvenio; FConvenio)
                {
                    ApplicationArea = All;
                    Caption = 'Cód. Convenio';
                    TableRelation = "Convenio Colectivo".Código;
                    ToolTip = 'Convenio sobre el que se asignan los conceptos.';
                    trigger OnValidate()
                    begin
                        FCategoria := '';
                        RecomputarLista();
                    end;
                }
                field(FCategoria; FCategoria)
                {
                    ApplicationArea = All;
                    Caption = 'Cód. Categoría (opcional)';
                    ToolTip = 'Vacío = la asignación aplica a todas las categorías del convenio. Cargada = se asigna solo a esa categoría.';
                    trigger OnValidate()
                    begin
                        if (FCategoria <> '') and (FConvenio = '') then
                            Error(ErrSinConvenio);
                        RecomputarLista();
                    end;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Categoria: Record "Categoría CCT";
                    begin
                        if FConvenio = '' then
                            Error(ErrSinConvenio);
                        Categoria.SetRange("Cód. Convenio", FConvenio);
                        if Page.RunModal(Page::"Categorías CCT", Categoria) <> Action::LookupOK then
                            exit(false);
                        FCategoria := Categoria.Código;
                        RecomputarLista();
                        exit(true);
                    end;
                }
                field(FVigencia; FVigencia)
                {
                    ApplicationArea = All;
                    Caption = 'Vigencia Desde (para nuevas filas)';
                    ToolTip = 'Fecha con la que se crean las filas al tildar un concepto.';
                    trigger OnValidate()
                    begin
                        RefrescarContexto();
                    end;
                }
                field(FMostrar; FMostrar)
                {
                    ApplicationArea = All;
                    Caption = 'Mostrar';
                    ToolTip = 'Asignados: solo los conceptos ya asignados a este convenio/categoría. Disponibles: solo los que no lo están. Todos: sin filtrar.';
                    trigger OnValidate()
                    begin
                        RecomputarLista();
                    end;
                }
            }
            part(Lista; "Conceptos Selección Sub")
            {
                ApplicationArea = All;
                Caption = 'Conceptos';
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Refrescar)
            {
                ApplicationArea = All;
                Caption = 'Refrescar';
                Image = RefreshLines;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Vuelve a leer los conceptos y sus asignaciones.';
                trigger OnAction()
                begin
                    RecomputarLista();
                end;
            }
            action(AsignarTodos)
            {
                ApplicationArea = All;
                Caption = 'Asignar todos los listados';
                Image = Add;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Asigna al convenio (y categoría) todos los conceptos que se están mostrando ahora.';
                trigger OnAction()
                begin
                    AplicarATodosLosListados(true);
                end;
            }
            action(QuitarTodos)
            {
                ApplicationArea = All;
                Caption = 'Quitar todos los listados';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Quita del convenio (y categoría) todos los conceptos que se están mostrando ahora.';
                trigger OnAction()
                begin
                    AplicarATodosLosListados(false);
                end;
            }
            action(CopiarAOtroConvenio)
            {
                ApplicationArea = All;
                Caption = 'Copiar a otro convenio...';
                Image = Copy;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Copia las asignaciones de conceptos del convenio (y categoría) en contexto hacia otro convenio y/o categoría. Solo agrega lo que falte: no borra nada en el destino.';
                trigger OnAction()
                begin
                    CopiarAOtroDestino();
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

    local procedure AplicarATodosLosListados(Asignar: Boolean)
    var
        CCTVig: Record "Concepto CCT Vigente";
        Nuevo: Record "Concepto CCT Vigente";
        Contador: Integer;
    begin
        if FConvenio = '' then
            Error(ErrSinConvenio);
        if Asignar and (FVigencia = 0D) then
            Error(ErrSinVigencia);
        if not Confirm(ConfirmMasivoQst, false, TempLista.Count()) then
            exit;

        if not TempLista.FindSet() then exit;
        repeat
            CCTVig.Reset();
            CCTVig.SetRange("Cód. Concepto", TempLista.Código);
            CCTVig.SetRange("Cód. Convenio", FConvenio);
            CCTVig.SetRange("Cód. Categoría", FCategoria);
            if Asignar then begin
                if CCTVig.IsEmpty() then begin
                    Nuevo.Init();
                    Nuevo."Cód. Concepto" := TempLista.Código;
                    Nuevo."Vigencia Desde" := FVigencia;
                    Nuevo."Cód. Convenio" := FConvenio;
                    Nuevo."Cód. Categoría" := FCategoria;
                    if Nuevo.Insert() then
                        Contador += 1;
                end;
            end else
                if not CCTVig.IsEmpty() then begin
                    CCTVig.DeleteAll();
                    Contador += 1;
                end;
        until TempLista.Next() = 0;

        RecomputarLista();
        Message(MsgMovidos, Contador);
    end;

    // Copia las asignaciones del convenio/categoría en contexto hacia otro destino. Es aditiva: solo
    // inserta lo que falte, nunca borra en el destino (si se quiere reemplazar, primero se usa
    // "Quitar todos los listados" parado en el destino). Se copia SIEMPRE el conjunto completo
    // asignado al origen, sin importar el filtro Mostrar — la confirmación lo dice explícitamente.
    local procedure CopiarAOtroDestino()
    var
        Dialogo: Page "Copiar Conceptos CCT Dialog";
        ConvenioDestino: Code[20];
        CategoriaDestino: Code[20];
        VigenciaDestino: Date;
        Origen: List of [Code[20]];
        Copiados: Integer;
    begin
        if FConvenio = '' then
            Error(ErrSinConvenio);

        Origen := ConceptosAsignadosAlOrigen();
        if Origen.Count() = 0 then
            Error(ErrOrigenVacio, DescribirDestino(FConvenio, FCategoria));

        Dialogo.SetOrigen(FConvenio, FCategoria, FVigencia);
        if Dialogo.RunModal() <> Action::OK then
            exit;
        Dialogo.GetDestino(ConvenioDestino, CategoriaDestino, VigenciaDestino);

        if ConvenioDestino = '' then
            Error(ErrSinConvenioDestino);
        if VigenciaDestino = 0D then
            Error(ErrSinVigencia);
        if (ConvenioDestino = FConvenio) and (CategoriaDestino = FCategoria) then
            Error(ErrMismoDestino);

        if not Confirm(
            ConfirmCopiaQst, false,
            Origen.Count(), DescribirDestino(FConvenio, FCategoria),
            DescribirDestino(ConvenioDestino, CategoriaDestino), VigenciaDestino)
        then
            exit;

        Copiados := CopiarConceptos(Origen, ConvenioDestino, CategoriaDestino, VigenciaDestino);

        RecomputarLista();
        Message(MsgCopiados, Copiados, Origen.Count() - Copiados);
    end;

    local procedure ConceptosAsignadosAlOrigen() Resultado: List of [Code[20]]
    var
        CCTVig: Record "Concepto CCT Vigente";
    begin
        CCTVig.SetRange("Cód. Convenio", FConvenio);
        CCTVig.SetRange("Cód. Categoría", FCategoria);
        if not CCTVig.FindSet() then exit;
        repeat
            // Una misma combinación puede tener varias vigencias: el concepto se copia una sola vez.
            if not Resultado.Contains(CCTVig."Cód. Concepto") then
                Resultado.Add(CCTVig."Cód. Concepto");
        until CCTVig.Next() = 0;
    end;

    local procedure CopiarConceptos(var Origen: List of [Code[20]]; ConvenioDestino: Code[20]; CategoriaDestino: Code[20]; VigenciaDestino: Date) Copiados: Integer
    var
        CCTVig: Record "Concepto CCT Vigente";
        Nuevo: Record "Concepto CCT Vigente";
        CodConcepto: Code[20];
    begin
        foreach CodConcepto in Origen do begin
            CCTVig.Reset();
            CCTVig.SetRange("Cód. Concepto", CodConcepto);
            CCTVig.SetRange("Cód. Convenio", ConvenioDestino);
            CCTVig.SetRange("Cód. Categoría", CategoriaDestino);
            if CCTVig.IsEmpty() then begin
                Nuevo.Init();
                Nuevo."Cód. Concepto" := CodConcepto;
                Nuevo."Vigencia Desde" := VigenciaDestino;
                Nuevo."Cód. Convenio" := ConvenioDestino;
                Nuevo."Cód. Categoría" := CategoriaDestino;
                if Nuevo.Insert() then
                    Copiados += 1;
            end;
        end;
    end;

    local procedure DescribirDestino(CodConvenio: Code[20]; CodCategoria: Code[20]): Text
    begin
        if CodCategoria = '' then
            exit(StrSubstNo(DestinoTodasCatTxt, CodConvenio));
        exit(CodConvenio + ' / ' + CodCategoria);
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

        RefrescarContexto();
        CurrPage.Lista.Page.CargarLista(TempLista);
    end;

    local procedure RefrescarContexto()
    begin
        CurrPage.Lista.Page.SetContexto(FConvenio, FCategoria, FVigencia);
    end;

    local procedure ClasificarConcepto(var C: Record "Concepto Liquidación")
    var
        Asignado: Boolean;
    begin
        // Accumulators never go through the CCT gate (the motor skips them) → not manageable here.
        if C."Es Acumulador" then exit;

        Asignado := EstaAsignado(C.Código);

        case FMostrar of
            FMostrar::Disponibles:
                if Asignado then
                    exit;
            FMostrar::Asignados:
                if not Asignado then
                    exit;
        end;

        TempLista.Init();
        TempLista.Código := C.Código;
        TempLista.Descripción := C.Descripción;
        TempLista.Marcado := Asignado;
        if TempLista.Insert() then;
    end;

    local procedure EstaAsignado(CodConcepto: Code[20]): Boolean
    var
        CCTVig: Record "Concepto CCT Vigente";
    begin
        if FConvenio = '' then
            exit(false);
        CCTVig.SetRange("Cód. Concepto", CodConcepto);
        CCTVig.SetRange("Cód. Convenio", FConvenio);
        CCTVig.SetRange("Cód. Categoría", FCategoria);
        exit(not CCTVig.IsEmpty());
    end;

    var
        TempLista: Record "Tipo Liq. Selección Buffer" temporary;
        FMostrar: Option Todos,Asignados,Disponibles;
        FConvenio: Code[20];
        FCategoria: Code[20];
        FVigencia: Date;
        ErrSinConvenio: Label 'Seleccioná primero un Cód. Convenio.';
        ErrSinVigencia: Label 'Indicá la Vigencia Desde con la que se crearán las filas nuevas.';
        ErrSinConvenioDestino: Label 'Indicá el Cód. Convenio de destino.';
        ErrMismoDestino: Label 'El destino es igual al origen. Elegí otro convenio o categoría.';
        ErrOrigenVacio: Label 'No hay conceptos asignados a %1, así que no hay nada para copiar.';
        DestinoTodasCatTxt: Label '%1 (todas las categorías)';
        ConfirmCopiaQst: Label 'Se van a copiar %1 concepto(s) de %2 a %3, con vigencia %4.\Los que ya estén asignados en el destino se omiten y no se borra nada. ¿Continuar?';
        MsgCopiados: Label '%1 concepto(s) copiados. %2 ya estaban asignados en el destino.';
        ConfirmMasivoQst: Label 'Se van a actualizar %1 concepto(s) listados. ¿Continuar?';
        MsgMovidos: Label '%1 concepto(s) actualizados.';
}
