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
/// La clave tiene DOS tramos de especialización, y la cascada los suelta de atrás para adelante:
///
///     COD_&lt;eje1&gt;_&lt;eje2&gt;_&lt;eje3&gt;  ·  _&lt;empleado&gt;  |  _&lt;convenio&gt;_&lt;categoría&gt;  |  _&lt;convenio&gt;  |  (nada)
///     └──────── los ejes de atributo ────────┘     └────────────── el alcance ──────────────┘
///
/// Para cada NIVEL DE ALCANCE se sueltan los ejes de atrás para adelante, y sólo después se baja un
/// nivel: así "el valor de MR08 para cualquier pesquería" le gana a "el de potero para todo el
/// convenio". Gana la primera clave que tenga valor cargado. Con un eje son 8 candidatos y con tres
/// 16, todos contra un Dictionary en memoria.
///
/// La fila sin ejes, sin empleado, sin convenio ni categoría deriva la clave base y hace de valor
/// por defecto: se cargan solo las excepciones y el resto cae al genérico, en vez de quedar en cero
/// por no existir la combinación exacta.
///
/// POR QUÉ LOS EJES SE SUELTAN DE ATRÁS PARA ADELANTE, y no en todas las combinaciones posibles. Van
/// ordenados por declaración —el eje 1 es el que el parámetro declara primero, o sea el que más
/// importa—, así que los subconjuntos útiles son los prefijos. Probar los 2³ subconjuntos obligaría
/// además a decidir si "eje 1 sin eje 2" gana a "eje 2 sin eje 1", que no tiene respuesta obvia.
///
/// EL EJE GUARDA EL SUFIJO, NO EL CÓDIGO DEL VALOR. Es lo que permite que varios valores de atributo
/// aporten el mismo segmento: `TA` Tangonero y `ML` Arrastrero/Merlucero tienen los dos
/// `Sufijo Parámetro = LAN`, así que una sola fila `_LAN` sirve a los dos. Guardar el código del
/// valor dejaría al Puente Mayor —que es ML— sin precio, que es exactamente el error que el 6/10/2026
/// hizo fallar al 04495.
///
/// Ya no hay banderas que declaren qué alcance usa cada parámetro: la clave sale de los campos que la
/// fila tiene completos, y la cascada consulta todos. Un parámetro puede así tener a la vez un valor
/// general, una excepción por convenio y otra por empleado.
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
        SinEjes: List of [Code[10]];
    begin
        exit(ArmarConEjes(CodigoBase, SinEjes, Parte1, Parte2));
    end;

    /// <summary>
    /// La misma clave, con los sufijos de los ejes de atributo entre el código base y el alcance.
    /// </summary>
    procedure ArmarConEjes(CodigoBase: Code[20]; var Ejes: List of [Code[10]]; Parte1: Code[20]; Parte2: Code[20]): Code[50]
    var
        Clave: Text;
        Eje: Code[10];
    begin
        Clave := CodigoBase;
        // Los ejes van PRIMERO, antes del alcance: es el orden que ya tienen las claves escritas
        // —VALOR_FRANCO_CAL_729/15_MR08—, así que migrar al eje no reescribe ninguna.
        foreach Eje in Ejes do
            if Eje <> '' then
                Clave += '_' + Eje;
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
    /// Los sufijos de eje que una fila declara, como lista densa y en orden.
    /// </summary>
    /// <remarks>
    /// DENSA porque la tabla no deja declarar el eje 2 sin el eje 1: un hueco haría que la clave de
    /// la fila no coincidiera con ninguna candidata y el valor quedara inalcanzable sin error.
    /// </remarks>
    procedure EjesDeFila(ParamVig: Record "Parámetro Vigente") Lista: List of [Code[10]]
    begin
        if ParamVig."Sufijo Atributo 1" <> '' then
            Lista.Add(ParamVig."Sufijo Atributo 1");
        if ParamVig."Sufijo Atributo 2" <> '' then
            Lista.Add(ParamVig."Sufijo Atributo 2");
        if ParamVig."Sufijo Atributo 3" <> '' then
            Lista.Add(ParamVig."Sufijo Atributo 3");
    end;

    /// <summary>
    /// La clave que le corresponde a una fila, según los campos que tenga completos.
    /// </summary>
    procedure ArmarDeFila(ParamVig: Record "Parámetro Vigente"): Code[50]
    var
        Ejes: List of [Code[10]];
    begin
        Ejes := EjesDeFila(ParamVig);
        // El empleado manda: es el alcance más específico y no se combina con los otros. Los ejes sí
        // lo acompañan —un valor puede ser "de este empleado EN potero"—, porque son otra dimensión.
        if ParamVig."No. Empleado" <> '' then
            exit(ArmarConEjes(ParamVig."Cód. Parámetro Base", Ejes, ParamVig."No. Empleado", ''));
        exit(ArmarConEjes(ParamVig."Cód. Parámetro Base", Ejes, ParamVig."Cód. Convenio", ParamVig."Cód. Categoría"));
    end;

    /// <summary>
    /// Nivel de la fila en el árbol: 0 base, 1 convenio o empleado, 2 convenio + categoría.
    /// </summary>
    /// <remarks>
    /// Los ejes NO suben el nivel. El árbol dibuja la jerarquía del ALCANCE —quién es excepción de
    /// quién—, y el eje es una dimensión paralela: `_CAL` y `_LAN` del mismo convenio son hermanos,
    /// no uno hijo del otro.
    /// </remarks>
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
    var
        SinEjes: List of [Code[10]];
    begin
        Lista := CandidatosConEjes(CodigoBase, SinEjes, CodEmpleado, CodConvenio, CodCategoria);
    end;

    /// <summary>
    /// Las mismas candidatas, recorriendo además los prefijos de los ejes del más largo al vacío.
    /// </summary>
    procedure CandidatosConEjes(CodigoBase: Code[20]; var Ejes: List of [Code[10]]; CodEmpleado: Code[20]; CodConvenio: Code[20]; CodCategoria: Code[20]) Lista: List of [Code[50]]
    begin
        // EL ALCANCE AFUERA, LOS EJES ADENTRO, y el orden importa de verdad. Para cada nivel de
        // alcance se sueltan los ejes de atrás para adelante, y sólo después se baja un nivel:
        //
        //     COD_<eje>_<empleado>    →  COD_<empleado>
        //     COD_<eje>_<conv>_<cat>  →  COD_<conv>_<cat>
        //     COD_<eje>_<conv>        →  COD_<conv>
        //     COD_<eje>               →  COD
        //
        // Así "el valor de MR08 para cualquier pesquería" le gana a "el valor de potero para todo el
        // convenio", que es lo que se espera: el par convenio+categoría es el eje primario de todo el
        // sistema de parámetros, y el atributo lo acompaña en vez de reemplazarlo.
        //
        // AL REVÉS —los ejes afuera— la primera versión de esto hacía que una fila por convenio CON
        // pesquería tapara una fila por categoría SIN pesquería. En los troncos ya migrados eso no
        // cambiaría ningún importe, porque sus filas están todas al mismo nivel; pero 25 parámetros de
        // la tabla ya mezclan niveles, y cargar el valor general sin eje con sólo las excepciones por
        // pesquería —que es la forma que vale la pena— es justamente la que crea la combinación.
        //
        // Y ES LO QUE EL FRANCO YA HACÍA. Gestión Francos.ResolverValorFrancoDia prueba el precio con
        // sufijo y sin sufijo SIN bajar de nivel de alcance, y era el único lugar del código donde el
        // sufijo se resolvía. Esta cascada generaliza eso en vez de contradecirlo.
        if CodEmpleado <> '' then
            AgregarSoltandoEjes(Lista, CodigoBase, Ejes, CodEmpleado, '');
        if (CodConvenio <> '') and (CodCategoria <> '') then
            AgregarSoltandoEjes(Lista, CodigoBase, Ejes, CodConvenio, CodCategoria);
        if CodConvenio <> '' then
            AgregarSoltandoEjes(Lista, CodigoBase, Ejes, CodConvenio, '');
        AgregarSoltandoEjes(Lista, CodigoBase, Ejes, '', '');
    end;

    /// <summary>
    /// Para un alcance fijo, las claves con todos los ejes, con menos, y sin ninguno.
    /// </summary>
    local procedure AgregarSoltandoEjes(var Lista: List of [Code[50]]; CodigoBase: Code[20]; var Ejes: List of [Code[10]]; Parte1: Code[20]; Parte2: Code[20])
    var
        Prefijo: List of [Code[10]];
        Cuantos: Integer;
        i: Integer;
        Eje: Code[10];
    begin
        // Del prefijo más largo al vacío. Sin ejes declarados esto agrega UNA sola clave, así que un
        // parámetro sin ejes recorre exactamente las cuatro de siempre.
        for Cuantos := Ejes.Count() downto 0 do begin
            Clear(Prefijo);
            for i := 1 to Cuantos do begin
                Ejes.Get(i, Eje);
                Prefijo.Add(Eje);
            end;
            Lista.Add(ArmarConEjes(CodigoBase, Prefijo, Parte1, Parte2));
        end;
    end;

    /// <summary>
    /// La clave efectiva: entre las candidatas cargadas, la de VIGENCIA MÁS RECIENTE.
    /// Si ninguna existe devuelve la más específica, que el llamador trata como sin valor.
    /// </summary>
    /// <remarks>
    /// LA FECHA PESA MÁS QUE EL RESTO DE LA CLAVE, y la especificidad sólo desempata. Un parámetro se
    /// lee como lo que es —un registro cronológico de decisiones—: la última instrucción cargada es
    /// la que vale, y cargar una fila genérica con vigencia de febrero significa "desde febrero esto
    /// vale para todos", aunque exista una fila por convenio de enero.
    ///
    /// ANTES GANABA SIEMPRE LA MÁS ESPECÍFICA sin mirar la fecha, y la fila genérica era sólo el
    /// valor por defecto de los alcances que no tenían fila propia. Eso hacía imposible expresar un
    /// cambio que alcanza a todos sin repetirlo en cada fila específica: la vigencia nueva se cargaba,
    /// no pasaba nada, y no había error ni aviso. Pasó con COEF_TANGONERO en febrero de 2026.
    ///
    /// EL PRECIO DE ESTA REGLA, que hay que conocer: una fila específica VIEJA pierde contra una
    /// genérica NUEVA aunque nadie haya querido pisarla. "Vieja" pasa a leerse como "superada", y una
    /// fila que no necesitó tocarse en años queda expuesta. Al cambiar la regla, `PCT_ANTIG_372/04`
    /// —vigencia 2023, 0,01, correcta contra Meta4 en 11 de 11— perdía contra la genérica de 2026
    /// (0,25) y multiplicaba por 25 la antigüedad de esos empleados. Se corrigió fechando la fila
    /// específica, no volviendo atrás con la regla. **Al cargar una genérica nueva hay que mirar qué
    /// filas específicas quedan por debajo**, y para eso está el control de la página de parámetros.
    ///
    /// EL EMPATE LO ROMPE LA ESPECIFICIDAD porque la lista de candidatas ya viene ordenada de la más
    /// específica a la menos, y sólo se reemplaza con una vigencia ESTRICTAMENTE mayor. Dos filas del
    /// mismo día —el caso normal cuando se carga una escala entera— se comportan como antes.
    /// </remarks>
    procedure Resolver(CodigoBase: Code[20]; CodEmpleado: Code[20]; CodConvenio: Code[20]; CodCategoria: Code[20]; var ValorMap: Dictionary of [Code[50], Decimal]; var VigMap: Dictionary of [Code[50], Date]) CodigoEfectivo: Code[50]
    var
        SinEjes: List of [Code[10]];
    begin
        exit(ResolverConEjes(CodigoBase, SinEjes, CodEmpleado, CodConvenio, CodCategoria, ValorMap, VigMap));
    end;

    procedure ResolverConEjes(CodigoBase: Code[20]; var Ejes: List of [Code[10]]; CodEmpleado: Code[20]; CodConvenio: Code[20]; CodCategoria: Code[20]; var ValorMap: Dictionary of [Code[50], Decimal]; var VigMap: Dictionary of [Code[50], Date]) CodigoEfectivo: Code[50]
    var
        Lista: List of [Code[50]];
        Candidato: Code[50];
        Vigencia: Date;
        MejorVigencia: Date;
        Encontrada: Boolean;
    begin
        Lista := CandidatosConEjes(CodigoBase, Ejes, CodEmpleado, CodConvenio, CodCategoria);
        foreach Candidato in Lista do
            // ContainsKey y Get NUNCA en la misma expresión: AL no cortocircuita.
            if ValorMap.ContainsKey(Candidato) then begin
                Vigencia := 0D;
                if VigMap.ContainsKey(Candidato) then
                    Vigencia := VigMap.Get(Candidato);
                if not Encontrada or (Vigencia > MejorVigencia) then begin
                    Encontrada := true;
                    MejorVigencia := Vigencia;
                    CodigoEfectivo := Candidato;
                end;
            end;
        if Encontrada then
            exit(CodigoEfectivo);
        Lista.Get(1, CodigoEfectivo);
    end;

    /// <summary>
    /// Igual que Resolver pero contra la tabla, para los llamadores que no tienen el mapa cargado.
    /// </summary>
    procedure ResolverEnTabla(CodigoBase: Code[20]; CodEmpleado: Code[20]; CodConvenio: Code[20]; CodCategoria: Code[20]; FechaRef: Date) CodigoEfectivo: Code[50]
    var
        SinEjes: List of [Code[10]];
    begin
        exit(ResolverEnTablaConEjes(CodigoBase, SinEjes, CodEmpleado, CodConvenio, CodCategoria, FechaRef));
    end;

    /// <remarks>
    /// Misma regla que Resolver —gana la vigencia más reciente, la especificidad desempata—, leída
    /// contra la tabla. Por eso ya no alcanza con IsEmpty: hay que traer la fecha de cada candidata.
    /// </remarks>
    procedure ResolverEnTablaConEjes(CodigoBase: Code[20]; var Ejes: List of [Code[10]]; CodEmpleado: Code[20]; CodConvenio: Code[20]; CodCategoria: Code[20]; FechaRef: Date) CodigoEfectivo: Code[50]
    var
        ParamVig: Record "Parámetro Vigente";
        Lista: List of [Code[50]];
        Candidato: Code[50];
        MejorVigencia: Date;
        Encontrada: Boolean;
    begin
        Lista := CandidatosConEjes(CodigoBase, Ejes, CodEmpleado, CodConvenio, CodCategoria);
        foreach Candidato in Lista do begin
            ParamVig.SetCurrentKey("Cód. Parámetro", "Vigencia Desde");
            ParamVig.SetRange("Cód. Parámetro", Candidato);
            ParamVig.SetFilter("Vigencia Desde", '<=%1', FechaRef);
            if ParamVig.FindLast() then
                if not Encontrada or (ParamVig."Vigencia Desde" > MejorVigencia) then begin
                    Encontrada := true;
                    MejorVigencia := ParamVig."Vigencia Desde";
                    CodigoEfectivo := Candidato;
                end;
        end;
        if Encontrada then
            exit(CodigoEfectivo);
        Lista.Get(1, CodigoEfectivo);
    end;

    /// <summary>
    /// Los sufijos distintos que los valores de un Tipo de Atributo pueden aportar a una clave.
    /// </summary>
    /// <remarks>
    /// Es el dominio contra el que se valida un "Sufijo Atributo N", y no se puede expresar con una
    /// TableRelation: varios valores aportan el mismo sufijo —TA y ML dan los dos LAN— y los que no
    /// aportan ninguno —FA, PA— no son opciones válidas.
    /// </remarks>
    procedure SufijosDelTipo(CodTipoAtributo: Code[20]) Lista: List of [Code[10]]
    var
        Valor: Record "Valor Atributo Liq.";
    begin
        if CodTipoAtributo = '' then
            exit;
        Valor.SetRange("Cód. Tipo Atributo", CodTipoAtributo);
        Valor.SetFilter("Sufijo Parámetro", '<>%1', '');
        if not Valor.FindSet() then
            exit;
        repeat
            if not Lista.Contains(Valor."Sufijo Parámetro") then
                Lista.Add(Valor."Sufijo Parámetro");
        until Valor.Next() = 0;
    end;

    var
        ErrClaveLarga: Label 'La clave de parámetro "%1" tiene %2 caracteres y el máximo son 50. Acortá el código base del parámetro o usá menos ejes: recortarla dejaría dos parámetros distintos compartiendo la misma clave.', Comment = '%1=clave armada, %2=largo de la clave';
}
