# Dark Theme CSS Patterns for VPN Tools

## User Feedback
"حالت شب بجز رنگ متن ها رنگ چیزهای دیگه خیلی روشن"
(Translation: "In dark mode, besides text colors, other element colors are too bright")

## Core Principle
In dark themes, keep ALL non-text elements (borders, backgrounds, shadows, orbs) at very low opacity. Only text should be clearly visible.

## CSS Variables
```css
body.dark {
  --bg: #0a0d12;           /* Very dark background */
  --bg-2: #080b0f;         /* Slightly darker */
  --fg: #d0ccc7;           /* Muted text (NOT pure white #fff) */
  --muted: #6b7179;        /* Dimmed text */
  --glass: rgba(255,255,255,.03);      /* Very subtle glass */
  --glass-brd: rgba(255,255,255,.06);  /* Barely visible borders */
}
```

## Element-Specific Opacity Values
| Element | Opacity | Background |
|---------|---------|------------|
| Background orbs | 0.08 - 0.20 | colored |
| Glass panels | 0.03 | white |
| Glass borders | 0.04 - 0.06 | white |
| Glass gradient overlay | 0.04 | white |
| Input fields | 0.03 | white |
| Input borders | 0.05 | white |
| Button glass | 0.02 | white |
| Button glass borders | 0.05 | white |
| Link rows | 0.02 | white |
| Link row borders | 0.04 | white |
| Info boxes | 0.04 | coral |
| Info box borders | 0.10 | coral |
| Result cards | 0.02 | white |
| Result card borders | 0.04 | white |
| Scrollbar thumb | 0.04 | white |
| Noise texture | 0.02 | SVG |
| Theme toggle button | 0.03 | white |
| Step number shadows | 0.15 | coral |

## Key Shadows
```css
/* Glass panels */
body.dark .glass {
  box-shadow: inset 0 1px 0 rgba(255,255,255,.05), 0 20px 50px -20px rgba(0,0,0,.8);
}

/* Primary buttons */
body.dark .btn-primary {
  box-shadow: 0 2px 12px rgba(225,90,76,.2);
}

/* Step numbers */
body.dark .sn {
  box-shadow: 0 2px 10px rgba(225,90,76,.15);
}

/* Theme toggle */
body.dark .theme-btn {
  box-shadow: 0 2px 8px rgba(0,0,0,.5);
}
```

## Comparison: Too Bright vs Correct
```css
/* ❌ TOO BRIGHT (old) */
body.dark { --bg: #14171c; --fg: #f3efea; --glass: rgba(255,255,255,.055); }
body.dark .orb.o1 { opacity: .55; }
body.dark .glass { box-shadow: var(--hi), var(--drop); }
body.dark .inp { background: rgba(255,255,255,.05); }
body.dark .btn-primary { box-shadow: 0 4px 20px var(--coral-glow); }

/* ✅ CORRECT (new) */
body.dark { --bg: #0a0d12; --fg: #d0ccc7; --glass: rgba(255,255,255,.03); }
body.dark .orb.o1 { opacity: .2; }
body.dark .glass { box-shadow: inset 0 1px 0 rgba(255,255,255,.05), 0 20px 50px -20px rgba(0,0,0,.8); }
body.dark .inp { background: rgba(255,255,255,.03); }
body.dark .btn-primary { box-shadow: 0 2px 12px rgba(225,90,76,.2); }
```

## Auto-Fill Field Rule
**NEVER use `readonly` on auto-filled inputs.** User must be able to edit them.
```html
<!-- ❌ WRONG: readonly prevents editing -->
<input id="cfgPanelUrl" type="text" class="inp" readonly>

<!-- ✅ CORRECT: editable but auto-filled -->
<input id="cfgPanelUrl" type="text" class="inp">
```
User said: "آدرس پنل هم خودکار پر بشه هم کاربر بتونه ادرس جدید بذاره"
(Translation: "Panel URL should auto-fill AND user should be able to enter a new address")
