import { afterEach, beforeEach, describe, expect, it, mock } from 'bun:test';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from '@testing-library/react';
import { assetMap } from './assets';
import type { ServerState } from './LobbyMenu';
import { LobbyMenu } from './LobbyMenu';

type LobbySubscription = (payload: unknown) => void;

const originalSendMessage = Byond.sendMessage;
const originalSubscribeTo = Byond.subscribeTo;
const originalRequestAnimationFrame = window.requestAnimationFrame;
const originalCancelAnimationFrame = window.cancelAnimationFrame;

const subscriptions = new Map<string, LobbySubscription>();
let sendMessage: ReturnType<typeof mock>;

function makeServerState(overrides: Partial<ServerState> = {}): ServerState {
  return {
    titleImageUrl: 'asset://title.png',
    titleImageTreatment: 'meridian',
    gamePhase: 'startup',
    isReady: false,
    canReady: true,
    canJoin: false,
    canObserve: false,
    assetsReady: true,
    countdown: '30s',
    playerCount: 1,
    readyCount: 0,
    adminReadyCount: 0,
    adminCount: 0,
    mapName: 'Test Station',
    shiftTime: 'Pre-Game',
    isAdmin: false,
    isLocalhost: false,
    stationTraits: [],
    hasNewPoll: false,
    canPoll: false,
    overflowJob: null,
    traitFeedback: null,
    transparent: false,
    notice: null,
    latejoinQueue: 'PRE-ROUND',
    characterName: 'TEST PLAYER',
    isAntag: false,
    startupMessages: [{ text: 'Loading test systems', warning: false }],
    progressCurrent: 25,
    progressTotal: 100,
    meridianTheme: 'meridian',
    ...overrides,
  };
}

function emit(name: 'init' | 'state', payload: unknown) {
  act(() => subscriptions.get(name)?.(payload));
}

beforeEach(() => {
  subscriptions.clear();
  sendMessage = mock(() => {});
  Byond.sendMessage = sendMessage as typeof Byond.sendMessage;
  Byond.subscribeTo = mock((name: string, callback: LobbySubscription) => {
    subscriptions.set(name, callback);
  }) as typeof Byond.subscribeTo;
  assetMap['meridian_rift_scanlines_navarobl.png'] =
    'asset://navarobl-scanlines.png';
});

afterEach(() => {
  cleanup();
  Byond.sendMessage = originalSendMessage;
  Byond.subscribeTo = originalSubscribeTo;
  window.requestAnimationFrame = originalRequestAnimationFrame;
  window.cancelAnimationFrame = originalCancelAnimationFrame;
  document.documentElement.classList.remove('runtime-marker');
  document.documentElement.style.removeProperty('--lobby-bg');
  delete assetMap['meridian_rift_scanlines_navarobl.png'];
});

