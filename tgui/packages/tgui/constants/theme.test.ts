import { describe, expect, it } from 'bun:test';
import {
  MERIDIAN_THEMES,
  MERIDIAN_THEME_IDS,
  normalizeMeridianTheme,
  resolveMeridianTheme,
} from './theme';

function channelToLinear(channel: number): number {
  const normalized = channel / 255;
  return normalized <= 0.04045
    ? normalized / 12.92
    : ((normalized + 0.055) / 1.055) ** 2.4;
}

function luminance(hex: string): number {
  const channels = hex
    .match(/[0-9a-f]{2}/gi)
    ?.map((value) => channelToLinear(Number.parseInt(value, 16)));
  if (channels?.length !== 3) {
    throw new Error(`Invalid hex color: ${hex}`);
  }
  return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
}

function contrast(first: string, second: string): number {
  const lighter = Math.max(luminance(first), luminance(second));
  const darker = Math.min(luminance(first), luminance(second));
  return (lighter + 0.05) / (darker + 0.05);
}

describe('MeridianOS theme catalog', () => {
  it('contains eleven unique skins and only Standard is production-facing', () => {
    expect(new Set(MERIDIAN_THEME_IDS).size).toBe(11);
    expect(MERIDIAN_THEMES.filter(({ production }) => production)).toEqual([
      expect.objectContaining({ id: 'meridian', name: 'Standard' }),
    ]);
  });

  it('meets text, status-boundary, selection, and focus contrast contracts', () => {
    for (const { id, palette } of MERIDIAN_THEMES) {
      for (const surface of [
        palette.canvas,
        palette.panel,
        palette.raised,
        palette.recessed,
      ]) {
        expect(
          contrast(palette.text, surface),
          `${id}: primary text`,
        ).toBeGreaterThanOrEqual(4.5);
        expect(
          contrast(palette.mutedText, surface),
          `${id}: muted text`,
        ).toBeGreaterThanOrEqual(4.5);
      }

      expect(
        contrast(palette.boundary, palette.panel),
        `${id}: boundary`,
      ).toBeGreaterThanOrEqual(3);
      expect(
        contrast(palette.accent, palette.panel),
        `${id}: accent`,
      ).toBeGreaterThanOrEqual(3);
      expect(
        contrast(palette.secondaryAccent, palette.panel),
        `${id}: selected`,
      ).toBeGreaterThanOrEqual(3);
      expect(
        contrast(palette.canvas, palette.secondaryAccent),
        `${id}: text on selection`,
      ).toBeGreaterThanOrEqual(4.5);
      expect(
        contrast(palette.focus, palette.panel),
        `${id}: focus on panel`,
      ).toBeGreaterThanOrEqual(3);
      expect(
        contrast(palette.focus, palette.canvas),
        `${id}: focus on canvas`,
      ).toBeGreaterThanOrEqual(3);
    }
  });
});

describe('MeridianOS theme resolution', () => {
  it('normalizes base legacy values without rewriting specialty themes', () => {
    expect(normalizeMeridianTheme()).toBe('meridian');
    expect(normalizeMeridianTheme('nanotrasen')).toBe('meridian');
    expect(normalizeMeridianTheme('ntos')).toBe('meridian');
    expect(normalizeMeridianTheme('ntos_terminal')).toBe('ntos_terminal');
    expect(normalizeMeridianTheme('paper')).toBe('paper');
  });

  it('falls unknown requested themes back to Standard', () => {
    expect(normalizeMeridianTheme('unregistered-theme')).toBe('meridian');
    expect(resolveMeridianTheme('unregistered-theme')).toEqual({
      base: 'meridian',
      classes: ['theme-meridian', 'theme-console'],
      isConsole: true,
    });
  });

  it('preserves modifier classes and marks only the Meridian family as console', () => {
    expect(resolveMeridianTheme('heretic heretic-theme-ascended')).toEqual({
      base: 'heretic',
      classes: ['theme-heretic', 'heretic-theme-ascended'],
      isConsole: false,
    });
    expect(resolveMeridianTheme('ntos')).toEqual({
      base: 'meridian',
      classes: ['theme-meridian', 'theme-console'],
      isConsole: true,
    });
  });

  it('gives the development override precedence over the requested theme', () => {
    expect(resolveMeridianTheme('paper', 'meridian_vector')).toEqual({
      base: 'meridian_vector',
      classes: ['theme-meridian_vector', 'theme-console'],
      isConsole: true,
    });
  });
});
