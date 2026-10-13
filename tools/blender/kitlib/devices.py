"""The puzzle stations and the house's devices (the visual rework V4d, the
kit's fifth rollout batch): the home computer and its printer (server/
Puzzles/Terminal), the fuse box, its breakers and its main switch (Puzzles/
Breaker), the cabinet radio on its side table (World/PropFactory's Radio),
the wall safe, its door and the painting over it (Puzzles/Safe), the music
box (Puzzles/MusicBox), the twin levers (Puzzles/Levers), the kettle and the
record player (Services/InteractService), the baby monitor (Services/
MonitorService), the tin robot (Services/ToyService), and the servants'
bell board and its bells (Services/BellBoardService).

What lights or moves stays the game's: the computer's screen, the radio's
dial and needle, the safe's dial (it holds its prompt), the music box's comb
and coloured teeth, the lever's lamp, the monitor's lamp, the robot's eyes,
the bell board's flags and labels. The pieces are built round them, in the
game's own frame (things.G, S), as kitlib/things is.
"""

import math
import random

import bmesh
import bpy

from . import materials, paintings, shapes
from .decor import FRAME_PROFILE, _canvas
from .house import _chrome, _porcelain, _steel
from .things import G, S, _box, _dark, _gilt, _lathe, _new, _ring, _sphere, _torus, _tube

BEIGE = (196, 186, 162)


def _beige(name, shade=1.0):
    return materials.paint(name, color=tuple(int(c * shade) for c in BEIGE), roughness=0.5, grime=0.3)


def _led(name, color):
    """A lamp that glows by itself (the importer carries its glow mask)."""
    mat = materials.paint(name, color=color, roughness=0.3, grime=0.0)
    mat["glow"] = 1.0
    return mat


def _bakelite(name, color=(34, 28, 24)):
    return materials.paint(name, color=color, roughness=0.3, grime=0.1)


# The home computer (Puzzles/Terminal) ------------------------------------------


def home_computer():
    """A 1988 home computer on a desk, 4.2 x 1.75 x 2.2, round World/
    Puzzles/Terminal's `top` (the desk's surface, +z toward whoever sits
    there): a beige CRT monitor on a swivel stand, its bezel round the
    game's glowing screen (kept), a power lamp and its knobs; the breadbin
    keyboard before it; a dot-matrix printer to its right, continuous paper
    rising out of its tractor."""
    beige = _beige("ComputerBeige")
    dark_beige = _beige("ComputerShade", 0.82)
    tube = _dark("ComputerTube", (10, 14, 12), 0.2)
    vent = _dark("ComputerVent", (40, 36, 30), 0.7)
    key = materials.paint("Keycap", color=(92, 78, 64), roughness=0.4, grime=0.2)
    fkey = materials.paint("FunctionKey", color=(170, 150, 112), roughness=0.4, grime=0.2)
    smoked = materials.paint("PrinterLid", color=(70, 64, 58), roughness=0.15, grime=0.1)
    paper = materials.paint("TractorPaper", color=(236, 234, 222), roughness=0.85, grime=0.1)
    green = _led("PowerLamp", (90, 255, 120))
    badge = _chrome("ComputerBadge")
    parts = []
    mx = -1.2
    # The monitor's bezel, round the screen's opening (y 0.45..1.55).
    for size, at in (
        ((1.9, 0.3, 0.08), (mx, 0.3, 0.75)),
        ((1.9, 0.2, 0.08), (mx, 1.65, 0.75)),
        ((0.22, 1.1, 0.08), (mx - 0.84, 1.0, 0.75)),
        ((0.22, 1.1, 0.08), (mx + 0.84, 1.0, 0.75)),
    ):
        parts.append(materials.assign(_box("Bezel", size, at, 0.02), beige))
    # (A chamfered lip into the glass.)
    for size, at in (
        ((1.5, 0.04, 0.05), (mx, 0.47, 0.73)),
        ((1.5, 0.04, 0.05), (mx, 1.53, 0.73)),
        ((0.04, 1.1, 0.05), (mx - 0.74, 1.0, 0.73)),
        ((0.04, 1.1, 0.05), (mx + 0.74, 1.0, 0.73)),
    ):
        parts.append(materials.assign(_box("Lip", size, at, 0.008), dark_beige))
    parts.append(materials.assign(_box("Tube", (1.46, 1.1, 0.4), (mx, 1.0, 0.52), 0.0), tube))
    parts.append(materials.assign(_box("Case", (1.86, 1.56, 0.5), (mx, 0.95, 0.45), 0.05, 3), beige))
    parts.append(materials.assign(_box("Back", (1.4, 1.2, 0.9), (mx, 1.0, -0.25), 0.12, 3), dark_beige))
    for k in range(6):
        parts.append(materials.assign(_box("Vent", (1.0, 0.012, 0.05), (mx, 1.605, -0.05 - k * 0.1), 0.0), vent))
    parts.append(materials.assign(_box("Badge", (0.36, 0.05, 0.01), (mx - 0.5, 0.3, 0.792), 0.003), badge))
    parts.append(materials.assign(shapes.roll("Lamp", 0.012, 0.025, G(mx + 0.62, 0.3, 0.795), axis="Y", steps=10), green))
    for x in (mx + 0.32, mx + 0.45):
        parts.append(materials.assign(shapes.roll("Knob", 0.04, 0.035, G(x, 0.3, 0.8), axis="Y", steps=10), vent))
    stand = _lathe("Stand", [(0.0, 0.0), (0.5, 0.0), (0.5, 0.05), (0.42, 0.09), (0.2, 0.13), (0.2, 0.17), (0.0, 0.17)], (mx, 0, 0), steps=28)
    stand.scale = (1.0, 0.85, 1.0)
    shapes.apply_transform(stand)
    parts.append(materials.assign(stand, dark_beige))
    # The breadbin keyboard, its keys on the slope.
    kz = 1.15
    profile = [(0.3, 0.0), (-0.3, 0.0), (-0.3, 0.05), (-0.24, 0.075), (0.22, 0.16), (0.3, 0.16)]
    breadbin = shapes.moulding("Keyboard", profile, 1.7, G(mx, 0, kz))
    shapes.bevel(breadbin, 0.012, 2, angle=30)
    parts.append(materials.assign(breadbin, beige))
    slope = math.degrees(math.atan2(0.085, 0.46))
    rows = 5
    for r in range(rows):
        z = kz + 0.2 - r * 0.085
        y = 0.13 - r * 0.016
        for c in range(15):
            x = mx - 0.7 + c * 0.088 + (r % 2) * 0.03
            if r == rows - 1 and 3 <= c <= 10:
                continue
            cap = _box("Key", (0.07, 0.03, 0.07), (0, 0, 0), 0.008, 1)
            shapes.turn(cap, (slope, 0, 0), G(x, y, z))
            parts.append(materials.assign(cap, key))
    space = _box("Space", (0.62, 0.03, 0.07), (0, 0, 0), 0.008, 1)
    shapes.turn(space, (slope, 0, 0), G(mx - 0.02, 0.13 - (rows - 1) * 0.016, kz + 0.2 - (rows - 1) * 0.085))
    parts.append(materials.assign(space, key))
    for r in range(4):
        cap = _box("FKey", (0.1, 0.03, 0.07), (0, 0, 0), 0.008, 1)
        shapes.turn(cap, (slope, 0, 0), G(mx + 0.72, 0.13 - r * 0.016, kz + 0.2 - r * 0.085))
        parts.append(materials.assign(cap, fkey))
    # The printer: its body, the smoked lid, the platen, paper rising and
    # curling back over its tractor.
    px, pz = 1.3, 0.1
    parts.append(materials.assign(_box("Printer", (1.5, 0.32, 1.0), (px, 0.16, pz), 0.04, 3), beige))
    parts.append(materials.assign(_box("Lid", (1.3, 0.12, 0.55), (px, 0.37, pz + 0.18), 0.03, 2), smoked))
    parts.append(materials.assign(_box("Back", (1.5, 0.18, 0.35), (px, 0.4, pz - 0.32), 0.03, 2), dark_beige))
    parts.append(materials.assign(shapes.roll("Platen", 1.3, 0.05, G(px, 0.47, pz - 0.2), axis="X", steps=14), vent))
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.roll("Knob", 0.06, 0.06, G(px + sx * 0.78, 0.4, pz - 0.2), axis="X", steps=12), vent))
    sheet = []
    for k in range(9):
        t = k / 8
        sheet.append((px, 0.5 + 0.55 * math.sin(t * math.pi * 0.62), pz - 0.22 - 0.3 * t * t))
    for a, b in zip(sheet, sheet[1:]):
        mid = [(a[i] + b[i]) / 2 for i in range(3)]
        length = math.dist(a, b)
        leaf = _box("Paper", (1.1, length + 0.01, 0.006), (0, 0, 0), 0.0)
        tilt = math.degrees(math.atan2(b[2] - a[2], b[1] - a[1]))
        shapes.turn(leaf, (tilt, 0, 0), G(*mid))
        parts.append(materials.assign(leaf, paper))
    parts.append(materials.assign(_box("Tray", (1.1, 0.02, 0.3), (px, 0.06, pz + 0.62), 0.006), dark_beige))
    parts.append(materials.assign(shapes.roll("Lamp", 0.012, 0.022, G(px + 0.6, 0.12, pz + 0.502), axis="Y", steps=10), green))
    piece = shapes.join(parts, "HomeComputer")
    piece["bake_size"] = 1024
    return piece


