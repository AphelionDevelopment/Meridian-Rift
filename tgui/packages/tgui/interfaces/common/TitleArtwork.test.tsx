// THIS IS AN APHELION UI FILE
import { afterEach, describe, expect, it } from 'bun:test';
import { cleanup, render } from '@testing-library/react';
import {
  DEFAULT_LOBBY_TITLE_ART_VARIANT,
  DEFAULT_LOBBY_TITLE_BEZEL,
  DEFAULT_LOBBY_TITLE_PRESENTATION,
  DEFAULT_LOBBY_TITLE_TEXTURE,
  resolveLobbyTitleArtVariant,
  resolveLobbyTitleBezel,
  resolveLobbyScreenPresentation,
  resolveLobbyTitlePresentation,
  resolveLobbyTitleTexture,
  TitleArtwork,
} from './TitleArtwork';

afterEach(() => {
  cleanup();
  delete document.documentElement.dataset.lobbyTitleVariant;
  delete document.documentElement.dataset.lobbyTitleTexture;
  delete document.documentElement.dataset.lobbyTitleClassicAlt;
  document.documentElement.classList.remove('theme-meridian_pipboy');
});

describe('TitleArtwork', () => {
  it('uses the convex glass treatment by default', () => {
    const { container } = render(
      <TitleArtwork
        treatment="mask"
        src="asset://meridian-rift.png"
        textureSrc="asset://scanlines-classic.png"
      />,
    );

    const artwork = container.querySelector('.lobby-title-art');
    expect(artwork?.getAttribute('data-variant')).toBe(
      DEFAULT_LOBBY_TITLE_ART_VARIANT,
    );
    expect(artwork?.getAttribute('aria-hidden')).toBe('true');
    expect(artwork?.getAttribute('data-texture')).toBe(
      DEFAULT_LOBBY_TITLE_TEXTURE,
    );
    expect(artwork?.getAttribute('data-presentation')).toBe(
      DEFAULT_LOBBY_TITLE_PRESENTATION,
    );
    expect(artwork?.getAttribute('data-bezel')).toBe(
      String(DEFAULT_LOBBY_TITLE_BEZEL),
    );
    expect(artwork?.classList.contains('lobby-title-art--bezel')).toBe(true);
    expect(
      container
        .querySelector('.lobby-title-art__fallback')
        ?.getAttribute('src'),
    ).toBe('asset://meridian-rift.png');
  });

  it('uses the supplied classic scanlines only when requested and available', () => {
    document.documentElement.dataset.lobbyTitleTexture = 'scanlines-classic';
    const { container } = render(
      <TitleArtwork
        treatment="mask"
        src="asset://meridian-rift.png"
        textureSrc="asset://scanlines-classic.png"
      />,
    );

    const artwork = container.querySelector('.lobby-title-art');
    const scanlines = container.querySelector(
      '.lobby-title-art__scanlines',
    ) as HTMLElement | null;
    expect(artwork?.getAttribute('data-texture')).toBe('scanlines-classic');
    expect(
      scanlines?.style.getPropertyValue('--lobby-title-scanline-image'),
    ).toContain('scanlines-classic.png');
    expect(resolveLobbyTitleTexture('scanlines-classic', false)).toBe('scanlines-light');
    expect(resolveLobbyTitleTexture('unknown')).toBe('scanlines-classic');
    expect(resolveLobbyTitleTexture('unknown', false)).toBe('scanlines-light');
  });

  it('selects the licensed scanlines for the Wastelander theme', () => {
    document.documentElement.classList.add('theme-meridian_pipboy');
    const { container } = render(
      <TitleArtwork
        treatment="mask"
        src="asset://meridian-rift.png"
        textureSrc="asset://scanlines-classic.png"
      />,
    );

    expect(
      container.querySelector('.lobby-title-art')?.getAttribute('data-texture'),
    ).toBe('scanlines-classic');
  });

  it('lets an explicit Original choice override Wastelander auto selection', () => {
    document.documentElement.classList.add('theme-meridian_pipboy');
    const { container } = render(
      <TitleArtwork
        treatment="mask"
        src="asset://meridian-rift.png"
        texture="scanlines-light"
        textureSrc="asset://scanlines-classic.png"
      />,
    );

    expect(
      container.querySelector('.lobby-title-art')?.getAttribute('data-texture'),
    ).toBe('scanlines-light');
  });

  it('applies controlled geometry and component-scoped Classic Alt presentation', () => {
    const { container } = render(
      <TitleArtwork
        treatment="mask"
        presentation="classic-alt"
        src="asset://meridian-rift.png"
        texture="scanlines-classic"
        textureSrc="asset://scanlines-classic.png"
        variant="convex"
        bezel
      />,
    );

    const artwork = container.querySelector('.lobby-title-art');
    expect(artwork?.getAttribute('data-variant')).toBe('convex');
    expect(artwork?.getAttribute('data-bezel')).toBe('classic');
    expect(artwork?.classList.contains('lobby-title-art--bezel')).toBe(true);
    expect(artwork?.getAttribute('data-texture')).toBe('scanlines-classic');
    expect(artwork?.getAttribute('data-presentation')).toBe('classic-alt');
    expect(artwork?.classList.contains('lobby-title-art--classic-alt')).toBe(
      true,
    );
  });

  it('uses the gradient master as default and keeps configured screens classic', () => {
    expect(resolveLobbyScreenPresentation('mask', false)).toBe('classic-alt');
    expect(resolveLobbyScreenPresentation('mask', true)).toBe('classic');
    expect(resolveLobbyScreenPresentation('screen', false)).toBe('classic');
    expect(resolveLobbyScreenPresentation('overlay', false)).toBe('classic');
    expect(resolveLobbyTitlePresentation('classic')).toBe('classic');
    expect(resolveLobbyTitlePresentation('classic-alt')).toBe('classic-alt');
    expect(resolveLobbyTitlePresentation('unknown')).toBe(
      DEFAULT_LOBBY_TITLE_PRESENTATION,
    );

    const { container, rerender } = render(
      <TitleArtwork
        presentation={resolveLobbyScreenPresentation('mask', false)}
        src="asset://meridian-rift.png"
        treatment="mask"
      />,
    );

    expect(
      container.querySelector('.lobby-title-art')?.getAttribute(
        'data-presentation',
      ),
    ).toBe('classic-alt');

    rerender(
      <TitleArtwork
        presentation={resolveLobbyScreenPresentation('mask', true)}
        src="asset://meridian-rift-alt.png"
        treatment="mask"
      />,
    );

    const alternateMaster = container.querySelector('.lobby-title-art');
    expect(alternateMaster?.getAttribute('data-presentation')).toBe('classic');
    expect(
      alternateMaster?.classList.contains('lobby-title-art--classic-alt'),
    ).toBe(false);

    rerender(
      <TitleArtwork
        presentation={resolveLobbyScreenPresentation('screen', false)}
        src="asset://configured-screen.png"
        treatment="screen"
      />,
    );

    expect(
      container.querySelector('.lobby-title-art')?.getAttribute(
        'data-presentation',
      ),
    ).toBe('classic');
  });

  it('falls back to Original when classic texture bytes are unavailable', () => {
    const { container } = render(
      <TitleArtwork
        treatment="mask"
        src="asset://meridian-rift.png"
        texture="scanlines-classic"
      />,
    );

    expect(
      container.querySelector('.lobby-title-art')?.getAttribute('data-texture'),
    ).toBe('scanlines-light');
  });

  it('accepts each controlled preview variant and rejects unknown values', () => {
    expect(resolveLobbyTitleArtVariant('flat')).toBe('flat');
    expect(resolveLobbyTitleArtVariant('edge')).toBe('edge');
    expect(resolveLobbyTitleArtVariant('convex')).toBe('convex');
    expect(resolveLobbyTitleArtVariant('unknown')).toBe(
      DEFAULT_LOBBY_TITLE_ART_VARIANT,
    );
  });

  it('reads a stored convex-bezel as convex plus a bezel', () => {
    // The bezel used to be welded onto the variant, so only a convex screen
    // could have one. Settings saved before the split still resolve.
    expect(resolveLobbyTitleArtVariant('convex-bezel')).toBe('convex');
    expect(resolveLobbyTitleBezel(undefined, 'convex-bezel')).toBe('classic');
    expect(resolveLobbyTitleBezel(undefined, 'convex')).toBe('rusty-dark');
    // An explicit value always wins over the legacy inference.
    expect(resolveLobbyTitleBezel(false, 'convex-bezel')).toBe('none');
    expect(resolveLobbyTitleBezel(true, 'flat')).toBe('classic');
  });

  it('switches bezel materials independently of every screen effect', () => {
    const { container, rerender } = render(
      <TitleArtwork treatment="mask" src="asset://mark.png" />,
    );
    for (const variant of ['flat', 'edge', 'convex'] as const) {
      for (const bezel of ['rusty', 'rusty-dark', 'aphelion', 'classic', 'none'] as const) {
        rerender(
          <TitleArtwork
            bezel={bezel}
            variant={variant}
            treatment="mask"
            src="asset://mark.png"
          />,
        );
        const artwork = container.querySelector('.lobby-title-art');
        expect(artwork?.getAttribute('data-bezel')).toBe(bezel);
        expect(artwork?.getAttribute('data-variant')).toBe(variant);
        expect(artwork?.classList.contains('lobby-title-art--bezel')).toBe(
          bezel !== 'none',
        );
        expect(
          artwork?.classList.contains(`lobby-title-art--bezel-${bezel}`),
        ).toBe(true);
      }
    }
    expect(resolveLobbyTitleBezel('invalid')).toBe('rusty-dark');
    expect(resolveLobbyTitleBezel('none', 'convex-bezel')).toBe('none');
    expect(resolveLobbyTitleBezel(0)).toBe('none');
    expect(resolveLobbyTitleBezel(1)).toBe('classic');
  });

  it('turns scanlines off without colliding with the untreated class', () => {
    const { container } = render(
      <TitleArtwork
        treatment="mask"
        src="asset://meridian-rift.png"
        texture="none"
      />,
    );

    const artwork = container.querySelector('.lobby-title-art');
    expect(artwork?.getAttribute('data-texture')).toBe('none');
    expect(artwork?.classList.contains('lobby-title-art--texture-none')).toBe(
      true,
    );
    // The treatment owns the unprefixed modifier; the texture must not take it.
    expect(artwork?.classList.contains('lobby-title-art--none')).toBe(false);
  });

  it('keeps operator-provided title screens as ordinary images', () => {
    const { container } = render(
      <TitleArtwork treatment="none" src="asset://operator-title.png" />,
    );

    expect(container.querySelector('.lobby-title-art')).toBeNull();
    expect(container.querySelector('.bg')?.getAttribute('src')).toBe(
      'asset://operator-title.png',
    );
  });
});
