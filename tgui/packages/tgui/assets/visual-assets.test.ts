import { describe, expect, it } from 'bun:test';
import { createHash } from 'node:crypto';
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
const previewCalloutSchema = JSON.parse(
  readFileSync(
    resolve(
      repositoryRoot,
      'tgui/packages/tgui/interfaces/PreferencesMenu/CharacterPreferences/augmentation-preview-callouts.json',
    ),
    'utf8',
  ),
) as {
  modes: Record<string, string>;
  profiles: Record<string, Array<{ region: string }>>;
};
const expectedPreviewStates = Object.entries(
  previewCalloutSchema.modes,
).flatMap(([mode, profile]) => [
  mode,
  ...previewCalloutSchema.profiles[profile].map(
    ({ region }) => `${mode}--${region}`,
  ),
]);
const previewDirectionCount = 4;
const previewFrameCount =
  expectedPreviewStates.length * previewDirectionCount;
const previewSheetCells = Math.ceil(Math.sqrt(previewFrameCount));
const loaderStylePath = resolve(
  import.meta.dir,
  '../styles/visual-system/_loader.scss',
);
const previewAssetSha256 = {
  32: '26c5afda2fd80bc215fa8c6ec0a5a47cdc41542dd44d184905b14cb209d2d2ea',
  64: 'f50f76ef095a1159a97bf907b36f1592b62863c576e2db8470b4ebf017eb73b1',
  96: 'ae4232eb396aab3717f0e92de867b45508dce42fb59d3c910036d03d569bce80',
} as const;

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
      const left =
        column >= bytesPerPixel ? decoded[target - bytesPerPixel] : 0;
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

  it('ships sanitized, bounded first-party Cyberpunk chassis artwork', () => {
    for (const filename of [
      'meridian-cyberpunk-window-frame.svg',
      'meridian-cyberpunk-panel-frame.svg',
      'meridian-cyberpunk-control-frame.svg',
    ]) {
      const artwork = readFileSync(resolve(assetRoot, filename), 'utf8');

      expect(Buffer.byteLength(artwork)).toBeLessThanOrEqual(25 * 1024);
      expect(artwork).toContain('<svg');
      expect(artwork).toContain('viewBox=');
      expect(artwork).not.toMatch(
        /<(?:script|filter|image|foreignObject|font)\b/i,
      );
      expect(artwork).not.toMatch(/(?:href|src)\s*=\s*["'](?:https?:|data:)/i);
    }
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

    for (const size of [32, 64, 96] as const) {
      const dmi = readFileSync(
        resolve(previewAssetRoot, `preview_decoration_${size}x${size}.dmi`),
      );
      combinedBytes += dmi.byteLength;

      expect(dmi.subarray(0, 8).toString('hex')).toBe('89504e470d0a1a0a');
      expect(dmi.readUInt32BE(16)).toBe(size * previewSheetCells);
      expect(dmi.readUInt32BE(20)).toBe(size * previewSheetCells);
      expect(dmi[24]).toBe(8);
      expect(dmi[25]).toBe(6);
      expect(dmi.byteLength).toBeLessThan(25 * 1024);
      // The cross-surface leader geometry has almost no room for error. Treat
      // the visually reviewed atlases as goldens so an endpoint cannot drift
      // away from its matching browser-side callout undetected.
      expect(createHash('sha256').update(dmi).digest('hex')).toBe(
        previewAssetSha256[size],
      );

      const description = readDmiDescription(dmi);
      expect(description).toContain(`\twidth = ${size}`);
      expect(description).toContain(`\theight = ${size}`);
      expect(
        [...description.matchAll(/^state = "([^"]+)"$/gm)].map(
          (match) => match[1],
        ),
      ).toEqual(expectedPreviewStates);
      expect(description.match(/^\tdirs = 4$/gm)).toHaveLength(
        expectedPreviewStates.length,
      );
      expect(description.match(/^\tframes = 1$/gm)).toHaveLength(
        expectedPreviewStates.length,
      );

      const sheetWidth = size * previewSheetCells;
      const sheetHeight = size * previewSheetCells;
      const alpha = decodeRgbaAlpha(dmi, sheetWidth, sheetHeight);
      const readCellAlpha = (cellIndex: number) => {
        const cellX = cellIndex % previewSheetCells;
        const cellY = Math.floor(cellIndex / previewSheetCells);
        const stateAlpha: number[] = [];
        for (let y = 0; y < size; y++) {
          const start = (cellY * size + y) * sheetWidth + cellX * size;
          stateAlpha.push(...alpha.subarray(start, start + size));
        }
        return stateAlpha;
      };

      for (let cell = 0; cell < previewFrameCount; cell++) {
        const stateAlpha = readCellAlpha(cell);
        expect(stateAlpha.some((value) => value === 0)).toBe(true);
        expect(stateAlpha.some((value) => value > 0)).toBe(true);
      }

      for (
        let cell = previewFrameCount;
        cell < previewSheetCells ** 2;
        cell++
      ) {
        expect(readCellAlpha(cell).every((value) => value === 0)).toBe(true);
      }

      const firstBaseFrame = readCellAlpha(0);
      for (let direction = 1; direction < previewDirectionCount; direction++) {
        expect(readCellAlpha(direction)).toEqual(firstBaseFrame);
      }

      const asymmetricState = expectedPreviewStates.indexOf(
        'augmentation_markings--l_arm',
      );
      const asymmetricFrame = asymmetricState * previewDirectionCount;
      expect(readCellAlpha(asymmetricFrame)).not.toEqual(
        readCellAlpha(asymmetricFrame + 1),
      );
      expect(readCellAlpha(asymmetricFrame + 2)).not.toEqual(
        readCellAlpha(asymmetricFrame + 3),
      );
    }

    expect(combinedBytes).toBeLessThan(25 * 1024);
  });
});
