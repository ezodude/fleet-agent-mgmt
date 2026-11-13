# Definition of Done

One list, two parts. Part 1 holds for every rung and never changes per
rung. Part 2 is one profile per project, seven lines each, born at the
project's first `brief-grilling`. Profiles are project data, so they live
outside this repo, one file per project, in
`$FLEET_HOME/profiles/<project>.md`. `writing-a-ticket` pastes
Part 1 and the project's profile verbatim under the rung's own
done-lines in the fleet ticket (`ticket.md` in the record folder); its
Definition of Done stays the one list the review checks. The PO view
filed to an external tracker (Jira, GitHub, any other) keeps only the rung's own done-lines, never this
block or the profile. It is core to the framework, not a formality.

## Part 1, standing, every rung

```
DONE, standing
  the IC pushes its own branch and opens a draft PR only at a green gate receipt at HEAD; ready, merge and every other push are the owner's word; the IC never merges
  commits one line each, no AI attribution
  the project's test command exits 0 and its "N passed" line is quoted in the evidence file
    (Platform: the CI checks stand in; there is no local test command)
  confidentiality sweep on every tracked file the rung touched: no client name, key, path or person
  superpowers:verification-before-completion run before every STOP and before "ready for push"
  evidence file and decision record complete, and audited by lead-1 after the push
  every shipped doc line checked against the code it describes
  every doc the rung commits to the product repo follows foundations/public-docs.md: no fleet terms, renders on GitHub
  the spec's `## Subtleties` still true at close, or amended with a date
```

## Part 2, one profile per project

Seven lines, fixed order, "none" is a valid value. A new project gets its
profile at its first `brief-grilling` (the seven questions are in that
skill); lead-1 writes it to `$FLEET_HOME/profiles/<project>.md`
on the owner's word, never into this file, and commits it when written. `writing-a-ticket` refuses a
ticket for a project with no profile file. Every close report says
`profile: unchanged` or `profile changed: <line>`; lead-1 edits the
project's file on the owner's word and commits it. The `sandbox` line is the only place
a sandbox is named (one-way.md, Two-way); `none` means every deploy needs
the word.

```
PROFILE <project>  (<IC names>)
  ticket      <Jira project | GitHub issue on <repo> | filesystem <dir> | none>
  gates       <command: pass line>, one per line
  ci          <workflow and trigger | none found>
  deploy      <who deploys, how; the UAT shape | none>
  one-way     <acts beyond foundations/one-way.md | none>
  docs        <venue for shipped docs | none>
  sandbox     <environment, local or remote, only this rung writes to; how the IC deploys to it | none>
```
