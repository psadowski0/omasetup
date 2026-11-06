# Adding a module

Omasetup is built from independent modules. Each module lives in
`modules/<name>/` and is a standalone tool. Omasetup will call modules through
their commands later, so a module must not depend on the Omasetup app.

Structure:

```
modules/
└── my-module/
    ├── my-module          # required: executable
    ├── README.md          # required: user-facing docs
    ├── helper.sh          # optional
    └── docs/              # optional
```

Every module must support these commands:

```bash
modules/my-module/my-module enable
modules/my-module/my-module disable
modules/my-module/my-module status
modules/my-module/my-module status --quiet
modules/my-module/my-module version
```

A module should also support these commands:

```bash
modules/my-module/my-module link
modules/my-module/my-module unlink
modules/my-module/my-module update
```

Rules:

- Put `# Summary: ...` on the second line. This is a short description for
  the module.
- Support `status --quiet`: print nothing and exit 0 only when the module is
  fully enabled.
- `enable` must be idempotent and add only what the module needs.
- `disable` must remove exactly what `enable` added. It must also work when
  nothing is installed.
- Never run the whole script as root. Escalate only the specific command that
  needs it, and keep that command in a small helper.
- Do not depend on another module or on the Omasetup app.
- Add a row to the `Modules` table in `README.md`.
- Add real-world test evidence to the module README or its `docs/testing.md`.

## User-facing text

Write short, complete sentences. Avoid clipped phrases such as "what is
available" or "turn it on". If an idea needs a longer sentence, write the longer
sentence instead of removing words that make it clear.

This rule applies to the README, help output, status messages, and errors.

## Before committing

```bash
find modules -type f \( -name '*.sh' -o -perm -u+x \) -print0 |
  xargs -0 -r -n1 bash -n
find modules -type f \( -name '*.sh' -o -perm -u+x \) -print0 |
  xargs -0 -r shellcheck -S warning
./modules/my-module/my-module status
```
