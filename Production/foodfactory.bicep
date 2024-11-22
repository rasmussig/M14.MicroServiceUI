@description('Name for the container group')
param name string = 'catalog-service'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Container image to deploy. Should be of the form repoName/imagename:tag for images stored in public Docker Hub, or a fully qualified URI for other registries. Images from private registries require additional registry credentials.')
param catalogimage string = 'index.docker.io/rasmussig/microservice-ui:latest'

@description('URL of the image registry')
param imageRegistryURL string = 'index.docker.io'

@description('Registry credentials: username')
param imageRegistryUserName string = 'rasmussig'

@description('Registry credentials: password or access token')
param imageRegistryAccessToken string = 'dckr_pat_pEk5HBCeiOUNRWoVIbwJyz4a_VY'

@description('Port to open on the container and the public IP address.')
param port int = 8080

@description('The number of CPU cores to allocate to the container.')
param cpuCores int = 1

@description('The amount of memory to allocate to the container in gigabytes.')
param memoryInGb int = 2

@description('The behavior of Azure runtime if container has stopped.')
@allowed([
  'Always'
  'Never'
  'OnFailure'
])
param restartPolicy string = 'Always'

@description('Specifies the name of the Azure Storage account.')
param storageAccountName string = 'storage${uniqueString(resourceGroup().id)}'

@description('Specifies the prefix of the file share names.')
param sharePrefix string = 'storage'

@description('Name of the virtual network resource')
param virtualNetworkName string = 'foodVNet'

// 
// Hard coded variables:
//
@description('List of file shares to create')
var shareNames = [
  'dbdata'
  'images'
]

var publicDomainName = 'foodcatalog${uniqueString(resourceGroup().id)}'
var publicIPAddressName = 'foodcatalog-public_ip'
var virtualNetworkPrefix = '10.0.0.0/16'
var gwSubnetPrefix = '10.0.0.0/24'
var backendSubnetPrefix = '10.0.1.0/24'
var subnetName = 'foodBackendSubnet'

//==========================================================================
// Setup storage ressourcer
//==========================================================================

//--- Opret storage konto til volumener ---
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
  }
}

//-- Opret et share i storage account til MongoDB data og Image upload data
resource service 'Microsoft.Storage/storageAccounts/fileServices@2021-02-01' = {
  parent: storageAccount
  name: 'default'
}

resource fileshare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-02-01' = [for share in shareNames : {
  parent: service
  name: '${sharePrefix}${share}'
}]

//==========================================================================
// Setup netværks resourcer
//==========================================================================

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2021-05-01' =  {
  name: publicIPAddressName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    dnsSettings: {
      domainNameLabel: publicDomainName
    }
  }
  /* TODO: Add DNS Name*/
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkPrefix
      ]
    }
    subnets: [
      {
        name: 'applicationGatewaySubnet'
        properties: {
          addressPrefix: gwSubnetPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'foodBackendSubnet'
        properties: {
          addressPrefix: backendSubnetPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          delegations: [
            {
              name: 'containerGroup'
              properties: {
                serviceName: 'Microsoft.ContainerInstance/containerGroups'
              }
            }
          ]
        }
      }
    ]
    enableDdosProtection: false
  }
}

//==========================================================================
// Setup container resourcer
//==========================================================================

resource VNET 'Microsoft.Network/virtualNetworks@2020-11-01' existing = {
  name: virtualNetworkName
  resource subnet 'subnets@2022-01-01' existing = {
    name: subnetName
  }
}

// Opret en container med MongoDB

