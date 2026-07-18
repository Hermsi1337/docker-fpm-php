# AGENTS.md

Working guide for AI agents and humans touching this repository. Read this
before making changes; it captures the invariants that are easy to break.

## What this is

A batteries-included **PHP-FPM on Alpine** image. One parameterised
[`Dockerfile`](./Dockerfile) builds PHP 7.1&ndash;8.5 in every variant; a
maintained [`versions.yaml`](./versions.yaml) drives both the CI build matrix
and the bundled extension set. Extensions are installed with
[`mlocati/docker-php-extension-installer`](https://github.com/mlocati/docker-php-extension-installer)
rather than hand-compiled. PHP 5.6 and 7.0 (where the installer cannot run)
build from a second, pinned [`Dockerfile.legacy`](./Dockerfile.legacy) &mdash;
see the legacy section below.

Images are published to two registries:

- Docker Hub: `hermsi/alpine-fpm-php`
- GHCR: `ghcr.io/hermsi1337/fpm-php`

**The tag scheme is a public contract** &mdash; users pin these tags, so do not
rename or drop them casually:

- `<X.Y>` &mdash; standard variant, multi-arch (`amd64` + `arm64`; PHP 5.6/7.0
  are `amd64`-only)
- `<X.Y>-composer` &mdash; standard plus Composer 2, multi-arch
- `<X.Y>-ioncube` &mdash; standard plus the ionCube loader, **`amd64` only**
- `latest`, `latest-composer`, `latest-ioncube` &mdash; track the newest GA
  release (the one flagged `latest: true` in `versions.yaml`)

## Repo layout

| Path                        | Purpose                                                        |
| --------------------------- | ------------------------------------------------------------- |
| `Dockerfile`                | Single multi-stage build for PHP 7.1+; targets `standard`/`composer`/`ioncube`. No default extension list &mdash; `PHP_EXTENSIONS` is a required build-arg. |
| `Dockerfile.legacy`         | Same targets for PHP 5.6/7.0 (`dockerfile: legacy` in `versions.yaml`): classic `docker-php-ext-install` + checksum-pinned PECL tarballs. |
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
   `ioncube` variant. Versions marked `dockerfile: legacy` carry
   `Dockerfile.legacy` into the matrix; everything else uses `./Dockerfile`.
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

**Legacy exception (PHP 5.6/7.0):** `Dockerfile.legacy` necessarily hard-codes
its build recipe (per-extension pins), so it cannot consume the list
dynamically. Instead it **asserts at build time** that `PHP_EXTENSIONS` (as
rendered from `versions.yaml`) matches the pinned recipe exactly and fails the
build on any drift. If you touch the global list, update the legacy recipe (and
its assert list) in the same change.

## The legacy build path (PHP 5.6 / 7.0)

`mlocati/docker-php-extension-installer` needs PHP 7.1+ on Alpine, so 5.6/7.0
build from `Dockerfile.legacy`. Facts that took real digging &mdash; do not
rediscover them:

- **Bases are frozen since January 2019**: `php:5.6-fpm-alpine` = 5.6.40 on
  Alpine 3.8, `php:7.0-fpm-alpine` = 7.0.33 on Alpine 3.7. The minor tags are
  digest-identical with the final patch tags (5.6.40 / 7.0.33). The old
  `dl-cdn` apk repos for those Alpine branches are still served (plain http).
- **PECL tarballs are fetched by BuildKit** (`ADD --checksum` into a `sources`
  stage, bind-mounted into the build). The frozen images never need TLS to
  pecl.php.net. Pins (last releases supporting each line):
  5.6 &rarr; apcu 4.0.11, imagick 3.4.4, memcached 2.2.0, redis 4.3.0,
  ssh2 0.13; 7.0 &rarr; apcu 5.1.21, imagick 3.4.4, memcached 3.1.5,
  redis 5.3.7, ssh2 1.4.1. Everything else is core `docker-php-ext-install`.
- **ionCube is pinned to loader 13.3.1** (immutable versioned URL,
  checksum-pinned). The current rolling archive still *ships* 5.6/7.0 loader
  binaries, but they **segfault** on these frozen musl bases &mdash; verified
  2026-07: current (15.5) and 14.4.1 crash; 13.3.1, 13.0.2, 12.0.5 and 10.4.5
  work. Do not "upgrade" this pin without re-testing `php -v` on both bases.
- **Composer variant ships Composer 2.2 LTS** (2.2.29, checksum-pinned phar)
  &mdash; the last line supporting PHP 5.3.2+. Do not bump it to 2.3+.
- **`amd64`-only**: the base manifests do publish `arm64/v8`, but the legacy
  compile path is validated on amd64 only and ionCube is amd64-only anyway.
- The full global extension set builds on both versions &mdash; there is
  currently **no** `extensions_remove` on the legacy entries.
- Legacy versions are `supported: false`: built on push/dispatch only, never
  on the weekly schedule.

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
  (`Dockerfile.legacy` pins its recipe but *asserts* it against the rendered
  list &mdash; drift fails the build.)
- `PHP_EXTENSIONS` is a **required** build-arg; a bare `docker build` must fail
  fast with a clear message.
- The `ioncube` variant is `amd64`-only and is skipped for PHP 8.0 (no loader).
  On 5.6/7.0 the loader pin (13.3.1) must not be bumped without re-testing on
  both frozen bases (newer loaders segfault).
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
- **Legacy arm64:** the 5.6/7.0 base manifests include `arm64/v8`; enabling it
  would require validating the whole legacy compile under QEMU first.
- **EOL versions** (PHP < 8.2) are built best-effort on frozen base images with
  **no security guarantees**; they are intentionally excluded from the weekly
  schedule.

## Note on `CLAUDE.md`

`CLAUDE.md` is a **git symlink** to this file (`AGENTS.md`), so both agent
conventions resolve to the same guide. On a Windows checkout git may materialise
it as a small text file whose contents are literally `AGENTS.md`. That is
expected &mdash; **never `git add` that materialised file**, or you would
replace the symlink with a text blob. Edit `AGENTS.md`; leave `CLAUDE.md` alone.
