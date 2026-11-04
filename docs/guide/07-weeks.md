# Weeks & Menus

A week is a `.json` file in `data/weeks/`. It decides which songs show up in Story Mode and Freeplay, which characters stand in the story menu, and how the menus look. Make it with the **Week Editor**.

## The Week Editor

Open it from the Editor Menu.

| Part | What's inside |
|---|---|
| **File** menu | Save (Ctrl + S), Save As, Load from JSON, Load Template. |
| **Color** menu | **Edit Week Color**: a color picker for the week's color. |
| **Week** tab | Songs, the three menu characters, background, display name, week file name, hide from Story Mode. |
| **Other** tab | Locked, hidden until unlocked, the week to finish to unlock it, difficulties. |
| **Menu Character** tab | Edit the story menu characters (see below). |
| **Freeplay** button | Opens the Freeplay part of the editor (see below). |

**Save** writes the week and, at the same time, every menu character you changed.

### Week color

The story menu has a colored band behind the characters, yellow in the base game. **Color > Edit Week Color** changes it for your week. The color is saved in the week as `"weekColor": [red, green, blue]`.

## Menu characters

The three characters in the story menu (opponent, boyfriend, girlfriend) are small `.json` files in `content/images/storymode/weekcharacters/` (the old Psych `images/menucharacters/` works too).

In the **Menu Character** tab:

1. Pick **Opponent**, **Boyfriend** or **Girlfriend** (or click the character).
2. Change the image, scale, idle and "HEY" animations, flip and antialiasing.
3. Move it with the **arrow keys** (Shift = 10x). **Space** plays the "HEY" animation.

```json
{
	"image": "menucharacters/my-character",
	"scale": 1,
	"position": [0, 0],
	"idle_anim": "my character idle",
	"confirm_anim": "my character hey",
	"flipX": false,
	"antialiasing": true
}
```

## Freeplay

Press **Freeplay** in the Week Editor to see the songs as they will look in Freeplay.

| Part | What's inside |
|---|---|
| **Freeplay** tab | Color of the selected song (red, green, blue, with copy and paste), its icon, hide the week from Freeplay. |
| **Background** box | A background image for the selected song, from `images/`. **Use BG Color** tints the image with the song's color. **Remove** goes back to the normal background. |

Each song in the week file is a list:

```json
"songs": [
	["my-song", "my-icon", [146, 113, 253]],
	["boss-song", "boss-icon", [255, 60, 60], "freeplay/boss-bg", true]
]
```

Song name, icon, color, and optionally the background image and "use BG color".
