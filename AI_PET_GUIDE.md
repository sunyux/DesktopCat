# Create Your Own DesktopCat Pet with AI

DesktopCat supports either:

1. A single static PNG, JPEG, or GIF.
2. A complete animation pack containing twelve named GIF files.

## Fast option: one transparent image

Attach several clear photos of your pet to an image-generation tool and use:

```text
Create one clean full-body desktop-pet sprite based faithfully on my reference photos.

Identity requirements:
- preserve the pet's species, face, eye color, nose color, fur pattern, body proportions, age, and distinctive markings
- use a compact readable silhouette
- show the entire pet with generous padding
- natural realistic fur with slightly simplified detail for display at 220x220 pixels

Pose: comfortably resting, facing slightly toward the viewer.
Background: fully transparent.

Do not add scenery, floor, shadows, text, borders, props, glow, loose particles, extra limbs, collars, or accessories that are not present in the references.

Output: square PNG, 1024x1024, transparent background.
```

Then open DesktopCat:

`🐾 DesktopCat → Pet appearance → Choose a single image…`

Transparent PNG gives the best result.

## Full animated pet

A complete pack uses these filenames:

```text
idle.gif
running-left.gif
running-right.gif
waving.gif
jumping.gif
failed.gif
waiting.gif
running.gif
review.gif
belly.gif
todo-loaf.gif
timer-yawn.gif
```

Generate each animation as a horizontal strip first, then export its frames as a transparent looping GIF.

Use this shared identity block in every prompt:

```text
Use all attached pet photos as strict identity references. Preserve exactly the same face, eye color, nose color, fur markings, body proportions, age, palette, and material in every frame. Keep the full body visible and the apparent scale stable.

Output separate, evenly spaced full-body poses on a perfectly flat chroma-key background. No scenery, text, borders, shadows, blur, detached effects, overlapping poses, cropped body parts, or identity drift.
```

State prompts:

- `idle.gif`: sleeping or quiet breathing loop, 4–6 frames
- `running-left.gif`: left-facing walking loop, 8 frames
- `running-right.gif`: right-facing walking loop, 8 frames
- `waving.gif`: friendly paw wave, 4 frames
- `jumping.gif`: crouch, lift, peak, descent, settle, 5 frames
- `failed.gif`: gentle slumped reaction, 6–8 frames
- `waiting.gif`: patient expectant pose, 6 frames
- `running.gif`: focused working/thinking in place, 6 frames
- `review.gif`: attentive inspection and head tilt, 6 frames
- `belly.gif`: relaxed belly-rub reaction, 5 frames
- `todo-loaf.gif`: calm loaf with blink and ear movement, 4 frames
- `timer-yawn.gif`: seated yawn sequence, 5 frames

Keep every final frame at `220x220` with a transparent background and save each GIF as an infinite loop.

Import the folder using:

`🐾 DesktopCat → Pet appearance → Import animation-pack folder…`

## Multiple pets

Use a transparent PNG for each companion pet, then choose:

`🐾 DesktopCat → Multiple pets → Add companion pet…`

Each companion can be moved and resized independently.
