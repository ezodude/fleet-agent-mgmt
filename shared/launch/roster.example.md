# Fleet roster (example)

Copy this file to $FLEET_HOME/roster.md and edit it. All data below is invented.

**owner: Robin** (the person the skills, charter and hooks call `the owner`)

`agent-up.sh` reads the fenced `fleet` block: name TAB directory [TAB extra claude flags].

```fleet
atlas-ic-1	/path/to/atlas
orbit-ic-1	/path/to/orbit
```

Reviewers, one per designated repo, sit in their own block: outside the cap of active projects, idle until lead-1 hands one a pull request on the owner's "review #N"; agent-up.sh --all does not start them.

```reviewers
atlas-reviewer	/path/to/atlas-review
```

`/path/to/atlas-review` is a clone or worktree only the reviewer uses.
