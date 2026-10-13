"""The golden room's furniture (the visual rework V3): each piece at its
Data/Props size, standing on Z = 0, centred, its front facing -Y (Roblox's
+Z once exported, the way a prop faces the room). One function per kind.

Sizes are Roblox's { x, y, z } = Blender's (x, z, y): width, height, depth.
"""

import math

import numpy as np

from . import materials, shapes

WALNUT_DARK, WALNUT_LIGHT = (46, 30, 20), (92, 62, 40)
OAK_DARK, OAK_LIGHT = (70, 48, 30), (128, 92, 58)


def _legs(name, w, d, h, inset, radius, mat):
    out = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            leg = shapes.turned_leg(name, h, radius, (sx * (w / 2 - inset), sy * (d / 2 - inset), 0))
            out.append(materials.assign(leg, mat))
    return out


def dining_table():
    """A long formal walnut dining table, 6 x 3.4 x 12: a moulded top with a
    rounded edge, an apron, six turned legs. Its top at 3.4 (the dinner's
    places are set on it)."""
    w, h, d = 6.0, 3.4, 12.0
    wood = materials.wood("TableWalnut", WALNUT_DARK, WALNUT_LIGHT, grain_axis="Y", scale=0.6, roughness=0.32)
    wood_leg = materials.wood("TableLeg", WALNUT_DARK, WALNUT_LIGHT, grain_axis="Z", scale=1.2)
    parts = []
    top = shapes.box("Top", (w, d, 0.22), (0, 0, h - 0.11), bevel_width=0.08, segments=4)
    parts.append(materials.assign(top, wood))
    lip = shapes.box("Lip", (w - 0.12, d - 0.12, 0.14), (0, 0, h - 0.29), bevel_width=0.05, segments=3)
    parts.append(materials.assign(lip, wood))
    apron = shapes.box("Apron", (w - 0.9, d - 0.9, 0.55), (0, 0, h - 0.62), bevel_width=0.03, segments=2)
    parts.append(materials.assign(apron, wood))
    leg_h = h - 0.36
    for sx in (-1, 1):
        for sy in (-1, 0, 1):
            y = sy * (d / 2 - 0.7)
            leg = shapes.turned_leg("Leg", leg_h, 0.2, (sx * (w / 2 - 0.55), y, 0))
            parts.append(materials.assign(leg, wood_leg))
    return shapes.join(parts, "DiningTable")


def _seat(name, w, d, h, seats, fabric, wood, arm_w, back_h):
    """The upholstered seats (sofa, armchair): a skirted base, rolled arms,
    a back, seat and back cushions, bun feet."""
    parts = []
    foot_h = 0.35
    for sx in (-1, 1):
        for sy in (-1, 1):
            foot = shapes.lathe(
                "Foot",
                [(0.0, 0.0), (0.12, 0.0), (0.17, 0.12), (0.16, 0.26), (0.12, foot_h), (0.0, foot_h)],
                (sx * (w / 2 - 0.4), sy * (d / 2 - 0.4), 0),
                steps=14,
            )
            parts.append(materials.assign(foot, wood))
    base_h = 1.25
    base = shapes.box("Base", (w - 0.1, d - 0.15, base_h), (0, 0.05, foot_h + base_h / 2), bevel_width=0.12, segments=3)
    parts.append(materials.assign(base, fabric))
    seat_top = foot_h + base_h
    # Arms: a block topped by a roll that overhangs a little to the front.
    for sx in (-1, 1):
        x = sx * (w / 2 - arm_w / 2)
        arm = shapes.box("Arm", (arm_w, d - 0.2, 1.0), (x, 0.08, seat_top + 0.45), bevel_width=0.14, segments=2)
        parts.append(materials.assign(arm, fabric))
        armroll = shapes.roll("ArmRoll", d - 0.05, arm_w * 0.5, (x, 0.0, seat_top + 0.95), axis="Y", steps=16)
        parts.append(materials.assign(armroll, fabric))
    inner = w - 2 * arm_w
    # The back: a frame behind the cushions, its top rounded.
    back = shapes.box("Back", (inner + 0.1, 0.9, back_h), (0, d / 2 - 0.45, seat_top + back_h / 2), bevel_width=0.2, segments=3)
    parts.append(materials.assign(back, fabric))
    backroll = shapes.roll("BackRoll", inner + 0.2, 0.36, (0, d / 2 - 0.45, seat_top + back_h), axis="X", steps=16)
    parts.append(materials.assign(backroll, fabric))
    sw = inner / seats
    for i in range(seats):
        x = -inner / 2 + sw * (i + 0.5)
        seat = shapes.cushion("Cushion", (sw - 0.06, d - 1.15, 0.62), (x, -0.42, seat_top + 0.28), puff=0.1, levels=1)
        parts.append(materials.assign(seat, fabric))
        backc = shapes.cushion(
            "BackCushion", (sw - 0.12, 0.62, back_h - 0.55), (x, d / 2 - 1.15, seat_top + back_h / 2 + 0.25), puff=0.08, levels=1
        )
        backc.rotation_euler = (math.radians(-10), 0, 0)
        shapes.apply_transform(backc)
        backc.location = (x, d / 2 - 1.15, seat_top + back_h / 2 + 0.25)
        parts.append(materials.assign(backc, fabric))
    return parts


