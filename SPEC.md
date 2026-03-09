# SPEC.md

## Purpose

Lapidary builds a knowledge graph between Ruby core features and developers from issue notifications on bugs.ruby-lang.org, helping researchers understand the evolution of the Ruby language and community collaboration patterns.

## Users

- **Ruby core community researchers** — Want to understand the discussion history and participants for specific features
- **Ruby contributors** — Want to find related issues and past design decisions

## Impacts

- Researchers can trace the complete journey of Ruby features from proposal to implementation through structured data
- Contributors can quickly find issues and discussions related to their areas of interest

## Success Criteria

- Webhook endpoint can receive Issue ID notifications, fetch data from the Redmine API, create analysis jobs for each entity, and respond with correct status codes
- Analysis Service processes queued jobs and writes analysis records to the database
- Duplicate notifications for the same Issue do not create jobs for already tracked entities
- Failed analysis jobs are retried with exponential backoff; permanently failed jobs are logged
- Knowledge graph schema supports storing entities and relationships as Nodes and Edges with flexible metadata
- Ontology-guided extraction pipeline extracts (Rubyist, Maintenance|Contribute, CoreModule|Stdlib) triplets from Issue/Journal content via LLM
- Extracted triplets are validated against ontology constraints before writing to the knowledge graph
- Validation feedback corrects LLM extraction errors by sending validation failures back to the LLM for a single correction attempt before rejecting
- Graph neighbor query returns connected nodes with edge observations, supporting direction and time-range filtering
- Graph node query endpoint supports listing nodes by type, searching by name/display_name, and paginated results
- Expired jobs are automatically removed from the database based on a configurable retention period
- Knowledge graph explorer UI renders at `GET /` and allows visual exploration of nodes, edges, time-range filtering, and direction selection using existing Graph API endpoints
- Expired graph edges are automatically archived when the most recent observation exceeds a configurable retention period
- Archived edges and orphan nodes are excluded from default query results
- A maintenance console (`bin/console`) loads the application container for manual data inspection and correction

## Non-goals

- Ontology evolution — The ontology is static and predefined; automatic discovery or modification of node types and relationship types is out of scope
- Multi-hop reasoning — No inference chains or logical deduction across multiple edges; graph traversal queries are supported for exploration but do not derive new knowledge
- End-user authentication and access control
- Multi-worker concurrency
- Job priority queues

---

## Vision

The complete system encompasses four capabilities:

1. **Webhook reception** — Receive issue change notifications, fetch data from the Redmine API, and track analyzed entities
2. **Ontology-guided extraction** — Use a predefined ontology and LLM to extract structured triplets from issue data
3. **Knowledge graph construction** — Write validated triplets into a directed property graph
4. **Query and exploration** — Provide APIs and a browser-based visual explorer for querying the knowledge graph

## Features

1. **Webhook endpoint** — Receive Issue ID notifications, fetch Issue data from the Redmine API, and create analysis jobs for each entity (Issue and its untracked Journals)
2. **Job queue** — Persist pending analysis work to the database, ensuring reliable processing
3. **Analysis service** — A background worker that dequeues and processes analysis jobs sequentially
4. **Issue data fetching** — Retrieve Issue data from the Redmine JSON API to identify entities for analysis
5. **Analysis tracking** — Record analyzed Issues and Journals to avoid redundant processing and support incremental analysis
6. **Health check endpoint** — Report application availability status at a dedicated path
7. **Container deployment** — Package the application as a container image for deployment
8. **Knowledge graph storage** — Store entities and relationships as a directed graph using Node and Edge tables with flexible metadata
9. **Ontology definition** — Define permitted node types, relationship types, and domain-range constraints that govern the knowledge graph structure
10. **Triplet extraction** — Use an LLM to extract (Rubyist, Relationship, Module) triplets from Issue and Journal content
11. **Ontology validation** — Validate extracted triplets against ontology constraints; when validation fails, feed errors back to the LLM for correction before rejecting
12. **Graph neighbor query** — Query the knowledge graph to find nodes connected to a given node, with optional time-range filtering on edge observations
13. **Job cleanup** — TTL-based cleanup of expired jobs, executed periodically by the Analysis Service
14. **Graph node query** — List and search nodes in the knowledge graph, with optional type filtering, keyword search, and pagination
15. **Knowledge graph explorer** — A browser-based UI at the application root that visualizes the knowledge graph using Cytoscape.js, consuming the existing Graph API endpoints
16. **Graph edge archiving** — TTL-based archiving of expired edges, executed periodically by the Analysis Service; an edge is archived when its most recent observation exceeds the retention cutoff; archived edges are excluded from queries by default, and corresponding analysis records are cleared for re-analysis
17. **Maintenance console** — A `bin/console` entry point that loads the application container into an IRB session for manual data inspection and correction

## User Journeys

### Webhook Reception and Job Enqueueing

- **Context**: An external system detects a change to an issue on bugs.ruby-lang.org
- **Action**: The external system sends a Webhook containing the Issue ID to Lapidary
- **Outcome**: Lapidary fetches Issue data from the Redmine JSON API, creates an analysis job for the Issue and one for each untracked Journal (each job carries the data needed for analysis), and responds with 202 Accepted

### Analysis Processing

- **Context**: Analysis jobs are waiting in the job queue
- **Action**: The Analysis Service dequeues a job and performs analysis
- **Outcome**: An analysis record is written to the database, and the job is marked as done

### Incremental Analysis

- **Context**: The same Issue is notified multiple times because new journal replies have been added
- **Action**: The Webhook compares against the tracking table to identify journals that have not yet been tracked
- **Outcome**: Only newly added journals have jobs enqueued; previously analyzed journals are not affected

### Knowledge Graph Construction

- **Context**: The Analysis Service dequeues a job carrying Issue or Journal data
- **Action**: The system sends the job content to an LLM for triplet extraction, validates extracted triplets against the ontology — correcting validation errors via LLM feedback when possible — normalizes entities, and writes valid triplets to the knowledge graph as Nodes and Edges
- **Outcome**: The knowledge graph contains validated (Rubyist, Maintenance|Contribute, CoreModule|Stdlib) relationships with temporal qualifiers linking back to the source entity

### Graph Neighbor Exploration

- **Context**: A researcher wants to understand which modules a specific Rubyist works with
- **Action**: The researcher queries the graph neighbor API with a node ID to retrieve all directly connected nodes and their edges
- **Outcome**: The API returns the queried node along with all neighbor nodes and edges, enabling the researcher to explore relationship patterns

### Time-based Query Filtering

- **Context**: A researcher wants to see how a Rubyist's module involvement has changed over a specific period
- **Action**: The researcher queries the graph neighbor API with a node ID and a time range (`observed_after` / `observed_before`) to filter edges by their observation timestamps
- **Outcome**: Only edges with at least one observation within the specified time range are returned, enabling analysis of how involvement patterns change over time

### Job Retry on Failure

- **Context**: The Analysis Service fails to process a job
- **Action**: The job is rescheduled for retry with exponential backoff
- **Outcome**: The job is retried at a later time; if the maximum number of attempts is exceeded, the job is marked as permanently failed and the error is logged

### Job Cleanup

- **Context**: Completed or permanently failed jobs accumulate in the database over time
- **Action**: The Analysis Service periodically checks for and deletes jobs that have exceeded the configured retention period
- **Outcome**: Terminal-state jobs (done/failed) and stale claimed jobs older than the TTL are removed, keeping the database lean

