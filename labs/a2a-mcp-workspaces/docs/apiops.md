# APIOps methodology

## Purpose

APIOps applies GitOps and DevOps practices to API lifecycle management. The repository holds the reviewed API Management configuration, pull requests provide design and governance checks, and CI/CD promotes an immutable commit through environments.

Use APIOps for API definitions, policies, products, diagnostics, named values, service-level proxies, and MCP publication. Use separate pipelines for:

- Azure infrastructure such as API Management, workspace gateways, networking, monitoring, and Foundry;
- backend applications and data;
- agent code, configuration, and evaluations.

The pipelines coordinate through versioned outputs and release metadata, not by sharing broad deployment credentials.

## Recommended repository model

For an organization with one shared API Management service, use a monorepo for API Management configuration unless regulatory or organizational boundaries require separate repositories.

Why:

- service-level names and paths must be coordinated globally;
- shared MCP publication changes often span a workspace API and service-level resources;
- one repository can enforce consistent checks and code ownership;
- a single publication pipeline can serialize writes to each API Management target.

Domain backend and agent source code can remain in team repositories.

Example:

```text
api-management/
├── platform/
│   ├── global-policy.xml
│   ├── policy-fragments/
│   ├── products/
│   └── diagnostics/
├── workspaces/
│   ├── weather/
│   │   ├── apis/
│   │   ├── products/
│   │   └── tests/
│   └── oncall/
│       ├── apis/
│       ├── products/
│       └── tests/
├── shared-publication/
│   ├── proxy-apis/
│   ├── mcp-servers/
│   └── tests/
├── environments/
│   ├── dev/
│   ├── test/
│   └── prod/
├── pipelines/
├── CODEOWNERS
└── package-lock.json
```

The exact generated artifact layout must follow the pinned APIOps CLI version. Do not assume this conceptual layout is directly publishable.

## Ownership and pull-request boundaries

Use `CODEOWNERS` or the equivalent repository control:

- `workspaces/<team>/`: domain team required;
- `shared-publication/`: API platform and affected domain team required;
- `platform/`: API platform required, security required for control changes;
- `environments/prod/`: platform release approver required;
- pipeline and identity files: platform security or DevOps owner required.

Protect release branches from direct pushes, force pushes, and deletion. Require successful checks and reviewer approval. Consider signed commits where provenance requirements justify them.

## Source strategies

### Code-first

Teams author API contracts, information files, and policies in Git. Use this as the normal model when teams already use contract-first development.

### Extract-first

Use `apiops extract` to establish a reviewed baseline from a known-good API Management environment or to capture an explicitly approved emergency change. Inspect extracted artifacts for secrets and unintended environment-specific values before committing.

After the baseline is accepted, Git becomes authoritative. Scheduled extraction can detect drift, but must not silently overwrite the repository.

## Pull-request pipeline

Run the narrowest checks relevant to changed paths, while always checking cross-scope dependencies for shared publication.

### Common checks

- artifact schema and APIOps CLI compatibility;
- OpenAPI syntax and organization lint rules;
- breaking-change detection;
- duplicate API names, paths, operation IDs, MCP names, and tool names;
- APIM policy XML validation;
- required `<base />` inheritance;
- forbidden policy expressions or payload logging;
- secret scanning;
- owner, classification, support, and service-objective metadata;
- environment-neutral configuration;
- Bicep validation for infrastructure changes.

### Workspace API checks

- backend reachability in the target test environment;
- authentication and authorization;
- positive and negative contract tests;
- policy behavior and error normalization;
- retry, timeout, rate-limit, and quota tests;
- compatibility with the current service-level global policy.

### Shared MCP checks

- operation exists in the approved workspace API contract;
- publication exposes only approved operations;
- tool description and input schema quality;
- MCP initialization, discovery, invocation, and streaming;
- no response-body access in MCP policies;
- agent evaluation and misuse tests;
- end-to-end telemetry correlation.

## Continuous delivery

Use one publisher per API Management target and prevent concurrent writes.

```mermaid
flowchart LR
    PR[Pull request] --> VALIDATE[Lint, diff, policy, security, API tests]
    VALIDATE --> REVIEW[Owners approve]
    REVIEW --> MERGE[Immutable commit]
    MERGE --> DRYRUN[apiops publish --dry-run]
    DRYRUN --> DEV[Publish development]
    DEV --> TEST[Test and evaluate]
    TEST --> APPROVE[Environment approval]
    APPROVE --> PROD[Publish production]
    PROD --> VERIFY[Smoke test, monitor, reconcile]
```

