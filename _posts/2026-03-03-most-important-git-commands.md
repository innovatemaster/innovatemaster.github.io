---
layout: post
title: "The Most Important Git Commands Every Developer Should Know"
date: 2026-03-03 10:00 +0100
categories: [Git, DevOps]
tags: [git, version-control, cli, branching, merging, rebase, collaboration, workflow]
description: A practical reference to the most important Git commands covering repository setup, branching, merging, rebasing, stashing, history inspection, undoing changes, collaboration workflows, and advanced techniques with clear examples.
---

# The Most Important Git Commands Every Developer Should Know

Git is the version control system behind nearly every modern software project. Whether you are working alone on a side project or collaborating across a team of hundreds, Git tracks every change, lets you branch and merge freely, and provides a safety net that makes experimentation risk-free.

Yet many developers only use a handful of commands and resort to GUIs or guesswork when anything goes wrong. This guide covers the commands that matter most, organized by workflow, with examples you can run today.

## Configuration

Before your first commit, tell Git who you are. These settings are stored in `~/.gitconfig` and attached to every commit you make.

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

A few other useful defaults:

```bash
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global core.autocrlf input   # use 'true' on Windows
```

To review your configuration:

```bash
git config --list --show-origin
```

This shows every active setting and the file it comes from, which is invaluable when debugging unexpected behavior.

## Creating and Cloning Repositories

### git init

Creates a new Git repository in the current directory.

```bash
mkdir my-project && cd my-project
git init
```

This gives you a `.git` folder and an empty history. You are now on the default branch.

### git clone

Copies a remote repository to your machine, including its entire history.

```bash
git clone https://github.com/user/repo.git
```

To clone into a specific folder:

```bash
git clone https://github.com/user/repo.git my-folder
```

For large repositories where you only need recent history:

```bash
git clone --depth 1 https://github.com/user/repo.git
```

A shallow clone with `--depth 1` downloads only the latest snapshot, which is significantly faster for CI pipelines or when you just need the code.

## Everyday Workflow

The commands in this section form the core loop: check status, stage changes, commit, repeat.

### git status

Shows the state of your working directory and staging area.

```bash
git status
```

Example output:

```
On branch main
Changes not staged for commit:
  modified:   src/App.java

Untracked files:
  src/Utils.java
```

For a compact view:

```bash
git status -s
```

This gives you a two-column format where the left column shows the staging area and the right column shows the working tree.

### git add

Moves changes from the working directory into the staging area (also called the index).

```bash
git add src/App.java           # stage a single file
git add src/                   # stage everything in a directory
git add -A                     # stage all changes (new, modified, deleted)
git add -p                     # interactively stage hunks
```

The `-p` (patch) flag is one of the most underused features in Git. It lets you review each change and decide whether to stage it, which is perfect for splitting unrelated changes into separate commits.

### git commit

Records the staged snapshot in the repository history.

```bash
git commit -m "Add user authentication endpoint"
```

For a more detailed message with a body:

```bash
git commit -m "Add user authentication endpoint" \
           -m "Implements JWT-based auth with refresh tokens.
Includes rate limiting on the login route."
```

To stage all tracked files and commit in one step:

```bash
git commit -am "Fix null pointer in order service"
```

The `-a` flag only stages files that Git already tracks. New (untracked) files still require an explicit `git add`.

### git diff

Shows exactly what changed, line by line.

```bash
git diff                  # unstaged changes vs last commit
git diff --staged         # staged changes vs last commit
git diff main..feature    # difference between two branches
git diff HEAD~3..HEAD     # last three commits
```

To see only the names of changed files:

```bash
git diff --name-only main..feature
```

## Branching

Branching is cheap in Git. A branch is just a pointer to a commit, so creating one is nearly instantaneous regardless of project size.

### git branch

Lists, creates, or deletes branches.

```bash
git branch                    # list local branches
git branch -a                 # list local and remote branches
git branch feature/login      # create a new branch
git branch -d feature/login   # delete a merged branch
git branch -D feature/login   # force-delete an unmerged branch
git branch -m old-name new-name  # rename a branch
```

### git switch / git checkout

`git switch` is the modern way to change branches (introduced in Git 2.23). `git checkout` still works but does more things, which can be confusing.

```bash
git switch main                     # switch to an existing branch
git switch -c feature/payment       # create and switch in one step
git switch -c hotfix/bug-123 main   # branch off a specific base
```

The equivalent older commands:

```bash
git checkout main
git checkout -b feature/payment
```

