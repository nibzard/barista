<!-- ABOUTME: Art direction for "Apocalypse Barista": look, feel, materials, palette, and production rules. -->
<!-- ABOUTME: Written in ASD-STE100 English. It extends section 20 of GAME_DESIGN.md. -->

# Apocalypse Barista — Art Direction

## 1. The big idea: sleep is a sketch, coffee is color

The world is a drawing that nobody finished.

Sleeping areas are pencil sketches: graphite lines on cream paper, pale washes, a lavender haze.
Awake areas are fully colored: pastel, colored pencil, and warm chalk light.
The player does not only wake people. The player colors the world in.

This rule connects the look to the game:

- A woken sleepwalker gets color back: first the face, then the clothes, from the cup hit outwards.
- A switched-off tower floods its city with color and morning light, from the tower outwards. This is the reward moment of every city (GAME_DESIGN.md, section 19, step 9).
- The café is always fully colored. It is the sanctuary because it is the only finished drawing.
- Mug Roasters Co. is the only thing that is not hand-drawn. Its posters, logo, and mascot are flat, glossy, perfect print. Perfection is the villain.

Three short rules for every artist and every asset:

1. **The world is pastel. The actors are pencil. The coffee is light.**
2. **Handmade means hope. Manufactured means sleep.**
3. **Funny before scary. Readable before beautiful.**

## 2. Tone

- The apocalypse is peaceful and silly, not terrible. Think of a Sunday morning where nobody got up.
- No blood, no rot, no horror dark. The darkest value in a scene is espresso brown, never black.
- Abandoned does not mean broken. Streets are quiet, plants grow over shop signs, laundry still hangs, a dog sleeps on a car roof.
- Every street tells one small story: a sleepwalker who sleep-waters a dead plant, a delivery robot stuck on a curb, a wedding cake on a bench.

## 3. Materials

The game uses four dry materials on one paper.

| Material | Job in the game |
| --- | --- |
| Cream toned paper | The ground for everything. Its grain shows through all colors. |
| Graphite | Contour lines and the sketch layer of sleeping areas. Broken, slightly loose lines. |
| Colored pencil | Form and color of characters and props. Hatching for shadows, never smooth gradients. |
| Soft pastel | Atmosphere: sky, light pools, haze, large ground areas. Soft edges, smudges. |
| White chalk | Steam, highlights, sparkle, and all interface text. The café chalkboard material. |

Rules for the materials:

- Shadows are hatched lines, not dark gradients. Hatching direction is consistent per scene: 45 degrees, from top-right.
- Contour lines are not closed everywhere. Leave small gaps where light hits.
- Pigment is uneven. The paper grain shows in every flat color.
- No digital airbrush, no clean vector gradients, no glow without texture. The only exception is Mug Roasters Co. (see section 8).
- Texture lives at large scale (ground, sky, walls). At the size of a character on a phone, the silhouette wins. Do not hatch a sprite into mud.

## 4. Palette

Eight world colors. Every asset uses these, plus their lighter and darker steps.

| Name | Hex | Role |
| --- | --- | --- |
| Warm cream | `#F3E6C8` | Paper, light, awake skin of the world |
| Espresso brown | `#3B2418` | Lines, darkest value, coffee |
| Brick red | `#A8432F` | Buildings, café accents, danger in friendly form |
| Buttery yellow | `#F2C866` | Morning light, coffee glow, rewards |
| Faded teal | `#5E9A94` | San Coffesco accent |
| Moss green | `#6F7F45` | Pourtland accent, plants |
| Rainy blue | `#6C87A6` | Steamtle accent, shade, water |
| Soft lavender | `#A99BC4` | Sleep haze, pajamas, dream |

The corporate pair is outside the world palette, on purpose:

| Name | Hex | Role |
| --- | --- | --- |
| Mug red | `#D6202A` | Mug Roasters Co. only |
| Mug black | `#151112` | Mug Roasters Co. only |

Value rules:

