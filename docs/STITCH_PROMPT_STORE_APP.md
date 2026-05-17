# Google Stitch UI Prompt — DHAV Store & Delivery Boy App
> Copy this entire prompt into Google Stitch to generate the full Store-side app UI (used by Store Owners AND Delivery Boys — same app, role-based views).

---

## PROMPT START

**Project Name:** DHAV — Hyperlocal Kirana Delivery App (Store Owner + Delivery Boy Side)  
**Platform:** Mobile App (Android + iOS)  
**Design Style:** Professional, high-trust, action-driven. The store owner needs FAST access to order actions — no clutter. Bold UI, high-contrast buttons, military precision in layouts. Think a Bloomberg Terminal meets a hyperlocal dukaan — serious, efficient, warm. Dark navy + emerald green + saffron orange palette. Bold readable typography because shopkeepers often use phones quickly in a busy store environment.

**Brand Colors:**
- Primary: Deep Saffron Orange `#FF6B2C`
- Secondary: Kirana Green `#2E7D32`
- Accent: Emerald Active `#10B981`
- Background: Off-White `#F5F5F0`
- Card Surface: Pure White `#FFFFFF`
- Dark Surface: Navy `#1A2332`
- Text Primary: Charcoal `#1A1A1A`
- Text Secondary: Slate `#6B7280`
- Warning: Amber `#F59E0B`
- Error: Red `#EF4444`
- Success: Green `#10B981`

**Typography:**
- Headings: Poppins Bold (larger than usual — shopkeepers need big, readable UI)
- Body: Inter Medium (clear, no serif)
- Numbers/Stats: DM Mono or Inter Bold (crisp financial figures)
- Minimum font size: 15px everywhere (readability in bright store lighting)

**Animation Style:**
- Snappy and functional (no fluff — store owners need speed)
- Order alerts: URGENT pulsing red/orange animations
- Countdown timers: real-time, high-contrast, animated progress bars
- Success actions: satisfying checkmark animations
- Toggle switches: smooth, oversized (easy to tap with busy hands)

---

## SCREEN 1: SPLASH SCREEN (Store App)

**Layout:**
- Full screen dark navy background (`#1A2332`)
- Center: Same DHAV logo (shopping bag + map pin) in orange glow
- Below: "DHAV" in bold white Poppins
- Smaller tagline: "Store Partner App"
- Bottom: Small text "For Store Owners & Delivery Partners"

**Animation:**
- Logo appears with a subtle pulse glow (orange halo expanding and contracting)
- Text slides up from below (600ms ease-out)
- Background has very faint animated grid pattern (like a dark dashboard)
- Transitions to Welcome Screen after 2 seconds

---

## SCREEN 2: WELCOME / LOGIN SELECTION

**Layout:**
- Dark navy top (40% of screen) with DHAV logo + "Partner App" label
- White bottom card (rounded top corners):
  - Bold heading: "Welcome, Partner"
  - Subtext: "Login to manage your store or deliveries"
  - **Google Sign-In Button** — large, full-width, white card button with Google G logo + "Continue with Google"
  - Divider: — or —
  - **Email Login** — outlined button
  - Bottom note: "New store? Contact DHAV to onboard your store."
  - Support number chip: "📞 Call DHAV Support"

**Animation:**
- White card slides up with spring animation on load
- Logo has a breathing pulse animation in the dark area

---

## SCREEN 3: STORE OWNER — DASHBOARD (Home Screen) ⭐ MOST USED SCREEN

**Layout — Top Section:**
- Dark navy header bar
- Left: DHAV logo (small) + "Good Morning, Ramesh 👋" 
- Right: Bell icon (order notification badge, pulsing red if unread) + Profile photo

