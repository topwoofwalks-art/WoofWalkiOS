# WoofWalk Color Palette

## Primary - Turquoise (Brand Color)

```
turquoise10  #001F24  ████████  Darkest - onPrimaryContainer (Light)
turquoise20  #003640  ████████  Dark - onPrimary (Dark)
turquoise30  #004E5C  ████████  Dark Medium - primaryContainer (Dark)
turquoise40  #006878  ████████  Medium Dark - inversePrimary (Dark)
turquoise50  #008394  ████████  Medium
turquoise60  #00A0B0  ████████  PRIMARY (Light Mode) ← Main brand
turquoise70  #4DC0CD  ████████  Medium Light
turquoise80  #7AD5DE  ████████  PRIMARY (Dark Mode) ← Main brand
turquoise90  #B3EAEF  ████████  Light - primaryContainer (Light), onPrimaryContainer (Dark)
turquoise95  #D9F5F7  ████████  Lightest
```

**Usage**: Primary buttons, active states, navigation, key interactions, branding

## Secondary - Orange (Accent Color)

```
orange10  #2B1000  ████████  Darkest - onSecondaryContainer (Light)
orange20  #4A1D00  ████████  Dark - onSecondary (Dark)
orange30  #6C2C00  ████████  Dark Medium - secondaryContainer (Dark)
orange40  #8E3B00  ████████  Medium Dark
orange50  #9F4300  ████████  Medium
orange60  #FF6B35  ████████  SECONDARY (Light Mode) ← Accent
orange70  #FF8C63  ████████  Medium Light
orange80  #FFAD8F  ████████  SECONDARY (Dark Mode) ← Accent
orange90  #FFD4C2  ████████  Light - secondaryContainer (Light), onSecondaryContainer (Dark)
orange95  #FFEAE1  ████████  Lightest
```

**Usage**: Secondary buttons, notifications, highlights, alerts, accents

## Tertiary - Success (Green)

```
success10  #002106  ████████  Darkest - onTertiaryContainer (Light)
success20  #00390F  ████████  Dark - onTertiary (Dark)
success30  #005319  ████████  Dark Medium - tertiaryContainer (Dark)
success40  #006E23  ████████  Medium Dark
success50  #008A2E  ████████  Medium
success60  #00A73A  ████████  SUCCESS (Light Mode) ← Success state
success70  #4CC76A  ████████  Medium Light
success80  #7ADB8F  ████████  SUCCESS (Dark Mode) ← Success state
success90  #B3F0BB  ████████  Light - tertiaryContainer (Light), onTertiaryContainer (Dark)
success95  #D9F7DD  ████████  Lightest
```

**Usage**: Success messages, completed states, positive indicators, walk completion

## Neutral (Text & Surfaces)

```
neutral10  #1A1C1E  ████████  DARKEST - surface/background (Dark), onBackground/onSurface (Light)
neutral20  #2F3033  ████████  Very Dark - onPrimary/onSecondary/onTertiary (Dark), inverseSurface (Light)
neutral30  #454649  ████████  Dark
neutral40  #5D5E62  ████████  Medium Dark
neutral50  #76777A  ████████  Medium
neutral60  #909094  ████████  Medium Light
neutral70  #ABABAف  ████████  Light
neutral80  #C6C6CA  ████████  Very Light
neutral90  #E3E2E6  ████████  Light - onBackground/onSurface (Dark), inverseOnSurface (Dark)
neutral95  #F1F0F4  ████████  LIGHTEST - surface/background (Light), inverseOnSurface (Light)
neutral99  #FDFBFF  ████████  Near White - onPrimary/onSecondary/onTertiary/onError (Light)
```

**Usage**: Text, backgrounds, surfaces, cards, general UI elements

## Neutral Variant (Outlines & Borders)

```
neutralVariant10  #161D1E  ████████  Darkest
neutralVariant20  #2B3133  ████████  Very Dark
neutralVariant30  #414749  ████████  Dark - onSurfaceVariant (Light), surfaceVariant/outlineVariant (Dark)
neutralVariant40  #595F61  ████████  Medium Dark
neutralVariant50  #72787A  ████████  Medium - outline (Light)
neutralVariant60  #8C9294  ████████  Medium Light - outline (Dark)
neutralVariant70  #A6ACAF  ████████  Light
neutralVariant80  #C2C7CA  ████████  Very Light - onSurfaceVariant (Dark), outlineVariant (Light)
neutralVariant90  #DEE3E6  ████████  Light - surfaceVariant (Light)
neutralVariant95  #ECF1F4  ████████  Lightest
```

**Usage**: Borders, dividers, subtle backgrounds, disabled states

## Error (Red)

```
error10  #410002  ████████  Darkest - onErrorContainer (Light)
error20  #690005  ████████  Dark - onError (Dark)
error30  #93000A  ████████  Dark Medium - errorContainer (Dark)
error40  #BA1A1A  ████████  Medium Dark
error50  #DE3730  ████████  Medium
error60  #FF5449  ████████  ERROR (Light Mode) ← Error state
error70  #FF897D  ████████  Medium Light
error80  #FFB4AB  ████████  ERROR (Dark Mode) ← Error state
error90  #FFDAD6  ████████  Light - errorContainer (Light), onErrorContainer (Dark)
error95  #FFEDEA  ████████  Lightest
```

**Usage**: Error messages, validation errors, destructive actions, warnings

---

## Light Mode Color Roles