- The background stays in the middle values with low saturation.
- Characters have the strongest contrast in the scene: a dark espresso contour and the most saturated colors.
- Things the player can use (scavenge points, coffee, doors) get a warm buttery-yellow rim or chalk outline.
- Sleep zones lower saturation and push all colors toward lavender. They never go dark.

## 5. Light and time of day

- The game always plays in the early morning. The sun is low and warm. Shadows are long and point to the bottom-left.
- Light is buttery yellow on cream. Shade is rainy blue, not gray.
- Coffee is a light source. Every brewed cup, café window, and espresso machine casts a small warm glow.
- A sleep zone is a pocket of blue-lavender dusk inside the morning. Street lamps in a zone are still on, and they droop like tired flowers.
- After a tower switch-off, the city moves from dawn to full morning: the sun rises one step, the haze burns off, and birds come.

## 6. The cities

All cities share one block kit (GAME_DESIGN.md, section 17). The palette accent, the props, and the weather make the difference.

| City | Mood | Light and weather | Ground | Signature props |
| --- | --- | --- | --- | --- |
| San Coffesco | Sunny, teal, tech | Clear morning, light sea fog at the block edges | Steep street hatching, cable car tracks | Robotaxis, scooters, startup banners, cable car, a painted-lady row |
| Steamtle | Rainy, blue, cozy | Soft drizzle as chalk strokes, puddles that reflect the warm café light | Wet stone, green moss in the joints | Fish market stalls, flannel on chairs, a giant needle-shaped tower on the horizon, record shops |
| Pourtland | Earthy, mossy, odd | Overcast with sun breaks, falling leaves | Brick, roots through the sidewalk | Food carts, bikes, a doughnut shop, a hardware store, "Keep Pourtland Sleepy" graffiti |

The sleeping version of each city is the same scene with less color, more graphite, and lavender haze. The awake version adds people in windows, laundry, music from the café, and birds.

## 7. Characters

### Shared rules

- About 3.5 heads tall. Big heads, small bodies, large hands. Hands are drawn to hold a cup.
- Camera: top-down with a three-quarter front view of characters and building fronts, like classic top-down adventure games. Not pure top view, not isometric.
- Every character must read as a silhouette at one centimeter on a phone screen. Test every design as a solid espresso-brown shape before you color it.
- One strong shape per character: a hat, a belly, a camera, a hood. Not many small details.

### The barista

- An unlikely hero. Slightly too tired, very determined.
- Steampunk apron with brass buckles and too many pockets. Goggles on the forehead. Heavy boots.
- The beard, hair, and hat must read from the top-down view. The head is the largest shape, so hair and hats carry the identity.
- The barista is the warmest-colored character on every screen. The apron is brick red or espresso brown, with buttery-yellow brass.

### Sleepwalkers

- Pastel pajamas, nightcaps, slippers, sleep masks pushed up on the forehead.
- Arms out in front, for the hug. Eyes closed, a happy little smile.
- Drool is one white chalk arc with a shine dot. Comic, never gross.
- Sleepwalkers are drawn in the sketch style: lavender-washed color, but dark contours. They are hazards, so they must stay readable on a sleeping street.
- On wake-up: color fills the character from the cup hit, the eyes pop open, and a short surprised pose plays before the thanks.

| Type | Silhouette hook | Color note |
| --- | --- | --- |
| The Neighbor | Bathrobe, one slipper, coffee-less mug in hand | Lavender robe |
| The Tourist | Wide hat, big camera, fanny pack | Faded teal shirt with palms |
| The Tech Bro | Gray fleece vest, earbuds, a drone above | Gray with one teal logo |
| The Gamer | Hunched, headset, glowing-can shape | Lavender hoodie, rainy blue light on the face |
| The Tinfoil Man | Tall foil cone hat | The only shiny silver, drawn with white chalk |
| The Karen | Large round shape, sharp asymmetric haircut | Brick red cardigan, buttery yellow sunglasses |
| The Moonwalker | Leaned far back, one white glove, white socks | Deep red jacket, one sparkle on the glove |

