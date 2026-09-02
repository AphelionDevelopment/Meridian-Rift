const THEME_PICKER_SELECTOR =
  '.MeridianThemePicker, .MeridianThemePicker__floating';
const KEYBOARD_INTERACTIVE_SELECTOR = [
  'button:not(:disabled)',
  'a[href]',
  'input:not(:disabled)',
  'select:not(:disabled)',
  'textarea:not(:disabled)',
  '[contenteditable="true"]',
  '[tabindex]:not([tabindex="-1"])',
  '[role="button"]',
  '[role="menuitemradio"]',
].join(', ');

/** Keep the lobby's map-focus hack away from the interactive theme menu. */
export function isThemePickerInteractionTarget(target: EventTarget | null) {
  return (
    target instanceof Element && Boolean(target.closest(THEME_PICKER_SELECTOR))
  );
}

/** Let native lobby controls keep focus for Tab, Enter, and Space handling. */
export function isLobbyKeyboardInteractionTarget(target: EventTarget | null) {
  return (
    target instanceof Element &&
    Boolean(
      target.closest(
        `${THEME_PICKER_SELECTOR}, ${KEYBOARD_INTERACTIVE_SELECTOR}`,
      ),
    )
  );
}
