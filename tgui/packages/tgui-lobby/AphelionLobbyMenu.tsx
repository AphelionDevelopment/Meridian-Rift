// THIS IS AN APHELION UI FILE

import { useState } from 'react';
import type { MeridianBaseThemeId } from 'tgui/constants/theme';
import { MeridianThemePicker } from 'tgui/layouts/MeridianThemePicker';
import { assetMap } from './assets';
import { BootTerminal } from './components/BootTerminal';
import {
  LobbyArtworkPicker,
  type LobbyArtworkPickerValue,
} from './components/LobbyArtworkPicker';
import { NavMenu } from './components/NavMenu';
import { NoticeBanner } from './components/NoticeBanner';
import {
  DEFAULT_LOBBY_TITLE_ART_VARIANT,
  TitleArtwork,
} from './components/TitleArtwork';
import type { ServerState } from './LobbyMenu';

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
  const [artworkOverride, setArtworkOverride] =
    useState<LobbyArtworkPickerValue | null>(null);
  const navaroTextureSrc =
    assetMap['meridian_rift_scanlines_navarobl.png'] || undefined;
  const isPipBoyTheme = meridianTheme === 'meridian_pipboy';
  const artworkValue: LobbyArtworkPickerValue = artworkOverride ?? {
    classicAlt: false,
    texture: isPipBoyTheme && navaroTextureSrc ? 'navarobl' : 'original',
    variant: DEFAULT_LOBBY_TITLE_ART_VARIANT,
  };
  const showArtworkPicker =
    !serverState.transparent &&
    !!serverState.titleImageUrl &&
    serverState.titleImageTreatment === 'meridian';

  return (
    <div
      className={`lobby ${serverState.transparent ? 'lobby--transparent' : ''}`}
    >
      {!serverState.transparent && !!serverState.titleImageUrl && (
        <TitleArtwork
          branded={serverState.titleImageTreatment === 'meridian'}
          presentation={artworkValue.classicAlt ? 'classic-alt' : 'classic'}
          src={serverState.titleImageUrl}
          texture={artworkValue.texture}
          textureSrc={navaroTextureSrc}
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
            onChange={setArtworkOverride}
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
