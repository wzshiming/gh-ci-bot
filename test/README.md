# Testing

The test suite runs the real scripts (`bin/*.sh`, `plugins/**/*.plugin.sh`, `entrypoint.sh`) against a mocked `gh` (and `curl` and `git`) that logs every invocation and serves canned JSON fixtures, so nothing ever talks to GitHub. It is pure bash with no dependencies beyond `bash` and `jq`, and runs on every push and pull request via [`.github/workflows/test.yml`](../.github/workflows/test.yml).

## Running

Run the whole suite from the repository root:

```bash
./test/run.sh
```

Or only some specs, by name:

```bash
./test/run.sh release-note check-wip
```

On macOS, install GNU coreutils first (`brew install coreutils`) because the scripts use `realpath -m`; CI's ubuntu runners work out of the box.

## Layout

| Path                 | Description                                                                             |
| -------------------- | ---------------------------------------------------------------------------------------- |
| [`run.sh`](run.sh)   | The runner: executes every spec, or only the ones given as arguments.                     |
| [`specs/`](specs/)   | The specs, one file per feature.                                                          |
| [`lib.sh`](lib.sh)   | The assertion, log and fixture helpers the specs use, documented inline.                  |
| [`mock/`](mock/)     | The fake `gh`, `curl` and `git` put on `PATH`, logging every call and serving canned replies. |
