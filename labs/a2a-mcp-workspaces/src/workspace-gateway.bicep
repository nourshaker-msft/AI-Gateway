// ------------------------------------------------------------------
//  workspace-gateway.bicep
//  Deploys a dedicated API Management workspace gateway and links
//  (assigns) one or more workspaces to it via config connections.
//
//  The workspace gateway is a standalone resource
//  (Microsoft.ApiManagement/gateways) that hosts the runtime for the
//  APIs owned by the linked workspaces.
// ------------------------------------------------------------------

@description('The name of the workspace gateway resource.')
param gatewayName string

@description('The location of the workspace gateway.')
param location string = resourceGroup().location

@description('The SKU of the workspace gateway.')
@allowed([
  'WorkspaceGatewayStandard'
  'WorkspaceGatewayPremium'
])
param gatewaySku string = 'WorkspaceGatewayStandard'

@description('The number of deployed units of the gateway SKU.')
param gatewayCapacity int = 1

@description('Workspaces to assign to the gateway. Each item: { name: <config connection name>, workspaceId: <workspace resource id> }.')
param workspaces array

resource gateway 'Microsoft.ApiManagement/gateways@2024-06-01-preview' = {
  name: gatewayName
  location: location
  sku: {
    name: gatewaySku
    capacity: gatewayCapacity
  }
  properties: {
    backend: {}
    frontend: {}
  }
}

resource configConnections 'Microsoft.ApiManagement/gateways/configConnections@2024-06-01-preview' = [
  for ws in workspaces: {
    parent: gateway
    name: ws.name
    properties: {
      sourceId: ws.workspaceId
    }
  }
]

// ------------------
//    OUTPUTS
// ------------------

output gatewayName string = gateway.name
output gatewayId string = gateway.id

@description('Per-workspace connection info, including the workspace gateway hostname that serves each workspace\'s APIs. Order matches the "workspaces" input.')
output connections array = [
  for (ws, i) in workspaces: {
    name: ws.name
    workspaceId: ws.workspaceId
    defaultHostname: configConnections[i].properties.defaultHostname
  }
]
