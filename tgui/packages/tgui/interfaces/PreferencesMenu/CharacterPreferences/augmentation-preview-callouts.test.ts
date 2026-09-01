import { describe, expect, it } from 'bun:test';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

type Callout = {
  edge: number;
  region: string;
  side: string;
  target: { x: number; y: number };
};

type CalloutSchema = {
  modes: Record<string, string>;
  profiles: Record<string, Callout[]>;
};

const schema = JSON.parse(
  readFileSync(
    resolve(import.meta.dir, 'augmentation-preview-callouts.json'),
    'utf8',
  ),
) as CalloutSchema;
const repositoryRoot = resolve(import.meta.dir, '../../../../../..');
const middlewareSource = readFileSync(
  resolve(
    repositoryRoot,
    'modular_nova/master_files/code/modules/client/preferences/middleware/limbs_and_markings.dm',
  ),
  'utf8',
);
const generatorSource = readFileSync(
  resolve(
    repositoryRoot,
    'modular_nova/modules/character_preview_background/tools/generate_preview_decorations.py',
  ),
  'utf8',
);
const runtimeSource = readFileSync(
  resolve(
    repositoryRoot,
    'modular_nova/modules/character_preview_background/code/character_preview_background.dm',
  ),
  'utf8',
);

const expectedProfiles = {
  body: {
    chest: ['bottom', 50, 50, 44],
    head: ['top', 50, 50, 21],
    l_arm: ['left', 30, 36, 40],
    l_hand: ['left', 52, 29, 54],
    l_leg: ['left', 78, 42, 76],
    r_arm: ['right', 30, 64, 40],
    r_hand: ['right', 52, 71, 54],
    r_leg: ['right', 78, 58, 76],
  },
  implants: {
    brain: ['top', 50, 50, 18],
    ears: ['right', 15, 52, 24],
    eyes: ['left', 15, 48, 23],
    heart: ['left', 57, 46, 43],
    liver: ['right', 78, 55, 54],
    lungs: ['right', 57, 53, 43],
    mouth: ['right', 36, 51, 30],
    stomach: ['left', 78, 47, 56],
    tongue: ['left', 36, 49, 30],
  },
};

