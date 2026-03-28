# Project Todos

> ⚠️ **AUTO-GENERATED WARNINGS** — Review and address these issues

---

## ⚠️ CrosshairSettings Naming Collision

**Status**: Pre-existing repository dirt (NOT part of system-issue-remediation scope)

**Issue**: A file or class named `CrosshairSettings` exists in the repository. This naming may conflict with:
- Future `Settings` system expansion
- Potential naming ambiguity with other "Settings" related classes

**Action Required**:
- [ ] Audit repository for `CrosshairSettings` usage
- [ ] Determine if naming should be refactored to `CrosshairConfiguration` or similar
- [ ] Check for any actual runtime conflicts or if this is just hygiene

**Related Context**: This was discovered during the system-issue-remediation work but was determined to be pre-existing dirt unrelated to the remediation scope. User explicitly noted: "警告写入project_todos.md" (Write warning to project_todos.md).

---

*Last updated: 2026-03-28*
