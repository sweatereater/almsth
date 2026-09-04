# Semantic UI theme — Stages 1C–1D / Семантическая тема UI — этапы 1C–1D

Stage 1C separates presentation from world art. `UiPalette` owns literal design
tokens; `UiThemeController` owns and caches every `Theme`, semantic `StyleBox` and
font resource. The character-only presentation exception below owns its cached
decorative materials. `UiFactory` remains a compatibility facade. The dungeon world,
camp painting, creatures, items and full-body art are never modulated by a UI theme.

Этап 1C отделяет представление интерфейса от рисунка мира. `UiPalette` хранит
буквальные токены, `UiThemeController` создаёт и кэширует темы, семантические
`StyleBox` и шрифты. `UiFactory` оставлен совместимым фасадом. Темы не модулируют
мир подземелья, лагерь, существ, предметы и полнофигурные изображения.

Stage 1D extends these exact tokens into character inventory, skill nodes, the compact
Dungeon material strip and structured action history. It introduces no literal or
derived color role and does not mutate or allocate theme/font/texture resources from
`_draw` or `_process`.

Этап 1D применяет ровно эти токены к инвентарю персонажа, навыкам, компактной полосе
материалов Dungeon и структурированному журналу. Новых базовых/производных цветов нет;
`_draw` и `_process` не создают и не изменяют ресурсы темы, шрифта или текстуры.

## Literal tokens / Базовые токены

| Role | Warm Archive | Cold Dungeon |
|---|---|---|
| background | `#100F0D` | `#070C11` |
| panel | `#2A251E` | `#142733` |
| inset | `#18140F` | `#0D161F` |
| raised / hover | `#342E25` | `#18303A` |
| primary | `#F2E8D4` | `#E9F1EF` |
| secondary | `#BAAB91` | `#9AB0B5` |
| neutral border | `#806F53` | `#557D91` |
| selected fill | `#263B35` | `#123B3A` |
| soul / selection | `#67CDC5` | `#55E0D4` |
| focus | `#E1B965` | `#FFD078` |
| copper / magic | `#A96D4C` | `#AA96D5` |
| danger | `#D87568` | `#FF7B72` |
| disabled | `#847A6B` | `#70838B` |

Only two measured derived color roles exist. Warm `disabled_text_contrast`
`#A49784` measures 5.31:1 on panel and 4.69:1 on raised; cold `#8298A0`
measures 5.08:1 and 4.56:1. `danger_surface` is the specified 20% sRGB danger
composition over background: warm `#38231F` (danger border 4.67:1, primary
12.09:1), cold `#392224` (5.83:1 and 12.81:1). A black-alpha 72% overlay scrim
is the only overlay derivative; equal RGB channels attenuate without hue tint.

Разрешены только две измеренные производные роли. Значения и коэффициенты выше
являются частью контракта, а не вычисляются произвольным осветлением/затемнением.
Чёрная подложка с alpha 72% одинаково ослабляет все каналы и не окрашивает мир.

## States and context / Состояния и контекст

- normal: inset plus 1 px neutral border;
- hover: raised plus 2 px neutral border;
- selected: selected fill, 2 px soul border and 5 px left marker/check;
- focus: transparent separated 3 px outer gold outline preserving the base state;
- selected + focus: both internal soul marker and external gold outline;
- disabled: square/depressed surface, readable derived text, disabled border, no action;
- danger: danger surface, border, left marker and explicit destructive verb/icon.

`DangerButton` never borrows the teal selected state: normal, hover, pressed and
hover-pressed retain the exact danger surface/border. Hover increases the border;
pressed squares the corners and widens the left marker. The separated gold focus
outline can coexist with any of them. Settings sliders likewise use cached semantic
rail, fill and grabber resources (including hover/disabled) and draw the same cached
external gold focus outline. No state allocates or mutates theme resources in `_draw`.

`DangerButton` не заимствует бирюзовое состояние выбора: normal, hover, pressed и
hover-pressed сохраняют точные danger surface/border. Наведение утолщает границу,
нажатие выпрямляет углы и расширяет левую метку; внешняя золотая рамка фокуса
остаётся отдельной. Ползунки настроек используют кэшируемые семантические рельс,
заполнение и бегунок, включая hover/disabled, без создания ресурсов в `_draw`.

Cold Dungeon belongs only to the active dungeon presentation. Startup, creation,
character, settings, remapping, save/load, storage, construction and every global
confirmation explicitly use Warm Archive, including when laid over a cold dungeon.
Inventory and skills opened from an active dungeon retain that same frozen Cold world
under the neutral 72% scrim while all modal content remains Warm. The STOP modal root
consumes background input; decorative controls use IGNORE. Back closes one layer and
restores the prior focus, floor, camera and 44/66/88 cell size.

