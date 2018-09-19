public class Batch_VerifyClientSublocationData implements Database.Batchable<Sobject> {
    public Database.Querylocator start(Database.BatchableContext BC) {
        // select fields that will be checked for data issues
        // NOTE: market will have to be revisited once we see where it lives/relationships
        return Database.getQueryLocator(
            [SELECT Id, Name, Sublocation__c,
             Client__c, ClientLocation__c , ClientSublocationAvailability__c, ClientLocation__r.Location__r.MarketServiceTerritory__r.Name
             FROM ClientSublocation__c WHERE Review_Complete__c = false]
        );
    }
    
    public void execute(Database.BatchableContext BC, List<ClientSublocation__c> dataRows) {        
        List<Data_Validation_Log__c> reportRows = new List<Data_Validation_Log__c>();
        // check each field and write out custom error depending on findings
        if (!dataRows.isEmpty()) {
            for (ClientSublocation__c cslocation : dataRows) {
                validateFields(cslocation, reportRows);
            }
        }
        if (!reportRows.isEmpty()) {
	        insert reportRows;
        }
    }
    
    public void finish(Database.BatchableContext BC) {
        // chain to the next batch job that will examine the object contents
        //Batch_VerifyContactData batchJob = new Batch_VerifyContactData();
        //Database.ExecuteBatch(batchJob, 1000);
    }
    
    private void validateFields(ClientSublocation__c cslocation, List<Data_Validation_Log__c> reportRows) {
        //  The below is an example of how to identify and code ClientSublocation__c type specific checks
        //Id locationType = Schema.SObjectType.cslocation.getRecordTypeInfosByName().get('cslocation').getRecordTypeId();
        
        //Required field checks
        if (String.isEmpty(cslocation.Name)) {
            reportRows.add(createValidationEntry(cslocation,
                                                 'ERROR',
                                                 'Field is empty',
                                                 'Name is empty'));
        }
        if (String.isEmpty(cslocation.Sublocation__c)) {
            reportRows.add(createValidationEntry(cslocation,
                                                 'ERROR',
                                                 'Field is empty',
                                                 'Sublocation is empty'));
        }
        if (String.isEmpty(cslocation.Client__c)) {
            reportRows.add(createValidationEntry(cslocation,
                                                 'ERROR',
                                                 'Field is empty',
                                                 'Client is empty'));
        }
        if (String.isEmpty(cslocation.ClientLocation__c)) {
            reportRows.add(createValidationEntry(cslocation,
                                                 'ERROR',
                                                 'Field is empty',
                                                 'ClientLocation is empty'));
        }
        
        
        //Picklist field checks
        if (!isValidPickListValue(cslocation.ClientSublocationAvailability__c, 
                                  Schema.ClientSublocation__c.ClientSublocationAvailability__c.getDescribe().getPickListValues())) 
        {
            reportRows.add(createValidationEntry(cslocation,
                                                 'ERROR',
                                                 'Invalid PickList Value',
                                                 'Client Sublocation Availability:'+cslocation.ClientSublocationAvailability__c));                
        }
    }
    
    private Data_Validation_Log__c createValidationEntry(ClientSublocation__c cslocation, String category, String summary, String detail) {
        Data_Validation_Log__c validationLog = new Data_Validation_Log__c();
        validationLog.Object_Name__c = 'ClientSublocation';
        validationLog.Object_Id__c = cslocation.Id;
        validationLog.Category__c = category;
        validationLog.Validation_Summary__c = summary;
        validationLog.Validation_Detail__c = detail;
        validationLog.Object_Link__c = URL.getSalesforceBaseUrl().toExternalForm() + '/lightning/r/ClientSublocation__c/' + cslocation.Id + '/view';
        validationLog.Display_Name__c = cslocation.Name;
        validationLog.Market__c = cslocation.ClientLocation__r.Location__r.MarketServiceTerritory__r.Name;
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