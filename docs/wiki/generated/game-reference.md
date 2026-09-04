# Сгенерированный справочник

Статус: `implemented`

> Этот файл создаётся из игровых реестров и runtime-констант. Не редактируйте его вручную.
> Ручные страницы объясняют поведение; их ссылки, anchors и статусы проверяет wiki-контракт.

## Формы

| ID | RU / EN | Уровень души | Порог `absorbed_souls` | Цена следующей формы | HP | Урон | Регенерация | Слоты |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `skeleton` | Скелет / Skeleton | 1 | 0 | 10 | 6 | 0 | 0 | jacket, right_hand, left_hand, talisman |
| `zombie` | Зомби / Zombie | 1 | 10 | 14 | 9 | 0 | 1 | jacket, right_hand, left_hand, talisman, feet, head |
| `ghoul` | Гуль / Ghoul | 2 | 24 | 24 | 11 | 1 | 1 | jacket, right_hand, left_hand, talisman, feet, head, body, legs, hands |
| `revenant` | Ревенант / Revenant | 3 | 48 | 32 | 13 | 1 | 1 | jacket, right_hand, left_hand, talisman, feet, head, body, legs, hands, back |
| `almost_human` | Почти человек / Almost Human | 4 | 80 | — | 16 | 2 | 1 | head, body, hands, legs, feet, ring_1, jacket, talisman, back, right_hand, left_hand, ring_2 |

## Навыки

| ID | RU / EN | Форма | Вид | Уровни | Цены | Требования | Ability |
| --- | --- | --- | --- | ---: | --- | --- | --- |
| `almost_double_strike` | Повторный удар / Follow-up Strike | `almost_human` | `passive` | 11 | 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150 | — | — |
| `choose_appearance` | Выбор облика / Choose Appearance | `almost_human` | `active` | 1 | 100 | — | `choose_appearance` |
| `circular_attack` | Круговая атака / Circular Attack | `almost_human` | `active` | 1 | 100 | — | `circular_attack` |
| `dash` | Рывок / Dash | `ghoul` | `active` | 1 | 50 | — | `dash` |
| `double_attack` | Двойная атака / Double Attack | `ghoul` | `active` | 1 | 75 | — | `double_attack` |
| `ears` | Уши / Ears | `ghoul` | `passive` | 1 | 20 | — | — |
| `flesh_regeneration` | Кровеносная система / Circulatory System | `ghoul` | `passive` | 1 | 20 | — | — |
| `flexible_joints` | Гибкие суставы / Flexible Joints | `skeleton` | `passive` | 1 | 15 | — | — |
| `fundamentals` | Развитие основ / Develop Fundamentals | `almost_human` | `passive` | 1 | 25 | — | — |
| `magic_awakening` | Пробуждение магии / Magic Awakening | `skeleton` | `passive` | 1 | 40 | — | — |
| `magic_missile` | Магическая стрела / Magic Missile | `skeleton` | `active` | 3 | 30, 45, 60 | `magic_awakening` 1 | `magic_missile` |
| `magic_missile_range` | Дальняя стрела / Long Missile | `skeleton` | `passive` | 1 | 50 | `magic_missile` 1 | — |
| `magic_ricochet` | Рикошет / Ricochet | `skeleton` | `passive` | 4 | 60, 80, 100, 120 | `magic_missile_range` 1 | — |
| `muscle_fibers` | Мышечные волокна / Muscle Fibers | `zombie` | `passive` | 2 | 20, 30 | — | — |
| `nervous_system` | Нервная система / Nervous System | `revenant` | `passive` | 1 | 80 | — | — |
| `sharp_vision` | Острое зрение / Sharp Vision | `zombie` | `passive` | 1 | 80 | — | — |
| `stomach` | Желудок / Stomach | `ghoul` | `passive` | 1 | 20 | — | — |
| `strong_bones` | Крепкие кости / Sturdy Bones | `skeleton` | `passive` | 5 | 5, 10, 15, 20, 25 | — | — |
| `strong_spine` | Крепкий позвоночник / Strong Spine | `skeleton` | `passive` | 1 | 20 | — | — |

## Способности

| ID | RU / EN | Слот | Цель | Требуемая форма | Перезарядка |
| --- | --- | --- | --- | --- | ---: |
| `basic_attack` | Базовая атака / Basic Attack | `attack` | `adjacent_enemy` | `skeleton` | 0 |
| `choose_appearance` | Выбор облика / Choose Appearance | `active` | `appearance_choice` | `almost_human` | 0 |
| `circular_attack` | Круговая атака / Circular Attack | `attack` | `adjacent_area` | `almost_human` | 0 |
| `dash` | Рывок / Dash | `active` | `dash_cell` | `ghoul` | 20 |
| `double_attack` | Двойная атака / Double Attack | `attack` | `adjacent_enemy` | `ghoul` | 15 |
| `magic_missile` | Магическая стрела / Magic Missile | `active` | `visible_enemy` | `skeleton` | 0 |

