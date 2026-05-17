# Google Stitch UI Prompt — DHAV Customer App
> Copy this entire prompt into Google Stitch to generate the full User-side app UI.

---

## PROMPT START

**Project Name:** DHAV — Hyperlocal Kirana Delivery App (Customer Side)  
**Platform:** Mobile App (Android + iOS)  
**Design Style:** Modern, vibrant, warm, Indian-market friendly. Think Blinkit × Zepto × Swiggy — clean cards, bold typography, smooth micro-animations, glassmorphism accents, warm saffron-orange + deep green color palette with white backgrounds. Rounded corners everywhere. Every screen should feel alive with subtle motion.
** MOST IMPRTANT :** i want morder UI design of this app , with good animation effect and all . 
**Brand Colors:**
- Primary: Deep Saffron Orange `#FF6B2C`
- Secondary: Kirana Green `#2E7D32`
- Accent: Golden Yellow `#FFB703`
- Background: Warm White `#FAFAF8`
- Card Surface: Pure White `#FFFFFF`
- Text Primary: Charcoal `#1A1A1A`
- Text Secondary: Slate `#6B7280`
- Success: Emerald `#10B981`
- Error: Warm Red `#EF4444`

**Typography:**
- Headings: Poppins Bold / Semi-Bold
- Body: Inter Regular / Medium
- Hindi/Marathi accents: Use Noto Sans Devanagari where needed

**Animation Style:**
- Lottie-style micro-animations on all key moments
- Spring physics on button presses (scale down 0.95 on tap)
- Fade + slide-up for screen transitions (300ms ease-out)
- Shimmer skeleton loaders (never plain spinners)
- Confetti burst on order confirmation

---

## SCREEN 1: SPLASH SCREEN

**Layout:**
- Full screen deep saffron-to-orange gradient background (`#FF6B2C` → `#FF8C42`)
- Center: App logo — a stylized shopping bag icon with a map pin inside it, glowing white
- Below logo: App name in bold white Poppins — "DHAV"
- Tagline below in light italic white: *"Apni Dukaan, Apke Darwaze Tak"* (Your Store, At Your Doorstep)
- Small subtitle in English below: *"Hyperlocal Kirana Delivery • Pune"*

**Animation:**
- Logo drops in from top with a bounce spring animation (0 → 100% scale, elastic ease)
- Text fades in 400ms after logo settles
- Background has subtle animated radial glow pulsing outward from center every 2 seconds
- Small floating grocery icons (🥛 🧅 🌾 🫙) drifting upward slowly in background (parallax effect)
- After 2.5 seconds → auto-transitions to Onboarding Screen 1

---

## SCREEN 2: ONBOARDING — SLIDE 1 (Welcome)

**Layout:**
- White background
- Top 60% of screen: Full illustration — A friendly animated kirana store shopkeeper character (South Indian/Maharashtrian look with kurta, smiling, holding a shopping bag) standing in front of a colorful kirana store. Store has grocery items on shelves. Warm, hand-drawn illustration style.
- Illustration character should have a subtle idle animation (slight body sway, blinking eyes)
- Below illustration:
  - Bold heading (28px Poppins): "Your Neighborhood Store, Now On Your Phone"
  - Subtext (16px Inter, grey): "Order from trusted local kirana stores near you. No dark stores. Real people. Real freshness."
- Bottom: Three dot indicators (slide progress) — first dot filled orange
- Large orange CTA button: "Get Started →"
- Skip text link top-right: "Skip"

**Animation:**
- Illustration slides in from right (400ms ease-out)
- Text fades + slides up (500ms delay)
- Button pulses subtly every 3 seconds to draw attention

---

## SCREEN 3: ONBOARDING — SLIDE 2 (How It Works)

