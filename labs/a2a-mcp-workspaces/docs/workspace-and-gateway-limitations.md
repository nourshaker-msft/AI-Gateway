# Workspace and gateway technical limitations

This page summarizes the current technical constraints that most strongly affect an organizational API Management workspace design. It focuses on resource placement, regional availability, networking, and gateway selection.

> [!IMPORTANT]
> The constraints and region list were verified against Microsoft documentation on September 22, 2026. Azure service availability and capacity change over time, so treat the region list as a point-in-time planning aid, not as a deployment guarantee. Always check [Availability of v2 tiers and workspace gateways](https://learn.microsoft.com/azure/api-management/api-management-region-availability) immediately before selecting a region or starting a deployment.

## Scope and terminology

An API Management **workspace** is a child resource of one API Management service. It does not have an independent Azure region, subscription, network, or public hostname.

Workspace APIs run on one of these gateway types:

- the API Management service's **default managed gateway**;
- a separately deployed **workspace gateway** associated with one or more workspaces.

The gateway choice determines runtime location, network capabilities, hostname, capacity isolation, cost, and several operational constraints.

## Placement rules at a glance

| Resource relationship | Current rule | Consequence |
| --- | --- | --- |
| Workspace to API Management service | A workspace belongs to exactly one API Management service | A workspace can't span services or be shared across services |
| Workspaces on one workspace gateway | All must belong to the same API Management service | A shared gateway can't aggregate workspaces from different API Management services |
| Workspace gateway to API Management service | Must be in the same Azure subscription and the same region as the service's primary region | No cross-subscription gateway placement and no gateway placement in a secondary API Management region |
| Workspace gateway virtual network to API Management service | Virtual network must be in the same subscription and region as the API Management service | A centrally managed virtual network in another subscription can't host the gateway subnet directly |
| Workspace gateway subnet | Dedicated to one workspace gateway | The subnet can't be shared with another workspace gateway or any other Azure resource |
| Backend placement | Not required to share the gateway subscription or region, provided network and identity paths work | Cross-region or cross-subscription backends remain possible, but add routing, latency, resiliency, and data-residency considerations |

An Azure subscription itself does not have a deployment location. The constraints apply to the regions of the API Management service, workspace gateway, and virtual network, and to whether those resources are in the same subscription.

## API Management tier and gateway support

Workspaces are currently supported in:

- Basic v2;
- Standard v2;
- Premium;
- Premium v2.

The default managed gateway option for workspaces is currently available only in the v2 tiers. Creating or updating the workspace association with the default managed gateway is currently performed through the API Management REST API.

A separately billed workspace gateway has its own SKU, capacity, hostname, network configuration, and regional availability. Do not assume that a region supporting the selected API Management tier also supports creation of a workspace gateway.

## Regional availability

At the time this guide was updated, Microsoft listed new Premium workspace gateway creation as available in these regions:

| Region | Workspace gateway creation |
| --- | --- |
| East Asia | Available |
| France Central | Available |
| Japan East | Available |
| North Central US | Available |
| Norway East | Available |
| West Europe | Available |
| West US | Available |

The following regions were listed with a temporary capacity limitation for new workspace gateway creation:

| Region | Current status |
| --- | --- |
| Australia East | Temporarily unavailable for new instances |
| Central US | Temporarily unavailable for new instances |
| East US 2 | Temporarily unavailable for new instances |
| Germany West Central | Temporarily unavailable for new instances |
| North Europe | Temporarily unavailable for new instances |
| Sweden Central | Temporarily unavailable for new instances |
| UK South | Temporarily unavailable for new instances |

Existing instances are not affected by a temporary new-instance capacity restriction. The list can change independently of this repository.

### Regional design implications

- Select the API Management primary region only after confirming availability for both the service tier and the intended workspace gateway.
- A multi-region API Management service does not allow a workspace gateway to be placed beside every secondary region. The workspace gateway must be in the primary region.
- Workspace gateways have a smaller regional footprint than Basic v2 and Standard v2 services.
- Region pairing does not override the same-primary-region rule.
- A disaster-recovery design that requires another region needs a separate pre-provisioned or deployable API Management environment and a tested configuration-promotion and traffic-failover process.
- Capacity can be unavailable even when a region appears in the support matrix. Validate quota, capacity, networking, and dependent-service availability before committing to a region.

## Default managed gateway limitations

When a workspace uses the service's default managed gateway:

- traffic uses the service hostname, such as `<service-name>.azure-api.net`;
- workspace APIs share the default gateway's capacity and configuration with service-level APIs and other workspaces;
- the workspace follows the network and regional topology of the API Management service;
- runtime isolation is lower than with a dedicated workspace gateway;
- a noisy or faulty workload can consume shared capacity;
- association is currently supported only in v2 tiers and is configured through the REST API.

The default gateway can be appropriate when shared capacity is acceptable and its broader API Management networking and hostname capabilities are required. It does not provide a separate scaling or network boundary for the workspace.

## Workspace gateway limitations

### Association and capacity

- A workspace gateway can serve only workspaces from its associated API Management service.
- Up to 30 workspaces can be associated with one workspace gateway by default; Microsoft support can be contacted about increasing this limit.
- Associating multiple workspaces is available only for workspace gateways created after April 15, 2025.
- All associated workspaces share the gateway's CPU, memory, networking, hostname, configuration, and scale units.
- A bug or traffic spike in one workspace can affect every workspace on that gateway.
- Gateway creation is a long-running operation and can take three hours or more. Workspace API runtime calls don't succeed while a new gateway is still being created.

The numerical limit is not a recommended consolidation target. Use workload criticality, trust zone, network dependencies, capacity, and failure-domain requirements to determine how many workspaces share a gateway.

### Hostnames and private access

- Each workspace gateway receives a Microsoft-provided hostname similar to `<gateway-name>-<hash>.gateway.<region>.azure-api.net`.
- Workspace gateways do not currently support custom hostnames.
- Workspace gateways do not currently support inbound Azure Private Endpoint.
- Private inbound access is instead provided by **virtual network injection**.
- For a custom external hostname, place an approved edge proxy such as Azure Front Door or Application Gateway in front of the workspace gateway and validate TLS, authentication, client IP handling, streaming, and failure behavior.

Private Endpoint and virtual network injection are different networking models. Do not design a private workspace gateway around an inbound private endpoint that the resource does not support.

### Network configuration is immutable

A workspace gateway's network configuration is selected when the gateway is created. It cannot currently be changed afterward.

This includes the choice between:

| Mode | Inbound access | Outbound access |
| --- | --- | --- |
| No virtual network isolation | Public | Public |
| Virtual network integration | Public | Private |
| Virtual network injection | Private | Private |

Changing the network mode requires planning a replacement gateway and moving workspace associations rather than updating the existing gateway in place. Treat the network mode, virtual network, subnet, DNS, and routing design as production architecture decisions.

The workspace gateway network configuration is independent of the API Management service's network configuration. Placing the service in a virtual network does not automatically place a workspace gateway in that network, and configuring a workspace gateway does not modify the service's default gateway network.

## Virtual network requirements

### Subscription and region

The virtual network must be in:

- the same Azure subscription as the API Management service; and
- the same Azure region as the API Management service.

This restriction is significant for hub-and-spoke organizations that place shared networks in a central connectivity subscription. A workspace gateway subnet cannot be selected directly from that other subscription. A same-subscription virtual network is required, after which approved peering or routing can connect it to shared network services.

### Dedicated subnet

The subnet:

- can be used by only one workspace gateway;
- can't contain other Azure resources;
- must be at least `/27`, providing 32 addresses;
- can be at most `/24`, providing 256 addresses;
- should use `/24` when future scale and address availability justify it.

Reserve the subnet before gateway deployment. Subnet reuse assumptions can otherwise block onboarding or force gateway replacement.

### Subnet delegation

The required delegation depends on network mode:

| Mode | Required subnet delegation |
| --- | --- |
| Virtual network integration | `Microsoft.Web/serverFarms` |
| Virtual network injection | `Microsoft.Web/hostingEnvironments` |

The `Microsoft.Web` resource provider must be registered in the subscription.

### Network security groups

An NSG is required on the subnet.

For virtual network integration:

- allow outbound TCP 443 to the `AzureKeyVault` service tag;
- allow any additional outbound paths needed to reach API backends;
- inbound NSG rules do not govern the gateway's public inbound path.

For virtual network injection:

- allow inbound TCP 80 from `AzureLoadBalancer` for health probes;
- allow inbound TCP 80 and 443 from the required `VirtualNetwork` sources;
- allow outbound TCP 443 to `AzureKeyVault`;
- allow required backend and dependency routes.

Apply more restrictive source ranges and egress rules where the platform supports them, but preserve mandatory service dependencies.

### DNS for private inbound access

Virtual network injection requires customer-managed DNS for inbound resolution:

1. create an Azure Private DNS zone or configure an approved custom DNS service;
2. link it to the gateway virtual network;
3. create an `A` record mapping the gateway's assigned hostname to its private virtual IP address;
4. ensure custom DNS resolves Azure Key Vault endpoints such as `*.vault.azure.net`;
5. validate resolution from every consuming network.

The workspace gateway responds to the configured hostname, not directly to its private virtual IP address. Calling the private IP without the expected host name is not a supported access pattern.

## Workspace feature constraints that influence gateway design

Current workspace constraints include:

- no association with self-hosted gateways;
- no MCP server resources inside workspaces;
- no Credential Manager support;
- internal cache only, with no external cache support;
- no synthetic GraphQL APIs;
- no CA certificates;
- no Defender for APIs coverage for workspace APIs;
- no direct portal creation of workspace APIs from resources such as Azure OpenAI, App Service, or Function Apps;
- no Azure Monitor request-metric split by workspace;
- managed identity uses the API Management service's identity.

These constraints can force selected capabilities to the service level. In this lab, MCP servers are service-level resources that proxy to workspace-owned REST APIs.

## Common architecture traps

| Assumption | Why it fails | Safer approach |
| --- | --- | --- |
| "Our central networking subscription can host every gateway subnet" | Workspace gateway virtual networks must be in the API Management subscription | Create a compliant VNet in the API Management subscription and connect it to the hub |
| "We can move the gateway to another region later" | Gateway and VNet placement are region-bound, and network configuration is immutable | Validate the target region first and use replacement-and-migration procedures |
| "Private Endpoint will make the workspace gateway private" | Inbound private endpoints aren't supported | Use virtual network injection and private DNS |
| "We can add our corporate hostname directly" | Custom hostnames aren't supported on workspace gateways | Use the Microsoft hostname internally or a validated edge proxy |
| "A shared gateway isolates teams" | Associated workspaces share compute and configuration | Use dedicated gateways for critical or incompatible workloads |
| "A supported v2 region supports workspace gateways" | Availability matrices differ | Check both columns in the current region table |
| "Workspaces provide regional disaster recovery" | Workspaces are children of one service and workspace gateways stay in its primary region | Deploy and rehearse a separate regional API Management environment |
| "We can change public networking to private after launch" | Workspace gateway network mode can't currently be changed | Choose the final network model before creation or plan replacement |

## Pre-deployment checklist

- [ ] The selected API Management tier supports workspaces.
- [ ] The primary region supports both the selected API Management tier and new workspace gateway creation.
- [ ] No temporary regional capacity restriction blocks deployment.
- [ ] API Management, the workspace gateway, and its virtual network are in the same subscription.
- [ ] The workspace gateway and virtual network are in the API Management primary region.
- [ ] The gateway-sharing and failure-domain decision is documented.
- [ ] The permanent network mode is selected before creation.
- [ ] A dedicated `/27` to `/24` subnet is reserved.
- [ ] The correct subnet delegation is configured.
- [ ] The `Microsoft.Web` resource provider is registered.
- [ ] Required NSG rules, backend routes, firewall rules, and Key Vault access are tested.
- [ ] Private DNS is designed and tested for virtual network injection.
- [ ] The hostname strategy accounts for the lack of workspace-gateway custom hostnames.
- [ ] The design does not depend on inbound private endpoints or self-hosted gateways.
- [ ] Regional recovery and gateway replacement procedures are documented.
- [ ] Long provisioning time is included in release and recovery planning.

## References

- [Federated API management with workspaces](https://learn.microsoft.com/azure/api-management/workspaces-overview)
- [Create and manage an API Management workspace](https://learn.microsoft.com/azure/api-management/how-to-create-workspace)
- [Network resource requirements for workspace gateways](https://learn.microsoft.com/azure/api-management/virtual-network-workspaces-resources)
- [Availability of v2 tiers and workspace gateways](https://learn.microsoft.com/azure/api-management/api-management-region-availability)
- [API Management virtual network concepts](https://learn.microsoft.com/azure/api-management/virtual-network-concepts)
- [API Management gateways overview](https://learn.microsoft.com/azure/api-management/api-management-gateways-overview)