### Node Listing and Search

- **Context**: A researcher wants to browse all Rubyists in the knowledge graph or find a specific module
- **Action**: The researcher queries the graph node API with optional type filter and/or search keyword
- **Outcome**: The API returns a paginated list of matching nodes, enabling the researcher to discover entities in the knowledge graph

### Visual Graph Exploration

- **Context**: A researcher wants to visually explore the knowledge graph
- **Action**: The researcher opens the application root URL in a browser
- **Outcome**: The UI renders an interactive graph visualization; the researcher can search for nodes, click to explore neighbors, and see relationship details

### Time-based Visual Filtering

- **Context**: A researcher is viewing a node's neighborhood in the UI
- **Action**: The researcher sets a time range and direction filter
- **Outcome**: The graph view updates to show only edges with observations within the specified time range and matching direction

### Node Detail Inspection

- **Context**: A researcher sees an interesting node or edge in the graph visualization
- **Action**: The researcher clicks on a node or edge
- **Outcome**: A detail panel displays the node's metadata or the edge's observations (evidence, timestamps, source entities)

### Graph Edge Archiving

- **Context**: Over time, observations accumulate and may include outdated or incorrect LLM analysis results
- **Action**: The Analysis Service periodically checks each edge's most recent observation; when the most recent `observed_at` exceeds the configured retention period, the entire edge is archived by setting `edges.archived_at`
- **Outcome**: Expired edges are archived, nodes with no active (non-archived) edges are excluded from queries by default, and corresponding analysis records are cleared so that entities can be re-analyzed on the next webhook notification; if the LLM no longer produces the same triplet on re-analysis, the edge remains archived (self-correcting)

### Manual Edge Archiving

- **Context**: An operator discovers incorrect or unwanted edges in the knowledge graph
- **Action**: The operator runs `bin/console` to load the application container and manually archives specific edges by setting their `archived_at` timestamp
- **Outcome**: Targeted edges are archived and excluded from default queries; corresponding analysis records are cleared to allow re-analysis on the next webhook notification

### Manual Node Deletion

- **Context**: An operator wants to remove a node that has no active edges (it may still have archived edges)
- **Action**: The operator runs `bin/console` and calls `delete_node(node_id)` to remove the node
- **Outcome**: Any archived edges and their observations are automatically purged, then the node is physically deleted from the database

### Manual Node Renaming

- **Context**: An operator discovers a node with an incorrect or outdated ID in the knowledge graph
- **Action**: The operator runs `bin/console` and calls `rename_node(old_id, new_id)` to rename the node
- **Outcome**: All edges and observations are migrated to the new node ID; if the target node already exists, node data is merged and edge observations are deduplicated; the old node is deleted

### Manual Graph Maintenance

- **Context**: An operator discovers incorrect data in the knowledge graph
- **Action**: The operator runs `bin/console` to load the application container and uses repositories and database tools to inspect and correct data
- **Outcome**: The operator can examine and fix graph data directly through the container API

---

## Behavior

### Health Check Endpoint

**Endpoint**: `GET /health`

**Responses**:

| Condition | Status Code | Body |
|-----------|-------------|------|
| Application is running | `200 OK` | `{ "status": "ok" }` |

Content-Type: `application/json`

### Knowledge Graph Explorer Endpoint

**Endpoint**: `GET /`

**Purpose**: Serve a single-page HTML application that provides interactive visual exploration of the knowledge graph.

**Response 200**: HTML page with:
- Cytoscape.js loaded via CDN
- JavaScript that consumes the existing Graph API endpoints (`GET /graph/nodes`, `GET /graph/neighbors`)

**UI Capabilities** (constrain design, open implementation):

| Capability | Description |
|------------|-------------|
| Node search | Search nodes by type and keyword, displaying results as a selectable list |
| Graph visualization | Display nodes and edges as an interactive graph using Cytoscape.js |
| Neighbor exploration | Click a node to fetch and display its neighbors from the Graph API |
| Direction filter | Select edge direction (outbound, inbound, both) for neighbor queries |
| Time-range filter | Set observed_after/observed_before to filter edges by observation time |
| Node detail | Display node metadata (type, data) when a node is selected |
| Edge detail | Display edge observations (evidence, timestamps, source entities) when an edge is selected |

**Content-Type**: `text/html`

**Initial state**: On page load, the UI displays the node search interface with no graph rendered. The graph visualization area remains empty until the user searches for and selects a node.

**Data source**: All graph data is fetched client-side via the existing JSON API endpoints. The server only serves the static HTML page.

**Responses**:

| Condition | Status Code | Body |
|-----------|-------------|------|
| Application is running | `200 OK` | HTML page |

### Webhook Endpoint

**Endpoint**: `POST /webhook`

**Authentication**:

- When the `WEBHOOK_SECRET` environment variable is set, requests must include a `?token=<value>` query parameter matching the configured secret
- When `WEBHOOK_SECRET` is not set, all requests are accepted without token verification
- Token comparison uses constant-time comparison to prevent timing attacks

**Request format**:

```json
{
  "issue_id": 12345
}
```

**Validation rules**:

- Content-Type must be `application/json`
- Body must be valid JSON
- Must include the `issue_id` field with a positive integer value

**Processing flow**:

1. Verify authentication (when `WEBHOOK_SECRET` is set)
2. Validate the request
3. Fetch Issue data from the Redmine API (including journals)
4. Determine which entities (Issue and Journals) are not yet tracked
5. Create one analysis job per untracked entity, each carrying the fields defined in the Job Arguments field mapping (see Issue Data Fetching)
6. Respond with 202 Accepted

**Responses**:

| Condition | Status Code | Body |
|-----------|-------------|------|
| Request processed successfully (zero or more analysis jobs enqueued) | `202 Accepted` | `{ "status": "accepted" }` |
| Missing or invalid token (when `WEBHOOK_SECRET` is set) | `401 Unauthorized` | `{ "error": "unauthorized" }` |
| Non-JSON request | `415 Unsupported Media Type` | `{ "error": "Content-Type must be application/json" }` |
| Invalid payload (malformed JSON or missing `issue_id`) | `422 Unprocessable Entity` | `{ "error": "..." }` |
| Redmine API unreachable or non-200 response | `502 Bad Gateway` | `{ "error": "failed to fetch issue from Redmine" }` |
| Internal processing failure | `500 Internal Server Error` | `{ "error": "internal server error" }` |

### Issue Data Fetching

**Data source**: `https://bugs.ruby-lang.org/issues/{id}.json?include=journals`

After receiving a Webhook, Lapidary fetches Issue data from the Redmine JSON API. The request includes the `include=journals` parameter to capture both the original author and all respondent data. The fetched data is attached to each analysis job so that the Analysis Service can process it without calling the Redmine API.

**Redmine API response structure** (relevant fields):

```json
{
  "issue": {
    "id": 12345,
    "subject": "Add new feature",
    "tracker": { "id": 2, "name": "Feature" },
    "status": { "id": 1, "name": "Open" },
    "priority": { "id": 2, "name": "Normal" },
    "author": { "id": 1, "name": "matz (Yukihiro Matsumoto)" },
    "created_on": "2024-01-15T10:30:00Z",
    "updated_on": "2024-01-16T14:20:00Z",
    "journals": [
      {
        "id": 1,
        "user": { "id": 2, "name": "nobu (Nobuyoshi Nakada)" },
        "notes": "Review comment here",
        "created_on": "2024-01-16T14:20:00Z"
      }
    ]
  }
}
```