**Layout:**
- Soft warm white background with very light orange radial gradient from center
- Top: Animated illustration — A map view showing a customer's home pin, with order rings pulsing outward (like sonar waves) reaching 3 nearby kirana store icons. First store to glow green "wins" the order.
- This animation loops continuously and looks like the order broadcasting system
- Below illustration:
  - Bold heading: "Order Rings to 3 Nearby Stores. Fastest Store Wins!"
  - Subtext: "Your order is broadcast to all kirana stores within 1-2km. The first to accept starts packing. No waiting in queues."
- Three-step mini process shown as horizontal chips:
  - 🛒 Place Order → 📢 Stores Ring → 🛵 Get Delivered
- Bottom: Dot indicators (slide 2 active), "Next →" button, "Skip" link

---

## SCREEN 4: ONBOARDING — SLIDE 3 (Live Tracking)

**Layout:**
- Deep green background `#1B4332` for drama
- Top: Beautiful Google Maps-style animated preview — shows a delivery scooter icon moving along a road toward a house icon, smooth gliding motion. Pin has a pulsing green halo.
- White overlay card at bottom (rounded top corners, large radius):
  - Bold WHITE heading: "Track Every Delivery. Live."
  - White subtext: "Watch your delivery boy move in real-time. Smooth animated tracking, just like Uber — built for your kirana order."
  - Feature chips in white glassmorphism style:
    - 📍 Live GPS Tracking
    - ⏱️ Real-time ETA
    - 📞 Call Delivery Boy
- "Next →" button in orange

---

## SCREEN 5: ONBOARDING — SLIDE 4 (Pay Simple)

**Layout:**
- White background
- Top: Friendly illustration — customer opening door, delivery boy handing over grocery bag, customer paying cash with a smile. Warm, neighborhood feel.
- Below:
  - Bold heading: "Cash on Delivery. Always. Zero Hidden Fees."
  - Subtext: "Pay only for your groceries — directly to the delivery boy. No platform fee, no surge pricing. Ever."
  - Large badge in green: "✅ Cash Only • Transparent • Zero Surprises"
- Bottom: "Let's Begin 🎉" large orange button (full-width rounded)
- Bottom dot indicators (slide 4 active)

**Animation on tapping "Let's Begin":**
- Button does a satisfying press animation + confetti burst from button edges
- Screen transitions with a circular reveal from the button (like Ripple Material effect)

---

## SCREEN 6: LOGIN / SIGN-IN SCREEN

**Layout:**
- Top half: Warm gradient background (light orange fade to white)
- Floating illustration in top area: Small animated grocery bag with tiny sparkles
- Bottom half: White card (rounded top corners, elevated shadow) containing all login options
- Inside card:
  - Bold heading: "Welcome to DHAV"
  - Subtext: "Sign in to order from stores near you"
  - **Google Sign-In Button:** White button, full-width, rounded pill shape. Left: Google "G" colored logo. Center text: "Continue with Google". Subtle shadow on button.
  - Divider: — or —
  - **Email Button:** Outlined orange button, full-width, pill shape. Left: ✉️ icon. Text: "Continue with Email"
  - Bottom: Language selector row — "🌐 English | हिंदी | मराठी" — tap to switch (active language underlined in orange)
  - Very small legal text: "By continuing, you agree to our Terms & Privacy Policy"

**Animation:**
- Card slides up from bottom (spring animation) when screen loads
- Each button has ripple effect on tap
- Language toggle has a smooth slide underline animation

---

## SCREEN 7: EMAIL SIGN-IN SCREEN

**Layout:**
- White background with orange accent elements
- Back arrow top-left
- Heading: "Sign in with Email"
- Subtext: "Enter your details to continue"
- Input Fields (large, rounded, border highlights orange on focus):
  - Email address input — icon: ✉️
  - Password input — icon: 🔒 — eye toggle to show/hide
- "Forgot Password?" link right-aligned below password field (orange)
- "Sign In" button — large, full-width, orange gradient, rounded
- Divider: "Don't have an account?"
- "Create Account" text button in orange

**Animation:**
- Input fields have smooth border animation (grey → orange glow) on focus
- Error states shake the input field (horizontal wiggle animation)
- Loading state: Button text changes to animated dots ". . ."

