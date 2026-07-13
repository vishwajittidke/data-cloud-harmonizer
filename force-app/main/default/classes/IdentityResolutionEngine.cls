/**
 * IdentityResolutionEngine
 * @description Engine for asynchronously bulkifying and harmonizing Email and POS records into Unified Individuals.
 */
public with sharing class IdentityResolutionEngine implements Database.Batchable<sObject> {
    
    private String objectToProcess;

    /**
     * @description Default constructor defaulting to Subscriber processing.
     */
    public IdentityResolutionEngine() {
        this.objectToProcess = 'Subscriber';
    }

    /**
     * @description Constructor for specifying object type.
     * @param objType The object to process ('Subscriber' or 'POS')
     */
    public IdentityResolutionEngine(String objType) {
        this.objectToProcess = objType;
    }

    /**
     * @description Entry point for the Aura/LWC UI to begin harmonization.
     */
    @AuraEnabled
    public static void runHarmonizationAura() {
        try {
            Database.executeBatch(new IdentityResolutionEngine('Subscriber'), 200);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Polls whether a harmonization batch is still processing.
     * @return Boolean true if running.
     */
    @AuraEnabled
    public static Boolean isBatchRunning() {
        try {
            Integer activeJobs = [
                SELECT COUNT() FROM AsyncApexJob 
                WHERE JobType = 'BatchApex' 
                AND Status IN ('Holding', 'Queued', 'Preparing', 'Processing') 
                AND ApexClass.Name = 'IdentityResolutionEngine'
                WITH USER_MODE
            ];
            return activeJobs > 0;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @description Fetches raw and unified lists for dashboard rendering.
     * @return Map of string keys to sobject lists.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> fetchDashboardData() {
        try {
            Map<String, Object> result = new Map<String, Object>();
            result.put('subscribers', [SELECT Id, Full_Name__c, Email_Address__c, Unified_Individual__c FROM Email_Subscriber__c WITH USER_MODE ORDER BY Full_Name__c LIMIT 1000]);
            result.put('pos', [SELECT Id, Customer_Name__c, Phone_Number__c, Total_Spent__c, Unified_Individual__c FROM POS_Transaction__c WITH USER_MODE ORDER BY Customer_Name__c LIMIT 1000]);
            result.put('unified', [SELECT Id, First_Name__c, Primary_Email__c, Primary_Phone__c, Total_Lifetime_Value__c FROM Unified_Individual__c WITH USER_MODE ORDER BY First_Name__c LIMIT 1000]);
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Fetches Node and Link data for the D3.js Lineage Graph
     * @param goldenRecordId The ID of the Unified Individual
     * @return Map of nodes and links
     */
    @AuraEnabled
    public static Map<String, Object> getLineageData(Id goldenRecordId) {
        try {
            Map<String, Object> response = new Map<String, Object>();
            List<Map<String, Object>> nodes = new List<Map<String, Object>>();
            List<Map<String, Object>> links = new List<Map<String, Object>>();
            
            Unified_Individual__c golden = [SELECT Id, First_Name__c, Match_Key__c FROM Unified_Individual__c WHERE Id = :goldenRecordId WITH USER_MODE LIMIT 1];
            
            // Add Golden Record Node (Center)
            nodes.add(new Map<String, Object>{ 'id' => golden.Id, 'group' => 1, 'label' => 'Golden: ' + golden.First_Name__c });
            
            // Add Subscribers
            for (Email_Subscriber__c sub : [SELECT Id, Full_Name__c FROM Email_Subscriber__c WHERE Unified_Individual__c = :goldenRecordId WITH USER_MODE]) {
                nodes.add(new Map<String, Object>{ 'id' => sub.Id, 'group' => 2, 'label' => 'Email: ' + sub.Full_Name__c });
                links.add(new Map<String, Object>{ 'source' => sub.Id, 'target' => golden.Id, 'value' => 1 });
            }
            
            // Add POS
            for (POS_Transaction__c pos : [SELECT Id, Customer_Name__c FROM POS_Transaction__c WHERE Unified_Individual__c = :goldenRecordId WITH USER_MODE]) {
                nodes.add(new Map<String, Object>{ 'id' => pos.Id, 'group' => 3, 'label' => 'POS: ' + pos.Customer_Name__c });
                links.add(new Map<String, Object>{ 'source' => pos.Id, 'target' => golden.Id, 'value' => 1 });
            }
            
            response.put('nodes', nodes);
            response.put('links', links);
            return response;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Fetches all unlinked raw records for the Resolution Queue
     */
    @AuraEnabled
    public static Map<String, Object> getResolutionQueue() {
        try {
            Map<String, Object> queue = new Map<String, Object>();
            queue.put('unlinkedSubscribers', [SELECT Id, Full_Name__c, Email_Address__c FROM Email_Subscriber__c WHERE Unified_Individual__c = null WITH USER_MODE LIMIT 500]);
            queue.put('unlinkedPOS', [SELECT Id, Customer_Name__c, Phone_Number__c, Total_Spent__c FROM POS_Transaction__c WHERE Unified_Individual__c = null WITH USER_MODE LIMIT 500]);
            return queue;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Manually links a raw record to a Golden Record
     */
    @AuraEnabled
    public static void manualMerge(Id sourceId, String objectType, Id goldenId) {
        try {
            if (objectType == 'Subscriber') {
                Email_Subscriber__c sub = new Email_Subscriber__c(Id = sourceId, Unified_Individual__c = goldenId, Is_Processed__c = true);
                update as user sub;
            } else if (objectType == 'POS') {
                POS_Transaction__c pos = new POS_Transaction__c(Id = sourceId, Unified_Individual__c = goldenId, Is_Processed__c = true);
                update as user pos;
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Manually unlinks a raw record from its Golden Record
     */
    @AuraEnabled
    public static void manualUnmerge(Id sourceId, String objectType) {
        try {
            if (objectType == 'Subscriber') {
                Email_Subscriber__c sub = new Email_Subscriber__c(Id = sourceId, Unified_Individual__c = null, Is_Processed__c = false);
                update as user sub;
            } else if (objectType == 'POS') {
                POS_Transaction__c pos = new POS_Transaction__c(Id = sourceId, Unified_Individual__c = null, Is_Processed__c = false);
                update as user pos;
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Resets the demo data by clearing objects.
     */
    @AuraEnabled
    public static void resetDemo() {
        try {
            delete as user [SELECT Id FROM Email_Subscriber__c LIMIT 10000];
            delete as user [SELECT Id FROM POS_Transaction__c LIMIT 10000];
            delete as user [SELECT Id FROM Unified_Individual__c LIMIT 10000];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Injects fresh demo data.
     */
    @AuraEnabled
    public static void injectMockData() {
        List<Email_Subscriber__c> subsOld = [SELECT Id FROM Email_Subscriber__c LIMIT 10000];
        if (!subsOld.isEmpty()) {
            delete subsOld;
            Database.emptyRecycleBin(subsOld);
        }

        List<POS_Transaction__c> txnsOld = [SELECT Id FROM POS_Transaction__c LIMIT 10000];
        if (!txnsOld.isEmpty()) {
            delete txnsOld;
            Database.emptyRecycleBin(txnsOld);
        }

        List<Unified_Individual__c> uniOld = [SELECT Id FROM Unified_Individual__c LIMIT 10000];
        if (!uniOld.isEmpty()) {
            delete uniOld;
            Database.emptyRecycleBin(uniOld);
        }
        
        List<Email_Subscriber__c> subs = new List<Email_Subscriber__c>();
        List<POS_Transaction__c> txns = new List<POS_Transaction__c>();

        for (Integer i = 0; i < 150; i++) {
            String baseName = 'BulkUser' + i;
            String email = 'user' + i + '@example.com';
            String phone = '555-' + String.valueOf(i).leftPad(4, '0');
            
            subs.add(new Email_Subscriber__c(Full_Name__c = baseName + ' Smith', Email_Address__c = email));
            
            if (Math.mod(i, 2) == 0) {
                subs.add(new Email_Subscriber__c(Full_Name__c = 'B. User ' + i, Email_Address__c = email));
            }
            
            txns.add(new POS_Transaction__c(Customer_Name__c = baseName + ' S.', Phone_Number__c = phone, Total_Spent__c = 150.00));
            
            if (Math.mod(i, 3) == 0) {
                txns.add(new POS_Transaction__c(Customer_Name__c = 'Mr. Smith ' + i, Phone_Number__c = phone, Total_Spent__c = 75.50));
            }
        }
        
        insert subs;
        insert txns;
    }

    // --- BATCH APEX LOGIC ---

    /**
     * @description Start method of batch processing.
     * @param bc Batch context
     * @return QueryLocator
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (objectToProcess == 'Subscriber') {
            return Database.getQueryLocator('SELECT Id, Full_Name__c, Email_Address__c FROM Email_Subscriber__c WHERE Is_Processed__c = false AND Full_Name__c != null');
        } else {
            return Database.getQueryLocator('SELECT Id, Customer_Name__c, Phone_Number__c, Total_Spent__c FROM POS_Transaction__c WHERE Is_Processed__c = false AND Customer_Name__c != null');
        }
    }

    /**
     * @description Inner class to hold batch context data to avoid excessive parameters.
     */
    private class BatchState {
        Set<String> names = new Set<String>();
        Set<String> emails = new Set<String>();
        Set<String> phones = new Set<String>();
        Map<String, Unified_Individual__c> upsertMap = new Map<String, Unified_Individual__c>();
        Map<String, Unified_Individual__c> profileIndex = new Map<String, Unified_Individual__c>();
        List<sObject> recordsToUpdate = new List<sObject>();
    }

    /**
     * @description Execute method of batch processing.
     * @param bc Batch context
     * @param scope List of records
     */
    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        BatchState state = new BatchState();

        extractKeys(scope, state);
        buildProfileIndex(state);

        if (objectToProcess == 'Subscriber') {
            processSubscribers(scope, state);
        } else if (objectToProcess == 'POS') {
            processPOS(scope, state);
        }

        if (!state.upsertMap.isEmpty()) {
            Schema.SObjectField externalIdField = Unified_Individual__c.Fields.Match_Key__c;
            Database.upsert(state.upsertMap.values(), externalIdField, false);
        }
        if (!state.recordsToUpdate.isEmpty()) {
            Database.update(state.recordsToUpdate, false);
        }
    }

    /**
     * @description Finish method of batch processing.
     * @param bc Batch context
     */
    public void finish(Database.BatchableContext bc) {
        if (objectToProcess == 'Subscriber') {
            Database.executeBatch(new IdentityResolutionEngine('POS'), 200);
        }
    }

    // --- UTILITIES ---

    private void extractKeys(List<sObject> scope, BatchState state) {
        for (sObject record : scope) {
            String name = (String) record.get(objectToProcess == 'Subscriber' ? 'Full_Name__c' : 'Customer_Name__c');
            String matchKey = normalizeName(name);
            if (matchKey != 'unknown') {
                state.names.add(matchKey);
            }
            
            if (objectToProcess == 'Subscriber') {
                String email = (String) record.get('Email_Address__c');
                if (String.isNotBlank(email)) {
                    state.emails.add(email);
                }
            } else {
                String phone = (String) record.get('Phone_Number__c');
                if (String.isNotBlank(phone)) {
                    state.phones.add(phone);
                }
            }
        }
    }

    private void buildProfileIndex(BatchState state) {
        List<Unified_Individual__c> existingProfiles = [
            SELECT Id, Match_Key__c, First_Name__c, Primary_Email__c, Primary_Phone__c, Total_Lifetime_Value__c 
            FROM Unified_Individual__c 
            WHERE Match_Key__c IN :state.names 
            OR Primary_Email__c IN :state.emails 
            OR Primary_Phone__c IN :state.phones
        ];

        for(Unified_Individual__c u : existingProfiles) {
            if (String.isNotBlank(u.Match_Key__c)) {
                state.profileIndex.put(u.Match_Key__c, u);
            }
            if (String.isNotBlank(u.Primary_Email__c)) {
                state.profileIndex.put(u.Primary_Email__c, u);
            }
            if (String.isNotBlank(u.Primary_Phone__c)) {
                state.profileIndex.put(u.Primary_Phone__c, u);
            }
            state.upsertMap.put(u.Match_Key__c, u);
        }
    }

    private Unified_Individual__c findGoldenRecord(String nameKey, String email, String phone, BatchState state) {
        if (String.isNotBlank(email) && state.profileIndex.containsKey(email)) {
            return state.profileIndex.get(email);
        }
        if (String.isNotBlank(phone) && state.profileIndex.containsKey(phone)) {
            return state.profileIndex.get(phone);
        }
        if (state.profileIndex.containsKey(nameKey)) {
            return state.profileIndex.get(nameKey);
        }
        Unified_Individual__c golden = new Unified_Individual__c(Match_Key__c = nameKey);
        if (golden.Total_Lifetime_Value__c == null) {
            golden.Total_Lifetime_Value__c = 0;
        }
        return golden;
    }

    private void updateContext(String nameKey, String email, String phone, Unified_Individual__c golden, BatchState state) {
        state.profileIndex.put(nameKey, golden);
        if (String.isNotBlank(email)) {
            state.profileIndex.put(email, golden);
        }
        if (String.isNotBlank(phone)) {
            state.profileIndex.put(phone, golden);
        }
        state.upsertMap.put(golden.Match_Key__c, golden);
    }

    private void applySubscriberSurvivorship(Unified_Individual__c golden, Email_Subscriber__c sub) {
        String fName = extractFirstName(sub.Full_Name__c);
        if (String.isBlank(golden.First_Name__c) || fName.length() > golden.First_Name__c.length()) {
            golden.First_Name__c = fName;
        }
        if (String.isBlank(golden.Primary_Email__c) && String.isNotBlank(sub.Email_Address__c)) {
            golden.Primary_Email__c = sub.Email_Address__c;
        }
    }

    private void processSubscribers(List<sObject> scope, BatchState state) {
        for (sObject record : scope) {
            Email_Subscriber__c sub = (Email_Subscriber__c) record;
            String nameKey = normalizeName(sub.Full_Name__c);
            String email = sub.Email_Address__c;
            
            if (nameKey == 'unknown') {
                continue; 
            }

            Unified_Individual__c golden = findGoldenRecord(nameKey, email, null, state);
            applySubscriberSurvivorship(golden, sub);
            updateContext(nameKey, email, null, golden, state);
            
            // Set the lookup!
            // Wait, golden might not have an ID if it's new.
            // Salesforce allows setting parent relationships by External ID!
            Unified_Individual__c parentRef = new Unified_Individual__c(Match_Key__c = golden.Match_Key__c);
            sub.Unified_Individual__r = parentRef;
            
            sub.Is_Processed__c = true;
            state.recordsToUpdate.add(sub);
        }
    }

    private void applyPOSSurvivorship(Unified_Individual__c golden, POS_Transaction__c txn) {
        String fName = extractFirstName(txn.Customer_Name__c);
        if (String.isBlank(golden.First_Name__c) || fName.length() > golden.First_Name__c.length()) {
            golden.First_Name__c = fName;
        }
        if (String.isBlank(golden.Primary_Phone__c) && String.isNotBlank(txn.Phone_Number__c)) {
            golden.Primary_Phone__c = txn.Phone_Number__c;
        }
        if (golden.Total_Lifetime_Value__c == null) {
            golden.Total_Lifetime_Value__c = 0;
        }
        if (txn.Total_Spent__c != null) {
            golden.Total_Lifetime_Value__c += txn.Total_Spent__c;
        }
    }

    private void processPOS(List<sObject> scope, BatchState state) {
        for (sObject record : scope) {
            POS_Transaction__c txn = (POS_Transaction__c) record;
            String nameKey = normalizeName(txn.Customer_Name__c);
            String phone = txn.Phone_Number__c;
            
            if (nameKey == 'unknown') {
                continue;
            }

            Unified_Individual__c golden = findGoldenRecord(nameKey, null, phone, state);
            applyPOSSurvivorship(golden, txn);
            updateContext(nameKey, null, phone, golden, state);
            
            Unified_Individual__c parentRef = new Unified_Individual__c(Match_Key__c = golden.Match_Key__c);
            txn.Unified_Individual__r = parentRef;
            
            txn.Is_Processed__c = true;
            state.recordsToUpdate.add(txn);
        }
    }

    private static String normalizeName(String name) {
        if (String.isBlank(name)) {
            return 'unknown';
        }
        String clean = name.toLowerCase().replaceAll('[^a-z0-9 ]', '').trim().replaceAll('\\s+', ' ');
        if(String.isBlank(clean)) {
            return 'unknown';
        }
        return clean.replaceAll('\\s+', ''); 
    }
    
    private static String extractFirstName(String fullName) {
        if (String.isBlank(fullName)) {
            return 'Unknown';
        }
        List<String> parts = fullName.trim().split('\\s+');
        return parts.isEmpty() ? 'Unknown' : parts[0];
    }
}
