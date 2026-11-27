"""Slides for the live-demo section, after the user-flow slides."""

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import PP_ALIGN
from pptx.util import Inches, Pt

OUT = r"c:\Users\馬仔\Desktop\ISEM3027_report\sharekit\ShareKit_Demo_Section.pptx"
W, H = Inches(13.333), Inches(7.5)
PAPER = RGBColor(0xF4, 0xF1, 0xEB)
GREEN = RGBColor(0x0E, 0x6B, 0x52)
INK = RGBColor(0x1B, 0x2A, 0x24)
MUTED = RGBColor(0x5E, 0x6A, 0x64)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
BROWN = RGBColor(0x8C, 0x62, 0x39)
LIVE = "https://horse630.github.io/ISEM_3027_Sharekit/"
PHONE = "https://mobileviewer.github.io/"

prs = Presentation()
prs.slide_width = W
prs.slide_height = H
prs.core_properties.title = "ShareKit live demo"


def blank():
    return prs.slides.add_slide(prs.slide_layouts[6])


def fill(shape, color):
    shape.fill.solid()
    shape.fill.fore_color.rgb = color
    shape.line.fill.background()


def rect(slide, x, y, w, h, color, round_=True):
    kind = MSO_SHAPE.ROUNDED_RECTANGLE if round_ else MSO_SHAPE.RECTANGLE
    shape = slide.shapes.add_shape(kind, x, y, w, h)
    fill(shape, color)
    if round_:
        try:
            shape.adjustments[0] = 0.12
        except Exception:
            pass
    return shape


def text(slide, content, x, y, w, h, size=18, bold=False, color=INK, align=PP_ALIGN.LEFT):
    box = slide.shapes.add_textbox(x, y, w, h)
    frame = box.text_frame
    frame.word_wrap = True
    p = frame.paragraphs[0]
    p.alignment = align
    run = p.add_run()
    run.text = content
    run.font.name = "Calibri"
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.color.rgb = color
    return box


def link(slide, label, url, x, y, w, h, size=18, color=GREEN):
    box = text(slide, label, x, y, w, h, size, True, color)
    box.text_frame.paragraphs[0].runs[0].hyperlink.address = url


def chrome(slide, number):
    rect(slide, 0, 0, W, H, PAPER, False)
    rect(slide, 0, 0, Inches(0.16), H, GREEN, False)
    text(slide, "SHAREKIT  ·  AFTER THE USER FLOW", Inches(0.45), Inches(0.22), Inches(7), Inches(0.3), 12, True, GREEN)
    text(slide, f"{number:02d}", Inches(12.3), Inches(7.08), Inches(0.7), Inches(0.28), 12, True, MUTED, PP_ALIGN.RIGHT)


def title(slide, heading, sub=None):
    text(slide, heading, Inches(0.48), Inches(0.62), Inches(12.2), Inches(0.7), 32, True)
    if sub:
        text(slide, sub, Inches(0.5), Inches(1.32), Inches(12), Inches(0.45), 16, False, MUTED)


def card(slide, x, y, w, h, head, body, accent=GREEN):
    rect(slide, x, y, w, h, WHITE)
    rect(slide, x, y, Inches(0.1), h, accent, False)
    text(slide, head, x + Inches(0.28), y + Inches(0.16), w - Inches(0.4), Inches(0.4), 16, True, accent)
    text(slide, body, x + Inches(0.28), y + Inches(0.58), w - Inches(0.45), h - Inches(0.74), 15)


# 1
s = blank()
chrome(s, 1)
text(s, "Live demo", Inches(0.55), Inches(1.4), Inches(7), Inches(0.8), 44, True)
text(s, "This section starts after the user-flow slides.\nI will show the working app, not another diagram.", Inches(0.55), Inches(2.5), Inches(7.2), Inches(1.1), 20, False, MUTED)
rect(s, Inches(8.5), Inches(1.45), Inches(4.2), Inches(4.4), GREEN)
text(s, "HKBU CAMPUS", Inches(8.75), Inches(1.75), Inches(3.7), Inches(0.3), 13, True, RGBColor(0xD5, 0xE4, 0xDC))
text(s, "Every account\nis on the\nHKBU campus.", Inches(8.75), Inches(2.25), Inches(3.7), Inches(2.2), 26, True, WHITE)
text(s, "Group 4  ·  ShareKit", Inches(8.75), Inches(5.05), Inches(3.7), Inches(0.4), 14, False, RGBColor(0xD5, 0xE4, 0xDC))

# 2
s = blank()
chrome(s, 2)
title(s, "Two links, one phone", "Open the phone frame first, then paste the website address.")
rect(s, Inches(0.48), Inches(2.0), Inches(6.1), Inches(4.3), WHITE)
text(s, "1  Phone frame", Inches(0.75), Inches(2.25), Inches(5.5), Inches(0.4), 18, True, GREEN)
link(s, "mobileviewer.github.io", PHONE, Inches(0.75), Inches(2.8), Inches(5.5), Inches(0.45), 22)
text(s, "The class sees the same screens a phone user sees.", Inches(0.75), Inches(3.5), Inches(5.4), Inches(0.8), 16, False, MUTED)
rect(s, Inches(6.8), Inches(2.0), Inches(6.0), Inches(4.3), WHITE)
text(s, "2  The real website", Inches(7.05), Inches(2.25), Inches(5.5), Inches(0.4), 18, True, GREEN)
link(s, "horse630.github.io/ISEM_3027_Sharekit/", LIVE, Inches(7.05), Inches(2.8), Inches(5.5), Inches(0.8), 18)
text(s, "Paste this into Mobile Viewer. Do not use a drawing or a local file.", Inches(7.05), Inches(3.8), Inches(5.4), Inches(1.0), 16, False, MUTED)

