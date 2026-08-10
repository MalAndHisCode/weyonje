# Current System State

> **Purpose:** This document is the living source of truth for the system as it currently exists. Record verified implementation and operational reality, not intended design. Clearly label anything planned, proposed, incomplete, deprecated, or unknown.

## 1. Document Control

<!-- Keep this metadata current whenever the document changes. -->

| Field | Value |
| --- | --- |
| Project | `[Project name]` |
| Document version | `[Version or revision identifier]` |
| System version / release | `[Release, tag, commit, or Unknown]` |
| Last updated | `[YYYY-MM-DD]` |
| Last verified | `[YYYY-MM-DD]` |
| Verified against | `[Repository commit, deployed release, environment, evidence, or Unknown]` |
| Maintainer(s) | `[Name, role, or team]` |
| Reviewers | `[Name, role, or team]` |
| Next review due | `[YYYY-MM-DD or event that triggers review]` |

### 1.1 Status and Evidence Rules

Use one of the following labels wherever implementation status could be ambiguous:

| Status | Meaning |
| --- | --- |
| **Implemented** | Confirmed to exist in the current codebase or deployed system. |
| **Partially implemented** | Some confirmed behaviour exists, but the described capability is incomplete. |
| **Configured but unverified** | Configuration exists, but runtime behaviour has not been confirmed. |
| **Planned** | Approved future work that is not currently implemented. |
| **Proposed** | Suggested work or design that has not been approved or implemented. |
| **Deprecated** | Still present but no longer recommended or intended for continued use. |
| **Removed** | Previously present but no longer exists in the current system. |
| **Unknown** | Available evidence is insufficient to determine the current state. |
| **Not applicable** | Deliberately outside the system's scope. |

For important claims, record the supporting evidence: source file, module, test, configuration, deployment record, monitoring result, or responsible person who verified it. Do not convert assumptions, requirements, mockups, tickets, or roadmap items into statements of implemented fact.

## 2. Executive Summary

<!-- Give a concise, non-technical account of what the system currently does, who uses it, where it runs, and its overall operational condition. -->

`[Current system summary]`

### 2.1 Current Health

| Area | Status | Summary | Evidence / Last Verified |
| --- | --- | --- | --- |
| Functionality | `[Status]` | `[Summary]` | `[Evidence and date]` |
| Security | `[Status]` | `[Summary]` | `[Evidence and date]` |
| Deployment | `[Status]` | `[Summary]` | `[Evidence and date]` |
| Operations | `[Status]` | `[Summary]` | `[Evidence and date]` |
| Data | `[Status]` | `[Summary]` | `[Evidence and date]` |

### 2.2 Material Changes Since the Previous Update

<!-- List only changes that altered documented system reality. Use "None" for the first version. -->

- `[Date — change and impact]`

## 3. System Identity and Scope

### 3.1 Purpose

`[Business problem currently addressed and value currently provided]`

### 3.2 Current Users and Stakeholders

| User / Stakeholder | Current relationship to the system | Status | Evidence |
| --- | --- | --- | --- |
| `[User or stakeholder]` | `[How they currently use, support, own, or depend on it]` | `[Status]` | `[Evidence]` |

### 3.3 In Scope

- `[Capability, process, user group, or boundary currently within scope]`

### 3.4 Out of Scope

- `[Explicitly excluded capability, process, user group, or boundary]`

### 3.5 System Boundaries and Assumptions

- `[Confirmed boundary, dependency, constraint, or operating assumption]`

## 4. Implemented Functionality and Behaviour

### 4.1 Capability Inventory

<!-- Describe observable behaviour. Separate complete, partial, and unavailable capabilities. -->

| Capability | Status | Current behaviour | Primary users | Entry point | Evidence / Last Verified |
| --- | --- | --- | --- | --- | --- |
| `[Capability]` | `[Status]` | `[What the system currently does, including important conditions]` | `[Roles]` | `[Screen, API, job, command, or other entry point]` | `[Evidence and date]` |

### 4.2 Core Workflows

#### `[Workflow name]`

- **Status:** `[Status]`
- **Purpose:** `[Current purpose]`
- **Actors:** `[Roles, systems, or services]`
- **Trigger:** `[What starts the workflow]`
- **Preconditions:** `[Required current state]`
- **Current flow:**
  1. `[Verified step]`
  2. `[Verified step]`