# The fuse box (Puzzles/Breaker) ------------------------------------------------------


def fuse_box():
    """A grey steel fuse box on a wall, 1.9 x 2.6 x 2.2, round its frame on
    the wall (+z out of it): open-fronted, the dead-front panel inside with
    the DIN strip its breakers sit on, a dark band for their pilot lamps, the
    main switch's housing, a ruled circuit card; conduit up to the ceiling's
    run; its door swung open to the left, the schedule card taped inside
    it. The breakers, their toggles and the main switch are their own
    (BreakerModule, BreakerToggle, MainSwitch); the lamps are the game's."""
    steel = _steel("FuseSteel", (110, 116, 112), 0.4, 0.4)
    panel = _steel("FusePanel", (92, 98, 94), 0.5, 0.35)
    dark = _dark("FuseDark", (26, 26, 28), 0.5)
    card = materials.paint("FuseCard", color=(228, 220, 196), roughness=0.85, grime=0.3)
    ink = _dark("FuseInk", (40, 36, 60), 0.8)
    warn = materials.paint("FuseWarning", color=(212, 176, 40), roughness=0.5, grime=0.3)
    parts = []
    w, h, d = 1.8, 2.4, 0.4
    parts.append(materials.assign(_box("Back", (w, h, 0.04), (0, 0, 0.02), 0.01), steel))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Side", (0.06, h, d), (sx * (w / 2 - 0.03), 0, d / 2), 0.01), steel))
    for sy in (-1, 1):
        parts.append(materials.assign(_box("End", (w, 0.06, d), (0, sy * (h / 2 - 0.03), d / 2), 0.01), steel))
    # The flange round the opening.
    for size, at in (((w + 0.06, 0.08, 0.04), (0, h / 2, d)), ((w + 0.06, 0.08, 0.04), (0, -h / 2, d)), ((0.08, h, 0.04), (w / 2, 0, d)), ((0.08, h, 0.04), (-w / 2, 0, d))):
        parts.append(materials.assign(_box("Flange", size, at, 0.012), steel))
    parts.append(materials.assign(_box("Panel", (1.6, 2.2, 0.02), (0, 0, 0.35), 0.006), panel))
    parts.append(materials.assign(_box("Strip", (1.52, 0.44, 0.02), (0, 0.3, 0.365), 0.004), dark))
    parts.append(materials.assign(_box("LampBand", (1.52, 0.12, 0.012), (0, 0.62, 0.366), 0.002), dark))
    parts.append(materials.assign(_box("MainHousing", (0.46, 0.62, 0.06), (0, -0.6, 0.37), 0.015), dark))
    parts.append(materials.assign(_box("Card", (0.9, 0.42, 0.004), (0, -0.05, 0.362), 0.0), card))
    for k in range(5):
        parts.append(materials.assign(_box("Rule", (0.8, 0.006, 0.002), (0, 0.1 - k * 0.07, 0.365), 0.0), ink))
    parts.append(materials.assign(_box("Warning", (0.5, 0.14, 0.004), (0.5, -1.0, 0.362), 0.0), warn))
    for x in (-0.45, 0.45):
        parts.append(materials.assign(shapes.roll("Conduit", 0.18, 0.05, G(x, h / 2 + 0.09, 0.2), axis="Z", steps=12), steel))
        parts.append(materials.assign(shapes.roll("Gland", 0.06, 0.07, G(x, h / 2 + 0.01, 0.2), axis="Z", steps=12), steel))
    # The door, swung open on its left hinge, square to the wall.
    dx = -0.93
    parts.append(materials.assign(_box("Door", (0.04, h, 1.8), (dx, 0, 1.3), 0.012), steel))
    for z in (0.5, 2.1):
        parts.append(materials.assign(_box("Lip", (0.06, h, 0.04), (dx, 0, z), 0.01), steel))
    parts.append(materials.assign(_box("Schedule", (0.004, 1.0, 0.8), (dx + 0.024, 0.25, 1.35), 0.0), card))
    for k in range(7):
        parts.append(materials.assign(_box("Line", (0.002, 0.008, 0.66), (dx + 0.027, 0.6 - k * 0.11, 1.35), 0.0), ink))
    parts.append(materials.assign(_box("Latch", (0.05, 0.22, 0.06), (dx - 0.04, -0.2, 2.08), 0.012), dark))
    for y in (0.85, -0.85):
        parts.append(materials.assign(shapes.roll("Hinge", 0.3, 0.025, G(-0.91, y, 0.42), axis="Z", steps=10), steel))
    piece = shapes.join(parts, "FuseBox")
    piece["bake_size"] = 1024
    return piece


