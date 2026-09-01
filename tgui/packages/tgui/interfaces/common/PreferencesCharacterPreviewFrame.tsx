import { type CSSProperties, type ReactNode, useEffect } from 'react';
import { classes } from 'tgui-core/react';
import type { sendAct } from '../../events/act';

export const PREFERENCES_CHARACTER_PREVIEW_DECORATION_MODES = [
  'none',
  'standard',
  'augmentation',
] as const;

export type PreferencesCharacterPreviewDecorationMode =
  (typeof PREFERENCES_CHARACTER_PREVIEW_DECORATION_MODES)[number];

const decorationModes = new Set<string>(
  PREFERENCES_CHARACTER_PREVIEW_DECORATION_MODES,
);

export const isPreferencesCharacterPreviewDecorationMode = (
  value: unknown,
): value is PreferencesCharacterPreviewDecorationMode =>
  typeof value === 'string' && decorationModes.has(value);

export const normalizePreferencesCharacterPreviewDecorationMode = (
  value: unknown,
): PreferencesCharacterPreviewDecorationMode =>
  isPreferencesCharacterPreviewDecorationMode(value) ? value : 'none';

export const resolvePreferencesCharacterPreviewDecoration = (options: {
  hasVisiblePreview: boolean;
  isAugmentsPage: boolean;
  resolvedTheme: string;
}): PreferencesCharacterPreviewDecorationMode => {
  if (!options.hasVisiblePreview) {
    return 'none';
  }
  if (
    options.isAugmentsPage &&
    options.resolvedTheme === 'meridian_augmentation'
  ) {
    return 'augmentation';
  }
  return 'standard';
};

/**
 * Synchronizes the finite, non-persistent decoration mode with DM. Mode changes
 * do not run cleanup; only destroying the owning Preferences window sends none.
 */
export function usePreferencesCharacterPreviewDecoration(
  act: typeof sendAct,
  mode: PreferencesCharacterPreviewDecorationMode,
) {
  useEffect(() => {
    act('set_preview_decoration', { mode });
  }, [act, mode]);

  useEffect(
    () => () => {
      act('set_preview_decoration', { mode: 'none' });
    },
    [act],
  );
}

export type PreferencesCharacterPreviewFrameProps = {
  children: ReactNode;
  className?: string;
  decoration: PreferencesCharacterPreviewDecorationMode;
  height: string;
  status?: ReactNode;
  title?: ReactNode;
  width: string;
};

/**
 * HTML chassis around a native BYOND map control.
 *
 * The supplied width and height deliberately match the child ByondUi control:
 * decorative elements are absolutely positioned and never participate in map
 * geometry or receive pointer input. Interior decoration belongs to BYOND.
 */
export function PreferencesCharacterPreviewFrame(
  props: PreferencesCharacterPreviewFrameProps,
) {
  const {
    children,
    className,
    decoration,
    height,
    status = decoration === 'augmentation' ? 'AUG LINKED' : 'LINK ACTIVE',
    title = decoration === 'augmentation' ? 'AUGMENTATION' : 'CHARACTER',
    width,
  } = props;
  const style = { height, width } satisfies CSSProperties;

  return (
    <div
      className={classes([
        'PreferencesCharacterPreviewFrame',
        `PreferencesCharacterPreviewFrame--${decoration}`,
        className,
      ])}
      data-decoration-mode={decoration}
      style={style}
    >
      {children}
      {decoration !== 'none' && (
        <div
          aria-hidden="true"
          className="PreferencesCharacterPreviewFrame__chrome"
        >
          <span className="PreferencesCharacterPreviewFrame__corner PreferencesCharacterPreviewFrame__corner--topLeft" />
          <span className="PreferencesCharacterPreviewFrame__corner PreferencesCharacterPreviewFrame__corner--topRight" />
          <span className="PreferencesCharacterPreviewFrame__corner PreferencesCharacterPreviewFrame__corner--bottomRight" />
          <span className="PreferencesCharacterPreviewFrame__corner PreferencesCharacterPreviewFrame__corner--bottomLeft" />
          <span className="PreferencesCharacterPreviewFrame__datum PreferencesCharacterPreviewFrame__datum--left" />
          <span className="PreferencesCharacterPreviewFrame__datum PreferencesCharacterPreviewFrame__datum--right" />
          <span className="PreferencesCharacterPreviewFrame__leader PreferencesCharacterPreviewFrame__leader--left" />
          <span className="PreferencesCharacterPreviewFrame__leader PreferencesCharacterPreviewFrame__leader--right" />
          <span className="PreferencesCharacterPreviewFrame__orientation PreferencesCharacterPreviewFrame__orientation--north">
            N
          </span>
          <span className="PreferencesCharacterPreviewFrame__orientation PreferencesCharacterPreviewFrame__orientation--south">
            S
          </span>
          <span className="PreferencesCharacterPreviewFrame__rail">
            <span className="PreferencesCharacterPreviewFrame__title">
              {title}
            </span>
            <span className="PreferencesCharacterPreviewFrame__status">
              {status}
            </span>
          </span>
        </div>
      )}
    </div>
  );
}
