# Adding a tweak

Tweaks live in `tweaks/`:

```
tweaks/
└── my-tweak/
    ├── my-tweak.sh      # required: enable | disable | status
    ├── helper.sh        # optional
    └── ...
```

`my-tweak.sh` is the only required file. The dispatcher runs it as:

```bash
tweaks/my-tweak/my-tweak.sh enable
tweaks/my-tweak/my-tweak.sh disable
tweaks/my-tweak/my-tweak.sh status
```

Rules:

- Put `# Summary: ...` on the second line. `omatweaks list` reads it.
- Support `status --quiet`: print nothing and exit 0 only when the tweak is
  fully enabled. `omatweaks list` uses it to show `enabled` / `disabled`.
- `enable` must be idempotent and add only what the tweak needs.
- `disable` must remove exactly what `enable` added. It must also work when
  nothing is installed.
- Never run the whole script as root. Escalate only the specific command that
  needs it, and keep that command in a small helper.
- Do not depend on another tweak.
- Add a row to the `Tweaks` table in `README.md` and a short section below it.

Before committing:

```bash
for f in omatweaks tweaks/*/*.sh; do bash -n "$f"; done
shellcheck -S warning omatweaks tweaks/*/*.sh
./omatweaks list
./omatweaks my-tweak status
```
