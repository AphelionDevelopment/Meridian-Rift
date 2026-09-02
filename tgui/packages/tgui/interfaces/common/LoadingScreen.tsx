/** Spinner that represents loading states.
 *
 * @usage
 * ```tsx
 * /// rest of the component
 * return (
 * ///... content to overlay
 * {!!loading && <LoadingScreen />}
 * /// ... content to overlay
 * );
 * ```
 * OR
 * ```tsx
 * return (
 * {loading ? <LoadingScreen /> : <ContentToHide />}
 * )
 * ```
 */
// APHELION EDIT CHANGE START - MERIDIAN_UI - ORIGINAL: this file rendered the
// spinner itself -- a centered `Stack` holding `<Icon color="blue" name="toolbox"
// spin size={4} />` above `props.label || 'Please wait...'`. The implementation
// moved to the modular DiagnosticLoader so every loading surface shares one
// instrument; this file stays as the upstream entry point so no tg call site
// has to be touched. DiagnosticLoader accepts the same optional `label`.
export { DiagnosticLoader as LoadingScreen } from './DiagnosticLoader';
// APHELION EDIT CHANGE END
