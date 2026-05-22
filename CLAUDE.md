# Cadence — Claude Code Notes

## Chatbot system prompt (`api/help.js`)

Whenever a feature is added, renamed, or removed from the app, update the chatbot system prompt in `api/help.js` to match.

Things that always need a prompt update:
- New buttons or UI labels visible to students or teachers
- Renamed actions or navigation items
- New sections, tabs, or modals
- Changed workflows (e.g. grading, exporting, class management)
- Removed features

Keep the prompt in sync with `js/app.js` and any HTML page changes. After updating `api/help.js`, commit it in the same PR or as a follow-up on the same branch.