def breaker_module():
    """A breaker's black body, 0.15 x 0.36 x 0.08, its slot for the toggle and
    a white label strip, round its middle (Puzzles/Breaker places one where
    each breaker is)."""
    bakelite = _bakelite("BreakerBody")
    slot = _dark("BreakerSlot", (8, 8, 8), 0.8)
    label = materials.paint("BreakerLabel", color=(226, 222, 206), roughness=0.7, grime=0.2)
    parts = [materials.assign(_box("Body", (0.15, 0.36, 0.08), (0, 0, 0), 0.012), bakelite)]
    parts.append(materials.assign(_box("Slot", (0.07, 0.14, 0.01), (0, 0.03, 0.038), 0.002), slot))
    parts.append(materials.assign(_box("Label", (0.12, 0.05, 0.004), (0, -0.13, 0.041), 0.0), label))
    piece = shapes.join(parts, "BreakerModule")
    piece["bake_size"] = 128
    return piece


def breaker_toggle():
    """A breaker's toggle, built standing up from its pivot (y = 0) out of
    its slot: a short stem and a rounded grip (Puzzles/Breaker tilts it up
    for on, down for off)."""
    grip = _bakelite("ToggleGrip", (46, 44, 42))
    parts = [materials.assign(_box("Stem", (0.05, 0.1, 0.04), (0, 0.05, 0), 0.01), grip)]
    parts.append(materials.assign(_box("Grip", (0.07, 0.06, 0.06), (0, 0.12, 0.005), 0.02), grip))
    piece = shapes.join(parts, "BreakerToggle")
    piece["bake_size"] = 128
    return piece


def main_switch():
    """The main switch's red handle, built standing up from its pivot, a
    white ON/OFF plate behind it (Puzzles/Breaker drops it when the main
    trips)."""
    red = materials.paint("MainRed", color=(160, 30, 26), roughness=0.3, grime=0.15)
    steel = _chrome("MainPivot")
    parts = [materials.assign(shapes.roll("Pivot", 0.2, 0.04, G(0, 0, 0), axis="X", steps=12), steel)]
    parts.append(materials.assign(_box("Arm", (0.1, 0.24, 0.06), (0, 0.12, 0.02), 0.02), red))
    parts.append(materials.assign(_box("Grip", (0.22, 0.08, 0.1), (0, 0.25, 0.04), 0.03), red))
    piece = shapes.join(parts, "MainSwitch")
    piece["bake_size"] = 128
    return piece


# The radio (World/PropFactory's Radio) ------------------------------------------------