Prefer `git switch` for changing branches and `git restore` for discarding changes. This separation makes intentions clearer.

## Merging

Merging integrates changes from one branch into another. It is the most common way to combine work in collaborative workflows.

### git merge

```bash
git switch main
git merge feature/payment
```

If the branches have diverged, Git creates a **merge commit** that ties both histories together. If no divergence occurred, Git performs a **fast-forward** merge, simply moving the branch pointer forward.

To always create a merge commit (useful for preserving history):

```bash
git merge --no-ff feature/payment
```

### Handling Merge Conflicts

When Git cannot automatically combine changes, it marks the conflicting sections in the affected files:

```
<<<<<<< HEAD
    return calculateTax(amount, 0.077);
=======
    return calculateTax(amount, rate);
>>>>>>> feature/tax-reform
```

The resolution process:

```bash
# 1. Open the conflicting file and edit it to the desired result
# 2. Remove the conflict markers
# 3. Stage the resolved file
git add src/TaxService.java
# 4. Complete the merge
git commit
```

To abort a merge and return to the state before it started:

```bash
git merge --abort
```

## Rebasing

Rebasing replays your commits on top of another branch, producing a linear history without merge commits.

### git rebase

```bash
git switch feature/payment
git rebase main
```

This takes every commit on `feature/payment` that is not on `main`, and replays them one by one on top of `main`'s latest commit.

### Interactive Rebase

Interactive rebase is one of Git's most powerful features. It lets you rewrite history before sharing it.

```bash
git rebase -i HEAD~4
```

This opens an editor listing the last four commits:

```
pick a1b2c3d Add payment model
pick e4f5g6h Add payment repository
pick i7j8k9l Fix typo in payment model
pick m0n1o2p Add payment service
```

You can change `pick` to:

| Command   | Effect |
|-----------|--------|
| `pick`    | Keep the commit as-is |
| `reword`  | Keep the commit but edit its message |
| `edit`    | Pause to amend the commit |
| `squash`  | Meld into the previous commit, combine messages |
| `fixup`   | Meld into the previous commit, discard this message |
| `drop`    | Remove the commit entirely |

A common pattern is squashing a typo fix into the commit it corrects:

```
pick a1b2c3d Add payment model
fixup i7j8k9l Fix typo in payment model
pick e4f5g6h Add payment repository
pick m0n1o2p Add payment service
```

**Important:** Never rebase commits that have already been pushed and shared with others. Rebasing rewrites commit hashes, which forces collaborators to reconcile divergent histories.

### Merge vs Rebase

| Aspect | Merge | Rebase |
|--------|-------|--------|
| History | Non-linear, preserves exact timeline | Linear, cleaner log |
| Safety | Safe on shared branches | Only safe on local/private branches |
| Conflict resolution | Once, at merge time | Potentially once per replayed commit |
| Traceability | Merge commit shows when integration happened | No merge commit |

A popular workflow: rebase locally to clean up your branch, then merge (with `--no-ff`) into the shared branch. This gives you the best of both approaches.

## Stashing

Stashing temporarily shelves uncommitted changes so you can work on something else without committing half-finished work.

### git stash

```bash
git stash                       # stash tracked changes
git stash -u                    # include untracked files
git stash push -m "WIP: refactor auth"  # stash with a description
```

### Retrieving Stashed Changes

```bash
git stash list                  # show all stashes
git stash pop                   # apply most recent stash and remove it
git stash apply stash@{2}      # apply a specific stash without removing it
git stash drop stash@{0}       # remove a specific stash
git stash clear                 # remove all stashes
```

You can also create a branch from a stash:

```bash
git stash branch feature/from-stash stash@{0}
```

This creates a new branch starting from the commit where the stash was made, applies the stash, and drops it. It is useful when your stashed changes conflict with work done since the stash was created.

## Inspecting History

Understanding what happened in a repository is just as important as making changes.

### git log

```bash
git log                         # full log
git log --oneline               # compact one-line format
git log --oneline --graph       # ASCII graph showing branches
git log --oneline -10           # last 10 commits
git log --author="Your Name"    # filter by author
git log --since="2026-01-01"    # filter by date
git log -- src/App.java         # history of a specific file
```

A particularly useful combination:

```bash
git log --oneline --graph --all --decorate
```

This shows the entire repository topology at a glance.

### git show

Displays the details of a specific commit, including the diff.

```bash
git show abc1234                # show a specific commit
git show HEAD                   # show the latest commit
git show main:src/App.java     # show a file as it exists on main
```

