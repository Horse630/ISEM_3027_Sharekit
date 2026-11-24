"""Build the ISEM 3027 ShareKit presentation in the app's visual style."""

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.oxml.ns import qn
from pptx.util import Emu, Inches, Pt

OUT = r"c:\Users\馬仔\Desktop\ISEM3027_report\sharekit\ShareKit_ISEM3027_Presentation.pptx"
W, H = Inches(13.333), Inches(7.5)
PAPER = RGBColor(0xF4, 0xF1, 0xEB)
GREEN = RGBColor(0x0E, 0x6B, 0x52)
INK = RGBColor(0x1B, 0x2A, 0x24)
MUTED = RGBColor(0x5E, 0x6A, 0x64)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
BROWN = RGBColor(0x8C, 0x62, 0x39)
CARD = RGBColor(0xFF, 0xFF, 0xFF)
LINE = RGBColor(0xE4, 0xDD, 0xD2)
LIVE = "https://horse630.github.io/ISEM_3027_Sharekit/"
PHONE = "https://mobileviewer.github.io/"

prs = Presentation()
prs.slide_width = W
prs.slide_height = H
prs.core_properties.title = "ShareKit — ISEM 3027"
prs.core_properties.subject = "Peer-to-peer community borrowing"


def blank():
    return prs.slides.add_slide(prs.slide_layouts[6])


def rgb(shape, color):
    shape.fill.solid()
    shape.fill.fore_color.rgb = color
    shape.line.fill.background()


def rect(slide, x, y, w, h, color, round_=True):
    kind = MSO_SHAPE.ROUNDED_RECTANGLE if round_ else MSO_SHAPE.RECTANGLE
    shape = slide.shapes.add_shape(kind, x, y, w, h)
    rgb(shape, color)
    if round_:
        try:
            shape.adjustments[0] = 0.12
        except Exception:
            pass
    return shape


def text(slide, content, x, y, w, h, size=18, bold=False, color=INK, align=PP_ALIGN.LEFT, font="Calibri"):
    box = slide.shapes.add_textbox(x, y, w, h)
    frame = box.text_frame
    frame.word_wrap = True
    frame.auto_size = None
    p = frame.paragraphs[0]
    p.alignment = align
    run = p.add_run()
    run.text = content
    run.font.name = font
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.color.rgb = color
    return box


def link_text(slide, label, url, x, y, w, h, size=16, color=GREEN):
    box = text(slide, label, x, y, w, h, size=size, bold=True, color=color)
    run = box.text_frame.paragraphs[0].runs[0]
    run.hyperlink.address = url
    return box


def notes(slide, body):
    slide.notes_slide.notes_text_frame.text = body


def chrome(slide, number, speaker):
    rect(slide, 0, 0, W, H, PAPER, round_=False)
    rect(slide, 0, 0, Inches(0.16), H, GREEN, round_=False)
    text(slide, "SHAREKIT", Inches(0.42), Inches(0.22), Inches(2.4), Inches(0.28), 12, True, GREEN)
    pill = rect(slide, Inches(9.15), Inches(0.2), Inches(3.75), Inches(0.36), GREEN)
    text(slide, speaker, Inches(9.15), Inches(0.22), Inches(3.75), Inches(0.32), 12, True, WHITE, PP_ALIGN.CENTER)
    text(slide, f"{number:02d}", Inches(12.35), Inches(7.08), Inches(0.7), Inches(0.28), 12, True, MUTED, PP_ALIGN.RIGHT)
    text(slide, "ISEM 3027  ·  Community borrowing", Inches(0.42), Inches(7.08), Inches(6), Inches(0.28), 12, False, MUTED)


def title_block(slide, title, subtitle=None):
    text(slide, title, Inches(0.48), Inches(0.68), Inches(12.2), Inches(0.7), 32, True)
    if subtitle:
        text(slide, subtitle, Inches(0.5), Inches(1.38), Inches(12), Inches(0.4), 16, False, MUTED)


def card(slide, x, y, w, h, heading, body, accent=GREEN):
    rect(slide, x, y, w, h, WHITE)
    rect(slide, x, y, Inches(0.1), h, accent, round_=False)
    text(slide, heading, x + Inches(0.28), y + Inches(0.16), w - Inches(0.42), Inches(0.4), 16, True, accent)
    text(slide, body, x + Inches(0.28), y + Inches(0.58), w - Inches(0.46), h - Inches(0.74), 15, False, INK)


def bullets(slide, items, x, y, w, h, size=16):
    box = slide.shapes.add_textbox(x, y, w, h)
    frame = box.text_frame
    frame.word_wrap = True
    for i, item in enumerate(items):
        p = frame.paragraphs[0] if i == 0 else frame.add_paragraph()
        p.alignment = PP_ALIGN.LEFT
        p.space_after = Pt(8)
        run = p.add_run()
        run.text = item
        run.font.name = "Calibri"
        run.font.size = Pt(size)
        run.font.color.rgb = INK
    return box


