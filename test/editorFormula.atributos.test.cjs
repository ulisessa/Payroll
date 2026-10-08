const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
// Exponer el detector solo en esta copia de prueba, sin alterar la API del add-in.
const source = fs.readFileSync(path.join(__dirname, '../src/ControlAddIns/EditorFormula/editorFormula.js'), 'utf8')
    .replace('init: function (contenedor)', '_valores: valoresAtributoEnCursor, init: function (contenedor)');
const sandbox = { window: {} };
vm.runInNewContext(source, sandbox);
const editor = sandbox.window.UASEditorFormula;
editor.setCatalogo(JSON.stringify({ variables: [{ nombre: 'CONVENIO', valoresAtributo: [
    { codigo: '729/15', desc: 'Marineros', padre: '' },
    { codigo: '175/75', desc: 'Personal', padre: 'PADRE' },
    { codigo: "D'ANGELO", desc: 'Con comilla', padre: '' }
] }] }));
function sugerir(value, cursor = value.length) {
    return editor._valores({ ta: { value, selectionStart: cursor } });
}
assert.equal(sugerir('CONVENIO = ').items.length, 3);
assert.equal(sugerir('IF(convenio <> ').items.length, 3);
assert.equal(sugerir("IF(CONVENIO = '729/").items[0].insertar, "'729/15'");
assert.equal(sugerir('CONVENIO = marin').items[0].insertar, "'729/15'");
assert.equal(sugerir('CONVENIO = PADRE').items[0].valor, 'PADRE');
assert.equal(sugerir('CONVENIO > '), null);
assert.equal(sugerir('OTRA = '), null);
assert.equal(sugerir('2 + CONVENIO = '), null);
assert.equal(sugerir("TRAMO('CONVENIO = "), null);
assert.equal(sugerir("CONVENIO = '729/15'"), null);
assert.equal(sugerir('CONVENIO = inexistente').items.length, 0);
const formula = "IF(CONVENIO = '729/15', 1, 0)";
const r = sugerir(formula, formula.indexOf('/15'));
const editada = formula.slice(0, r.rango.ini) + r.items[0].insertar + formula.slice(r.rango.fin);
assert.equal(editada, formula);
assert.equal(sugerir("CONVENIO = 'D''A").items[0].insertar, "'D''ANGELO'");
console.log('14 comprobaciones de sugerencias de atributos correctas.');
