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

    procedure GetContext(var Ctx: Dictionary of [Text, Decimal])
    begin
        Clear(Ctx);
        Rec.Reset();
        if Rec.FindSet() then
            repeat
                Ctx.Add(Rec.Nombre, Rec.Valor);
            until Rec.Next() = 0;
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

    procedure GetAndClearPendingInsert(): Text[100]
    var
        Result: Text[100];
    begin
        Result := PendingInsert;
        PendingInsert := '';
        exit(Result);
    end;
}
