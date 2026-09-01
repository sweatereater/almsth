# QA-отчёт: интеграция ночного задания 2026-09-01

## Итог

Интеграционный срез принят: сфокусированные проверки, normal-renderer preview matrix,
авторитетные smoke/soak и один полный nightly-цикл завершились с кодом `0`.
Подтверждённых блокеров или незакрытых дефектов нет. Формат сохранений теперь имеет
строгую границу v16; все проверки выполнялись в изолированных временных каталогах.

Реализованный срез включает матрицу map-персонажа 10×4, transient-анимацию шага,
общий множитель автоматической скорости ×1.2, независимые `attack_type`/`grip`,
двуручный ghost-slot и `old_claymore`, двенадцать модулей лагеря и Build-модал,
новую шкалу Soul Level, строгий save boundary v16, паритет RU/EN и обновлённую wiki.

## Ассеты и ImageGen

- Runtime-матрица содержит десять наборов по четыре кадра 264×264 RGBA8. Девять
  наборов созданы из утверждённых локальных references; защищённый
  `female/ghoul` подключён без изменения. Генеративные попытки по наборам:
  `female/skeleton=2`, `female/zombie=2`, `female/revenant=2`,
  `female/almost_human=1`, пять мужских наборов — по `2`. Во всех случаях лимит
  трёх попыток не достигнут. Точные prompts, candidates, tool-result IDs и выбор
  зафиксированы в
  [`art/characters/map-runtime/2026-09-01/imagegen-prompts.md`](../../art/characters/map-runtime/2026-09-01/imagegen-prompts.md).
- Для каждого сгенерированного gait-набора применяется одна общая нормализационная
  шкала: максимальная разница scale между четырьмя кадрами `0`, разница contact
  baseline `0`; anchor `(132,260)`, четыре разных file- и silhouette-хэша.
- `old_claymore` создан за одну попытку. Финал — 132×132 RGBA8 с прозрачным
  отступом; автоматическая редукция проверена для 44/64 logical и 33/48 physical,
  а RU/EN варианты списка сняты normal renderer.
- Camp isolation использовал ровно три ImageGen-попытки: попытки 1 и 2 отклонены
  из-за перестановки/перекрытия мебели; попытка 3 (`4×3 atlas`, SHA256
  `8541B849007EDB9C2D1B409040F365321DC79A64FAD2B3FD66634AE48B662F7C`)
  принята. Четвёртой попытки не было. Полные дословные prompts, ordinals, call IDs,
  размеры и verdicts находятся в
  [`art/concepts/camp/2026-09-01/PROMPTS.md`](../../art/concepts/camp/2026-09-01/PROMPTS.md).
- Лагерь собирается без furnished-minus-empty subtraction: один 818×480 RGB8 base
  и 12 tight RGBA layers. Independence gate прошли `12/12`; у каждого слоя ровно
  одна непересекающаяся atlas-cell, собственные shadow/local-light и документированный
  draw rect. Независимый visual post-audit обнаружил detached orange arc у `whetstone`
  и 11-pixel orphan с одиночными пикселями у `crusher`; recipe теперь детерминированно
  оставляет крупнейший 8-connected alpha component. После удаления чужих компонентов
  утверждены действительно tight rect `crusher=39,243,177,178` (SHA256
  `539579729599B0925DCEDF62BDF09CBBFB477D3A393A332956D309340E1A1E24`) и
  `whetstone=217,274,131,96` (SHA256
  `E0EBFBA632EA769130420F310CBC93DF46315E47C44AC4CD89F1858C945BBBA5`), без изменения
  позиции оставшегося реквизита в композиции. Старая death-композиция отделена в
  `assets/art/death-camp-background.png`, SHA256
  `84D4ABB92AD0610CFF86C0947718FB2C6825CC52A4F6C2856AA790870D28ECCF`.
- Защищённые female-ghoul SHA256 после работ:
  `walk-00=85944C51018691ADBE3A6BCB40898EBB390ADD4FC7243531D2746690C6DD108B`,
  `walk-01=03222F39A2D9E52683CF8B6C7DC6940C717C1830E3F572D70331D58D7980A2E0`,
  `walk-02=716FCF5DB51D902514313F21440E22BA9BD9FFAC14553E855BB1A3D4C5D1DC1B`,
  `walk-03=DB5EC118EB6986BC38385A351B473A96B45F29C1F153F5BA041A4C71123BAF61`.
  Десять утверждённых 264×704 fullbody-файлов не переписывались.

