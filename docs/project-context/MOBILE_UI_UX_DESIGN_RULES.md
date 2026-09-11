## Product and UX Architecture

### Adopted Mobile Foundation

Use the repository-pinned Forui components through the central Weyonje theme and existing application-owned wrappers. New standard controls should compose Forui and preserve its anatomy, semantics, focus, validation, loading and disabled behavior. Do not add a competing Material design layer or per-screen palette. Keep at least 48 dp touch targets, including explicit component overrides where Forui defaults are smaller. Preserve native date/time pickers, Google Maps and platform permission interfaces. Retain the existing fonts, icons and light/dark behavior; recommendations do not authorize dependency upgrades.

The welcome screen has the unchanged logo, “Welcome to Weyonje”, and four actions in order: “Create Account” (primary), “Client Sign In”, “Provider Sign In”, “KCCA Sign In” (consistent secondary styling). It has no explanatory paragraph. Provider/KCCA entry context changes the heading and introductory copy of the shared form; API actor resolution remains authoritative.


1. Derive every screen, component, and action from a documented requirement, user goal, actor responsibility, business rule, state, or transition.

2. Maintain traceability from each major interface element to the requirement or workflow step it supports.

3. Never invent dashboards, analytics, activity feeds, favourites, recommendations, chat, onboarding, settings, profile features, quick actions, or help features merely because similar applications contain them.

4. Design role-specific experiences around each role’s actual permissions, responsibilities, information needs, and task frequency.

5. Do not expose actions or information to a role that cannot use them.

6. Prioritize tasks by frequency, urgency, consequence, and user value rather than by visual appeal.

7. Model complete workflows—including entry points, decisions, validation, waiting states, rejection, cancellation, completion, and recovery—before composing individual screens.

8. Ensure every workflow has a clear entry point, next step, completion condition, and route back to an appropriate destination.

9. Do not design isolated attractive screens that fail to connect into an executable end-to-end flow.

10. Reflect business-process states accurately; do not collapse materially different states merely to simplify the interface.

11. Preserve the user’s context, entered data, filters, scroll position, and selected item when they temporarily leave and return to a workflow.

12. Use progressive disclosure when secondary information or advanced controls would distract from the current task.

13. Do not hide information required for an immediate decision behind unnecessary navigation or disclosure controls.

14. Minimize navigation depth for frequent tasks without flattening distinct concepts into an incoherent screen.

15. Combine steps when they involve one decision, little information, and no meaningful need for separate validation.

16. Separate steps when they involve different decisions, substantial cognitive load, conditional branches, external processing, or a meaningful opportunity to review.

17. Use a full page for substantial tasks, durable destinations, deep-linkable content, or workflows requiring navigation and state preservation.

18. Use a bottom sheet for a focused, temporary choice or contextual action that benefits from retaining the underlying page as context.

19. Use a dialog only for short, blocking decisions requiring immediate attention.

20. Use inline disclosure or inline feedback when the information belongs directly to the affected content.

21. Do not create a new page when expanding a section, revealing details, or editing inline would preserve context more effectively.

22. Do not fragment a simple operation into multiple screens merely to imitate a wizard.

23. Use a multi-step workflow only when sequencing, validation, dependencies, or cognitive load genuinely require it.

24. Prevent dead ends by providing an appropriate next action, recovery action, or route back from every nonterminal state.

25. Distinguish destinations from actions: destinations open places; actions change state or initiate work.

26. Make irreversible, financially significant, privacy-sensitive, or safety-sensitive consequences visible before commitment.

## Layout and Composition

 1. Size and arrange sections according to their content and importance rather than forcing them into a reusable dashboard template.

 2. Establish a deliberate alignment system and align related text, controls, imagery, and metadata to shared visual axes.

 3. Prefer natural content flow over arbitrary two-column grids, equal-sized tiles, or symmetrical arrangements.

 4. Use grids only when the items are genuinely parallel, similarly important, and scannable by comparison.

 5. Do not force unequal content into identical tile dimensions when doing so creates truncation, empty space, or false equivalence.

 6. Use cards only when a bounded surface communicates meaningful grouping, independence, interactivity, or elevation.

 7. Do not place every section inside a card; use spacing, alignment, typography, dividers, headings, or background hierarchy for ordinary grouping.

 8. Avoid card-inside-card composition unless the nested element is independently interactive or semantically distinct.

 9. Do not add a hero section, oversized header, or decorative banner unless it serves an important product or communication function.

