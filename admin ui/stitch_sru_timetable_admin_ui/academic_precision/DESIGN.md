---
name: Academic Precision
colors:
  surface: '#fbf8fa'
  surface-dim: '#dcd9db'
  surface-bright: '#fbf8fa'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f5f3f4'
  surface-container: '#f0edef'
  surface-container-high: '#eae7e9'
  surface-container-highest: '#e4e2e3'
  on-surface: '#1b1b1d'
  on-surface-variant: '#45474c'
  inverse-surface: '#303032'
  inverse-on-surface: '#f3f0f2'
  outline: '#75777d'
  outline-variant: '#c5c6cd'
  surface-tint: '#545f73'
  primary: '#091426'
  on-primary: '#ffffff'
  primary-container: '#1e293b'
  on-primary-container: '#8590a6'
  inverse-primary: '#bcc7de'
  secondary: '#505f76'
  on-secondary: '#ffffff'
  secondary-container: '#d0e1fb'
  on-secondary-container: '#54647a'
  tertiary: '#1e1200'
  on-tertiary: '#ffffff'
  tertiary-container: '#35260c'
  on-tertiary-container: '#a38c6a'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d8e3fb'
  primary-fixed-dim: '#bcc7de'
  on-primary-fixed: '#111c2d'
  on-primary-fixed-variant: '#3c475a'
  secondary-fixed: '#d3e4fe'
  secondary-fixed-dim: '#b7c8e1'
  on-secondary-fixed: '#0b1c30'
  on-secondary-fixed-variant: '#38485d'
  tertiary-fixed: '#fadfb8'
  tertiary-fixed-dim: '#ddc39d'
  on-tertiary-fixed: '#271902'
  on-tertiary-fixed-variant: '#564427'
  background: '#fbf8fa'
  on-background: '#1b1b1d'
  surface-variant: '#e4e2e3'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-sm:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  container-padding-mobile: 1rem
  container-padding-desktop: 2rem
  gutter: 1.5rem
  stack-sm: 0.5rem
  stack-md: 1rem
  stack-lg: 1.5rem
---

## Brand & Style

This design system is built for a high-performance academic environment. The brand personality is **Professional, Academic, and Fast**, prioritizing clarity of information over decorative elements. 

The visual style follows a **Corporate / Modern** aesthetic with a lean towards **Minimalism**. It utilizes a systematic approach to whitespace and hierarchy to ensure that complex timetable data remains legible and actionable. The interface should feel like a high-end tool—unobtrusive, reliable, and efficient.

- **Minimalism:** Heavy focus on whitespace to reduce cognitive load in data-dense views.
- **Precision:** Perfect alignment and consistent mathematical spacing.
- **Reliability:** A sober, navy-led palette that evokes traditional institutional trust.

## Colors

The palette is anchored by a deep Navy Primary (`#1E293B`), providing a strong sense of authority and readability. The background uses a very light cool gray to differentiate from white surface cards, reducing glare during long periods of use.

- **Primary:** Used for navigation, primary actions, and key headers.
- **Secondary:** Used for supporting text, icons, and non-critical interactive elements.
- **Functional (Success/Warning/Error):** Reserved strictly for status indicators, validation, and system feedback.
- **Surface:** Pure white is reserved for content containers (cards, modals, inputs) to create a clear "layer" above the background.

## Typography

This design system uses **Inter** for all roles. It is a highly legible, systematic sans-serif that excels in user interfaces and data-heavy tables.

- **Headlines:** Use semi-bold weights with slight negative letter spacing to feel tight and professional.
- **Body:** Standardized at 16px for optimal readability. Use `body-sm` (14px) for secondary metadata and table cell content.
- **Labels:** Use `label-sm` with uppercase transformation for category headers or small UI tags to provide visual contrast without increasing size.

## Layout & Spacing

The layout utilizes a **12-column fluid grid** for desktop and a **single-column vertical stack** for mobile. 

- **Grid:** On desktop, use a 24px (1.5rem) gutter. Sidebars should be fixed at 280px, while the main content area expands.
- **Rhythm:** All spacing is based on a 4px baseline grid. Use `stack-md` (16px) for the majority of internal card padding and `stack-lg` (24px) for spacing between major sections.
- **Density:** For data tables, use a "Compact" vertical padding of 12px to allow more rows to be visible above the fold.

## Elevation & Depth

Hierarchy is established through **Tonal Layers** and **Low-contrast Outlines**. 

- **Level 0 (Background):** `#F8FAFC` - The lowest layer.
- **Level 1 (Surface):** `#FFFFFF` - Primary container layer. Uses a 1px solid border of `#E2E8F0` and a very soft, diffused shadow (`0 1px 3px 0 rgba(0, 0, 0, 0.05)`).
- **Level 2 (Popovers/Modals):** Elevated with a more pronounced shadow (`0 10px 15px -3px rgba(0, 0, 0, 0.1)`) to indicate temporary interaction.

Avoid heavy shadows or dark glows. Depth should feel natural and light, mimicking paper layers.

## Shapes

The design system uses a **Rounded** shape language to soften the professional tone and make the interface feel modern and accessible.

- **Small Components:** Checkboxes and small tags use `rounded-sm` (4px).
- **Standard Components:** Buttons and Input fields use `rounded-md` (8px).
- **Containers:** Dashboard cards and modals use `rounded-lg` (16px) to clearly define content areas.
- **Status Pills:** Success/Warning tags use a full pill shape for distinct visual categorisation.

## Components

### Buttons
- **Primary:** Solid `#1E293B` with white text. 8px border-radius.
- **Secondary:** White background with `#E2E8F0` border and `#1E293B` text.
- **Ghost:** No background or border; used for secondary actions in headers.

### Input Fields
- Height: 40px. 
- Border: 1px solid `#E2E8F0`. 
- Focus State: 1px solid `#1E293B` with a soft 3px outer glow in the primary color at 10% opacity.

### Cards
- Background: `#FFFFFF`.
- Border: 1px solid `#E2E8F0`.
- Padding: 24px for desktop, 16px for mobile.
- Corner Radius: 16px.

### Status Chips (Badges)
- Used for "Online", "Pending", or "Full". 
- Styling: Light tinted background (10% opacity of the functional color) with high-contrast text of the same hue. 
- Shape: Full pill (999px radius).

### Data Tables
- Row Height: 56px.
- Header: `#F8FAFC` background with `label-sm` typography.
- Divider: 1px horizontal line in `#F1F5F9`.