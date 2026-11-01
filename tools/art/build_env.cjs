// Renders the painterly environment, effects and UI art.
// node tools/art/build_env.cjs [filter]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '../../assets');
const AUTUMN = "['#2b3a2a','#b4612a','#d98a35','#8e9a3c','#f2c46b','#ffe2a0']";
const GREEN = "['#1f3324','#3f6b35','#5b8a3c','#2f5a36','#a9c45c','#e3f0a0']";
const TEAL = "['#1d2f2c','#355d4f','#4c7a5f','#2d4d45','#8fb27a','#d6ecb0']";
const JOBS = {
  'sprites/env/tree_autumn_a.png': `Env.tree({seed:3, w:640, h:1024, trunk:0.45, girth:0.16, canopyY:0.24, canopyH:0.22, leaves:${AUTUMN}, moss:true})`,
  'sprites/env/tree_autumn_b.png': `Env.tree({seed:8, w:640, h:1024, leaves:${AUTUMN}, trunk:0.5, girth:0.13, canopyY:0.26, canopyH:0.24, moss:true})`,
  'sprites/env/tree_green_a.png': `Env.tree({seed:5, w:640, h:1024, trunk:0.45, girth:0.16, canopyY:0.24, canopyH:0.22, leaves:${GREEN}, moss:true})`,
  'sprites/env/tree_green_b.png': `Env.tree({seed:12, w:640, h:1024, leaves:${GREEN}, trunk:0.52, girth:0.12, canopyY:0.28, canopyH:0.27, moss:true})`,
  'sprites/env/tree_teal.png': `Env.tree({seed:21, w:640, h:1024, leaves:${TEAL}, trunk:0.48, girth:0.15, canopyY:0.25, canopyH:0.23, moss:true})`,
  'sprites/env/tree_ancient.png': `Env.ancientTree({seed:101})`,
  'sprites/env/far_tree_a.png': `Env.farTree({seed:2, color:'#ffffff'})`,
  'sprites/env/far_tree_b.png': `Env.farTree({seed:9, color:'#ffffff', w:256, h:512})`,
  'sprites/env/bush_green.png': `Env.bush({seed:4, leaves:${GREEN}})`,
  'sprites/env/bush_autumn.png': `Env.bush({seed:6, leaves:${AUTUMN}, berries:'#b8323a'})`,
  'sprites/env/fern.png': `Env.fern({seed:7, c1:'#4f7d34', c2:'#6b9a3e'})`,
  'sprites/env/fern_autumn.png': `Env.fern({seed:17, c1:'#a36a2b', c2:'#c98a3a'})`,
  'sprites/env/grass_a.png': `Env.grassTuft({seed:1, c1:'#3f6a2c', c2:'#8fb24a'})`,
  'sprites/env/grass_b.png': `Env.grassTuft({seed:2, c1:'#4c6f2a', c2:'#a7b856', flowers:'#f4f1e6'})`,
  'sprites/env/grass_c.png': `Env.grassTuft({seed:3, c1:'#5b6b2a', c2:'#c09a4a', flowers:'#e8c75a'})`,
  'sprites/env/mushrooms_orange.png': `Env.mushrooms({seed:11, cap:'#d9792e'})`,
  'sprites/env/mushrooms_glow.png': `Env.mushrooms({seed:12, cap:'#5ec8d8', glow:'#7ff0ff'})`,
  'sprites/env/boulder_a.png': `Env.boulder({seed:13})`,
  'sprites/env/boulder_b.png': `Env.boulder({seed:14, w:256, h:256, moss:1.6})`,
  'sprites/env/runestone_moon.png': `Env.runestone({seed:17, rune:0})`,
  'sprites/env/runestone_flame.png': `Env.runestone({seed:18, rune:1})`,
  'sprites/env/runestone_root.png': `Env.runestone({seed:19, rune:2})`,
  'sprites/env/runestone_star.png': `Env.runestone({seed:20, rune:3})`,
  'sprites/env/runestone_spiral.png': `Env.runestone({seed:21, rune:4})`,
  'sprites/fx/rune_moon.png': `Env.runeGlow({rune:0, color:'#7fd6ff'})`,
  'sprites/fx/rune_flame.png': `Env.runeGlow({rune:1, color:'#ffb347'})`,
  'sprites/fx/rune_root.png': `Env.runeGlow({rune:2, color:'#9cff8a'})`,
  'sprites/fx/rune_star.png': `Env.runeGlow({rune:3, color:'#fff1a8'})`,
  'sprites/fx/rune_spiral.png': `Env.runeGlow({rune:4, color:'#d6a8ff'})`,
  'sprites/env/pillar.png': `Env.pillar({seed:19})`,
  'sprites/env/pillar_broken.png': `Env.pillar({seed:20, broken:true})`,
  'sprites/env/arch.png': `Env.arch({seed:23})`,
  'sprites/env/wall_ruin.png': `Env.wallRuin({seed:29})`,
  'sprites/env/lantern.png': `Env.lantern({seed:31})`,
  'sprites/env/pedestal_moon.png': `Env.pedestal({seed:37, rune:0})`,
  'sprites/env/pedestal_flame.png': `Env.pedestal({seed:38, rune:1})`,
  'sprites/env/log.png': `Env.log({seed:41, mush:true})`,
  'sprites/env/roots_barrier.png': `Env.rootsBarrier({seed:71})`,
  'textures/ground_grass.png': `Env.groundTile({seed:51, c0:'#26381f', c1:'#3d5a2a', c2:'#5f7a35', blades:2600, bladeCols:['#6f9a3c','#4a6e2c','#9db457'], leafCount:120, leafCols:['#c0702c','#d99a3c','#8d4a22']})`,
  'textures/ground_moss.png': `Env.groundTile({seed:53, c0:'#1e2e1c', c1:'#30482a', c2:'#4d6a34', blades:1200, bladeCols:['#5b8a3c','#3e5f2c'], pebbles:60, pebbleCol:'#6c6f63', leafCount:200, leafCols:['#b4612a','#d98a35','#7a3d1c']})`,
  'textures/ground_dirt.png': `Env.groundTile({seed:55, c0:'#3a2e22', c1:'#56452f', c2:'#6e5a3c', pebbles:260, pebbleCol:'#8a8574', leafCount:160, leafCols:['#b4612a','#d98a35','#6d4a22']})`,
  'textures/path_stones.png': `Env.pathTile({seed:61})`,
  'sprites/fx/soft_dot.png': `Env.softDot({size:128})`,
  'sprites/fx/soft_core.png': `Env.softDot({size:128, core:0.45})`,
  'sprites/fx/sparkle.png': `Env.sparkle({size:128})`,
  'sprites/fx/leaf_orange.png': `Env.leafParticle({color:'#d9822e'})`,
  'sprites/fx/leaf_gold.png': `Env.leafParticle({color:'#e8b74a'})`,
  'sprites/fx/light_shaft.png': `Env.lightShaft()`,
  'sprites/fx/blob_shadow.png': `Env.blobShadow()`,
  'sprites/fx/magic_circle.png': `Env.magicCircle({size:512})`,
  'sprites/enemy/shade.png': `Env.shadeWisp()`,
  'ui/emblem.png': `Env.emblem()`,
  'sprites/prologue/goddess.png': `Extra.figure({kind:'goddess'})`,
  'sprites/prologue/goddess_reach.png': `Extra.figure({kind:'goddess', reach:1})`,
  'sprites/prologue/god.png': `Extra.figure({kind:'god'})`,
  'sprites/prologue/god_reach.png': `Extra.figure({kind:'god', reach:1})`,
  'ui/icon_magic.png': `Extra.icon('magic')`,
  'ui/icon_jump.png': `Extra.icon('jump')`,
  'ui/icon_interact.png': `Extra.icon('interact')`,
  'ui/icon_pause.png': `Extra.icon('pause')`,
  'ui/icon_moon.png': `Extra.icon('moon')`,
  'ui/icon_flame.png': `Extra.icon('flame')`,
  'ui/icon_spark.png': `Extra.icon('spark')`,
  'ui/icon_read.png': `Extra.icon('read')`,
  'ui/ring.png': `Extra.ring({})`,
  'ui/ring_ticks.png': `Extra.ring({ticks:true})`,
};
(async () => {
  const filter = process.argv[2];
  const b = await chromium.launch();
  const p = await b.newPage();
  p.on('pageerror', e => { console.error('ERR', e.message); process.exit(1); });
  await p.setContent('<html><body></body></html>');
  for (const f of ['paint.js', 'env.js', 'extra.js']) await p.addScriptTag({ path: path.join(__dirname, 'lib', f) });
  for (const [out, expr] of Object.entries(JOBS)) {
    if (filter && !out.includes(filter)) continue;
    const data = await p.evaluate(`(${expr}).toDataURL('image/png')`);
    const file = path.join(ROOT, out);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, Buffer.from(data.split(',')[1], 'base64'));
    console.log(out);
  }
  await b.close();
})();
