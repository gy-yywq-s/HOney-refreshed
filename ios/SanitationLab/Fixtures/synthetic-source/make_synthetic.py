#!/usr/bin/env python3
"""Synthetic fixture set for the credential-image sanitation prototype (spec §8).

Every image is drawn here — no real person, no real credential. The two portraits
are public-domain artworks (Wikimedia Commons: Mona Lisa; Lincoln O-77 print), used
only so Vision's face detector has something to find.

Output: <out>/<group>/<name>.jpg plus <out>/manifest.json with the expected result
and the regions that MUST be hidden / MUST survive (image-space fractions).
The real/ group is appended to the manifest by hand (see real/ATTRIBUTION.md);
re-running this script rewrites only the synthetic items.

Needs: pillow, qrcode, python-barcode (pip). Fonts: DejaVu + WenQuanYi Zen Hei.
"""
import json, math, os, random, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import qrcode
from barcode import Code128
from barcode.writer import ImageWriter

HERE = os.path.dirname(os.path.abspath(sys.argv[0]))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(HERE)  # the Fixtures folder
ASSETS = HERE  # the two public-domain portraits sit beside this script
LATIN = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
LATIN_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
LATIN_I = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
CJK = "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc"
random.seed(7)

W, H = 1200, 900
manifest = []


def font(path, size):
    return ImageFont.truetype(path, size)


def desk(seed=1):
    """A warm desk background with faint grain so photos don't look flat."""
    rnd = random.Random(seed)
    img = Image.new("RGB", (W, H), (176, 138, 96))
    px = img.load()
    for y in range(0, H, 3):
        shade = rnd.randint(-10, 10)
        for x in range(0, W, 3):
            r, g, b = px[x, y]
            v = shade + rnd.randint(-4, 4)
            for dx in range(3):
                for dy in range(3):
                    if x + dx < W and y + dy < H:
                        px[x + dx, y + dy] = (max(0, min(255, r + v)), max(0, min(255, g + v)), max(0, min(255, b + v)))
    return img


def portrait(name, size):
    im = Image.open(os.path.join(ASSETS, name)).convert("RGB")
    w, h = im.size
    # square-ish head crop from the upper part
    side = int(min(w, h * 0.62))
    left = (w - side) // 2
    im = im.crop((left, int(h * 0.05), left + side, int(h * 0.05) + side))
    return im.resize(size, Image.LANCZOS)


def qr(data, box):
    q = qrcode.QRCode(border=1, box_size=6)
    q.add_data(data)
    q.make(fit=True)
    return q.make_image(fill_color="black", back_color="white").convert("RGB").resize((box, box), Image.NEAREST)


def barcode_img(data, width, height):
    tmp = os.path.join(OUT, "_bc")
    Code128(data, writer=ImageWriter()).save(tmp, {"write_text": False, "module_height": 12, "quiet_zone": 2})
    im = Image.open(tmp + ".png").convert("RGB")
    os.remove(tmp + ".png")
    return im.resize((width, height), Image.NEAREST)


def frac(box, size):
    x0, y0, x1, y1 = box
    return [round(x0 / size[0], 4), round(y0 / size[1], 4), round(x1 / size[0], 4), round(y1 / size[1], 4)]


class Card:
    """A credential card drawn onto its own canvas; regions recorded in card space."""

    def __init__(self, w=900, h=560, colour=(245, 247, 250)):
        self.im = Image.new("RGB", (w, h), colour)
        self.d = ImageDraw.Draw(self.im)
        self.hide = {}  # kind -> list of boxes
        self.keep = {}
        self.d.rounded_rectangle((0, 0, w - 1, h - 1), radius=28, outline=(180, 186, 196), width=3)

    def band(self, text, colour=(18, 52, 92)):
        self.d.rectangle((0, 0, self.im.width, 92), fill=colour)
        self.d.rounded_rectangle((0, 0, self.im.width - 1, 92 + 28), radius=28, fill=colour)
        self.d.rectangle((0, 60, self.im.width, 92), fill=colour)
        f = font(CJK, 32) if any(ord(ch) > 127 for ch in text) else font(LATIN_B, 32)
        self.d.text((36, 26), text, font=f, fill="white")

    def text(self, xy, s, f, fill=(30, 30, 30), keep_as=None, hide_as=None):
        self.d.text(xy, s, font=f, fill=fill)
        box = self.d.textbbox(xy, s, font=f)
        if keep_as:
            self.keep.setdefault(keep_as, []).append(box)
        if hide_as:
            self.hide.setdefault(hide_as, []).append(box)
        return box

    def labelled(self, xy, label, value, f, gap=14, hide_as="number", keep_label=True):
        lb = self.text(xy, label, f, fill=(90, 96, 104), keep_as="label" if keep_label else None)
        vb = self.text((lb[2] + gap, xy[1]), value, font(LATIN_B, f.size), hide_as=hide_as)
        return vb

    def portrait(self, xy, size, asset="monalisa.jpg"):
        p = portrait(asset, size)
        self.im.paste(p, xy)
        self.d.rectangle((xy[0], xy[1], xy[0] + size[0], xy[1] + size[1]), outline=(150, 150, 150), width=2)
        self.hide.setdefault("portrait", []).append((xy[0], xy[1], xy[0] + size[0], xy[1] + size[1]))

    def qr(self, xy, data, box=150):
        self.im.paste(qr(data, box), xy)
        self.hide.setdefault("code", []).append((xy[0], xy[1], xy[0] + box, xy[1] + box))

    def barcode(self, xy, data, width=300, height=90):
        self.im.paste(barcode_img(data, width, height), xy)
        self.hide.setdefault("code", []).append((xy[0], xy[1], xy[0] + width, xy[1] + height))


