import './styles/main.scss';

import { loadMappings, loadStyleSheet } from 'common/assets';
import { createRoot, type Root } from 'react-dom/client';
import { focusMap } from 'tgui/focus';
import { globalEvents } from 'tgui-core/events';
import { assetMap } from './assets';
import { LobbyMenu } from './LobbyMenu';
import { updateScaling } from './scaling';
import {
  isLobbyKeyboardInteractionTarget,
  isThemePickerInteractionTarget,
} from './themeFocus';

let reactRoot: Root | null = null;

document.onreadystatechange = () => {
  if (document.readyState !== 'complete') return;

  updateScaling();

  window.addEventListener('resize', () => {
    updateScaling();
  });

  globalEvents.on('keydown', (key) => {
    if (
      key.isModifierKey() ||
      key.event.key === 'Tab' ||
      isLobbyKeyboardInteractionTarget(key.event.target)
    ) {
      return;
    }
    setTimeout(focusMap);
  });
  window.addEventListener('mouseup', (event) => {
    if (isThemePickerInteractionTarget(event.target)) {
      return;
    }
    setTimeout(focusMap);
  });

  Byond.winget('mapwindow.map_lobby_selector').then(
    (info: { size: string }) => {
      Byond.winset('lobby_menu', { size: info.size });
    },
  );

  if (!reactRoot) {
    const root = document.getElementById('react-root');
    reactRoot = createRoot(root!);
  }

  reactRoot.render(<LobbyMenu />);

  Byond.subscribeTo('asset/stylesheet', loadStyleSheet);
  Byond.subscribeTo('asset/mappings', (payload: Record<string, string>) => {
    loadMappings(payload, assetMap);
  });
};
