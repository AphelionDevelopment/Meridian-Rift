// APHELION EDIT CHANGE START - MERIDIAN_UI - ORIGINAL: this file rendered the
// bar itself -- `const Loader = ({ value }) => <div className="AlertModal__Loader">`
// wrapping a `Box.AlertModal__LoaderProgress` whose width was set to
// `clamp01(value) * 100%`. The implementation moved to the modular TimeoutBar
// so every blocking input window shares one treatment; this file stays as the
// upstream entry point so no tg call site has to be touched.
export { TimeoutBar as Loader } from './TimeoutBar';
// APHELION EDIT CHANGE END
