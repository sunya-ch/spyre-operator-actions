# Spyre Operator GitHub Actions

Reusable GitHub Actions workflows for spyre-operator CI/CD pipeline.

## Available Workflows

| Workflow | Description | Use Case |
|----------|-------------|----------|
| [pre-commit.yaml](.github/workflows/pre-commit.yaml) | Run pre-commit hooks | PR checks, code quality |
| [unit-test.yaml](.github/workflows/unit-test.yaml) | Run Go unit tests and build | PR checks, continuous testing |
| [build-image.yaml](.github/workflows/build-image.yaml) | Build and push Docker images for specific architectures | Image builds |
| [version-patch.yaml](.github/workflows/version-patch.yaml) | Create a PR to bump the VERSION file | Manual version updates |
| [create-release.yaml](.github/workflows/create-release.yaml) | Create GitHub release from VERSION file | Release automation |
| [sonarqube-scan.yaml](.github/workflows/sonarqube-scan.yaml) | Perform Sonar Qube scan on repisotiry | code quality |

## Workflow Inputs Reference

### Pre-commit Workflow

```yaml
uses: ibm-aiu/spyre-operator-actions/.github/workflows/pre-commit.yaml@main
with:
  python-version: '3.13'              # Python version (default: '3.13')
  goprivate: 'github.com/ibm-aiu'    # GOPRIVATE for private modules (optional)
secrets:
  gh-token: ${{ secrets.GH_PAT }}    # PAT with repo scope (required for private repos)
```

**Inputs:**

- `python-version` (optional): Python version to use for pre-commit hooks
  - Type: string
  - Default: `'3.13'`
- `goprivate` (optional): GOPRIVATE environment variable for private Go modules
  - Type: string
  - Default: `''`
  - Example: `'github.com/ibm-aiu'` or `'github.com/ibm-aiu/*'`

**Secrets:**

- `gh-token` (optional): GitHub Personal Access Token with `repo` scope
  - Required if your code depends on private Go modules
  - Falls back to `GITHUB_TOKEN` if not provided (limited access)
  - Create PAT at: Settings → Developer settings → Personal access tokens

### Unit Test Workflow

```yaml
uses: ibm-aiu/spyre-operator-actions/.github/workflows/unit-test.yaml@main
with:
  go-version: '1.24.13'              # Go version (default: '1.24.13')
  goprivate: 'github.com/ibm-aiu'    # GOPRIVATE for private modules (optional)
secrets:
  gh-token: ${{ secrets.GH_PAT }}    # PAT with repo scope (required for private repos)
```

**Inputs:**

- `go-version` (optional): Go version to use for tests and build
  - Type: string
  - Default: `'1.24.13'`
- `goprivate` (optional): GOPRIVATE environment variable for private Go modules
  - Type: string
  - Default: `''`
  - Example: `'github.com/ibm-aiu'` or `'github.com/ibm-aiu/*'`

**Secrets:**

- `gh-token` (optional): GitHub Personal Access Token with `repo` scope
  - Required if your code depends on private Go modules
  - Falls back to `GITHUB_TOKEN` if not provided (limited access)
  - Create PAT at: Settings → Developer settings → Personal access tokens

### Build Image Workflow

```yaml
uses: ibm-aiu/spyre-operator-actions/.github/workflows/build-image.yaml@main
with:
  runner: 'ubuntu-latest'             # GitHub runner (default: 'ubuntu-latest')
  image_suffix: '-dev'                # Image tag suffix (default: '-dev')
  registry: 'ghcr.io/ibm-aiu'         # Container registry (default: 'ghcr.io/ibm-aiu')
# No secrets needed for pushing to ghcr.io in the same org - uses GITHUB_TOKEN automatically
```

For custom registries (Docker Hub, etc.):

```yaml
uses: ibm-aiu/spyre-operator-actions/.github/workflows/build-image.yaml@main
with:
  runner: 'ubuntu-latest'
  registry: 'your-registry'
secrets:
  registry-username: ${{ secrets.DOCKER_USERNAME }}
  registry-password: ${{ secrets.DOCKER_PASSWORD }}
```

**Inputs:**

- `runner` (optional): GitHub runner to use for building the image
  - Type: string
  - Default: `'ubuntu-latest'`
  - Examples: `'ubuntu-latest'`, `'ubuntu-24.04-arm64'`, `'self-hosted'`
  - **Architecture is automatically detected from the runner**