Typography uses 32/28/20/16/14/12 virtual pixels. Interactive, selectable and
essential Stage 1C text never drops below 12 px. The project stretch contract keeps
the 1280×720 virtual canvas at both 1280×720 and 960×540.

Functional text uses local Noto Sans Regular/Medium/SemiBold with a cached `tnum`
`FontVariation` for aligned numeric columns. Cormorant Garamond SemiBold is limited
to 28/32 px display headings outside the character-only exception below. Seven project-native monochrome UI shapes provide only
the semantic symbols absent from Noto; they are a cached fallback, never a system
font. Provenance, licenses and hashes are recorded in `assets/fonts/README.md`.

Функциональный текст использует локальный Noto Sans и кэшируемую вариацию `tnum`;
Cormorant Garamond применяется только для заголовков 28/32 px. Семь служебных
монохромных форм дополняют отсутствующие символы без системных шрифтов.

Character headings use Cormorant only while the complete name/form string fits at
28 px. A long heading switches to Noto Sans SemiBold 20 and ellipsizes; Cormorant is
never reduced to an intermediate size. `FONT_SIZES` is executable policy: factories
and fitting helpers select only `32/28/20/16/14/12`, with a 12 px virtual minimum for
interactive/selectable/essential text.

Заголовок персонажа использует Cormorant только когда полная строка имени и формы
помещается при 28 px. Длинная строка переключается на Noto Sans SemiBold 20 и
обрезается многоточием; промежуточный уменьшенный Cormorant запрещён.

## Focused controls and diagnostics / Фокус и диагностика

Character inventory exposes exactly six 2×3 cards per page in its existing 549×546
region. The character-only display groups map to immutable internal categories as
`All`; `Weapons → weapon`; `Off-hand → offhand`; `Armor → head/body/hands/legs/feet`;
`Accessories → talisman/ring`; `Backpack → back`. Service/storage modes keep their old
`GameRules` identifiers. Cards validate `(item key, source, physical slot)` plus the
current refresh revision immediately before an action. Selection uses an internal
5 px soul marker, focus a separate external gold outline. Every visible card owns
interactive code-drawn lock and broken-sword Keep/Salvage corner controls. Repeating the
active mark clears it; Salvage switches directly to Keep, while Keep must be explicitly
cleared before Salvage. Their focus outline coexists with card selection; 2H occupancy
keeps its 40% ghost and adds a non-color link cue. Essential card, pager, property and action text is at least
12 virtual px; names are 14 px with ellipsis plus complete tooltip/accessibility text.

Skill nodes preserve the exact 19-ID topology and eleven protected 128×128 bitmap
paths with 96×96 safe areas. Nodes remain 54 and detail output 64. Locked/depressed
plus lock/dashed connector/reason, available plus/cost, learned check, and MAX double
ring are independently non-color readable. The internal soul selection and external
gold focus can coexist. A separate disabled specimen uses a two-pixel depressed
geometry, disabled token and explicit reason; held state uses the same non-color
offset and never derives a lightened/darkened color. Locked nodes remain inspectable;
selecting a node never buys it.

Status chips on the character stats view cache their semantic StyleBoxes and tabular
Noto font before drawing. Each chip has a localized accessible name, participates in
the explicit keyboard/D-pad focus graph, and shows the external gold focus outline.
The three Base material counters follow the same contract: cached Warm inset/raised
neutral states, a separate external gold focus outline, and fixed tabular Noto Sans
12 px values. Their responsive 198 px strip fits all three four-digit maximum review
values while the adjacent 104 px soul field preserves the complete `999999 (1999998)`
at 1280×720 and 960×540, without overlap, shrinking, or protected icon-color changes.
Remap conflicts expose stable `ConfirmBindingConflict` and `CancelBindingConflict`
actions; the modal consumes a second tap on the source binding until Replace or Cancel
is activated by touch, keyboard or gamepad. Conflict/error and reset confirmation use
the danger language consistently.

Save error-16 and delete-failure recovery copy lives in a 532×72 semantic danger
banner with a 508×64 wrapped text area. Six 460×52 save rows remain visible below it;
the banner and text bounds are measured in both languages at both supported windows.

