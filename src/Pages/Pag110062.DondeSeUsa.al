namespace UAS.Payroll;

// Dónde se usa un símbolo: qué fórmulas, condiciones, filtros y acumuladores lo nombran.
//
// Este motor se configura, no se codifica, y eso tiene un precio: la dependencia entre dos cosas no
// está en ningún lado como declaración, está escondida dentro de un campo de texto. Para saber a
// quién le afecta tocar un parámetro hay que leer dos mil fórmulas, y nadie lo hace.
//
// LA COLUMNA ROJA ES LA RAZÓN DE SER. El motor falla en silencio cuando una fórmula lee algo que
// todavía no se calculó: devuelve cero y paga de menos sin un solo error. Y con un ACUMULADOR el
// umbral no es su orden sino el de su último aportante —el acumulador existe desde el principio,
// pero no está COMPLETO hasta el final—. Esa confusión costó medio día de SQL cada vez que apareció.
page 110062 "Dónde se Usa"
{
    ApplicationArea = All;
    Caption = 'Dónde se usa';
    PageType = List;
    UsageCategory = ReportsAndAnalysis;
    SourceTable = "Uso Símbolo Liq.";
    SourceTableTemporary = true;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    // Sin Editable = false a nivel página: bloquearía los campos de la cabecera, que son lo único que
    // acá se escribe.

    layout
    {
        area(Content)
        {
            group(Busqueda)
            {
                Caption = 'Búsqueda';

                field(Simbolo; Simbolo)
                {
                    ApplicationArea = All;
                    Caption = 'Símbolo';
                    ToolTip = 'El nombre tal como aparece en una fórmula: un código de concepto (1053), un acumulador (BASE_PROMEDIO), un parámetro, una fuente de datos, una variable de sistema o un atributo. Sin el # ni el @.';

                    trigger OnValidate()
                    begin
                        Cargar();
                    end;
                }
                field(SoloVigentes; SoloVigentes)
                {
                    ApplicationArea = All;
                    Caption = 'Sólo vigentes';
                    ToolTip = 'Deja afuera las vigencias ya cerradas y las que todavía no arrancaron. Apagado, muestra también la historia, que sirve para entender un importe viejo.';

                    trigger OnValidate()
                    begin
                        Cargar();
                    end;
                }
                field(ConSufijos; ConSufijos)
                {
                    ApplicationArea = All;
                    Caption = 'Incluir sufijos';
                    ToolTip = 'Encuentra también las formas sufijadas, que es el caso de un parámetro: se llama PRECIO_NAV y la fórmula puede nombrar PRECIO_NAV_LAN. Apagado por omisión, porque con esto DIAS también encuentra DIAS_MAREA.';

                    trigger OnValidate()
                    begin
                        Cargar();
                    end;
                }
                field(Resumen; Resumen)
                {
                    ApplicationArea = All;
                    Caption = 'Resultado';
                    Editable = false;
                    MultiLine = true;
                    StyleExpr = EstiloResumen;
                    ToolTip = 'Cuántos usos se encontraron y cuántos de ellos leen el símbolo antes de que esté listo.';
                }
            }

            repeater(Grilla)
            {
                field("Tipo Uso"; Rec."Tipo Uso")
                {
                    ApplicationArea = All;
                    ToolTip = 'Qué clase de objeto lo nombra. Las dos filas de fracción son las que más se olvidan: "Aportante del acum." es quién le suma al símbolo, y "Aporta al acumulador" es a qué bases entra él. Un concepto puede no estar en ninguna fórmula y mover plata igual, por su fracción.';
                }
                field("Cód. Objeto"; Rec."Cód. Objeto")
                {
                    ApplicationArea = All;
                    ToolTip = 'El objeto que usa el símbolo.';
                }
                field("Descripción Objeto"; Rec."Descripción Objeto")
                {
                    ApplicationArea = All;
                }
                field(Campo; Rec.Campo)
                {
                    ApplicationArea = All;
                    ToolTip = 'En qué campo aparece. Una condición y una variable de cantidad se olvidan al revisar a mano y pesan igual que la fórmula.';
                }
                field("Orden Cálculo"; Rec."Orden Cálculo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Orden de cálculo de quien lo usa. En cero cuando el objeto no participa del bucle de conceptos: una fuente de datos y una variable de sistema se resuelven antes y están siempre disponibles.';
                }
                field("Orden Símbolo Listo"; Rec."Orden Símbolo Listo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Orden a partir del cual el símbolo ya vale lo que va a valer. Para un concepto es su propio orden; para un acumulador, el de su último aportante.';
                }
                field("Lee Antes de Estar Listo"; Rec."Lee Antes de Estar Listo")
                {
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                    ToolTip = 'Corre antes de que el símbolo esté listo: va a leer cero, o un acumulador a medio llenar, y no va a dar ningún error. Se arregla moviendo al PRODUCTOR hacia atrás, no al consumidor hacia adelante.';
                }
                field(Fragmento; Rec.Fragmento)
                {
                    ApplicationArea = All;
                    ToolTip = 'El texto alrededor de la aparición, para juzgar si el uso es real sin abrir el objeto.';
                }
                field(Vigente; Rec.Vigente)
                {
                    ApplicationArea = All;
                    ToolTip = 'Vigente hoy según las fechas de la vigencia.';
                }
                field("Vigencia Desde"; Rec."Vigencia Desde")
                {
                    ApplicationArea = All;
                }
                field("Vigencia Hasta"; Rec."Vigencia Hasta")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AbrirObjeto)
            {
                ApplicationArea = All;
                Caption = 'Abrir el objeto';
                Image = View;
                ToolTip = 'Abre el concepto, la fuente de datos o la variable de sistema de la fila.';

                trigger OnAction()
                begin
                    AbrirObjetoDeLaFila();
                end;
            }
            action(Recargar)
            {
                ApplicationArea = All;
                Caption = 'Recargar';
                Image = Refresh;
                ToolTip = 'Vuelve a buscar. Hace falta después de editar una fórmula desde otra ventana.';

                trigger OnAction()
                begin
                    Cargar();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(AbrirObjeto_Promoted; AbrirObjeto)
                {
                }
                actionref(Recargar_Promoted; Recargar)
                {
                }
            }
        }
    }

    var
        BuscarMgt: Codeunit "Buscar Usos Liq.";
        Simbolo: Code[50];
        SoloVigentes: Boolean;
        ConSufijos: Boolean;
        Resumen: Text;
        EstiloResumen: Text;
        EstiloFila: Text;
        SinUsosMsg: Label 'El símbolo %1 no aparece en ninguna fórmula, condición, filtro ni acumulador. O está mal escrito, o es configuración muerta.', Comment = '%1 = símbolo buscado';
        ResumenOkMsg: Label '%1 uso(s). El símbolo tiene su valor definitivo a partir del orden %2.', Comment = '%1 = cantidad de usos, %2 = orden';
        ResumenTardeMsg: Label '%1 uso(s), y %2 lee(n) el símbolo ANTES de que esté listo (orden %3): esos devuelven cero o un valor a medio llenar, sin dar error.', Comment = '%1 = usos, %2 = usos tardíos, %3 = orden';
        TipoConceptoTok: Label 'Concepto', Locked = true;
        TipoAportanteTok: Label 'Aportante del acum.', Locked = true;
        TipoAportaATok: Label 'Aporta al acumulador', Locked = true;
        TipoFuenteTok: Label 'Fuente de Datos', Locked = true;
        TipoVarSistemaTok: Label 'Variable de Sistema', Locked = true;

    trigger OnOpenPage()
    begin
        SoloVigentes := true;
        if Simbolo <> '' then
            Cargar();
    end;

    trigger OnAfterGetRecord()
    begin
        if Rec."Lee Antes de Estar Listo" then
            EstiloFila := 'Unfavorable'
        else
            EstiloFila := 'Standard';
    end;

    // Para abrirla ya apuntada a algo desde la ficha de un concepto, de un parámetro o de una fuente.
    procedure SetSimbolo(NuevoSimbolo: Code[50])
    begin
        Simbolo := UpperCase(NuevoSimbolo);
    end;

    local procedure Cargar()
    var
        Tardios: Integer;
        Total: Integer;
        OrdenListo: Integer;
    begin
        Simbolo := UpperCase(Simbolo);
        Rec.Reset();
        Rec.DeleteAll();
        Resumen := '';
        EstiloResumen := 'Standard';
        if Simbolo = '' then begin
            CurrPage.Update(false);
            exit;
        end;

        BuscarMgt.Buscar(Simbolo, SoloVigentes, ConSufijos, Rec);
        OrdenListo := BuscarMgt.OrdenSimboloListo(Simbolo);

        Rec.Reset();
        Total := Rec.Count();
        Rec.SetRange("Lee Antes de Estar Listo", true);
        Tardios := Rec.Count();
        Rec.Reset();

        if Total = 0 then begin
            Resumen := StrSubstNo(SinUsosMsg, Simbolo);
            EstiloResumen := 'Ambiguous';
        end else
            if Tardios > 0 then begin
                Resumen := StrSubstNo(ResumenTardeMsg, Total, Tardios, OrdenListo);
                EstiloResumen := 'Unfavorable';
            end else begin
                Resumen := StrSubstNo(ResumenOkMsg, Total, OrdenListo);
                EstiloResumen := 'Favorable';
            end;

        Rec.SetCurrentKey("Tipo Uso", "Orden Cálculo", "Cód. Objeto");
        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;

    local procedure AbrirObjetoDeLaFila()
    var
        Concepto: Record "Concepto Liquidación";
        Fuente: Record "Fuente Datos Liquidación";
        VarSist: Record "Variable Sistema Liq.";
    begin
        if Rec."Cód. Objeto" = '' then
            exit;

        case Rec."Tipo Uso" of
            TipoConceptoTok, TipoAportanteTok, TipoAportaATok:
                begin
                    Concepto.SetRange(Código, CopyStr(Rec."Cód. Objeto", 1, 20));
                    if Rec."Vigencia Desde" <> 0D then
                        Concepto.SetRange("Vigencia Desde", Rec."Vigencia Desde");
                    if Concepto.FindFirst() then
                        Page.Run(Page::"Concepto Liq. Card", Concepto);
                end;
            TipoFuenteTok:
                if Fuente.Get(CopyStr(Rec."Cód. Objeto", 1, 30)) then
                    Page.Run(Page::"Fuente Datos Card", Fuente);
            TipoVarSistemaTok:
                begin
                    VarSist.SetRange("Cód. Cálculo", CopyStr(Rec."Cód. Objeto", 1, 30));
                    Page.Run(Page::"Variable Sistema Liq.", VarSist);
                end;
        end;
    end;
}