10. Keep operational screen headers compact enough to leave useful viewport space for the task.

11. Let content density reflect the task: increase density for scanning and comparison; reduce it for difficult decisions or focused data entry.

12. Do not use excessive whitespace to manufacture elegance while pushing essential information below the fold.

13. Do not compress content so tightly that grouping, readability, or touch accuracy is impaired.

14. Vary spacing by relationship: use smaller gaps within a group and larger gaps between groups.

15. Do not apply one identical gap between every element; mechanical spacing erases semantic grouping.

16. Keep page margins, section spacing, and internal component padding consistent with defined spacing tokens.

17. Avoid ornamental containers whose only purpose is to fill an otherwise weak composition.

18. Use the initial viewport for the screen identity, essential context, and highest-priority task—not decorative content.

19. Make scrolling predictable; avoid nested vertical scroll regions unless independently scrolling content is required.

20. Keep related content and its action close enough that their relationship is unambiguous.

21. Test visual balance with realistic content rather than placeholder text of convenient lengths.

22. Do not make every screen share the same card-grid composition; adapt structure to reading, selecting, entering, reviewing, or monitoring tasks.

## Visual Hierarchy

 1. Make the screen identity, primary information, and primary action recognizable within the first visual scan.

 2. Establish hierarchy using position, grouping, typography, spacing, and contrast before adding decoration.

 3. Limit each screen region to one dominant focal point unless the task genuinely requires comparison between peers.

 4. Do not give headings, cards, icons, buttons, and statistics equal visual emphasis.

 5. Use visual prominence in proportion to task importance and consequence.

 6. Use heading levels semantically and consistently; do not select heading sizes solely to fill space.

 7. Use weight sparingly; reserve stronger weights for content that must anchor scanning or decision-making.

 8. De-emphasize metadata through appropriate size, colour, position, and spacing without reducing legibility.

 9. Use accent colour to direct attention deliberately, not to decorate every interactive or branded element.

10. Ensure interactive elements look interactive and informational elements do not falsely resemble controls.

11. Make the primary action distinct without making it visually disproportionate to the screen.

12. Do not compensate for weak information architecture with multiple banners, colours, icons, or oversized labels.

## Surfaces, Borders, Shadows, and Elevation

 1. Use a surface change only to communicate grouping, hierarchy, interaction, selection, or elevation.

 2. Do not alternate surface colours arbitrarily between sections.

 3. Use borders when boundaries must remain visible without implying elevation.

 4. Use dividers for dense lists or adjacent content whose boundaries require reinforcement.

 5. Avoid outlining every container, field, row, and chip simultaneously.

 6. Use shadows only when elevation or overlap must be perceived.

 7. Do not add shadows to static sections merely to make them appear polished.

 8. Keep elevation levels few, standardized, and tied to specific behaviours such as app bars, menus, sheets, dialogs, and floating controls.

 9. Do not make every surface appear to float.

10. Use corner radii from a restrained token set and assign them consistently by component type.

11. Do not apply the same large radius to pages, cards, buttons, fields, images, chips, and dialogs indiscriminately.

12. Prefer unboxed content when natural structure already communicates the grouping.

## Colour and Brand

 1. Define semantic colour roles such as background, surface, text, border, primary action, secondary action, success, warning, error, and information.

 2. Reference semantic colour tokens in components rather than hard-coded colour values.

 3. Use brand colours to create identity at deliberate touchpoints rather than saturating every component.

 4. Maintain a strong neutral foundation so brand and semantic colours retain meaning.

 5. Use the primary brand colour for priority, identity, or key interaction—not for every icon, heading, border, and background.

 6. Use accent colours consistently; do not assign new colours merely to make adjacent elements look varied.

 7. Use gradients only when they express brand character, hierarchy, data, or meaningful depth.

 8. Do not apply gradients as a default header, button, card, or background treatment.

 9. Do not create a separate arbitrary colour for every status; group statuses by semantic meaning and consequence.

10. Avoid excessive pastel containers that weaken hierarchy and make unrelated content appear equivalent.

11. Do not place every icon on a coloured circle or rounded-square tile.

12. Ensure text and essential controls meet contrast requirements in every state, including disabled and selected states.

13. Do not use colour as the sole indicator of status, selection, validation, or change; pair it with text, shape, iconography, or position.

14. Preserve semantic meaning across light and dark modes rather than mechanically inverting colours.

