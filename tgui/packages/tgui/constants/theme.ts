/**
 * MeridianOS theme metadata and runtime theme resolution.
 *
 * The palette metadata is intentionally kept in TypeScript as well as Sass so
 * contract and contrast tests can validate every debug skin without parsing
 * generated CSS. Runtime component styles consume semantic CSS variables only.
 */

export type MeridianThemePalette = {
  canvas: string;
  panel: string;
  raised: string;
  recessed: string;
  boundary: string;
  text: string;
  mutedText: string;
  accent: string;
  secondaryAccent: string;
  focus: string;
};

export const MERIDIAN_THEMES = [
  {
    id: 'meridian',
    name: 'Standard',
    construction: 'Restrained chamfers and a double-rule shell',
    production: true,
    palette: {
      canvas: '#080D10',
      panel: '#0D171D',
      raised: '#18303A',
      recessed: '#091217',
      boundary: '#4B6B78',
      text: '#E6EEF1',
      mutedText: '#9FB2BC',
      accent: '#58D1C9',
      secondaryAccent: '#7AE2DB',
      focus: '#FFD84D',
    },
  },
  {
    id: 'meridian_vector',
    name: 'Vector',
    construction: 'Paired notches, calibration ticks, and measurement rails',
    production: false,
    palette: {
      canvas: '#070D16',
      panel: '#0B1626',
      raised: '#162D49',
      recessed: '#08111D',
      boundary: '#426B96',
      text: '#E7F1FF',
      mutedText: '#9CB3CF',
      accent: '#54A9FF',
      secondaryAccent: '#7FC0FF',
      focus: '#B8F5FF',
    },
  },
  {
    id: 'meridian_foundry',
    name: 'Foundry',
    construction: 'Structural edges, recessed controls, and fastener marks',
    production: false,
    palette: {
      canvas: '#100C08',
      panel: '#1B140C',
      raised: '#342615',
      recessed: '#110D08',
      boundary: '#8A6930',
      text: '#FFF0D3',
      mutedText: '#C6AC80',
      accent: '#F2AD3D',
      secondaryAccent: '#FFC86B',
      focus: '#FFD98A',
    },
  },
  {
    id: 'meridian_diagnostic',
    name: 'Diagnostic',
    construction: 'Square brackets, alignment ticks, and acquisition nodes',
    production: false,
    palette: {
      canvas: '#050D09',
      panel: '#091611',
      raised: '#123020',
      recessed: '#06100B',
      boundary: '#3F7354',
      text: '#E2F4E8',
      mutedText: '#98BAA3',
      accent: '#4AD879',
      secondaryAccent: '#79E79A',
      focus: '#B1FFD8',
    },
  },
  {
    id: 'meridian_highline',
    name: 'Highline',
    construction: 'Square two-pixel boundaries and inverse selections',
    production: false,
    palette: {
      canvas: '#000000',
      panel: '#0B0D0F',
      raised: '#22282D',
      recessed: '#000000',
      boundary: '#F5F7F8',
      text: '#FFFFFF',
      mutedText: '#D1DAE0',
      accent: '#FFD84D',
      secondaryAccent: '#FFE77F',
      focus: '#FFD84D',
    },
  },
  {
    id: 'meridian_synapse',
    name: 'Synapse',
    construction: 'Asymmetric cuts, violet edges, and teal status pins',
    production: false,
    palette: {
      canvas: '#0C0710',
      panel: '#160D1A',
      raised: '#301A38',
      recessed: '#100912',
      boundary: '#885094',
      text: '#F4EAF6',
      mutedText: '#C0A7C5',
      accent: '#C477E8',
      secondaryAccent: '#38D6CF',
      focus: '#C9BCFF',
    },
  },
  {
    id: 'meridian_cyberpunk',
    name: 'Cyberpunk',
    construction: 'Broken red rails, opposing cuts, and cyan inner pins',
    production: false,
    palette: {
      canvas: '#090304',
      panel: '#0F0505',
      raised: '#1A090C',
      recessed: '#050203',
      boundary: '#C0152A',
      text: '#F7EDF0',
      mutedText: '#C9A9B0',
      accent: '#FF5267',
      secondaryAccent: '#00E5D4',
      focus: '#74FFF5',
    },
  },
  {
    id: 'meridian_augmentation',
    name: 'Augmentation',
    construction: 'Clinical trapezoids, module sockets, and a symmetric axis',
    production: false,
    palette: {
      canvas: '#070203',
      panel: '#0F0505',
      raised: '#19080B',
      recessed: '#050102',
      boundary: '#C0152A',
      text: '#EAF7F6',
      mutedText: '#A9C7C4',
      accent: '#00E5D4',
      secondaryAccent: '#F04459',
      focus: '#70FFF5',
    },
  },
  {
    id: 'meridian_afterlight',
    name: 'Afterlight',
    construction:
      'Retro-noir bezel slabs, service plates, and substantial keys',
    production: false,
    palette: {
      canvas: '#07090C',
      panel: '#11161C',
      raised: '#1B232B',
      recessed: '#040608',
      boundary: '#64727C',
      text: '#F4EBDD',
      mutedText: '#B5AA9A',
      accent: '#F0A35A',
      secondaryAccent: '#73BFC0',
      focus: '#FFE0A6',
    },
  },
  {
    id: 'meridian_relay',
    name: 'Relay',
    construction: 'Unequal equipment bays, label plates, and relay lamps',
    production: false,
    palette: {
      canvas: '#101314',
      panel: '#1B2021',
      raised: '#293032',
      recessed: '#080A0B',
      boundary: '#747E7A',
      text: '#F3EEDC',
      mutedText: '#BCB7A8',
      accent: '#F4A62A',
      secondaryAccent: '#6FC5D2',
      focus: '#FFF2A3',
    },
  },
  {
    id: 'meridian_bastion',
    name: 'Bastion',
    construction: 'Monumental slab rails, portal corners, and deep recesses',
    production: false,
    palette: {
      canvas: '#100D0A',
      panel: '#1A1712',
      raised: '#262117',
      recessed: '#080705',
      boundary: '#7C6E50',
      text: '#F0E7CE',
      mutedText: '#BDB18F',
      accent: '#D5A84C',
      secondaryAccent: '#8C9F86',
      focus: '#FFE6A3',
    },
  },
] as const satisfies ReadonlyArray<{
  id: string;
  name: string;
  construction: string;
  production: boolean;
  palette: MeridianThemePalette;
}>;

