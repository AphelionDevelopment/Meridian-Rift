// THIS IS AN APHELION UI FILE
import type { MeridianBaseThemeId } from 'tgui/constants/theme';

/** Menus with their own heading also share the title artwork's scanline glass. */
export function getLobbyMenuHeading(theme: MeridianBaseThemeId) {
  switch (theme) {
    case 'meridian_pipboy':
      return 'PERSONNEL TERMINAL';
    case 'meridian_highline':
      return 'CREW OPERATIONS';
    case 'meridian_aphelion':
      return 'CREW ACCESS';
    default:
      return undefined;
  }
}