# 1 Title
s = blank()
chrome(s, 1, "Member 1  ·  Open")
text(s, "Need it once.\nBorrow it nearby.", Inches(0.55), Inches(1.15), Inches(7.2), Inches(2.1), 40, True)
text(s, "ShareKit is a peer-to-peer app for borrowing tools, home equipment,\ncamping gear, and event furniture across Hong Kong's 18 districts.", Inches(0.55), Inches(3.45), Inches(7.4), Inches(0.9), 18, False, MUTED)
rect(s, Inches(8.55), Inches(1.35), Inches(4.15), Inches(4.7), GREEN)
text(s, "LIVE DEMO", Inches(8.8), Inches(1.6), Inches(3.7), Inches(0.3), 13, True, RGBColor(0xD5, 0xE4, 0xDC))
text(s, "One shared catalogue.\nEvery browser sees\nthe same items.", Inches(8.8), Inches(2.05), Inches(3.6), Inches(1.6), 22, True, WHITE)
link_text(s, "Open ShareKit", LIVE, Inches(8.8), Inches(4.15), Inches(3.6), Inches(0.4), 18, WHITE)
text(s, "Then show it in a phone frame\non Mobile Viewer.", Inches(8.8), Inches(4.6), Inches(3.6), Inches(0.7), 14, False, RGBColor(0xD5, 0xE4, 0xDC))
text(s, "ISEM 3027  ·  Introduction to App Development and Mobile User Experience Design", Inches(0.55), Inches(5.85), Inches(7.6), Inches(0.4), 13, False, MUTED)
notes(s, "Member 1 opens. Say the name, the one-sentence idea, and that the class will see the real site, not a drawing. Do not log in yet.")

# 2 Problem
s = blank()
chrome(s, 2, "Member 2  ·  Problem")
title_block(s, "The problem in Hong Kong", "Many useful things are bought for a few uses, then stored.")
card(s, Inches(0.48), Inches(1.95), Inches(4.0), Inches(2.35), "Bought, barely used", "A drill, carpet cleaner, camping set, or folding table may be used a handful of times a year.")
card(s, Inches(4.66), Inches(1.95), Inches(4.0), Inches(2.35), "Small flats", "Storage is expensive. A one-time purchase still takes space after the job is done.", BROWN)
card(s, Inches(8.84), Inches(1.95), Inches(4.0), Inches(2.35), "No neighbourhood record", "Estate chats and resale apps do not keep a clear borrow, return, and review history.", GREEN)
text(s, "People already own what their neighbours need. What is missing is a safe way to lend it.", Inches(0.5), Inches(4.55), Inches(12), Inches(0.7), 20, True)
notes(s, "Member 2. Use one concrete story: rain, a drill for one afternoon, or a folding table for a floor gathering. Weight: Problem Identification 15%.")

# 3 Pain
s = blank()
chrome(s, 3, "Member 2  ·  Pain points")
title_block(s, "What makes borrowing fail today")
rows = [
    ("Trust", "An old photo from a camera roll does not show the item today. Damage and no-shows have no record."),
    ("Handover", "People do not agree whether they will meet or post the item, or where to meet."),
    ("Findability", "A post in a chat group disappears. Another browser, or another account, cannot see the same list."),
    ("Money", "Buying is clear. Borrowing often adds an unclear platform cut, so people walk away."),
]
for i, (head, body) in enumerate(rows):
    y = Inches(1.85) + Inches(i * 1.2)
    rect(s, Inches(0.5), y, Inches(12.3), Inches(1.05), WHITE)
    text(s, f"{i+1:02d}", Inches(0.7), y + Inches(0.28), Inches(0.7), Inches(0.45), 20, True, GREEN)
    text(s, head, Inches(1.6), y + Inches(0.12), Inches(3), Inches(0.36), 18, True)
    text(s, body, Inches(1.6), y + Inches(0.48), Inches(10.6), Inches(0.45), 15, False, MUTED)
notes(s, "Stay on the user, not the server. The product answers each of these four points on the next slides and in the live demo.")

