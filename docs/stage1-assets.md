# Графика первого пакета

Все27 изображений созданы встроенным `image_gen`. Runtime-файлы находятся в проекте;
исходные изображения из пользовательского cache не менялись. Точные сохранённые
промпты, имена исходников, SHA-256 и размеры перечислены в
[stage1-asset-manifest.json](stage1-asset-manifest.json). Для пяти ранних изображений
(E06, I01, I04, I05, I06) исходный промпт не сохранился: соответствующие записи прямо
помечены как сохранённый художественный brief, а не дословный промпт.

| Позиции | Runtime-пути | Размер |
|---|---|---|
| E01/E03/E06/E09 | `assets/dungeon/enemy-blind-scavenger.png`, `enemy-arachnid.png`, `enemy-bone-crossbowman.png`, `enemy-slag-smith.png` |264×264 RGBA|
|14 предметов|`assets/items/item-rusty-sabre.png` … `item-expedition-backpack.png`; полный список в manifest|132×132 RGBA|
| O06 |`assets/dungeon/chest-crypt.png`|264×264 RGBA|
| D01 |`assets/dungeon/decor-cocoon-1.png`, `decor-cocoon-2.png`|264×264 RGBA|
| D02 |`assets/dungeon/decor-mosaic-1.png` … `decor-mosaic-3.png`|264×264 RGB|
| B02 |`assets/art/camp-kettle.png`|132×104 RGBA|
| B03 |`assets/art/camp-bunk.png`|248×100 RGBA|
| B05 |`assets/art/camp-mural.png`|152×84 RGBA|

`tools/normalize_stage1_assets.gd` выполняет только технический экспорт: обрезает
полностью прозрачные поля, уменьшает Lanczos с premultiplied alpha и добавляет
утверждённые прозрачные отступы. Цвета и исходная альфа не ретушируются; удаления фона
или исправления контуров нет. После уменьшения нижняя опора существ/Склепа находится
на y=260, лагерных предметов — на высоте холста минус4px. Иконки центрированы с
отступом не менее8px. Мозаика уменьшается целиком без обрезки или перерисовки краёв.
Повторный экспорт допускается только поверх файлов, SHA-256 которых совпадает с
предыдущим манифестом этого инструмента; неизвестные изменения не перезаписываются.

Пример повторного экспорта из исходного manifest, который содержит пути к master PNG:

```powershell
godot --headless --path . --script res://tools/normalize_stage1_assets.gd -- "C:/path/stage1-assets.json"
godot --headless --path . --editor --import --quit
```

Проверка `tests/content_stage1_test.gd` контролирует все27 путей, размеры, альфу,
отступы, опоры и соответствие SHA-256. Существующая проверка `visual_overhaul_test.gd`
дополнена явными путями новых предметов и врагов; старые контракты и хеши сохранены.

`tests/capture_content_stage1.gd` создаёт52 снимка: мир44/66/88 на1280×720 и960×540,
со скрытым/видимым стрелком; лагерь до/после трофея и постройки, дробилка и все страницы
инвентаря на двух размерах в RU/EN. Запускать с настоящим renderer, без `--headless`;
результат и хеши использованных исходников находятся в `.tmp/stage1-previews`.
Этот инструмент не создаёт игровых сохранений и не публикует сборку.
