// ------------------------------------------------------------------
//  a2a-mcp-workspaces - main.bicep
//
//  APIM (Standard v2) federated with two workspaces:
//    - Weather workspace : team-owned Weather API      -> Weather MCP  (service level)
//    - OnCall workspace  : team-owned OnCall API        -> OnCall MCP   (service level)
//
//  Model Gateway pattern with three AI Foundry instances:
//    - inference-foundry : hosts the model deployments; exposed as a shared,
//                          service-level Inference API endpoint via APIM.
//    - weather-foundry   : no models; reaches models through an APIM
//                          model-gateway connection. Hosts the Weather agent.
//    - oncall-foundry    : no models; reaches models through an APIM
//                          model-gateway connection. Hosts the OnCall agent.
//
//  MCP servers are not supported inside workspaces, so each MCP server
//  is created at the service level and proxies to the workspace-owned
//  API (served on the dedicated workspace gateway).
// ------------------------------------------------------------------

// ------------------
//    PARAMETERS
// ------------------

param aiServicesConfig array = []
param modelsConfig array = []
param apimSku string = 'Standardv2'
param apimSubscriptionsConfig array = []
param inferenceAPIType string = 'AzureOpenAI'
param inferenceAPIPath string = 'inference'
param foundryProjectName string = 'default'

// Name of the model-gateway connection created on each team Foundry instance
param modelGatewayConnectionName string = 'ai-gateway'

// Weather workspace / tool configuration
param weatherWorkspaceName string = 'weather-ws'
param weatherWorkspaceDisplayName string = 'Weather Team Workspace'
param weatherApiPath string = 'weather'
param weatherToolApiPath string = 'weather-tool'
param weatherMcpPath string = 'weather-mcp'

// OnCall workspace / tool configuration
param oncallWorkspaceName string = 'oncall-ws'
param oncallWorkspaceDisplayName string = 'OnCall Team Workspace'
param oncallApiPath string = 'oncall'
param oncallToolApiPath string = 'oncall-tool'
param oncallMcpPath string = 'oncall-mcp'

// Dedicated workspace gateway (all workspaces are assigned to it)
param workspaceGatewayName string = 'workspace-gateway'
param workspaceGatewaySku string = 'WorkspaceGatewayPremium'

// ------------------
//    VARIABLES
// ------------------

var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)

// Models projected into each team Foundry's model-gateway connection metadata
var modelGatewayModels = [for model in modelsConfig: {
  name: model.name
  properties: {
    model: {
      name: model.name
      version: model.version
      format: model.publisher
    }
  }
}]

// ------------------
//    RESOURCES
// ------------------

// 1. Log Analytics Workspace
module lawModule '../../modules/operational-insights/v1/workspaces.bicep' = {
  name: 'lawModule'
}

// 2. Application Insights
module appInsightsModule '../../modules/monitor/v1/appinsights.bicep' = {
  name: 'appInsightsModule'
  params: {
    lawId: lawModule.outputs.id
    customMetricsOptedInType: 'WithDimensions'
  }
}

// 3. API Management (Standard v2 - required for workspaces)
module apimModule '../../modules/apim/v3/apim.bicep' = {
  name: 'apimModule'
  params: {
    apimSku: apimSku
    apimSubscriptionsConfig: apimSubscriptionsConfig
    lawId: lawModule.outputs.id
    appInsightsId: appInsightsModule.outputs.id
    appInsightsInstrumentationKey: appInsightsModule.outputs.instrumentationKey
  }
}

// 4. AI Foundry instances (inference + one per team). Models are deployed only to the
//    inference foundry (targeted via the "aiservice" field on each model in modelsConfig).
module foundryModule '../../modules/cognitive-services/v3/foundry.bicep' = {
  name: 'foundryModule'
  params: {
    aiServicesConfig: aiServicesConfig
    modelsConfig: modelsConfig
    apimPrincipalId: apimModule.outputs.principalId
    foundryProjectName: foundryProjectName
  }
}

// 5. Shared, service-level Inference API. Routes only to the inference foundry (index 0),
//    which is the only instance that hosts model deployments.
module inferenceAPIModule '../../modules/apim/v3/inference-api.bicep' = {
  name: 'inferenceAPIModule'
  params: {
    policyXml: loadTextContent('policy.xml')
    apimLoggerId: apimModule.outputs.loggerId
    aiServicesConfig: [foundryModule.outputs.extendedAIServicesConfig[0]]
    inferenceAPIType: inferenceAPIType
    inferenceAPIPath: inferenceAPIPath
  }
}

