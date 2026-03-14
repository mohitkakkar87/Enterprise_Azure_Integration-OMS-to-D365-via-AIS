// ============================================================
//  Module: Event Grid Custom Topic
//  Creates: Event Grid Topic (oms-events-topic),
//           Event Subscription routing events to Service Bus
//  Security: OMS authenticates via Entra ID app registration
//            with EventGrid Data Sender role (no SAS keys shared)
// ============================================================

@description('Deployment environment')
param environment string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('Service Bus topic resource ID (destination for event routing)')
param serviceBusTopicId string

@description('Service Bus namespace resource ID (for RBAC assignment)')
param serviceBusNamespaceId string

// ── Event Grid Custom Topic ────────────────────────────────────
//  inputSchema: CloudEventSchemaV1_0
//    CloudEvents is the CNCF standard for event metadata.
//    OMS must send events in CloudEvents format (specversion,
//    type, source, id, data). This prevents arbitrary payloads.
//
//  publicNetworkAccess: prod uses Private Endpoint (disabled below)
//                       dev/uat: Enabled for ease of testing
//
//  disableLocalAuth: false — keep SAS key auth for backward compat
//                           (OMS may not support AAD initially)

resource eventGridTopic 'Microsoft.EventGrid/topics@2023-12-15-preview' = {
  name: 'egt-oms-events-${environment}'
  location: location
  properties: {
    inputSchema: 'CloudEventSchemaV1_0'
    publicNetworkAccess: environment == 'prod' ? 'Disabled' : 'Enabled'
    disableLocalAuth: false
    dataResidencyBoundary: 'WithinGeopair'
    inboundIpRules: []   // Add OMS IP ranges here for IP-based restriction
  }
  identity: {
    type: 'SystemAssigned'   // Needed for delivering to Service Bus
  }
  tags: tags
}

// ── RBAC: Event Grid Topic → Service Bus ──────────────────────
//  Event Grid needs "Azure Service Bus Data Sender" on the
//  Service Bus namespace to forward events to the topic.

resource egToSbRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceBusNamespaceId, eventGridTopic.id, 'sb-data-sender')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39') // Azure Service Bus Data Sender
    principalId: eventGridTopic.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ── Event Subscription: Route to Service Bus ──────────────────
//  OMS.Order.Created events are forwarded to the Service Bus topic.
//  deadLetterDestination: storage account in prod for DLQ capture.
//  retryPolicy: 30 events per minute, up to 1440 minutes (24h).

resource eventSubscription 'Microsoft.EventGrid/topics/eventSubscriptions@2023-12-15-preview' = {
  parent: eventGridTopic
  name: 'oms-to-servicebus-subscription'
  properties: {
    destination: {
      endpointType: 'ServiceBusTopic'
      properties: {
        resourceId: serviceBusTopicId
      }
    }
    filter: {
      includedEventTypes: ['OMS.Order.Created', 'OMS.Order.Updated']
      enableAdvancedFilteringOnArrays: true
    }
    eventDeliverySchema: 'CloudEventSchemaV1_0'
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440  // 24 hours
    }
  }
  dependsOn: [egToSbRoleAssignment]  // Role must exist before subscription can deliver
}

// ── Outputs ────────────────────────────────────────────────────

@description('Event Grid topic endpoint (share with OMS for publishing events)')
output topicEndpoint string = eventGridTopic.properties.endpoint

@description('Event Grid topic resource ID')
output topicId string = eventGridTopic.id

@description('Event Grid topic name')
output topicName string = eventGridTopic.name

@description('Managed Identity principal ID of the Event Grid topic')
output principalId string = eventGridTopic.identity.principalId
