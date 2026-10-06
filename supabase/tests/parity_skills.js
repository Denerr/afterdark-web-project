// Paridade atributo/pericia: o catalogo do app (src/data/attributes.js) e a tabela
// do banco (_ad_skill_attr em migration_skill_pairs.sql) precisam ser identicos.
// Uso: node supabase/tests/parity_skills.js   (a partir da raiz do repositorio)
const fs = require('fs'), path = require('path');
const root = path.join(__dirname, '..', '..');
global.window = {};
require(path.join(root, 'src', 'data', 'attributes.js'));
const app = new Map(window.AfterdarkData.skills.map(s => [s.key, s.attr]));
const sql = fs.readFileSync(path.join(root, 'supabase', 'migration_skill_pairs.sql'), 'utf8');
const bloco = sql.slice(sql.indexOf('_ad_skill_attr'), sql.indexOf(') as v(s, a)'));
const db = new Map([...bloco.matchAll(/\('([a-z_]+)','([a-z_]+)'\)/g)].map(m => [m[1], m[2]]));
const erros = [];
for (const [k, a] of app) if (db.get(k) !== a) erros.push(`app ${k}->${a}, banco ${db.get(k) || '(ausente)'}`);
for (const [k, a] of db) if (!app.has(k)) erros.push(`banco tem ${k}->${a}, app nao`);
const attrs = new Set(window.AfterdarkData.attributes.map(a => a.key));
for (const [k, a] of app) if (!attrs.has(a)) erros.push(`pericia ${k} aponta para atributo inexistente ${a}`);
if (erros.length) { console.log('FALHOU paridade:'); erros.forEach(e => console.log('  - ' + e)); process.exit(1); }
console.log(`PASSOU paridade: ${app.size} pericias identicas no app e no banco`);
