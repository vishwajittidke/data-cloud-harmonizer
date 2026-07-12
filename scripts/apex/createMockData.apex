// Wipe existing mock data
delete [SELECT Id FROM Email_Subscriber__c];
delete [SELECT Id FROM POS_Transaction__c];
delete [SELECT Id FROM Unified_Individual__c];

// Insert Messy Marketing Data (Emails, no phones, no spend)
List<Email_Subscriber__c> subs = new List<Email_Subscriber__c>{
    new Email_Subscriber__c(Full_Name__c = 'John Doe', Email_Address__c = 'john.doe@example.com'),
    new Email_Subscriber__c(Full_Name__c = 'Sarah Connor', Email_Address__c = 's.connor@sky.net')
};
insert subs;

// Insert Messy In-Store Data (Phones and spend, but no emails)
List<POS_Transaction__c> txns = new List<POS_Transaction__c>{
    // John Doe matches the marketing data!
    new POS_Transaction__c(Customer_Name__c = 'John Doe', Phone_Number__c = '555-0199', Total_Spent__c = 500.00),
    // Sarah Connor matches the marketing data!
    new POS_Transaction__c(Customer_Name__c = 'Sarah Connor', Phone_Number__c = '555-8888', Total_Spent__c = 1250.00),
    // Bob is ONLY in the physical store system, never signed up for email
    new POS_Transaction__c(Customer_Name__c = 'Bob Builder', Phone_Number__c = '555-0300', Total_Spent__c = 1000.00)
};
insert txns;

System.debug('Mock Data Generated successfully!');
