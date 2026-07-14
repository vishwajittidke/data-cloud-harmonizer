@RestResource(urlMapping='/v1/UnifiedProfile/*')
global with sharing class UnifiedProfileRESTAPI {

    global class ProfileRequest {
        public List<String> emails;
    }

    global class ProfileResponse {
        public String id;
        public String firstName;
        public String primaryEmail;
        public String primaryPhone;
        public Decimal lifetimeValue;
        public Decimal confidenceScore;
    }

    @HttpPost
    global static List<ProfileResponse> getProfiles(ProfileRequest request) {
        if (request == null || request.emails == null || request.emails.isEmpty()) {
            RestContext.response.statusCode = 400;
            return null;
        }

        List<ProfileResponse> responses = new List<ProfileResponse>();
        
        try {
            List<Unified_Individual__c> profiles = [
                SELECT Id, First_Name__c, Primary_Email__c, Primary_Phone__c, Total_Lifetime_Value__c, Confidence_Score__c
                FROM Unified_Individual__c
                WHERE Primary_Email__c IN :request.emails
                WITH USER_MODE
            ];
            
            for (Unified_Individual__c profile : profiles) {
                ProfileResponse pr = new ProfileResponse();
                pr.id = profile.Id;
                pr.firstName = profile.First_Name__c;
                pr.primaryEmail = profile.Primary_Email__c;
                pr.primaryPhone = profile.Primary_Phone__c;
                pr.lifetimeValue = profile.Total_Lifetime_Value__c;
                pr.confidenceScore = profile.Confidence_Score__c;
                responses.add(pr);
            }
        } catch (Exception e) {
            RestContext.response.statusCode = 500;
        }
        
        return responses;
    }
}
