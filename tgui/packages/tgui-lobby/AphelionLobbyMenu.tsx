// THIS IS AN APHELION UI FILE

import { Icon } from 'tgui-core/components';

import type { MeridianBaseThemeId } from 'tgui/constants/theme';
import { MeridianThemePicker } from 'tgui/layouts/MeridianThemePicker';
import { assetMap } from './assets';
import { BootTerminal } from './components/BootTerminal';
import { NavMenu } from './components/NavMenu';
import { NoticeBanner } from './components/NoticeBanner';
import {
  resolveLobbyScreenPresentation,
  TitleArtwork,
} from 'tgui/interfaces/common/TitleArtwork';
import type { ServerState } from './LobbyMenu';

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
  // The server re-checks the rank when the message arrives; this only hides
  // the button.
  const showArtworkButton =
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
          bezel={serverState.titleBezel}
          markSrc={serverState.titleMarkUrl}
          presentation={resolveLobbyScreenPresentation(
            serverState.titleImageTreatment,
            serverState.titleClassicAlt,
          )}
          src={serverState.titleImageUrl}
          texture={serverState.titleTexture}
          textureSrc={navaroTextureSrc}
          treatment={serverState.titleImageTreatment}
          variant={serverState.titleVariant}
        />
      )}

      <div
        aria-label="Lobby display controls"
        className="lobby__theme-picker lobby__display-controls"
        role="group"
      >
        {showArtworkButton && (
          <button
            aria-label="Manage the lobby title screen"
            className="lobby__display-control"
            onClick={() => Byond.sendMessage('openTitleManager')}
            title="Manage the lobby title screen"
            type="button"
          >
            <Icon name="images" />
          </button>
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
