import { type CSSProperties, type ReactNode, useEffect } from 'react';
import { classes } from 'tgui-core/react';
import type { sendAct } from '../../events/act';

export const PREFERENCES_CHARACTER_PREVIEW_DECORATION_MODES = [
  'none',
  'augmentation_markings',
  'augmentation_body_parts',
  'augmentation_implants',
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

const augmentationFrameCopy: Record<
  Exclude<PreferencesCharacterPreviewDecorationMode, 'none'>,
  { status: string; title: string }
> = {
  augmentation_markings: { status: 'REGION MAP', title: 'MARKINGS' },
  augmentation_body_parts: { status: 'LIMB MAP', title: 'BODY PARTS' },
  augmentation_implants: { status: 'INTERNAL MAP', title: 'IMPLANTS' },
};

/**
 * Synchronizes the finite, non-persistent decoration mode with DM. Changing
 * tabs replaces the current state; leaving Augments or closing Preferences
 * unmounts the owner and clears it.
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
    status = decoration === 'none'
      ? undefined
      : augmentationFrameCopy[decoration].status,
    title = decoration === 'none'
      ? undefined
      : augmentationFrameCopy[decoration].title,
    width,
  } = props;
  const style = { height, width } satisfies CSSProperties;

  return (
    <div
      className={classes([
        'PreferencesCharacterPreviewFrame',
        decoration !== 'none' &&
          'PreferencesCharacterPreviewFrame--augmentation',
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