# 4 Gap
s = blank()
chrome(s, 4, "Member 1  ·  The gap")
title_block(s, "One place to borrow what is already nearby")
rect(s, Inches(0.5), Inches(1.9), Inches(12.3), Inches(4.5), RGBColor(0x14, 0x35, 0x2C))
text(s, "ShareKit", Inches(0.85), Inches(2.15), Inches(6), Inches(0.4), 16, True, RGBColor(0xD5, 0xE4, 0xDC))
text(s, "A shared catalogue for all 18 districts.", Inches(0.85), Inches(2.6), Inches(11), Inches(0.6), 28, True, WHITE)
points = [
    "Search by district, category, distance, rating, or price.",
    "The photo is taken with the camera at the moment of listing.",
    "Booking, pickup code, return, review, and chat stay on one record.",
    "The owner's price is the only charge. The platform fee is HK$0.",
]
bullets(s, ["·  " + p for p in points], Inches(0.9), Inches(3.45), Inches(11.2), Inches(2.5), 18)
for shape in s.shapes:
    if shape.has_text_frame:
        for p in shape.text_frame.paragraphs:
            for run in p.runs:
                if run.text.startswith("·"):
                    run.font.color.rgb = RGBColor(0xE7, 0xF3, 0xEE)
notes(s, "Member 1 states the value in one breath, then hands back to Member 2 for the market.")

# 5 Target
s = blank()
chrome(s, 5, "Member 2  ·  Market")
title_block(s, "Who it is for", "Start with one community, then open the same flow across Hong Kong.")
card(s, Inches(0.48), Inches(1.95), Inches(4.0), Inches(4.3), "Borrowers", "Residents and students who need a tool, cleaner, tent, or table for a short job and do not want to buy it.")
card(s, Inches(4.66), Inches(1.95), Inches(4.0), Inches(4.3), "Lenders", "Owners of items that sit idle. They set a free borrow or a daily price, and choose meet-up or post.", BROWN)
card(s, Inches(8.84), Inches(1.95), Inches(4.0), Inches(4.3), "Communities", "Estates and student hostels that want a recorded way to share, instead of a chat group that scrolls away.")
notes(s, "Name the first setting: a residential estate, with Kowloon City as the demo home district. Citywide is phase 3, not day one.")

# 6 Market numbers
s = blank()
chrome(s, 6, "Member 2  ·  Market size")
title_block(s, "How large the borrowing pool is", "Figures below are a sizing logic, not a forecast of revenue.")
stats = [
    ("2.7 million", "Domestic households in Hong Kong, the pool of possible lenders and borrowers."),
    ("18 districts", "The product already filters Central & Western through Islands, so supply can be local."),
    ("HK$0", "Platform fee today. Any money shown is the owner's own daily rent."),
]
for i, (big, small) in enumerate(stats):
    x = Inches(0.5) + Inches(i * 4.2)
    rect(s, x, Inches(1.95), Inches(3.95), Inches(2.5), WHITE)
    text(s, big, x + Inches(0.25), Inches(2.15), Inches(3.45), Inches(0.7), 28, True, GREEN)
    text(s, small, x + Inches(0.25), Inches(2.95), Inches(3.45), Inches(1.2), 15, False, INK)
rect(s, Inches(0.5), Inches(4.7), Inches(12.3), Inches(1.85), WHITE)
text(s, "Illustration, not a promise", Inches(0.75), Inches(4.88), Inches(6), Inches(0.35), 14, True, BROWN)
text(s, "If 10% of households borrowed one item a year at an average owner price of HK$50, the rental flow would be about HK$13.5 million. ShareKit would not take that money. It shows why the behaviour is worth a pilot.", Inches(0.75), Inches(5.3), Inches(11.7), Inches(1.0), 16)
notes(s, "Cite Census and Statistics Department for household numbers. Say 2.7 million is rounded. The 10% and HK$50 are assumptions. Potential Market Estimation is 15%.")

# 7 Objectives
s = blank()
chrome(s, 7, "Member 1  ·  Objective")
title_block(s, "What ShareKit is trying to become")
card(s, Inches(0.48), Inches(1.9), Inches(6.05), Inches(2.2), "Mission", "Make a one-time need a borrow, not a purchase, inside the borrower's own district.")
card(s, Inches(6.75), Inches(1.9), Inches(6.05), Inches(2.2), "Vision", "The ordinary entrance for community sharing in Hong Kong, estate by estate.", BROWN)
rect(s, Inches(0.48), Inches(4.3), Inches(12.32), Inches(2.2), WHITE)
text(s, "Near term", Inches(0.75), Inches(4.48), Inches(3), Inches(0.35), 16, True, GREEN)
text(s, "A working pilot: discover, list, book, hand over, return, review, and chat on one database.", Inches(0.75), Inches(4.95), Inches(5.5), Inches(1.2), 16)
text(s, "Longer term", Inches(6.9), Inches(4.48), Inches(3), Inches(0.35), 16, True, GREEN)
text(s, "Estate partners, five districts, then all 18, still with no surprise platform fee on the rent.", Inches(6.9), Inches(4.95), Inches(5.5), Inches(1.2), 16)
notes(s, "Apps Business Objective is 20%. Keep mission and vision distinct. Do not promise citywide on day one.")