def radio():
    """A walnut cabinet radio on its side table, 2.4 x 5 x 1.9 (World/
    PropFactory.buildTellBase "Radio"): tapered legs and a lower shelf; the
    cabinet with rounded shoulders, a cloth grille behind a fret of slats, a
    brass bezel round the game's lit dial and its needle (both kept), two
    bakelite knobs, a telescopic aerial leaning back."""
    walnut = materials.wood("RadioWalnut", (58, 36, 22), (112, 74, 46), grain_axis="X", scale=1.3, roughness=0.3)
    walnut_up = materials.wood("RadioWalnutUp", (58, 36, 22), (112, 74, 46), grain_axis="Z", scale=1.3, roughness=0.3)
    cloth = materials.fabric("RadioCloth", color=(120, 100, 72))
    brass = materials.brass("RadioBrass", color=(170, 132, 70), roughness=0.3)
    knob = _bakelite("RadioKnob", (196, 186, 160))
    chrome = _chrome("RadioAerial")
    parts = []
    parts.append(materials.assign(_box("Top", (2.4, 0.08, 1.9), (0, 2.56, 0), 0.03, 2), walnut))
    parts.append(materials.assign(_box("Apron", (2.2, 0.18, 1.7), (0, 2.43, 0), 0.02, 2), walnut))
    parts.append(materials.assign(_box("Shelf", (2.1, 0.08, 1.6), (0, 0.8, 0), 0.02, 2), walnut))
    for sx in (-1, 1):
        for sz in (-1, 1):
            leg = _lathe("Leg", [(0.0, 0.0), (0.05, 0.0), (0.055, 0.1), (0.075, 1.8), (0.08, 2.34), (0.0, 2.34)], (sx * 1.05, 0.0, sz * 0.8), steps=10)
            parts.append(materials.assign(leg, walnut_up))
    # The cabinet (y 2.6..3.65, z -0.525..0.325).
    cab = _box("Cabinet", (1.9, 1.05, 0.85), (0, 3.125, -0.1), 0.12, 4)
    parts.append(materials.assign(cab, walnut))
    parts.append(materials.assign(_box("Plinth", (1.96, 0.06, 0.9), (0, 2.63, -0.1), 0.02, 2), walnut))
    parts.append(materials.assign(_box("Grille", (0.86, 0.74, 0.02), (-0.4, 3.13, 0.33), 0.0), cloth))
    for k in range(7):
        x = -0.4 - 0.36 + k * 0.12
        parts.append(materials.assign(_box("Slat", (0.03, 0.76, 0.03), (x, 3.13, 0.345), 0.008), walnut_up))
    parts.append(materials.assign(_box("Fret", (0.92, 0.04, 0.04), (-0.4, 3.53, 0.345), 0.01), walnut))
    parts.append(materials.assign(_box("Fret", (0.92, 0.04, 0.04), (-0.4, 2.73, 0.345), 0.01), walnut))
    # The dial's brass bezel, round the game's glowing glass.
    for size, at in (
        ((0.82, 0.05, 0.04), (0.45, 3.495, 0.355)),
        ((0.82, 0.05, 0.04), (0.45, 3.145, 0.355)),
        ((0.05, 0.4, 0.04), (0.06, 3.32, 0.355)),
        ((0.05, 0.4, 0.04), (0.84, 3.32, 0.355)),
    ):
        parts.append(materials.assign(_box("Bezel", size, at, 0.01), brass))
    for x in (0.25, 0.65):
        parts.append(materials.assign(_lathe("Knob", [(0.0, 0.0), (0.1, 0.0), (0.095, 0.05), (0.07, 0.08), (0.0, 0.085)], steps=16), knob))
        shapes.turn(parts[-1], (90, 0, 0), G(x, 2.9, 0.33))
    aerial = _tube("Aerial", [(0.493, 3.6, -0.074), (0.6, 3.96, -0.24), (0.7, 4.3, -0.4), (0.8, 4.65, -0.56), (0.9, 4.98, -0.72)], [0.028, 0.024, 0.02, 0.016, 0.013], 8)
    parts.append(materials.assign(aerial, chrome))
    parts.append(materials.assign(_sphere("Tip", 0.03, (0.905, 5.0, -0.73), 8, 5), chrome))
    piece = shapes.join(parts, "Radio")
    piece["bake_size"] = 1024
    return piece


# The wall safe (Puzzles/Safe) ----------------------------------------------------------


def wall_safe():
    """The wall safe's steel box, 1.8 x 1.8 x 0.92, round its frame on the
    wall (+z out): open-fronted (what it keeps shows once its door swings),
    its walls, a flange round the opening, a riveted edge. Its door is
    SafeDoor; the painting over it SafePainting."""
    steel = _steel("SafeSteel", (88, 92, 92), 0.35, 0.4)
    inside = _dark("SafeInside", (34, 34, 34), 0.7)
    rivet = _chrome("SafeRivet")
    parts = [materials.assign(_box("Back", (1.7, 1.7, 0.1), (0, 0, 0.05), 0.01), inside)]
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Side", (0.1, 1.7, 0.9), (sx * 0.8, 0, 0.45), 0.015), steel))
    for sy in (-1, 1):
        parts.append(materials.assign(_box("Wall", (1.7, 0.1, 0.9), (0, sy * 0.8, 0.45), 0.015), steel))
    parts.append(materials.assign(_box("Floor", (1.5, 0.02, 0.8), (0, -0.74, 0.45), 0.0), inside))
    for size, at in (((1.8, 0.1, 0.04), (0, 0.85, 0.9)), ((1.8, 0.1, 0.04), (0, -0.85, 0.9)), ((0.1, 1.6, 0.04), (0.85, 0, 0.9)), ((0.1, 1.6, 0.04), (-0.85, 0, 0.9))):
        parts.append(materials.assign(_box("Flange", size, at, 0.012), steel))
    for k in range(8):
        a = k * math.tau / 8
        x, y = 0.86 * math.copysign(1, math.cos(a)) if abs(math.cos(a)) > 0.7 else 0.6 * math.cos(a), 0.86 * math.copysign(1, math.sin(a)) if abs(math.sin(a)) > 0.7 else 0.6 * math.sin(a)
        parts.append(materials.assign(_sphere("Rivet", 0.02, (x, y, 0.92), 6, 4), rivet))
    piece = shapes.join(parts, "WallSafe")
    piece["bake_size"] = 512
    return piece


