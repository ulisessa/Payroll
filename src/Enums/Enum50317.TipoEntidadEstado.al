namespace UAS.Payroll;

enum 50317 "Tipo Entidad Estado"
{
    Extensible = true;
    // Discriminator for the shared state history: an entry belongs to an employee or a vessel.

    value(0; Empleado) { Caption = 'Empleado'; }
    value(1; Buque) { Caption = 'Buque'; }
    // Lo usan los atributos (Atributo Entidad Liq.), no el historial de estados. Agregarlo es seguro
    // porque ningún consumidor enumera los valores de forma exhaustiva: todos filtran por ::Empleado
    // o ::Buque explícitamente, o descartan con <> ::Empleado.
    value(2; Proyecto) { Caption = 'Proyecto (Marea)'; }
}
