// ------------------------------------------------------------------
//  workspace-tool.bicep
//  Creates an APIM workspace and a workspace-scoped REST API (a
//  team-owned "tool"). The workspace is later associated with the
//  service default managed gateway (serveOn = workspaceAndDefault)
//  from the notebook, so the API is served on the default hostname.
// ------------------------------------------------------------------

@description('The name of the API Management instance.')
param apimServiceName string

@description('The workspace resource name (must be unique across the service).')
param workspaceName string

@description('The workspace display name.')
param workspaceDisplayName string

@description('The workspace description.')
param workspaceDescription string = ''

@description('The workspace API resource name (must be unique across the service).')
param apiName string

@description('The workspace API display name.')
param apiDisplayName string

@description('The workspace API description.')
param apiDescription string = ''

@description('The workspace API path (URL suffix on the default gateway).')
param apiPath string

@description('The OpenAPI (openapi+json) document for the API, as a string.')
param openApiJson string

@description('The raw XML policy applied to the workspace API.')
param apiPolicyXml string

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimServiceName
}

resource workspace 'Microsoft.ApiManagement/service/workspaces@2024-06-01-preview' = {
  parent: apim
  name: workspaceName
  properties: {
    displayName: workspaceDisplayName
    description: workspaceDescription
  }
}

resource api 'Microsoft.ApiManagement/service/workspaces/apis@2024-06-01-preview' = {
  parent: workspace
  name: apiName
  properties: {
    type: 'http'
    displayName: apiDisplayName
    description: apiDescription
    path: apiPath
    protocols: [
      'https'
    ]
    subscriptionRequired: false
    format: 'openapi+json'
    value: openApiJson
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/workspaces/apis/policies@2024-06-01-preview' = {
  parent: api
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: apiPolicyXml
  }
}

// ------------------
//    OUTPUTS
// ------------------

output workspaceName string = workspace.name
output workspaceId string = workspace.id
output apiName string = api.name
output apiPath string = apiPath