Asset recipes и их проверки:

| Команда | Код | Результат / лог |
|---|---:|---|
| `python tools/prepare_nightly_character_assets.py --check` | 0 | 9 gait-наборов + Claymore byte-identical; staging только в system temp; `.tmp/nightly/asset-generator-check-20260901/character-assets-check-system-temp.log` |
| `python tools/prepare_character_sex_assets.py --check` | 0 | source hashes, masks, canvases, anchors и head alignment; `.tmp/nightly/asset-generator-check-20260901/character-sex-assets-check.log` |
| `python tools/prepare_nightly_camp_assets.py --check` | 0 | byte-identical base/layers/manifest + strict orphan/component gate; `.tmp/nightly/remediation-20260901/camp-check.log` |
| `Godot --headless --editor --path . --import --quit` | 0 | штатный повторный импорт очищенных crusher/whetstone в `.ctex`; `.tmp/nightly/remediation-20260901/godot-force-import.log` |
| `Godot --headless --path . --script res://tests/run_nightly_contract_test.gd` | 0 | source/import dimensions, one-component output, exact removed-leak records, runtime asset contracts; `.tmp/nightly/remediation-20260901/nightly-contract-post-import.log` |

## Поведенческие проверки

Все команды Godot ниже запускались копией Godot 4.7.2 с private
`APPDATA`, `LOCALAPPDATA`, `TEMP` и `TMP`.

| Команда | Код | Итог / лог |
|---|---:|---|
| `Godot --headless --path . --script res://tests/run_save_slots_test.gd` | 0 | `SAVE SLOTS TEST PASSED`; exact state-only/full-run schema, missing skill, extra attribute/state, missing procedural rooms, impossible hand/camp dependencies, primary/bak/tmp bytes и live Main state reject exactly, valid backup fallback read-only; `.tmp/nightly/remediation-20260901/save-slots-strict-schema-final.log` |
| `Godot --headless --path . --script res://tests/run_exact_resume_test.gd` | 0 | v16 round-trip плюс direct validators для exact envelope/hearing/memory, procedural rooms и fixed-floor exception; `.tmp/nightly/remediation-20260901/exact-resume-strict-schema-1.log` |
| `Godot --headless --path . --script res://tests/run_ability_test.gd` | 0 | Magic Missile сбрасывает активный `≤0.10 s` map transient до cast без второго хода; `.tmp/nightly/remediation-20260901/ability-focused.log` |
| `Godot --headless --path . --script res://tests/run_dungeon_viewport_test.gd` | 0 | 1000 реальных шагов через Main: точные cell/turn/RNG/save cadence и отсутствие drift; `.tmp/nightly/remediation-20260901/dungeon-viewport-focused-2.log` |
| `Godot --headless --path . --script res://tests/run_character_sex_test.gd` | 0 | RU/EN hint и sheet/map sex×form runtime hooks; `.tmp/nightly/remediation-20260901/character-sex-focused.log` |
| `Godot --headless --path . --script res://tests/run_camp_build_panel_test.gd` | 0 | blocking modal, scroll/focus/input/no-click-through/live refresh; `.tmp/nightly/remediation-20260901/camp-build-panel-focused.log` |
| `Godot --headless --path . --script res://tests/run_skill_tree_ui_test.gd` | 0 | строгий v16 UI state; `.tmp/nightly/focused-post-audit-20260901/skill-tree-ui.log` |
| `Godot --headless --path . --script res://tests/run_nightly_contract_test.gd` | 0 | 1H/2H transaction, ghost-slot, Claymore, auto delays, 1000 visual steps/no drift/state mutation и asset contracts; `.tmp/nightly/remediation-20260901/nightly-contract-strict-schema-1.log` |
| `Godot --headless --path . --script res://tests/run_regression_test.gd` | 0 | strict disk boundary и сохранённая permissive семантика прямого setup helper; `.tmp/nightly/remediation-20260901/regression-strict-schema-2.log` |
| `Godot --headless --path . --script res://tests/run_hearing_contact_test.gd` | 0 | runtime hearing paths совместимы с точной двух-/трёхключевой snapshot-схемой; `.tmp/nightly/remediation-20260901/hearing-strict-schema.log` |
| `Godot --headless --path . --script res://tests/run_room_door_test.gd` | 0 | procedural rooms и 395-step AUTO; `.tmp/nightly/remediation-20260901/room-door-strict-schema.log` |