describe('LobbyMenu MeridianOS integration', () => {
  it('applies an optimistic picker choice and preserves unrelated root classes', async () => {
    document.documentElement.classList.add('runtime-marker');
    render(<LobbyMenu />);
    emit('init', makeServerState());

    fireEvent.click(
      screen.getByRole('button', { name: /change base interface theme/i }),
    );
    fireEvent.click(screen.getByRole('menuitemradio', { name: /classic nt/i }));
    await act(async () => Promise.resolve());

    expect(sendMessage).toHaveBeenCalledWith('setMeridianTheme', {
      theme: 'meridian_classic',
    });
    expect(
      document.documentElement.classList.contains('theme-nanotrasen'),
    ).toBe(true);
    expect(document.documentElement.classList.contains('theme-console')).toBe(
      false,
    );
    expect(document.documentElement.classList.contains('runtime-marker')).toBe(
      true,
    );
  });

  it('keeps the same boot loader and RAF when only the theme changes', () => {
    let rafCount = 0;
    window.requestAnimationFrame = mock(() => ++rafCount);
    window.cancelAnimationFrame = mock(() => {});

    render(<LobbyMenu />);
    emit('init', makeServerState());
    const loader = screen.getByRole('progressbar', {
      name: 'System startup progress',
    });
    const cursor = document.querySelector('.boot_terminal__cursor');
    expect(cursor).toBeTruthy();
    const initialRafCount = rafCount;

    emit('state', { meridianTheme: 'meridian_vector' });

    expect(
      screen.getByRole('progressbar', { name: 'System startup progress' }),
    ).toBe(loader);
    expect(document.querySelector('.boot_terminal__cursor')).toBe(cursor);
    expect(rafCount).toBe(initialRafCount);
    expect(
      document.documentElement.classList.contains('theme-meridian_vector'),
    ).toBe(true);
  });

  it('retains theme and transparency behavior across startup and nav phases', () => {
    render(<LobbyMenu />);
    emit(
      'init',
      makeServerState({
        meridianTheme: 'meridian_foundry',
        transparent: true,
      }),
    );

    expect(screen.getByRole('progressbar')).toBeTruthy();
    expect(document.querySelector('.bg')).toBeNull();
    expect(document.documentElement.style.getPropertyValue('--lobby-bg')).toBe(
      'transparent',
    );

    emit('state', { gamePhase: 'pregame' });

    expect(screen.queryByRole('progressbar')).toBeNull();
    expect(screen.getByRole('button', { name: /ready/i })).toBeTruthy();
    expect(
      document.documentElement.classList.contains('theme-meridian_foundry'),
    ).toBe(true);
    expect(document.querySelector('.bg')).toBeNull();

    emit('state', { transparent: false });

    expect(document.querySelector('.lobby-title-art')).toBeTruthy();
    expect(
      document.querySelector<HTMLImageElement>('.lobby-title-art__fallback')
        ?.src,
    ).toContain('asset://title.png');
    expect(document.documentElement.style.getPropertyValue('--lobby-bg')).toBe(
      'black',
    );
  });

  it('keeps artwork comparisons window-local across state and phase updates', async () => {
    render(<LobbyMenu />);
    emit('init', makeServerState());

    const trigger = screen.getByRole('button', {
      name: /change lobby artwork/i,
    });
    fireEvent.click(trigger);
    fireEvent.click(
      screen.getByRole('menuitemradio', {
        name: /navarobl - d convex \+ bezel/i,
      }),
    );
    await act(async () => Promise.resolve());

    let artwork = document.querySelector('.lobby-title-art');
    expect(artwork?.getAttribute('data-texture')).toBe('navarobl');
    expect(artwork?.getAttribute('data-variant')).toBe('convex-bezel');

    fireEvent.click(trigger);
    fireEvent.click(
      screen.getByRole('menuitemcheckbox', { name: /classic alt/i }),
    );
    await act(async () => Promise.resolve());
    artwork = document.querySelector('.lobby-title-art');
    expect(artwork?.getAttribute('data-presentation')).toBe('classic-alt');

    emit('state', { gamePhase: 'pregame', playerCount: 9 });
    artwork = document.querySelector('.lobby-title-art');
    expect(artwork?.getAttribute('data-texture')).toBe('navarobl');
    expect(artwork?.getAttribute('data-variant')).toBe('convex-bezel');
    expect(artwork?.getAttribute('data-presentation')).toBe('classic-alt');
    expect(sendMessage).not.toHaveBeenCalled();

    emit('state', { transparent: true });
    expect(
      screen.queryByRole('button', { name: /change lobby artwork/i }),
    ).toBeNull();
    expect(document.querySelector('.lobby-title-art')).toBeNull();

    emit('state', { transparent: false });
    expect(
      screen.getByRole('button', { name: /change lobby artwork/i }),
    ).toBeTruthy();
    artwork = document.querySelector('.lobby-title-art');
    expect(artwork?.getAttribute('data-texture')).toBe('navarobl');
    expect(artwork?.getAttribute('data-variant')).toBe('convex-bezel');
    expect(artwork?.getAttribute('data-presentation')).toBe('classic-alt');
  });

  it('hides comparison controls for operator-provided artwork', () => {
    render(<LobbyMenu />);
    emit(
      'init',
      makeServerState({
        titleImageTreatment: null,
      }),
    );

    expect(
      screen.queryByRole('button', { name: /change lobby artwork/i }),
    ).toBeNull();
    expect(document.querySelector('.lobby-title-art')).toBeNull();
    expect(document.querySelector('.bg')?.getAttribute('src')).toBe(
      'asset://title.png',
    );
    expect(
      screen.getByRole('button', { name: /change base interface theme/i }),
    ).toBeTruthy();
  });

  it('uses Pip-Boy scanlines automatically but honors an explicit Original choice', async () => {
    render(<LobbyMenu />);
    emit(
      'init',
      makeServerState({
        meridianTheme: 'meridian_pipboy',
      }),
    );

    expect(
      document.querySelector('.lobby-title-art')?.getAttribute('data-texture'),
    ).toBe('navarobl');

    fireEvent.click(
      screen.getByRole('button', { name: /change lobby artwork/i }),
    );
    fireEvent.click(
      screen.getByRole('menuitemradio', { name: /original - c convex/i }),
    );
    await act(async () => Promise.resolve());

    expect(
      document.querySelector('.lobby-title-art')?.getAttribute('data-texture'),
    ).toBe('original');
    expect(sendMessage).not.toHaveBeenCalled();
  });

  it('resets the temporary comparison only when the lobby remounts', async () => {
    const view = render(<LobbyMenu />);
    emit('init', makeServerState());
    fireEvent.click(
      screen.getByRole('button', { name: /change lobby artwork/i }),
    );
    fireEvent.click(
      screen.getByRole('menuitemradio', { name: /navarobl - a flat/i }),
    );
    await act(async () => Promise.resolve());
    expect(
      document.querySelector('.lobby-title-art')?.getAttribute('data-variant'),
    ).toBe('flat');

    view.unmount();
    render(<LobbyMenu />);
    emit('init', makeServerState());

    const artwork = document.querySelector('.lobby-title-art');
    expect(artwork?.getAttribute('data-variant')).toBe('convex');
    expect(artwork?.getAttribute('data-texture')).toBe('original');
    expect(artwork?.getAttribute('data-presentation')).toBe('classic');
  });
});
