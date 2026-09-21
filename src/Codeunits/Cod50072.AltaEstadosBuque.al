namespace UAS.Payroll;

/// <summary>
/// Da de alta los códigos de estado operativo de buque, equivalentes al enum "Vessel Status" de la
/// extensión Producción.Descargas.
/// </summary>
/// <remarks>
/// Se traen a "Cód. Estado Empleado" con Ámbito = Buque porque acá el estado del buque hace algo:
/// tiene vigencia con fecha fin, mantiene contigüidad, y al pasar de productivo a improductivo
/// mueve a toda la tripulación a su "Estado Siguiente" (ver Gestión Estado Empleado.SetEstadoBuque).
/// En la tabla "Vessel Status" era una etiqueta que ningún proceso leía.
///
/// Es IDEMPOTENTE y NO PISA nada: solo crea los códigos que falten. Si un código ya existe se deja
/// tal cual, porque puede haberse ajustado a mano y esa decisión vale más que estos valores por
/// defecto.
/// </remarks>
codeunit 50072 "Alta Estados Buque"
{
    Access = Public;

    procedure CrearFaltantes() Creados: Integer
    begin
        // "Devenga Francos" es lo que decide la cascada: al pasar de un estado que lo tiene a uno
        // que no, la tripulación avanza a su Estado Siguiente (embarcado → Francos) y arranca el
        // consumo. Es la marca que hay que revisar antes de usar esto en producción.
        Creados += Crear('PESCA', 'En pesca', true);
        Creados += Crear('NAVEGACION', 'En navegación', false);
        Creados += Crear('PUERTO', 'En puerto', false);
        Creados += Crear('AMARRADO', 'Amarrado', false);
        Creados += Crear('DIQUE', 'En dique', false);
    end;

    local procedure Crear(Codigo: Code[20]; Descripcion: Text[100]; DevengaFrancos: Boolean): Integer
    var
        CodEst: Record "Cód. Estado Empleado";
    begin
        if CodEst.Get(Codigo) then
            exit(0);

        CodEst.Init();
        CodEst.Código := Codigo;
        CodEst.Descripción := Descripcion;
        CodEst."Ámbito" := CodEst."Ámbito"::Buque;
        CodEst."Tipo Estado" := CodEst."Tipo Estado"::Normal;
        CodEst."Devenga Francos" := DevengaFrancos;
        CodEst.Activo := true;
        // "Estado Siguiente" queda vacío a propósito: en la cascada de arribo, el estado siguiente
        // que importa es el DEL EMPLEADO, no el del buque. Ver AvanzarEmpleadosAEstadoSiguiente.
        CodEst.Insert(true);
        exit(1);
    end;
}
