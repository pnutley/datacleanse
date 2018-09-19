public class Batch_VerifySublocationData implements Database.Batchable<Sobject> {
    public Database.Querylocator start(Database.BatchableContext BC) {
        // select fields that will be checked for data issues
        // NOTE: market will have to be revisited once we see where it lives/relationships
        return Database.getQueryLocator(
            [SELECT Id, Name, Type__c, TemperatureState__c,
             Location__c, Location__r.MarketServiceTerritory__r.Name
             FROM Sublocation__c WHERE Review_Complete__c = false]
        );
    }
    
    public void execute(Database.BatchableContext BC, List<Sublocation__c> dataRows) {        
        List<Data_Validation_Log__c> reportRows = new List<Data_Validation_Log__c>();
        List<Sublocation__c> updateRows = new List<Sublocation__c>();  //list to hold auto validation changes
        // check each field and write out custom error depending on findings
        if (!dataRows.isEmpty()) {
            for (Sublocation__c slocation : dataRows) {
                validateFields(slocation, reportRows, updateRows);
            }
        }
        if (!reportRows.isEmpty()) {
	        insert reportRows;
        }
        
        // update if records exist
        if (!updateRows.isEmpty()) {
            update updateRows;            
        }
    }
    
    public void finish(Database.BatchableContext BC) {
        // chain to the next batch job that will examine the object contents
        Batch_VerifyClientSublocationData batchJob = new Batch_VerifyClientSublocationData();
        Database.ExecuteBatch(batchJob, 1000);
    }
    
    private void validateFields(Sublocation__c slocation, List<Data_Validation_Log__c> reportRows, List<Sublocation__c> updateRows) {
        Boolean rowNeedsToBeUpdated = false;
        //Required field checks
        if (String.isEmpty(slocation.Name)) {
            reportRows.add(createValidationEntry(slocation,
                                                 'ERROR',
                                                 'Field is empty',
                                                 'Name is empty'));
        }
        if (String.isEmpty(slocation.Type__c)) {
            reportRows.add(createValidationEntry(slocation,
                                                 'ERROR',
                                                 'Field is empty',
                                                 'Type is empty'));
        }
        if (String.isEmpty(slocation.Location__c)) {
            reportRows.add(createValidationEntry(slocation,
                                                 'ERROR',
                                                 'Field is empty',
                                                 'Location is empty'));
        }
        if (String.isEmpty(slocation.TemperatureState__c)) {
            reportRows.add(createValidationEntry(slocation,
                                                 'ERROR',
                                                 'Field is empty',
                                                 'TemperatureState is empty'));
        }
        
        
        //Picklist field checks, first replace values, then check for valid picklist entries
        if (slocation.TemperatureState__c == 'RoomTemp')
        {
            slocation.TemperatureState__c = 'Room Temperature';
            rowNeedsToBeUpdated = true;
        }
        else if (slocation.TemperatureState__c == 'Refrig')
        {
            slocation.TemperatureState__c = 'Refrigerated';
            rowNeedsToBeUpdated = true;
        }
        else if (!isValidPickListValue(slocation.TemperatureState__c, 
                                  Schema.Sublocation__c.TemperatureState__c.getDescribe().getPickListValues())) 
        {
            reportRows.add(createValidationEntry(slocation,
                                                 'ERROR',
                                                 'Invalid PickList Value',
                                                 'Temperature State:'+slocation.TemperatureState__c));                
        }
        
        
        if (slocation.Type__c == 'Frozen')
        {
            slocation.Type__c = 'Freezer';
            rowNeedsToBeUpdated = true;
        }
        else if (slocation.Type__c == 'InsideLockBox')
        {
            slocation.Type__c = 'Lockbox';
            rowNeedsToBeUpdated = true;
        }
        else if (slocation.Type__c == 'LockBox')
        {
            slocation.Type__c = 'Lockbox';
            rowNeedsToBeUpdated = true;
        }
        else if (slocation.Type__c == 'Mail')
        {
            slocation.Type__c = 'Mail Bin';
            rowNeedsToBeUpdated = true;
        }
        else if (slocation.Type__c == 'OutsideLockBox')
        {
            slocation.Type__c = 'Lockbox';
            rowNeedsToBeUpdated = true;
        }
        else if (slocation.Type__c == 'Supply')
        {
            slocation.Type__c = 'Supply Shelf';
            rowNeedsToBeUpdated = true;
        }
        else if (!isValidPickListValue(slocation.Type__c, 
                                  Schema.Sublocation__c.Type__c.getDescribe().getPickListValues())) 
        {
            reportRows.add(createValidationEntry(slocation,
                                                 'ERROR',
                                                 'Invalid PickList Value',
                                                 'Sublocation Type:'+slocation.Type__c));                
        }
        
        // data was auto-corrected, needs to be updated
        if (rowNeedsToBeUpdated) {
            updateRows.add(slocation);            
        }
    }
    
    private Data_Validation_Log__c createValidationEntry(Sublocation__c slocation, String category, String summary, String detail) {
        Data_Validation_Log__c validationLog = new Data_Validation_Log__c();
        validationLog.Object_Name__c = 'Sublocation';
        validationLog.Object_Id__c = slocation.Id;
        validationLog.Category__c = category;
        validationLog.Validation_Summary__c = summary;
        validationLog.Validation_Detail__c = detail;
        validationLog.Object_Link__c = URL.getSalesforceBaseUrl().toExternalForm() + '/lightning/r/Sublocation__c/' + slocation.Id + '/view';
        validationLog.Display_Name__c = slocation.Name;
        validationLog.Market__c = slocation.Location__r.MarketServiceTerritory__r.Name;
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