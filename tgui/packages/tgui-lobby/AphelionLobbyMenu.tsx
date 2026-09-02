// THIS IS AN APHELION UI FILE

import type { MeridianBaseThemeId } from 'tgui/constants/theme';
import { MeridianThemePicker } from 'tgui/layouts/MeridianThemePicker';
import { assetMap } from './assets';
import { BootTerminal } from './components/BootTerminal';
import { NavMenu } from './components/NavMenu';
import { NoticeBanner } from './components/NoticeBanner';
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
  return (
    <div
      className={`lobby ${serverState.transparent ? 'lobby--transparent' : ''}`}
    >
      {!serverState.transparent && !!serverState.titleImageUrl && (
        <img className="bg" src={serverState.titleImageUrl} alt="" />
      )}

      <div className="lobby__theme-picker">
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
