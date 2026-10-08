namespace UAS.Payroll;

enum 50305 "Estado Período Liq."
{
    Extensible = false;

    value(0; "Abierto") { Caption = 'Abierto'; }
    value(1; "Cerrado") { Caption = 'Cerrado'; }
    // Existe pero todavía no se opera: las listas y los selectores no lo muestran y ninguna carga ni
    // cálculo lo acepta. Va último en el número y no al principio para no renumerar los dos que ya
    // tienen datos; el ciclo es Creado → Abierto → Cerrado.
    value(2; "Creado") { Caption = 'Creado'; }
}
