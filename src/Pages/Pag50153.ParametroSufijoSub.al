namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

page 50153 "Parámetro Sufijo Sub"
{
    ApplicationArea = All;
    Caption = 'Valores por alcance';
    PageType = ListPart;
    SourceTable = "Parámetro Vigente";
    // Mismo orden que el árbol completo: la clave primaria, que alfabéticamente ya deja a cada
    // especialización debajo de la clave de la que deriva.
    SourceTableView = sorting("Cód. Parámetro Base", "Cód. Parámetro", "Vigencia Desde");
    DelayedInsert = true;
    // Los tres campos de alcance están SIEMPRE habilitados. Antes se habilitaban y deshabilitaban
    // según qué bandera de sufijo tuviera el parámetro; ahora la clave derivada sale de los campos
    // que se completen, así que la bandera no hace falta y un parámetro puede tener a la vez un
    // valor por defecto, una excepción por convenio y otra por empleado.
    //
    // La clave la arma la tabla (Parámetro Vigente.RecalcularClave) y no esta página: es la misma
    // regla que usa el motor para buscarla, y tenerla en un solo lugar es lo que evita que se
    // desincronicen.

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                // Lista plana, NO árbol. Se probó con ShowAsTree para que la jerarquía de la clave
                // derivada se viera dibujada —valor por defecto arriba, excepciones debajo— y el
                // costo fue desproporcionado: un repeater en modo árbol no ofrece la fila en blanco
                // del pie, que es el modo natural de cargar en BC. Esta pantalla existe sobre todo
                // para CARGAR valores, y perder el alta inline para ganar una sangría es un mal
                // negocio.
                //
                // La jerarquía igual se lee: el orden de la vista agrupa por parámetro base y clave
                // derivada, la columna Alcance la dice en palabras ("Convenio 729/15, categoría
                // MR03") y la clave inconsistente sigue resaltada en rojo. Para verla dibujada está
                // el Árbol de Parámetros, que es una pantalla de consulta y ahí sí corresponde.

                field(Alcance; Alcance)
                {
                    ApplicationArea = All;
                    Caption = 'Alcance';
                    Editable = false;
                    Visible = false;
                }
                field("Cód. Convenio"; Rec."Cód. Convenio")
                {
                    ApplicationArea = All;
                    Caption = 'Cód. Convenio';
                    Editable = not Rec."En Uso";
                    ToolTip = 'Convenio para el que aplica este valor. Solo, arma la excepción por convenio; con la categoría, la excepción por convenio y categoría.';
                }
                field("Cód. Categoría"; Rec."Cód. Categoría")
                {
                    ApplicationArea = All;
                    Caption = 'Cód. Categoría';
                    Editable = not Rec."En Uso";
                    ToolTip = 'Categoría para la que aplica este valor. Se carga junto con el convenio.';
                }
                field("No. Empleado"; Rec."No. Empleado")
                {
                    ApplicationArea = All;
                    Caption = 'No. Empleado';
                    Editable = not Rec."En Uso";
                    ToolTip = 'Empleado para el que aplica este valor. Excluyente con convenio y categoría: al completarlo, esos dos se limpian.';
                }

                // Los ejes de atributo. Se EDITA eligiendo el valor del atributo —"Potero"— y se
                // GUARDA su sufijo —CAL—. Ver OnLookup: pedirle al usuario que tipee el sufijo sería
                // pedirle que sepa una convención interna.
                //
                // EL EJE 1 VA SIEMPRE VISIBLE, y no condicionado a que el parámetro lo declare.
                // La primera versión lo ataba a VisibleEje1, calculado al abrir el part leyendo el
                // filtro del SubPageLink, y la columna NO APARECÍA ni en los parámetros que sí
                // declaran eje: el `Visible` de una columna se resuelve al construir el layout, antes
                // de que el part tenga su filtro aplicado, así que la variable valía false siempre.
                //
                // Una columna vacía en los 85 parámetros sin eje es poca cosa frente a una columna
                // que no se ve cuando hace falta. Los ejes 2 y 3 quedan ocultos de entrada —hoy no
                // hay ningún parámetro con más de uno— y se muestran con "Elegir columnas".
                //
                // El CaptionClass sí funciona por fila, así que el título dice el nombre del atributo
                // en cuanto hay uno declarado, y "Eje 1" cuando no.
                field("Sufijo Atributo 1"; Rec."Sufijo Atributo 1")
                {
                    ApplicationArea = All;
                    CaptionClass = '3,' + CaptionEje(1);
                    Editable = not Rec."En Uso";
                    ToolTip = 'Valor del primer eje para el que aplica este importe. Vacío = sirve para cualquier valor de ese atributo, y hace de valor por defecto.';

                    trigger OnLookup(var Text: Text): Boolean
                    begin
                        exit(BuscarSufijo(1, Text));
                    end;
                }
                field("Sufijo Atributo 2"; Rec."Sufijo Atributo 2")
                {
                    ApplicationArea = All;
                    CaptionClass = '3,' + CaptionEje(2);
                    Visible = false;
                    Editable = not Rec."En Uso";
                    ToolTip = 'Valor del segundo eje. No se puede cargar sin el primero.';

                    trigger OnLookup(var Text: Text): Boolean
                    begin
                        exit(BuscarSufijo(2, Text));
                    end;
                }
                field("Sufijo Atributo 3"; Rec."Sufijo Atributo 3")
                {
                    ApplicationArea = All;
                    CaptionClass = '3,' + CaptionEje(3);
                    Visible = false;
                    Editable = not Rec."En Uso";
                    ToolTip = 'Valor del tercer eje. No se puede cargar sin el segundo.';

                    trigger OnLookup(var Text: Text): Boolean
                    begin
                        exit(BuscarSufijo(3, Text));
                    end;
                }

                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field(Valor; Rec.Valor)
                {
                    ApplicationArea = All;
                    Editable = not Rec."En Uso";
                }
                field(Moneda; Rec.Moneda) { ApplicationArea = All; }
                field("Cód. Variable TC"; Rec."Cód. Variable TC") { ApplicationArea = All; }
                field("En Uso"; Rec."En Uso")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Style = Attention;
                    StyleExpr = Rec."En Uso";
                }
                field(Descripción; Rec.Descripción)
                {
                    ApplicationArea = All;
                    Caption = 'Descripción Versión';
                }
                field("Cód. Parámetro"; Rec."Cód. Parámetro")
                {
                    ApplicationArea = All;
                    Caption = 'Clave Derivada';
                    StyleExpr = EstiloClave;
                    ToolTip = 'La clave con la que el motor busca este valor. Se calcula sola: dejando el alcance vacío queda la clave base, que hace de valor por defecto.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            // El alta normal es la fila en blanco del pie: se tipea el alcance y la tabla arma la
            // clave derivada sola. Estas dos acciones son atajos, no el camino principal.
            action(NuevoValor)
            {
                ApplicationArea = All;
                Caption = 'Nuevo valor...';
                Image = New;
                ToolTip = 'Crea un valor y abre su ficha para completar el alcance con más contexto. Para cargar de a varios, conviene la fila en blanco del final de la lista.';

                trigger OnAction()
                begin
                    CrearValor(false);
                end;
            }
            action(NuevaVigencia)
            {
                ApplicationArea = All;
                Caption = 'Nueva vigencia';
                Image = NewRow;
                ToolTip = 'Crea una vigencia nueva para el alcance de la fila seleccionada, copiando su valor. Es la forma de cambiar un valor ya usado en una liquidación sin tocar el anterior.';

                trigger OnAction()
                begin
                    CrearValor(true);
                end;
            }
        }
    }

    /// <summary>
    /// Da de alta un valor y abre su ficha. Con HeredarAlcance, arranca del alcance de la fila.
    /// </summary>
    /// <remarks>
    /// La fila se inserta ANTES de abrir la ficha, que es como se dan de alta las fichas en toda la
    /// base: la clave derivada la calcula la tabla al insertar, y la ficha necesita un registro real
    /// para poder guardar lo que se edite. Si se abandona la ficha queda una fila con el valor en
    /// cero — visible y borrable, que es mejor que un alta que parece haberse guardado.
    /// </remarks>
    local procedure CrearValor(HeredarAlcance: Boolean)
    var
        Nuevo: Record "Parámetro Vigente";
    begin
        if FBaseCodigo = '' then
            Error(ErrSinParametro);

        Nuevo.Init();
        Nuevo."Cód. Parámetro Base" := FBaseCodigo;
        if HeredarAlcance then begin
            if Rec."Cód. Parámetro" = '' then
                Error(ErrSinFila);
            Nuevo."Cód. Convenio" := Rec."Cód. Convenio";
            Nuevo."Cód. Categoría" := Rec."Cód. Categoría";
            Nuevo."No. Empleado" := Rec."No. Empleado";
            Nuevo.Valor := Rec.Valor;
            Nuevo.Moneda := Rec.Moneda;
            Nuevo."Cód. Variable TC" := Rec."Cód. Variable TC";
        end;
        Nuevo."Vigencia Desde" := WorkDate();
        Nuevo.RecalcularClave();

        // Mismo alcance y misma fecha que una fila que ya está: son dos respuestas para la misma
        // pregunta. Se avisa acá, que es donde se entiende, en vez de dejar salir el error de clave
        // duplicada de la plataforma.
        if not Nuevo.Insert(true) then
            Error(ErrYaExiste, Nuevo."Cód. Parámetro", Nuevo."Vigencia Desde");

        // El Commit es obligatorio, no una precaución: abrir una página MODAL con la transacción de
        // escritura abierta —y el Insert de arriba la deja abierta— la corta con un "se produjo un
        // error y la transacción se detuvo", sin decir cuál. Confirmar acá además es lo coherente
        // con lo que ya pasa: la fila existe desde el Insert, se cancele o no la ficha.
        Commit();
        Page.RunModal(Page::"Ficha Valor Parámetro", Nuevo);
        CurrPage.Update(false);
    end;

    // La clave la calcula la tabla al insertar y al cambiar cualquier campo de alcance. Acá solo se
    // fija el parámetro base: con el alcance vacío, la clave queda igual al código base y esa fila
    // es el valor por defecto.
    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        if FBaseCodigo = '' then exit;
        Rec."Cód. Parámetro Base" := FBaseCodigo;
        Rec.RecalcularClave();
        if Rec."Vigencia Desde" = 0D then
            Rec."Vigencia Desde" := WorkDate();
    end;

    procedure SetBaseCodigo(BaseCodigo: Code[20])
    begin
        FBaseCodigo := BaseCodigo;
        Rec.FilterGroup(2);
        Rec.SetRange("Cód. Parámetro Base", BaseCodigo);
        Rec.FilterGroup(0);
        CurrPage.Update(false);
    end;

    trigger OnAfterGetRecord()
    var
        Claves: Codeunit "Claves Parámetro Liq.";
    begin
        Alcance := DescribirAlcance();
        // Una clave que no coincide con lo que se derivaría de su alcance es inalcanzable para el
        // motor: se resalta acá para que no haya que abrir el diagnóstico para notarla.
        if Rec."Cód. Parámetro" <> Claves.ArmarDeFila(Rec) then
            EstiloClave := 'Attention'
        else
            if Rec.Nivel = 0 then
                EstiloClave := 'Strong'
            else
                EstiloClave := 'Standard';
    end;

    /// <summary>
    /// Qué ejes declara el parámetro de la cabecera, para titular y mostrar sólo esas columnas.
    /// </summary>
    /// <remarks>
    /// El parámetro sale del FILTRO del part —SubPageLink por "Cód. Parámetro Base"— y no de la fila,
    /// porque hace falta antes de que haya una: la lista puede estar vacía y las columnas igual tienen
    /// que aparecer para poder cargar la primera.
    /// </remarks>
    local procedure TipoEje(Indice: Integer): Code[20]
    begin
        // SALE DEL REGISTRO, NO DEL FILTRO DEL PART, y la diferencia era un error en pantalla.
        //
        // La primera versión leía Rec.GetFilter("Cód. Parámetro Base") al abrir el part para
        // cachear los tres tipos. Nunca encontraba nada: el SubPageLink pone su filtro en el
        // GRUPO 4 y GetFilter sólo devuelve el del grupo actual. La columna quedaba titulada
        // "Eje 1" en vez de "TIPOACTIVIDAD" y el lookup cortaba con "el parámetro no declara
        // ningún atributo para el eje 1" sobre un parámetro que sí lo declaraba.
        //
        // El registro, en cambio, ya trae su "Cód. Parámetro Base" —es parte de su clave—, así que
        // la tabla puede responder sola. TipoAtributoDeclarado vive en "Parámetro Vigente" y lee la
        // cabecera; acá no hay nada que cachear ni ningún momento en el que la respuesta no esté.
        exit(Rec.TipoAtributoDeclarado(Indice));
    end;

    /// <summary>
    /// El título de la columna: la descripción del atributo, para no mostrar "Sufijo Atributo 1".
    /// </summary>
    local procedure CaptionEje(Indice: Integer): Text
    var
        TipoAtr: Record "Tipo Atributo Liq.";
        CodTipo: Code[20];
    begin
        CodTipo := TipoEje(Indice);
        if CodTipo = '' then
            exit(StrSubstNo(TxtEjeN, Indice));
        if TipoAtr.Get(CodTipo) and (TipoAtr.Descripción <> '') then
            exit(TipoAtr.Descripción);
        exit(CodTipo);
    end;

    /// <summary>
    /// Elige el VALOR del atributo y devuelve su SUFIJO, que es lo que se guarda.
    /// </summary>
    /// <remarks>
    /// Se ofrecen sólo los valores que tienen sufijo cargado: FA Administración y PA Planta no tienen
    /// ninguno, así que no pueden partir una clave y ofrecerlos sería ofrecer un valor que nunca va a
    /// resolver.
    /// </remarks>
    local procedure BuscarSufijo(Indice: Integer; var Texto: Text): Boolean
    var
        Valor: Record "Valor Atributo Liq.";
        CodTipo: Code[20];
    begin
        CodTipo := TipoEje(Indice);
        if CodTipo = '' then
            Error(ErrEjeNoDeclarado, Indice);

        Valor.SetRange("Cód. Tipo Atributo", CodTipo);
        Valor.SetFilter("Sufijo Parámetro", '<>%1', '');
        if Valor.IsEmpty() then
            Error(ErrTipoSinSufijos, CodTipo);

        if Page.RunModal(Page::"Valores de Atributo", Valor) <> Action::LookupOK then
            exit(false);
        Texto := Valor."Sufijo Parámetro";
        exit(true);
    end;

    local procedure DescribirAlcance(): Text
    begin
        if Rec."No. Empleado" <> '' then
            exit(StrSubstNo(TxtEmpleado, Rec."No. Empleado"));
        if Rec."Cód. Categoría" <> '' then
            exit(StrSubstNo(TxtCCT, Rec."Cód. Convenio", Rec."Cód. Categoría"));
        if Rec."Cód. Convenio" <> '' then
            exit(StrSubstNo(TxtConvenio, Rec."Cód. Convenio"));
        exit(TxtDefecto);
    end;

    var
        FBaseCodigo: Code[20];
        Alcance: Text;
        EstiloClave: Text;
        TxtDefecto: Label 'Valor por defecto';
        TxtEjeN: Label 'Eje %1', Comment = '%1 = número del eje';
        ErrEjeNoDeclarado: Label 'El parámetro no declara ningún atributo para el eje %1. Cargalo en la ficha del parámetro, en "Ejes de atributo".', Comment = '%1 = número del eje';
        ErrTipoSinSufijos: Label 'Ningún valor del atributo %1 tiene cargado un "Sufijo Parámetro", así que no hay nada que elegir. Cargá el sufijo en los valores que correspondan.', Comment = '%1 = tipo de atributo';
        ErrSinParametro: Label 'Abrí la ficha de un parámetro para cargarle valores.';
        ErrSinFila: Label 'Poné el cursor sobre un valor existente para crear una vigencia nueva. Si el parámetro todavía no tiene ninguno, usá "Nuevo valor...".';
        ErrYaExiste: Label 'Ya hay un valor para %1 con vigencia %2. Cambiale la fecha, o editá el que está.', Comment = '%1=clave derivada, %2=fecha de vigencia';
        TxtConvenio: Label 'Convenio %1';
        TxtCCT: Label 'Convenio %1, categoría %2';
        TxtEmpleado: Label 'Empleado %1';
}
