// ------------------------------------------------------------------
//  aca.bicep
//  Deploys the container platform (Azure Container Registry + a
//  Container Apps environment) and the two skeleton backend APIs
//  (Weather and OnCall) as Azure Container Apps.
//
//  The container apps are created with a placeholder image so their
//  ingress FQDNs are available for the workspace APIs to target. The
//  real application images are built from src/<tool>/app and pushed
//  from the notebook, then the container apps are updated.
// ------------------------------------------------------------------

@description('Location for all container resources.')
param location string = resourceGroup().location

@description('Suffix used to build globally-unique resource names.')
param resourceSuffix string = uniqueString(subscription().id, resourceGroup().id)

@description('Log Analytics workspace customer (workspace) id for container app logs.')
param lawCustomerId string

@description('Log Analytics workspace primary shared key for container app logs.')
@secure()
param lawSharedKey string

@description('The container port exposed by the backend apps.')
param targetPort int = 8080

// Placeholder image used only until the real images are built and pushed.
var placeholderImage = 'docker.io/jfxs/hello-world:latest'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  #disable-next-line BCP334 // resourceSuffix (uniqueString) is always 13 chars, so the name is never too short
  name: 'acr${resourceSuffix}'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    anonymousPullEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

resource containerAppEnv 'Microsoft.App/managedEnvironments@2023-11-02-preview' = {
  name: 'aca-env-${resourceSuffix}'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: lawCustomerId
        sharedKey: lawSharedKey
      }
    }
  }
}

resource containerAppUAI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'aca-mi-${resourceSuffix}'
  location: location
}

var acrPullRole = resourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

@description('Allow the container apps managed identity to pull images from the registry.')
resource containerAppUAIRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, containerAppUAI.id, acrPullRole)
  properties: {
    roleDefinitionId: acrPullRole
    principalId: containerAppUAI.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource weatherApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: 'aca-weather-${resourceSuffix}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${containerAppUAI.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: targetPort
        allowInsecure: false
      }
      registries: [
        {
          identity: containerAppUAI.id
          server: containerRegistry.properties.loginServer
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'weather'
          image: placeholderImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 2
      }
    }
  }
}

resource oncallApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: 'aca-oncall-${resourceSuffix}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${containerAppUAI.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: targetPort
        allowInsecure: false
      }
      registries: [
        {
          identity: containerAppUAI.id
          server: containerRegistry.properties.loginServer
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'oncall'
          image: placeholderImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 2
      }
    }
  }
}

// ------------------
//    OUTPUTS
// ------------------

output containerRegistryName string = containerRegistry.name
output weatherAppName string = weatherApp.name
output oncallAppName string = oncallApp.name
output weatherAppUrl string = 'https://${weatherApp.properties.configuration.ingress.fqdn}'
output oncallAppUrl string = 'https://${oncallApp.properties.configuration.ingress.fqdn}'
