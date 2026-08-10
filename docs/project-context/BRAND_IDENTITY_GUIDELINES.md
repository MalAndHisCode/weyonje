# Weyonje Brand Identity Guidelines

## 1. Purpose and Status

This document defines how the Weyonje identity should be applied across the Flutter mobile application and React-based KCCA and Call Centre web portal. It translates the supplied logo into practical interface guidance while preserving a clear boundary between source evidence, approved implementation constraints, mandatory coding-agent rules, and complementary design recommendations.

These guidelines do not replace formal brand approval by KCCA or the logo owner. The supplied raster logo is the visual authority for the current work. `TECHNOLOGY_STACK.md` is authoritative for selected interface and mapping technologies, while `AI_CODING_AGENT_RULES.md` governs how those technologies and these guidelines are implemented. Recommended colours, typography, component rules, and design tokens should be reviewed and approved before they are treated as official brand standards.

### Evidence labels

The following labels are used throughout:

- **Observed** — directly visible or measurable in the supplied Weyonje logo.
- **Stack-confirmed** — explicitly established by `TECHNOLOGY_STACK.md`.
- **Agent-rule-confirmed** — an implementation constraint explicitly required by `AI_CODING_AGENT_RULES.md`.
- **Recommended** — a complementary rule introduced to make the identity usable, consistent, accessible, and maintainable. It is not an established property of the original logo.
- **Pending approval** — a decision or asset that requires confirmation from KCCA or the logo owner.

When a rule marked **Recommended** is approved, record the approval in the appropriate decision or design documentation. Record it in `CURRENT_SYSTEM_STATE.md` only after it is implemented and verified. Do not silently relabel an inference as an original brand fact or describe a recommendation as implemented.

If these guidelines conflict with the approved technology stack, coding-agent rules, an architecture decision, or verified current implementation, stop and surface the conflict. Do not resolve it silently through interface code.

## 2. Source Materials and Scope

### Supplied logo

**Observed:** The source is a transparent PNG measuring `554 × 554 px`. The visible artwork occupies approximately `472 × 148 px`, giving the artwork an approximate visible aspect ratio of `3.19:1`. The square file contains substantial transparent space above and below the artwork.

The supplied PNG is suitable as a visual reference and for limited digital use at an appropriate size. It is not an ideal production master because it is raster-based, has excess transparent padding, and cannot be enlarged indefinitely without loss of quality.

### Relevant implementation stack

The following interface technologies are confirmed in `TECHNOLOGY_STACK.md` and constrain these guidelines:

- **Stack-confirmed — Mobile:** Flutter with the Forui component and design system.
- **Stack-confirmed — Web:** React, TypeScript, Vite, Tailwind CSS, shadcn/ui, and Radix UI primitives.
- **Stack-confirmed — Mobile maps:** Google Maps for Flutter (`google_maps_flutter`).
- **Stack-confirmed — Web maps:** Google Maps JavaScript API.
- **Stack-confirmed — Supporting mapping services:** Google Places API (New) for place and address search, Google Geocoding API where conversion between addresses and coordinates is genuinely required, and Google Routes API for calculated routes, distances, and travel times.
- **Stack-confirmed — Responsive design:** Tailwind CSS is responsible for controlled responsive layouts, spacing, typography, status colours, and accessible interaction states on the web.
- **Stack-confirmed and agent-rule-confirmed — Component ownership:** Reused Forui components should be wrapped in application-owned widgets, while shadcn/ui component source and Radix-based application components remain inside the project. This permits Weyonje styling without introducing another UI framework.
- **Agent-rule-confirmed — Client responsibility:** Mobile and web interfaces present data and provide usability validation, but the backend remains authoritative for permissions, workflow transitions, business rules, and operational records.

No interface font family or separate cross-platform icon package is selected in `TECHNOLOGY_STACK.md`. Inter and Lucide are complementary recommendations in this document, not stack-confirmed dependencies. Before adding or changing a package, inspect the repository, confirm that the existing stack does not already provide the capability, and apply the dependency-review requirements in `AI_CODING_AGENT_RULES.md`.

## 3. Brand Identity Overview

### Visual character

**Observed:** The logo combines a broad green oval or leaf-like field, a black hand-cut uppercase `WEYONJE!` wordmark, a red upper sweep, a yellow lower-right sweep, and a dark rounded tagline plaque. The tagline reads `Build it. Use it. Empty it.` The irregular lettering and curved silhouette create an energetic, informal, hand-rendered character.

**Recommended:** Translate that character into interfaces through:

- confident use of deep green for primary actions and active brand moments;
- restrained red and yellow accents rather than large competing colour fields;
- rounded but controlled component shapes inspired by the oval silhouette;
- clear, direct language and uncluttered layouts;
- authentic imagery of people, services, vehicles, and Kampala's environment; and
- consistent, accessible controls rather than reproducing the logo's irregular lettering in interface text.

These characteristics are design recommendations, not officially established brand meanings. In particular, do not claim that green, red, or yellow has a specific symbolic meaning unless KCCA approves that interpretation.

### Core identity principles

**Recommended:** Apply four principles when making design decisions:

1. **Recognisable:** Preserve the supplied logo and its colour relationships without redrawing or fragmenting it.
2. **Clear:** Make requests, journey states, decisions, errors, and next actions immediately understandable.
3. **Inclusive:** Design for varied devices, connectivity, visual ability, motor ability, and digital confidence.
4. **Operationally dependable:** Use consistent components and state treatments so clients, providers, Call Centre staff, and KCCA staff can act safely.

## 4. Logo System

### 4.1 Composition and visual characteristics

**Observed:** The supplied logo contains these inseparable elements:

- a flattened green oval or leaf-like base;
- the irregular uppercase wordmark `WEYONJE!` in black or near-black;
- a thin red sweep following the upper-right curve;
- a yellow sweep emerging around the lower-right edge; and
- a dark rounded plaque beneath the main mark containing the handwritten tagline `Build it. Use it. Empty it.`

The exclamation mark is part of the observed wordmark and must not be removed from the artwork. The apparent black surrounding the logo in some viewers is not a background; the PNG itself has transparency.

### 4.2 Approved digital asset

**Pending approval:** Obtain an authoritative vector master from the logo owner, preferably `SVG` for interfaces and `PDF` or the original editable artwork for controlled production use. The vector must come from the owner or an approved designer. Do not auto-trace, redraw, or reconstruct the logo from the PNG.

Until that master is available:

- use the supplied PNG without editing its visible artwork;
- do not enlarge it beyond a size at which raster edges remain clean;
- export derivatives only when necessary for platform packaging;
- preserve transparency and colour profile; and
- keep one version-controlled source asset so teams do not create competing copies.

