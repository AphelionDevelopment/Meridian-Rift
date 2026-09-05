// THIS IS AN APHELION UI FILE
import { afterEach, describe, expect, it, mock } from 'bun:test';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from '@testing-library/react';
import { MERIDIAN_BASE_THEME_OPTIONS } from '../constants/theme';
import { MeridianThemePicker } from './MeridianThemePicker';

afterEach(cleanup);

describe('MeridianThemePicker', () => {
  it('renders the ordered theme catalog as an accessible radio menu', () => {
    render(<MeridianThemePicker onChange={() => {}} value="meridian" />);

    const trigger = screen.getByRole('button', {
      name: /change base interface theme/i,
    });
    expect(trigger.getAttribute('aria-haspopup')).toBe('menu');
    expect(trigger.getAttribute('aria-expanded')).toBe('false');

    fireEvent.click(trigger);

    expect(trigger.getAttribute('aria-expanded')).toBe('true');
    const options = screen.getAllByRole('menuitemradio');
    expect(options).toHaveLength(MERIDIAN_BASE_THEME_OPTIONS.length);
    expect(options[0].textContent).toContain('Standard');
    expect(options[1].textContent).toContain('Classic NT');
    expect(options[2].textContent).toContain('Wastelander');
    expect(options[0].getAttribute('aria-checked')).toBe('true');
    expect(options[1].getAttribute('aria-checked')).toBe('false');
    expect(options[2].getAttribute('aria-checked')).toBe('false');
  });

  it('supports complete menu navigation, selection, and focus return', async () => {
    const onChange = mock(() => {});
    render(<MeridianThemePicker onChange={onChange} value="meridian" />);
    const trigger = screen.getByRole('button', {
      name: /change base interface theme/i,
    });

    fireEvent.click(trigger);
    const menu = screen.getByRole('menu');
    const options = screen.getAllByRole('menuitemradio');

    expect(document.activeElement).toBe(options[0]);
    fireEvent.keyDown(menu, { key: 'ArrowDown' });
    expect(document.activeElement).toBe(options[1]);
    fireEvent.keyDown(menu, { key: 'ArrowUp' });
    expect(document.activeElement).toBe(options[0]);
    fireEvent.keyDown(menu, { key: 'End' });
    expect(document.activeElement).toBe(options[options.length - 1]);
    fireEvent.keyDown(menu, { key: 'Home' });
    expect(document.activeElement).toBe(options[0]);
    fireEvent.keyDown(menu, { key: 'c' });
    expect(document.activeElement).toBe(options[1]);
    fireEvent.keyDown(menu, { key: 'y' });
    expect(document.activeElement).toBe(options[8]);

    fireEvent.keyDown(menu, { key: 'Escape' });
    await Promise.resolve();
    expect(trigger.getAttribute('aria-expanded')).toBe('false');
    expect(document.activeElement).toBe(trigger);

    fireEvent.click(trigger);
    fireEvent.click(screen.getAllByRole('menuitemradio')[1]);
    expect(onChange).toHaveBeenCalledWith('meridian_classic');
  });

  it('opens from either arrow key at the corresponding boundary', () => {
    const view = render(
      <MeridianThemePicker onChange={() => {}} value="meridian_diagnostic" />,
    );
    const trigger = screen.getByRole('button', {
      name: /change base interface theme/i,
    });

    fireEvent.keyDown(trigger, { key: 'ArrowUp' });
    const options = screen.getAllByRole('menuitemradio');
    expect(document.activeElement).toBe(options[options.length - 1]);

    view.unmount();
    render(
      <MeridianThemePicker onChange={() => {}} value="meridian_diagnostic" />,
    );
    const nextTrigger = screen.getByRole('button', {
      name: /change base interface theme/i,
    });
    fireEvent.keyDown(nextTrigger, { key: 'ArrowDown' });
    expect(document.activeElement).toBe(screen.getAllByRole('menuitemradio')[0]);
  });

  it('dismisses on an outside press', async () => {
    render(<MeridianThemePicker onChange={() => {}} value="meridian" />);
    const trigger = screen.getByRole('button', {
      name: /change base interface theme/i,
    });

    fireEvent.click(trigger);
    expect(screen.getByRole('menu')).toBeTruthy();
    await act(async () => {
      await Promise.resolve();
    });
    fireEvent.pointerDown(document.body);

    expect(trigger.getAttribute('aria-expanded')).toBe('false');
    expect(
      screen
        .getByRole('menu')
        .closest('.Floating')
        ?.getAttribute('data-transition'),
    ).toBe('close');
  });
});
