namespace UAS.Payroll;

/// <summary>
/// Qué hecho dispara un tipo de liquidación. Uno solo, o ninguno.
/// </summary>
/// <remarks>
/// Eran tres banderas sueltas —"Liquida al Arribo", "Sólo Proyectos en Curso" y la baja del empleado
/// que iba a ser una cuarta— que contestan todas la MISMA pregunta y que en los datos nunca
/// coincidieron: una marea o arribó o sigue navegando, y una baja no es ninguna de las dos. Con
/// banderas, "arribo y en curso a la vez" es representable y no significa nada; con un enum, no se
/// puede ni escribir.
///
/// No entra acá todo lo que Tipo Liquidación tiene marcado: "Agrupa por Empleado" e "Incluye Francos
/// Puerto" son ortogonales —la Regular agrupa y no tiene disparador; el Cierre de Marea no agrupa y
/// sí lo tiene— así que siguen siendo booleanos.
/// </remarks>
enum 50331 "Disparador Tipo Liq."
{
    Extensible = true;
    Caption = 'Disparador';

    value(0; Ninguno)
    {
        Caption = 'Ninguno';
        // Corre para todos los que pasen los demás filtros: el calendario del tipo, sus estados
        // exigidos y la fase de alta. Es el caso de la Regular, Vacaciones y Aguinaldo.
    }
    value(1; Arribo)
    {
        Caption = 'Finalización del proyecto';
        // Cierre de Marea: fecha de referencia = fin del proyecto, cobertura hasta ahí, y los filtros
        // de proyecto y de personal miran esa fecha y el desembarco en vez del fin del período.
        //
        // SE LLAMA "Arribo" POR HISTORIA Y NO POR ALCANCE. El caso que lo motivó es el arribo de una
        // marea, pero lo que el motor mira es la FECHA DE FINALIZACIÓN del proyecto productivo:
        // cualquier proyecto que termine sirve, no hace falta que sea una marea. El identificador
        // quedó para no tocar las cinco referencias por un cambio cosmético; la leyenda es la que
        // manda en pantalla.
    }
    value(2; MareaEnCurso)
    {
        Caption = 'Proyecto en curso';
        // Devengados: sólo los proyectos que al cierre del período TODAVÍA NO ARRIBARON. Mira la
        // fecha de arribo y no el Status del proyecto, que no se mantiene — en enero de 2026 había
        // dos mareas en Open que habían arribado meses antes, y las tres que de verdad navegaban el
        // 31 figuraban como Completed.
    }
    value(3; BajaEmpleado)
    {
        Caption = 'Baja del empleado';
        // Liquidación Final: sólo para quien se fue dentro del período. Corre todos los meses y sale
        // sólo para los que corresponde, en vez de fabricar una por empleado.
    }
}