## Статусы

| ID | RU / EN | Длительность | Временные HP | Модификаторы | Сокращение перезарядки |
| --- | --- | ---: | ---: | --- | --- |
| `rested` | Отдых / Rested | 500 | 5 | `damage` 1, `ranged_damage` 1 | `dash` 10, `double_attack` 5 |
| `satiated` | Сытость / Satiated | 400 | 3 | `regeneration` 1 | — |

## Предметы

| ID | RU / EN | Слоты | attack_type | grip | Min depth | Параметры | Разбор |
| --- | --- | --- | --- | --- | ---: | --- | --- |
| `aiming_ring` | Кольцо прицела / Aiming Ring | `ring_1, ring_2` | `` | `` | 15 | `accuracy` 2, `dodge` -1 | `stone` 1 |
| `archivists_mask` | Маска архивиста / Archivist’s Mask | `head` | `` | `` | 18 | `accuracy` -1, `mana` 5, `spell_power` 1 | `cloth` 1, `stone` 1 |
| `bone_bow` | Костяной лук / Bone Bow | `right_hand` | `ranged` | `two_handed` | 0 | `range` 5, `ranged_damage` 1 | `cloth` 1, `wood` 2 |
| `bone_buckler` | Костяной баклер / Bone Buckler | `left_hand` | `` | `` | 8 | `dodge` 1, `max_hp` 2 | `stone` 1, `wood` 1 |
| `bone_knife` | Костяной нож / Bone Knife | `right_hand` | `melee` | `one_handed` | 0 | `accuracy` 1, `damage` 1 | `stone` 1, `wood` 1 |
| `expedition_backpack` | Походный рюкзак / Expedition Backpack | `back` | `` | `` | 15 | `preparation` 200 | `cloth` 3, `wood` 1 |
| `grave_mace` | Могильная булава / Grave Mace | `right_hand` | `melee` | `one_handed` | 8 | `accuracy` -1, `damage` 2 | `stone` 2, `wood` 1 |
| `gravediggers_lamp` | Лампа могильщика / Gravedigger’s Lamp | `left_hand` | `` | `` | 6 | `vision` 1 | `stone` 1, `wood` 1 |
| `heavy_leg_wraps` | Плотные обмотки / Heavy Leg Wraps | `legs` | `` | `` | 9 | `max_hp` 3 | `cloth` 2 |
| `hollow_lantern` | Пустотный фонарь / Hollow Lantern | `left_hand` | `` | `` | 18 | `mana` 10, `max_hp` 2, `soul_bonus` 1, `spell_power` 1 | `stone` 1, `wood` 1 |
| `lamellar_vest` | Ламельный жилет / Lamellar Vest | `body` | `` | `` | 15 | `dodge` -2, `max_hp` 7 | `cloth` 2, `stone` 2 |
| `leather_gloves` | Кожаные перчатки / Leather Gloves | `hands` | `` | `` | 10 | `accuracy` 1, `max_hp` 1 | `cloth` 1 |
| `old_claymore` | Старый клеймор / Old Claymore | `right_hand` | `melee` | `two_handed` | 14 | `accuracy` 2, `damage` 3 | `stone` 3, `wood` 1 |
| `pilgrim_shield` | Щит паломника / Pilgrim Shield | `left_hand` | `` | `` | 28 | `dodge` -1, `max_hp` 4 | `stone` 1, `wood` 2 |
| `pilgrims_boots` | Башмаки паломника / Pilgrim’s Boots | `feet` | `` | `` | 4 | `max_hp` 2 | `cloth` 1, `wood` 1 |
| `rotting_mail` | Сшитый панцирь / Stitched Carapace | `body` | `` | `` | 3 | `dodge` -1, `max_hp` 3 | `cloth` 2 |
| `rusty_sabre` | Ржавая сабля / Rusty Sabre | `right_hand` | `melee` | `one_handed` | 5 | `accuracy` 2, `damage` 1 | `stone` 1, `wood` 1 |
| `scouts_trousers` | Штаны лазутчика / Scout’s Trousers | `legs` | `` | `` | 14 | `dodge` 1, `max_hp` 2 | `cloth` 1 |
| `short_crossbow` | Короткий арбалет / Short Crossbow | `right_hand` | `ranged` | `two_handed` | 12 | `accuracy` -1, `range` 4, `ranged_damage` 3 | `cloth` 1, `wood` 2 |
| `soul_locket` | Медальон ловца / Soulcatcher Locket | `talisman` | `` | `` | 0 | `mana` 5, `soul_bonus` 1, `spell_power` 1 | `stone` 1 |
| `thickblood_ring` | Кольцо плотной крови / Thickblood Ring | `ring_1, ring_2` | `` | `` | 15 | `mana` -5, `max_hp` 3 | `cloth` 1, `stone` 1 |
| `unexpectedly_comfortable_jacket` | Уютный пиджак / Cozy Jacket | `jacket` | `` | `` | 0 | `soul_level_bonus` 1 | — |
| `wanderers_gambeson` | Стёганка странника / Wanderer’s Gambeson | `body` | `` | `` | 10 | `dodge` 1, `max_hp` 2 | `cloth` 2 |
| `watchmans_cap` | Шапка сторожа / Watchman’s Cap | `head` | `` | `` | 4 | `max_hp` 2 | `cloth` 1 |

