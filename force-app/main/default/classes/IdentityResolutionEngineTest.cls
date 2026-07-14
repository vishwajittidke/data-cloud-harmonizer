@isTest
public class IdentityResolutionEngineTest {
    
    @testSetup
    static void setupData() {
        // Create dummy subscriber
        Email_Subscriber__c sub = new Email_Subscriber__c(
            Full_Name__c = 'Jon Smith',
            Email_Address__c = 'jsmith@test.com',
            Is_Processed__c = false
        );
        insert sub;
        
        // Create dummy POS transaction
        POS_Transaction__c pos = new POS_Transaction__c(
            Customer_Name__c = 'John Smyth',
            Phone_Number__c = '555-1234',
            Total_Spent__c = 300,
            Is_Processed__c = false
        );
        insert pos;
    }

    @isTest
    static void testRunHarmonizationAura() {
        Test.startTest();
        String result = IdentityResolutionEngine.runHarmonizationAura();
        Test.stopTest();
        
        System.assertEquals('SYNC', result, 'Should run synchronously for less than 500 records');
        
        // Assert that Unified profile was created
        List<Unified_Individual__c> unifieds = [SELECT Id, First_Name__c, Total_Lifetime_Value__c FROM Unified_Individual__c];
        System.assert(unifieds.size() > 0, 'Unified profile should be created');
        
        // Ensure the source records are linked
        Email_Subscriber__c sub = [SELECT Id, Unified_Individual__c FROM Email_Subscriber__c LIMIT 1];
        System.assertNotEquals(null, sub.Unified_Individual__c, 'Subscriber should be linked to Unified Profile');
    }
    
    @isTest
    static void testGetLineageData() {
        Test.startTest();
        IdentityResolutionEngine.runHarmonizationAura();
        Test.stopTest();
        
        Unified_Individual__c unified = [SELECT Id FROM Unified_Individual__c LIMIT 1];
        
        Map<String, Object> lineage = IdentityResolutionEngine.getLineageData(unified.Id);
        System.assertNotEquals(null, lineage, 'Lineage data should be returned');
        System.assert(lineage.containsKey('nodes'), 'Lineage should have nodes');
        System.assert(lineage.containsKey('links'), 'Lineage should have links');
    }
}