resource mongodbContainerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: 'mongodb-container'
  location: location
  properties: {
    containers: [
      {
        name: 'mongodb'
        properties: {
          image: 'index.docker.io/mongo:latest'
          command: [
            'mongod'
            '--dbpath=/data/mongodb'
            '--bind_ip_all'
            '--auth'
          ]
          ports: [
            {
              protocol: 'TCP'
              port: 27017
            }
          ]
          environmentVariables: [
          ]
          resources: {
            requests: {
              memoryInGB: json('1.0')
              cpu: json('0.5')
            }
          }
          volumeMounts: [
            {
              name: 'db'
              mountPath: '/data/mongodb'
            }
          ]
        }
      }
    ]
    osType: 'Linux'
    volumes: [
      {
        name: 'db'
        azureFile: {
          shareName: 'storagedbdata'
          storageAccountName: storageAccount.name
          storageAccountKey: storageAccount.listKeys().keys[0].value
        }
      }
    ]
    restartPolicy: restartPolicy
    ipAddress: {
      type: 'Private'
      ip: '10.0.1.5'
      ports: [
        {
          port: 27017
          protocol: 'TCP'          
        }
      ]
    }
    imageRegistryCredentials: [
      {
        server: imageRegistryURL
        username: imageRegistryUserName
        password: imageRegistryAccessToken
      }
    ]
    subnetIds: [
      {
        id: VNET::subnet.id
      }
    ]
  }
}

resource catalogsvcContainerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: name
  location: location
  properties: {
    containers: [
      {
        name: name
        properties: {
          image: catalogimage
          environmentVariables: [
            {
              name: 'CatalogImagePath'
              value: '/srv/resources/images'
            }
            {
              name: 'MongoConnectionString'
              value: 'mongodb://catalogUser:catalog12E4@10.0.1.5:27017/?authSource=admin'
            }
            {
              name: 'CatalogDatabase'
              value: 'catalog'
            }
            {
              name: 'CatalogCollection'
              value: 'products'
            }
          ]
          ports: [
            {
              port: port
              protocol: 'TCP'
            }
          ]
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGb
            }
          }
          volumeMounts: [
            {
              name: 'images'
              mountPath: '/srv/resources/images'
            }
          ]
        }
      }
    ]
    osType: 'Linux'
    volumes: [
      {
        name: 'images'
        azureFile: {
          shareName: 'storageimages'
          storageAccountName: storageAccount.name
          storageAccountKey: storageAccount.listKeys().keys[0].value
        }
      }
    ]
    restartPolicy: restartPolicy
    ipAddress: {
      type: 'Private'
      ip: '10.0.1.4'
      ports: [
        {
          port: port
          protocol: 'TCP'
        }
      ]
    }
    imageRegistryCredentials: [
      {
        server: imageRegistryURL
        username: imageRegistryUserName
        password: imageRegistryAccessToken
      }
    ]
    subnetIds: [
      {
        id: VNET::subnet.id
      }
    ]
  }
}

//==========================================================================
// Setup application gateway  
//==========================================================================

var applicationGateWayName = 'foodApplicationGateway'

resource applicationGateWay 'Microsoft.Network/applicationGateways@2022-11-01' = {
  name: applicationGateWayName
  location: location
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, 'applicationGatewaySubnet')
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: resourceId('Microsoft.Network/publicIPAddresses', publicIPAddressName)
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'CatalogSvcFrontPort'
        properties: {
          port: 4000
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'CatalogSvcBackendPool' 
        properties: {
          backendAddresses: [
            {
              ipAddress:  catalogsvcContainerGroup.properties.ipAddress.ip
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'CatalogSvcHttpSettings'
        properties: {
          port: 8080
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          connectionDraining: {
            enabled: false
            drainTimeoutInSec: 1
          }
          pickHostNameFromBackendAddress: false
          requestTimeout: 30
        }
      }
    ]
    httpListeners: [
      {
        name: 'CatalogSvcHttpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGateWayName, 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGateWayName, 'CatalogSvcFrontPort')
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'CatalogSvcRule'
        properties: {
          ruleType: 'Basic'
          priority: 12000
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGateWayName, 'CatalogSvcHttpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGateWayName, 'CatalogSvcBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGateWayName, 'CatalogSvcHttpSettings')
          }
        }
      }
    ]
    enableHttp2: false
    autoscaleConfiguration: {
      minCapacity: 0
      maxCapacity: 10
    }
  }
}

output containerIPv4Address string = catalogsvcContainerGroup.properties.ipAddress.ip