Removing only empty transparent canvas may improve layout sizing, but the crop must retain all visible and anti-aliased pixels and should be approved before replacing the supplied asset.

### 4.3 Clear space

**Recommended:** Define `x` as the height of the dark tagline plaque in the approved logo asset. Maintain at least `1x` of empty space on every side of the visible artwork. No text, icon, photograph, card edge, viewport edge, or other graphic should enter this area.

The transparent padding in the supplied PNG does not reliably define clear space. Measure clear space from the visible artwork, not from the `554 × 554 px` canvas.

### 4.4 Minimum size

**Recommended:** Use the complete logo lockup only at the following minimum widths:

- mobile and high-density application screens: `240 dp` wide;
- web interfaces: `240 CSS px` wide; and
- low-density raster export: never smaller than `240 physical px` wide.

These are conservative working minima intended to keep the small handwritten tagline legible. Validate them on representative Android devices, desktop screens, and browser zoom levels before formal approval.

Below the minimum width, do not crop the oval, remove the tagline, or invent a monogram. Use the plain text name `Weyonje` in the approved interface typeface, or obtain an officially approved compact logo variant.

### 4.5 Placement

**Recommended:** Appropriate placements for the full lockup include:

- app launch or splash screen;
- sign-in and account-entry screens;
- onboarding or an introductory empty state;
- web sign-in screen;
- web portal about/help area; and
- controlled public-facing headers where adequate width exists.

Keep the logo visually level and separated from interactive controls. On left-to-right screens, left alignment is preferred in wide layouts and centred alignment is suitable for focused entry screens. Do not place the full lockup in a compact mobile app bar or repeat it on every card.

### 4.6 Background treatment

**Recommended:** The preferred logo background is solid white `#FFFFFF` or the light canvas `#F8FAF9`. On photographs, maps, patterned surfaces, coloured panels, or dark-mode screens, place the unchanged logo on an opaque white or light-neutral container that includes the required clear space.

No reversed, monochrome, dark-background, or single-colour logo variant was supplied. Do not create one by recolouring or inverting the logo. If such variants are operationally necessary, commission them from the logo owner and add them only after approval.

### 4.7 Incorrect logo usage

Do not:

- stretch, compress, skew, rotate, or flip the logo;
- crop any visible portion of the artwork;
- remove the exclamation mark, tagline, colour sweeps, plaque, or green field;
- isolate the oval or another logo element as an unofficial app icon;
- retype, correct, or substitute the wordmark or tagline lettering;
- change the colours, transparency, proportions, or order of elements;
- add outlines, gradients, glow, bevels, shadows, or animation;
- place it on a background that hides any of its colours;
- use it as a low-contrast watermark behind content;
- place it closer to another element than the required clear space;
- place it inside a shape that appears to be part of the logo; or
- use a screenshot, compressed social-media copy, or visibly pixelated file when the source asset is available.

## 5. Colour System

### 5.1 How to use these values

The logo is a compressed, anti-aliased raster image, so it contains many edge and shading values. The representative logo colours below are measured samples from dominant opaque pixel clusters; they are not confirmed original master swatches.

All derivative, neutral, and semantic colours are **Recommended** additions. They create sufficient states and contrast for application interfaces without altering the logo.

### 5.2 Observed logo colours

| Token | Representative value | RGB | HSL | Intended interface role |
|---|---:|---:|---:|---|
| Logo green | `#056C35` | `rgb(5 108 53)` | `hsl(148 91% 22%)` | Recommended primary brand and action colour |
| Logo red | `#E52517` | `rgb(229 37 23)` | `hsl(4 82% 49%)` | Brand accent only; not the default error token |
| Logo yellow | `#FBDC08` | `rgb(251 220 8)` | `hsl(52 97% 51%)` | Brand accent and rating highlight with dark text |
| Logo near-black | `#111412` | `rgb(17 20 18)` | `hsl(140 8% 7%)` | Primary text and dark surfaces |

On `#056C35`, white text has approximately `6.56:1` contrast. On `#E52517`, white text is approximately `4.56:1` and should not be relied on for small or low-weight text. On `#FBDC08`, white text fails contrast; use near-black text.

### 5.3 Recommended brand extensions

| Token | HEX | RGB | HSL | Use |
|---|---:|---:|---:|---|
| Green dark | `#034A25` | `rgb(3 74 37)` | `hsl(149 92% 15%)` | Pressed primary controls and strong brand surfaces |
| Green hover | `#045D2E` | `rgb(4 93 46)` | `hsl(148 92% 19%)` | Web hover state for primary controls |
| Green soft | `#E8F3ED` | `rgb(232 243 237)` | `hsl(147 31% 93%)` | Selected rows, active navigation, and subtle brand panels |
| Red dark | `#B91E13` | `rgb(185 30 19)` | `hsl(4 81% 40%)` | Strong red text or controlled accent requiring more contrast |
| Red soft | `#FDECEA` | `rgb(253 236 234)` | `hsl(6 83% 95%)` | Soft red accent or error background |
| Yellow dark | `#7A6400` | `rgb(122 100 0)` | `hsl(49 100% 24%)` | Yellow-associated text on a light warning surface |
| Yellow soft | `#FFF8CC` | `rgb(255 248 204)` | `hsl(52 100% 90%)` | Soft brand highlight |

Do not use the darker derivatives inside the logo. They are interface tokens only.

### 5.4 Recommended neutral palette

| Token | HEX | RGB | HSL | Use |
|---|---:|---:|---:|---|
| White | `#FFFFFF` | `rgb(255 255 255)` | `hsl(0 0% 100%)` | Cards, dialogs, logo container |
| Canvas | `#F8FAF9` | `rgb(248 250 249)` | `hsl(150 17% 98%)` | Default application background |
| Surface muted | `#EEF2F0` | `rgb(238 242 240)` | `hsl(150 13% 94%)` | Secondary surfaces and disabled fills |
| Border | `#D4DAD6` | `rgb(212 218 214)` | `hsl(140 7% 84%)` | Dividers and input/card boundaries |
| Muted | `#9AA49E` | `rgb(154 164 158)` | `hsl(144 5% 62%)` | Decorative or disabled content only |
| Secondary text | `#5E6862` | `rgb(94 104 98)` | `hsl(144 5% 39%)` | Supporting text on white/light surfaces |
| Strong text | `#2B332E` | `rgb(43 51 46)` | `hsl(142 9% 18%)` | Headings and high-emphasis text |
| Ink | `#111412` | `rgb(17 20 18)` | `hsl(140 8% 7%)` | Default body text and icons |

