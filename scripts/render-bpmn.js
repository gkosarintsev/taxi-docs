#!/usr/bin/env node
/**
 * render-bpmn.js
 * Renders all .bpmn files in docs/ to .svg using Playwright + bpmn-js (CDN).
 * Usage: node scripts/render-bpmn.js
 */

const { chromium } = require('playwright');
const fs   = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Find all BPMN files recursively
const bpmnFiles = execSync('find docs -type f -name "*.bpmn"')
  .toString().trim().split('\n').filter(Boolean);

async function renderBpmn(bpmnPath, browser) {
  const dir     = path.dirname(bpmnPath);
  const base    = path.basename(bpmnPath, '.bpmn');
  const outPath = path.join(dir, base + '.svg');

  const bpmnXml = fs.readFileSync(bpmnPath, 'utf-8');

  const page = await browser.newPage();

  // Inject the BPMN XML as a JSON string so it survives HTML embedding
  const xmlJson = JSON.stringify(bpmnXml);

  await page.setContent(`<!DOCTYPE html>
<html>
<head>
  <style>
    html, body { margin: 0; padding: 0; background: white; }
    #canvas { width: 1800px; height: 900px; }
  </style>
</head>
<body>
  <div id="canvas"></div>
  <script src="https://unpkg.com/bpmn-js@17/dist/bpmn-navigated-viewer.production.min.js"></script>
  <script>
    (async () => {
      const xml = ${xmlJson};
      const viewer = new BpmnJS({ container: document.getElementById('canvas') });
      try {
        await viewer.importXML(xml);
        viewer.get('canvas').zoom('fit-viewport');
        const { svg } = await viewer.saveSVG();
        document.body.setAttribute('data-result', svg);
        document.title = 'OK';
      } catch (e) {
        document.body.setAttribute('data-result', 'ERROR:' + e.message);
        document.title = 'ERR';
      }
    })();
  </script>
</body>
</html>`);

  await page.waitForFunction(
    () => document.title === 'OK' || document.title === 'ERR',
    { timeout: 60000 }
  );

  const title  = await page.title();
  const result = await page.getAttribute('body', 'data-result');
  await page.close();

  if (title !== 'OK') {
    throw new Error(result);
  }

  fs.writeFileSync(outPath, result);
  console.log(`  ✓ ${bpmnPath} → ${outPath}`);
}

async function main() {
  if (bpmnFiles.length === 0) {
    console.log('No .bpmn files found.');
    return;
  }

  console.log(`Found ${bpmnFiles.length} BPMN file(s). Launching browser...`);
  const browser = await chromium.launch({ args: ['--no-sandbox', '--disable-setuid-sandbox'] });

  let ok = 0, fail = 0;
  for (const f of bpmnFiles) {
    try {
      await renderBpmn(f, browser);
      ok++;
    } catch (e) {
      console.error(`  ✗ ${f}: ${e.message}`);
      fail++;
    }
  }

  await browser.close();
  console.log(`\nDone: ${ok} rendered, ${fail} failed.`);
  process.exit(fail > 0 ? 1 : 0);
}

main().catch(e => { console.error(e); process.exit(1); });
