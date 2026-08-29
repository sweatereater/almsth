# Dungeon prototype asset prompts

The raster assets in this folder were generated with the built-in ImageGen
tool. They are deliberately static prototype art: restrained stylized realism,
top-down readability, no text, logos, UI or watermarks.

## `floor-stone.png`

```text
Use case: stylized-concept
Asset type: tileable game texture for a top-down dungeon crawler
Primary request: ancient worn dungeon floor made of irregular dark gray flagstones
Style/medium: understated stylized realism, hand-painted game texture, believable stone grain, optimized to remain readable when downscaled
Composition/framing: orthographic straight-down surface, uniform detail across the whole square canvas
Lighting/mood: neutral soft ambient light, cold subterranean mood, very low baked-in shadows
Color palette: charcoal gray, muted blue-gray, faint dusty brown accents
Materials/textures: chipped limestone slabs, thin dark mortar, sparse hairline cracks and tiny dust deposits
Constraints: perfectly seamless/tileable edges; no single focal object; no symbols; no text; no creatures; no props; no logos; no watermark
Avoid: perspective, dramatic highlights, deep cast shadows, bright colors, photoreal photography
```

## `wall-stone.png`

```text
Use case: stylized-concept
Asset type: tileable game texture for a top-down dungeon crawler
Primary request: ancient dungeon wall masonry made from rough dark stone blocks
Style/medium: understated stylized realism, hand-painted game texture, stronger chunky shapes than the floor, optimized to remain readable when downscaled
Composition/framing: orthographic straight-down material surface, uniform detail across the square canvas
Lighting/mood: neutral soft ambient light, cold subterranean mood, gentle edge highlights only
Color palette: slate gray, desaturated blue, muted iron-gray
Materials/textures: large worn blocks, chipped edges, deep narrow mortar seams, occasional moss-dark stains
Constraints: perfectly seamless/tileable edges; clearly distinct from a floor texture; no single focal object; no symbols; no text; no creatures; no props; no logos; no watermark
Avoid: perspective, brick wall seen from the side, dramatic lighting, bright green moss, photoreal photography
```

The renderer samples roughly ten times the former texture area per logical wall
cell and applies one of five close, coordinate-hashed tints. This keeps the
masonry fine and slightly varied without extra textures or runtime RNG.

## `chest.png`

```text
Use case: stylized-concept
Asset type: top-down item sprite for a grid-based dungeon crawler
Input images: wall-stone.png is a dungeon-palette reference; player-skeleton.png is a rendering-style reference
Primary request: one closed ancient dungeon treasure chest, unmistakable at roughly 28–30 pixels
Subject: compact low wooden chest with a slightly arched lid, battered dark timber, worn iron bands and corners, and one muted brass latch
Style/medium: simplified hand-painted stylized realism matching Almsth's dark prototype sprites; strong silhouette and restrained chunky detail
Composition/framing: orthographic near-top-down view, entire chest centered, lid facing upward, generous transparent padding, no ground plane
Lighting/mood: cool dim dungeon light with a restrained warm latch highlight; no glow
Color palette: dark desaturated wood, charcoal iron, muted brass
Constraints: genuinely transparent background; exactly one closed chest; no contents, scenery, text, UI, border, logo or watermark
Avoid: pixel art, cartoon proportions, bright gold, magical aura, open lid, dramatic cast shadow
```

## `player-skeleton.png`

```text
Use case: stylized-concept
Asset type: top-down character sprite for a grid-based dungeon crawler
Primary request: a complete wandering skeleton player wearing a short worn brown-gray poncho
Subject: one slender human skeleton, readable skull and rib cage, small cloth poncho behind the shoulders, empty hands, cautious walking stance
Style/medium: simplified hand-painted stylized realism, strong clean silhouette, restrained detail that remains readable at 28 pixels
Composition/framing: orthographic near-top-down view, entire body centered, facing toward the top of the image, generous transparent padding, no ground plane
Lighting/mood: soft cool dungeon light with a faint warm bone rim, quiet and slightly melancholic
Color palette: ivory bone, dusty brown-gray cloth, subtle turquoise pin-light in eye sockets
Constraints: genuinely transparent background and preserved alpha; exactly one character; no circular base; no shadow beyond a tiny soft contact shadow; no weapons; no text; no UI; no border; no logo; no watermark
Avoid: pixel art, chibi proportions, front-facing portrait, side view, gore, flesh, complex background
```