def sofa():
    """A 1980s three-seat sofa, 9 x 3.5 x 4, in a faded rust damask."""
    fabric = materials.upholstery("SofaFabric", base=(92, 56, 40), figure=(112, 76, 50))
    wood = materials.wood("SofaFeet", WALNUT_DARK, WALNUT_LIGHT, grain_axis="Z", scale=2.0)
    parts = _seat("Sofa", 9.0, 4.0, 3.5, 3, fabric, wood, arm_w=0.85, back_h=1.54)  # its top at 3.5
    return shapes.join(parts, "Sofa")


def armchair():
    """A wing-back armchair, 4 x 4 x 4, in bottle-green velvet: rolled arms,
    a tall back with wings."""
    fabric = materials.velvet("ArmchairVelvet", color=(42, 64, 50))
    wood = materials.wood("ArmchairFeet", WALNUT_DARK, WALNUT_LIGHT, grain_axis="Z", scale=2.0)
    w, d = 4.0, 4.0
    parts = _seat("Armchair", w, d, 4.0, 1, fabric, wood, arm_w=0.75, back_h=2.04)  # its top at 4
    # The wings: curved panels from the back's sides, flaring forward.
    seat_top = 0.35 + 1.25
    for sx in (-1, 1):
        wing = shapes.cushion("Wing", (0.35, 1.5, 1.6), (sx * (w / 2 - 0.35), d / 2 - 1.0, seat_top + 1.55), puff=0.04, roundness=0.6, levels=1)
        wing.rotation_euler = (0, 0, math.radians(sx * 12))
        shapes.apply_transform(wing)
        wing.location = (sx * (w / 2 - 0.35), d / 2 - 1.0, seat_top + 1.55)
        parts.append(materials.assign(wing, fabric))
    return shapes.join(parts, "Armchair")


