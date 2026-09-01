# Альтернативы главного героя — 31 августа 2026

Шесть концептов для выбора типажа. Созданы встроенным image_gen; CLI/API fallback не использовался. Это не утверждённая замена героя и не игровые спрайты. Код, активные ассеты и сохранения не изменены.

Общая идея: нежить постепенно собирает себя обратно в человека; тёмный потёртый полосатый пиджак, красная подкладка, янтарные глаза, бедная практичная одежда, рисованный контур и приглушённая живопись.

| № | Типаж RU / EN | Условная придурковатость | Файл |
|---|---|---|---|
| 01 | Усталый скептик / Tired Skeptic | 1/6 | [PNG](01-tired-skeptic.png) |
| 02 | Мелкий прохиндей / Shifty Rogue | 2/6 | [PNG](02-shifty-rogue.png) |
| 03 | Рассеянный умник / Absent-minded Scholar | 3/6 | [PNG](03-absent-minded-scholar.png) |
| 04 | Добродушный увалень / Gentle Oaf | 4/6 | [PNG](04-gentle-oaf.png) |
| 05 | Важный недотёпа / Pompous Bungler | 5/6 | [PNG](05-pompous-bungler.png) |
| 06 | Бесстыжий балбес / Shameless Goofball | 6/6 | [PNG](06-shameless-goofball.png) |

Большая фигура показывает промежуточную форму; малые портреты исследуют восстановление лица. Шкала юмора художественная, а не игровая характеристика.

## Проверка

Визуально просмотрены все шесть карточек; независимый read-only арт-ревью подтвердил различия лиц, пропорций и поз, узнаваемость внутри варианта и сохранение общего замысла. В 01 исправлен верхний портрет на череп, в 02 восстановлена щека нижнего почти человеческого портрета.

Портреты пока являются эскизами, а не утверждёнными стадиями: у части костяных голов сохраняются волосы и/или мягкие ткани шеи (особенно 03–05). После выбора кандидата требуется отдельная выверенная линейка всех пяти форм. До подготовки runtime также обязательны размеры, альфа, опоры, crop и обзор 44/66/88 по docs/art-direction.md. Эти проверки и Godot smoke/soak не выполнялись: ни игровые ресурсы, ни поведение игры не менялись.

## Точный набор промптов

Reference image: `art/concepts/character_fullbody/style_tests/ghoul/ghoul_style_03_hybrid.png`.
Каждый первоначальный вызов получил общий промпт ниже, затем `VARIANT DIRECTION:` и соответствующий текст варианта. Использовался отдельный image_gen-вызов для каждого кандидата.

### Общий промпт

```text
Use case: stylized-concept.
Asset type: alternative protagonist concept card for Almsth, a darkly comic dungeon crawler in which the main character begins as a skeleton and gradually rebuilds himself into a human.
Primary request: Reinterpret the supplied existing protagonist illustration as ONE genuinely new protagonist candidate. Use the reference for the handmade ink-and-paint art language, worn clothing and undead-to-human premise, but deliberately REDESIGN the face, skull, hair, body proportions and attitude as specified below. This is an alternative casting, not another evolutionary stage of the original handsome young man.
Art and world invariants: adult male undead wanderer, shabby charcoal pinstripe long blazer / cozy jacket, burgundy-red lining and turned-up collar, practical patched earthy trousers, scuffed lace-up boots, a small subdued teal neck cloth, amber-gold eyes with visibly asymmetric intensity (one bright pinpoint, one dimmer), pale grey-olive skin, only dry exposed cheekbone and bone hand to suggest partial restoration. No blood, no wet gore. Maintain melancholy, warmth and deadpan dark comedy. No weapons, scenery, class costume, gadgets or extra props to carry the personality: it must read from face and body.
Style: expressive hand-drawn dark fantasy storybook / graphic-novel character concept, lively visible ink contours, selective hatch, restrained opaque gouache washes, crisp silhouette, matte distressed cloth and bone, muted charcoal / burgundy / ochre / grey-olive palette. Avoid glossy 3D, photorealism, cute chibi, generic handsome anime faces, modern sneakers, meme faces, clown accessories. Small facial asymmetry must appear intentionally characterful, not medical caricature.
Composition: a polished landscape 3:2 character design card on a very quiet pale warm-grey parchment backdrop. LEFT roughly 60 percent: exactly one complete head-to-toe figure, relaxed standing three-quarter view, both feet fully visible on a common ground line with soft faint contact shadow, generous clear margins and narrow readable silhouette, no cropping. RIGHT roughly 35 percent: two large clean shoulder-up head studies of THIS SAME candidate at matching angles, upper study as a bare skull with amber soul lights, lower study as the almost-human face with its hair / eyebrows / characteristic nose restored. The full body in the left panel is in the intermediate ghoul form and must clearly express the given personality. These are three renderings of ONE identity, not three different candidates. Keep skull geometry and eye spacing related across all studies.
Text: only the two-digit candidate number requested below, clean small dark lettering at top left, no other words, no labels, no logo, no watermark.
Concept-only deliverable: do not imitate in-game UI or equipment frames.
```