**Analysis Records field mapping**:

| Stored Field | Source | Type | Description |
|--------------|--------|------|-------------|
| `entity_type` | Derived | String | `issue` or `journal` |
| `entity_id` | `issue.id` or `issue.journals[].id` | Integer | The ID of the tracked entity |
| `analyzed_at` | System clock | DateTime | Timestamp when the analysis record was created |

**Job Arguments field mapping**:

The Redmine API returns author names in the format `"username (Display Name)"` (e.g., `"matz (Yukihiro Matsumoto)"`). When no display name is present, the field contains only the username without parentheses.

Each analysis job carries a minimal set of fields extracted from the Redmine API response. The structure differs by entity type:

*Issue Job Arguments:*

| Field | Source | Type | Description |
|-------|--------|------|-------------|
| `entity_type` | Derived | String | Fixed value `issue` |
| `entity_id` | `issue.id` | Integer | Issue ID |
| `content` | `issue.subject` | String | Issue title/content |
| `author_username` | `issue.author.name` (before parentheses) | String | Author account name |
| `author_display_name` | `issue.author.name` (inside parentheses) | String | Author display name |
| `created_on` | `issue.created_on` | DateTime | Issue creation timestamp (used as `observed_at` for graph edges) |

*Journal Job Arguments:*

| Field | Source | Type | Description |
|-------|--------|------|-------------|
| `entity_type` | Derived | String | Fixed value `journal` |
| `entity_id` | `journal.id` | Integer | Journal ID |
| `content` | `journal.notes` | String | Journal reply content |
| `author_username` | `journal.user.name` (before parentheses) | String | Respondent account name |
| `author_display_name` | `journal.user.name` (inside parentheses) | String | Respondent display name |
| `issue_id` | `issue.id` | Integer | Associated Issue ID |
| `issue_content` | `issue.subject` | String | Associated Issue title (provides context) |
| `created_on` | `journal.created_on` | DateTime | Journal creation timestamp (used as `observed_at` for graph edges) |

### Analysis Tracking

**Purpose**: Record which Issues and Journals have been analyzed, enabling incremental analysis when the same Issue is notified multiple times.

**Tracking table structure** (single table, polymorphic design):

| Field | Type | Description |
|-------|------|-------------|
| `entity_type` | String | `issue` or `journal` |
| `entity_id` | Integer | Issue ID or Journal ID |
| `analyzed_at` | DateTime | Timestamp when the record was created |

- `entity_type` + `entity_id` must be jointly unique; duplicate writes do not create new records.

**Usage in Webhook processing**:

- After Issue data is fetched, the tracking table is queried to determine which Journals have not yet been tracked. Jobs are only created for untracked entities.
- All untracked journals create analysis jobs regardless of whether notes are empty.

**Usage in Analysis Service**:

- After a job is successfully processed, an analysis record is created to mark the entity as analyzed.

**Query behavior**:

- Given an Issue ID and a list of Journal IDs (from the Redmine API response), the system determines which Journal IDs have not yet been tracked.
- Untracked means no corresponding `(journal, journal_id)` record exists in the tracking table.

### Job Queue

**Purpose**: Persist pending analysis work to the database, ensuring jobs survive process restarts and are processed reliably.

**Job record structure** (logical):

| Field | Description |
|-------|-------------|
| Job identity | Unique identifier for the job |
| Arguments | The fields defined in the Job Arguments field mapping (see Issue Data Fetching): entity type, entity ID, author, and content information extracted from the Redmine API response |
| Status | Current state of the job |
| Attempts | Number of times the job has been attempted |
| Max attempts | Maximum number of retry attempts allowed |
| Error info | Error message from the most recent failure |
| Scheduled time | When the job should next be executed |

**Status transitions**:

- `pending` → `claimed`: Worker picks up the job for processing
- `claimed` → `done`: Processing completes successfully
- `claimed` → `failed`: Processing fails and max attempts exceeded
- `claimed` → `pending`: Processing fails but retries remain, or graceful shutdown releases the job

**Data strategy**: Each job carries all data needed from the Redmine API. The Analysis Service does not call the Redmine API, but does call an LLM API for triplet extraction.

#### Job Cleanup

**Trigger**: The Analysis Service poll loop periodically executes job cleanup. Cleanup does not need to run on every poll iteration — it runs at the interval configured by `CLEANUP_INTERVAL` (default: 86400 seconds / 1 day).

**Retention period**: Configured via the `JOB_RETENTION` environment variable, formatted as a number followed by a unit suffix (`12h`, `1d`, `7d`). Default: `7d`.

- Supported units: `h` (hours), `d` (days)
- Invalid values are treated as errors: a warning is logged at startup and the default value is used

**Cleanup rules**:

- Delete jobs in `done` status whose `updated_at` exceeds the retention period
- Delete jobs in `failed` status whose `updated_at` exceeds the retention period
- Delete jobs in `claimed` status whose `updated_at` exceeds the retention period (treated as stale/abandoned)

**Deletion method**: Hard delete — rows are removed directly from the jobs table. No archival is performed, as job data has no value after the graph has been written.

### Graph Edge Archiving

**Trigger**: The Analysis Service poll loop periodically executes graph edge archiving. Archiving does not need to run on every poll iteration — it shares the same `CLEANUP_INTERVAL` as job cleanup (default: 86400 seconds / 1 day).

**Retention period**: Configured via the `GRAPH_RETENTION` environment variable, formatted as a number followed by a unit suffix (`12h`, `1d`, `180d`). Default: `180d`.

- Supported units: `h` (hours), `d` (days)
- Invalid values are treated as errors: a warning is logged at startup and the default value is used

**Archive rules** (executed in order):

1. For each non-archived edge (`archived_at IS NULL`), find its most recent observation (`MAX(observed_at)`). If the most recent `observed_at < cutoff`, archive the edge by setting `edges.archived_at` to the current timestamp, collecting the edge's observations' `(source_entity_type, source_entity_id)` pairs for use in step 2
2. Perform Analysis Record Reset: clear analysis records whose `(entity_type, entity_id)` match the `(source_entity_type, source_entity_id)` pairs collected in step 1 — this allows the entity to be re-analyzed on the next webhook notification

**Unarchive rule**: When a new observation is inserted into an archived edge (i.e., the edge has `archived_at IS NOT NULL`), clear the edge's `archived_at` to restore it to active status. This happens naturally when re-analysis produces the same triplet.

**Visibility**: Edges and nodes are not physically deleted. Query-time filtering determines visibility — archived edges (`archived_at IS NOT NULL`) and nodes with no active (non-archived) edges are excluded from default query results.

**Archive method**: Soft archive — edges are marked with `archived_at` timestamp. Node visibility is determined at query time based on whether the node has any active edges.

### Analysis Service

**Purpose**: A background worker service that dequeues and processes analysis jobs from the job queue.

**Processing model**:

- Single worker, sequential processing — one job at a time
- Dequeues a job, writes the analysis record, and marks the job as done
- The analysis record marks the entity in the tracking table as analyzed
- Job Arguments carry entity data for knowledge graph construction
- Periodically executes job cleanup to remove expired jobs from the queue (see Job Queue § Job Cleanup)
- Periodically executes graph edge archiving to archive expired edges (see Graph Edge Archiving)

**Analysis domain model**:

Job Arguments capture the data needed to identify relationships between Rubyists and Ruby Core Modules. The Analysis Service uses an ontology-guided extraction pipeline inspired by the Wikontic methodology (see [Ontology](docs/ontology.md) for complete type enumerations and theoretical background).

