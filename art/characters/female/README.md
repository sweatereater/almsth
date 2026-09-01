# Женский персонаж / Female character

Утверждённый основной художественный набор женской версии от **31.08.2026**:
скелет → зомби → гуль → ревенант → почти человек. Оригинальный почти человеческий
образ и последний согласованный лист четырёх предыдущих форм сохранены побайтово.
Одинаковые красно-карие глаза, повреждения плоти, одежда и рисунок не перерисованы.

**Approved canonical female artwork, 2026-08-31:** skeleton → zombie → ghoul →
revenant → almost human. The original almost-human illustration and final approved
four-form sheet are preserved byte for byte. Eye colour, damage, clothing and painted
detail are unchanged; this delivery uses cropping and alpha masks, not generation.

| Файлы / Files | Назначение / Purpose |
|---|---|
| `sources/` | Два неизменённых оригинала / Two unchanged masters |
| `fullbody/form-*.png` | Пять прямоугольных вырезок в исходном разрешении, с фоном; эталоны, **не игровые спрайты** / Five native rectangular reference crops with background, **not runtime sprites** |
| `heads/form-*.png` | Пять нативных RGBA-голов; RGB точно из исходника / Five native RGBA heads with exact source RGB |
| `masks/form-*.png` | Проверенные маски прозрачности / Reviewed alpha masks |
| `../../../assets/portraits/female/form-*.png` | Пять прозрачных иконок 264×264 RGBA8 / Five transparent 264×264 RGBA8 icons |
| `recipe.json` | Координаты вырезок, контуры, параметры альфы и ориентиры лица / Crops, contours, alpha parameters and facial landmarks |
| `manifest.json` | SHA-256, размеры, источники и преобразования каждого результата / SHA-256, dimensions, source mapping and transformations |
| `previews/` | Пять голов и матрица 264/88/66/44 px на тёмном, светлом и шахматном фоне / Five-head strips and 264/88/66/44 px dark, light and checker previews |

Иконки содержат только головы, короткую шею, волосы, косы и серьги. Пальто, руки,
нагрудные подвески и бумажный фон исключены масками. Лица приведены к общему масштабу
56 px от середины глаз до подбородка; координата середины глаз — `(115, 105)`.
Использовано только пропорциональное обычное масштабирование, прозрачное поле минимум
4 px, без рамок. Скелет не увеличен до размера всей причёски других стадий.

Icons contain heads, short necks, hair, braids and earrings only. Masks exclude coats,
hands, chest pendants and parchment. Faces share a 56 px eye-to-chin span and eye
midpoint `(115, 105)`. Scaling is proportional with at least 4 px transparent padding
and no baked frame; the bald skull is not enlarged to match the others' hair bounds.

Нативное разрешение голов ограничено утверждёнными изображениями: вырезки четырёх
стадий меньше 264 px. Обычная интерполяция не добавляет деталей; тонкие светлые края
исходного рисунка могут оставаться заметны на тёмном фоне при увеличении. Маски меняют
только альфу, сохраняя настоящие пряди, светлую кость и блики серёг.

Native detail is limited by the approved sources: the four-form head crops are smaller
than 264 px. Ordinary interpolation adds no new detail. Fine light source-art edges may
remain visible when enlarged over dark backgrounds. Masks change alpha only, preserving
real strands, ivory bone and earring highlights.

**Подключено к выбору пола, листу персонажа и map-матрице.** Почти человеческая голова используется
над именем; прозрачные полнофигурные версии подготовлены отдельно в
`assets/ui/character-fullbody/female/`, см. [общий рецепт](../sex-selection/README.md).
Оригиналы этого архива и пять голов не менялись. `.gdignore` исключает архив из импорта;
runtime PNG используют lossless, mipmaps off, fix alpha border on. На карте сохранённый
женский пол выбирает отдельный gait-набор для текущей/косметической формы.

**Connected to sex selection, the character sheet and the map matrix.** The almost-human head appears
above the name; transparent figures are in `assets/ui/character-fullbody/female/`, using
the [shared extraction recipe](../sex-selection/README.md). This archive's original art
and five heads are unchanged. `.gdignore` excludes references from imports; runtime PNGs
use lossless, mipmaps off and alpha-border fix on. On the map, saved female sex selects a
separate gait set for the current/cosmetic form.

Пересборка из корня репозитория / Rebuild from the repository root (Python, Pillow, numpy):

```powershell
python tools/prepare_female_character_assets.py
python tools/prepare_female_character_assets.py --check
```

Скрипт использует только копии из `sources/` и `recipe.json`, не обращается к `.codex`
или сети. Проверка подтверждает SHA, точное совпадение RGB и полнофигурных вырезок,
повторяемость масок/иконок, размеры и прозрачные поля. Подписи превью используют Arial
из Windows, если он установлен; иначе — шрифт Pillow. Это не влияет на ассеты голов.

The script reads only workspace `sources/` and `recipe.json`, never `.codex` or the
network. Checks cover hashes, source-exact RGB/fullbody crops, reproducible masks/icons,
dimensions and transparent borders. Preview labels use Windows Arial when available,
otherwise Pillow's font; this does not affect the head assets.
