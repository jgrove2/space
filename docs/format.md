# Object File Format (.txt)

Each object (ship, asteroid, station, etc.) is a plain-text `.txt` file placed under `ships/` (or another subdirectory of the project root). The engine's `lib/ship.lua` parser reads these files and the `Spawn` factory system dispatches to the appropriate loader.

## File structure

```
name: <display name>
font_size: <pixels>

[<section name>]
<content>
...
```

Sections are denoted by `[section_name]` in square brackets. Lines before the first section are header fields.

## Sections

### `[exterior]` (required)

The exterior (hull) grid. Each line is a row of characters. Empty/whitespace-only lines at the edges are automatically trimmed.

### `[interior]` (optional)

The interior grid. Same format as exterior. Only ships have interiors.

### `[thrusters]` (optional)

List of thruster positions and directions. Each line:
```
<row>,<col>,<direction>
```
Where `direction` is one of: `up`, `down`, `left`, `right`.

Thrusters can also be auto-detected from exterior tile characters if this section is omitted.

### `[palette]` (optional)

Custom palette overrides. Each line:
```
<key>=<r>,<g>,<b>
```
Where `key` is a single letter `a`–`p` and `r,g,b` are floats in range 0–1.

### `[colors_exterior]` / `[colors_interior]` (optional)

Per-tile color overrides. Each line:
```
<row>,<col>,<key>
```
Overrides the tile at (row,col) to use palette key instead of the character's default.

## Header fields

| Field | Default | Description |
|-------|---------|-------------|
| `name:` | "Unnamed" | Display name |
| `font_size:` | 24 | Tile size in pixels |

## Tile characters

Ships use the following character set. Other object types (asteroids, etc.) define their own tileset and may differ.

| Char | Glyph | Type | Color key |
|------|-------|------|-----------|
| `#` | █ | hull | a |
| `@` | ▓ | hull (bordered) | a |
| `.` | ░ | deck/floor | e |
| `/` | ╱ | slant SE | b |
| `\\` | ╲ | slant SW | b |
| `=` | ═ | horizontal wall | a |
| `|` | ║ | vertical wall | a |
| `-` | ─ | horizontal panel | b |
| `!` | │ | vertical panel | b |
| `+` | ┼ | junction | b |
| `[` | ╔ | corner top-left | a |
| `]` | ╗ | corner top-right | a |
| `{` | ╚ | corner bottom-left | a |
| `}` | ╝ | corner bottom-right | a |
| `o` | O | window | c |
| `*` | ◆ | console | h |
| `~` | ~ | conduit | h |
| `v^<>` | ▼▲◄► | thruster | f |
| `A` | A | airlock | c |
| `C` | C | captain's seat | g |
| `S` | ◈ | shield gen | h |
| `E` | ⊞ | engine | f |

## Walkable tiles (collision)

The following chars are walkable; all others are solid:

`.` `A` `C` `*` `~` `S` `E` `o`

## Example

```
name: Example Ship
font_size: 24

[exterior]
  ###
  #.#
  ###

[interior]
  [=]
  !.!
  {A}

[thrusters]
1,2,down
```
