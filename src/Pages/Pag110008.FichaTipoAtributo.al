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
                field("Cód. Clase"; Rec."Cód. Clase")
                {
                    ApplicationArea = All;
                    Caption = 'Clase de entidad';
                    ToolTip = 'Acota este tipo a una clase, para que un buque no ofrezca los atributos de una planta. En blanco = aplica a todas las entidades de ese tipo.';
                }
                field(Obligatorio; Rec.Obligatorio)
                {
                    ApplicationArea = All;
                    ToolTip = 'Los obligatorios son los que "Aplicar plantilla" crea al clasificar una entidad. No bloquean la liquidación: un atributo faltante debe avisar, no impedir que se pague.';
                }
                field("Espejo De"; Rec."Espejo De")
                {
                    ApplicationArea = All;
                    Caption = 'Espejo de';
                    Enabled = EsLista;
                    ToolTip = 'Copia los valores permitidos de una tabla maestra en vez de cargarlos a mano. Los códigos quedan siempre iguales a los del maestro, que es lo que el motor necesita para resolver el % de escala y los parámetros por sufijo. Un espejo no se edita desde acá: se cambia en el maestro.';
                }
                field("Cód. Tipo Atributo Padre"; Rec."Cód. Tipo Atributo Padre")
                {
                    ApplicationArea = All;
                    Caption = 'Depende de';
                    Enabled = EsLista;
                    ToolTip = 'Encadena este atributo con otro de tipo Lista: sus valores cuelgan de un valor del padre, y al asignarlo solo se ofrecen los que correspondan al valor que la entidad tenga vigente ese día. Ej.: CATEGORIA depende de CONVENIO.';
                }
                field("Padre Según el Valor"; Rec."Padre Según el Valor")
                {
                    ApplicationArea = All;
                    Caption = 'Padre según el valor';
                    Enabled = EsLista;
                    ToolTip = 'Marcado, el valor del padre lo trae el valor que se elige, y se ofrecen todos los del atributo sin importar qué tenga la entidad en el padre. Desmarcado (lo normal), el padre lo deriva la entidad: sólo se ofrecen los que cuelgan del valor que tiene vigente ese día. CATEGORIA va desmarcado, para que nadie quede con una categoría de otro convenio; PUESTO va marcado, porque el convenio del puesto sale de la actividad con la que se navega y no del encuadre de la persona.';
                }
                field("Mostrar en Recibo"; Rec."Mostrar en Recibo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Marcado, el valor de este atributo se imprime en el recibo, en el bloque de variables. De un atributo de lista sale la descripción del valor, no el código. Necesita Nombre Variable cargado: sin él, el atributo no entra al cálculo y no hay nada que imprimir.';
                }
                field("Etiqueta Recibo"; Rec."Etiqueta Recibo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Con qué nombre sale en el recibo. En blanco se usa la Descripción.';
                }
                field("Nombre Variable"; Rec."Nombre Variable")
                {
                    ApplicationArea = All;
                    ToolTip = 'Con este nombre cargado, el atributo se puede usar directamente en una fórmula: en cada liquidación toma el valor de la entidad que corresponda, vigente a esa fecha. En blanco no se inyecta.';
                }
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
            action(Resincronizar)
            {
                ApplicationArea = All;
                Caption = 'Resincronizar con el maestro';
                Image = Refresh;
                Enabled = EsEspejo;
                ToolTip = 'Vuelve a copiar los valores desde la tabla maestra. En régimen no debería hacer nada —los triggers del maestro lo mantienen al día—; sirve para la carga inicial y para reparar.';

                trigger OnAction()
                var
                    Espejo: Codeunit "Espejo Atributos Liq.";
                    Tocados: Integer;
                begin
                    Tocados := Espejo.Resincronizar(Rec);
                    CurrPage.Update(false);
                    if Tocados = 0 then
                        Message(MsgEspejoAlDia)
                    else
                        Message(MsgEspejoTocados, Tocados);
                end;
            }
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
        EsEspejo := Rec."Espejo De" <> Rec."Espejo De"::Ninguno;
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        EsLista := Rec.UsaLista();
        EsEspejo := false;
    end;

    var
        EsLista: Boolean;
        EsEspejo: Boolean;
        MsgEspejoAlDia: Label 'Los valores ya estaban al día con el maestro.';
        MsgEspejoTocados: Label '%1 valor(es) agregados o corregidos desde el maestro.', Comment = '%1=cantidad';
}