Save-тесты используют только фиксированные корни внутри `.tmp/nightly`; cleanup
проверяет resolved absolute path до удаления. Проверены несовместимые primary/bak/tmp,
различие explicit и autogenerated family ID, отсутствие мутации runtime/реальных файлов,
строгая загрузка v16 и контролируемый отказ v15/future/corrupt.

Wiki/reference проверки:

| Команда | Код | Лог |
|---|---:|---|
| `Godot --headless --path . --script res://tools/generate_wiki.gd -- --check` | 0 | `.tmp/nightly/wiki-focused-final-20260901/generate-wiki-check-final.log` |
| `Godot --headless --path . --script res://tests/wiki_contract_test.gd` | 0 | `.tmp/nightly/wiki-focused-final-20260901/wiki-contract-final.log` |
| `npm run build` в `docs/wiki-site` | 0 | `.tmp/nightly/wiki-build-20260901/build-final.log` |
| `npm run check` в `docs/wiki-site` | 0 | `.tmp/nightly/wiki-build-20260901/check-final.log` |

Generated reference содержит 24 предмета и 12 camp entries; для оружия экспортируются
`attack_type` и `grip`.

## Normal-renderer visual QA

Финальная визуальная приёмка выполнена не headless: Godot Compatibility/OpenGL 3.3,
NVIDIA GeForce RTX 4060 Ti, private environment. Каноническая команда каждого batch:

```powershell
Godot_v4.7.2-stable_win64.exe --path . --script res://tests/capture_nightly_preview.gd -- --batch=<map|character|camp>
```

| Batch | Код | Raw | Содержание | Лог |
|---|---:|---:|---|---|
| map | 0 | 162 | 10 наборов idle/mid-step, zoom 44/66/88, 1280×720/960×540, mirror/direction/door/chest/edge/snap | `.tmp/nightly/map-recapture-shared-scale-20260901/map-capture.log` |
| character | 0 | 80 | 10 Character Sheet вариантов RU/EN, оба окна, zoom invariance; все hands/ghost/Claymore states | `.tmp/nightly/capture-character-final-20260901/character-capture.log` |
| camp | 0 | 88 | post-reimport empty, каждый модуль, пары, mixed/all, modal top/bottom и death before/after RU/EN | `.tmp/nightly/remediation-20260901/camp-capture-normal-post-import.log` |

Итого: `330` raw PNG, `0` capture failures. Команда
`python tools/build_nightly_contact_sheets.py` создала `16` вторичных contact sheets
из `330` placements, код `0`; лог
`.tmp/nightly/remediation-20260901/contact-sheets-post-import.log`. Независимый hash-аудит не нашёл
missing, duplicate или unmanifested raw-файлов; каждый raw использован ровно один раз.
Пути: `.tmp/nightly/previews-20260901/raw/` и
`.tmp/nightly/previews-20260901/contact-sheets/`.

Sidecar logs рядом с preview root синхронизированы с фактическими totals:
`map=162`, `character=80`, `camp=88`, `raw=330`, `sheets=16`; старые значения
`150/64/302` больше не выдаются как текущая evidence. Post-import mtime, hashes,
component counts и raw totals собраны в
`.tmp/nightly/remediation-20260901/camp-post-import-audit.log`.

## Независимый post-audit remediation

Независимый QA обнаружил три поведенческих/контрактных пробела, которые прежние зелёные
suites не покрывали. Все исправлены сфокусированными регрессиями:

- v16 `state_only` теперь проверяет присутствие, типы, диапазоны и семантические связи
  всех обязательных полей до `restore_save_data`; отсутствующий `soul_level`, неверный
  двуручный/offhand и нарушенные `writing_set/workbench`, `kettle/campfire` отклоняются
  без изменения live Main state или любого байта primary/bak/tmp. Прямой permissive
  restore helper оставлен только для тестовой/legacy setup-санитизации, не disk boundary;