---

## SCREEN 8: PROFILE SETUP SCREEN (First-time only)

**Layout:**
- Progress indicator top: Step 1 of 2 — "Set up your profile"
- Top: Large circular avatar placeholder with camera icon overlay (tap to upload photo)
- Input fields:
  - Full Name (pre-filled if from Google)
  - Phone number (optional, with +91 prefix chip)
- "Next →" button

**Step 2 — Address Setup:**
- Progress indicator: Step 2 of 2 — "Where should we deliver?"
- Full-screen Google Maps embed (70% of screen height) with a pin marker at center
- Instruction text: "Move the map to pin your location"
- Pin icon stays fixed at center while map moves underneath (Uber-style)
- Bottom card (sliding up from bottom):
  - Area name auto-detected (bold): "Kothrud, Pune"
  - Editable address fields: Flat/Building, Street, Landmark
  - Address label toggle: 🏠 Home | 💼 Work | 📍 Other
  - "Confirm Location ✅" orange button
- Map has subtle map animation (faint pulse on the pin) when user stops dragging

---

## SCREEN 9: HOME SCREEN (Main Screen) ⭐ HERO SCREEN

**Layout — Top Bar:**
- Left: Orange pin icon + "Delivering to:" label + bold area name "Kothrud, Pune ▾" (tappable to change)
- Right: Bell icon (notification badge if unread) + small circular profile photo

**Location Loading State:**
- When app first opens, show subtle pulsing skeleton where the area name is
- Text animation: "Finding your location… 📍" (typewriter effect)
- Once resolved: Area name pops in with a spring bounce

**Search Bar (below top bar):**
- Full-width, rounded white search bar with orange left accent border
- Placeholder: "Search dal, rice, oil, soap…"
- Right: 🎤 mic icon (voice search)
- Tapping opens Search Screen

**Active Order Banner (if order in progress):**
- Sticky floating banner just above bottom nav bar
- Orange gradient card, rounded, with pulsing green dot
- Text: "Order in progress • Track Now 🛵"
- Tapping opens Order Tracking Screen

**Category Chips Row (horizontal scroll):**
- Emojis + labels in rounded pill chips (white background, orange border on selected):
  - 🌾 Grains | 🫙 Oil & Ghee | 🥛 Dairy | 🍿 Snacks | 🧴 Personal Care | 🧹 Cleaning | 👶 Baby Care | 📦 Other
- Active chip: Orange background, white text
- Chips smoothly scroll horizontally with momentum

**Featured Items Grid (2 columns):**
- Section heading: "Popular Near You" with "See All →" right link
- Each item card:
  - Rounded white card with subtle shadow
  - Item image (square, rounded corners)
  - Item name (bold, 14px)
  - Category tag (small green pill)
  - "Add +" button — small orange pill button bottom-right of card
  - Tapping "Add" animates item flying to cart icon (arc animation like food delivery apps)

**Recently Ordered Section:**
- Section heading: "Order Again" (only visible if returning user)
- Horizontal scroll of past items with "Reorder" chips

**Bottom Navigation Bar:**
- 4 tabs: 🏠 Home | 🔍 Search | 📦 Orders | 👤 Profile
- Active tab: Orange icon + label + underline indicator (animated slide)
- Bar has white background, subtle top shadow

**Home Screen Micro-Animations:**
- Lottie grocery store animation plays once on first open (1.5 sec, top area)
- Item cards have shimmer loading state (skeleton)
- Pull-to-refresh shows spinning grocery bag animation

---

## SCREEN 10: SEARCH & BROWSE SCREEN

**Layout:**
- White background
- Top: Back arrow + Search input (active, focused state, orange border glow)
- Below search: Category filter chips (horizontal scroll)
- Search Results List:
  - Each item: image left, name + category right, "Add to Cart" orange pill button far right
  - Greyed-out items with lock icon: "Not available near you"
  - Item count badge: "3 stores have this"
- Empty state: Animated illustration — empty shelves, text "Nothing found. Try a different name!"