- **Decision points and business rules:** `[Rules and branching behaviour]`
- **State transitions:** `[From status → action/event → resulting status]`
- **Notifications or side effects:** `[Messages, writes, events, jobs, or external calls]`
- **Failure and recovery behaviour:** `[Validation, errors, retries, rollback, or manual intervention]`
- **Postconditions / output:** `[Result after successful completion]`
- **Known gaps:** `[Incomplete, inconsistent, or unknown behaviour]`
- **Evidence / last verified:** `[Source and date]`

### 4.3 User Interfaces

| Interface | Platform | Route / Location | Available to | Status | Current behaviour and notable states |
| --- | --- | --- | --- | --- | --- |
| `[Page, screen, view, or interface]` | `[Web, mobile, desktop, CLI, etc.]` | `[Route or location]` | `[Roles]` | `[Status]` | `[Normal, loading, empty, validation, error, and permission behaviour where relevant]` |

### 4.4 Background and Automated Processing

| Process | Trigger / Schedule | Current behaviour | Failure handling | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| `[Job, worker, listener, or scheduled task]` | `[Trigger or schedule]` | `[What it does]` | `[Retries, alerts, dead letters, or manual recovery]` | `[Status]` | `[Evidence]` |

### 4.5 Business Rules and Validation

| Rule | Scope | Enforcement point | Failure response | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| `[Rule or invariant]` | `[Affected workflow or data]` | `[Client, API, database, worker, manual process, etc.]` | `[Current user/system response]` | `[Status]` | `[Evidence]` |

## 5. Roles, Authentication, and Permissions

### 5.1 Authentication

- **Status:** `[Status]`
- **Authentication methods:** `[Methods currently supported]`
- **Identity source:** `[Local, directory, identity provider, or Unknown]`
- **Session / token behaviour:** `[Creation, lifetime, renewal, revocation, and storage]`
- **Account lifecycle:** `[Registration, verification, activation, suspension, reset, and deactivation]`
- **Known gaps or risks:** `[Current issues or Unknown]`
- **Evidence / last verified:** `[Source and date]`

### 5.2 Roles and Permission Matrix

| Role | Purpose | Key permissions | Restrictions | Assignment method | Status | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| `[Role]` | `[Why it exists]` | `[Allowed actions and data]` | `[Explicitly denied or scoped actions]` | `[How the role is granted or removed]` | `[Status]` | `[Evidence]` |

### 5.3 Authorization Enforcement

`[Where and how authorization is enforced, including object-level/data-scope checks and any known client-only enforcement]`

## 6. Architecture and Major Components

### 6.1 Current Architecture Overview

`[Describe the implemented architecture and request/data flow. Add a diagram only if it is kept current and based on verified components.]`

### 6.2 Component Inventory

| Component | Responsibility | Technology | Location | Interfaces | Deployment unit | Status | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `[Component]` | `[Current responsibility]` | `[Framework, runtime, or service]` | `[Repository path or service location]` | `[APIs, events, files, or protocols]` | `[How/where it is deployed]` | `[Status]` | `[Evidence]` |

### 6.3 Repository and Code Organization

```text
[Current top-level repository structure, limited to meaningful paths]
```

| Path / Module | Responsibility | Important conventions or constraints |
| --- | --- | --- |
| `[Path]` | `[Purpose]` | `[Pattern, ownership, or constraint]` |

### 6.4 Internal Interfaces and Communication

| Producer / Caller | Consumer / Callee | Interface | Data / Purpose | Security | Failure behaviour | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `[Component]` | `[Component]` | `[API, function, event, queue, file, etc.]` | `[What crosses the boundary]` | `[Authentication, authorization, or trust boundary]` | `[Timeout, retry, fallback, or error handling]` | `[Status]` |

### 6.5 Architectural Constraints and Decisions

| Decision / Constraint | Current rationale | Consequences | Evidence / Reference | Status |
| --- | --- | --- | --- | --- |
| `[Decision or constraint]` | `[Why it currently applies]` | `[Trade-offs and operational effect]` | `[ADR, issue, code, or responsible owner]` | `[Active, Deprecated, Unknown, etc.]` |

