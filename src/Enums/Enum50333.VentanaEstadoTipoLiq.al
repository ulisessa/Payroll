namespace UAS.Payroll;

/// <summary>Sobre qué días se busca el estado que la línea exige o excluye.</summary>
/// <remarks>
/// COBERTURA NO ES EL PERÍODO. Un cierre de marea cubre los días del viaje, no el mes entero; buscar
/// en el mes le daría por buenos días que esa liquidación no va a pagar. La definición es la de
/// "Liquidación.Cobertura", la misma que después guarda el motor y que usa Gestión Novedades para
/// repartirlas, y se puede resolver antes de insertar porque sólo depende del período, el tipo y el
/// proyecto.
///
/// MES SIGUIENTE es para las vacaciones que se pagan por adelantado: el empleado todavía no tiene el
/// estado, lo va a tener. Sin esta ventana habría que duplicar el tipo.
/// </remarks>
enum 50333 "Ventana Estado Tipo Liq."
{
    Extensible = true;
    Caption = 'Ventana';

    value(0; Cobertura) { Caption = 'Días que cubre la liquidación'; }
    value(1; Periodo) { Caption = 'Período completo'; }
    value(2; MesSiguiente) { Caption = 'Mes siguiente'; }
}
