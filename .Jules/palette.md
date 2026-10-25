## 2024-10-24 - Tooltips on IconButtons
**Learning:** Icon-only buttons without tooltips lack context for screen readers.
**Action:** Always add descriptive tooltips to IconButton widgets.

## 2024-11-20 - Password Visibility and Autofill Hints
**Learning:** Hardcoded `obscureText: true` on password fields hinders UX because users cannot verify their input. Lacking autofill hints prevents password managers from easily populating forms.
**Action:** Always provide an IconButton to toggle password visibility (with descriptive tooltips for accessibility) and add appropriate `autofillHints` (like `AutofillHints.email`, `AutofillHints.password`, `AutofillHints.newPassword`, `AutofillHints.name`) to `TextFormField`s to help password managers.
