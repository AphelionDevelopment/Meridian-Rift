import { afterEach, describe, expect, it, mock } from 'bun:test';
import { cleanup, fireEvent, render } from '@testing-library/react';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import {
  AugmentsRegionSelector,
  getAugmentsPreviewCallouts,
} from './AugmentsWorkbench';

afterEach(cleanup);

const workbenchSource = readFileSync(
  resolve(import.meta.dir, 'AugmentsWorkbench.tsx'),
  'utf8',
);
const workbenchStyles = readFileSync(
  resolve(import.meta.dir, '../../../styles/interfaces/LimbsPage.scss'),
  'utf8',
);

describe('Augments anatomical workbench', () => {
  it('uses real button semantics and sends the stable region id', () => {
    const onSelect = mock(() => {});
    const view = render(
      <AugmentsRegionSelector
        callout={{
          edge: 15,
          region: 'eyes',
          side: 'left',
          target: { x: 48, y: 23 },
        }}
        item={{
          label: 'Eyes',
          region: 'eyes',
          summary: 'Diagnostic HUD',
        }}
        onSelect={onSelect}
        selected
      />,
    );

    const selector = view.getByRole('button', { name: /eyes/i });
    expect(selector.getAttribute('aria-controls')).toBe(
      'augments-region-editor',
    );
    expect(selector.getAttribute('aria-pressed')).toBe('true');
    expect(selector.textContent).toContain('Diagnostic HUD');

    fireEvent.click(selector);
    expect(onSelect).toHaveBeenCalledWith('eyes');
  });

  it('changes native callout coverage with the active tab', () => {
    const markings = getAugmentsPreviewCallouts('augmentation_markings');
    const bodyParts = getAugmentsPreviewCallouts('augmentation_body_parts');
    const implants = getAugmentsPreviewCallouts('augmentation_implants');

    expect(markings.map((callout) => callout.region)).toContain('l_hand');
    expect(bodyParts.map((callout) => callout.region)).toEqual(
      markings.map((callout) => callout.region),
    );
    expect(implants.map((callout) => callout.region)).toContain('eyes');
    expect(implants.map((callout) => callout.region)).toContain('brain');
    expect(implants.map((callout) => callout.region)).not.toContain('l_hand');
  });

  it('keeps browser leaders attached to the native map edge while reflowing', () => {
    expect(workbenchStyles).toMatch(/&--left\s*\{\s*right:\s*10px;/);
    expect(workbenchStyles).toMatch(/&--right\s*\{\s*left:\s*10px;/);
    expect(workbenchStyles).toContain('@media (max-width: 720px)');
    expect(workbenchStyles).toContain('grid-template-columns: minmax(0, 1fr);');
    expect(workbenchStyles).toContain(
      'width: min(400px, calc(100vw - 24px));',
    );
    expect(workbenchStyles).toContain('@media (forced-colors: active)');
    expect(workbenchStyles).toContain('border-image: none;');
    expect(workbenchStyles).not.toContain('forced-color-adjust: none;');
    expect(workbenchSource).not.toMatch(/ResizeObserver|requestAnimationFrame/);
  });
});
