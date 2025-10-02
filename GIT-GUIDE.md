# Git Repository Guide

Complete Git workflow and repository management guide for the C2 Enumeration Toolkit.

---

## 📊 Repository Overview

**Repository:** https://github.com/SWORDIntel/c2-enum-toolkit
**Visibility:** 🔒 Private
**Owner:** SWORDIntel
**Branch:** master
**Commits:** 5
**Contributors:** SWORDIntel + Claude (Co-Author)

---

## 📈 Commit History

```
* eca0dfb - Add comprehensive code review and security analysis
* 102b5f4 - Phase 1 Improvements: Advanced Intelligence Analysis Modules
* 709e67d - Add scanning mode comparison guide
* 28641c7 - Add Docker support + Comprehensive C2 scanning capabilities
* bb174f7 - Initial commit: C2 Enumeration Toolkit v2.1
```

### Commit Statistics

| Commit | Files Changed | Insertions | Deletions | Summary |
|--------|---------------|------------|-----------|---------|
| bb174f7 | 7 | 3,079 | 0 | Initial toolkit v2.1 |
| 28641c7 | 10 | 3,296 | 0 | Docker + comprehensive scanning |
| 709e67d | 1 | 482 | 0 | Scanning comparison guide |
| 102b5f4 | 8 | 2,471 | 1 | Phase 1 analyzers |
| eca0dfb | 2 | 1,228 | 0 | Code review |

**Total:** 28 files, 10,556 insertions, 1 deletion

---

## 🌳 Repository Structure

```
c2-enum-toolkit/
├── .git/                           Git repository data
├── .gitignore                      Excludes intel_* directories
├── .dockerignore                   Docker build exclusions
│
├── c2-enum-tui.sh                  Main TUI script (1,481 lines)
├── c2-scan-comprehensive.sh        Aggressive scanner (763 lines)
├── c2-enum-cli.sh                  JSON CLI (340 lines)
│
├── analyzers/                      Specialized analysis modules
│   ├── README.md
│   ├── binary-analysis.sh          Advanced binary analysis
│   ├── javascript-analysis.sh      JS endpoint extraction
│   ├── certificate-intel.sh        Cert intelligence
│   └── content-crawler.sh          Content analysis
│
├── docker/                         Docker configuration
│   ├── entrypoint.sh              Container startup
│   └── torrc                       Tor configuration
│
├── Dockerfile                      Container definition
├── docker-compose.yml              Orchestration
│
└── Documentation (12 guides)
    ├── README.md                   Overview
    ├── QUICKSTART.md               User guide
    ├── ENHANCEMENTS.md             v2.0 details
    ├── PORT-SCANNING.md            Port features
    ├── COMPREHENSIVE-SCANNING.md   Aggressive scanning
    ├── SCANNING-COMPARISON.md      Mode comparison
    ├── DOCKER.md                   Deployment
    ├── DOCKER-BENEFITS.md          ROI analysis
    ├── PHASE1-IMPROVEMENTS.md      Analyzer modules
    ├── CODE-REVIEW.md              Security review
    ├── CHANGELOG.md                Version history
    └── FIXES.sh                    Fix templates
```

---

## 🔧 Git Configuration

### Current Remote

```bash
origin  https://github.com/SWORDIntel/c2-enum-toolkit.git (fetch)
origin  https://github.com/SWORDIntel/c2-enum-toolkit.git (push)
```

### .gitignore Rules

```
Intel outputs
intel_*/
```

**Ignored:**
- All `intel_*` output directories (can be large)
- Prevents accidental commit of scan results

---

## 🚀 Common Git Workflows

### 1. Daily Development Workflow

```bash
# Start work
cd /run/media/john/DATA/Active\ Measures/c2-enum-toolkit/

# Check status
git status

# Make changes
vim c2-enum-tui.sh

# Stage changes
git add c2-enum-tui.sh

# Commit with message
git commit -m "Enhancement: Add new feature X"

# Push to GitHub
git push origin master
```

---

### 2. Feature Branch Workflow

```bash
# Create feature branch
git checkout -b feature/new-analyzer

# Make changes
vim analyzers/new-analyzer.sh
git add analyzers/new-analyzer.sh

# Commit
git commit -m "Add new analyzer module"

# Push branch
git push -u origin feature/new-analyzer

# Create PR on GitHub
gh pr create --title "New Analyzer Module" --body "Description..."

# After review, merge
gh pr merge
git checkout master
git pull
```