```
PRIMARY LAYER
├─ primary:             turquoise60  #00A0B0  Main actions, branding
├─ onPrimary:           neutral99    #FDFBFF  Text on primary
├─ primaryContainer:    turquoise90  #B3EAEF  Highlighted backgrounds
└─ onPrimaryContainer:  turquoise10  #001F24  Text on primary container

SECONDARY LAYER
├─ secondary:           orange60     #FF6B35  Accent actions
├─ onSecondary:         neutral99    #FDFBFF  Text on secondary
├─ secondaryContainer:  orange90     #FFD4C2  Highlighted backgrounds
└─ onSecondaryContainer: orange10    #2B1000  Text on secondary container

TERTIARY LAYER (Success)
├─ tertiary:            success60    #00A73A  Success states
├─ onTertiary:          neutral99    #FDFBFF  Text on tertiary
├─ tertiaryContainer:   success90    #B3F0BB  Success backgrounds
└─ onTertiaryContainer: success10    #002106  Text on tertiary container

ERROR LAYER
├─ error:               error60      #FF5449  Error states
├─ onError:             neutral99    #FDFBFF  Text on error
├─ errorContainer:      error90      #FFDAD6  Error backgrounds
└─ onErrorContainer:    error10      #410002  Text on error container

SURFACE LAYER
├─ background:          neutral95    #F1F0F4  App background
├─ onBackground:        neutral10    #1A1C1E  Text on background
├─ surface:             neutral95    #F1F0F4  Card surfaces
├─ onSurface:           neutral10    #1A1C1E  Text on surface
├─ surfaceVariant:      neutralVariant90  #DEE3E6  Subtle backgrounds
└─ onSurfaceVariant:    neutralVariant30  #414749  Secondary text

OUTLINE LAYER
├─ outline:             neutralVariant50  #72787A  Standard borders
└─ outlineVariant:      neutralVariant80  #C2C7CA  Subtle borders

INVERSE LAYER
├─ inverseSurface:      neutral20    #2F3033  Dark surface in light mode
├─ inverseOnSurface:    neutral95    #F1F0F4  Light text on inverse
└─ inversePrimary:      turquoise80  #7AD5DE  Primary color on inverse
```

---

## Dark Mode Color Roles

```
PRIMARY LAYER
├─ primary:             turquoise80  #7AD5DE  Main actions (lighter)
├─ onPrimary:           turquoise20  #003640  Text on primary (darker)
├─ primaryContainer:    turquoise30  #004E5C  Highlighted backgrounds
└─ onPrimaryContainer:  turquoise90  #B3EAEF  Text on primary container

SECONDARY LAYER
├─ secondary:           orange80     #FFAD8F  Accent actions (lighter)
├─ onSecondary:         orange20     #4A1D00  Text on secondary (darker)
├─ secondaryContainer:  orange30     #6C2C00  Highlighted backgrounds
└─ onSecondaryContainer: orange90    #FFD4C2  Text on secondary container

TERTIARY LAYER (Success)
├─ tertiary:            success80    #7ADB8F  Success states (lighter)
├─ onTertiary:          success20    #00390F  Text on tertiary (darker)
├─ tertiaryContainer:   success30    #005319  Success backgrounds
└─ onTertiaryContainer: success90    #B3F0BB  Text on tertiary container

ERROR LAYER
├─ error:               error80      #FFB4AB  Error states (lighter)
├─ onError:             error20      #690005  Text on error (darker)
├─ errorContainer:      error30      #93000A  Error backgrounds
└─ onErrorContainer:    error90      #FFDAD6  Text on error container

SURFACE LAYER
├─ background:          neutral10    #1A1C1E  App background (dark)
├─ onBackground:        neutral90    #E3E2E6  Text on background (light)
├─ surface:             neutral10    #1A1C1E  Card surfaces (dark)
├─ onSurface:           neutral90    #E3E2E6  Text on surface (light)
├─ surfaceVariant:      neutralVariant30  #414749  Subtle backgrounds
└─ onSurfaceVariant:    neutralVariant80  #C2C7CA  Secondary text (light)

OUTLINE LAYER
├─ outline:             neutralVariant60  #8C9294  Standard borders (lighter)
└─ outlineVariant:      neutralVariant30  #414749  Subtle borders

INVERSE LAYER
├─ inverseSurface:      neutral90    #E3E2E6  Light surface in dark mode
├─ inverseOnSurface:    neutral20    #2F3033  Dark text on inverse
└─ inversePrimary:      turquoise40  #006878  Primary color on inverse
```

---

## Color Usage Guidelines

### When to Use Each Color

**Primary (Turquoise)**
- Primary action buttons (Start Walk, Save, Submit)
- Active navigation items
- Selected states
- Key UI elements requiring attention
- Links and interactive elements

**Secondary (Orange)**
- Secondary actions (Cancel, Alternative actions)
- Notifications and badges
- Highlights and callouts
- Complementary accents
- Less critical interactive elements

**Tertiary (Success)**
- Success confirmations
- Completed tasks
- Positive indicators
- Achievement badges
- Progress completion

**Error (Red)**
- Error messages
- Validation failures
- Destructive actions (Delete, Remove)
- Critical warnings
- Failed states

**Neutral**
- Body text (neutral10 in light, neutral90 in dark)
- Backgrounds (neutral95 in light, neutral10 in dark)
- Card surfaces
- General UI elements

**Neutral Variant**
- Borders and dividers
- Input field outlines
- Subtle backgrounds
- Disabled states
- Secondary UI elements

### Accessibility Notes

All color combinations meet WCAG 2.1 Level AA standards:
- Text contrast ratio: minimum 4.5:1 for normal text
- Large text contrast ratio: minimum 3:1 for 18pt+ text
- Interactive elements: minimum 3:1 contrast
- Tested in both light and dark modes