# 3
s = blank()
chrome(s, 3)
title(s, "What is running", "Three parts. The visitor never sees the database password.")
rows = [
    ("Flutter  ·  Dart", "The app on the phone and in the browser. One codebase."),
    ("Python on Render", "The cloud service in the middle. It is the only part that holds the key."),
    ("MongoDB", "One database for accounts, items, bookings, and chat."),
]
for i, (head, body) in enumerate(rows):
    y = Inches(2.0) + Inches(i * 1.5)
    rect(s, Inches(0.5), y, Inches(12.3), Inches(1.35), WHITE)
    text(s, f"{i+1:02d}", Inches(0.75), y + Inches(0.38), Inches(0.8), Inches(0.5), 22, True, GREEN)
    text(s, head, Inches(1.8), y + Inches(0.22), Inches(10), Inches(0.4), 20, True)
    text(s, body, Inches(1.8), y + Inches(0.68), Inches(10), Inches(0.45), 16, False, MUTED)

# 4
s = blank()
chrome(s, 4)
title(s, "What the first screen shows", "The old sample listings are gone.")
card(s, Inches(0.48), Inches(2.0), Inches(4.0), Inches(4.2), "You are at HKBU", "The explore page says the account is on the Hong Kong Baptist University campus.")
card(s, Inches(4.66), Inches(2.0), Inches(4.0), Inches(4.2), "Categories", "Tools, Daily, Electronics, Study, Sports, Home, Outdoor, and Events.", BROWN)
card(s, Inches(8.84), Inches(2.0), Inches(4.0), Inches(4.2), "Others", "A separate button for an item that does not fit those categories.")

# 5
s = blank()
chrome(s, 5)
title(s, "Click path while I talk", "I drive the phone. These are the stops, not a second lecture.")
steps = [
    "Sign in. The bar shows HKBU.",
    "Explore: search, a category, then Others.",
    "Open an item and tap the photo to see it full size.",
    "Book it. Choose pay online or pay in person.",
    "The owner gets the request in chat, with the dates, the renter, and the note.",
    "Accept or reject. Online payment is finished on the booking page. Face to face skips it.",
    "Both sides see the exchange code. Only the owner confirms handover, then return.",
    "A review can be written. It can also be left blank.",
]
for i, line in enumerate(steps):
    col, row = i % 2, i // 2
    x = Inches(0.48) + Inches(col * 6.4)
    y = Inches(1.95) + Inches(row * 1.2)
    rect(s, x, y, Inches(6.15), Inches(1.05), WHITE)
    text(s, f"{i+1}", x + Inches(0.2), y + Inches(0.28), Inches(0.4), Inches(0.45), 18, True, GREEN)
    text(s, line, x + Inches(0.7), y + Inches(0.18), Inches(5.2), Inches(0.72), 15)

# 6
s = blank()
chrome(s, 6)
title(s, "If the first screen waits", "Say this once, then keep going.")
rect(s, Inches(0.5), Inches(2.0), Inches(12.3), Inches(4.3), RGBColor(0x14, 0x35, 0x2C))
text(s, "Render sleeps when nobody has used it.", Inches(0.85), Inches(2.4), Inches(11), Inches(0.6), 28, True, WHITE)
text(s, "The first load can take about a minute. After that, taps are quick.\nThe website files are already on GitHub Pages. Only the Python service is waking up.", Inches(0.85), Inches(3.4), Inches(11), Inches(1.4), 18, False, RGBColor(0xD5, 0xE4, 0xDC))
text(s, "Do not refresh again and again while it wakes.", Inches(0.85), Inches(5.1), Inches(11), Inches(0.5), 18, True, WHITE)

# 7
s = blank()
chrome(s, 7)
text(s, "That is the\nworking loop.", Inches(0.55), Inches(1.6), Inches(8), Inches(1.8), 40, True)
text(s, "Find, ask the owner, pay only if it is online,\nhand over with a code, return, and review if you want.", Inches(0.55), Inches(3.7), Inches(7.4), Inches(1.1), 18, False, MUTED)
rect(s, Inches(8.6), Inches(1.6), Inches(4.15), Inches(4.3), GREEN)
text(s, "Platform fee", Inches(8.9), Inches(1.95), Inches(3.6), Inches(0.35), 14, True, RGBColor(0xD5, 0xE4, 0xDC))
text(s, "HK$0", Inches(8.9), Inches(2.45), Inches(3.6), Inches(0.8), 40, True, WHITE)
text(s, "The rent, if any, is the owner's price.", Inches(8.9), Inches(3.5), Inches(3.5), Inches(1.0), 16, False, WHITE)
link(s, "Open the site", LIVE, Inches(8.9), Inches(4.7), Inches(3.5), Inches(0.4), 16, WHITE)

prs.save(OUT)
print(OUT, len(prs.slides))
