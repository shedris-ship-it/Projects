"""Cloth materials for the wardrobe (V6; kitlib/wardrobe): procedural, in
object space, baked to PBR maps by kitlib.bake like every kit piece. Plaid
flannel, a chunky knit, melton wool and leather, nylon and its colour
blocks, stonewashed denim, corduroy, ribbing, laces, metal.
"""

import bpy

from . import materials


_cache = {}


def _srgb(c):
    return materials._srgb(c)


def _rgb(n, c):
    node = n.add("ShaderNodeRGB")
    node.outputs["Color"].default_value = _srgb(c)
    return node.outputs["Color"]


def _xyz(n, scale=1.0):
    m = n.mapping(scale=(scale, scale, scale))
    sep = n.add("ShaderNodeSeparateXYZ")
    n.link(m.outputs["Vector"], sep.inputs["Vector"])
    return m, sep


def _stripe(n, coord, period, width, offset=0.0):
    """1 inside stripes of `width` (share of each period) along a coordinate."""
    shifted = n.math("ADD", coord, offset)
    scaled = n.math("DIVIDE", shifted.outputs["Value"], period)
    frac = n.math("FRACT", scaled.outputs["Value"])
    return n.math("LESS_THAN", frac.outputs["Value"], width).outputs["Value"]


def _mix(n, a, b, factor_socket):
    out = n.mix_colour(a, b, 0.0)
    fac = [s for s in out.node.inputs if s.identifier == "Factor_Float"][0]
    n.link(factor_socket, fac)
    return out


def _fold_bump(n, m, base_height=None, strength=0.25, scale=7.0):
    """Soft cloth folds: creases from a noise stretched round the body (so
    they run across a sleeve or a back, loosely), and a fine weave height if
    given, for the baked normal map."""
    stretch = n.add("ShaderNodeMapping")
    stretch.inputs["Scale"].default_value = (scale * 0.35, scale * 0.35, scale * 1.3)
    n.link(n.coord.outputs["Object"], stretch.inputs["Vector"])
    creases = n.noise(stretch.outputs["Vector"], 1.0, 2.0, 0.45)
    # Ridges where the noise crosses its middle: soft creases, not blobs.
    centred = n.math("SUBTRACT", creases.outputs["Fac"], 0.5)
    ridge = n.math("ABSOLUTE", centred.outputs["Value"])
    folds = n.math("MULTIPLY", ridge.outputs["Value"], 1.2)
    height = folds.outputs["Value"]
    if base_height is not None:
        height = n.math("ADD", height, base_height).outputs["Value"]
    n.bump(height, strength * 0.7, 0.012)