# 8 Business model
s = blank()
chrome(s, 8, "Member 1  ·  Business model")
title_block(s, "Three sides, one record", "The current product does not charge a platform fee.")
card(s, Inches(0.48), Inches(1.95), Inches(4.0), Inches(4.3), "Borrower", "Finds an item, books dates, pays only the owner's price if there is one, and confirms pickup and return.")
card(s, Inches(4.66), Inches(1.95), Inches(4.0), Inches(4.3), "Owner", "Lists with a live camera photo, an address, a district, and either meet-up or post. Free is allowed.", BROWN)
card(s, Inches(8.84), Inches(1.95), Inches(4.0), Inches(4.3), "Community", "Later, an estate or hostel can adopt ShareKit as its sharing desk. That is a partnership, not a cut of the rent.")
notes(s, "Say clearly: today's demo takes HK$0 as a platform fee. A future estate subscription is separate from the renter's payment.")

# 9 Revenue
s = blank()
chrome(s, 9, "Member 1  ·  Revenue later")
title_block(s, "How it could earn, after the pilot", "None of these fees are switched on in the live demo.")
card(s, Inches(0.48), Inches(1.95), Inches(4.0), Inches(4.3), "Now", "HK$0 platform fee. A priced item shows the owner's daily rent only. Free items stay free.")
card(s, Inches(4.66), Inches(1.95), Inches(4.0), Inches(4.3), "Estate desk", "A monthly fee for an estate or hostel that wants its own sharing desk, support, and posters.", BROWN)
card(s, Inches(8.84), Inches(1.95), Inches(4.0), Inches(4.3), "Optional cover", "A voluntary damage-cover add-on, chosen by the borrower, never hidden inside the rent.")
notes(s, "If asked why not take 10%: we removed it. Trust is higher when the price on screen is the owner's price.")

# 10 Competitors
s = blank()
chrome(s, 10, "Member 2  ·  Competition")
title_block(s, "What people use instead")
card(s, Inches(0.48), Inches(1.9), Inches(6.05), Inches(2.15), "Resale apps and groups", "Carousell and Facebook groups are built to sell or to chat. The post scrolls away. There is no return step.")
card(s, Inches(6.75), Inches(1.9), Inches(6.05), Inches(2.15), "Buying new", "A shop solves the need once and leaves the object in the flat. Fine for daily tools, wasteful for rare ones.", BROWN)
card(s, Inches(0.48), Inches(4.2), Inches(12.32), Inches(2.25), "Why they do not close the gap", "They do not combine a live photo, a district, a booking, a pickup code, a review, and a chat on one shared database. ShareKit is for borrowing, not for a classified advertisement.")
notes(s, "Do not attack competitors. Say they solve a different job. Competition analysis sits inside the market section.")

# 11 Comparison
s = blank()
chrome(s, 11, "Member 2  ·  Comparison")
title_block(s, "Side by side")
headers = ["", "Resale chat", "Buy new", "ShareKit"]
rows = [
    ["Borrow, not buy", "No", "No", "Yes"],
    ["18 districts", "Weak", "Shop location", "Yes"],
    ["Photo taken now", "Any old photo", "Shop photo", "Camera only"],
    ["Pickup and return", "No", "No", "Yes"],
    ["Platform fee", "Seller fees", "Retail price", "HK$0"],
]
rect(s, Inches(0.45), Inches(1.8), Inches(12.4), Inches(4.8), WHITE)
for c, head in enumerate(headers):
    text(s, head, Inches(0.6) + Inches(c * 3.05), Inches(1.95), Inches(2.9), Inches(0.4), 16, True, GREEN if c == 3 else INK)
for r, row in enumerate(rows):
    y = Inches(2.55) + Inches(r * 0.72)
    for c, cell in enumerate(row):
        color = GREEN if c == 3 else INK
        weight = c == 0 or c == 3
        text(s, cell, Inches(0.6) + Inches(c * 3.05), y, Inches(2.9), Inches(0.45), 16, weight, color)
notes(s, "Read only the ShareKit column aloud. The point is the combination, not any single tick.")

# 12 Social
s = blank()
chrome(s, 12, "Member 1  ·  Social responsibility")
title_block(s, "Why a community should care")
card(s, Inches(0.48), Inches(1.95), Inches(4.0), Inches(4.3), "Less waste", "An item that already exists does the job. Fewer one-time purchases means less storage and less disposal.")
card(s, Inches(4.66), Inches(1.95), Inches(4.0), Inches(4.3), "Fair access", "A student or a small flat can use a good tool without paying a shop price for a single afternoon.", BROWN)
card(s, Inches(8.84), Inches(1.95), Inches(4.0), Inches(4.3), "Neighbourhood trust", "A record, a review, and a conversation make lending safer than handing something to a stranger in a chat.")
notes(s, "CCMF social responsibility is 10% of that framework. Tie it back to reuse and access, not to a donation story we do not have.")

