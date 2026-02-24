# Ontology

This document defines the complete ontology for Lapidary's knowledge graph. The ontology constrains which node types, relationship types, and connections are valid.

For behavioral specification and technical decisions, see [SPEC.md](../SPEC.md).

## Theoretical Background

Lapidary's extraction pipeline is inspired by the **Wikontic** methodology (arXiv 2512.00590v2), which demonstrates that predefined ontologies can guide LLMs to extract structured knowledge from unstructured text with high consistency.

The key insight applied here: rather than letting the LLM freely invent entity types and relationships, we provide a **static ontology** that defines exactly which types and constraints are valid. The LLM's role is limited to identifying instances of these predefined types within the text. A post-extraction **validator** then ensures ontology entailment — that every extracted triplet conforms to the type and constraint definitions.

### How Wikontic Applies to Lapidary

| Wikontic Concept | Lapidary Application |
|------------------|---------------------|
| Predefined ontology | Node types (Rubyist, CoreModule, Stdlib) and relationships (Maintenance, Contribute) are defined statically |
| LLM-based extraction | An LLM reads Issue/Journal content and outputs candidate triplets using the ontology vocabulary |
| Ontology entailment validation | A validator checks each triplet against type constraints and domain-range rules before graph insertion |
| Entity normalization | Author names and module names are resolved to canonical forms to prevent duplicate nodes |

## Node Types

### Rubyist

A person who participates in Ruby development discussions on bugs.ruby-lang.org.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `username` | String | Yes | Account name on bugs.ruby-lang.org (e.g., `matz`) |
| `display_name` | String | No | Full display name (e.g., `Yukihiro Matsumoto`) |
| `is_committer` | Boolean | No | Whether this person is a Ruby committer (defaults to `false` if unknown) |

**Identity**: Two Rubyist nodes are the same entity if they share the same `username`.

### CoreModule

A core module of the Ruby language (built into the interpreter, always available without `require`).

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | String | Yes | Canonical module name (e.g., `String`, `Array`, `IO`) |

**Identity**: Two CoreModule nodes are the same entity if they share the same `name` (case-sensitive).

### Stdlib

A standard library module shipped with Ruby (available via `require`).

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | String | Yes | Canonical library name (e.g., `net/http`, `json`, `openssl`) |

**Identity**: Two Stdlib nodes are the same entity if they share the same `name` (case-sensitive).

## Relationship Types

### Maintenance

Indicates that a Rubyist maintains or is responsible for a module.

| Attribute | Value |
|-----------|-------|
| Domain (source) | `Rubyist` where `is_committer = true` |
| Range (target) | `CoreModule` or `Stdlib` |
| Direction | Rubyist → Module |

**Semantics**: The Rubyist has maintenance responsibility — they review patches, fix bugs, and guide the module's evolution.

### Contribute

Indicates that a Rubyist contributes to or interacts with a module.

| Attribute | Value |
|-----------|-------|
| Domain (source) | `Rubyist` (any) |
| Range (target) | `CoreModule` or `Stdlib` |
| Direction | Rubyist → Module |

**Semantics**: The Rubyist has reported bugs, proposed features, submitted patches, or participated in discussions about the module.

## Domain-Range Constraints

The following table summarizes valid (source type, relationship, target type) combinations. Any triplet not matching a row in this table is invalid and must be rejected.

| Relationship | Source Type | Source Condition | Target Type |
|-------------|------------|-----------------|------------|
| `Maintenance` | `Rubyist` | `is_committer = true` | `CoreModule` |
| `Maintenance` | `Rubyist` | `is_committer = true` | `Stdlib` |
| `Contribute` | `Rubyist` | (none) | `CoreModule` |
| `Contribute` | `Rubyist` | (none) | `Stdlib` |

**Validation rules**:

1. The subject must be of type `Rubyist`
2. The object must be of type `CoreModule` or `Stdlib`
3. The relationship must be `Maintenance` or `Contribute`
4. For `Maintenance`, the subject's `is_committer` must be `true`
5. The object's `name` must exist in the curated module lists below

## Curated Module Lists

### Core Modules

The following are valid `CoreModule` names. This list covers Ruby's built-in classes and modules.

<!-- Placeholder: to be completed with the full list from Ruby source -->

- Array
- BasicObject
- Binding
- Class
- Comparable
- Complex
- Dir
- Encoding
- Enumerable
- Enumerator
- Errno
- Exception
- FalseClass
- Fiber
- File
- Float
- GC
- Hash
- IO
- Integer
- Kernel
- Marshal
- MatchData
- Math
- Method
- Module
- NilClass
- Numeric
- Object
- ObjectSpace
- Proc
- Process
- Ractor
- Random
- Range
- Rational
- Regexp
- Signal
- String
- Struct
- Symbol
- Thread
- Time
- TrueClass
- UnboundMethod

### Standard Libraries

The following are valid `Stdlib` names. This list covers Ruby's standard libraries.

<!-- Placeholder: to be completed with the full list from Ruby distribution -->

- abbrev
- base64
- benchmark
- bigdecimal
- bundler
- cgi
- csv
- date
- delegate
- digest
- drb
- english
- erb
- etc
- fcntl
- fiddle
- fileutils
- find
- forwardable
- getoptlong
- io/console
- io/nonblock
- io/wait
- ipaddr
- irb
- json
- logger
- monitor
- mutex_m
- net/ftp
- net/http
- net/imap
- net/pop
- net/smtp
- nkf
- objspace
- observer
- open-uri
- open3
- openssl
- optparse
- ostruct
- pathname
- pp
- prettyprint
- pstore
- psych
- racc
- rdoc
- readline
- reline
- resolv
- ripper
- ruby2_keywords
- securerandom
- set
- shellwords
- singleton
- socket
- stringio
- strscan
- syntax_suggest
- syslog
- tempfile
- time
- timeout
- tmpdir
- tsort
- un
- uri
- weakref
- yaml
- zlib

## Ontology Entailment Verification

A triplet `(subject, relationship, object)` is **entailed** by the ontology if and only if all of the following hold:

1. `subject.type` is a valid node type (`Rubyist`)
2. `object.type` is a valid node type (`CoreModule` or `Stdlib`)
3. `relationship` is a valid relationship type (`Maintenance` or `Contribute`)
4. The `(subject.type, relationship, object.type)` combination exists in the Domain-Range Constraints table
5. Any additional conditions on the source node are satisfied (e.g., `is_committer = true` for `Maintenance`)
6. The object's `name` exists in the corresponding curated module list

Triplets that fail any of these checks are rejected. The system logs the rejection reason at `warn` level for debugging and ontology refinement.
