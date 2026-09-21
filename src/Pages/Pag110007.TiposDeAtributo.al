namespace UAS.Payroll;

page 110007 "Tipos de Atributo"
{
    ApplicationArea = All;
    Caption = 'Tipos de Atributo';
    PageType = List;
    UsageCategory = Administration;
    SourceTable = "Tipo Atributo Liq.";
    CardPageId = "Ficha Tipo Atributo";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Tipo Dato"; Rec."Tipo Dato")
                {
                    ApplicationArea = All;
                    ToolTip = 'Define en qué columna se carga el valor y cómo llega a una fórmula. "Lista de valores" es la opción preferida para todo lo que decida un cálculo.';
                }
                field("Tipo Entidad"; Rec."Tipo Entidad")
                {
                    ApplicationArea = All;
                    ToolTip = 'A qué maestro se le carga este atributo.';
                }
                field("Cód. Clase"; Rec."Cód. Clase")
                {
                    ApplicationArea = All;
                    Caption = 'Clase';
                    ToolTip = 'Acota este tipo a una clase de entidad, para que un buque no ofrezca los atributos de una planta. En blanco = aplica a todas.';
                }
                field(Obligatorio; Rec.Obligatorio)
                {
                    ApplicationArea = All;
                    ToolTip = 'Los obligatorios son los que "Aplicar plantilla" materializa al clasificar una entidad.';
                }
                field("Nombre Variable"; Rec."Nombre Variable")
                {
                    ApplicationArea = All;
                    ToolTip = 'Con este nombre cargado, el atributo se puede usar directamente en una fórmula: en cada liquidación toma el valor de la entidad que corresponda, vigente a esa fecha. En blanco no se inyecta.';
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(VerValores)
            {
                ApplicationArea = All;
                Caption = 'Valores permitidos';
                Image = List;
                ToolTip = 'Lista cerrada contra la que se valida este atributo, y el número que cada valor le pasa a las fórmulas.';
                Enabled = EsLista;
                RunObject = Page "Valores de Atributo";
                RunPageLink = "Cód. Tipo Atributo" = field(Código);
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

    // Hereda la clase del filtro con el que se abrió la lista. Se lee el filtro en vez de confiar en
    // que la plataforma lo copie sola: eso solo ocurre con ciertos grupos de filtro, y acá la lista
    // se abre tanto desde "Clases de Entidad" (que fija el filtro) como filtrando a mano en la
    // pantalla, donde no pasaba nada y el atributo nuevo nacía sin clase.
    trigger OnNewRecord(BelowxRec: Boolean)
    var
        FiltroClase: Text;
    begin
        if Rec."Cód. Clase" <> '' then
            exit;
        FiltroClase := Rec.GetFilter("Cód. Clase");
        // Solo un valor simple: un filtro con rangos o comodines no identifica una clase única.
        if (FiltroClase = '') or (StrPos(FiltroClase, '|') > 0) or (StrPos(FiltroClase, '.') > 0) or
           (StrPos(FiltroClase, '*') > 0) or (StrPos(FiltroClase, '<') > 0) or (StrPos(FiltroClase, '>') > 0)
        then
            exit;
        Rec."Cód. Clase" := CopyStr(DelChr(FiltroClase, '<>', ''''), 1, MaxStrLen(Rec."Cód. Clase"));
    end;

    var
        EsLista: Boolean;
}