### git blame

Shows who last modified each line of a file and when.

```bash
git blame src/App.java
```

To ignore whitespace changes and track code moved between files:

```bash
git blame -w -C src/App.java
```

### git reflog

The reflog records every time `HEAD` moves. It is your safety net when things go wrong.

```bash
git reflog
```

Example output:

```
a1b2c3d HEAD@{0}: commit: Add payment service
e4f5g6h HEAD@{1}: rebase (finish): returning to refs/heads/feature
i7j8k9l HEAD@{2}: rebase (start): checkout main
m0n1o2p HEAD@{3}: commit: WIP payment model
```

Even after a bad rebase or reset, the reflog lets you find the previous state and recover it.

## Undoing Changes

Git provides multiple ways to undo work, each appropriate for a different situation.

### git restore

Discards changes in the working directory or unstages files.

```bash
git restore src/App.java              # discard unstaged changes
git restore --staged src/App.java     # unstage a file (keep changes)
git restore --source=HEAD~1 src/App.java  # restore from a previous commit
```

### git reset

Moves the branch pointer backward, with varying effects on the staging area and working directory.

```bash
git reset --soft HEAD~1     # undo last commit, keep changes staged
git reset --mixed HEAD~1    # undo last commit, keep changes unstaged (default)
git reset --hard HEAD~1     # undo last commit, discard all changes
```

| Mode | HEAD | Staging Area | Working Directory |
|------|------|--------------|-------------------|
| `--soft` | Moves back | Unchanged | Unchanged |
| `--mixed` | Moves back | Reset | Unchanged |
| `--hard` | Moves back | Reset | Reset |

**Warning:** `git reset --hard` permanently discards uncommitted changes. Use it carefully.

### git revert

Creates a new commit that undoes the changes from a previous commit. Unlike reset, revert is safe to use on shared branches because it does not rewrite history.

```bash
git revert abc1234              # revert a single commit
git revert HEAD~3..HEAD         # revert the last three commits
git revert -m 1 abc1234        # revert a merge commit (keep first parent)
```

### When to Use What

| Scenario | Command |
|----------|---------|
| Discard local uncommitted changes | `git restore` |
| Unstage a file | `git restore --staged` |
| Undo the last commit (not yet pushed) | `git reset --soft HEAD~1` |
| Completely erase recent local commits | `git reset --hard` |
| Undo a commit on a shared branch | `git revert` |
| Recover from a bad rebase or reset | `git reflog` + `git reset` |

## Working with Remotes

Collaboration requires synchronizing your local repository with remote repositories.

### git remote

```bash
git remote -v                              # list remotes with URLs
git remote add upstream https://github.com/original/repo.git
git remote rename origin backup
git remote remove upstream
```

### git fetch

Downloads new commits and branches from a remote without modifying your working directory.

```bash
git fetch origin                # fetch from origin
git fetch --all                 # fetch from all remotes
git fetch --prune               # remove stale remote-tracking branches
```

Fetching is always safe. It updates your remote-tracking branches (e.g., `origin/main`) but never touches your local branches.

### git pull

Fetches and integrates remote changes into your current branch.

```bash
git pull                        # fetch + merge (default)
git pull --rebase               # fetch + rebase (cleaner history)
git pull origin main            # pull a specific branch
```

With `pull.rebase true` in your config (recommended earlier), `git pull` automatically rebases instead of merging, which avoids unnecessary merge commits.

### git push

Uploads your local commits to a remote repository.

```bash
git push                                  # push current branch
git push origin main                      # push a specific branch
git push -u origin feature/payment        # push and set upstream tracking
git push --tags                           # push all tags
git push origin --delete feature/old      # delete a remote branch
```

After setting the upstream with `-u`, subsequent pushes on that branch only need `git push`.

**Never force-push to shared branches** unless the team has explicitly agreed on the workflow. If you must force-push a rebased private branch:

```bash
git push --force-with-lease origin feature/payment
```

The `--force-with-lease` flag is safer than `--force` because it refuses to overwrite commits on the remote that you have not seen locally.

## Tags

Tags mark specific points in history, typically used for releases.

```bash
git tag v1.0.0                            # lightweight tag
git tag -a v1.0.0 -m "Release 1.0.0"     # annotated tag (recommended)
git tag -a v1.0.0 abc1234                 # tag a specific commit
git tag -l "v1.*"                         # list tags matching a pattern
git push origin v1.0.0                    # push a single tag
git push origin --tags                    # push all tags
git tag -d v1.0.0                         # delete a local tag
git push origin --delete v1.0.0           # delete a remote tag
```

