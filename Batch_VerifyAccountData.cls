public class Batch_VerifyAccountData implements Database.Batchable<Sobject> {
    
    private Map<Id, String> accountIdToMarketMap = new Map<Id, String>();
    
    public Database.Querylocator start(Database.BatchableContext BC) {
        // select fields that will be checked for data issues
        // NOTE: market will have to be revisited once we see where it lives/relationships
        return Database.getQueryLocator(
            [SELECT Id, Name, RecordTypeId, 
             BillingStreet, BillingCity, BillingState, BillingPostalCode, 
             Phone, Market__c, CurrentSolution__c    
             FROM Account WHERE Review_Complete__c = false]
        );
    }
    
    public void execute(Database.BatchableContext BC, List<Account> dataRows) {        
        List<Data_Validation_Log__c> reportRows = new List<Data_Validation_Log__c>();
        // check each field and write out custom error depending on findings
        if (!dataRows.isEmpty()) {
            // build lookup map                        
            for (ClientLocation__c cl : [SELECT Id, ClientAccount__c, Location__r.MarketServiceTerritory__r.Name 
                                         FROM ClientLocation__c WHERE ClientAccount__c IN :dataRows]
                ) 
            {
                if (cl.Location__r.MarketServiceTerritory__r.Name != null) {
                    accountIdToMarketMap.put(cl.ClientAccount__c, cl.Location__r.MarketServiceTerritory__r.Name);                    
                }
            }                

            for (Account account : dataRows) {
                validateFields(account, reportRows);
            }
        }
        if (!reportRows.isEmpty()) {
	        insert reportRows;
        }
    }
    
    public void finish(Database.BatchableContext BC) {
        // chain to the next batch job that will examine the object contents
        Batch_VerifyContactData batchJob = new Batch_VerifyContactData();
        Database.ExecuteBatch(batchJob, 1000);
    }
    
    private void validateFields(Account account, List<Data_Validation_Log__c> reportRows) {
        //  The below is an example of how to identify and code account type specific checks
        Id clientType = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Client').getRecordTypeId();
        Id vendorType = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Vendor').getRecordTypeId();
        Id outsideCourierType = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Outside Courier').getRecordTypeId();
        
        if (account.RecordTypeId == clientType) {
            // do account client type specific checks here
            if (
                String.isEmpty(account.BillingStreet) || 
                String.isEmpty(account.BillingCity) ||               
                String.isEmpty(account.BillingState) ||
                String.isEmpty(account.BillingPostalCode)) 
            {                       
                reportRows.add(createValidationEntry(account,
                                                     'ERROR',
                                                     'Field is empty',
                                                     'Billing Address field(s) missing data'));
            }
            /* Examples
            if (String.isEmpty(account.Phone)) {
                reportRows.add(createValidationEntry(account,
                                                     'ERROR',
                                                     'Field is empty',
                                                     'Phone is empty'));
            }
            // check picklist value
            if (!isValidPickListValue(account.CurrentSolution__c, 
                                      Schema.Account.Current_Solution__c.getDescribe().getPickListValues())) 
            {
                reportRows.add(createValidationEntry(account,
                                                     'ERROR',
                                                     'Invalid PickList Value',
                                                     'Current Solution:'+account.CurrentSolution__c));                
            }
            */
        }
        if (account.RecordTypeId == vendorType) {
            // do account vendor type specific checks here
        }
    }
    
    private Data_Validation_Log__c createValidationEntry(Account account, String category, String summary, String detail) {
        Data_Validation_Log__c validationLog = new Data_Validation_Log__c();
        validationLog.Object_Name__c = 'Account';
        validationLog.Object_Id__c = account.Id;
        validationLog.Category__c = category;
        validationLog.Validation_Summary__c = summary;
        validationLog.Validation_Detail__c = detail;
        validationLog.Object_Link__c = URL.getSalesforceBaseUrl().toExternalForm() + '/lightning/r/Account/' + account.Id + '/view';
        validationLog.Display_Name__c = account.Name;
        if (accountIdToMarketMap.containsKey(account.Id)) {
	        validationLog.Market__c = accountIdToMarketMap.get(account.Id);            
        } else {
	        validationLog.Market__c = 'NO_ACCOUNT_MARKET';            
        }
        return validationLog;
    }
    
    private Boolean isValidPickListValue(String valueToCheck, List<Schema.PicklistEntry> pleList) {
        Boolean validValue = false;
        if (String.isEmpty(valueToCheck)) {
            validValue = true;
        } else {
            for (Schema.PicklistEntry pe : pleList) {
                if (pe.getValue() == valueToCheck) {
                    validValue = true;
                    break;                    
                }
            }            
        }
        return validValue;
    }    
}