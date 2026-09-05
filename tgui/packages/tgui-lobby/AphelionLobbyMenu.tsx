// THIS IS AN APHELION UI FILE

import type { CSSProperties } from 'react';
import { Icon } from 'tgui-core/components';

import type { MeridianBaseThemeId } from 'tgui/constants/theme';
import { MeridianThemePicker } from 'tgui/layouts/MeridianThemePicker';
import { assetMap } from './assets';
import { BootTerminal } from './components/BootTerminal';
import { NavMenu } from './components/NavMenu';
import { NoticeBanner } from './components/NoticeBanner';
import {
  resolveLobbyScreenPresentation,
  resolveLobbyTitleArtVariant,
  resolveLobbyTitleBezel,
  resolveLobbyTitleTexture,
  resolveLobbyTitleTreatment,
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

  const scanlineOverlay = (() => {
    if (
      meridianTheme !== 'meridian_pipboy' ||
      serverState.gamePhase === 'startup' ||
      serverState.transparent ||
      !serverState.titleImageUrl
    ) {
      return null;
    }

    const treatment = resolveLobbyTitleTreatment(
      serverState.titleImageTreatment,
    );
    if (
      treatment === 'none' ||
      (treatment === 'overlay' && !serverState.titleMarkUrl)
    ) {
      return null;
    }

    // Match TitleArtwork's explicit choice, document fallback, and asset fallback.
    const texture = resolveLobbyTitleTexture(
      serverState.titleTexture ??
        document.documentElement.dataset.lobbyTitleTexture,
      !!navaroTextureSrc,
    );
    if (texture === 'none') {
      return null;
    }

    const requestedVariant =
      serverState.titleVariant ??
      document.documentElement.dataset.lobbyTitleVariant;
    const textureStyle = navaroTextureSrc
      ? ({
          '--lobby-title-scanline-image': `url("${navaroTextureSrc
            .replaceAll('\\', '\\\\')
            .replaceAll('"', '\\"')}")`,
        } as CSSProperties)
      : undefined;

    return {
      bezel: resolveLobbyTitleBezel(serverState.titleBezel, requestedVariant),
      texture,
      textureStyle,
      variant: resolveLobbyTitleArtVariant(requestedVariant),
    };
  })();

  return (
    <div
      className={`lobby ${serverState.transparent ? 'lobby--transparent' : ''}`}
      data-menu-scanlines={scanlineOverlay ? 'true' : undefined}
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
            texture={scanlineOverlay ? 'none' : serverState.titleTexture}
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

      {/* A decorative sibling allows interleaving without reparenting controls
          into the aria-hidden, clipped artwork. CSS makes this glass transparent. */}
      {scanlineOverlay && (
        <div
          aria-hidden="true"
          className={[
            'lobby-title-art',
            'lobby-menu-scanline-overlay',
            `lobby-title-art--${scanlineOverlay.variant}`,
            `lobby-title-art--texture-${scanlineOverlay.texture}`,
            scanlineOverlay.bezel && 'lobby-title-art--bezel',
          ]
            .filter(Boolean)
            .join(' ')}
          data-bezel={scanlineOverlay.bezel ? 'true' : 'false'}
          data-texture={scanlineOverlay.texture}
          data-variant={scanlineOverlay.variant}
        >
          <div className="lobby-title-art__bezel">
            <div className="lobby-title-art__screen">
              <div
                className="lobby-title-art__scanlines"
                style={scanlineOverlay.textureStyle}
              />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