15. Test dark-mode surfaces, borders, elevation, imagery, and system bars independently where dark mode is supported.

16. Do not use pure brand fidelity as justification for inaccessible contrast.

## Typography

1. Define a restrained semantic type scale with named styles for screen titles, section headings, body text, labels, metadata, captions, and actions.

2. Use typography styles by meaning rather than selecting arbitrary sizes and weights per screen.

3. Limit the number of distinct font sizes visible within a single region.

4. Avoid oversized marketing-style headlines in operational or data-heavy applications.

5. Use bold text only where emphasis improves scanning, hierarchy, or comprehension.

6. Do not bold entire paragraphs, labels, values, and buttons simultaneously.

7. Set line height for comfortable reading and prevent tightly packed multiline text.

8. Keep readable line lengths on large screens; do not stretch paragraphs across the full tablet width.

9. Use left alignment for most reading and data-entry content; use centred text only when the composition and content justify it.

10. Apply capitalization consistently and avoid unnecessary all-caps labels.

11. Do not truncate information required to distinguish records, make decisions, or complete tasks.

12. Allow text to wrap where the content is important and provide expansion where truncation is unavoidable.

13. Design for dynamic type and text scaling without overlapping, clipping, or hiding controls.

14. Test headings, buttons, tabs, chips, and form labels with long localized text.

15. Keep metadata legible; de-emphasis must not turn information into faint decoration.

16. Do not introduce multiple font families without an established brand requirement and a defined role for each.

## Iconography and Imagery

  1. Use icons when they improve recognition, scanning, spatial efficiency, or platform familiarity.

  2. Prefer text when an icon would be ambiguous, unfamiliar, or require explanation.

  3. Do not place decorative icons beside every heading, label, field, or list item.

  4. Do not repeat the icon-in-circle or icon-in-rounded-square treatment without semantic justification.

  5. Use one coherent icon family with consistent stroke, fill, proportion, and optical weight.

  6. Select icons by established meaning; do not choose icons merely because they look attractive.

  7. Pair unfamiliar or consequential icon actions with visible text.

  8. Provide accessible names for all icon-only controls.

  9. Keep icon sizing and alignment consistent within the same control class.

 10. Distinguish actionable icons from decorative or informational icons.

 11. Use imagery and illustrations only when they convey identity, instruction, context, content, or meaningful emotion.

 12. Do not add generic stock illustrations to fill empty space.

 13. Define image cropping, aspect ratio, loading, failure, and fallback behaviour.

## Buttons and Actions

  1. Provide one visually dominant primary action when the screen has a clear principal task.

  2. Do not show multiple competing primary buttons in the same decision region.

  3. Represent secondary actions with lower-emphasis button styles and tertiary actions with text or contextual controls where appropriate.

  4. Use destructive styling only for genuinely destructive or high-risk actions.

  5. Do not turn ordinary navigation links into oversized calls to action.

  6. Do not make every action a full-width rounded button; use full width when it improves reach, clarity, or layout on narrow screens.

  7. Place actions near the content or decision they affect.

  8. Use sticky actions only when the action remains relevant throughout scrolling and must remain readily available.

  9. Ensure sticky controls do not obscure content, system gestures, validation messages, or keyboard interaction.

 10. Write button labels as specific actions, such as “Submit Request” or “Save Changes,” rather than vague labels such as “Continue” when the outcome matters.

 11. Show loading state inside the initiating control when the operation is directly tied to it.

 12. Prevent repeated activation while an operation is being submitted.

 13. Preserve button dimensions during loading to prevent layout movement.

 14. Provide clear disabled-state styling and expose the reason for disability when it is not obvious.

 15. Do not disable a primary action without helping the user identify what remains incomplete.

 16. Meet platform-appropriate minimum touch-target dimensions even when the visible icon is smaller.