## 7. Data and Persistence

### 7.1 Data Stores

| Store | Technology | Purpose | Owner / Accessing components | Location / Environment | Status | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| `[Database, cache, object store, file system, etc.]` | `[Technology and version]` | `[Data held]` | `[Components]` | `[Non-secret location reference]` | `[Status]` | `[Evidence]` |

### 7.2 Core Data Structures

| Entity / Structure | Purpose | Key fields / relationships | Source of truth | Retention / Lifecycle | Status |
| --- | --- | --- | --- | --- | --- |
| `[Entity, table, collection, event, or file format]` | `[Purpose]` | `[Important fields, identifiers, and relationships]` | `[Authoritative store or owner]` | `[Creation, update, archive, and deletion behaviour]` | `[Status]` |

### 7.3 Data Integrity and Concurrency

- **Constraints and invariants:** `[Keys, uniqueness, references, validation, or Unknown]`
- **Transaction boundaries:** `[Current transaction behaviour or Unknown]`
- **Concurrency controls:** `[Locking, versioning, idempotency, or Unknown]`
- **Migration mechanism:** `[Tool and current process]`
- **Known integrity risks:** `[Risk or None known, with evidence]`

### 7.4 Data Classification and Privacy

| Data category | Classification / Sensitivity | Collection purpose | Access | Protection | Retention / Deletion | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `[Data category]` | `[Classification]` | `[Why it is held]` | `[Who/what can access it]` | `[Encryption, masking, audit, etc.]` | `[Current policy/behaviour or Unknown]` | `[Status]` |

## 8. APIs and External Integrations

### 8.1 Exposed APIs

| API / Endpoint group | Consumers | Authentication | Versioning | Current behaviour | Status | Specification / Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| `[API or endpoint group]` | `[Consumers]` | `[Method]` | `[Strategy]` | `[Purpose, inputs, outputs, and important errors]` | `[Status]` | `[OpenAPI, tests, code, or other evidence]` |

### 8.2 External Integrations

| Integration | Purpose | Direction / Protocol | Data exchanged | Authentication | Failure / Retry behaviour | Environments | Status | Owner |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `[External system or provider]` | `[Purpose]` | `[Inbound/outbound and protocol]` | `[Data]` | `[Credential mechanism; never include secret values]` | `[Current handling]` | `[Where enabled]` | `[Status]` | `[Owner]` |

### 8.3 Third-Party and Runtime Dependencies

| Dependency | Version / Constraint | Used by | Purpose | Update mechanism | Risk / Support status |
| --- | --- | --- | --- | --- | --- |
| `[Package, runtime, service, SDK, or platform]` | `[Pinned version or range]` | `[Component]` | `[Purpose]` | `[How updates are managed]` | `[Known risk, EOL status, or Unknown]` |

## 9. Configuration and Environments

### 9.1 Environment Inventory

| Environment | Purpose | Location / Platform | Deployed version | Data type | External access | Current status | Last verified |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `[Local, development, test, staging, production, etc.]` | `[Purpose]` | `[Platform or non-sensitive location]` | `[Release / commit]` | `[Synthetic, masked, production, etc.]` | `[Access boundary]` | `[Status]` | `[Date]` |

### 9.2 Configuration Inventory

<!-- Record names, purposes, sources, defaults, and requirements. Never record secret values. -->

| Configuration key / Group | Purpose | Required | Default | Source / Management | Environments | Validation | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `[Key or group]` | `[Purpose]` | `[Yes/No/Conditional]` | `[Non-secret default or None]` | `[Environment, file, vault, platform, etc.]` | `[Applicable environments]` | `[Startup/runtime validation]` | `[Status]` |

### 9.3 Secrets and Certificates

- **Management mechanism:** `[How secrets/certificates are stored, delivered, rotated, and revoked—without values]`
- **Owners:** `[Responsible role or team]`
- **Rotation / expiry process:** `[Current process and schedule]`
- **Known gaps:** `[Issue or Unknown]`

### 9.4 Feature Flags and Runtime Controls

| Flag / Control | Purpose | Default | Enabled environments / users | Owner | Removal condition | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `[Flag or control]` | `[Purpose]` | `[Value]` | `[Scope]` | `[Owner]` | `[When it should be retired]` | `[Status]` |

