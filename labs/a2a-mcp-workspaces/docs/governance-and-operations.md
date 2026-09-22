# Governance and operations

## Identity and access

Assign permissions to Microsoft Entra groups, not individual users.

Recommended groups per team:

- workspace readers;
- workspace contributors;
- workspace approvers;
- gateway operators, only when gateway management is delegated;
- production release approvers.

Use workspace-scoped built-in roles or equivalent custom roles for workspace resources. Grant service-scoped permissions only when a workspace collaborator must reference a supported service-level resource. Keep production write permissions with the publisher identity and use just-in-time elevation for emergencies.

Pipeline identities should be separated by purpose and environment:

- infrastructure deployment;
- APIOps extraction;
- nonproduction publication;
- production publication;
- backend deployment;
- agent deployment.

Prefer workload identity federation. Do not store long-lived service-principal secrets in repositories or pipeline variables.

## Policy hierarchy

API Management evaluates policy by scope:

```text
global -> workspace -> product -> API -> operation
```

Use each scope intentionally:

| Scope | Appropriate controls |
| --- | --- |
| Global | correlation, approved baseline headers, organization-wide network controls, mandatory audit behavior |
| Workspace | team-wide conventions and controls |
| Product | consumer plan, quota, subscription behavior |
| API | authentication, backend routing, API-specific limits and transformations |
| Operation | exceptional operation-specific validation or limits |
| MCP server | MCP client authentication, tool-level rate limiting, trace metadata |

Require `<base />` so child scopes inherit parent controls. Audit or deny noncompliant policies with Azure Policy where available.

Global policy executes on workspace gateways. Avoid global authentication or routing logic that is inappropriate for workspace APIs. If behavior depends on the gateway, branch explicitly using `context.Deployment.Gateway.Id`, or move the policy to a narrower scope.

## Security baseline

### Inbound

- authenticate every nonpublic consumer;
- validate issuer, audience, signature, expiry, and required claims;
- authorize by product, application, user, tenant, role, or scope as required;
- use distinct identities for agents and human clients;
- rate-limit by a stable consumer identity rather than IP alone where possible;
- validate content type, size, parameters, and schemas;
- restrict CORS to approved origins;
- reject undocumented operations and methods.

### Backend

- prefer managed identity or workload identity;
- restrict backend ingress to trusted network paths and identities;
- remove inbound consumer credentials before forwarding unless explicitly required;
- use explicit timeouts and retry only safe, idempotent operations;
- protect secrets with Key Vault or an approved secret store;
- pin TLS and certificate expectations according to organizational policy.

### MCP and agents

- expose the minimum set of operations as tools;
- classify tools as read-only, write, destructive, or privileged;
- require stronger approval or human confirmation for high-impact actions;
- treat tool descriptions, parameters, and backend output as untrusted input;
- prevent agents from receiving credentials they do not need;
- test indirect prompt injection and confused-deputy scenarios;
- avoid response payload logging;
- never read `context.Response.Body` in MCP policies.

## API and tool governance

Every published API and MCP server should carry:

- business domain;
- accountable owner;
- support contact and escalation route;
- data classification;
- API version and lifecycle state;
- consumer audience;
- authentication method;
- service objective;
- dependency list;
- repository and approved commit;
- deployment environment;
- MCP tool risk classification, where applicable.

Use Azure API Center or another approved catalog when centralized discovery, inventory, lifecycle, and compliance metadata need to span multiple API Management services.

## Observability

### Correlation

Create or preserve a W3C-compatible correlation identifier across:

```text
A2A client -> agent -> MCP server -> service proxy -> workspace API -> backend
```

Record the agent identity, consuming application, API ID, operation ID, workspace, gateway, backend release, and result without recording sensitive prompts or payloads.

### Signals

Platform dashboards:

- gateway CPU, memory, capacity, availability, and saturation;
- aggregate request rate, latency, error rate, and throttling;
- authentication failures and policy errors;
- MCP initialization, discovery, and invocation failures;
- model token usage, quota, and cost;
- workspace-gateway and backend connectivity.

Team dashboards:

- API and operation availability;
- backend latency and errors;
- quota and rate-limit events;
- dependency health;
- consumer and agent usage;
- MCP tool success, rejection, and timeout rates.