## Forms and Data Entry

  1. Use persistent labels for fields; do not rely on placeholders as the only label.

  2. Use placeholders only for format examples or genuinely useful hints.

  3. Do not repeat the same instruction in the label, placeholder, helper text, tooltip, and information banner.

  4. Group fields according to the user’s mental model and the business process.

  5. Order fields according to natural entry sequence, dependencies, and frequency.

  6. Use the correct keyboard, input mode, autofill metadata, and capitalization behaviour for each field.

  7. Apply input masks and formatting only when they help entry without obstructing editing, pasting, or accessibility.

  8. Accept common valid input variations and normalize them safely.

  9. Provide sensible defaults only when they are likely correct, transparent, and easy to change.

 10. Use autocomplete, saved values, and selection controls when they reduce effort without creating privacy or accuracy risks.

 11. Use native or familiar date and time controls appropriate to the required precision and range.

 12. Choose radio buttons, checkboxes, switches, pickers, and menus according to selection cardinality, immediacy, and option count.

 13. Reveal conditional fields only when their triggering answer makes them relevant.

 14. Preserve entered data across validation errors, temporary navigation, interruptions, and recoverable failures.

 15. Warn before discarding meaningful unsaved work.

 16. Validate at the earliest point that helps correction without interrupting normal entry.

 17. Place field-level errors adjacent to the affected field and describe how to fix them.

 18. Use form-level errors for failures involving multiple fields, server processing, or the submission as a whole.

 19. Move focus to or summarize errors after failed submission in an accessible manner.

 20. Identify required fields consistently and explain the convention once when necessary.

 21. Do not mark nearly every field as required without reviewing whether the business process truly requires it.

 22. Break long forms into sections before creating separate pages.

 23. Use multiple form steps only when sections have meaningful dependencies, distinct decisions, or substantial length.

 24. Show progress only when the user benefits from understanding the remaining work.

 25. Make submit behaviour explicit and distinguish saving a draft from final submission.

 26. Do not clear fields after a failed submission.

 27. Handle server-side validation without contradicting earlier client-side guidance.

## Navigation

  1. Define top-level destinations from the application’s information architecture, not from a standard navigation template.

  2. Use bottom navigation only for a small set of frequently accessed, peer-level destinations.

  3. Do not create four or five bottom-navigation items merely because the layout permits them.

  4. Do not place actions in bottom navigation to fill an empty slot.

  5. Use tabs for closely related peer views within one context, not as a substitute for the application’s primary navigation.

  6. Keep tab labels concise, distinct, and meaningful.

  7. Do not combine bottom navigation, a drawer, top tabs, and prominent shortcut grids unless each serves a distinct, necessary level of navigation.

  8. Maintain predictable back behaviour and return users to the location and state from which they entered.

  9. Distinguish closing a temporary layer from navigating back in the content hierarchy.

 10. Preserve navigation state independently for top-level destinations where users reasonably expect to resume.

 11. Support deep links to durable content and handle missing authorization, expired content, and invalid destinations gracefully.

 12. Do not use breadcrumbs on ordinary phone layouts unless the hierarchy is unusually deep and breadcrumbs materially improve orientation.

 13. Provide visible screen titles or equivalent context so users know where they are.

 14. Avoid duplicate routes to the same destination when the alternatives create uncertainty rather than convenience.

 15. Do not hide critical destinations exclusively behind gestures or ambiguous icons.

 16. Ensure system back gestures and buttons behave according to platform expectations.

## Lists, Detail Screens, and Information Presentation

  1. Prefer a list over a collection of cards when users need to scan, compare, or act on repeated records.

  2. Use cards for repeated records only when each item contains meaningful internal structure, media, multiple actions, or independent grouping.

  3. Define a consistent row anatomy for primary text, secondary text, metadata, status, thumbnail, and actions.

  4. Adjust list density to the task without making tap targets too small.

  5. Use separators, spacing, or grouping consistently; do not combine all three without need.

  6. Keep the most discriminating information visible so users can distinguish similar records.

  7. Do not display every metadata value as a chip or coloured label.

  8. Place infrequent row actions in a contextual menu rather than displaying a toolbar of icons on every row.

  9. Use swipe actions only for familiar, reversible, high-frequency actions and provide a visible alternative.

 10. Group lists only when grouping supports scanning, chronology, ownership, or status understanding.

 11. Define loading, empty, error, pagination, refresh, and end-of-list behaviour.

 12. Preserve list filters, sort order, search query, and scroll position after viewing a detail page.

 13. Structure detail pages around the user’s questions and decisions, not by placing every field in a separate card.

 14. Group related detail fields through headings, spacing, alignment, and definition-list patterns.

 15. Reveal secondary metadata progressively when showing everything would impair scanning.

 16. Keep important actions attached to the current record and reflect whether each action is available in its present state.

 17. Support long descriptions, missing values, failed media, and unusually large values without breaking alignment.

