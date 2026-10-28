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
    // Los cálculos sin parámetros se agregan acá y al StrMenu de la tabla. Los mecanismos genéricos
    // que requieren un estado, concepto, acumulador o tipo se ofrecen en el lookup y se configuran
    // con datos de la instalación; tener un Cód. Cálculo no obliga a inventar un nombre estándar.
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
        AgregarPorConcepto('SAC_JUB_PAGADO_MES', '6002', 'Jubilación SAC ya descontada en otras liquidaciones del mes');
        AgregarPorConcepto('SAC_LEY_PAGADO_MES', '6012', 'Ley 19032 SAC ya descontada en otras liquidaciones del mes');
        AgregarPorConcepto('SAC_OS_PAGADO_MES', '6034', 'Obra social SAC ya descontada en otras liquidaciones del mes');
        AgregarPorConcepto('SAC_SIND_PAGADO_MES', '8523', 'Cuota sindical SAC ya descontada en otras liquidaciones del mes');
        AgregarPorConcepto('MES_CONTRIB_SIND', '7090', 'Otras contribuciones sindicales ya liquidadas en otras liquidaciones del mes');

        Agregar('AÑOS_ANTIGUEDAD', 'Años de antigüedad desde la fecha de ingreso hasta el fin del período');
        Agregar('AÑOS_ANTIG_30JUN', 'Años completos de antigüedad al 30 de junio vigente (Art. 32 CCT)');
        Agregar('DIAS_HAB', 'Días hábiles (lunes a viernes) del período de liquidación');
        // Su COMPLEMENTO —30 menos esto— son los días que el sueldo mensual no devengó, y es lo que
        // lo prorratea. Ojo de no confundirla con DIAS_MES, que da los días calendario: 31 en enero.
        Agregar('DIAS_ALTA_30', 'Días del mes comercial de 30 con el empleado de alta (el día 31 no cuenta)');
        Agregar('DIAS_HAB_AÑO', 'Días hábiles del año calendario de la fecha de referencia');
        Agregar('DIAS_ALTA_AÑO', 'Días hábiles del año con el empleado de alta');
        Agregar('DIAS_FERIADOS', 'Días feriados del período, según el calendario del período');
        Agregar('DIAS_FERIADOS_MAREA', 'Días feriados dentro de la ventana de la marea (feriados a bordo)');
        Agregar('DIAS_FERIADOS_GUARDIA', 'Días feriados a bordo pero fuera de la marea: guardia en puerto, dique, pilotaje');
        Agregar('DIAS_PROYECTO', 'Días de navegación de la marea dentro de la ventana de liquidación');
        Agregar('DIAS_PUERTO', 'Días de puerto (bordes) de la marea dentro de la ventana de liquidación');
        Agregar('DIAS_MAREA', 'Días totales de la marea en la ventana de liquidación: navegación más puerto');
        Agregar('HORAS_PROYECTO', 'Horas del proyecto, de la zarpada al arribo (fecha y hora); 0 si falta alguna fecha');
        Agregar('DIAS_ENROLAMIENTO', 'Días calendario enrolado en toda la marea, en estados que devengan francos');
        Agregar('DIAS_FRANCOS_PERIODO', 'Días calendario en estado Francos dentro del período');
        Agregar('FRANCOS_CONSUMIDOS', 'Francos consumidos en el período: el menor entre días en Francos y saldo');
        Agregar('PAGO_FRANCOS_FIFO', 'Importe de los francos consumidos, FIFO, cada lote a su propio valor');
        Agregar('SALDO_FRANCOS', 'Saldo de francos pendientes del empleado (devengados menos consumidos)');
        Agregar('DIAS_ALTA_SEMESTRE', 'Días calendario de alta desde el inicio del semestre al cierre del período (DIAS_SAC de Meta4)');
        Agregar('EXCESO_NETO_GU_MES', 'Neto pagado de más sobre el objetivo en las liquidaciones anteriores del mes con grossing-up');
        Agregar('PAGO_FRANCOS_SALDO', 'Importe del saldo entero de francos, FIFO: indemnización por no gozados');
        Agregar('PCT_ESCALA', 'Porcentaje de escala de la Categoría CCT, dividido 100');
        Agregar('VACACIONES_ANUALES', 'Días de vacaciones por antigüedad (Art. 150 LCT)');
        Agregar('VACACIONES_PROP_DIAS', 'Días de vacaciones proporcionales (días de alta en el año / 20)');
        Agregar('DIAS_VAC_PERIODO', 'Días en estado Vacaciones que caen dentro del período');
        Agregar('MESES_PROM_VAC', 'Períodos mensuales a promediar para vacaciones (Art. 34 CCT): entre 0 y 6');
        Agregar('VENT_PROM_ES_MES_ACTUAL', 'La ventana del promedio de vacaciones es el mes en curso: 1 o 0');
        Agregar('DIAS_PREST_PROM_VAC', 'Días de prestación en la ventana del promedio: el divisor del Art. 49 (base/días*30)');
        Agregar('DIAS_DEVENGA_FRANCOS_COBERTURA', 'Días de estados que devengan francos dentro de la cobertura de la liquidación');
        Agregar('VALOR_FRANCO_DIA', 'Precio de un día de franco para el par que paga esta liquidación');
        Agregar('BASE_SAC_SEMESTRE', 'Remuneraciones del semestre en curso ya grabadas: base del SAC de egreso (Art. 121 LCT)');
        Agregar('MESES_PROM_AUS_6', 'Meses con alta dentro del semestre anterior al inicio de la licencia: divisor del promedio');
        Agregar('MESES_PROM_AUS_12', 'Meses con alta dentro de los 12 meses anteriores al inicio de la licencia: divisor del promedio');
        // Los divisores de licencia requieren Cód. Estado y parámetros de ventana: se cargan como
        // configuración, incluidos los nombres de compatibilidad DIV_PROM_ENF_6/12.

        // DIAS_ESTADO_PERIODO y DIAS_ESTADO_PREVIOS requieren Cód. Estado: los nombres de ausentismo
        // y su origen (fuente de datos o variable genérica) pertenecen a la configuración.
        // No recrear aquí las antiguas asociaciones a AU1/ACC ni modificar filas existentes.
        Agregar('DEDUC_GANANCIAS', 'Deducciones anuales de Ganancias: cargas de familia más gastos deducibles');
        Agregar('DEDUC_GANANCIAS_ACUM', 'Deducciones de Ganancias acumuladas del año: familia mes a mes más gastos declarados');
        Agregar('MES_ANUAL', 'Número de mes de la fecha de referencia (1 a 12)');
        // La forma recomendada es comparar por código —TIPO_LIQ = 'LIQ_FINAL'—, que el editor
        // autocompleta con la lista de tipos. El Orden numérico sigue funcionando y lo usan las
        // fórmulas viejas, pero no se puede leer: la descripción no enumera los números a propósito,
        // porque una lista escrita a mano acá se desactualiza el día que se agrega un tipo.
        Agregar('TIPO_LIQ', 'Tipo de liquidación. Comparar por código: TIPO_LIQ = ''LIQ_FINAL'' (o su Orden numérico)');

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
    local procedure AgregarPorConcepto(Nombre: Code[30]; Concepto: Code[20]; Desc: Text[100])
    var
        VarSis: Record "Variable Sistema Liq.";
    begin
        VarSis.SetRange("Nombre Variable", Nombre);
        if not VarSis.IsEmpty() then
            exit;
        VarSis.Init();
        VarSis."Nombre Variable" := Nombre;
        VarSis."Cód. Cálculo" := 'PERIODO_CONCEPTO';
        VarSis."Cód. Concepto" := Concepto;
        VarSis.Descripción := Desc;
        VarSis.Activo := true;
        VarSis.Insert();
        FAgregadas += 1;
    end;

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