- `image_suffix` (optional): Suffix to append to IMAGE_TAG
  - Type: string
  - Default: `'-dev'`
  - Example: `'-dev'` creates tags like `1.0.0-dev-amd64`
- `registry` (optional): Container registry to push to
  - Type: string
  - Default: `'ghcr.io'`
  - Examples: `'ghcr.io'`, `'docker.io'`, `'quay.io'`

**Secrets:**

- `registry-username` (optional): Container registry username
  - **Not needed for ghcr.io** - uses `GITHUB_TOKEN` automatically
  - Required for other registries (Docker Hub, Quay.io, etc.)
- `registry-password` (optional): Container registry password or token
  - **Not needed for ghcr.io** - uses `GITHUB_TOKEN` automatically
  - Required for other registries (Docker Hub, Quay.io, etc.)

**Permissions:**

For pushing to GitHub Container Registry (ghcr.io):
- `packages: write`: Required to push images to ghcr.io
- Add to your workflow that calls this reusable workflow:
  ```yaml
  permissions:
    packages: write
  ```

**Requirements:**

- Repository must have a `VERSION` file containing semantic version (e.g., `1.0.0`)
- Repository must have a `Makefile` with `docker-build-push` target
- The `docker-build-push` target should use `REGISTRY`, and `IMAGE_TAG` environment variables

**How it works:**

The workflow automatically reads the version from the VERSION file, detects the architecture from the runner, and sets the following environment variables before running `make docker-build-push`:
- `VERSION`: Read from VERSION file (e.g., `1.0.0`)
- `ARCH`: Auto-detected from runner (e.g., `amd64` from `ubuntu-latest`, `arm64` from `ubuntu-24.04-arm64`)
- `IMAGE_TAG`: Constructed as `$(VERSION)$(image_suffix)-$(ARCH)` (e.g., `1.0.0-dev-amd64`)

**Supported architectures:**
- `amd64` (x86_64)
- `arm64` (aarch64)
- `ppc64le`
- `s390x`

### Version Patch Workflow

```yaml
uses: ibm-aiu/spyre-operator-actions/.github/workflows/version-patch.yaml@main
with:
  version_bump: ${{ inputs.version_bump }}  # Required: minor or major
  operator_sdk_version: 'v1.38.0'           # Optional: operator-sdk version (default: 'v1.38.0')
```

**Inputs:**

- `version_bump` (required): Version bump type
  - Type: choice
  - Options: `minor`, `major`
- `operator_sdk_version` (optional): Operator SDK version to install
  - Type: string
  - Default: `'v1.38.0'`
  - Only used for spyre-operator projects

**Permissions:**

- `contents: write`: Required to create the version bump branch and commit changes
- `pull-requests: write`: Required to create the pull request
- `actions: read`: Required for private reusable workflows

**Requirements:**

- Repository must contain a `VERSION` file
- Default target branch is `main`

**Special Behavior for spyre-operator Projects:**

When the workflow detects that the repository name is `spyre-operator`, it automatically performs additional steps after incrementing the version:

1. **Retrieve component versions**: Fetches the latest VERSION from dependent components:
   - spyre-device-plugin
   - spyre-scheduler
   - spyre-webhook-validator
   - spyre-health-checker
   - spyre-exporter
   - dra-driver-spyre
   
   All retrieved versions automatically get a `-dev` suffix appended. If a component's VERSION file is not found, it uses `$(cat VERSION)-dev` as a fallback version.

2. **Update release-artifacts.yaml**: Uses `yq` to update component versions in the release-artifacts.yaml file with the retrieved versions (or fallback versions) from step 1.

3. **Install operator-sdk**: Downloads and installs the specified version of operator-sdk

4. **Run make bundle**: Generates operator bundle manifests

5. **Run make propagate-version**: Propagates the new version throughout the project files

These steps ensure that all operator-related files and component dependencies are updated with the correct versions before creating the pull request.

### Create Release Workflow

```yaml
uses: ibm-aiu/spyre-operator-actions/.github/workflows/create-release.yaml@main
with:
  draft: false                        # Create as draft (default: false)
  prerelease: false                   # Mark as prerelease (default: false)
  generate_release_notes: true        # Auto-generate notes (default: true)
  tag_prefix: 'v'                     # Tag prefix (default: 'v')
secrets:
  gh-token: ${{ secrets.GITHUB_TOKEN }}  # GitHub token (optional)
```

**Inputs:**

- `draft` (optional): Create release as draft
  - Type: boolean
  - Default: `false`
  - When `true`, release is created but not published