---

## SCREEN 11: CART SCREEN

**Layout:**
- White background
- Top bar: "My Cart 🛒" + item count badge
- Cart Items List:
  - Each item: image, name, quantity stepper (− qty +), subtotal
  - Swipe left on item to delete (with red delete reveal)
- Delivery Address Section:
  - Card showing current address with "Change" link
  - Small static map thumbnail showing the address pin
- Order Summary Card:
  - Items Total: ₹XXX
  - Delivery: Free (from store's delivery boy)
  - Total: ₹XXX (bold)
  - Small note in grey: "Cash on Delivery only"
- Large CTA Button (orange, full-width): "Place Order →"
- Below button: small text "Your order will ring to nearby kirana stores"

**Empty Cart State:**
- Large Lottie animation — empty shopping bag swinging
- Text: "Your cart is empty" + "Start Shopping" button

---

## SCREEN 12: ORDER BROADCASTING SCREEN ⭐ ANIMATED HERO

**Layout:**
- FULL SCREEN dark-to-deep-navy background gradient
- CENTER: Google Maps satellite/hybrid view showing customer location
- On top of map: Customer location pin (pulsing orange halo)
- 3 concentric animated rings expanding outward from customer pin (like radar/sonar):
  - Ring 1: Orange, 1km radius
  - Ring 2: Yellow, 2km radius  
  - Ring 3: White translucent, 3km radius
  - Rings animate with a smooth pulse outward, fading as they expand, looping continuously
- Small store icons appear/glow as the rings hit them (stores being notified)
- Bottom overlay card (glassmorphism white blur card):
  - Heading: "Finding your kirana store…"
  - Subtext: "Checking 3 stores near you"
  - Animated status text: "Wave 1 — within 1km" → "Wave 2 — within 2km" (updates live)
  - Loading indicator: Pulsing orange dots
  - Cancel Order link (small, red)

**If order accepted:**
- All rings shrink back to source
- One store icon glows bright green with checkmark
- Screen transitions with a celebration animation (confetti + green flash)
- Transition to Order Accepted Screen

**If no stores found:**
- Rings fade to grey
- Sad animation plays
- Message: "No stores available right now 😔"
- Retry button

---

## SCREEN 13: ORDER ACCEPTED SCREEN

**Layout:**
- White background
- Top: Big checkmark Lottie animation (green circle with white checkmark drawing in) — very satisfying
- Store card (elevated, rounded):
  - Store photo (circular)
  - Store name (bold 20px)
  - Distance chip: "📍 0.8 km away"
  - Owner name: "By Ramesh Kirana"
  - Star rating
- Items List with confirmed prices (now shown by store)
- Estimated time: Large bold "~35 minutes" with clock icon
- Note: "If prices seem wrong, you can cancel for free" (small grey text)
- "Track Order →" orange button
- Share ETA button (optional)

---

## SCREEN 14: ORDER TRACKING SCREEN ⭐ MOST CRITICAL

**Layout — Top Half: Status Timeline**
- White background
- Top bar: "Order #KM1234" + "Need Help?" link
- Vertical timeline with 5 steps:
  1. ✅ Order Placed — "Your order was placed" (timestamp)
  2. ✅ Store Accepted — "Ramesh Kirana is preparing your order"
  3. ⏳ Being Packed — (currently active, animated pulsing orange dot)
  4. ⬜ Out for Delivery — locked
  5. ⬜ Delivered — locked
- Active step has pulsing orange indicator dot (Lottie animation)
- Completed steps have green checkmarks with slide-in animation

**Layout — Bottom Half: Live Map (appears when Out for Delivery)**
- Google Maps embedded view
- Two pins:
  - 🛵 Delivery boy pin: Custom scooter icon, SMOOTHLY ANIMATED (glides between GPS updates using tween animation — NO sudden jumps). Pin has subtle shadow.
  - 🏠 Customer pin: Home icon with pulsing green ring
- Route line drawn between the two pins (polyline)
- ETA chip floating on map: "🕐 Arriving in ~8 min"

**Below Map:**
- Delivery boy card:
  - Small circular photo of delivery boy
  - Name: "Raju Patil"
  - Phone icon → tap to call (opens dialer)
  - Message icon (optional)
- "I have a problem" link in grey

**Map Animation Details:**
- When delivery boy pin updates (every 3 seconds), it smoothly glides to new position (2 second tween animation)
- The route line updates dynamically
- ETA recalculates and updates with fade transition

---

## SCREEN 15: ORDER DELIVERED SCREEN

**Layout:**
- Full-screen white
- Center: Large Lottie celebration animation — ✅ delivery checkmark + fireworks/confetti burst
- "Order Delivered! 🎉" (bold 28px)
- "Paid: ₹XXX cash to delivery boy"
- Order summary card (collapsible)
- "Rate this delivery" — 5 star selector (animated stars glow gold on tap)
- "Order Again" orange button
- "Back to Home" ghost button

---

## SCREEN 16: ORDER HISTORY SCREEN

**Layout:**
- White background
- Top: "My Orders" heading
- Filter tabs: All | Active | Delivered | Cancelled
- Order Cards (list):
  - Store name + photo
  - Order date + time
  - Items count: "3 items"
  - Total: ₹XXX
  - Status badge: green "Delivered" / orange "In Progress" / red "Failed"
  - "Reorder" orange chip button (right side)
- Empty state: Animated empty box Lottie + "No orders yet. Start ordering! 🛒"

---

## SCREEN 17: PROFILE SCREEN

**Layout:**
- Soft orange-to-white gradient header (top 30%)
- Header: Large circular profile photo + name (bold white) + email (light white)
- Below header (white card area), list items with icons:
  - 📍 Saved Addresses
  - 🌐 Language (English / हिंदी / मराठी)
  - 🔔 Notifications
  - ❓ Help & Support
  - 📄 Terms & Privacy
  - 🚪 Logout (red text)
- Each row: left icon in orange circle, label, right arrow
- Tapping Logout → confirmation bottom sheet

---

## SCREEN 18: NOTIFICATIONS SCREEN

**Layout:**
- White background
- "Notifications" heading
- Grouped list (Today / Yesterday / Earlier):
  - Each notification: left colored dot (green = delivered, orange = in progress), notification text, timestamp
  - Unread notifications have light orange background highlight
  - Swipe left to dismiss
- Empty state: Bell illustration with "No notifications yet"

---

## DESIGN SYSTEM NOTES FOR STITCH

**Buttons:**
- Primary: Orange gradient (`#FF6B2C → #FF8C42`), rounded 50px, white bold text, subtle drop shadow
- Secondary: White with orange border, orange text
- Destructive: Red `#EF4444`
- All buttons: scale to 0.95 on press (spring physics)

**Cards:**
- White background, 16px border radius, shadow: `0 2px 16px rgba(0,0,0,0.08)`
- Hover/press: shadow deepens slightly

**Input Fields:**
- Grey border default → orange glow on focus
- 12px border radius, 16px padding
- Icon left + clear (x) button right

**Loading States:**
- Use shimmer skeleton, never plain spinner
- Shimmer: light grey → lighter grey → light grey animation sweeping left to right

**Error States:**
- Input shakes horizontally (wiggle animation)
- Red border + red text below
- Toast notification slides in from bottom (red, white text)

**Empty States:**
- Always use a friendly Lottie/illustration (no plain "No data found" text)
- Include a CTA button to take action

**Micro-interactions to include on every screen:**
- Button press: spring scale down + up
- List item tap: brief highlight flash
- Swipe actions: smooth reveal with haptic feedback indicator
- Navigation transitions: slide-left / slide-right based on direction

---

**TOTAL SCREENS TO GENERATE: 18 screens as listed above. Generate each screen with the full mobile UI layout (375px width, full height). Apply all animations, color palette, and typography system consistently across all screens.**

## PROMPT END