`#9AA49E` does not have enough contrast for ordinary text on white. Reserve it for disabled or non-essential decoration, and ensure disabled controls remain understandable through labels and structure.

### 5.5 Recommended semantic palette

Semantic colours communicate system meaning and must remain separate from the decorative logo accents.

| Meaning | Foreground | Background | RGB / HSL foreground | Typical use |
|---|---:|---:|---:|---|
| Success | `#087A3E` | `#E8F7EF` | `rgb(8 122 62)` / `hsl(148 88% 25%)` | Successful completion and confirmations |
| Warning | `#8A6A00` | `#FFF8D6` | `rgb(138 106 0)` / `hsl(46 100% 27%)` | Attention, pending decisions, and non-destructive warnings |
| Error | `#B42318` | `#FDECEA` | `rgb(180 35 24)` / `hsl(4 76% 40%)` | Validation errors, failures, rejected outcomes, and destructive actions |
| Information | `#175CD3` | `#EAF2FF` | `rgb(23 92 211)` / `hsl(218 80% 46%)` | Informational notices and active operational states |
| Focus | `#0B65D8` | — | `rgb(11 101 216)` / `hsl(214 90% 45%)` | Keyboard and accessibility focus ring |

The success, warning, error, information, and focus foregrounds each meet WCAG AA contrast for normal text against white. Pair every semantic colour with a label and, where useful, an icon; colour alone must never carry the meaning.

### 5.6 Colour proportions

**Recommended:** Let neutral backgrounds and surfaces dominate each screen. Use green for the primary action, selected navigation, and a small number of key highlights. Use red and yellow sparingly. A screen should normally have one visually dominant action, not several competing brand-coloured controls.

## 6. Typography

### 6.1 Logo lettering

**Observed:** The wordmark and tagline use irregular, hand-rendered lettering. The exact typefaces cannot be established from the supplied raster logo and may be custom artwork.

Do not identify either style as an official font. Do not imitate the lettering in headings, buttons, navigation, or body copy. Preserve it only as part of the approved logo artwork.

### 6.2 Interface typeface

**Recommended; pending approval:** Use **Inter Variable** for both mobile and web interfaces. It is a complementary UI choice, not a font inferred from the logo or a stack-confirmed dependency. It provides strong legibility, broad weight coverage, clear numerals, and a consistent cross-platform appearance.

- Bundle the approved Inter variable font files with the Flutter app so rendering is predictable offline.
- Self-host the web font files rather than depending on a third-party font CDN.
- Use the web fallback stack: `Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`.
- Limit normal interface use to weights `400`, `500`, `600`, and `700`.
- Use tabular numerals for metrics, times, prices, and operational tables where column alignment matters.

If KCCA later mandates an institutional typeface, perform legibility and layout testing before replacing these tokens.

### 6.3 Recommended type scale

| Role | Size / line height | Weight | Use |
|---|---:|---:|---|
| Display | `40 / 48` | `700` | Rare introductory or public-facing statement |
| Heading 1 | `32 / 40` | `700` | Page title |
| Heading 2 | `28 / 36` | `700` | Major page section |
| Heading 3 | `24 / 32` | `600` | Subsection or card group |
| Title | `20 / 28` | `600` | Card, dialog, or panel title |
| Body large | `18 / 28` | `400` | Introductory text or high-priority instructions |
| Body | `16 / 24` | `400` | Default content, form inputs, and mobile text |
| Body small | `14 / 20` | `400` | Supporting data and dense web interfaces |
| Label / button | `14 / 20` | `600` | Controls, field labels, tabs, and badges |
| Caption | `12 / 16` | `400–500` | Timestamps and supplementary metadata only |

Sizes are logical pixels on Flutter and CSS pixels on the web. Keep body text at `16 px` in mobile web form controls to avoid browser zoom. Never place essential instructions below the caption size.

### 6.4 Hierarchy and writing style

**Recommended:**

- Use sentence case for headings, buttons, fields, tabs, and status labels.
- Use bold weight to establish hierarchy, not entire paragraphs in capitals.
- Keep one `Heading 1` per page or principal screen.
- Keep web reading lines to approximately `45–75` characters where practical.
- Do not use colour alone to distinguish headings from body text.
- Allow device text scaling without clipping, overlap, or lost actions.
- Use plain, action-oriented labels such as `Submit request`, `Accept request`, and `Confirm collection`.
- Do not put critical instructions only in placeholder text.

## 7. Iconography

### 7.1 Icon family

**Recommended; pending dependency confirmation:** Use **Lucide** as the shared icon language where it is already supported by the pinned Forui and shadcn/ui configurations. This avoids conflicting visual families without adding another component framework. Lucide is not independently selected by `TECHNOLOGY_STACK.md`; the implementing agent must inspect the installed versions and repository configuration before adding or changing an icon dependency.

Use one outlined icon style with:

- `24 px/dp` default size and approximately `2 px` stroke;
- `20 px/dp` for ordinary controls;
- `16 px/dp` only in compact metadata or dense web tables; and
- `32 px/dp` or larger only for empty states and explanatory illustrations.

### 7.2 Icon usage

**Recommended:**

- Pair unfamiliar or consequential icons with a visible text label.
- Use the same icon for the same action across mobile and web.
- Give icon-only buttons an accessible name and tooltip on pointer-based web interfaces.
- Preserve the icon's aspect ratio and standard stroke; do not stretch or mix filled and outlined styles arbitrarily.
- Use semantic colour only when the icon communicates that state.
- Never substitute a Lucide icon for the Weyonje logo or extract a logo element as an interface icon.
- Use directional icons consistently with the interface's reading direction.

## 8. Imagery, Shapes, and Supporting Graphics

### 8.1 Photography and illustration

**Recommended:** Prefer authentic, well-lit imagery of Kampala, responsible waste handling, service delivery, vehicles, teams, communities, and clean public spaces. Show people with dignity and agency.

- Obtain the required consent and usage rights.
- Avoid exposing faces, home addresses, phone screens, registration plates, or precise private locations without authorization.
- Do not use sensational waste imagery, stereotypes, humiliating depictions, or unverifiable before-and-after claims.
- Keep important text outside visually busy areas; use an opaque surface when text overlays cannot be avoided.
- Add meaningful alternative text for informative imagery and empty alternative text for purely decorative imagery.

**Recommended:** Use simple line illustrations based on the Lucide stroke character when photography is inappropriate. Illustration must support comprehension, not decorate every empty area.

### 8.2 Shapes and radii

**Observed:** The logo is dominated by an elongated oval and a rounded tagline plaque.

**Recommended:** Echo this softness through controlled component radii:

- small controls and chips: `6 px`;
- inputs and ordinary buttons: `10 px`;
- cards and dialogs: `14 px`;
- prominent panels: `20 px`; and
- pills, status chips, and circular controls: `999 px`.

Do not turn every container into an oval. Layout hierarchy and usability take priority over decorative resemblance.

### 8.3 Patterns and accent strokes

**Recommended:** Curved route lines, subtle ovals, and short red or yellow sweeps may be used as supporting motifs, provided they cannot be mistaken for interactive controls or parts of the logo. Keep decorative patterns low contrast, outside reading areas, and absent from high-density operational screens. Do not repeat the complete logo as a pattern.

### 8.4 Spacing, borders, elevation, and motion

**Recommended:**

- Base spacing on a `4 px/dp` grid: `4`, `8`, `12`, `16`, `24`, `32`, `40`, `48`, and `64`.
- Use `1 px` neutral borders for most cards, forms, and dividers.
- Prefer separation by spacing and border over heavy shadows.
- Use a soft shadow only for floating menus, dialogs, and temporarily elevated surfaces.
- Use approximately `150 ms` for small feedback, `200 ms` for standard transitions, and up to `300 ms` for a complex panel change.
- Prefer ease-out movement and respect reduced-motion preferences.
- Do not animate or disassemble the logo.

## 9. Interface Foundations

### 9.1 Layout and density

**Recommended:** Mobile screens should prioritise one task and one primary action at a time. The KCCA web portal may use denser tables and split views, but it must retain readable spacing, clear grouping, and predictable keyboard order.

Use a maximum content width for forms and prose rather than stretching them across large monitors. Allow operational maps and data tables to use wider areas when that materially improves the task.

### 9.2 Navigation

#### Mobile

- Use a bottom navigation bar for `3–5` top-level destinations when the information architecture supports it.
- Show both icon and text for each destination.
- Use logo green and a visible label for the active destination; do not rely on colour alone.
- Keep each target at least `48 × 48 dp`.
- Use a standard app bar for screen title, back navigation, and no more than a few contextual actions.
- Do not force the full logo into a compact app bar.

#### Web

- Use a persistent side navigation for KCCA and Call Centre workflows when viewport width permits.
- Mark the current location with a green indicator, soft-green surface, icon, and text weight.
- Collapse to a controlled drawer at narrower widths; preserve labels rather than showing an unexplained icon rail.
- Provide breadcrumbs only when they clarify a genuinely nested record or task.
- Keep account, help, and sign-out actions in stable, predictable locations.

### 9.3 Buttons and links

#### Primary button

- Background: `#056C35`; text and icon: `#FFFFFF`.
- Web hover: `#045D2E`; pressed: `#034A25`.
- Use for the single highest-priority safe action in a section.

#### Secondary button

- Background: `#E8F3ED`; text and icon: `#034A25`.
- Optional border: `#D4DAD6` where the surface requires definition.
- Use for a meaningful alternative that should not compete with the primary action.

#### Outline and tertiary actions

- Use a white or transparent background, `#056C35` text, and a visible border for outline controls.
- Use text-only controls for low-priority actions.
- Underline inline links by default or on hover, and never distinguish a link only by green colour.

#### Destructive button

- Background: `#B42318`; text: `#FFFFFF`.
- State the consequence explicitly, for example `Reject provider` rather than `Continue`.
- Require confirmation when the result is difficult to reverse.

#### Shared behaviour

- Minimum target: `48 × 48 dp` on mobile and `44 × 44 CSS px` for ordinary web controls.
- Keep labels visible during loading and preserve button width; add a progress indicator and prevent duplicate submission.
- Disabled controls must be visually distinct, non-interactive, and understandable from surrounding guidance. Do not communicate disabled state through opacity alone.
- Apply a `2–3 px` focus ring in `#0B65D8` with enough offset to remain visible against the control and background.
- Yellow is not a primary call-to-action colour. If used for a warning action, pair it with `#111412` text.

### 9.4 Forms

**Recommended:**

- Place persistent labels above fields; placeholders may show examples but cannot replace labels.
- Mark required fields in text and explain the convention once per form.
- Use a minimum field height of `48 dp` on mobile and `44 CSS px` on web.
- Default border: `#D4DAD6`; text: `#111412`; supporting text: `#5E6862`.
- Focus: show the `#0B65D8` focus ring and retain a visible boundary.
- Error: show `#B42318` text, an icon, and a precise message adjacent to the field. Do not merely turn the border red.
- Success: show confirmation only when it helps the user, rather than colouring every valid field green.
- Preserve entered values after a recoverable validation or network error.
- Group related controls with a visible heading or `fieldset` and legend.
- Provide appropriate keyboard, input type, autocomplete, and format examples for phone numbers and other structured data.
- Never expose sensitive information in helper text, logs, screenshots, or analytics.

### 9.5 Cards and content panels

**Recommended:** Use `#FFFFFF`, a `1 px` `#D4DAD6` border, and a `14 px` radius for ordinary cards. Use a subtle shadow only when elevation conveys behaviour. Keep the card title, status, metadata, and action order consistent. Do not make an entire card clickable when it also contains separate interactive controls unless focus and click behaviour are unambiguous.

### 9.6 Dialogs, drawers, and menus

**Recommended:**

- Use Forui primitives on mobile and shadcn/ui components built on Radix UI on the web.
- Give every dialog a visible title, concise purpose, and clearly labelled actions.
- Place the safe action before the destructive action in reading order unless platform convention and testing establish otherwise.
- Trap focus inside modal dialogs, return focus to the invoking control, support `Escape` on web, and prevent background interaction.
- Do not use a dialog for content that needs deep linking, lengthy comparison, or a multi-step workflow; use a page instead.
- Use a bottom sheet or drawer only when content, keyboard, and screen-reader behaviour remain usable on small screens.

### 9.7 Alerts, notifications, and toasts

**Recommended:** Pair semantic background and foreground colours with an icon, heading, and plain-language message. State what happened and what the user can do next.

- Use inline alerts for information that must remain visible.
- Use toasts for brief confirmation of a completed, non-critical action.
- Do not use a disappearing toast as the only presentation of an error that requires action.
- Ensure live announcements use the appropriate polite or assertive accessibility behaviour without repeatedly interrupting screen readers.

### 9.8 Status indicators

**Recommended:** Render each state as a text label plus a consistent icon or shape. The following mappings are suitable where these documented workflow states are displayed:

| Workflow state | Treatment | Supporting cue |
|---|---|---|
| Pending | `#8A6A00` on `#FFF8D6` | Clock icon and `Pending` label |
| Accepted | `#175CD3` on `#EAF2FF` | Check-circle icon and `Accepted` label |
| Active / journey in progress | `#056C35` on `#E8F3ED` | Navigation icon and explicit live-state label |
| Collection completed | `#087A3E` on `#E8F7EF` | Package-check icon and full label |
| Completed | `#034A25` on `#E8F7EF` | Badge-check icon and `Completed` label |
| Rejected or failed | `#B42318` on `#FDECEA` | X-circle icon and explicit outcome label |

The status name remains authoritative; the icon and colour are reinforcing cues. Do not introduce undocumented workflow states merely to fit this visual mapping. If the implemented state machine differs, update the mapping to the implemented terms rather than translating states only in the interface.

### 9.9 Tables and data-heavy web views

**Recommended:**

- Keep column headings visible and meaningful; avoid abbreviations that require guessing.
- Use tabular numerals for dates, times, prices, counts, and ratings.
- Use row hover only as a pointer aid, not as the sole indication that a row is actionable.
- Preserve visible keyboard focus and provide an accessible name for row actions.
- Allow critical state and action columns to remain visible on narrower views; move secondary fields into a detail view instead of shrinking text below the approved scale.
- Supply an accessible non-visual name for icon-only sort controls and announce sort direction.

### 9.10 Loading, empty, offline, and error states

**Recommended:** Every data-dependent screen should define:

- a stable loading layout that does not cause large content shifts;
- an empty state explaining why no records appear and what action is available;
- an offline or connection-failure state that preserves safe local work where supported;
- a permission-denied state with a clear recovery path;
- a recoverable server-error state with retry behaviour; and
- a final failure state that gives the user a support or escalation route.

Use a spinner for short, indeterminate waits and progress for measurable work. Do not use the logo as a spinner.

### 9.11 Ratings

**Recommended:** Use logo yellow `#FBDC08` to fill selected rating stars, with `#7A6400` or `#111412` for outlines and adjacent text. Always show the numeric rating and response count where available. Do not communicate the rating through colour or stars alone, and never imply a rating when no feedback exists.

### 9.12 Authorization, sensitive data, and operational safety

**Agent-rule-confirmed:** Interface visibility is not an authorization control. Mobile and web clients may hide or disable actions to improve usability, but the API must independently authorize every request and data object.

- Do not briefly render protected content while authentication, role, or object-level access is still being resolved.
- Distinguish `Unauthenticated`, `Access denied`, `Not found`, `Session expired`, and ordinary loading states without revealing whether an inaccessible record exists.
- Show the actor, target, consequence, and required confirmation before consequential approvals, rejections, assignments, collection confirmations, or disposal actions.
- Do not place tokens, OTPs, phone numbers, feedback text, or precise locations in screenshots, client logs, analytics, crash breadcrumbs, or decorative interface elements.
- Ensure environment indicators used for development or testing cannot be mistaken for business status and never expose secrets or internal infrastructure details.
- Preserve an understandable error and recovery path when identity, mapping, notification, or backend services are unavailable.

## 10. Google Maps and Journey Interfaces

### 10.1 Technology, purpose, and data ownership

**Stack-confirmed and agent-rule-confirmed:** Weyonje uses Google Maps for Flutter (`google_maps_flutter`) in the mobile application and Google Maps JavaScript API in the web portal. Google Places API (New), Geocoding API, and Routes API support only the approved place search, address search, coordinate conversion, and route-calculation needs.

Google Maps Platform supplies maps and calculated mapping content; it is not Weyonje's business database. Weyonje must keep its authoritative service locations, disposal-site records, timestamped GPS positions, arrival decisions, and actual journey history in PostgreSQL/PostGIS. A Google-calculated route is guidance and must never be presented as proof of the route a provider actually travelled.

The interface must distinguish clearly between:

- a user-confirmed service or disposal location owned by Weyonje;
- a calculated route, distance, or duration supplied by Google;
- the provider's latest reported position;
- the actual sampled journey history stored by Weyonje; and
- an arrival or geofence decision made by the Weyonje backend.

### 10.2 Map styling and operational overlays

**Recommended:** Keep the Google basemap visually quieter than Weyonje-owned operational overlays while preserving map labels, usability, and required Google presentation rules. Use one mapping convention across mobile and web:

- calculated or planned route: a controlled blue or neutral line labelled `Suggested route` or `Estimated route`;
- actual recorded journey: logo green `#056C35`, with sufficient width, a contrasting halo, and a label that identifies it as recorded history;
- active provider position: a labelled marker with direction, accuracy, and last-updated information where available;
- collection and disposal points: distinct icons and visible text labels, not colour alone;
- selected point: a clear outline or halo plus a written selection state;
- stale or uncertain position: neutral treatment plus an explicit timestamp or accuracy message;
- critical geospatial error: semantic error styling, not decorative logo red; and
- route progress: combine line treatment, marker position, written status, and time information.

Do not place precise journey information beneath opaque panels without a way to refocus the map. Avoid decorative animation that implies movement when no fresh position has been received. A live marker must show when its data is stale rather than continuing to appear current.

### 10.3 Place and address search

**Stack-confirmed and recommended application:** Use Places API (New) for approved place and address search. Use Geocoding API only where the selected place-search flow does not supply the conversion that the documented workflow needs.

- Label search clearly, for example `Search for collection location`.
- Debounce input, cancel obsolete requests, and avoid requests for empty or unchanged text.
- Show explicit loading, no-result, ambiguous-result, offline, denied-key, timeout, and quota-exhausted states.
- Let the user review and confirm the selected point before it becomes the Weyonje operational location.
- Display enough address context to distinguish similar results without exposing unrelated personal data.
- Request and display only fields required by the approved workflow; do not add place photos, reviews, or unrelated Google content.
- Provide a non-map method for reviewing the selected textual address and coordinates where appropriate.

### 10.4 Routes and actual journey history

**Stack-confirmed and agent-rule-confirmed:** Routes API may provide estimated routes, distances, and travel times. The interface must label these as estimates and keep them visually distinct from actual recorded GPS history.

- Do not recalculate a route for every incoming location sample.
- Do not infer collection, disposal, compliance, or arrival solely from the displayed route.
- Show route-unavailable, invalid-point, timeout, quota, and provider-error states without blocking unrelated Weyonje tasks.
- When comparing planned and actual movement, provide a legend and a textual summary; never rely on two colours alone.
- Show timestamps and data freshness for actual journey points and live provider positions.

### 10.5 Map controls and accessible alternatives