- независимый functional probe затем обнаружил, что `full_run` допускал отсутствующий
  канонический skill и лишний attribute, а обе формы v16 допускали лишние top-level keys.
  Текущая граница требует точное множество полей RunState и точные canonical keys для
  `attributes`, `resources`, `skill_levels`, но намеренно не запрещает sparse/dynamic
  inventory/loadout/marks/cooldowns/statuses. Дисковые и Main-регрессии подтверждают
  zero mutation для missing `ears`, extra attribute и extra state key;
- snapshot format 2 теперь требует точный семиполевой envelope, exact hearing
  (`attack_memories`, `event_revision`) и exact memory (`uid`, `pos`,
  `expires_after_turn`). Процедурный этаж обязан содержать `rooms`, потому что это часть
  навигационного состояния генератора; канонический `fixed_layout` floor 90 по-прежнему
  валиден без этого procedural-поля. Corrupt primary при валидном backup загружает backup
  read-only/write-locked и не переписывает ни один файл family;
- `magic_missile` использует тот же presentation reset, что физические атаки;
- 1000-step contract проходит через реальный Main action/round/presentation path и
  сравнивает только намеренно изменяемый `total_turns`, сохраняя точные RNG и остальные
  serializable поля.

Visual QA дополнительно поймал stale Godot import cache после deterministic PNG
regeneration. Финальные captures сделаны только после штатного editor reimport; nightly
asset contract теперь сравнивает runtime `Texture2D` dimensions с tight source, чтобы такой
cache mismatch не мог снова пройти незамеченным. Независимый visual reviewer повторно
проверил fresh single/pair/all captures, новые rect/hash/component records и выдал PASS:
`0` оставшихся визуальных дефектов.

## Final functional QA remediation addendum (06:56 MSK)

После visual PASS независимый functional QA выполнил отдельный exhaustive strict-v16
audit. Он подтвердил дополнительные accepted-then-change payloads, которые прежние
зелёные suites не моделировали. В одном сериализованном remediation-цикле закрыты:

- связь `floor_data` с `state.current_floor`: только этаж 90 может быть fixed-layout и
  обязан хранить полный boss/door block; обычные этажи обязаны хранить 2–3 разные
  канонические комнаты с непустыми полными cell-компонентами и уникальными landmark;
- соответствие boss-defeated состоянию permanent milestone, tail award и trophy/mural,
  включая повторный вход на очищенный этаж 90;
- неизменяемые generated enemy stats/capabilities по id и глубине, допустимые enemy
  ability cooldowns, точная цель сохранённой preparation, границы ресурсов chest и
  непересечение player/enemy/item/landmark cells. Runtime movement не может поставить
  врага на сундук или landmark через исключение occupied goal;
- общая semantic-проверка RunState для `full_run` и `state_only`: точные evolution
  thresholds, current/highest form, lifetime с отдельным учётом permanent unlock после
  смерти, stage/prerequisites навыков, доступность cooldown в текущей форме, remainder
  regeneration/mana, status и camp-preparation compatibility;
- hearing memory только для доступного скрытого живого врага: текущая enemy position,
  TTL ровно `turn+1`, достаточный положительный event revision и отсутствие памяти без
  `has_hearing`;
- точные metadata/envelope policy: обязательные `updated_at`,
  `lifetime_souls_earned`, `save_policy`, только `full_run` содержит
  `publication_order`; single-file legacy boundary принимает только строгий
  `state_only`, поэтому full-run snapshot нельзя незаметно превратить в base-save.

Прямой `restore_save_data` намеренно остаётся permissive setup helper; все disk/Main
пути сначала проходят строгий validator и при отказе сохраняют live session и
primary/bak/tmp byte-for-byte. Corrupt primary с валидным backup продолжает читать
backup без побочной записи.

Свежая focused-матрица после последней source-правки выполнена Godot 4.7.2 с private
`APPDATA`, `LOCALAPPDATA`, `TEMP`, `TMP`; все exit-файлы содержат `exit_code=0`:

| Проверка | Итог / лог |
|---|---|
| save slots | `SAVE SLOTS TEST PASSED`; `.tmp/nightly/remediation-20260901/save-slots-remediation-final.log` |
| exact resume | `EXACT RESUME TEST PASSED`; `.tmp/nightly/remediation-20260901/exact-resume-remediation-final.log` |
| hearing | `HEARING CONTACT TEST PASSED`; `.tmp/nightly/remediation-20260901/hearing-remediation-final.log` |
| content/preparation | `CONTENT STAGE1 TEST PASSED`; `.tmp/nightly/remediation-20260901/content-stage1-remediation-final.log` |
| room/door | `ROOM DOOR TEST PASSED`, 395 AUTO steps; `.tmp/nightly/remediation-20260901/room-door-remediation-final.log` |
| regression | `REGRESSION TEST PASSED`; `.tmp/nightly/remediation-20260901/regression-remediation-final.log` |
| nightly contract | `NIGHTLY CONTRACT TEST PASSED`; `.tmp/nightly/remediation-20260901/nightly-contract-remediation-final.log` |
| status/cooldown | `STATUS COOLDOWN TEST PASSED`; `.tmp/nightly/remediation-20260901/status-cooldown-remediation-final.log` |
| ability | `ABILITY TEST PASSED`; `.tmp/nightly/remediation-20260901/ability-remediation-final.log` |
| Main/map integration | `DUNGEON VIEWPORT TEST PASSED`; `.tmp/nightly/remediation-20260901/dungeon-viewport-remediation-final.log` |
| camp modal | `CAMP BUILD PANEL TEST PASSED`; `.tmp/nightly/remediation-20260901/camp-build-panel-remediation-final.log` |
| Soul Level | `SOUL LEVEL TEST PASSED`; `.tmp/nightly/remediation-20260901/soul-level-remediation-final.log` |
| independent extended repro | все corruption cases `accepted=false`; `.tmp/nightly/remediation-20260901/strict-extended-probe-remediation-final.log` |
| pre-final smoke | `SMOKE TEST PASSED`; `.tmp/nightly/remediation-20260901/smoke-remediation-prefinal.log` |

Независимый closed-scope recheck завершён PASS. Evidence root:
`.tmp/nightly/independent-final-closed-scope-20260901-065754`. Original, strict и
extended probes завершились с кодом `0`: canonical baseline принят, все 29 ранее
подтверждённых corruption cases имеют `accepted=false`. Save-slots, exact-resume,
hearing, room-door (395 steps), regression, nightly-contract, status-cooldown,
content-stage1, ability, dungeon-viewport/Main1000 и smoke также завершились кодом `0`;
скрытых parse/assert/script failures нет. Независимый `git diff --check` — код `0`,
только ожидаемое предупреждение о CRLF для существующего dirty doc.

Следующий раздел сохраняется только как evidence предыдущего цикла. Новый
авторитетный smoke→soak→full nightly→diff-check запускается после этого PASS и будет
записан отдельным финальным addendum без последующих runtime/source/test изменений.

## Предыдущий авторитетный цикл (заменяется post-audit прогоном)

После последнего изменения (`candidates/.gdignore`) smoke и soak были заново запущены
одной и той же private-копией runtime. Перед запуском заданы:

```powershell
$env:APPDATA=(Resolve-Path '.tmp/nightly/final-authoritative-20260901/appdata').Path
$env:LOCALAPPDATA=(Resolve-Path '.tmp/nightly/final-authoritative-20260901/localappdata').Path
$env:TEMP=(Resolve-Path '.tmp/nightly/final-authoritative-20260901/temp').Path
$env:TMP=$env:TEMP
```

| Команда | Код | Результат / лог |
|---|---:|---|
| `.tmp/nightly/final-authoritative-20260901/runtime/Godot_v4.7.2-stable_win64_console.exe --headless --path . --log-file .tmp/nightly/final-authoritative-20260901/smoke-engine.log --script res://tests/smoke_test.gd` | 0 | pre-remediation `SMOKE TEST PASSED`; `.tmp/nightly/final-authoritative-20260901/smoke.log` |
| `.tmp/nightly/final-authoritative-20260901/runtime/Godot_v4.7.2-stable_win64_console.exe --headless --path . --log-file .tmp/nightly/final-authoritative-20260901/soak-engine.log --script res://tests/soak_test.gd` | 0 | `SOAK TEST PASSED: 500 floors, 254 Cradles, 1200 random actions`; `.tmp/nightly/final-authoritative-20260901/soak.log` |
| `pwsh -NoProfile -File .\tools\run_nightly.ps1` | 0 | Full mode, `15/15` фаз, без timeout/errors, `protected_data_unchanged=true`; `.tmp/nightly/20260901-045308-28996-6b8fb626/summary.json` |

