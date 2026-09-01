// THIS IS AN APHELION UI FILE
import { describe, expect, it } from 'bun:test';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const assetRoot = resolve(import.meta.dir, '../styles/assets');
const attributionPath = resolve(import.meta.dir, 'ATTRIBUTIONS.md');
const loaderStylePath = resolve(
  import.meta.dir,
  '../styles/visual-system/_loader.scss',
);

describe('MeridianOS visual assets', () => {
  it('ships a real, bounded WOFF2 font with matching provenance', () => {
    const font = readFileSync(resolve(assetRoot, 'VCR_OSD_Mono.woff2'));
    const attribution = readFileSync(attributionPath, 'utf8');

    expect(font.subarray(0, 4).toString('ascii')).toBe('wOF2');
    expect(font.byteLength).toBeLessThanOrEqual(25 * 1024);
    expect(attribution).toContain(
      'C029138709AE80008846A1D96C037553040749A50C3DB4E89B5D1221C8907E43',
    );
  });

  it('keeps loader motion localized, bounded, and source independent', () => {
    const loaderStyles = readFileSync(loaderStylePath, 'utf8');

    expect(
      loaderStyles.match(/animation:\s*meridian-loader-turn/g) ?? [],
    ).toHaveLength(1);
    expect(loaderStyles).toContain('.DiagnosticLoader__outerCage');
    expect(loaderStyles).toContain("[data-motion='running']");
    expect(loaderStyles).toContain('@media (prefers-reduced-motion: reduce)');
    expect(loaderStyles).toContain('transform: rotate(23deg)');
    expect(loaderStyles).toContain('@media (forced-colors: active)');
    expect(loaderStyles).toContain('forced-color-adjust: none');
    expect(loaderStyles).not.toMatch(/\bfilter\s*:/);
    expect(loaderStyles).not.toMatch(/\burl\s*\(/);
  });
});
