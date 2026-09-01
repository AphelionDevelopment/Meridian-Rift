// THIS IS AN APHELION UI FILE
import { describe, expect, it } from 'bun:test';
import {
  isLobbyDisplayControlInteractionTarget,
  isLobbyKeyboardInteractionTarget,
} from './themeFocus';

describe('lobby display-picker focus integration', () => {
  it('recognizes both picker triggers and their portaled floating menus', () => {
    const triggerRoot = document.createElement('span');
    triggerRoot.className = 'MeridianThemePicker';
    const trigger = document.createElement('button');
    triggerRoot.appendChild(trigger);

    const floatingRoot = document.createElement('div');
    floatingRoot.className = 'MeridianThemePicker__floating';
    const option = document.createElement('button');
    floatingRoot.appendChild(option);

    const artworkTriggerRoot = document.createElement('span');
    artworkTriggerRoot.className = 'LobbyArtworkPicker';
    const artworkTrigger = document.createElement('button');
    artworkTriggerRoot.appendChild(artworkTrigger);

    const artworkFloatingRoot = document.createElement('div');
    artworkFloatingRoot.className = 'LobbyArtworkPicker__floating';
    const presentationOption = document.createElement('button');
    presentationOption.setAttribute('role', 'menuitemcheckbox');
    artworkFloatingRoot.appendChild(presentationOption);

    expect(isLobbyDisplayControlInteractionTarget(trigger)).toBe(true);
    expect(isLobbyDisplayControlInteractionTarget(option)).toBe(true);
    expect(isLobbyDisplayControlInteractionTarget(artworkTrigger)).toBe(true);
    expect(isLobbyDisplayControlInteractionTarget(presentationOption)).toBe(
      true,
    );
    expect(isLobbyKeyboardInteractionTarget(presentationOption)).toBe(true);
    expect(isLobbyDisplayControlInteractionTarget(document.body)).toBe(false);
    expect(isLobbyDisplayControlInteractionTarget(null)).toBe(false);
  });

  it('lets native lobby controls retain keyboard focus', () => {
    const navButton = document.createElement('button');
    const label = document.createElement('span');
    navButton.appendChild(label);

    expect(isLobbyKeyboardInteractionTarget(label)).toBe(true);
    expect(isLobbyKeyboardInteractionTarget(document.body)).toBe(false);

    navButton.disabled = true;
    expect(isLobbyKeyboardInteractionTarget(label)).toBe(false);

    const scrollRegion = document.createElement('div');
    scrollRegion.tabIndex = 0;
    expect(isLobbyKeyboardInteractionTarget(scrollRegion)).toBe(true);
  });
});
