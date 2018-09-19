public class Batch_CreateClientSublocations implements Database.Batchable<Sobject> {
    public Database.Querylocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(
            [SELECT Id, Name, 
             (SELECT Id, Name, Notes__c, Type__c FROM Sublocation__r) 
             FROM Location__c]
        );
    }

    public void execute(Database.BatchableContext BC, List<Location__c> dataRows) {        
        List<ClientSublocation__c> insertRows = new List<ClientSublocation__c>();
        
        if (!dataRows.isEmpty()) {
			// identify locations that have sublocations
            Map<Id, Location__c> locationMap = new Map<Id, Location__c>();
            for (Location__c location : dataRows) {
                if (location.Sublocation__r != null) {
                    locationMap.put(location.Id, location);
                }
            }
			
            // get client locations for locations that have sublocations
            List<ClientLocation__c> cLocList = 
                [SELECT Id, ClientAccount__c, ClientID__c, Location__c 
                 FROM ClientLocation__c 
                 WHERE Location__c IN :locationMap.keySet()];
            
            if (!cLocList.isEmpty()) {
                // create sublocations for client location using sublocations from location
                for (ClientLocation__c cloc : cLocList) {
                    if (locationMap.containsKey(cloc.Location__c)) {
						Location__c location = locationMap.get(cloc.Location__c);
                        for (Sublocation__c subLocation : location.Sublocation__r) {
                            ClientSublocation__c csloc = new ClientSublocation__c();
                            csloc.ClientLocation__c = cloc.Id;
                            csloc.Sublocation__c = subLocation.Id;
                            csloc.Client__c = cloc.ClientAccount__c;
                            csloc.ClientSublocationNotes__c = subLocation.Notes__c;
                            insertRows.add(csloc);
                        }
                    }                    
                }              
            }            
        }
        
        if (!insertRows.isEmpty()) {
            insert insertRows;
        }
    }    

    public void finish(Database.BatchableContext BC) {
    }
}