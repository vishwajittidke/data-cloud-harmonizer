public with sharing class AgentforceIntegrationService {
    /**
     * @description Calls the Dahl Inference API to generate AI Insights based on Customer Data.
     * Note for Portfolio: In a true production environment, the API Key would be stored in 
     * a Named Credential / External Credential, NOT hardcoded.
     */
    @AuraEnabled
    public static String generateInsights(String firstName, Decimal lifetimeValue, Decimal confidenceScore) {
        String prompt = 'You are an expert marketing assistant. We have a customer named ' + firstName + 
            '. Their Lifetime Value is $' + lifetimeValue + ' and the match confidence score for their unified profile is ' + 
            confidenceScore + '%. Write a 2-sentence summary evaluating their value, and then provide a specific ' +
            'marketing segment recommendation on the next line.';

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.openai.com/v1/chat/completions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setHeader('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)');
        
        // ENTERPRISE BEST PRACTICE WARNING: Do not hardcode tokens. Use Named Credentials.
        // We are using a direct token injection here for portfolio demonstration speed.
        req.setHeader('Authorization', 'Bearer <YOUR_OPENAI_API_KEY>'); 
        req.setTimeout(120000); // Set timeout to 120 seconds for AI generation

        Map<String, Object> body = new Map<String, Object>();
        body.put('model', 'gpt-4o-mini');
        
        List<Map<String, String>> messages = new List<Map<String, String>>();
        Map<String, String> msg = new Map<String, String>();
        msg.put('role', 'user');
        msg.put('content', prompt);
        messages.add(msg);
        
        body.put('messages', messages);
        
        req.setBody(JSON.serialize(body));
        
        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> choices = (List<Object>) responseMap.get('choices');
                if (choices != null && !choices.isEmpty()) {
                    Map<String, Object> choice = (Map<String, Object>) choices[0];
                    Map<String, Object> message = (Map<String, Object>) choice.get('message');
                    String content = (String) message.get('content');
                    // Replace newlines with <br/> for LWC rich text rendering
                    return content.replace('\n', '<br/>');
                }
            }
            
            // FALLBACK FOR PORTFOLIO DEMO: If the API key is out of quota (429) or fails, return a simulated response
            String sentiment = lifetimeValue > 500 ? 'highly valuable' : 'emerging';
            return '<strong>[Simulated Fallback - API Quota Exceeded]</strong><br/><br/>' +
                   'This is a <strong>' + sentiment + '</strong> customer based on cross-cloud signals. ' +
                   'Their unified Lifetime Value is calculated at <strong>$' + lifetimeValue + '</strong> ' +
                   'with a match confidence score of <strong>' + confidenceScore + '%</strong>.<br/><br/>' +
                   '<em>Recommended Action:</em> Add this profile to the ' + 
                   (sentiment == 'highly valuable' ? 'VIP Loyalty' : 'Re-engagement') + ' segment.';

        } catch (Exception e) {
            throw new AuraHandledException('Callout failed: ' + e.getMessage());
        }
    }
}
