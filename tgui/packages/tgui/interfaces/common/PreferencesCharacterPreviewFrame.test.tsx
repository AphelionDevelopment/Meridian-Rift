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
  it('renders pointer-transparent Markings chrome without resizing its child contract', () => {
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
    expect(
      chrome.querySelectorAll('.PreferencesCharacterPreviewFrame__datum'),
    ).toHaveLength(2);
    expect(
      chrome.querySelectorAll('.PreferencesCharacterPreviewFrame__leader'),
    ).toHaveLength(2);
    expect(
      chrome.querySelectorAll('.PreferencesCharacterPreviewFrame__orientation'),
    ).toHaveLength(2);
    expect(view.getByText('MARKINGS')).toBeDefined();
    expect(view.getByText('REGION MAP')).toBeDefined();
  });

  it('gives Augmentation its stronger identity and supports bounded label overrides', () => {
    const view = render(
      <PreferencesCharacterPreviewFrame
        decoration="augmentation_implants"
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
    expect(frame.classList).toContain(
      'PreferencesCharacterPreviewFrame--augmentation_implants',
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
    }) => {
      usePreferencesCharacterPreviewDecoration(act, props.mode);
      return null;
    };
    const view = render(<Harness mode="augmentation_markings" />);

    expect(calls).toEqual([
      {
        action: 'set_preview_decoration',
        payload: { mode: 'augmentation_markings' },
      },
    ]);

    view.rerender(<Harness mode="augmentation_body_parts" />);
    expect(calls).toEqual([
      {
        action: 'set_preview_decoration',
        payload: { mode: 'augmentation_markings' },
      },
      {
        action: 'set_preview_decoration',
        payload: { mode: 'augmentation_body_parts' },
      },
    ]);

    view.unmount();
    expect(calls.at(-1)).toEqual({
      action: 'set_preview_decoration',
      payload: { mode: 'none' },
    });
  });
});
