namespace UAS.Payroll;

/// <summary>
/// Arma el paso a paso del cálculo de una línea de liquidación.
///
/// CÓMO, Y POR QUÉ ASÍ. Re-evalúa la fórmula GUARDADA en la línea ("Fórmula Aplicada")
/// con los valores GUARDADOS en "Detalle Variable Línea Liq.", no con la fórmula ni
/// los datos de hoy. Es la diferencia entre explicar el número que está en el recibo
/// y explicar el número que saldría si se recalculara ahora — que pueden no ser el
/// mismo, porque entre una cosa y otra pudo cambiar una fórmula, un parámetro o una
/// vigencia.
///
/// El orden y el signo de cada paso salen de la propia fórmula, vía la traza del
/// evaluador. No hay configuración que mantener y no puede desincronizarse: si
/// alguien edita la fórmula, el paso a paso cambia con ella.
///
/// Y TERMINA CON UN CONTROL. La última fila compara lo reconstruido contra el
/// importe guardado en la línea. Si no coinciden, la página lo dice en vez de
/// mostrar una explicación que no corresponde al número que se pagó.
/// </summary>
codeunit 110044 "Detalle Cálculo Línea"
{
    var
        TxtTotal: Label 'TOTAL — resultado de la fórmula';
        TxtCoincide: Label 'Coincide con el importe de la línea';
        TxtNoCoincide: Label 'NO COINCIDE con el importe de la línea (%1). La fórmula o los datos cambiaron desde que se calculó.', Comment = '%1 = importe guardado';
        TxtSinFormula: Label 'La línea no tiene fórmula guardada: nada que explicar.';
        TxtSubtotal: Label 'Subtotal del bloque';
        TxtSinTraza: Label 'La fórmula no es una suma de términos, así que no hay paso a paso. El valor sale de una sola expresión.';

    /// <summary>
    /// Llena <paramref name="Pasos"/> (temporal) con el paso a paso de la línea.
    /// </summary>
    procedure Construir(LinLiq: Record "Línea Liquidación"; var Pasos: Record "Paso Cálculo Línea")
    var
        Liq: Record "Liquidación";
        Evaluador: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Resultado: Decimal;
        Traza: Text;
        Formula: Text;
    begin
        Pasos.Reset();
        Pasos.DeleteAll();

        Formula := LinLiq."Fórmula Aplicada";
        if Formula.Trim() = '' then begin
            AgregarNota(Pasos, TxtSinFormula);
            exit;
        end;

        if not Liq.Get(LinLiq."No. Liquidación") then
            exit;

        CargarContexto(LinLiq, Ctx);

        Evaluador.Init(Ctx, Liq."Fecha Liquidación");
        // Tolerante a propósito: si una variable que se usó aquel día ya no existe, el paso a paso
        // tiene que poder armarse igual y dejar que el control final avise de la diferencia. Fallar
        // con un error dejaría al usuario sin ninguna explicación, que es peor que una incompleta.
        Evaluador.SetLenientMode(true);
        SembrarReferencias(LinLiq, Evaluador);

        Evaluador.ActivarTraza(true);
        Evaluador.TryEvalFormula(Formula, Resultado);
        Traza := Evaluador.GetTraza();
        Evaluador.ActivarTraza(false);

        if Traza = '' then begin
            AgregarNota(Pasos, TxtSinTraza);
            AgregarTotal(Pasos, LinLiq, Resultado);
            exit;
        end;

        VolcarTraza(Traza, LinLiq, Pasos);
        AgregarTotal(Pasos, LinLiq, Resultado);
    end;

    /// <summary>
    /// Reconstruye el contexto de variables desde el detalle guardado. Las referencias @CÓDIGO y
    /// #CÓDIGO se guardan CON el prefijo para que se vea cuál de los dos mecanismos se usó, pero
    /// en el contexto viven bajo el código pelado — ver WriteVariableDetail en el motor.
    /// </summary>
    local procedure CargarContexto(LinLiq: Record "Línea Liquidación"; var Ctx: Dictionary of [Text, Decimal])
    var
        Det: Record "Detalle Variable Línea Liq.";
        Clave: Text;
    begin
        Det.SetRange("No. Liquidación", LinLiq."No. Liquidación");
        Det.SetRange("No. Línea", LinLiq."No. Línea");
        if not Det.FindSet() then exit;
        repeat
            Clave := Det."Nombre Variable";
            if Clave.StartsWith('@') or Clave.StartsWith('#') then
                Clave := CopyStr(Clave, 2);
            if Ctx.ContainsKey(Clave) then
                Ctx.Set(Clave, Det.Valor)
            else
                Ctx.Add(Clave, Det.Valor);
        until Det.Next() = 0;
    end;

    local procedure SembrarReferencias(LinLiq: Record "Línea Liquidación"; var Evaluador: Codeunit "Evaluador Fórmula")
    var
        Det: Record "Detalle Variable Línea Liq.";
        Clave: Text;
    begin
        Det.SetRange("No. Liquidación", LinLiq."No. Liquidación");
        Det.SetRange("No. Línea", LinLiq."No. Línea");
        if not Det.FindSet() then exit;
        repeat
            Clave := Det."Nombre Variable";
            if Clave.StartsWith('@') or Clave.StartsWith('#') then
                Evaluador.SeedConceptoRef(CopyStr(Clave, 2), Det.Valor);
        until Det.Next() = 0;
    end;

    /// <summary>
    /// Vuelca la traza a la tabla temporal EN EL ORDEN EN QUE SE CALCULÓ, cerrando cada bloque
    /// anidado con su subtotal.
    ///
    /// El evaluador anota cada término recién cuando terminó de calcularlo, así que un bloque
    /// anidado aparece antes del término que lo consume. Eso es exactamente el orden en que se
    /// hace la cuenta —se arma la base, después se le aplica el tramo— y es como uno la explicaría
    /// en papel. La fila de subtotal que cierra cada bloque es la que lo vuelve legible: sin ella
    /// la columna Acumulado cambia de sujeto en silencio al pasar de una cadena a la de afuera.
    ///
    /// En ganancias eso deja "= 5.406.765,39" pegado arriba del TRAMO, cuyo detalle dice
    /// "base 5.406.765,39": los dos números se tocan y la conexión se ve sin buscarla.
    /// </summary>
    local procedure VolcarTraza(Traza: Text; LinLiq: Record "Línea Liquidación"; var Pasos: Record "Paso Cálculo Línea")
    var
        Filas: List of [Text];
        Campos: List of [Text];
        Niveles: List of [Integer];
        Fila: Text;
        NoPaso: Integer;
        Valor: Decimal;
        Acumulado: Decimal;
        NivelMin: Integer;
        Nivel: Integer;
        i: Integer;
        Idx: Integer;
    begin
        // Primera pasada: quedarse con las filas útiles y su nivel.
        foreach Fila in Traza.Split(LfChar()) do
            if Fila.Trim() <> '' then begin
                Campos := Fila.Split(TabChar());
                if Campos.Count() >= 6 then begin
                    Filas.Add(Fila);
                    Evaluate(Nivel, Campos.Get(1));
                    Niveles.Add(Nivel);
                end;
            end;
        if Filas.Count() = 0 then exit;

        NivelMin := Niveles.Get(1);
        for i := 1 to Niveles.Count() do
            if Niveles.Get(i) < NivelMin then
                NivelMin := Niveles.Get(i);

        for Idx := 1 to Filas.Count() do begin
            Campos := Filas.Get(Idx).Split(TabChar());
            NoPaso += 1;
            Pasos.Init();
            Pasos."No. Paso" := NoPaso;
            Evaluate(Nivel, Campos.Get(1));
            Pasos.Nivel := Nivel - NivelMin; // 0-based: lo consume IndentationColumn
            Evaluate(Pasos.Orden, Campos.Get(2));
            Pasos.Signo := CopyStr(Campos.Get(3), 1, 1);
            // FORMATO 9 EN LAS DOS PUNTAS. La traza escribe los decimales con Format(...,9), que es
            // el formato XML y usa punto decimal; leerlos con un Evaluate normal los interpretaría
            // con la configuración regional —coma en español— y devolvería cero sin fallar, porque
            // Evaluate informa el error por su valor de retorno y nadie lo mira. Toda la página
            // mostraría ceros y parecería un problema de datos.
            if not Evaluate(Valor, Campos.Get(4), 9) then
                Valor := 0;
            if not Evaluate(Acumulado, Campos.Get(5), 9) then
                Acumulado := 0;
            Pasos.Valor := Valor;
            Pasos.Acumulado := Acumulado;
            // EL TÉRMINO VA LIMPIO. La sangría la dibuja el árbol de la página a partir de
            // "Nivel" — antes se simulaba con puntos adentro del texto, porque una columna de
            // espacios la recorta el cliente web. Con ShowAsTree eso sobra, y además cada rama
            // se puede plegar: se ve la narración de tres pasos y se abre la base sólo si hace
            // falta.
            Pasos.Término := CopyStr(Resumir(Campos.Get(6)), 1, MaxStrLen(Pasos.Término));
            Pasos.Descripción := CopyStr(DescribirTermino(Campos.Get(6)), 1, MaxStrLen(Pasos.Descripción));
            Pasos.Detalle := CopyStr(BuscarDetalle(LinLiq, Campos.Get(6)), 1, MaxStrLen(Pasos.Detalle));
            Pasos.Insert();

            // ¿Terminó acá un bloque anidado? Termina cuando la fila siguiente es MENOS profunda:
            // el término que la consume ya está en la cadena de afuera. La última fila de todas no
            // cierra bloque — de esa se ocupa la fila TOTAL.
            if Idx < Filas.Count() then
                if Niveles.Get(Idx + 1) < Niveles.Get(Idx) then begin
                    NoPaso += 1;
                    Pasos.Init();
                    Pasos."No. Paso" := NoPaso;
                    Pasos.Nivel := Niveles.Get(Idx) - NivelMin;
                    Pasos.Signo := '=';
                    Pasos.Término := CopyStr(TxtSubtotal, 1, MaxStrLen(Pasos.Término));
                    Pasos.Acumulado := Acumulado;
                    Pasos."Es Subtotal" := true;
                    Pasos.Insert();
                end;
        end;
    end;

        /// <summary>
    /// Traduce el término a castellano cuando se puede. Se prueban las tres tablas donde puede
    /// vivir un nombre, en el mismo orden en que las resuelve el evaluador. Si el término es una
    /// expresión y no un nombre suelto —"(A + B) / 12"— no hay nada que traducir y se deja vacío:
    /// el texto de la fórmula ya se muestra en su propia columna.
    /// </summary>
    local procedure DescribirTermino(Termino: Text): Text
    var
        Concepto: Record "Concepto Liquidación";
        Param: Record "Parámetro";
        VarSis: Record "Variable Sistema Liq.";
        Nombre: Text;
    begin
        Nombre := Termino.Trim().ToUpper();
        if (Nombre = '') or (StrPos(Nombre, ' ') > 0) or (StrPos(Nombre, '(') > 0) then
            exit('');

        if Nombre.StartsWith('@') or Nombre.StartsWith('#') then
            Nombre := CopyStr(Nombre, 2);

        Concepto.SetRange(Código, CopyStr(Nombre, 1, 20));
        if Concepto.FindLast() then
            exit(Concepto.Descripción);

        VarSis.SetRange("Nombre Variable", CopyStr(Nombre, 1, 50));
        if VarSis.FindFirst() then
            exit(VarSis.Descripción);

        Param.SetRange("Nombre Variable", CopyStr(Nombre, 1, 50));
        if Param.FindFirst() then
            exit(Param.Descripción);

        exit('');
    end;

    /// <summary>
    /// Un término largo, mostrado entero, es ilegible: la llamada a TRAMO de ganancias lleva toda
    /// la base adentro y ocupa más de 250 caracteres. Se la resume a "FUNCIÓN(primer argumento, …)",
    /// que es lo que identifica la llamada. La fórmula completa sigue arriba, en el encabezado.
    /// </summary>
    local procedure Resumir(Termino: Text): Text
    var
        PosPar: Integer;
        PosComa: Integer;
    begin
        Termino := Termino.Trim();
        if StrLen(Termino) <= 60 then
            exit(Termino);

        PosPar := StrPos(Termino, '(');
        if PosPar = 0 then
            exit(CopyStr(Termino, 1, 57) + '…');

        PosComa := StrPos(CopyStr(Termino, PosPar), ',');
        if (PosComa = 0) or (PosPar + PosComa > 60) then
            exit(CopyStr(Termino, 1, 57) + '…');

        exit(CopyStr(Termino, 1, PosPar + PosComa - 1) + ' …)');
    end;

    /// <summary>
    /// El texto de auditoría del término, si lo tiene. El caso que importa es TRAMO, que deja
    /// escrito qué tramo aplicó, de qué vigencia y con qué porcentaje — justo lo que uno quiere
    /// ver al lado del número.
    /// </summary>
    local procedure BuscarDetalle(LinLiq: Record "Línea Liquidación"; Termino: Text): Text
    var
        Det: Record "Detalle Variable Línea Liq.";
        Aguja: Text;
    begin
        if Termino.Trim() = '' then exit('');
        Det.SetRange("No. Liquidación", LinLiq."No. Liquidación");
        Det.SetRange("No. Línea", LinLiq."No. Línea");
        Det.SetFilter(Detalle, '<>%1', '');
        if not Det.FindSet() then exit('');
        repeat
            // SE COMPARA NORMALIZANDO LAS DOS PUNTAS. El detalle se llama "TRAMO(TAB_IMP_4CAT)" y
            // el término está escrito "TRAMO( 'TAB_IMP_4CAT', …)": con el espacio y las comillas,
            // una contención literal nunca coincide. Se sacan espacios, comillas y el paréntesis
            // de cierre de la aguja, y recién ahí se busca.
            Aguja := Normalizar(Det."Nombre Variable");
            if (Aguja <> '') and (StrPos(Normalizar(Termino), Aguja) > 0) then
                exit(Det.Detalle);
        until Det.Next() = 0;
        exit('');
    end;

    local procedure Normalizar(Txt: Text): Text
    begin
        Txt := Txt.ToUpper().Replace(' ', '').Replace('''', '').Replace('"', '');
        // El paréntesis de cierre se saca sólo del final: "TRAMO(TAB_IMP_4CAT)" tiene que poder
        // encontrarse dentro de "TRAMO(TAB_IMP_4CAT,BASE…)", donde ese paréntesis está mucho
        // más lejos.
        if Txt.EndsWith(')') then
            Txt := CopyStr(Txt, 1, StrLen(Txt) - 1);
        exit(Txt);
    end;

    local procedure AgregarTotal(var Pasos: Record "Paso Cálculo Línea"; LinLiq: Record "Línea Liquidación"; Resultado: Decimal)
    var
        Ultimo: Integer;
    begin
        Pasos.Reset();
        if Pasos.FindLast() then
            Ultimo := Pasos."No. Paso";

        Pasos.Init();
        Pasos."No. Paso" := Ultimo + 1;
        Pasos."Es Total" := true;
        Pasos.Término := CopyStr(TxtTotal, 1, MaxStrLen(Pasos.Término));
        Pasos.Valor := Resultado;
        Pasos.Acumulado := Resultado;
        // El control. Se compara con tolerancia de un centavo porque el importe de la línea pasó
        // por el redondeo del concepto y el resultado crudo de la fórmula no.
        if Abs(Resultado - LinLiq.Importe) <= 0.01 then
            Pasos.Descripción := CopyStr(TxtCoincide, 1, MaxStrLen(Pasos.Descripción))
        else
            Pasos.Descripción := CopyStr(StrSubstNo(TxtNoCoincide, Format(LinLiq.Importe)), 1, MaxStrLen(Pasos.Descripción));
        Pasos.Insert();
    end;

    local procedure AgregarNota(var Pasos: Record "Paso Cálculo Línea"; Nota: Text)
    begin
        Pasos.Init();
        Pasos."No. Paso" := 1;
        Pasos.Descripción := CopyStr(Nota, 1, MaxStrLen(Pasos.Descripción));
        Pasos.Insert();
    end;

    // Tienen que coincidir con los del evaluador: es el mismo formato de traza en las dos puntas.
    local procedure TabChar(): Text
    var
        C: Char;
    begin
        C := 9;
        exit(Format(C));
    end;

    local procedure LfChar(): Text
    var
        C: Char;
    begin
        C := 10;
        exit(Format(C));
    end;
}