For every target:

1. authenticate with a least-privilege federated workload identity;
2. select the approved commit;
3. apply reviewed environment overrides;
4. run `apiops publish --dry-run`;
5. fail on unexpected deletion or scope expansion;
6. publish the same commit with `apiops publish`;
7. run post-deployment tests;
8. record deployment evidence and compatibility metadata.

Pin `@azure-tools/apiops-cli` to a tested version, commit the lock file, and install with `npm ci`.

## Environment configuration

Keep shared artifacts environment-neutral. Override only values that genuinely differ:

- backend URLs;
- Azure resource IDs;
- named-value references;
- diagnostic targets;
- product visibility;
- allowed audiences and issuers;
- capacity and quotas.

Secrets must remain in an approved secret store or protected CI/CD environment and be referenced indirectly.

Current APIOps CLI guidance identifies a known limitation: workspace child overrides can be accepted in configuration but are not applied when publishing; only overrides to the workspace container itself are applied. Do not depend on child-resource overrides for workspace APIs, backends, named values, or policies until the limitation is resolved and verified with the pinned CLI version. Prefer one of these approaches:

- generate environment-specific artifacts in a reviewed build step;
- use named-value indirection where supported and secure;
- parameterize those resources in a separate IaC deployment;
- maintain explicit, reviewed environment overlays that are tested before publication.

## Infrastructure and configuration split

Use Bicep or Terraform for slow-changing infrastructure:

- API Management service and managed identity;
- workspaces and workspace gateways;
- network integration and private connectivity;
- Log Analytics and Application Insights;
- Foundry accounts and model deployments;
- role assignments.

Use APIOps for independently released API configuration:

- API contracts and operations;
- policies;
- products and subscriptions;
- diagnostics;
- service-level proxy APIs;
- MCP servers where supported by the selected APIOps CLI release.

Before adopting the split, verify that the pinned APIOps CLI supports every required workspace and MCP artifact. Keep unsupported resources in IaC rather than mixing portal changes into the release process.

## Drift management

Production portal writes should normally be denied or tightly limited.

Run scheduled extraction or a read-only comparison to detect:

- resources present only in Azure;
- resources present only in Git;
- policy differences;
- changed paths or authentication;
- new operations or widened MCP tool exposure;
- changed diagnostics or logging.

Open an issue or pull request for drift. Do not automatically accept the deployed state as correct.

## Emergency changes

When immediate production mitigation cannot wait for the normal pipeline:

1. declare an incident and record the approver;
2. grant time-bound, least-privilege access;
3. make the smallest reversible change;
4. capture before-and-after state;
5. validate service recovery;
6. extract the change into a branch;
7. run normal validation and review;
8. merge and republish so Git becomes authoritative again;
9. remove elevated access;
10. complete a post-incident review.

## Rollback and compatibility

Record these as one release unit:

- APIOps commit;
- API version and revision;
- backend image or release;
- service-level proxy and MCP tool set;
- agent version and evaluation result.

For nonbreaking changes, make the previous API revision current. For breaking changes, retain the previous API version until consumers migrate. Test the full rollback path: reverting APIM configuration alone cannot repair an incompatible backend or agent.

## Metrics

Track:

- pull-request lead time and approval wait time;
- deployment frequency and failure rate;
- time to restore;
- drift count and age;
- breaking changes detected before merge;
- emergency changes;
- percentage of APIs with owners, service objectives, and deprecation metadata;
- MCP evaluation pass rate;
- failed or throttled tool calls by consumer and team.

## References

- [Automate API Management configuration by using APIOps CLI](https://learn.microsoft.com/azure/architecture/example-scenario/devops/automated-api-deployments-apiops)
- [APIOps CLI](https://github.com/Azure/apiops-cli)
- [API Management DevOps and CI/CD guidance](https://learn.microsoft.com/azure/api-management/devops-api-development-templates)
- [API revisions](https://learn.microsoft.com/azure/api-management/api-management-revisions)
- [API versions](https://learn.microsoft.com/azure/api-management/api-management-versions)

