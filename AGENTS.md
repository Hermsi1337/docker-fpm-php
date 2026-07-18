# AGENTS.md

Working guide for AI agents and humans touching this repository. Read this
before making changes; it captures the invariants that are easy to break.

## What this is

A batteries-included **PHP-FPM on Alpine** image. One parameterised
[`Dockerfile`](./Dockerfile) builds every PHP version (7.1&ndash;8.5) and every
variant; a maintained [`versions.yaml`](./versions.yaml) drives both the CI
build matrix and the bundled extension set. Extensions are installed with
[`mlocati/docker-php-extension-installer`](https://github.com/mlocati/docker-php-extension-installer)
rather than hand-compiled.

Images are published to two registries:

- Docker Hub: `hermsi/alpine-fpm-php`
- GHCR: `ghcr.io/hermsi1337/fpm-php`

**The tag scheme is a public contract** &mdash; users pin these tags, so do not
rename or drop them casually:

- `<X.Y>` &mdash; standard variant, multi-arch (`amd64` + `arm64`)
- `<X.Y>-composer` &mdash; standard plus Composer 2, multi-arch
- `<X.Y>-ioncube` &mdash; standard plus the ionCube loader, **`amd64` only**
- `latest`, `latest-composer`, `latest-ioncube` &mdash; track the newest GA
  release (the one flagged `latest: true` in `versions.yaml`)

## Repo layout

| Path                        | Purpose                                                        |
| --------------------------- | ------------------------------------------------------------- |
| `Dockerfile`                | Single multi-stage build; targets `standard`/`composer`/`ioncube`. No default extension list &mdash; `PHP_EXTENSIONS` is a required build-arg. |
| `versions.yaml`             | **Single source of truth**: build matrix + global/per-version extension list. |
| `build-local.sh`            | Build one image locally, reading args from `versions.yaml`.   |
| `test/smoke.sh`             | Assert a built image contains everything `versions.yaml` promises. |
| `.github/workflows/build.yml` | The whole CI/CD pipeline (matrix + build + smoke + push).   |
| `.github/dependabot.yml`    | Weekly `github-actions` version bumps (commit prefix `ci`).   |
| `conf.d/`                   | Recommended `opcache`/`apcu` tuning and `expose_php=Off`, copied into the image. |
| `AGENTS.md` / `CLAUDE.md`   | This guide. `CLAUDE.md` is a **git symlink** to `AGENTS.md` (see bottom). |

## CI/CD (`.github/workflows/build.yml`)

Two jobs:

1. **`prepare`** &mdash; converts `versions.yaml` to JSON with `yq -o=json` and
   builds the matrix with `jq`. Each PHP version expands into `standard` +
   `composer` (multi-arch) and, where a loader exists, an `amd64`-only
   `ioncube` variant.
2. **`build`** (matrix) &mdash; per `(php, variant)`:
   - resolve the effective extension list from `versions.yaml`;
   - build `linux/amd64` with `load: true`, then run `test/smoke.sh`;
   - for multi-arch variants, also build `linux/arm64` (QEMU), load it, and
     smoke-test it under `docker run --platform linux/arm64`;
   - **only after** the per-arch smoke tests pass, build the multi-arch image
     and push it (reusing the per-arch buildx caches, so the push build is
     cheap).

Trigger behaviour:

- **pull_request** &mdash; `amd64` only, **build-only**: no registry login, no
  push. Just build + smoke test. This is the safe path for fork PRs (no secrets
  required).
- **push to `master` / `workflow_dispatch`** &mdash; full lineup, multi-arch,
  push after smoke tests.
- **schedule** (weekly, `Mon 04:00 UTC`) &mdash; **supported versions only**
  (`supported: true`, i.e. PHP 8.2+). EOL versions sit on frozen base images, so
  rebuilding them buys nothing.
- **concurrency** &mdash; superseded PR runs are cancelled; push/dispatch/
  schedule runs are allowed to finish so in-flight pushes are never interrupted.

Secrets / permissions:

- `DOCKERHUB_USERNAME` + `DOCKERHUB_TOKEN` for Docker Hub; `GITHUB_TOKEN`
  (built-in) for GHCR. Logins are gated on `github.event_name != 'pull_request'`.
- Job permissions: `contents: read`, `packages: write` (GHCR).

## Extension maintenance (the important bit)

The bundled extension set is defined **once**, in `versions.yaml`:

```yaml
extensions:          # global list, every version/variant
  - apcu
  # ...
versions:
  - php: "7.2"
    extensions_add:  # optional per-version overrides
      - calendar
    # extensions_remove: [ ... ]
```

Effective list for a version = `extensions + extensions_add - extensions_remove`.

The **same** list flows to three consumers, which is what keeps them honest:

1. the build &mdash; rendered in through the `PHP_EXTENSIONS` build-arg (never
   hard-coded in the `Dockerfile`; a bare build fails fast);
2. CI &mdash; matrix and per-build extension list both come from `versions.yaml`;
3. `test/smoke.sh` &mdash; reads the same list back and asserts each extension
   is present (`php -m`), the PHP minor matches, `php-fpm -t` passes, and the
   variant extras work.

If you change the extension list, you change `versions.yaml` and nothing else;
the smoke test validates the result automatically.

## Common tasks

**Add a PHP version:** add an entry to `versions.yaml` (`php`, `platforms`,
`ioncube`, `supported`, `latest`). Set exactly one entry to `latest: true`.
Build + smoke it locally before pushing.

**Drop a PHP version:** remove its entry from `versions.yaml`. Remember the tag
scheme is a public contract &mdash; existing pushed tags are not deleted.

**Add / remove an extension globally:** edit the top-level `extensions` list.
For a single version, use `extensions_add` / `extensions_remove` on that entry.

**Build & test locally** (needs `bash`, `docker`, `jq`, and `yq` &mdash; falls
back to the `mikefarah/yq` container when `yq` is absent):

```bash
./build-local.sh 8.4 composer            # build
./test/smoke.sh fpm-php:8.4-composer 8.4 composer   # verify
```

## Invariants (do not break)

- `versions.yaml` is the **only** place PHP versions and extensions are defined.
  No extension list in the `Dockerfile`, the workflow, or the scripts.
- `PHP_EXTENSIONS` is a **required** build-arg; a bare `docker build` must fail
  fast with a clear message.
- The `ioncube` variant is `amd64`-only and is skipped for PHP 8.0 (no loader).
- **Every pushed image is smoke-tested first.** Never add a push path that
  bypasses `test/smoke.sh`.
- PRs must stay build-only and secret-free (fork-safe).
- **LF line endings** everywhere (enforced by `.gitattributes`); the shell
  scripts must stay executable.
- Don't touch the trigger / concurrency / secrets logic without a clear reason.

## Known follow-ups

- **ionCube arm64:** an arm64 loader now exists (ionCube 15.5.0), but the
  `ioncube` variant is still deliberately `amd64`-only. Extending it to arm64 is
  a possible future change (build arm64 + smoke-test it before enabling).
- **EOL versions** (PHP < 8.2) are built best-effort on frozen base images with
  **no security guarantees**; they are intentionally excluded from the weekly
  schedule.

## Note on `CLAUDE.md`

`CLAUDE.md` is a **git symlink** to this file (`AGENTS.md`), so both agent
conventions resolve to the same guide. On a Windows checkout git may materialise
it as a small text file whose contents are literally `AGENTS.md`. That is
expected &mdash; **never `git add` that materialised file**, or you would
replace the symlink with a text blob. Edit `AGENTS.md`; leave `CLAUDE.md` alone.