## 10. Security and Compliance

### 10.1 Security Controls

| Area | Current control | Enforcement point | Status | Evidence / Last Tested | Known gap |
| --- | --- | --- | --- | --- | --- |
| Authentication | `[Control]` | `[Location]` | `[Status]` | `[Evidence/date]` | `[Gap]` |
| Authorization | `[Control]` | `[Location]` | `[Status]` | `[Evidence/date]` | `[Gap]` |
| Input validation | `[Control]` | `[Location]` | `[Status]` | `[Evidence/date]` | `[Gap]` |
| Data in transit | `[Control]` | `[Location]` | `[Status]` | `[Evidence/date]` | `[Gap]` |
| Data at rest | `[Control]` | `[Location]` | `[Status]` | `[Evidence/date]` | `[Gap]` |
| Audit logging | `[Control]` | `[Location]` | `[Status]` | `[Evidence/date]` | `[Gap]` |
| Abuse / rate limiting | `[Control]` | `[Location]` | `[Status]` | `[Evidence/date]` | `[Gap]` |
| Dependency security | `[Control]` | `[Location]` | `[Status]` | `[Evidence/date]` | `[Gap]` |

### 10.2 Trust Boundaries and Threat Considerations

- `[Trust boundary, material threat, current mitigation, and residual risk]`

### 10.3 Compliance and Policy Obligations

| Obligation | Applicability | Current implementation / evidence | Owner | Status | Gap / Next action |
| --- | --- | --- | --- | --- | --- |
| `[Law, regulation, policy, standard, or contractual obligation]` | `[Why it applies or Unknown]` | `[Current control/evidence]` | `[Owner]` | `[Status]` | `[Gap or action]` |

### 10.4 Security Assessment History

| Date | Assessment | Scope | Result | Open findings reference |
| --- | --- | --- | --- | --- |
| `[YYYY-MM-DD]` | `[Review, scan, penetration test, audit, etc.]` | `[Scope]` | `[Summary]` | `[Issue/report reference]` |

## 11. Build, Test, and Release

### 11.1 Local Development

- **Prerequisites:** `[Required tools and supported versions]`
- **Setup:** `[Current setup steps or reference]`
- **Run commands:** `[Commands or reference]`
- **Test commands:** `[Commands or reference]`
- **Common setup problems:** `[Known issue and resolution]`

### 11.2 Build Process

`[How deployable artifacts are currently produced, versioned, signed, and stored]`

### 11.3 Test Coverage and Quality Gates

| Test / Gate | Scope | Execution point | Required result | Current result | Status | Evidence / Date |
| --- | --- | --- | --- | --- | --- | --- |
| `[Unit, integration, end-to-end, static analysis, manual UAT, etc.]` | `[Scope]` | `[Local, CI, pre-release, etc.]` | `[Threshold or rule]` | `[Latest result]` | `[Status]` | `[Evidence/date]` |

### 11.4 Release and Change Management

- **Branching / versioning strategy:** `[Current strategy]`
- **Release approval:** `[Who approves and required checks]`
- **Deployment promotion:** `[How changes move between environments]`
- **Rollback criteria and process:** `[Current process]`
- **Database migration coordination:** `[Current process]`
- **Release notes location:** `[Reference]`

## 12. Deployment and Infrastructure

### 12.1 Deployment Topology

`[Describe where each deployable component runs and how traffic, networking, storage, and dependencies connect.]`

### 12.2 Infrastructure Inventory

| Resource / Service | Purpose | Environment | Provisioning method | Owner | Backup / Redundancy | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `[Host, container, database, gateway, storage, DNS, etc.]` | `[Purpose]` | `[Environment]` | `[Manual, IaC, managed platform, etc.]` | `[Owner]` | `[Current protection]` | `[Status]` |

### 12.3 Deployment Procedure

1. `[Verified deployment step or link to controlled runbook]`
2. `[Verified validation step]`

### 12.4 Rollback and Recovery

- **Application rollback:** `[Procedure and limitations]`
- **Database rollback / forward-fix:** `[Procedure and limitations]`
- **Configuration rollback:** `[Procedure]`
- **Last tested:** `[YYYY-MM-DD and result, or Never/Unknown]`