def student_card(kind="qr", chinese=False, label="Student ID:"):
    c = Card()
    if chinese:
        c.band("上海华曜浦东学校 · 学生证")
        c.portrait((40, 130), (210, 270))
        c.text((290, 150), "姓名：张伟", font(CJK, 34), keep_as="name")
        c.labelled((290, 215), "学号：", "20230188", font(CJK, 34))
        c.text((290, 280), "班级：高二(3)班", font(CJK, 30), keep_as="context")
        c.text((290, 340), "有效期至 2027-07", font(CJK, 24), keep_as="context")
    else:
        c.band("HUAYAO PUDONG SCHOOL · STUDENT CARD")
        c.portrait((40, 130), (210, 270))
        c.text((290, 150), "Zhang Wei", font(LATIN_B, 40), keep_as="name")
        c.labelled((290, 220), label, "20230188", font(LATIN, 32))
        c.text((290, 280), "Grade 11 · Class 3", font(LATIN, 28), keep_as="context")
        c.text((290, 340), "Valid until 07/2027", font(LATIN, 24), keep_as="context")
    if kind == "qr":
        c.qr((700, 360), "HYPD-20230188")
    elif kind == "barcode":
        c.barcode((290, 420), "20230188")
    return c


def library_card():
    c = Card(colour=(240, 246, 238))
    c.band("SCHOOL LIBRARY · READER CARD", colour=(28, 92, 60))
    c.text((40, 140), "Li Na", font(LATIN_B, 40), keep_as="name")
    c.labelled((40, 210), "Card No.", "LIB-0048821", font(LATIN, 32))
    c.text((40, 270), "Senior section · 5 loans", font(LATIN, 26), keep_as="context")
    c.barcode((40, 400), "LIB0048821", width=420, height=100)
    return c


def access_card():
    c = Card(colour=(236, 240, 247))
    c.band("CAMPUS ACCESS", colour=(60, 60, 70))
    c.text((40, 140), "Wang Fang", font(LATIN_B, 40), keep_as="name")
    c.labelled((40, 210), "ID No.", "0009123", font(LATIN, 32))
    c.text((40, 270), "Dormitory building B", font(LATIN, 26), keep_as="context")
    # RFID glyph
    for r in (40, 70, 100):
        c.d.arc((760 - r, 400 - r, 760 + r, 400 + r), 300, 60, fill=(80, 80, 90), width=8)
    c.qr((560, 330), "ACC-0009123", box=140)
    return c


def staff_card():
    c = Card(colour=(250, 244, 236))
    c.band("HUAYAO PUDONG SCHOOL · STAFF", colour=(120, 50, 30))
    c.portrait((40, 130), (210, 270), asset="lincoln.jpg")
    c.text((290, 150), "Mr. Chen", font(LATIN_B, 40), keep_as="name")
    c.labelled((290, 220), "Staff No.", "T-10442", font(LATIN, 32))
    c.text((290, 280), "Physics department", font(LATIN, 28), keep_as="context")
    c.qr((700, 360), "STAFF-T10442")
    return c