# 13 Phases
s = blank()
chrome(s, 13, "Member 5  ·  Roadmap")
title_block(s, "Three phases", "The live site is the start of phase 1, not the finished city network.")
phases = [
    ("1", "One community", "Prove discover, list, book, hand over, return, and chat with real neighbours."),
    ("2", "Five districts", "Add estate partners and keep the same record. Still no platform fee on the rent."),
    ("3", "18 districts", "Open the filter people already see in the prototype, with local supply in each district."),
]
for i, (n, head, body) in enumerate(phases):
    x = Inches(0.48) + Inches(i * 4.2)
    rect(s, x, Inches(1.95), Inches(3.95), Inches(4.3), WHITE)
    bubble = rect(s, x + Inches(0.25), Inches(2.2), Inches(0.7), Inches(0.7), GREEN)
    text(s, n, x + Inches(0.25), Inches(2.32), Inches(0.7), Inches(0.5), 22, True, WHITE, PP_ALIGN.CENTER)
    text(s, head, x + Inches(0.25), Inches(3.15), Inches(3.4), Inches(0.5), 22, True)
    text(s, body, x + Inches(0.25), Inches(3.8), Inches(3.4), Inches(1.8), 16)
notes(s, "Member 5 previews the six-month plan. Phase 3 is a direction, not a six-month promise.")

# 14 Live prototype
s = blank()
chrome(s, 14, "Member 3  ·  Prototype")
title_block(s, "The prototype is already online", "We will show the real product, first in a phone frame, then on the site itself.")
rect(s, Inches(0.48), Inches(1.9), Inches(7.5), Inches(4.5), WHITE)
text(s, "PHONE FRAME", Inches(0.75), Inches(2.1), Inches(6), Inches(0.3), 13, True, GREEN)
text(s, "Open Mobile Viewer and paste the ShareKit address. The class sees the same screens a phone user sees.", Inches(0.75), Inches(2.5), Inches(6.9), Inches(1.1), 16)
link_text(s, "mobileviewer.github.io", PHONE, Inches(0.75), Inches(3.7), Inches(6.5), Inches(0.4), 20)
text(s, "Direct site, if the room display is wide:", Inches(0.75), Inches(4.4), Inches(6.5), Inches(0.35), 14, False, MUTED)
link_text(s, "horse630.github.io/ISEM_3027_Sharekit/", LIVE, Inches(0.75), Inches(4.85), Inches(6.9), Inches(0.4), 16)
text(s, "Demo login   Isem_3027   /   Isem_3027", Inches(0.75), Inches(5.5), Inches(6.5), Inches(0.4), 16, True)
rect(s, Inches(8.2), Inches(1.9), Inches(4.6), Inches(4.5), GREEN)
text(s, "IF IT PAUSES", Inches(8.45), Inches(2.15), Inches(4.1), Inches(0.3), 13, True, RGBColor(0xD5, 0xE4, 0xDC))
text(s, "The free server sleeps when idle. The first load can take about a minute. Later taps are quick.", Inches(8.45), Inches(2.6), Inches(4.1), Inches(1.5), 16, False, WHITE)
text(s, "Every signed-in visitor reads and writes the same database.", Inches(8.45), Inches(4.3), Inches(4.1), Inches(1.4), 16, True, WHITE)
notes(s, "Open Mobile Viewer before this slide if possible, paste the URL, and wait out the cold start during the market section. Login is Isem_3027 / Isem_3027. Apps Function and User Flow is 35%, so do not rush this block.")

# 15 Flow A
s = blank()
chrome(s, 15, "Member 3  ·  Core flow")
title_block(s, "The path a borrower walks", "Click these in order on the live site.")
steps = [
    ("1", "Sign in", "Create an account or use the demo login. The session stays on this device."),
    ("2", "Explore", "Search, pick a category, or open the 18 districts. Sort by nearest, rating, or price."),
    ("3", "Open an item", "See the live photo, district, address, condition, and whether it is free."),
    ("4", "Book dates", "The app skips days that are already taken. You cannot book your own item."),
    ("5", "Pay the owner only", "The screen shows rent, platform fee HK$0, and the total."),
]
for i, (n, head, body) in enumerate(steps):
    y = Inches(1.75) + Inches(i * 0.98)
    rect(s, Inches(0.48), y, Inches(12.35), Inches(0.88), WHITE)
    bubble = rect(s, Inches(0.66), y + Inches(0.16), Inches(0.56), Inches(0.56), GREEN)
    text(s, n, Inches(0.66), y + Inches(0.24), Inches(0.56), Inches(0.4), 16, True, WHITE, PP_ALIGN.CENTER)
    text(s, head, Inches(1.45), y + Inches(0.1), Inches(3.2), Inches(0.65), 18, True)
    text(s, body, Inches(4.5), y + Inches(0.18), Inches(8), Inches(0.55), 15, False, MUTED)