def bookcase():
    """A tall bookcase, 8 x 9 x 2, open shelves full of books in faded cloth
    bindings, a cornice on top and a plinth below."""
    w, h, d = 8.0, 9.0, 2.0
    # An old varnish, not a gloss: the torch shines from the eye, and at 0.45
    # the case flared pale in it (seen 2026-10-12).
    wood = materials.wood("CaseOak", OAK_DARK, OAK_LIGHT, grain_axis="Z", scale=0.9, roughness=0.62)
    wood_x = materials.wood("CaseOakAcross", OAK_DARK, OAK_LIGHT, grain_axis="X", scale=0.9, roughness=0.62)
    # The back between the books: a plain, darker, unfinished board.
    backboard = materials.wood("CaseBack", (40, 28, 19), (66, 46, 30), grain_axis="Z", scale=1.4, roughness=0.85)
    books = materials.by_colour("Bindings")
    # Hundreds of books took most of the case's texture and left the wood
    # blurred and pale (the owner, 2026-10-12): they get a fixed share of it.
    books["uv_share"] = 0.3
    parts = []
    t = 0.18
    for sx in (-1, 1):
        side = shapes.box("Side", (t, d, h - 0.5), (sx * (w / 2 - t / 2), 0, (h - 0.5) / 2 + 0.25), 0.03, 2)
        parts.append(materials.assign(side, wood))
    back = shapes.box("Back", (w - 2 * t, 0.08, h - 0.5), (0, d / 2 - 0.04, (h - 0.5) / 2 + 0.25), 0.0)
    parts.append(materials.assign(back, backboard))
    plinth = shapes.box("Plinth", (w + 0.06, d + 0.04, 0.5), (0, -0.02, 0.25), 0.04, 2)
    parts.append(materials.assign(plinth, wood_x))
    cornice = shapes.box("Cornice", (w + 0.2, d + 0.12, 0.32), (0, -0.06, h - 0.16), 0.08, 3)
    parts.append(materials.assign(cornice, wood_x))
    frieze = shapes.box("Frieze", (w - 0.1, d - 0.05, 0.3), (0, 0, h - 0.47), 0.03, 2)
    parts.append(materials.assign(frieze, wood_x))
    shelves = 5
    clear = h - 0.5 - 0.62
    pitch = clear / shelves
    rng = np.random.default_rng(1988)
    palette = [
        (0.30, 0.08, 0.06), (0.10, 0.16, 0.10), (0.08, 0.10, 0.20), (0.36, 0.26, 0.10),
        (0.22, 0.16, 0.12), (0.40, 0.34, 0.24), (0.14, 0.05, 0.07), (0.06, 0.08, 0.07),
    ]
    for i in range(shelves + 1):
        z = 0.5 + i * pitch
        shelf = shapes.box("Shelf", (w - 2 * t, d - 0.12, 0.12), (0, 0.02, z), 0.02, 2)
        parts.append(materials.assign(shelf, wood_x))
        if i == shelves:
            break
        # A row of books, leaning now and then, gaps here and there.
        x = -w / 2 + t + 0.05
        while x < w / 2 - t - 0.3:
            if rng.random() < 0.06:
                x += rng.uniform(0.3, 0.8)
                continue
            thick = rng.uniform(0.12, 0.3)
            tall = min(pitch - 0.2, rng.uniform(0.85, 1.35))
            deep = rng.uniform(1.0, 1.4)
            book = shapes.box("Book", (thick, deep, tall), (x + thick / 2, d / 2 - 0.15 - deep / 2, z + 0.06 + tall / 2), 0.015, 1)
            shapes.cull(book, [(0, 1, 0), (0, 0, -1)])  # its back to the case, its bottom on the shelf
            c = palette[rng.integers(len(palette))]
            fade = rng.uniform(0.75, 1.15)
            shapes.colour(book, tuple(min(1.0, v * fade) for v in c))
            parts.append(materials.assign(book, books))
            x += thick + 0.005
    return shapes.join(parts, "Shelf")