## Statuses, Chips, Badges, and Tags

  1. Define one canonical label and meaning for every business-process status.

  2. Do not use different terms for the same status across lists, details, notifications, and actions.

  3. Use a badge when a compact value or status must be noticed quickly.

  4. Use a chip when the element represents a selectable filter, removable value, input token, or compact interactive choice.

  5. Use plain text when the status or metadata does not require special prominence.

  6. Use icon-and-text treatment when an icon materially improves recognition and the text preserves clarity.

  7. Do not turn every metadata value into a pill.

  8. Do not use decorative tags that imply state, categorization, or interactivity without providing it.

  9. Map status colours to semantic meaning consistently and keep the palette restrained.

 10. Pair status colour with a readable label and, where useful, an icon.

 11. Distinguish status from the action that changes it.

 12. Use contextual messages rather than badges when a state requires explanation or recovery instructions.

## Dashboards, Home Screens, Statistics, and Quick Actions

  1. Define the home screen from the user’s highest-priority recurring needs rather than from a standard dashboard formula.

  2. Do not assume the home screen requires a greeting, hero card, KPI row, quick-action grid, recent activity, banner, or bottom navigation.

  3. Add a greeting only when personalization or time-sensitive context benefits the user.

  4. Add statistics only when users need them to understand performance, risk, workload, progress, or required action.

  5. Ensure every metric answers a real user question and has a clear definition, scope, time range, and data source.

  6. Do not display decorative numbers merely because data is available.

  7. Use charts only when they communicate comparison, trend, distribution, composition, or relationship more effectively than text or a simple value.

  8. Do not use progress rings for values that are not meaningful progress toward a defined target.

  9. Add quick actions only for frequent, high-value actions that users genuinely need to start from the home screen.

 10. Do not duplicate primary navigation destinations in a quick-action grid without a demonstrated usability benefit.

 11. Show recent activity only when reviewing or resuming activity is an actual user task.

 12. Do not add promotional banners, tips, recommendations, or announcements without supported content, ownership, lifecycle, and dismissal rules.

 13. Keep dashboards focused on decisions and next actions rather than filling a grid with equally weighted cards.

 14. Provide definitions and drill-down paths when summarized information could otherwise be misunderstood.

## Empty, Loading, Error, Success, and Offline States

  1. Design states as part of each component and workflow rather than as a final polish step.

  2. Distinguish first-use emptiness, genuinely empty data, filtered emptiness, search with no results, unavailable data, and loading failure.

  3. Explain why content is absent and provide the most relevant next action when one exists.

  4. Do not use a large illustration for every empty state; use imagery only when it improves comprehension, identity, or tone.

  5. Match loading feedback to expected duration and scope.

  6. Use local loading indicators for local operations and page-level indicators only when the whole page is unavailable.

  7. Use skeletons only when the approximate content structure is known and their presence reduces perceived uncertainty.

  8. Do not use skeletons for brief actions, unpredictable layouts, or content that may never load.

  9. Avoid blocking the entire interface when unaffected content and actions can remain usable.

 10. Preserve visible content during refresh when stale data remains safe to show.

 11. Distinguish network failure, server failure, validation failure, permission denial, authentication expiry, and unavailable services.

 12. Write errors that state what happened, what was preserved, and what the user can do next.

 13. Provide retry only when retrying can reasonably succeed.

 14. Preserve user context and entered data after recoverable errors.

 15. Handle partial failure at the affected component or item rather than replacing an otherwise usable page with a generic error screen.

 16. Define offline behaviour for reading, creating, editing, synchronizing, and resolving conflicts where offline use is supported.

 17. Make pending synchronization and unsynchronized changes visible without causing unnecessary alarm.

 18. Acknowledge successful consequential actions clearly and show the resulting state or next step.

 19. Do not present a full-screen celebration, giant checkmark, confetti, or exaggerated animation for trivial actions.

 20. Use transient feedback for minor reversible actions and persistent confirmation for consequential changes.

 21. Avoid generic “Success!” and “Oops!” messages when a specific outcome can be stated.

