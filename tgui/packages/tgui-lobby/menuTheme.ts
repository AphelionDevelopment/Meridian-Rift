// THIS IS AN APHELION UI FILE
import type { MeridianBaseThemeId } from 'tgui/constants/theme';

const HEADINGS: Record<MeridianBaseThemeId, string> = {
  meridian: 'STATION CONTROL',
  meridian_classic: 'CREW TERMINAL',
  meridian_pipboy: 'PERSONNEL TERMINAL',
  meridian_vector: 'NAVIGATION LINK',
  meridian_foundry: 'CREW DISPATCH',
  meridian_diagnostic: 'SYSTEM DIAGNOSTICS',
  meridian_highline: 'CREW OPERATIONS',
  meridian_synapse: 'SIGNAL CONNECTION',
  meridian_synapse_xxxo: 'SIGNAL CONNECTION',
  meridian_cyberpunk: 'NETWORK ACCESS',
  meridian_augmentation: 'AUGMENT INTERFACE',
  meridian_afterlight: 'FIELD TERMINAL',
  meridian_relay: 'CREW UPLINK',
  meridian_bastion: 'ACCESS CONTROL',
  meridian_aphelion: 'CREW ACCESS',
};

/** Themed menus share the title artwork's selected scanline glass. */
export function getLobbyMenuHeading(theme: MeridianBaseThemeId) {
  return HEADINGS[theme];
}

/** The first three authored menus retain their independently tuned layouts. */
export function usesSharedLobbyMenu(theme: MeridianBaseThemeId) {
  return (
    !!getLobbyMenuHeading(theme) &&
    !['meridian_pipboy', 'meridian_highline', 'meridian_aphelion'].includes(
      theme,
    )
  );
}