- Keep zoom, recenter, marker selection, and other controls reachable and understandable on each supported platform.
- Do not require a precise map gesture as the only way to choose a location or understand a journey.
- Provide a textual journey summary containing the current status, last update, collection point, disposal point, and relevant route or stop information the user is authorised to see.
- Give custom markers and controls accessible names, and preserve a logical keyboard order on web where the Google Maps integration permits it.
- Ensure overlays, bottom sheets, and side panels can be dismissed or resized without trapping map controls or hiding the selected location.

### 10.6 Google branding and attribution boundaries

Do not recolour the entire Google basemap in brand green or create styling that makes roads, labels, boundaries, or controls difficult to interpret. Preserve all required Google attribution and terms-compliant presentation. The Weyonje logo, cards, markers, and controls must not obscure Google attribution, navigation controls, map labels, or operational points.

Do not present Google place names, calculated routes, or estimated durations as KCCA-verified facts unless Weyonje has separately verified and recorded them. Store or cache Google-provided content only where and for as long as the applicable Google Maps Platform terms permit.

### 10.7 Credentials, privacy, cost, and resilience

**Agent-rule-confirmed:** Use separate, narrowly restricted Android, web, and server credentials for each environment as established by the technology stack. Android keys must be restricted by the approved application identity and signing certificate; browser keys by approved web origins; server credentials must remain only in approved secret stores. Never place a server credential in Flutter, JavaScript, documentation, screenshots, or source control.

Client-side Google Maps keys may be technically visible in a built application and therefore depend on correct application and API restrictions; they must not be treated as unrestricted secrets. The interface and diagnostics must never display keys, billing identifiers, provider payloads, or internal credential errors to users.

- Send Google only the minimum location data required for the requested mapping operation.
- Do not include client names, phone numbers, request notes, provider identities, feedback, or other unnecessary business data in mapping requests.
- Prevent precise locations from entering browser telemetry, mobile crash reports, analytics, screenshots, URLs, or ordinary logs.
- Debounce requests and avoid duplicate map, place, geocoding, and route calls.
- Define a useful degraded state when Google Maps is unavailable, restricted, offline, or over quota; unrelated request details and permitted actions should remain usable.
- Use controlled development credentials and synthetic locations for testing. Do not generate uncontrolled paid requests or use production journey data in tests.
- Treat quotas, spending limits, privacy approval, contractual compliance, and attribution as implementation constraints, not merely operational concerns.

## 11. Mobile Application Guidance

### 11.1 Forui theme implementation

**Stack-confirmed:** Forui is the mobile component and design foundation, and frequently reused components should be wrapped in application-owned widgets.

**Recommended:** Create one generated Weyonje theme and map the semantic tokens as follows:

```text
primary              = #056C35
primaryForeground    = #FFFFFF
secondary            = #E8F3ED
secondaryForeground  = #034A25
destructive          = #B42318
destructiveForeground= #FFFFFF
background           = #F8FAF9
foreground           = #111412
muted                = #EEF2F0
mutedForeground      = #5E6862
border               = #D4DAD6
focus                 = #0B65D8
```

Use the theme-generation or theme-configuration workflow supported by the Forui version pinned in the repository rather than styling each screen independently. Inspect that version's documentation and existing project structure before running a generator or naming generated files.

Then:

- configure `FColors` with the semantic colour pairs above;
- configure `FTypography` to use the bundled Inter family and approved scale;
- retain the Lucide-based `FIcons` family unless an approved replacement is introduced;
- configure `FStyle` for the radius, focus outline, spacing, and restrained shadow rules;
- use the touch-oriented theme variant for mobile controls; and
- expose app-owned wrappers such as primary button, status badge, field, card, and alert so product screens do not hard-code values.

Names and exact generated files depend on the pinned Forui version. Follow that version's generated structure; do not bypass it with scattered constants.

### 11.2 Platform behaviour

**Recommended:** Keep Weyonje's visual tokens consistent while respecting Android and iOS behaviour for safe areas, back navigation, keyboard handling, permission prompts, text scaling, and system accessibility settings. Brand consistency must not override a platform convention that protects usability.

Design mobile layouts for small screens first. Test long names, long locations, multi-line status text, increased font size, landscape orientation, keyboard-open states, weak connectivity, and denied location or notification permissions.

### 11.3 Google Maps for Flutter application

**Stack-confirmed:** Render mobile maps through `google_maps_flutter` and Weyonje-owned widgets that apply the conventions in Section 10.

- Keep API calls, map configuration, operational overlays, and presentation state out of unrelated page widgets.
- Render loading, permission-denied, offline, unavailable-service, invalid-location, quota, and stale-position states explicitly.
- Do not start background location collection merely because a map screen is open; tracking is allowed only for the approved active-journey flow.
- Respect Android lifecycle, safe areas, system text scaling, foreground-service notifications, and battery restrictions.
- Test real GPS, foreground tracking, permissions, weak-network recovery, and map interaction on maintained physical Android devices; emulator success is insufficient.
- Ensure a user can review essential location and journey information without relying solely on the map.

## 12. Web Application Guidance

### 12.1 Tailwind token implementation

**Stack-confirmed:** Tailwind CSS controls responsive layouts, spacing, typography, status colours, and accessible states. shadcn/ui and Radix UI provide the web component primitives.

**Recommended:** Define semantic CSS variables once and connect Tailwind and shadcn/ui components to them. Do not scatter raw brand hex values through JSX.

```css
:root {
  --background: #f8faf9;
  --foreground: #111412;
  --card: #ffffff;
  --card-foreground: #111412;
  --primary: #056c35;
  --primary-foreground: #ffffff;
  --secondary: #e8f3ed;
  --secondary-foreground: #034a25;
  --muted: #eef2f0;
  --muted-foreground: #5e6862;
  --destructive: #b42318;
  --destructive-foreground: #ffffff;
  --border: #d4dad6;
  --input: #d4dad6;
  --ring: #0b65d8;
  --radius: 0.625rem;
}
```

Map these variables into the Tailwind version and shadcn/ui convention pinned in the repository. Use application-owned variants for primary, secondary, destructive, link, status, and loading states. Do not edit Radix interaction logic or remove its keyboard and focus behaviour merely to change appearance.

### 12.2 Responsive behaviour

**Recommended:** Use Tailwind's mobile-first responsive model:

- start with a single-column content flow;
- introduce side navigation and multi-column layouts only when content has room;
- avoid device-name breakpoints; respond to content constraints;
- use container queries for self-contained dashboard components where they simplify reuse;
- preserve reading and keyboard order when the visual layout changes; and
- turn wide tables into a purposeful compact view or scroll region, not a squeezed desktop table.

Do not build separate visual brands for mobile and web. Share tokens and meaning while allowing each platform's navigation and density to suit its tasks.

### 12.3 Web interaction states