def safe_door():
    """The safe's door, 1.66 x 1.66 x 0.22, round the middle of its slab: a
    bevelled steel face with a recessed field, a chrome bezel round the
    game's dial (kept: it holds the dial's prompt), a three-spoked handle,
    its hinge barrels on the left, the bolt-work along its right edge."""
    steel = _steel("SafeDoorSteel", (96, 100, 100), 0.3, 0.35)
    chrome = _chrome("SafeChrome")
    dark = _dark("SafeDoorDark", (30, 30, 32), 0.5)
    parts = [materials.assign(_box("Slab", (1.6, 1.6, 0.12), (0, 0, 0), 0.03, 3), steel)]
    parts.append(materials.assign(_box("Field", (1.3, 1.3, 0.03), (0, 0, 0.07), 0.04, 3), steel))
    parts.append(materials.assign(_ring("Bezel", 0.33, 0.02, (0.15, 0.15, 0.08), (90, 0, 0), 28), chrome))
    parts.append(materials.assign(shapes.roll("Hub", 0.06, 0.05, G(-0.45, -0.35, 0.1), axis="Y", steps=12), chrome))
    for k in range(3):
        a = k * math.tau / 3 + 0.3
        tip = (-0.45 + math.cos(a) * 0.22, -0.35 + math.sin(a) * 0.22, 0.11)
        parts.append(materials.assign(_tube("Spoke", [(-0.45, -0.35, 0.11), tip], 0.016, 8), chrome))
        parts.append(materials.assign(_sphere("Ball", 0.03, tip, 8, 5), chrome))
    for y in (0.5, -0.5):
        parts.append(materials.assign(shapes.roll("Hinge", 0.3, 0.04, G(-0.82, y, 0.0), axis="Z", steps=12), steel))
    for y in (0.45, 0.0, -0.45):
        parts.append(materials.assign(shapes.roll("Bolt", 0.06, 0.035, G(0.83, y, 0.0), axis="X", steps=10), dark))
    piece = shapes.join(parts, "SafeDoor")
    piece["bake_size"] = 512
    return piece


def safe_painting():
    """The painting over the safe, 2.4 x 2.2 x 0.14, round the middle of its
    frame: a narrower gilt moulding, an evening landscape (kitlib/
    paintings, its own seed)."""
    w, h = 2.4, 2.2
    profile = [(u * 0.6, d * 0.56) for u, d in FRAME_PROFILE]
    frame = materials.assign(shapes.frame("Frame", w, h, profile), _gilt("SafeFrameGilt"))
    canvas = _canvas("Canvas", paintings.evening_hills(seed=71), w - 0.36 + 0.05, h - 0.36 + 0.05, 0.05)
    piece = shapes.join([frame, canvas], "SafePainting")
    # Round the frame's middle: its back was on the wall (y = 0).
    piece.location.y += 0.07
    shapes.select_only(piece)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    piece["bake_size"] = 512
    return piece


# The music box (Puzzles/MusicBox) -------------------------------------------------------


def music_box():
    """A walnut music box, 1.24 x 1.3 x 0.86 with its lid up (Puzzles/
    MusicBox's box), standing on y = 0: inlaid sides, a brass bed plate and
    the pinned cylinder the game's comb and coloured teeth (kept) play on, the
    lid thrown back with a mirror inside, the winding key at its side."""
    walnut = materials.wood("MusicWalnut", (60, 34, 20), (118, 72, 42), grain_axis="X", scale=1.6, roughness=0.25)
    inlay = materials.wood("MusicInlay", (170, 140, 96), (210, 180, 130), grain_axis="X", scale=3.0, roughness=0.3)
    brass = materials.brass("MusicBrass", color=(176, 142, 80), roughness=0.3)
    velvet = materials.velvet("MusicVelvet", color=(90, 26, 34))
    mirror = materials.brass("MusicMirror", color=(170, 176, 180), roughness=0.06)
    w, h, d, t = 1.2, 0.4, 0.8, 0.05
    parts = [materials.assign(_box("Floor", (w, 0.05, d), (0, 0.025, 0), 0.01), walnut)]
    for sz in (-1, 1):
        parts.append(materials.assign(_box("Side", (w, h + 0.04, t), (0, (h + 0.04) / 2, sz * (d / 2 - t / 2)), 0.012), walnut))
        parts.append(materials.assign(_box("Inlay", (w - 0.2, 0.05, 0.004), (0, 0.2, sz * (d / 2 + 0.002)), 0.0), inlay))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("End", (t, h + 0.04, d - 2 * t), (sx * (w / 2 - t / 2), (h + 0.04) / 2, 0), 0.012), walnut))
    parts.append(materials.assign(_box("Bed", (w - 2 * t, 0.02, d - 2 * t), (0, 0.39, 0), 0.0), velvet))
    parts.append(materials.assign(_box("Plate", (1.04, 0.02, 0.3), (0, 0.405, -0.12), 0.004), brass))
    cylinder = shapes.roll("Cylinder", 0.9, 0.06, G(0, 0.46, -0.3), axis="X", steps=18)
    parts.append(materials.assign(cylinder, brass))
    rng = random.Random(4)
    for k in range(26):
        x = rng.uniform(-0.42, 0.42)
        a = rng.uniform(0, math.tau)
        parts.append(materials.assign(_box("Pin", (0.008, 0.012, 0.008), (x, 0.46 + math.sin(a) * 0.065, -0.3 + math.cos(a) * 0.065), 0.0), brass))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Bearing", (0.04, 0.12, 0.12), (sx * 0.47, 0.44, -0.3), 0.01), brass))
    # The lid, thrown back past upright on its hinge along the back edge.
    lid = [materials.assign(_box("Lid", (1.22, 0.06, 0.82), (0, 0, 0), 0.015), walnut)]
    lid.append(materials.assign(_box("Mirror", (1.0, 0.004, 0.62), (0, -0.032, 0), 0.0), mirror))
    lid.append(materials.assign(_box("Inlay", (0.9, 0.004, 0.5), (0, 0.032, 0), 0.0), inlay))
    lid_obj = shapes.join(lid, "Lid")
    shapes.turn(lid_obj, (-105, 0, 0), G(0, 0.816, -0.506))
    parts.append(lid_obj)
    parts.append(materials.assign(shapes.roll("Arbor", 0.12, 0.02, G(0.66, 0.22, 0), axis="X", steps=8), brass))
    parts.append(materials.assign(_box("Key", (0.03, 0.16, 0.14), (0.74, 0.22, 0), 0.02), brass))
    piece = shapes.join(parts, "MusicBox")
    piece["bake_size"] = 512
    return piece


