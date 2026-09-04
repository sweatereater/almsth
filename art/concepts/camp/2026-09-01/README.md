# Лагерь демо — концепт 01.09.2026 / Demo camp concept

Статус: утверждённая пара v2 для base/первых 12 слоёв и независимый master Хранилища.
Status: approved v2 pair for the base/first 12 layers plus an independent Storage master.

## Изображения / Images

- [Обжитый лагерь / Furnished camp](camp-furnished-v2.png) — 1639×959, RGB; дробилка целиком внутри кадра.
- [Пустая архитектура / Empty architecture](camp-empty-v2.png) — 1639×959, RGB; получена редактированием обжитого v2.
- [Хранилище / Storage chest](storage-chest-master.png) — 1536×1024 RGBA; свежий оригинальный transparent cutout.
- [Точные промпты / Exact prompts](PROMPTS.md).

Версии v1 сохранены как история. В runtime используется только v2.
Versions v1 are retained as history; runtime uses v2 only.

Независимая визуальная проверка v2: все исторические 12 модулей представлены; обрезание дробилки
исправлено; новых существенных дефектов концепта не обнаружено. Проверены исходные
изображения и равенство размеров. Runtime-комбинации сохранены в `runtime-review/`,
а итоговая визуальная матрица перечислена в датированном QA-отчёте.
Independent v2 visual review: all 12 modules represented, crusher clipping resolved,
no new major concept defects. Native images and matching dimensions were checked;
runtime-scale composites live in `runtime-review/`; the dated QA report lists the final matrix.
The thirteenth Storage layer is an independently generated original, not a crop from the
historical 4×3 isolation atlas.

Оба изображения созданы встроенным инструментом image_gen; CLI/API-скрипты не использовались.
Исходные результаты сохранены также в стандартной папке generated_images Codex.
Both images were made with the built-in image_gen tool, without CLI/API scripts.
These files preserve the native generated outputs.

## Замысел / Direction

Лагерь постепенно обживается: каждая постройка приносит собственное окружение.
Верстак — вместе с табуретом и инструментами, кресло — со шкурой и подушкой,
ткацкий уголок — с зеркалами, тканями и рисунками пальто на стене.
Центральный проход остаётся свободным; тёплый очаг связывает зону отдыха,
а рабочие станции сгруппированы у стен. Котёл стоит над тем же костром.
Лежанка опирается на постоянный каменный выступ.

Each building arrives with its own associated dressing: stool and tools for the workbench,
hide and cushion for the rocker, mirrors, textiles and wall coat sketches for the tailoring area.
Keep a clear central route, a warm hearth grouping and wall-side workshops.
The cauldron belongs over the existing hearth. The bed rests on a permanent stone ledge.

## Полный концептуальный список демо / Complete proposed demo list

Все тринадцать объектов имеют стабильные runtime ID. Дробилка, Точильный камень,
Ритуальный стол, Котёл и Хранилище остаются интерактивными услугами; остальные декоративны.
All thirteen objects have stable runtime IDs. Crusher, Whetstone, Ritual Table, Kettle and
Storage retain interactive services; the others are decorative.

| Модуль / Module | Статус / Status | Что появляется вместе / Associated dressing |
|---|---|---|
| Костёр / Campfire | Уже в игре / Existing | Каменное кольцо, дрова, пламя; свет отдельно / Stone ring, logs, flame; separate light |
| Походный котёл / Kettle | Уже в игре / Existing | Чан над костром, подвес, черпак / Cauldron over hearth, support, ladle |
| Тканевые нары / Bunk | Уже в игре / Existing | Матрас, подушки, одеяло, ткань ниши / Mattress, pillows, blanket, alcove textile |
| Дробилка / Crusher | Уже в игре / Existing | Пресс, собственное основание и кучка материалов / Press, its base and material scraps |
| Точильный камень / Whetstone | Уже в игре / Existing | Круг, станина, ведёрко, подстилка / Grinding wheel, frame, bucket, mat |
| Ритуальный стол / Ritual table | Уже в игре / Existing | Стол, символ, свечи, коврик / Table, sigil, candles, rug |
| Мурал / Mural | Уже в игре / Existing | Граффити победы над Минотавром прямо на кладке / Minotaur victory graffiti on masonry |
| Верстак / Workbench | Runtime, бесплатно / Runtime, free | Деревянный стол, удобный табурет, обычные инструменты / Wooden table, comfortable stool, basic tools |
| Письменный набор / Writing and papermaking set | Runtime, бесплатно; требует Верстак / Runtime, free; requires Workbench | Отдельно на верстаке: перо, чернила, бумага, принадлежности изготовления, сушка листов / Separate tabletop set with writing, ink and paper-making supplies |
| Ткацкая область / Textile area | Runtime, бесплатно / Runtime, free | Манекен, два зеркала, нитки, ткань, эскизы пальто / Mannequin, two mirrors, thread, fabric, wall coat sketches |
| Кресло-качалка / Rocking chair | Runtime, 30 дерева, raw Soul +1 / Runtime, 30 wood, raw Soul +1 | Кресло рядом с огнём, шкура у ног, подушка / Chair beside fire, hide rug, cushion |
| Музыкальный аппарат / Record player | Runtime, бесплатно / Runtime, free | Деревянный проигрыватель, пластинка, металлический раструб, запас записей / Wooden turntable, record, metal horn, record storage |
| Хранилище / Storage chest | Runtime, 20 дерева, 4 камня, 3 ткани / Runtime, 20 wood, 4 stone, 3 cloth | Низкий закрытый сундук из тёмного дерева с состаренным железом / Low closed dark-wood chest with aged iron |

