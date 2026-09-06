// THIS IS AN APHELION UI FILE
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
    construction: '',
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
    id: 'meridian_pipboy',
    name: 'Wastelander',
    construction: '',
    production: true,
    palette: {
      canvas: '#0C100B',
      panel: '#11160F',
      raised: '#22291B',
      recessed: '#090D08',
      boundary: '#657653',
      text: '#ADB997',
      mutedText: '#919F7E',
      accent: '#90A863',
      secondaryAccent: '#A4BA78',
      focus: '#D3BE7E',
    },
  },
  {
    id: 'meridian_vector',
    name: 'Vector',
    construction: '',
    production: true,
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
    construction: '',
    production: true,
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
    construction: '',
    production: true,
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
    construction: '',
    production: true,
    palette: {
      canvas: '#10151A',
      panel: '#171E24',
      raised: '#29343D',
      recessed: '#0D1216',
      boundary: '#77868F',
      text: '#C9D0D3',
      mutedText: '#AFBAC1',
      accent: '#B9C5CA',
      secondaryAccent: '#A6C5D3',
      focus: '#9DC7DE',
    },
  },
  {
    id: 'meridian_synapse',
    name: 'Synapse',
    construction: '',
    production: true,
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
    construction: '',
    production: true,
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
    construction: '',
    production: true,
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
    construction: '',
    production: true,
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
    construction: '',
    production: true,
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
    construction: '',
    production: true,
    palette: {
      canvas: '#100D0A',
      panel: '#1A1712',
      raised: '#2B251D',
      recessed: '#080705',
      boundary: '#7C6E50',
      text: '#F0E7CE',
      mutedText: '#C9BEA3',
      accent: '#D5A84C',
      secondaryAccent: '#9AAA8C',
      focus: '#FFE6A3',
    },
  },
  {
    id: 'meridian_aphelion',
    name: 'Aphelion',
    construction: '',
    production: true,
    palette: {
      canvas: '#131110',
      panel: '#1A1714',
      raised: '#211D19',
      recessed: '#0E0C0B',
      boundary: '#8F887C',
      text: '#ECE5D8',
      mutedText: '#A89F90',
      accent: '#56D4DC',
      secondaryAccent: '#56D4DC',
      focus: '#56D4DC',
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

export const MERIDIAN_CLASSIC_THEME_ID = 'meridian_classic' as const;

const MERIDIAN_CLASSIC_THEME = {
  id: MERIDIAN_CLASSIC_THEME_ID,
  name: 'Classic NT',
  construction: '',
  production: true,
} as const;

/**
 * User-facing theme order. Classic deliberately sits after Standard while the
 * palette-bearing MeridianOS themes retain their established order.
 */
export const MERIDIAN_BASE_THEME_OPTIONS = [
  MERIDIAN_THEMES[0],
  MERIDIAN_CLASSIC_THEME,
  ...MERIDIAN_THEMES.slice(1),
] as const;

export type MeridianBaseThemeId =
  (typeof MERIDIAN_BASE_THEME_OPTIONS)[number]['id'];

export const MERIDIAN_BASE_THEME_IDS = MERIDIAN_BASE_THEME_OPTIONS.map(
  ({ id }) => id,
) as MeridianBaseThemeId[];

export const DEFAULT_MERIDIAN_BASE_THEME: MeridianBaseThemeId = 'meridian';

export const MERIDIAN_STATUS_COLORS = {
  information: '#63B4FF',
  success: '#54D98C',
  warning: '#F2BD52',
  danger: '#FF6B6B',
} as const;

const MERIDIAN_THEME_ID_SET = new Set<string>(MERIDIAN_THEME_IDS);
const MERIDIAN_BASE_THEME_ID_SET = new Set<string>(MERIDIAN_BASE_THEME_IDS);

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

const LEGACY_THEME_ALIASES: Readonly<Record<string, MeridianBaseThemeId>> = {
  nanotrasen: 'meridian',
  ntos: 'meridian',
  meridian_standard: 'meridian',
};

export function isMeridianTheme(theme: string): theme is MeridianThemeId {
  return MERIDIAN_THEME_ID_SET.has(theme);
}

export function isMeridianBaseTheme(
  theme: string,
): theme is MeridianBaseThemeId {
  return MERIDIAN_BASE_THEME_ID_SET.has(theme);
}

/** Normalize untrusted player-preference values to a selectable theme ID. */
export function normalizeMeridianBaseTheme(
  requested?: string | null,
): MeridianBaseThemeId {
  const aliased = requested
    ? (LEGACY_THEME_ALIASES[requested] ?? requested)
    : '';
  return isMeridianBaseTheme(aliased) ? aliased : DEFAULT_MERIDIAN_BASE_THEME;
}

/** Normalize the base token while retaining specialty modifier classes. */
export function normalizeMeridianTheme(requested?: string): string {
  const tokens = requested?.trim().split(/\s+/).filter(Boolean) ?? [];
  const base = tokens.shift() || DEFAULT_MERIDIAN_BASE_THEME;
  const aliasedBase = LEGACY_THEME_ALIASES[base] ?? base;
  const normalizedBase =
    isMeridianBaseTheme(aliasedBase) || SPECIALTY_THEME_ID_SET.has(aliasedBase)
      ? aliasedBase
      : DEFAULT_MERIDIAN_BASE_THEME;
  return [normalizedBase, ...tokens].join(' ');
}

export type ResolvedTheme = {
  base: string;
  classes: string[];
  isConsole: boolean;
};

/**
 * Resolution precedence: development override, specialty device theme,
 * player preference, requested theme, Standard.
 */
export type ResolveMeridianThemeOptions = {
  requested?: string;
  preferred?: MeridianBaseThemeId | null;
  debugOverride?: MeridianBaseThemeId | null;
};

export function resolveMeridianTheme(
  options: ResolveMeridianThemeOptions = {},
): ResolvedTheme {
  const { requested, preferred, debugOverride } = options;
  const normalizedRequested = normalizeMeridianTheme(requested);
  const [requestedBase, ...requestedModifiers] =
    normalizedRequested.split(/\s+/);
  const requestedIsSpecialty = SPECIALTY_THEME_ID_SET.has(requestedBase);
  const selectedTheme = debugOverride
    ? normalizeMeridianBaseTheme(debugOverride)
    : requestedIsSpecialty
      ? requestedBase
      : normalizeMeridianBaseTheme(preferred || requestedBase);
  const base =
    selectedTheme === MERIDIAN_CLASSIC_THEME_ID ? 'nanotrasen' : selectedTheme;
  const modifiers = debugOverride ? [] : requestedModifiers;
  const isConsole = isMeridianTheme(base);
  return {
    base,
    classes: [
      `theme-${base}`,
      // Classic NT borrows nanotrasen's paint wholesale, which leaves it
      // indistinguishable in CSS from a genuine legacy window. This marker is
      // the only thing separating the two, so Classic can be given geometry
      // fixes that must not reach the real legacy themes. It carries no paint.
      ...(selectedTheme === MERIDIAN_CLASSIC_THEME_ID
        ? [`theme-${MERIDIAN_CLASSIC_THEME_ID}`]
        : []),
      ...(isConsole ? ['theme-console'] : []),
      ...modifiers,
    ],
    isConsole,
  };
}

/** MeridianOS Base16 palette, used by the Kitchen Sink JSON inspector. */
export const MERIDIAN_BASE16 = {
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
