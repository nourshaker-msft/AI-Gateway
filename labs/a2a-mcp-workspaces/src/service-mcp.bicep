// ------------------------------------------------------------------
//  service-mcp.bicep
//  Creates a service-level proxy API that forwards to a workspace API
//  (served on the default gateway), and exposes it as an MCP server.
//  MCP servers are not supported inside workspaces, so they live at the
//  service level and route to the workspace-owned API.
// ------------------------------------------------------------------

@description('The name of the API Management instance.')
param apimServiceName string

@description('The service-level proxy API resource name.')
param toolApiName string

@description('The service-level proxy API display name.')
param toolApiDisplayName string

@description('The service-level proxy API description.')
param toolApiDescription string = ''

@description('The service-level proxy API path (URL suffix on the default gateway).')
param toolApiPath string

@description('The OpenAPI (openapi+json) document for the proxy API, as a string.')
param toolOpenApiJson string

@description('The raw XML policy applied to the proxy API (backend URL already substituted).')
param proxyPolicyXml string

@description('The operationId (from the OpenAPI document) exposed as an MCP tool.')
param operationName string

@description('The MCP server API resource name.')
param mcpName string

@description('The MCP server display name.')
param mcpDisplayName string

@description('The MCP server description (also used as the tool description).')
param mcpDescription string = ''

@description('The MCP server path. The streamable endpoint is served at <gateway>/<mcpPath>/mcp.')
param mcpPath string

@description('The raw XML policy applied to the MCP server API.')
param mcpPolicyXml string

@description('The name of the Application Insights logger to use for MCP diagnostics.')
param appInsightsLoggerName string = 'appinsights-logger'

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}

// Service-level proxy API that forwards to the workspace-owned API.
resource toolApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: toolApiName
  properties: {
    type: 'http'
    displayName: toolApiDisplayName
    description: toolApiDescription
    path: toolApiPath
    protocols: [
      'https'
    ]
    subscriptionRequired: false
    format: 'openapi+json'
    value: toolOpenApiJson
  }
}

resource toolApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: toolApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: proxyPolicyXml
  }
}

resource operation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' existing = {
  parent: toolApi
  name: operationName
}

// MCP server (service level) that exposes the proxy API operation as a tool.
resource mcp 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: mcpName
  properties: {
    type: 'mcp'
    displayName: mcpDisplayName
    description: mcpDescription
    subscriptionRequired: false
    path: mcpPath
    protocols: [
      'https'
    ]
    mcpTools: [
      {
        name: operation.name
        operationId: operation.id
        description: mcpDescription
      }
    ]
  }
  dependsOn: [
    toolApiPolicy
  ]
}

resource mcpPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: mcp
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: mcpPolicyXml
  }
}

resource mcpDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2024-06-01-preview' = {
  parent: mcp
  name: 'applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: resourceId(resourceGroup().name, 'Microsoft.ApiManagement/service/loggers', apimServiceName, appInsightsLoggerName)
    metrics: true
    verbosity: 'verbose'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
  }
}

// ------------------
//    OUTPUTS
// ------------------

output mcpName string = mcp.name
output mcpPath string = mcpPath
