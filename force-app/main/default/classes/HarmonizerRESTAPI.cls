@RestResource(urlMapping='/v1/harmonizer/*')
global with sharing class HarmonizerRESTAPI {
    
    global class DataPayload {
        public String sourceSystem;
        public String fullName;
        public String email;
        public String phone;
        public Decimal totalSpent;
    }

    @HttpPost
    global static String ingestData(List<DataPayload> records) {
        if (records == null || records.isEmpty()) {
            RestContext.response.statusCode = 400;
            return 'Error: No records provided.';
        }

        List<Email_Subscriber__c> subscribersToInsert = new List<Email_Subscriber__c>();
        List<POS_Transaction__c> posToInsert = new List<POS_Transaction__c>();

        for (DataPayload payload : records) {
            if (payload.sourceSystem == 'Email' || payload.sourceSystem == 'Marketing') {
                subscribersToInsert.add(new Email_Subscriber__c(
                    Full_Name__c = payload.fullName,
                    Email_Address__c = payload.email,
                    Is_Processed__c = false
                ));
            } else if (payload.sourceSystem == 'POS' || payload.sourceSystem == 'Retail') {
                posToInsert.add(new POS_Transaction__c(
                    Customer_Name__c = payload.fullName,
                    Phone_Number__c = payload.phone,
                    Total_Spent__c = payload.totalSpent != null ? payload.totalSpent : 0.0,
                    Is_Processed__c = false
                ));
            }
        }

        try {
            if (!subscribersToInsert.isEmpty()) {
                insert as user subscribersToInsert;
            }
            if (!posToInsert.isEmpty()) {
                insert as user posToInsert;
            }
            
            // Optionally, we could run the batch engine here, but since we have a nightly scheduled flow, 
            // we will let the data sit in the Resolution Queue until the batch runs.
            
            return 'Success: Ingested ' + (subscribersToInsert.size() + posToInsert.size()) + ' records into the harmonization queue.';
        } catch (Exception e) {
            RestContext.response.statusCode = 500;
            return 'Error: ' + e.getMessage();
        }
    }
}