**BIG OPEN/CLOSED TOGGLE — Hero element:**
- Centered below header, full-width card
- Card background: GREEN when OPEN (`#2E7D32`), DARK RED when CLOSED (`#7F1D1D`)
- Left: Large animated icon — green shop illustration when open, sleeping shop when closed
- Center: Large text "OPEN" or "CLOSED" (32px Bold)
- Right: Giant toggle switch (oversized, pill-shaped, satisfying animation)
- When toggling CLOSED: confirmation bottom sheet appears ("Are you sure? Orders will stop coming.")
- Toggle animation: smooth slide with haptic feedback simulation

**Today's Stats Row (3 cards below toggle):**
- Card 1 (orange): "Today's Orders" — big number (e.g., "12") with upward arrow trend
- Card 2 (green): "Delivered" — number with checkmark
- Card 3 (blue): "Today's Earnings" — "₹1,240" with money icon
- Cards have subtle number count-up animation on load

**Active Order Card (if order in progress):**
- Pulsing orange border card
- Bold: "1 Active Order 🔥"
- Customer name, items count, status (Being Packed / Dispatched)
- "Manage Order →" button
- This card has a gentle continuous pulse animation to stay visible

**Recent Orders List:**
- Section heading: "Recent Orders"
- Each order row: Order ID | Time | Amount | Status badge
- Status badges: green "Delivered" / orange "In Progress" / red "Failed"
- Tap order → opens Order Detail Screen

**Bottom Navigation:**
- 5 tabs: 🏠 Home | 📦 Orders | 📋 Inventory | 💰 Earnings | 👤 Profile
- Active tab: Orange icon + orange underline indicator

---

## SCREEN 4: INCOMING ORDER POPUP — LAYER 1 (CRITICAL ALERT) ⭐ MOST IMPORTANT

**This is a FULL-SCREEN OVERLAY that appears ON TOP of any screen the store owner is on. It's like an incoming phone call UI.**

**Layout — Full Screen:**
- Background: Urgent dark overlay (semi-transparent dark behind the popup)
- Center: Large alert card (white, rounded corners, elevated shadow)

**Alert Card Contents:**
- TOP STRIP: Flashing orange-red gradient strip with "🔔 NEW ORDER REQUEST" in white bold caps
- Subtext: "Tap ACCEPT before the timer runs out!"

**Order Summary:**
- 📦 Items count: "3 items" (large, bold)
- 📍 Distance: "Customer 0.8 km away" (with small static map thumbnail)
- 💵 "Cash on Delivery" badge (green pill)
- 🕐 Wave indicator: "Wave 1 of 3 — Within 1km" (small info chip)

**Countdown Bar:**
- Full-width animated progress bar
- Orange/red gradient — depletes from right to left as time decreases
- Large countdown number: "38 sec" (ticking down in real time, number turns red below 15 seconds)
- Bar has subtle pulse animation when below 15 seconds

**Action Buttons:**
- ACCEPT button (left, 50% width): LARGE, emerald green, "✅ QUICK ACCEPT" — bold white text. This is the star button — extra large, impossible to miss.
- VIEW DETAILS button (right, 50% width): Orange outlined, "📋 View Details"
- REJECT (full width below, smaller): Red outlined text button "❌ Reject this Order"

**Audio/Vibration Indicators (visual metaphor):**
- Animated sound wave icon near the top (shows the alarm is ringing)
- Subtle shake animation on the card edges (every 2 seconds)

**Animation:**
- Alert card crashes in from top with a bounce animation (like a falling object)
- Countdown bar depletes smoothly in real time
- When time < 15 sec: card border flashes red
- When order expires: card shakes, fades out, "Order Taken by Another Store" message appears briefly

---

## SCREEN 5: INCOMING ORDER — LAYER 2 DETAIL SHEET

**This is a BOTTOM SHEET that slides up while the countdown continues at the top.**

