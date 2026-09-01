# Almsth Devlog #1: Why Would a Skeleton Climb Up?

Most dungeon crawlers send you down in search of treasure, experience, and trouble. We decided to begin with the trouble: the protagonist wakes up as a skeleton on floor 100 and has to find a way to the surface.

That is how **Almsth** began — a turn-based dungeon crawler in reverse. We are a small indie team building a game around an idea we genuinely want to play, rather than a checklist of the safest possible choices. In this devlog, we want to show how the game grows without making grand promises: what started working, what had to be rebuilt, and what strange problems appeared along the way.

![The protagonist awakens](../../assets/art/intro-03-awakening.png)

*The first question after waking up is not “Who am I?” but “Why are there ninety-nine more floors above me?”*

## First, We Needed a Game Loop

The first stage was about answering a simple question: is exploring this dungeon actually interesting?

We built the basic loop: explore a floor, encounter enemies and chests, collect souls, and search for a path upward. Movement is turn-based. The world waits while the player thinks, but every step gives the dungeon’s inhabitants a chance to respond. Distance, line of sight, and corridor positioning immediately began to matter. Sometimes one tile is worth more than another point of damage.

Alongside movement, we added melee combat, early items, character attributes, and fog of war. Places you have visited remain in the map’s memory, but enemies disappear when the protagonist can no longer see them. We wanted uncertainty to be more than a black curtain over unexplored tiles.

![Early gameplay prototype](../../builds/previews/texture-update-1280x720-dungeon.png)

*The early prototype could already track turns, vision, and combat. It also looked completely honest: like a program trying very hard to become a game.*

## Procedural Generation Is Not a “Make Level” Button

The floors are procedurally generated. On paper, this sounds convenient: choose a size, place some walls, add a staircase, and the job is done. In practice, the generator has to be taught many things a person would consider obvious.

The starting position must not be sealed off. A valid route to the exit must exist. Important objects cannot appear inside a wall or on top of one another. A floor should not become either a narrow intestine or a football field where you can see an enemy three business days before meeting it.

The first version produced a large irregular hall containing entrances, exits, enemies, and chests. We then ran the generator repeatedly, checking connectivity and edge cases. This work is nearly invisible in a screenshot, but extremely visible when it has not been done.

One later automated run generated 500 floors and performed 1,200 random actions. That does not guarantee immortality, but it is a reasonable way to make sure a new skeleton is not born inside a wall.

## Finding the Game’s Face

At the same time, we explored different looks for the protagonist. A skeleton has an immediately recognizable silhouette. The problem is that games already contain roughly as many skeletons as wooden crates.

![An early face concept](../../art/concepts/character_faces/form_01_skeleton_v2.png)

*One of the variants that remained in the work folder. Not every drawing has to enter the game; sometimes its purpose is to show us where to go next.*

We are not trying to present the prototype as an almost finished product. Parts of the interface are temporary, the visual direction is still being refined, and the numbers will certainly change. But the foundation exists: you can create a character, enter a floor, explore, fight, find loot, and climb higher.

That is enough for the first notional week. The skeleton is standing. Now we need to decide what it will lose, discover, and become along the way.

## This Week in Short

**Added:** turn-based movement and combat, procedural floors, fog of war, early items and enemies, chests, and transitions between floors.

**Fixed:** several edge cases in generation and important-object placement; added automatic floor-connectivity checks.

**Discovered:** a valid map can still be boring when it does not create useful route and combat choices. A generator must do more than produce traversable spaces — it has to produce situations.

## What Comes Next

The next stage is about death, the base, equipment, and character development. Without those, the climb would quickly become a very long staircase with rats.

Which kind of procedural floor do you prefer exploring: dense rooms and corridors, or large irregular spaces where danger can be spotted earlier? We read the replies and are willing to change decisions while the project is still flexible.