notes(s, "Member 3 drives the phone. Stop on the fee line and say platform fee is zero. If a date is taken, the default date has already moved to the next open day.")

# 16 Flow B
s = blank()
chrome(s, 16, "Member 3  ·  After booking")
title_block(s, "Handover, return, and the conversation")
steps = [
    ("6", "Pickup code", "After payment, or immediately if the item is free, a code is shown for the owner to check."),
    ("7", "Return", "The borrower records the condition: fine, light use, or needs the owner to look."),
    ("8", "Review", "Stars and a short note stay on the item for the next person."),
    ("9", "Chat", "The Chats tab lists each item like a messaging app. Unread messages show a red count."),
    ("10", "Settings", "Name, camera photo, address, home district, text size, and English or 中文."),
]
for i, (n, head, body) in enumerate(steps):
    y = Inches(1.75) + Inches(i * 0.98)
    rect(s, Inches(0.48), y, Inches(12.35), Inches(0.88), WHITE)
    rect(s, Inches(0.66), y + Inches(0.16), Inches(0.7), Inches(0.56), GREEN)
    text(s, n, Inches(0.66), y + Inches(0.24), Inches(0.7), Inches(0.4), 16, True, WHITE, PP_ALIGN.CENTER)
    text(s, head, Inches(1.6), y + Inches(0.1), Inches(2.6), Inches(0.65), 18, True)
    text(s, body, Inches(4.3), y + Inches(0.18), Inches(8.2), Inches(0.55), 15, False, MUTED)
notes(s, "Show the Chats tab even if the thread is empty, then send one line from the item page so the badge appears. Switch language in Settings if time allows.")

# 17 Trust
s = blank()
chrome(s, 17, "Member 4  ·  Trust")
title_block(s, "How lending stays safe enough to try")
items = [
    ("Camera only", "A listing cannot use an old picture from the album. The photo is of the item now."),
    ("Verified contact", "A new account confirms an email or phone before it can use the community."),
    ("Booking record", "Dates, handover note, pickup, return condition, and review stay on one booking."),
    ("Your bookings only", "You see what you borrowed and what others borrowed from you, not a stranger's order."),
    ("Chat on the item", "Meet-up time and mailing questions stay next to the object, with an unread mark."),
    ("Readable UI", "Larger text, and a switch between 中文 and English, for more of the household."),
]
for i, (head, body) in enumerate(items):
    col, row = i % 3, i // 3
    x = Inches(0.48) + Inches(col * 4.2)
    y = Inches(1.9) + Inches(row * 2.35)
    card(s, x, y, Inches(4.0), Inches(2.15), head, body, GREEN if row == 0 else BROWN)
notes(s, "Member 4. Creativity is the camera-at-listing rule plus district plus one shared record. Do not claim insurance or police checks we do not have.")

# 18 Technology in one picture
s = blank()
chrome(s, 18, "Member 4  ·  How it is built")
title_block(s, "What the phone is actually talking to", "The visitor never holds the database key.")
boxes = [
    (Inches(0.5), "The phone", "The Flutter app runs in the browser after the page is downloaded."),
    (Inches(4.55), "GitHub Pages", "Stores the website files and gives the same app to every visitor."),
    (Inches(8.6), "Render", "The middle service. It is the only place with the database key."),
]
for x, head, body in boxes:
    rect(s, x, Inches(2.0), Inches(3.7), Inches(2.3), WHITE)
    text(s, head, x + Inches(0.25), Inches(2.2), Inches(3.2), Inches(0.45), 18, True, GREEN)
    text(s, body, x + Inches(0.25), Inches(2.75), Inches(3.2), Inches(1.3), 15)
rect(s, Inches(0.5), Inches(4.55), Inches(12.3), Inches(1.9), RGBColor(0x14, 0x35, 0x2C))
text(s, "MongoDB Atlas holds one database: accounts, items, bookings, and chat.", Inches(0.8), Inches(4.8), Inches(11.6), Inches(0.5), 20, True, WHITE)
text(s, "A change made in one browser is the change the next browser loads.", Inches(0.8), Inches(5.4), Inches(11.6), Inches(0.6), 16, False, RGBColor(0xD5, 0xE4, 0xDC))
notes(s, "One sentence: the website is files, Render is the doorman, MongoDB is the cupboard. Do not show the password.")

