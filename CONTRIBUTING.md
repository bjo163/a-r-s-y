# Contributing to A-R-S-Y

- main is the stable branch; pushes run CI only and never deploy to the VPS.
- dev is the integration branch when active development begins.
- Use feat/<scope>-<short-name>, fix/<scope>-<short-name>, and chore/<scope>-<short-name> branches.
- Use Conventional Commits and SemVer for releases.
- A release only makes a version available; installation always requires operator consent.
- Do not commit secrets, .env, private keys, provider credentials, or production data.
- Include tests, security impact, operational documentation, and rollback notes for behavior changes.
- Keep upstream engines behind replaceable adapters; do not fork upstream code by default.
- Review source, edition, plugins, image contents, and transitive dependency licenses before adding runtime dependencies.