## Dialogs, Sheets, Menus, and Confirmations

  1. Use a dialog only when the user must address a short, blocking decision before proceeding.

  2. Do not use a modal for content that requires extensive reading, scrolling, navigation, or multi-step entry.

  3. Do not stack dialogs, sheets, or menus on top of one another.

  4. Dismiss temporary layers predictably and preserve any entered data when accidental dismissal is plausible.

  5. Use confirmation only when an action is destructive, irreversible, costly, privacy-sensitive, safety-sensitive, or has significant workflow consequences.

  6. Do not ask “Are you sure?” for low-risk reversible actions; perform the action and offer undo where appropriate.

  7. State the specific action and consequence in confirmation copy.

  8. Name destructive confirmation buttons after the destructive action rather than using “Yes” or “OK.”

  9. Use menus for secondary contextual actions, not for the screen’s principal action.

 10. Use bottom sheets for compact contextual choices and actions that benefit from keeping the underlying screen visible.

 11. Escalate a sheet to a full page when the content becomes complex, stateful, deeply navigable, or keyboard-heavy.

## Content and Microcopy

  1. Use the vocabulary users and the underlying business process use.

  2. Define canonical names for entities, statuses, actions, and workflow stages and use them consistently.

  3. Write concise labels and instructions that state what the user needs to know or do.

  4. Use specific verbs that describe the outcome of an action.

  5. Do not place a descriptive subtitle beneath every screen title or section heading.

  6. Include supporting copy only when it reduces uncertainty, prevents error, explains consequence, or supplies essential context.

  7. Remove repeated explanations that the layout, label, or current state already makes clear.

  8. Avoid generic AI-style phrases, artificial friendliness, motivational filler, and unnecessary reassurance.

  9. Avoid excessive exclamation marks and celebratory language.

 10. Do not use “Oops,” “Great job,” or “Success” when neutral, precise language better fits the context.

 11. Write error messages in plain language without exposing implementation details.

 12. Do not blame the user for invalid input or failed operations.

 13. Distinguish instructions, explanations, warnings, and errors through wording and presentation.

 14. Use conventional English Title Case for authored headings and button labels, including dialogs, sheets and loading actions. Keep short articles, conjunctions and prepositions lowercase unless first or last (for example, “Request a Service” and “Welcome to Weyonje”). Preserve acronyms, proper names, user-entered text and API values. Body text, field labels, help and validation text retain sentence case. Do not introduce runtime title casing.

 15. Test microcopy with realistic names, quantities, dates, status labels, and localized text.

## Interaction Design

  1. Provide immediate visible feedback for taps, selections, toggles, submissions, and other state-changing actions.

  2. Define default, pressed, focused, hovered where relevant, selected, disabled, loading, error, and completed states for interactive components.

  3. Keep interaction behaviour consistent across equivalent components and workflows.

  4. Make selected states visually distinct without relying solely on colour.

  5. Use optimistic updates only when failure is unlikely, reversal is safe, and rollback can be communicated clearly.

  6. Prevent duplicate submissions and communicate when an operation is already in progress.

  7. Preserve context while asynchronous work completes whenever the user can safely continue.

  8. Use gestures only when they are familiar, discoverable, and backed by a visible alternative for important actions.

  9. Do not make destructive actions depend solely on gestures.

 10. Offer undo for reversible actions where accidental activation is plausible.

 11. Delay irreversible commitment until the user has reviewed consequential information where necessary.

 12. Prevent accidental activation through adequate spacing, touch targets, confirmation proportional to risk, and safe placement.

 13. Do not move controls unexpectedly while the user is interacting with them.

 14. Make latency visible when silence could lead users to repeat an action or assume failure.

 15. Announce dynamically updated content to assistive technologies without overwhelming users.

 16. Ensure state transitions preserve a clear causal relationship between the user’s action and the resulting change.

## Motion and Animation

  1. Use motion only to communicate hierarchy, navigation, causality, continuity, state change, or feedback.

  2. Do not add animation merely to make the application appear premium.

  3. Avoid unnecessary bouncing, pulsing, parallax, scale effects, and decorative looping motion.

  4. Keep routine transitions brief and subordinate to task completion.

  5. Do not animate every card, list item, icon, and heading on page entry.

  6. Maintain spatial continuity when opening details, expanding content, or changing navigation layers.

  7. Avoid motion that delays interaction or blocks repeated work.

  8. Respect reduced-motion preferences and provide a functionally equivalent experience without nonessential animation.

  9. Ensure loading animation does not imply determinate progress unless actual progress is known.