Чипы статусов кэшируют стили и табличный Noto до отрисовки, имеют локализованное
accessibility-имя и входят в явный граф фокуса. Три счётчика материалов Базы также
используют кэшированные тёплые inset/raised-состояния, отдельную внешнюю золотую
рамку фокуса и табличный Noto Sans 12 px; адаптивная полоса 198 px вмещает три значения
9999, пока соседнее поле 104 px показывает полное `999999 (1999998)` при 1280×720 и
960×540 без перекрытий, уменьшения шрифта материалов и изменения цветов защищённых
иконок. Конфликт переназначения блокирует
повторное касание исходной строки до выбора видимых действий «Перенести» или
«Оставить»; клавиатура и геймпад используют те же действия. Диагностики сохранения
занимают баннер 532×72, а все шесть строк 460×52 остаются доступны ниже него.

The compact Cold material strip sits directly below souls, reads the same
`RunState.resources` dictionary, renders code-drawn wood/stone/cloth symbols and
tabular values at 12 px or above, and is non-interactive (`MOUSE_FILTER_IGNORE`). Action
history retains at most eight newest-first top-level entries with ordered semantic
segments: outgoing `↑ OUT:/↑ ИСХ:`, incoming `↓ IN:/↓ ВХОД:`, loot
`▣ LOOT:/▣ ДОБЫЧА:`, neutral `· INFO:/· СИСТ:`. The protected local fallback contains
`▣` but not the proposed diamond, so the supported square-with-center glyph is the
documented non-color loot marker; fonts and bitmap assets remain untouched. Rendering
is uniform 12 px with no age fade, BBCode-escaped content and complete accessible text.

## Render evidence / Рендер-доказательства

`tools/capture_stage1c_previews.ps1` regenerates 57 real-control scenarios for each
RU/EN × 1280×720/960×540 profile (228 PNGs). The original 34 remain unchanged and 23
Stage 1D scenarios cover eight inventory states, six skill views (including state and
all-icon sheets), three Cold HUD zooms and six Warm-over-Cold inventory/skill zooms.
It includes active statuses, slider focus,
actual danger hover/held-press, long headings, and the real cold Dungeon → warm
Character → same cold Dungeon transition, plus maximum Base material counters with
real focus. The workflow rejects stale/unmanifested
PNGs and verifies dimensions, SHA-256 and a recursive source-hash closure covering
all scripts, scenes, runtime assets, fonts, portraits, runner and workflow.
Before cleanup or Godot launch, both workflow layers canonicalize the output and accept
only the exact preview root. The mandatory disposable-sentinel preflight rejects both
traversal and sibling-prefix paths before cleanup. The Stage 1D protected manifest has
416 exact files and narrowly includes the shipped `assets/ui/soul-icon.png` alongside
the already frozen art/portraits; unrelated generated UI files remain outside it.

Сценарий захвата пересоздаёт 228 PNG (57 на профиль), проверяет размеры/SHA-256,
отсутствие старых файлов и полный набор входных хэшей. Все прежние 34 сценария сохранены;
23 новых покрывают восемь инвентарей, шесть представлений навыков, Cold HUD 44/66/88
и Warm-over-Cold inventory/skills 44/66/88. Матрица также содержит состояния статусов,
ползунка, danger hover/press, максимальных счётчиков материалов с фокусом и возврата
из тёплого листа персонажа в то же холодное подземелье.

## Character-only archive presentation / Оформление только листа персонажа

The 2026-09-05 sheet refinement deliberately extends Stage 1D decoration locally.
`CharacterSheetSurface` caches deterministic grain and wrapped value-noise textures,
bronze `#766346`, edge light `#A78B5C`, dark groove `#080A09`, and a subtle warm niche
light. The opaque charcoal sheet sits above the unchanged neutral 72% scrim and frozen
world. These are UI materials, never color modulation of portraits, items or world art.
Cards have thin double bronze lines and restrained corner joins. Character buttons use
cached nine-slice textures with tiled centers; selection keeps teal plus a left marker,
while keyboard focus has a separate 1px gold line expanded by 3px. Global danger and
Cold Dungeon styles remain unchanged. The global menu button restores its normal style
when leaving Character.

Локальное исключение типографики: крупные вкладки и возврат — Cormorant 28, меню —
Cormorant 20, заголовки разделов — Cormorant 16. Если полная строка заголовка не
помещается, используется Noto Sans 12 (русские «ОСНОВНЫЕ ХАРАКТЕРИСТИКИ»).
Текст и числа остаются Noto Sans не меньше 12. Длинное имя сохраняет прежний fallback
Noto Sans 20 с многоточием и полным доступным именем. Уровень души, форма и облик
показываются тремя полными локализованными строками.
