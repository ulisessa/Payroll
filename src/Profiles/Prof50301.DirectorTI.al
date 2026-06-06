namespace UAS.Payroll;
using Microsoft.RoleCenters;

// La navegación de payroll se agrega a la página 9018 vía PagExt50352.
// Este archivo solo es necesario si "Director de TI" NO existe todavía en otra extensión.
// Si ya existe, eliminar este archivo — la pageextension es suficiente.

profile "DIRECTOR-TI"
{
    Caption = 'Director de TI';
    ProfileDescription = 'Administración del sistema y gestión de liquidaciones de haberes.';
    RoleCenter = "Administrator Role Center";
    Enabled = true;
    Promoted = true;
}