# The twin levers (Puzzles/Levers) -------------------------------------------------------
# Built facing +z like the rest; Data/Kit turns them (the lever's frame
# looks into the room down its -z).


def lever_plate():
    """A cast-iron lever plate, 0.8 x 1.6 x 0.12, round the middle of the
    game's plate (its face a little behind the game's, so the door's mark
    painted on that shows): a raised border, the quadrant guide the arm
    swings in, the pivot boss, the lamp's bezel (the lamp is the game's),
    four bolts."""
    iron = materials.paint("LeverIron", color=(46, 44, 42), roughness=0.55, grime=0.4)
    worn = materials.brass("LeverWorn", color=(110, 104, 92), roughness=0.4)
    chrome = _chrome("LeverBezel")
    parts = [materials.assign(_box("Plate", (0.78, 1.58, 0.1), (0, 0, -0.01), 0.03, 2), iron)]
    for size, at in (((0.78, 0.05, 0.03), (0, 0.765, 0.045)), ((0.78, 0.05, 0.03), (0, -0.765, 0.045)), ((0.05, 1.58, 0.03), (0.365, 0, 0.045)), ((0.05, 1.58, 0.03), (-0.365, 0, 0.045))):
        parts.append(materials.assign(_box("Border", size, at, 0.01), iron))
    # The cheeks the arm's pin turns in (the arm swings out from the wall).
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Cheek", (0.04, 0.36, 0.1), (sx * 0.1, 0, 0.09), 0.012), iron))
    parts.append(materials.assign(shapes.roll("Pin", 0.26, 0.025, G(0, 0, 0.09), axis="X", steps=12), worn))
    parts.append(materials.assign(shapes.roll("Boss", 0.06, 0.09, G(0, 0, 0.05), axis="Y", steps=14), worn))
    parts.append(materials.assign(_ring("LampBezel", 0.1, 0.018, (0, -0.62, 0.05), (90, 0, 0), 16), chrome))
    for x in (-0.28, 0.28):
        for y in (0.68, -0.68):
            parts.append(materials.assign(_sphere("Bolt", 0.025, (x, y, 0.045), 8, 4), worn))
    piece = shapes.join(parts, "LeverPlate")
    piece["bake_size"] = 256
    return piece


def lever_arm():
    """The lever's arm, round the middle of the game's Arm part (0.95 long
    up its y): an iron rod, a collar at its pivot, the turned black grip at
    its top (the game's Knob, hidden)."""
    iron = materials.paint("ArmIron", color=(56, 54, 50), roughness=0.4, grime=0.3)
    grip = _bakelite("ArmGrip", (30, 24, 20))
    parts = [materials.assign(shapes.roll("Rod", 0.95, 0.05, G(0, 0, 0), axis="Z", steps=12), iron)]
    parts.append(materials.assign(shapes.roll("Collar", 0.08, 0.075, G(0, -0.44, 0), axis="Z", steps=12), iron))
    knob = _lathe("Grip", [(0.0, 0.0), (0.06, 0.0), (0.09, 0.05), (0.13, 0.14), (0.12, 0.2), (0.07, 0.24), (0.0, 0.25)], (0, 0.42, 0), steps=16)
    parts.append(materials.assign(knob, grip))
    piece = shapes.join(parts, "LeverArm")
    piece["bake_size"] = 128
    return piece


# The kettle and the record player (Services/InteractService) ------------------------------------


def kettle():
    """A red enamel stovetop kettle, 1 x 1.3 x 1.3 (InteractService's
    Kettle), standing on y = 0, its spout out front (+z): a swelling body, a
    domed top and black knob, the spout, a black handle on chrome posts."""
    red = materials.paint("KettleRed", color=(156, 36, 30), roughness=0.18, grime=0.25)
    black = _bakelite("KettleBlack")
    chrome = _chrome("KettleChrome")
    parts = []
    body = [(0.0, 0.0), (0.42, 0.0), (0.48, 0.03), (0.5, 0.15), (0.49, 0.38), (0.42, 0.55), (0.3, 0.66), (0.24, 0.7), (0.24, 0.74), (0.0, 0.74)]
    parts.append(materials.assign(_lathe("Body", body, steps=32), red))
    lid = [(0.0, 0.72), (0.25, 0.72), (0.24, 0.76), (0.18, 0.84), (0.08, 0.88), (0.0, 0.89)]
    parts.append(materials.assign(_lathe("Lid", lid, steps=24), red))
    parts.append(materials.assign(_sphere("Knob", 0.08, (0, 0.95, 0), 12, 6), black))
    spout = _tube("Spout", [(0, 0.2, 0.42), (0, 0.32, 0.56), (0, 0.48, 0.66), (0, 0.6, 0.7)], [0.1, 0.07, 0.05, 0.045], 12)
    parts.append(materials.assign(spout, red))
    for z in (-0.3, 0.3):
        parts.append(materials.assign(_tube("Post", [(0, 0.6, z * 0.95), (0, 0.9, z), (0, 1.14, z)], 0.03, 8), chrome))
    parts.append(materials.assign(shapes.roll("Handle", 0.72, 0.06, G(0, 1.2, 0), axis="Y", steps=12), black))
    piece = shapes.join(parts, "Kettle")
    piece["bake_size"] = 512
    return piece