// 5b. Model Gateway connections on each team Foundry instance. Neither team foundry hosts
//     models locally; both reach the models through the shared APIM inference endpoint using
//     an ApiManagement connection. Agents reference the model as "{connection}/{model}".
resource weatherFoundryAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: 'weather-foundry-${resourceSuffix}'
}

resource oncallFoundryAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: 'oncall-foundry-${resourceSuffix}'
}

resource weatherModelGatewayConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  parent: weatherFoundryAccount
  name: modelGatewayConnectionName
  properties: {
    authType: 'ApiKey'
    category: 'ApiManagement'
    target: '${apimModule.outputs.gatewayUrl}/${inferenceAPIPath}/openai'
    isSharedToAll: true
    credentials: {
      key: apimModule.outputs.apimSubscriptions[0].key
    }
    metadata: {
      ApiType: 'Azure'
      inferenceAPIVersion: '2024-12-01-preview'
      Location: aiServicesConfig[0].location
      deploymentInPath: 'true'
      models: string(modelGatewayModels)
    }
  }
  dependsOn: [
    foundryModule
    inferenceAPIModule
  ]
}

resource oncallModelGatewayConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  parent: oncallFoundryAccount
  name: modelGatewayConnectionName
  properties: {
    authType: 'ApiKey'
    category: 'ApiManagement'
    target: '${apimModule.outputs.gatewayUrl}/${inferenceAPIPath}/openai'
    isSharedToAll: true
    credentials: {
      key: apimModule.outputs.apimSubscriptions[0].key
    }
    metadata: {
      ApiType: 'Azure'
      inferenceAPIVersion: '2024-12-01-preview'
      Location: aiServicesConfig[0].location
      deploymentInPath: 'true'
      models: string(modelGatewayModels)
    }
  }
  dependsOn: [
    foundryModule
    inferenceAPIModule
  ]
}

// 6. Container platform + skeleton backend APIs (Weather & OnCall) on Azure Container Apps
module acaModule 'src/aca.bicep' = {
  name: 'acaModule'
  params: {
    lawCustomerId: lawModule.outputs.customerId
    lawSharedKey: lawModule.outputs.primarySharedKey
  }
}

// 7a. Weather workspace + team-owned Weather API
module weatherWorkspaceModule 'src/workspace-tool.bicep' = {
  name: 'weatherWorkspaceModule'
  params: {
    apimServiceName: apimModule.outputs.name
    workspaceName: weatherWorkspaceName
    workspaceDisplayName: weatherWorkspaceDisplayName
    workspaceDescription: 'Workspace owned by the Weather API team.'
    apiName: 'weather-api'
    apiDisplayName: 'Weather API'
    apiDescription: 'Team-owned Weather API managed in the Weather workspace.'
    apiPath: weatherApiPath
    openApiJson: loadTextContent('src/weather/openapi.json')
    apiPolicyXml: replace(loadTextContent('src/weather/api-policy.xml'), '{backend-url}', acaModule.outputs.weatherAppUrl)
  }
  dependsOn: [
    inferenceAPIModule
  ]
}

// 7b. OnCall workspace + team-owned OnCall API
module oncallWorkspaceModule 'src/workspace-tool.bicep' = {
  name: 'oncallWorkspaceModule'
  params: {
    apimServiceName: apimModule.outputs.name
    workspaceName: oncallWorkspaceName
    workspaceDisplayName: oncallWorkspaceDisplayName
    workspaceDescription: 'Workspace owned by the OnCall API team.'
    apiName: 'oncall-api'
    apiDisplayName: 'OnCall API'
    apiDescription: 'Team-owned OnCall API managed in the OnCall workspace.'
    apiPath: oncallApiPath
    openApiJson: loadTextContent('src/oncall/openapi.json')
    apiPolicyXml: replace(loadTextContent('src/oncall/api-policy.xml'), '{backend-url}', acaModule.outputs.oncallAppUrl)
  }
  dependsOn: [
    inferenceAPIModule
  ]
}

// 8. Dedicated workspace gateway - all workspaces are assigned to it.
//    Each workspace API is served on the gateway hostname exposed via the config connection.
module workspaceGatewayModule 'src/workspace-gateway.bicep' = {
  name: 'workspaceGatewayModule'
  params: {
    gatewayName: workspaceGatewayName
    gatewaySku: workspaceGatewaySku
    workspaces: [
      {
        name: '${weatherWorkspaceName}-connection'
        workspaceId: weatherWorkspaceModule.outputs.workspaceId
      }
      {
        name: '${oncallWorkspaceName}-connection'
        workspaceId: oncallWorkspaceModule.outputs.workspaceId
      }
    ]
  }
}

