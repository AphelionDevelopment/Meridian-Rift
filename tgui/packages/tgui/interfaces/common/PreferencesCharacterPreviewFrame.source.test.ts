// THIS IS AN APHELION UI FILE
import { describe, expect, it } from 'bun:test';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const read = (path: string) =>
  readFileSync(resolve(import.meta.dir, path), 'utf8');

describe('Preferences character preview integration', () => {
  it('keeps non-Augments previews plain and scopes each native state to an Augments tab', () => {
    const plainPages = [
      '../PreferencesMenu/CharacterPreferences/MainPage.tsx',
      '../PreferencesMenu/CharacterPreferences/SpeciesPage.tsx',
      '../PreferencesMenu/CharacterPreferences/loadout/index.tsx',
    ];

    for (const page of plainPages) {
      expect(read(page)).not.toContain('decoration=');
    }

    const limbs = read('../PreferencesMenu/CharacterPreferences/LimbsPage.tsx');
    const workbench = read(
      '../PreferencesMenu/CharacterPreferences/AugmentsWorkbench.tsx',
    );
    expect(workbench).toContain('decoration={decoration}');
    expect(limbs).toContain("[AugmentsTab.Markings]: 'augmentation_markings'");
    expect(limbs).toContain(
      "[AugmentsTab.BodyParts]: 'augmentation_body_parts'",
    );
    expect(limbs).toContain(
      "[AugmentsTab.InternalImplants]: 'augmentation_implants'",
    );
    expect(limbs).toContain(
      'usePreferencesCharacterPreviewDecoration(\n    act,\n    previewDecoration,\n    activeRegion || null,\n  )',
    );
    expect(limbs).toContain('<AugmentsWorkbench');

    const coordinator = read(
      '../PreferencesMenu/CharacterPreferences/index.tsx',
    );
    expect(coordinator).not.toContain('previewDecoration=');
    expect(coordinator).not.toContain(
      'resolvePreferencesCharacterPreviewDecoration',
    );

    const quirks = read(
      '../PreferencesMenu/CharacterPreferences/QuirksPage.tsx',
    );
    expect(quirks).toContain('width="1px"');
    expect(quirks).toContain('height="1px"');
    expect(quirks).not.toContain('decoration=');
  });

  it('keeps all exterior ornament pointer-transparent and non-animated', () => {
    const styles = read('../../styles/visual-system/_decoration.scss');
    const previewStyles = styles.slice(
      styles.indexOf('.PreferencesCharacterPreviewFrame'),
      styles.indexOf('\n}\n\n@media (forced-colors: active)'),
    );

    expect(previewStyles).toContain('pointer-events: none');
    expect(previewStyles).toContain('&--topLeft');
    expect(previewStyles).toContain('&--topRight');
    expect(previewStyles).toContain('&--bottomRight');
    expect(previewStyles).toContain('&--bottomLeft');
    expect(previewStyles).toContain('&--augmentation');
    expect(previewStyles).not.toContain('&__orientation');
    expect(previewStyles).not.toContain('&__rail');
    expect(previewStyles).not.toContain('&__leader');
    expect(previewStyles).not.toMatch(/\banimation\s*:/);
    expect(previewStyles).not.toMatch(/\bfilter\s*:/);
    expect(previewStyles).not.toMatch(/overflow:\s*hidden/);
  });

  it('allows preview cleanup even while character creation is disabled', () => {
    const preferencesDm = read(
      '../../../../../code/modules/client/preferences.dm',
    );
    const uiAct = preferencesDm.indexOf('/datum/preferences/ui_act');
    const decorationAction = preferencesDm.indexOf(
      'if(action == "set_preview_decoration")',
      uiAct,
    );
    const creatorGate = preferencesDm.indexOf(
      'SSlag_switch.measures[DISABLE_CREATOR]',
      uiAct,
    );

    expect(uiAct).toBeGreaterThan(-1);
    expect(decorationAction).toBeGreaterThan(uiAct);
    expect(decorationAction).toBeLessThan(creatorGate);
    expect(preferencesDm).toContain(
      'set_meridian_decoration(params["mode"], params["region"])',
    );
    expect(preferencesDm).toContain(
      '/atom/movable/screen/map_view/char_preview/setDir(newdir)',
    );
    expect(preferencesDm).toContain(
      'meridian_decoration_overlay.dir = preview_direction',
    );
  });
});
