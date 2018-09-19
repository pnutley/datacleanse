public class Batch_DeleteDataValidationLog implements Database.Batchable<Sobject> {
    public Database.Querylocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(
            [SELECT Id FROM Data_Validation_Log__c]
        );
    }
    
    public void execute(Database.BatchableContext BC, List<Data_Validation_Log__c> dataRows) {
        if (!dataRows.isEmpty()) {
            delete dataRows;
        }
    }
    
    public void finish(Database.BatchableContext BC) {
        // chain to the next batch job that will examine the object contents
        Batch_VerifyAccountData batchJob = new Batch_VerifyAccountData();
        Database.ExecuteBatch(batchJob, 1000);
    }    
}