The pipeline processes each job through four stages:

**1. Triplet Extraction** — An LLM receives the Job Arguments and outputs candidate triplets.

- *Input*: `entity_type`, `content`, `author_username`, `author_display_name`, and for journals: `issue_id`, `issue_content`
- *Output*: Zero or more triplets of the form `{ subject: Rubyist, relationship: Maintenance | Contribute, object: CoreModule | Stdlib, evidence: String }`
- The LLM prompt includes the ontology schema (permitted types and constraints) to guide extraction
- The LLM may return zero triplets if the content does not describe a relevant relationship
- Jobs with empty `content` (e.g., journals with no notes) are sent to the LLM normally; the expected result is zero triplets

**2. Entity Normalization** — Extracted triplets are normalized to canonical entities using Job Arguments context.

*Rubyist Normalization (Job-context resolution):*

- Matching uses case-insensitive string comparison (LLM output may vary in casing)
- Canonical identity for a Rubyist is `username` (see [Ontology](docs/ontology.md) § Rubyist Identity)
- If the extracted subject name matches the Job's `author_username`, use `author_username` as the canonical username
- If the extracted subject name matches the Job's `author_display_name`, resolve to `author_username`
- If neither matches, use the extracted name directly as the canonical username (represents a different Rubyist mentioned in the content)
- When the subject resolves to the Job's author, `author_display_name` from Job Arguments is carried forward as the Rubyist's `display_name` for node data

*Module Normalization:*

- Validation (Stage 3) ensures the object name exists in the curated module list via case-sensitive exact match (consistent with [Ontology](docs/ontology.md) § CoreModule/Stdlib Identity)
- Normalization passes the extracted name through as-is — no additional transformation is applied

**3. Ontology Validation** — Each normalized triplet is validated against the ontology constraints. When validation fails, the system attempts correction via LLM feedback before rejecting.

*Validation rules:*

- Subject node type must be `Rubyist`
- Object node type must be `CoreModule` or `Stdlib`
- Relationship must be `Maintenance` or `Contribute`
- The relationship's domain-range constraint must be satisfied (see [Ontology](docs/ontology.md))
- `Maintenance` requires the subject to have `role = maintainer`
- Object name must exist in the curated module list
- Subject name must not be a reserved anonymous identifier (e.g., `Anonymous`); such names represent unidentifiable users and are rejected

*Validation feedback correction:*

- When a triplet fails any validation rule, the system sends the original triplet and its validation errors back to the LLM for correction
- The LLM receives: the failing triplet, the specific validation error messages, and the original extraction context
- The corrected triplet is re-validated against the same rules
- Maximum one correction attempt per triplet; if the corrected triplet still fails validation, it is rejected
- `Maintenance` role constraint after correction: if the corrected triplet still has `Maintenance` with a non-maintainer role, the triplet is downgraded to `Contribute`
- Triplets that pass initial validation proceed directly without correction
- Correction attempts are logged at `info` level with the original error and correction result
- Final rejections (after failed correction) are logged at `warn` level
- Triplets rejected for reserved anonymous subject names are not eligible for correction — the identity is inherently unresolvable

**4. Graph Writing** — Normalized triplets are written to the knowledge graph.

- Subject and object are created as Nodes (upserted by canonical identity); Rubyist node `data` is merged with `display_name` from normalization
- The relationship is upserted as an Edge; an observation record is inserted into the `observations` table:
  - `observed_at`: the `created_on` timestamp from the source Issue or Journal
  - `source_entity_type`: `issue` or `journal`
  - `source_entity_id`: the ID of the source entity
  - `evidence`: the LLM-generated summary from the triplet

**Retry behavior**:

- Failed jobs are retried with exponential backoff
- A maximum number of attempts is enforced; jobs exceeding this limit are marked as permanently failed
- Specific backoff parameters (base delay, max delay, max attempts) are implementation choices and not prescribed by this specification

**Graceful shutdown**:

- On shutdown signal, the service finishes the current in-progress job or releases it back to the queue
- No new jobs are claimed after shutdown is initiated

### Graph Neighbor Query Endpoint

**Endpoint**: `GET /graph/neighbors`

**Purpose**: Query the knowledge graph to find all nodes directly connected to a given node, with optional time-range filtering on edge observations.

**Query parameters**:

| Parameter | Required | Type | Default | Description |
|-----------|----------|------|---------|-------------|
| `node_id` | Yes | String | — | Node ID in `type://name` format (e.g., `Rubyist://matz`) |
| `direction` | No | String | `both` | Edge direction filter: `outbound`, `inbound`, or `both` |
| `observed_after` | No | String | — | ISO 8601 datetime — include edges where `observed_at >= observed_after` (inclusive) |
| `observed_before` | No | String | — | ISO 8601 datetime — include edges where `observed_at <= observed_before` (inclusive) |
| `include_archived` | No | Boolean | `false` | When `true`, include archived edges in results; when `false`, only active edges (`edges.archived_at IS NULL`) are returned |

**Response 200**:

```json
{
  "node": {
    "id": "Rubyist://matz",
    "type": "Rubyist",
    "data": { "display_name": "Yukihiro Matsumoto" }
  },
  "neighbors": [
    {
      "node": {
        "id": "CoreModule://String",
        "type": "CoreModule",
        "data": {}
      },
      "edges": [
        {
          "source": "Rubyist://matz",
          "target": "CoreModule://String",
          "relationship": "Contribute",
          "observations": [
            {
              "observed_at": "2024-01-15T10:30:00Z",
              "source_entity_type": "issue",
              "source_entity_id": 12345,
              "evidence": "Discussed String encoding improvements"
            }
          ]
        }
      ]
    }
  ]
}
```

Content-Type: `application/json`

**Behavior**:

- Returns the queried node and all neighbor nodes with connecting edges
- When `direction` is `outbound`, only edges where the queried node is the source are included
- When `direction` is `inbound`, only edges where the queried node is the target are included
- When `direction` is `both`, edges in either direction are included
- By default, only active edges (`edges.archived_at IS NULL`) are included; when `include_archived` is `true`, both active and archived edges are returned
- When time-range parameters are specified, only edges with at least one matching observation are included; the `observations` array in the response is filtered to contain only matching observations
- When no time-range parameters are specified, all qualifying edges and their observations are included
- An edge is included only if it satisfies the active/archived filter and has at least one observation matching the time-range filter (if specified)
- When `include_archived` is `true`, each edge object in the response includes an `archived_at` field (`null` for active, ISO 8601 datetime for archived); when `include_archived` is `false` (default), `archived_at` is omitted from edge objects since all returned edges are active
- Neighbors with no matching edges after filtering are excluded from the response

**Validation rules**:

- `node_id` is required and must match the `type://name` format
- `direction` must be one of `outbound`, `inbound`, or `both`
- `observed_after` and `observed_before` must be valid ISO 8601 datetime strings when provided

**Responses**:

| Condition | Status Code | Body |
|-----------|-------------|------|
| Query processed successfully | `200 OK` | `{ "node": {...}, "neighbors": [...] }` |
| Missing or invalid parameters | `400 Bad Request` | `{ "error": "..." }` |
| Node not found | `404 Not Found` | `{ "error": "node not found" }` |
| Internal processing failure | `500 Internal Server Error` | `{ "error": "internal server error" }` |

### Graph Node Query Endpoint

