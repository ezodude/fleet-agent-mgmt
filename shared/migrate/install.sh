#!/bin/bash
# install.sh [--repo <clone>] [--home <user home>] [--claude-home <dir>]
# Writes this machine's Claude settings from this clone. In <claude-home>/settings.json
# (default <home>/.claude, <home> default $HOME):
#   - the two user-level hooks from shared/hooks/settings-hooks.json, with @FLEET_REPO@
#     replaced by the clone root (absolute). A hook already there that runs a script of
#     the same name (from an older clone) is replaced, never duplicated; every other key
#     and hook is kept.
#   - env.FLEET_REPO (the clone) and env.FLEET_HOME: the state folder, an exported
#     $FLEET_HOME, else <home>/.fleet-agent-mgmt. --home names the user's home, never the state folder.
#   - $FLEET_HOME/migrate/install-stamp (UTC time), written only when settings.json changes
#     (or the stamp is missing): an idempotent re-run leaves it alone.
# Links each shared/skills/<name> that holds a SKILL.md into <claude-home>/skills/<name>;
# a real (non-link) folder at that name is skipped, never deleted.
# Prints one line per change; a run that changes nothing prints no "changed" line.
# The old settings file is copied to settings.json.pre-install-<stamp> before a rewrite.
set -eu
HERE="$(cd -P "$(dirname "$0")" && pwd)"
REPO="$(cd -P "$HERE/../.." && pwd)"
HOME_DIR="$HOME"; CH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$(cd -P "${2:?--repo needs a folder}" && pwd)"; shift ;;
    --home) HOME_DIR="${2:?--home needs a folder}"; shift ;;
    --claude-home) CH="${2:?--claude-home needs a folder}"; shift ;;
    *) echo "usage: install.sh [--repo <clone>] [--home <user home>] [--claude-home <dir>]" >&2; exit 2 ;;
  esac
  shift
done
[ -n "$CH" ] || CH="$HOME_DIR/.claude"
FH="${FLEET_HOME:-$HOME_DIR/.fleet-agent-mgmt}"
TEMPLATE="$(cd -P "$HERE/../.." && pwd)/shared/hooks/settings-hooks.json"  # own clone, never --repo
[ -f "$TEMPLATE" ] || { echo "install: no $TEMPLATE" >&2; exit 1; }
mkdir -p "$CH/skills" "$HOME_DIR"

STAMP="$(date +%Y%m%d-%H%M%S)"
python3 - "$CH/settings.json" "$TEMPLATE" "$REPO" "$FH" "$STAMP" <<'PY'
import datetime, json, os, shlex, shutil, sys
path, template, repo, fleet_home, stamp = sys.argv[1:6]
existed = os.path.exists(path)
settings = json.load(open(path)) if existed else {}
before = json.dumps(settings, sort_keys=True)
tpl = json.load(open(template))
def script_name(cmd):
    # basename of the command's first word, whether bare or shell-quoted
    # one word = the quoted form; several words = an old bare path that holds a space
    try:
        w = shlex.split(cmd)
    except ValueError:
        w = []
    return os.path.basename(w[0] if len(w) == 1 else cmd)
for _es in tpl.get("hooks", {}).values():
    for _e in _es:
        for _h in _e["hooks"]:
            # parsed first, then the absolute path is shell-quoted (a clone path may hold a space)
            _h["command"] = shlex.quote(_h["command"].replace("@FLEET_REPO@", repo))
changes = []

env = settings.setdefault("env", {})
for k, v in (("FLEET_REPO", repo), ("FLEET_HOME", fleet_home)):
    if env.get(k) != v:
        changes.append("changed: env.%s = %s" % (k, v))
        env[k] = v

hooks = settings.setdefault("hooks", {})
for event, entries in tpl.get("hooks", {}).items():
    mine = hooks.setdefault(event, [])
    for entry in entries:
        for h in entry["hooks"]:
            name = script_name(h["command"])
            same = False
            for e in mine:
                for x in e.get("hooks", []):
                    if script_name(x.get("command", "")) == name and x["command"] == h["command"] \
                       and e.get("matcher") == entry.get("matcher"):
                        same = True
            if same:
                continue
            # drop any hook running a script of this name (an older clone), then add ours
            for e in mine:
                kept = [x for x in e.get("hooks", []) if script_name(x.get("command", "")) != name]
                if len(kept) != len(e.get("hooks", [])):
                    e["hooks"] = kept
            hooks[event] = mine = [e for e in mine if e.get("hooks")]
            mine.append(dict(entry, hooks=[h]))
            changes.append("changed: %s hook -> %s" % (event, h["command"]))

if json.dumps(settings, sort_keys=True) != before or not existed:
    if existed:
        shutil.copy2(path, "%s.pre-install-%s" % (path, stamp))
        changes.append("backup: %s.pre-install-%s" % (path, stamp))
    with open(path + ".tmp", "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
    os.chmod(path + ".tmp", (os.stat(path).st_mode & 0o777) if existed else 0o600)
    os.replace(path + ".tmp", path)
    if not existed:
        changes.append("changed: wrote %s" % path)
    changed = True
else:
    changed = False
# the cut-over check reads this: one line, UTC, the format state-gate.log uses; rewritten only on a change
stamp_path = os.path.join(fleet_home, "migrate", "install-stamp")
if changed or not os.path.exists(stamp_path):
    os.makedirs(os.path.dirname(stamp_path), exist_ok=True)
    with open(stamp_path, "w") as f:
        f.write(datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") + "\n")
for c in changes:
    print(c)
if not changes:
    print("ok: settings.json already current")
PY

for d in "$REPO"/shared/skills/*/; do
  [ -f "${d}SKILL.md" ] || continue
  name="$(basename "$d")"
  target="$REPO/shared/skills/$name"
  link="$CH/skills/$name"
  if [ -L "$link" ]; then
    if [ "$(readlink "$link")" = "$target" ]; then echo "ok: skill $name already linked"
    else ln -sfn "$target" "$link"; echo "changed: skill $name repointed to $target"; fi
  elif [ -e "$link" ]; then
    echo "skipped: skill $name (a real folder is at $link; left alone)"
  else
    ln -s "$target" "$link"; echo "changed: skill $name linked to $target"
  fi
done