## 13. Operations, Monitoring, and Maintenance

### 13.1 Service Ownership and Support

| Area | Owner | Responsibilities | Support hours / escalation | Contact reference |
| --- | --- | --- | --- | --- |
| `[Application, infrastructure, database, integration, business process, etc.]` | `[Role/team]` | `[Responsibilities]` | `[Coverage and escalation]` | `[Non-sensitive reference]` |

### 13.2 Monitoring and Alerting

| Signal / Check | Source | Threshold / Condition | Alert destination | Response / Runbook | Status | Last verified |
| --- | --- | --- | --- | --- | --- | --- |
| `[Availability, latency, errors, queue depth, disk, business metric, etc.]` | `[Tool/component]` | `[Condition]` | `[Team/channel/system]` | `[Action/reference]` | `[Status]` | `[Date]` |

### 13.3 Logging and Auditability

- **Log sources and locations:** `[Non-secret references]`
- **Structured fields / correlation:** `[Current approach]`
- **Retention and access:** `[Current policy and roles]`
- **Sensitive-data handling:** `[Redaction/masking behaviour]`
- **Audit events:** `[Events currently captured]`
- **Known gaps:** `[Issue or Unknown]`

### 13.4 Operational Runbooks

| Scenario | Detection | Immediate response | Recovery / Verification | Runbook | Status |
| --- | --- | --- | --- | --- | --- |
| `[Incident or routine operation]` | `[How identified]` | `[First actions]` | `[How service is restored and checked]` | `[Reference]` | `[Status]` |

### 13.5 Backups and Disaster Recovery

| Asset | Backup method | Frequency | Retention | Restore procedure | Last restore test | RPO / RTO | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `[Data or configuration asset]` | `[Method]` | `[Schedule]` | `[Retention]` | `[Reference]` | `[Date/result or Never]` | `[Targets or Unknown]` | `[Status]` |

### 13.6 Routine Maintenance

| Activity | Frequency / Trigger | Owner | Procedure | Last completed | Status |
| --- | --- | --- | --- | --- | --- |
| `[Patching, dependency updates, certificate rotation, cleanup, data archiving, etc.]` | `[Schedule/trigger]` | `[Owner]` | `[Reference]` | `[Date]` | `[Status]` |

## 14. Performance, Capacity, and Reliability

| Concern / Metric | Current measurement | Expected threshold / capacity | Evidence / Date | Limitation or risk | Status |
| --- | --- | --- | --- | --- | --- |
| `[Latency, throughput, concurrency, availability, storage growth, etc.]` | `[Observed value or Unknown]` | `[Target or Unknown]` | `[Evidence/date]` | `[Known constraint]` | `[Status]` |

### 14.1 Resilience Behaviour

- **Timeouts:** `[Current behaviour]`
- **Retries and idempotency:** `[Current behaviour]`
- **Circuit breaking / degradation:** `[Current behaviour]`
- **High availability / failover:** `[Current behaviour]`
- **Single points of failure:** `[Confirmed items or Unknown]`

## 15. Known Issues, Limitations, Risks, and Technical Debt

### 15.1 Known Issues

| ID | Issue | User / Operational impact | Affected area | Workaround | Severity | Owner | Status | Evidence / Reference |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `[ID]` | `[Confirmed defect or incident pattern]` | `[Impact]` | `[Component/workflow]` | `[Current workaround or None]` | `[Severity]` | `[Owner]` | `[Open, Mitigated, Resolved, etc.]` | `[Issue, log, test, or date]` |

### 15.2 Current Limitations

| Limitation | Effect | Reason | Scope | Planned resolution | Status |
| --- | --- | --- | --- | --- | --- |
| `[Intentional or unavoidable current limitation]` | `[Effect]` | `[Why it exists]` | `[Affected users/components]` | `[Approved plan or None]` | `[Status]` |

### 15.3 Risks

| ID | Risk | Likelihood | Impact | Current controls | Residual risk | Owner | Review date | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `[ID]` | `[Potential future problem]` | `[Rating]` | `[Rating/consequence]` | `[Existing mitigations]` | `[Rating]` | `[Owner]` | `[YYYY-MM-DD]` | `[Status]` |

