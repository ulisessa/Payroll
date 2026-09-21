namespace UAS.Payroll;

codeunit 50077 "Gestión Variables Sistema"
{
    // Siembra el catálogo estándar de Variables de Sistema. Idempotente: agrega solo lo que falta y
    // no toca lo que ya está, así que se puede correr sin miedo sobre una tabla con datos.
    //
    // La tabla es configuración pura —ningún proceso la escribe— y sin ella el motor no resuelve
    // ninguna variable de sistema: Contexto Liquidación sale sin cargar nada y el evaluador corta
    // con "Variable desconocida en la fórmula" en la primera fórmula que use una. Una empresa nueva
    // arranca exactamente así, y hasta ahora la única forma de poblarla era a mano.
    //
    // La lista de abajo es el espejo del case de ComputeVariableSistema (Cod50016): si se agrega un
    // Cód. Cálculo al motor, va también acá y en el StrMenu de la tabla.
    //
    // Quedan afuera a propósito YTD_ACUM y YTD_LINEAS: no tienen un nombre canónico ni sentido
    // propio hasta que se les dice CUÁL acumulador o CUÁL tipo de concepto sumar, y la misma
    // instalación suele tener varias (HAB_GRAV_ANUAL→BASE_IG4, HAB_EXTORD_ANUAL→BASE_EXT_IG4).
    // Sembrarlas con un nombre inventado dejaría filas que devuelven cero sin decir por qué.

    Access = Public;

    /// <summary>Agrega las variables estándar que falten. Devuelve cuántas insertó.</summary>
    procedure Sembrar(): Integer
    begin
        FAgregadas := 0;

        Agregar('AÑOS_ANTIGUEDAD', 'Años de antigüedad desde la fecha de ingreso hasta el fin del período');
        Agregar('AÑOS_ANTIG_30JUN', 'Años completos de antigüedad al 30 de junio vigente (Art. 32 CCT)');
        Agregar('DIAS_HAB', 'Días hábiles (lunes a viernes) del período de liquidación');
        Agregar('DIAS_HAB_AÑO', 'Días hábiles del año calendario de la fecha de referencia');
        Agregar('DIAS_ALTA_AÑO', 'Días hábiles del año con el empleado de alta');
        Agregar('DIAS_FERIADOS', 'Días feriados del período, según el calendario del período');
        Agregar('DIAS_FERIADOS_MAREA', 'Días feriados dentro de la ventana de la marea (feriados a bordo)');
        Agregar('DIAS_FERIADOS_GUARDIA', 'Días feriados a bordo pero fuera de la marea: guardia en puerto, dique, pilotaje');
        Agregar('DIAS_PROYECTO', 'Días de navegación de la marea dentro de la ventana de liquidación');
        Agregar('DIAS_PUERTO', 'Días de puerto (bordes) de la marea dentro de la ventana de liquidación');
        Agregar('DIAS_MAREA', 'Días totales de la marea en la ventana de liquidación: navegación más puerto');
        Agregar('DIAS_ENROLAMIENTO', 'Días calendario enrolado en toda la marea, en estados que devengan francos');
        Agregar('DIAS_FRANCOS_PERIODO', 'Días calendario en estado Francos dentro del período');
        Agregar('FRANCOS_CONSUMIDOS', 'Francos consumidos en el período: el menor entre días en Francos y saldo');
        Agregar('PAGO_FRANCOS_FIFO', 'Importe de los francos consumidos, FIFO, cada lote a su propio valor');
        Agregar('SALDO_FRANCOS', 'Saldo de francos pendientes del empleado (devengados menos consumidos)');
        Agregar('PCT_ESCALA', 'Porcentaje de escala de la Categoría CCT, dividido 100');
        Agregar('VACACIONES_ANUALES', 'Días de vacaciones por antigüedad (Art. 150 LCT)');
        Agregar('VACACIONES_PROP_DIAS', 'Días de vacaciones proporcionales (días de alta en el año / 20)');
        Agregar('DIAS_VAC_PERIODO', 'Días en estado Vacaciones que caen dentro del período');
        Agregar('MESES_PROM_VAC', 'Períodos mensuales a promediar para vacaciones (Art. 34 CCT): entre 0 y 6');
        Agregar('DEDUC_GANANCIAS', 'Deducciones anuales de Ganancias: cargas de familia más gastos deducibles');
        Agregar('MES_ANUAL', 'Número de mes de la fecha de referencia (1 a 12)');

        exit(FAgregadas);
    end;

    /// <remarks>
    /// La idempotencia va por Cód. Cálculo y NO por la clave primaria, que es el Nombre Variable: el
    /// nombre es configurable —una instalación pudo renombrar DIAS_HAB a DIAS_HABILES para que las
    /// fórmulas se lean mejor— y buscar por clave insertaría una segunda fila que calcula
    /// exactamente lo mismo con otro nombre, duplicando el valor en el contexto.
    ///
    /// Tampoco se toca la fila existente: si alguien la dejó inactiva o le cambió la descripción,
    /// fue a propósito, y un sembrado no es el lugar para revisarlo.
    /// </remarks>
    local procedure Agregar(CodCalculo: Code[30]; Desc: Text[100])
    var
        VarSis: Record "Variable Sistema Liq.";
    begin
        VarSis.SetRange("Cód. Cálculo", CodCalculo);
        if not VarSis.IsEmpty() then
            exit;

        VarSis.Reset();
        VarSis.Init();
        VarSis."Cód. Cálculo" := CodCalculo;
        // Por convención el nombre arranca igual al código de cálculo. Es lo que esperan las
        // fórmulas escritas contra la documentación de la tabla, y se puede renombrar después sin
        // tocar nada: el motor busca por Cód. Cálculo y expone el Nombre Variable.
        VarSis."Nombre Variable" := CodCalculo;
        VarSis.Descripción := Desc;
        VarSis.Activo := true;
        VarSis.Insert();
        FAgregadas += 1;
    end;


    var
        FAgregadas: Integer;
}
