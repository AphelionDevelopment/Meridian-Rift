// THIS IS AN APHELION UI FILE
import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  jest,
  mock,
  spyOn,
} from 'bun:test';
import { act, render } from '@testing-library/react';
import { ByondUi } from 'tgui-core/components';
import { globalEvents } from 'tgui-core/events';

type TestRect = {
  bottom: number;
  height: number;
  left: number;
  right: number;
  top: number;
  width: number;
  x: number;
  y: number;
  toJSON: () => object;
};

const originalDevicePixelRatio = Object.getOwnPropertyDescriptor(
  window,
  'devicePixelRatio',
);
const originalSendMessage = Byond.sendMessage;
const originalWinset = Byond.winset;

let currentRect: TestRect;

function makeRect(left: number, top: number, width: number, height: number) {
  return {
    bottom: top + height,
    height,
    left,
    right: left + width,
    top,
    width,
    x: left,
    y: top,
    toJSON: () => ({}),
  } satisfies TestRect;
}

beforeEach(() => {
  jest.useFakeTimers();
  currentRect = makeRect(0, 0, 16, 16);
  Object.defineProperty(window, 'devicePixelRatio', {
    configurable: true,
    value: 1.5,
  });
  spyOn(HTMLElement.prototype, 'getBoundingClientRect').mockImplementation(
    () => currentRect as DOMRect,
  );
});

afterEach(() => {
  Byond.sendMessage = originalSendMessage;
  Byond.winset = originalWinset;
  if (originalDevicePixelRatio) {
    Object.defineProperty(
      window,
      'devicePixelRatio',
      originalDevicePixelRatio,
    );
  }
  jest.restoreAllMocks();
  jest.useRealTimers();
});

describe('ByondUi geometry lifecycle', () => {
  it('remeasures the final rectangle and device-pixel ratio after geometry', () => {
    const winset = mock((..._args: any[]) => {});
    Byond.winset = winset as typeof Byond.winset;

    const view = render(
      <ByondUi params={{ id: 'preferences_character_preview', type: 'map' }} />,
    );

    const renderCalls = () =>
      winset.mock.calls.filter(
        ([id, params]) =>
          id === 'preferences_character_preview' && params?.parent,
      );

    expect(renderCalls()).toHaveLength(1);
    expect(renderCalls()[0][1]).toMatchObject({
      pos: '0,0',
      size: '24x24',
    });

    currentRect = makeRect(12, 24, 96, 128);
    act(() => globalEvents.emit('window-geometry-finished'));
    act(() => jest.advanceTimersByTime(100));

    expect(renderCalls()).toHaveLength(2);
    expect(renderCalls()[1][1]).toMatchObject({
      pos: '18,36',
      size: '144x192',
    });

    view.unmount();
  });

  it('handles an event before mount, remounts, and unparents cleanly', () => {
    const winset = mock((..._args: any[]) => {});
    const sendMessage = mock((..._args: any[]) => {});
    Byond.winset = winset as typeof Byond.winset;
    Byond.sendMessage = sendMessage as typeof Byond.sendMessage;

    // An early geometry event must be harmless. ByondUi performs an immediate
    // measurement when it mounts specifically to cover this ordering.
    globalEvents.emit('window-geometry-finished');
    act(() => jest.advanceTimersByTime(100));

    currentRect = makeRect(4, 8, 64, 96);
    const first = render(
      <ByondUi params={{ id: 'preferences_character_preview', type: 'map' }} />,
    );
    expect(
      winset.mock.calls.filter(
        ([id, params]) =>
          id === 'preferences_character_preview' && params?.size === '96x144',
      ),
    ).toHaveLength(1);

    first.unmount();
    expect(winset).toHaveBeenCalledWith('preferences_character_preview', {
      parent: '',
    });
    expect(sendMessage).toHaveBeenCalledWith('unmountByondUi', {
      renderByondUi: 'preferences_character_preview',
    });

    const callCountAfterUnmount = winset.mock.calls.length;
    globalEvents.emit('window-geometry-finished');
    act(() => jest.advanceTimersByTime(100));
    expect(winset.mock.calls).toHaveLength(callCountAfterUnmount);

    currentRect = makeRect(10, 20, 96, 96);
    const second = render(
      <ByondUi params={{ id: 'preferences_character_preview', type: 'map' }} />,
    );
    expect(
      winset.mock.calls.filter(
        ([id, params]) =>
          id === 'preferences_character_preview' &&
          params?.pos === '15,30' &&
          params?.size === '144x144',
      ),
    ).toHaveLength(1);

    second.unmount();
  });
});