### 01 — Усталый скептик

```text
Candidate number "01". Low goofiness 1/6. A middle-aged, long narrow-faced, slim man with a slightly hooked nose, heavy horizontal brows, deep-set half-lidded eyes, thin compressed lips and a subtly crooked dry smirk. Short untidy dark hair with a little grey at the temples, receding slightly; absolutely not a handsome boy. Slight forward stoop, narrow drooping shoulders, one hand in jacket pocket, other hanging loose, feet nearly parallel. A tired reasonable man who woke up dead and is profoundly unimpressed. The comedy is understated resignation. Nearly realistic adult proportions with a slightly long face. Preserve likability. Ghoul cheekbone exposed as a small dry patch, not a huge cavity.
```

### 02 — Мелкий прохиндей

```text
Candidate number "02". Goofiness 2/6. A lean wiry adult streetwise opportunist, compact triangular face, prominent pointed nose, sharp cheekbones, narrow sly amber eyes, one eyebrow cocked much higher, small pointed chin and a very crooked conspiratorial grin. Short slicked-back black hair with one rebellious forelock; almost-human portrait has faint uneven stubble. Leaning at an easy diagonal, one shoulder raised, one thumb hooked into the jacket pocket, free hand loosely open as if explaining a dubious bargain. Narrow agile body with bent elbow and asymmetric collar, visibly different from a brooding anime lead. Feeling: he definitely has a plan, and it is probably a terrible plan. Dry exposed cheekbone stays small and subtle.
```

### 03 — Рассеянный умник

```text
Candidate number "03". Goofiness 3/6. An extremely lanky adult intellectual with a tall elongated cranium, high forehead, long gently curved nose, tiny chin, large earnest eyes looking thoughtfully a little upwards, one brow raised, small slightly open mouth as if he forgot what he was saying. Sparse unruly dark hair sticking up in a soft uneven tuft, no glasses. Long thin neck, very narrow sloping shoulders, long bony arms, hunched questioning stance with knees close and oversized practical boots slightly pigeon-toed. Both hands held loosely near the jacket pockets; nothing held. Thoughtful good-natured bewilderment, forever formulating the wrong theory. Exaggeration is elegant and deliberate, not grotesque or childish. The jacket hangs straight like a loose narrow rectangle.
```

### 04 — Добродушный увалень

```text
Candidate number "04". Goofiness 4/6. A big broad adult with a soft stocky pear-shaped build, substantial shoulders and belly under his slightly too-small worn jacket, thick neck, broad round-square face, broad flat nose, small warm amber eyes, heavy expressive brows, large uneven kindly smile. Short blunt dark hair, simple tousled crop. Both full-body ghoul and restored portrait are unmistakably broad and warm, not conventionally attractive. Relaxed rounded shoulders, big hands hanging loosely, feet apart but within a compact grounded silhouette. An earnest cheerful fellow delighted to have found his missing arm; no arm held as a prop. Humor is sunny naivety and utter calm about being dead. Make the bare skull study broad-jawed and round-crowned to match, and keep the same big approachable identity. No visible blood or missing hanging parts.
```

### 05 — Важный недотёпа

```text
Candidate number "05". Goofiness 5/6. A short compact middle-aged fussy gentleman in the same shabby long blazer, trying desperately to look distinguished. Broad forehead, small pinched eyes, long upturned angular nose, little pursed mouth and a receding chin. Perfectly parted sparse black hair with a ridiculous stubborn curl; small neat moustache only in the almost-human portrait. Head held high, chest puffed out, belly forward, elbows slightly out, one hand carefully straightening the lapel, short legs in baggy patched trousers and stout boots. Self-important injured dignity with visible foolishness, not an actual aristocrat in expensive dress. Adult cartoon proportions about five and a half heads tall, not a dwarf fantasy race or chibi. His jacket looks a size too large and too long but retains the original worn charcoal/red design. Distinctive compact upright silhouette, tiny smug asymmetrical smile.
```

### 06 — Бесстыжий балбес

