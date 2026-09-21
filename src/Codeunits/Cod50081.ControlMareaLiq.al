namespace UAS.Payroll;

using Microsoft.Finance.Currency;

/// <summary>
/// Arma el control de liquidación de una marea: resumen por concepto y detalle por empleado.
/// </summary>
/// <remarks>
/// Es la versión hecha por el sistema de lo que el liquidador venía armando a mano en Excel: exportar
/// las líneas de una liquidación, ponerlas al lado de los importes del sistema anterior y sacar la
/// diferencia concepto por concepto. Acá salen las de TODA la tripulación de una vez, en el mismo
/// orden de cálculo, para poder pegar la columna de comparación al costado.
///
/// El resumen se acumula sobre la marcha y no con un segundo recorrido: las dos secciones se llenan
/// en la misma pasada por las líneas.
/// </remarks>
codeunit 50081 "Control Marea Liq."
{
    Access = Public;

    /// <summary>
    /// Llena Buffer con las dos secciones de un proyecto. Devuelve cuántas liquidaciones entraron.
    /// </summary>
    /// <remarks>
    /// Entran todas las liquidaciones del proyecto, en cualquier estado. Un control que escondiera
    /// los borradores serviría solo después de aprobar, que es cuando ya no se puede corregir nada.
    /// </remarks>
    procedure Construir(var Buffer: Record "Control Marea Buffer" temporary; NoProyecto: Code[20]) Liquidaciones: Integer
    var
        Liq: Record "Liquidación";
        Lin: Record "Línea Liquidación";
    begin
        Buffer.Reset();
        Buffer.DeleteAll();
        if NoProyecto = '' then
            exit(0);

        Liq.SetCurrentKey("No. Proyecto");
        Liq.SetRange("No. Proyecto", NoProyecto);
        if not Liq.FindSet() then
            exit(0);

        repeat
            Liquidaciones += 1;
            Lin.SetCurrentKey("No. Liquidación", "Orden Cálculo", "No. Línea");
            Lin.SetRange("No. Liquidación", Liq."No.");
            if Lin.FindSet() then
                repeat
                    AgregarDetalle(Buffer, Liq, Lin);
                    AcumularEnResumen(Buffer, Lin);
                until Lin.Next() = 0;
        until Liq.Next() = 0;

        ConstruirDiferencias(Buffer);

        Buffer.Reset();
        Buffer.SetCurrentKey(Sección, "Orden Cálculo", "Cód. Concepto");
        if Buffer.FindFirst() then;
    end;

    /// <summary>
    /// Agrega la sección Diferencia: quién cobró distinto que la mayoría de su misma categoría.
    /// </summary>
    /// <remarks>
    /// Es la lista corta que hace falta para cerrar una marea. La matriz de conceptos por tripulante
    /// tiene la misma información, pero repartida en cientos de celdas: el ojo no encuentra ahí al que
    /// cobró cien pesos de más.
    ///
    /// Solo conceptos que imprimen en recibo. Sin ese filtro, cada diferencia real en un haber
    /// arrastraba su contribución patronal y sus acumuladores, y un solo caso aparecía como tres o
    /// cuatro filas — entre las que se perdían las que importaban.
    ///
    /// Los tripulantes sin línea del concepto cuentan como cero al buscar el valor habitual, a
    /// propósito: si a seis de ocho no les salió, lo habitual de esa categoría es no cobrarlo y los
    /// dos que lo cobraron son justamente lo que hay que mirar.
    /// </remarks>
    local procedure ConstruirDiferencias(var Buffer: Record "Control Marea Buffer" temporary)
    var
        Det: Record "Control Marea Buffer" temporary;
        // Tabla temporal PROPIA, no una vista compartida del buffer: las diferencias se arman
        // mientras se recorre el detalle, y escribir en la misma tabla que se está recorriendo es la
        // clase de cosa que funciona hasta que un día deja de funcionar. Se vuelcan al final.
        Difs: Record "Control Marea Buffer" temporary;
        Importes: Dictionary of [Text, Decimal];
        CatDeEmpleado: Dictionary of [Code[20], Text];
        Empleados: List of [Code[20]];
        Conceptos: List of [Text];
        Habitual: Dictionary of [Text, Decimal];
        Clave: Text;
        Cat: Text;
        Emp: Code[20];
        Importe: Decimal;
    begin
        Det.Copy(Buffer, true);
        Det.Reset();
        Det.SetRange(Sección, Det.Sección::Detalle);
        if not Det.FindSet() then
            exit;

        repeat
            if Det."Imprime en Recibo" then begin
                Clave := ClaveConcepto(Det."Orden Cálculo", Det."Cód. Concepto");
                if not Conceptos.Contains(Clave) then
                    Conceptos.Add(Clave);
                if not Empleados.Contains(Det."No. Empleado") then
                    Empleados.Add(Det."No. Empleado");
                CatDeEmpleado.Set(Det."No. Empleado", Det."Categoría Empleado");
                Acumular(Importes, Clave + '~' + Det."No. Empleado", Det.Importe);
            end;
        until Det.Next() = 0;

        CalcularHabituales(Habitual, Importes, Conceptos, Empleados, CatDeEmpleado);

        Det.Reset();
        Det.SetRange(Sección, Det.Sección::Detalle);
        if Det.FindSet() then
            repeat
                if Det."Imprime en Recibo" then begin
                    Clave := ClaveConcepto(Det."Orden Cálculo", Det."Cód. Concepto");
                    Emp := Det."No. Empleado";
                    Cat := CatDeEmpleado.Get(Emp);
                    Importe := Importes.Get(Clave + '~' + Emp);
                    if Importe <> Habitual.Get(Clave + '~' + Cat) then
                        EscribirDiferencia(Difs, Det, Importe, Habitual.Get(Clave + '~' + Cat));
                end;
            until Det.Next() = 0;

        Difs.Reset();
        if Difs.FindSet() then
            repeat
                Buffer := Difs;
                Buffer.Insert();
            until Difs.Next() = 0;
    end;

    local procedure CalcularHabituales(var Habitual: Dictionary of [Text, Decimal]; var Importes: Dictionary of [Text, Decimal]; var Conceptos: List of [Text]; var Empleados: List of [Code[20]]; var CatDeEmpleado: Dictionary of [Code[20], Text])
    var
        Categorias: List of [Text];
        Claves: List of [Text];
        Clave: Text;
        Cat: Text;
        Emp: Code[20];
    begin
        foreach Emp in Empleados do
            if not Categorias.Contains(CatDeEmpleado.Get(Emp)) then
                Categorias.Add(CatDeEmpleado.Get(Emp));

        foreach Clave in Conceptos do
            foreach Cat in Categorias do begin
                Clear(Claves);
                foreach Emp in Empleados do
                    if CatDeEmpleado.Get(Emp) = Cat then
                        Claves.Add(Clave + '~' + Emp);
                Habitual.Set(Clave + '~' + Cat, ValorHabitual(Importes, Claves));
            end;
    end;

    /// <summary>
    /// El valor que más se repite entre las claves indicadas. Las ausentes cuentan como cero.
    /// </summary>
    /// <remarks>
    /// Una sola implementación de la regla, compartida con el informe en Excel: si la pantalla y la
    /// planilla decidieran por separado cuál es el valor habitual, el día que difieran nadie sabría
    /// cuál de las dos creer.
    ///
    /// Empate (dos valores con la misma cantidad de tripulantes) lo gana el primero que apareció.
    /// </remarks>
    procedure ValorHabitual(var Valores: Dictionary of [Text, Decimal]; var Claves: List of [Text]): Decimal
    var
        Conteo: Dictionary of [Text, Integer];
        Clave: Text;
        ClaveValor: Text;
        Valor: Decimal;
        Habitual: Decimal;
        MasVisto: Integer;
    begin
        foreach Clave in Claves do begin
            Valor := 0;
            if Valores.ContainsKey(Clave) then
                Valor := Valores.Get(Clave);
            ClaveValor := Format(Valor, 0, '<Precision,2:5><Standard Format,0>');
            if Conteo.ContainsKey(ClaveValor) then
                Conteo.Set(ClaveValor, Conteo.Get(ClaveValor) + 1)
            else
                Conteo.Add(ClaveValor, 1);
            // Estrictamente mayor: ante un empate gana el que se vio primero.
            if Conteo.Get(ClaveValor) > MasVisto then begin
                MasVisto := Conteo.Get(ClaveValor);
                Habitual := Valor;
            end;
        end;
        exit(Habitual);
    end;

    local procedure EscribirDiferencia(var Buffer: Record "Control Marea Buffer" temporary; var Det: Record "Control Marea Buffer" temporary; Importe: Decimal; Habitual: Decimal)
    begin
        Buffer.Init();
        Buffer.Sección := Buffer.Sección::Diferencia;
        Buffer."No. Empleado" := Det."No. Empleado";
        Buffer."Orden Cálculo" := Det."Orden Cálculo";
        Buffer."Cód. Concepto" := Det."Cód. Concepto";
        Buffer."No. Línea" := 0;
        Buffer."Nombre Empleado" := Det."Nombre Empleado";
        Buffer."Nombre Impresión" := Det."Nombre Impresión";
        Buffer."Tipo Concepto" := Det."Tipo Concepto";
        Buffer."Convenio Empleado" := Det."Convenio Empleado";
        Buffer."Categoría Empleado" := Det."Categoría Empleado";
        Buffer."Imprime en Recibo" := true;
        Buffer.Importe := Importe;
        Buffer."Importe Habitual" := Habitual;
        Buffer.Diferencia := Importe - Habitual;
        Buffer."No. Liquidación" := Det."No. Liquidación";
        // Un concepto puede haber dado varias líneas al mismo tripulante; la diferencia es una sola,
        // sobre el total, y por eso la inserción se ignora si ya está.
        if Buffer.Insert() then;
    end;

    local procedure ClaveConcepto(Orden: Integer; Codigo: Code[20]): Text
    begin
        exit(Format(Orden, 6, '<Integer,6><Filler Character,0>') + '|' + Codigo);
    end;

    local procedure Acumular(var Mapa: Dictionary of [Text, Decimal]; Clave: Text; Valor: Decimal)
    begin
        if Mapa.ContainsKey(Clave) then
            Mapa.Set(Clave, Mapa.Get(Clave) + Valor)
        else
            Mapa.Add(Clave, Valor);
    end;

    // ── Datos de cálculo de la marea ──────────────────────────────────────────
    //
    // Todo lo de acá abajo sale de lo que el motor YA calculó y dejó guardado, no de volver a
    // calcularlo. Un control que recalcula por su cuenta puede diferir del recibo y entonces no
    // controla nada: dice lo que habría dado, no lo que dio.

    /// <summary>
    /// Deja en Comunes las variables de cálculo que valen lo mismo para TODA la tripulación.
    /// </summary>
    /// <remarks>
    /// Eso es exactamente lo que hace que una variable sea "de la marea" y no del tripulante: días de
    /// navegación, días de puerto, kilos del buque, tipo de cambio, parámetros del convenio. No hay
    /// que enumerarlas ni configurarlas — se descubren solas comparando entre liquidaciones, así que
    /// una fuente de datos nueva aparece acá sin tocar código.
    ///
    /// "Común" exige estar en todas las liquidaciones con el mismo valor. Una variable que a un
    /// tripulante le dio distinto no es un dato de la marea: es justo lo que hay que ir a mirar al
    /// detalle, y ponerla acá con el valor de la mayoría la escondería.
    ///
    /// El buffer se llena con No. Liquidación en blanco: ya no pertenece a ninguna.
    /// </remarks>
    procedure ConstruirVariablesComunes(var Comunes: Record "Resumen Variable Liq." temporary; NoProyecto: Code[20]; Convenio: Code[20]; Categoria: Code[20])
    var
        Liq: Record "Liquidación";
        Res: Record "Resumen Variable Liq.";
        Descartadas: List of [Code[30]];
        Vistas: Integer;
    begin
        Comunes.Reset();
        Comunes.DeleteAll();
        FiltrarLiq(Liq, NoProyecto, Convenio, Categoria);
        if not Liq.FindSet() then
            exit;

        repeat
            Vistas += 1;
            Res.SetRange("No. Liquidación", Liq."No.");
            if Vistas = 1 then begin
                if Res.FindSet() then
                    repeat
                        Comunes := Res;
                        Comunes."No. Liquidación" := '';
                        if Comunes.Insert() then;
                    until Res.Next() = 0;
            end else
                DescartarDiferentes(Comunes, Res, Descartadas);
        until Liq.Next() = 0;

        BorrarDescartadas(Comunes, Descartadas);
    end;

    /// <remarks>
    /// Descarta en dos direcciones: la variable que en esta liquidación vale otra cosa, y la que acá
    /// directamente no está. La segunda es la que se olvida: un concepto que no le aplicó a un
    /// tripulante deja su variable sin fila, y si solo se compararan las presentes, el valor de los
    /// demás pasaría por dato de toda la marea.
    /// </remarks>
    local procedure DescartarDiferentes(var Comunes: Record "Resumen Variable Liq." temporary; var Res: Record "Resumen Variable Liq."; var Descartadas: List of [Code[30]])
    var
        Presentes: List of [Code[30]];
    begin
        if Res.FindSet() then
            repeat
                Presentes.Add(Res."Nombre Variable");
                if Comunes.Get('', Res."Nombre Variable") then
                    if (Comunes.Valor <> Res.Valor) or (Comunes."Valor Texto" <> Res."Valor Texto") then
                        if not Descartadas.Contains(Comunes."Nombre Variable") then
                            Descartadas.Add(Comunes."Nombre Variable");
            until Res.Next() = 0;

        Comunes.Reset();
        if Comunes.FindSet() then
            repeat
                if not Presentes.Contains(Comunes."Nombre Variable") then
                    if not Descartadas.Contains(Comunes."Nombre Variable") then
                        Descartadas.Add(Comunes."Nombre Variable");
            until Comunes.Next() = 0;
    end;

    local procedure BorrarDescartadas(var Comunes: Record "Resumen Variable Liq." temporary; var Descartadas: List of [Code[30]])
    var
        Nombre: Code[30];
    begin
        foreach Nombre in Descartadas do
            if Comunes.Get('', Nombre) then
                Comunes.Delete();
        Comunes.Reset();
        if Comunes.FindFirst() then;
    end;

    /// <summary>
    /// Valor de una variable de sistema en la marea, buscada por su Cód. Cálculo.
    /// </summary>
    /// <remarks>
    /// Por Cód. Cálculo y no por nombre: el nombre de la variable lo elige quien configura —DIAS_NAV,
    /// DIAS_NAVEGACION, DIAS_MAR—, y el Cód. Cálculo es lo que el motor entiende. Hardcodear el
    /// nombre haría que el dato desapareciera de la cabecera el día que alguien la renombre.
    /// </remarks>
    procedure ValorVariableSistema(var Comunes: Record "Resumen Variable Liq." temporary; CodCalculo: Code[30]): Decimal
    var
        VarSis: Record "Variable Sistema Liq.";
    begin
        VarSis.SetRange("Cód. Cálculo", CodCalculo);
        if not VarSis.FindFirst() then
            exit(0);
        if not Comunes.Get('', VarSis."Nombre Variable") then
            exit(0);
        exit(Comunes.Valor);
    end;

    /// <summary>Neto mínimo, máximo y promedio de la tripulación, para detectar un neto fuera de rango.</summary>
    procedure Netos(NoProyecto: Code[20]; Convenio: Code[20]; Categoria: Code[20]; var Minimo: Decimal; var Maximo: Decimal; var Promedio: Decimal)
    var
        Liq: Record "Liquidación";
        Suma: Decimal;
        Cuantas: Integer;
    begin
        Minimo := 0;
        Maximo := 0;
        Promedio := 0;
        FiltrarLiq(Liq, NoProyecto, Convenio, Categoria);
        Liq.SetLoadFields("Neto a Pagar");
        if not Liq.FindSet() then
            exit;
        repeat
            Cuantas += 1;
            Suma += Liq."Neto a Pagar";
            if (Cuantas = 1) or (Liq."Neto a Pagar" < Minimo) then
                Minimo := Liq."Neto a Pagar";
            if (Cuantas = 1) or (Liq."Neto a Pagar" > Maximo) then
                Maximo := Liq."Neto a Pagar";
        until Liq.Next() = 0;
        Promedio := Round(Suma / Cuantas, 0.01);
    end;

    /// <summary>
    /// Los tipos de cambio con los que se liquidó la marea, como "USD 1.045,50".
    /// </summary>
    /// <remarks>
    /// La moneda no se elige acá: se descubre a partir de los parámetros que las liquidaciones
    /// efectivamente usaron (Uso Parámetro Liq. → Parámetro Vigente.Moneda). Y la cotización se pide
    /// con la misma llamada que hace el motor —ExchangeRate a la fecha de la liquidación—, así que es
    /// el número con el que se calculó y no uno parecido de hoy.
    ///
    /// Si hubiera más de una moneda salen todas: enseñar una sola sería elegir por el liquidador.
    /// </remarks>
    procedure TiposDeCambio(NoProyecto: Code[20]; Convenio: Code[20]; Categoria: Code[20]): Text
    var
        Liq: Record "Liquidación";
        Uso: Record "Uso Parámetro Liq.";
        ParVig: Record "Parámetro Vigente";
        Monedas: List of [Code[10]];
        Vistas: List of [Text];
        ClaveVersion: Text;
        Resultado: Text;
    begin
        FiltrarLiq(Liq, NoProyecto, Convenio, Categoria);
        Liq.SetLoadFields("No.", "Fecha Liquidación");
        if not Liq.FindSet() then
            exit('');

        repeat
            Uso.SetRange("No. Liquidación", Liq."No.");
            Uso.SetLoadFields("Cód. Parámetro", "Vigencia Desde");
            if Uso.FindSet() then
                repeat
                    // Toda la tripulación usa prácticamente las mismas versiones de parámetro, así
                    // que sin este descarte se repetiría la misma búsqueda una vez por tripulante.
                    ClaveVersion := Uso."Cód. Parámetro" + '|' + Format(Uso."Vigencia Desde", 0, 9);
                    if not Vistas.Contains(ClaveVersion) then begin
                        Vistas.Add(ClaveVersion);
                        // Por la clave secundaria y no con Get: la primaria de Parámetro Vigente
                        // empieza por "Cód. Parámetro Base" (Code[20]), así que un Get con la clave
                        // DERIVADA —que es Code[50] y suele ser más larga— la mete en el campo
                        // equivocado y revienta por longitud. Además el campo base puede estar vacío
                        // en filas viejas, y ahí el Get tampoco encontraría nada.
                        ParVig.Reset();
                        ParVig.SetCurrentKey("Cód. Parámetro", "Vigencia Desde");
                        ParVig.SetRange("Cód. Parámetro", Uso."Cód. Parámetro");
                        ParVig.SetRange("Vigencia Desde", Uso."Vigencia Desde");
                        ParVig.SetLoadFields(Moneda);
                        if ParVig.FindFirst() then
                            if (ParVig.Moneda <> '') and not Monedas.Contains(ParVig.Moneda) then begin
                                Monedas.Add(ParVig.Moneda);
                                if Resultado <> '' then
                                    Resultado += '   ';
                                Resultado += Cotizacion(ParVig.Moneda, Liq."Fecha Liquidación");
                            end;
                    end;
                until Uso.Next() = 0;
        until Liq.Next() = 0;

        if Resultado = '' then
            exit(TxtSinMonedaExtranjera);
        exit(Resultado);
    end;

    /// <summary>
    /// La cotización de una moneda a una fecha, en la orientación en que se lee: "USD 1.045,5000 al
    /// 31/07/26" = cuántos pesos vale un dólar.
    /// </summary>
    /// <remarks>
    /// OJO con ExchangeRate: NO devuelve la cotización sino el factor, que es su inversa
    /// ("Exchange Rate Amount" / "Relational Exch. Rate Amount"). Con el dólar a 1.045,50 devuelve
    /// 0,000956. Es el número correcto para pasarle a ExchangeAmtFCYToLCY —y por eso el motor lo usa
    /// así en la convergencia de Grossing Up— pero mostrarlo tal cual no dice nada.
    ///
    /// Se invierte en lugar de leer los campos de la cotización a mano: FindCurrency resuelve además
    /// las cadenas de moneda relacional, y rehacer esa lógica acá abriría la puerta a que el control
    /// muestre un tipo de cambio distinto del que se usó para liquidar.
    ///
    /// ExchangeRate hace TestField y por lo tanto FALLA si no hay cotización a esa fecha. En un
    /// control eso cerraría la página entera por un dato accesorio, así que primero se verifica que
    /// exista alguna y, si no, se lo dice.
    /// </remarks>
    local procedure Cotizacion(Moneda: Code[10]; Fecha: Date): Text
    var
        CurrExchRate: Record "Currency Exchange Rate";
        Factor: Decimal;
    begin
        CurrExchRate.SetRange("Currency Code", Moneda);
        CurrExchRate.SetRange("Starting Date", 0D, Fecha);
        if not CurrExchRate.FindLast() then
            exit(StrSubstNo(TxtSinCotizacion, Moneda, Fecha));

        Factor := CurrExchRate.ExchangeRate(Fecha, Moneda);
        if Factor = 0 then
            exit(StrSubstNo(TxtSinCotizacion, Moneda, Fecha));

        exit(StrSubstNo(TxtCotizacion, Moneda,
            Format(1 / Factor, 0, '<Precision,2:4><Standard Format,0>'),
            Format(CurrExchRate."Starting Date")));
    end;

    local procedure FiltrarLiq(var Liq: Record "Liquidación"; NoProyecto: Code[20]; Convenio: Code[20]; Categoria: Code[20])
    begin
        Liq.Reset();
        Liq.SetCurrentKey("No. Proyecto");
        Liq.SetRange("No. Proyecto", NoProyecto);
        if Convenio <> '' then
            Liq.SetRange("Cód. Convenio", Convenio);
        if Categoria <> '' then
            Liq.SetRange("Cód. Categoría", Categoria);
    end;

    local procedure AgregarDetalle(var Buffer: Record "Control Marea Buffer" temporary; var Liq: Record "Liquidación"; var Lin: Record "Línea Liquidación")
    begin
        Buffer.Init();
        Buffer.Sección := Buffer.Sección::Detalle;
        Buffer."No. Empleado" := Liq."No. Empleado";
        Buffer."Orden Cálculo" := Lin."Orden Cálculo";
        Buffer."Cód. Concepto" := Lin."Cód. Concepto";
        Buffer."No. Línea" := Lin."No. Línea";
        Buffer."Nombre Empleado" := Liq."Nombre Empleado";
        Buffer."Nombre Impresión" := Lin."Nombre Impresión";
        Buffer."Tipo Concepto" := Lin."Tipo Concepto";
        Buffer."Imprime en Recibo" := Lin."Imprime en Recibo";
        Buffer.Cantidad := Lin.Cantidad;
        Buffer."Unidad Cantidad" := CopyStr(Lin."Unidad Cantidad", 1, MaxStrLen(Buffer."Unidad Cantidad"));
        Buffer."Base Cálculo" := Lin."Base Cálculo";
        Buffer.Importe := Lin.Importe;
        Buffer."No. Liquidación" := Liq."No.";
        // El par de la LÍNEA, no el de la cabecera: en los conceptos que se liquidan con el convenio
        // de la asignación no son el mismo, y el control tiene que mostrar con cuál se calculó.
        Buffer."Cód. Convenio" := Lin."Cód. Convenio";
        Buffer."Cód. Categoría" := Lin."Cód. Categoría";
        // Y el de la cabecera aparte, que es el encuadre del tripulante y por el que se filtra.
        Buffer."Convenio Empleado" := Liq."Cód. Convenio";
        Buffer."Categoría Empleado" := Liq."Cód. Categoría";
        Buffer.Insert();
    end;

    /// <remarks>
    /// El contador de empleados cuenta LIQUIDACIONES con ese concepto y no líneas: si un concepto le
    /// generó dos líneas al mismo tripulante —el consumo de francos abre una por lote— sigue siendo
    /// un empleado. Por eso se compara contra la última liquidación anotada en vez de sumar de a uno.
    /// </remarks>
    local procedure AcumularEnResumen(var Buffer: Record "Control Marea Buffer" temporary; var Lin: Record "Línea Liquidación")
    var
        UltimaLiq: Code[20];
    begin
        if Buffer.Get(Buffer.Sección::Resumen, '', Lin."Orden Cálculo", Lin."Cód. Concepto", 0) then begin
            UltimaLiq := Buffer."No. Liquidación";
            Buffer.Cantidad += Lin.Cantidad;
            Buffer.Importe += Lin.Importe;
            if UltimaLiq <> Lin."No. Liquidación" then begin
                Buffer.Empleados += 1;
                Buffer."No. Liquidación" := Lin."No. Liquidación";
            end;
            Buffer.Modify();
            exit;
        end;

        Buffer.Init();
        Buffer.Sección := Buffer.Sección::Resumen;
        Buffer."No. Empleado" := '';
        Buffer."Orden Cálculo" := Lin."Orden Cálculo";
        Buffer."Cód. Concepto" := Lin."Cód. Concepto";
        Buffer."No. Línea" := 0;
        Buffer."Nombre Impresión" := Lin."Nombre Impresión";
        Buffer."Tipo Concepto" := Lin."Tipo Concepto";
        Buffer."Imprime en Recibo" := Lin."Imprime en Recibo";
        Buffer.Cantidad := Lin.Cantidad;
        Buffer."Unidad Cantidad" := CopyStr(Lin."Unidad Cantidad", 1, MaxStrLen(Buffer."Unidad Cantidad"));
        Buffer.Importe := Lin.Importe;
        Buffer.Empleados := 1;
        // Se guarda para saber si la próxima línea del mismo concepto es de otro empleado.
        Buffer."No. Liquidación" := Lin."No. Liquidación";
        Buffer.Insert();
    end;

    var
        TxtSinMonedaExtranjera: Label 'Ningún parámetro en moneda extranjera';
        TxtCotizacion: Label '%1 %2 (cotización del %3)', Comment = '%1=moneda, %2=importe en moneda local por unidad, %3=fecha de la cotización usada';
        TxtSinCotizacion: Label '%1 sin cotización al %2', Comment = '%1=moneda, %2=fecha';
}