**Endpoint**: `GET /graph/nodes`

**Purpose**: List and search nodes in the knowledge graph, with optional type filtering, keyword search, and pagination.

**Query parameters**:

| Parameter | Required | Type | Default | Description |
|-----------|----------|------|---------|-------------|
| `type` | No | String | — | Filter by node type (e.g., `Rubyist`, `CoreModule`, `Stdlib`) |
| `q` | No | String | — | Search keyword — matches against node name (extracted from ID) and `display_name` in node data |
| `limit` | No | Integer | `20` | Maximum number of nodes per page (max: 100) |
| `offset` | No | Integer | `0` | Number of nodes to skip |
| `include_orphans` | No | Boolean | `false` | When `false` (default), exclude nodes that have no active edges; when `true`, include all nodes regardless of edge status |

**Search behavior**:

- Search uses case-insensitive substring matching
- Search scope: the name portion of the node ID (`type://name`) and the `display_name` field in node data (currently only `Rubyist` nodes carry `display_name`; other node types have empty `data`)
- `type` and `q` can be used together (AND logic)
- When no filter parameters are provided, all nodes are returned (paginated)

**Node visibility**:

- By default (`include_orphans=false`), only nodes that have at least one active edge (`edges.archived_at IS NULL`) are returned
- When `include_orphans=true`, all nodes are returned regardless of edge status
- `include_orphans` operates independently from the neighbor query's `include_archived` parameter; `include_orphans` controls node-level visibility based on active edge existence, while `include_archived` controls edge-level visibility in neighbor queries
- This filtering is applied after `type` and `q` filters and before pagination

**Response 200**:

```json
{
  "nodes": [
    {
      "id": "Rubyist://matz",
      "type": "Rubyist",
      "data": { "display_name": "Yukihiro Matsumoto" }
    }
  ],
  "total": 42,
  "limit": 20,
  "offset": 0
}
```

Content-Type: `application/json`

**Validation rules**:

- `type` must be one of the ontology-defined node types (`Rubyist`, `CoreModule`, `Stdlib`)
- `limit` must be a positive integer between 1 and 100
- `offset` must be a non-negative integer
- `q`, if provided, must be at least 1 character long
- `include_orphans`, if provided, must be a boolean value (`true` or `false`)

**Responses**:

| Condition | Status Code | Body |
|-----------|-------------|------|
| Query processed successfully | `200 OK` | `{ "nodes": [...], "total": N, "limit": N, "offset": N }` |
| Invalid parameters | `400 Bad Request` | `{ "error": "..." }` |
| Internal processing failure | `500 Internal Server Error` | `{ "error": "internal server error" }` |

### Knowledge Graph Schema

**Purpose**: Store entities and their relationships as a directed property graph, governed by the ontology.

**Node table**:

| Field | Type | Description |
|-------|------|-------------|
| `id` | Text (PK) | Unique node identifier |
| `type` | Text (NOT NULL) | Node classification — constrained to ontology types: `Rubyist`, `CoreModule`, `Stdlib` |
| `data` | Text (JSON) | Flexible metadata as JSON |
| `created_at` | DateTime | Creation timestamp |
| `updated_at` | DateTime | Last update timestamp |

- `type` is indexed for efficient filtering
- `type` values are constrained by the ontology (see [Ontology](docs/ontology.md))

**Node `data` schema by type**:

| Node Type | `data` Fields | Description |
|-----------|---------------|-------------|
| `Rubyist` | `{ display_name?, role }` | `display_name` (String, optional): full display name, accumulated from observations — latest non-nil value wins. `role` (String): `maintainer`, `submaintainer`, or `contributor` (default `contributor`). |
| `CoreModule` | `{}` | No additional metadata beyond the node identity |
| `Stdlib` | `{}` | No additional metadata beyond the node identity |

**Node upsert behavior**: When a node is upserted by canonical identity, `data` fields are **merged** (not overwritten). New non-nil values update existing fields. Existing fields not present in the new data are preserved. This ensures that metadata accumulates over time as more observations arrive.

**Edge table**:

| Field | Type | Description |
|-------|------|-------------|
| `source` | Text (NOT NULL, FK → nodes.id) | Source node |
| `target` | Text (NOT NULL, FK → nodes.id) | Target node |
| `relationship` | Text (NOT NULL) | Relationship type — constrained to ontology types: `Maintenance`, `Contribute` |
| `properties` | Text (JSON) | Edge metadata as JSON (reserved for future non-observation metadata) |
| `archived_at` | DateTime | Archive timestamp — `NULL` means active, non-NULL means archived |
| `created_at` | DateTime | Creation timestamp |
| `updated_at` | DateTime | Last update timestamp |

- Directed: `source → target`
- `UNIQUE(source, target, relationship)` — one relationship type per node pair
- Indexes on `source` and `target` for traversal performance
- Index on `archived_at` for efficient active/archived filtering
- `relationship` values are constrained by the ontology (see [Ontology](docs/ontology.md))

**Observation table**:

| Field | Type | Description |
|-------|------|-------------|
| `edge_source` | Text (NOT NULL, FK) | Edge source node |
| `edge_target` | Text (NOT NULL, FK) | Edge target node |
| `edge_relationship` | Text (NOT NULL) | Edge relationship type |
| `observed_at` | DateTime (NOT NULL) | Timestamp of the source Issue or Journal (`created_on`) |
| `source_entity_type` | Text (NOT NULL) | `issue` or `journal` — provenance of this observation |
| `source_entity_id` | Integer (NOT NULL) | ID of the source entity |
| `evidence` | Text | Brief LLM-generated summary explaining why this relationship was identified from the source content |
| `created_at` | DateTime | Row creation timestamp |

- `UNIQUE(edge_source, edge_target, edge_relationship, source_entity_type, source_entity_id)` — one observation per source entity per edge
- FK: `(edge_source, edge_target, edge_relationship)` references `edges(source, target, relationship)`
- Index on `observed_at` for time-range queries

**Edge upsert behavior**: When a triplet matches an existing edge (`UNIQUE(source, target, relationship)`), the new observation is inserted into the `observations` table. Existing observations are preserved. Duplicate observations (same `source_entity_type` + `source_entity_id` for the same edge) are not added.

**CTE Query patterns**:

1. **Neighbor query** — Find all nodes connected to a given node (outbound, inbound, or both)
2. **Traversal query** — Recursive CTE to walk the graph N hops from a starting node (schema capability; not yet exposed via API)

**Time-based query filtering**:

- Queries may specify a time range to filter edges by `observed_at` values in the `observations` table
- An edge is included if at least one of its observations falls within the specified time range
- When no time range is specified, all qualifying edges and their observations are included
- By default, only active edges (`edges.archived_at IS NULL`) are included; archived edges are excluded unless explicitly requested via `include_archived`

**Constraints**:

- Node `type` values must be one of the types defined in the ontology
- Edge `relationship` values must be one of the relationships defined in the ontology
- Edge `source` and `target` must satisfy the domain-range constraints for the given `relationship`
- Multiple edges with different `relationship` types between the same node pair are allowed

### Error Scenarios

**Webhook Errors**:

