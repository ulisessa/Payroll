namespace UAS.Payroll;

page 50140 "Variables Liq. Test Sub"
{
    ApplicationArea = All;
    Caption = 'Variables de prueba';
    PageType = ListPart;
    SourceTable = "Variable Liq. Test";
    SourceTableTemporary = true;
    Editable = true;

    layout
    {
        area(Content)
        {
            field(Busqueda; FBusqueda)
            {
                ApplicationArea = All;
                Caption = 'Buscar';
                ToolTip = 'Filtra por nombre o descripción (contiene el texto, sin importar mayúsculas).';
                trigger OnValidate()
                begin
                    AplicarFiltro();
                end;
            }
            field(TipoFiltro; FTipoFiltro)
            {
                ApplicationArea = All;
                Caption = 'Tipo';
                ToolTip = 'Filtra por categoría de variable.';
                trigger OnValidate()
                begin
                    AplicarFiltro();
                end;
            }
            repeater(Lines)
            {
                field(Tipo; Rec.Tipo)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Width = 12;
                    StyleExpr = TipoStyle;
                }
                field(Nombre; Rec.Nombre)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Style = Strong;
                    trigger OnDrillDown()
                    begin
                        PendingInsert := Rec.Nombre;
                        CurrPage.Update(false);
                    end;
                }
                field(Valor; Rec.Valor) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; Editable = false; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(InsertarEnFormula)
            {
                ApplicationArea = All;
                Caption = 'Insertar en fórmula';
                Image = Add;
                ToolTip = 'Agrega el nombre de esta variable al final de la fórmula.';
                trigger OnAction()
                begin
                    PendingInsert := Rec.Nombre;
                    CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.SetCurrentKey(Rec.Tipo, Rec.Nombre);
    end;

    trigger OnAfterGetRecord()
    begin
        case Rec.Tipo of
            'Parámetro':
                TipoStyle := 'Favorable';
            'Sistema':
                TipoStyle := 'Attention';
            'Acumulador':
                TipoStyle := 'Strong';
            'Fuente Datos':
                TipoStyle := 'Subordinate';
            else
                TipoStyle := '';
        end;
    end;

    var
        PendingInsert: Text[100];
        TipoStyle: Text;
        FBusqueda: Text[100];
        FTipoFiltro: Option Todos,Parámetro,Sistema,"Fuente Datos",Acumulador;

    // Combines the Tipo range (real filter) with a Nombre/Descripción "contains" search (Mark-based,
    // since AL SetFilter can't OR across two different fields) — searches only within whatever the
    // Tipo filter already narrowed down to.
    local procedure AplicarFiltro()
    var
        TipoTexto: Text[20];
        BusquedaUpper: Text;
    begin
        Rec.Reset();
        Rec.ClearMarks();
        Rec.MarkedOnly(false);

        case FTipoFiltro of
            FTipoFiltro::Parámetro:
                TipoTexto := 'Parámetro';
            FTipoFiltro::Sistema:
                TipoTexto := 'Sistema';
            FTipoFiltro::"Fuente Datos":
                TipoTexto := 'Fuente Datos';
            FTipoFiltro::Acumulador:
                TipoTexto := 'Acumulador';
        end;
        if TipoTexto <> '' then
            Rec.SetRange(Tipo, TipoTexto)
        else
            Rec.SetRange(Tipo);

        if FBusqueda <> '' then begin
            BusquedaUpper := FBusqueda.ToUpper();
            if Rec.FindSet() then
                repeat
                    if Rec.Nombre.ToUpper().Contains(BusquedaUpper) or Rec.Descripción.ToUpper().Contains(BusquedaUpper) then
                        Rec.Mark(true);
                until Rec.Next() = 0;
            Rec.MarkedOnly(true);
        end;
        CurrPage.Update(false);
    end;

    // Called by the parent before reloading the catalog, so a search left over from a previous load
    // doesn't hide freshly-inserted rows (SetVariable/LoadFromContext only insert; they don't know about
    // whatever filter/mark state is currently active on Rec).
    procedure LimpiarFiltro()
    begin
        FBusqueda := '';
        FTipoFiltro := FTipoFiltro::Todos;
        Rec.Reset();
        Rec.ClearMarks();
        Rec.MarkedOnly(false);
    end;

    procedure SetVariable(VarNombre: Text[100]; VarValor: Decimal; VarDesc: Text[100]; VarTipo: Text[20])
    begin
        if Rec.Get(VarNombre) then begin
            Rec.Valor := VarValor;
            Rec.Descripción := VarDesc;
            Rec.Tipo := VarTipo;
            Rec.Modify();
        end else begin
            Rec.Init();
            Rec.Nombre := VarNombre;
            Rec.Valor := VarValor;
            Rec.Descripción := VarDesc;
            Rec.Tipo := VarTipo;
            Rec.Insert();
        end;
    end;

    // Copy con ShareTable en vez de Rec.Reset(): comparte los datos temporales pero con vista propia,
    // así leer el contexto no le borra al usuario el filtro de búsqueda que tenga puesto. Importa más
    // que antes, porque el editor con IntelliSense pide diagnóstico cada vez que se deja de escribir.
    procedure GetContext(var Ctx: Dictionary of [Text, Decimal])
    var
        Todas: Record "Variable Liq. Test" temporary;
    begin
        Clear(Ctx);
        Todas.Copy(Rec, true);
        Todas.Reset();
        Todas.MarkedOnly(false);
        if Todas.FindSet() then
            repeat
                Ctx.Add(Todas.Nombre, Todas.Valor);
            until Todas.Next() = 0;
    end;

    procedure LoadFromContext(var Ctx: Dictionary of [Text, Decimal]; var TipoMap: Dictionary of [Text, Text])
    var
        Keys: List of [Text];
        K: Text;
        Tipo: Text[20];
    begin
        Rec.Reset();
        Rec.DeleteAll();
        Keys := Ctx.Keys();
        foreach K in Keys do begin
            Tipo := '';
            if TipoMap.ContainsKey(K) then
                Tipo := CopyStr(TipoMap.Get(K), 1, 20);
            Rec.Init();
            Rec.Nombre := CopyStr(K, 1, 100);
            Rec.Valor := Ctx.Get(K);
            Rec.Tipo := Tipo;
            Rec.Insert();
        end;
    end;

    // Catálogo para el editor con IntelliSense. Se arma desde ESTA temporal, la misma que alimenta a
    // GetContext, para que el valor que muestra el autocompletado no pueda diferir nunca del que usa
    // el Evaluador.
    procedure BuildCatalogoJson(): Text
    var
        Catalogo: Codeunit "Catálogo Variables Liq.";
    begin
        exit(Catalogo.BuildCatalogoJson(Rec));
    end;

    procedure GetAndClearPendingInsert(): Text[100]
    var
        Result: Text[100];
    begin
        Result := PendingInsert;
        PendingInsert := '';
        exit(Result);
    end;
}
