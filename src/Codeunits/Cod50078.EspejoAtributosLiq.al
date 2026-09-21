namespace UAS.Payroll;

/// <summary>
/// Mantiene los valores de un atributo como espejo de una tabla maestra.
/// </summary>
/// <remarks>
/// El problema que resuelve: para que el convenio y la categoría de un empleado tengan historial se
/// cargan como atributos, pero los códigos válidos ya viven en Convenio Colectivo y Categoría CCT.
/// Dos listas que dicen lo mismo se separan, y acá la separación no avisa: el motor busca
/// "Categoría CCT".Get(convenio, categoría) para PCT_ESCALA y arma los parámetros con sufijo
/// CÓDIGO_CONVENIO_CATEGORÍA. Un código que no coincide no da error, da importe cero.
///
/// Por eso los valores no se mantienen: se derivan. La forma de las dos tablas es la misma —
/// "Categoría CCT" tiene clave (Cód. Convenio, Código) y un valor de atributo encadenado tiene
/// (Tipo, Cód. Valor Padre, Código)— así que el espejo es una copia campo a campo, no una
/// traducción.
///
/// Los triggers de los dos maestros llaman acá en cada alta, cambio, renombrado y baja. La
/// resincronización completa existe para la carga inicial y para reparar; en régimen no debería
/// hacer nada, y si hace algo es que alguien tocó los valores a mano.
/// </remarks>
codeunit 50078 "Espejo Atributos Liq."
{
    Access = Public;

    // ── Resincronización completa ─────────────────────────────────────────────

    /// <summary>
    /// Rehace los valores de todos los atributos espejo. Devuelve cuántos agregó o corrigió.
    /// </summary>
    procedure ResincronizarTodo() Tocados: Integer
    var
        TipoAtr: Record "Tipo Atributo Liq.";
    begin
        TipoAtr.SetFilter("Espejo De", '<>%1', TipoAtr."Espejo De"::Ninguno);
        if TipoAtr.FindSet() then
            repeat
                Tocados += Resincronizar(TipoAtr);
            until TipoAtr.Next() = 0;
    end;

    /// <summary>
    /// Rehace los valores de un atributo espejo contra su maestro.
    /// </summary>
    /// <remarks>
    /// Copia y corrige, pero NO borra lo que sobra. Un valor que ya no está en el maestro puede tener
    /// asignaciones históricas colgando, y borrarlo dejaría a las liquidaciones de enero apuntando a
    /// un código que no existe — el mismo error silencioso que este espejo viene a evitar. La baja
    /// tiene su propio camino, desde el maestro, y ahí sí se verifica el historial antes.
    /// </remarks>
    procedure Resincronizar(TipoAtr: Record "Tipo Atributo Liq.") Tocados: Integer
    var
        Convenio: Record "Convenio Colectivo";
        Categoria: Record "Categoría CCT";
    begin
        case TipoAtr."Espejo De" of
            TipoAtr."Espejo De"::"Convenio Colectivo":
                if Convenio.FindSet() then
                    repeat
                        if Copiar(TipoAtr.Código, '', Convenio.Código, Convenio.Descripción, 0) then
                            Tocados += 1;
                    until Convenio.Next() = 0;
            // Puesto copia el MISMO maestro que Categoría CCT: los puestos de a bordo se expresan con
            // códigos de categoría. Es un espejo aparte sólo para que el par pueda distinguir los dos
            // ejes —ver el comentario en "Espejo Atributo Liq."— no porque la fuente sea otra.
            TipoAtr."Espejo De"::"Categoría CCT",
            TipoAtr."Espejo De"::Puesto:
                if Categoria.FindSet() then
                    repeat
                        // El % Escala viaja como Valor Numérico: es el único número que la categoría
                        // tiene y es el que una fórmula querría ver si lee este atributo por Fuente de
                        // Datos. El motor NO lo lee de acá — PCT_ESCALA lo saca de Categoría CCT
                        // directamente— así que copiarlo es informativo y no cambia ningún cálculo.
                        if Copiar(TipoAtr.Código, Categoria."Cód. Convenio", Categoria.Código,
                                  Categoria.Descripción, Categoria."% Escala")
                        then
                            Tocados += 1;
                    until Categoria.Next() = 0;
        end;
    end;

    // ── Enganches de los maestros ─────────────────────────────────────────────

    procedure AlEscribirConvenio(Codigo: Code[20]; Desc: Text[100])
    var
        TipoAtr: Record "Tipo Atributo Liq.";
    begin
        if not BuscarTipos(TipoAtr, TipoAtr."Espejo De"::"Convenio Colectivo") then
            exit;
        repeat
            Copiar(TipoAtr.Código, '', Codigo, Desc, 0);
        until TipoAtr.Next() = 0;
    end;

    procedure AlEscribirCategoria(CodConvenio: Code[20]; Codigo: Code[20]; Desc: Text[100]; PctEscala: Decimal)
    var
        TipoAtr: Record "Tipo Atributo Liq.";
    begin
        if not BuscarTiposDeCategoria(TipoAtr) then
            exit;
        repeat
            Copiar(TipoAtr.Código, CodConvenio, Codigo, Desc, PctEscala);
        until TipoAtr.Next() = 0;
    end;

    /// <remarks>
    /// El renombrado ARRASTRA, y es la mitad más importante de todo esto. El código es la clave con
    /// la que quedaron guardadas las asignaciones: si no se arrastra, no falla nada — el histórico
    /// del empleado simplemente queda colgando de un código que ya no existe, invisible, mientras el
    /// valor nuevo aparece sin historia. Mismo criterio que el arrastre de Entidad Liq. (Cod50075).
    /// </remarks>
    procedure AlRenombrarConvenio(CodigoViejo: Code[20]; CodigoNuevo: Code[20])
    var
        TipoAtr: Record "Tipo Atributo Liq.";
    begin
        if BuscarTipos(TipoAtr, TipoAtr."Espejo De"::"Convenio Colectivo") then
            repeat
                RenombrarValor(TipoAtr.Código, '', CodigoViejo, '', CodigoNuevo);
            until TipoAtr.Next() = 0;

        // Un convenio renombrado se lleva puestos a sus hijos: las categorías cuelgan de su código.
        // Los DOS tipos que espejan categorías —encuadre y puesto— tienen hijos así.
        if BuscarTiposDeCategoria(TipoAtr) then
            repeat
                RenombrarPadres(TipoAtr.Código, CodigoViejo, CodigoNuevo);
            until TipoAtr.Next() = 0;
    end;

    procedure AlRenombrarCategoria(CodConvenio: Code[20]; CodigoViejo: Code[20]; CodigoNuevo: Code[20])
    var
        TipoAtr: Record "Tipo Atributo Liq.";
    begin
        if not BuscarTiposDeCategoria(TipoAtr) then
            exit;
        repeat
            RenombrarValor(TipoAtr.Código, CodConvenio, CodigoViejo, CodConvenio, CodigoNuevo);
        until TipoAtr.Next() = 0;
    end;

    /// <summary>
    /// Verifica que se pueda dar de baja, y borra el valor espejo si nadie lo usa.
    /// </summary>
    /// <remarks>
    /// La baja es el único caso que NO se propaga en silencio. Un valor con asignaciones cargadas es
    /// el pasado de alguien: borrarlo dejaría huérfanas las vigencias que lo nombran. Se corta la
    /// baja en el maestro, que es donde el usuario puede entender por qué.
    /// </remarks>
    procedure AlBorrarConvenio(Codigo: Code[20])
    var
        TipoAtr: Record "Tipo Atributo Liq.";
    begin
        if not BuscarTipos(TipoAtr, TipoAtr."Espejo De"::"Convenio Colectivo") then
            exit;
        repeat
            BorrarValor(TipoAtr.Código, '', Codigo);
        until TipoAtr.Next() = 0;
    end;

    procedure AlBorrarCategoria(CodConvenio: Code[20]; Codigo: Code[20])
    var
        TipoAtr: Record "Tipo Atributo Liq.";
    begin
        if not BuscarTiposDeCategoria(TipoAtr) then
            exit;
        repeat
            BorrarValor(TipoAtr.Código, CodConvenio, Codigo);
        until TipoAtr.Next() = 0;
    end;

    // ── Primitivas ────────────────────────────────────────────────────────────

    local procedure BuscarTipos(var TipoAtr: Record "Tipo Atributo Liq."; Espejo: Enum "Espejo Atributo Liq."): Boolean
    begin
        TipoAtr.Reset();
        TipoAtr.SetRange("Espejo De", Espejo);
        exit(TipoAtr.FindSet());
    end;

    /// <summary>Los tipos que copian el maestro de categorías: el de encuadre y el de puesto.</summary>
    /// <remarks>
    /// Los dos espejos salen de "Categoría CCT", así que los enganches del maestro —alta, renombrado
    /// y baja— tienen que alcanzarlos a los dos. Buscar sólo por ::"Categoría CCT" dejaría el tipo de
    /// puesto sin mantener: no fallaría nada visible, simplemente su lista de valores se iría
    /// quedando vieja, y un renombrado dejaría colgando el historial de puestos de todo el mundo.
    /// </remarks>
    local procedure BuscarTiposDeCategoria(var TipoAtr: Record "Tipo Atributo Liq."): Boolean
    begin
        TipoAtr.Reset();
        TipoAtr.SetFilter("Espejo De", '%1|%2',
                          TipoAtr."Espejo De"::"Categoría CCT", TipoAtr."Espejo De"::Puesto);
        exit(TipoAtr.FindSet());
    end;

    /// <summary>Alta o actualización de un valor. True si hubo algo que escribir.</summary>
    local procedure Copiar(CodTipo: Code[20]; CodPadre: Code[20]; Codigo: Code[20]; Desc: Text[100]; Numero: Decimal): Boolean
    var
        Valor: Record "Valor Atributo Liq.";
    begin
        if Valor.Get(CodTipo, CodPadre, Codigo) then begin
            if (Valor.Descripción = Desc) and (Valor."Valor Numérico" = Numero) then
                exit(false);
            Valor.Descripción := Desc;
            Valor."Valor Numérico" := Numero;
            Valor.PermitirEscrituraEspejo();
            Valor.Modify();
            exit(true);
        end;

        Valor.Init();
        Valor."Cód. Tipo Atributo" := CodTipo;
        Valor."Cód. Valor Padre" := CodPadre;
        Valor.Código := Codigo;
        Valor.Descripción := Desc;
        Valor."Valor Numérico" := Numero;
        Valor.PermitirEscrituraEspejo();
        Valor.Insert();
        exit(true);
    end;

    local procedure RenombrarValor(CodTipo: Code[20]; PadreViejo: Code[20]; CodigoViejo: Code[20]; PadreNuevo: Code[20]; CodigoNuevo: Code[20])
    var
        Valor: Record "Valor Atributo Liq.";
        Asignacion: Record "Atributo Entidad Liq.";
    begin
        if CodigoViejo = CodigoNuevo then
            exit;
        if not Valor.Get(CodTipo, PadreViejo, CodigoViejo) then
            exit;
        Valor.PermitirEscrituraEspejo();
        Valor.Rename(CodTipo, PadreNuevo, CodigoNuevo);

        // Las asignaciones guardan el código copiado, no una referencia: se arrastran a mano. El
        // valor va en la clave primaria de nada acá, así que alcanza con ModifyAll.
        Asignacion.SetRange("Cód. Tipo Atributo", CodTipo);
        Asignacion.SetRange("Cód. Valor Padre", PadreViejo);
        Asignacion.SetRange("Cód. Valor", CodigoViejo);
        if not Asignacion.IsEmpty() then begin
            Asignacion.ModifyAll("Cód. Valor", CodigoNuevo);
            if PadreNuevo <> PadreViejo then begin
                Asignacion.SetRange("Cód. Valor", CodigoNuevo);
                Asignacion.ModifyAll("Cód. Valor Padre", PadreNuevo);
            end;
        end;
    end;

    // Renombrar un convenio mueve a TODAS sus categorías de padre, valores y asignaciones incluidas.
    local procedure RenombrarPadres(CodTipo: Code[20]; PadreViejo: Code[20]; PadreNuevo: Code[20])
    var
        Valor: Record "Valor Atributo Liq.";
        Codigos: List of [Code[20]];
        Codigo: Code[20];
    begin
        Valor.SetRange("Cód. Tipo Atributo", CodTipo);
        Valor.SetRange("Cód. Valor Padre", PadreViejo);
        if Valor.FindSet() then
            repeat
                Codigos.Add(Valor.Código);
            until Valor.Next() = 0;

        // Las claves primero: el Rename mueve la fila dentro del orden de la clave y el Next() de un
        // recorrido en vivo puede saltear o repetir.
        foreach Codigo in Codigos do
            RenombrarValor(CodTipo, PadreViejo, Codigo, PadreNuevo, Codigo);
    end;

    local procedure BorrarValor(CodTipo: Code[20]; CodPadre: Code[20]; Codigo: Code[20])
    var
        Valor: Record "Valor Atributo Liq.";
        Asignacion: Record "Atributo Entidad Liq.";
    begin
        if not Valor.Get(CodTipo, CodPadre, Codigo) then
            exit;

        Asignacion.SetRange("Cód. Tipo Atributo", CodTipo);
        Asignacion.SetRange("Cód. Valor Padre", CodPadre);
        Asignacion.SetRange("Cód. Valor", Codigo);
        if not Asignacion.IsEmpty() then
            Error(ErrValorConHistoria, Codigo, CodTipo, Asignacion.Count());

        Valor.PermitirEscrituraEspejo();
        Valor.Delete();
    end;

    var
        ErrValorConHistoria: Label 'No se puede eliminar: %1 está asignado en %3 registro(s) de historial del atributo %2. Esas vigencias quedarían apuntando a un código inexistente.', Comment = '%1=código, %2=tipo de atributo, %3=cantidad de asignaciones';
}
