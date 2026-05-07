"""
Rasterize tools/build-hex.svg to PNG outputs.

Run from package root:
    python tools/rasterize-hex.py

Outputs:
- man/figures/logo.png  (480px wide; standard pkgdown logo target)
- tools/cybedtools-hex@2x.png  (1200px wide; high-res for slides/posters;
  gitignored).
"""
from pathlib import Path
from svglib.svglib import svg2rlg
from reportlab.graphics import renderPM

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tools" / "build-hex.svg"

drawing = svg2rlg(str(SRC))

orig_w, orig_h = drawing.width, drawing.height

def write_at(width: int, dest: Path):
    scale = width / orig_w
    drawing.width = orig_w * scale
    drawing.height = orig_h * scale
    drawing.scale(scale, scale)
    dest.parent.mkdir(parents=True, exist_ok=True)
    renderPM.drawToFile(drawing, str(dest), fmt="PNG", dpi=300)
    print(f"wrote {dest}  ({int(drawing.width)}x{int(drawing.height)})")
    # Reset for the next write_at call
    drawing.scale(1 / scale, 1 / scale)
    drawing.width, drawing.height = orig_w, orig_h

write_at(480,  ROOT / "man" / "figures" / "logo.png")
write_at(1200, ROOT / "tools" / "cybedtools-hex@2x.png")