---

### 3. Hot Fix Workflow

```bash
# On master, make quick fix
git checkout master
git pull

# Fix issue
vim c2-enum-tui.sh

# Commit and push immediately
git add c2-enum-tui.sh
git commit -m "Fix: Critical bug in Tor connectivity check"
git push

# Tag the fix
git tag -a v2.3.1 -m "Hotfix for Tor connectivity"
git push --tags
```

---

### 4. Reviewing Changes Before Commit

```bash
# See what changed
git diff

# See what changed in specific file
git diff c2-enum-tui.sh

# See staged changes
git add file.sh
git diff --staged

# Review line-by-line
git diff --word-diff

# Unstage if needed
git reset HEAD file.sh
```

---

### 5. Viewing History

```bash
# Recent commits
git log --oneline -10

# Detailed log
git log --stat

# With graph
git log --oneline --graph --all

# Changes in specific file
git log --follow c2-enum-tui.sh

# Who changed what
git blame c2-enum-tui.sh

# Search commits
git log --grep="Docker"
git log --author="Claude"
```

---

### 6. Undoing Changes

```bash
# Undo uncommitted changes
git checkout -- file.sh

# Unstage file
git reset HEAD file.sh

# Undo last commit (keep changes)
git reset --soft HEAD~1

# Undo last commit (discard changes)
git reset --hard HEAD~1

# Revert a specific commit
git revert abc123

# Go back to specific commit
git checkout abc123
```

---

### 7. Tagging Versions

```bash
# Create annotated tag
git tag -a v2.3 -m "Version 2.3 - Phase 1 Complete"

# Push tags
git push --tags

# List tags
git tag -l

# Checkout specific version
git checkout v2.3

# Delete tag
git tag -d v2.3
git push origin :refs/tags/v2.3
```

---

### 8. Collaboration Workflow

```bash
# Add collaborator (via gh CLI)
gh repo collaborator add username

# Clone repository
git clone https://github.com/SWORDIntel/c2-enum-toolkit.git

# Keep in sync
git pull origin master

# Push changes
git push origin master

# Resolve conflicts
git pull  # If conflicts
# Edit conflicted files
git add .
git commit -m "Resolve merge conflicts"
git push
```

---

## 📋 Git Best Practices for This Project

### Commit Message Format

```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation
- `style:` Formatting
- `refactor:` Code restructuring
- `perf:` Performance improvement
- `test:` Adding tests
- `chore:` Maintenance

**Examples:**
```bash
git commit -m "feat: Add certificate intelligence analyzer

Implements full TLS/SSL analysis with:
- Certificate extraction
- Fingerprint generation
- Security scoring
- Cipher suite enumeration

Closes #12"

git commit -m "fix: Handle empty port list in CLI mode

Prevents crash when --no-port-scan is used.
Adds proper validation.

Fixes #45"
```

---

### Branch Strategy

**Current:** Single branch (master)

**Recommended for team:**

```
master               # Production-ready code only
  ├── develop        # Integration branch
  ├── feature/*      # New features
  ├── bugfix/*       # Bug fixes
  └── hotfix/*       # Critical fixes
```

**Example:**
```bash
# Feature development
git checkout -b feature/misp-integration develop
# ... work ...
git push -u origin feature/misp-integration
# PR to develop

# Release
git checkout master
git merge develop
git tag -a v2.4 -m "Release v2.4"
git push --tags
```

---

## 🔐 Security Considerations

### Sensitive Data

**.gitignore protects:**
- ✅ Output directories (`intel_*/`)
- ✅ PCAP files (can contain metadata)
- ✅ Downloaded binaries

**Never commit:**
- ❌ Scan results
- ❌ PCAP captures
- ❌ API keys or tokens
- ❌ Real target lists (use examples only)

### Pre-commit Checks

```bash
# Create .git/hooks/pre-commit
cat > .git/hooks/pre-commit <<'HOOK'
#!/bin/bash
# Pre-commit hook: Check for sensitive data