describe('augmentation preview callout schema', () => {
  it('maps every finite preview mode to one canonical geometry profile', () => {
    expect(schema.modes).toEqual({
      augmentation_body_parts: 'body',
      augmentation_implants: 'implants',
      augmentation_markings: 'body',
    });
    expect(Object.keys(schema.profiles).sort()).toEqual(['body', 'implants']);
  });

  it('keeps reviewed edge and anatomical target coordinates stable', () => {
    for (const [profileName, expectedCallouts] of Object.entries(
      expectedProfiles,
    )) {
      const callouts = schema.profiles[profileName];
      const byRegion = Object.fromEntries(
        callouts.map(({ edge, region, side, target }) => [
          region,
          [side, edge, target.x, target.y],
        ]),
      );
      expect(byRegion).toEqual(expectedCallouts);
    }
  });

  it('uses unique stable IDs and bounded side, edge, and target values', () => {
    const validSides = new Set(['top', 'right', 'bottom', 'left']);

    for (const callouts of Object.values(schema.profiles)) {
      const regions = new Set<string>();
      for (const callout of callouts) {
        expect(callout.region).toMatch(/^[a-z][a-z0-9_]*$/);
        expect(regions.has(callout.region)).toBe(false);
        regions.add(callout.region);
        expect(validSides.has(callout.side)).toBe(true);
        for (const value of [
          callout.edge,
          callout.target.x,
          callout.target.y,
        ]) {
          expect(Number.isFinite(value)).toBe(true);
          expect(value).toBeGreaterThanOrEqual(0);
          expect(value).toBeLessThanOrEqual(100);
        }
      }
    }
  });

  it('exposes matching stable regions from the DM augment catalog', () => {
    expect(middlewareSource).toMatch(
      /"preview_region"\s*=\s*limb_aug_path::body_zone/,
    );

    for (const [slot, region] of [
      ['AUGMENT_SLOT_BRAIN', 'brain'],
      ['AUGMENT_SLOT_HEART', 'heart'],
      ['AUGMENT_SLOT_LUNGS', 'lungs'],
      ['AUGMENT_SLOT_LIVER', 'liver'],
      ['AUGMENT_SLOT_STOMACH', 'stomach'],
      ['AUGMENT_SLOT_EARS', 'ears'],
      ['AUGMENT_SLOT_EYES', 'eyes'],
      ['AUGMENT_SLOT_TONGUE', 'tongue'],
      ['AUGMENT_SLOT_MOUTH_IMPLANT', 'mouth'],
    ]) {
      expect(middlewareSource).toContain(`${slot} = "${region}"`);
    }
    expect(middlewareSource).toMatch(/"preview_region"\s*=\s*preview_region/);
  });

  it('keeps native artwork schema-driven and free of embedded text', () => {
    expect(generatorSource).toContain('augmentation-preview-callouts.json');
    expect(generatorSource).toContain('profiles[modes[mode]]');
    expect(generatorSource).toContain('CANONICAL_BODY_SIZE = 32');
    expect(generatorSource).toContain('return floor(value + 0.5)');
    expect(generatorSource).toContain('_pixel(CANONICAL_BODY_SIZE, target_x)');
    expect(generatorSource).toContain('_pixel(CANONICAL_BODY_SIZE, target_y)');
    expect(generatorSource).toContain(
      'BYOND_CARDINAL_DIRECTIONS = (SOUTH, NORTH, EAST, WEST)',
    );
    expect(generatorSource).toContain('selected_state = dmi.state(');
    expect(generatorSource).toContain(
      'AUGMENTATION_LEADER = (0, 176, 165, 235)',
    );
    expect(generatorSource).toContain(
      'draw.line((*edge, *elbow), fill=AUGMENTATION_READOUT, width=1)',
    );
    expect(generatorSource).not.toMatch(/PIXEL_FONT|ImageFont|draw\.text/);
  });

  it('keeps the body-aware DM rasterizer synchronized with the schema', () => {
    const dmRegionNames: Record<string, string> = {
      BODY_ZONE_CHEST: 'chest',
      BODY_ZONE_HEAD: 'head',
      BODY_ZONE_L_ARM: 'l_arm',
      BODY_ZONE_L_LEG: 'l_leg',
      BODY_ZONE_PRECISE_L_HAND: 'l_hand',
      BODY_ZONE_PRECISE_R_HAND: 'r_hand',
      BODY_ZONE_R_ARM: 'r_arm',
      BODY_ZONE_R_LEG: 'r_leg',
    };
    const runtimeEntries = [
      ...runtimeSource.matchAll(
        /^\s*(BODY_ZONE_[A-Z_]+|"[a-z_]+")\s*=\s*list\("side"\s*=\s*"([a-z]+)",\s*"edge"\s*=\s*(\d+),\s*"target_x"\s*=\s*(\d+),\s*"target_y"\s*=\s*(\d+)\),$/gm,
      ),
    ];
    const runtimeByRegion = Object.fromEntries(
      runtimeEntries.map(([, rawRegion, side, edge, targetX, targetY]) => {
        const region = rawRegion.startsWith('"')
          ? rawRegion.slice(1, -1)
          : dmRegionNames[rawRegion];
        return [
          region,
          [side, Number(edge), Number(targetX), Number(targetY)],
        ];
      }),
    );
    const expectedByRegion = Object.fromEntries(
      Object.values(expectedProfiles).flatMap((profile) =>
        Object.entries(profile),
      ),
    );

    expect(runtimeByRegion).toEqual(expectedByRegion);
    expect(runtimeSource).toContain('body.transform');
    expect(runtimeSource).toContain('leader_icon.DrawBox(null');
    expect(runtimeSource).toContain('draw_meridian_decoration_line');
  });
});
