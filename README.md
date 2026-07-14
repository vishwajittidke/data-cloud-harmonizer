# Data Cloud Harmonizer & Identity Resolution Engine

![Salesforce](https://img.shields.io/badge/Salesforce-00A1E0?style=for-the-badge&logo=salesforce&logoColor=white)
![LWC](https://img.shields.io/badge/LWC-F26522?style=for-the-badge&logo=salesforce&logoColor=white)
![Apex](https://img.shields.io/badge/Apex-1798c1?style=for-the-badge)

A robust, enterprise-grade Salesforce application designed to simulate the core functionalities of Salesforce Data Cloud (CDP). This project demonstrates how to unify disparate data sources, perform complex identity resolution using fuzzy matching algorithms, and trigger real-time event-driven automation.

## 🚀 Key Features

*   **Identity Resolution Engine (Apex Batch)**
    *   Ingests mock data from diverse sources (Email Subscribers, POS Transactions).
    *   Utilizes the **Soundex algorithm** for fuzzy matching to resolve typos, spelling variations, and differing formats (e.g., "Kathryn Smyth" -> "Catherine Smith").
    *   Aggregates cross-platform metrics to calculate a unified **Total Lifetime Value (LTV)** and calculates a dynamic **Match Confidence Score**.
*   **Data Cloud Explorer (LWC)**
    *   A premium, custom-built Lightning Web Component dashboard acting as the central hub.
    *   Integrates **D3.js** to render visual Data Lineage graphs, mapping precisely how disparate source records merge into a single Unified Golden Record.
*   **Agentforce 360 Insights (Simulated AI)**
    *   Provides generative AI summaries of customer profiles based on their unified data, showcasing an understanding of AI integration patterns and seamless UX loading states.
*   **Event-Driven Automation**
    *   Leverages **Platform Events** (`High_Value_Unified__e`) to decouple data processing from automation logic.
    *   Automatically fires when a Golden Record's Lifetime Value crosses a $200 threshold, instantly triggering a Salesforce Flow to assign follow-up Tasks to account executives.
*   **Unified Profile REST API**
    *   A secure, bulkified custom Apex REST endpoint (`/v1/UnifiedProfile/`) allowing external systems to query Golden Records.
    *   Enforces strict Field-Level Security by executing `WITH USER_MODE`.

## 🏗️ Architecture & Enterprise Scalability Considerations

When transitioning this architecture into a massive, multi-million record production environment, several enterprise scalability considerations must be accounted for:

### 1. Asynchronous Processing & Batch Volumes
The Identity Resolution Engine currently runs via Batch Apex. In a true enterprise scenario processing tens of millions of rows, this should be scaled using **Bulk API 2.0** for data ingestion, followed by heavily chunked `Database.Batchable` or DataWeave in Apex (to handle faster transformations). 

### 2. Change Data Capture (CDC) vs. Nightly Batches
Currently, harmonization runs via a manual trigger (or scheduled batch). For real-time harmonization, **Change Data Capture (CDC)** should be enabled on the source objects (`POS_Transaction__c`, `Email_Subscriber__c`). A Platform Event trigger would catch these changes and push the specific records to an asynchronous queue (Queueable Apex) for near real-time fuzzy matching and unification, reducing the need for heavy nightly batch jobs.

### 3. API Authentication & Security
The custom REST API (`UnifiedProfileRESTAPI.cls`) currently relies on standard Salesforce Session IDs or OAuth for access. In an enterprise landscape (e.g., integrating with an external AWS gateway or MuleSoft), **Connected Apps with JWT Bearer Token flows** should be established. Furthermore, the API respects `WITH USER_MODE`, guaranteeing that the external integration user only retrieves data they explicitly have permission to see, preventing data leaks.

## 🛠️ Deployment Instructions

1. Deploy the source code to your org using Salesforce CLI:
   ```bash
   sf project deploy start --source-dir force-app
   ```
2. Assign the **Data Cloud Harmonizer** Permission Set to your user.
3. Open the **Data Cloud Explorer** app from the App Launcher.
4. Click **Inject Mock Data**, followed by **Run Harmonization** to see the engine in action!
