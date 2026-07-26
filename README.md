# Qore json module

**As of Qore 3.0 the `json` module is delivered with Qore itself, so this branch is no longer
the source of the module for current Qore releases.**

This repository is *not* retired. **Only the `develop` branch is superseded** — every other
branch remains valid and is still built and released from here, because Qore and Qorus versions
running on those release lines continue to depend on the module. `2.x` is current for Qore 2.x,
and any of the older release-line branches may still be in use.

Branches are named after the **Qore** release line they support, not the module version:

| Branch | Qore release line | json module version |
| --- | --- | --- |
| `develop` | superseded — Qore 3.0 and later ship the module in-tree | 1.12.0, the final release from this branch |
| `2.x` | Qore 2.x | 1.9.2 |
| `1.19.x` | Qore 1.19.x | 1.8.3 |
| `1.12.x` | Qore 1.12.x | 1.8.2 |
| `0.9.x`, `0.9.4`, `0.9.3`, `0.8.13`, `0.8.12`, `master`, … | earlier Qore releases | see the branch |

The GitLab mirror, its CI pipeline and the `github-ci-helper` branch all remain in place to serve
these branches.

## Where the code went

Everything on `develop` is now part of the
[Qore repository](https://github.com/qoretechnologies/qore):

| What | Where it is now |
| --- | --- |
| `json` binary module (JSON, CBOR, TOON, JSON Schema, SAX parser, stream writer, JWT, JSON-RPC client) | `modules/json/` |
| JSON parser and serializer | the Qore library itself, exported as a public C++ API in `include/qore/QoreJson.h` |
| The 16 user modules listed below | `qlib/` |
| Test suites | `examples/test/modules/json/` and `examples/test/qlib/<Module>/` |
| Design documents | `design/` |

The user modules that moved: `A2aClient`, `A2aClientDataProvider`, `A2aServerHandler`,
`FhirRestClient`, `FhirRestDataProvider`, `JsonFileDataProvider`, `JsonLd`, `JsonRpcClientIo`,
`JsonRpcConnection`, `JsonRpcHandler`, `McpClient`, `McpClientDataProvider`, `McpServerHandler`,
`NdjsonDataProvider`, `OneRecordClient` and `OneRecordServerHandler`.

## What this means for you

### On Qore 3.0 and later

- **Nothing to install.** `%requires json` works out of the box, and so does every user module
  listed above. Module names and APIs are unchanged.
- **Remove the dependency.** Packages no longer need to require `qore-json-module`; the
  `qore-stdlib` package obsoletes and provides it.
- **Drop the conditionals.** `%try-module json` / `%ifdef NoJson` guards are no longer needed —
  json can no longer be absent. Use a plain `%requires json`.
- **C++ callers.** Builtin binary modules can parse and generate JSON directly via
  `<qore/QoreJson.h>` without loading this module or calling into Qore-language code.

### On earlier Qore releases

Nothing changes. Build and install the module from the branch matching your Qore release line, as
before.

## Licensing

The module source is dual-licensed LGPL 2.1 / MIT (see `COPYING.LGPL` and `COPYING.MIT`) and keeps
that licensing in the Qore tree. The vendored
[jsoncons](https://github.com/danielaparker/jsoncons) library it depends on is distributed under
the Boost Software License 1.0; in the Qore tree that notice is recorded in Qore's
`README-LICENSE`.

## Background

See [issue #5366](https://github.com/qoretechnologies/qore/issues/5366) for the rationale and the
full migration record, and `design/json-module-migration.md` in the Qore repository for the design
notes.
