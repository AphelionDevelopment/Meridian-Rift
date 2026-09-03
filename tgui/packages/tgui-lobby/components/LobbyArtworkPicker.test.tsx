// THIS IS AN APHELION UI FILE
import { afterEach, describe, expect, it, mock } from 'bun:test';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from '@testing-library/react';
import {
  LobbyArtworkPicker,
  type LobbyArtworkPickerValue,
} from './LobbyArtworkPicker';

afterEach(cleanup);

const DEFAULT_VALUE: LobbyArtworkPickerValue = {
  classicAlt: false,
  texture: 'original',
  variant: 'convex',
  rotate: true,
  selected: null,
  screens: [
    { name: 'station_alpha.png', overlay: false },
    { name: 'nebula_dawn.png', overlay: true },
  ],
};

describe('LobbyArtworkPicker', () => {
  it('renders the title screen list, its overlay toggles, and the presets', () => {
    render(<LobbyArtworkPicker onAction={() => {}} value={DEFAULT_VALUE} />);
    const trigger = screen.getByRole('button', {
      name: /change lobby artwork/i,
    });

    expect(trigger.getAttribute('aria-haspopup')).toBe('menu');
    expect(trigger.getAttribute('aria-expanded')).toBe('false');
    fireEvent.click(trigger);

    // The configured screens lead, then the default master, then the presets. The
    // default trails the pictures because it is the fallback, not a rotation candidate.
    const radios = screen.getAllByRole('menuitemradio');
    expect(radios).toHaveLength(DEFAULT_VALUE.screens.length + 1 + 8);
    // The row shows a shortened name and carries the full one on hover.
    expect(radios[0].textContent).toContain('station_alpha');
    expect(radios[0].textContent).not.toContain('.png');
    expect(radios[0].getAttribute('title')).toBe('station_alpha.png');
    const defaultRadio = radios[DEFAULT_VALUE.screens.length];
    expect(defaultRadio.textContent).toContain('Meridian Rift (default)');
    expect(defaultRadio.getAttribute('aria-checked')).toBe('true');

    const presets = radios.slice(DEFAULT_VALUE.screens.length + 1);
    expect(presets[0].textContent).toContain('Original - A Flat');
    expect(presets[2].getAttribute('aria-checked')).toBe('true');
    expect(presets[6].textContent).toContain('NavaroBL - C Convex');

    // Each screen carries its own overlay opt-in, reflecting the server value.
    for (const shot of DEFAULT_VALUE.screens) {
      const overlay = screen.getByRole('menuitemcheckbox', {
        name: new RegExp(`overlay .*${shot.name}`, 'i'),
      });
      expect(overlay.getAttribute('aria-checked')).toBe(String(shot.overlay));
    }

    expect(
      screen
        .getByRole('menuitemcheckbox', { name: /rotate title screens/i })
        .getAttribute('aria-checked'),
    ).toBe('true');
    expect(
      screen
        .getByRole('menuitemcheckbox', { name: /classic alt/i })
        .getAttribute('aria-checked'),
    ).toBe('false');
  });

  it('supports complete menu navigation, typeahead, Escape, and focus return', async () => {
    render(<LobbyArtworkPicker onAction={() => {}} value={DEFAULT_VALUE} />);
    const trigger = screen.getByRole('button', {
      name: /change lobby artwork/i,
    });

    fireEvent.click(trigger);
    const menu = screen.getByRole('menu');
    // Queried by role and name rather than by index, so adding a section to the
    // menu does not silently rewrite what this test is asserting.
    const firstItem = screen.getAllByRole('menuitemradio')[0];
    const classicAlt = screen.getByRole('menuitemcheckbox', {
      name: /classic alt/i,
    });
    const rotate = screen.getByRole('menuitemcheckbox', {
      name: /rotate title screens/i,
    });

    fireEvent.keyDown(menu, { key: 'End' });
    expect(document.activeElement).toBe(classicAlt);
    fireEvent.keyDown(menu, { key: 'Home' });
    expect(document.activeElement).toBe(firstItem);
    fireEvent.keyDown(menu, { key: 'r' });
    expect(document.activeElement).toBe(rotate);
    fireEvent.keyDown(menu, { key: 'c' });
    expect(document.activeElement).toBe(classicAlt);

    fireEvent.keyDown(menu, { key: 'Escape' });
    await Promise.resolve();
    expect(trigger.getAttribute('aria-expanded')).toBe('false');
    expect(document.activeElement).toBe(trigger);
  });

  it('opens from arrow keys at the corresponding boundary', () => {
    const view = render(
      <LobbyArtworkPicker onAction={() => {}} value={DEFAULT_VALUE} />,
    );
    const trigger = screen.getByRole('button', {
      name: /change lobby artwork/i,
    });

    fireEvent.keyDown(trigger, { key: 'ArrowUp' });
    expect(document.activeElement).toBe(
      screen.getByRole('menuitemcheckbox', { name: /classic alt/i }),
    );

    view.unmount();
    render(<LobbyArtworkPicker onAction={() => {}} value={DEFAULT_VALUE} />);
    const nextTrigger = screen.getByRole('button', {
      name: /change lobby artwork/i,
    });
    fireEvent.keyDown(nextTrigger, { key: 'ArrowDown' });
    expect(document.activeElement).toBe(
      screen.getAllByRole('menuitemradio')[0],
    );
  });

  it('emits immutable composite and Classic Alt changes, then returns focus', async () => {
    const onAction = mock(() => {});
    render(<LobbyArtworkPicker onAction={onAction} value={DEFAULT_VALUE} />);
    const trigger = screen.getByRole('button', {
      name: /change lobby artwork/i,
    });

    fireEvent.click(trigger);
    fireEvent.click(
      screen.getByRole('menuitemradio', { name: /navarobl - d convex/i }),
    );
    await Promise.resolve();
    expect(onAction).toHaveBeenCalledWith({
      type: 'presentation',
      classicAlt: false,
      texture: 'navarobl',
      variant: 'convex-bezel',
    });
    expect(document.activeElement).toBe(trigger);

    fireEvent.click(trigger);
    fireEvent.click(
      screen.getByRole('menuitemcheckbox', { name: /classic alt/i }),
    );
    await Promise.resolve();
    expect(onAction).toHaveBeenCalledWith({
      type: 'presentation',
      classicAlt: true,
      texture: 'original',
      variant: 'convex',
    });
    expect(document.activeElement).toBe(trigger);
  });

  it('dismisses on outside press without selecting anything', async () => {
    const onAction = mock(() => {});
    render(<LobbyArtworkPicker onAction={onAction} value={DEFAULT_VALUE} />);
    const trigger = screen.getByRole('button', {
      name: /change lobby artwork/i,
    });

    fireEvent.click(trigger);
    await act(async () => {
      await Promise.resolve();
    });
    fireEvent.pointerDown(document.body);

    expect(trigger.getAttribute('aria-expanded')).toBe('false');
    expect(onAction).not.toHaveBeenCalled();
    expect(
      screen
        .getByRole('menu')
        .closest('.Floating')
        ?.getAttribute('data-transition'),
    ).toBe('close');
  });
});
