# Multi-team operating model

## Team model

### API platform team

The API platform team provides the paved road. It owns the shared API Management service, workspace creation, gateway topology, global policy, service-level MCP publication, platform observability, and the production publisher identity.

It does not own domain contracts or backend behavior.

### Domain API teams

Each domain team owns a bounded API capability from design through operations:

- API contract and semantic versioning;
- backend implementation and deployment;
- workspace API and workspace-scoped policy;
- functional, contract, security, and performance tests;
- service objectives, dashboards, alerts, and on-call response;
- consumer communication and deprecation.

### Agent teams

Agent teams own agent instructions, tool selection, A2A publication, evaluations, and behavior. They consume only approved MCP endpoints and shared inference connections. A domain API team and an agent team can be the same organizational team, but their release artifacts remain separately traceable.

### Security and governance

Security and governance define mandatory controls, review exceptions, data handling, threat-model requirements, and evidence retention. Controls should be automated in pull requests and Azure Policy wherever possible.

## Responsibility matrix

| Activity | Domain API team | Agent team | API platform | Security/governance |
| --- | --- | --- | --- | --- |
| Define API contract | A/R | C | C | C |
| Implement and operate backend | A/R | I | I | C |
| Manage workspace API | A/R | I | C | C |
| Create workspace and RBAC | C | I | A/R | C |
| Define global policy baseline | C | I | A/R | C |
| Approve API for shared publication | A/R | C | A/R | C |
| Create service proxy and MCP server | C | C | A/R | C |
| Define MCP tool descriptions | A/R | C | C | C |
| Configure agent and A2A card | C | A/R | C | C |
| Operate shared gateway | I | I | A/R | C |
| Respond to backend/API incident | A/R | C | C | I |
| Respond to gateway-wide incident | C | C | A/R | I |
| Approve policy exception | C | I | C | A/R |

`R` = responsible, `A` = accountable, `C` = consulted, `I` = informed.

## Workspace onboarding

The platform team creates workspaces; teams do not self-provision arbitrary workspaces in production.

An onboarding request should contain:

- domain and owning Microsoft Entra group;
- technical and business contacts;
- API names and globally unique resource-name prefix;
- data classification and regulatory requirements;
- expected traffic, latency, payload size, and availability;
- backend network and identity requirements;
- consumer types: human applications, services, MCP clients, or agents;
- requested gateway trust zone;
- monitoring workspace and support routing;
- recovery, deprecation, and cost-center information.

The platform team then:

1. validates the domain boundary and naming;
2. selects or creates the gateway;
3. creates the workspace through IaC;
4. grants workspace-scoped roles to Entra groups;
5. grants only the service-scoped read permissions needed for supported shared references;
6. configures repository ownership and CI/CD environment permissions;
7. provisions dashboards, alerts, and budget attribution;
8. provides a nonproduction path for the first API.

## Change classes

| Change | Primary workflow | Required approval |
| --- | --- | --- |
| Backend implementation only | application CI/CD | domain team |
| Nonbreaking contract or workspace policy | team APIOps pull request | domain code owner |
| Breaking contract | new API version plus consumer migration plan | domain owner and platform |
| New shared API publication | publication pull request | domain owner and platform |
| New or changed MCP tool | publication pull request plus agent evaluation | domain, platform, and affected agent owners |
| Global policy or shared gateway change | platform repository | platform and security |
| Agent instructions/model/configuration | agent CI/CD | agent owner; domain review if tool assumptions change |
| Emergency production change | time-bound privileged process | incident commander, followed by reconciliation pull request |

## API lifecycle

### Discover and design

- confirm that an existing capability cannot be reused;
- define consumers, data classification, and threat model;
- design the OpenAPI contract before implementation where practical;
- give every operation a stable `operationId`;
- define compatibility and deprecation rules;
- identify which operations, if any, are safe and useful as MCP tools.

### Build and verify

- deploy the backend independently;
- import or publish the API into a development workspace;
- validate authentication, authorization, policy behavior, failure mapping, and rate limits;
- test the API contract against the deployed backend;
- test MCP schemas and descriptions with realistic agent prompts;
- evaluate prompt injection, excess capability, data leakage, and destructive operations.

### Publish

- merge an approved, immutable set of API Management artifacts;
- promote it through nonproduction;
- create or update the service-level proxy and MCP server only after the workspace API is healthy;
- publish consumer documentation and ownership metadata;
- release the agent only after its tool dependencies pass evaluation.

### Operate and improve

- monitor availability, latency, error rate, throttling, backend health, and tool-call outcomes;
- review quota and capacity trends;
- investigate drift and reconcile through Git;
- periodically review unused tools, permissions, subscriptions, and stale versions.

### Deprecate and retire

1. mark the API or tool deprecated in its contract and catalog;
2. identify consumers from telemetry and ownership records;
3. communicate a dated migration plan;
4. remove the tool from agents before removing the MCP publication;
5. remove the service-level MCP server and proxy;
6. retire the workspace API and backend only when remaining traffic is zero or explicitly accepted;
7. preserve audit evidence according to retention requirements.

## Collaboration rules

- Teams may change only their owned workspace artifacts and backend.
- The platform team may reject publication without taking ownership of the domain API.
- Shared policy is changed once at the appropriate parent scope and inherited with `<base />`.
- A team-specific exception is explicit, documented, time-bound, and testable.
- No team may rely on another workspace's resources; shared capabilities belong at service level or behind a separately governed API.
- A single production target has a single active publisher pipeline to prevent concurrent writers.