def decorative_card():
    c = Card(colour=(255, 246, 230))
    c.band("READING CLUB · MEMBER", colour=(220, 130, 40))
    # cartoon smiley, not a photo
    c.d.ellipse((60, 150, 260, 350), fill=(255, 220, 90), outline=(120, 90, 20), width=4)
    c.d.ellipse((110, 210, 135, 235), fill=(60, 40, 20))
    c.d.ellipse((185, 210, 210, 235), fill=(60, 40, 20))
    c.d.arc((110, 240, 210, 320), 20, 160, fill=(60, 40, 20), width=6)
    c.text((300, 160), "Sun Li", font(LATIN_B, 40), keep_as="name")
    c.text((300, 230), "Book of the month: No. 7", font(LATIN, 28), keep_as="context")
    c.text((300, 290), "Every Thursday, room 204", font(LATIN, 26), keep_as="context")
    return c


def place(card, bg, box, angle=0.0, perspective=None, blur=0):
    """Paste a card onto bg into `box` (image space); returns transformed region boxes."""
    cw, ch = card.im.size
    tw, th = box[2] - box[0], box[3] - box[1]
    im = card.im.resize((tw, th), Image.LANCZOS)
    sx, sy = tw / cw, th / ch

    def map_box(b):
        return (box[0] + b[0] * sx, box[1] + b[1] * sy, box[0] + b[2] * sx, box[1] + b[3] * sy)

    hide = {k: [map_box(b) for b in v] for k, v in card.hide.items()}
    keep = {k: [map_box(b) for b in v] for k, v in card.keep.items()}
    if perspective:
        # shear the card as if photographed from the left
        pad = int(tw * 0.18)
        canvas = Image.new("RGB", (tw + 2 * pad, th + 2 * pad), (0, 0, 0))
        canvas.paste(im, (pad, pad))
        mask = Image.new("L", canvas.size, 0)
        ImageDraw.Draw(mask).rectangle((pad, pad, pad + tw, pad + th), fill=255)
        coeffs = perspective
        canvas = canvas.transform(canvas.size, Image.PERSPECTIVE, coeffs, Image.BICUBIC)
        mask = mask.transform(mask.size, Image.PERSPECTIVE, coeffs, Image.BICUBIC)
        bg.paste(canvas, (box[0] - pad, box[1] - pad), mask)
        # Regions become approximate: widen by 6 % on each side.
        def widen(b):
            w_, h_ = b[2] - b[0], b[3] - b[1]
            return (b[0] - 0.06 * w_, b[1] - 0.06 * h_, b[2] + 0.06 * w_, b[3] + 0.06 * h_)
        hide = {k: [widen(b) for b in v] for k, v in hide.items()}
        keep = {k: [widen(b) for b in v] for k, v in keep.items()}
    else:
        if blur:
            im = im.filter(ImageFilter.GaussianBlur(blur))
        shadow = Image.new("RGBA", (tw + 30, th + 30), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle((15, 15, tw + 15, th + 15), radius=20, fill=(0, 0, 0, 90))
        shadow = shadow.filter(ImageFilter.GaussianBlur(12))
        bg.paste(shadow, (box[0] - 8, box[1] - 2), shadow)
        bg.paste(im, (box[0], box[1]))
    return hide, keep


def save(group, name, img, expected, hide=None, keep=None, note=""):
    d = os.path.join(OUT, group)
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, name + ".jpg")
    img.convert("RGB").save(path, "JPEG", quality=88)
    size = img.size
    manifest.append({
        "id": f"{group}/{name}",
        "file": f"{group}/{name}.jpg",
        "expected": expected,
        "mustHide": {k: [frac(b, size) for b in v] for k, v in (hide or {}).items()},
        "mustKeep": {k: [frac(b, size) for b in v] for k, v in (keep or {}).items()},
        "note": note,
    })
    print("wrote", path)


