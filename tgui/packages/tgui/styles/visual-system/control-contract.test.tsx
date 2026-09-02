// THIS IS AN APHELION UI FILE
import { afterAll, afterEach, beforeAll, describe, expect, it } from 'bun:test';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import type { CSSProperties } from 'react';
import { cleanup, render } from '@testing-library/react';
import { compileAsync } from 'sass-embedded';
import { Button, Icon, Stack, Tabs } from 'tgui-core/components';

import {
  MERIDIAN_THEME_IDS,
  resolveMeridianTheme,
} from '../../constants/theme';
import { LOADOUT_CATEGORY_TABS_CLASS } from '../../interfaces/PreferencesMenu/CharacterPreferences/loadout';

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
  const [
    controlsCss,
    tabsCss,
    themeCss,
    componentCss,
    decorationCss,
    preferencesCss,
  ] = await Promise.all(
    [
      // Dropdown @uses Button, so this entry includes both legacy margin
      // contracts in the same order as production core styles.
      '../../../../node_modules/tgui-core/styles/components/Dropdown.scss',
      '../../../../node_modules/tgui-core/styles/components/Tabs.scss',
      '_themes.scss',
      '_components.scss',
      '_decoration.scss',
      '../interfaces/PreferencesMenu.scss',
    ].map(
      async (file) => (await compileAsync(join(import.meta.dir, file))).css,
    ),
  );
  productionStyle = document.createElement('style');
  // happy-dom does not resolve custom properties in background shorthands.
  // Substitute two sentinel colors so the real compiled selectors and import
  // order can still prove that Highline's inverse state wins the cascade.
  productionStyle.textContent = (
    controlsCss +
    tabsCss +
    themeCss +
    componentCss +
    decorationCss +
    preferencesCss
  )
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
      expect(resolveMeridianTheme({ requested: theme }).classes).toContain(
        'theme-console',
      );

      const view = render(
        <div
          className={`theme-console theme-${theme}`}
          style={
            {
              '--space-xs': '2px',
              '--tab-indicator-size': '3px',
            } as CSSProperties
          }
        >
          <Button aria-label="Ungrouped legacy button">Ungrouped</Button>
          <div className="MeridianShowcase__switcherControls">
            <Button aria-label="Switcher inherit" icon="undo" selected>
              Inherit
            </Button>
            <Button aria-label="Icon only" icon="rotate" />
            <div className="Dropdown">
              <div className="Dropdown__control">
                <span className="Dropdown__selected-text">Aligned option</span>
                <span className="Dropdown__icon">V</span>
              </div>
            </div>
          </div>
          <Stack className="LimbsPage__rotationControls">
            <Stack.Item>
              <Button aria-label="Rotate preview clockwise" icon="redo" />
            </Stack.Item>
            <Stack.Item>
              <Button
                aria-label="Rotate preview counter-clockwise"
                icon="undo"
              />
            </Stack.Item>
          </Stack>
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
          <div className="Section__buttons">
            <div className="Dropdown">
              <div className="Dropdown__control">
                <span className="Dropdown__selected-text">Section option</span>
                <span className="Dropdown__icon">V</span>
              </div>
            </div>
            <Button aria-label="Section action">Apply</Button>
          </div>
          <Tabs className={LOADOUT_CATEGORY_TABS_CLASS} fluid>
            <Tabs.Tab selected>
              <span>
                <Icon name="hat-cowboy" />
                <br />
                Head
              </span>
            </Tabs.Tab>
          </Tabs>
        </div>,
      );

      const fixture = view.container.firstElementChild as HTMLElement;
      const ungroupedButton = view.getByLabelText('Ungrouped legacy button');
      const switcherInherit = view.getByLabelText('Switcher inherit');
      const iconOnly = view.getByLabelText('Icon only');
      const rotateClockwise = view.getByLabelText('Rotate preview clockwise');
      const rotateCounterClockwise = view.getByLabelText(
        'Rotate preview counter-clockwise',
      );
      const compact = view.getByLabelText('Compact icon');
      const denseJobPriority = view.getByLabelText('Dense job priority');
      const shortInlineHeight = view.getByLabelText('Short inline height');
      const checked = view.getByRole('checkbox', { name: 'Checked' });
      const unchecked = view.getByRole('checkbox', { name: 'Unchecked' });
      const selectedRadio = view.getByLabelText('Selected radio');
      const disabledCheckbox = view.getByLabelText('Disabled checkbox');
      const selectedTab = view
        .getByText('Selected tab')
        .closest('.Tab') as HTMLElement;
      const dropdownControl = view.getByText('Aligned option').parentElement!;
      const switcherDropdown = dropdownControl.closest('.Dropdown')!;
      const sectionDropdownControl =
        view.getByText('Section option').parentElement!;
      const sectionDropdown = sectionDropdownControl.closest('.Dropdown')!;
      const sectionAction = view.getByLabelText('Section action');
      const sectionButtons = sectionAction.parentElement!;
      const loadoutCategoryTab = view
        .getByText('Head')
        .closest('.Tab') as HTMLElement;
      const iconContent = iconOnly.querySelector(
        '.Button__content',
      ) as HTMLElement;
      const compactContent = compact.querySelector(
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
      expect(getComputedStyle(iconContent).minHeight).toBe('22px');
      expect(getComputedStyle(compactContent).minHeight).not.toBe('22px');
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
      expect(getComputedStyle(sectionDropdownControl).height).toBe('24px');
      expect(getComputedStyle(sectionButtons).gap).toBe('2px');

      expect(getComputedStyle(ungroupedButton).marginRight).toBe('2px');
      expect(getComputedStyle(ungroupedButton).marginBottom).toBe('2px');
      for (const groupedControl of [
        switcherInherit,
        iconOnly,
        rotateClockwise,
        rotateCounterClockwise,
        switcherDropdown,
        sectionDropdown,
        sectionAction,
      ]) {
        expect(getComputedStyle(groupedControl).marginRight).toBe('0px');
        expect(getComputedStyle(groupedControl).marginBottom).toBe('0px');
      }
      expect(rotateClockwise.parentElement?.classList).toContain('Stack__item');
      expect(rotateCounterClockwise.parentElement?.classList).toContain(
        'Stack__item',
      );
      expect(getComputedStyle(rotateClockwise).minHeight).toBe(
        getComputedStyle(rotateCounterClockwise).minHeight,
      );
      for (const rotateControl of [rotateClockwise, rotateCounterClockwise]) {
        expect(getComputedStyle(rotateControl).marginTop).toBe('0px');
        expect(getComputedStyle(rotateControl).marginLeft).toBe('0px');
      }

      expect(getComputedStyle(loadoutCategoryTab).paddingTop).toBe('3px');
      expect(getComputedStyle(loadoutCategoryTab).paddingBottom).toBe('3px');
      expect(
        getComputedStyle(selectedTab.querySelector('.Tab__left')!).display,
      ).toBe('inline-flex');

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

  it('keeps skin paint off caller-styled section headers', () => {
    // tgui-core deliberately gives .Section__title no background, which is
    // what lets a caller colour a whole section and have the header inherit
    // it. StyleableSection reuses these class names under a caller-styled
    // root that carries no `.Section` class, so an unscoped paint rule here
    // covers the caller's colour while the caller's own text colour survives
    // -- that is how JobSelection's department headers went dark-on-dark.
    // Skin paint therefore has to be scoped to a real Section.
    const headerRule =
      /([^\n{}]*\.Section__title(?:Text)?\b[^\n{}]*?)\{([^{}]*)\}/g;
    const paints = /(^|[\s;])(background|color)[-a-z]*\s*:/;
    const offenders: string[] = [];

    for (const [label, source] of [
      ['_components.scss', COMPONENT_SOURCE],
      ['_decoration.scss', DECORATION_SOURCE],
    ] as const) {
      for (const [, selector, body] of source.matchAll(headerRule)) {
        if (!paints.test(body) || selector.includes('.Section >')) {
          continue;
        }
        offenders.push(`${label}: ${selector.trim()}`);
      }
    }

    expect(offenders).toEqual([]);
  });
});
