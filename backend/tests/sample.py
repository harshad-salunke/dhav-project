from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import mm, cm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT, TA_JUSTIFY
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    HRFlowable, PageBreak, KeepTogether
)
from reportlab.graphics.shapes import Drawing, Rect, String, Line, Polygon
from reportlab.graphics.charts.barcharts import VerticalBarChart
from reportlab.graphics.charts.linecharts import HorizontalLineChart
from reportlab.graphics import renderPDF
from reportlab.platypus.flowables import Flowable
import os

# ─── COLOUR PALETTE ────────────────────────────────────────────────────────────
FIREBASE_ORANGE  = colors.HexColor('#FF6F00')
FIREBASE_YELLOW  = colors.HexColor('#FFA000')
FIREBASE_AMBER   = colors.HexColor('#FFB300')
DARK_BG          = colors.HexColor('#1A1A2E')
SECTION_BLUE     = colors.HexColor('#16213E')
ACCENT_TEAL      = colors.HexColor('#0F3460')
LIGHT_GRAY       = colors.HexColor('#F5F5F5')
MID_GRAY         = colors.HexColor('#E0E0E0')
DARK_GRAY        = colors.HexColor('#424242')
WHITE            = colors.white
GREEN_OK         = colors.HexColor('#2E7D32')
GREEN_LIGHT      = colors.HexColor('#E8F5E9')
RED_WARN         = colors.HexColor('#C62828')
RED_LIGHT        = colors.HexColor('#FFEBEE')
AMBER_LIGHT      = colors.HexColor('#FFF8E1')
TEAL_LIGHT       = colors.HexColor('#E0F7FA')
BLUE_LIGHT       = colors.HexColor('#E3F2FD')

# ─── STYLES ────────────────────────────────────────────────────────────────────
styles = getSampleStyleSheet()

def S(name, **kw):
    return ParagraphStyle(name, **kw)

TITLE_STYLE = S('MainTitle',
    fontSize=26, textColor=WHITE, fontName='Helvetica-Bold',
    alignment=TA_CENTER, spaceAfter=4, leading=32)

SUBTITLE_STYLE = S('Subtitle',
    fontSize=13, textColor=FIREBASE_AMBER, fontName='Helvetica',
    alignment=TA_CENTER, spaceAfter=2, leading=16)

PART_STYLE = S('Part',
    fontSize=15, textColor=WHITE, fontName='Helvetica-Bold',
    alignment=TA_LEFT, spaceAfter=2, leading=20,
    backColor=DARK_BG, borderPad=8)

H2_STYLE = S('H2',
    fontSize=12, textColor=DARK_BG, fontName='Helvetica-Bold',
    spaceAfter=4, spaceBefore=10, leading=16,
    textTransform='uppercase', borderPadding=(0,0,2,0))

BODY_STYLE = S('Body',
    fontSize=9.5, textColor=DARK_GRAY, fontName='Helvetica',
    spaceAfter=4, leading=14, alignment=TA_JUSTIFY)

BODY_BOLD = S('BodyBold',
    fontSize=9.5, textColor=DARK_GRAY, fontName='Helvetica-Bold',
    spaceAfter=4, leading=14)

CODE_STYLE = S('Code',
    fontSize=8.5, textColor=colors.HexColor('#37474F'), fontName='Courier',
    spaceAfter=2, leading=13, backColor=colors.HexColor('#ECEFF1'),
    borderPad=4)

NOTE_STYLE = S('Note',
    fontSize=9, textColor=colors.HexColor('#E65100'), fontName='Helvetica-Bold',
    spaceAfter=4, leading=12)

BULLET_STYLE = S('Bullet',
    fontSize=9.5, textColor=DARK_GRAY, fontName='Helvetica',
    spaceAfter=3, leading=14, leftIndent=14, bulletIndent=4,
    bulletFontName='Helvetica', bulletFontSize=9)

SMALL_ITALIC = S('SmallItalic',
    fontSize=8.5, textColor=colors.HexColor('#78909C'), fontName='Helvetica-Oblique',
    spaceAfter=3, leading=12)

SUMMARY_KEY = S('SummKey',
    fontSize=10, textColor=DARK_BG, fontName='Helvetica-Bold', leading=14)

SUMMARY_VAL = S('SummVal',
    fontSize=10, textColor=GREEN_OK, fontName='Helvetica-Bold', leading=14)

# ─── HELPER FLOWABLES ──────────────────────────────────────────────────────────
class ColorBand(Flowable):
    def __init__(self, w, h, color, radius=4):
        super().__init__()
        self.width, self.height, self.color, self.radius = w, h, color, radius
    def draw(self):
        self.canv.setFillColor(self.color)
        self.canv.roundRect(0, 0, self.width, self.height, self.radius, fill=1, stroke=0)

def part_header(text):
    """Big coloured section header."""
    data = [[Paragraph(text, PART_STYLE)]]
    t = Table(data, colWidths=[170*mm])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), DARK_BG),
        ('ROWBACKGROUNDS', (0,0), (-1,-1), [DARK_BG]),
        ('TOPPADDING',    (0,0), (-1,-1), 10),
        ('BOTTOMPADDING', (0,0), (-1,-1), 10),
        ('LEFTPADDING',   (0,0), (-1,-1), 12),
        ('RIGHTPADDING',  (0,0), (-1,-1), 12),
        ('ROUNDEDCORNERS', [6]),
    ]))
    return t

def section_header(text):
    d = Drawing(170*mm, 22)
    d.add(Rect(0, 0, 170*mm, 22, fillColor=FIREBASE_ORANGE, strokeColor=None, rx=4, ry=4))
    d.add(String(10, 6, text.upper(), fontSize=10, fontName='Helvetica-Bold', fillColor=WHITE))
    return d

def hr(color=FIREBASE_AMBER, thickness=1.2):
    return HRFlowable(width='100%', thickness=thickness, color=color, spaceAfter=6, spaceBefore=4)

def sp(h=6):
    return Spacer(1, h)

def bullet(text, color=FIREBASE_ORANGE):
    return Paragraph(f'<bullet bulletColor="{color.hexval() if hasattr(color,"hexval") else "#FF6F00"}">&#x2022;</bullet> {text}', BULLET_STYLE)