if git diff --cached | grep -iE "password|api.?key|secret|token|BEGIN (RSA |)PRIVATE KEY"; then
  echo "⚠️  Potential sensitive data detected!"
  echo "Review changes before committing."
  exit 1
fi

# Syntax check all shell scripts
for file in $(git diff --cached --name-only | grep "\.sh$"); do
  if ! bash -n "$file"; then
    echo "⚠️  Syntax error in $file"
    exit 1
  fi
done

echo "✓ Pre-commit checks passed"
HOOK

chmod +x .git/hooks/pre-commit
```

---

## 📦 GitHub CLI Workflows

### Repository Management

```bash
# View repository
gh repo view

# View in browser
gh repo view --web

# Edit repository
gh repo edit --description "New description"

# Add topics
gh repo edit --add-topic security,tor,c2-analysis

# Archive repository (when done)
gh repo archive
```

### Issues & Pull Requests

```bash
# Create issue
gh issue create --title "Add VirusTotal integration" \
  --body "Implement API integration for hash lookups"

# List issues
gh issue list

# Create PR
gh pr create --title "Feature: MISP Integration" \
  --body "Adds automatic IOC export to MISP"

# Review PR
gh pr view 1
gh pr diff 1
gh pr merge 1
```

### Releases

```bash
# Create release
gh release create v2.3 --title "Version 2.3 - Phase 1" \
  --notes "Complete intelligence analysis modules"

# Upload assets
gh release upload v2.3 c2-enum-toolkit-v2.3.tar.gz

# List releases
gh release list
```

---

## 🔄 Maintenance Workflows

### Keeping Fork Updated

If others fork the repository:

```bash
# In forked repo
git remote add upstream https://github.com/SWORDIntel/c2-enum-toolkit.git
git fetch upstream
git merge upstream/master
git push origin master
```

### Cleaning Up

```bash
# Remove untracked files (dry run)
git clean -n

# Remove untracked files
git clean -f

# Remove untracked directories
git clean -fd

# Prune remote branches
git remote prune origin

# Garbage collection
git gc --aggressive
```

---

## 📊 Repository Analytics

### Current Statistics

```bash
# Total commits
git rev-list --count HEAD
# Result: 5

# Lines of code added
git log --shortstat | grep "insertions" | \
  awk '{sum+=$4} END {print sum " insertions"}'
# Result: 10,556 insertions

# Contributors
git shortlog -sn
# SWORDIntel + Claude (Co-Author)

# Most changed files
git log --format=format: --name-only | \
  grep -v '^$' | sort | uniq -c | sort -rn | head -10
```

### Code Churn Analysis

```bash
# Files with most changes
git log --all --numstat --format="%H" -- | \
  awk 'NF==3 {plus+=$1; minus+=$2} END {print plus " + " minus " -"}'

# Commit frequency
git log --format="%ai" | cut -d' ' -f1 | uniq -c
```

---

## 🎯 Advanced Git Techniques

### 1. Interactive Rebase (Cleanup History)

```bash
# Rebase last 3 commits
git rebase -i HEAD~3

# Squash, reword, or reorder commits
# Use with caution - rewrites history
```

### 2. Cherry-Pick Commits

```bash
# Pick specific commit from another branch
git cherry-pick abc123

# Cherry-pick range
git cherry-pick abc123..def456
```

### 3. Bisect (Find Bug Introduction)

```bash
# Find commit that introduced bug
git bisect start
git bisect bad HEAD
git bisect good v2.1

# Git will checkout commits - test each
./c2-enum-tui.sh --help
git bisect good  # or bad

# When found
git bisect reset
```

### 4. Stashing Changes

```bash
# Save work in progress
git stash save "WIP: New feature"

# List stashes
git stash list

# Apply stash
git stash apply stash@{0}

# Pop stash (apply and delete)
git stash pop
```

---

## 🔍 Searching Repository

### Finding Code

```bash
# Search in current files
git grep "function_name"

# Search in history
git log -S "pattern" --source --all

# Search commit messages
git log --grep="Docker"

# Find who changed line
git blame c2-enum-tui.sh -L 100,110
```

### Finding When Something Changed

```bash
# When was file added
git log --diff-filter=A -- file.sh

# When was file deleted
git log --diff-filter=D -- file.sh

