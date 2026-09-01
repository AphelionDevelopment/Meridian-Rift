import { afterEach, describe, expect, it } from 'bun:test';
import { cleanup, render } from '@testing-library/react';
import {
  isPreferencesCharacterPreviewDecorationMode,
  normalizePreferencesCharacterPreviewDecorationMode,
  PreferencesCharacterPreviewFrame,
  usePreferencesCharacterPreviewDecoration,
} from './PreferencesCharacterPreviewFrame';

afterEach(cleanup);

describe('PreferencesCharacterPreviewFrame', () => {
  it('renders text-free Markings chrome without resizing its child contract', () => {
    const view = render(
      <PreferencesCharacterPreviewFrame
        decoration="augmentation_markings"
        height="100%"
        width="272px"
      >
        <div data-testid="native-map" />
      </PreferencesCharacterPreviewFrame>,
    );
    const frame = view.getByTestId('native-map').parentElement!;
    const chrome = frame.querySelector(
      '.PreferencesCharacterPreviewFrame__chrome',
    )!;

    expect(frame.dataset.decorationMode).toBe('augmentation_markings');
    expect(frame.style.width).toBe('272px');
    expect(frame.style.height).toBe('100%');
    expect(chrome.getAttribute('aria-hidden')).toBe('true');
    expect(
      chrome.querySelectorAll('.PreferencesCharacterPreviewFrame__corner'),
    ).toHaveLength(4);
    expect(chrome.textContent).toBe('');
    expect(
      chrome.querySelector('.PreferencesCharacterPreviewFrame__rail'),
    ).toBeNull();
    expect(
      chrome.querySelector('.PreferencesCharacterPreviewFrame__leader'),
    ).toBeNull();
  });

  it('gives every finite Augments mode its stronger identity', () => {
    const view = render(
      <PreferencesCharacterPreviewFrame
        decoration="augmentation_implants"
        height="96px"
        width="96px"
      >
        <div data-testid="native-map" />
      </PreferencesCharacterPreviewFrame>,
    );
    const frame = view.getByTestId('native-map').parentElement!;

    expect(frame.classList).toContain(
      'PreferencesCharacterPreviewFrame--augmentation',
    );
    expect(frame.classList).toContain(
      'PreferencesCharacterPreviewFrame--augmentation_implants',
    );
    expect(frame.textContent).toBe('');
  });

  it('keeps none free of ornamental DOM', () => {
    const view = render(
      <PreferencesCharacterPreviewFrame
        decoration="none"
        height="1px"
        width="1px"
      >
        <div data-testid="native-map" />
      </PreferencesCharacterPreviewFrame>,
    );
    const frame = view.getByTestId('native-map').parentElement!;

    expect(frame.dataset.decorationMode).toBe('none');
    expect(
      frame.querySelector('.PreferencesCharacterPreviewFrame__chrome'),
    ).toBeNull();
  });

  it('validates the finite native action contract', () => {
    expect(isPreferencesCharacterPreviewDecorationMode('none')).toBe(true);
    expect(
      isPreferencesCharacterPreviewDecorationMode('augmentation_markings'),
    ).toBe(true);
    expect(
      isPreferencesCharacterPreviewDecorationMode('augmentation_body_parts'),
    ).toBe(true);
    expect(
      isPreferencesCharacterPreviewDecorationMode('augmentation_implants'),
    ).toBe(true);
    expect(isPreferencesCharacterPreviewDecorationMode('standard')).toBe(false);
    expect(isPreferencesCharacterPreviewDecorationMode('augmentation')).toBe(
      false,
    );
    expect(isPreferencesCharacterPreviewDecorationMode('diagnostic')).toBe(
      false,
    );
    expect(
      normalizePreferencesCharacterPreviewDecorationMode('diagnostic'),
    ).toBe('none');
  });

  it('orders mode updates without page-cleanup races and clears on owner teardown', () => {
    const calls: Array<{
      action: string;
      payload: Record<string, unknown>;
    }> = [];
    const act = (action: string, payload: Record<string, unknown> = {}) => {
      calls.push({ action, payload });
    };
    const Harness = (props: {
      mode:
        | 'none'
        | 'augmentation_markings'
        | 'augmentation_body_parts'
        | 'augmentation_implants';
      region: string | null;
    }) => {
      usePreferencesCharacterPreviewDecoration(act, props.mode, props.region);
      return null;
    };
    const view = render(<Harness mode="augmentation_markings" region="head" />);

    expect(calls).toEqual([
      {
        action: 'set_preview_decoration',
        payload: { mode: 'augmentation_markings', region: 'head' },
      },
    ]);

    view.rerender(<Harness mode="augmentation_markings" region="chest" />);
    expect(calls).toEqual([
      {
        action: 'set_preview_decoration',
        payload: { mode: 'augmentation_markings', region: 'head' },
      },
      {
        action: 'set_preview_decoration',
        payload: { mode: 'augmentation_markings', region: 'chest' },
      },
    ]);

    view.rerender(<Harness mode="augmentation_body_parts" region="l_arm" />);
    expect(calls.at(-1)).toEqual({
      action: 'set_preview_decoration',
      payload: { mode: 'augmentation_body_parts', region: 'l_arm' },
    });

    view.unmount();
    expect(calls.at(-1)).toEqual({
      action: 'set_preview_decoration',
      payload: { mode: 'none', region: null },
    });
  });
});