def record_player():
    """A portable record player in its open case, 1.5 x 1.45 x 1.3
    (InteractService's RecordPlayer), standing on y = 0: a vinyl-covered
    case, the lid up behind with its speaker grille, a platter and a record
    with its paper label, the tone arm resting on it, two knobs."""
    vinyl = materials.paint("CaseVinyl", color=(118, 82, 54), roughness=0.6, grime=0.3)
    deck = materials.paint("Deck", color=(206, 198, 178), roughness=0.5, grime=0.25)
    grille = materials.fabric("SpeakerCloth", color=(70, 64, 56))
    black = _dark("Vinyl", (14, 14, 16), 0.25)
    label = materials.paint("RecordLabel", color=(170, 40, 40), roughness=0.6, grime=0.1)
    chrome = _chrome("PlayerChrome")
    parts = [materials.assign(_box("Case", (1.5, 0.33, 1.2), (0, 0.165, 0), 0.04, 3), vinyl)]
    parts.append(materials.assign(_box("Deck", (1.4, 0.02, 1.1), (0, 0.33, 0), 0.006), deck))
    parts.append(materials.assign(_lathe("Platter", [(0.0, 0.33), (0.5, 0.33), (0.5, 0.36), (0.0, 0.36)], (-0.12, 0, 0.04), steps=40), chrome))
    parts.append(materials.assign(_lathe("Record", [(0.0, 0.36), (0.475, 0.36), (0.475, 0.375), (0.0, 0.375)], (-0.12, 0, 0.04), steps=40), black))
    parts.append(materials.assign(_lathe("Label", [(0.0, 0.375), (0.15, 0.375), (0.15, 0.378), (0.0, 0.378)], (-0.12, 0, 0.04), steps=24), label))
    parts.append(materials.assign(shapes.roll("Pivot", 0.08, 0.05, G(0.55, 0.38, -0.3), axis="Z", steps=12), chrome))
    arm = _tube("Arm", [(0.55, 0.42, -0.3), (0.5, 0.42, -0.05), (0.38, 0.41, 0.25), (0.3, 0.4, 0.33)], 0.016, 8)
    parts.append(materials.assign(arm, chrome))
    parts.append(materials.assign(_box("Head", (0.06, 0.04, 0.1), (0.29, 0.39, 0.36), 0.01), black))
    for x in (0.45, 0.6):
        parts.append(materials.assign(shapes.roll("Knob", 0.05, 0.05, G(x, 0.36, 0.45), axis="Z", steps=12), black))
    lid = [materials.assign(_box("Lid", (1.5, 1.2, 0.08), (0, 0, 0), 0.04, 3), vinyl)]
    lid.append(materials.assign(_box("Grille", (1.1, 0.8, 0.01), (0, 0.05, 0.045), 0.0), grille))
    lid_obj = shapes.join(lid, "Lid")
    shapes.turn(lid_obj, (-12, 0, 0), G(0, 0.85, -0.62))
    parts.append(lid_obj)
    piece = shapes.join(parts, "RecordPlayer")
    piece["bake_size"] = 512
    return piece


# The baby monitor and the tin robot ---------------------------------------------------------
# Their fronts are -z, as the game builds them.


def baby_monitor():
    """A 1980s baby monitor, 0.47 x 0.98 x 0.27 (MonitorService's unit, its
    front -z): cream plastic, a speaker grille, the game's green lamp (kept)
    in a little window, a volume wheel, a rubber aerial."""
    cream = materials.paint("MonitorCream", color=(226, 220, 204), roughness=0.4, grime=0.3)
    slot = _dark("MonitorSlot", (40, 40, 40), 0.6)
    rubber = _dark("MonitorAerial", (32, 32, 34), 0.7)
    window = _dark("MonitorWindow", (20, 34, 24), 0.2)
    parts = [materials.assign(_box("Body", (0.45, 0.6, 0.25), (0, 0.3, 0), 0.06, 3), cream)]
    for k in range(6):
        parts.append(materials.assign(_box("Slot", (0.24, 0.016, 0.01), (0.05, 0.36 - k * 0.04, -0.128), 0.0), slot))
    parts.append(materials.assign(_box("Window", (0.1, 0.1, 0.01), (-0.12, 0.45, -0.127), 0.004), window))
    parts.append(materials.assign(shapes.roll("Wheel", 0.04, 0.05, G(0.23, 0.45, 0.0), axis="X", steps=12), slot))
    aerial = _lathe("Aerial", [(0.0, 0.0), (0.035, 0.0), (0.03, 0.3), (0.02, 0.36), (0.0, 0.37)], (0.15, 0.58, 0), steps=10)
    parts.append(materials.assign(aerial, rubber))
    piece = shapes.join(parts, "BabyMonitor")
    piece["bake_size"] = 256
    return piece