# When was function added
git log -S "function_name" -p
```

---

## 📝 Commit Guidelines

### What to Commit

✅ **DO Commit:**
- Source code changes
- Documentation updates
- Configuration files
- Dockerfile changes
- Tests
- Build scripts

❌ **DON'T Commit:**
- Scan results (`intel_*/`)
- PCAP files (`.pcap`)
- Compiled binaries
- API keys or secrets
- Personal notes
- Temporary files

### Atomic Commits

**Good:**
```bash
git commit -m "feat: Add binary entropy analysis

Implements Shannon entropy calculation for packing detection.
Includes threat scoring based on entropy levels."
```

**Bad:**
```bash
git commit -m "Updated lots of stuff, fixed bugs, added features"
```

---

## 🔐 Security Best Practices

### 1. Protect Sensitive Data

```bash
# Check before commit
git diff --cached | grep -iE "password|key|secret|token"

# Use git-secrets (install first)
git secrets --scan
```

### 2. Sign Commits (Optional)

```bash
# Generate GPG key
gpg --gen-key

# Configure Git
git config --global user.signingkey YOUR_KEY_ID
git config --global commit.gpgsign true

# Signed commit
git commit -S -m "Signed commit"
```

### 3. Verify Repository Integrity

```bash
# Verify commits
git fsck