| Scenario | Behavior |
|----------|----------|
| Missing token when `WEBHOOK_SECRET` is set | Respond 401, do not process |
| Invalid token when `WEBHOOK_SECRET` is set | Respond 401, do not process |
| Content-Type is not `application/json` | Respond 415, do not process |
| Invalid JSON payload | Respond 422, do not process |
| Missing `issue_id` or not a positive integer | Respond 422, do not process |
| Redmine API unreachable | Respond 502, do not enqueue any jobs |
| Redmine API responds with non-200 | Respond 502, do not enqueue any jobs |
| Redmine API responds 200 but response structure is invalid | Respond 502, do not enqueue any jobs |
| Duplicate notification (same Issue notified again) | Process normally, only create jobs for untracked entities |
| Job enqueueing failure (database error) | Respond 500, log error |

**Analysis Service Errors**:

| Scenario | Behavior |
|----------|----------|
| Analysis record write failure | Retry with exponential backoff |
| Maximum retry attempts exceeded | Mark job as permanently failed, log error |
| Unexpected error during processing | Retry or mark as failed depending on remaining attempts |
| LLM extraction failure (timeout, API error) | Retry with exponential backoff (counts as a job attempt) |
| LLM output fails ontology validation | Attempt correction via LLM feedback (one attempt); if correction also fails, reject the triplet and log warning; valid triplets from the same response are still written |
| Module name not in curated list | Attempt correction via LLM feedback; if corrected name is still not in curated list, reject the triplet and log warning |
| LLM outputs `Maintenance` with non-maintainer role | Attempt correction via LLM feedback; if corrected triplet still has non-maintainer role with Maintenance, downgrade to `Contribute` and log info |
| LLM outputs reserved anonymous subject name | Reject triplet immediately (no correction attempt); log warning |
| LLM correction attempt fails (timeout, API error) | Skip correction, apply original validation result (reject or downgrade); log warning |
| Normalization produces a duplicate edge observation | Skip duplicate observation, continue processing remaining triplets |
| Job cleanup database error | Log error, continue processing — cleanup failure must not block job processing |
| Graph edge archiving database error | Log error, continue processing — archiving failure must not block job processing |

**Graph Neighbor Query Errors**:

| Scenario | Behavior |
|----------|----------|
| Missing `node_id` parameter | Respond 400, do not query |
| `node_id` does not match `type://name` format | Respond 400, do not query |
| Invalid `direction` value | Respond 400, do not query |
| Invalid `observed_after` or `observed_before` format | Respond 400, do not query |
| Invalid `include_archived` value (not a boolean) | Respond 400, do not query |
| `node_id` references a node that does not exist | Respond 404 |
| Database query failure | Respond 500, log error |

**Graph Node Query Errors**:

| Scenario | Behavior |
|----------|----------|
| Invalid `type` value (not in ontology) | Respond 400, do not query |
| `limit` out of range or not an integer | Respond 400, do not query |
| `offset` negative or not an integer | Respond 400, do not query |
| Invalid `include_orphans` value (not a boolean) | Respond 400, do not query |
| Empty `q` parameter | Respond 400, do not query |
| Database query failure | Respond 500, log error |

**Maintenance Console Errors**:

| Scenario | Behavior |
|----------|----------|
| `delete_node` called on node with active (non-archived) edges | Raise error, do not delete — operator must archive or remove active edges first |
| `delete_node` called on non-existent node | Raise error |
| `rename_node` called on non-existent source node | Raise error |
| `archive_edge` called on non-existent edge | Raise error |

**Knowledge Graph Explorer Errors**:

| Scenario | Behavior |
|----------|----------|
| Graph API returns error during client-side fetch | UI displays an inline error message describing the failure; graph visualization remains interactive and does not crash |
| Graph API returns zero results (empty graph) | UI displays an informational message indicating no matching data is available |
| Cytoscape.js CDN unavailable | Page loads but graph visualization is non-functional; search and filters remain visible |

### Global Error Handling

**Scope**: All Controller endpoints

**Behavior**: Any unhandled exception is caught and converted into a standard, safe error response.

**Response format**:

| Item | Value |
|------|-------|
| Status Code | `500 Internal Server Error` |
| Body | `{ "error": "internal server error" }` |
| Content-Type | `application/json` |

**Security principle**: Error responses must not leak internal implementation details (class names, stack traces, database information, etc.).

**Logging**: Full error information is recorded via Error Logging.

### Error Logging

**Log level mapping**:

| Scenario | Log Level | Recorded Information |
|----------|-----------|---------------------|
| Unhandled exception (caught by Global Error Handler) | `error` | Error class, message, stack trace |
| Database write failure | `error` | Operation name, error message |
| Job execution failure | `error` | Job identity, error message, attempt count |
| Job permanently failed | `error` | Job identity, error message, total attempts |
| Redmine API failure | `warn` | Request URL, HTTP status code |
| Authentication failure (401) | `warn` | Request origin information |
| Invalid request (422/415) | `warn` | Request origin information, validation errors |
| Validation correction attempted | `info` | Original triplet, validation errors, corrected triplet, correction result (success/failure), job identity |
| Validation correction failed (still invalid) | `warn` | Original triplet, corrected triplet, remaining validation errors, job identity |
| Reserved anonymous subject rejected | `warn` | Rejected triplet, subject name, job identity |
| Ontology validation rejection (after failed correction) | `warn` | Rejected triplet, validation rule violated, job identity |
| Maintenance downgraded to Contribute (after correction attempted) | `info` | Original triplet, subject role, job identity |
| Duplicate edge observation skipped | `info` | Edge identity, source entity, job identity |
| Graph neighbor query invalid request (400) | `warn` | Request origin, validation errors |
| Graph neighbor query node not found (404) | `info` | Requested node ID |
| Graph neighbor query database failure | `error` | Query parameters, error message |
| Graph node query invalid request (400) | `warn` | Request origin, validation errors |
| Graph node query database failure | `error` | Query parameters, error message |
| Job cleanup execution | `info` | Number of jobs cleaned, retention period |
| Job cleanup failure | `error` | Error message |
| Invalid `JOB_RETENTION` value | `warn` | Provided value, using default |
| Graph edge archiving execution | `info` | Number of edges archived and analysis records reset; retention period |
| Graph edge archiving failure | `error` | Error message |
| Invalid `GRAPH_RETENTION` value | `warn` | Provided value, using default |

**Principles**:

- Do not log sensitive information (e.g., full request body)
- Each error log entry must include sufficient context to trace the problem

### Logging Infrastructure

**Provider**: The `console` gem is registered as `Container['logger']` (`Console.logger`) via a dry-system provider.

**Injection by layer**:

- **Controller layer**: `BaseController` resolves the logger lazily via `container['logger']` (Controllers are not container-managed, so they do not use `Lapidary::Dependency`)
- **Use Case layer (inner layer)**: Receives the logger through plain Ruby constructor injection (adhering to Clean Architecture dependency rule — inner layers must not depend on framework infrastructure)
- **Outer-layer components**: Inject via `Lapidary::Dependency['logger']`

**Sinatra built-in logging**: Explicitly disabled (`set :logging, false`) to avoid duplicate output; all logging goes through the DI-injected `console` logger.

**Testing**: Tests use `Console::Logger.new(Console::Output::Null.new)` to silence log output.

### Deployment

#### Container Image

The application is packaged as a container image using multi-stage build:

- **Base image**: Ruby 3.4 (official image)
- **Build stage**: Installs dependencies (`bundle install`)
- **Runtime stage**: Contains only the application code and runtime dependencies
- **Entry point**: `bundle exec falcon host`

#### Process Management

Falcon manages both the web server and the Analysis Service as supervised processes within a single container.

#### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PORT`   | No       | `9292`  | HTTP listen port |
| `WEBHOOK_SECRET` | No | — | When set, webhook requests must include `?token=<value>` matching this secret; when unset, authentication is bypassed |
| `REDMINE_URL` | No | `https://bugs.ruby-lang.org` | Base URL for the Redmine JSON API |
| `OPENAI_API_KEY` | Yes | — | API key for OpenAI LLM used in triplet extraction |
| `OPENAI_MODEL` | No | `gpt-5-mini` | OpenAI model used for triplet extraction |
| `JOB_RETENTION` | No | `7d` | Retention period for completed/failed/stale jobs. Format: `<number><unit>` where unit is `h` (hours) or `d` (days). Examples: `12h`, `1d`, `7d` |
| `GRAPH_RETENTION` | No | `180d` | Retention period for graph edges. An edge is archived when its most recent observation exceeds this period. Format: `<number><unit>` where unit is `h` (hours) or `d` (days). Examples: `30d`, `180d`, `365d` |
| `CLEANUP_INTERVAL` | No | `86400` | Interval in seconds between retention cleanup runs (expired jobs + archived edges). Default is 1 day |
| `SENTRY_DSN` | No | — | Sentry DSN for error tracking and performance monitoring. When unset, Sentry is a no-op |

#### Port

- Container exposes port `9292` by default

#### Health Check

- Uses the dedicated `GET /health` endpoint as the container health check
- Expected response: `200 OK` with `{ "status": "ok" }`

#### Data Persistence

- SQLite database file must be persisted via volume mount
- Database path is determined by application configuration
- The job queue uses the same SQLite database

### Maintenance Console

**Entry point**: `bin/console`

**Behavior**: Loads the application environment, finalizes the container, and starts an IRB session with convenience methods available at the top level.

**Scope**: An operational tool for manual data inspection and correction.

#### Convenience Methods

| Method | Behavior |
|--------|----------|
| `container` | Returns the finalized `Lapidary::Container` |
| `db` | Returns the Sequel database connection |
| `nodes(type = nil)` | Lists all nodes; when type is given, filters by node type |
| `node(id)` | Looks up a single node by ID |
| `neighbors(node_id)` | Returns edges connected to the node as Node-Edge-Node triplets, each with its observations; supports `--archived` flag to include archived edges |
| `archive_edge(source, target, relationship)` | Sets `archived_at` on the edge and deletes corresponding analysis records derived from the edge's observations |
| `rename_node(old_id, new_id)` | Renames a node by migrating all edges and observations to the new ID; if the target node already exists, merges node data (field-level merge per Node upsert behavior) and deduplicates edge observations (per Edge upsert deduplication); deletes the old node after migration |
| `delete_node(node_id)` | Deletes a node; automatically purges any archived edges and their observations; raises an error if the node has active (non-archived) edges |

---

## Terminology

| Term | Definition |
|------|------------|
| Issue | A tracking record on bugs.ruby-lang.org |
| Journal | A reply record on an Issue, containing the respondent and change details |
| Webhook | An HTTP notification proactively sent by an external system |
| Graph | A knowledge graph describing relationships between entities |
| Ontology | A model defining domain concepts and semantic relationships |
| Analysis Record | A tracking entry that records whether a specific Issue or Journal has been analyzed |
| Redmine | The issue tracking system used by bugs.ruby-lang.org |
| Job | A deferred work unit carrying analysis data, stored in the database for asynchronous processing |
| Job Queue | A database-backed queue that holds pending analysis jobs |
| Analysis Service | A background worker service that dequeues and processes analysis jobs |
| Rubyist | A person who participates in Ruby development discussions, represented as a node in the knowledge graph |
| CoreModule | A core module built into the Ruby interpreter (e.g., String, Array, IO), represented as a node in the knowledge graph |
| Stdlib | A standard library shipped with Ruby (e.g., net/http, json, openssl), represented as a node in the knowledge graph |
| Maintenance | A relationship indicating a Ruby maintainer is responsible for a module |
| Contribute | A relationship indicating a Rubyist contributes to or interacts with a module |
| Node | A vertex in the knowledge graph representing an entity (e.g., Rubyist, CoreModule, Stdlib) |
| Edge | A directed connection between two Nodes representing a relationship |
| Property Graph | A graph model where both Nodes and Edges can carry key-value metadata |
| Triplet | A (subject, relationship, object) triple — the fundamental unit of the knowledge graph |
| Domain-Range Constraint | A rule defining which node types a relationship may legally connect (domain = source type, range = target type) |
| Entity Normalization | Resolving different textual representations to a single canonical entity using the node type's identity rule (e.g., resolving a display name to a username for Rubyist nodes) |
| Ontology Entailment | The degree to which extracted triplets conform to the predefined ontology constraints |
| Qualifier | Contextual metadata attached to an Edge (e.g., observation time, provenance) |
| Neighbor | A node directly connected to a given node by one or more edges |
| Job Cleanup | The process of removing expired jobs from the database based on a configured retention period |
| Validation Feedback Correction | The process of sending a failed triplet and its validation errors back to the LLM for a single correction attempt before final rejection |
| TTL (Time to Live) | A configured duration after which data is eligible for removal or archiving |
| Knowledge Graph Explorer | A browser-based single-page application for visually exploring the knowledge graph |
| Cytoscape.js | A JavaScript graph visualization library used to render the knowledge graph in the browser |
| Graph Edge Archiving | The process of marking edges as archived (by setting `edges.archived_at`) when their most recent observation exceeds a configured retention period; archived edges are excluded from default queries |
| Active Edge | An edge where `archived_at IS NULL` — included in default query results |
| Archived Edge | An edge where `archived_at IS NOT NULL` — excluded from default query results unless explicitly requested via `include_archived` |
| Orphan Node | A node in the knowledge graph that has no remaining active (non-archived) edges connecting it to other nodes |
| Maintenance Console | An IRB-based operational tool (`bin/console`) that loads the application container for manual data inspection and correction |
| Analysis Record Reset | The process of clearing analysis records for entities whose edges have been archived, enabling re-analysis on the next webhook notification (see Graph Edge Archiving § archive step 2) |

## Patterns

| Pattern | Definition | Used In |
|---------|------------|---------|
| Async handoff | Receive a request, prepare data, persist work to a queue, and respond immediately | Webhook creates jobs then responds 202 |
| Exponential backoff | Progressively increasing retry delays to avoid overwhelming a failing service | Analysis Service retry |
| Claim-and-execute | Atomically claim a job before executing it, preventing duplicate processing | Analysis Service processing |
| Graceful shutdown | On shutdown, finish or release in-progress work before stopping | Analysis Service shutdown |
| Upsert by ID | Insert or update a record keyed by a unique identifier; create if absent, update if present | Analysis Record writing |
| Safe error response | Unhandled exceptions are converted into a generic error message, never leaking internal details | Global Error Handling |
| Polymorphic tracking | A single table using `type` + `id` columns to track multiple entity types | Analysis Records tracking Issue and Journal |
| Property graph | Nodes and Edges store flexible metadata as JSON, enabling schema evolution without migrations | Knowledge Graph Schema |
| Ontology-guided extraction | Use a predefined ontology (types + constraints) to guide LLM extraction, ensuring structural consistency of outputs | Triplet extraction |
| Temporal qualifier | Edges carry an observation timestamp, enabling time-range filtering to exclude stale relationships | Knowledge Graph edges |
| Neighbor query | Find all nodes directly connected to a given node by traversing edges in specified directions | Graph Neighbor Query Endpoint |
| TTL-based cleanup | Delete records older than a configured retention period, preventing unbounded data growth | Job Cleanup |
| Paginated listing | Return a subset of records with total count, limit, and offset metadata for client-side pagination | Graph Node Query Endpoint |
| Server-rendered SPA | Serve a self-contained HTML page from the server; client-side JavaScript handles all interactivity and data fetching | Knowledge Graph Explorer |
| Soft archive with query-time filtering | Expired edges are marked as archived rather than deleted; queries dynamically exclude archived edges by default | Graph Edge Archiving |
| TTL-triggered re-analysis | Archived edges clear corresponding analysis records, allowing webhooks to naturally trigger fresh analysis; if the LLM no longer produces the same triplet, the edge stays archived (self-correcting) | Graph Edge Archiving |

