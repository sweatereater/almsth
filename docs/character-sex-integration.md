# Выбор пола / Sex selection

Выбор пола и все десять новых полнофигурных образов подключены. Две почти человеческие
головы смотрят в разные стороны над полем имени. Художественные оригиналы не перерисовывались.

Sex selection and all ten new full-body figures are connected. Two almost-human heads
face opposite directions above the name input. The approved artwork was not repainted.

- Создание: женская/мужская карточка над именем, RU/EN, мышь, touch,
  клавиатура и D-pad/A; выбранный пол и фокус показаны отдельно.
- `RunState.character_sex` обязателен и хранится в state-only и полном v17-сохранении.
  Миграции v16→v17 нет: v16 показывается заблокированным, но остаётся доступным для
  подтверждённого удаления. Отсутствующее или некорректное поле v17 отклоняет снимок.
- Смерть не меняет пол. Лист выбирает пол × косметическую/текущую форму.
- Выбор пола выбирает набор кадров на карте, но не влияет на RNG, характеристики,
  логическое движение, число ходов, сохранения или правила прогрессии.
- Прежняя смена косметического облика на карте сохраняется. Старые изображения остаются
  защитным fallback на случай отсутствующего ресурса; все новые файлы поставлены.

Creation supports RU/EN, mouse, touch, keyboard and D-pad/A with separate selection and
focus highlights. Both v17 save paths require and retain `character_sex`; there is no
v16→v17 migration. A v16 row remains visible but locked and deletable, while a missing or
invalid v17 value rejects the snapshot. Death retains sex. The sheet and map both resolve
sex × current/cosmetic form. Sex changes presentation only: RNG, logical movement, turns,
stats, saves and progression are unchanged.
Legacy art remains only a missing-resource fallback; all new resources are delivered.

Runtime-файлы / Runtime resources:

- `assets/ui/character-fullbody/{female,male}/form-*.png`: по пять форм,
  264×704 RGBA, crop `(7,8,250,692)`, опора `(132,696)`.
- `assets/dungeon/player-forms/{female,male}/{form}/walk-00..03.png`: матрица 10×4,
  264×264 RGBA8, минимум 4 px альфа-поля, опора `(132,260)`. Старый
  `assets/dungeon/female-ghoul/frames/` остаётся источником неизменённого female/ghoul.
- `assets/portraits/male/form-almost-human.png`: 264×264 RGBA;
  готовый женский портрет уже находится в `assets/portraits/female/`.

По разрешению пользователя фигуры и мужская голова локально вырезаны из утверждённых
оригиналов, без генерации и перерисовки. Женские оригиналы: `art/characters/female/sources/`.
Утверждённый мужской лист скопирован без изменения в
`art/characters/male/sources/five-stages-approved.png`. Женские головы и прежние игровые
PNG сохранены без изменения. [Рецепт, SHA, маски и превью](../art/characters/sex-selection/README.md).

With the user's permission, figures and the male head were locally extracted from approved
originals without generation or repainting. The unchanged male lineup is archived in the
project. Existing female heads and legacy gameplay PNGs remain unchanged. Figures use
264×704 RGBA, crop `(7,8,250,692)` and foot anchor `(132,696)`. Heads use 264×264 RGBA;
only the creation UI flips the male head. The shared archive stores hashes and the recipe.

Map presentation lazy-loads only the active four-frame set. A step begins at the previous
cell, changes contact→transition at 50%→next contact, and lasts
`min(0.10, 0.75 × expected_next_interval)`. A new step snaps unfinished presentation and
never queues. Right mirrors the canonical three-quarter-left view; vertical movement keeps
the last horizontal facing. Attack, dash, floor transition, load, death, base entry, and
real or cosmetic form changes reset presentation without creating a turn.

## Проверка / Verification

`tests/character_sex_test.gd` проверяет создание RU/EN, native D-pad/A/Enter/Space,
обязательное поле `character_sex`, строгий v17 reject без мутации, смерть и выбор
sex×display-form. `tests/nightly_contract_test.gd` проверяет все 40 map-кадров,
RGBA8/264×264, минимум 4 px alpha-поля, общий масштаб четырёх поз внутри каждого набора,
опору `(132,260)` и четыре разные silhouette SHA.
`tools/prepare_nightly_character_assets.py --check` собирает результат только в системном
временном каталоге и побайтово сверяет runtime,
не перезаписывая рабочие ассеты.

Нормальный OpenGL-захват `tests/capture_nightly_preview.gd` (не `--headless`) сохраняет
для окон 1280×720 и 960×540: десять вариантов Character Sheet на обоих языках, проверку
неизменности листа при zoom 44/66/88 и состояния рук, включая двуручный UI-призрак и
Старый клеймор в 44px-списке. Текущий character batch: 80 raw, 0 failures. Полная матрица
лежит в `.tmp/nightly/previews-20260901/raw/`, вторичные листы — в
`.tmp/nightly/previews-20260901/contact-sheets/`. Точные команды и итоговые smoke/soak/
nightly результаты находятся в [отчёте 01.09.2026](qa/2026-09-01-nightly-integration.md).

The focused suites cover creation input, strict v17 persistence, death and sex×display-form
selection. The asset contract checks all forty frames, shared per-set scale, padding,
anchors and distinct silhouettes. The deterministic `--check` path writes only a system
temporary copy before byte-comparing runtime files. Normal-renderer captures cover both
locales and windows, all ten Character Sheets, zoom invariance and all hand states; the
settled character batch contains 80 raw images with zero harness failures.