### Masters and bosses

- Masters are drawn fully colored, like the café. They are already awake and they are allies.
- Bosses are large and theatrical. Each boss has one stage prop that is part of the fight read: Sam Oatman's slide screen, the fish market stall, the Sleep Jam's amplifiers.

## 8. Mug Roasters Co.

Mug Roasters Co. is the visual opposite of the hand-drawn world.

- Flat colors, perfect vector curves, no paper grain, no hatching. Only Mug red and Mug black, plus white.
- Muggy, the mascot, smiles too much. The smile is the same in every picture.
- Posters and billboards are slightly peeled, faded by the sun, and covered with hand-drawn graffiti from survivors.
- "JOIN THE GRIND" and Uncle Steam posters appear in every city.
- When the player wakes a city, survivors draw over the corporate signs with chalk.

## 9. Coffee is legendary

- Coffee equipment is drawn with the most care in the game. An espresso machine is like a sacred artifact: brass, steam, warm glow.
- Steam is always white chalk curls that boil slowly.
- A thrown cup leaves a short warm trail. The hit splashes in buttery yellow and espresso brown, with chalk sparkle.
- Every new brewing method gets a small reveal: a close-up on the tool, a chalk label, and a warm light pulse.

## 10. The café

- The café is the one place that is always warm, colored, and full of detail.
- Light: warm yellow pools from lamps and the espresso machine. The outside is visible through windows in cool morning blue.
- Details reward a long look: a chalk menu that changes with the progress of the player, photos of woken survivors on the wall, a record player, plants that grow over time.
- When the player enters, the haze stops and the color saturation goes up. When the player leaves, the world cools down.

## 11. Interface

The interface is part of the world: chalk, kraft paper, and coffee stains.

- Menus are café chalkboards with a wood frame. Text is hand-lettered white chalk.
- The awake meter is a mug. The coffee level in the mug is the meter. When it gets low, the mug cools and the steam stops.
- Cups in hand are small paper cup icons in a row.
- Wake-ups are five small alarm clocks. A used wake-up is a clock that rings and falls over.
- The SleepyDex is the only screen in phone style, but the entries are hand-drawn field-guide pages: a sketch of the type, notes, and the cure recipe as a café order ticket.
- Touch buttons are round coasters with a chalk icon. Icons replace words where possible (cup for throw, mug for drink, roll arrow for dodge).
- The interface uses the world palette. Mug red is never used for the interface, except on corporate screens.

### Typography

- Display text: a hand-lettered chalk face for titles and signs.
- Body text: a warm, rounded, very readable sans serif for dialog and menus. Readability on a phone wins over style.
- Both fonts need approval before they go into the project (open-font license only).

## 12. Motion

- Characters animate at 12 frames per second, "on twos", for a hand-made feel. Camera movement and projectiles stay smooth.
- Line boil: lines move very slightly at about 8 frames per second. Characters and steam boil. Backgrounds do not boil, or the screen gets tiring.
- Squash and stretch on hits, wake-ups, and dodge rolls.
- Sleepwalkers move with a slow sway, like they float.
- Every important change has a short reaction: a pause of 2 to 4 frames on a hit, a small camera push on a wake-up.

## 13. Readability rules

- A sleepwalker must be readable at one centimeter on a phone screen.
- Every hazard has an outline or haze that the player can see before it hurts.
- Sleep zone edges are always visible.
- Text on the screen must be at least 14 points on a phone.
- Test every new screen in grayscale. If the important things do not stand out, fix the values.

## 14. Production plan

### How to make the art

