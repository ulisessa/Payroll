namespace UAS.Payroll;

// El equivalente a un Valor de Dimensión: la lista cerrada contra la que se valida un atributo de
// tipo Lista.
//
// "Valor Numérico" es la pieza que hace que todo esto llegue a una fórmula. La fórmula no puede ver
// el código "PATAGONIA"; ve el 1,20 que este valor le asigna. Y como el código está validado por
// relación de tabla, renombrar o retipear un valor no rompe fórmulas en silencio, que es lo que sí
// pasaría comparando literales de texto dentro de la fórmula.
table 110004 "Valor Atributo Liq."
{
    Caption = 'Valor de Atributo';
    DataClassification = CustomerContent;
    // La tabla no declaraba página de lookup, así que un Page.RunModal(0, ...) sobre ella no tenía
    // nada que resolver. Declarada acá, cualquier búsqueda futura abre la pantalla correcta sola.
    LookupPageId = "Valores de Atributo";
    DrillDownPageId = "Valores de Atributo";

    fields
    {
        field(1; "Cód. Tipo Atributo"; Code[20])
        {
            Caption = 'Cód. Tipo Atributo';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Tipo Atributo Liq.".Código;
        }
        field(2; Código; Code[20])
        {
            Caption = 'Código';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(3; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(4; "Valor Numérico"; Decimal)
        {
            Caption = 'Valor Numérico';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 6;
            // Lo que ve la fórmula cuando la entidad tiene este valor asignado.
        }
        field(5; "Cód. Valor Padre"; Code[20])
        {
            Caption = 'Valor Padre';
            DataClassification = CustomerContent;
            // El valor del atributo padre del que cuelga éste — la categoría OF01 colgando del
            // convenio 175/75. Vacío cuando el tipo no declara padre, que es la lista plana de
            // siempre.
            //
            // Sin TableRelation: apunta a un valor de OTRO tipo de atributo, y cuál es se sabe recién
            // en ejecución (Tipo Atributo."Cód. Tipo Atributo Padre"). La relación se valida abajo y
            // se elige con el OnLookup.

            trigger OnLookup()
            var
                ValorPadre: Record "Valor Atributo Liq.";
                CodPadre: Code[20];
            begin
                CodPadre := TipoPadre();
                if CodPadre = '' then
                    Error(ErrTipoSinPadre, "Cód. Tipo Atributo");
                ValorPadre.FilterGroup(4);
                ValorPadre.SetRange("Cód. Tipo Atributo", CodPadre);
                ValorPadre.FilterGroup(0);
                if Page.RunModal(Page::"Valores de Atributo", ValorPadre) = Action::LookupOK then
                    Validate("Cód. Valor Padre", ValorPadre.Código);
            end;

            trigger OnValidate()
            begin
                ValidarPadre();
            end;
        }
    }

    keys
    {
        // El padre entra en la clave, y no es un detalle de implementación: es lo que permite que el
        // mismo código exista bajo dos padres distintos. OF01 es Capitán en 175/75 y también en
        // 768/19, y son dos categorías distintas que comparten código. Con la clave vieja —tipo más
        // código— la segunda no entraba, y namespacear el código (175-OF01) habría ensuciado
        // justamente el dato que después se lee en pantalla y se compara contra el CCT.
        key(PK; "Cód. Tipo Atributo", "Cód. Valor Padre", Código) { Clustered = true; }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Código, Descripción, "Valor Numérico") { }
    }

    trigger OnInsert()
    begin
        BloquearSiEsEspejo();
        ValidarPadre();
    end;

    trigger OnDelete()
    begin
        BloquearSiEsEspejo();
    end;

    trigger OnRename()
    begin
        BloquearSiEsEspejo();
    end;

    /// <summary>
    /// Habilita UNA escritura sobre esta instancia del registro. La usa el espejo.
    /// </summary>
    /// <remarks>
    /// La bandera vive en la variable de registro, no en la fila: solo el código que la prende puede
    /// escribir, y se apaga sola después de cada escritura. Un derivado que se puede editar a mano
    /// deja de ser un derivado en la primera corrección "rápida" que alguien haga sobre la lista.
    /// </remarks>
    procedure PermitirEscrituraEspejo()
    begin
        FEscrituraEspejo := true;
    end;

    local procedure BloquearSiEsEspejo()
    var
        TipoAtr: Record "Tipo Atributo Liq.";
    begin
        if FEscrituraEspejo then begin
            FEscrituraEspejo := false;
            exit;
        end;
        if not TipoAtr.Get("Cód. Tipo Atributo") then
            exit;
        if TipoAtr."Espejo De" <> TipoAtr."Espejo De"::Ninguno then
            Error(ErrEsEspejo, "Cód. Tipo Atributo", Format(TipoAtr."Espejo De"));
    end;

    /// <summary>El tipo de atributo del que depende éste, o vacío si es una lista plana.</summary>
    procedure TipoPadre(): Code[20]
    var
        TipoAtr: Record "Tipo Atributo Liq.";
    begin
        if not TipoAtr.Get("Cód. Tipo Atributo") then
            exit('');
        exit(TipoAtr."Cód. Tipo Atributo Padre");
    end;

    /// <remarks>
    /// Se valida al insertar y no solo al escribir el campo: un valor sin padre en un tipo que sí lo
    /// declara es inalcanzable —al asignarlo, el filtro por padre nunca lo va a ofrecer— y quedaría
    /// como una fila muerta en la lista que nadie entiende por qué no aparece.
    /// </remarks>
    local procedure ValidarPadre()
    var
        ValorPadre: Record "Valor Atributo Liq.";
        CodPadre: Code[20];
    begin
        CodPadre := TipoPadre();
        if CodPadre = '' then begin
            if "Cód. Valor Padre" <> '' then
                Error(ErrTipoSinPadre, "Cód. Tipo Atributo");
            exit;
        end;

        if "Cód. Valor Padre" = '' then
            Error(ErrFaltaPadre, "Cód. Tipo Atributo", CodPadre);
        ValorPadre.SetRange("Cód. Tipo Atributo", CodPadre);
        ValorPadre.SetRange(Código, "Cód. Valor Padre");
        if ValorPadre.IsEmpty() then
            Error(ErrPadreInexistente, "Cód. Valor Padre", CodPadre);
    end;

    // El valor numérico viaja copiado a cada asignación (ver "Atributo Entidad Liq."), así que
    // cambiarlo acá NO reescribe lo ya asignado — y eso es deliberado: una liquidación vieja tiene
    // que poder recalcularse con el número que se usó, no con el de hoy. Lo que sí hace falta es que
    // quien lo cambia sepa que solo rige para las asignaciones nuevas.
    trigger OnModify()
    var
        Atributo: Record "Atributo Entidad Liq.";
    begin
        BloquearSiEsEspejo();
        if "Valor Numérico" = xRec."Valor Numérico" then
            exit;
        Atributo.SetRange("Cód. Tipo Atributo", "Cód. Tipo Atributo");
        Atributo.SetRange("Cód. Valor Padre", "Cód. Valor Padre");
        Atributo.SetRange("Cód. Valor", Código);
        if not Atributo.IsEmpty() then
            Message(MsgValorEnUso, Código, Atributo.Count());
    end;

    var
        FEscrituraEspejo: Boolean;
        ErrEsEspejo: Label 'Los valores de %1 son espejo de %2 y no se editan acá: cambialos en esa tabla y se copian solos.', Comment = '%1=código del tipo de atributo, %2=nombre del maestro';
        ErrTipoSinPadre: Label 'El atributo %1 no depende de ningún otro, así que sus valores no llevan valor padre. Si querés encadenarlo, completá "Depende de" en la ficha del tipo de atributo.', Comment = '%1=código del tipo de atributo';
        ErrFaltaPadre: Label 'El atributo %1 depende de %2: cada valor tiene que indicar de qué valor de %2 cuelga.', Comment = '%1=tipo de atributo, %2=tipo de atributo padre';
        ErrPadreInexistente: Label 'No existe el valor %1 en el atributo %2.', Comment = '%1=código de valor padre, %2=tipo de atributo padre';
        MsgValorEnUso: Label 'El valor %1 ya está asignado en %2 registro(s), que conservan el número anterior. El nuevo rige solo para las asignaciones que se carguen desde ahora; para cambiar las vigentes, cargá una vigencia nueva en cada entidad.';
}
