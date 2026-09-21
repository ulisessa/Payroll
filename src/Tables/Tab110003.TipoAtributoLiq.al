namespace UAS.Payroll;

// El equivalente a una Dimensión de BC: define QUÉ se puede cargar, no el valor.
//
// Existe para que un dato que importa al cálculo —zona desfavorable, obra social, régimen horario—
// se pueda agregar como configuración y no como campo nuevo en una tabla. El motor no necesita
// enterarse: con un "Nombre Variable" cargado acá, el contexto de cálculo lo inyecta solo y la
// fórmula lo escribe como a cualquier otra variable.
table 110003 "Tipo Atributo Liq."
{
    Caption = 'Tipo de Atributo';
    DataClassification = CustomerContent;
    LookupPageId = "Tipos de Atributo";
    DrillDownPageId = "Tipos de Atributo";

    fields
    {
        field(1; Código; Code[20])
        {
            Caption = 'Código';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(2; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(3; "Tipo Dato"; Enum "Tipo Dato Atributo Liq.")
        {
            Caption = 'Tipo de Dato';
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                Atributo: Record "Atributo Entidad Liq.";
            begin
                // Cambiar el tipo dejaría las asignaciones existentes con el valor en una columna
                // que ya no corresponde, y su proyección numérica congelada con la regla vieja.
                if "Tipo Dato" = xRec."Tipo Dato" then
                    exit;
                Atributo.SetRange("Cód. Tipo Atributo", Código);
                if not Atributo.IsEmpty() then
                    Error(ErrTipoConDatos, Código);
            end;
        }
        field(4; "Tipo Entidad"; Enum "Tipo Entidad Estado")
        {
            Caption = 'Se carga en';
            DataClassification = CustomerContent;
            // A qué maestro se le cuelga: empleado, buque o proyecto (marea).
        }
        field(5; Obligatorio; Boolean)
        {
            Caption = 'Obligatorio';
            DataClassification = CustomerContent;
            // Los obligatorios son los que la plantilla materializa al clasificar una entidad
            // (ver "Aplicar plantilla"). No bloquean la liquidación: un atributo faltante debe
            // avisar, no impedir que se pague.
        }
        field(7; "Cód. Clase"; Code[20])
        {
            Caption = 'Clase de Entidad';
            DataClassification = CustomerContent;
            TableRelation = "Clase Entidad Liq.".Código;
            // Solo para atributos de entidad: acota este tipo a una clase, de modo que un buque no
            // ofrezca los atributos de una planta ni al revés. En blanco = aplica a todas.
            //
            // Los atributos de empleado o de proyecto no usan clase: su "tipo de entidad" ya los
            // acota lo suficiente.
        }
        field(6; "Nombre Variable"; Code[30])
        {
            Caption = 'Nombre Variable';
            DataClassification = CustomerContent;
            // Con este nombre cargado, el atributo ES una variable: el contexto de cálculo le pone
            // un valor en cada liquidación —el de la entidad que corresponda, vigente a la fecha de
            // referencia— y la fórmula lo escribe como a cualquier otra. No hace falta declarar una
            // Fuente de Datos para leerlo.
            //
            // En blanco = el atributo no se inyecta. Sirve para los que son puramente
            // administrativos, y para los que ya se leen con una Fuente de Datos hecha a mano.
            //
            // En MAYÚSCULAS a propósito: el evaluador pasa la fórmula entera por ToUpper antes de
            // resolver, así que una variable con minúsculas nunca se encuentra.
            trigger OnValidate()
            begin
                "Nombre Variable" := UpperCase("Nombre Variable");
                ValidarNombreLibre();
            end;
        }
        field(8; "Cód. Tipo Atributo Padre"; Code[20])
        {
            Caption = 'Depende de';
            DataClassification = CustomerContent;
            TableRelation = "Tipo Atributo Liq.".Código where("Tipo Dato" = const(Lista));
            // Encadena dos atributos de lista: los valores de éste cuelgan de un valor del padre, y
            // al asignarlo solo se ofrecen los del padre que la entidad tenga vigente ese día.
            // CATEGORIA depende de CONVENIO, y la asignación queda coherente por construcción.
            //
            // Las FECHAS no viven acá. Esto es el catálogo: dice qué valores existen y de quién
            // cuelgan. Cuándo los tuvo cada entidad lo dice "Atributo Entidad Liq.", que ya es
            // effective-dated — y ahí es donde hacía falta el historial.
            //
            // Vacío = lista plana, como era hasta ahora.

            trigger OnValidate()
            begin
                ValidarPadre();
            end;
        }
        field(11; "Mostrar en Recibo"; Boolean)
        {
            Caption = 'Mostrar en Recibo';
            DataClassification = CustomerContent;
            // Mismo interruptor que ya tienen Fuente de Datos y Variable de Sistema, y el mismo
            // camino: el recibo imprime un bloque con las variables marcadas, y de un atributo de
            // lista sale su DESCRIPCIÓN —"Sindicato Obreros Marítimos Unidos"— porque el contexto
            // guarda el texto además del número.
            //
            // Requiere "Nombre Variable": sin nombre el atributo no entra al contexto de cálculo, y
            // lo que no está en el contexto no llega al resumen ni al recibo.
        }
        field(12; "Etiqueta Recibo"; Text[50])
        {
            Caption = 'Etiqueta Recibo';
            DataClassification = CustomerContent;
            // Cómo se llama en el recibo, cuando la descripción interna no sirve para el empleado.
            // Vacía, se imprime la Descripción.
        }
        field(10; "Padre Según el Valor"; Boolean)
        {
            Caption = 'Padre según el valor';
            DataClassification = CustomerContent;
            // DE DÓNDE SALE EL PADRE cuando este atributo depende de otro. Son dos reglas distintas
            // y las dos existen en el negocio:
            //
            //  · Apagado (lo normal): el padre lo DERIVA LA ENTIDAD, del valor que tiene vigente en
            //    el atributo padre ese día. Es lo que hace coherente a CATEGORIA — un empleado
            //    encuadrado en 729/15 no puede tener una categoría de 175/75 — y al derivarlo el
            //    par no se puede armar mal.
            //
            //  · Encendido: el padre lo trae EL VALOR ELEGIDO. Es para PUESTO, donde el encadenado
            //    anterior no sólo no ayuda: impide justo el caso que el puesto viene a resolver. El
            //    convenio del puesto sale de la actividad con la que se navega, no del encuadre de
            //    la persona, y cuando difieren es cuando el segundo eje sirve. Un oficial de 768/19
            //    que embarca de Patrón de Pesca tiene el puesto FE01, que cuelga de ESP; derivando
            //    el padre de su CONVENIO ese valor no existe y no hay forma de cargarlo.
            //
            // Sin "Depende de" no significa nada: no hay padre que resolver de ninguna de las dos formas.

            trigger OnValidate()
            begin
                if "Padre Según el Valor" and ("Cód. Tipo Atributo Padre" = '') then
                    Error(ErrPadreSegunValorSinPadre);
            end;
        }
        field(9; "Espejo De"; Enum "Espejo Atributo Liq.")
        {
            Caption = 'Espejo de';
            DataClassification = CustomerContent;
            // Los valores permitidos dejan de cargarse a mano y se copian de una tabla maestra, que
            // sigue siendo la única fuente de verdad. Es lo que evita mantener dos listas que dicen
            // lo mismo: los códigos del atributo TIENEN que coincidir con los del maestro, porque el
            // motor busca "Categoría CCT".Get(convenio, categoría) y arma los parámetros con sufijo
            // con esos códigos. Si no coinciden no hay error, hay importe cero.

            trigger OnValidate()
            var
                Espejo: Codeunit "Espejo Atributos Liq.";
            begin
                if "Espejo De" = xRec."Espejo De" then
                    exit;
                ValidarEspejo();
                if "Espejo De" = "Espejo De"::Ninguno then
                    exit;
                // Se copia en el momento: si no, el atributo queda declarado como espejo y con la
                // lista vacía hasta que alguien se acuerde de resincronizar.
                Modify();
                Espejo.Resincronizar(Rec);
            end;
        }
    }

    keys
    {
        key(PK; Código) { Clustered = true; }
        key(K2; "Tipo Entidad", Código) { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Código, Descripción, "Tipo Dato") { }
        fieldgroup(Brick; Código, Descripción) { }
    }

    trigger OnDelete()
    var
        Valor: Record "Valor Atributo Liq.";
        Atributo: Record "Atributo Entidad Liq.";
    begin
        Atributo.SetRange("Cód. Tipo Atributo", Código);
        if not Atributo.IsEmpty() then
            Error(ErrTipoConDatos, Código);
        Valor.SetRange("Cód. Tipo Atributo", Código);
        Valor.DeleteAll();
    end;

    /// <summary>
    /// Corta si el nombre de variable ya lo usa otra cosa que escribe en el contexto de cálculo.
    /// </summary>
    /// <remarks>
    /// El contexto es un diccionario por nombre: dos definiciones para el mismo nombre no dan error,
    /// una gana y la otra desaparece. Cuál gana depende del orden en que se cargan —hoy el atributo
    /// no pisa a nadie— y eso es exactamente lo que nadie debería tener que saber para entender una
    /// fórmula. Se rechaza acá, que es donde el choque se puede explicar.
    ///
    /// Los parámetros se revisan también por su sufijo _ESFCY, que ocupan igual.
    /// </remarks>
    local procedure ValidarNombreLibre()
    var
        Param: Record "Parámetro";
        VarSis: Record "Variable Sistema Liq.";
        Fuente: Record "Fuente Datos Liquidación";
        OtroTipo: Record "Tipo Atributo Liq.";
    begin
        if "Nombre Variable" = '' then
            exit;

        Param.SetFilter("Nombre Variable", '%1|%2', "Nombre Variable", DesufijarESFCY("Nombre Variable"));
        if Param.FindFirst() then
            Error(ErrNombreTomado, "Nombre Variable", Param.TableCaption(), Param.Código);

        VarSis.SetRange("Nombre Variable", "Nombre Variable");
        if VarSis.FindFirst() then
            Error(ErrNombreTomado, "Nombre Variable", VarSis.TableCaption(), VarSis."Nombre Variable");

        Fuente.SetRange("Nombre Variable", "Nombre Variable");
        if Fuente.FindFirst() then
            Error(ErrNombreTomado, "Nombre Variable", Fuente.TableCaption(), Fuente."Nombre Variable");

        OtroTipo.SetFilter(Código, '<>%1', Código);
        OtroTipo.SetRange("Nombre Variable", "Nombre Variable");
        if OtroTipo.FindFirst() then
            Error(ErrNombreTomado, "Nombre Variable", OtroTipo.TableCaption(), OtroTipo.Código);
    end;

    // VAR_ESFCY es el nombre que el contexto deriva del parámetro VAR, así que un atributo llamado
    // VAR_ESFCY chocaría con un parámetro que no se llama así. Se busca el nombre base también.
    local procedure DesufijarESFCY(Nombre: Code[30]): Code[30]
    var
        Texto: Text;
    begin
        Texto := Nombre;
        if not Texto.EndsWith(SufijoMonedaTok) then
            exit(Nombre);
        exit(CopyStr(Nombre, 1, StrLen(Nombre) - StrLen(SufijoMonedaTok)));
    end;

    /// <remarks>
    /// Tres cosas que no pueden pasar, y las tres dan una lista imposible de usar en vez de un error
    /// claro si se dejan pasar: encadenar algo que no es una lista (no hay valores de los que
    /// colgar), armar un ciclo (el lookup del hijo pediría el padre y el del padre pediría el hijo),
    /// y cambiarle el padre a un atributo que ya tiene valores cargados, que quedarían colgando de
    /// un valor que ya no es de nadie.
    /// </remarks>
    local procedure ValidarPadre()
    var
        Padre: Record "Tipo Atributo Liq.";
        Valor: Record "Valor Atributo Liq.";
        Actual: Code[20];
        Saltos: Integer;
    begin
        if "Cód. Tipo Atributo Padre" = '' then
            exit;
        if "Cód. Tipo Atributo Padre" = Código then
            Error(ErrPadreSiMismo);
        if not UsaLista() then
            Error(ErrPadreSoloLista, Código);

        Actual := "Cód. Tipo Atributo Padre";
        while (Actual <> '') and (Saltos < 50) do begin
            if not Padre.Get(Actual) then
                Error(ErrPadreInexistente, Actual);
            if not Padre.UsaLista() then
                Error(ErrPadreSoloLista, Padre.Código);
            if Padre."Cód. Tipo Atributo Padre" = Código then
                Error(ErrPadreCiclo, Código, Padre.Código);
            Actual := Padre."Cód. Tipo Atributo Padre";
            Saltos += 1;
        end;

        Valor.SetRange("Cód. Tipo Atributo", Código);
        if not Valor.IsEmpty() then
            Error(ErrPadreConValores, Código);
    end;

    /// <remarks>
    /// La forma del espejo tiene que calzar con la del maestro, y eso incluye el encadenado: las
    /// categorías cuelgan de su convenio en "Categoría CCT" igual que los valores cuelgan de su
    /// padre acá. Un espejo de Categoría CCT sin un padre que sea espejo de Convenio Colectivo
    /// copiaría códigos de convenio que del lado del atributo no existen, y ningún valor sería
    /// alcanzable.
    /// </remarks>
    local procedure ValidarEspejo()
    var
        Padre: Record "Tipo Atributo Liq.";
        Valor: Record "Valor Atributo Liq.";
    begin
        if "Espejo De" = "Espejo De"::Ninguno then
            exit;
        if not UsaLista() then
            Error(ErrEspejoSoloLista);

        // Prender el espejo sobre una lista ya cargada mezclaría valores derivados con valores
        // hechos a mano, y después no hay forma de saber cuál es cuál. Misma regla que el padre.
        Valor.SetRange("Cód. Tipo Atributo", Código);
        if not Valor.IsEmpty() then
            Error(ErrEspejoConValores, Código);

        case "Espejo De" of
            "Espejo De"::"Convenio Colectivo":
                if "Cód. Tipo Atributo Padre" <> '' then
                    Error(ErrEspejoConvenioConPadre);
            "Espejo De"::"Categoría CCT":
                begin
                    if "Cód. Tipo Atributo Padre" = '' then
                        Error(ErrEspejoCategoriaSinPadre);
                    if not Padre.Get("Cód. Tipo Atributo Padre") then
                        Error(ErrPadreInexistente, "Cód. Tipo Atributo Padre");
                    if Padre."Espejo De" <> Padre."Espejo De"::"Convenio Colectivo" then
                        Error(ErrEspejoCategoriaPadreAjeno, Padre.Código);
                end;
        end;
    end;

    /// <summary>
    /// True si el valor de este atributo se elige de una lista cerrada.
    /// </summary>
    procedure UsaLista(): Boolean
    begin
        exit("Tipo Dato" = "Tipo Dato"::Lista);
    end;

    var
        ErrTipoConDatos: Label 'El tipo de atributo %1 ya tiene valores cargados en entidades. Borrá esas asignaciones antes de cambiarlo o eliminarlo.';
        SufijoMonedaTok: Label '_ESFCY', Locked = true;
        ErrNombreTomado: Label 'El nombre de variable %1 ya lo usa %2 (%3). Dos cosas con el mismo nombre no pueden convivir en una fórmula: elegí otro.', Comment = '%1=nombre de variable, %2=nombre de la tabla que ya lo usa, %3=código del registro';
        ErrPadreSiMismo: Label 'Un atributo no puede depender de sí mismo.';
        ErrPadreSegunValorSinPadre: Label 'No hay padre que resolver: "Padre según el valor" sólo tiene sentido con un "Depende de" cargado.';
        ErrPadreSoloLista: Label 'Solo los atributos de tipo Lista pueden encadenarse: %1 no lo es.', Comment = '%1=código del tipo de atributo';
        ErrPadreInexistente: Label 'No existe el tipo de atributo %1.', Comment = '%1=código del tipo de atributo';
        ErrPadreCiclo: Label '%1 y %2 quedarían dependiendo uno del otro.', Comment = '%1,%2=códigos de tipo de atributo';
        ErrEspejoSoloLista: Label 'Solo un atributo de tipo Lista puede ser espejo de una tabla.';
        ErrEspejoConValores: Label 'El atributo %1 ya tiene valores cargados a mano. Borralos antes de convertirlo en espejo: los valores de un espejo se copian del maestro y no se mantienen acá.', Comment = '%1=código del tipo de atributo';
        ErrEspejoConvenioConPadre: Label 'Un espejo de Convenio Colectivo no depende de nadie: sacale el "Depende de".';
        ErrEspejoCategoriaSinPadre: Label 'Un espejo de Categoría CCT tiene que depender del atributo que sea espejo de Convenio Colectivo: las categorías cuelgan de su convenio.';
        ErrEspejoCategoriaPadreAjeno: Label 'El atributo padre %1 no es espejo de Convenio Colectivo, así que sus códigos no van a coincidir con los convenios de las categorías.', Comment = '%1=código del tipo de atributo padre';
        ErrPadreConValores: Label 'El atributo %1 ya tiene valores cargados: cada uno tendría que indicar de qué valor del padre cuelga. Borralos antes de encadenarlo.', Comment = '%1=código del tipo de atributo';
}