Полный nightly включает settings, prepare/resume/death-resume/auto для seeds
`812`, `10007`, `90001`, затем smoke и soak. Wrapper log:
`.tmp/nightly/final-authoritative-20260901/run-nightly.log`; подробные команды и private
environment каждой фазы сохранены в соответствующих `command.json` внутри run root.

## Авторитетный post-remediation цикл

Первый full-wrapper запуск после strict remediation сохранён как диагностическое
evidence: `.tmp/nightly/20260901-070348-16472-4cfb8595/summary.json`. `settings`
прошёл, а `812-prepare` корректно остановился с exit `1`: nightly fixture всё ещё
подменял immutable generated enemy stats, которые новая v16-граница обязана отклонять.
Protected user data остались неизменными. Исправлен только fixture
`tests/nightly_scenarios.gd`: он теперь сохраняет generated id/depth stats/capabilities
и выбирает позиции вне items/landmarks. Root
`.tmp/nightly/targeted-nightly-fixture-20260901` подтверждает exit `0` для всех
`prepare/resume/death-resume/auto × 3 seeds` перед повторным полным запуском.

После этой последней runtime/test правки авторитетная последовательность повторена
сначала direct-командами на одной private runtime-копии, затем одним полностью зелёным
wrapper-циклом:

| Команда | Код | Результат / лог |
|---|---:|---|
| `.tmp/nightly/final-post-remediation-20260901/runtime/Godot_v4.7.2-stable_win64_console.exe --headless --path . --log-file .tmp/nightly/final-post-remediation-20260901/direct-smoke-post-fixture-engine.log --script res://tests/smoke_test.gd` | 0 | `SMOKE TEST PASSED`; `.tmp/nightly/final-post-remediation-20260901/direct-smoke-post-fixture.log` |
| `.tmp/nightly/final-post-remediation-20260901/runtime/Godot_v4.7.2-stable_win64_console.exe --headless --path . --log-file .tmp/nightly/final-post-remediation-20260901/direct-soak-post-fixture-engine.log --script res://tests/soak_test.gd` | 0 | `SOAK TEST PASSED: 500 floors, 254 Cradles, 1200 random actions`; `.tmp/nightly/final-post-remediation-20260901/direct-soak-post-fixture.log` |
| `pwsh -NoProfile -File .\tools\run_nightly.ps1` | 0 | Full mode, `15/15` фаз PASS, `0` phase errors, `protected_data_unchanged=true`; `.tmp/nightly/20260901-070959-11208-665788f4/summary.json` |

Финальный wrapper root:
`.tmp/nightly/20260901-070959-11208-665788f4`; human-readable summary —
`.tmp/nightly/20260901-070959-11208-665788f4/summary.md`, wrapper stdout —
`.tmp/nightly/final-post-remediation-20260901/run-nightly-post-fixture.log`.
Все 15 фаз имеют exit `0`, timeout отсутствуют. Единственное известное предупреждение
каждой Godot-фазы — недоступный Windows root certificate store; test-only image-load
warnings не являются parse/assert/runtime errors. Этот раздел добавлен после успешного
runtime-цикла как doc-only запись; после цикла runtime, assets и tests не менялись.

## Изменённые области и остаточный риск

Изменения сосредоточены в `scripts/game`, `scripts/system`, `scripts/ui`, localization,
сфокусированных tests, runtime/source assets и recipes, `README.md`, `docs`, wiki и
generated reference/site output. Существующий dirty baseline, включая прежние
sex-selection/fullbody/female-ghoul изменения, не сбрасывался и не нормализовался.

Подтверждённых блокеров нет. Неблокирующее сообщение Windows test-host — отсутствие
доступа к root certificate store; asset contracts также намеренно используют
`Image.load_from_file`, из-за чего headless logs предупреждают, что этот test-only путь
не предназначен для export runtime. Не выполнялись export/install, проверка физического
геймпада/сенсорного устройства или публикация; финальная визуальная QA выполнена raw
снимками normal renderer, а не headless-кадрами.
