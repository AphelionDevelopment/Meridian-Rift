import { afterAll, afterEach, beforeAll, describe, expect, it } from 'bun:test';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { cleanup, render } from '@testing-library/react';
import { compileAsync } from 'sass-embedded';
import { Button } from 'tgui-core/components';

import {
  MERIDIAN_THEME_IDS,
  resolveMeridianTheme,
} from '../../constants/theme';

const COMPONENT_SOURCE = readFileSync(
  join(import.meta.dir, '_components.scss'),
  'utf8',
);
const DECORATION_SOURCE = readFileSync(
  join(import.meta.dir, '_decoration.scss'),
  'utf8',
);
const THEME_SOURCE = readFileSync(
  join(import.meta.dir, '_themes.scss'),
  'utf8',
);
const CHECKED_ARIA = {
  'aria-checked': true,
  role: 'checkbox',
} as const;
const UNCHECKED_ARIA = {
  'aria-checked': false,
  role: 'checkbox',
} as const;

let productionStyle: HTMLStyleElement;

beforeAll(async () => {
  const [themeCss, componentCss, decorationCss] = await Promise.all(
    ['_themes.scss', '_components.scss', '_decoration.scss'].map(
      async (file) => (await compileAsync(join(import.meta.dir, file))).css,
    ),
  );
  productionStyle = document.createElement('style');
  // happy-dom does not resolve custom properties in background shorthands.
  // Substitute two sentinel colors so the real compiled selectors and import
  // order can still prove that Highline's inverse state wins the cascade.
  productionStyle.textContent = (themeCss + componentCss + decorationCss)
    .replaceAll('var(--console-interaction-pressed)', 'rgb(1, 2, 3)')
    .replaceAll('var(--console-text-primary)', 'rgb(255, 255, 255)');
  document.head.appendChild(productionStyle);
});

afterEach(cleanup);

afterAll(() => productionStyle.remove());

describe('MeridianOS shared control geometry', () => {
  it('uses one theme-console contract for every MeridianOS skin', () => {
    expect(COMPONENT_SOURCE.trimStart().startsWith('.theme-console {')).toBe(
      true,
    );

    for (const theme of MERIDIAN_THEME_IDS) {
      expect(resolveMeridianTheme(theme).classes).toContain('theme-console');

      const view = render(
        <div className={`theme-console theme-${theme}`}>
          <Button aria-label="Icon only" icon="rotate" />
          <Button aria-label="Short inline height" height="20px">
            Short
          </Button>
          <Button aria-label="Compact icon" compact icon="rotate" />
          <Button
            aria-label="Dense job priority"
            className="PreferencesMenu__Jobs__departments__priority"
          />
          <Button.Checkbox {...CHECKED_ARIA} checked>
            Checked
          </Button.Checkbox>
          <Button.Checkbox {...UNCHECKED_ARIA} checked={false}>
            Unchecked
          </Button.Checkbox>
          <input aria-label="Selected radio" defaultChecked type="radio" />
          <input aria-label="Disabled checkbox" disabled type="checkbox" />
          <div aria-selected="true" className="Tab Tab--selected">
            <span className="Tab__left">L</span>
            <span className="Tab__text">Selected tab</span>
            <span className="Tab__right">R</span>
          </div>
          <div className="Dropdown">
            <div className="Dropdown__control">
              <span className="Dropdown__selected-text">Aligned option</span>
              <span className="Dropdown__icon">V</span>
            </div>
          </div>
        </div>,
      );

      const fixture = view.container.firstElementChild as HTMLElement;
      const iconOnly = view.getByLabelText('Icon only');
      const compact = view.getByLabelText('Compact icon');
      const denseJobPriority = view.getByLabelText('Dense job priority');
      const shortInlineHeight = view.getByLabelText('Short inline height');
      const checked = view.getByRole('checkbox', { name: 'Checked' });
      const unchecked = view.getByRole('checkbox', { name: 'Unchecked' });
      const selectedRadio = view.getByLabelText('Selected radio');
      const disabledCheckbox = view.getByLabelText('Disabled checkbox');
      const selectedTab = view.getByText('Selected tab').closest(
        '.Tab',
      ) as HTMLElement;
      const dropdownControl = view.getByText('Aligned option').parentElement!;
      const iconContent = iconOnly.querySelector(
        '.Button__content',
      ) as HTMLElement;
      const checkedGlyph = checked.querySelector(
        '.fa-check-square',
      ) as HTMLElement;

      expect(
        getComputedStyle(fixture).getPropertyValue('--button-height').trim(),
        `${theme}: normal control height`,
      ).toBe('22px');
      expect(getComputedStyle(iconContent).display).toBe('flex');
      expect(getComputedStyle(iconContent).alignItems).toBe('center');
      expect(getComputedStyle(iconOnly).minWidth).toBe('24px');
      expect(getComputedStyle(iconOnly).minHeight).toBe('24px');
      expect(getComputedStyle(shortInlineHeight).minHeight).toBe('24px');
      expect(getComputedStyle(compact).minWidth).not.toBe('24px');
      expect(getComputedStyle(compact).minHeight).not.toBe('24px');
      expect(getComputedStyle(denseJobPriority).minHeight).not.toBe('24px');

      expect(checked.classList).toContain('Button--selected');
      expect(checked.getAttribute('aria-checked')).toBe('true');
      expect(checkedGlyph).not.toBeNull();
      expect(getComputedStyle(checkedGlyph).display).toBe('inline-flex');
      expect(getComputedStyle(checkedGlyph).overflow).toBe('visible');
      expect(unchecked.classList).not.toContain('Button--selected');
      expect(unchecked.getAttribute('aria-checked')).toBe('false');
      expect(unchecked.querySelector('.fa-square')).not.toBeNull();

      expect(getComputedStyle(selectedRadio).width).toBe('16px');
      expect(getComputedStyle(selectedRadio).height).toBe('16px');
      expect(getComputedStyle(disabledCheckbox).opacity).toBe(
        theme === 'meridian_highline' ? '1' : '0.58',
      );
      expect(getComputedStyle(dropdownControl).height).toBe('24px');
      expect(getComputedStyle(selectedTab.querySelector('.Tab__left')!).display)
        .toBe('inline-flex');

      if (theme === 'meridian_highline') {
        expect(getComputedStyle(selectedTab).backgroundColor).toBe(
          'rgb(255, 255, 255)',
        );
      }

      cleanup();
    }
  });

  it('keeps compact sizing out of individual skin decoration', () => {
    for (const source of [DECORATION_SOURCE, THEME_SOURCE]) {
      expect(source).not.toContain('.Button--compact');
      expect(source).not.toContain('--button-height');
    }

    const artworkIndex = DECORATION_SOURCE.indexOf(
      'meridian-cyberpunk-control-frame.svg',
    );
    const cyberpunkControlRule = DECORATION_SOURCE.slice(
      artworkIndex - 320,
      artworkIndex + 240,
    );
    expect(artworkIndex).toBeGreaterThan(0);
    expect(cyberpunkControlRule).toContain('border: 1px solid transparent');
    expect(cyberpunkControlRule).toContain('border-image-width: 2px');
    expect(COMPONENT_SOURCE).toContain(
      ".Tab:where(.Tab--selected, [aria-selected='true'])",
    );
  });
});
