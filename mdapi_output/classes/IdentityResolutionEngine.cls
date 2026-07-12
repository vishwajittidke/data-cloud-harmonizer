public with sharing class IdentityResolutionEngine {
    
    @AuraEnabled
    public static void runHarmonizationAura() {
        runHarmonization();
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> fetchDashboardData() {
        Map<String, Object> result = new Map<String, Object>();
        result.put('subscribers', [SELECT Id, Full_Name__c, Email_Address__c FROM Email_Subscriber__c ORDER BY Full_Name__c]);
        result.put('pos', [SELECT Id, Customer_Name__c, Phone_Number__c, Total_Spent__c FROM POS_Transaction__c ORDER BY Customer_Name__c]);
        result.put('unified', [SELECT Id, First_Name__c, Primary_Email__c, Primary_Phone__c, Total_Lifetime_Value__c FROM Unified_Individual__c ORDER BY First_Name__c]);
        return result;
    }

    @AuraEnabled
    public static void resetDemo() {
        delete [SELECT Id FROM Email_Subscriber__c];
        delete [SELECT Id FROM POS_Transaction__c];
        delete [SELECT Id FROM Unified_Individual__c];
    }

    @AuraEnabled
    public static void injectMockData() {
        // Only inject if empty so we don't duplicate forever
        if([SELECT COUNT() FROM Email_Subscriber__c] == 0) {
            insert new List<Email_Subscriber__c>{
                new Email_Subscriber__c(Full_Name__c = 'John Doe', Email_Address__c = 'john.doe@example.com'),
                new Email_Subscriber__c(Full_Name__c = 'Sarah Connor', Email_Address__c = 's.connor@sky.net')
            };
            insert new List<POS_Transaction__c>{
                new POS_Transaction__c(Customer_Name__c = 'John Doe', Phone_Number__c = '555-0199', Total_Spent__c = 500.00),
                new POS_Transaction__c(Customer_Name__c = 'Sarah Connor', Phone_Number__c = '555-8888', Total_Spent__c = 1250.00),
                new POS_Transaction__c(Customer_Name__c = 'Bob Builder', Phone_Number__c = '555-0300', Total_Spent__c = 1000.00)
            };
        }
    }

    public static void runHarmonization() {
        List<Email_Subscriber__c> subscribers = [SELECT Id, Full_Name__c, Email_Address__c FROM Email_Subscriber__c];
        List<POS_Transaction__c> posTxns = [SELECT Id, Customer_Name__c, Phone_Number__c, Total_Spent__c FROM POS_Transaction__c];
        Map<String, Unified_Individual__c> goldenRecordsMap = new Map<String, Unified_Individual__c>();
        
        for(Email_Subscriber__c sub : subscribers) {
            String matchKey = normalizeName(sub.Full_Name__c);
            if(!goldenRecordsMap.containsKey(matchKey)) {
                goldenRecordsMap.put(matchKey, new Unified_Individual__c(
                    First_Name__c = extractFirstName(sub.Full_Name__c),
                    Primary_Email__c = sub.Email_Address__c,
                    Total_Lifetime_Value__c = 0
                ));
            } else {
                Unified_Individual__c existing = goldenRecordsMap.get(matchKey);
                if(String.isBlank(existing.Primary_Email__c)) existing.Primary_Email__c = sub.Email_Address__c;
            }
        }
        
        for(POS_Transaction__c txn : posTxns) {
            String matchKey = normalizeName(txn.Customer_Name__c);
            if(goldenRecordsMap.containsKey(matchKey)) {
                Unified_Individual__c golden = goldenRecordsMap.get(matchKey);
                if(String.isBlank(golden.Primary_Phone__c)) golden.Primary_Phone__c = txn.Phone_Number__c;
                if(txn.Total_Spent__c != null) golden.Total_Lifetime_Value__c += txn.Total_Spent__c;
            } else {
                goldenRecordsMap.put(matchKey, new Unified_Individual__c(
                    First_Name__c = extractFirstName(txn.Customer_Name__c),
                    Primary_Phone__c = txn.Phone_Number__c,
                    Total_Lifetime_Value__c = txn.Total_Spent__c != null ? txn.Total_Spent__c : 0
                ));
            }
        }
        
        if(!goldenRecordsMap.values().isEmpty()) {
            delete [SELECT Id FROM Unified_Individual__c];
            insert goldenRecordsMap.values();
        }
    }
    
    private static String normalizeName(String name) {
        if(String.isBlank(name)) return 'unknown';
        return name.toLowerCase().replaceAll('\\s+', '');
    }
    
    private static String extractFirstName(String fullName) {
        if(String.isBlank(fullName)) return 'Unknown';
        return fullName.split(' ')[0];
    }
}
