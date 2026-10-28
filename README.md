# Payroll

## Comparar atributos por código

Los atributos de tipo Lista con «Nombre Variable» admiten comparaciones por código con `=` y `<>`:

```text
IF(CONVENIO = '729/15', IMPORTE_BASE, 0)
```

Al escribir `CONVENIO = ` o `CONVENIO <> `, el editor propone los valores configurados. Se puede buscar por código o descripción y elegir con Enter, Tab o clic. El editor inserta las comillas; para códigos con apóstrofes las duplica automáticamente.

La comparación utiliza el código asignado a la entidad y vigente en la fecha de cálculo. Las comparaciones numéricas existentes siguen usando «Valor Numérico». Para probar códigos en el asistente, cargar el contexto completo del empleado: modificar un número de prueba no cambia el código asignado.

Las sugerencias de atributos dependientes muestran también el código del padre. Una comparación por código coincide con ese código bajo cualquier padre; para restringir ambos, combinar las condiciones:

```text
CONVENIO = '729/15' AND CATEGORIA = 'MARINERO'
```

Los códigos inexistentes se rechazan al validar. Un atributo sin asignación vigente no coincide con ningún código (`=` devuelve falso y `<>`, verdadero). Cambiar una descripción no altera las fórmulas; renombrar un código requiere actualizar sus referencias.