def grandfather_clock():
    """A grandfather clock's case, 2.5 x 8 x 2: plinth, a waisted trunk with a
    glazed door's frame, a hood with columns and a broken pediment. The face,
    hands, pendulum and glass stay the game's own (they're animated): the
    hood leaves the face open."""
    w, h, d = 2.5, 8.0, 2.0
    wood = materials.wood("ClockMahogany", (48, 22, 16), (104, 52, 34), grain_axis="Z", scale=1.1, roughness=0.3)
    parts = []
    parts.append(materials.assign(shapes.box("Plinth", (w, d, 1.4), (0, 0, 0.7), 0.06, 3), wood))
    parts.append(materials.assign(shapes.box("PlinthCap", (w + 0.12, d + 0.12, 0.14), (0, 0, 1.45), 0.05, 2), wood))
    # The trunk, with a frame round the glass door's opening (the game's glass sits in it).
    trunk_h = 3.6
    parts.append(materials.assign(shapes.box("Trunk", (w - 0.3, d - 0.25, trunk_h), (0, 0.05, 1.52 + trunk_h / 2), 0.05, 2), wood))
    door_w, door_h = w - 0.8, h * 0.45
    for sx in (-1, 1):
        stile = shapes.box("Stile", (0.14, 0.1, door_h + 0.2), (sx * (door_w / 2 + 0.07), -(d - 0.25) / 2 - 0.02, h * 0.38), 0.03, 2)
        parts.append(materials.assign(stile, wood))
    for sz in (-1, 1):
        rail = shapes.box("Rail", (door_w + 0.28, 0.1, 0.14), (0, -(d - 0.25) / 2 - 0.02, h * 0.38 + sz * (door_h / 2 + 0.07)), 0.03, 2)
        parts.append(materials.assign(rail, wood))
    # The hood: a box round the face with an open front, columns, pediment.
    hood_base = 1.52 + trunk_h
    hood_h = h - hood_base - 0.5
    parts.append(materials.assign(shapes.box("HoodBase", (w + 0.1, d + 0.1, 0.16), (0, 0, hood_base + 0.08), 0.05, 2), wood))
    face_z = h - 1.3
    for sx in (-1, 1):
        col = shapes.lathe("Column", [(0.0, 0.0), (0.1, 0.0), (0.08, 0.08), (0.07, hood_h - 0.1), (0.1, hood_h), (0.0, hood_h)], (sx * (w / 2 - 0.12), -d / 2 + 0.15, hood_base + 0.16), steps=12)
        parts.append(materials.assign(col, wood))
        side = shapes.box("HoodSide", (0.12, d - 0.3, hood_h), (sx * (w / 2 - 0.06), 0.1, hood_base + 0.16 + hood_h / 2), 0.03, 2)
        parts.append(materials.assign(side, wood))
    parts.append(materials.assign(shapes.box("HoodBack", (w - 0.2, 0.12, hood_h), (0, d / 2 - 0.1, hood_base + 0.16 + hood_h / 2), 0.0), wood))
    top = hood_base + 0.16 + hood_h
    # A stepped cornice: three mouldings, each a little wider, then a cap.
    # (Out over the front and the sides only, and only a little: the case
    # stands against a wall and within its footprint, Kit.spec.)
    for k, (grow, tall) in enumerate(((0.06, 0.08), (0.12, 0.1), (0.16, 0.08))):
        z = top + 0.04 + k * 0.09
        cornice = shapes.box("Cornice", (w + grow, d + grow * 0.5, tall), (0, -grow * 0.25, z), 0.03, 2)
        parts.append(materials.assign(cornice, wood))
    cap = shapes.box("CorniceCap", (w - 0.2, d - 0.3, 0.12), (0, 0, top + 0.34), 0.04, 2)
    parts.append(materials.assign(cap, wood))
    finial = shapes.lathe("Finial", [(0.0, 0.0), (0.09, 0.0), (0.12, 0.08), (0.05, 0.16), (0.08, 0.24), (0.0, 0.32)], (0, -0.1, top + 0.4), steps=12)
    parts.append(materials.assign(finial, materials.brass("ClockBrass")))
    _ = face_z
    return shapes.join(parts, "GrandfatherClock")


