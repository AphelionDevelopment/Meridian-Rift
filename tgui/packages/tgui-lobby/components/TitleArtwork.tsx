// THIS IS AN APHELION UI FILE

import type { CSSProperties } from 'react';

export const LOBBY_TITLE_ART_VARIANTS = [
  'flat',
  'edge',
  'convex',
  'convex-bezel',
] as const;

export type LobbyTitleArtVariant = (typeof LOBBY_TITLE_ART_VARIANTS)[number];

export const LOBBY_TITLE_TEXTURES = ['original', 'navarobl'] as const;

export type LobbyTitleTexture = (typeof LOBBY_TITLE_TEXTURES)[number];

export const LOBBY_TITLE_PRESENTATIONS = ['classic', 'classic-alt'] as const;

export type LobbyTitlePresentation = (typeof LOBBY_TITLE_PRESENTATIONS)[number];

// The emphasized user direction was convex glass without a physical bezel.
// Keep the other controlled variants available for visual review.
export const DEFAULT_LOBBY_TITLE_ART_VARIANT: LobbyTitleArtVariant = 'convex';
export const DEFAULT_LOBBY_TITLE_TEXTURE: LobbyTitleTexture = 'original';
export const DEFAULT_LOBBY_TITLE_PRESENTATION: LobbyTitlePresentation =
  'classic';

export function resolveLobbyTitleArtVariant(
  value?: string,
): LobbyTitleArtVariant {
  return LOBBY_TITLE_ART_VARIANTS.includes(value as LobbyTitleArtVariant)
    ? (value as LobbyTitleArtVariant)
    : DEFAULT_LOBBY_TITLE_ART_VARIANT;
}

export function resolveLobbyTitleTexture(
  value?: string,
  hasNavaroTexture = true,
): LobbyTitleTexture {
  return value === 'navarobl' && hasNavaroTexture
    ? 'navarobl'
    : DEFAULT_LOBBY_TITLE_TEXTURE;
}

export function resolveLobbyTitlePresentation(
  value?: string,
): LobbyTitlePresentation {
  return value === 'classic-alt'
    ? 'classic-alt'
    : DEFAULT_LOBBY_TITLE_PRESENTATION;
}

function cssUrl(url: string): string {
  return `url("${url.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}")`;
}

export function TitleArtwork({
  branded,
  presentation: presentationProp,
  src,
  texture: textureProp,
  textureSrc,
  variant: variantProp,
}: {
  branded: boolean;
  presentation?: LobbyTitlePresentation;
  src: string;
  texture?: LobbyTitleTexture;
  textureSrc?: string;
  variant?: LobbyTitleArtVariant;
}) {
  if (!branded) {
    return <img className="bg" src={src} alt="" />;
  }

  const variant = resolveLobbyTitleArtVariant(
    variantProp ?? document.documentElement.dataset.lobbyTitleVariant,
  );
  const requestedTexture =
    textureProp ??
    document.documentElement.dataset.lobbyTitleTexture ??
    (document.documentElement.classList.contains('theme-meridian_pipboy')
      ? 'navarobl'
      : undefined);
  const texture = resolveLobbyTitleTexture(requestedTexture, !!textureSrc);
  const presentation = resolveLobbyTitlePresentation(
    presentationProp ??
      (document.documentElement.dataset.lobbyTitleClassicAlt === 'true'
        ? 'classic-alt'
        : undefined),
  );
  const imageStyle = {
    '--lobby-title-art-image': cssUrl(src),
  } as CSSProperties;
  const textureStyle = textureSrc
    ? ({
        '--lobby-title-scanline-image': cssUrl(textureSrc),
      } as CSSProperties)
    : undefined;

  return (
    <div
      aria-hidden="true"
      className={`lobby-title-art lobby-title-art--${variant} lobby-title-art--${texture} lobby-title-art--${presentation}`}
      data-presentation={presentation}
      data-texture={texture}
      data-variant={variant}
    >
      <div className="lobby-title-art__bezel">
        <div className="lobby-title-art__screen">
          <img className="lobby-title-art__fallback" src={src} alt="" />
          <div className="lobby-title-art__mark" style={imageStyle} />
          <div className="lobby-title-art__scanlines" style={textureStyle} />
        </div>
      </div>
    </div>
  );
}
