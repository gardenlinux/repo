---
title: Creating APT Repository Releases
description: Comprehensive guide to creating releases for Garden Linux APT repositories
order: 2
related_topics:
  - /explanation/release-hierarchy.md
  - /explanation/packaging.md
  - /explanation/repo-infrastructure.md
  - /explanation/os-releases.md
  - /explanation/semver.md
  - /how-to/packaging/backporting.md
  - /how-to/releases/apt-repos.md
  - /how-to/releases/os-releases.md
  - /reference/releases/release-lifecycle
migration_status: "done"
migration_issue: "https://github.com/gardenlinux/gardenlinux/issues/4705"
migration_stakeholder: "@tmangold, @yeoldegrove, @ByteOtter"
migration_approved: false
github_org: gardenlinux
github_repo: repo
github_source_path: docs/how-to/releases/apt-repos.md
github_target_path: docs/how-to/releases/apt-repos.md
---

# Creating APT Repository Releases

This guide explains how to create minor releases for Garden Linux APT repositories. APT repository releases contain the packages that Garden Linux OS images consume during builds.

## Release Hierarchy

Garden Linux uses a [three-tier release hierarchy](/explanation/release-hierarchy.md) to deliver a complete operating system.

This document is about the second tier, the [Repository Infrastructure](/explanation/repo-infrastructure).

## Understanding APT Repository Releases

Please read the [APT Repository Infrastructure](/explanation/repo-infrastructure.md) to get familiar with the concepts for the Releases.

## Prerequisites

Before creating a minor release, ensure you have:

- Write access to the `gardenlinux/repo` repository
- `git` and `gh` CLI tool installed and configured

## Understanding package-releases and package-imports

The `repo` repository uses two key files to define what goes into a release:

### package-releases File

The `package-releases` file lists the specific versions of custom-built packages from `package-*` repositories to include in the release.

**Format**: Each line contains:

```
<package-name> <version-tag>
```

**Example**:

```
containerd v1.7.13
kernel 6.6.13
openssh 9.6p1
runc v1.1.12
```

**How to determine versions**:

1. Check the `package-*` repository for available release tags
2. Verify the package builds successfully in that version
3. Check dependencies and compatibility with other packages in the release

**To update a package**:

1. Find the package line in `package-releases`
2. Change the version tag to the desired release from the `package-*` repository
3. Verify that the new version is compatible with other packages

### package-imports File

The `package-imports` file specifies which packages should be imported directly from the Debian snapshot rather than being built from `package-*` repositories.

**Format**: Each line contains a Debian package name:

```
<package-name>
```

**Example**:

```
systemd
curl
glibc
```

**When to modify**:

- **Add a package**: When switching from a custom build to using the Debian version
- **Remove a package**: When you've created a custom build and no longer want to import from Debian

### Special Files

- **`.container` file**: Specifies the `repo-debian-snapshot` container image used as the build environment. This is set automatically for major releases and typically should not be changed for minor releases to maintain reproducibility.

## Creating a Minor Release

Follow these steps to create an APT repository minor release:

### Step 1: Prepare Your Environment

```bash
# Clone the repo repository if you haven't already
git clone https://github.com/gardenlinux/repo.git
cd repo

# Fetch all tags and branches
git fetch --tags
git fetch --all
```

### Step 2: Checkout the Base Release

```bash
# Checkout the base release tag you want to minor
# For example, to create minor 2150.1.0 based on 2150.0.0:
git checkout 2150.0.0

# Create a release branch (use rel-<MAJOR> naming convention)
git checkout -b rel-2150

# If the branch already exists, checkout and pull latest
# git checkout rel-2150
# git pull origin rel-2150
```

### Step 3: Modify Package Versions

Edit the `package-releases` file to update package versions:

```bash
# Open the file in your editor
vi package-releases

# Example: Update containerd from v2.1.1 to v2.2.3
# Change the line:
#   gardenlinux/package-containerd 2.1.1-0gl0+bp2150
# To:
#   gardenlinux/package-containerd 2.2.3-0gl0+bp2150
```