- `prerelease` (optional): Mark release as prerelease
  - Type: boolean
  - Default: `false`
  - Useful for beta/RC versions
- `generate_release_notes` (optional): Automatically generate release notes
  - Type: boolean
  - Default: `true`
  - GitHub will generate notes from commits and PRs
- `tag_prefix` (optional): Prefix for the git tag
  - Type: string
  - Default: `'v'`
  - Example: `'v'` creates tags like `v1.0.0`, empty string creates `1.0.0`

**Secrets:**

- `gh-token` (optional): GitHub token for creating releases
  - Falls back to `GITHUB_TOKEN` if not provided
  - `GITHUB_TOKEN` is usually sufficient for public repositories

**Permissions:**

- `contents: write`: Required to create tags and releases
- `actions: read`: Required for private reusable workflows

**Requirements:**

- Repository must contain a `VERSION` file with semantic version (e.g., `1.0.0`)
- The workflow checks if the tag already exists to avoid conflicts

## Advanced Usage

### Using Different Versions

Override default versions:

```yaml
unit-test:
  uses: ibm-aiu/spyre-operator-actions/.github/workflows/unit-test.yaml@main
  with:
    go-version: '1.23.0'  # Use different Go version
```

### Pinning to Specific Version

Instead of using `@main`, pin to a specific version:

```yaml
pre-commit:
  uses: ibm-aiu/spyre-operator-actions/.github/workflows/pre-commit.yaml@v1.0.0
```

### Sequential Job Execution

Use `needs` to control job execution order:

```yaml
jobs:
  pre-commit:
    uses: ibm-aiu/spyre-operator-actions/.github/workflows/pre-commit.yaml@main
  
  unit-test:
    needs: pre-commit  # Only runs if pre-commit succeeds
    uses: ibm-aiu/spyre-operator-actions/.github/workflows/unit-test.yaml@main
```

### Multi-Architecture Image Builds

Build images for multiple architectures using a matrix strategy:

```yaml
jobs:
  build-images:
    permissions:
      packages: write  # Required for pushing to ghcr.io
    strategy:
      matrix:
        runner:
          - ubuntu-latest        # Builds amd64
          - ubuntu-24.04-arm64   # Builds arm64
    uses: ibm-aiu/spyre-operator-actions/.github/workflows/build-image.yaml@main
    with:
      runner: ${{ matrix.runner }}
    # Architecture is automatically detected from the runner
    # No secrets needed for ghcr.io - uses GITHUB_TOKEN automatically
```

Or build for specific architectures separately:

```yaml
jobs:
  build-amd64:
    permissions:
      packages: write
    uses: ibm-aiu/spyre-operator-actions/.github/workflows/build-image.yaml@main
    with:
      runner: ubuntu-latest  # Auto-detects amd64
  
  build-arm64:
    permissions:
      packages: write
    uses: ibm-aiu/spyre-operator-actions/.github/workflows/build-image.yaml@main
    with:
      runner: ubuntu-24.04-arm64  # Auto-detects arm64
```

## Requirements

### Workflow-Specific Requirements

**Pre-commit and Unit Test:**
- Repository must have `make test` and `make build` targets

**Build Image:**
- Repository must have a `Makefile` with `docker-build-push` target
- The target should accept `IMAGE_TAG`, `VERSION`, and `ARCH` environment variables
- Docker Buildx must be available (automatically set up by the workflow)

**Create Release:**
- Repository must have a `VERSION` file containing semantic version (e.g., `1.0.0`)
- The `VERSION` file should be updated before triggering the release workflow


### SonarQube Scan Workflow

**Triggers:**

- `push`: Runs on pushes to the `main` branch
- `pull_request`: Runs on PR events (opened, synchronize, reopened)
- `workflow_dispatch`: Can be manually triggered

**Required Secrets:**

- `SONAR_TOKEN`: SonarQube authentication token
- `SONAR_HOST_URL`: URL of your SonarQube server
- `SONAR_TRUSTSTORE_BASE64`: Base64-encoded truststore file for SSL/TLS verification
- `SONAR_CERTS_PASSWORD`: Password for the truststore file

**Required Variables:**

- `ORGID`: Organization identifier used in the project key

**SonarQube Configuration:**

The workflow automatically configures:
- Project key: `${ORGID}-${repository_id}`
- Project name: Repository full name
- Source directory: Current working directory (`.`)

## License

Apache-2.0

## Support

For issues or questions:

- Open an issue in the spyre-operator-actions repository
- Check existing issues for similar problems
- Provide workflow run logs when reporting issues
