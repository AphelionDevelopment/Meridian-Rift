# Meridian Rift title artwork provenance

## Included production asset

`icons/meridian_rift_title_mask.png` is a neutral alpha-mask wordmark created
for this repository on 2026-09-02 with OpenAI's built-in image-generation tool.
The repository's former `nova_sector_title_screen.png` supplied only the broad
square-canvas placement reference. The generated wordmark was mechanically
thresholded to alpha and resized to 512 x 512; no third-party texture pixels
are included.

The TGUI lobby supplies the black screen, original scanline overlay, optional
edge falloff, convex-glass shading, and optional physical bezel in CSS. Its
phosphor color comes from semantic MeridianOS theme variables rather than from
duplicated theme-specific rasters.

### Image-generation prompt record

Three edit requests were used while producing the neutral wordmark master:

1. Replace the supplied square NOVA SECTOR placement reference with the exact
   uppercase text **MERIDIAN RIFT**, centered as a retro-futurist scanline
   display wordmark and underline on a transparent square canvas; remove all
   other branding and do not copy Fallout art.
2. Clean the result into a crisp production mask: preserve exact text and
   placement, use straight segmented horizontal scanline glyphs, and remove
   grunge, debris, scratches, scenery, bezel, and unrelated decoration.
3. Extract only the wordmark and underline to true alpha with no visible
   checkerboard or background field and no new elements.

The second result had the cleanest glyph geometry but a baked checkerboard, so
its wordmark was mechanically isolated to alpha and resized. The generated
background pixels themselves are not present in the shipped mask.

## NavaroBL source-derived alternate

The visual research reference was NavaroBL's **Pip-Boy Classic Scan Lines
Texture**, Nexus Mods 74157:

- Source: https://www.nexusmods.com/newvegas/mods/74157
- Author/uploader: NavaroBL
- Version: V1; original upload 2021-10-23; page last updated 2026-03-05
- Current files listed on 2026-09-02:
  - `Scan Lines - Alternative` v1.0, 1 KB (main file, file id 1000171091)
  - `Scan-Lines-V1` V1, 2 KB (main file, file id 1000082936)
  - `Scan Lines - Light` v1.0, 1 KB (optional file, file id 1000171090)
- Nexus permission summary: asset reuse and conversion to other games are
  allowed with creator credit; modified releases are allowed with credit; the
  full file may not be re-uploaded elsewhere; use in sold mods/files is not
  allowed; Donation Points are allowed.

Nexus required an authenticated account to download an archive in this
session. The user supplied the downloaded `Scan Lines - Alternative` archive
contents for inspection from:

`C:\Users\mal\Scan Lines - Alternative-74157-v1-0-1772684075\Scan-Lines-Alternative`

The supplied archive contains one file:

- `textures/pipboy3000/pipboyscanlines.dds`
- SHA-256: `BD9FD9AE272EBB9D52192FA0F80E9E8C80507A0548DFE589BDFC8DB7BCB5BC6A`
- DDS DXT3, 1024 x 1024, one mip level, 1,048,704 bytes

`icons/hud/lobby/png/meridian_rift_scanlines_navarobl.png` is a transformed,
credited derivative of that exact file. The DXT3 blocks were decoded to RGBA;
the source luminance was converted to an alpha mask using Rec. 709 weights
(`alpha = 255 - luminance`), RGB was normalized to white, and the result was
losslessly encoded as a 1024 x 1024 RGBA PNG. Its SHA-256 is
`3E3140FEE5D179B1FCBAE844007A348D3AC7EAB19FA513573F0FA5D87CDE7FD0`.
The browser colors this neutral mask from semantic theme tokens. No Fallout,
Pip-Boy, or other franchise branding is embedded.

The original CSS scanline treatment remains a separate comparison option and
contains no third-party texture pixels. The source-derived option is selected
automatically for the Meridian Pip-Boy theme and can be explicitly selected by
the controlled artwork preview.