```text
Candidate number "06". Maximum goofiness 6/6 while still an appealing playable protagonist. A gangly adult with a very long lower face, huge loose square jaw, prominent jutting chin, long nose with a soft round tip, arched mobile eyebrows and an absurdly wide, utterly confident crooked grin showing two noticeably prominent front teeth. Messy dark cowlick hair exploding in three broad tufts. Eyes wide and alert, one narrower from the grin, amber gaze focused normally; DO NOT cross the eyes or evoke a medical disability. Long thin rubbery-looking limbs with believable joints, narrow torso in the familiar oversized worn jacket, head cocked, chest proudly up, knees bent slightly, large boots splayed at different angles but feet firmly grounded. One hand jammed in a pocket, the other gives a casual small thumbs-up close to torso. An idiotically optimistic survivor who treats every disaster as proof his brilliant plan worked. Very strong silhouette and face character, comedic but not creepy horror, not a clown, no tongue out. Bare skull study has the same huge jaw and two characteristic front teeth; restored head has the same elongated jawline and loose shameless grin.
```

### Точечные правки

#### 01

Reference: `C:/Users/Kirill/.codex/generated_images/01a0593b-bf1e-7fd2-be63-0172e544f369/exec-49afcb57-f8d2-4804-af8d-a35165342fb7.png`

```text
Use case: precise-object-edit. Edit only the UPPER RIGHT shoulder-up portrait on this character concept card "01". Replace this upper right ghoul head with this SAME tired skeptical man's completely BARE SKELETON skull, absolutely no skin, no fleshy nose, no ears, no hair or scalp, no fleshy lips. The skull needs the same long narrow cranium, brow shape, eye spacing, long jaw and three-quarter angle; asymmetrical dim amber soul lights in deep eye sockets, bony nasal opening, exposed dry teeth, a weary skeptical expression through the bony brow and slight skull tilt. Use muted warm grey ivory bone and matching fine ink contours and paint rendering. Bare skeletal neck inside the unchanged jacket collar. Preserve the entire left full-body figure, the bottom-right nearly-human portrait, number "01", all clothing, parchment background, existing composition and image dimensions completely unchanged. The upper-right skull must be clearly a literal bare skull, not a ghoul. Do not add anything else.
```

#### 02

Reference: `C:/Users/Kirill/.codex/generated_images/01a0593b-bf1e-7fd2-be63-0172e544f369/exec-1c629dac-95e7-4ce6-a075-c6aef2154334.png`

```text
Use case: precise-object-edit. Edit only the LOWER RIGHT shoulder-up portrait on this character concept card "02". This lower right portrait must depict the SAME sly sharp-faced rogue almost fully restored to human: replace the exposed cheekbone / open cheek cavity on the viewer's right of his face with intact pale grey-olive skin with subtle weathering and faint stubble. Reconstruct the missing cheek with normal continuous cheek skin, a normal mouth corner, no exposed teeth except what belongs to the small crooked smirk, no cheek holes and no exposed bone in this LOWER RIGHT head. Preserve his pointed nose, sly amber eyes, raised eyebrow, slick black hair and forelock, exact face proportions and conspiratorial expression; keep the original ink and paint style. Preserve the entire LEFT full-body ghoul including its exposed cheek, preserve the UPPER RIGHT bare skull, number "02", clothing, background, composition and dimensions completely unchanged. Do not beautify, de-age or turn him into someone else. Do not add anything else.
```

## Источники окончательных PNG

- 01: `C:/Users/Kirill/.codex/generated_images/01a0593b-bf1e-7fd2-be63-0172e544f369/exec-280160e8-9a29-47bf-98a9-0a36824691db.png` → `01-tired-skeptic.png`
- 02: `C:/Users/Kirill/.codex/generated_images/01a0593b-bf1e-7fd2-be63-0172e544f369/exec-5746f7a7-3266-4c0b-95fd-869b7f71a307.png` → `02-shifty-rogue.png`
- 03: `C:/Users/Kirill/.codex/generated_images/01a0593b-bf1e-7fd2-be63-0172e544f369/exec-765c6a44-f1fe-4d06-9c08-75bbef7791cb.png` → `03-absent-minded-scholar.png`
- 04: `C:/Users/Kirill/.codex/generated_images/01a0593b-bf1e-7fd2-be63-0172e544f369/exec-35841b4a-174b-44dd-a829-17dc9ef11018.png` → `04-gentle-oaf.png`
- 05: `C:/Users/Kirill/.codex/generated_images/01a0593b-bf1e-7fd2-be63-0172e544f369/exec-ee50a8e2-70e1-4e98-965a-0233dd74f05e.png` → `05-pompous-bungler.png`
- 06: `C:/Users/Kirill/.codex/generated_images/01a0593b-bf1e-7fd2-be63-0172e544f369/exec-3a27114b-0c41-4e42-993b-9e1252276990.png` → `06-shameless-goofball.png`