def coat_rack():
    """A bentwood coat rack, 2 x 7 x 2, with two coats and a hat on it."""
    wood = materials.wood("RackBentwood", (40, 26, 18), (84, 56, 36), grain_axis="Z", scale=2.0, roughness=0.35)
    wool = materials.upholstery("CoatWool", base=(52, 46, 40), figure=(58, 52, 46), roughness=0.95)
    tweed = materials.upholstery("CoatTweed", base=(86, 70, 52), figure=(96, 80, 60), roughness=0.95)
    parts = []
    pole = shapes.lathe("Pole", [(0.0, 0.0), (0.11, 0.0), (0.09, 0.3), (0.08, 6.6), (0.12, 6.75), (0.0, 7.0)], steps=16)
    parts.append(materials.assign(pole, wood))
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        # Feet and hooks point straight out from the pole (built along Y, so
        # turned a quarter less than their angle).
        leg = shapes.box("Foot", (0.12, 0.9, 0.14), (0, 0, 0), 0.04, 2)
        shapes.turn(leg, (0, 0, math.degrees(a) - 90), (math.cos(a) * 0.45, math.sin(a) * 0.45, 0.07))
        parts.append(materials.assign(leg, wood))
        hook = shapes.box("Hook", (0.07, 0.5, 0.08), (0, 0, 0), 0.03, 2)
        shapes.turn(hook, (-25, 0, math.degrees(a) - 90), (math.cos(a) * 0.27, math.sin(a) * 0.27, 6.45))
        parts.append(materials.assign(hook, wood))
    # Two coats hanging from hooks: a collar at the hook, narrow shoulders,
    # the body flaring a little to the hem, flattened front to back. Within
    # the rack's 2 x 2 footprint.
    for a, mat, length in ((math.pi / 4 + math.pi, wool, 3.6), (math.pi * 1.75, tweed, 3.1)):
        cx, cy = math.cos(a) * 0.4, math.sin(a) * 0.4
        top_z = 6.4
        profile = [
            (0.0, 0.0),
            (0.42, 0.0),
            (0.44, 0.05),
            (0.4, length * 0.45),
            (0.37, length * 0.75),
            (0.34, length * 0.9),
            (0.16, length * 0.98),
            (0.08, length),
            (0.0, length),
        ]
        coat = shapes.lathe("Coat", profile, (0, 0, 0), steps=18)
        for v in coat.data.vertices:
            v.co.y *= 0.45
        coat.rotation_euler = (0, 0, a + math.pi / 2)
        shapes.apply_transform(coat)
        coat.location = (cx, cy, top_z - length)
        parts.append(materials.assign(coat, mat))
    hat = shapes.lathe("Hat", [(0.0, 0.0), (0.42, 0.0), (0.44, 0.03), (0.26, 0.06), (0.24, 0.3), (0.0, 0.33)], (0.05, 0.1, 6.62), steps=24)
    parts.append(materials.assign(hat, wool))
    return shapes.join(parts, "CoatRack")


def hall_bench():
    """A hall bench, 8 x 2.5 x 2.5: a buttoned velvet seat on a turned frame."""
    w, h, d = 8.0, 2.5, 2.5
    wood = materials.wood("BenchWalnut", WALNUT_DARK, WALNUT_LIGHT, grain_axis="X", scale=1.0, roughness=0.35)
    leg_wood = materials.wood("BenchLegs", WALNUT_DARK, WALNUT_LIGHT, grain_axis="Z", scale=1.6)
    seat = materials.velvet("BenchVelvet", color=(78, 30, 34))
    parts = _legs("Leg", w, d, 1.75, 0.35, 0.16, leg_wood)
    parts.append(materials.assign(shapes.box("Rail", (w - 0.2, d - 0.2, 0.35), (0, 0, 1.85), 0.06, 3), wood))
    parts.append(materials.assign(shapes.cushion("Seat", (w - 0.3, d - 0.3, 0.55), (0, 0, 2.25), puff=0.08), seat))
    parts.append(materials.assign(shapes.box("Stretcher", (w - 0.9, 0.12, 0.12), (0, 0, 0.5), 0.03, 2), wood))
    return shapes.join(parts, "Bench")