## Противники

| ID | RU / EN | HP | Урон | Души | Точность | Уклонение | Обзор | Атака | Min depth |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| `arachnid` | Арахнид / Crypt Arachnid | 7 | 2 | 3 | 4 | 3 | 5 | `melee` | 11 |
| `blind_scavenger` | Слепой падальщик / Blind Scavenger | 12 | 1 | 1 | 2 | 1 | 2 | `melee` | 4 |
| `bone_crossbowman` | Костяной арбалетчик / Bone Crossbowman | 5 | 2 | 3 | 4 | 0 | 6 | `ranged` | 20 |
| `grave_rat` | Могильная крыса / Grave Rat | 2 | 1 | 1 | 2 | 2 | 3 | `melee` | 0 |
| `hollow_guard` | Пустой страж / Hollow Guard | 4 | 1 | 2 | 3 | 1 | 5 | `melee` | 6 |
| `minotaur` | Минотавр / Minotaur | 36 | 2 | 12 | 4 | 0 | 6 | `melee` | — |
| `skeletal_archer` | Скелет-лучник / Skeletal Archer | 4 | 1 | 2 | 3 | 1 | 6 | `ranged` | 6 |
| `slag_smith` | Шлаковый кузнец / Slag Smith | 10 | 2 | 5 | 4 | 0 | 5 | `melee` | 15 |
| `soul_leech` | Душеед / Soul Leech | 5 | 2 | 3 | 4 | 2 | 4 | `melee` | 15 |

### Масштабирование обычных этажей

`depth = 100 - floor_number`

- Число врагов: `min(12, 5 + floor(depth / 12))`.
- HP: `base.max_hp + floor(depth / 20)`.
- Урон: `base.damage + floor(depth / 35)`.
- Точность: `base.accuracy + floor(depth / 25)`.
- Уклонение: `base.dodge + floor(depth / 30)`.
- Награда душами: `base.souls + floor(depth / 30)`.
- Обзор не масштабируется.
- Фиксированный этаж 90 использует базовые параметры Минотавра без этих бонусов.

## Постройки лагеря

| ID | RU / EN | Стоимость | Требует |
| --- | --- | --- | --- |
| `bunk` | Тканевые нары / Cloth Bunk | `cloth` 6, `wood` 8 | — |
| `campfire` | Костёр / Campfire | `cloth` 0, `stone` 3, `wood` 3 | — |
| `crusher` | Дробилка / Crusher | `cloth` 0, `stone` 5, `wood` 5 | — |
| `kettle` | Походный котёл / Expedition Kettle | `cloth` 2, `stone` 8, `wood` 6 | campfire |
| `mural` | Мурал / Mural | `banked_souls` 60, `cloth` 5, `minotaur_tail` 1, `stone` 20, `wood` 12 | — |
| `record_player` | Проигрыватель / Record Player | — | — |
| `ritual_table` | Ритуальный стол / Ritual Table | `cloth` 5, `stone` 10, `wood` 10 | — |
| `rocking_chair` | Кресло-качалка / Rocking Chair | `wood` 30 | — |
| `storage_chest` | Сундук хранения / Storage Chest | `cloth` 3, `stone` 4, `wood` 20 | — |
| `textile_area` | Ткацкий уголок / Textile Area | — | — |
| `whetstone` | Точильный камень / Whetstone | `cloth` 5, `stone` 10, `wood` 10 | — |
| `workbench` | Верстак / Workbench | — | — |
| `writing_set` | Письменные принадлежности / Writing Set | — | workbench |

## Источник истины

- `scripts/game/game_rules.gd` — формы, навыки, предметы, враги, постройки и числовые правила.
- `scripts/game/skill_system.gd` — реестр способностей и совместимость слотов.
- `scripts/game/status_system.gd` — реестр статусов, их модификаторов и длительности.
- `scripts/localization/localization.gd` — RU/EN названия и описания.
- `scripts/world/floor_generator.gd` — runtime-константы глубинного усиления обычных врагов.
- `scripts/world/fixed_floor_90.gd` — номер и контракт фиксированной арены.
