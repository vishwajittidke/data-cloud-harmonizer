@IsTest
private class UnifiedProfileRESTAPITest {
    @TestSetup
    static void setupData() {
        Unified_Individual__c ui = new Unified_Individual__c(
            First_Name__c = 'Test',
            Primary_Email__c = 'test@example.com',
            Total_Lifetime_Value__c = 1000.0,
            Confidence_Score__c = 100
        );
        insert ui;

        // Assign permission set to test user
        User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'DataCloudHarmonizer'];
        List<PermissionSetAssignment> psa = [SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = :u.Id AND PermissionSetId = :ps.Id];
        if (psa.isEmpty()) {
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        }
    }

    @IsTest
    static void testGetProfilesSuccess() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/v1/UnifiedProfile/';
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;

        UnifiedProfileRESTAPI.ProfileRequest pr = new UnifiedProfileRESTAPI.ProfileRequest();
        pr.emails = new List<String>{'test@example.com'};

        Test.startTest();
        List<UnifiedProfileRESTAPI.ProfileResponse> results = UnifiedProfileRESTAPI.getProfiles(pr);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one profile');
        System.assertEquals('Test', results[0].firstName, 'First name should match');
        System.assertEquals(1000.0, results[0].lifetimeValue, 'Lifetime value should match');
    }

    @IsTest
    static void testGetProfilesBadRequest() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/v1/UnifiedProfile/';
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;

        UnifiedProfileRESTAPI.ProfileRequest pr = new UnifiedProfileRESTAPI.ProfileRequest();

        Test.startTest();
        List<UnifiedProfileRESTAPI.ProfileResponse> results = UnifiedProfileRESTAPI.getProfiles(pr);
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Status code should be 400 for bad request');
        System.assertEquals(null, results, 'Results should be null for bad request');
    }
}