def tin_robot():
    """A tin wind-up robot, 0.62 x 1.08 x 0.44 (ToyService's toy, its front
    -z): lithographed tin, a chest of painted dials, a domed head with
    ears and an aerial, eye sockets round the game's glowing eyes (kept),
    arms at its sides, square feet, the winding key in its back."""
    tin = materials.paint("RobotTin", color=(176, 64, 46), roughness=0.3, grime=0.35)
    silver = _chrome("RobotSilver")
    dark = _dark("RobotDark", (30, 30, 34), 0.4)
    dial = materials.paint("RobotDial", color=(224, 206, 120), roughness=0.4, grime=0.2)
    brass = materials.brass("RobotKey", color=(196, 170, 90), roughness=0.3)
    parts = [materials.assign(_box("Body", (0.45, 0.5, 0.32), (0, 0.45, 0), 0.04, 2), tin)]
    parts.append(materials.assign(_box("Chest", (0.32, 0.26, 0.01), (0, 0.5, -0.163), 0.004), silver))
    for x in (-0.08, 0.08):
        parts.append(materials.assign(shapes.roll("Gauge", 0.01, 0.045, G(x, 0.55, -0.17), axis="Y", steps=12), dial))
    for k in range(3):
        parts.append(materials.assign(_box("Light", (0.04, 0.03, 0.01), (-0.08 + k * 0.08, 0.43, -0.17), 0.0), dark))
    parts.append(materials.assign(_box("Head", (0.34, 0.3, 0.3), (0, 0.85, 0), 0.05, 2), silver))
    for x in (-0.084, 0.084):
        parts.append(materials.assign(_ring("Socket", 0.045, 0.012, (x, 0.88, -0.152), (90, 0, 0), 12), dark))
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.roll("Ear", 0.06, 0.06, G(sx * 0.19, 0.86, 0), axis="X", steps=12), tin))
        parts.append(materials.assign(_tube("Arm", [(sx * 0.24, 0.62, 0.0), (sx * 0.27, 0.48, -0.02), (sx * 0.26, 0.34, -0.06)], 0.035, 8), silver))
        parts.append(materials.assign(_box("Hand", (0.05, 0.08, 0.06), (sx * 0.26, 0.29, -0.07), 0.015), tin))
        parts.append(materials.assign(_box("Leg", (0.12, 0.2, 0.14), (sx * 0.12, 0.12, 0), 0.02), dark))
        parts.append(materials.assign(_box("Foot", (0.14, 0.05, 0.2), (sx * 0.12, 0.025, -0.02), 0.015), tin))
    parts.append(materials.assign(_tube("Antenna", [(0, 1.0, 0), (0, 1.05, 0)], 0.012, 6), silver))
    parts.append(materials.assign(_sphere("Bulb", 0.025, (0, 1.065, 0), 8, 5), tin))
    parts.append(materials.assign(shapes.roll("Arbor", 0.08, 0.015, G(0, 0.5, 0.2), axis="Y", steps=8), brass))
    parts.append(materials.assign(_box("Key", (0.3, 0.08, 0.02), (0, 0.5, 0.24), 0.02), brass))
    piece = shapes.join(parts, "TinRobot")
    piece["bake_size"] = 256
    return piece


# The servants' bell board (Services/BellBoardService) ------------------------------------------


def bell_board():
    """A mahogany bell board, 2.85 x 3.1 x 0.16, round its frame on the wall
    (+z out): a moulded frame, a crest over it, two rails the bells hang
    from (the bells are each a Bell; the flags and the rooms' labels stay
    the game's)."""
    wood = materials.wood("BoardMahogany", (52, 28, 18), (100, 56, 34), grain_axis="X", scale=1.4, roughness=0.35)
    wood_up = materials.wood("BoardMahoganyUp", (52, 28, 18), (100, 56, 34), grain_axis="Z", scale=1.4, roughness=0.35)
    w, h = 2.85, 3.0
    parts = [materials.assign(_box("Board", (w, h, 0.1), (0, 0, 0.05), 0.02), wood_up)]
    for size, at in (((w, 0.1, 0.06), (0, h / 2 - 0.05, 0.13)), ((w, 0.1, 0.06), (0, -h / 2 + 0.05, 0.13)), ((0.1, h, 0.06), (w / 2 - 0.05, 0, 0.13)), ((0.1, h, 0.06), (-w / 2 + 0.05, 0, 0.13))):
        parts.append(materials.assign(_box("Frame", size, at, 0.02, 2), wood))
    for y in (1.4, -0.05):
        parts.append(materials.assign(_box("Rail", (w - 0.3, 0.06, 0.05), (0, y, 0.125), 0.012), wood))
    crest = shapes.moulding("Crest", [(0.0, 0.0), (-0.06, 0.0), (-0.06, 0.04), (-0.03, 0.08), (0.0, 0.1)], w - 0.4, G(0, h / 2, 0.06))
    parts.append(materials.assign(crest, wood))
    piece = shapes.join(parts, "BellBoard")
    piece["bake_size"] = 512
    return piece


def bell():
    """A servant's bell, 0.3 x 0.32 x 0.31, round the game's ball: a brass
    dome on a coiled spring whose bracket runs back to the board."""
    brass = materials.brass("BellBrass", color=(186, 152, 82), roughness=0.25)
    iron = materials.paint("BellIron", color=(50, 48, 46), roughness=0.5, grime=0.3)
    parts = [materials.assign(_lathe("Dome", [(0.0, 0.14), (0.04, 0.14), (0.1, 0.11), (0.14, 0.02), (0.15, -0.06), (0.14, -0.07), (0.12, -0.03), (0.0, 0.08)], steps=24), brass)]
    parts.append(materials.assign(_sphere("Clapper", 0.03, (0, -0.1, 0), 8, 5), brass))
    # Its spring runs back from the dome's crown to a little plate on the
    # board (0.145 behind the ball's middle).
    coil = [(0.03 * math.cos(t * 1.1), 0.14 + t * 0.004, -0.01 * t + 0.03 * math.sin(t * 1.1) * 0.3) for t in range(15)]
    parts.append(materials.assign(_tube("Spring", coil, 0.008, 5, caps=False), iron))
    parts.append(materials.assign(_box("Bracket", (0.07, 0.07, 0.02), (0, 0.2, -0.145), 0.006), iron))
    piece = shapes.join(parts, "Bell")
    piece["bake_size"] = 128
    return piece


DEVICES = [
    home_computer,
    fuse_box,
    breaker_module,
    breaker_toggle,
    main_switch,
    radio,
    wall_safe,
    safe_door,
    safe_painting,
    music_box,
    lever_plate,
    lever_arm,
    kettle,
    record_player,
    baby_monitor,
    tin_robot,
    bell_board,
    bell,
]