Every interactive web component must define default, hover, active, focus-visible, disabled, loading, error, and success behaviour where relevant. Never remove the browser focus outline without providing the approved visible replacement. Test Windows forced-colours/high-contrast mode; avoid forcing brand colours when doing so would hide system state cues.

### 12.4 Google Maps JavaScript API application

**Stack-confirmed:** Render web maps through Google Maps JavaScript API inside application-owned React components. Keep server state in TanStack Query and authorised live updates through Socket.IO rather than making the map object a second source of application state.

- Restrict the browser key to approved origins and the minimum required APIs.
- Keep map loading and provider errors inside a stable layout so the rest of the request or journey page remains usable.
- Reconcile live marker updates with authoritative REST data after reconnects; do not let duplicate or out-of-order events move the interface backwards silently.
- Do not place phone numbers, precise coordinates, request notes, or other sensitive values in URLs, telemetry, analytics, or map labels unless the authorised workflow requires their display.
- Provide keyboard-accessible controls and a textual journey view for operational users who cannot use the map.
- Test the component with mocked Google boundaries in routine tests and use restricted live Google integration checks only where they add necessary confidence.

## 13. Accessibility Requirements

Accessibility is a release requirement, not a decorative enhancement.

### 13.1 Colour and contrast

**Recommended minimum:** Meet WCAG 2.2 Level AA.

- Normal text: at least `4.5:1` contrast.
- Large text: at least `3:1` contrast.
- Meaningful control boundaries, icons, and focus indicators: at least `3:1` against adjacent colours.
- Do not use colour as the only status, error, selection, rating, or route cue.
- Test actual rendered combinations; do not assume a token is accessible in every pairing.
- Keep text out of the red and yellow logo accent colours unless the documented accessible pairing is used.

### 13.2 Keyboard, pointer, and touch

- All web tasks must be operable by keyboard in a logical order.
- Focus must remain visible and must not be hidden under sticky headers, dialogs, or drawers.
- Use at least `44 × 44 CSS px` pointer targets on web and `48 × 48 dp` touch targets on mobile for ordinary controls.
- Do not require hover, drag, swipe, or a precise map gesture as the only way to complete a task.
- Provide accessible alternatives for map selection and route information.

### 13.3 Text and legibility

- Support browser zoom to at least `200%` without loss of content or operation.
- Support mobile text scaling without clipping or overlapping controls.
- Do not communicate essential information only through placeholder text, icon shape, capitalization, or position.
- Write link and button labels that make sense out of context.
- Use plain language and explain uncommon operational terms.

### 13.4 Screen readers and semantics

- Use native semantic controls before custom gestures or clickable containers.
- Give fields programmatic labels, descriptions, and error relationships.
- Give icon-only controls accessible names.
- Announce meaningful dynamic changes, but avoid noisy repeated live updates.
- Make decorative images and icons silent to assistive technology.
- Provide meaningful alternative text for informative images.
- Expose dialog titles, table headings, status labels, progress, and expanded/collapsed states correctly.

### 13.5 Motion and time

- Respect reduced-motion settings.
- Avoid flashing content and unnecessary pulsing.
- Do not make animation the only signal of a live journey or status change.
- Warn users about session expiry and provide a safe extension mechanism where security policy permits.

### 13.6 Language and localisation readiness

**Recommended:** Keep interface strings outside component code, allow labels to expand, and avoid embedding text in images. Even before additional languages are approved, this reduces layout failure and keeps future localisation possible. Do not claim support for a language until its interface, validation, notifications, and assistance content have been translated and tested.

## 14. Dark Mode and High-Contrast Modes

No approved dark logo variant or dark application palette is supplied.

**Recommended:** Treat light mode as the approved baseline. If dark mode is required later, design and accessibility-test a complete semantic dark palette rather than automatically inverting these colours. Continue to place the unchanged logo on its approved light container. Forui requires explicit light/dark theme handling; do not assume that a platform brightness change automatically produces a valid Weyonje theme.

Support operating-system and browser high-contrast modes independently of any future branded dark mode. System legibility takes priority over exact decorative colour reproduction.

## 15. Design Tokens and Cross-Platform Governance

### 15.1 Token naming

**Recommended:** Name tokens by purpose, not by the appearance of one screen:

```text
color.brand.primary
color.brand.red
color.brand.yellow
color.text.default
color.text.secondary
color.surface.canvas
color.surface.card
color.border.default
color.action.primary.default
color.action.primary.hover
color.action.primary.pressed
color.status.success.foreground
color.status.success.background
color.status.warning.foreground
color.status.warning.background
color.status.error.foreground
color.status.error.background
color.status.info.foreground
color.status.info.background
color.focus
radius.control
radius.card
space.1 ... space.9
type.body
type.label
type.heading.1 ... type.heading.3
```

Platform implementations may follow Dart and CSS naming conventions, but the mapping and meaning must remain the same.

### 15.2 Component ownership

**Stack-confirmed and recommended application:**

- On Flutter, wrap commonly reused Forui components in Weyonje-owned widgets.
- On web, maintain the selected shadcn/ui component source in the project and compose it with Radix primitives.
- Keep tokens in one theme layer per platform.
- Avoid one-off colour, radius, font, and shadow values in feature screens.
- Do not add another design system, icon family, or styling framework merely to implement a visual variation already supported by the confirmed stack.

### 15.3 Visual parity

Cross-platform parity means shared hierarchy, colour meaning, type roles, icon meaning, state language, and accessibility—not pixel-identical screens. Mobile may use sheets and bottom navigation; the web portal may use dialogs, side navigation, and denser tables.

### 15.4 Change control and implementation status

**Agent-rule-confirmed:** An AI coding agent must inspect the existing component, theme, tests, and current system documentation before applying these guidelines. It must make the smallest coherent change and reuse established patterns.

- Do not add a new UI framework, styling system, font package, icon package, map library, or component library without an approved technical decision.
- Treat `Observed`, `Stack-confirmed`, `Agent-rule-confirmed`, `Recommended`, and `Pending approval` as materially different statuses.
- Do not describe a recommended token or component as implemented until it exists in the repository or deployed system and has been verified.
- Record approved design decisions in the appropriate design or architecture record.
- Update `CURRENT_SYSTEM_STATE.md` when implementation changes the verified visual system, component structure, accessibility behaviour, integration behaviour, or known limitations.
- Where the repository already differs from this document, surface the discrepancy before normalising code or documentation.

## 16. Asset and Content Management

**Recommended:** Maintain a controlled brand asset directory containing:

