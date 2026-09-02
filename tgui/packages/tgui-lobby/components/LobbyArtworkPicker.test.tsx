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
  it('renders eight radio presets and an orthogonal Classic Alt checkbox', () => {
    render(<LobbyArtworkPicker onAction={() => {}} value={DEFAULT_VALUE} />);
    const trigger = screen.getByRole('button', {
      name: /change lobby artwork/i,
    });

    expect(trigger.getAttribute('aria-haspopup')).toBe('menu');
    expect(trigger.getAttribute('aria-expanded')).toBe('false');
    fireEvent.click(trigger);

    const presets = screen.getAllByRole('menuitemradio');
    expect(presets).toHaveLength(8);
    expect(presets[0].textContent).toContain('Original - A Flat');
    expect(presets[2].getAttribute('aria-checked')).toBe('true');
    expect(presets[6].textContent).toContain('NavaroBL - C Convex');

    const classicAlt = screen.getByRole('menuitemcheckbox', {
      name: /classic alt/i,
    });
    expect(classicAlt.getAttribute('aria-checked')).toBe('false');
  });

  it('supports complete menu navigation, typeahead, Escape, and focus return', async () => {
    render(<LobbyArtworkPicker onAction={() => {}} value={DEFAULT_VALUE} />);
    const trigger = screen.getByRole('button', {
      name: /change lobby artwork/i,
    });

    fireEvent.click(trigger);
    const menu = screen.getByRole('menu');
    const presets = screen.getAllByRole('menuitemradio');
    const classicAlt = screen.getByRole('menuitemcheckbox');

    expect(document.activeElement).toBe(presets[2]);
    fireEvent.keyDown(menu, { key: 'ArrowDown' });
    expect(document.activeElement).toBe(presets[3]);
    fireEvent.keyDown(menu, { key: 'ArrowUp' });
    expect(document.activeElement).toBe(presets[2]);
    fireEvent.keyDown(menu, { key: 'End' });
    expect(document.activeElement).toBe(classicAlt);
    fireEvent.keyDown(menu, { key: 'Home' });
    expect(document.activeElement).toBe(presets[0]);
    fireEvent.keyDown(menu, { key: 'n' });
    expect(document.activeElement).toBe(presets[4]);
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
    expect(document.activeElement).toBe(screen.getByRole('menuitemcheckbox'));

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
