// THIS IS AN APHELION UI FILE
import { afterEach, describe, expect, it } from 'bun:test';
import { cleanup, render } from '@testing-library/react';
import {
  DEFAULT_LOBBY_TITLE_ART_VARIANT,
  DEFAULT_LOBBY_TITLE_PRESENTATION,
  DEFAULT_LOBBY_TITLE_TEXTURE,
  resolveLobbyTitleArtVariant,
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
      <TitleArtwork treatment="mask" src="asset://meridian-rift.png" />,
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
    expect(
      container
        .querySelector('.lobby-title-art__fallback')
        ?.getAttribute('src'),
    ).toBe('asset://meridian-rift.png');
  });

  it('uses the supplied NavaroBL scanlines only when requested and available', () => {
    document.documentElement.dataset.lobbyTitleTexture = 'navarobl';
    const { container } = render(
      <TitleArtwork
        treatment="mask"
        src="asset://meridian-rift.png"
        textureSrc="asset://navarobl-scanlines.png"
      />,
    );

    const artwork = container.querySelector('.lobby-title-art');
    const scanlines = container.querySelector(
      '.lobby-title-art__scanlines',
    ) as HTMLElement | null;
    expect(artwork?.getAttribute('data-texture')).toBe('navarobl');
    expect(
      scanlines?.style.getPropertyValue('--lobby-title-scanline-image'),
    ).toContain('navarobl-scanlines.png');
    expect(resolveLobbyTitleTexture('navarobl', false)).toBe('original');
    expect(resolveLobbyTitleTexture('unknown')).toBe('original');
  });

  it('selects the licensed scanlines for the Pip-Boy theme', () => {
    document.documentElement.classList.add('theme-meridian_pipboy');
    const { container } = render(
      <TitleArtwork
        treatment="mask"
        src="asset://meridian-rift.png"
        textureSrc="asset://navarobl-scanlines.png"
      />,
    );

    expect(
      container.querySelector('.lobby-title-art')?.getAttribute('data-texture'),
    ).toBe('navarobl');
  });

  it('lets an explicit Original choice override Pip-Boy auto selection', () => {
    document.documentElement.classList.add('theme-meridian_pipboy');
    const { container } = render(
      <TitleArtwork
        treatment="mask"
        src="asset://meridian-rift.png"
        texture="original"
        textureSrc="asset://navarobl-scanlines.png"
      />,
    );

    expect(
      container.querySelector('.lobby-title-art')?.getAttribute('data-texture'),
    ).toBe('original');
  });

  it('applies controlled geometry and component-scoped Classic Alt presentation', () => {
    const { container } = render(
      <TitleArtwork
        treatment="mask"
        presentation="classic-alt"
        src="asset://meridian-rift.png"
        texture="navarobl"
        textureSrc="asset://navarobl-scanlines.png"
        variant="convex-bezel"
      />,
    );

    const artwork = container.querySelector('.lobby-title-art');
    expect(artwork?.getAttribute('data-variant')).toBe('convex-bezel');
    expect(artwork?.getAttribute('data-texture')).toBe('navarobl');
    expect(artwork?.getAttribute('data-presentation')).toBe('classic-alt');
    expect(artwork?.classList.contains('lobby-title-art--classic-alt')).toBe(
      true,
    );
  });

  it('falls back to Original when NavaroBL texture bytes are unavailable', () => {
    const { container } = render(
      <TitleArtwork
        treatment="mask"
        src="asset://meridian-rift.png"
        texture="navarobl"
      />,
    );

    expect(
      container.querySelector('.lobby-title-art')?.getAttribute('data-texture'),
    ).toBe('original');
  });

  it('accepts each controlled preview variant and rejects unknown values', () => {
    expect(resolveLobbyTitleArtVariant('flat')).toBe('flat');
    expect(resolveLobbyTitleArtVariant('edge')).toBe('edge');
    expect(resolveLobbyTitleArtVariant('convex')).toBe('convex');
    expect(resolveLobbyTitleArtVariant('convex-bezel')).toBe('convex-bezel');
    expect(resolveLobbyTitleArtVariant('unknown')).toBe(
      DEFAULT_LOBBY_TITLE_ART_VARIANT,
    );
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
