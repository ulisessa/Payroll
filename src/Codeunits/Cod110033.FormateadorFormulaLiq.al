namespace UAS.Payroll;

/// <summary>
/// Da forma canónica al texto de una fórmula: una sola manera de escribir lo mismo.
/// </summary>
/// <remarks>
/// No es un embellecedor opcional, es la forma en la que las fórmulas se guardan. Antes el campo
/// pasaba por un normalizador que hacía exactamente lo contrario —reemplazaba los saltos de línea
/// por espacios y colapsaba los dobles—, así que toda fórmula terminaba en una sola línea por larga
/// que fuera.
///
/// Que la forma sea canónica y no una preferencia tiene un motivo concreto: el historial guarda
/// "Fórmula Anterior" y "Fórmula Nueva" enteras en cada cambio, y con todo en una línea comparar dos
/// versiones de doscientos caracteres es buscar la diferencia a ojo. Con una sola forma posible, dos
/// textos que dicen lo mismo son idénticos —el historial ni siquiera registra la entrada, porque
/// compara los textos— y lo que aparece en el diff es siempre un cambio real.
///
/// El criterio de corte es el de cualquier formateador de código: cada grupo entre paréntesis se
/// escribe en una línea si entra, y si no entra se abre, se pone un argumento por línea y se cierra.
/// No hay opciones para configurar.
/// </remarks>
codeunit 110033 "Formateador Fórmula Liq."
{
    Access = Public;

    /// <summary>
    /// Devuelve la fórmula en forma canónica. Ante cualquier duda, devuelve el texto original.
    /// </summary>
    /// <remarks>
    /// La garantía que importa: el formateador no puede cambiar lo que una fórmula calcula. Después
    /// de formatear se vuelve a tokenizar el resultado y se compara la secuencia con la del original;
    /// si difieren en algo que no sea espacio en blanco, se descarta el trabajo y se devuelve el
    /// texto tal como vino. Un formateador que rompe una fórmula sería mucho peor que uno que a veces
    /// no formatea.
    /// </remarks>
    procedure Formatear(Texto: Text): Text
    var
        Original: List of [Text];
        Verificacion: List of [Text];
        Salida: Text;
    begin
        if Texto.Trim() = '' then
            exit('');
        // Un texto con algo que el tokenizador no reconoce se devuelve intacto. Suele ser una fórmula
        // a medio escribir, y ahí reordenarla sería pelearse con quien la está escribiendo.
        if not Tokenizar(Texto, Original) then
            exit(Texto);
        if Original.Count = 0 then
            exit(Texto);

        // Emitir va envuelto porque este codeunit corre con CADA TECLA del editor de fórmulas, sobre
        // texto que está a medio escribir. La promesa de arriba —ante cualquier duda, el original— no
        // se sostiene si una fórmula incompleta puede tirar un error: el usuario ve un cuadro de
        // diálogo por cada letra que escribe.
        if not TryEmitir(Original, Salida) then
            exit(Texto);

        // NO ALCANZA CON QUE EL RESULTADO SEA CORRECTO: TIENE QUE ENTRAR EN EL CAMPO. Los campos que
        // guardan una fórmula son Text[2048] y el formateador corre dentro del OnValidate, así que
        // devolver un texto más largo no se trunca —aborta la validación con un error, en un editor
        // que formatea con cada tecla—. Con CRLF cada salto cuesta un carácter más que antes, así
        // que el margen se achicó: hoy la más larga queda en 1.085 de 2048 y sobra, pero el día que
        // una se acerque es preferible dejarla sin formatear a no poder guardarla.
        if StrLen(Salida) > LargoMaximoCampo() then
            exit(Texto);

        if not Tokenizar(Salida, Verificacion) then
            exit(Texto);
        if not MismaSecuencia(Original, Verificacion) then
            exit(Texto);
        exit(Salida);
    end;

    /// <summary>
    /// ¿El formateador entiende este texto? False = lo devolvería intacto por las dudas.
    /// </summary>
    /// <remarks>
    /// Formatear devuelve el original tanto cuando ya estaba en forma canónica como cuando no pudo
    /// leerlo, y desde afuera las dos cosas se ven igual: el texto no cambió. Son situaciones
    /// opuestas —una está bien y la otra hay que mirarla— así que quien avise al usuario necesita
    /// poder distinguirlas.
    /// </remarks>
    procedure Reconoce(Texto: Text): Boolean
    var
        Toks: List of [Text];
    begin
        if Texto.Trim() = '' then
            exit(true);
        exit(Tokenizar(Texto, Toks));
    end;

    // ── Tokenizador ───────────────────────────────────────────────────────────
    // Las mismas reglas que NextTok en "Evaluador Fórmula": si acá se partiera un identificador o un
    // número donde allá no, el formateador escribiría una fórmula distinta de la que el motor lee.
    // La coma NUNCA es decimal —el separador decimal es el punto— y '@' y '#' arrancan identificador.
    local procedure Tokenizar(Texto: Text; var Toks: List of [Text]): Boolean
    var
        C: Char;
        Pos: Integer;
        Len: Integer;
        Ini: Integer;
    begin
        Clear(Toks);
        Len := StrLen(Texto);
        Pos := 1;
        while Pos <= Len do begin
            C := Texto[Pos];
            case true of
                EsEspacio(C):
                    Pos += 1;
                C in ['+', '-', '*', '/', '(', ')', ',', '=']:
                    begin
                        Toks.Add(Format(C));
                        Pos += 1;
                    end;
                (C = '<') or (C = '>'):
                    begin
                        Ini := Pos;
                        Pos += 1;
                        if Pos <= Len then
                            if (Texto[Pos] = '=') or ((C = '<') and (Texto[Pos] = '>')) then
                                Pos += 1;
                        Toks.Add(CopyStr(Texto, Ini, Pos - Ini));
                    end;
                C = 39: // comilla simple: literal de texto, se conserva tal cual
                    begin
                        Ini := Pos;
                        Pos += 1;
                        while Pos <= Len do begin
                            if Texto[Pos] = 39 then begin
                                if (CopyStr(Texto, Pos, 2) = '''''') then
                                    Pos += 1
                                else
                                    break;
                            end;
                            Pos += 1;
                        end;
                        if Pos > Len then
                            exit(false); // comilla sin cerrar: no se toca nada
                        Pos += 1;
                        Toks.Add(CopyStr(Texto, Ini, Pos - Ini));
                    end;
                EsDigito(C) or (C = '.'):
                    begin
                        Ini := Pos;
                        while (Pos <= Len) and (EsDigito(Texto[Pos]) or (Texto[Pos] = '.')) do
                            Pos += 1;
                        Toks.Add(CopyStr(Texto, Ini, Pos - Ini));
                    end;
                EsLetra(C) or (C = '_') or (C = '@') or (C = '#'):
                    begin
                        Ini := Pos;
                        Pos += 1;
                        while (Pos <= Len) and (EsLetra(Texto[Pos]) or EsDigito(Texto[Pos]) or (Texto[Pos] = '_')) do
                            Pos += 1;
                        Toks.Add(CopyStr(Texto, Ini, Pos - Ini));
                    end;
                else
                    exit(false);
            end;
        end;
        exit(true);
    end;

    // ── Impresor ──────────────────────────────────────────────────────────────

    [TryFunction]
    local procedure TryEmitir(var Toks: List of [Text]; var Salida: Text)
    begin
        Salida := Emitir(Toks);
    end;

    local procedure Emitir(var Toks: List of [Text]): Text
    var
        Sb: TextBuilder;
        Roto: List of [Integer];
        NombreGrupo: List of [Text];
        ComasGrupo: List of [Integer];
        T: Text;
        Prev: Text;
        Sep: Text;
        i: Integer;
        Nivel: Integer;
        Col: Integer;
        PrevUnario: Boolean;
        EsteUnario: Boolean;
        GrupoRoto: Boolean;
    begin
        for i := 1 to Toks.Count do begin
            T := Toks.Get(i);
            EsteUnario := (T = '-') and EsPosicionUnaria(Prev);
            case T of
                '(':
                    begin
                        Sep := Separador(Prev, T, PrevUnario);
                        Sb.Append(Sep);
                        Sb.Append(T);
                        Col += StrLen(Sep) + 1;
                        // La decisión de romper se toma acá, mirando si el grupo ENTERO entra en lo
                        // que queda de línea. Es lo que hace que un grupo chico anidado dentro de uno
                        // roto se siga escribiendo de un tirón, en vez de arrastrar la ruptura hacia
                        // abajo y dejar una escalera de una palabra por línea.
                        // El nombre que precede al paréntesis es el de la función: alcanza para que
                        // el corte pueda ser distinto según cuál sea. Si adelante no hay un nombre
                        // —un simple (a + b)— queda vacío y se usa el criterio general.
                        NombreGrupo.Add(UpperCase(Prev));
                        ComasGrupo.Add(0);
                        if Col + LargoGrupo(Toks, i) > AnchoMaximo() then begin
                            Roto.Add(1);
                            Nivel += 1;
                            Col := AbrirLinea(Sb, Nivel);
                        end else
                            Roto.Add(0);
                    end;
                ')':
                    begin
                        GrupoRoto := false;
                        if Roto.Count > 0 then begin
                            GrupoRoto := Roto.Get(Roto.Count) = 1;
                            Roto.RemoveAt(Roto.Count);
                            NombreGrupo.RemoveAt(NombreGrupo.Count);
                            ComasGrupo.RemoveAt(ComasGrupo.Count);
                        end;
                        if GrupoRoto then begin
                            Nivel -= 1;
                            Col := AbrirLinea(Sb, Nivel);
                        end;
                        Sb.Append(T);
                        Col += 1;
                    end;
                ',':
                    begin
                        Sb.Append(T);
                        Col += 1;
                        if ComasGrupo.Count > 0 then
                            ComasGrupo.Set(ComasGrupo.Count, ComasGrupo.Get(ComasGrupo.Count) + 1);
                        // El Get va en su propio if y no pegado al Count con un and: AL evalúa los
                        // DOS lados del and, así que con la pila vacía el Get corre igual y tira
                        // "argumento no válido". Y la pila está vacía cada vez que aparece una coma
                        // fuera de todo paréntesis, que es lo normal a mitad de escribir una fórmula:
                        // el editor formatea con cada tecla, así que el error salía sin parar.
                        GrupoRoto := false;
                        if Roto.Count > 0 then
                            GrupoRoto := Roto.Get(Roto.Count) = 1;
                        if GrupoRoto and CortaEnEstaComa(NombreGrupo, ComasGrupo) then
                            Col := AbrirLinea(Sb, Nivel)
                        else begin
                            Sb.Append(' ');
                            Col += 1;
                        end;
                    end;
                else
                    if CortaCadena(Toks, i, T, EsteUnario, Roto, Col) then begin
                        // El operador arranca el renglón, no lo termina: leyendo en vertical, cada
                        // línea dice qué se suma o qué se resta antes de decir qué cosa. En una base
                        // imponible de quince términos es la diferencia entre poder auditarla y no.
                        Col := AbrirLinea(Sb, Nivel + 1);
                        Sb.Append(T);
                        Col += StrLen(T);
                    end else begin
                        Sep := Separador(Prev, T, PrevUnario);
                        Sb.Append(Sep);
                        Sb.Append(T);
                        Col += StrLen(Sep) + StrLen(T);
                    end;
            end;
            Prev := T;
            PrevUnario := EsteUnario;
        end;
        exit(Sb.ToText());
    end;

    /// <summary>¿Este + o − arranca un renglón nuevo?</summary>
    /// <remarks>
    /// Cortar solo en las comas alcanza mientras los argumentos sean cortos. La base imponible de
    /// Ganancias no lo es: es una cadena de quince términos que entra en UN argumento, así que sin
    /// esto queda una línea de doscientos caracteres —y, peor, cualquier paréntesis que aparezca
    /// después se rompe en varios renglones, porque para entonces la columna ya se pasó del ancho.
    /// Lo peor de los dos mundos: una línea ilegible y encima partida en el lugar equivocado.
    ///
    /// Se corta antes del operador y solo si lo que sigue —el operador más su término— no entra en lo
    /// que queda de línea. Los * y / no cortan: encadenan factores de un mismo producto, que se lee
    /// como una unidad, y partirlos daría renglones sin sentido propio.
    /// </remarks>
    local procedure CortaCadena(var Toks: List of [Text]; i: Integer; T: Text; EsUnario: Boolean; var Roto: List of [Integer]; Col: Integer): Boolean
    begin
        if EsUnario then
            exit(false);
        if (T <> '+') and (T <> '-') then
            exit(false);
        // Dentro de un grupo, solo si ese grupo ya se rompió: si entró en una línea, se respeta.
        // Fuera de todo grupo —una fórmula que es una sola cadena larga— se corta igual.
        if Roto.Count > 0 then
            if Roto.Get(Roto.Count) <> 1 then
                exit(false);
        exit(Col + 1 + LargoTermino(Toks, i) > AnchoMaximo());
    end;

    /// <summary>Largo del operador en Desde más el término que le sigue, escrito de un tirón.</summary>
    /// <remarks>
    /// Termina en el próximo + o − del MISMO nivel, o en la coma o el paréntesis que cierran el
    /// argumento. Lo de adentro de un paréntesis no cuenta como corte: (A + B) es un término solo.
    /// </remarks>
    local procedure LargoTermino(var Toks: List of [Text]; Desde: Integer): Integer
    var
        T: Text;
        Prev: Text;
        i: Integer;
        Prof: Integer;
        Largo: Integer;
        PrevUnario: Boolean;
        EsteUnario: Boolean;
    begin
        for i := Desde to Toks.Count do begin
            T := Toks.Get(i);
            EsteUnario := (T = '-') and EsPosicionUnaria(Prev);
            if (Prof = 0) and (i > Desde) then begin
                if (T = ',') or (T = ')') then
                    exit(Largo);
                if (T = '+') or ((T = '-') and not EsteUnario) then
                    exit(Largo);
            end;
            if i > Desde then
                if Prev = ',' then
                    Largo += 1
                else
                    Largo += StrLen(Separador(Prev, T, PrevUnario));
            Largo += StrLen(T);
            if T = '(' then
                Prof += 1;
            if T = ')' then
                Prof -= 1;
            Prev := T;
            PrevUnario := EsteUnario;
        end;
        exit(Largo);
    end;

    /// <summary>¿La coma que se acaba de emitir corta la línea, o sigue en la misma?</summary>
    /// <remarks>
    /// En general cada argumento va en su renglón. CASE es la excepción: se lee de a pares —una
    /// condición y su valor— así que el corte cae recién después del valor. Partirlos dejaría cada
    /// rama ocupando dos renglones y se perdería justo lo que CASE vino a dar, que es ver la escala
    /// entera de un vistazo.
    /// </remarks>
    local procedure CortaEnEstaComa(var Nombres: List of [Text]; var Comas: List of [Integer]): Boolean
    begin
        // Las dos pilas se llenan y se vacían juntas, pero se consultan por separado a propósito:
        // atar el Get de una al Count de la otra es la clase de suposición que se rompe el día que
        // alguien toque el orden de los Add.
        if (Nombres.Count = 0) or (Comas.Count = 0) then
            exit(true);
        if Nombres.Get(Nombres.Count) <> 'CASE' then
            exit(true);
        exit(Comas.Get(Comas.Count) mod 2 = 0);
    end;

    /// <summary>Largo del grupo que abre en Desde, escrito de un tirón, incluido su ')'.</summary>
    local procedure LargoGrupo(var Toks: List of [Text]; Desde: Integer): Integer
    var
        T: Text;
        Prev: Text;
        i: Integer;
        Prof: Integer;
        Largo: Integer;
        PrevUnario: Boolean;
        EsteUnario: Boolean;
    begin
        for i := Desde to Toks.Count do begin
            T := Toks.Get(i);
            EsteUnario := (T = '-') and EsPosicionUnaria(Prev);
            if i > Desde then
                if Prev = ',' then
                    Largo += 1 // la coma escribe su propio espacio
                else
                    Largo += StrLen(Separador(Prev, T, PrevUnario));
            Largo += StrLen(T);
            if T = '(' then
                Prof += 1;
            if T = ')' then begin
                Prof -= 1;
                if Prof = 0 then
                    exit(Largo);
            end;
            Prev := T;
            PrevUnario := EsteUnario;
        end;
        // Paréntesis sin cerrar: se devuelve un largo imposible para que nunca entre en una línea.
        // La fórmula tampoco va a pasar la validación de sintaxis, así que da igual cómo se vea.
        exit(Largo + AnchoMaximo());
    end;

    local procedure Separador(Prev: Text; Cur: Text; PrevUnario: Boolean): Text
    begin
        if Prev = '' then
            exit('');
        // La coma ya escribió su espacio —o su salto de línea— cuando se emitió.
        if Prev = ',' then
            exit('');
        if Prev = '(' then
            exit('');
        if (Cur = ',') or (Cur = ')') then
            exit('');
        // Un menos unario va pegado a lo que niega: -SUELDO, no - SUELDO.
        if PrevUnario then
            exit('');
        if EsOperador(Prev) or EsOperador(Cur) then
            exit(' ');
        // Nombre seguido de paréntesis: es una llamada, va pegado.
        if Cur = '(' then
            exit('');
        exit(' ');
    end;

    local procedure AbrirLinea(var Sb: TextBuilder; Nivel: Integer): Integer
    begin
        Sb.Append(NuevaLinea());
        Sb.Append(PadStr('', Nivel * Sangria(), ' '));
        exit(Nivel * Sangria());
    end;

    local procedure MismaSecuencia(var A: List of [Text]; var B: List of [Text]): Boolean
    var
        i: Integer;
    begin
        if A.Count <> B.Count then
            exit(false);
        for i := 1 to A.Count do
            if A.Get(i) <> B.Get(i) then
                exit(false);
        exit(true);
    end;

    // ── Helpers ───────────────────────────────────────────────────────────────

    local procedure EsPosicionUnaria(Prev: Text): Boolean
    begin
        exit((Prev = '') or (Prev = '(') or (Prev = ',') or EsOperador(Prev));
    end;

    local procedure EsOperador(T: Text): Boolean
    begin
        exit(UpperCase(T) in ['+', '-', '*', '/', '=', '<>', '<', '>', '<=', '>=', 'AND', 'OR', 'NOT']);
    end;

    local procedure EsEspacio(C: Char): Boolean
    begin
        exit((C = ' ') or (C = 9) or (C = 10) or (C = 13));
    end;

    local procedure EsDigito(C: Char): Boolean
    begin
        exit((C >= '0') and (C <= '9'));
    end;

    // El mismo juego de letras que el tokenizador del evaluador, acentos incluidos.
    local procedure EsLetra(C: Char): Boolean
    begin
        exit(((C >= 'A') and (C <= 'Z')) or ((C >= 'a') and (C <= 'z')) or
             (C in ['Ñ', 'ñ', 'Á', 'á', 'É', 'é', 'Í', 'í', 'Ó', 'ó', 'Ú', 'ú', 'Ü', 'ü']));
    end;

    /// <summary>El salto de línea canónico: CRLF.</summary>
    /// <remarks>
    /// EMITÍA LF SOLO Y NO SE VEÍA. El formateador cortaba las líneas y las indentaba bien, pero el
    /// control multilínea no rompe con un LF suelto: la fórmula se mostraba de corrido y la sangría
    /// aparecía como una tira de espacios en el medio. Parecía que el formateador no hacía nada.
    ///
    /// Y LA BASE YA ESTABA MEZCLADA: 16 fórmulas guardadas con CRLF contra 48 con LF solo. Dos
    /// textos que dicen lo mismo con distinto salto NO son iguales, así que el historial registraba
    /// una entrada con el diff del texto entero cada vez que se volvía a guardar una fórmula sin
    /// cambiarla —justo lo que la forma canónica existe para evitar—. Al unificar en CRLF hubo que
    /// migrar las 48 por SQL, sin pasar por el OnValidate, para no generar esas entradas falsas.
    ///
    /// El tokenizador cuenta el CR (13) como espacio, así que una fórmula vieja en LF se sigue
    /// leyendo igual y se reescribe en CRLF la primera vez que se la guarda.
    /// </remarks>
    local procedure NuevaLinea(): Text
    var
        CR: Char;
        LF: Char;
    begin
        CR := 13;
        LF := 10;
        exit(Format(CR) + Format(LF));
    end;

    local procedure AnchoMaximo(): Integer
    begin
        exit(96);
    end;

    local procedure Sangria(): Integer
    begin
        exit(4);
    end;

    /// <summary>El tamaño de los campos que guardan una fórmula: `Fórmula` y `Condición`, Text[2048].</summary>
    local procedure LargoMaximoCampo(): Integer
    begin
        exit(2048);
    end;
}