## Accessibility

  1. Treat accessibility requirements as design and implementation constraints from the first component.

  2. Meet applicable contrast requirements for text, icons, controls, borders conveying meaning, focus indicators, and disabled states.

  3. Ensure every interactive target meets platform-appropriate minimum touch dimensions and spacing.

  4. Provide semantic roles, names, values, states, and hints for assistive technologies.

  5. Label icon-only controls with meaningful accessible names.

  6. Define a logical screen-reader and keyboard focus order matching the visual and task sequence.

  7. Move focus deliberately after navigation, dialog opening, validation failure, and significant dynamic updates.

  8. Support text scaling without clipping, overlap, hidden actions, or inaccessible horizontal scrolling.

  9. Do not encode meaning through colour, position, animation, or shape alone.

 10. Associate validation errors programmatically with their fields and announce them appropriately.

 11. Ensure custom controls expose the same semantics and interaction affordances as equivalent native controls.

 12. Provide visible focus indicators for keyboard and switch-device interaction where relevant.

 13. Respect reduced-motion, increased-contrast, bold-text, and other supported accessibility preferences.

 14. Ensure disabled controls remain identifiable and do not become illegibly faint.

 15. Provide accessible alternatives for gestures, charts, images containing information, and time-limited interactions.

 16. Test core workflows with screen readers, large text, colour-vision deficiencies, reduced motion, and limited dexterity assumptions.

## Platform Conventions

  1. Respect the navigation, back behaviour, gestures, system bars, safe areas, and keyboard conventions of each target platform.

  2. Do not force identical iOS and Android behaviour when native conventions differ materially.

  3. Use platform-standard permission flows and explain the benefit immediately before requesting a non-obvious permission.

  4. Do not request permissions before the user initiates a feature requiring them.

  5. Provide a useful path when permission is denied, permanently denied, restricted, or later revoked.

  6. Use platform-appropriate controls for dates, times, selections, menus, sharing, and system actions when they improve familiarity and accessibility.

  7. Avoid overriding system gestures with conflicting custom gestures.

  8. Handle Android system back and predictive-back behaviour consistently with the navigation hierarchy.

  9. Handle iOS edge-swipe and modal dismissal without causing unexpected data loss.

 10. Keep content clear of notches, status bars, navigation indicators, gesture regions, and display cut-outs.

 11. Integrate keyboard appearance, dismissal, focus movement, and inset adjustment into form layouts.

 12. Match system-bar appearance to the active surface while preserving contrast.

## Design Systems and Component Architecture

  1. Define tokens for colour, typography, spacing, radius, border, elevation, opacity, motion, and component sizing.

  2. Use semantic token names that describe purpose rather than appearance.

  3. Use a restrained spacing scale and require layouts to use scale values except where a documented exception is necessary.

  4. Define named typography styles and prohibit arbitrary per-screen type values.

  5. Define a small corner-radius scale and assign radii consistently by component role.

  6. Define elevation levels by behaviour and layering rather than by visual preference.

  7. Document each reusable component’s anatomy, variants, states, behaviour, content constraints, and accessibility semantics.

  8. Implement complete component states before reusing the component across production workflows.

  9. Avoid creating duplicate components that differ only by minor styling.

 10. Consolidate near-identical components when their semantics and behaviour are the same.

 11. Keep components flexible enough to support realistic text lengths, optional content, validation, loading, and accessibility scaling.

 12. Do not make components so configurable that their visual and behavioural rules become unenforceable.

 13. Minimize one-off styling and record justified exceptions.

 14. Separate semantic consistency from structural sameness; reuse tokens and behaviours while allowing page composition to fit the task.

 15. Apply changes through shared tokens and components when the intended effect is application-wide.

 16. Do not modify a shared component for one screen in a way that silently changes unrelated workflows.

 17. Review new components against existing patterns before adding them to the system.

## Responsive and Device-Aware Design

  1. Design from the supported device range rather than from one idealized viewport.

  2. Test every core screen on small phones, large phones, and tablets where tablets are supported.

  3. Adapt layout structure at meaningful breakpoints rather than merely stretching widths and gaps.

  4. Constrain readable content widths on large screens.

  5. Use additional tablet space to improve comparison, navigation, or simultaneous context—not to inflate cards and typography.

  6. Define portrait and landscape behaviour where orientation changes are supported.

  7. Account for safe areas, system insets, foldable hinges where supported, and transient system UI.

  8. Ensure the keyboard does not cover focused fields, validation messages, suggestions, or submission controls.

  9. Keep focused fields visible as the keyboard opens and closes.

 10. Test layouts with the shortest and longest expected localized strings.

 11. Support dynamic text sizes without assuming fixed component heights.

 12. Define wrapping, truncation, overflow, and expansion rules for every constrained text region.

 13. Preserve image intent across different aspect ratios and provide deterministic cropping behaviour.

 14. Avoid horizontal scrolling for ordinary text and forms; reserve it for content such as wide data sets where no clearer mobile representation exists.

 15. Ensure sticky headers, tabs, and actions do not consume an excessive portion of small screens.