# ---------------------------------------------------------------- clean set
def clean_calculator():
    bg = desk(11)
    d = ImageDraw.Draw(bg)
    d.rounded_rectangle((380, 120, 820, 800), radius=30, fill=(40, 42, 48))
    d.rounded_rectangle((420, 160, 780, 300), radius=12, fill=(190, 205, 170))
    d.text((440, 200), "1234.56", font=font(LATIN, 64), fill=(30, 40, 30))
    keys = ["7", "8", "9", "÷", "4", "5", "6", "×", "1", "2", "3", "−", "0", ".", "=", "+"]
    for i, k in enumerate(keys):
        x, y = 420 + (i % 4) * 92, 340 + (i // 4) * 110
        d.rounded_rectangle((x, y, x + 76, y + 90), radius=10, fill=(90, 92, 100))
        d.text((x + 24, y + 22), k, font=font(LATIN_B, 36), fill="white")
    save("clean", "calculator", bg, "CLEAN")


def clean_notebook():
    bg = desk(12)
    page = Image.new("RGB", (760, 820), (252, 250, 240))
    d = ImageDraw.Draw(page)
    for y in range(90, 820, 46):
        d.line((30, y, 730, y), fill=(200, 210, 230), width=2)
    d.line((90, 0, 90, 820), fill=(230, 150, 150), width=2)
    d.text((110, 50), "Zhang Wei  张伟", font=font(CJK, 40), fill=(40, 50, 120))
    d.text((110, 140), "Chemistry notes — reactions", font=font(LATIN_I, 30), fill=(40, 50, 120))
    d.text((110, 232), "2H₂ + O₂ → 2H₂O", font=font(LATIN, 32), fill=(40, 50, 120))
    d.text((110, 324), "Lost this on Tuesday near the lab", font=font(LATIN_I, 30), fill=(40, 50, 120))
    bg.paste(page, (220, 40))
    save("clean", "notebook_name", bg, "CLEAN", keep={"name": [(330, 90, 700, 140)]},
         note="A handwritten person name must survive")


def clean_textbook():
    bg = desk(13)
    d = ImageDraw.Draw(bg)
    d.rectangle((300, 100, 900, 820), fill=(30, 90, 140))
    d.rectangle((300, 100, 340, 820), fill=(20, 60, 100))
    d.text((380, 180), "PHYSICS", font=font(LATIN_B, 80), fill="white")
    d.text((380, 290), "Grade 10", font=font(LATIN, 46), fill=(220, 230, 240))
    d.text((380, 380), "高中物理  必修一", font=font(CJK, 44), fill="white")
    d.text((380, 700), "Shanghai Education Press", font=font(LATIN, 26), fill=(200, 215, 230))
    d.text((380, 750), "ISBN 978-7-5320-1234-5", font=font(LATIN, 24), fill=(200, 215, 230))
    save("clean", "textbook", bg, "CLEAN", note="ISBN is a long number on a NON-credential; must not be masked")


def clean_ruler():
    bg = desk(14)
    d = ImageDraw.Draw(bg)
    d.rectangle((100, 380, 1100, 520), fill=(240, 232, 150))
    for i in range(0, 31):
        x = 120 + i * 32
        h = 40 if i % 10 == 0 else 25 if i % 5 == 0 else 14
        d.line((x, 380, x, 380 + h), fill=(40, 40, 40), width=2)
        if i % 5 == 0:
            d.text((x - 8, 440), str(i), font=font(LATIN, 24), fill=(40, 40, 40))
    d.text((900, 470), "cm", font=font(LATIN, 24), fill=(40, 40, 40))
    save("clean", "ruler", bg, "CLEAN")


def clean_bottle_with_faces():
    bg = desk(15)
    # background "people": two portraits far back, slightly blurred
    for i, (asset, x) in enumerate((("monalisa.jpg", 60), ("lincoln.jpg", 980))):
        p = portrait(asset, (150, 150)).filter(ImageFilter.GaussianBlur(1.2))
        bg.paste(p, (x, 40))
    d = ImageDraw.Draw(bg)
    d.rounded_rectangle((500, 150, 700, 850), radius=60, fill=(90, 150, 210))
    d.rounded_rectangle((540, 90, 660, 190), radius=20, fill=(40, 60, 90))
    d.rectangle((520, 380, 680, 560), fill=(230, 240, 250))
    d.text((545, 440), "H2O", font=font(LATIN_B, 44), fill=(40, 60, 90))
    save("clean", "bottle_background_faces", bg, "CLEAN",
         keep={"face": [(60, 40, 210, 190), (980, 40, 1130, 190)]},
         note="Background faces on a non-credential must NOT be blurred")


# ------------------------------------------------------------ credential set
def cred_student_qr():
    bg = desk(21)
    hide, keep = place(student_card("qr"), bg, (150, 170, 1050, 730))
    save("credential", "student_card_qr", bg, "SANITIZED", hide, keep)


def cred_student_barcode():
    bg = desk(22)
    hide, keep = place(student_card("barcode"), bg, (150, 170, 1050, 730))
    save("credential", "student_card_barcode", bg, "SANITIZED", hide, keep)


def cred_student_id_label():
    bg = desk(23)
    hide, keep = place(student_card("none", label="Student ID"), bg, (150, 170, 1050, 730))
    save("credential", "student_id_label_only", bg, "SANITIZED", hide, keep,
         note="No code at all: number + portrait are the only sensitive regions")


def cred_chinese():
    bg = desk(24)
    hide, keep = place(student_card("qr", chinese=True), bg, (150, 170, 1050, 730))
    save("credential", "student_card_zh", bg, "SANITIZED", hide, keep)


def cred_angled():
    bg = desk(25)
    # perspective coefficients for a mild left-tilt (computed for the padded canvas)
    hide, keep = place(student_card("qr"), bg, (200, 200, 1000, 700),
                       perspective=(1.18, 0.16, -110, 0.02, 1.02, -20, 0.00022, 0.00003))
    save("credential", "student_card_angled", bg, "SANITIZED", hide, keep,
         note="Regions are approximate (widened 6 %)")


def cred_in_scene():
    bg = desk(26)
    d = ImageDraw.Draw(bg)
    d.rounded_rectangle((60, 80, 460, 760), radius=20, fill=(60, 60, 70))  # a laptop-ish slab
    d.ellipse((900, 560, 1140, 800), fill=(200, 60, 60))  # a mug
    d.rectangle((520, 640, 900, 860), fill=(240, 236, 220))  # paper
    hide, keep = place(student_card("qr"), bg, (560, 120, 920, 344))
    save("credential", "student_card_in_scene", bg, "SANITIZED", hide, keep,
         note="Card is ~30 % of the frame")


def cred_library():
    bg = desk(27)
    hide, keep = place(library_card(), bg, (150, 170, 1050, 730))
    save("credential", "library_card", bg, "SANITIZED", hide, keep)


def cred_access():
    bg = desk(28)
    hide, keep = place(access_card(), bg, (150, 170, 1050, 730))
    save("credential", "access_card", bg, "SANITIZED", hide, keep)


def cred_staff():
    bg = desk(29)
    hide, keep = place(staff_card(), bg, (150, 170, 1050, 730))
    save("credential", "staff_card", bg, "SANITIZED", hide, keep)


# ------------------------------------------------------------------ edge set
def edge_blurred():
    bg = desk(31)
    hide, keep = place(student_card("qr"), bg, (150, 170, 1050, 730), blur=7)
    save("edge", "credential_blurred", bg, "UNCERTAIN", hide, keep,
         note="Record classifier + final behaviour; never publish the original if credential-like")


def edge_tiny():
    bg = desk(32)
    d = ImageDraw.Draw(bg)
    d.rectangle((0, 0, W, 300), fill=(180, 200, 220))  # a wall
    d.rectangle((100, 300, 1100, 900), fill=(120, 110, 100))  # a table far away
    hide, keep = place(student_card("qr"), bg, (520, 420, 664, 510))
    save("edge", "credential_tiny", bg, "UNCERTAIN", hide, keep, note="Card is ~12 % of the width")


def edge_partial_qr():
    bg = desk(33)
    c = student_card("qr")
    crop = c.im.crop((600, 300, 900, 560)).resize((900, 780), Image.LANCZOS)
    bg.paste(crop, (150, 60))
    save("edge", "credential_partial_qr", bg, "UNCERTAIN",
         hide={"code": [(150 + 100 * 3, 60 + 60 * 3, 150 + 250 * 3, 60 + 210 * 3)]},
         note="Only a QR corner is visible")


def edge_decorative():
    bg = desk(34)
    hide, keep = place(decorative_card(), bg, (150, 170, 1050, 730))
    save("edge", "decorative_card", bg, "CLEAN", hide, keep,
         note="Looks like a card, is not a credential — ideally CLEAN; record what happens")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for f in (clean_calculator, clean_notebook, clean_textbook, clean_ruler, clean_bottle_with_faces,
              cred_student_qr, cred_student_barcode, cred_student_id_label, cred_chinese, cred_angled,
              cred_in_scene, cred_library, cred_access, cred_staff,
              edge_blurred, edge_tiny, edge_partial_qr, edge_decorative):
        f()
    mpath = os.path.join(OUT, "manifest.json")
    kept = []
    if os.path.exists(mpath):
        kept = [i for i in json.load(open(mpath))["items"] if i["id"].startswith("real/")]
    with open(mpath, "w") as fh:
        json.dump({"version": 1, "coordinates": "fractions of image width/height, origin top-left", "items": manifest + kept}, fh, indent=2, ensure_ascii=False)
    print("manifest:", len(manifest), "items")
