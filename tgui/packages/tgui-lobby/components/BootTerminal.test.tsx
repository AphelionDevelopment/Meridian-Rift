import { afterEach, describe, expect, it } from 'bun:test';
import { cleanup, render } from '@testing-library/react';
import {
  BOOT_PROGRESS_WRITE_INTERVAL_MS,
  BootTerminal,
  extrapolateStartupTime,
  getStartupProgressPercent,
  isBootProgressWriteDue,
} from './BootTerminal';

afterEach(cleanup);

describe('BootTerminal progress', () => {
  it('normalizes malformed values and never moves visual progress backwards', () => {
    expect(getStartupProgressPercent(50, 100)).toBe(50);
    expect(getStartupProgressPercent(150, 100)).toBe(100);
    expect(getStartupProgressPercent(20, 100, 40)).toBe(40);
    expect(getStartupProgressPercent(Number.NaN, 100, 25)).toBe(25);
    expect(getStartupProgressPercent(50, Number.NaN, 25)).toBe(25);
    expect(getStartupProgressPercent(50, 0, 25)).toBe(25);
  });

  it('extrapolates Dream Maker deciseconds and clamps at completion', () => {
    expect(extrapolateStartupTime(50, 100, 1000)).toBe(60);
    expect(extrapolateStartupTime(95, 100, 1000)).toBe(100);
    expect(extrapolateStartupTime(50, 100, -1000)).toBe(50);
    expect(BOOT_PROGRESS_WRITE_INTERVAL_MS).toBe(100);
  });

  it('gates visual writes to ten updates per second', () => {
    expect(isBootProgressWriteDue(0, 0)).toBe(false);
    expect(isBootProgressWriteDue(99, 0)).toBe(false);
    expect(isBootProgressWriteDue(100, 0)).toBe(true);
    expect(isBootProgressWriteDue(199, 100)).toBe(false);
    expect(isBootProgressWriteDue(200, 100)).toBe(true);
  });

  it('renders the shared diagnostic instrument, latest status, log, and rail', () => {
    const view = render(
      <BootTerminal
        messages={[
          { text: 'Loading core systems', warning: false },
          { text: 'Delayed map subsystem', warning: true },
        ]}
        progressCurrent={25}
        progressTotal={100}
      />,
    );

    const instrument = view.getByRole('progressbar', {
      name: 'System startup progress',
    });
    expect(instrument.getAttribute('aria-valuemin')).toBe('0');
    expect(instrument.getAttribute('aria-valuemax')).toBe('100');
    expect(instrument.getAttribute('aria-valuenow')).toBe('25');
    expect(view.getByText('SYSTEM STARTUP')).toBeDefined();
    expect(
      view.container.querySelector('.boot_terminal__statusValue')?.textContent,
    ).toBe('25% · Delayed map subsystem');

    const log = view.getByRole('log', { name: 'System startup log' });
    expect(log.tabIndex).toBe(0);
    expect(log.textContent).toContain('Loading core systems');
    expect(log.textContent).toContain('CAUTION / Delayed map subsystem');

    const prompt = view.container.querySelector('.terminal_prompt');
    const cursor = view.container.querySelector('.boot_terminal__cursor');
    expect(prompt?.getAttribute('aria-hidden')).toBe('true');
    expect(prompt?.textContent).toContain('MeridianOS/BOOT:STREAM>');
    expect(cursor).toBeTruthy();
    expect(view.container.querySelectorAll('.boot_terminal__cursor')).toHaveLength(
      1,
    );

    const rail = view.container.querySelector<HTMLElement>('.progress_bar');
    expect(rail?.style.getPropertyValue('--boot-progress')).toBe('0.25');
    expect(view.container.querySelector('.sub_progress_bar')).toBeNull();
  });

  it('keeps an active transcript and cursor while awaiting the first message', () => {
    const view = render(
      <BootTerminal messages={[]} progressCurrent={0} progressTotal={100} />,
    );

    expect(view.getByRole('log').textContent).toContain(
      'Awaiting startup telemetry',
    );
    expect(view.container.querySelector('.boot_terminal__cursor')).toBeTruthy();
    expect(
      view.container.querySelector('.container_terminal__channel')?.textContent,
    ).toContain('00 REC / LIVE');
  });
});