export type MeridianThemeId = (typeof MERIDIAN_THEMES)[number]['id'];

export const MERIDIAN_THEME_IDS = MERIDIAN_THEMES.map(
  ({ id }) => id,
) as MeridianThemeId[];

export const MERIDIAN_STATUS_COLORS = {
  information: '#63B4FF',
  success: '#54D98C',
  warning: '#F2BD52',
  danger: '#FF6B6B',
} as const;

const MERIDIAN_THEME_ID_SET = new Set<string>(MERIDIAN_THEME_IDS);

// Themes with deliberately separate visual languages. Unknown runtime values
// are not allowed to create an unstyled `theme-*` class; they fall back to
// MeridianOS Standard while these established specialty themes remain intact.
const SPECIALTY_THEME_ID_SET = new Set([
  'Heretic',
  'abductor',
  'admin',
  'armament',
  'cardtable',
  'clockwork',
  'dark',
  'generic',
  'hackerman',
  'heretic',
  'malfunction',
  'neutral',
  'ntOS95',
  'ntos_cat',
  'ntos_darkmode',
  'ntos_lightmode',
  'ntos_spooky',
  'ntos_synth',
  'ntos_terminal',
  'operating_computer',
  'paper',
  'retro',
  'slimecore',
  'spookyconsole',
  'syndicate',
  'wizard',
]);

const LEGACY_THEME_ALIASES: Readonly<Record<string, MeridianThemeId>> = {
  nanotrasen: 'meridian',
  ntos: 'meridian',
  meridian_standard: 'meridian',
};

export function isMeridianTheme(theme: string): theme is MeridianThemeId {
  return MERIDIAN_THEME_ID_SET.has(theme);
}

/** Normalize the base token while retaining specialty modifier classes. */
export function normalizeMeridianTheme(requested?: string): string {
  const tokens = requested?.trim().split(/\s+/).filter(Boolean) ?? [];
  const base = tokens.shift() || 'meridian';
  const aliasedBase = LEGACY_THEME_ALIASES[base] ?? base;
  const normalizedBase =
    isMeridianTheme(aliasedBase) || SPECIALTY_THEME_ID_SET.has(aliasedBase)
      ? aliasedBase
      : 'meridian';
  return [normalizedBase, ...tokens].join(' ');
}

export type ResolvedTheme = {
  base: string;
  classes: string[];
  isConsole: boolean;
};

/** Resolution precedence: development override, requested theme, Standard. */
export function resolveMeridianTheme(
  requested?: string,
  debugOverride?: MeridianThemeId | null,
): ResolvedTheme {
  const normalized = normalizeMeridianTheme(debugOverride || requested);
  const [base, ...modifiers] = normalized.split(/\s+/);
  const isConsole = isMeridianTheme(base);
  return {
    base,
    classes: [
      `theme-${base}`,
      ...(isConsole ? ['theme-console'] : []),
      ...modifiers,
    ],
    isConsole,
  };
}

/** TGUI Base16 theme used by the Kitchen Sink JSON inspector. */
export const tgui16 = {
  scheme: 'meridian16',
  author: 'Meridian-Rift contributors',
  base00: '#080D10',
  base01: '#0D171D',
  base02: '#18303A',
  base03: '#4B6B78',
  base04: '#9FB2BC',
  base05: '#E6EEF1',
  base06: '#F5F8F9',
  base07: '#FFFFFF',
  base08: MERIDIAN_STATUS_COLORS.danger,
  base09: MERIDIAN_STATUS_COLORS.warning,
  base0A: '#FFD84D',
  base0B: MERIDIAN_STATUS_COLORS.success,
  base0C: '#7AE2DB',
  base0D: '#58D1C9',
  base0E: '#C477E8',
  base0F: '#F0A35A',
} as const;
