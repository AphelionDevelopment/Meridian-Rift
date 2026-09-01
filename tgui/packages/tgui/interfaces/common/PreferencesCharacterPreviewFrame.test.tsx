import { afterEach, describe, expect, it } from 'bun:test';
import { cleanup, render } from '@testing-library/react';
import {
  isPreferencesCharacterPreviewDecorationMode,
  normalizePreferencesCharacterPreviewDecorationMode,
  PreferencesCharacterPreviewFrame,
  resolvePreferencesCharacterPreviewDecoration,
  usePreferencesCharacterPreviewDecoration,
} from './PreferencesCharacterPreviewFrame';

afterEach(cleanup);

describe('PreferencesCharacterPreviewFrame', () => {
  it('renders pointer-transparent Standard exterior chrome without resizing its child contract', () => {
    const view = render(
      <PreferencesCharacterPreviewFrame
        decoration="standard"
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

    expect(frame.dataset.decorationMode).toBe('standard');
    expect(frame.style.width).toBe('272px');
    expect(frame.style.height).toBe('100%');
    expect(chrome.getAttribute('aria-hidden')).toBe('true');
    expect(
      chrome.querySelectorAll('.PreferencesCharacterPreviewFrame__corner'),
    ).toHaveLength(4);
    expect(
      chrome.querySelectorAll('.PreferencesCharacterPreviewFrame__datum'),
    ).toHaveLength(2);
    expect(
      chrome.querySelectorAll('.PreferencesCharacterPreviewFrame__leader'),
    ).toHaveLength(2);
    expect(
      chrome.querySelectorAll(
        '.PreferencesCharacterPreviewFrame__orientation',
      ),
    ).toHaveLength(2);
    expect(view.getByText('CHARACTER')).toBeDefined();
    expect(view.getByText('LINK ACTIVE')).toBeDefined();
  });

  it('gives Augmentation its stronger identity and supports bounded label overrides', () => {
    const view = render(
      <PreferencesCharacterPreviewFrame
        decoration="augmentation"
        height="96px"
        status="CALIBRATED"
        title="MODULE MAP"
        width="96px"
      >
        <div data-testid="native-map" />
      </PreferencesCharacterPreviewFrame>,
    );
    const frame = view.getByTestId('native-map').parentElement!;

    expect(frame.classList).toContain(
      'PreferencesCharacterPreviewFrame--augmentation',
    );
    expect(view.getByText('MODULE MAP')).toBeDefined();
    expect(view.getByText('CALIBRATED')).toBeDefined();
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
    expect(isPreferencesCharacterPreviewDecorationMode('standard')).toBe(true);
    expect(isPreferencesCharacterPreviewDecorationMode('augmentation')).toBe(
      true,
    );
    expect(isPreferencesCharacterPreviewDecorationMode('diagnostic')).toBe(
      false,
    );
    expect(normalizePreferencesCharacterPreviewDecorationMode('diagnostic')).toBe(
      'none',
    );
  });

  it('resolves only visible Augments under the Augmentation debug skin', () => {
    expect(
      resolvePreferencesCharacterPreviewDecoration({
        hasVisiblePreview: true,
        isAugmentsPage: true,
        resolvedTheme: 'meridian_augmentation',
      }),
    ).toBe('augmentation');
    expect(
      resolvePreferencesCharacterPreviewDecoration({
        hasVisiblePreview: true,
        isAugmentsPage: false,
        resolvedTheme: 'meridian_augmentation',
      }),
    ).toBe('standard');
    expect(
      resolvePreferencesCharacterPreviewDecoration({
        hasVisiblePreview: true,
        isAugmentsPage: true,
        resolvedTheme: 'meridian_vector',
      }),
    ).toBe('standard');
    expect(
      resolvePreferencesCharacterPreviewDecoration({
        hasVisiblePreview: false,
        isAugmentsPage: false,
        resolvedTheme: 'meridian',
      }),
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
      mode: 'none' | 'standard' | 'augmentation';
    }) => {
      usePreferencesCharacterPreviewDecoration(act, props.mode);
      return null;
    };
    const view = render(<Harness mode="standard" />);

    expect(calls).toEqual([
      { action: 'set_preview_decoration', payload: { mode: 'standard' } },
    ]);

    view.rerender(<Harness mode="augmentation" />);
    expect(calls).toEqual([
      { action: 'set_preview_decoration', payload: { mode: 'standard' } },
      { action: 'set_preview_decoration', payload: { mode: 'augmentation' } },
    ]);

    view.unmount();
    expect(calls.at(-1)).toEqual({
      action: 'set_preview_decoration',
      payload: { mode: 'none' },
    });
  });
});
