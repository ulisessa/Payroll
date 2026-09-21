namespace UAS.Payroll;

page 110011 "Atributos de Entidad"
{
    ApplicationArea = All;
    Caption = 'Atributos';
    PageType = List;
    UsageCategory = Lists;
    SourceTable = "Atributo Entidad Liq.";
    // Mismo orden que la subpágina de la ficha: lo más nuevo arriba. Las dos pantallas muestran lo
    // mismo, así que ordenar distinto sería un defecto en sí. Ver el comentario de Pag110030 sobre
    // por qué el descendente arrastra también al tipo de atributo.
    SourceTableView = sorting("Tipo Entidad", "Cód. Entidad", "Cód. Tipo Atributo", "Vigencia Desde")
                      order(descending);
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Tipo Entidad"; Rec."Tipo Entidad") { ApplicationArea = All; }
                field("Cód. Entidad"; Rec."Cód. Entidad") { ApplicationArea = All; }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field("Vigencia Hasta"; Rec."Vigencia Hasta")
                {
                    ApplicationArea = All;
                    ToolTip = 'En blanco = vigencia abierta. Al cargar una vigencia nueva, la anterior se cierra sola el día previo si estaba abierta.';
                }
                field("Cód. Tipo Atributo"; Rec."Cód. Tipo Atributo")
                {
                    ApplicationArea = All;

                    trigger OnValidate()
                    begin
                        // El FlowField del tipo de dato hay que recalcularlo A MANO: en una fila
                        // nueva se calculó cuando el atributo todavía estaba vacío —y dio Decimal,
                        // que es el valor cero del enum— y sin esto la columna Valor seguiría
                        // interpretando lo que se escriba como un número aunque el atributo sea de
                        // lista.
                        // Sin CurrPage.Update, ni con true ni con false: en una fila que todavía no
                        // existe, las dos formas rompen algo. Con TRUE se fuerza el guardado, la fila
                        // se inserta a medio cargar y completar la clave después pasa a ser un
                        // renombre —la plataforma pide confirmar el cambio de clave en cada alta—.
                        // Con FALSE se relee desde el origen, y como el registro todavía no está,
                        // se pierde lo recién elegido.
                        //
                        // No hace falta ninguna de las dos: la plataforma repinta la fila al salir
                        // del campo, y el tipo de dato ya quedó recalculado en memoria, que es lo
                        // que la columna Valor necesita para saber cómo interpretarse.
                        Rec.CalcFields("Tipo Dato");
                        AtributosUI.ProponerVigenciaLibre(Rec);
                        // Elegido el atributo, si es de lista lo único que falta es el valor. Abrirla
                        // sola ahorra el clic y, sobre todo, evita el camino que no funciona: tipear
                        // el código a mano esperando que la columna autocomplete, que no puede.
                        AtributosUI.AbrirListaSiCorresponde(Rec, ValorEntrada);
                    end;
                }
                field("Tipo Dato"; Rec."Tipo Dato") { ApplicationArea = All; }
                // UNA columna para los cuatro tipos. Antes estaban las cuatro de entrada a la vez y en
                // cada fila tres quedaban vacías: la de lista con el código, y al lado un decimal en
                // cero, un texto vacío y una fecha vacía que no significaban nada. Acá se muestra y se
                // edita la que corresponde al tipo de dato de la fila; las otras siguen existiendo,
                // ocultas, para quien necesite verlas por personalización.
                field(ValorEntrada; ValorEntrada)
                {
                    ApplicationArea = All;
                    Caption = 'Valor';
                    ToolTip = 'El valor de este atributo. Si es de lista se elige con el botón de búsqueda —y solo se ofrecen los que cuelgan del padre vigente ese día—; si es numérico, texto o fecha, se escribe.';

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        ValorAtr: Record "Valor Atributo Liq.";
                    begin
                        Rec.CalcFields("Tipo Dato");
                        if Rec."Tipo Dato" <> Rec."Tipo Dato"::Lista then
                            exit(false);
                        if not AtributosUI.ElegirValorDeLista(Rec, Text, ValorAtr) then
                            exit(false);
                        Text := ValorAtr.Código;
                        exit(true);
                    end;

                    trigger OnValidate()
                    begin
                        AtributosUI.AplicarValor(Rec, ValorEntrada);
                    end;
                }
                field("Cód. Valor"; Rec."Cód. Valor")
                {
                    ApplicationArea = All;
                    Visible = false;
                    ToolTip = 'Valor elegido de la lista del atributo.';
                }
                field("Cód. Valor Padre"; Rec."Cód. Valor Padre")
                {
                    ApplicationArea = All;
                    Caption = 'Cuelga de';
                    // Oculta: es derivada, está vacía en todos los atributos que no dependen de otro,
                    // y en los encadenados no agrega nada a la lectura normal — la categoría ya se
                    // eligió entre las del convenio correcto. Se muestra por personalización cuando
                    // hay que verificar contra qué padre quedó congelada una vigencia vieja.
                    Visible = false;
                    ToolTip = 'Para los atributos encadenados, el valor del padre que la entidad tenía vigente el día en que empieza esta vigencia. Se completa solo y queda congelado: el par de enero sigue siendo el de enero aunque el padre cambie después.';
                }
                field("Descripción Valor"; Rec."Descripción Valor") { ApplicationArea = All; }
                field("Valor Decimal"; Rec."Valor Decimal") { ApplicationArea = All; Visible = false; }
                field("Valor Texto"; Rec."Valor Texto") { ApplicationArea = All; Visible = false; }
                field("Valor Fecha"; Rec."Valor Fecha") { ApplicationArea = All; Visible = false; }
                field("Valor Numérico"; Rec."Valor Numérico")
                {
                    ApplicationArea = All;
                    Visible = false;
                    ToolTip = 'El número que efectivamente ve la fórmula. Queda congelado al asignar, para que un recálculo de un período viejo dé lo mismo que dio.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            // Dos acciones que se turnan la visibilidad: en AL el Caption de una acción es constante
            // y no admite expresión, así que es la única forma de que el botón diga qué va a hacer.
            action(VerTodas)
            {
                ApplicationArea = All;
                Caption = 'Ver historial completo';
                Image = History;
                Visible = SoloActualesActivo;
                ToolTip = 'Muestra también las vigencias que ya terminaron y las que todavía no empezaron.';
                trigger OnAction()
                begin
                    SoloActuales := false;
                    AplicarFiltros();
                end;
            }
            action(VerActuales)
            {
                ApplicationArea = All;
                Caption = 'Ver solo actuales';
                Image = FilterLines;
                Visible = VerTodasActivo;
                ToolTip = 'Muestra solo los atributos vigentes hoy.';
                trigger OnAction()
                begin
                    SoloActuales := true;
                    AplicarFiltros();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        SoloActuales := true;
        AplicarFiltros();
    end;

    trigger OnAfterGetRecord()
    begin
        Rec.CalcFields("Tipo Dato");
        ValorEntrada := AtributosUI.ValorParaEditar(Rec);
    end;

    // La columna Valor no es un campo de la tabla: es la variable ValorEntrada, que OnAfterGetRecord
    // llena al posarse sobre cada fila. Y en una fila NUEVA ese trigger no corre —todavía no hay
    // registro que leer— así que la variable conservaba lo último que se hubiera cargado: el valor de
    // la fila anterior, mostrado como si fuera el de ésta. Peor que un adorno, porque si el usuario
    // no lo pisaba, al salir de la línea se guardaba de verdad.
    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        ValorEntrada := '';
        ProponerEntidadDelFiltro();
    end;

    /// <summary>
    /// Deja la fila nueva apuntando a la entidad desde la que se abrió la página.
    /// </summary>
    /// <remarks>
    /// La plataforma llena los campos de una fila nueva a partir del vínculo cuando la página se
    /// abre con RunPageLink —el camino desde la ficha del empleado—, pero no cuando se abre con
    /// Page.Run sobre un registro filtrado, que es como entra desde la ficha de la entidad y desde
    /// el factbox. Ahí la fila nacía vacía y había que volver a tipear el buque del que uno venía,
    /// teniéndolo en el título de la pantalla anterior.
    ///
    /// Se propone y no se fuerza: si el filtro abarca más de una entidad —un rango, una lista, un
    /// comodín— no hay una respuesta única y la fila queda en blanco, que es lo correcto.
    /// </remarks>
    local procedure ProponerEntidadDelFiltro()
    var
        FiltroTipo: Text;
        FiltroCodigo: Text;
    begin
        FiltroTipo := Rec.GetFilter("Tipo Entidad");
        if (FiltroTipo <> '') and EsValorUnico(FiltroTipo) then
            if Evaluate(Rec."Tipo Entidad", FiltroTipo) then;

        FiltroCodigo := Rec.GetFilter("Cód. Entidad");
        if (FiltroCodigo <> '') and EsValorUnico(FiltroCodigo) then
            Rec."Cód. Entidad" := CopyStr(FiltroCodigo, 1, MaxStrLen(Rec."Cód. Entidad"));
    end;

    // Se mira el TEXTO del filtro y no GetRangeMin/GetRangeMax: ésos cortan con un error cuando el
    // filtro no es un rango, y acá el filtro lo puede haber escrito el usuario en la propia lista.
    local procedure EsValorUnico(Filtro: Text): Boolean
    begin
        exit(not (Filtro.Contains('|') or Filtro.Contains('..') or Filtro.Contains('*') or
                  Filtro.Contains('<') or Filtro.Contains('>') or Filtro.Contains('&') or
                  Filtro.Contains('=') or Filtro.Contains('''')));
    end;

    // Sin OnNewRecord que proponga la fecha de trabajo, y es deliberado.
    //
    // "Vigencia Desde" es parte de la clave primaria. Proponer un valor hacía que la fila naciera con
    // una clave que casi nunca era la correcta —una vigencia se carga con la fecha en que rige, no
    // con la de hoy— y corregirla después no es editar un campo: es RENOMBRAR el registro, con todo
    // lo que eso arrastra. Que el campo arranque vacío y lo complete el usuario evita el renombre.
    //
    // Lo que aquel default protegía —el choque de dos filas con la fecha en blanco, que aparecía como
    // "registro duplicado" y mandaba a buscar el problema al lugar equivocado— ya está cubierto en el
    // OnInsert de la tabla, que corta con un error que nombra la fecha faltante. Y DelayedInsert está
    // en true arriba: la fila no se escribe hasta que el usuario sale de la línea, así que hay dónde
    // completar la fecha antes de que exista el registro.

    // "Solo actuales" se resuelve con dos filtros, no marcando fila por fila.
    //
    // La versión anterior recorría las vigencias, marcaba las que VigenteA daba por buenas y mostraba
    // solo las marcadas. El problema es que las marcas no sobreviven a que la plataforma relea el
    // conjunto —insertar una fila alcanza, y con DelayedInsert eso pasa en cada alta— y entonces la
    // lista se vaciaba sola: atributos vigentes, con "Vigencia Hasta" en blanco, desaparecían de la
    // vista sin que nadie hubiera filtrado nada.
    //
    // El filtro sobre el "hasta" es la misma condición que evalúa VigenteA, escrita como lista de
    // valores donde el 0D es uno más. Esa forma ya la usan el motor (Cod50080) y la resolución del
    // valor padre en la tabla, así que no es terreno nuevo. Y además de no romperse, descarta en SQL
    // en vez de traerse todas las vigencias para tirarlas en memoria.
    local procedure AplicarFiltros()
    begin
        SoloActualesActivo := SoloActuales;
        VerTodasActivo := not SoloActuales;
        AtributosUI.FiltrarVigentes(Rec, SoloActuales, WorkDate());
        CurrPage.Update(false);
    end;

    var
        AtributosUI: Codeunit "Atributos Entidad UI";
        SoloActuales: Boolean;
        SoloActualesActivo: Boolean;
        VerTodasActivo: Boolean;
        ValorEntrada: Text;
}
