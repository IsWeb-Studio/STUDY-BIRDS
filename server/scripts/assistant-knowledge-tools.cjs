// Build-time only. No provider calls, database access, or source modifications.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
function scan(root, prefix, extensions) {
  const rows = [], skippedLinks = [];
  function visit(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true }).sort((a,b)=>a.name.localeCompare(b.name))) {
      const file = path.join(dir, entry.name), stat = fs.lstatSync(file);
      if (stat.isSymbolicLink()) { skippedLinks.push(file); continue; }
      if (stat.isDirectory()) visit(file);
      else if (stat.isFile() && extensions.includes(path.extname(file))) {
        const bytes = fs.readFileSync(file), text = bytes.toString('utf8');
        rows.push({ path: prefix + path.relative(root, file).replace(/\\/g, '/'), sha256: hash(bytes),
          dependencies: [...text.matchAll(/(?:require\(\s*['"]([^'"]+)['"]|(?:import|export)\s+(?:[^;]*?from\s+)?['"]([^'"]+)['"])/g)]
            .map(m=>m[1]||m[2]).filter(ref=>ref.startsWith('.'))
            .map(ref=>{
              const target=path.resolve(path.dirname(file),ref);
              const actual=['','.js','.dart','.ts','.tsx'].map(ext=>target+ext).find(p=>fs.existsSync(p)&&fs.statSync(p).isFile());
              return actual?path.posix.normalize(prefix+path.relative(root,actual).replace(/\\/g,'/')):null;
            }).filter(Boolean),
          screens: [...text.matchAll(/\bclass\s+([A-Z]\w*(?:Screen|Hub))\s+extends\s+/g)].map(m=>m[1]),
          routes: [...text.matchAll(/(?:router\.(get|post|put|patch|delete)\s*\(\s*['"]([^'"]+)['"]|<Route\s+path="([^"]+)")/g)].map(m=>m[3]||`${m[1].toUpperCase()} ${m[2]}`),
        });
      }
    }
  }
  visit(root); return { rows, skippedLinks };
}
function collect(roots) {
  const sections = [scan(path.join(roots.mobile, 'lib'), 'mobile:lib/', ['.dart']),
    scan(path.join(roots.server, 'src/routes'), 'server:src/routes/', ['.js']),
    scan(path.join(roots.server, 'src/models'), 'server:src/models/', ['.js']),
    scan(path.join(roots.server, 'src/controllers'), 'server:src/controllers/', ['.js']),
    scan(path.join(roots.server, 'src/utils'), 'server:src/utils/', ['.js']),
    scan(path.join(roots.website, 'src'), 'website:src/', ['.tsx','.ts'])];
  return { sources: sections.flatMap(s=>s.rows), skippedLinks: sections.flatMap(s=>s.skippedLinks) };
}
function compare(expected, current) {
  const before = new Map(expected.map(s=>[s.path,s.sha256]));
  const after = new Map(current.map(s=>[s.path,s.sha256]));
  return [...new Set([...before.keys(),...after.keys()])].filter(p=>before.get(p)!==after.get(p));
}
function affectedEntries(catalog, changed, sources = []) {
  const impacted=new Set(changed);
  let more=true;
  while(more){more=false;for(const source of sources){
    if(!impacted.has(source.path)&&source.dependencies?.some(p=>impacted.has(p))){impacted.add(source.path);more=true;}
  }}
  return catalog.entries.filter(e=>e.sources.some(p=>impacted.has(p))).map(e=>e.id);
}
function validateBindings(catalog, roots) {
  const source=fs.readFileSync(path.join(roots.mobile,'lib/screens/ai/assistant_navigation.dart'),'utf8');
  const version=source.match(/knowledgeVersion\s*=\s*'([^']+)'/)?.[1];
  const actions=new Set([...source.matchAll(/'([a-z-]+)'\s*=>\s*const\s+\w+\(/g)].map(m=>m[1]));
  return {versionMatches:version===catalog.version,missingActions:catalog.entries.filter(e=>e.action&&!actions.has(e.action)).map(e=>e.id)};
}
if (require.main === module) {
  const args = process.argv.slice(2);
  const get = key => { const i=args.indexOf(key); return i<0?null:args[i+1]; };
  const roots = { mobile:get('--mobile-root'), website:get('--website-root'), server:path.resolve(__dirname,'..') };
  if (!roots.mobile || !roots.website) throw new Error('Explicit --mobile-root and --website-root required');
  const catalog = require('../src/knowledge/assistantKnowledge.json');
  const bindings=validateBindings(catalog,roots);
  if(!bindings.versionMatches||bindings.missingActions.length)throw new Error(`Invalid Flutter bindings: ${JSON.stringify(bindings)}`);
  const current = collect(roots);
  const snapshotPath = path.join(__dirname,'../src/knowledge/assistantSourceSnapshot.json');
  if (args.includes('--record-reviewed-snapshot')) {
    // Explicit authoring operation only. CI must invoke verification without
    // this flag. Review knowledge before accepting a changed source snapshot.
    const sourcePaths = new Set(current.sources.map(s=>s.path));
    for (const e of catalog.entries) for(const source of e.sources) {
      if(!sourcePaths.has(source)) throw new Error(`Missing entry source: ${e.id} ${source}`);
    }
    fs.writeFileSync(snapshotPath, JSON.stringify({version:catalog.version,catalogSHA256:hash(fs.readFileSync(path.join(__dirname,'../src/knowledge/assistantKnowledge.json'))),...current},null,2)+'\n');
    console.log(JSON.stringify({recorded:true,sources:current.sources.length,screenDeclarations:current.sources.reduce((n,s)=>n+s.screens.length,0),entries:catalog.entries.length}));
  } else {
    const snapshot=JSON.parse(fs.readFileSync(snapshotPath,'utf8'));
    const changed=compare(snapshot.sources,current.sources);
    const catalogChanged=snapshot.catalogSHA256!==hash(fs.readFileSync(path.join(__dirname,'../src/knowledge/assistantKnowledge.json')));
    console.log(JSON.stringify({valid:!changed.length&&!catalogChanged,changed,affectedEntries:affectedEntries(catalog,changed,snapshot.sources),catalogChanged,reviewRequired:changed.length>0||catalogChanged}));
    if(changed.length||catalogChanged)process.exitCode=1;
  }
}
module.exports={collect,compare,affectedEntries,hash,validateBindings};
