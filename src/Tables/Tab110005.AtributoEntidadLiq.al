namespace UAS.Payroll;

// El valor de un atributo para una entidad, con historial.
//
// Las reglas de vigencia son las mismas que en Concepto Liquidación, y no por gusto de la simetría:
// las aprendimos rompiendo cosas. Al insertar, la versión anterior se cierra el día previo SOLO si
// estaba abierta; si ya tenía fecha de fin se respeta, porque ese hueco es una decisión (un atributo
// que se da de baja en marzo y recién vuelve a hacer falta en julio). La superposición se rechaza,
// nunca se corrige sola pisando una fecha puesta a mano.
//
// "Valor Numérico" está desnormalizado a propósito: es lo único que "Fuente Datos Liquidación" lee,
// porque lee UNA tabla y no hace joins. Y al quedar copiado, una liquidación vieja se recalcula con
// el número que efectivamente usó, aunque el valor de la lista haya cambiado después.
table 110005 "Atributo Entidad Liq."
{
    Caption = 'Atributo de Entidad';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Tipo Entidad"; Enum "Tipo Entidad Estado")
        {
            Caption = 'Tipo Entidad';
            DataClassification = CustomerContent;
        }
        field(2; "Cód. Entidad"; Code[20])
        {
            Caption = 'Cód. Entidad';
            NotBlank = true;
            DataClassification = CustomerContent;
            // Sin TableRelation: apunta a empleado, buque o proyecto según "Tipo Entidad".
            // Mismo criterio que "Estado Empleado"."Cód. Entidad".
        }
        field(3; "Cód. Tipo Atributo"; Code[20])
        {
            Caption = 'Atributo';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Tipo Atributo Liq.".Código;
        }
        field(4; "Vigencia Desde"; Date)
        {
            Caption = 'Vigencia Desde';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(5; "Vigencia Hasta"; Date)
        {
            Caption = 'Vigencia Hasta';
            DataClassification = CustomerContent;
            // En blanco = abierta.
            trigger OnValidate()
            begin
                ValidarIntervalo();
                ValidarNoPisaSiguiente();
            end;
        }
        field(6; "Cód. Valor"; Code[20])
        {
            Caption = 'Valor';
            DataClassification = CustomerContent;
            // Sin TableRelation: cuando el atributo depende de otro, la lista válida no sale de un
            // where() sobre esta fila —el valor del padre está en OTRA fila de esta misma tabla, la
            // del atributo padre vigente a esta fecha—, así que la relación se resuelve abajo y se
            // verifica al validar, que además cubre escribir el código a mano sin abrir la lista.

            trigger OnLookup()
            var
                ValorAtr: Record "Valor Atributo Liq.";
                PadreLoTraeElValor: Boolean;
            begin
                PadreLoTraeElValor := PadreSegunElValor();
                // Se filtra por padre SÓLO cuando el padre lo deriva la entidad. Si lo trae el
                // valor, filtrar por el padre derivado escondería exactamente lo que se viene a elegir.
                if not PadreLoTraeElValor then
                    ResolverValorPadre();
                ValorAtr.FilterGroup(4);
                ValorAtr.SetRange("Cód. Tipo Atributo", "Cód. Tipo Atributo");
                if not PadreLoTraeElValor then
                    ValorAtr.SetRange("Cód. Valor Padre", "Cód. Valor Padre");
                ValorAtr.FilterGroup(0);
                if Page.RunModal(Page::"Valores de Atributo", ValorAtr) = Action::LookupOK then begin
                    // El padre se toma de la FILA elegida y antes de validar: el código solo no
                    // alcanza para identificarla cuando el mismo puesto existe bajo dos convenios.
                    "Cód. Valor Padre" := ValorAtr."Cód. Valor Padre";
                    Validate("Cód. Valor", ValorAtr.Código);
                end;
            end;

            trigger OnValidate()
            begin
                ExigirTipo("Tipo Dato"::Lista);
                ResolverValorPadre();
                ValidarValorExiste();
                RecalcularValorNumerico();
            end;
        }
        field(7; "Valor Decimal"; Decimal)
        {
            Caption = 'Valor Decimal';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 6;

            trigger OnValidate()
            begin
                if not ("Tipo Dato" in ["Tipo Dato"::Decimal, "Tipo Dato"::Entero]) then
                    Error(ErrColumnaEquivocada, Format("Tipo Dato"), ColumnaEsperada());
                RecalcularValorNumerico();
            end;
        }
        field(8; "Valor Texto"; Text[250])
        {
            Caption = 'Valor Texto';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                ExigirTipo("Tipo Dato"::Texto);
                RecalcularValorNumerico();
            end;
        }
        field(9; "Valor Fecha"; Date)
        {
            Caption = 'Valor Fecha';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                ExigirTipo("Tipo Dato"::Fecha);
                RecalcularValorNumerico();
            end;
        }
        field(10; "Valor Numérico"; Decimal)
        {
            Caption = 'Valor Numérico';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 6;
            Editable = false;
            // Congelado al asignar. Es el campo que apunta la Fuente de Datos.
        }
        field(11; "Descripción Valor"; Text[100])
        {
            Caption = 'Descripción';
            FieldClass = FlowField;
            CalcFormula = lookup("Valor Atributo Liq.".Descripción
                                 where("Cód. Tipo Atributo" = field("Cód. Tipo Atributo"),
                                       "Cód. Valor Padre" = field("Cód. Valor Padre"),
                                       Código = field("Cód. Valor")));
            Editable = false;
        }
        field(12; "Tipo Dato"; Enum "Tipo Dato Atributo Liq.")
        {
            Caption = 'Tipo de Dato';
            FieldClass = FlowField;
            CalcFormula = lookup("Tipo Atributo Liq."."Tipo Dato" where(Código = field("Cód. Tipo Atributo")));
            Editable = false;
        }
        field(13; "Cód. Valor Padre"; Code[20])
        {
            Caption = 'Valor Padre';
            DataClassification = CustomerContent;
            Editable = false;
            // Derivado, nunca tipeado: es el valor que la entidad tenía en el atributo PADRE el día
            // en que arranca esta vigencia. Queda congelado en la fila, igual que "Valor Numérico" y
            // por la misma razón — el par (convenio, categoría) de enero tiene que seguir siendo el
            // de enero aunque el convenio del empleado cambie en julio.
            //
            // Y es lo que desambigua: sin él, "CATEGORIA = OF01" no dice cuál de las dos OF01 es.
        }
    }

    keys
    {
        key(PK; "Tipo Entidad", "Cód. Entidad", "Cód. Tipo Atributo", "Vigencia Desde") { Clustered = true; }
        // La lee Fuente Datos: filtra por entidad y atributo, y recorre las vigencias.
        key(K2; "Cód. Tipo Atributo", "Cód. Entidad", "Vigencia Desde") { }
        // Para ordenar la ficha por fecha de inicio SIN el tipo en el medio. La clave primaria no
        // sirve para eso: tiene "Cód. Tipo Atributo" antes de la fecha, así que ordena por tipo y
        // recién adentro por fecha.
        key(K3; "Tipo Entidad", "Cód. Entidad", "Vigencia Desde") { }
    }

    trigger OnInsert()
    begin
        // Guarda propia y no solo NotBlank: la fecha es parte de la clave, así que si llega en blanco
        // por cualquier camino el choque aparece como "registro duplicado" y manda a buscar el
        // problema al lugar equivocado.
        if "Vigencia Desde" = 0D then
            Error(ErrFaltaVigencia);
        ValidarYaExiste();
        ValidarIntervalo();
        ValidarNoSuperponeConAnterior();
        // Antes de ValidarNoPisaSiguiente: al intercalar una vigencia, la fecha de fin llega en
        // blanco y es la sincronización la que la cierra contra la que sigue.
        SincronizarContiguidad();
        ValidarNoPisaSiguiente();
        // También acá y no solo al escribir el valor: la fila se puede armar por código —la
        // asignación masiva, una plantilla— o editando la fecha después del valor, y en los dos
        // casos el padre congelado tiene que corresponder a ESTA vigencia.
        ResolverValorPadre();
        ValidarValorExiste();
        RecalcularValorNumerico();
    end;

    trigger OnModify()
    begin
        if "Vigencia Hasta" <> xRec."Vigencia Hasta" then begin
            ValidarIntervalo();
            ValidarNoPisaSiguiente();
        end;
    end;

    trigger OnDelete()
    begin
        ReabrirAnteriorAlBorrar();
    end;

    /// <remarks>
    /// El choque contra la clave primaria lo detecta la plataforma igual, pero su mensaje —"ya existe
    /// el registro en la tabla..."— manda a buscar una fila que el usuario muchas veces NO está
    /// viendo: la lista abre filtrada a lo vigente hoy, y una vigencia futura o cerrada queda fuera.
    /// Este error dice qué valor tiene la fila que está en el medio, que es lo que se necesita para
    /// decidir si hay que cambiar la fecha o editar la que ya está.
    /// </remarks>
    local procedure ValidarYaExiste()
    var
        Existente: Record "Atributo Entidad Liq.";
    begin
        if not Existente.Get("Tipo Entidad", "Cód. Entidad", "Cód. Tipo Atributo", "Vigencia Desde") then
            exit;
        Error(ErrVigenciaDuplicada, "Cód. Tipo Atributo", "Vigencia Desde", Existente.ValorParaMostrar());
    end;

    // ── Encadenado con el atributo padre ──────────────────────────────────────

    /// <summary>
    /// Completa "Cód. Valor Padre" con el valor que la entidad tiene en el atributo padre a la fecha
    /// en que empieza esta vigencia. Sin padre declarado, lo deja vacío.
    /// </summary>
    /// <remarks>
    /// Se resuelve y NO se elige: si el usuario pudiera tipearlo, podría cargarle a un empleado del
    /// convenio 729/15 una categoría de 175/75, que es exactamente la incoherencia que este
    /// encadenado viene a impedir. Al derivarlo de lo que la entidad ya tiene, el par no puede
    /// quedar mal armado.
    ///
    /// La fecha que manda es la de ESTA vigencia, no la de hoy: cargar hoy la categoría que rigió en
    /// enero tiene que resolver contra el convenio de enero.
    /// </remarks>
    local procedure ResolverValorPadre()
    begin
        if PadreSegunElValor() then begin
            "Cód. Valor Padre" := PadreDelValorElegido();
            exit;
        end;
        "Cód. Valor Padre" := ValorPadreVigente();
    end;

    /// <summary>Si el tipo declara que el padre lo trae el valor elegido, y no la entidad.</summary>
    /// <remarks>
    /// Público porque la lista de valores se arma en DOS lugares —el OnLookup del campo y el
    /// codeunit que usan las páginas de atributos— y la regla tiene que ser una sola. Cuando eran
    /// dos copias, arreglar una dejaba la otra igual de rota y en la pantalla que el usuario abre.
    /// </remarks>
    procedure PadreSegunElValor(): Boolean
    var
        TipoAtr: Record "Tipo Atributo Liq.";
    begin
        if not TipoAtr.Get("Cód. Tipo Atributo") then
            exit(false);
        exit(TipoAtr."Padre Según el Valor");
    end;

    /// <summary>El padre que le corresponde al valor cargado. Vacío si no hay valor.</summary>
    /// <remarks>
    /// Si el que ya está identifica una fila real, se respeta: es el que dejó el lookup, y es lo
    /// único que sabe cuál de las dos filas quiso el usuario cuando el mismo código cuelga de dos
    /// padres. Si no, se deduce, y sólo se puede deducir cuando el código es único dentro del tipo.
    /// Con más de una fila no se elige por el usuario: se pide la lista. Adivinar acá es armar un
    /// par que después liquida mal, y sin que nada avise.
    /// </remarks>
    local procedure PadreDelValorElegido(): Code[20]
    var
        ValorAtr: Record "Valor Atributo Liq.";
        Cuantos: Integer;
    begin
        if "Cód. Valor" = '' then
            exit('');
        if ValorAtr.Get("Cód. Tipo Atributo", "Cód. Valor Padre", "Cód. Valor") then
            exit("Cód. Valor Padre");

        ValorAtr.Reset();
        ValorAtr.SetRange("Cód. Tipo Atributo", "Cód. Tipo Atributo");
        ValorAtr.SetRange(Código, "Cód. Valor");
        Cuantos := ValorAtr.Count();
        if Cuantos = 1 then begin
            ValorAtr.FindFirst();
            exit(ValorAtr."Cód. Valor Padre");
        end;
        if Cuantos > 1 then
            Error(ErrValorAmbiguo, "Cód. Valor", "Cód. Tipo Atributo", Cuantos);
        // Cero filas: se devuelve lo que había, para que falle ValidarValorExiste, que tiene el
        // mensaje que explica el problema real.
        exit("Cód. Valor Padre");
    end;

    /// <summary>
    /// El valor del atributo padre vigente al inicio de esta vigencia. Vacío si no depende de nadie.
    /// </summary>
    /// <remarks>
    /// Público porque el lookup del valor lo necesita para filtrar la lista ANTES de que la fila
    /// exista: al cargar una categoría hay que ofrecer solo las del convenio que el empleado tiene
    /// ese día, y en una fila nueva "Cód. Valor Padre" todavía está vacío.
    /// </remarks>
    procedure ValorPadreVigente(): Code[20]
    var
        TipoAtr: Record "Tipo Atributo Liq.";
        Padre: Record "Atributo Entidad Liq.";
    begin
        if not TipoAtr.Get("Cód. Tipo Atributo") then
            exit('');
        if TipoAtr."Cód. Tipo Atributo Padre" = '' then
            exit('');
        if "Vigencia Desde" = 0D then
            Error(ErrFaltaVigenciaParaPadre, TipoAtr."Cód. Tipo Atributo Padre");

        Padre.SetRange("Tipo Entidad", "Tipo Entidad");
        Padre.SetRange("Cód. Entidad", "Cód. Entidad");
        Padre.SetRange("Cód. Tipo Atributo", TipoAtr."Cód. Tipo Atributo Padre");
        Padre.SetFilter("Vigencia Desde", '<=%1', "Vigencia Desde");
        // El historial es contiguo, así que la última que empezó antes es la vigente. El filtro de
        // fin acepta la abierta (0D) además de la que todavía no cerró.
        Padre.SetFilter("Vigencia Hasta", '%1|>=%2', 0D, "Vigencia Desde");
        if not Padre.FindLast() then
            Error(ErrSinPadreVigente, TipoAtr."Cód. Tipo Atributo Padre", "Cód. Entidad", "Vigencia Desde");

        exit(Padre."Cód. Valor");
    end;

    local procedure ValidarValorExiste()
    var
        ValorAtr: Record "Valor Atributo Liq.";
    begin
        if "Cód. Valor" = '' then
            exit;
        if ValorAtr.Get("Cód. Tipo Atributo", "Cód. Valor Padre", "Cód. Valor") then
            exit;
        if "Cód. Valor Padre" = '' then
            Error(ErrValorInexistente, "Cód. Valor", "Cód. Tipo Atributo");
        Error(ErrValorNoCuelga, "Cód. Valor", "Cód. Tipo Atributo", "Cód. Valor Padre");
    end;

    // ── Valor según el tipo ───────────────────────────────────────────────────

    // Se recalcula al asignar y queda congelado: cambiar después el número del valor de la lista NO
    // reescribe lo ya asignado, para que un recálculo de un período viejo dé lo mismo que dio.
    procedure RecalcularValorNumerico()
    var
        ValorAtr: Record "Valor Atributo Liq.";
    begin
        CalcFields("Tipo Dato");
        case "Tipo Dato" of
            "Tipo Dato"::Decimal, "Tipo Dato"::Entero:
                "Valor Numérico" := "Valor Decimal";
            "Tipo Dato"::Lista:
                if ValorAtr.Get("Cód. Tipo Atributo", "Cód. Valor Padre", "Cód. Valor") then
                    "Valor Numérico" := ValorAtr."Valor Numérico"
                else
                    "Valor Numérico" := 0;
            "Tipo Dato"::Texto:
                // Bandera de presencia. Para preguntar por un valor puntual desde una fórmula, la vía
                // es una Fuente de Datos con COUNT y el texto en el filtro: compara en SQL, que es
                // donde sí existe la comparación de texto.
                if "Valor Texto" <> '' then
                    "Valor Numérico" := 1
                else
                    "Valor Numérico" := 0;
            "Tipo Dato"::Fecha:
                // A propósito 0: los días dependen de la fecha de referencia de cada liquidación, así
                // que no se pueden congelar acá. Los calcula la Fuente de Datos declarada como Fecha.
                "Valor Numérico" := 0;
        end;
    end;

    /// <summary>
    /// El valor en una sola columna, sea cual sea el tipo. Para listas y factboxes, donde no entran
    /// las cuatro columnas de valor.
    /// </summary>
    procedure ValorParaMostrar(): Text
    var
        ValorAtr: Record "Valor Atributo Liq.";
    begin
        CalcFields("Tipo Dato");
        case "Tipo Dato" of
            "Tipo Dato"::Decimal, "Tipo Dato"::Entero:
                exit(Format("Valor Decimal"));
            "Tipo Dato"::Lista:
                begin
                    // La descripción es más útil que el código, pero el código es lo que identifica:
                    // si el valor ya no existe en la lista se muestra igual, para que se note.
                    if ValorAtr.Get("Cód. Tipo Atributo", "Cód. Valor Padre", "Cód. Valor") then
                        if ValorAtr.Descripción <> '' then
                            exit(ValorAtr.Descripción);
                    exit("Cód. Valor");
                end;
            "Tipo Dato"::Texto:
                exit("Valor Texto");
            "Tipo Dato"::Fecha:
                if "Valor Fecha" <> 0D then
                    exit(Format("Valor Fecha"));
        end;
        exit('');
    end;

    local procedure ExigirTipo(Esperado: Enum "Tipo Dato Atributo Liq.")
    begin
        CalcFields("Tipo Dato");
        if "Tipo Dato" <> Esperado then
            Error(ErrColumnaEquivocada, Format("Tipo Dato"), ColumnaEsperada());
    end;

    local procedure ColumnaEsperada(): Text
    begin
        case "Tipo Dato" of
            "Tipo Dato"::Decimal, "Tipo Dato"::Entero:
                exit(FieldCaption("Valor Decimal"));
            "Tipo Dato"::Lista:
                exit(FieldCaption("Cód. Valor"));
            "Tipo Dato"::Texto:
                exit(FieldCaption("Valor Texto"));
            "Tipo Dato"::Fecha:
                exit(FieldCaption("Valor Fecha"));
        end;
        exit('');
    end;

    // ── Vigencia ──────────────────────────────────────────────────────────────

    procedure VigenteA(FechaRef: Date): Boolean
    begin
        if "Vigencia Desde" > FechaRef then
            exit(false);
        exit(("Vigencia Hasta" = 0D) or ("Vigencia Hasta" >= FechaRef));
    end;

    local procedure ValidarIntervalo()
    begin
        if ("Vigencia Hasta" <> 0D) and ("Vigencia Hasta" < "Vigencia Desde") then
            Error(ErrIntervaloInvertido, "Vigencia Hasta", "Vigencia Desde");
    end;

    local procedure BuscarAnterior(var Anterior: Record "Atributo Entidad Liq."): Boolean
    begin
        FiltrarMismaSerie(Anterior);
        Anterior.SetFilter("Vigencia Desde", '<%1', "Vigencia Desde");
        exit(Anterior.FindLast());
    end;

    local procedure BuscarSiguiente(var Siguiente: Record "Atributo Entidad Liq."): Boolean
    begin
        FiltrarMismaSerie(Siguiente);
        Siguiente.SetFilter("Vigencia Desde", '>%1', "Vigencia Desde");
        exit(Siguiente.FindFirst());
    end;

    local procedure FiltrarMismaSerie(var Otro: Record "Atributo Entidad Liq.")
    begin
        Otro.SetRange("Tipo Entidad", "Tipo Entidad");
        Otro.SetRange("Cód. Entidad", "Cód. Entidad");
        Otro.SetRange("Cód. Tipo Atributo", "Cód. Tipo Atributo");
    end;

    local procedure ValidarNoSuperponeConAnterior()
    var
        Anterior: Record "Atributo Entidad Liq.";
    begin
        if not BuscarAnterior(Anterior) then
            exit;
        if Anterior."Vigencia Hasta" = 0D then
            exit;
        if Anterior."Vigencia Hasta" >= "Vigencia Desde" then
            Error(ErrSuperponeAnterior, Anterior."Vigencia Desde", Anterior."Vigencia Hasta", "Vigencia Desde");
    end;

    local procedure ValidarNoPisaSiguiente()
    var
        Siguiente: Record "Atributo Entidad Liq.";
    begin
        if not BuscarSiguiente(Siguiente) then
            exit;
        if "Vigencia Hasta" = 0D then
            Error(ErrAbiertaConSiguiente, Siguiente."Vigencia Desde");
        if "Vigencia Hasta" >= Siguiente."Vigencia Desde" then
            Error(ErrSuperponeSiguiente, "Vigencia Hasta", Siguiente."Vigencia Desde");
    end;

    local procedure SincronizarContiguidad()
    var
        Anterior: Record "Atributo Entidad Liq.";
        Siguiente: Record "Atributo Entidad Liq.";
    begin
        if BuscarAnterior(Anterior) then
            if Anterior."Vigencia Hasta" = 0D then begin
                Anterior."Vigencia Hasta" := "Vigencia Desde" - 1;
                // Sin disparar triggers: es una fecha derivada, no una edición del usuario.
                Anterior.Modify();
            end;

        if "Vigencia Hasta" = 0D then
            if BuscarSiguiente(Siguiente) then
                "Vigencia Hasta" := Siguiente."Vigencia Desde" - 1;
    end;

    local procedure ReabrirAnteriorAlBorrar()
    var
        Anterior: Record "Atributo Entidad Liq.";
        Siguiente: Record "Atributo Entidad Liq.";
        NuevoFin: Date;
    begin
        if not BuscarAnterior(Anterior) then
            exit;
        // Solo se reabre la que ESTA fila había cerrado; una fecha puesta a mano no se toca.
        if Anterior."Vigencia Hasta" <> "Vigencia Desde" - 1 then
            exit;
        if BuscarSiguiente(Siguiente) then
            NuevoFin := Siguiente."Vigencia Desde" - 1
        else
            NuevoFin := 0D;
        Anterior."Vigencia Hasta" := NuevoFin;
        Anterior.Modify();
    end;

    var
        ErrIntervaloInvertido: Label 'La fecha de fin de vigencia (%1) no puede ser anterior al inicio (%2).';
        ErrSuperponeAnterior: Label 'La vigencia que arranca el %1 llega hasta el %2 y se superpone con la nueva del %3. Cerrá antes la anterior.';
        ErrSuperponeSiguiente: Label 'La fecha de fin %1 se superpone con la vigencia que arranca el %2.';
        ErrAbiertaConSiguiente: Label 'Esta vigencia no puede quedar abierta: existe una posterior que arranca el %1.';
        ErrColumnaEquivocada: Label 'El atributo es de tipo %1: el valor se carga en "%2".';
        ErrFaltaVigencia: Label 'Falta la fecha de "Vigencia Desde". Es parte de la clave del registro, así que sin ella no se puede guardar.';
        ErrVigenciaDuplicada: Label 'El atributo %1 ya tiene una vigencia que empieza el %2, con el valor %3. Cambiá la fecha, o editá esa fila — puede no estar a la vista si la lista está mostrando solo lo vigente hoy.', Comment = '%1=tipo de atributo, %2=fecha, %3=valor de la fila existente';
        ErrFaltaVigenciaParaPadre: Label 'Poné primero la fecha de "Vigencia Desde": el valor válido de %1 depende de qué tenía la entidad ese día.', Comment = '%1=código del tipo de atributo padre';
        ErrSinPadreVigente: Label 'La entidad %2 no tiene ningún valor de %1 vigente al %3, y este atributo depende de %1. Cargá primero %1.', Comment = '%1=tipo de atributo padre, %2=código de entidad, %3=fecha';
        ErrValorInexistente: Label 'No existe el valor %1 en el atributo %2.', Comment = '%1=código de valor, %2=tipo de atributo';
        ErrValorNoCuelga: Label 'El valor %1 no existe en %2 colgando de %3. Elegí uno de los que corresponden a %3.', Comment = '%1=código de valor, %2=tipo de atributo, %3=código de valor padre';
        ErrValorAmbiguo: Label 'El valor %1 existe %3 veces en %2, colgando de padres distintos. Elegilo desde la lista para que quede claro cuál es.', Comment = '%1=código de valor, %2=tipo de atributo, %3=cantidad de coincidencias';
}
