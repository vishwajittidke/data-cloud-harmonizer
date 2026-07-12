# 🌩️ Salesforce Data Cloud: Identity Resolution Engine

## Overview
This repository contains a fully interactive, custom-built simulation of the **Salesforce Data Cloud Identity Resolution Engine**. 

Because standard Developer Edition orgs do not have Data Cloud provisioned, this project was architected from scratch using **Apex, SOQL, and Lightning Web Components (LWC)** to prove a fundamental, code-level understanding of how Data Cloud ingests, harmonizes, and unifies fragmented customer data silos into a **Customer 360 Golden Record**.

## 🚀 The Architecture
The simulation features three core Data Model Objects (Custom Objects):
1. `POS_Transaction__c`: Represents a messy, disconnected **Physical Retail / In-Store** system (contains phone numbers and spend, but no email).
2. `Email_Subscriber__c`: Represents a disconnected **Marketing Automation** silo (contains names and emails, but no phone).
3. `Unified_Individual__c`: Represents the Data Cloud **Golden Record**.

## ⚙️ The Harmonization Engine (Apex)
The core logic lives in `IdentityResolutionEngine.cls`. This class acts as the Data Cloud processing engine:
* **Fuzzy Matching:** Automatically normalizes disparate string inputs to find identity overlaps.
* **Identity Stitching:** Intelligently merges the digital marketing data (Email) with the physical retail data (Phone, Spend).
* **Golden Record Generation:** Upserts a unified `Unified_Individual__c` record that acts as the single source of truth for the enterprise.

## 💻 Interactive LWC Dashboard
The project includes a completely self-contained, interactive Lightning Web Component (`dataCloudExplorer`).
* **Dynamic Injection:** Click a button to simulate a live data feed of messy records flooding into the fragmented silos.
* **Real-time Resolution:** Click "Run Harmonization" to watch the Apex engine instantly resolve the identities and render the stitched Customer 360 profiles in real-time.
* **State Management:** Fully dynamic UI leveraging `@track` and `@wire` for instant updates without page refreshes.

## 🛠 Tech Stack
* **Salesforce Apex** (Harmonization algorithms)
* **SOQL / DML** (Database aggregation)
* **Lightning Web Components** (Frontend visualization)
* **Salesforce Lightning Design System (SLDS)** (Enterprise UX/UI)
