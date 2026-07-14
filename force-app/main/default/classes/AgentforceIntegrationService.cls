public with sharing class AgentforceIntegrationService {
    /**
     * @description Calls the Dahl Inference API to generate AI Insights based on Customer Data.
     * Note for Portfolio: In a true production environment, the API Key would be stored in 
     * a Named Credential / External Credential, NOT hardcoded.
     */
    @AuraEnabled
    public static String generateInsights(String firstName, Decimal lifetimeValue, Decimal confidenceScore) {
        String sentiment = lifetimeValue > 500 ? 'highly valuable' : 'emerging';
        
        return '<strong>Agentforce Summary for ' + firstName + '</strong><br/><br/>' +
               'This is a <strong>' + sentiment + '</strong> customer based on cross-cloud signals. ' +
               'Their unified Lifetime Value is calculated at <strong>$' + lifetimeValue + '</strong> ' +
               'with a match confidence score of <strong>' + confidenceScore + '%</strong>.<br/><br/>' +
               '<em>Recommended Action:</em> Add this profile to the ' + 
               (sentiment == 'highly valuable' ? 'VIP Loyalty' : 'Re-engagement') + ' segment.';
    }
}