def info_box(text, bg=BLUE_LIGHT, border=ACCENT_TEAL):
    data = [[Paragraph(text, BODY_STYLE)]]
    t = Table(data, colWidths=[166*mm])
    t.setStyle(TableStyle([
        ('BACKGROUND',    (0,0), (-1,-1), bg),
        ('LINEAFTER',     (0,0), (0,-1), 3, border),
        ('LINEBEFORE',    (0,0), (0,-1), 3, border),
        ('TOPPADDING',    (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING',   (0,0), (-1,-1), 12),
        ('RIGHTPADDING',  (0,0), (-1,-1), 12),
    ]))
    return t

def make_table(headers, rows, col_widths=None, stripe=True, header_bg=ACCENT_TEAL):
    data = [headers] + rows
    if col_widths is None:
        col_widths = [170*mm / len(headers)] * len(headers)
    t = Table(data, colWidths=col_widths, repeatRows=1)
    style = [
        ('BACKGROUND',    (0,0), (-1,0),  header_bg),
        ('TEXTCOLOR',     (0,0), (-1,0),  WHITE),
        ('FONTNAME',      (0,0), (-1,0),  'Helvetica-Bold'),
        ('FONTSIZE',      (0,0), (-1,0),  9),
        ('ALIGN',         (0,0), (-1,-1), 'CENTER'),
        ('VALIGN',        (0,0), (-1,-1), 'MIDDLE'),
        ('FONTNAME',      (0,1), (-1,-1), 'Helvetica'),
        ('FONTSIZE',      (0,1), (-1,-1), 8.5),
        ('TOPPADDING',    (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING',   (0,0), (-1,-1), 6),
        ('RIGHTPADDING',  (0,0), (-1,-1), 6),
        ('GRID',          (0,0), (-1,-1), 0.5, colors.HexColor('#B0BEC5')),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [WHITE, LIGHT_GRAY] if stripe else [WHITE]),
    ]
    t.setStyle(TableStyle(style))
    return t

# ─── VISUAL CHARTS ─────────────────────────────────────────────────────────────
def bandwidth_bar_chart():
    drawing = Drawing(170*mm, 120)
    bc = VerticalBarChart()
    bc.x = 35; bc.y = 15; bc.height = 90; bc.width = 145*mm
    bc.data = [[13, 26, 39, 130, 260, 520]]
    bc.bars[0].fillColor = FIREBASE_ORANGE
    bc.categoryAxis.categoryNames = ['5 PGs','10 PGs','15 PGs','50 PGs','100 PGs','200 PGs']
    bc.categoryAxis.labels.fontSize = 7.5
    bc.categoryAxis.labels.fontName = 'Helvetica'
    bc.valueAxis.valueMin = 0; bc.valueAxis.valueMax = 550
    bc.valueAxis.valueStep = 100
    bc.valueAxis.labels.fontSize = 7.5
    bc.valueAxis.labels.fontName = 'Helvetica'
    # free tier line
    from reportlab.graphics.shapes import Line as GLine, String as GStr
    free_y = bc.y + (30/550) * bc.height
    drawing.add(GLine(bc.x, bc.y + (30/550)*bc.height, bc.x+bc.width, bc.y + (30/550)*bc.height,
                      strokeColor=GREEN_OK, strokeWidth=1.5, strokeDashArray=[4,3]))
    drawing.add(GStr(bc.x+2, bc.y + (30/550)*bc.height + 2, '30 GB Free Tier',
                     fontSize=7, fontName='Helvetica-Bold', fillColor=GREEN_OK))
    drawing.add(bc)
    from reportlab.graphics.shapes import String as GStr2
    drawing.add(GStr2(85*mm, 108, 'DB Bandwidth (GB/Month) by Scale',
                      fontSize=9, fontName='Helvetica-Bold', fillColor=DARK_BG, textAnchor='middle'))
    return drawing

def cost_line_chart():
    drawing = Drawing(170*mm, 130)
    lc = HorizontalLineChart()
    lc.x = 45; lc.y = 20; lc.height = 95; lc.width = 140*mm
    # unoptimised total, optimised total
    lc.data = [
        [9, 115, 320, 670],     # unoptimised
        [9,  90, 160, 330],     # optimised
    ]
    lc.lines[0].strokeColor = RED_WARN
    lc.lines[0].strokeWidth = 2
    lc.lines[1].strokeColor = GREEN_OK
    lc.lines[1].strokeWidth = 2
    lc.categoryAxis.categoryNames = ['10 PGs','50 PGs','100 PGs','200 PGs']
    lc.categoryAxis.labels.fontSize = 8
    lc.valueAxis.valueMin = 0; lc.valueAxis.valueMax = 700
    lc.valueAxis.valueStep = 100
    lc.valueAxis.labels.fontSize = 8
    drawing.add(lc)
    from reportlab.graphics.shapes import String as GStr, Rect as GRect
    # legend
    drawing.add(GRect(48, 5, 10, 6, fillColor=RED_WARN, strokeColor=None))
    drawing.add(GStr(62, 5, 'Unoptimised', fontSize=8, fontName='Helvetica', fillColor=DARK_GRAY))
    drawing.add(GRect(120, 5, 10, 6, fillColor=GREEN_OK, strokeColor=None))
    drawing.add(GStr(134, 5, 'Optimised', fontSize=8, fontName='Helvetica', fillColor=DARK_GRAY))
    drawing.add(GStr(85*mm, 118, 'Total Firebase Cost ($/Month) — Unoptimised vs Optimised',
                     fontSize=9, fontName='Helvetica-Bold', fillColor=DARK_BG, textAnchor='middle'))
    return drawing

def storage_growth_chart():
    drawing = Drawing(170*mm, 120)
    bc = VerticalBarChart()
    bc.x = 40; bc.y = 15; bc.height = 90; bc.width = 130*mm
    bc.data = [
        [12.9, 25, 37],  # DB MB
        [1700, 2800, 3900],  # Cloud Storage MB
    ]
    bc.groupSpacing = 10
    bc.bars[0].fillColor = ACCENT_TEAL
    bc.bars[1].fillColor = FIREBASE_AMBER
    bc.categoryAxis.categoryNames = ['Year 1','Year 2','Year 3']
    bc.categoryAxis.labels.fontSize = 9
    bc.valueAxis.valueMin = 0; bc.valueAxis.valueMax = 4200
    bc.valueAxis.valueStep = 700
    bc.valueAxis.labels.fontSize = 8
    drawing.add(bc)
    from reportlab.graphics.shapes import String as GStr, Rect as GRect
    drawing.add(GRect(42, 3, 10, 6, fillColor=ACCENT_TEAL, strokeColor=None))
    drawing.add(GStr(56, 3, 'Realtime DB (MB)', fontSize=8, fontName='Helvetica', fillColor=DARK_GRAY))
    drawing.add(GRect(140, 3, 10, 6, fillColor=FIREBASE_AMBER, strokeColor=None))
    drawing.add(GStr(154, 3, 'Cloud Storage (MB)', fontSize=8, fontName='Helvetica', fillColor=DARK_GRAY))
    drawing.add(GStr(85*mm, 110, 'Storage Growth — 200-Bed Single PG (MB)',
                     fontSize=9, fontName='Helvetica-Bold', fillColor=DARK_BG, textAnchor='middle'))
    return drawing

def margin_bar_chart():
    drawing = Drawing(170*mm, 120)
    bc = VerticalBarChart()
    bc.x = 40; bc.y = 15; bc.height = 90; bc.width = 130*mm
    bc.data = [[94, 92, 90, 90]]
    bc.bars[0].fillColor = GREEN_OK
    bc.categoryAxis.categoryNames = ['Starter\n(30 beds)', 'Growth\n(100 beds)', 'Pro\n(200 beds)', 'Enterprise\n(200+)']
    bc.categoryAxis.labels.fontSize = 8
    bc.valueAxis.valueMin = 85; bc.valueAxis.valueMax = 100
    bc.valueAxis.valueStep = 5
    bc.valueAxis.labels.fontSize = 8
    drawing.add(bc)
    from reportlab.graphics.shapes import String as GStr
    drawing.add(GStr(85*mm, 110, 'Profit Margin % by Pricing Tier',
                     fontSize=9, fontName='Helvetica-Bold', fillColor=DARK_BG, textAnchor='middle'))
    return drawing

# ─── COVER PAGE ────────────────────────────────────────────────────────────────
def cover_page(story):
    # dark header block
    cover_data = [[
        Paragraph('Complete Firebase Cost Analysis', TITLE_STYLE),
        Paragraph('PG Owner SaaS', SUBTITLE_STYLE),
        Paragraph('Billing Mechanics · Data Architecture · SaaS Scaling · Pricing Strategy', 
                  S('sub2', fontSize=9, textColor=colors.HexColor('#BDBDBD'),
                    fontName='Helvetica-Oblique', alignment=TA_CENTER, leading=13)),
    ]]
    cover = Table([[Paragraph('Complete Firebase Cost Analysis', TITLE_STYLE)],
                   [Paragraph('PG Owner SaaS', SUBTITLE_STYLE)],
                   [Paragraph('Billing Mechanics  ·  Data Architecture  ·  SaaS Scaling  ·  Pricing Strategy',
                               S('sub2', fontSize=9, textColor=colors.HexColor('#BDBDBD'),
                                 fontName='Helvetica-Oblique', alignment=TA_CENTER, leading=13))],
                   ], colWidths=[170*mm])
    cover.setStyle(TableStyle([
        ('BACKGROUND',    (0,0), (-1,-1), DARK_BG),
        ('TOPPADDING',    (0,0), (-1,-1), 14),
        ('BOTTOMPADDING', (0,-1),(-1,-1), 18),
        ('LEFTPADDING',   (0,0), (-1,-1), 16),
        ('RIGHTPADDING',  (0,0), (-1,-1), 16),
        ('ROUNDEDCORNERS', [8]),
    ]))
    story.append(cover)
    story.append(sp(16))

    # quick-glance summary cards
    cards = [
        ('₹75–130', 'Monthly cost\n200-bed PG', GREEN_OK, GREEN_LIGHT),
        ('90%+',    'Profit margin\nat ₹15/bed',  FIREBASE_ORANGE, AMBER_LIGHT),
        ('10+ yrs', 'Before DB\nstorage cost',   ACCENT_TEAL, TEAL_LIGHT),
        ('15 PGs',  'Scale before\nbandwidth bill', RED_WARN, RED_LIGHT),
    ]
    cell_data = []
    for val, label, tc, bg in cards:
        cell_data.append(Table(
            [[Paragraph(val, S('cv', fontSize=18, textColor=tc, fontName='Helvetica-Bold',
                               alignment=TA_CENTER, leading=22))],
             [Paragraph(label.replace('\n','<br/>'), S('cl', fontSize=8, textColor=DARK_GRAY,
                               fontName='Helvetica', alignment=TA_CENTER, leading=11))]],
            colWidths=[38*mm]))

    card_table = Table([cell_data], colWidths=[42.5*mm]*4)
    card_table.setStyle(TableStyle([
        ('BACKGROUND',    (0,0), (-1,-1), WHITE),
        ('BOX',           (0,0), (0,-1), 1.5, colors.HexColor('#E0E0E0')),
        ('BOX',           (1,0), (1,-1), 1.5, colors.HexColor('#E0E0E0')),
        ('BOX',           (2,0), (2,-1), 1.5, colors.HexColor('#E0E0E0')),
        ('BOX',           (3,0), (3,-1), 1.5, colors.HexColor('#E0E0E0')),
        ('TOPPADDING',    (0,0), (-1,-1), 10),
        ('BOTTOMPADDING', (0,0), (-1,-1), 10),
        ('ROUNDEDCORNERS', [6]),
    ]))
    story.append(card_table)
    story.append(sp(10))
    story.append(hr())

# ─── BUILD STORY ───────────────────────────────────────────────────────────────
def build_pdf():
    output = 'Firebase_Cost_Analysis_PG_SaaS.pdf'
    doc = SimpleDocTemplate(output, pagesize=A4,
                            leftMargin=20*mm, rightMargin=20*mm,
                            topMargin=18*mm, bottomMargin=18*mm,
                            title='Complete Firebase Cost Analysis — PG Owner SaaS')

    story = []

    # ── COVER ──────────────────────────────────────────────────────────────────
    cover_page(story)

    # ═══════════════════════════════════════════════════════════════════════════
    # PART 1
    # ═══════════════════════════════════════════════════════════════════════════
    story.append(part_header('PART 1: How Firebase Billing Actually Works (Your Core Questions Answered)'))
    story.append(sp(8))

    # Q1
    story.append(section_header('Question 1: Is storage monthly or one-time?'))
    story.append(sp(6))
    story.append(Paragraph(
        'Monthly recurring — every single month. Think of it like rent for a storage unit. '
        'Firebase looks at how much data you have stored at the end of each month and charges '
        'you for it. There is no concept of "I already paid for this data."', BODY_STYLE))
    story.append(sp(4))
    story.append(info_box(
        '<b>Example:</b> You store 3 GB in January → pay for 3 GB. Same data still there in '
        'February → pay for 3 GB again. Delete it in March → pay $0.', AMBER_LIGHT, FIREBASE_ORANGE))
    story.append(sp(6))

    story.append(Paragraph('<b>For Realtime Database on Blaze plan:</b>', BODY_BOLD))
    story.append(bullet('First 5 GB stored: <b>FREE every month</b>'))
    story.append(bullet('Beyond 5 GB: <b>$5 per GB per month</b> (recurring)'))
    story.append(sp(4))
    story.append(Paragraph('<b>For Cloud Storage on Blaze plan:</b>', BODY_BOLD))
    story.append(bullet('First 5 GB stored: <b>FREE every month</b>'))
    story.append(bullet('Beyond 5 GB: <b>$0.026 per GB per month</b> (recurring)'))
    story.append(sp(8))

    # Q2
    story.append(section_header('Question 2: What counts as "download" / bandwidth?'))
    story.append(sp(6))
    story.append(Paragraph(
        'Every byte of data read by any client = download. This includes:', BODY_STYLE))
    for b in [
        'Your app opening and loading dashboard data',
        'Realtime listeners receiving updates when data changes',
        'Any .get(), .onValue, .once() call',
        'Residents opening the resident app and loading their info',
        'Images/files loaded from Cloud Storage',
    ]:
        story.append(bullet(b))
    story.append(sp(6))

    bw_headers = [
        Paragraph('<b>Service</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Free/Month</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>After Free</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
    ]
    bw_rows = [
        ['Realtime DB bandwidth', '~30 GB/month (1 GB/day)', '$1.00 per GB'],
        ['Cloud Storage bandwidth', '~30 GB/month (1 GB/day)', '$0.12 per GB'],
    ]
    story.append(make_table(bw_headers, bw_rows, [65*mm, 60*mm, 45*mm]))
    story.append(sp(8))

    # Q3
    story.append(section_header('Question 3: Phone OTP (Firebase Phone Auth) Pricing'))
    story.append(sp(6))
    story.append(info_box(
        'This is the most confusing and highest actual cost for your app.', RED_LIGHT, RED_WARN))
    story.append(sp(4))
    story.append(Paragraph(
        'On the <b>Spark (free) plan:</b> 10 OTP SMS per day maximum — hard cap, not scalable for production.',
        BODY_STYLE))
    story.append(sp(4))
    story.append(Paragraph('<b>On the Blaze plan:</b>', BODY_BOLD))
    story.append(bullet('First ~10 SMS/day free (tiny)'))
    story.append(bullet('Beyond that: charged per SMS by destination country'))
    story.append(bullet('India rate: approximately <b>&#x20B9;0.23–&#x20B9;0.42 per OTP</b> ($0.0028–$0.005)'))
    story.append(sp(4))
    story.append(Paragraph(
        'Firebase does NOT publish a clear table in their main docs — the per-country rates are only '
        'visible after you sign up in the Firebase console under Billing. The pricing agent confirmed '
        'India is approximately <b>$0.003–$0.005 per verification</b>.', BODY_STYLE))
    story.append(sp(4))
    story.append(Paragraph(
        'There is <b>no monthly free bundle</b> — just 10/day free, then pay per OTP.', NOTE_STYLE))
    story.append(sp(8))

    # Q4
    story.append(section_header('Question 4: Cloud Functions'))
    story.append(sp(6))
    cf_headers = [
        Paragraph('<b>Dimension</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Free/Month</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>After Free</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
    ]
    cf_rows = [
        ['Invocations', '2,000,000', '$0.40/million'],
        ['Compute (GB-seconds)', '400,000', '$0.0000025 each'],
        ['External network egress', '5 GB', '$0.12/GB'],
    ]
    story.append(make_table(cf_headers, cf_rows, [65*mm, 60*mm, 45*mm]))
    story.append(sp(6))
    story.append(info_box(
        'Your app has 1 Cloud Function (push notifications). At even 10,000 notifications/month, '
        'cost = <b>$0 — completely in free tier</b>.', GREEN_LIGHT, GREEN_OK))
    story.append(sp(10))

    # ═══════════════════════════════════════════════════════════════════════════
    # PART 2
    # ═══════════════════════════════════════════════════════════════════════════
    story.append(part_header('PART 2: Your App\'s Data Analysis (From Codebase)'))
    story.append(sp(8))

    story.append(section_header('Database Structure'))
    story.append(sp(6))
    story.append(Paragraph('Your Firebase has these main paths:', BODY_STYLE))
    story.append(sp(4))

    paths = [
        ('/Owners/{uid}', 'owner/staff accounts'),
        ('/Pgs/{pgId}', 'PG metadata'),
        ('/PgsInfo/{pgId}/floorInfo', 'ALL rooms, beds, allocation history'),
        ('/PgsInfo/{pgId}/payments/', 'master + by_month + by_resident indices'),
        ('/Residents/{pgId}/', 'all resident records'),
        ('/PgsInfo/{pgId}/notifications/', 'notifications + per-user read states'),
        ('/PgsInfo/{pgId}/expenses/', 'all expenses'),
        ('/PgsInfo/{pgId}/serviceRequests/', 'service requests'),
        ('/login_ref/ and /owner_login_ref/', 'phone→user mapping'),
    ]
    path_rows = [[Paragraph(p, CODE_STYLE), Paragraph(d, BODY_STYLE)] for p, d in paths]
    path_table = Table(path_rows, colWidths=[90*mm, 80*mm])
    path_table.setStyle(TableStyle([
        ('BACKGROUND',    (0,0), (0,-1), colors.HexColor('#ECEFF1')),
        ('BACKGROUND',    (1,0), (1,-1), WHITE),
        ('ROWBACKGROUNDS', (0,0), (-1,-1), [colors.HexColor('#ECEFF1'), WHITE]*5),
        ('GRID',          (0,0), (-1,-1), 0.4, colors.HexColor('#CFD8DC')),
        ('TOPPADDING',    (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING',   (0,0), (-1,-1), 6),
        ('RIGHTPADDING',  (0,0), (-1,-1), 6),
        ('VALIGN',        (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(path_table)
    story.append(sp(8))

    story.append(section_header('How Much Data Is Loaded on App Open'))
    story.append(sp(6))
    story.append(Paragraph(
        'Your app opens <b>16–18 simultaneous real-time listeners</b> on every dashboard load. '
        'No pagination exists — ALL data is loaded into memory.', BODY_STYLE))
    story.append(sp(6))

    load_headers = [
        Paragraph('<b>What Gets Loaded</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Data Size (50-bed PG)</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Data Size (200-bed PG)</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
    ]
    load_rows = [
        ['Owner/staff records', '5 KB', '5 KB'],
        ['PG metadata + config', '4 KB', '4 KB'],
        ['Floor/room/bed tree', '120 KB', '500 KB'],
        ['Resident records', '100 KB', '400 KB'],
        ['Payments (current month)', '60 KB', '250 KB'],
        ['Service requests', '25 KB', '100 KB'],
        ['Notifications (+ user states)', '100 KB', '600 KB'],
        ['Expenses', '60 KB', '250 KB'],
        ['Other (machines, menu, etc.)', '10 KB', '25 KB'],
        [Paragraph('<b>Total per session open</b>', S('tot', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER)),
         Paragraph('<b>~490 KB</b>', S('tot', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER, textColor=GREEN_OK)),
         Paragraph('<b>~2.1 MB</b>', S('tot', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER, textColor=RED_WARN))],
    ]
    t = make_table(load_headers, load_rows, [75*mm, 47.5*mm, 47.5*mm])
    t.setStyle(TableStyle([
        ('BACKGROUND',    (0,0), (-1,0),  ACCENT_TEAL),
        ('TEXTCOLOR',     (0,0), (-1,0),  WHITE),
        ('FONTNAME',      (0,0), (-1,0),  'Helvetica-Bold'),
        ('BACKGROUND',    (0,-1),(-1,-1), AMBER_LIGHT),
        ('GRID',          (0,0), (-1,-1), 0.5, colors.HexColor('#B0BEC5')),
        ('TOPPADDING',    (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING',   (0,0), (-1,-1), 6),
        ('RIGHTPADDING',  (0,0), (-1,-1), 6),
        ('ROWBACKGROUNDS', (0,1), (-1,-2), [WHITE, LIGHT_GRAY]),
        ('ALIGN',         (0,0), (-1,-1), 'CENTER'),
        ('FONTSIZE',      (0,1), (-1,-1), 8.5),
        ('FONTNAME',      (0,1), (-1,-1), 'Helvetica'),
    ]))
    story.append(t)
    story.append(sp(8))

    story.append(section_header('Data Size Per Record'))
    story.append(sp(6))
    rec_headers = [
        Paragraph('<b>Model</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Size Per Record</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Notes</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
    ]
    rec_rows = [
        ['Resident', '1.5–2 KB', 'Includes 3 embedded documents'],
        ['Payment', '1.5–3 KB', 'Higher with attachments'],
        ['Room config', '5–8 KB', 'Includes full allocation history'],
        ['Notification', '1–3 KB base + 60 bytes per user who saw it', 'Scales badly with users'],
        ['Expense', '1–1.5 KB', 'With image URLs'],
        ['Service request', '~1 KB', ''],
        ['Owner/staff', '~900 bytes', ''],
    ]
    story.append(make_table(rec_headers, rec_rows, [35*mm, 55*mm, 80*mm]))
    story.append(sp(10))

    # ═══════════════════════════════════════════════════════════════════════════
    # PART 3
    # ═══════════════════════════════════════════════════════════════════════════
    story.append(part_header('PART 3: Storage Growth Projections — Single 200-Bed PG'))
    story.append(sp(8))

    story.append(section_header('Realtime Database Storage Growth'))
    story.append(sp(6))
    db_headers = [
        Paragraph('<b>Data Category</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Year 1</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Year 2</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Year 3</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
    ]
    db_rows = [
        ['Residents (200 active)', '0.4 MB', '0.4 MB', '0.4 MB'],
        ['Rooms + beds + allocation history', '0.8 MB', '1.2 MB', '1.6 MB'],
        ['Payments (200/month)', '4.8 MB', '9.6 MB', '14.4 MB'],
        ['Expenses (100/month)', '1.4 MB', '2.9 MB', '4.3 MB'],
        ['Notifications + user states', '4.8 MB', '9.6 MB', '14.4 MB'],
        ['Service requests', '0.3 MB', '0.6 MB', '0.9 MB'],
        ['Daily menus', '0.3 MB', '0.6 MB', '0.9 MB'],
        ['Misc (config, machines, etc.)', '0.1 MB', '0.1 MB', '0.1 MB'],
        [Paragraph('<b>Total DB size</b>', S('tot', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER)),
         Paragraph('<b>~12.9 MB</b>', S('tot', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER, textColor=GREEN_OK)),
         Paragraph('<b>~25 MB</b>', S('tot', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER, textColor=GREEN_OK)),
         Paragraph('<b>~37 MB</b>', S('tot', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER, textColor=GREEN_OK))],
    ]
    t3 = make_table(db_headers, db_rows, [65*mm, 35*mm, 35*mm, 35*mm])
    t3.setStyle(TableStyle([
        ('BACKGROUND',    (0,0), (-1,0), ACCENT_TEAL),
        ('TEXTCOLOR',     (0,0), (-1,0), WHITE),
        ('BACKGROUND',    (0,-1),(-1,-1), GREEN_LIGHT),
        ('GRID',          (0,0), (-1,-1), 0.5, colors.HexColor('#B0BEC5')),
        ('ROWBACKGROUNDS', (0,1),(-1,-2), [WHITE, LIGHT_GRAY]),
        ('TOPPADDING',    (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING',   (0,0), (-1,-1), 6),
        ('RIGHTPADDING',  (0,0), (-1,-1), 6),
        ('ALIGN',         (0,0), (-1,-1), 'CENTER'),
        ('FONTSIZE',      (0,1), (-1,-1), 8.5),
        ('FONTNAME',      (0,1), (-1,-1), 'Helvetica'),
        ('FONTNAME',      (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE',      (0,0), (-1,0), 9),
        ('TEXTCOLOR',     (0,0), (-1,0), WHITE),
    ]))
    story.append(t3)
    story.append(sp(4))
    story.append(info_box(
        '<b>DB storage cost: $0 for at least 10+ years per PG.</b> The 5 GB free tier is enormous '
        'compared to your text-only data.', GREEN_LIGHT, GREEN_OK))
    story.append(sp(8))

    # Storage chart
    story.append(storage_growth_chart())
    story.append(sp(8))

    story.append(section_header('Cloud Storage (Images/Files) Growth'))
    story.append(sp(6))
    cs_headers = [
        Paragraph('<b>File Type</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Per PG (Year 1)</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Per PG (Year 2)</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Per PG (Year 3)</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
    ]
    cs_rows = [
        ['Resident ID documents\n(3 docs × 200 residents × ~1 MB)', '600 MB', '600 MB', '600 MB'],
        ['PG profile image', '2 MB', '2 MB', '2 MB'],
        ['Expense bill photos (100/month × 0.5 MB)', '600 MB', '600 MB', '600 MB'],
        ['Service request images (50/month × 0.8 MB)', '480 MB', '480 MB', '480 MB'],
        ['Payment proofs', '~0 (auto-deleted)', '~0', '~0'],
        [Paragraph('<b>Total Cloud Storage</b>', S('tot', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER)),
         Paragraph('<b>~1.7 GB</b>', S('tot', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER, textColor=GREEN_OK)),
         Paragraph('<b>~2.8 GB</b>', S('tot', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER, textColor=GREEN_OK)),
         Paragraph('<b>~3.9 GB</b>', S('tot', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER, textColor=FIREBASE_ORANGE))],
    ]
    t_cs = make_table(cs_headers, cs_rows, [60*mm, 36.5*mm, 36.5*mm, 37*mm])
    t_cs.setStyle(TableStyle([
        ('BACKGROUND',    (0,0), (-1,0), ACCENT_TEAL),
        ('TEXTCOLOR',     (0,0), (-1,0), WHITE),
        ('BACKGROUND',    (0,-1),(-1,-1), AMBER_LIGHT),
        ('GRID',          (0,0), (-1,-1), 0.5, colors.HexColor('#B0BEC5')),
        ('ROWBACKGROUNDS', (0,1),(-1,-2), [WHITE, LIGHT_GRAY]),
        ('TOPPADDING',    (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING',   (0,0), (-1,-1), 5),
        ('RIGHTPADDING',  (0,0), (-1,-1), 5),
        ('ALIGN',         (0,0), (-1,-1), 'CENTER'),
        ('FONTSIZE',      (0,1), (-1,-1), 8.5),
        ('FONTNAME',      (0,1), (-1,-1), 'Helvetica'),
        ('FONTNAME',      (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE',      (0,0), (-1,0), 9),
        ('TEXTCOLOR',     (0,0), (-1,0), WHITE),
    ]))
    story.append(t_cs)
    story.append(sp(4))
    story.append(info_box(
        '<b>Cloud Storage cost: $0 for first 3–4 years per PG</b> (5 GB free tier covers it). '
        'Year 4 onwards, maybe $0.05–$0.10/month.', GREEN_LIGHT, GREEN_OK))
    story.append(sp(10))

    # ═══════════════════════════════════════════════════════════════════════════
    # PART 4
    # ═══════════════════════════════════════════════════════════════════════════
    story.append(PageBreak())
    story.append(part_header('PART 4: Monthly Cost Breakdown — 200-Bed Single PG'))
    story.append(sp(8))

    story.append(section_header('Bandwidth (The Real Variable Cost)'))
    story.append(sp(6))
    bw2_headers = [
        Paragraph('<b>Who Reads</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Sessions/Day</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Data/Session</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Monthly Total</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
    ]
    bw2_rows = [
        ['Owner (dashboard opens)', '3', '2.1 MB', '189 MB'],
        ['Staff (5 members)', '2 each', '1.5 MB', '450 MB'],
        ['Residents (200, 50% active/day)', '100 sessions', '0.5 MB', '1,500 MB'],
        ['Real-time push updates (all listeners)', 'continuous', '—', '~500 MB/month'],
        [Paragraph('<b>Total bandwidth/month</b>', S('tot', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER)),
         '', '', Paragraph('<b>~2.6 GB/month</b>', S('tot', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER, textColor=GREEN_OK))],
    ]
    t_bw2 = make_table(bw2_headers, bw2_rows, [55*mm, 35*mm, 35*mm, 45*mm])
    t_bw2.setStyle(TableStyle([
        ('BACKGROUND',    (0,0), (-1,0), ACCENT_TEAL),
        ('TEXTCOLOR',     (0,0), (-1,0), WHITE),
        ('BACKGROUND',    (0,-1),(-1,-1), GREEN_LIGHT),
        ('GRID',          (0,0), (-1,-1), 0.5, colors.HexColor('#B0BEC5')),
        ('ROWBACKGROUNDS', (0,1),(-1,-2), [WHITE, LIGHT_GRAY]),
        ('TOPPADDING',    (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING',   (0,0), (-1,-1), 6),
        ('RIGHTPADDING',  (0,0), (-1,-1), 6),
        ('ALIGN',         (0,0), (-1,-1), 'CENTER'),
        ('FONTSIZE',      (0,1), (-1,-1), 8.5),
        ('FONTNAME',      (0,1), (-1,-1), 'Helvetica'),
        ('FONTNAME',      (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE',      (0,0), (-1,0), 9),
        ('TEXTCOLOR',     (0,0), (-1,0), WHITE),
        ('SPAN',          (0,-1),(2,-1)),
    ]))
    story.append(t_bw2)
    story.append(sp(4))
    story.append(info_box(
        '<b>Blaze free tier: 30 GB/month</b> → you\'re well within free tier for a single PG.', GREEN_LIGHT, GREEN_OK))
    story.append(sp(8))

    story.append(section_header('Phone OTP Cost (Main Recurring Cost)'))
    story.append(sp(6))
    otp_headers = [
        Paragraph('<b>User Type</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>OTPs/Month</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Cost @ &#x20B9;0.33/OTP</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
    ]
    otp_rows = [
        ['Resident logins (200 × 1/month avg)', '200', '&#x20B9;66'],
        ['New resident registrations (~10/month)', '10', '&#x20B9;3.30'],
        ['Staff logins (5 × 3/month)', '15', '&#x20B9;5'],
        ['Owner', '2', '&#x20B9;0.66'],
        [Paragraph('<b>Total</b>', S('tot', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER)),
         Paragraph('<b>~227 OTPs</b>', S('tot', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER, textColor=FIREBASE_ORANGE)),
         Paragraph('<b>~&#x20B9;75/month ($0.90)</b>', S('tot', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER, textColor=FIREBASE_ORANGE))],
    ]
    t_otp = make_table(otp_headers, otp_rows, [80*mm, 45*mm, 45*mm])
    t_otp.setStyle(TableStyle([
        ('BACKGROUND',    (0,0), (-1,0), ACCENT_TEAL),
        ('TEXTCOLOR',     (0,0), (-1,0), WHITE),
        ('BACKGROUND',    (0,-1),(-1,-1), AMBER_LIGHT),
        ('GRID',          (0,0), (-1,-1), 0.5, colors.HexColor('#B0BEC5')),
        ('ROWBACKGROUNDS', (0,1),(-1,-2), [WHITE, LIGHT_GRAY]),
        ('TOPPADDING',    (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING',   (0,0), (-1,-1), 6),
        ('RIGHTPADDING',  (0,0), (-1,-1), 6),
        ('ALIGN',         (0,0), (-1,-1), 'CENTER'),
        ('FONTSIZE',      (0,1), (-1,-1), 8.5),
        ('FONTNAME',      (0,1), (-1,-1), 'Helvetica'),
        ('FONTNAME',      (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE',      (0,0), (-1,0), 9),
        ('TEXTCOLOR',     (0,0), (-1,0), WHITE),
    ]))
    story.append(t_otp)
    story.append(sp(4))
    story.append(Paragraph(
        'If residents login more frequently (2×/month): <b>~&#x20B9;130/month ($1.55)</b>', BODY_STYLE))
    story.append(sp(8))

    story.append(section_header('Single 200-Bed PG Monthly Cost Summary'))
    story.append(sp(6))
    sum_headers = [
        Paragraph('<b>Cost Item</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Monthly Cost</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
    ]
    sum_rows = [
        ['Realtime Database storage', Paragraph('&#x20B9;0', S('gr', fontSize=9, textColor=GREEN_OK, fontName='Helvetica-Bold', alignment=TA_CENTER))],
        ['Realtime Database bandwidth', Paragraph('&#x20B9;0', S('gr', fontSize=9, textColor=GREEN_OK, fontName='Helvetica-Bold', alignment=TA_CENTER))],
        ['Cloud Storage (files)', Paragraph('&#x20B9;0', S('gr', fontSize=9, textColor=GREEN_OK, fontName='Helvetica-Bold', alignment=TA_CENTER))],
        ['Cloud Storage downloads', Paragraph('&#x20B9;0', S('gr', fontSize=9, textColor=GREEN_OK, fontName='Helvetica-Bold', alignment=TA_CENTER))],
        ['Phone OTP SMS', Paragraph('&#x20B9;75–&#x20B9;130', S('or', fontSize=9, textColor=FIREBASE_ORANGE, fontName='Helvetica-Bold', alignment=TA_CENTER))],
        ['Cloud Functions', Paragraph('&#x20B9;0', S('gr', fontSize=9, textColor=GREEN_OK, fontName='Helvetica-Bold', alignment=TA_CENTER))],
        [Paragraph('<b>Total Firebase cost</b>', S('tot', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER)),
         Paragraph('<b>&#x20B9;75–&#x20B9;130/month ($0.90–$1.55)</b>', S('tot', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER, textColor=FIREBASE_ORANGE))],
    ]
    t_sum = make_table(sum_headers, sum_rows, [110*mm, 60*mm])
    t_sum.setStyle(TableStyle([
        ('BACKGROUND',    (0,0), (-1,0), ACCENT_TEAL),
        ('TEXTCOLOR',     (0,0), (-1,0), WHITE),
        ('BACKGROUND',    (0,-1),(-1,-1), AMBER_LIGHT),
        ('GRID',          (0,0), (-1,-1), 0.5, colors.HexColor('#B0BEC5')),
        ('ROWBACKGROUNDS', (0,1),(-1,-2), [WHITE, LIGHT_GRAY]),
        ('TOPPADDING',    (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING',   (0,0), (-1,-1), 8),
        ('RIGHTPADDING',  (0,0), (-1,-1), 8),
        ('ALIGN',         (1,0), (1,-1), 'CENTER'),
        ('ALIGN',         (0,1), (0,-1), 'LEFT'),
        ('FONTSIZE',      (0,1), (-1,-1), 9),
        ('FONTNAME',      (0,1), (-1,-1), 'Helvetica'),
        ('FONTNAME',      (0,0), (-1,0), 'Helvetica-Bold'),
        ('FONTSIZE',      (0,0), (-1,0), 9),
        ('TEXTCOLOR',     (0,0), (-1,0), WHITE),
    ]))
    story.append(t_sum)
    story.append(sp(10))

    # ═══════════════════════════════════════════════════════════════════════════
    # PART 5
    # ═══════════════════════════════════════════════════════════════════════════
    story.append(PageBreak())
    story.append(part_header('PART 5: SaaS Scale — What Happens With Multiple PGs'))
    story.append(sp(8))

    story.append(section_header('Free Tier Is Shared Across Your Entire Project'))
    story.append(sp(6))
    story.append(Paragraph(
        'When you have 100 PGs all using one Firebase project, free tiers are pooled together.',
        BODY_STYLE))
    story.append(sp(6))

    scale_headers = [
        Paragraph('<b>PGs</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>DB Bandwidth/Month</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Free</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Billable</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Cost</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
    ]

    def scale_cost_color(cost_str):
        if cost_str == '$0':
            return Paragraph(cost_str, S('gc', fontSize=8.5, textColor=GREEN_OK, fontName='Helvetica-Bold', alignment=TA_CENTER))
        return Paragraph(cost_str, S('rc', fontSize=8.5, textColor=RED_WARN, fontName='Helvetica-Bold', alignment=TA_CENTER))

    scale_rows = [
        ['5 PGs',   '13 GB',  '30 GB free', '0', scale_cost_color('$0')],
        ['10 PGs',  '26 GB',  '30 GB free', '0', scale_cost_color('$0')],
        ['15 PGs',  '39 GB',  '30 GB free', '9 GB', scale_cost_color('$9/month')],
        ['50 PGs',  '130 GB', '30 GB free', '100 GB', scale_cost_color('$100/month')],
        ['100 PGs', '260 GB', '30 GB free', '230 GB', scale_cost_color('$230/month')],
        ['200 PGs', '520 GB', '30 GB free', '490 GB', scale_cost_color('$490/month')],
    ]
    story.append(make_table(scale_headers, scale_rows, [25*mm, 40*mm, 35*mm, 35*mm, 35*mm]))
    story.append(sp(8))

    # bandwidth chart
    story.append(bandwidth_bar_chart())
    story.append(sp(8))

    story.append(section_header('Phone OTP Costs Scale Linearly'))
    story.append(sp(6))
    otp2_headers = [
        Paragraph('<b>PGs</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>OTPs/Month</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Cost (India)</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
    ]
    otp2_rows = [
        ['10 PGs',  '2,270',  '&#x20B9;750 (~$9)'],
        ['50 PGs',  '11,350', '&#x20B9;3,745 (~$45)'],
        ['100 PGs', '22,700', '&#x20B9;7,490 (~$90)'],
        ['200 PGs', '45,400', '&#x20B9;14,980 (~$180)'],
    ]
    story.append(make_table(otp2_headers, otp2_rows, [40*mm, 65*mm, 65*mm]))
    story.append(sp(8))

    story.append(section_header('Total Firebase Cost Projection (SaaS)'))
    story.append(sp(6))
    proj_headers = [
        Paragraph('<b>Scale</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>DB Bandwidth</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Phone OTPs</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Total/Month</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Per PG</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
    ]
    proj_rows = [
        ['10 PGs',  '$0',    '$9',   '$9/month',   '$0.90'],
        ['50 PGs',  '$70',   '$45',  '$115/month',  '$2.30'],
        ['100 PGs', '$230',  '$90',  '$320/month',  '$3.20'],
        ['200 PGs', '$490',  '$180', '$670/month',  '$3.35'],
    ]
    story.append(make_table(proj_headers, proj_rows, [25*mm, 38*mm, 38*mm, 42*mm, 27*mm]))
    story.append(sp(8))

    story.append(Paragraph(
        '<b>After fixing pagination/no-load-all issues, bandwidth drops ~70%:</b>', BODY_BOLD))
    story.append(sp(4))
    opt_headers = [
        Paragraph('<b>Scale (optimized)</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>DB Bandwidth</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Phone OTPs</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Total/Month</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Per PG</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
    ]
    opt_rows = [
        ['100 PGs', '$70',  '$90',  '$160/month', '$1.60'],
        ['200 PGs', '$150', '$180', '$330/month', '$1.65'],
    ]
    story.append(make_table(opt_headers, opt_rows, [35*mm, 38*mm, 38*mm, 42*mm, 17*mm], header_bg=GREEN_OK))
    story.append(sp(8))

    # Cost comparison chart
    story.append(cost_line_chart())
    story.append(sp(10))

    # ═══════════════════════════════════════════════════════════════════════════
    # PART 6
    # ═══════════════════════════════════════════════════════════════════════════
    story.append(PageBreak())
    story.append(part_header('PART 6: What to Charge Per Bed'))
    story.append(sp(8))

    story.append(section_header('Your Actual Cost Per Bed (200-bed PG at 100-PG scale)'))
    story.append(sp(6))
    story.append(bullet('Firebase cost per PG: <b>~&#x20B9;240–&#x20B9;270/month ($3.20)</b>'))
    story.append(bullet('Cost per bed: <b>&#x20B9;1.2–&#x20B9;1.35/bed/month</b>'))
    story.append(sp(8))

    story.append(section_header('Recommended Pricing Model'))
    story.append(sp(4))
    story.append(Paragraph('Tiered by bed count (monthly subscription):', BODY_STYLE))
    story.append(sp(6))
    tier_headers = [
        Paragraph('<b>Tier</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Beds</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Suggested Price</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Firebase Cost</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
        Paragraph('<b>Margin</b>', S('th', fontSize=9, textColor=WHITE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
    ]
    tier_rows = [
        [Paragraph('<b>Starter</b>', S('tc', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER)), 'Up to 30 beds',
         Paragraph('<b>&#x20B9;499/month</b>', S('tp', fontSize=9, textColor=FIREBASE_ORANGE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
         '&#x20B9;30', Paragraph('<b>94%</b>', S('tm', fontSize=9, textColor=GREEN_OK, fontName='Helvetica-Bold', alignment=TA_CENTER))],
        [Paragraph('<b>Growth</b>', S('tc', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER)), '31–100 beds',
         Paragraph('<b>&#x20B9;999/month</b>', S('tp', fontSize=9, textColor=FIREBASE_ORANGE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
         '&#x20B9;80', Paragraph('<b>92%</b>', S('tm', fontSize=9, textColor=GREEN_OK, fontName='Helvetica-Bold', alignment=TA_CENTER))],
        [Paragraph('<b>Pro</b>', S('tc', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER)), '101–200 beds',
         Paragraph('<b>&#x20B9;1,999/month</b>', S('tp', fontSize=9, textColor=FIREBASE_ORANGE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
         '&#x20B9;200', Paragraph('<b>90%</b>', S('tm', fontSize=9, textColor=GREEN_OK, fontName='Helvetica-Bold', alignment=TA_CENTER))],
        [Paragraph('<b>Enterprise</b>', S('tc', fontSize=9, fontName='Helvetica-Bold', alignment=TA_CENTER)), '200+ beds',
         Paragraph('<b>&#x20B9;3,499/month</b>', S('tp', fontSize=9, textColor=FIREBASE_ORANGE, fontName='Helvetica-Bold', alignment=TA_CENTER)),
         '&#x20B9;350', Paragraph('<b>90%</b>', S('tm', fontSize=9, textColor=GREEN_OK, fontName='Helvetica-Bold', alignment=TA_CENTER))],
    ]
    t_tier = make_table(tier_headers, tier_rows, [28*mm, 33*mm, 43*mm, 35*mm, 31*mm], header_bg=FIREBASE_ORANGE)
    story.append(t_tier)
    story.append(sp(8))

    # Margin chart
    story.append(margin_bar_chart())
    story.append(sp(8))

    story.append(section_header('Alternative: Per-Bed Pricing'))
    story.append(sp(6))
    story.append(bullet('&#x20B9;15–&#x20B9;20/bed/month is very reasonable for the Indian market'))
    story.append(bullet('200 beds × &#x20B9;15 = <b>&#x20B9;3,000/month</b> → Firebase cost &#x20B9;200–&#x20B9;270 → <b>91% margin</b>'))
    story.append(sp(8))

    story.append(section_header('Break-even Analysis'))
    story.append(sp(6))
    story.append(info_box(
        'You break even if you charge more than your Firebase cost. Since Firebase costs '
        '<b>&#x20B9;1–&#x20B9;1.5/bed/month</b>, literally any charge above <b>&#x20B9;2/bed/month</b> '
        'is profitable. Even &#x20B9;5/bed gives you <b>70%+ margin</b>.', GREEN_LIGHT, GREEN_OK))
    story.append(sp(10))

    # ═══════════════════════════════════════════════════════════════════════════
    # PART 7
    # ═══════════════════════════════════════════════════════════════════════════
    story.append(PageBreak())
    story.append(part_header('PART 7: Critical Issues That Will Hurt You at Scale'))
    story.append(sp(8))

    story.append(Paragraph(
        'The codebase analysis found <b>10 inefficiencies</b>. The top 3 that directly affect your Firebase bill:',
        BODY_STYLE))
    story.append(sp(8))

    issues = [
        (
            '1. No Pagination on Payments',
            'HIGH IMPACT',
            RED_WARN, RED_LIGHT,
            [
                '<b>Problem:</b> When viewing "All Months", the app loads every single payment record ever created.',
                '200-bed PG, 2 years old: 4,800 payment records × 2 KB = <b>9.6 MB per "All Months" view</b>',
                '<b>Fix:</b> Add .limitToFirst(50) with pagination — reduces this 95%',
            ]
        ),
        (
            '2. Notifications User States Blow Up',
            'HIGH IMPACT',
            RED_WARN, RED_LIGHT,
            [
                '<b>Problem:</b> Every notification stores a state entry for every user who saw it.',
                '100 notifications × 200 users × 60 bytes = <b>1.2 MB just in read-states</b>',
                'After 1 year: 600 notifications × 200 users = <b>7.2 MB of user-state data</b>',
                'This downloads on <b>EVERY</b> dashboard open',
                '<b>Fix:</b> Move user states to a separate path, lazy-load them',
            ]
        ),
        (
            '3. Full Floor Tree Always Loaded',
            'MEDIUM IMPACT',
            FIREBASE_ORANGE, AMBER_LIGHT,
            [
                '<b>Problem:</b> Every room, every bed, every allocation from the beginning of time loads on dashboard open.',
                'A mature 200-bed PG with 5 allocation records per bed: 200 × 5 × 200 bytes = <b>200 KB just in history</b>',
                'Grows forever',
                '<b>Fix:</b> Truncate allocation history in the tree, archive old records',
            ]
        ),
    ]

    for title, badge, badge_color, bg_color, points in issues:
        badge_p = Paragraph(
            f'<b>{badge}</b>',
            S('badge', fontSize=8, textColor=WHITE, fontName='Helvetica-Bold',
              alignment=TA_CENTER, backColor=badge_color))
        header_row = Table(
            [[Paragraph(title, S('ith', fontSize=10.5, textColor=DARK_BG, fontName='Helvetica-Bold')),
              badge_p]],
            colWidths=[130*mm, 36*mm])
        header_row.setStyle(TableStyle([
            ('BACKGROUND',    (0,0), (-1,-1), bg_color),
            ('TOPPADDING',    (0,0), (-1,-1), 8),
            ('BOTTOMPADDING', (0,0), (-1,-1), 8),
            ('LEFTPADDING',   (0,0), (-1,-1), 10),
            ('RIGHTPADDING',  (0,0), (-1,-1), 8),
            ('BACKGROUND',    (1,0), (1,0), badge_color),
            ('ALIGN',         (1,0), (1,0), 'CENTER'),
            ('VALIGN',        (0,0), (-1,-1), 'MIDDLE'),
        ]))
        story.append(header_row)
        for pt in points:
            body_row = Table(
                [[Paragraph(f'&#x2022; {pt}', S('pb', fontSize=9, fontName='Helvetica', textColor=DARK_GRAY, leading=13, leftIndent=8))]],
                colWidths=[166*mm])
            body_row.setStyle(TableStyle([
                ('BACKGROUND',    (0,0), (-1,-1), WHITE),
                ('TOPPADDING',    (0,0), (-1,-1), 4),
                ('BOTTOMPADDING', (0,0), (-1,-1), 4),
                ('LEFTPADDING',   (0,0), (-1,-1), 14),
                ('RIGHTPADDING',  (0,0), (-1,-1), 10),
                ('LINEAFTER',     (0,0), (0,-1), 3, badge_color),
                ('LINEBEFORE',    (0,0), (0,-1), 3, badge_color),
            ]))
            story.append(body_row)
        story.append(sp(10))

    # ═══════════════════════════════════════════════════════════════════════════
    # FINAL SUMMARY
    # ═══════════════════════════════════════════════════════════════════════════
    story.append(PageBreak())
    story.append(part_header('Summary — Is Firebase Profitable for Your SaaS?'))
    story.append(sp(8))

    qa_data = [
        ('Is storage monthly recurring?', 'Yes, every month'),
        ('Will a 200-bed PG\'s DB data cost you?', 'No — 12 MB after year 1 vs 5 GB free'),
        ('What is the main cost?', 'Phone OTP SMS (~&#x20B9;75–&#x20B9;130/PG/month)'),
        ('Firebase cost per 200-bed PG', '&#x20B9;75–&#x20B9;270/month ($1–$3.25)'),
        ('Recommended charge per bed', '&#x20B9;15–&#x20B9;20/bed/month'),
        ('Margin at &#x20B9;15/bed on 200 beds', '~90%'),
        ('Is it profitable?', 'Extremely — the business model works'),
        ('Main risk', 'DB bandwidth at 50+ PGs if you don\'t fix pagination'),
        ('Priority fix', 'Implement pagination on payments and lazy-load notifications'),
    ]

    qa_rows = []
    for i, (q, a) in enumerate(qa_data):
        bg = DARK_BG if i % 2 == 0 else SECTION_BLUE
        val_color = GREEN_OK if 'Yes' in a or 'Extremely' in a or '90%' in a or '&#x20B9;15' in a else WHITE
        qa_rows.append([
            Paragraph(q, S('qq', fontSize=9.5, fontName='Helvetica-Bold', textColor=FIREBASE_AMBER, leading=14)),
            Paragraph(a, S('qa', fontSize=9.5, fontName='Helvetica', textColor=val_color, leading=14)),
        ])

    qa_table = Table(qa_rows, colWidths=[80*mm, 90*mm])
    style_list = [
        ('TOPPADDING',    (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING',   (0,0), (-1,-1), 12),
        ('RIGHTPADDING',  (0,0), (-1,-1), 12),
        ('VALIGN',        (0,0), (-1,-1), 'MIDDLE'),
        ('GRID',          (0,0), (-1,-1), 0.5, colors.HexColor('#37474F')),
        ('LINEAFTER',     (0,0), (0,-1), 2, FIREBASE_ORANGE),
    ]
    for i in range(len(qa_rows)):
        bg = DARK_BG if i % 2 == 0 else SECTION_BLUE
        style_list.append(('BACKGROUND', (0, i), (-1, i), bg))
    qa_table.setStyle(TableStyle(style_list))
    story.append(qa_table)
    story.append(sp(10))

    # Final verdict box
    verdict_text = (
        'The Firebase cost is <b>tiny</b> compared to what you can charge. Your biggest financial risk is '
        'not Firebase costs — it\'s the <b>bandwidth bill if your app keeps loading all data without '
        'pagination when you reach 15+ PGs</b>. Fix that before you onboard more customers.'
    )
    verdict_table = Table(
        [[Paragraph('&#x26A0; PRIORITY ACTION', S('va', fontSize=10, fontName='Helvetica-Bold',
                                                    textColor=FIREBASE_AMBER, alignment=TA_CENTER))],
         [Paragraph(verdict_text, S('vb', fontSize=10, fontName='Helvetica',
                                     textColor=WHITE, leading=15, alignment=TA_JUSTIFY))]],
        colWidths=[170*mm])
    verdict_table.setStyle(TableStyle([
        ('BACKGROUND',    (0,0), (-1,-1), DARK_BG),
        ('TOPPADDING',    (0,0), (-1,-1), 10),
        ('BOTTOMPADDING', (0,0), (-1,-1), 10),
        ('LEFTPADDING',   (0,0), (-1,-1), 16),
        ('RIGHTPADDING',  (0,0), (-1,-1), 16),
        ('LINEABOVE',     (0,0), (-1,0), 3, FIREBASE_ORANGE),
        ('ROUNDEDCORNERS', [6]),
    ]))
    story.append(verdict_table)

    doc.build(story)
    print(f"PDF saved to {output}")
    return output

build_pdf()