namespace UAS.Payroll;

using Microsoft.Finance.Dimension;
using Microsoft.Finance.GeneralLedger.Setup;

// Los valores de la dimensión global 1 — buques, plantas, administraciones — y su entidad asociada.
//
// Esta página es el PUENTE de alta y nada más: desde acá se crea la entidad, que hereda el código
// del valor de dimensión. Todo lo operativo —estados, atributos, plantillas— vive en la lista de
// Entidades, porque una entidad clasificada es lo que hace que esas acciones signifiquen algo.
// Un valor de dimensión sin entidad todavía no es un buque ni una planta.
page 50191 "Buques"
{
    PageType = List;
    Caption = 'Valores de Dimensión y Entidades';
    SourceTable = "Dimension Value";
    UsageCategory = Lists;
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Code; Rec.Code)
                {
                    ApplicationArea = All;
                    Caption = 'Código';

                    trigger OnDrillDown()
                    begin
                        AbrirEntidadAsociada();
                    end;
                }
                field(Name; Rec.Name)
                {
                    ApplicationArea = All;
                    Caption = 'Nombre';
                }
                field(EntidadTxt; EntidadTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Entidad';
                    Editable = false;
                    StyleExpr = EntidadStyle;
                    ToolTip = 'Clase de la entidad asociada. Si dice "sin entidad", todavía no fue creada: usá la acción Entidad.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AbrirEntidad)
            {
                ApplicationArea = All;
                Caption = 'Entidad';
                Image = Card;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Abre la entidad asociada a este valor de dimensión. Si todavía no existe, ofrece crearla — es la única vía de alta, para que el código de la entidad sea siempre el del valor de dimensión.';

                trigger OnAction()
                begin
                    AbrirEntidadAsociada();
                end;
            }
        }
        area(Navigation)
        {
            action(VerEntidades)
            {
                ApplicationArea = All;
                Caption = 'Todas las entidades';
                Image = List;
                ToolTip = 'Abre la lista de entidades, donde están los estados, los atributos y las plantillas.';
                RunObject = Page Entidades;
            }
        }
    }

    trigger OnOpenPage()
    var
        GLSetup: Record "General Ledger Setup";
    begin
        GLSetup.Get();
        GLSetup.TestField("Global Dimension 1 Code");
        Rec.FilterGroup(2);
        Rec.SetRange("Dimension Code", GLSetup."Global Dimension 1 Code");
        Rec.SetRange("Dimension Value Type", Rec."Dimension Value Type"::Standard);
        Rec.FilterGroup(0);
    end;

    trigger OnAfterGetRecord()
    var
        Entidad: Record "Entidad Liq.";
    begin
        if Entidad.Get(Rec.Code) then begin
            EntidadTxt := Entidad."Cód. Clase";
            EntidadStyle := 'Favorable';
        end else begin
            EntidadTxt := TxtSinEntidad;
            EntidadStyle := 'Subordinate';
        end;
    end;

    local procedure AbrirEntidadAsociada()
    var
        Entidad: Record "Entidad Liq.";
        Gestion: Codeunit "Gestión Entidades Liq.";
    begin
        if Gestion.ObtenerOCrear(Rec.Code, CopyStr(Rec.Name, 1, 100), Entidad) then
            Page.Run(Page::"Ficha Entidad", Entidad);
        CurrPage.Update(false);
    end;

    var
        EntidadTxt: Text;
        EntidadStyle: Text;
        TxtSinEntidad: Label 'Sin entidad';
}
