import { describe, expect, it } from 'bun:test';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const read = (path: string) => readFileSync(resolve(import.meta.dir, path), 'utf8');

describe('Preferences character preview integration', () => {
  it('decorates only the visible Preferences previews', () => {
    const visiblePages = [
      '../PreferencesMenu/CharacterPreferences/MainPage.tsx',
      '../PreferencesMenu/CharacterPreferences/SpeciesPage.tsx',
      '../PreferencesMenu/CharacterPreferences/loadout/index.tsx',
    ];

    for (const page of visiblePages) {
      expect(read(page)).toContain('decoration="standard"');
    }

    const limbs = read(
      '../PreferencesMenu/CharacterPreferences/LimbsPage.tsx',
    );
    expect(limbs).toContain('decoration={props.decoration}');
    expect(limbs).toContain("'standard' | 'augmentation'");

    const coordinator = read(
      '../PreferencesMenu/CharacterPreferences/index.tsx',
    );
    expect(coordinator).toContain('previewDecoration="augmentation"');
    expect(coordinator).toContain(
      'usePreferencesCharacterPreviewDecoration(act, nativePreviewDecoration)',
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
    expect(previewStyles).not.toMatch(/\banimation\s*:/);
    expect(previewStyles).not.toMatch(/\bfilter\s*:/);
    expect(previewStyles).not.toMatch(/overflow:\s*hidden/);
  });
});
