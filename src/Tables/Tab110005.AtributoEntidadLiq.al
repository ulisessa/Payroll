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
            TableRelation = "Valor Atributo Liq.".Código where("Cód. Tipo Atributo" = field("Cód. Tipo Atributo"));

            trigger OnValidate()
            begin
                ExigirTipo("Tipo Dato"::Lista);
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
    }

    keys
    {
        key(PK; "Tipo Entidad", "Cód. Entidad", "Cód. Tipo Atributo", "Vigencia Desde") { Clustered = true; }
        // La lee Fuente Datos: filtra por entidad y atributo, y recorre las vigencias.
        key(K2; "Cód. Tipo Atributo", "Cód. Entidad", "Vigencia Desde") { }
    }

    trigger OnInsert()
    begin
        // Guarda propia y no solo NotBlank: la fecha es parte de la clave, así que si llega en blanco
        // por cualquier camino el choque aparece como "registro duplicado" y manda a buscar el
        // problema al lugar equivocado.
        if "Vigencia Desde" = 0D then
            Error(ErrFaltaVigencia);
        ValidarIntervalo();
        ValidarNoSuperponeConAnterior();
        // Antes de ValidarNoPisaSiguiente: al intercalar una vigencia, la fecha de fin llega en
        // blanco y es la sincronización la que la cierra contra la que sigue.
        SincronizarContiguidad();
        ValidarNoPisaSiguiente();
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
                if ValorAtr.Get("Cód. Tipo Atributo", "Cód. Valor") then
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
                    if ValorAtr.Get("Cód. Tipo Atributo", "Cód. Valor") then
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
}
