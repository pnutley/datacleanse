public class Batch_VerifyContactData implements Database.Batchable<Sobject> {
    
    private Map<Id, String> accountIdToMarketMap = new Map<Id, String>();
    private Map<Id, String> contactIdToMarketMap = new Map<Id, String>();
    
    public Database.Querylocator start(Database.BatchableContext BC) {
        // select fields that will be checked for data issues
        return Database.getQueryLocator(
            [SELECT Id, AccountId, Name, LastName, FirstName, 
             Phone, Email, Account.BillingState 
             FROM Contact WHERE Review_Complete__c = false]
        );
    }
    
    public void execute(Database.BatchableContext BC, List<Contact> dataRows) {
        List<Data_Validation_Log__c> reportRows = new List<Data_Validation_Log__c>();
        // check each field and write out custom error depending on findings
        if (!dataRows.isEmpty()) {
            // build lookup map for client contacts markets
            Set<Id> accountIdSet = new Set<Id>();
            for (Contact contact : dataRows) {
                if (contact.AccountId != null) {
                    accountIdSet.add(contact.AccountId);                    
                }                
            }
            
            if (!accountIdSet.isEmpty()) {
                for (ClientLocation__c cl : [SELECT Id, ClientAccount__c, Location__r.MarketServiceTerritory__r.Name 
                                             FROM ClientLocation__c WHERE ClientAccount__c IN :accountIdSet]
                    ) 
                {
                    if (cl.Location__r.MarketServiceTerritory__r.Name != null) {
                        accountIdToMarketMap.put(cl.ClientAccount__c, cl.Location__r.MarketServiceTerritory__r.Name);                    
                    }
                }                 
            }
            
            // build lookup map for location contacts markets
            for (LocationContact__c lc : [SELECT Id, Contact__c, Location__r.MarketServiceTerritory__r.Name 
                                          FROM LocationContact__c WHERE Contact__c IN :dataRows]
                ) 
            {
                if (lc.Location__r.MarketServiceTerritory__r.Name != null) {
                    contactIdToMarketMap.put(lc.Contact__c, lc.Location__r.MarketServiceTerritory__r.Name);                    
                }
            }                 
            
            for (Contact contact : dataRows) {
                validateFields(contact, reportRows);
            }
        }
        if (!reportRows.isEmpty()) {
	        insert reportRows;
        }
    }
    
    public void finish(Database.BatchableContext BC) {
        // chain to the next batch job that will examine the object contents
        Batch_VerifyLocationData batchJob = new Batch_VerifyLocationData();
        Database.ExecuteBatch(batchJob, 1000);
    }
    
    private void validateFields(Contact contact, List<Data_Validation_Log__c> reportRows) {
        if (String.isEmpty(contact.Phone)) {                        
            reportRows.add(createValidationEntry(contact,
                                                 'ERROR',
                                                 'Field is empty',
                                                 'Phone is empty'));
        } else if (contact.Phone.length() < 10) {
            reportRows.add(createValidationEntry(contact,
                                                 'ERROR',
                                                 'Invalid format',
                                                 'Phone is less than 10 digits long'));            
        }
        if (String.isEmpty(contact.Email)) {                        
            reportRows.add(createValidationEntry(contact,
                                                 'ERROR',
                                                 'Field is empty',
                                                 'Email is empty'));
        }
        if (contact.LastName == 'UNKNOWN' || contact.LastName == '.') {
            reportRows.add(createValidationEntry(contact,
                                                 'WARNING',
                                                 'Unknown Last Name',
                                                 'Last Name is Unknown'));
        }
        if (String.isEmpty(contact.AccountId)) {
            reportRows.add(createValidationEntry(contact,
                                                 'ERROR',
                                                 'Field is empty',
                                                 'Not associated to an account'));
        }
    }
    
    private Data_Validation_Log__c createValidationEntry(Contact contact, String category, String summary, String detail) {
        Data_Validation_Log__c validationLog = new Data_Validation_Log__c();
        validationLog.Object_Name__c = 'Contact';
        validationLog.Object_Id__c = contact.Id;
        validationLog.Category__c = category;
        validationLog.Validation_Summary__c = summary;
        validationLog.Validation_Detail__c = detail;
        validationLog.Object_Link__c = URL.getSalesforceBaseUrl().toExternalForm() + '/lightning/r/Contact/' + contact.Id + '/view';
        validationLog.Display_Name__c = contact.Name;
        validationLog.Market__c = contact.Account.BillingState;
        if (accountIdToMarketMap.containsKey(contact.Id)) {
	        validationLog.Market__c = accountIdToMarketMap.get(contact.Id);            
        } else if (contactIdToMarketMap.containsKey(contact.Id)) {
	        validationLog.Market__c = contactIdToMarketMap.get(contact.Id);            
        } else {
	        validationLog.Market__c = 'NO_CONTACT_MARKET';  
        }

        return validationLog;
    }
}