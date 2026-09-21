namespace UAS.Payroll;

using System.IO;
using Microsoft.Projects.Project.Job;

/// <summary>
/// Control de liquidación de una marea en Excel, como matriz de conceptos por categoría.
/// </summary>
/// <remarks>
/// La forma importa y no es un detalle de presentación. En una marea, todos los tripulantes de la
/// misma categoría cobran lo mismo: el control real es mirar UNA columna por categoría y comparar
/// entre ellas y contra el cálculo teórico. Una lista con una fila por empleado y concepto —cientos
/// de filas— no deja ver eso, por más que tenga los mismos números adentro.
///
/// Cada celda muestra lo que cobró la MAYORÍA de esa categoría, no la suma: lo que se controla es
/// cuánto le toca a un Capitán, no cuánto se pagó a todos los capitanes juntos. Los totales de la
/// marea van en su propia columna. Ver CalcularHabituales para por qué es la mayoría y no un
/// tripulante elegido de representante.
///
/// Al mostrar un solo número por categoría, esta planilla esconde por construcción a quien se aparte
/// de sus pares. La sección de diferencias al pie es el contrapeso, y recorre los mismos conceptos
/// que la matriz —con importe y que imprimen en recibo—: incluir todos la volvía ilegible, porque
/// cada diferencia real en un haber arrastraba su contribución patronal y sus acumuladores.
/// </remarks>
codeunit 110028 "Control Marea Excel Liq."
{
    Access = Public;

    /// <summary>
    /// Restringe la planilla a los tripulantes encuadrados en ese convenio y esa categoría. Blanco =
    /// sin restricción. Hay que llamarlo ANTES de Generar.
    /// </summary>
    /// <remarks>
    /// Filtra por el par de la CABECERA de la liquidación —el encuadre del tripulante—, igual que el
    /// control en pantalla, para que el Excel que se baja con un filtro puesto muestre exactamente lo
    /// que se estaba mirando. Con una sola categoría filtrada la matriz queda de una columna, que es
    /// justamente la vista para revisar esa categoría contra el cálculo teórico.
    /// </remarks>
    procedure SetFiltro(Convenio: Code[20]; Categoria: Code[20])
    begin
        FFiltroConvenio := Convenio;
        FFiltroCategoria := Categoria;
    end;

    procedure Generar(NoProyecto: Code[20])
    var
        Job: Record Job;
        Libro: Record "Excel Buffer" temporary;
        Filas: List of [Text];
        Nombre: Dictionary of [Text, Text];
    begin
        if NoProyecto = '' then
            Error(ErrSinProyecto);
        if not Job.Get(NoProyecto) then
            Error(ErrSinProyecto);

        FProyecto := NoProyecto;
        Recolectar(NoProyecto);
        if FConceptos.Count() = 0 then
            Error(ErrSinLiquidaciones, NoProyecto);

        FControl.ConstruirVariablesComunes(FComunes, NoProyecto, FFiltroConvenio, FFiltroCategoria);

        Libro.CreateNewBook(CopyStr(StrSubstNo(TxtHoja, NoProyecto), 1, 30));
        EscribirCabecera(Libro, Job);
        EscribirMatriz(Libro);
        EscribirVariablesComunes(Libro);
        Libro.WriteSheet(CopyStr(StrSubstNo(TxtHoja, NoProyecto), 1, 30), CompanyName(), UserId());

        // Las diferencias van en su propia hoja: es una tabla con otra forma y otro largo, y abajo de
        // la matriz obligaba a scrollear la marea entera para llegar. La hoja se crea sólo si hay algo
        // que poner — una segunda hoja vacía hace dudar de si el informe corrió completo.
        if RecolectarDiferencias(Filas, Nombre) > 0 then begin
            // El buffer es el contenido de UNA hoja: hay que vaciarlo y volver el cursor al origen
            // antes de armar la siguiente.
            Libro.Reset();
            Libro.DeleteAll();
            Libro.ClearNewRow();
            EscribirDiferencias(Libro, Filas, Nombre);

            // WriteSheet va UNA sola vez, para la primera hoja: arranca por AddPageSetup sobre el
            // worksheet writer y en una hoja recién agregada eso revienta con "No se ha creado la
            // instancia de la variable DotNet". Las hojas siguientes se escriben con
            // SelectOrAddSheet + WriteAllToCurrentSheet, que solo vuelca el buffer — es el mismo
            // camino que usa "Export Analysis View" en la base para su segunda hoja.
            Libro.SelectOrAddSheet(TxtHojaDif);
            Libro.WriteAllToCurrentSheet(Libro);
        end;

        Libro.CloseBook();
        Libro.OpenExcel();
    end;

    // ── Recolección ───────────────────────────────────────────────────────────

    local procedure Recolectar(NoProyecto: Code[20])
    var
        Liq: Record "Liquidación";
        Lin: Record "Línea Liquidación";
        Categoria: Text;
        ClaveConcepto: Text;
    begin
        Clear(FCategorias);
        Clear(FEtiquetaCat);
        Clear(FOrdenCategoria);
        Clear(FEmpleadosPorCat);
        Clear(FConceptos);
        Clear(FNombreConcepto);
        Clear(FCodigoConcepto);
        Clear(FOrdenConcepto);
        Clear(FImprime);
        Clear(FTipoConcepto);
        Clear(FUnidad);
        Clear(FCantidadRep);
        Clear(FImporteRep);
        Clear(FImporteTotal);
        Clear(FImporteEmpleado);
        Clear(FCantidadEmpleado);
        Clear(FUnidadEmpleado);
        Clear(FCatDeEmpleado);
        Clear(FEmpleados);
        FLiquidaciones := 0;
        FOcultos := 0;
        FImporteOculto := 0;

        Liq.SetCurrentKey("No. Proyecto");
        Liq.SetRange("No. Proyecto", NoProyecto);
        if FFiltroConvenio <> '' then
            Liq.SetRange("Cód. Convenio", FFiltroConvenio);
        if FFiltroCategoria <> '' then
            Liq.SetRange("Cód. Categoría", FFiltroCategoria);
        if not Liq.FindSet() then
            exit;

        // Primera pasada: qué categorías hay y quiénes las integran.
        repeat
            FLiquidaciones += 1;
            Categoria := ClaveCategoria(Liq."Cód. Convenio", Liq."Cód. Categoría");
            FCatDeEmpleado.Set(Liq."No. Empleado", Categoria);
            if not FEmpleadosPorCat.ContainsKey(Categoria) then begin
                FCategorias.Add(Categoria);
                FEmpleadosPorCat.Add(Categoria, 1);
                DescribirCategoria(Categoria, Liq."Cód. Convenio", Liq."Cód. Categoría");
            end else
                FEmpleadosPorCat.Set(Categoria, FEmpleadosPorCat.Get(Categoria) + 1);
            if not FEmpleados.Contains(Liq."No. Empleado") then
                FEmpleados.Add(Liq."No. Empleado");
        until Liq.Next() = 0;

        OrdenarPorClave(FCategorias, FOrdenCategoria);

        // Segunda pasada: los importes de CADA tripulante. El valor que va a la celda no se decide
        // acá — hace falta haberlos visto a todos para saber cuál es el habitual.
        Liq.FindSet();
        repeat
            Lin.SetCurrentKey("No. Liquidación", "Orden Cálculo", "No. Línea");
            Lin.SetRange("No. Liquidación", Liq."No.");
            if Lin.FindSet() then
                repeat
                    ClaveConcepto := ClaveDeConcepto(Lin."Orden Cálculo", Lin."Cód. Concepto");
                    RegistrarConcepto(ClaveConcepto, Lin);
                    Acumular(FImporteTotal, ClaveConcepto, Lin.Importe);
                    Acumular(FImporteEmpleado, ClaveConcepto + '~' + Liq."No. Empleado", Lin.Importe);
                    if Lin.Cantidad <> 0 then begin
                        FCantidadEmpleado.Set(ClaveConcepto + '~' + Liq."No. Empleado", Lin.Cantidad);
                        FUnidadEmpleado.Set(ClaveConcepto + '~' + Liq."No. Empleado", Lin.UnidadParaMostrar());
                    end;
                until Lin.Next() = 0;
        until Liq.Next() = 0;

        // Las filas se van descubriendo a medida que aparecen: un concepto que sólo cobra el último
        // tripulante entra a la lista al final, sin importar su Orden Cálculo. Recién acá, con todos
        // vistos, se los pone en el orden en que el motor los liquidó.
        // Sin diccionario de claves: la clave de un concepto ES su propio texto, que ya empieza con el
        // Orden Cálculo en seis dígitos.
        OrdenarPorClave(FConceptos, FSinOrden);

        CalcularHabituales();
    end;

    /// <summary>
    /// Llena la celda de cada concepto y categoría con el importe que cobró la MAYORÍA de esa
    /// categoría.
    /// </summary>
    /// <remarks>
    /// Antes la celda mostraba el importe de un tripulante representante, elegido por tener el número
    /// de empleado más chico. Funcionaba mientras el representante fuera uno más del montón, pero si
    /// justo era él el que había cobrado distinto, la matriz mostraba su número como si fuera el de
    /// toda la categoría y la sección de diferencias listaba a TODOS los demás — escondiendo el único
    /// caso real detrás de siete falsos.
    ///
    /// El valor habitual no tiene ese problema: por definición es el que más se repite, así que el
    /// que se aparta es siempre el que se aparta. Empate (dos valores con la misma cantidad de
    /// tripulantes) lo gana el primero que apareció, que con las liquidaciones leídas en orden de
    /// proyecto es estable entre corridas.
    ///
    /// Los tripulantes SIN línea del concepto cuentan como cero, y eso es a propósito: si a seis de
    /// ocho no les salió, lo habitual de esa categoría es no cobrarlo, y los dos que lo cobraron son
    /// justamente lo que hay que mirar. La celda queda en blanco y ellos aparecen en las diferencias.
    /// </remarks>
    local procedure CalcularHabituales()
    var
        Clave: Text;
        Cat: Text;
        Emp: Code[20];
        Cantidad: Decimal;
    begin
        foreach Clave in FConceptos do begin
            foreach Cat in FCategorias do
                FImporteRep.Set(Clave + '~' + Cat, ImporteHabitual(Clave, Cat));

            // La cantidad de la columna "Un." es una sola para toda la fila, así que se toma la
            // habitual sobre TODA la tripulación y no por categoría.
            Cantidad := CantidadHabitual(Clave);
            FCantidadRep.Set(Clave, Cantidad);
            // La unidad se toma de un tripulante que tenga JUSTO la cantidad habitual, no del primero
            // que aparezca: viene ya concordada en plural o singular según su propia cantidad, y
            // mezclarlas escribiría "9 DIA".
            FUnidad.Set(Clave, '');
            foreach Emp in FEmpleados do
                if FCantidadEmpleado.ContainsKey(Clave + '~' + Emp) then
                    if FCantidadEmpleado.Get(Clave + '~' + Emp) = Cantidad then begin
                        FUnidad.Set(Clave, FUnidadEmpleado.Get(Clave + '~' + Emp));
                        break;
                    end;
        end;
    end;

    // La regla del "valor habitual" vive en "Control Marea Liq." y se usa desde acá: si la planilla y
    // la pantalla la decidieran cada una por su lado, el día que difieran nadie sabría cuál creer.
    local procedure ImporteHabitual(Clave: Text; Cat: Text): Decimal
    var
        Claves: List of [Text];
        Emp: Code[20];
    begin
        foreach Emp in FEmpleados do
            if FCatDeEmpleado.Get(Emp) = Cat then
                Claves.Add(Clave + '~' + Emp);
        exit(FControl.ValorHabitual(FImporteEmpleado, Claves));
    end;

    /// <remarks>
    /// Solo entran los tripulantes que TIENEN cantidad cargada: a diferencia del importe, un cero acá
    /// no significa "no le tocó" sino "el concepto no se mide en unidades", y contarlo haría que la
    /// columna "Un." quedara vacía en cuanto un tripulante no tuviera el concepto.
    /// </remarks>
    local procedure CantidadHabitual(Clave: Text): Decimal
    var
        Claves: List of [Text];
        Emp: Code[20];
    begin
        foreach Emp in FEmpleados do
            if FCantidadEmpleado.ContainsKey(Clave + '~' + Emp) then
                Claves.Add(Clave + '~' + Emp);
        exit(FControl.ValorHabitual(FCantidadEmpleado, Claves));
    end;

    /// <summary>Etiqueta de columna y criterio de orden de una categoría.</summary>
    /// <remarks>
    /// Las columnas van de mayor a menor % de escala, que es como está armada la planilla que se
    /// venía llevando a mano —Capitán primero, Bodeguero último— y no una convención de este informe:
    /// el % de escala ES la jerarquía del convenio. Ordenar alfabéticamente pondría "Bod" antes que
    /// "Capitán" y obligaría a buscar cada columna en vez de leerlas de corrido.
    /// </remarks>
    local procedure DescribirCategoria(Clave: Text; Convenio: Code[20]; Categoria: Code[20])
    var
        CatCCT: Record "Categoría CCT";
        Escala: Integer;
        Etiqueta: Text;
    begin
        Etiqueta := Categoria;
        if Etiqueta = '' then
            Etiqueta := TxtSinCategoria;
        if CatCCT.Get(Convenio, Categoria) then begin
            Escala := Round(CatCCT."% Escala" * 10, 1);
            if CatCCT.Descripción <> '' then
                Etiqueta := CatCCT.Descripción;
        end;
        FEtiquetaCat.Set(Clave, Etiqueta);
        // Clave de orden descendente por escala: 99999 - escala*10, a ancho fijo para que compare
        // como texto. Empate de escala (o categorías sin CCT, escala 0) se desempata por el código.
        FOrdenCategoria.Set(Clave, Format(99999 - Escala, 8, '<Integer,8><Filler Character,0>') + '|' + Clave);
    end;

    local procedure RegistrarConcepto(Clave: Text; var Lin: Record "Línea Liquidación")
    begin
        if FNombreConcepto.ContainsKey(Clave) then
            exit;
        FConceptos.Add(Clave);
        FNombreConcepto.Add(Clave, Lin."Nombre Impresión");
        FCodigoConcepto.Add(Clave, Lin."Cód. Concepto");
        FOrdenConcepto.Add(Clave, Lin."Orden Cálculo");
        FTipoConcepto.Add(Clave, Format(Lin."Tipo Concepto"));
        FImprime.Add(Clave, Lin."Imprime en Recibo");
        FUnidad.Add(Clave, '');
        FCantidadRep.Add(Clave, 0);
    end;

    /// <summary>
    /// Si el concepto merece una fila en la matriz: tiene que haberle dado importe a alguien y tiene
    /// que imprimir en recibo.
    /// </summary>
    /// <remarks>
    /// Lo que se descarta son las contribuciones patronales y los acumuladores —correctos, pero no
    /// forman parte de lo que el tripulante cobra— y los conceptos que dieron cero en todo el viaje.
    ///
    /// Las filas de total NO usan este filtro: se calculan sobre todos los conceptos, para que sigan
    /// coincidiendo con las cabeceras de las liquidaciones. Por eso el pie dice cuántas filas se
    /// ocultaron y cuánto suman: si no, un total patronal sin ninguna fila que lo explique parecería
    /// un error del informe.
    /// </remarks>
    local procedure ConceptoVisible(Clave: Text): Boolean
    var
        Cat: Text;
    begin
        if not FImprime.Get(Clave) then
            exit(false);
        // Celda por celda y no el total: un concepto que le sumó a una categoría lo mismo que le
        // restó a otra da total cero y sin embargo hay algo que mirar.
        foreach Cat in FCategorias do
            if ValorDe(FImporteRep, Clave + '~' + Cat) <> 0 then
                exit(true);
        exit(ValorDe(FImporteTotal, Clave) <> 0);
    end;

    // Orden de cálculo primero, código después: el mismo orden en que el motor los liquidó y en que
    // salen en el recibo. Se ordena la lista de claves, que ya empieza con el orden en 6 dígitos.
    local procedure ClaveDeConcepto(Orden: Integer; Codigo: Code[20]): Text
    begin
        exit(Format(Orden, 6, '<Integer,6><Filler Character,0>') + '|' + Codigo);
    end;

    local procedure ClaveCategoria(Convenio: Code[20]; Categoria: Code[20]): Text
    begin
        if Categoria = '' then
            exit(Convenio + ' (sin categoría)');
        exit(Convenio + '/' + Categoria);
    end;

    /// <summary>
    /// Ordena Lista según el texto que Claves asocia a cada elemento; si no hay entrada, el propio
    /// elemento es su clave de orden.
    /// </summary>
    local procedure OrdenarPorClave(var Lista: List of [Text]; var Claves: Dictionary of [Text, Text])
    var
        Ordenadas: List of [Text];
        Elem: Text;
        Menor: Text;
        MenorClave: Text;
        ClaveElem: Text;
        i: Integer;
    begin
        while Lista.Count() > 0 do begin
            Menor := '';
            MenorClave := '';
            foreach Elem in Lista do begin
                ClaveElem := Elem;
                if Claves.ContainsKey(Elem) then
                    ClaveElem := Claves.Get(Elem);
                if (MenorClave = '') or (ClaveElem < MenorClave) then begin
                    MenorClave := ClaveElem;
                    Menor := Elem;
                end;
            end;
            Ordenadas.Add(Menor);
            for i := 1 to Lista.Count() do
                if Lista.Get(i) = Menor then begin
                    Lista.RemoveAt(i);
                    break;
                end;
        end;
        Lista := Ordenadas;
    end;

    local procedure Acumular(var Mapa: Dictionary of [Text, Decimal]; Clave: Text; Importe: Decimal)
    begin
        if Mapa.ContainsKey(Clave) then
            Mapa.Set(Clave, Mapa.Get(Clave) + Importe)
        else
            Mapa.Add(Clave, Importe);
    end;

    local procedure ValorDe(var Mapa: Dictionary of [Text, Decimal]; Clave: Text): Decimal
    begin
        if Mapa.ContainsKey(Clave) then
            exit(Mapa.Get(Clave));
        exit(0);
    end;

    // ── Escritura ─────────────────────────────────────────────────────────────

    local procedure EscribirCabecera(var Libro: Record "Excel Buffer" temporary; var Job: Record Job)
    var
        Cat: Text;
    begin
        NuevaFila(Libro);
        Texto(Libro, TxtTituloInforme, true);
        NuevaFila(Libro);
        Etiqueta(Libro, TxtProyecto, Job."No." + '  ' + Job.Description);
        Etiqueta(Libro, TxtSalida, Format(Job."Starting Date"));
        Etiqueta(Libro, TxtArribo, Format(Job."Ending Date"));
        Etiqueta(Libro, TxtLiquidaciones, Format(FLiquidaciones));
        Etiqueta(Libro, TxtCategorias, Format(FCategorias.Count()));
        // Un Excel sin la marca del filtro se archiva y al mes siguiente nadie sabe si le falta media
        // tripulación o si la marea era así.
        if (FFiltroConvenio <> '') or (FFiltroCategoria <> '') then
            Etiqueta(Libro, TxtFiltro, FFiltroConvenio + ' ' + FFiltroCategoria);
        EscribirDatosCalculo(Libro);
        NuevaFila(Libro);

        // Dos filas de encabezado, como en la planilla que se venía usando a mano: la categoría y,
        // debajo, a cuántos tripulantes representa cada columna.
        NuevaFila(Libro);
        Texto(Libro, TxtOrden, true);
        Texto(Libro, TxtCodigo, true);
        Texto(Libro, TxtConcepto, true);
        Texto(Libro, TxtUn, true);
        foreach Cat in FCategorias do
            Texto(Libro, FEtiquetaCat.Get(Cat), true);
        Texto(Libro, TxtTotalMarea, true);

        NuevaFila(Libro);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        foreach Cat in FCategorias do
            Texto(Libro, StrSubstNo(TxtTripulantes, FEmpleadosPorCat.Get(Cat)), false);
        Texto(Libro, '', false);
    end;

    /// <remarks>
    /// Sólo los cuatro datos que hacen falta para releer la matriz: los días de la marea, el tipo de
    /// cambio y el rango de netos. La planilla se imprime y se discute lejos del sistema, y sin esto
    /// cada número de la matriz es imposible de reconstruir a mano.
    ///
    /// El RESTO de las variables comunes va al final de la hoja y no acá. "Resumen Variable Liq."
    /// guarda toda variable de contexto con valor —parámetros, acumuladores, fuentes de datos—, así
    /// que son cientos de filas: puestas en la cabecera empujaban la matriz tan abajo que la planilla
    /// no se entendía. En pantalla el mismo dato no molesta porque es una grilla aparte.
    ///
    /// Todo sale de "Control Marea Liq.", que lo lee de lo que el motor dejó calculado. Recalcularlo
    /// acá habría abierto la puerta a que la planilla dijera una cosa y el recibo otra.
    /// </remarks>
    local procedure EscribirDatosCalculo(var Libro: Record "Excel Buffer" temporary)
    var
        Minimo: Decimal;
        Maximo: Decimal;
        Promedio: Decimal;
    begin
        Etiqueta(Libro, TxtDiasNav, Format(FControl.ValorVariableSistema(FComunes, 'DIAS_PROYECTO')));
        Etiqueta(Libro, TxtDiasPuerto, Format(FControl.ValorVariableSistema(FComunes, 'DIAS_PUERTO')));
        Etiqueta(Libro, TxtDiasFeriados, Format(FControl.ValorVariableSistema(FComunes, 'DIAS_FERIADOS_MAREA')));
        Etiqueta(Libro, TxtTipoCambio, FControl.TiposDeCambio(FProyecto, FFiltroConvenio, FFiltroCategoria));

        FControl.Netos(FProyecto, FFiltroConvenio, FFiltroCategoria, Minimo, Maximo, Promedio);
        Etiqueta(Libro, TxtNetoMin, Format(Minimo, 0, '<Precision,2:2><Standard Format,0>'));
        Etiqueta(Libro, TxtNetoProm, Format(Promedio, 0, '<Precision,2:2><Standard Format,0>'));
        Etiqueta(Libro, TxtNetoMax, Format(Maximo, 0, '<Precision,2:2><Standard Format,0>'));
    end;

    /// <summary>
    /// Junta quién cobró distinto que la mayoría de su categoría, de mayor a menor diferencia.
    /// Devuelve cuántos casos hay.
    /// </summary>
    /// <remarks>
    /// Es el contrapeso de una matriz que muestra un solo número por categoría y por lo tanto esconde
    /// por construcción a quien se aparte de sus pares.
    ///
    /// Recorre SOLO los conceptos que están en la matriz —con importe y que imprimen en recibo— y no
    /// todos. Sin ese filtro la sección era ilegible: cada diferencia real en un haber arrastraba su
    /// contribución patronal y sus acumuladores, así que un solo caso aparecía como tres o cuatro
    /// filas, y entre ellas se perdían las que importaban.
    ///
    /// Ordenada por tamaño de la diferencia y no por empleado: lo que se revisa primero es lo que más
    /// plata mueve, no lo que quedó primero en el archivo.
    ///
    /// Se junta antes de escribir porque la hoja de diferencias sólo tiene sentido si hay alguna: un
    /// libro con una segunda hoja vacía hace dudar de si el informe corrió.
    /// </remarks>
    local procedure RecolectarDiferencias(var Filas: List of [Text]; var Nombre: Dictionary of [Text, Text]): Integer
    var
        Liq: Record "Liquidación";
        Orden: Dictionary of [Text, Text];
        Fila: Text;
        Clave: Text;
        Cat: Text;
        ImporteEmp: Decimal;
        ImporteRepCat: Decimal;
        // Techo para invertir el orden por diferencia. Decimal y no Integer: un Integer no llega ni a
        // 2.150 millones, y un importe de marea puede pasarlo.
        Techo: Decimal;
    begin
        Techo := 99999999999.0;
        Liq.SetCurrentKey("No. Proyecto");
        Liq.SetRange("No. Proyecto", FProyecto);
        if FFiltroConvenio <> '' then
            Liq.SetRange("Cód. Convenio", FFiltroConvenio);
        if FFiltroCategoria <> '' then
            Liq.SetRange("Cód. Categoría", FFiltroCategoria);
        Liq.SetLoadFields("No. Empleado", "Nombre Empleado");
        if Liq.FindSet() then
            repeat
                Cat := FCatDeEmpleado.Get(Liq."No. Empleado");
                foreach Clave in FConceptos do
                    if ConceptoVisible(Clave) then begin
                        ImporteEmp := ValorDe(FImporteEmpleado, Clave + '~' + Liq."No. Empleado");
                        ImporteRepCat := ValorDe(FImporteRep, Clave + '~' + Cat);
                        if ImporteEmp <> ImporteRepCat then begin
                            Fila := Clave + '~' + Liq."No. Empleado";
                            Filas.Add(Fila);
                            // Clave de orden descendente por diferencia absoluta, a ancho fijo
                            // para que compare como texto.
                            Orden.Set(Fila, Format(Techo - Abs(ImporteEmp - ImporteRepCat), 14, '<Integer,14><Filler Character,0>') + Fila);
                            Nombre.Set(Liq."No. Empleado", Liq."Nombre Empleado");
                        end;
                    end;
            until Liq.Next() = 0;

        OrdenarPorClave(Filas, Orden);
        exit(Filas.Count());
    end;

    /// <summary>La hoja de diferencias: una fila por tripulante que se apartó, con su concepto.</summary>
    local procedure EscribirDiferencias(var Libro: Record "Excel Buffer" temporary; var Filas: List of [Text]; var Nombre: Dictionary of [Text, Text])
    var
        Fila: Text;
        Clave: Text;
        Cat: Text;
        Emp: Code[20];
        ImporteEmp: Decimal;
        ImporteRepCat: Decimal;
    begin
        NuevaFila(Libro);
        Texto(Libro, TxtDiferencias, true);
        NuevaFila(Libro);
        Texto(Libro, TxtDifAyuda, false);
        NuevaFila(Libro);

        NuevaFila(Libro);
        Texto(Libro, TxtCodigo, true);
        Texto(Libro, TxtConcepto, true);
        Texto(Libro, TxtCategoria, true);
        Texto(Libro, TxtEmpleado, true);
        Texto(Libro, TxtCobro, true);
        Texto(Libro, TxtRepCobro, true);
        Texto(Libro, TxtDiferencia, true);

        foreach Fila in Filas do begin
            Clave := CopyStr(Fila, 1, StrPos(Fila, '~') - 1);
            Emp := CopyStr(CopyStr(Fila, StrPos(Fila, '~') + 1), 1, MaxStrLen(Emp));
            Cat := FCatDeEmpleado.Get(Emp);
            ImporteEmp := ValorDe(FImporteEmpleado, Clave + '~' + Emp);
            ImporteRepCat := ValorDe(FImporteRep, Clave + '~' + Cat);

            NuevaFila(Libro);
            Texto(Libro, FCodigoConcepto.Get(Clave), false);
            Texto(Libro, FNombreConcepto.Get(Clave), false);
            Texto(Libro, FEtiquetaCat.Get(Cat), false);
            Texto(Libro, Emp + '  ' + Nombre.Get(Emp), false);
            Numero(Libro, ImporteEmp, false);
            Numero(Libro, ImporteRepCat, false);
            Numero(Libro, ImporteEmp - ImporteRepCat, true);
        end;
    end;

    /// <summary>
    /// Al final de la hoja: todas las variables que valieron lo mismo para toda la tripulación.
    /// </summary>
    /// <remarks>
    /// Son los kilos del buque, los parámetros del convenio y cualquier fuente de datos que no
    /// dependa del tripulante — sin enumerarlas, se descubren solas comparando entre liquidaciones.
    /// Van al final justamente porque son muchas: acá se consultan cuando hace falta explicar un
    /// número de la matriz, y mientras tanto no estorban.
    /// </remarks>
    local procedure EscribirVariablesComunes(var Libro: Record "Excel Buffer" temporary)
    begin
        FComunes.Reset();
        if not FComunes.FindSet() then
            exit;

        NuevaFila(Libro);
        NuevaFila(Libro);
        Texto(Libro, TxtComunes, true);
        NuevaFila(Libro);
        Texto(Libro, TxtVariable, true);
        Texto(Libro, TxtDescripcion, true);
        Texto(Libro, TxtValor, true);

        repeat
            if (FComunes.Valor <> 0) or (FComunes."Valor Texto" <> '') then begin
                NuevaFila(Libro);
                Texto(Libro, FComunes."Nombre Variable", false);
                Texto(Libro, FComunes.Etiqueta, false);
                if FComunes."Valor Texto" <> '' then
                    Texto(Libro, FComunes."Valor Texto", false)
                else
                    Numero(Libro, FComunes.Valor, false);
            end;
        until FComunes.Next() = 0;
    end;

    local procedure EscribirMatriz(var Libro: Record "Excel Buffer" temporary)
    var
        Clave: Text;
        Cat: Text;
    begin
        // Orden y código salen como columnas propias, y no pegados al nombre, para que en Excel se
        // pueda reordenar la matriz por cualquiera de los dos sin tocar los datos.
        foreach Clave in FConceptos do
            if ConceptoVisible(Clave) then begin
                NuevaFila(Libro);
                Entero(Libro, FOrdenConcepto.Get(Clave));
                Texto(Libro, FCodigoConcepto.Get(Clave), false);
                Texto(Libro, FNombreConcepto.Get(Clave), false);
                Texto(Libro, UnidadDe(Clave), false);
                foreach Cat in FCategorias do
                    Numero(Libro, ValorDe(FImporteRep, Clave + '~' + Cat), false);
                Numero(Libro, ValorDe(FImporteTotal, Clave), false);
            end else begin
                FOcultos += 1;
                FImporteOculto += ValorDe(FImporteTotal, Clave);
            end;

        NuevaFila(Libro);
        EscribirTotal(Libro, TxtTotalRem, "Tipo Concepto Liq."::"Haber Remunerativo");
        EscribirTotal(Libro, TxtTotalNoRem, "Tipo Concepto Liq."::"Haber No Remunerativo");
        EscribirTotal(Libro, TxtTotalDesc, "Tipo Concepto Liq."::"Descuento Empleado");
        EscribirTotal(Libro, TxtTotalSS, "Tipo Concepto Liq."::"Seguridad Social");
        EscribirTotal(Libro, TxtTotalContrib, "Tipo Concepto Liq."::"Contribución Patronal");

        // Las filas de total abarcan TODOS los conceptos, también los que no llegaron a ser fila.
        // Sin esta aclaración, un total de contribuciones sin una sola fila que lo explique parece un
        // error de la planilla en lugar de lo que es: conceptos que no imprimen en recibo.
        if FOcultos > 0 then begin
            NuevaFila(Libro);
            NuevaFila(Libro);
            Texto(Libro, StrSubstNo(TxtOcultos, FOcultos, Format(FImporteOculto, 0, '<Precision,2:2><Standard Format,0>')), false);
        end;
    end;

    local procedure EscribirTotal(var Libro: Record "Excel Buffer" temporary; Etiq: Text; Tipo: Enum "Tipo Concepto Liq.")
    var
        Clave: Text;
        Cat: Text;
        SumaCat: Decimal;
        SumaTotal: Decimal;
    begin
        NuevaFila(Libro);
        Texto(Libro, '', false);
        Texto(Libro, '', false);
        Texto(Libro, Etiq, true);
        Texto(Libro, '', false);
        foreach Cat in FCategorias do begin
            SumaCat := 0;
            foreach Clave in FConceptos do
                if FTipoConcepto.Get(Clave) = Format(Tipo) then
                    SumaCat += ValorDe(FImporteRep, Clave + '~' + Cat);
            Numero(Libro, SumaCat, true);
        end;
        SumaTotal := 0;
        foreach Clave in FConceptos do
            if FTipoConcepto.Get(Clave) = Format(Tipo) then
                SumaTotal += ValorDe(FImporteTotal, Clave);
        Numero(Libro, SumaTotal, true);
    end;

    local procedure UnidadDe(Clave: Text): Text
    var
        Cant: Decimal;
    begin
        Cant := 0;
        if FCantidadRep.ContainsKey(Clave) then
            Cant := FCantidadRep.Get(Clave);
        if Cant = 0 then
            exit('');
        exit(Format(Cant) + ' ' + FUnidad.Get(Clave));
    end;

    // ── Envoltorios del Excel Buffer ──────────────────────────────────────────

    local procedure NuevaFila(var Libro: Record "Excel Buffer" temporary)
    begin
        Libro.NewRow();
    end;

    local procedure Texto(var Libro: Record "Excel Buffer" temporary; Valor: Text; Negrita: Boolean)
    begin
        Libro.AddColumn(Valor, false, '', Negrita, false, false, '', Libro."Cell Type"::Text);
    end;

    local procedure Numero(var Libro: Record "Excel Buffer" temporary; Valor: Decimal; Negrita: Boolean)
    begin
        Libro.AddColumn(Valor, false, '', Negrita, false, false, '#,##0.00', Libro."Cell Type"::Number);
    end;

    // El orden de cálculo se escribe como número entero y no con el formato de importe: en Excel tiene
    // que poder ordenarse como número, pero un "10,00" en la columna Orden se lee como un error.
    local procedure Entero(var Libro: Record "Excel Buffer" temporary; Valor: Integer)
    begin
        Libro.AddColumn(Valor, false, '', false, false, false, '0', Libro."Cell Type"::Number);
    end;

    local procedure Etiqueta(var Libro: Record "Excel Buffer" temporary; Etiq: Text; Valor: Text)
    begin
        NuevaFila(Libro);
        Texto(Libro, Etiq, true);
        Texto(Libro, Valor, false);
    end;

    var
        FComunes: Record "Resumen Variable Liq." temporary;
        FControl: Codeunit "Control Marea Liq.";
        FCategorias: List of [Text];
        FEtiquetaCat: Dictionary of [Text, Text];
        FOrdenCategoria: Dictionary of [Text, Text];
        FSinOrden: Dictionary of [Text, Text];
        FEmpleadosPorCat: Dictionary of [Text, Integer];
        FConceptos: List of [Text];
        FNombreConcepto: Dictionary of [Text, Text];
        FCodigoConcepto: Dictionary of [Text, Text];
        FOrdenConcepto: Dictionary of [Text, Integer];
        FImprime: Dictionary of [Text, Boolean];
        FTipoConcepto: Dictionary of [Text, Text];
        FUnidad: Dictionary of [Text, Text];
        FCantidadRep: Dictionary of [Text, Decimal];
        FImporteRep: Dictionary of [Text, Decimal];
        FImporteTotal: Dictionary of [Text, Decimal];
        FImporteEmpleado: Dictionary of [Text, Decimal];
        FCantidadEmpleado: Dictionary of [Text, Decimal];
        FUnidadEmpleado: Dictionary of [Text, Text];
        FCatDeEmpleado: Dictionary of [Code[20], Text];
        FEmpleados: List of [Code[20]];
        FLiquidaciones: Integer;
        FOcultos: Integer;
        FImporteOculto: Decimal;
        FProyecto: Code[20];
        FFiltroConvenio: Code[20];
        FFiltroCategoria: Code[20];
        TxtHoja: Label 'Control %1', Comment = '%1=No. proyecto';
        TxtTituloInforme: Label 'CONTROL DE LIQUIDACIÓN POR MAREA';
        TxtProyecto: Label 'Proyecto';
        TxtSalida: Label 'Fecha de salida';
        TxtArribo: Label 'Fecha de arribo';
        TxtLiquidaciones: Label 'Liquidaciones';
        TxtCategorias: Label 'Categorías';
        TxtFiltro: Label 'Filtrado por';
        TxtDiasNav: Label 'Días de navegación';
        TxtDiasPuerto: Label 'Días de puerto';
        TxtDiasFeriados: Label 'Feriados a bordo';
        TxtTipoCambio: Label 'Tipo de cambio';
        TxtNetoMin: Label 'Neto mínimo';
        TxtNetoProm: Label 'Neto promedio';
        TxtNetoMax: Label 'Neto máximo';
        TxtHojaDif: Label 'Diferencias';
        TxtDiferencias: Label 'DIFERENCIAS DENTRO DE LA MISMA CATEGORÍA';
        TxtDifAyuda: Label 'Tripulantes que cobraron distinto que la mayoría de su categoría, de mayor a menor diferencia. Sólo conceptos que imprimen en recibo.';
        TxtCategoria: Label 'Categoría';
        TxtEmpleado: Label 'Empleado';
        TxtCobro: Label 'Cobró';
        TxtRepCobro: Label 'Su categoría';
        TxtDiferencia: Label 'Diferencia';
        TxtComunes: Label 'DATOS DE CÁLCULO COMUNES A TODA LA TRIPULACIÓN';
        TxtVariable: Label 'Variable';
        TxtDescripcion: Label 'Descripción';
        TxtValor: Label 'Valor';
        TxtConcepto: Label 'Concepto';
        TxtOrden: Label 'Orden';
        TxtCodigo: Label 'Código';
        TxtUn: Label 'Un.';
        TxtOcultos: Label 'Los totales de arriba incluyen %1 concepto(s) que no figuran como fila —sin importe en toda la marea, o que no imprimen en recibo (contribuciones patronales, acumuladores)—, por %2 en total.', Comment = '%1=cantidad de conceptos, %2=importe';
        TxtTotalMarea: Label 'TOTAL MAREA';
        TxtTripulantes: Label '%1 tripulante(s)', Comment = '%1=cantidad de tripulantes de la categoría';
        TxtTotalRem: Label 'Total remunerativo';
        TxtTotalNoRem: Label 'Total NO remunerativo';
        TxtTotalDesc: Label 'Total descuentos';
        TxtTotalSS: Label 'Total seguridad social';
        TxtTotalContrib: Label 'Total contribuciones';
        TxtSinCategoria: Label '(sin categoría)';
        ErrSinProyecto: Label 'Elegí un proyecto (marea) para generar el control.';
        ErrSinLiquidaciones: Label 'El proyecto %1 no tiene líneas de liquidación para ese filtro de convenio y categoría.', Comment = '%1=No. proyecto';
}