**Layout:**
- Handle bar at top
- Persistent mini countdown strip at very top of sheet (timer never hides): "⏱️ 31 sec" with shrinking red bar
- Section: "ORDER ITEMS"
  - Each item row:
    - ✅ Green tick if store has it in inventory: "Tata Salt 1kg — You have this"
    - ⚠️ Yellow warning if uncertain: "Horlicks 200g — Check your stock"
    - Quantity shown clearly
  - Items list in clean rows with dividers
- Section: "DELIVERY DETAILS"
  - 📍 Address: "Flat 4B, Shivaji Nagar, Kothrud"
  - 📏 Distance: "0.8 km from your store"
  - Small static Google Maps thumbnail of customer location
- Section: "PAYMENT"
  - "Cash on Delivery"
  - "Estimated Product Value: ~₹XXX"
- Bottom (sticky): Two action buttons
  - Full-width green "✅ ACCEPT ORDER" button
  - Full-width red outlined "❌ Reject Order" button
- "Can you deliver in 45 minutes?" confirmation appears on tapping Accept (Yes/No choice)

**Animation:**
- Sheet slides up with spring animation
- Items list animates in staggered (each row fades in 50ms after previous)
- Countdown bar at top continues ticking (NEVER pauses)

---

## SCREEN 6: ACTIVE ORDER MANAGEMENT SCREEN ⭐

**Layout:**
- White background
- Top bar: "Order #KM1234 • Active" + back arrow + "Report Problem" link (top right, red)
- Customer Info Card:
  - Name, address, distance, items count
  - Orange "Active" badge with pulsing dot

**Step-by-Step Progress (vertical stepper):**
Step 1 — ASSIGN DELIVERY BOY:
  - Section header: "Step 1: Assign Delivery Boy 🛵"
  - Dropdown/picker: Shows list of this store's registered delivery boys
    - Each entry: Photo thumbnail, name, status (🟢 Available / 🔴 On Delivery)
  - "Add One-Time Delivery Boy" option (enter name + phone manually)
  - "Assign →" orange button
  - Status: ⏳ Pending / ✅ Assigned

Step 2 — MARK PACKED:
  - Greyed out until Step 1 complete
  - When active: Large green "✅ Order is Packed" button
  - This notifies the customer

Step 3 — CONFIRM DISPATCH:
  - "🛵 Delivery Boy Dispatched" button (emerald green, full-width)
  - Note: "This starts live tracking for the customer"
  - This opens WebSocket channel (shown as a subtle "🔴 Live Tracking Active" indicator)

Step 4 — MARK DELIVERED:
  - "🏠 Order Delivered" button (green)
  - Confirmation dialog: "Confirm delivery — this closes the order and charges ₹15 platform fee"

**Completed steps:** Show with green checkmark + timestamp
**Active step:** Pulsing orange indicator + highlighted border

---

## SCREEN 7: ORDER LIST SCREEN

**Layout:**
- White background
- Top: "All Orders" heading + filter row
- Filter tabs: All | Active | Today | This Week
- Order cards:
  - Bold order ID
  - Customer address (truncated)
  - Items summary
  - Time elapsed since order
  - Status badge (color-coded)
  - Right chevron to open detail

---

## SCREEN 8: ORDER DETAIL SCREEN (Past Orders)

**Layout:**
- White background
- Order ID + timestamp at top
- Timeline showing all steps completed with timestamps
- Items list
- Store's delivery boy who did the delivery
- Payment: Cash collected ₹XXX
- Platform fee note: ₹15 charged for this order
- Status: Delivered / Failed

---

## SCREEN 9: INVENTORY MANAGEMENT SCREEN

**Layout:**
- White background
- Top: Search bar (search catalog items) + category filter chips
- Section: "My Inventory" — toggle what's in stock

**Catalog Items List:**
- Each item row:
  - Left: Item image (small square)
  - Center: Item name (bold) + category badge
  - Right: Large toggle switch — ON (green) = "I have this" / OFF (grey) = "Out of stock"
  - Toggle is oversized (44px height) — easy to tap quickly in store environment
