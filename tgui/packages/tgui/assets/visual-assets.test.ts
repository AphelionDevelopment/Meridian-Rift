import { describe, expect, it } from 'bun:test';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const assetRoot = resolve(import.meta.dir, '../styles/assets');
const attributionPath = resolve(import.meta.dir, 'ATTRIBUTIONS.md');

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
});
