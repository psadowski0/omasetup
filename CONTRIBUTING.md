# Adding a tweak

One folder per tweak:

```
my-tweak/
├── my-tweak.sh      # enable | disable | status
├── helper.sh        # optional
└── ...
```

`my-tweak.sh` is the only required file. The dispatcher runs it as:

```bash
my-tweak/my-tweak.sh enable
my-tweak/my-tweak.sh disable
my-tweak/my-tweak.sh status
```

Rules:

- Put `# Summary: ...` on the second line. `omatweaks list` reads it.
- `enable` must be idempotent and add only what the tweak needs.
- `disable` must remove exactly what `enable` added. It must also work when
  nothing is installed.
- Never run the whole script as root. Escalate only the specific command that
  needs it, and keep that command in a small helper.
- Do not depend on another tweak.
- Add a short user-facing section to `README.md`.

Before committing:

```bash
for f in omatweaks */[a-z]*.sh; do bash -n "$f"; done
shellcheck -S warning omatweaks */[a-z]*.sh
./omatweaks list
./omatweaks my-tweak status
```