Azure Monitor metrics cannot currently be split by workspace. Use resource logs, API identifiers, custom dimensions, and correlation IDs for workspace-level analysis.

### Logging controls

- log metadata needed for security and operations;
- redact credentials, tokens, personal data, prompts, and sensitive response fields;
- set global frontend response payload logging to zero for MCP compatibility;
- define retention by classification and audit requirements;
- restrict log query access;
- test that logging does not buffer or break streaming.

## Reliability and capacity

Multiple workspaces on one gateway share its compute and configuration. One team's anomalous traffic or faulty API can affect others.

Controls:

- define per-team and per-consumer rate limits;
- monitor capacity and saturation;
- load-test before onboarding high-volume APIs;
- maintain headroom for failures and bursts;
- place mission-critical workspaces on dedicated gateways where justified;
- distribute noncritical workspaces across at least two gateways for larger estates;
- prepare a tested quarantine procedure for a noisy workspace;
- document gateway and backend recovery objectives.

A workspace gateway can be associated with multiple workspaces only under current platform conditions, and published limits can change. Validate current regional availability, workspace-per-gateway limits, and SKU support during design.

## Incident ownership

| Symptom | Initial owner | Required collaborators |
| --- | --- | --- |
| One backend or workspace API fails | domain API team | platform if gateway or policy is implicated |
| One MCP server fails but workspace API is healthy | API platform | domain and agent teams |
| Agent selects or uses a tool incorrectly | agent team | domain team for contract interpretation |
| Multiple workspaces degrade on one gateway | API platform | affected teams and cloud operations |
| Shared inference fails | AI platform | API platform and agent teams |
| Unauthorized access or data exposure | security incident response | platform and owning teams |

Every alert must identify the owning team and a runbook. The incident commander coordinates cross-layer mitigation and records the known-good compatibility set used for recovery.

## Operational runbooks

Maintain tested runbooks for:

- disabling one MCP tool without disabling its workspace API;
- disabling an MCP server;
- reverting an API revision;
- rolling back a backend;
- moving or quarantining a workspace on another gateway;
- rotating credentials and certificates;
- responding to a compromised agent identity;
- restoring APIOps source-of-truth after an emergency portal change;
- draining and retiring an API version.

## Governance review cadence

| Cadence | Review |
| --- | --- |
| Per pull request | contract, policy, security, ownership, publication scope |
| Per release | dry-run, compatibility, rollback, test evidence |
| Monthly | drift, failed deployments, unused subscriptions, quota and capacity |
| Quarterly | workspace access, tool inventory, exceptions, deprecations, cost allocation |
| Annually or after major change | threat model, gateway topology, disaster recovery, control effectiveness |

## Production readiness checklist

### Platform

- [ ] Environment and gateway topology are documented.
- [ ] Production publisher uses least privilege and workload identity federation.
- [ ] Global policy is compatible with workspace gateways.
- [ ] Diagnostics do not log MCP response bodies.
- [ ] Capacity alerts and quarantine procedures exist.

### Domain API

- [ ] Owner, support route, service objective, and data classification are registered.
- [ ] Contract and breaking-change checks pass.
- [ ] Authentication and authorization are tested.
- [ ] Backend release and rollback are reproducible.
- [ ] Workspace dashboards and alerts are active.

### MCP and agent

- [ ] Only approved operations are exposed.
- [ ] Tool names, schemas, and descriptions are stable and evaluated.
- [ ] High-impact operations have additional safeguards.
- [ ] MCP streaming and telemetry correlation are verified.
- [ ] Agent release records its compatible API and MCP versions.
- [ ] A2A agent card accurately describes supported skills and authentication.

## References

- [API Management workspaces](https://learn.microsoft.com/azure/api-management/workspaces-overview)
- [API Management RBAC](https://learn.microsoft.com/azure/api-management/api-management-role-based-access-control)
- [API Management policy scopes](https://learn.microsoft.com/azure/api-management/api-management-howto-policies#scopes)
- [Monitor MCP server traffic](https://learn.microsoft.com/azure/api-management/monitor-mcp-servers)
- [Secure MCP servers](https://learn.microsoft.com/azure/api-management/secure-mcp-servers)