### 15.4 Technical Debt

| ID | Debt item | Evidence / Location | Consequence | Recommended treatment | Priority | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `[ID]` | `[Structural or maintainability problem]` | `[Path, module, test, or observation]` | `[Cost/risk]` | `[Refactor, replace, document, accept, etc.]` | `[Priority]` | `[Owner]` | `[Status]` |

## 16. Incomplete, Deprecated, Planned, and Unknown Areas

### 16.1 Incomplete or Partially Implemented Work

| Capability / Change | Implemented portion | Missing portion | Current user-visible effect | Safe to use? | Owner / Reference | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `[Item]` | `[What is confirmed]` | `[What remains]` | `[Effect]` | `[Yes/No/Conditional]` | `[Owner/issue]` | **Partially implemented** |

### 16.2 Deprecated or Removed Functionality

| Item | Status | Replacement | Remaining dependencies / migration | Removal date or condition | Evidence |
| --- | --- | --- | --- | --- | --- |
| `[Feature, endpoint, component, or configuration]` | `[Deprecated/Removed]` | `[Replacement or None]` | `[Current dependencies]` | `[Date/condition]` | `[Evidence]` |

### 16.3 Planned or Proposed Work

<!-- Keep future work separate from implemented capability. Include only approved plans or material proposals needed to understand current direction. -->

| Item | Status | Intended outcome | Approval / Source | Dependencies | Target / Priority | Current-system impact |
| --- | --- | --- | --- | --- | --- | --- |
| `[Future item]` | `[Planned/Proposed]` | `[Outcome]` | `[Approved roadmap, ticket, proposal, or owner]` | `[Dependencies]` | `[Target/priority]` | `[How current decisions are affected, if at all]` |

### 16.4 Unknowns Requiring Verification

| Question / Unknown | Why it matters | Evidence already checked | How to verify | Owner | Due date / Trigger |
| --- | --- | --- | --- | --- | --- |
| `[Unverified aspect]` | `[Impact of uncertainty]` | `[Sources reviewed]` | `[Specific verification action]` | `[Owner]` | `[Date/trigger]` |

## 17. Current Priorities and Next Safe Actions

<!-- Record near-term work that is approved and relevant to maintaining or changing current system reality. Do not treat it as implemented. -->

| Priority | Action | Reason | Dependencies | Owner | Completion evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `[Priority]` | `[Specific action]` | `[Why now]` | `[Dependencies]` | `[Owner]` | `[What proves completion]` | `[Planned/In progress/Blocked]` |

## 18. Verification Checklist

<!-- Complete this checklist whenever the document is materially updated. -->

- [ ] Implemented claims were checked against the current codebase, deployed system, tests, configuration, or other direct evidence.
- [ ] The documented release or commit matches the system that was inspected.
- [ ] Partial, planned, proposed, deprecated, removed, and unknown items are clearly labelled.
- [ ] Roles and permissions reflect actual enforcement, not UI visibility alone.
- [ ] Configuration is documented without exposing secret values.
- [ ] Integrations and dependencies reflect current versions and runtime use.
- [ ] Environment and deployment information reflects current operation.
- [ ] Known issues, risks, limitations, and technical debt were reviewed.
- [ ] Operational procedures, monitoring, backups, and recovery information were reviewed.
- [ ] Superseded information was updated or moved to the appropriate historical/deprecated section.
- [ ] Material changes were added to the change history.

## 19. Change History

<!-- Record changes to this current-state document, not every source-code commit. -->

| Date | Document version | Changed by | System-state change recorded | Evidence / Reference |
| --- | --- | --- | --- | --- |
| `[YYYY-MM-DD]` | `[Version]` | `[Name/role]` | `[Summary]` | `[Commit, release, issue, deployment, decision, or verification source]` |

## 20. References

<!-- Link only to sources that help verify or operate the current system. Distinguish requirements and historical design documents from implementation evidence. -->

| Reference | Type | Relevance | Authority / Limitations |
| --- | --- | --- | --- |
| `[Document, repository, dashboard, runbook, specification, ticket, or decision record]` | `[Implementation evidence, operational source, requirement, historical design, etc.]` | `[What it supports]` | `[Whether it proves current behaviour or provides context only]` |

