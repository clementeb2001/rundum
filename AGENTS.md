# Rundum project workflow

## GitHub synchronization requested by the owner

After each completed, relevantly verified implementation task in this repository,
commit the task's reviewed changes and push the current branch to its configured
upstream without asking the owner to perform these steps. The existing remote is
`https://github.com/clementeb2001/rundum`. Do not change it automatically.

This is a workflow for agents working in this repository, not a background file
watcher: saving a file in Xcode alone does not trigger an upload. Read-only tasks
do not authorize a commit of unrelated pending changes.

Before every commit and push:

- Inspect status and the exact diff, including new files; preserve unrelated work.
- Run checks appropriate to the change and report any unverified parts honestly.
- Stage explicit reviewed paths, not an indiscriminate `git add .`.
- Never commit credentials, private keys, certificates, provisioning profiles,
  real operator private contact details, local environment configuration, device
  data, or Xcode user-state files. Keep private values in ignored local files.
- Inspect the staged diff for secrets; `.gitignore` does not protect values added
  to files that are already tracked. Stop and ask if safe publication is unclear.
- Never force-push, rewrite shared history, delete branches, or overwrite remote
  changes as part of this workflow. Report conflicts or missing authorization.
- Verify the remote branch points at the pushed commit before claiming upload
  success. If the push fails, state clearly that the commit remains local.

Do not start a persistent watcher, scheduled job, or upload on every editor save
unless the owner specifically selects that behavior separately.