// 9a. Weather MCP server (service level) -> proxies to the Weather workspace API on the workspace gateway
module weatherMcpModule 'src/service-mcp.bicep' = {
  name: 'weatherMcpModule'
  params: {
    apimServiceName: apimModule.outputs.name
    toolApiName: 'weather-tool-api'
    toolApiDisplayName: 'Weather Tool (proxy)'
    toolApiDescription: 'Service-level proxy to the Weather workspace API.'
    toolApiPath: weatherToolApiPath
    toolOpenApiJson: loadTextContent('src/weather/openapi.json')
    proxyPolicyXml: replace(loadTextContent('src/weather/proxy-policy.xml'), '{backend-url}', 'https://${workspaceGatewayModule.outputs.connections[0].defaultHostname}/${weatherApiPath}')
    operationName: 'get-weather'
    mcpName: 'weather-mcp'
    mcpDisplayName: 'Weather MCP'
    mcpDescription: 'Get the current weather for a city.'
    mcpPath: weatherMcpPath
    mcpPolicyXml: loadTextContent('src/weather/mcp-policy.xml')
  }
}

// 9b. OnCall MCP server (service level) -> proxies to the OnCall workspace API on the workspace gateway
module oncallMcpModule 'src/service-mcp.bicep' = {
  name: 'oncallMcpModule'
  params: {
    apimServiceName: apimModule.outputs.name
    toolApiName: 'oncall-tool-api'
    toolApiDisplayName: 'OnCall Tool (proxy)'
    toolApiDescription: 'Service-level proxy to the OnCall workspace API.'
    toolApiPath: oncallToolApiPath
    toolOpenApiJson: loadTextContent('src/oncall/openapi.json')
    proxyPolicyXml: replace(loadTextContent('src/oncall/proxy-policy.xml'), '{backend-url}', 'https://${workspaceGatewayModule.outputs.connections[1].defaultHostname}/${oncallApiPath}')
    operationName: 'get-oncall'
    mcpName: 'oncall-mcp'
    mcpDisplayName: 'OnCall MCP'
    mcpDescription: 'Get the current on-call engineer for a team.'
    mcpPath: oncallMcpPath
    mcpPolicyXml: loadTextContent('src/oncall/mcp-policy.xml')
  }
}

// ------------------
//    OUTPUTS
// ------------------

output logAnalyticsWorkspaceId string = lawModule.outputs.customerId
output apimServiceId string = apimModule.outputs.id
output apimServiceName string = apimModule.outputs.name
output apimResourceGatewayURL string = apimModule.outputs.gatewayUrl
output apimSubscriptions array = apimModule.outputs.apimSubscriptions

// Foundry instances: inference (hosts models) + one per team (model gateway consumers)
output inferenceFoundryProjectEndpoint string = foundryModule.outputs.extendedAIServicesConfig[0].foundryProjectEndpoint
output weatherFoundryProjectEndpoint string = foundryModule.outputs.extendedAIServicesConfig[1].foundryProjectEndpoint
output oncallFoundryProjectEndpoint string = foundryModule.outputs.extendedAIServicesConfig[2].foundryProjectEndpoint
output modelGatewayConnectionName string = modelGatewayConnectionName

output weatherWorkspaceName string = weatherWorkspaceModule.outputs.workspaceName
output oncallWorkspaceName string = oncallWorkspaceModule.outputs.workspaceName
output weatherApiPath string = weatherApiPath
output oncallApiPath string = oncallApiPath
output weatherMcpEndpoint string = '${apimModule.outputs.gatewayUrl}/${weatherMcpPath}/mcp'
output oncallMcpEndpoint string = '${apimModule.outputs.gatewayUrl}/${oncallMcpPath}/mcp'

output containerRegistryName string = acaModule.outputs.containerRegistryName
output weatherAppName string = acaModule.outputs.weatherAppName
output oncallAppName string = acaModule.outputs.oncallAppName
output weatherAppUrl string = acaModule.outputs.weatherAppUrl
output oncallAppUrl string = acaModule.outputs.oncallAppUrl

output workspaceGatewayName string = workspaceGatewayModule.outputs.gatewayName
output workspaceGatewayId string = workspaceGatewayModule.outputs.gatewayId
output workspaceGatewayUrl string = 'https://${workspaceGatewayModule.outputs.connections[0].defaultHostname}'
