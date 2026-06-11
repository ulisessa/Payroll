namespace UAS.Payroll;

enum 50312 "Estado Importación SIRADIG"
{
    Caption = 'Estado Importación SIRADIG';
    value(0; "Pendiente Procesar")
    {
        Caption = 'Pendiente Procesar';
    }
    value(1; "Procesado Exitosamente")
    {
        Caption = 'Procesado Exitosamente';
    }
    value(2; "Procesado con Advertencias")
    {
        Caption = 'Procesado con Advertencias';
    }
    value(3; "Error en Procesamiento")
    {
        Caption = 'Error en Procesamiento';
    }
}
