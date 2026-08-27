---
name: Academic Precision
colors:
  surface: '#f9f9ff'
  surface-dim: '#d3daef'
  surface-bright: '#f9f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f1f3ff'
  surface-container: '#e9edff'
  surface-container-high: '#e1e8fd'
  surface-container-highest: '#dce2f7'
  on-surface: '#141b2b'
  on-surface-variant: '#424751'
  inverse-surface: '#293040'
  inverse-on-surface: '#edf0ff'
  outline: '#727782'
  outline-variant: '#c2c6d2'
  surface-tint: '#265ea6'
  primary: '#003870'
  on-primary: '#ffffff'
  primary-container: '#0b4f96'
  on-primary-container: '#9fc3ff'
  inverse-primary: '#a8c8ff'
  secondary: '#585f6c'
  on-secondary: '#ffffff'
  secondary-container: '#dce2f3'
  on-secondary-container: '#5e6572'
  tertiary: '#5f2900'
  on-tertiary: '#ffffff'
  tertiary-container: '#823b00'
  on-tertiary-container: '#ffaf7f'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d5e3ff'
  primary-fixed-dim: '#a8c8ff'
  on-primary-fixed: '#001b3c'
  on-primary-fixed-variant: '#00468a'
  secondary-fixed: '#dce2f3'
  secondary-fixed-dim: '#c0c7d6'
  on-secondary-fixed: '#151c27'
  on-secondary-fixed-variant: '#404754'
  tertiary-fixed: '#ffdbc8'
  tertiary-fixed-dim: '#ffb68b'
  on-tertiary-fixed: '#321200'
  on-tertiary-fixed-variant: '#753400'
  background: '#f9f9ff'
  on-background: '#141b2b'
  surface-variant: '#dce2f7'
typography:
  display:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.02em
  headline:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-sm:
    fontFamily: Geist
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.02em
  mono-label:
    fontFamily: Geist
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.01em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  container-padding: 16px
  stack-gap: 12px
---

## Brand & Style

This design system is built for the SR University ecosystem, prioritizing clarity, academic focus, and effortless navigation. The aesthetic sits at the intersection of **Minimalism** and **Modern Corporate**, drawing inspiration from the high-fidelity utility of professional productivity tools.

The interface leverages high whitespace to reduce cognitive load, essential for dense scheduling information. It utilizes a "light-first" approach with a sophisticated, cool-toned palette that feels clean and expansive. The emotional response should be one of calm control—transforming a complex university schedule into an organized, legible, and premium digital experience.

## Colors

The palette is anchored by the **SRU Blue**, which is reserved strictly for high-intent actions, active states, and critical branding touchpoints. This ensures the primary brand color retains its impact without overwhelming the user during long periods of reading.

- **Backgrounds**: Use the soft cool-grey (#F7F9FC) for the main application canvas to differentiate from card surfaces.
- **Surfaces**: Pure white (#FFFFFF) is used for cards, sheets, and interactive modules to create a clear "layer" above the background.
- **Typography**: Primary text uses a deep ink-grey (#111827) for maximum legibility, while secondary text (#6B7280) handles metadata and captions.
- **Semantic States**: Success, Warning, and Error colors are applied with low-chroma backgrounds and high-chroma text/icons to maintain the refined, non-jarring aesthetic.

## Typography

The system employs **Inter** for its exceptional legibility and neutral character, ensuring that course titles and timings are easily scannable. **Geist** is introduced for labels and technical metadata (like room numbers or timestamps) to provide a subtle, developer-grade precision that aligns with the "Linear" aesthetic.

- **Scale**: Large titles (Display) should be used sparingly for screen headings.
- **Weight**: Use Semibold (600) for section headers to create clear vertical hierarchy.
- **Optimization**: On mobile devices, line-heights are kept tight to maximize the "above the fold" content of the timetable, while letter-spacing is slightly tightened on larger headings to maintain a premium feel.

## Layout & Spacing

This design system is built on a strict **8px grid**. All dimensions, padding, and margins must be multiples of 8 (or 4 for micro-adjustments).

- **Mobile Grid**: A fluid layout with a default horizontal margin of 16px (spacing.md).
- **Timetable Density**: Course cards within the timetable should use 12px (stack-gap) vertical spacing to balance information density with breathability.
- **Alignment**: All text elements should align to the 8px baseline grid to ensure a rhythmic, professional feel consistent with high-end productivity apps.

## Elevation & Depth

The system uses **Tonal Layering** combined with **Ambient Shadows** to define hierarchy.

- **Level 0 (Flat)**: Background surfaces (#F7F9FC). No shadow.
- **Level 1 (Subtle)**: Primary course cards and list items. 
  - *Shadow*: `0px 1px 3px rgba(0, 0, 0, 0.05), 0px 1px 2px rgba(0, 0, 0, 0.03)`
  - *Border*: 1px solid #E5E7EB
- **Level 2 (Floating)**: Active modals, bottom sheets, or "Current Class" highlights.
  - *Shadow*: `0px 10px 15px -3px rgba(0, 0, 0, 0.08), 0px 4px 6px -2px rgba(0, 0, 0, 0.03)`
- **Interactions**: On press, cards should visually "sink" by reducing the shadow spread and slightly dimming the background color, providing tactile feedback.

## Shapes

The shape language is "Soft-Modern." 

- **Primary Cards**: Use a `rounded-lg` (16px) radius to create a friendly, approachable container for information.
- **Buttons & Inputs**: Use a `rounded-md` (12px) radius.
- **Indicators/Tags**: Small status tags (e.g., "Lecture", "Lab") should use a 6px radius to distinguish them from larger interactive components.
- **Consistency**: Never use fully sharp corners. The soft radius is a core pillar of the "Apple-esque" aesthetic, ensuring the app feels modern and premium.

## Components

### Buttons
- **Primary**: SRU Blue background, white text, 12px radius. High-emphasis only.
- **Secondary**: Light gray background (#F3F4F6) with primary text. Used for less critical actions.
- **Ghost**: No background, SRU Blue text. Used for navigation or "View All" actions.

### Course Cards
- **Structure**: Surface white, 16px radius, Level 1 shadow.
- **Left Accent**: A 4px vertical bar on the left edge of the card, color-coded by course type or department.
- **Content**: Headline 18px for Course Name, Label 12px (Geist) for Room/Time.

### Input Fields
- **Style**: 1px border (#E5E7EB), 12px radius, minimal padding (12px 16px).
- **Focus**: Border color changes to SRU Blue with a subtle blue outer glow (2px).

### Navigation (Bottom Bar)
- **Visuals**: Pure white background, top border 1px (#E5E7EB), no shadow. 
- **Icons**: 24px modern line icons (2px stroke width). Active state uses SRU Blue; inactive uses Secondary Text.

### Chips & Tags
- **Appearance**: Small, low-contrast backgrounds (e.g., Success Green at 10% opacity) with high-contrast text. 
- **Usage**: Used for class status (e.g., "Ongoing", "Cancelled", "Rescheduled").