// Usage: node preview.cjs <out.png> "<js expression returning canvas>"
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
(async () => {
  const [out, expr] = process.argv.slice(2);
  const b = await chromium.launch();
  const p = await b.newPage();
  p.on('console', m => console.log('page:', m.text()));
  p.on('pageerror', e => console.log('ERR', e.message));
  await p.setContent('<html><body></body></html>');
  for (const f of ['paint.js', 'character.js']) await p.addScriptTag({ path: path.join(__dirname, 'lib', f) });
  const data = await p.evaluate(`(()=>{ const cv = (${expr}); return cv.toDataURL('image/png'); })()`);
  fs.writeFileSync(out, Buffer.from(data.split(',')[1], 'base64'));
  await b.close();
})();