# Verify objects
git verify-pack -v .git/objects/pack/*.idx
```

---

## 🔄 Backup Strategies

### 1. Local Backup

```bash
# Clone as backup
git clone /path/to/c2-enum-toolkit /backup/c2-enum-toolkit

# Or tar the entire directory
tar -czf c2-enum-toolkit-backup-$(date +%F).tar.gz c2-enum-toolkit/
```

### 2. Remote Backup

```bash
# Add second remote
git remote add backup git@gitlab.com:user/c2-enum-toolkit.git

# Push to both
git push origin master
git push backup master

# Or push to all
git remote add all origin
git remote set-url --add --push all git@github.com:SWORDIntel/c2-enum-toolkit.git
git remote set-url --add --push all git@gitlab.com:user/c2-enum-toolkit.git
git push all master
```

### 3. Automated Backup

```bash
#!/bin/bash
# backup-repo.sh

DATE=$(date +%Y%m%d)
BACKUP_DIR="/backup/git-backups"

cd /run/media/john/DATA/Active\ Measures/c2-enum-toolkit/

# Create bundle (includes all history)
git bundle create "$BACKUP_DIR/c2-enum-toolkit-$DATE.bundle" --all

# Verify bundle
git bundle verify "$BACKUP_DIR/c2-enum-toolkit-$DATE.bundle"

echo "Backup complete: $BACKUP_DIR/c2-enum-toolkit-$DATE.bundle"

# Keep only last 30 days
find "$BACKUP_DIR" -name "*.bundle" -mtime +30 -delete
```

**Run daily via cron:**
```bash
0 2 * * * /path/to/backup-repo.sh
```

---

## 📊 Repository Health

### Metrics

```bash
# Repository size
du -sh .git
# Current: ~2-5 MB (small, healthy)

# Commit frequency
git log --format="%ai" | cut -d' ' -f1 | uniq -c
# 5 commits on 2025-10-02 (active development)

# Code churn (lines changed)
git log --shortstat | grep "files changed" | \
  awk '{files+=$1; inserted+=$4; deleted+=$6} END {
    print "Files: " files
    print "Insertions: " inserted
    print "Deletions: " deleted
  }'
```

---

## 🎓 Tips & Tricks

### 1. Aliases

Add to `~/.gitconfig`:

```ini
[alias]
  st = status
  co = checkout
  br = branch
  ci = commit
  unstage = reset HEAD --
  last = log -1 HEAD
  lg = log --oneline --graph --all
  contributors = shortlog -sn
```

Usage:
```bash
git st       # Instead of git status
git lg       # Pretty log graph
git last     # Show last commit
```

### 2. Diff Tools

```bash
# Use better diff viewer
git config --global diff.tool vimdiff
git difftool

# Or use GUI
git config --global diff.tool meld
```

### 3. Quick Stats

```bash
# Lines of code by author
git ls-files | xargs -n1 git blame --line-porcelain | \
  grep "^author " | sort | uniq -c | sort -rn

# Recent activity
git log --since="1 week ago" --oneline

# Commits per day
git log --format="%ai" | cut -d' ' -f1 | uniq -c
```

---

## 🐛 Troubleshooting

### Common Issues

#### Issue 1: "Your branch is ahead of origin"

```bash
# Solution: Push commits
git push origin master
```

#### Issue 2: "Your branch is behind origin"

```bash
# Solution: Pull changes
git pull origin master

# If you have local changes
git stash
git pull
git stash pop
```

#### Issue 3: Merge Conflicts

```bash
# When conflicts occur
git pull  # Shows conflicts

# Edit conflicted files (look for <<<<<<, =======, >>>>>> markers)
vim conflicted-file.sh

# Mark as resolved
git add conflicted-file.sh

# Complete merge
git commit -m "Merge: Resolved conflicts in conflicted-file.sh"
git push
```

#### Issue 4: Accidentally Committed Large File

```bash
# Remove from last commit
git rm --cached large-file.pcap
git commit --amend -m "Remove large file"
git push --force  # Use with caution!

# Remove from history (if pushed)
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch large-file.pcap' \
  --prune-empty --tag-name-filter cat -- --all
```

---

## 🔄 GitHub-Specific Features

### Actions & Workflows

```bash
# List workflows
gh workflow list

# Run workflow
gh workflow run ci.yml

# View runs
gh run list

# View run logs
gh run view
```

### Repository Settings

```bash
# Make repository public (careful!)
gh repo edit --visibility public

# Keep private (current)
gh repo edit --visibility private

# Enable features
gh repo edit --enable-issues --enable-wiki

# Add topics
gh repo edit --add-topic security,tor,osint
```

---

## 📈 Growth Tracking

### Version Timeline

| Version | Date | Lines | Commits | Major Features |
|---------|------|-------|---------|----------------|
| v1.0 | Original | 489 | - | Basic enumeration |
| v2.1 | 2025-10-02 | 1,481 | 1 | Enhanced + port scanning |
| v2.2 | 2025-10-02 | 2,244 | 2 | Docker + comprehensive |
| v2.3 | 2025-10-02 | 3,769 | 2 | Analyzer modules + CLI |

**Total Growth:** 489 → 3,769 (7.7× in one day!)

---

## 🎯 Recommended Git Workflow

### For Solo Development

```bash
# Current workflow (works well)
master branch only
Commit often with clear messages
Push after each feature
Tag releases
```

### For Team Development

```bash
# Recommended workflow
develop branch for integration
Feature branches for new work
PR review before merge
Semantic versioning tags
Automated testing via GitHub Actions
```

---

## 📚 Additional Resources

### Git Commands Reference

```bash
# Show all commands
git help -a

# Help for specific command
git help commit
git commit --help

# Quick reference
git help -g
```

### GitHub CLI Reference

```bash
# All commands
gh help

# Specific command help
gh repo help
gh pr help
gh issue help
```

---

## ✅ Git Health Checklist

- [x] Repository initialized
- [x] Remote configured (GitHub)
- [x] .gitignore configured
- [x] Regular commits (semantic messages)
- [x] All changes pushed
- [x] No uncommitted changes
- [x] Clean working tree
- [x] Private visibility maintained
- [x] Co-authorship attribution
- [x] Documentation in repository

**Status:** ✅ **Healthy Repository**

---

## 🎓 Quick Reference Card

```bash
# Daily Commands
git status                    # Check status
git add file.sh              # Stage file
git commit -m "Message"      # Commit
git push                     # Push to GitHub
git pull                     # Get updates

# Viewing
git log --oneline           # Commit history
git diff                    # See changes
git show abc123             # Show commit

# Undoing
git checkout -- file.sh     # Undo changes
git reset HEAD file.sh      # Unstage
git revert abc123           # Undo commit

# Branching
git branch feature          # Create branch
git checkout feature        # Switch branch
git merge feature           # Merge branch

# Remote
git remote -v               # Show remotes
git push origin master      # Push
git pull origin master      # Pull

# GitHub CLI
gh repo view                # View repo
gh pr create                # Create PR
gh issue list               # List issues
```

---

**For more details, see:**
- Official Git documentation: https://git-scm.com/doc
- GitHub CLI docs: https://cli.github.com/manual/
- Pro Git book: https://git-scm.com/book
