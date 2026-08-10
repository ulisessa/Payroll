namespace UAS.Payroll;

codeunit 50069 "Ejecutor Liquidación"
{
    TableNo = "Liquidación";

    // Envoltorio para poder capturar un cálculo fallido SIN perder el registro del error.
    //
    // La primera versión usaba [TryFunction] y la plataforma la rechazó en tiempo de ejecución:
    // "Una llamada a la función 'MODIFY' no se permite dentro de ... cuando se usa como un objeto
    // TryFunction". Un TryFunction no puede escribir en la base, y liquidar es todo escritura.
    //
    // Codeunit.Run sí puede: crea su propio ámbito de transacción, así que si el cálculo falla la
    // plataforma revierte lo que hizo ESTE codeunit y devuelve false al llamador, que sigue vivo y
    // en condiciones de escribir el registro del error. Es el mismo motivo por el que "Gestión
    // Incidencia Masiva" existe como codeunit aparte.

    trigger OnRun()
    var
        Motor: Codeunit "Motor Liquidación";
    begin
        Motor.LiquidarRecord(Rec);
    end;
}