## `enemy-grave-rat.png`

```text
Use case: stylized-concept
Asset type: top-down enemy sprite for a grid-based dungeon crawler
Primary request: a grave rat, large diseased dungeon rat enemy
Subject: exactly one lean rat with patchy dark gray-brown fur, pale scarred tail, low stalking pose, small sickly red eyes
Style/medium: simplified hand-painted stylized realism, strong clean silhouette, restrained detail that remains readable at 28 pixels
Composition/framing: orthographic near-top-down view, full animal centered, facing toward the top of the image, generous transparent padding, no ground plane
Lighting/mood: cool dungeon light, grim but not gory
Color palette: charcoal fur, dusty brown, pale tail, tiny muted red eye accents
Constraints: genuinely transparent background and preserved alpha; exactly one rat; no circular base; no scenery; no text; no UI; no border; no logo; no watermark
Avoid: pixel art, cute cartoon, front portrait, multiple animals, blood, dramatic shadow
```

## `enemy-hollow-guard.png`

```text
Use case: stylized-concept
Asset type: top-down enemy sprite for a grid-based dungeon crawler
Primary request: a Hollow Guard, an empty corroded suit of medieval dungeon armor animated by faint soul-light
Subject: exactly one broad armored humanoid with dented dark iron helmet and breastplate, no visible flesh, a simple short blunt sword held close to the body, thin turquoise glow leaking from visor
Style/medium: simplified hand-painted stylized realism, strong clean silhouette, restrained chunky detail that remains readable at 28 pixels
Composition/framing: orthographic near-top-down view, entire figure centered, facing toward the top of the image, generous transparent padding, no ground plane
Lighting/mood: cold dungeon light, heavy and ominous rather than spectacular
Color palette: dark iron, muted rust brown, subtle turquoise soul glow
Constraints: genuinely transparent background and preserved alpha; exactly one figure; no circular base; no scenery; no text; no UI; no border; no logo; no watermark
Avoid: pixel art, ornate heroic armor, huge weapon, bright magical effects, flesh, gore, dramatic shadow
```

## `enemy-soul-leech.png`

```text
Use case: stylized-concept
Asset type: top-down enemy sprite for a grid-based dungeon crawler
Primary request: a Soul Leech, a small floating dungeon spirit that feeds on souls
Subject: exactly one hunched wraith-like creature made from ragged charcoal cloth and translucent smoky tendrils, a narrow violet-turquoise core glow, no human face
Style/medium: simplified hand-painted stylized realism, strong clean silhouette, restrained detail that remains readable at 28 pixels
Composition/framing: orthographic near-top-down view, whole floating creature centered, facing toward the top of the image, generous transparent padding, no ground plane
Lighting/mood: cold eerie light, mysterious rather than horrific
Color palette: charcoal, desaturated violet, subtle turquoise core
Constraints: genuinely transparent background and preserved alpha; exactly one creature; no circular base; no scenery; no text; no UI; no border; no logo; no watermark
Avoid: pixel art, tentacle monster, human portrait, bright neon, gore, dramatic shadow
```

## `enemy-minotaur.png`

```text
Use case: stylized-concept
Asset type: top-down boss character sprite for a grid-based dungeon crawler
Primary request: a Minotaur dungeon boss, physically imposing but designed to occupy one logical grid cell while its artwork visibly extends beyond that cell
Subject: exactly one massive bull-headed humanoid with broad shoulders, large weathered horns, dark shaggy fur, scarred hide, ragged leather-and-iron dungeon armor, and a heavy chipped one-handed labyrinth axe held close to the body
Style/medium: simplified hand-painted stylized realism matching restrained dark-fantasy game sprites; strong clean silhouette; chunky readable details that survive aggressive downscaling
Composition/framing: orthographic near-top-down view, entire figure centered and facing toward the top of the image, feet near the lower edge, generous transparent padding around horns and shoulders, no ground plane
Lighting/mood: cold dim dungeon light, ancient and threatening rather than spectacular
Color palette: charcoal-brown fur, weathered iron, muted leather, bone-colored horns, very subtle ember-red eyes
Constraints: genuinely transparent background with preserved alpha; exactly one creature; full body; no circular base; no scenery; no text; no UI; no border; no logo; no watermark
Avoid: pixel art, cute cartoon, front-facing portrait, side view, multiple creatures, gore, huge magical effects, dramatic cast shadow
```