- Alphabetically grouped or by category
- Sticky category headers

**Custom Items Section:**
- Section header: "My Store's Custom Items"
- "Add Custom Item +" button (orange, pill shape)
- Each custom item card:
  - Image thumbnail
  - Name, price, unit
  - Edit icon ✏️ | Delete icon 🗑️ | Active toggle
- Add Custom Item Modal:
  - Name input
  - Price input (with ₹ prefix)
  - Unit selector (kg / litre / piece / packet)
  - Upload photo button
  - "Save Item" button

**Animation:**
- Toggle switches have smooth slide animation with color transition
- Adding custom item: modal slides up from bottom
- Deleting: swipe left to reveal red delete action

---

## SCREEN 10: EARNINGS & SETTLEMENT SCREEN ⭐

**Layout — Header Card (dark navy):**
- "This Week's Earnings" label (white text)
- Large bold number: "₹4,250" (white, 36px)
- "Orders Delivered: 12" subtitle

**Breakdown Cards (white, stacked):**
- Card 1: "Gross Earnings (Cash Collected)" — ₹X (green)
- Card 2: "Platform Fee Owed" — ₹15 × 12 = ₹180 (orange/amber)
- Card 3: "Your Net Earnings" — ₹X (bold green)
- Divider
- **Settlement Status Card:**
  - Status badge: ✅ SETTLED (green) / ⏳ DUE BY SUNDAY (amber) / ⚠️ OVERDUE (red flashing)
  - If overdue: pulsing red warning border on the card + warning text "Your store is hidden from customers until payment"
  - "Pay DHAV" button → shows UPI ID + QR code bottom sheet

**Weekly History Section:**
- "Past Settlements" heading
- List of past weeks: Week dates | Orders | Fee Owed | Status badge
- Tap to expand each week's detail

**Pay Bottom Sheet (when tapping Pay DHAV):**
- DHAV's UPI ID displayed prominently
- Amount due highlighted in bold
- QR code for scanning
- "I've Made the Payment" button (generates a payment confirmation for admin review)

**Animation:**
- Numbers count up from 0 to their value on screen load (satisfying)
- Settlement status card: green sparkle animation when settled, red pulse when overdue

---

## SCREEN 11: STORE PROFILE SCREEN

**Layout:**
- Top header (dark navy): Store photo + Shop name + "Active" green badge
- White content area:
  - Shop Details section:
    - Store name (editable), phone, email
    - Operating hours (open/close time pickers)
    - Address
    - "Edit Profile" button
  - Account Status section:
    - "Store Status: Active ✅" or "Suspended ⚠️" with reason
    - Strike Counter: "⚠️ Strikes: 1 / 3" with visual gauge bar
      - 0 strikes: all green
      - 1 strike: one segment red, warning text
      - 2 strikes: warning banner
      - 3 strikes = 7-day suspension warning shown
  - "Manage Delivery Boys" row → navigates to Delivery Boy Management Screen
  - "Help & Support" row
  - "Logout" row (red)

---

## SCREEN 12: DELIVERY BOY MANAGEMENT SCREEN (Store Owner only)

**Layout:**
- White background
- Top: "My Delivery Team" heading + "Add Delivery Boy +" orange button (top right)
- Delivery Boys List:
  - Each card: circular photo, name (bold), phone, status badge
    - 🟢 Available
    - 🔴 On Delivery — "Delivering Order #KM1234"
    - ⚫ Offline
  - Tap on card → see full profile + delivery history count
  - Remove button (red, with confirmation)

