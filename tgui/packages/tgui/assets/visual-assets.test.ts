import { describe, expect, it } from 'bun:test';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { inflateSync } from 'node:zlib';

const assetRoot = resolve(import.meta.dir, '../styles/assets');
const attributionPath = resolve(import.meta.dir, 'ATTRIBUTIONS.md');
const repositoryRoot = resolve(import.meta.dir, '../../../..');
const previewAssetRoot = resolve(
  repositoryRoot,
  'modular_nova/modules/character_preview_background/icons',
);
const loaderStylePath = resolve(
  import.meta.dir,
  '../styles/visual-system/_loader.scss',
);

function pngChunks(png: Buffer) {
  const chunks: Array<{ data: Buffer; type: string }> = [];
  let offset = 8;
  while (offset < png.byteLength) {
    const length = png.readUInt32BE(offset);
    const type = png.subarray(offset + 4, offset + 8).toString('ascii');
    chunks.push({
      data: png.subarray(offset + 8, offset + 8 + length),
      type,
    });
    offset += length + 12;
  }
  return chunks;
}

function readDmiDescription(png: Buffer) {
  for (const chunk of pngChunks(png)) {
    if (chunk.type !== 'zTXt') {
      continue;
    }
    const separator = chunk.data.indexOf(0);
    const keyword = chunk.data.subarray(0, separator).toString('latin1');
    if (keyword === 'Description' && chunk.data[separator + 1] === 0) {
      return inflateSync(chunk.data.subarray(separator + 2)).toString('utf8');
    }
  }
  throw new Error('DMI Description metadata is missing');
}

function paeth(left: number, up: number, upperLeft: number) {
  const prediction = left + up - upperLeft;
  const leftDistance = Math.abs(prediction - left);
  const upDistance = Math.abs(prediction - up);
  const upperLeftDistance = Math.abs(prediction - upperLeft);
  if (leftDistance <= upDistance && leftDistance <= upperLeftDistance) {
    return left;
  }
  return upDistance <= upperLeftDistance ? up : upperLeft;
}

function decodeRgbaAlpha(png: Buffer, width: number, height: number) {
  const compressed = pngChunks(png)
    .filter((chunk) => chunk.type === 'IDAT')
    .map((chunk) => chunk.data);
  const payload = inflateSync(Buffer.concat(compressed));
  const bytesPerPixel = 4;
  const stride = width * bytesPerPixel;
  const decoded = Buffer.alloc(stride * height);
  let sourceOffset = 0;

  for (let row = 0; row < height; row++) {
    const filter = payload[sourceOffset++];
    for (let column = 0; column < stride; column++) {
      const raw = payload[sourceOffset++];
      const target = row * stride + column;
      const left = column >= bytesPerPixel ? decoded[target - bytesPerPixel] : 0;
      const up = row > 0 ? decoded[target - stride] : 0;
      const upperLeft =
        row > 0 && column >= bytesPerPixel
          ? decoded[target - stride - bytesPerPixel]
          : 0;
      const predictor =
        filter === 0
          ? 0
          : filter === 1
            ? left
            : filter === 2
              ? up
              : filter === 3
                ? Math.floor((left + up) / 2)
                : filter === 4
                  ? paeth(left, up, upperLeft)
                  : Number.NaN;
      if (!Number.isFinite(predictor)) {
        throw new Error(`Unsupported PNG filter ${filter}`);
      }
      decoded[target] = (raw + predictor) & 0xff;
    }
  }

  return decoded.filter((_, index) => index % bytesPerPixel === 3);
}

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

  it('ships exact-size transparent preview DMI states with bounded weight', () => {
    let combinedBytes = 0;

    for (const size of [32, 64, 96]) {
      const dmi = readFileSync(
        resolve(previewAssetRoot, `preview_decoration_${size}x${size}.dmi`),
      );
      combinedBytes += dmi.byteLength;

      expect(dmi.subarray(0, 8).toString('hex')).toBe(
        '89504e470d0a1a0a',
      );
      expect(dmi.readUInt32BE(16)).toBe(size * 2);
      expect(dmi.readUInt32BE(20)).toBe(size);
      expect(dmi[24]).toBe(8);
      expect(dmi[25]).toBe(6);
      expect(dmi.byteLength).toBeLessThan(25 * 1024);

      const description = readDmiDescription(dmi);
      expect(description).toContain(`\twidth = ${size}`);
      expect(description).toContain(`\theight = ${size}`);
      expect(description.match(/^state = /gm)).toHaveLength(2);
      expect(description).toContain('state = "standard"');
      expect(description).toContain('state = "augmentation"');

      const alpha = decodeRgbaAlpha(dmi, size * 2, size);
      for (let state = 0; state < 2; state++) {
        const stateAlpha: number[] = [];
        for (let y = 0; y < size; y++) {
          const start = y * size * 2 + state * size;
          stateAlpha.push(...alpha.subarray(start, start + size));
        }
        expect(stateAlpha.some((value) => value === 0)).toBe(true);
        expect(stateAlpha.some((value) => value > 0)).toBe(true);
      }
    }

    expect(combinedBytes).toBeLessThan(5 * 1024);
  });
});
