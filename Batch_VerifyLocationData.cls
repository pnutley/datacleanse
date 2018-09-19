public class Batch_VerifyLocationData implements Database.Batchable<Sobject> {
    public Database.Querylocator start(Database.BatchableContext BC) {
        // select fields that will be checked for data issues
        // NOTE: market will have to be revisited once we see where it lives/relationships
        return Database.getQueryLocator(
            [SELECT Id, Name, RecordTypeId, 
             MarketServiceTerritory__c, FinancialTerritory__c,
             AddressLine1__c, City__c, ZipPostalCode__c,
             StateProvince__c, Country__c, AccessCodeType__c, LocationType__c, MarketServiceTerritory__r.Name    
             FROM Location__c WHERE Review_Complete__c = false]
        );
    }
    
    public void execute(Database.BatchableContext BC, List<Location__c> dataRows) {        
        List<Data_Validation_Log__c> reportRows = new List<Data_Validation_Log__c>();
        // check each field and write out custom error depending on findings
        if (!dataRows.isEmpty()) {
            for (Location__c location : dataRows) {
                validateFields(location, reportRows);
            }
        }
        if (!reportRows.isEmpty()) {
	        insert reportRows;
        }
    }
    
    public void finish(Database.BatchableContext BC) {
        // chain to the next batch job that will examine the object contents
        Batch_VerifyClientLocationData batchJob = new Batch_VerifyClientLocationData();
        Database.ExecuteBatch(batchJob, 1000);
    }
    
    private void validateFields(Location__c location, List<Data_Validation_Log__c> reportRows) {
        Id locationType = Schema.SObjectType.Location__c.getRecordTypeInfosByName().get('Location').getRecordTypeId();
        Id MSLaunchType = Schema.SObjectType.Location__c.getRecordTypeInfosByName().get('MedSpeed Launch Location').getRecordTypeId();
        
        if (location.RecordTypeId == MSLaunchType) {
            // do Location__c MSLaunch type specific checks here
            if (
                String.isEmpty(location.AddressLine1__c) || 
                String.isEmpty(location.City__c) ||               
                String.isEmpty(location.ZipPostalCode__c) ||
                String.isEmpty(location.StateProvince__c) ||
                String.isEmpty(location.Country__c)) 
            {                       
                reportRows.add(createValidationEntry(location,
                                                     'ERROR',
                                                     'Field is empty',
                                                     'Address field(s) missing data'));
            }
            if (String.isEmpty(location.MarketServiceTerritory__c)) {
                reportRows.add(createValidationEntry(location,
                                                     'ERROR',
                                                     'Field is empty',
                                                     'MarketServiceTerritory is empty'));
            }
            if (String.isEmpty(location.FinancialTerritory__c)) {
                reportRows.add(createValidationEntry(location,
                                                     'ERROR',
                                                     'Field is empty',
                                                     'FinancialTerritory is empty'));
            }
            if (String.isEmpty(location.Name)) {
                reportRows.add(createValidationEntry(location,
                                                     'ERROR',
                                                     'Field is empty',
                                                     'Name is empty'));
            }
            // check picklist value
            if (!isValidPickListValue(location.AccessCodeType__c, 
                                      Schema.Location__c.AccessCodeType__c.getDescribe().getPickListValues())) 
            {
                reportRows.add(createValidationEntry(location,
                                                     'ERROR',
                                                     'Invalid PickList Value',
                                                     'Access Code Type:'+location.AccessCodeType__c));                
            }
            if (!isValidPickListValue(location.LocationType__c, 
                                      Schema.Location__c.LocationType__c.getDescribe().getPickListValues())) 
            {
                reportRows.add(createValidationEntry(location,
                                                     'ERROR',
                                                     'Invalid PickList Value',
                                                     'Location Type:'+location.LocationType__c));                
            }
        }
        if (location.RecordTypeId == locationType) {
            // do location location type specific checks here
            if (
                String.isEmpty(location.AddressLine1__c) || 
                String.isEmpty(location.City__c) ||               
                String.isEmpty(location.ZipPostalCode__c) ||
                String.isEmpty(location.StateProvince__c) ||
                String.isEmpty(location.Country__c)) 
            {                       
                reportRows.add(createValidationEntry(location,
                                                     'ERROR',
                                                     'Field is empty',
                                                     'Address field(s) missing data'));
            }
            if (String.isEmpty(location.MarketServiceTerritory__c)) {
                reportRows.add(createValidationEntry(location,
                                                     'ERROR',
                                                     'Field is empty',
                                                     'MarketServiceTerritory is empty'));
            }
            if (String.isEmpty(location.Name)) {
                reportRows.add(createValidationEntry(location,
                                                     'ERROR',
                                                     'Field is empty',
                                                     'Name is empty'));
            }
            // check picklist value
            if (!isValidPickListValue(location.AccessCodeType__c, 
                                      Schema.Location__c.AccessCodeType__c.getDescribe().getPickListValues())) 
            {
                reportRows.add(createValidationEntry(location,
                                                     'ERROR',
                                                     'Invalid PickList Value',
                                                     'Access Code Type:'+location.AccessCodeType__c));                
            }
            if (!isValidPickListValue(location.LocationType__c, 
                                      Schema.Location__c.LocationType__c.getDescribe().getPickListValues())) 
            {
                reportRows.add(createValidationEntry(location,
                                                     'ERROR',
                                                     'Invalid PickList Value',
                                                     'Location Type:'+location.LocationType__c));                
            }
        }
    }
    
    private Data_Validation_Log__c createValidationEntry(Location__c location, String category, String summary, String detail) {
        Data_Validation_Log__c validationLog = new Data_Validation_Log__c();
        validationLog.Object_Name__c = 'Location';
        validationLog.Object_Id__c = location.Id;
        validationLog.Category__c = category;
        validationLog.Validation_Summary__c = summary;
        validationLog.Validation_Detail__c = detail;
        validationLog.Object_Link__c = URL.getSalesforceBaseUrl().toExternalForm() + '/lightning/r/Location__c/' + location.Id + '/view';
        validationLog.Display_Name__c = location.Name;
        validationLog.Market__c = location.MarketServiceTerritory__r.Name;
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