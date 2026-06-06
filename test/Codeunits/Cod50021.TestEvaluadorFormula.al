namespace UAS.Payroll;

codeunit 50021 "Test Evaluador Fórmula"
{
    Subtype = Test;
    TestPermissions = Disabled;

    // Unit tests for the formula evaluator. No DB writes — pure expression tests.
    // Assertions use Error() so a failing test surfaces directly in the runner output.

    // ── Arithmetic ────────────────────────────────────────────────────────────

    [Test]
    procedure SumaSimple()
    begin
        AssertEq(5, Eval('2 + 3'), 'suma simple');
    end;

    [Test]
    procedure RestaConParentesis()
    begin
        AssertEq(0, Eval('(2 + 3) - 5'), 'resta con paréntesis');
    end;

    [Test]
    procedure Precedencia()
    begin
        AssertEq(14, Eval('2 + 3 * 4'), 'multiplicación antes que suma');
        AssertEq(20, Eval('(2 + 3) * 4'), 'paréntesis fuerzan suma primero');
    end;

    [Test]
    procedure UnaryMinus()
    begin
        AssertEq(-5, Eval('-5'), 'unary minus simple');
        AssertEq(5, Eval('--5'), 'doble unary minus');
        AssertEq(-7, Eval('-(3 + 4)'), 'unary minus sobre paréntesis');
    end;

    [Test]
    procedure UnaryPlus()
    begin
        AssertEq(5, Eval('+5'), 'unary plus simple');
        AssertEq(7, Eval('+(3 + 4)'), 'unary plus sobre paréntesis');
    end;

    [Test]
    procedure DivisionExacta()
    begin
        AssertEq(2.5, Eval('10 / 4'), 'división decimal');
    end;

    // ── Funciones built-in ───────────────────────────────────────────────────

    [Test]
    procedure ABSPositivoYNegativo()
    begin
        AssertEq(5, Eval('ABS(5)'), 'ABS positivo');
        AssertEq(5, Eval('ABS(-5)'), 'ABS negativo');
    end;

    [Test]
    procedure MAXyMIN()
    begin
        AssertEq(10, Eval('MAX(3, 10)'), 'MAX devuelve el mayor');
        AssertEq(3, Eval('MIN(3, 10)'), 'MIN devuelve el menor');
        AssertEq(3, Eval('MAX(-3, 3)'), 'MAX con negativos');
    end;

    [Test]
    procedure RoundEjemplos()
    begin
        AssertEq(10, Eval('ROUND(9.6, 1)'), 'ROUND a entero');
        AssertEq(1.5, Eval('ROUND(1.499, 0.5)'), 'ROUND a 0.5');
    end;

    [Test]
    procedure DivSegura()
    begin
        AssertEq(0, Eval('DIV(10, 0)'), 'DIV(_,0) = 0 sin error');
        AssertEq(2.5, Eval('DIV(10, 4)'), 'DIV normal');
    end;

    // ── IF lazy ───────────────────────────────────────────────────────────────

    [Test]
    procedure IFRamaTrue()
    begin
        AssertEq(100, Eval('IF(1, 100, 200)'), 'IF true → rama true');
    end;

    [Test]
    procedure IFRamaFalse()
    begin
        AssertEq(200, Eval('IF(0, 100, 200)'), 'IF false → rama false');
    end;

    [Test]
    procedure IFLazyEvitaDivCero()
    var
        Evaluador: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Result: Decimal;
        OK: Boolean;
    begin
        // Si fuera eager, la rama no seleccionada (5 / 0) abortaría con error.
        // Con lazy IF la rama muerta nunca se evalúa.
        Evaluador.Init(Ctx, WorkDate());
        OK := Evaluador.TryEvalFormula('IF(1, 42, 5 / 0)', Result);
        if not OK then
            Error('IF lazy: la rama false con división por cero NO debería evaluarse. Error: %1', GetLastErrorText());
        AssertEq(42, Result, 'IF lazy con rama muerta peligrosa');

        OK := Evaluador.TryEvalFormula('IF(0, 5 / 0, 42)', Result);
        if not OK then
            Error('IF lazy: la rama true con división por cero NO debería evaluarse. Error: %1', GetLastErrorText());
        AssertEq(42, Result, 'IF lazy con rama true muerta peligrosa');
    end;

    // ── Comparadores y booleanos ─────────────────────────────────────────────

    [Test]
    procedure ComparadoresIgualdad()
    begin
        AssertEq(1, Eval('5 = 5'), 'igualdad true → 1');
        AssertEq(0, Eval('5 = 6'), 'igualdad false → 0');
        AssertEq(1, Eval('5 <> 6'), 'desigualdad true');
    end;

    [Test]
    procedure ComparadoresOrden()
    begin
        AssertEq(1, Eval('3 < 5'), '<');
        AssertEq(1, Eval('5 > 3'), '>');
        AssertEq(1, Eval('5 <= 5'), '<=');
        AssertEq(1, Eval('5 >= 5'), '>=');
        AssertEq(0, Eval('5 < 5'), '< estricto');
    end;

    [Test]
    procedure ANDORNOT()
    begin
        AssertEq(1, Eval('1 AND 1'), 'AND true');
        AssertEq(0, Eval('1 AND 0'), 'AND con un falso');
        AssertEq(1, Eval('0 OR 1'), 'OR con uno verdadero');
        AssertEq(0, Eval('0 OR 0'), 'OR con dos falsos');
        AssertEq(1, Eval('NOT 0'), 'NOT 0 → 1');
        AssertEq(0, Eval('NOT 1'), 'NOT 1 → 0');
    end;

    [Test]
    procedure CondicionCombinada()
    var
        Evaluador: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Resultado: Boolean;
    begin
        Evaluador.Init(Ctx, WorkDate());
        Resultado := Evaluador.EvalCondicion('5 > 3 AND 10 <= 10');
        if not Resultado then
            Error('Condición compuesta debería ser true');
        Resultado := Evaluador.EvalCondicion('5 > 3 AND 10 < 10');
        if Resultado then
            Error('Condición con conjunción falsa debería ser false');
    end;

    // ── Variables ────────────────────────────────────────────────────────────

    [Test]
    procedure ResolucionVariable()
    var
        Evaluador: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
    begin
        Ctx.Add('BASICO', 1000);
        Ctx.Add('PCT_ESCALA', 1.5);
        Evaluador.Init(Ctx, WorkDate());
        AssertEq(1500, Evaluador.EvalFormula('BASICO * PCT_ESCALA'), 'BASICO * PCT_ESCALA');
        AssertEq(2500, Evaluador.EvalFormula('BASICO + 1500'), 'BASICO + literal');
    end;

    [Test]
    procedure VariableDesconocidaDaError()
    var
        Evaluador: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Dummy: Decimal;
        OK: Boolean;
    begin
        Evaluador.Init(Ctx, WorkDate());
        OK := Evaluador.TryEvalFormula('NO_EXISTE + 1', Dummy);
        if OK then
            Error('Variable desconocida debería disparar error');
    end;

    [Test]
    procedure DivisionPorCeroErrorFueraDeDiv()
    var
        Evaluador: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        Dummy: Decimal;
        OK: Boolean;
    begin
        Evaluador.Init(Ctx, WorkDate());
        OK := Evaluador.TryEvalFormula('5 / 0', Dummy);
        if OK then
            Error('División por cero (fuera de DIV) debería dar error');
    end;

    // ── Casos borde de tokenizer ─────────────────────────────────────────────

    [Test]
    procedure DecimalConComa()
    begin
        AssertEq(1.5, Eval('0,5 + 1'), 'decimal con coma');
    end;

    [Test]
    procedure DecimalConPunto()
    begin
        AssertEq(1.5, Eval('0.5 + 1'), 'decimal con punto');
    end;

    [Test]
    procedure CondicionVaciaEsTrue()
    var
        Evaluador: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
    begin
        Evaluador.Init(Ctx, WorkDate());
        if not Evaluador.EvalCondicion('') then
            Error('Condición vacía debería ser true');
        if not Evaluador.EvalCondicion('   ') then
            Error('Condición sólo con espacios debería ser true');
    end;

    [Test]
    procedure FormulaVaciaEsCero()
    begin
        AssertEq(0, Eval(''), 'fórmula vacía → 0');
        AssertEq(0, Eval('   '), 'fórmula con espacios → 0');
    end;

    // ── Helpers ──────────────────────────────────────────────────────────────

    local procedure Eval(Formula: Text): Decimal
    var
        Evaluador: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
    begin
        Evaluador.Init(Ctx, WorkDate());
        exit(Evaluador.EvalFormula(Formula));
    end;

    local procedure AssertEq(Expected: Decimal; Actual: Decimal; Description: Text)
    begin
        if Expected <> Actual then
            Error('Falló %1: esperaba %2, obtuve %3.', Description, Expected, Actual);
    end;
}