If you need to add or remove packages from Debian imports (e.g. because we are building it ourselves):

```bash
# Edit package-imports file
vi package-imports

# Add or remove Debian package names as needed
```

### Step 4: Verify Your Changes

Review your changes carefully:

```bash
# See what you've changed
git diff 2150.0.0

# Verify the package versions exist in their respective repositories
# For example, check that containerd v2.2.3 exists:
# https://github.com/gardenlinux/package-containerd/releases/tag/2.2.3-0gl0%2Bbp2150
```

**Important checks**:

- Verify all package versions in `package-releases` actually exist as releases in their respective repositories
- Ensure package versions are compatible with each other
- Check that dependency versions in Debian snapshot support your changes
- Consider impact on existing deployments

### Step 5: Commit and Push

```bash
# Commit your changes with a descriptive message
git add package-releases package-imports
git commit -m "Minor release 2150.1.0: Update containerd to v2.2.3-0gl0+bp2150 for CVE-2026-XXXXX"

# Push the branch to GitHub
git push origin rel-2150
```

### Step 6: Create the Release Tag

```bash
# Create a tag for the new minor release
# Use semantic versioning: <major>.<minor>.0
git tag 2150.1.0

# Push the tag
git push origin 2150.1.0
```

### Step 7: Monitor the Build

Once you push the tag, the `update.yml` GitHub Action will automatically:

1. Collect the specified package versions
2. Fetch dependencies from Debian snapshots
3. Assemble the APT repository
4. Sign it with the Garden Linux signing key
5. Publish to S3

Monitor the workflow:

```bash
# Watch the workflow status
gh run watch
```

Or check the GitHub Actions page: https://github.com/gardenlinux/repo/actions

## Verification and Testing

After the minor release is published, verify it works correctly:

### Verify APT Repository Structure

Check that the repository was published to S3:

```bash
# The repository should be available at:
# https://repo.gardenlinux.io/gardenlinux/dists/2150.1.0/
```

### Test Package Installation

In a test environment, configure the new repository and test package installation:

```bash
# Add the repository (in a test Garden Linux system)
echo "deb https://repo.gardenlinux.io/gardenlinux 2150.1.0 main" > /etc/apt/sources.list.d/gardenlinux.list

# Update package lists
apt update

# Verify your updated packages are available
apt policy <package-name>

# Test installing/upgrading
apt install <package-name>
```

### Verify Package Versions

Confirm that the packages in the repository match your `package-releases` file:

```bash
# Check package versions in the published repository
# This should show the versions you specified
apt-cache madison <package-name>
```

## Troubleshooting

### Build Failures

If the GitHub Action fails:

1. **Check the workflow logs**: Click on the failed workflow run in GitHub Actions
2. **Common issues**:
   - **Package version doesn't exist**: Verify the tag exists in the `package-*` repository
   - **Dependency conflicts**: Check if the new package version has dependency requirements that conflict with other packages
   - **Build errors**: The package may have failed to build properly in the `package-*` repository

### Package Not Found After Release

If packages aren't appearing in the repository:

1. Check that the workflow completed successfully
2. Verify the S3 bucket was updated (check timestamp)
3. Clear APT cache: `apt clean && apt update`
4. Check repository URL is correct in `/etc/apt/sources.list.d/`

### Dependency Resolution Failures

If you encounter dependency issues:

1. Check which Debian snapshot is being used (from `.container` file)
2. Verify dependencies exist in that snapshot
3. Consider whether you need to import additional packages from Debian

### Rolling Back a Minor Release

If you need to rollback:

1. Users can simply use the previous release: change APT sources to previous version tag
2. For OS builds, reference the previous APT repository version
3. If necessary, create a new minor release with reverted changes (do not delete tags)

## Related Topics

<RelatedTopics />