## Real-World Data and Edge Cases

  1. Test every repeated-content design with zero items, one item, several items, and hundreds of items.

  2. Test names, identifiers, descriptions, and addresses at realistic maximum lengths.

  3. Test missing optional fields without displaying meaningless blank rows, separators, or placeholders.

  4. Distinguish “not provided,” “not applicable,” “unknown,” and “unavailable” where the difference matters.

  5. Test failed, missing, slow-loading, and unusually shaped images.

  6. Test slow networks, intermittent connectivity, request timeouts, and duplicate responses.

  7. Test expired sessions during viewing, entry, upload, submission, and payment-sensitive workflows.

  8. Preserve recoverable work when authentication must be renewed.

  9. Test denied and revoked permissions at every point where the feature depends on them.

 10. Represent partial completion, pending review, rejection, cancellation, expiry, and resubmission explicitly where supported by the workflow.

 11. Make rejection and cancellation reasons available when users need them to understand or recover.

 12. Prevent duplicate actions at both interface and transaction levels.

 13. Format unusually large, small, negative, or fractional numeric values without clipping or misleading abbreviation.

 14. Define timezone, locale, currency, number, date, and pluralization behaviour explicitly.

 15. Test accessibility text scaling together with localization and long real-world content.

 16. Handle services that are temporarily unavailable without offering actions that cannot succeed.

 17. Verify that stale, cached, partial, and synchronized data are represented honestly.

## Avoiding Stereotypical AI Composition

  1. Do not default to the combination of gradient header, personalized greeting, KPI cards, quick-action grid, and recent activity.

  2. Use any element from that combination only when individually justified by the product’s requirements and user decisions.

  3. Do not repeat pastel icon tile, title, and subtitle rows merely to make a page appear designed; use a list structure appropriate to the information.

  4. Do not place every section inside a rounded card or nest rounded cards inside one another.

  5. Do not assign an icon to every section, field, action, and status.

  6. Do not represent every state and metadata value as a coloured pill.

  7. Do not make every action a large full-width rounded button.

  8. Do not place explanatory subtitles beneath every title when the title and content already establish context.

  9. Do not add a large illustration to every empty, error, permission, or onboarding state.

 10. Do not use giant checkmarks or celebratory screens for routine successful actions.

 11. Do not add analytics to home screens whose users have no supported analytical task.

 12. Do not convert every workflow into a numbered wizard.

 13. Do not apply the same header-card-grid-section pattern to every page.

 14. Do not populate bottom navigation with four or five items merely to imitate common application layouts.

 15. Do not combine gradients, glass effects, blobs, heavy shadows, oversized radii, and floating surfaces to manufacture visual sophistication.

 16. Do not use uniform visual softness—pastels, rounded containers, faint borders, and low contrast—when the task requires precision, density, or strong hierarchy.

 17. Do not use excessive symmetry when differences in priority, frequency, or content should shape the composition.

 18. Do not add decorative statistics, progress indicators, charts, badges, or banners to fill empty space.

 19. Require every visually distinctive treatment to express brand, meaning, state, interaction, hierarchy, or content.

 20. Remove any element whose absence does not materially reduce usability, comprehension, task completion, necessary feedback, or intentional brand expression.

 21. Review screens together as complete workflows to detect repetitive compositions, inconsistent behaviour, and accumulated decoration that may not be obvious when screens are reviewed separately.

 22. Validate the final interface with realistic data, all component states, supported roles, platform conventions, accessibility settings, and complete end-to-end workflows.


### Adopted Provider Registration Exception — 2026-09-11

Use exact Service Provider Sign In welcome/destination labels and the shared phone OTP flow. Service Provider Registration authored field/section/choice/action labels use Title Case, preserving ESS/KCCA and Required/Optional indicators. Keep KCCA Approval Required in the semantic red token with no subtitle; this is informational, not a blocking validation error. Password controls are removed. These scoped changes supersede earlier Provider email/password presentation guidance; KCCA presentation remains password-based.
