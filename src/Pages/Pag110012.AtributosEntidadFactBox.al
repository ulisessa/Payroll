namespace UAS.Payroll;

// Los atributos VIGENTES de la entidad, para mirar de reojo desde su ficha.
//
// Tabla temporal y no SubPageLink: "vigente" es "arrancó y todavía no terminó", y expresar eso como
// filtro exige preguntar por una fecha de fin en blanco sobre un campo Date. Esa forma ya nos costó
// un cálculo entero — cuando no se comporta como uno espera devuelve de menos en silencio. Acá la
// entidad ya acota el conjunto a unas pocas filas, así que se resuelven en código y se copian.
page 110012 "Atributos Entidad FactBox"
{
    ApplicationArea = All;
    Caption = 'Atributos';
    PageType = ListPart;
    SourceTable = "Atributo Entidad Liq.";
    SourceTableTemporary = true;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Cód. Tipo Atributo"; Rec."Cód. Tipo Atributo")
                {
                    ApplicationArea = All;
                    Caption = 'Atributo';
                    trigger OnDrillDown()
                    begin
                        AbrirHistorial();
                    end;
                }
                field(ValorMostrar; ValorMostrar)
                {
                    ApplicationArea = All;
                    Caption = 'Valor';
                    Style = Strong;
                }
                field("Vigencia Desde"; Rec."Vigencia Desde")
                {
                    ApplicationArea = All;
                    Caption = 'Desde';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(VerHistorial)
            {
                ApplicationArea = All;
                Caption = 'Ver historial';
                Image = History;
                ToolTip = 'Abre todos los atributos de esta entidad, incluidas las vigencias cerradas y las futuras.';
                trigger OnAction()
                begin
                    AbrirHistorial();
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        ValorMostrar := Rec.ValorParaMostrar();
    end;

    /// <summary>
    /// La llama la ficha de la entidad en OnAfterGetCurrRecord. Sin esto el factbox queda vacío:
    /// una tabla temporal no se llena sola con un SubPageLink.
    /// </summary>
    procedure SetEntidad(TipoEntidad: Enum "Tipo Entidad Estado"; CodEntidad: Code[20])
    begin
        FTipoEntidad := TipoEntidad;
        FCodEntidad := CodEntidad;
        Cargar();
    end;

    local procedure Cargar()
    var
        Origen: Record "Atributo Entidad Liq.";
    begin
        Rec.Reset();
        Rec.DeleteAll();
        FTieneDatos := false;

        if FCodEntidad = '' then begin
            CurrPage.Update(false);
            exit;
        end;

        Origen.SetRange("Tipo Entidad", FTipoEntidad);
        Origen.SetRange("Cód. Entidad", FCodEntidad);
        if Origen.FindSet() then
            repeat
                // Una fila por atributo: la que rige hoy. La contigüidad que mantiene la tabla
                // garantiza que no haya dos vigentes a la vez para el mismo atributo.
                if Origen.VigenteA(WorkDate()) then begin
                    Rec := Origen;
                    Rec.Insert();
                    FTieneDatos := true;
                end;
            until Origen.Next() = 0;

        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;

    local procedure AbrirHistorial()
    var
        Todos: Record "Atributo Entidad Liq.";
    begin
        if FCodEntidad = '' then
            exit;
        Todos.SetRange("Tipo Entidad", FTipoEntidad);
        Todos.SetRange("Cód. Entidad", FCodEntidad);
        Page.Run(Page::"Atributos de Entidad", Todos);
    end;

    var
        FTipoEntidad: Enum "Tipo Entidad Estado";
        FCodEntidad: Code[20];
        FTieneDatos: Boolean;
        ValorMostrar: Text;
}
