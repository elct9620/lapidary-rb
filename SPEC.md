# SPEC.md

## Purpose

Lapidary builds a knowledge graph between Ruby core features and developers from issue notifications on bugs.ruby-lang.org, helping researchers understand the evolution of the Ruby language and community collaboration patterns.

## Users

- **Ruby core community researchers** — Want to understand the discussion history and participants for specific features
- **Ruby contributors** — Want to find related issues and past design decisions

## Impacts

- Researchers can trace the complete journey of Ruby features from proposal to implementation through structured data
- Contributors can quickly find issues and discussions related to their areas of interest

## Success Criteria (V1)

- Webhook endpoint can receive Issue ID notifications and respond with correct status codes
- Issue data successfully fetched from the Redmine API can be stored in a SQLite database
- Duplicate notifications for the same Issue correctly update the database record (upsert)

## Non-goals (V1)

- Ontology processing — No semantic classification or concept association
- LLM integration — No natural language summarization or intelligent analysis
- Graph queries — No graph query interface
- User authentication and access control
- Frontend UI

---

## Vision

The complete system is divided into four phases:

1. **Webhook reception** — Receive issue change notifications, fetch data from the Redmine API, and store it
2. **Ontology processing** — Extract concepts and relationships from issue data, building a semantic model
3. **Knowledge graph construction** — Transform the semantic model into a graph structure
4. **Query and exploration** — Provide APIs and interfaces for querying the knowledge graph

V1 implements only the first phase.

## V1 Features

1. **Webhook endpoint** — Receive Issue ID notifications sent by external systems
2. **Issue data fetching** — Retrieve complete Issue data from the Redmine JSON API
3. **Issue data storage** — Store data in SQLite after validating completeness

## User Journeys

### Webhook Reception and Storage

- **Context**: An external system detects a change to an issue on bugs.ruby-lang.org
- **Action**: The external system sends a Webhook containing the Issue ID to Lapidary
- **Outcome**: Lapidary fetches Issue data from the Redmine JSON API, validates completeness, and stores it in the database

---

## Behavior

### Webhook Endpoint

**Endpoint**: `POST /webhook`

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

**Responses**:

| Condition | Status Code | Body |
|-----------|-------------|------|
| Successfully processed (data stored) | `200 OK` | `{ "status": "ok" }` |
| Accepted but not stored (incomplete data) | `200 OK` | `{ "status": "skipped", "reason": "incomplete data" }` |
| Non-JSON request | `415 Unsupported Media Type` | `{ "error": "Content-Type must be application/json" }` |
| Invalid payload (malformed JSON or missing `issue_id`) | `422 Unprocessable Entity` | `{ "error": "..." }` |
| Redmine API unreachable or non-200 response | `502 Bad Gateway` | `{ "error": "failed to fetch issue from Redmine" }` |
| Internal processing failure | `500 Internal Server Error` | `{ "error": "internal server error" }` |

### Issue Data Fetching

**Data source**: `https://bugs.ruby-lang.org/issues/{id}.json?include=journals`

After receiving a Webhook, Lapidary proactively fetches complete Issue data from the Redmine JSON API. The request includes the `include=journals` parameter. Without journals, only the author-to-subject relationship can be analyzed. Journals track respondents whose interactions are not yet recorded, enabling analysis of participant relationships beyond just the original author and extending the knowledge graph.

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
    "journals": [...]
  }
}
```

**Field mapping**:

| Stored Field | Source Path | Type | Description |
|--------------|------------|------|-------------|
| `id` | `issue.id` | Integer | Issue number (unique identifier) |
| `subject` | `issue.subject` | String | Issue title |
| `tracker` | `issue.tracker.name` | String | Category (Bug, Feature, etc.) |
| `status` | `issue.status.name` | String | Status (Open, Closed, etc.) |
| `priority` | `issue.priority.name` | String | Priority level |
| `author` | `issue.author.name` | String | Author name |
| `created_on` | `issue.created_on` | DateTime | Creation time |
| `updated_on` | `issue.updated_on` | DateTime | Last updated time |
| `journals[].user` | `issue.journals[].user.name` | String | Respondent name |

> `tracker`, `status`, `priority`, and `author` are nested objects `{ "id": N, "name": "..." }` in the Redmine API; the `name` field is extracted. The same applies to `user` in journals.

### Issue Data Storage

**Completeness check**: Data is written to the database only when all fields listed above have values. If any field is missing, the data is not stored and a warning is logged.

**Storage behavior**:

- Upsert using `id` as the key
- New Issue (no matching `id` in database) → create a new record
- Existing Issue → full record update (no partial updates)

**Technology choice**: Sequel + SQLite

### Error Scenarios

| Scenario | Behavior |
|----------|----------|
| Content-Type is not `application/json` | Respond 415, do not process |
| Invalid JSON payload | Respond 422, do not process |
| Missing `issue_id` or not a positive integer | Respond 422, do not process |
| Redmine API unreachable | Respond 502, do not write to database |
| Redmine API responds with non-200 | Respond 502, do not write to database |
| Incomplete Issue data (required fields missing) | Respond 200 (`skipped`), do not write to database, log warning |
| Duplicate notification (same Issue notified again) | Process normally, full update of existing record |
| Database write failure | Respond 500, log error |

---

## Terminology

| Term | Definition |
|------|------------|
| Issue | A tracking record on bugs.ruby-lang.org |
| Journal | A reply record on an Issue, containing the respondent and change details |
| Webhook | An HTTP notification proactively sent by an external system |
| Graph | A knowledge graph describing relationships between entities |
| Ontology | A model defining domain concepts and semantic relationships |
| Redmine | The issue tracking system used by bugs.ruby-lang.org |

## Technical Decisions

### Decided

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Web framework | Sinatra | Lightweight, suitable for API services |
| HTTP server | Falcon | Supports asynchronous processing |
| DI container | dry-system | Manages component dependencies |
| Database | SQLite + Sequel | Simple deployment, small data volume for V1 |
| Webhook format | Custom `{ "issue_id": N }` | External system sends Issue ID, Lapidary proactively fetches data from Redmine API |
| Issue data source | Redmine JSON API | `GET /issues/{id}.json?include=journals` |
| Redmine API access method | Public access (no authentication required) | bugs.ruby-lang.org JSON API is publicly accessible |

### To Be Decided

| Item | Candidate Options | Notes |
|------|-------------------|-------|
| Webhook authentication | HMAC signature / IP whitelist | Whether source verification is needed in V1 |
| Logging solution | Ruby Logger / dry-logger | Logging framework to be selected |
