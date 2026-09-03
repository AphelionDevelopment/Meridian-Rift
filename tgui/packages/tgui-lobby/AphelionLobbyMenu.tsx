// THIS IS AN APHELION UI FILE

import type { MeridianBaseThemeId } from 'tgui/constants/theme';
import { MeridianThemePicker } from 'tgui/layouts/MeridianThemePicker';
import { assetMap } from './assets';
import { BootTerminal } from './components/BootTerminal';
import {
  type LobbyArtworkAction,
  LobbyArtworkPicker,
  type LobbyArtworkPickerValue,
} from './components/LobbyArtworkPicker';
import { NavMenu } from './components/NavMenu';
import { NoticeBanner } from './components/NoticeBanner';
import { TitleArtwork } from './components/TitleArtwork';
import type { ServerState } from './LobbyMenu';

/**
 * Forward one admin change to the server.
 *
 * The server is the single source of truth: nothing is applied optimistically,
 * so the menu only moves once the broadcast comes back. That also means every
 * open lobby stays in step, not just the one that made the change.
 */
function sendArtworkAction(action: LobbyArtworkAction) {
  switch (action.type) {
    case 'screen':
      Byond.sendMessage('setTitleScreen', { screen: action.name });
      break;
    case 'rotate':
      Byond.sendMessage('setTitleRotation', { rotate: action.rotate });
      break;
    case 'overlay':
      Byond.sendMessage('setTitleOverlay', {
        screen: action.name,
        overlay: action.overlay,
      });
      break;
    case 'presentation':
      Byond.sendMessage('setTitlePresentation', {
        classicAlt: action.classicAlt,
        texture: action.texture,
        variant: action.variant,
      });
      break;
  }
}

/**
 * Aphelion's own lobby layout - plain-text/Fixedsys nav menu and boot terminal, ported
 * from config/nova/title_html.txt, in place of upstream's sprite buttons and TV panel.
 * Kept in its own file so LobbyMenu.tsx (the vanilla-tracked state shell) stays small
 * and easy to diff against upstream.
 */
export function AphelionLobbyMenu({
  meridianTheme,
  onMeridianThemeChange,
  serverState,
}: {
  meridianTheme: MeridianBaseThemeId;
  onMeridianThemeChange: (theme: MeridianBaseThemeId) => void;
  serverState: ServerState;
}) {
  const navaroTextureSrc =
    assetMap['meridian_rift_scanlines_navarobl.png'] || undefined;
  // Presentation is server-wide now, so it comes straight off serverState
  // rather than being mirrored into local state.
  const artworkValue: LobbyArtworkPickerValue = {
    classicAlt: serverState.titleClassicAlt,
    texture: serverState.titleTexture,
    variant: serverState.titleVariant,
    rotate: serverState.titleRotate,
    selected: serverState.titleSelected,
    screens: serverState.titleScreens ?? [],
  };
  // The server re-checks the rank on every message; this only hides the menu.
  const showArtworkPicker =
    !serverState.transparent && serverState.canSetTitleScreen;

  return (
    <div
      className={`lobby ${serverState.transparent ? 'lobby--transparent' : ''}`}
    >
      {/* The boot terminal owns the screen during startup, so the title
          artwork stays out of the way until the round is loaded. */}
      {serverState.gamePhase !== 'startup' &&
        !serverState.transparent &&
        !!serverState.titleImageUrl && (
        <TitleArtwork
          markSrc={serverState.titleMarkUrl}
          presentation={artworkValue.classicAlt ? 'classic-alt' : 'classic'}
          src={serverState.titleImageUrl}
          texture={artworkValue.texture}
          textureSrc={navaroTextureSrc}
          treatment={serverState.titleImageTreatment}
          variant={artworkValue.variant}
        />
      )}

      <div
        aria-label="Lobby display controls"
        className="lobby__theme-picker lobby__display-controls"
        role="group"
      >
        {showArtworkPicker && (
          <LobbyArtworkPicker
            onAction={sendArtworkAction}
            placement="bottom-end"
            value={artworkValue}
          />
        )}
        <MeridianThemePicker
          onChange={onMeridianThemeChange}
          placement="bottom-end"
          value={meridianTheme}
        />
      </div>

      {serverState.gamePhase === 'startup' ? (
        <BootTerminal
          messages={serverState.startupMessages}
          progressCurrent={serverState.progressCurrent}
          progressTotal={serverState.progressTotal}
        />
      ) : (
        <>
          {!!serverState.notice && <NoticeBanner text={serverState.notice} />}
          <NavMenu serverState={serverState} assetMap={assetMap} />
        </>
      )}
    </div>
  );
}