- The game needs one illustrator, or a small group with one lead, for the final art. The style depends on a real hand.
- Before production, the illustrator makes three style frames: one San Coffesco street (sleeping and awake), the café inside, and one character line-up. These frames define the game. Everything after them must match.
- Characters use cut-out animation: hand-drawn body parts on a skeleton (Skeleton2D). This is necessary for the character creator: hair, beard, goggles, hats, and tattoos are separate parts. Frame-by-frame animation for every combination is not possible.
- Scan real paper textures and real pencil and chalk marks. Use them for the shaders and brushes. Do not use a generic "paper filter".
- Image generators can help with early exploration, but they do not make final assets. The look must stay consistent and made by a human.

### What the engine does

The engine adds the shared look, so every asset matches without extra work:

- A paper grain overlay on the whole screen.
- A wobble shader for line boil on characters and steam.
- A color-fill shader: one value from 0 to 1 moves an asset or an area from sketch to full color. Wake-ups and tower switch-offs drive this value.
- A sleep haze shader: lavender tint, lower saturation, slow soft noise. It replaces the flat purple circles.
- Palette resources per city (`.tres`), linked from the city definition.
- 2D lights for the café glow and coffee light. The Compatibility renderer supports 2D lights, but use few of them for Android performance.

### Prototypes to follow

- `art/artboard/index.html` is the visual reference. Open it in a browser. It shows the style frame (one street, asleep and awake), the palette, the materials, the cast as silhouettes and in color, the barista options, the three city moods, the interface kit, and Mug Roasters Co.
- `game/scenes/prototypes/style_lab.tscn` is the playable prototype. Run `make lab`. Tap a sleepwalker to throw coffee and color it in. Tap "Switch off tower" to flood the street with morning. Tap "Next city" to see the three city looks.
- The engine parts of the prototype are ready for the real game: `game/shaders/` (hand_drawn, sleep_haze, paper_grain), `ColorFill` in `game/scripts/components/`, `ArtPalette`, and the `CityLook` resources in `game/resources/art/`.
- The style lab figures and street are placeholder shapes. Do not ship them. Real art replaces them.

### What the placeholder pass already wired into the live game (T045)

The in-house pass before the real art (T054) replaced the flat placeholder shapes with placeholder-quality vector art that follows this document:

- `SleeperFigure` (`game/scripts/components/sleeper_figure.gd`) builds every sleepwalker type from the silhouette hooks of section 7: 3.5 heads, oversized hands, pastel pajamas, nightcap or hat, and the white chalk drool arc. The one-centimeter readability rule is pinned by `game/tests/unit/test_silhouette_readability.gd`.
- `BaristaPortrait` rounds the player body and adds the oversized hands with a held cup; the steampunk apron and goggles ride the appearance catalog of the character creator.
- `CityLookStage` (`game/scripts/art/city_look_stage.gd`) wires one `CityLook` into live play: dusk `CanvasModulate`, the city weather, the paper grain overlay above the screen, and the sunrise tween when the tower switches off. Every city definition links its look (`city_look`), and the block kit draws the cream paper ground with the city accent.
- The sleep zones run the `sleep_haze` shader over the pole zones, draw the drooping lamp, and burn the haze off when the address dies.
- The broadcast tower wears the Mug Roasters Co. look: mug black and red, the smiling logo panel, and the chalk strike of the survivors after the switch-off.
- The interface theme (`ChalkTheme`, `game/scripts/ui/chalk_theme.gd`) puts the menus on chalkboards with a wood frame, and the SleepyDex phone rows carry the field-guide silhouette portraits.
- The awake meter reads as the mug of section 11 (`MugMeter`, `game/scripts/ui/mug_meter.gd`): the coffee level in the mug is the meter value, and below one quarter the steam stops and the coffee cools from buttery yellow toward rainy blue.

### Order of work

1. Palette resources and the interface theme (chalkboard, mug meter). Low cost, large effect.
2. Shaders: paper grain, sleep haze, color fill. They make the placeholder shapes look like a direction.
3. Silhouette pass: replace the rectangles with simple shapes that follow the silhouette hooks in section 7.
4. Style frames from the illustrator.
5. Final art, city by city, San Coffesco first because it is the free city and the first impression.
