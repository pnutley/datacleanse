public class Batch_VerifyClientLocationData implements Database.Batchable<Sobject> {
    public Database.Querylocator start(Database.BatchableContext BC) {
        // select fields that will be checked for data issues
        // NOTE: market will have to be revisited once we see where it lives/relationships
        return Database.getQueryLocator(
            [SELECT Id, Name, ClientAccount__c, Location__c,
             Contact__c, ImplementationStatus__c, RequiredPODType__c, Location__r.MarketServiceTerritory__r.Name
             FROM ClientLocation__c WHERE Review_Complete__c = false]
        );
    }
    
    public void execute(Database.BatchableContext BC, List<ClientLocation__c> dataRows) {        
        List<Data_Validation_Log__c> reportRows = new List<Data_Validation_Log__c>();
        // check each field and write out custom error depending on findings
        if (!dataRows.isEmpty()) {
            for (ClientLocation__c clocation : dataRows) {
                validateFields(clocation, reportRows);
            }
        }
        if (!reportRows.isEmpty()) {
        	insert reportRows;            
        }
    }
    
    public void finish(Database.BatchableContext BC) {
        // chain to the next batch job that will examine the object contents
        Batch_VerifySublocationData batchJob = new Batch_VerifySublocationData();
        Database.ExecuteBatch(batchJob, 1000);
    }
    
    private void validateFields(ClientLocation__c clocation, List<Data_Validation_Log__c> reportRows) {        
        //Required field checks
        if (String.isEmpty(clocation.Name)) {
            reportRows.add(createValidationEntry(clocation,
                                                 'ERROR',
                                                 'Field is empty',
                                                 'Name is empty'));
        }
        if (String.isEmpty(clocation.ClientAccount__c)) {
            reportRows.add(createValidationEntry(clocation,
                                                 'ERROR',
                                                 'Field is empty',
                                                 'ClientAccount is empty'));
        }
        if (String.isEmpty(clocation.Location__c)) {
            reportRows.add(createValidationEntry(clocation,
                                                 'ERROR',
                                                 'Field is empty',
                                                 'Location is empty'));
        }
        if (String.isEmpty(clocation.Contact__c)) {
            reportRows.add(createValidationEntry(clocation,
                                                 'ERROR',
                                                 'Field is empty',
                                                 'Contact is empty'));
        }
        
        
        //Picklist field checks
        if (!isValidPickListValue(clocation.ImplementationStatus__c, 
                                  Schema.ClientLocation__c.ImplementationStatus__c.getDescribe().getPickListValues())) 
        {
            reportRows.add(createValidationEntry(clocation,
                                                 'ERROR',
                                                 'Invalid PickList Value',
                                                 'Implementation Status:'+clocation.ImplementationStatus__c));                
        }
        if (!isValidPickListValue(clocation.RequiredPODType__c, 
                                  Schema.ClientLocation__c.RequiredPODType__c.getDescribe().getPickListValues())) 
        {
            reportRows.add(createValidationEntry(clocation,
                                                 'ERROR',
                                                 'Invalid PickList Value',
                                                 'Required POD Type:'+clocation.RequiredPODType__c));                
        }
    }
    
    private Data_Validation_Log__c createValidationEntry(ClientLocation__c clocation, String category, String summary, String detail) {
        Data_Validation_Log__c validationLog = new Data_Validation_Log__c();
        validationLog.Object_Name__c = 'ClientLocation';
        validationLog.Object_Id__c = clocation.Id;
        validationLog.Category__c = category;
        validationLog.Validation_Summary__c = summary;
        validationLog.Validation_Detail__c = detail;
        validationLog.Object_Link__c = URL.getSalesforceBaseUrl().toExternalForm() + '/lightning/r/ClientLocation__c/' + clocation.Id + '/view';
        validationLog.Display_Name__c = clocation.Name;
        validationLog.Market__c = clocation.Location__r.MarketServiceTerritory__r.Name;
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