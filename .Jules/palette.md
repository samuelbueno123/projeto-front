## 2024-10-24 - Tooltips on IconButtons
**Learning:** Icon-only buttons without tooltips lack context for screen readers.
**Action:** Always add descriptive tooltips to IconButton widgets.
## 2024-10-26 - Added Autofill Hints and Password Visibility Toggle
**Learning:** Adding autofill hints and password visibility toggles dramatically improves the UX for authentication forms, particularly on mobile or web interfaces where typing errors in obscured fields are common. Ensuring the toggle button has a `tooltip` guarantees the functionality is accessible to screen readers.
**Action:** Always include `autofillHints` for standard form fields (name, email, password) and consider providing a visibility toggle with proper accessibility labels for password fields.
