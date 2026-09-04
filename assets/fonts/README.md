# Stage 1C bundled fonts / Локальные шрифты Stage 1C

The UI uses repository-local fonts only. No system font, CDN or runtime download is
required. Functional UI is Noto Sans; Cormorant Garamond SemiBold is limited to
large 28/32 px headings. Both families are redistributed under SIL Open Font
License 1.1; the complete license text is stored beside each family.

Интерфейс использует только локальные файлы репозитория. Функциональный текст набран
Noto Sans, Cormorant Garamond SemiBold применяется только для крупных заголовков
28/32 px. Обе гарнитуры распространяются по SIL OFL 1.1; полный текст лицензии лежит
рядом с файлами.

## Provenance / Происхождение

| File | Official source | Pinned revision | SHA-256 |
|---|---|---|---|
| `noto-sans/NotoSans-Regular.ttf` | [Noto Sans v2.015 release](https://github.com/notofonts/latin-greek-cyrillic/releases/tag/NotoSans-v2.015), `NotoSans/full/ttf` | v2.015; Google Fonts metadata revision `c4a321e123e4d4ff315f57f4e0adf294fe3a95be` | `f5f552c8c5edb61fe6efb824baf4d4de47b1a8689ab4925ff43f7bd6a4ebece5` |
| `noto-sans/NotoSans-Medium.ttf` | same / тот же | same / тот же | `1d1570dd66d70cbcd56646c55580c3cc453c7abc505534230c165f93b55ad394` |
| `noto-sans/NotoSans-SemiBold.ttf` | same / тот же | same / тот же | `bfcab863fec70318e9af8ead5266176a5231a77e693dacfc10f572754f9463a6` |
| `cormorant-garamond/CormorantGaramond-SemiBold.ttf` | [CatharsisFonts/Cormorant](https://github.com/CatharsisFonts/Cormorant) | tag v4.002, commit `b149467f785bc38e5417b68faa2d32bac8d7db5f` | `dc4bc094dc3c55cf79ff2f6f0ba1e501b712fc3cf3742296cd8fdcc6e995127d` |

License hashes: Noto `OFL.txt` —
`cee9892f9f0cc8fe882c9e9537ee6a89621d86ee7ceaf70b02e2b2b1c25c061a`;
Cormorant `OFL.txt` —
`60700d351cac4650c51f3f9db318d2a420f8b45052dba2715eb5fec41f0f6956`.

`UiThemeController` enables the OpenType `tnum` feature through `FontVariation`
for numeric columns. The Stage 1C contract verifies every RU/EN localization string
and the required symbols against the bundled functional fonts.

Noto Sans v2.015 intentionally does not contain a few semantic UI symbols used by
the project (`✓`, arrows, `▣`, `🔒`). `ui-symbols/stage1c-ui-symbols.svg` and its
BMFont map are a seven-glyph, project-native monochrome fallback, not another font
family or a system-font dependency. They are shape-only and inherit the semantic
text color. SHA-256: SVG
`58c93cbe73e6657fb5018c0ad2c5d2d76acffd9e04cd77110b7cd0ad458436e7`,
FNT `22c9059256e6f4690af133c775b4bf1295397fde6919d718559c932931911ef7`.

Noto Sans v2.015 намеренно не содержит несколько служебных символов (`✓`, стрелки,
`▣`, `🔒`). Малый монохромный атлас `ui-symbols` создан внутри проекта, наследует
семантический цвет текста и не обращается к системным шрифтам.
