namespace UAS.Payroll;

page 110008 "Ficha Tipo Atributo"
{
    ApplicationArea = All;
    Caption = 'Tipo de Atributo';
    PageType = Card;
    SourceTable = "Tipo Atributo Liq.";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Tipo Dato"; Rec."Tipo Dato")
                {
                    ApplicationArea = All;
                    ToolTip = 'Define en qué columna se carga el valor y cómo llega a una fórmula. No se puede cambiar una vez que hay valores asignados.';

                    trigger OnValidate()
                    begin
                        CurrPage.Update(true);
                    end;
                }
                field("Tipo Entidad"; Rec."Tipo Entidad") { ApplicationArea = All; }
                field(Obligatorio; Rec.Obligatorio)
                {
                    ApplicationArea = All;
                    ToolTip = 'Marca los atributos que se esperan cargados en toda entidad. No bloquea la liquidación: un atributo faltante debe avisar, no impedir que se pague.';
                }
                field("Nombre Variable"; Rec."Nombre Variable") { ApplicationArea = All; }
            }
            part(Valores; "Valores Atributo Sub")
            {
                ApplicationArea = All;
                Caption = 'Valores permitidos';
                SubPageLink = "Cód. Tipo Atributo" = field(Código);
                UpdatePropagation = Both;
                // Solo tiene sentido para los de tipo Lista: en los demás el valor es libre.
                Visible = EsLista;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(VerValores)
            {
                ApplicationArea = All;
                Caption = 'Valores permitidos';
                Image = List;
                Enabled = EsLista;
                ToolTip = 'Abre la lista completa de valores de este atributo en su propia pantalla, para cargar de a muchos o buscar.';
                trigger OnAction()
                var
                    Valor: Record "Valor Atributo Liq.";
                begin
                    Valor.SetRange("Cód. Tipo Atributo", Rec.Código);
                    // FilterGroup 4 deja el filtro fijo: la lista se abre acotada a este atributo y
                    // el usuario no puede sacarlo por accidente y editar los valores de otro.
                    Valor.FilterGroup(4);
                    Valor.SetRange("Cód. Tipo Atributo", Rec.Código);
                    Valor.FilterGroup(0);
                    Page.Run(Page::"Valores de Atributo", Valor);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';
                actionref(VerValoresProm; VerValores) { }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        EsLista := Rec.UsaLista();
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        EsLista := Rec.UsaLista();
    end;

    var
        EsLista: Boolean;
}
