# Фигуры для выбора пола / Sex-specific character figures

Десять прозрачных фигур и недостающая мужская почти человеческая голова подготовлены
локально из утверждённых оригиналов, с разрешения пользователя. Генерация, перерисовка,
замена лица или изменение пропорций не использовались. Нативные вырезки сохраняют RGB
источника; маски меняют только альфу. Пять ранее подготовленных женских голов не изменены.

Ten transparent figures and the missing male almost-human head were locally extracted
from approved originals with the user's permission. No generation, repainting, face
replacement or proportion changes were used. Native cutouts retain source RGB; masks
only change alpha. The five existing female heads are unchanged.

| Файлы / Files | Назначение / Purpose |
|---|---|
| `../female/sources/` | Два неизменённых женских оригинала / Two unchanged female originals |
| `../male/sources/five-stages-approved.png` | Неизменённый утверждённый мужской лист / Unchanged approved male lineup |
| `recipe.json` | SHA источников, области, точки глаз/стоп и локальные маски / Source hashes, crops, anatomical anchors and local masks |
| `cutouts/`, `masks/` | Прозрачные нативные вырезки и маски / Native transparent cutouts and masks |
| `manifest.json` | SHA runtime, границы альфы, масштаб и опоры / Runtime hashes, alpha bounds, scale and anchors |
| `previews/` | Обе серии на светлом/тёмном фоне и головы селектора / Light/dark figure strips and selector heads |
| `../../../assets/ui/character-fullbody/{female,male}/` | По пять runtime PNG 264×704 RGBA / Five runtime 264×704 RGBA PNGs per sex |
| `../../../assets/portraits/male/form-almost-human.png` | Голова 264×264 RGBA / 264×264 RGBA head |

Внутри каждого пола расстояние глаз–стопы общее; масштаб ограничен самой широкой позой
и одеждой. Фигуры не растягиваются: стопы стоят на `(132,696)`, сохраняются безопасные
поля crop `(7,8,250,692)`. Головы используют глаз `(115,105)` и глаз–подбородок 56 px.
Мужская голова отражается только в интерфейсе создания. Рамки/галочка — элементы UI.

Each sex shares an eye-to-foot scale limited by its widest pose and clothing. Figures
are not stretched: foot anchor `(132,696)` and crop `(7,8,250,692)` remain safe. Heads use
eye anchor `(115,105)` and a 56 px eye-to-chin span. Only the creation UI flips the male
head. Frames and the check mark are UI elements.

Архив исключён из импорта через `.gdignore`. Runtime импорт: lossless, mipmaps off,
alpha-border fix on. Эти 264×704 ресурсы принадлежат только листу персонажа; тот же
сохранённый выбор пола также выбирает 264×264 gait-набор по текущей/косметической
форме из `assets/dungeon/player-forms/` (защищённый `female/ghoul` хранится отдельно).

The archive is excluded by `.gdignore`. Runtime imports use lossless, no mipmaps and
alpha-border fix. These 264×704 resources belong only to the character sheet; the same
saved sex also selects the 264×264 map gait set for the current/cosmetic form
under `assets/dungeon/player-forms/` (the protected `female/ghoul` set remains separate).

Пересборка и проверка / Rebuild and verify (Python + Pillow + numpy):

```powershell
python tools/prepare_character_sex_assets.py
python tools/prepare_character_sex_assets.py --check
```

`--check` не пишет файлы: сверяет SHA оригиналов, RGB нативных вырезок, точную
воспроизводимость масок/PNG, размеры, опоры и manifest. Повторный импорт нужен после сборки.

`--check` writes nothing: it verifies original hashes, native RGB preservation, exact
mask/PNG reproducibility, dimensions, anchors and the manifest. Reimport after rebuilding.
