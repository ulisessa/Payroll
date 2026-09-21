namespace UAS.Payroll;

/// <summary>
/// Único lugar donde se arma y se resuelve la clave derivada de un parámetro.
/// </summary>
/// <remarks>
/// Antes esta misma cascada estaba escrita en cuatro lugares —el motor, aprobar, reabrir y el
/// catálogo— sincronizados por convención. Esa forma ya nos costó caro en los conceptos: dos
/// consultas que se mantenían iguales de palabra, se tocó una, y fallaron todas las liquidaciones.
/// Con cuatro copias el riesgo era el doble.
///
/// La cascada va de la clave MÁS específica a la menos, y gana la primera que tenga valor cargado:
///
///     COD_&lt;empleado&gt;  →  COD_&lt;convenio&gt;_&lt;categoría&gt;  →  COD_&lt;convenio&gt;  →  COD
///
/// La fila sin empleado, convenio ni categoría deriva la clave base y hace de valor por defecto: se
/// cargan solo las excepciones y el resto cae al genérico, en vez de quedar en cero por no existir
/// la combinación exacta.
///
/// Ya no hay banderas que declaren qué eje usa cada parámetro: la clave sale de los campos que la
/// fila tiene completos, y la cascada consulta todos los ejes. Un parámetro puede así tener a la vez
/// un valor general, una excepción por convenio y otra por empleado.
/// </remarks>
codeunit 50071 "Claves Parámetro Liq."
{
    Access = Public;

    /// <summary>
    /// Arma COD, COD_&lt;p1&gt; o COD_&lt;p1&gt;_&lt;p2&gt; salteando los tramos vacíos.
    /// </summary>
    /// <remarks>
    /// Saltear los vacíos evita claves con separadores colgando (VALOR_L1_ o VALOR_L1__OF01) que no
    /// coincidirían con ninguna clave real.
    /// </remarks>
    procedure Armar(CodigoBase: Code[20]; Parte1: Code[20]; Parte2: Code[20]): Code[50]
    var
        Clave: Text;
    begin
        Clave := CodigoBase;
        if Parte1 <> '' then
            Clave += '_' + Parte1;
        if Parte2 <> '' then
            Clave += '_' + Parte2;

        // Antes esto era un CopyStr a 50 y la clave se recortaba en silencio. Dos claves distintas que
        // se recortan al mismo prefijo son dos parámetros que se pisan, con el importe de uno
        // apareciendo en el cálculo del otro. Corta acá, que es donde se puede explicar, en vez de en
        // la liquidación.
        if StrLen(Clave) > 50 then
            Error(ErrClaveLarga, Clave, StrLen(Clave));
        exit(CopyStr(Clave, 1, 50));
    end;

    /// <summary>
    /// La clave que le corresponde a una fila, según los campos que tenga completos.
    /// </summary>
    procedure ArmarDeFila(ParamVig: Record "Parámetro Vigente"): Code[50]
    begin
        // El empleado manda: es el eje más específico y no se combina con los otros.
        if ParamVig."No. Empleado" <> '' then
            exit(Armar(ParamVig."Cód. Parámetro Base", ParamVig."No. Empleado", ''));
        exit(Armar(ParamVig."Cód. Parámetro Base", ParamVig."Cód. Convenio", ParamVig."Cód. Categoría"));
    end;

    /// <summary>
    /// Nivel de la fila en el árbol: 0 base, 1 convenio o empleado, 2 convenio + categoría.
    /// </summary>
    procedure NivelDeFila(ParamVig: Record "Parámetro Vigente"): Integer
    begin
        if ParamVig."No. Empleado" <> '' then
            exit(1);
        if ParamVig."Cód. Categoría" <> '' then
            exit(2);
        if ParamVig."Cód. Convenio" <> '' then
            exit(1);
        exit(0);
    end;

    /// <summary>
    /// Recalcula el Nivel de todas las filas existentes. Devuelve cuántas cambió.
    /// </summary>
    /// <remarks>
    /// "Nivel" es la columna de indentación del árbol y se calcula al insertar, así que las filas
    /// anteriores al campo lo tienen en cero y el árbol las mostraría todas planas.
    ///
    /// Solo toca esa columna: es un valor derivado y de presentación. NO reescribe la clave, que es
    /// lo único que cambiaría un resultado de cálculo — las claves mal armadas se revisan una por una
    /// en "Claves de Parámetro a Revisar", porque repararlas es una decisión de negocio.
    /// </remarks>
    procedure RecalcularNiveles() Actualizadas: Integer
    var
        ParamVig: Record "Parámetro Vigente";
        NivelNuevo: Integer;
    begin
        if not ParamVig.FindSet(true) then
            exit(0);
        repeat
            NivelNuevo := NivelDeFila(ParamVig);
            if ParamVig.Nivel <> NivelNuevo then begin
                ParamVig.Nivel := NivelNuevo;
                // Sin disparar triggers: es una columna derivada, no una edición del usuario.
                ParamVig.Modify();
                Actualizadas += 1;
            end;
        until ParamVig.Next() = 0;
    end;

    /// <summary>
    /// Claves candidatas para un contexto de cálculo, de la más específica a la menos.
    /// </summary>
    procedure Candidatos(CodigoBase: Code[20]; CodEmpleado: Code[20]; CodConvenio: Code[20]; CodCategoria: Code[20]) Lista: List of [Code[50]]
    begin
        if CodEmpleado <> '' then
            Lista.Add(Armar(CodigoBase, CodEmpleado, ''));
        if (CodConvenio <> '') and (CodCategoria <> '') then
            Lista.Add(Armar(CodigoBase, CodConvenio, CodCategoria));
        if CodConvenio <> '' then
            Lista.Add(Armar(CodigoBase, CodConvenio, ''));
        Lista.Add(CodigoBase);
    end;

    /// <summary>
    /// La clave efectiva: la primera candidata que exista en el mapa de valores cargados.
    /// Si ninguna existe devuelve la más específica, que el llamador trata como sin valor.
    /// </summary>
    procedure Resolver(CodigoBase: Code[20]; CodEmpleado: Code[20]; CodConvenio: Code[20]; CodCategoria: Code[20]; var ValorMap: Dictionary of [Code[50], Decimal]) CodigoEfectivo: Code[50]
    var
        Lista: List of [Code[50]];
        Candidato: Code[50];
    begin
        Lista := Candidatos(CodigoBase, CodEmpleado, CodConvenio, CodCategoria);
        foreach Candidato in Lista do
            if ValorMap.ContainsKey(Candidato) then
                exit(Candidato);
        Lista.Get(1, CodigoEfectivo);
    end;

    /// <summary>
    /// Igual que Resolver pero contra la tabla, para los llamadores que no tienen el mapa cargado.
    /// </summary>
    procedure ResolverEnTabla(CodigoBase: Code[20]; CodEmpleado: Code[20]; CodConvenio: Code[20]; CodCategoria: Code[20]; FechaRef: Date) CodigoEfectivo: Code[50]
    var
        ParamVig: Record "Parámetro Vigente";
        Lista: List of [Code[50]];
        Candidato: Code[50];
    begin
        Lista := Candidatos(CodigoBase, CodEmpleado, CodConvenio, CodCategoria);
        foreach Candidato in Lista do begin
            ParamVig.SetCurrentKey("Cód. Parámetro", "Vigencia Desde");
            ParamVig.SetRange("Cód. Parámetro", Candidato);
            ParamVig.SetFilter("Vigencia Desde", '<=%1', FechaRef);
            if not ParamVig.IsEmpty() then
                exit(Candidato);
        end;
        Lista.Get(1, CodigoEfectivo);
    end;

    var
        ErrClaveLarga: Label 'La clave de parámetro "%1" tiene %2 caracteres y el máximo son 50. Acortá el código base del parámetro: recortarla dejaría dos parámetros distintos compartiendo la misma clave.', Comment = '%1=clave armada, %2=largo de la clave';
}
