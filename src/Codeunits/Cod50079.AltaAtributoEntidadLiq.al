namespace UAS.Payroll;

/// <summary>
/// Inserta un Atributo de Entidad en su propio ámbito de transacción, para que un alta fallida no
/// se lleve puesta la corrida.
/// </summary>
/// <remarks>
/// Existe por la misma razón que el ejecutor del motor: un [TryFunction] no puede escribir en la
/// base —"Una llamada a la función 'MODIFY' no se permite dentro de un TryFunction"— y acá todo es
/// escritura. Codeunit.Run abre su propia transacción, así que cuando el alta falla la plataforma
/// revierte lo que hizo y el llamador sigue con el siguiente registro.
///
/// El llamador tiene que hacer Commit() antes de cada Run: la plataforma solo deja USAR el valor de
/// retorno de Codeunit.Run cuando la transacción no tiene escrituras pendientes, y en un lote la
/// vuelta anterior siempre dejó alguna.
///
/// Se pasa el registro con todos los campos puestos, "Cód. Valor" incluido: el OnInsert de la tabla
/// resuelve el valor padre, verifica que el valor exista colgando de él y congela el numérico.
/// </remarks>
codeunit 50079 "Alta Atributo Entidad Liq."
{
    TableNo = "Atributo Entidad Liq.";

    trigger OnRun()
    begin
        Rec.Insert(true);
    end;
}