# 19 Six months overview
s = blank()
chrome(s, 19, "Member 5  ·  Six months")
title_block(s, "Month 1 to month 6", "Spend is planned against the work, in Hong Kong dollars.")
months = [
    ("1–2", "Listen and design", "HK$18,000", "Interviews in one estate. Fix the words and the phone flow with residents."),
    ("3–4", "Harden the product", "HK$40,000", "Android plus the website, trust rules, and a support script for the pilot."),
    ("5–6", "Pilot and learn", "HK$42,000", "One district live, posters, office hours, then a written list of what to change."),
]
for i, (m, head, money, body) in enumerate(months):
    y = Inches(1.9) + Inches(i * 1.55)
    rect(s, Inches(0.48), y, Inches(12.35), Inches(1.4), WHITE)
    text(s, m, Inches(0.7), y + Inches(0.4), Inches(1.3), Inches(0.5), 22, True, GREEN)
    text(s, head, Inches(2.2), y + Inches(0.18), Inches(5.5), Inches(0.4), 18, True)
    text(s, body, Inches(2.2), y + Inches(0.65), Inches(6.8), Inches(0.55), 15, False, MUTED)
    text(s, money, Inches(9.3), y + Inches(0.4), Inches(3.2), Inches(0.5), 22, True, BROWN, PP_ALIGN.RIGHT)
notes(s, "Member 5. The prototype already exists, so this budget is the next six months, not the cost of starting from an empty folder.")

# 20 Budget
s = blank()
chrome(s, 20, "Member 6  ·  Budget")
title_block(s, "HK$100,000 over six months", "Matched to the milestone amounts on the previous slide.")
lines = [
    ("Community research and pilot events", "28,000"),
    ("Design, bilingual copy, and posters", "12,000"),
    ("Part-time product development", "35,000"),
    ("Hosting above the free tier, and SMS", "8,000"),
    ("Local marketing in one district", "12,000"),
    ("Admin and basic insurance", "5,000"),
]
rect(s, Inches(0.48), Inches(1.85), Inches(8.3), Inches(4.6), WHITE)
for i, (label, amount) in enumerate(lines):
    y = Inches(2.05) + Inches(i * 0.62)
    text(s, label, Inches(0.75), y, Inches(5.6), Inches(0.4), 16)
    text(s, amount, Inches(6.4), y, Inches(2.0), Inches(0.4), 16, True, align=PP_ALIGN.RIGHT)
rect(s, Inches(9.0), Inches(1.85), Inches(3.8), Inches(4.6), GREEN)
text(s, "TOTAL", Inches(9.25), Inches(2.2), Inches(3.3), Inches(0.3), 14, True, RGBColor(0xD5, 0xE4, 0xDC))
text(s, "HK$100,000", Inches(9.25), Inches(2.6), Inches(3.3), Inches(0.7), 26, True, WHITE)
text(s, "The website, the middle service, and the database already run on free tiers. This money is for people, a pilot, and room to grow.", Inches(9.25), Inches(3.6), Inches(3.3), Inches(2.3), 15, False, WHITE)
notes(s, "Budget Estimation is 10%. If asked, the HK$100,000 matches a micro-fund scale. Current Render and Atlas usage is inside free limits. Member 6 owns this slide and the Q&A.")

# 21 Team
s = blank()
chrome(s, 21, "Member 6  ·  The group")
title_block(s, "Who speaks, and for how long", "About 3 minutes each, then 5 minutes of questions.")
roles = [
    ("1", "Objective and impact", "Opening, the gap, the business idea, social value, close."),
    ("2", "Problem and market", "Pain, users, size, and competitors."),
    ("3", "The live flow", "Phone demo: explore, book, pay, return."),
    ("4", "Trust and build", "Camera, records, chat, and the three services."),
    ("5", "Six-month plan", "What happens after this prototype."),
    ("6", "Cost and questions", "The HK$100,000 split, then Q&A."),
]
for i, (n, head, body) in enumerate(roles):
    col, row = i % 3, i // 3
    x = Inches(0.48) + Inches(col * 4.2)
    y = Inches(1.9) + Inches(row * 2.35)
    rect(s, x, y, Inches(4.0), Inches(2.15), WHITE)
    text(s, n, x + Inches(0.25), y + Inches(0.2), Inches(0.5), Inches(0.4), 20, True, GREEN)
    text(s, head, x + Inches(0.8), y + Inches(0.22), Inches(2.9), Inches(0.4), 16, True)
    text(s, body, x + Inches(0.25), y + Inches(0.85), Inches(3.5), Inches(1.0), 15, False, MUTED)
