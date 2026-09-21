namespace UAS.Payroll;

// Equivalencia entre las dos formas de resolver el fin efectivo de un intervalo.
//
// El fin efectivo es "el menor inicio estrictamente posterior, menos un día", y lo usan las fuentes
// sobre tablas effective-dated sin Fecha Fin guardada — hoy DIAS_VAC y DIAS_VAC_INICIO sobre Estado
// Empleado. Se contesta de dos maneras: recorriendo la lista de inicios, que es LA DEFINICIÓN, y
// consultando un mapa que se arma una vez por fuente, que es lo rápido.
//
// Las dos tienen que dar siempre lo mismo. Estas pruebas lo afirman sobre los casos que los datos de
// hoy no ejercitan pero que van a aparecer: listas desordenadas, fechas repetidas, consultas por una
// fecha que no es ningún inicio. Sin ellas, un error acá no daría un mensaje: daría un intervalo mal
// cerrado, unos días de vacaciones de más o de menos, y nadie mirando.
//
// Cada prueba usa su propia instancia de Contexto Liquidación: el mapa se cachea por nombre de
// variable y compartir la instancia haría que una prueba contestara con el mapa de otra.
codeunit 110045 "Test Fin Efectivo Liq."
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure ListaOrdenadaSinRepetidos()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Fechas: List of [Date];
    begin
        Fechas.Add(D(2026, 1, 1));
        Fechas.Add(D(2026, 3, 10));
        Fechas.Add(D(2026, 7, 5));

        AssertFecha(D(2026, 3, 9), Ctx.FinEfectivoDeLista('A', Fechas, D(2026, 1, 1)), 'cierra el día antes del siguiente');
        AssertFecha(D(2026, 7, 4), Ctx.FinEfectivoDeLista('A', Fechas, D(2026, 3, 10)), 'el del medio');
        AssertFecha(0D, Ctx.FinEfectivoDeLista('A', Fechas, D(2026, 7, 5)), 'el último queda abierto');
    end;

    // Dos estados que arrancan el mismo día comparten fin efectivo: el primer inicio DISTINTO que
    // venga después. Si el mapa tomara "el de al lado" en vez de "el siguiente distinto", el primero
    // de los dos cerraría el día anterior a sí mismo — un intervalo de longitud negativa.
    [Test]
    procedure FechasRepetidas()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Fechas: List of [Date];
    begin
        Fechas.Add(D(2026, 1, 1));
        Fechas.Add(D(2026, 3, 10));
        Fechas.Add(D(2026, 3, 10));
        Fechas.Add(D(2026, 7, 5));

        AssertFecha(D(2026, 7, 4), Ctx.FinEfectivoDeLista('B', Fechas, D(2026, 3, 10)), 'la repetida salta a la siguiente distinta');
        AssertFecha(D(2026, 3, 9), Ctx.FinEfectivoDeLista('B', Fechas, D(2026, 1, 1)), 'la anterior no se ve afectada');
    end;

    // La lista puede llegar por clave primaria. Se ordena una copia sin alterar el resultado.
    [Test]
    procedure ListaDesordenadaUsaMapa()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Fechas: List of [Date];
    begin
        Fechas.Add(D(2026, 7, 5));
        Fechas.Add(D(2026, 1, 1));
        Fechas.Add(D(2026, 3, 10));

        AssertFecha(D(2026, 3, 9), Ctx.FinEfectivoDeLista('C', Fechas, D(2026, 1, 1)), 'desordenada, primera');
        AssertFecha(D(2026, 7, 4), Ctx.FinEfectivoDeLista('C', Fechas, D(2026, 3, 10)), 'desordenada, del medio');
        AssertFecha(0D, Ctx.FinEfectivoDeLista('C', Fechas, D(2026, 7, 5)), 'desordenada, última');
    end;

    [Test]
    procedure FechaQueNoEsNingunInicio()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Fechas: List of [Date];
    begin
        Fechas.Add(D(2026, 1, 1));
        Fechas.Add(D(2026, 3, 10));
        Fechas.Add(D(2026, 7, 5));

        AssertFecha(D(2026, 3, 9), Ctx.FinEfectivoDeLista('D', Fechas, D(2026, 2, 15)), 'una fecha del medio que no está en la lista');
        AssertFecha(D(2025, 12, 31), Ctx.FinEfectivoDeLista('D', Fechas, D(2025, 6, 1)), 'anterior a todas');
        AssertFecha(0D, Ctx.FinEfectivoDeLista('D', Fechas, D(2027, 1, 1)), 'posterior a todas');
    end;

    [Test]
    procedure ListaVaciaYDeUnSoloElemento()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Vacia: List of [Date];
        Una: List of [Date];
    begin
        AssertFecha(0D, Ctx.FinEfectivoDeLista('E', Vacia, D(2026, 1, 1)), 'lista vacía: intervalo abierto');
        Una.Add(D(2026, 1, 1));
        AssertFecha(0D, Ctx.FinEfectivoDeLista('F', Una, D(2026, 1, 1)), 'un solo inicio: intervalo abierto');
    end;

    // La que de verdad importa: sobre un historial del tamaño de los reales —el promedio medido es 61
    // estados por empleado y el máximo 774— las dos formas coinciden en TODA fecha de inicio, con
    // repetidos incluidos.
    [Test]
    procedure EquivalenciaSobreUnHistorialLargo()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Fechas: List of [Date];
        Base: Date;
        Cur: Date;
        i: Integer;
        Salto: Integer;
    begin
        Base := D(2006, 1, 1);
        for i := 1 to 400 do begin
            // Saltos irregulares y algún día repetido, que es lo que produce un historial real: un
            // cambio de estado y un cambio de proyecto el mismo día.
            Salto := (i * 7) mod 23;
            Base := Base + Salto;
            Fechas.Add(Base);
            if (i mod 13) = 0 then
                Fechas.Add(Base);
        end;

        foreach Cur in Fechas do
            AssertFecha(
                Ctx.FinEfectivoPorRecorrido(Fechas, Cur),
                Ctx.FinEfectivoDeLista('G', Fechas, Cur),
                'historial largo');

        // Y también en fechas que no son inicios: un día antes y un día después de cada uno.
        foreach Cur in Fechas do begin
            AssertFecha(
                Ctx.FinEfectivoPorRecorrido(Fechas, Cur - 1),
                Ctx.FinEfectivoDeLista('G', Fechas, Cur - 1),
                'historial largo, día previo');
            AssertFecha(
                Ctx.FinEfectivoPorRecorrido(Fechas, Cur + 1),
                Ctx.FinEfectivoDeLista('G', Fechas, Cur + 1),
                'historial largo, día siguiente');
        end;
    end;

    [Test]
    procedure OrdenacionNoModificaOriginal()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Original: List of [Date];
        Ordenada: List of [Date];
    begin
        Original.Add(D(2026, 7, 5));
        Original.Add(0D);
        Original.Add(D(2026, 1, 1));
        Original.Add(D(2026, 1, 1));
        Ordenada := Ctx.OrdenarFechas(Original);
        AssertFecha(D(2026, 7, 5), Original.Get(1), 'no cambia la lista compartida');
        AssertFecha(0D, Ordenada.Get(1), 'fecha vacía primero');
        AssertFecha(D(2026, 1, 1), Ordenada.Get(2), 'inicio intermedio');
        AssertFecha(D(2026, 1, 1), Ordenada.Get(3), 'repetido conservado');
        AssertFecha(D(2026, 7, 5), Ordenada.Get(4), 'último inicio');
        AssertFecha(Ctx.FinEfectivoPorRecorrido(Original, 0D),
            Ctx.FinEfectivoDeLista('CERO', Original, 0D), 'fin efectivo desde cero');
    end;

    [Test]
    procedure HistorialInversoYReinicio()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Fechas: List of [Date];
        Nueva: List of [Date];
        Base: Date;
        Cur: Date;
        i: Integer;
    begin
        Base := D(2020, 1, 1);
        for i := 400 downto 1 do begin
            Fechas.Add(Base + i * 3);
            if (i mod 7) = 0 then
                Fechas.Add(Base + i * 3);
        end;
        foreach Cur in Fechas do begin
            AssertFecha(Ctx.FinEfectivoPorRecorrido(Fechas, Cur),
                Ctx.FinEfectivoDeLista('MISMA', Fechas, Cur), 'historial inverso');
            AssertFecha(Ctx.FinEfectivoPorRecorrido(Fechas, Cur - 1),
                Ctx.FinEfectivoDeLista('MISMA', Fechas, Cur - 1), 'fecha ausente');
        end;
        Ctx.Init('', '', '', Base, '', '', '', '', Base);
        Nueva.Add(Base + 3);
        Nueva.Add(Base + 30);
        AssertFecha(Base + 29, Ctx.FinEfectivoDeLista('MISMA', Nueva, Base + 3),
            'otra liquidación debe reconstruir la caché');
    end;

    // El caso que se parece a los datos de producción. Ascendente e inverso son los dos órdenes
    // fáciles: en los dos, el merge sort acierta aunque el drenaje de una de las colas esté mal,
    // porque una de las mitades se agota siempre primero. Lo que rompe esa suerte es la entrada
    // INTERCALADA, y es justo la que hay: 3.301 empleados con el historial desordenado y 56.706
    // saltos hacia atrás dispersos, no invertido en bloque.
    //
    // La permutación es determinista —149 es coprimo con 400, así que recorre los 400 índices sin
    // repetir— para que un fallo se pueda reproducir. Los duplicados quedan esparcidos a propósito:
    // caen en mitades distintas del split y ejercitan el borde de la mezcla, donde el <= decide si
    // un repetido sobrevive o se pierde.
    [Test]
    procedure EquivalenciaSobreUnHistorialIntercalado()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Cronologico: List of [Date];
        Fechas: List of [Date];
        Base: Date;
        Cur: Date;
        i: Integer;
        k: Integer;
    begin
        Base := D(2006, 1, 1);
        for i := 1 to 400 do begin
            Base := Base + ((i * 7) mod 23) + 1;
            Cronologico.Add(Base);
        end;

        for i := 0 to 399 do begin
            k := ((i * 149) mod 400) + 1;
            Fechas.Add(Cronologico.Get(k));
            if (k mod 11) = 0 then
                Fechas.Add(Cronologico.Get(k));
        end;

        foreach Cur in Fechas do begin
            AssertFecha(
                Ctx.FinEfectivoPorRecorrido(Fechas, Cur),
                Ctx.FinEfectivoDeLista('INTERCALADO', Fechas, Cur),
                'historial intercalado');
            AssertFecha(
                Ctx.FinEfectivoPorRecorrido(Fechas, Cur - 1),
                Ctx.FinEfectivoDeLista('INTERCALADO', Fechas, Cur - 1),
                'historial intercalado, día previo');
            AssertFecha(
                Ctx.FinEfectivoPorRecorrido(Fechas, Cur + 1),
                Ctx.FinEfectivoDeLista('INTERCALADO', Fechas, Cur + 1),
                'historial intercalado, día siguiente');
        end;
    end;

    // La mezcla se prueba también en chico, donde un error de borde no queda tapado por el volumen:
    // el mismo valor a los dos lados del corte, y una mitad que se agota antes que la otra.
    [Test]
    procedure BordesDeLaMezcla()
    var
        Ctx: Codeunit "Contexto Liquidación";
        Fechas: List of [Date];
        Ordenada: List of [Date];
    begin
        // Dos elementos: es el caso que decide si el split genera una mitad vacía y recursa para
        // siempre. Mitad = 2 div 2 = 1, así que cada lado se lleva uno.
        Fechas.Add(D(2026, 5, 1));
        Fechas.Add(D(2026, 1, 1));
        Ordenada := Ctx.OrdenarFechas(Fechas);
        AssertFecha(D(2026, 1, 1), Ordenada.Get(1), 'dos elementos, menor primero');
        AssertFecha(D(2026, 5, 1), Ordenada.Get(2), 'dos elementos, mayor después');

        // Cantidad impar y el mismo valor repartido entre las dos mitades.
        Clear(Fechas);
        Fechas.Add(D(2026, 3, 1));
        Fechas.Add(D(2026, 1, 1));
        Fechas.Add(D(2026, 3, 1));
        Fechas.Add(D(2026, 2, 1));
        Fechas.Add(D(2026, 3, 1));
        Ordenada := Ctx.OrdenarFechas(Fechas);
        AssertFecha(D(2026, 1, 1), Ordenada.Get(1), 'impar, primero');
        AssertFecha(D(2026, 2, 1), Ordenada.Get(2), 'impar, segundo');
        AssertFecha(D(2026, 3, 1), Ordenada.Get(3), 'impar, tercero');
        AssertFecha(D(2026, 3, 1), Ordenada.Get(4), 'impar, cuarto');
        AssertFecha(D(2026, 3, 1), Ordenada.Get(5), 'los tres repetidos sobreviven');
        AssertEntero(5, Ordenada.Count(), 'la mezcla no pierde ni duplica elementos');
    end;

    local procedure D(Anio: Integer; Mes: Integer; Dia: Integer): Date
    begin
        exit(DMY2Date(Dia, Mes, Anio));
    end;

    local procedure AssertEntero(Esperado: Integer; Obtenido: Integer; Caso: Text)
    begin
        if Esperado <> Obtenido then
            Error(ErrEntero, Caso, Esperado, Obtenido);
    end;

    local procedure AssertFecha(Esperado: Date; Obtenido: Date; Caso: Text)
    begin
        if Esperado <> Obtenido then
            Error(ErrFecha, Caso, Esperado, Obtenido);
    end;

    var
        ErrFecha: Label '%1: se esperaba %2 y se obtuvo %3.', Comment = '%1=caso, %2=fecha esperada, %3=fecha obtenida';
        ErrEntero: Label '%1: se esperaban %2 y se obtuvieron %3.', Comment = '%1=caso, %2=cantidad esperada, %3=cantidad obtenida';
}