- the untouched supplied logo;
- any later approved vector master;
- approved export sizes and app-store assets;
- locally hosted font files with licence information;
- a short asset manifest recording source, owner, approval date, and intended use; and
- no unapproved redraws or alternate colour versions.

Optimise copies during the build process while retaining the source. Use lossless or high-quality formats appropriate to each platform. Do not expose internal filenames as accessible labels.

## 17. Review and Quality Checklist

Before approving a design or release, verify:

### Logo

- The logo uses an approved source asset and retains all visible elements.
- Its aspect ratio is unchanged and it is not pixelated.
- Required clear space and minimum width are respected.
- It appears on white or an approved light-neutral container.
- No unofficial compact, reversed, monochrome, or animated variant has been created.

### Colour and typography

- Components use semantic tokens rather than scattered raw values.
- Red and yellow accents are restrained and use accessible foregrounds.
- Contrast has been tested on the rendered interface.
- Inter is bundled or self-hosted with appropriate licensing and fallbacks.
- Text scaling, browser zoom, long content, and tabular data remain usable.

### Components and states

- Navigation, buttons, links, forms, cards, dialogs, alerts, tables, and maps follow these rules.
- Default, hover, active, focus, disabled, loading, empty, offline, success, and error states exist where relevant.
- Workflow states use explicit text and match the implemented state machine.
- Mobile and web use consistent icons and semantic meanings.
- Authentication, access-denied, not-found, expired-session, dependency-failure, and permission states do not leak protected data.

### Accessibility and responsiveness

- Keyboard-only and screen-reader task flows have been tested.
- Focus is visible and restored correctly after overlays close.
- Touch and pointer targets meet the minimum sizes.
- Screens work at narrow widths, large widths, `200%` browser zoom, and increased mobile text size.
- Reduced-motion and forced-colours/high-contrast behaviour has been checked.
- Maps and imagery have accessible alternatives and do not expose private information.

### Google Maps and location handling

- Mobile uses Google Maps for Flutter and web uses Google Maps JavaScript API; no superseded or self-hosted mapping dependency has been introduced.
- Suggested Google routes are visibly and textually distinct from Weyonje-recorded actual journey history.
- Service locations, disposal sites, GPS samples, arrival decisions, and route history remain Weyonje-owned operational records.
- Required Google attribution and controls remain visible and unobstructed.
- Place search, geocoding, routes, maps, and live locations define loading, no-result, offline, timeout, denied-key, quota, unavailable-service, stale-data, and invalid-location behaviour where applicable.
- Android, browser, and server credentials are separated and restricted appropriately; no server credential or unrestricted key appears in code, documentation, screenshots, or client bundles.
- Mapping requests and diagnostics exclude unnecessary personal and operational information.
- Development and test usage is controlled by restricted credentials, synthetic locations, quotas, and spending safeguards.

### Implementation integrity

- Flutter styling comes through the Weyonje Forui theme and app-owned wrappers.
- Web styling comes through shared Tailwind/shadcn semantic variables and owned components.
- No conflicting UI framework or icon family has been introduced.
- The implementing agent inspected the pinned package versions and existing components rather than inventing APIs, generator commands, or file paths.
- Flutter changes are covered by relevant unit, widget, semantics, integration, and physical-device checks.
- React changes are covered by relevant Vitest/React Testing Library and Playwright checks using accessible queries and stable user-facing behaviour.
- Routine map tests use controlled adapters or mocks; live Google tests use restricted development credentials and do not generate uncontrolled paid traffic.
- Visual changes are covered by component tests, accessibility checks, representative-device review, and honest reporting of checks not run.

## 18. Open Approvals and Future Inputs

The following items remain **Pending approval** because the supplied sources do not establish them:

- authoritative vector logo files and ownership/usage terms;
- official master colour swatches, including print colour definitions;
- official wordmark and tagline lettering provenance;
- an approved compact mark, app icon, monochrome variant, or reversed variant;
- formal brand meanings, voice, and message architecture;
- final approval of Inter as the interface family;
- final minimum sizes and clear-space measurement;
- a dark-mode palette; and
- any institutional KCCA co-branding or government identity requirements;
- final marker artwork and the approved visual distinction between suggested routes and recorded journey history; and
- any optional Google basemap styling beyond the default presentation, subject to accessibility, attribution, contractual, privacy, and cost review.

Until these decisions are approved, use the conservative rules in this document and preserve the supplied logo unchanged.

## 19. Implementation References

The following references support implementation details without changing the source-of-truth labels above:

- [Forui themes](https://forui.dev/docs/concepts/themes) — theme colours, typography, icons, styles, variants, and light/dark handling.
- [Forui icon library](https://forui.dev/docs/reference/icon-library) — bundled Lucide icon support.
- [Forui theme customisation](https://dev.forui.dev/docs/guides/customizing-themes) — generated theme workflow and token files.
- [Tailwind CSS colours](https://tailwindcss.com/docs/color) — theme colour variables and state variants.
- [Tailwind responsive design](https://tailwindcss.com/docs/responsive-design) — mobile-first responsive utilities and container queries.
- [Tailwind focus outlines](https://tailwindcss.com/docs/outline-style) — visible replacement focus styles.
- [Tailwind forced-colour adjustment](https://tailwindcss.com/docs/forced-color-adjust) — high-contrast mode behaviour.
- [shadcn/ui icon configuration](https://ui.shadcn.com/docs/changelog/2024-11-icons) — Lucide as the standard icon library and supported configuration.
- [Google Maps for Flutter](https://developers.google.com/maps/flutter-package/overview) — approved Flutter map integration.
- [Google Maps JavaScript API](https://developers.google.com/maps/documentation/javascript/) — approved web map integration.
- [Places API (New)](https://developers.google.com/maps/documentation/places/web-service/op-overview) — approved place and address search service.
- [Geocoding API](https://developers.google.com/maps/documentation/geocoding/overview) — address and coordinate conversion where required.
- [Routes API](https://developers.google.com/maps/documentation/routes) — calculated routes, distances, and travel times.
- [Google Maps Platform API security guidance](https://developers.google.com/maps/api-security-best-practices) — application restrictions, API restrictions, and credential handling.
- [Google Maps Platform policies and attribution](https://developers.google.com/maps/terms) — contractual, storage, presentation, and attribution requirements.
- [Google Maps Platform billing and pricing](https://developers.google.com/maps/billing-and-pricing/overview) — usage monitoring, quotas, and cost governance context.

---

**Document status:** Proposed brand identity implementation guideline derived from the supplied logo and aligned with `TECHNOLOGY_STACK.md` and `AI_CODING_AGENT_RULES.md`. Complementary recommendations remain subject to approval and must not be described as official or implemented until the appropriate approval and verification have occurred.