Котёл требует Костёр; Мурал скрыт до хвоста. Все зависимости проверяются до цены.
Kettle requires Campfire; Mural is hidden until the tail. Dependencies validate before cost.

## Runtime-разделение на слои / Runtime layer preparation

1. Постоянный фон содержит только своды, кладку, пол, потолочный люк, его свет,
   каменный выступ и ступени.
2. Каждый из 13 модулей имеет отдельный tight RGBA8-слой со своими мелкими предметами
   и настенным декором.
3. Слой владеет только своим реквизитом, контактной тенью и локальным светом.
4. Письменный набор требует Верстак; Котёл требует Костёр — это действующие правила модели.
5. Свет и отражения не должны раскрывать отсутствующий соседний модуль.
6. Мурал и эскизы пальто — разные накладки; в пустой базе их нет.

The base contains architecture only. Each of the thirteen modules has one tight RGBA8 layer
which owns only its props, contact shadow and local light. Writing Set requires Workbench;
Kettle requires Campfire. No layer may reveal pixels from an absent neighbor.

## Производственный рецепт / Production recipe

- Оба утверждённых v2-холста 1639×959 нормализуются отдельно: crop `x=1..1636`
  удаляет один пиксель слева и два справа, затем строка 958 детерминированно дублируется
  как строка 959. Общий review-холст — 1636×960; точное уменьшение ×0,5 даёт 818×480.
- База сохраняется RGB8. RGB и форма каждого слоя берутся из принятого третьего
  ImageGen-кандидата — независимого 4×3 atlas. Локальный нейтральный matte, tight crop и
  размещение в утверждённой v2-композиции воспроизводятся детерминированно;
  furnished-empty subtraction не используется. Две предыдущие попытки отклонены из-за
  перестановки/перекрытия реквизита; точные три промпта и результаты записаны в
  [`PROMPTS.md`](PROMPTS.md).
- Для одиночных станций `crusher` и `whetstone` действует строгий component gate:
  после matte остаётся только крупнейший 8-connected alpha cluster. Так удаляются восемь
  detached fragments дробилки (включая 11 high-alpha пикселей в bounds
  `138,456..143,459` общего runtime-холста) и одна чужая оранжевая дуга точильного камня
  (541 high-alpha пиксель, `259,399..310,414`). Оставшийся реквизит не сдвигается;
  итоговые tight rect — `crusher 39,243,177,178`, `whetstone 217,274,131,96`.
- Фиксированный порядок: `mural,bunk,textile_area,workbench,writing_set,ritual_table,crusher,whetstone,campfire,kettle,rocking_chair,record_player`.
- Первые 12 слоёв и base выше сохраняются побайтово. После `record_player` добавлен
  `storage_chest`: свежий master 1536×1024 RGBA с настоящей alpha, SHA-256
  `9FC7C1D961E2A9B0D13EA967866C3C6B4E91422E044D1EB7E894770238C3D1A3`. Это отдельная
  встроенная ImageGen-генерация, а не производная старого 4×3 atlas. Premultiplied-alpha
  Lanczos даёт 108×67, опору `(54,63)` и 4 px нижнего поля; runtime SHA-256
  `E4728C749EEFDDDB02AA123130E7AF6227805F4B5F690D40F30A732C2D3D020F`.
- Итоговый порядок дополняется `storage_chest` после `record_player`. Его camp-local draw
  rect `(224,392,108,67)`, hitbox `(230,395,96,60)`; в `BaseLayout` это соответственно
  `(252,470,108,67)` и `(258,473,96,60)`.
- Точные draw rect, hitbox, SHA и ownership записаны в
  `assets/art/camp-2026-09-01/manifest.json`; воспроизводимый скрипт —
  `tools/prepare_nightly_camp_assets.py`.
- Лагерь и смерть разделены до замены: смерть использует побайтово сохранённый
  `assets/art/death-camp-background.png`, а лагерь — новый base/layers. Каталог концептов
  остаётся исключённым из Godot-импорта через `.gdignore`.

Production review covers empty/full at 818×480 in the 1280×720 virtual window and
613.5×360 at 960×540, each individual module, representative pairs/mixed states, the
Build modal and the separate death composition. Dungeon zoom 44/66/88 does not scale camp art.

Пересборка выполняется `python tools/prepare_nightly_camp_assets.py`; non-writing проверка
`python tools/prepare_nightly_camp_assets.py --check` строит outputs в system temp и
побайтово сравнивает base, 13 layers, review composites и manifest. После write-сборки
перед normal-renderer captures нужен штатный Godot editor import: runtime contract
сравнивает размеры импортированного `Texture2D` с tight source и отклоняет stale cache.