Annotated tags store the tagger's name, date, and message. Use them for releases. Lightweight tags are just pointers and are fine for temporary or personal markers.

## Cherry-Picking

Cherry-pick applies a single commit from one branch onto another without merging the entire branch.

```bash
git cherry-pick abc1234                   # apply one commit
git cherry-pick abc1234 def5678           # apply multiple commits
git cherry-pick abc1234 --no-commit       # apply changes without committing
```

Cherry-picking is useful for backporting a bug fix to a release branch or pulling a specific change out of a long-running feature branch.

If a conflict occurs during cherry-pick:

```bash
git cherry-pick --continue    # after resolving conflicts
git cherry-pick --abort       # cancel the cherry-pick
```

## Cleaning Up

### git clean

Removes untracked files from the working directory.

```bash
git clean -n          # dry run: show what would be removed
git clean -f          # remove untracked files
git clean -fd         # remove untracked files and directories
git clean -fX         # remove only ignored files
git clean -fx         # remove ignored and non-ignored untracked files
```

Always run with `-n` first to avoid accidentally deleting important files.

### Pruning Remote Branches

Over time, remote-tracking branches for deleted remote branches accumulate:

```bash
git fetch --prune
git remote prune origin       # alternative
```

To see which remote branches have been merged and can be cleaned up:

```bash
git branch -r --merged main
```

## Useful Aliases

Git aliases save keystrokes and encode best practices. Add them to your `~/.gitconfig`:

```ini
[alias]
    st = status -s
    co = checkout
    sw = switch
    br = branch
    ci = commit
    lg = log --oneline --graph --all --decorate
    unstage = restore --staged
    last = log -1 HEAD --stat
    amend = commit --amend --no-edit
    wip = !git add -A && git commit -m 'WIP'
```

With these aliases, `git lg` gives you a full topology view and `git wip` creates a quick work-in-progress snapshot.

## Common Workflows

### Feature Branch Workflow

```bash
# 1. Start from an up-to-date main
git switch main
git pull

# 2. Create a feature branch
git switch -c feature/user-profile

# 3. Make changes, commit often
git add -A
git commit -m "Add user profile model"
# ... more commits ...

# 4. Keep up with main
git fetch origin
git rebase origin/main

# 5. Push and open a pull request
git push -u origin feature/user-profile
```

### Hotfix Workflow

```bash
# 1. Branch from the release tag
git switch -c hotfix/fix-login v1.2.0

# 2. Fix the bug
git add -A
git commit -m "Fix null pointer on login with expired session"

# 3. Merge into main and the release branch
git switch main
git merge --no-ff hotfix/fix-login
git tag -a v1.2.1 -m "Hotfix: login null pointer"

git switch release/1.2
git cherry-pick <hotfix-commit-hash>

# 4. Clean up
git branch -d hotfix/fix-login
```

## Quick Reference

| Task | Command |
|------|---------|
| Initialize a repository | `git init` |
| Clone a repository | `git clone <url>` |
| Check status | `git status` |
| Stage changes | `git add <file>` or `git add -A` |
| Commit | `git commit -m "message"` |
| View diff | `git diff` |
| Create a branch | `git switch -c <branch>` |
| Switch branch | `git switch <branch>` |
| Merge a branch | `git merge <branch>` |
| Rebase onto a branch | `git rebase <branch>` |
| Stash changes | `git stash` |
| View log | `git log --oneline --graph` |
| Undo last commit (keep changes) | `git reset --soft HEAD~1` |
| Revert a pushed commit | `git revert <hash>` |
| Fetch remote changes | `git fetch` |
| Pull remote changes | `git pull --rebase` |
| Push to remote | `git push` |
| Tag a release | `git tag -a v1.0.0 -m "msg"` |
| Cherry-pick a commit | `git cherry-pick <hash>` |
| Clean untracked files | `git clean -fd` |

## Conclusion

Git's power comes from its flexibility, but that same flexibility can be overwhelming. The commands in this guide cover the vast majority of what you will need day to day. Start with the everyday workflow commands, get comfortable with branching and merging, then gradually add rebasing, stashing, and cherry-picking to your toolkit.

When something goes wrong, remember that `git reflog` is your ultimate safety net. As long as you committed or stashed your work at some point, Git almost certainly still has it. The key to mastering Git is not memorizing every flag but understanding the mental model: commits are snapshots, branches are pointers, and nearly every operation is reversible.
