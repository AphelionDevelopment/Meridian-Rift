import { afterEach, beforeEach, describe, expect, it, mock } from 'bun:test';
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from '@testing-library/react';
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
});

afterEach(() => {
  cleanup();
  Byond.sendMessage = originalSendMessage;
  Byond.subscribeTo = originalSubscribeTo;
  window.requestAnimationFrame = originalRequestAnimationFrame;
  window.cancelAnimationFrame = originalCancelAnimationFrame;
  document.documentElement.classList.remove('runtime-marker');
  document.documentElement.style.removeProperty('--lobby-bg');
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

    expect(document.querySelector<HTMLImageElement>('.bg')?.src).toContain(
      'asset://title.png',
    );
    expect(document.documentElement.style.getPropertyValue('--lobby-bg')).toBe(
      'black',
    );
  });
});
