import { describe, expect, it } from 'bun:test';
import {
  isLobbyKeyboardInteractionTarget,
  isThemePickerInteractionTarget,
} from './themeFocus';

describe('lobby theme-picker focus integration', () => {
  it('recognizes both the trigger and its portaled floating menu', () => {
    const triggerRoot = document.createElement('span');
    triggerRoot.className = 'MeridianThemePicker';
    const trigger = document.createElement('button');
    triggerRoot.appendChild(trigger);

    const floatingRoot = document.createElement('div');
    floatingRoot.className = 'MeridianThemePicker__floating';
    const option = document.createElement('button');
    floatingRoot.appendChild(option);

    expect(isThemePickerInteractionTarget(trigger)).toBe(true);
    expect(isThemePickerInteractionTarget(option)).toBe(true);
    expect(isThemePickerInteractionTarget(document.body)).toBe(false);
    expect(isThemePickerInteractionTarget(null)).toBe(false);
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