## Architecture

See [Architecture](docs/architecture.md) for component structure, layers, and data flow design.

## Ontology

See [Ontology](docs/ontology.md) for complete node/relationship enumerations, domain-range constraints, curated module lists, and theoretical background.

## Technical Decisions

### Decided

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Web framework | Sinatra | Lightweight, suitable for API services |
| HTTP server | Falcon | Supports asynchronous processing |
| DI container | dry-system | Manages component dependencies |
| Database | SQLite + Sequel | Simple deployment, small data volume |
| Webhook format | Custom `{ "issue_id": N }` | External system sends Issue ID, Lapidary proactively fetches data from Redmine API |
| Issue data source | Redmine JSON API | `GET /issues/{id}.json?include=journals` |
| Redmine API access method | Public access (no authentication required) | bugs.ruby-lang.org JSON API is publicly accessible |
| Analysis tracking storage | Separate tracking table (no content) | Track status only, avoid duplicating data |
| Analysis tracking table design | Single polymorphic table (`entity_type` + `entity_id`) | Simple, one table handles both Issue and Journal entities |
| Analysis tracking state | `analyzed_at` timestamp | Provides more information than a boolean |
| Analysis tracking uniqueness | Joint unique constraint on `(entity_type, entity_id)` | Prevents duplicate records |
| Error handling strategy | All errors propagate correctly; Global Error Handler ensures safe responses | Errors should not be silently swallowed; safe responses prevent information leakage |
| Deployment method | Container (Docker) | Portable, reproducible, consistent across environments |
| Container build | Multi-stage build | Smaller image size, separates build and runtime dependencies |
| Webhook processing model | Fetch from Redmine API then enqueue analysis jobs asynchronously | Decouples data fetching from analysis processing |
| Job data strategy | Jobs carry all Redmine data needed for analysis | Analysis Service does not call the Redmine API; LLM API is called separately for extraction |
| Job granularity | One job per entity | Fine-grained retry, independent failure handling |
| Job queue storage | SQLite (same database) | Zero external dependencies |
| Worker concurrency | Single worker, sequential processing | Simple, minimizes SQLite write contention |
| Job retry strategy | Exponential backoff with max attempts | Handles transient failures gracefully |
| Process management | Falcon managed services | Unified process supervision |
| Job idempotency | Analysis tracking layer | Reuses existing tracking mechanism to prevent duplicate work |
| Graph storage model | Property graph (Node + Edge tables) | Simple relational model, no external graph DB dependency |
| Node ID system | Independent text-based IDs | Decouples graph identity from source system |
| Edge directionality | Directed graph | Relationships have explicit source and target |
| Metadata storage | JSON text columns for node/edge data; dedicated table for observations; `archived_at` on edges table | Edge-level archiving requires column-level `archived_at` on edges; observations are append-only records used for time-range filtering; other metadata remains flexible JSON |
| Graph traversal | SQL CTE | Leverages SQLite's recursive CTE support, no external engine needed |
| Ontology approach | Wikontic-inspired (static ontology + LLM extraction + validation) | Predefined types ensure consistent graph structure; LLM handles unstructured text |
| Validation feedback strategy | LLM correction with max 1 attempt; role constraint falls back to automatic downgrade | Balances extraction quality improvement with API cost; single attempt captures most correctable errors (name typos, case mismatches) without diminishing returns |
| Ontology enumeration storage | `docs/ontology.md` | Keeps SPEC.md focused on decisions; detailed enumerations live in a dedicated document |
| Entity normalization strategy | Job-context resolution (author fields) + passthrough for unknown Rubyists | Simple, deterministic, no external lookup required; leverages existing Job Arguments data |
| Node ID generation strategy | URI format (`type://name`) | Human-readable, deterministic, avoids external ID generators |
| LLM provider | OpenAI | Widely available, sufficient for triplet extraction task |
| Node metadata merge strategy | Field-level merge (latest non-nil wins) | Metadata accumulates naturally over time; no data loss from partial updates |
| Graph API bounded context | New `graph` BC | Separates query concerns from analysis concerns; follows existing BC pattern |
| Graph query endpoint style | Query parameters (`GET /graph/neighbors?node_id=...`) | Simple, cacheable, fits RESTful conventions for read-only queries |
| Node ID in query | URI format passed as query parameter | Reuses existing `type://name` node ID convention; human-readable |
| Webhook authentication | Static token via query parameter (`?token=`) | Simple, no cryptographic overhead; optional via env var presence |
| Logging solution | `console` gem (via DI) | Default integration with Falcon, structured log output; registered via dry-system provider, injected into all layers via DI |
| Job cleanup strategy | TTL-based hard delete, built into Analysis Service | Simple and effective — no extra process or cron needed; hard delete because job data has no value after graph writing |
| Node query pagination | `limit` + `offset` with total count | Simple, suitable for small datasets; consistent with project's simplicity philosophy |
| Node search mechanism | Case-insensitive substring match on name and display_name | Simple SQL LIKE query; sufficient for knowledge graph scale |
| Node query default page size | 20 (max 100) | Reasonable default balancing response size and usability |
| UI rendering approach | Server-rendered single HTML page with client-side JS | No build step, no asset pipeline; keeps deployment simple |
| Graph visualization library | Cytoscape.js via CDN | Purpose-built for graph/network visualization; no bundler needed |
| UI data fetching | Client-side fetch from existing Graph API endpoints | Reuses existing API; no server-side rendering of graph data |
| Health check endpoint path | `GET /health` | Frees root path for UI; follows common health check conventions |
| Graph edge retention default | `180d` | bugs.ruby-lang.org issues evolve very slowly; 180 days (half a year) provides sufficient history while allowing periodic refresh |
| Graph archiving strategy | TTL-based soft archive at edge level in Analysis Service | Mirrors job cleanup pattern; no additional process required; edge-level archiving ensures that when the most recent observation exceeds the retention period, the entire edge is archived and analysis records are cleared for re-analysis; if the LLM no longer produces the same triplet, the edge stays archived (self-correcting erroneous extractions) |
| Edge archiving triggers re-analysis | Clear corresponding analysis records | Simplest approach — lets webhooks naturally trigger re-analysis without a dedicated re-analysis scheduler |
| Observation storage strategy | Dedicated `observations` table (no `archived_at`) with archiving at edge level | Observations are append-only evidence records; archiving is determined by edge staleness (`edges.archived_at`), not per-observation; avoids complexity of observation-level archive management |
| Maintenance console | `bin/console` + IRB + container | Standard Ruby convention; no predefined commands, operators use the container API directly |
| Graph retention env var name | `GRAPH_RETENTION` | Follows `JOB_RETENTION` naming convention |

### To Be Decided

*No pending decisions.*

