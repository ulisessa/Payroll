namespace UAS.Payroll;

/// <summary>Si la línea de estado habilita la liquidación o la impide.</summary>
enum 50332 "Modo Estado Tipo Liq."
{
    Extensible = true;
    Caption = 'Modo';

    value(0; Exige) { Caption = 'Exige'; }
    value(1; Excluye) { Caption = 'Excluye'; }
    // EXCLUYE EL ESTADO CONTRA EXCLUYE A LA PERSONA, y la diferencia decide un recibo entero.
    //
    // "Excluye" descarta UN ESTADO, no al empleado: alcanza con que otro estado justifique para que
    // la liquidación se genere igual. Es lo correcto para NV, PL y PS en la Regular —los días de
    // marea los paga el Cierre, pero los dos días de guardia en puerto los tiene que pagar alguien—,
    // y por eso se escribió así: con la exclusión por persona, 99 empleados perdían 307 días en
    // enero de 2026.
    //
    // Pero hay reglas que son sobre la PERSONA y no sobre el tramo. Una baja es la que lo obliga: el
    // que se fue no lleva Regular, porque su liquidación final ES su regular. Con "Excluye" a secas
    // eso no se puede decir —el empleado tiene estados de trabajo que justifican la Regular por su
    // cuenta, y la exclusión sólo tacha el estado de baja—, y el resultado son los dos documentos
    // pagando lo mismo: medido en enero, seis de siete, dos de ellos al centavo.
    //
    // Este modo corta por el empleado: si CUALQUIER estado suyo cumple la línea, no se genera nada.
    value(2; ExcluyePersona) { Caption = 'Excluye a la persona'; }
}
