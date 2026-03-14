// ============================================================
//  Module: Service Bus
//  Creates: Namespace, Topic (oms-orders-topic),
//           Subscription (oms-d365-subscription),
//           Dead Letter Queue (auto-enabled on subscription)
// ============================================================

@description('Deployment environment')
param environment string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

// ── Computed names ────────────────────────────────────────────

var namespaceName = 'sb-oms-integration-${environment}'

// ── Service Bus Namespace ─────────────────────────────────────
//  SKU: Standard — required for Topics (Basic only has Queues).
//  TLS 1.2 enforced. Local auth retained for backward compat
//  but managed identity is the primary auth mechanism.

resource sbNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: namespaceName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    minimumTlsVersion: '1.2'
    disableLocalAuth: false
    zoneRedundant: environment == 'prod' ? true : false
  }
  tags: tags
}

// ── Topic: oms-orders-topic ────────────────────────────────────
//  enablePartitioning: true  — distributes load across 16 partitions
//                              for higher throughput
//  duplicateDetectionHistoryTimeWindow: PT10M — prevents duplicate
//  message delivery from Event Grid retry storms
//  defaultMessageTimeToLive: P14D — 14 day retention matches our
//                                   SLA requirements

resource sbTopic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  parent: sbNamespace
  name: 'oms-orders-topic'
  properties: {
    enablePartitioning: true
    requiresDuplicateDetection: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    defaultMessageTimeToLive: 'P14D'
    maxSizeInMegabytes: 1024
    enableBatchedOperations: true
    supportOrdering: false    // partitioned topics cannot guarantee ordering
  }
}

// ── Subscription: oms-d365-subscription ───────────────────────
//  maxDeliveryCount: 10 — after 10 failed attempts the message is
//                         automatically moved to the Dead Letter Queue
//  lockDuration: PT5M   — Function 1 has up to 5 minutes to complete
//                         processing before the lock expires
//  deadLetteringOnMessageExpiration: true — expired messages go to DLQ
//                                           rather than being silently dropped

resource sbSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: sbTopic
  name: 'oms-d365-subscription'
  properties: {
    maxDeliveryCount: 10
    lockDuration: 'PT5M'
    deadLetteringOnMessageExpiration: true
    enableBatchedOperations: true
    defaultMessageTimeToLive: 'P14D'
    requiresSession: false
  }
}

// ── DLQ Monitoring Subscription ───────────────────────────────
//  Separate subscription to monitor DLQ activity for alerting.
//  Operations team subscribes to this for remediation workflow.

resource dlqMonitorSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: sbTopic
  name: 'oms-dlq-monitor'
  properties: {
    maxDeliveryCount: 1
    lockDuration: 'PT1M'
    deadLetteringOnMessageExpiration: false
    defaultMessageTimeToLive: 'P7D'
    requiresSession: false
  }
}

// ── Outputs ────────────────────────────────────────────────────

@description('Service Bus namespace name')
output namespaceName string = sbNamespace.name

@description('Service Bus namespace resource ID')
output namespaceId string = sbNamespace.id

@description('OMS orders topic resource ID (used by Event Grid subscription)')
output topicId string = sbTopic.id

@description('D365 subscription name')
output subscriptionName string = sbSubscription.name

@description('Service Bus namespace hostname for Managed Identity connections')
output namespaceHostname string = '${sbNamespace.name}.servicebus.windows.net'
