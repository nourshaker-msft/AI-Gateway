---
name: "Federated MCP with API Management Workspaces"
architectureDiagram: images/a2a-mcp-workspaces.gif
categories: ["AI Agents"]
services: ["Azure API Management", "Azure AI Foundry", "Azure OpenAI", "Azure Container Apps"]
shortDescription: "Federated AI gateway where team-owned APIs in API Management workspaces are backed by Azure Container Apps, exposed as MCP servers, and consumed by Azure AI Foundry agents."
detailedDescription: "Two decentralized API teams each own their tools in an isolated API Management workspace (Standard v2) associated with the default managed gateway. Each workspace API forwards to a skeleton backend service hosted on Azure Container Apps. The central platform team exposes each workspace API as a service-level Model Context Protocol (MCP) server, and a shared service-level Inference API is available to all agents. Two Azure AI Foundry agents — a Weather agent and an OnCall agent — consume the MCP servers, demonstrating federated, governed tool sharing across teams."
authors: ["AI-Gateway"]
---

# APIM ❤️ AI Agents

## [Federated MCP with API Management Workspaces lab](a2a-mcp-workspaces.ipynb)

[![flow](../../images/a2a-mcp-workspaces.gif)](a2a-mcp-workspaces.ipynb)

This lab demonstrates a **federated** AI gateway built on Azure API Management [workspaces](https://learn.microsoft.com/azure/api-management/workspaces-overview) (Standard v2), where decentralized API teams own their tools while the platform team exposes them as agent tools through a single, governed gateway.

### Architecture

- **Workspace 1 — Weather team** (`weather-ws`): owns a **Weather API** (a team-managed tool) that forwards to a **Weather backend on Azure Container Apps**.
- **Workspace 2 — OnCall team** (`oncall-ws`): owns an **OnCall API** (a team-managed tool) that forwards to an **OnCall backend on Azure Container Apps**.
- **Container platform**: an Azure Container Registry and a Container Apps environment host the two skeleton backend APIs (built from [src/weather/app](src/weather/app) and [src/oncall/app](src/oncall/app)).
- **Service level (shared by the platform team)**:
  - A **Weather MCP server** and an **OnCall MCP server** that proxy to the respective workspace-owned APIs.
  - A shared **Inference API** used by all agents.
- **Azure AI Foundry agents**: a **Weather agent** and an **OnCall agent**, each consuming its MCP server.

Both workspaces are associated with the service's **default managed gateway** (`serveOn: workspaceAndDefault`), which keeps deployment fast and avoids the extra cost of dedicated workspace gateways.

> [!NOTE]
> API Management workspaces don't support MCP servers directly, so each MCP server is created at the **service level** and routes to the workspace-owned API served on the default gateway. Workspaces require the Basic v2, Standard v2, Premium, or Premium v2 tier.

### Prerequisites

- [Python 3.12 or later version](https://www.python.org/) installed
- [VS Code](https://code.visualstudio.com/) installed with the [Jupyter notebook extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) enabled
- [uv](https://docs.astral.sh/uv/) — run `uv sync` from the repo root to install dependencies
- [An Azure Subscription](https://azure.microsoft.com/free/) with [Contributor](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#contributor) + [RBAC Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) or [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged#owner) roles
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and [Signed into your Azure subscription](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively)

### 🚀 Get started

Proceed by opening the [Jupyter notebook](a2a-mcp-workspaces.ipynb), and follow the steps provided.

### 🗑️ Clean up resources

When you're finished with the lab, you should remove all your deployed resources from Azure to avoid extra charges and keep your Azure subscription uncluttered.
Use the [clean-up-resources notebook](clean-up-resources.ipynb) for that.