notes(s, "Write the six real names onto this slide before the presentation. Marks are one group mark, but every person must speak.")

# 22 Demo checklist
s = blank()
chrome(s, 22, "Member 3  ·  Demo card")
title_block(s, "Keep this sequence on the phone")
checks = [
    "Mobile Viewer is open on the ShareKit address.",
    "Log in. If the first screen waits, tell the room the free server is waking.",
    "Show 18 districts, then open one item.",
    "Start a booking and point at platform fee HK$0.",
    "Open Chats, send one line, and show the unread count.",
    "Open Settings and switch English / 中文.",
]
for i, line in enumerate(checks):
    y = Inches(1.85) + Inches(i * 0.78)
    rect(s, Inches(0.5), y, Inches(12.3), Inches(0.68), WHITE)
    text(s, line, Inches(0.75), y + Inches(0.14), Inches(11.7), Inches(0.42), 18)
notes(s, "Practice once on the classroom network. Cold start can be 50 seconds. Do not type the database password anywhere.")

# 23 Q&A
s = blank()
chrome(s, 23, "Member 6  ·  Questions")
title_block(s, "Questions we should be ready for")
qs = [
    ("Why no platform fee?", "Member 1", "The price on screen must be the owner's price. Revenue comes later from estates, not from a hidden cut."),
    ("Is the data really shared?", "Member 4", "Yes. Pages delivers the app. Render talks to one MongoDB. Two browsers see the same new item."),
    ("What if someone damages it?", "Member 4", "The return note, review, and chat are the controls we have. We do not claim insurance."),
    ("What does the money buy?", "Member 6", "People and a one-district pilot. The prototype is already on free hosting."),
]
for i, (q, who, a) in enumerate(qs):
    col, row = i % 2, i // 2
    x = Inches(0.48) + Inches(col * 6.4)
    y = Inches(1.9) + Inches(row * 2.35)
    rect(s, x, y, Inches(6.15), Inches(2.15), WHITE)
    text(s, q, x + Inches(0.25), y + Inches(0.18), Inches(5.6), Inches(0.4), 16, True, GREEN)
    text(s, who, x + Inches(0.25), y + Inches(0.62), Inches(5.6), Inches(0.3), 13, True, BROWN)
    text(s, a, x + Inches(0.25), y + Inches(1.0), Inches(5.6), Inches(0.9), 14)
notes(s, "Member 6 takes the question, then names the person who answers. Keep answers under 40 seconds.")

# 24 Close
s = blank()
chrome(s, 24, "Member 1  ·  Close")
text(s, "Borrow what the\ndistrict already has.", Inches(0.55), Inches(1.5), Inches(8), Inches(1.8), 40, True)
text(s, "ShareKit is live. The platform fee is zero.\nThe next step is one community, for six months.", Inches(0.55), Inches(3.6), Inches(7.5), Inches(1.0), 18, False, MUTED)
rect(s, Inches(8.7), Inches(1.6), Inches(4.05), Inches(4.3), GREEN)
text(s, "TRY IT", Inches(8.95), Inches(1.85), Inches(3.6), Inches(0.3), 13, True, RGBColor(0xD5, 0xE4, 0xDC))
link_text(s, "Open the site", LIVE, Inches(8.95), Inches(2.4), Inches(3.6), Inches(0.45), 20, WHITE)
link_text(s, "Open the phone frame", PHONE, Inches(8.95), Inches(3.15), Inches(3.6), Inches(0.7), 18, WHITE)
text(s, "Thank you.", Inches(8.95), Inches(4.5), Inches(3.6), Inches(0.5), 22, True, WHITE)
notes(s, "Member 1 closes in under 30 seconds and sits down for Q&A led by Member 6.")

# 25 References
s = blank()
chrome(s, 25, "Sources")
title_block(s, "Sources")
refs = [
    "Census and Statistics Department. Hong Kong domestic households and population statistics.",
    "Census and Statistics Department. Persons aged 10 and over who had a smartphone.",
    "Environmental Protection Department. Waste reduction and sustainable consumption guidance.",
    "Cyberport Creative Micro Fund. Project areas used to shape the six-month plan.",
    "ISEM 3027 presentation weights: problem 15, market 15, objective 20, function and flow 35, budget 10, Q&A 5.",
    "The live product: https://horse630.github.io/ISEM_3027_Sharekit/",
]
bullets(s, refs, Inches(0.55), Inches(1.8), Inches(12.2), Inches(4.8), 16)
notes(s, "Do not read this slide unless a marker asks for a source. Household figure should be checked against the latest C&SD table before the day.")

prs.save(OUT)
print(OUT)
print("slides", len(prs.slides))