def _persian(w_px=1024, h_px=1434, seed=7):
    """A worn Persian rug pattern (h x w x 3, 0-1): borders and guard
    stripes, a red field with a central medallion and corner pieces, small
    repeating motifs, faded and worn in the middle."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h_px, 0:w_px].astype(float)
    u = (xx + 0.5) / w_px * 2 - 1  # -1..1 across
    v = (yy + 0.5) / h_px * 2 - 1  # -1..1 along
    red = np.array([0.42, 0.09, 0.07])
    navy = np.array([0.08, 0.10, 0.20])
    cream = np.array([0.78, 0.70, 0.54])
    gold = np.array([0.62, 0.44, 0.18])
    img = np.zeros((h_px, w_px, 3)) + red
    edge = np.minimum(1 - np.abs(u), (1 - np.abs(v)) * (h_px / w_px))
    # Border bands, outermost in.
    img[edge < 0.03] = navy
    img[(edge >= 0.03) & (edge < 0.05)] = cream
    band = (edge >= 0.05) & (edge < 0.15)
    img[band] = navy
    # A running motif in the wide border: diamonds along it.
    along = np.where(np.abs(u) > np.abs(v) * (h_px / w_px) * 0.98, v * 14, u * 10)
    diamond = (np.abs((along % 2) - 1) + np.abs((edge - 0.1) / 0.05)) < 0.8
    img[band & diamond] = gold
    img[(edge >= 0.15) & (edge < 0.17)] = cream
    img[(edge >= 0.17) & (edge < 0.19)] = navy
    field = edge >= 0.19
    # The medallion: a lozenge in the middle, rings inside it.
    lozenge = np.abs(u) / 0.55 + np.abs(v) / 0.42
    img[field & (lozenge < 1.0)] = navy
    img[field & (lozenge < 0.82)] = cream
    img[field & (lozenge < 0.7)] = red * 0.9
    img[field & (lozenge < 0.38)] = gold
    img[field & (lozenge < 0.22)] = navy
    # Corner pieces (spandrels).
    for sx in (-1, 1):
        for sy in (-1, 1):
            c = np.abs(u - sx * 0.81) / 0.4 + np.abs(v - sy * 0.86) / 0.36
            img[field & (c < 0.6)] = navy
            img[field & (c < 0.42)] = cream * 0.9
    # Small motifs scattered over the open field.
    small = (np.abs(((u * 9) % 1) - 0.5) + np.abs(((v * 12) % 1) - 0.5)) < 0.16
    img[field & (lozenge > 1.05) & small] = gold * 0.9
    # Wear: paler and greyer where feet go (the middle), a little everywhere.
    noise = rng.standard_normal((h_px // 8 + 1, w_px // 8 + 1))
    noise = np.kron(noise, np.ones((8, 8)))[:h_px, :w_px]
    wear = np.clip(0.35 * np.exp(-(u ** 2 / 0.4 + v ** 2 / 0.5)) + 0.08 * noise, 0, 0.5)
    grey = img.mean(axis=-1, keepdims=True)
    img = img * (1 - wear[..., None]) + (grey * 0.9 + 0.06) * wear[..., None]
    # The weave: fine light and dark rows.
    img *= (0.92 + 0.08 * np.sin(yy * 1.7))[..., None]
    return np.clip(img, 0, 1)


def rug():
    """A worn Persian rug, 10 x 0.1 x 14, with fringe at the short ends."""
    import bmesh as _bmesh
    import bpy

    w, d, t = 10.0, 14.0, 0.06
    pattern = materials.image("RugWool", _persian(), roughness=0.95, bump=0.12)
    fringe = materials.fabric("RugFringe", color=(196, 182, 150))
    body = shapes.box("Rug", (w, d, t), (0, 0, t / 2), bevel_width=0.02, segments=1)
    # The pattern's own flat layout, read while baking.
    mesh = body.data
    uv = mesh.uv_layers.new(name="Pattern")
    for loop in mesh.loops:
        co = mesh.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = ((co.x / w) + 0.5, (co.y / d) + 0.5)
    materials.assign(body, pattern)
    # Its underside lies on the floor, never seen: off, so the top gets the
    # texture's room.
    bm = _bmesh.new()
    bm.from_mesh(mesh)
    under = [f for f in bm.faces if f.normal.z < -0.9]
    _bmesh.ops.delete(bm, geom=under, context="FACES")
    bm.to_mesh(mesh)
    bm.free()
    parts = [body]
    for sy in (-1, 1):
        for i in range(48):
            x = -w / 2 + 0.15 + i * (w - 0.3) / 47
            strand = shapes.box("Fringe", (0.06, 0.4, 0.02), (x, sy * (d / 2 + 0.18), 0.01), 0.0)
            parts.append(materials.assign(strand, fringe))
    _ = (_bmesh, bpy)
    return shapes.join(parts, "Rug")


GOLDEN = [dining_table, sofa, armchair, bookcase, grandfather_clock, coat_rack, hall_bench, rug]