**Add Delivery Boy Bottom Sheet:**
- Heading: "Add Delivery Boy"
- Fields: Name | Phone | Google Account Email (this is how they'll login)
- "Add to My Team" button
- Info note: "They'll receive a link to download the app and login"

**Empty State:**
- Illustration of lonely scooter
- "No delivery boys added yet"
- "Add your first delivery boy" CTA

---

## SCREEN 13: ORDER ALERT NOTIFICATION SCREEN (Missed Order)

**Layout:**
- Full white background
- Top: Warning icon (amber) + heading "You Missed an Order ⚠️"
- Order detail summary card (greyed out, crossed out slightly)
- Message: "This order was taken by another store. You missed it!"
- Strike Warning (if applicable):
  - Red bordered card: "⚠️ Warning: Missing orders repeatedly can result in suspension"
  - Strike count update shown
- Button: "Go to Dashboard" orange
- Secondary: "View My Strike History" text link

---

## DELIVERY BOY VIEW (Role-Based — Completely Different UI) ⭐

**When a delivery boy logs in, the app detects role = delivery_boy and shows these screens instead:**

---

## SCREEN 14: DELIVERY BOY — HOME SCREEN

**Layout:**
- Dark navy header
- "DHAV Delivery" label
- "Hi, Raju 👋" greeting with delivery boy profile photo
- Center card: Large STATUS TOGGLE
  - 🟢 AVAILABLE (green background card) — actively receiving assignments
  - ⚫ OFFLINE (dark grey card) — not receiving
  - Oversized toggle, easy to flip
- Today's Stats Row:
  - "Deliveries Today: 4"
  - "Earnings Today: ₹XXX" (delivery boy's payment if applicable)
- "No Active Delivery" empty state card (when no delivery assigned)
  - Illustration: delivery boy relaxing on scooter
  - "Waiting for your next delivery…" text with subtle animation
- Bottom nav (simplified): 🏠 Home | 📦 History | 👤 Profile

---

## SCREEN 15: DELIVERY BOY — INCOMING ASSIGNMENT POPUP ⭐

**Full-screen urgent overlay (similar to store owner order popup but from delivery boy perspective):**

- "🚨 NEW DELIVERY ASSIGNED" — large flashing amber header
- Order Details:
  - Store name: "Pick up from Ramesh Kirana"
  - Store address + distance from delivery boy's current location
  - Customer name + delivery address + distance
  - Items count
- Action Buttons:
  - "✅ I'm Ready — Start Delivery" (large green, full width)
  - "❌ I Can't Deliver This" (small red outlined)
- Countdown: "Accept in 30 seconds" with timer bar

---

## SCREEN 16: DELIVERY BOY — ACTIVE DELIVERY SCREEN ⭐ MOST USED

**Layout:**
- Top status bar: "🔴 Live Delivery Active — GPS Streaming" (small red indicator dot pulsing = GPS active)

**Two-Phase View:**

**Phase 1 — Go to Store (Pickup)**
- Google Maps view (60% of screen) showing route from delivery boy → store
- Store details card (bottom 40%):
  - Store name, address, owner phone (tap to call)
  - "Navigate to Store 🗺️" button → launches Google Maps navigation app
  - Items to pick up (list)
  - "✅ I've Picked Up the Order" button (prominent, green)

**Phase 2 — Deliver to Customer (after pickup marked)**
- Map updates: route from current location → customer address
- Customer details card:
  - Customer name (first name only for privacy)
  - Delivery address (full)
  - "Navigate to Customer 🗺️" button → Google Maps
  - Tap to call customer button
  - "✅ Order Delivered" button (large green, full-width)

**GPS Streaming Indicator:**
- Small persistent chip at top of screen: "📡 GPS Active • Customer is tracking you"
- This reassures delivery boy that tracking is working

**Animation:**
- Map marker for delivery boy moves in real time on the map
- Route line shown (Google Maps navigation)
- Phase transition (store pickup → customer delivery) has a smooth animated state change

---

## SCREEN 17: DELIVERY BOY — ORDER COMPLETED SCREEN

**Layout:**
- White background
- Large green checkmark Lottie animation (satisfying)
- "Delivery Complete! ✅"
- Order summary: Store | Customer | Items | Cash collected
- Earnings for this delivery: "₹XX earned"
- "Back to Home" button

---

## SCREEN 18: DELIVERY BOY — HISTORY SCREEN

**Layout:**
- "My Deliveries" heading
- Filter: Today | This Week | All Time
- List of deliveries (compact rows):
  - Date + time | Store → Customer | Distance | Status
  - Earnings per delivery (if applicable)
- Total earnings summary at top

---

## SCREEN 19: DELIVERY BOY — PROFILE SCREEN

**Layout:**
- Top: Circular profile photo + name + assigned store ("Works at: Ramesh Kirana")
- Details: Phone, Google email (non-editable — set by store owner)
- Store Contact: "My Store: Ramesh Kirana — 📞 Call Owner"
- Stats: Total deliveries | Active since date
- Help & Support
- Logout

---

## SCREEN 20: SETTLEMENT OVERDUE ALERT SCREEN (Store Owner — Critical)

**Layout:**
- FULL SCREEN urgent design — dark amber/red background
- Top: Warning icon with pulsing red animation
- Bold heading: "⚠️ Settlement Overdue"
- Message: "You owe ₹180 in platform fees for last week. Your store is currently HIDDEN from customers. Pay now to resume orders."
- Amount owed: Large bold "₹180" (white text)
- Deadline shown: "Due: Last Sunday"
- Two buttons:
  - "Pay Now →" (full-width, white background, orange text — urgent CTA)
  - "Contact Support" (outlined white button)
- Note: "Your store will be re-activated within 5 minutes of payment confirmation"

---

## SCREEN 21: STORE SUSPENSION SCREEN

**Layout:**
- Full screen dark navy background
- Sad shop illustration (store with shutters down, dark)
- Bold white text: "Your Store is Suspended"
- Reason shown (e.g., "3 failed orders in a week")
- Suspension end date: "Until: 23 May 2026"
- Strike history shown briefly
- "Contact DHAV Support" button
- Support phone + WhatsApp button

---

## DESIGN SYSTEM NOTES FOR STORE APP

**Key Design Principles:**
1. SPEED — Store owners use this in a rush. Big buttons. Clear hierarchy.
2. READABILITY — Many store owners are in bright-lit shops. High contrast text.
3. ONE ACTION PER SCREEN — Never confuse with too many options.
4. TRUST — Green = safe/active, Orange = action needed, Red = urgent/problem

**Buttons:**
- Accept/Confirm: Large emerald green, minimum 56px height, full-width where possible
- Primary Action: Orange gradient, bold white text
- Reject/Danger: Red border, red text (NOT full red fill — avoid accidental taps)
- All buttons: scale 0.95 on press, haptic-like animation

**Status Badges:**
- OPEN: Bright green pill with pulsing dot
- CLOSED: Dark red pill
- ACTIVE order: Orange pulsing badge
- DELIVERED: Green static badge
- FAILED: Red badge
- OVERDUE: Amber/red flashing

**The Countdown Timer (used in multiple screens):**
- Show as a progress bar + large number
- Bar color: green → orange → red as time decreases
- Number: white on colored background, large (28px minimum)
- Shake animation when < 10 seconds

**Incoming Order Alert (Screen 4):**
- This is the most critical UI in the entire app
- Must look like an emergency notification
- Must work when app is backgrounded (system notification UI)
- Countdown must be visible at a glance from 2 feet away

**Maps Integration:**
- Show Google Maps embedded in all tracking/delivery screens
- Store location + Customer location always visible simultaneously
- Route line (polyline) between relevant points
- Navigation button always visible to launch external Google Maps

---

**TOTAL SCREENS TO GENERATE: 21 screens as listed above. Generate with a consistent design system. Store Owner screens use the full nav bar. Delivery Boy screens have a simplified nav. Apply all animations and interactive states. Use the dark navy + orange + green palette throughout. All screen widths: 375px mobile. Focus on bold, readable, action-oriented UI.**

## PROMPT END
