namespace UAS.Payroll;

using Microsoft.Finance.Dimension;

// Extensión sin uso: la clase se mudó a "Entidad Liq.".
//
// Nació colgando la clase del valor de dimensión, para no inventar un maestro paralelo. Pero la
// entidad terminó necesitando ser un registro propio: le hacía falta una ficha, un lugar donde
// crecer sin extender una tabla de sistema, un alta controlada que garantice que toda entidad tiene
// clase, y una relación de tabla real para "Cód. Entidad" en los atributos — que apuntaba a tres
// cosas distintas y por eso no podía tener ninguna.
//
// El campo queda obsoleto y no borrado: sacar un campo de una extensión publicada exige ese paso
// previo. No hay migración de datos porque la clase nunca llegó a cargarse acá.
tableextension 52005 "Clase en Dimension Value" extends "Dimension Value"
{
    fields
    {
        field(52010; "Cód. Clase Entidad"; Code[20])
        {
            Caption = 'Clase de Entidad (obsoleto)';
            DataClassification = CustomerContent;
            ObsoleteState = Pending;
            ObsoleteReason = 'La clase pasó a "Entidad Liq.", que es el maestro operativo. Ver Gestión Entidades Liq.';
        }
    }
}
