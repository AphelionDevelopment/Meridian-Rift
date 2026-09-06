// THIS IS AN APHELION UI FILE
import { afterAll, afterEach, beforeAll, describe, expect, it } from 'bun:test';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { cleanup, render } from '@testing-library/react';
import type { CSSProperties } from 'react';
import { compileAsync } from 'sass-embedded';
import { Button, Input, Section, Tabs, TextArea } from 'tgui-core/components';

let productionStyle: HTMLStyleElement;
let previousRootClasses: string;

beforeAll(async () => {
  const nodeModules = join(import.meta.dir, '../../../../node_modules');
  const { css } = await compileAsync(join(import.meta.dir, '../main.scss'), {
    importers: [
      {
        findFileUrl(url) {
          if (!url.startsWith('~')) {
            return null;
          }
          return pathToFileURL(
            join(
              nodeModules,
              url === '~tgui-core/styles'
                ? 'tgui-core/styles/main.scss'
                : url.slice(1),
            ),
          );
        },
      },
    ],
  });
  productionStyle = document.createElement('style');
  productionStyle.textContent = css;
  document.head.appendChild(productionStyle);
  previousRootClasses = document.documentElement.className;
});

afterEach(() => {
  cleanup();
  document.documentElement.className = previousRootClasses;
});

afterAll(() => productionStyle.remove());

function fixture(theme = 'meridian_bastion', fitted = false) {
  document.documentElement.className = `theme-console theme-${theme}`;
  const content = (
    <>
      <Tabs>
        <Tabs.Tab selected>Character</Tabs.Tab>
        <Tabs.Tab>Settings</Tabs.Tab>
      </Tabs>
      <div className="PreferencesMenu__profiles">
        <Button>Profile</Button>
      </div>
      <div className="PreferencesMenu__settings">
        <div style={{ backgroundColor: 'rgba(0, 0, 0, 0.5)' }}>
          Settings data
        </div>
      </div>
      <Section title="Character data">
        <Input value="Name" />
        <TextArea value="Description" />
        <Button>Save character</Button>
        <Section title="Nested data">Details</Section>
      </Section>
      <Section
        title="Caller-colored title"
        style={
          { '--section-title-background': 'rgb(12, 34, 56)' } as CSSProperties
        }
      >
        Caller-owned content
      </Section>
    </>
  );
  // Window shell classes match Window.tsx; the components inside it are real.
  // Avoid mounting BYOND window-position effects for a stylesheet contract.
  return render(
    <div className="Window">
      <div className="TitleBar">Preferences</div>
      <div className="Window__rest">
        <div className="Window__content">
          {fitted ? (
            content
          ) : (
            <div className="Window__contentPadding">{content}</div>
          )}
        </div>
      </div>
    </div>,
  );
}

function pixels(value: string): number {
  // happy-dom substitutes custom properties but does not evaluate calc().
  const plain = value.match(/^([\d.]+)px$/);
  if (plain) {
    return Number(plain[1]);
  }
  const sum = value.match(/^calc\(\s*([\d.]+)px\s*\+\s*([\d.]+)px\s*\)$/);
  if (!sum) {
    throw new Error(`Expected a pixel length or simple pixel sum: ${value}`);
  }
  return Number(sum[1]) + Number(sum[2]);
}

describe('Bastion casing and reading surfaces', () => {
  it('uses one frame at the real window edges', () => {
    const { container } = fixture();
    expect(
      getComputedStyle(container.querySelector('.Window')!).boxShadow,
    ).toBe('none');
    expect(
      getComputedStyle(document.documentElement)
        .getPropertyValue('--console-frame-gap')
        .trim(),
    ).toBe('0px');
  });

  for (const fitted of [false, true]) {
    it(`reserves the casing outside ${fitted ? 'fitted' : 'padded'} content`, () => {
      const { container } = fixture('meridian_bastion', fitted);
      const rest = getComputedStyle(container.querySelector('.Window__rest')!);
      for (const edge of ['left', 'right', 'bottom'] as const) {
        expect(pixels(rest[edge]), `${edge} content clearance`).toBe(4);
      }
    });
  }

  it('textures the casing while keeping data panels and inputs clear', () => {
    const { container } = fixture();
    for (const selector of [
      '.Window',
      '.TitleBar',
      '.Tabs',
      '.PreferencesMenu__profiles',
    ]) {
      expect(
        getComputedStyle(container.querySelector(selector)!).backgroundImage,
        `${selector} material`,
      ).toContain('bastion-rust.jpg');
    }
    for (const element of container.querySelectorAll(
      '.Section, .Input, .TextArea, .Button',
    )) {
      expect(
        getComputedStyle(element).backgroundImage,
        `${element.className} reading surface`,
      ).not.toContain('url(');
    }
    const nestedTitle = container.querySelector(
      '.Section .Section > .Section__title',
    )!;
    expect(getComputedStyle(nestedTitle).backgroundImage).not.toContain('url(');
  });

  it('retains the caller title-background opt-out in production CSS', () => {
    const { getByText } = fixture();
    const title = getByText('Caller-colored title').closest('.Section__title')!;
    // happy-dom drops background shorthands with nested custom-property
    // fallbacks. Check the compiled opt-out declaration against the real
    // Section DOM; its rendered color still requires browser verification.
    const titleRules = [
      ...productionStyle.textContent!.matchAll(/([^{}]+)\{([^{}]*)\}/g),
    ].filter(
      ([, selector]) =>
        selector.includes('.theme-meridian_bastion') &&
        title.matches(selector.trim()),
    );
    expect(
      titleRules.some(([, , body]) =>
        /background(?:-image)?:\s*var\(--section-title-background,/.test(body),
      ),
    ).toBe(true);
  });

  it('backs translucent settings content with an opaque reading surface', () => {
    const { container } = fixture();
    const settings = getComputedStyle(
      container.querySelector('.PreferencesMenu__settings')!,
    );
    expect(settings.backgroundImage).not.toContain('url(');
    expect(settings.backgroundColor).toMatch(
      /^(#[0-9a-f]{6}|rgb\([\d, ]+\))$/i,
    );
  });

  it('keeps the Standard window and title bar free of Bastion materials', () => {
    const { container } = fixture('meridian');
    const windowStyle = getComputedStyle(container.querySelector('.Window')!);
    expect(windowStyle.boxShadow).not.toBe('none');
    for (const selector of ['.Window', '.TitleBar']) {
      expect(
        getComputedStyle(container.querySelector(selector)!).backgroundImage,
      ).not.toContain('bastion-rust.jpg');
    }
  });
});
