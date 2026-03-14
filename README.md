# OMS to D365 Integration - Interactive Tutorial

## Overview

Comprehensive, production-grade interactive HTML tutorial for Azure Order Management System (OMS) to Dynamics 365 Finance & Operations integration via Azure Integration Services (AIS).

**File:** `index.html` (145 KB, 3,498 lines)  
**Format:** Single-page application (SPA) with client-side navigation

## Features

### ✅ All 13 Sections Implemented

1. **🏠 Overview** - Key highlights, big picture data flow, performance metrics
2. **🏛️ Architecture** - High-level and low-level design with detailed Mermaid diagrams
3. **🔀 Data Flow** - End-to-end sequence diagrams and state machines
4. **🧩 Design Decisions** - Component selection matrix with alternatives analysis
5. **⚡ Event Grid & Security** - CloudEvents payload, authentication methods, 4-hour cycle rationale
6. **📨 Service Bus & DLQ** - Configuration details, dead-letter handling, monitoring alerts
7. **⚡ Function App** - Ingestion & transformation functions with full C# code
8. **🔗 Logic App** - Visual workflow design and JSON definition with exception handling
9. **🌐 Cosmos DB** - Document schema, state machine, partition key strategy, TTL policy
10. **🏗️ IaC** - Complete Bicep modules and Terraform HCL for 3-environment deployment
11. **🔒 Security** - Defense-in-depth: network, identity, data encryption, secret management
12. **📊 Monitoring** - KQL queries, alerts, SLA/SLO targets, Application Insights dashboard
13. **🚀 Roadmap** - 5-phase evolution plan with durable functions, multi-region failover, chaos engineering


### 📁 Infrastructure as Code (IaC) Structure

- The tutorial includes complete IaC implementation with the following folder structure:

- infrastructure/
├── bicep/
│ ├── main.bicep # Main orchestrator module
│ ├── README.md # Bicep-specific documentation
│ ├── modules/
│ │ ├── appInsights.bicep # Application Insights + Log Analytics
│ │ ├── cosmosDb.bicep # Cosmos DB account, database, container
│ │ ├── eventGrid.bicep # Event Grid topic + subscription
│ │ ├── functionApp.bicep # Function App with consumption plan
│ │ ├── keyVault.bicep # Key Vault with RBAC model
│ │ ├── logicApp.bicep # Logic App Standard workflow
│ │ ├── serviceBus.bicep # Service Bus namespace, topic, subscription
│ │ └── storage.bicep # Storage account, containers, lifecycle
│ └── parameters/
│ ├── dev.bicepparam # Development environment values
│ ├── prod.bicepparam # Production environment (hardened)
│ └── uat.bicepparam # UAT environment (mirrors prod)
└── terraform/
├── main.tf # Main Terraform configuration
├── outputs.tf # Terraform outputs
└── variables.tf # Input variables

### 🎨 Rich Media & Interactive Elements

- **9 Mermaid diagrams** - System architecture, data flows, state machines, RBAC flows
- **26 code blocks** - Bicep, Terraform, C#, JSON, KQL, Bash with syntax highlighting
- **17 tab interfaces** - Design/Code tabs, IaC file switchers, environment parameters
- **28 copy buttons** - One-click code copying with visual feedback
- **Responsive sidebar** - Fixed navigation with collapsible sections
- **Back-to-top button** - Sticky button for quick navigation

### 📚 Typography & Styling

