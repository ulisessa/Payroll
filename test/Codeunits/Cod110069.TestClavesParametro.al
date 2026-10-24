namespace UAS.Payroll;

// Qué clave de parámetro gana, ahora que la fecha pesa más que el resto de la clave.
//
// La regla es: entre las claves candidatas que tengan valor cargado gana la de VIGENCIA MÁS
// RECIENTE, y la especificidad sólo desempata. Antes ganaba siempre la más específica sin mirar la
// fecha, y una vigencia nueva cargada en la fila genérica no hacía nada —ni error, ni aviso—.
//
// ESTO NO TENÍA NINGUNA PRUEBA, y es la función más central del motor: de ella sale el valor de
// todos los parámetros de todas las fórmulas. Un error acá no da un mensaje: da un importe plausible
// y equivocado. Las pruebas trabajan contra diccionarios, sin base de datos, así que afirman la regla
// y nada más.
//
// Los casos que importan son los dos bordes del cambio: la genérica nueva que ahora SÍ pisa (el caso
// COEF_TANGONERO de febrero de 2026) y el empate de fechas, que es el que protege a una fila
// específica de ser pisada por una genérica del mismo día (el caso PCT_ANTIG de 372/04).
codeunit 110069 "Test Claves Parámetro Liq."
{
    Subtype = Test;
    TestPermissions = Disabled;

    // La regla de siempre: sin fechas en juego gana la más específica.
    [Test]
    procedure MismaFechaGanaLaMasEspecifica()
    var
        Valores: Dictionary of [Code[50], Decimal];
        Vigencias: Dictionary of [Code[50], Date];
    begin
        Cargar(Valores, Vigencias, 'P_729/15', 0.3, D(2026, 1, 1));
        Cargar(Valores, Vigencias, 'P', 1, D(2026, 1, 1));

        AssertClave('P_729/15', Resolver(Valores, Vigencias), 'el empate lo rompe la especificidad');
    end;

    // El caso que motivó el cambio: la genérica de febrero tiene que ganarle a la del convenio de
    // enero. Antes ganaba la del convenio y la fila nueva no hacía nada.
    [Test]
    procedure GenericaPosteriorPisaALaEspecifica()
    var
        Valores: Dictionary of [Code[50], Decimal];
        Vigencias: Dictionary of [Code[50], Date];
    begin
        Cargar(Valores, Vigencias, 'P_729/15', 0.3, D(2026, 1, 1));
        Cargar(Valores, Vigencias, 'P', 1, D(2026, 2, 1));

        AssertClave('P', Resolver(Valores, Vigencias), 'la genérica más nueva manda');
    end;

    // Y al revés sigue andando: una específica nueva le gana a una genérica vieja.
    [Test]
    procedure EspecificaPosteriorSigueGanando()
    var
        Valores: Dictionary of [Code[50], Decimal];
        Vigencias: Dictionary of [Code[50], Date];
    begin
        Cargar(Valores, Vigencias, 'P', 1, D(2026, 1, 1));
        Cargar(Valores, Vigencias, 'P_729/15', 0.3, D(2026, 5, 1));

        AssertClave('P_729/15', Resolver(Valores, Vigencias), 'la específica más nueva manda');
    end;

    // El blindaje de PCT_ANTIG_372/04: fechando la fila específica al mismo día que la genérica, la
    // específica vuelve a ganar. Es la única manera de proteger un valor por convenio sin volver
    // atrás con la regla.
    [Test]
    procedure FecharLaEspecificaLaProtege()
    var
        Claves: Codeunit "Claves Parámetro Liq.";
        Valores: Dictionary of [Code[50], Decimal];
        Vigencias: Dictionary of [Code[50], Date];
    begin
        Cargar(Valores, Vigencias, 'P_372/04', 0.01, D(2026, 1, 1));
        Cargar(Valores, Vigencias, 'P', 0.25, D(2026, 1, 1));

        // El convenio del contexto tiene que ser el de la fila, no el del helper: una clave de otro
        // convenio NO es candidata y la resolución ni la mira. La primera versión de esta prueba
        // cargaba P_372/04 y resolvía con 729/15, así que afirmaba que ganaba una clave que no
        // competía — y la daba por rota al código, no a sí misma.
        AssertClave('P_372/04', Claves.Resolver('P', '', '372/04', '', Valores, Vigencias),
            'misma fecha: gana la del convenio');
    end;

    // Una fila de empleado es la más específica de todas, y con fecha posterior gana sin discusión.
    [Test]
    procedure EmpleadoPosteriorGanaATodos()
    var
        Claves: Codeunit "Claves Parámetro Liq.";
        Valores: Dictionary of [Code[50], Decimal];
        Vigencias: Dictionary of [Code[50], Date];
    begin
        Cargar(Valores, Vigencias, 'P', 1, D(2026, 2, 1));
        Cargar(Valores, Vigencias, 'P_729/15_MR02', 2, D(2026, 1, 1));
        Cargar(Valores, Vigencias, 'P_00191', 3, D(2026, 3, 1));

        AssertClave('P_00191', Claves.Resolver('P', '00191', '729/15', 'MR02', Valores, Vigencias),
            'la del empleado, y además es la más nueva');
    end;

    // Sin ninguna cargada se devuelve la más específica, que el llamador trata como "sin valor".
    // Devolver vacío obligaría a cada llamador a inventarse una clave para el mensaje de error.
    [Test]
    procedure SinNingunaDevuelveLaMasEspecifica()
    var
        Claves: Codeunit "Claves Parámetro Liq.";
        Valores: Dictionary of [Code[50], Decimal];
        Vigencias: Dictionary of [Code[50], Date];
    begin
        AssertClave('P_00191', Claves.Resolver('P', '00191', '729/15', 'MR02', Valores, Vigencias),
            'nada cargado: la más específica, sin valor');
    end;

    // Una candidata con valor pero sin fecha en el mapa no puede ganarle a una fechada: cuenta como
    // la fecha más vieja posible. No debería pasar —los dos mapas se arman juntos—, pero si pasara,
    // lo que no puede hacer es ganar por descarte.
    [Test]
    procedure SinFechaNoLeGanaAUnaFechada()
    var
        Valores: Dictionary of [Code[50], Decimal];
        Vigencias: Dictionary of [Code[50], Date];
    begin
        Valores.Set('P_729/15', 0.3);
        Cargar(Valores, Vigencias, 'P', 1, D(2026, 1, 1));

        AssertClave('P', Resolver(Valores, Vigencias), 'la fechada le gana a la que no tiene fecha');
    end;

    local procedure Resolver(var Valores: Dictionary of [Code[50], Decimal]; var Vigencias: Dictionary of [Code[50], Date]): Code[50]
    var
        Claves: Codeunit "Claves Parámetro Liq.";
    begin
        exit(Claves.Resolver('P', '', '729/15', '', Valores, Vigencias));
    end;

    local procedure Cargar(var Valores: Dictionary of [Code[50], Decimal]; var Vigencias: Dictionary of [Code[50], Date]; Clave: Code[50]; Valor: Decimal; Vigencia: Date)
    begin
        Valores.Set(Clave, Valor);
        Vigencias.Set(Clave, Vigencia);
    end;

    local procedure D(Anio: Integer; Mes: Integer; Dia: Integer): Date
    begin
        exit(DMY2Date(Dia, Mes, Anio));
    end;

    local procedure AssertClave(Esperada: Code[50]; Obtenida: Code[50]; Caso: Text)
    begin
        if Esperada <> Obtenida then
            Error(ErrClave, Caso, Esperada, Obtenida);
    end;

    var
        ErrClave: Label '%1: se esperaba la clave %2 y se obtuvo %3.', Comment = '%1=caso, %2=clave esperada, %3=clave obtenida';
}
