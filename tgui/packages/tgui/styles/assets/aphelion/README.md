# Aphelion website assets

These assets reproduce the typography and subtle blue-noise texture of the
[Meridian website](https://meridian.a13.info/about/), verified on 2026-09-05.
The font binaries are unchanged Latin-subset WOFF2 files from the site's
self-hosted Fontsource cache. The Aphelion family names are CSS aliases only;
font binary metadata remains unchanged.

## Fonts

| File | Weight | Role | License |
| --- | --- | --- | --- |
| public-sans-latin-variable.woff2 | 100-900 | UI/body | OFL-Public-Sans.txt |
| ibm-plex-mono-latin-400.woff2 | 400 | Labels/telemetry | OFL-IBM-Plex-Mono.txt |
| ibm-plex-mono-latin-600.woff2 | 600 | Emphasized labels | OFL-IBM-Plex-Mono.txt |
| space-grotesk-latin-variable.woff2 | 300-700 | Display/headings | OFL-Space-Grotesk.txt |

The original copyright statements and complete SIL Open Font License 1.1
texts are bundled alongside the font files, retrieved from Google Fonts:

- [OFL-Public-Sans.txt](https://raw.githubusercontent.com/google/fonts/main/ofl/publicsans/OFL.txt)
- [OFL-IBM-Plex-Mono.txt](https://raw.githubusercontent.com/google/fonts/main/ofl/ibmplexmono/OFL.txt)
- [OFL-Space-Grotesk.txt](https://raw.githubusercontent.com/google/fonts/main/ofl/spacegrotesk/OFL.txt)

Fontsource sources recorded by the website's Astro font cache:

- https://cdn.jsdelivr.net/fontsource/fonts/public-sans:vf@latest/latin-wght-normal.woff2
- https://cdn.jsdelivr.net/fontsource/fonts/ibm-plex-mono@latest/latin-400-normal.woff2
- https://cdn.jsdelivr.net/fontsource/fonts/ibm-plex-mono@latest/latin-600-normal.woff2
- https://cdn.jsdelivr.net/fontsource/fonts/space-grotesk:vf@latest/latin-wght-normal.woff2

## Grain

`aphelion-grain-blue-noise-512.png` is copied byte-for-byte from the website's
`src/assets/textures/grain-blue-noise-512.png`. It is the original 512px
seamless texture, not a generated replacement. The website uses opacity 0.02
for grain and effective opacity 0.016 for its separate CSS scanlines.

## Provenance and integrity

These content-addressed website URLs identify the exact copied assets;
SHA-256 values make provenance independent of future website changes.

- [public-sans-latin-variable.woff2](https://meridian.a13.info/_astro/fonts/e39e7ea65aa44c33.woff2)
  - SHA-256: `5ed4d31c988e73b258894244f209069ebe77dc7e564861954b21198b6de90d68`
- [ibm-plex-mono-latin-400.woff2](https://meridian.a13.info/_astro/fonts/a3a0a8110b9e369d.woff2)
  - SHA-256: `08949f728dc52d528e69b1667d15c89a5686a4ee9a296ff90983985f99c380f7`
- [ibm-plex-mono-latin-600.woff2](https://meridian.a13.info/_astro/fonts/9be50d119b1fd79e.woff2)
  - SHA-256: `0d1f0b8d0722224e32e9f28261bdc86c79115be73444ae5eceb73976a1bcdf83`
- [space-grotesk-latin-variable.woff2](https://meridian.a13.info/_astro/fonts/09583b04074fd09f.woff2)
  - SHA-256: `0640890476fc1198ab4de571fb658de443c4d85b66466ec09534a8737ab1ce9d`
- [aphelion-grain-blue-noise-512.png](https://meridian.a13.info/_astro/grain-blue-noise-512.BHVQ2Vs9.png)
  - SHA-256: `37c6396a769482fbba0268c9075ce336d4c688ef4428fbd2e2198664ef9fb99e`
