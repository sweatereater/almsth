# Гуль: прототип ходьбы по карте / Ghoul map walking prototype

Отдельная сцена: `res://scenes/demos/female_ghoul_walk.tscn` (F6), либо из корня проекта:

```powershell
.\tools\run_female_ghoul_demo.ps1
.\tools\run_female_ghoul_demo.ps1 -Locale en -AutoWalk
```

WASD/стрелки — соседняя клетка; 1/2/3 — 44/66/88; Space — автошаг; R — сброс;
L — язык; Esc — выход. Начальный масштаб 88. Стены и сундук блокируют движение;
открытая дверь пропускает. Отпускание направления заканчивает начатую клетку и
сохраняет последнюю опорную позу. Демо не запускает Main, не читает настройки,
не сохраняет данные и не вызывает игровые ходы, бой, сытость или RNG.

Separate F6 scene, with a local RunState and fixed 12×7 review map. WASD/arrows move;
1/2/3 select 44/66/88; Space toggles auto walk; R resets; L switches RU/EN; Esc quits.
The scene starts at 88 and never loads settings or saves, invokes turns or changes
gameplay. Walls/chest block movement; the open door permits passage. Releasing a
direction completes the current cell and holds the last planted contact.

## Кадры / Frames

- Четыре отдельные позы: `assets/dungeon/female-ghoul/frames/walk-00..03.png`.
- 264×264 RGBA8; общий масштаб исходного листа 0,552; регистрация по поясу/тазу;
  холст и нижняя опора `(132, 260)` общие. Фактическая нижняя альфа y258–260;
  минимум четыре прозрачных пикселя по периметру. Детали рецепта — в
  `frames-manifest.json` и `tools/prepare_female_ghoul_walk.gd`.
- Рендерер уменьшает **весь холст** до 40/62/84 px, нижний отступ в клетке 2 px.
  Клетка 88 не означает 88 пикселей непрозрачного рисунка. В окне 960×540 холст
  становится 30/46,5/63 физических px.
- Намеренно шаркающая походка: 4 ключевых кадра ×180 мс = цикл 0,72 с; одна клетка
  за 0,36 с. Это четыре уникальные позы (5,56 смены кадра/с), не восемь нарисованных
  кадров и не плавная скелетная анимация. Колени/ботинки/руки меняют позу; общего
  вертикального покачивания текстуры нет.
- Один ракурс 3/4 влево. Движение вправо использует зеркало, включая асимметрию
  волос и повреждение лица. Вертикальное движение сохраняет последний поворот.
  Вид со спины и полноценный набор направлений пока не сделаны.
- Четыре несжатых кадра занимают 1 115 136 байт ≈1,064 MiB; mipmaps отключены;
  lossless и исправление alpha border включены. Большие источники не импортируются
  благодаря `.gdignore`.

Four 264×264 RGBA8 key poses share one sheet scale and anatomical registration.
The renderer fits the entire canvas into cell-minus-four pixels: 40/62/84, with a
2 px bottom inset. This is a deliberate shuffle, four 180 ms holds per 0.72 s cycle,
not eight painted frames. Limbs change pose; there is no whole-sprite vertical bob.
One left-facing 3/4 view is mirrored for rightward travel (asymmetries also mirror).
Vertical travel retains facing. Four raw RGBA frames total about 1.064 MiB. No
mipmaps; lossless import and alpha-border fix enabled.

## Источники / Provenance

Использован встроенный ImageGen; CLI/API не использовались. Исходная внешность:
`../fullbody/form-ghoul.png` и `assets/portraits/female/form-ghoul.png`.

1. `walk-master.png` — исходная генерация листа. Реальный вывод 1774×887 RGB с
   нарисованной шахматкой; запрос 2048×1024/восемь фаз модель полностью не выполнила.
   Точный запрос — `generation-01-prompt.txt`.
2. `generation-02-prompt.txt` — отклонённая попытка исправить сразу цикл и альфу;
   этот результат не используется в runtime.
3. `walk-alpha.png` — прозрачная версия 1672×941 RGBA, полученная отдельным запросом извлечения
   `generation-03-prompt.txt`. Сохранена исходная альфа, в коде фон не удаляется.
4. Попытки дополнительных фаз `opposite-attempt.png` и
   `contact-opposite-master.png` архивируются с точными одноимёнными `*-prompt.txt`.
   Они не используются: некоторые запросы сохранили RGB-шахматку, а получение альфы
   изменяло нужную позу. Итоговый компактный цикл выбирает исходные позы 1, 5, 7, 6
   из `walk-alpha.png` (нумерация слева направо, сверху вниз).

Built-in ImageGen created the art; no CLI/API fallback. Exact original prompts were
recovered from this feature's previous agent session and preserved verbatim. The
requested eight alternating poses were not delivered reliably. Runtime therefore
uses four original alpha-sheet poses (1, 5, 7, 6), registered/cropped/resized by Godot
without background removal, repainting, colour correction or changing proportions.
Unused experiments are archived, never loaded by the demo. The manifest records the
mechanical recipe; generated source resolution is stated above, not inferred from
the requested resolution.

## Проверка / Review

```powershell
godot --headless --path . --script res://tools/prepare_female_ghoul_walk.gd
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/female_ghoul_walk_test.gd
godot --headless --path . --script res://tests/smoke_test.gd
godot --path . --resolution 960x540 --script res://tests/capture_female_ghoul_walk.gd
godot --path . --resolution 1280x720 --script res://tests/capture_female_ghoul_walk.gd -- --animation
python tools/build_female_ghoul_previews.py
```

Локальный прогон использовал
`.tmp/nightly/stage1-dev/runtime/Godot_v4.7.2-stable_win64.exe`, отдельные APPDATA,
LOCALAPPDATA/TEMP/TMP в `.tmp/ghoul-preview-env/` и `--log-file .tmp/ghoul-*.log`.
Эта копия Godot не меняет каталог исходного редактора. Узкий тест проверяет рамки,
формат/импорт, отдельное изменение ног, переходы опоры/idle, коллизии, 1000 шагов без
дрейфа, все масштабы, передачу текстуры и сохранение default/display-form fallback.

Preview outputs: `builds/previews/female-ghoul/` (ignored by Git and Godot). There are
idle/walk screenshots at 44/66/88 in both 1280×720 and 960×540 windows, extra mirrored,
door/chest/perimeter and English views; dark/light/checker contact sheets; and
`walking-map.gif`, packed from 144 actual 1280×720 Godot frames at 50 ms each.
`walking-map-crop.gif` is a native-pixel crop of those same frames, not a synthetic
animation. The full screenshots remain the source of truth for physical scale.
Copies of the selected review outputs live in the ignored `review/` art subtree.

Глобальные спрайты игрока и настройки масштаба не подменяются. Единственное расширение
общего кода — необязательный последний `player_visual`-аргумент у DungeonViewport и
GameRenderer: текстура, смещение в клетках и зеркало. Пустой словарь сохраняет старый
спрайт формы и hit-flash; отметка под ногами получает то же смещение.
