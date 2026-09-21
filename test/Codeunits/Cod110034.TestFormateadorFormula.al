namespace UAS.Payroll;

codeunit 110034 "Test Formateador Fórmula"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // Tests del formateador de fórmulas. Sin base de datos: texto entra, texto sale.
    //
    // Los dos que realmente importan son ConservaElSignificado e Idempotencia. Un formateador que se
    // ve raro es una molestia; uno que cambia lo que la fórmula calcula, o que da un resultado
    // distinto cada vez que se guarda, es un problema de liquidación.

    // ── Lo que no debe tocar ──────────────────────────────────────────────────

    [Test]
    procedure NoRompeLoCorto()
    begin
        AssertTxt('2 + 3', Formatear('2 + 3'), 'una expresión corta queda en una línea');
        AssertTxt('IF(1, 2, 3)', Formatear('IF(1,2,3)'), 'llamada corta sin saltos');
    end;

    [Test]
    procedure NormalizaEspacios()
    begin
        AssertTxt('IF(1, 2, 3)', Formatear('IF(  1 ,2,   3 )'), 'espacios de más y de menos');
        AssertTxt('A + B * C', Formatear('A+B*C'), 'operadores separados por espacio');
    end;

    [Test]
    procedure MenosUnarioVaPegado()
    begin
        AssertTxt('-BASICO', Formatear('- BASICO'), 'menos unario pegado a lo que niega');
        AssertTxt('A - B', Formatear('A-B'), 'menos binario con espacios');
        AssertTxt('ROUND(-BASICO, 0.01)', Formatear('ROUND(-BASICO,0.01)'), 'unario como argumento');
    end;

    [Test]
    procedure ConservaLiteralesDeTexto()
    begin
        AssertTxt('TRAMO(''TAB_IMP_4CAT'', 100)', Formatear('TRAMO(''TAB_IMP_4CAT'',100)'),
            'el literal entre comillas se conserva tal cual');
    end;

    [Test]
    procedure TextoVacio()
    begin
        AssertTxt('', Formatear(''), 'vacío queda vacío');
        AssertTxt('', Formatear('    '), 'solo espacios queda vacío');
    end;

    // ── Lo que sí debe cortar ─────────────────────────────────────────────────

    [Test]
    procedure CortaLoQueNoEntra()
    var
        Salida: Text;
    begin
        Salida := Formatear(FormulaLarga());
        if not Salida.Contains(Format(SaltoLinea())) then
            Error('Una fórmula de %1 caracteres tendría que cortarse en varias líneas.', StrLen(FormulaLarga()));
        // Un argumento por línea: la fórmula tiene tres argumentos en el IF externo.
        if StrLen(Salida) <= StrLen(FormulaLarga()) then
            Error('El formateo agrega sangría, así que el texto no puede quedar más corto.');
    end;

    [Test]
    procedure CortaLasCadenasLargas()
    var
        Salida: Text;
        Linea: Text;
        Lineas: List of [Text];
    begin
        // El caso que motivó el corte por operador: la base imponible de Ganancias es una cadena de
        // quince términos dentro de UN argumento. Cortando solo en las comas quedaba una línea de
        // 224 caracteres y, peor, el paréntesis del último término se partía en tres renglones,
        // porque para cuando llegaba ahí la columna ya se había pasado del ancho.
        Salida := Formatear(FormulaGanancias());
        Lineas := Salida.Split(Format(SaltoLinea()));
        foreach Linea in Lineas do
            if StrLen(Linea) > 96 then
                Error('Quedó una línea de %1 caracteres, sobre un ancho de 96:\%2', StrLen(Linea), Linea);
    end;

    [Test]
    procedure NoCortaLoQueEntra()
    var
        Corta: Text;
    begin
        // Una cadena que entra en el ancho no se toca: el corte es por necesidad, no por gusto.
        Corta := 'A + B + C + D';
        AssertTxt(Corta, Formatear(Corta), 'una cadena corta queda en una línea');
    end;

    // ── Las dos garantías ─────────────────────────────────────────────────────


    [Test]
    procedure Idempotencia()
    var
        UnaVez: Text;
        DosVeces: Text;
    begin
        // Formatear algo ya formateado no puede cambiarlo. Si no, cada guardado generaría una
        // entrada de historial distinta y el diff nunca se estabilizaría.
        UnaVez := Formatear(FormulaLarga());
        DosVeces := Formatear(UnaVez);
        AssertTxt(UnaVez, DosVeces, 'formatear dos veces da lo mismo que formatear una');
    end;

    [Test]
    procedure ConservaElSignificado()
    var
        Evaluador: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Antes: Decimal;
        Despues: Decimal;
    begin
        // La fórmula formateada —con saltos de línea y sangría— tiene que dar exactamente el mismo
        // número que la original. De paso prueba que el evaluador tolera los saltos, que antes no.
        Evaluador.Init(Ctx, WorkDate());
        Antes := Evaluador.EvalFormula(FormulaLarga());
        Evaluador.Init(Ctx, WorkDate());
        Despues := Evaluador.EvalFormula(Formatear(FormulaLarga()));
        if Antes <> Despues then
            Error('El formateo cambió el resultado: antes %1, después %2.', Antes, Despues);
    end;

    [Test]
    procedure TextoRaroQuedaIntacto()
    var
        Raro: Text;
    begin
        // Un carácter que el tokenizador no reconoce: no se entiende la fórmula, no se la toca.
        Raro := 'A $ B';
        AssertTxt(Raro, Formatear(Raro), 'lo que no se entiende se devuelve tal cual');
    end;

    // ── Helpers ───────────────────────────────────────────────────────────────

    local procedure Formatear(Texto: Text): Text
    var
        Formateador: Codeunit "Formateador Fórmula Liq.";
    begin
        exit(Formateador.Formatear(Texto));
    end;

    // Larga a propósito y sin variables, para poder evaluarla sin contexto.
    local procedure FormulaLarga(): Text
    begin
        exit('IF(1 = 1, ROUND(123.456 * 2 + 1000 * 3 + 500 * 4 + 250 * 5 + 125 * 6 + 60 * 7, 0.01), 0)');
    end;

    // La real del sistema, con toda su cadena de términos.
    local procedure FormulaGanancias(): Text
    begin
        exit('round(MAX(TRAMO(''TAB_IMP_4CAT'',YTD_HAB_GRAV_ANUAL + BASE_IG4 + YTD_HAB_EXTORD_ANUAL + ' +
             'YTD_SAC_DEV + BASE_EXT_IG4 + BASE_SAC_DEV - MNI_ANUAL -SS_LIQUIDADO - SS_SAC_DEV ' +
             '-YTD_SS_LIQUIDADO -YTD_SS_SAC_DEV -DESP_4CAT_ANUAL- DEDUC_GANANCIAS - ' +
             '(DEDUC_GANANCIAS+DESP_4CAT_ANUAL+MNI_ANUAL)/12) - YTD_RETENIDO_ANUAL, 0),0.0001)');
    end;

    local procedure SaltoLinea(): Char
    begin
        exit(10);
    end;

    local procedure AssertTxt(Esperado: Text; Obtenido: Text; Descripción: Text)
    begin
        if Esperado <> Obtenido then
            Error('Falló %1:\esperaba <%2>\obtuve   <%3>', Descripción, Esperado, Obtenido);
    end;
}
