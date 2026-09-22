# Federated A2A and MCP platform guide

This guide expands the [a2a-mcp-workspaces lab](../README.md) into an organizational operating model for many API teams sharing one Azure API Management service.

The model separates two concerns:

- **Workspace ownership:** each domain team owns its API contract, backend, workspace-scoped policy, tests, and support.
- **Shared publication:** the API platform team controls what is exposed at the API Management service level, including shared MCP servers, agent-facing endpoints, cross-cutting policy, and production promotion.

This separation is required by the current platform boundary: API Management workspaces support team-owned REST APIs, but MCP servers must be created at the service level.

## Who should read this

| Audience | Start here |
| --- | --- |
| Platform architects | [Architecture and boundaries](architecture.md) |
| Network and landing-zone architects | [Workspace and gateway technical limitations](workspace-and-gateway-limitations.md) |
| API and agent team leads | [Operating model](operating-model.md) |
| API developers | [Onboarding and publishing](onboarding-and-publishing.md) |
| Platform and DevOps engineers | [APIOps methodology](apiops.md) |
| Security and operations teams | [Governance and operations](governance-and-operations.md) |

## Documentation map

1. [Architecture and boundaries](architecture.md) explains the control plane, data plane, workspace isolation, shared gateway surfaces, and request paths.
2. [Operating model](operating-model.md) defines ownership, decision rights, collaboration, and lifecycle responsibilities.
3. [Onboarding and publishing](onboarding-and-publishing.md) provides the workflow for taking a team-owned API from proposal to a shared API or MCP server.
4. [APIOps methodology](apiops.md) defines repositories, pull requests, validation, promotion, drift control, rollback, and emergency changes.
5. [Governance and operations](governance-and-operations.md) defines identity, policy, observability, reliability, support, and audit controls.
6. [Workspace and gateway technical limitations](workspace-and-gateway-limitations.md) documents current networking, subscription, region, hostname, and gateway-placement constraints.

## Lab implementation at a glance

The lab deploys:

- one Azure API Management service;
- one `weather-ws` workspace and one `oncall-ws` workspace;
- one shared dedicated workspace gateway connected to both workspaces;
- one team-owned REST API per workspace;
- one service-level proxy API and MCP server per published workspace API;
- one shared inference API;
- one central model-hosting Foundry resource and one Foundry resource per agent team;
- Weather and OnCall agents that use their published MCP servers and can be exposed over A2A.

The lab is intentionally compact. A production implementation should preserve the ownership boundaries in this guide while choosing gateway placement, repository topology, environment isolation, and approval controls according to workload criticality.

## Guiding principles

1. **One owner for every artifact.** A contract, policy, pipeline, and runtime alert must have an accountable team.
2. **Git is the source of truth.** Portal edits are exceptional and must be reconciled immediately.
3. **Teams publish contracts; the platform publishes shared surfaces.**
4. **Promote immutable commits.** Do not rebuild or reinterpret artifacts between environments.
5. **Separate API configuration from infrastructure and backend deployment.**
6. **Apply least privilege at workspace, service, gateway, and environment scopes.**
7. **Make backward compatibility and rollback part of the release design.**
8. **Treat MCP tools as privileged API capabilities, not as a second governance system.**

## Microsoft references

- [Federated API management with workspaces](https://learn.microsoft.com/azure/api-management/workspaces-overview)
- [Automate API Management configuration by using APIOps CLI](https://learn.microsoft.com/azure/architecture/example-scenario/devops/automated-api-deployments-apiops)
- [Expose a REST API as an MCP server](https://learn.microsoft.com/azure/api-management/export-rest-mcp-server)
- [About MCP servers in API Management](https://learn.microsoft.com/azure/api-management/mcp-server-overview)
