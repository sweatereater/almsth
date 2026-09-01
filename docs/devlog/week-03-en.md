# Almsth Devlog #3: We Made an “Explore for Me” Button, Then Taught It Fear

Turn-based games have a strange contradiction. Important turns should demand attention, but a safe corridor does not become more interesting because the player pressed the same key twenty times.

During the third notional week, we added automatic exploration. Then we spent considerably more time defining every situation in which it must stop immediately.

## Automation Without Teleportation

Automatic exploration in Almsth does not move the protagonist instantly or simulate the result off-screen. It plans a route through the known part of the map and performs one normal gameplay step at a time. Enemies receive their turns, chests follow their ordinary rules, and the game state is saved just as it would be during manual movement.

The difficult part is not starting the route but ending it safely. Movement stops when an enemy becomes visible, nearby movement is heard, or an enemy occupies the next tile. Automation never attacks on its own. Any manual command cancels the route before being executed.

These sound like minor rules, but together they determine whether the player can trust the button. If auto-exploration walks the protagonist into danger even once, the perfectly reasonable response is to do everything manually forever.

![A noise in the darkness](../../builds/previews/hearing-en-960x540-zoom-66-composite.png)

*Hearing does not reveal the enemy or the map geometry. It merely reports that something nearby may disapprove of your eight remaining HP.*

## Hearing, Not X-Ray Vision

Fog of war works well while enemies act only inside the visible part of the map. Ranged attacks created a problem: the player could take damage from the darkness without understanding even the approximate direction of the threat.

That led to noise contacts. If the protagonist can hear a hidden enemy, an anonymous question mark briefly appears on the map. It does not reveal the enemy’s name, health, or exact type, and it does not uncover unknown tiles. It is a clue, not free reconnaissance.

Hearing also had to interact with waiting and automated routes. Sequences of 10 or 100 skipped turns now stop when danger appears, damage is taken, or a new contact is heard. Otherwise, the convenient Wait button could carefully escort the protagonist to death in a few seconds — technically without a single bug.

## Active Abilities and Three Map Scales

Combat also became less repetitive. We added a common registry of active abilities, four assignable slots, mana, and cooldowns. Different development paths gained a magical projectile, a dash, a double attack, and a circular attack. We will keep the complete progression chain hidden for now, but the main principle is simple: abilities should change positioning and combat tempo instead of merely multiplying damage by 1.2.

![Selecting a destination for Dash](../../builds/previews/status-menu-en-1280x720-dash-mixed-66.png)

*Dash turned out to be more than “move three tiles.” It needed separate agreements with walls, closed doors, corners, creatures, chests, and fog of war.*

The dungeon also gained three scales: an overview map, a tactical view, and a detailed view. Scale affects presentation only. Coordinates, attack ranges, visibility, AI, and turn counts remain unchanged. Zooming the camera should not mysteriously make a bow shorter.

We rebuilt the dungeon interface around the map. Concise information about the protagonist and selected target remains on the right, while actions stay at the bottom. The previous version sincerely tried to show everything at once and mostly succeeded at showing its own effort.

![Three gameplay scales](../../tmp/visual-overhaul-preview-contact.png)

*The same situation at different scales. The mechanics stay unchanged; only the amount of surrounding context changes.*

## Bug of the Week: Procedural Generation Defeated the Test

During final verification, a smoke test suddenly failed. The reason was suspicious: the randomly generated floor did not contain two suitable tiles near the entrance where the test wanted to place its targets.

The game was working correctly. The floor was traversable. The test scenario was broken because it silently expected convenient geometry.

We assigned seed `1001` to that test and ran it successfully five times in a row. It was a useful reminder that tests need predictable scenes. Otherwise, procedural generation is testing the developer’s patience instead of the game.

A separate long-running test then created 500 floors, checked hundreds of rare-object appearances, and performed 1,200 random actions. Rare bugs can still exist, but they now have considerably less room to hide.

## This Week in Short

**Added:** automatic exploration, a route to discovered stairs, long waits, noise contacts, active abilities, cooldowns, three map scales, and a more compact HUD.

**Fixed:** automatic actions stop before a dangerous step; generation tests now use reproducible conditions.

**Discovered:** a convenience feature can require more safety rules than the main mechanic. The “explore automatically” button occupies one line of the interface and quite a few lines of code.

## What Comes Next

Next, we want to deepen the dungeon itself: more expressive spaces, sealed rooms, new enemies, and visual details that distinguish floors by more than their number.

Should auto-exploration stop at every audible noise, even when the source is far away, or only when danger is a few steps away? The first option is safer; the second is faster. Which one would you trust more?