- **Google Fonts**: Inter (body), Fira Code (monospace)
- **Prism.js CDN** - Syntax highlighting for bicep, hcl, csharp, json, yaml, kusto, bash
- **Mermaid.js CDN** - Live diagram rendering
- **Azure color palette** - Primary blue (#0078d4), success green (#107c10), error red (#d83b01)
- **GitHub-inspired UI** - Clean, professional dark-on-light design

### 🔍 Content Highlights

#### Architecture Diagrams
- HLD with 6 layers (Event Capture → State Store → Transform → Stage → Deliver → D365)
- LLD with detailed SKU configurations and service specifics
- Full component relationships and data flow

#### Code Examples
- **C# Functions**: Complete OmsOrderIngestion and OmsTimerTransform implementations
- **Bicep IaC**: Modular main.bicep with servicebus.bicep, cosmosdb.bicep, etc.
- **Terraform**: HCL for Azure Service Bus, Cosmos DB, Storage, App Insights, Key Vault
- **KQL Queries**: 5 production-ready queries for ingestion rate, DLQ events, latency, errors
- **Logic App JSON**: Full workflow definition with recurrence, conditions, scope-based exception handling

#### Design Rationale
- Why Service Bus Standard (not Premium)
- Why Session consistency (not Strong) in Cosmos DB
- Why /orderId partition key (not /processingStatus)
- Why Managed Identity (not connection strings)
- Why Logic App Standard (not Cloud)

#### Security Architecture
- Managed Identity + RBAC for all services
- Key Vault with secret references
- Private endpoints and VNet integration
- Audit logging and compliance tracking

#### Monitoring & Operations
- Application Insights integration strategy
- KQL queries for success rate, latency, error analysis
- Azure Monitor alerts with severity levels
- SLA/SLO definitions (99.9% delivery, < 5h E2E latency)

#### Future Roadmap
- Phase 2: Durable Functions, multi-region Cosmos DB, circuit breaker
- Phase 3: Private endpoints everywhere, VNet isolation, Defender for Cloud
- Phase 4: Azure Monitor Workbooks, W3C TraceContext, Grafana integration
- Phase 5: GitHub Actions CI/CD, integration tests, chaos engineering

## How to Use

### Opening the File
1. Download `index.html`
2. Open in modern browser (Chrome, Edge, Firefox, Safari)
3. No server required; all content loads from CDNs

### Navigation
- **Left Sidebar**: Click section titles to jump to topics
- **Collapsible Sections**: Click section headers to expand/collapse
- **Tab Switching**: Switch between Design/Code, Bicep/Terraform, etc.
- **Copy Buttons**: Hover over code blocks to reveal copy button
- **Back to Top**: Click floating button in bottom-right

### Search Tips
- Use browser Ctrl+F (Cmd+F on Mac) to search content
- Search for function names, component names, KQL syntax

## Technology Stack

### Frontend Libraries
- **Prism.js v1.29.0** - Syntax highlighting (6 languages)
- **Mermaid.js v10.6.1** - Diagram rendering (flowchart, sequence, state)
- **Google Fonts** - Typography (Inter, Fira Code)

### Content Scope
- **13 sections** covering 4+ Azure services
- **26 code examples** across 6 languages
- **9 architecture diagrams** with detailed labels
- **50+ decision tables** comparing options
- **5 KQL queries** for production monitoring

## Key Takeaways

1. **Event-driven architecture** scales from 100 to 100M orders/year
2. **Service Bus DLQ** provides automatic failure handling + manual recovery
3. **Cosmos DB state machine** enables idempotent batch processing
4. **Managed Identity + RBAC** eliminates credential management overhead
5. **3-environment IaC** (Bicep/Terraform) enables repeatable deployments
6. **Application Insights KQL** provides deep operational visibility
7. **4-hour batch cycle** balances cost, latency, and D365 API limits

## File Information

| Property | Value |
|----------|-------|
| File Size | 145 KB |
| Lines of Code | 3,498 |
| Sections | 13 |
| Code Blocks | 26 |
| Diagrams | 9 |
| Tables | 50+ |
| CDN Libraries | 3 (Prism, Mermaid, Fonts) |
| Supported Browsers | Chrome, Edge, Firefox, Safari (ES6+) |

## Offline Usage

The HTML file is **fully self-contained** once loaded:
- All CSS/JS embedded or from CDN
- External libraries load on page open (requires internet)
- After initial load, works offline (diagrams pre-rendered)

For fully offline mode, download CDN files locally and update HTML src= references.

## Browser Compatibility

- ✅ Chrome/Edge (latest)
- ✅ Firefox (latest)
- ✅ Safari 14+
- ✅ Edge (Chromium-based)
- ❌ Internet Explorer (not supported)

## Performance

- **Initial Load**: ~2-3 seconds (CDN libraries)
- **Section Switch**: <100ms (instant visual feedback)
- **Code Copy**: <50ms (clipboard API)
- **Responsive**: Works on desktop, tablet, and mobile

## Author Notes

- **Target Audience**: Azure architects, integration engineers, DevOps teams
- **Prior Knowledge**: Basic Azure concepts (Functions, Cosmos DB, Service Bus)
- **Use Cases**: Architecture review, implementation guide, training material
- **Maintenance**: Update sections independently; self-contained HTML format
- **Extensibility**: Add more Mermaid diagrams, code examples, or sections as needed

---

**Created By**: MOHIT KAKKAR  
**Created**: March 2026  
**Format**: Single-page HTML with embedded styles and client-side JavaScript  
**License**: Internal use (customizable as needed)