def flannel(name, base, dark, line, roughness=0.88, period=0.42):
    """A brushed cotton plaid: broad dark bands across and down, darker
    where they cross, a thin bright line through, a soft nap."""
    if name in _cache:
        return _cache[name]
    mat = bpy.data.materials.new(name)
    n = materials.Nodes(mat)
    m, sep = _xyz(n)
    across = _stripe(n, sep.outputs["X"], period, 0.36)
    down = _stripe(n, sep.outputs["Z"], period, 0.36, 0.11)
    thin_a = _stripe(n, sep.outputs["X"], period, 0.05, -0.26)
    thin_b = _stripe(n, sep.outputs["Z"], period, 0.05, -0.15)
    both = n.math("ADD", across, down).outputs["Value"]
    shade = n.math("MULTIPLY", both, 0.5).outputs["Value"]
    col = _mix(n, _rgb(n, base), _rgb(n, dark), shade)
    thin = n.math("MAXIMUM", thin_a, thin_b).outputs["Value"]
    col = _mix(n, col, _rgb(n, line), n.math("MULTIPLY", thin, 0.8).outputs["Value"])
    nap = n.noise(m.outputs["Vector"], 60.0, 3.0, 0.55)
    col = _mix(n, col, _rgb(n, (255, 255, 255)), n.math("MULTIPLY", nap.outputs["Fac"], 0.07).outputs["Value"])
    n.link(col, n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = roughness
    weave = n.add("ShaderNodeTexWave", wave_type="BANDS", bands_direction="DIAGONAL")
    weave.inputs["Scale"].default_value = 140.0
    n.link(m.outputs["Vector"], weave.inputs["Vector"])
    _fold_bump(n, m, n.math("MULTIPLY", weave.outputs["Fac"], 0.25).outputs["Value"], 0.3)
    _cache[name] = mat
    return mat


def knit(name, color, dark=None, roughness=0.95, stitches=11.0):
    """A chunky hand knit: columns of V-shaped stitches (stockinette), each
    darker where it tucks under the next, and a gently mottled yarn.
    `stitches`: columns per stud."""
    if name in _cache:
        return _cache[name]
    mat = bpy.data.materials.new(name)
    n = materials.Nodes(mat)
    m, sep = _xyz(n)
    # A V in each column: |frac(x * s) - 0.5| plus the height, wrapped.
    column = n.math("FRACT", n.math("MULTIPLY", sep.outputs["X"], stitches).outputs["Value"])
    across = n.math("ABSOLUTE", n.math("SUBTRACT", column.outputs["Value"], 0.5).outputs["Value"])
    rise = n.math("MULTIPLY", sep.outputs["Z"], stitches * 1.5)
    vee = n.math("FRACT", n.math("ADD", across.outputs["Value"], rise.outputs["Value"]).outputs["Value"])
    # Dark at the stitch's edges (the gaps between loops).
    edge = n.math("ABSOLUTE", n.math("SUBTRACT", vee.outputs["Value"], 0.5).outputs["Value"])
    gaps = n.math("POWER", n.math("MULTIPLY", edge.outputs["Value"], 2.0).outputs["Value"], 3.0)
    column_gap = n.math("POWER", n.math("MULTIPLY", across.outputs["Value"], 2.0).outputs["Value"], 6.0)
    shade = n.math("MAXIMUM", gaps.outputs["Value"], column_gap.outputs["Value"])
    yarn = n.noise(m.outputs["Vector"], 9.0, 3.0, 0.5)
    base = _srgb(color)
    low = tuple(c * 0.88 for c in base[:3]) + (1.0,)
    ramp = n.ramp(yarn.outputs["Fac"], [(0.4, low), (0.6, base)])
    deep = _rgb(n, dark or tuple(int(c * 0.55) for c in color))
    col = _mix(n, ramp.outputs["Color"], deep, n.math("MULTIPLY", shade.outputs["Value"], 0.75).outputs["Value"])
    n.link(col, n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = roughness
    height = n.math("SUBTRACT", 1.0, shade.outputs["Value"])
    _fold_bump(n, m, n.math("MULTIPLY", height.outputs["Value"], 1.0).outputs["Value"], 0.5, 5.0)
    _cache[name] = mat
    return mat


def plain(name, color, roughness, bump=0.12, scale=40.0, mottle=0.12, sheen=None, metal=0.0, folds=0.25):
    """A plain cloth or leather: a colour mottled a little, a fine grain,
    soft folds."""
    if name in _cache:
        return _cache[name]
    mat = bpy.data.materials.new(name)
    n = materials.Nodes(mat)
    m, _ = _xyz(n)
    grain = n.noise(m.outputs["Vector"], scale, 4.0, 0.55)
    base = _srgb(color)
    low = tuple(c * (1 - mottle * 2) for c in base[:3]) + (1.0,)
    ramp = n.ramp(grain.outputs["Fac"], [(0.3, low), (0.7, base)])
    n.link(ramp.outputs["Color"], n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = roughness
    n.bsdf.inputs["Metallic"].default_value = metal
    fine = n.noise(m.outputs["Vector"], scale * 5, 3.0, 0.5)
    _fold_bump(n, m, n.math("MULTIPLY", fine.outputs["Fac"], bump).outputs["Value"], folds)
    _cache[name] = mat
    return mat


def leather(name, color, roughness=0.5):
    """Smooth leather: a slight sheen, creased."""
    if name in _cache:
        return _cache[name]
    mat = bpy.data.materials.new(name)
    n = materials.Nodes(mat)
    m, _ = _xyz(n)
    vor = n.add("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 90.0
    n.link(m.outputs["Vector"], vor.inputs["Vector"])
    blot = n.noise(m.outputs["Vector"], 9.0, 4.0, 0.6)
    base = _srgb(color)
    low = tuple(c * 0.8 for c in base[:3]) + (1.0,)
    ramp = n.ramp(blot.outputs["Fac"], [(0.35, low), (0.7, base)])
    n.link(ramp.outputs["Color"], n.bsdf.inputs["Base Color"])
    rough = n.math("MULTIPLY_ADD", blot.outputs["Fac"], 0.15, roughness - 0.07)
    n.link(rough.outputs["Value"], n.bsdf.inputs["Roughness"])
    _fold_bump(n, m, n.math("MULTIPLY", vor.outputs["Distance"], 0.4).outputs["Value"], 0.3, 9.0)
    _cache[name] = mat
    return mat


def denim(name, color, light, roughness=0.9):
    """Stonewashed denim: a diagonal twill, paler where it's worn (the
    fronts of the thighs, the seams), white flecks."""
    if name in _cache:
        return _cache[name]
    mat = bpy.data.materials.new(name)
    n = materials.Nodes(mat)
    m, sep = _xyz(n)
    twill = n.add("ShaderNodeTexWave", wave_type="BANDS", bands_direction="DIAGONAL")
    twill.inputs["Scale"].default_value = 160.0
    n.link(m.outputs["Vector"], twill.inputs["Vector"])
    wash = n.noise(m.outputs["Vector"], 3.0, 5.0, 0.6)
    # Paler toward the front (-z in the game; Blender's +y).
    front = n.math("MULTIPLY_ADD", sep.outputs["Y"], 1.2, 0.45)
    fade = n.math("MULTIPLY", wash.outputs["Fac"], front.outputs["Value"])
    clamp = n.math("MINIMUM", n.math("MAXIMUM", fade.outputs["Value"], 0.0).outputs["Value"], 1.0)
    col = _mix(n, _rgb(n, color), _rgb(n, light), clamp.outputs["Value"])
    fleck = n.noise(m.outputs["Vector"], 300.0, 2.0, 0.5)
    flecks = n.ramp(fleck.outputs["Fac"], [(0.66, (0, 0, 0, 1)), (0.72, (1, 1, 1, 1))])
    col = _mix(n, col, _rgb(n, (220, 224, 230)), n.math("MULTIPLY", flecks.outputs["Color"], 0.25).outputs["Value"])
    lines = n.math("MULTIPLY", twill.outputs["Fac"], 0.12)
    col = _mix(n, col, _rgb(n, tuple(int(c * 0.6) for c in color)), lines.outputs["Value"])
    n.link(col, n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = roughness
    _fold_bump(n, m, n.math("MULTIPLY", twill.outputs["Fac"], 0.3).outputs["Value"], 0.35)
    _cache[name] = mat
    return mat


def corduroy(name, color, roughness=0.9):
    """Corduroy: soft round wales running down the leg, darker between
    them."""
    if name in _cache:
        return _cache[name]
    mat = bpy.data.materials.new(name)
    n = materials.Nodes(mat)
    m, _ = _xyz(n)
    wales = n.add("ShaderNodeTexWave", wave_type="BANDS", bands_direction="X", wave_profile="SIN")
    wales.inputs["Scale"].default_value = 70.0
    n.link(m.outputs["Vector"], wales.inputs["Vector"])
    base = _srgb(color)
    low = tuple(c * 0.62 for c in base[:3]) + (1.0,)
    ramp = n.ramp(wales.outputs["Fac"], [(0.0, low), (0.6, base), (1.0, base)])
    blot = n.noise(m.outputs["Vector"], 5.0, 4.0, 0.6)
    col = _mix(n, ramp.outputs["Color"], _rgb(n, tuple(int(c * 1.1) for c in color)), n.math("MULTIPLY", blot.outputs["Fac"], 0.25).outputs["Value"])
    n.link(col, n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = roughness
    _fold_bump(n, m, n.math("MULTIPLY", wales.outputs["Fac"], 0.9).outputs["Value"], 0.45)
    _cache[name] = mat
    return mat


def rib(name, color, roughness=0.92):
    """Ribbing (a cuff, a waistband, a knit collar): fine ribs down it."""
    if name in _cache:
        return _cache[name]
    mat = bpy.data.materials.new(name)
    n = materials.Nodes(mat)
    m, _ = _xyz(n)
    ribs = n.add("ShaderNodeTexWave", wave_type="BANDS", bands_direction="X", wave_profile="SIN")
    ribs.inputs["Scale"].default_value = 90.0
    n.link(m.outputs["Vector"], ribs.inputs["Vector"])
    base = _srgb(color)
    low = tuple(c * 0.72 for c in base[:3]) + (1.0,)
    ramp = n.ramp(ribs.outputs["Fac"], [(0.0, low), (0.7, base), (1.0, base)])
    n.link(ramp.outputs["Color"], n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = roughness
    n.bump(ribs.outputs["Fac"], 0.5, 0.008)
    _cache[name] = mat
    return mat


def nylon(name, color, roughness=0.34):
    """A nylon shell: smooth, a soft sheen, crinkled."""
    if name in _cache:
        return _cache[name]
    mat = bpy.data.materials.new(name)
    n = materials.Nodes(mat)
    m, _ = _xyz(n)
    crinkle = n.noise(m.outputs["Vector"], 14.0, 8.0, 0.7)
    base = _srgb(color)
    low = tuple(c * 0.86 for c in base[:3]) + (1.0,)
    ramp = n.ramp(crinkle.outputs["Fac"], [(0.35, low), (0.65, base)])
    n.link(ramp.outputs["Color"], n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = roughness
    _fold_bump(n, m, n.math("MULTIPLY", crinkle.outputs["Fac"], 0.5).outputs["Value"], 0.4, 9.0)
    _cache[name] = mat
    return mat


def blocks(name, colours, cuts, chevron=0.0, roughness=0.34):
    """Nylon in colour blocks: colours[i] below cuts[i] (heights, game y in
    the piece's frame), the last above; `chevron` raises a cut toward the
    middle (a V across the chest)."""
    if name in _cache:
        return _cache[name]
    mat = bpy.data.materials.new(name)
    n = materials.Nodes(mat)
    m, sep = _xyz(n)
    lift = n.math("MULTIPLY", n.math("ABSOLUTE", sep.outputs["X"]).outputs["Value"], -chevron)
    height = n.math("ADD", sep.outputs["Z"], lift.outputs["Value"]).outputs["Value"]
    col = _rgb(n, colours[0])
    for cut, colour in zip(cuts, colours[1:]):
        above = n.math("GREATER_THAN", height, cut).outputs["Value"]
        col = _mix(n, col, _rgb(n, colour), above)
    crinkle = n.noise(m.outputs["Vector"], 14.0, 8.0, 0.7)
    shade = n.math("MULTIPLY", crinkle.outputs["Fac"], 0.12)
    col = _mix(n, col, _rgb(n, (0, 0, 0)), shade.outputs["Value"])
    n.link(col, n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = roughness
    _fold_bump(n, m, n.math("MULTIPLY", crinkle.outputs["Fac"], 0.3).outputs["Value"], 0.35, 9.0)
    _cache[name] = mat
    return mat


def lacing(name, lace, gap, roughness=0.85):
    """Laces crossing a shoe's instep: bands across it with dark gaps."""
    if name in _cache:
        return _cache[name]
    mat = bpy.data.materials.new(name)
    n = materials.Nodes(mat)
    m, sep = _xyz(n)
    bands_ = _stripe(n, sep.outputs["Y"], 0.09, 0.6)
    col = _mix(n, _rgb(n, gap), _rgb(n, lace), bands_)
    n.link(col, n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = roughness
    n.bump(bands_, 0.4, 0.01)
    _cache[name] = mat
    return mat


def metal(name, color, roughness=0.3):
    if name in _cache:
        return _cache[name]
    mat = plain(name, color, roughness, bump=0.02, scale=30.0, mottle=0.08, metal=1.0, folds=0.0)
    return mat
