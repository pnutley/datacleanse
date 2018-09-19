public class Batch_DeDupeLocation implements Database.Batchable<Sobject>, Database.Stateful {
    
    private Set<Id> totalRecords = new Set<Id>();
    private Set<Id> matchesFound = new Set<Id>();
    private Set<Id> cleanFound = new Set<Id>();
    
    public Database.Querylocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(
            [SELECT Id, MOMS_ID__c FROM Location__c]
        );
    }
    
    public void execute(Database.BatchableContext BC, List<Location__c> dataRows) {
        List<Location_Matching__c> locationMatchingList = new List<Location_Matching__c>();
        Set<Id> matchesFoundInBatch = new Set<Id>();

        if (!dataRows.isEmpty()) {
            for (Location__c location : dataRows) {
                totalRecords.add(location.Id);
                
                // skip if this id was already identified as matching another record
                if (matchesFound.contains(location.Id)) {
                    continue;
                }
                
                List<Location__c> locationList = new List<Location__c>();
                locationList.add(location);
                
                Datacloud.FindDuplicatesResult[] results = 
                    Datacloud.FindDuplicates.findDuplicates(locationList);
                
                for (Datacloud.FindDuplicatesResult findDupeResult : results) {
                    for (Datacloud.DuplicateResult dupeResult : findDupeResult.getDuplicateResults()) {
                        if (String.isEmpty(dupeResult.getErrorMessage())) {
                            // no matches
                            cleanFound.add(location.Id);
                        } else {
                            // matches
                            matchesFound.add(location.Id);
                            matchesFoundInBatch.add(location.Id);
                            for (Datacloud.MatchResult matchResult : dupeResult.getMatchResults()) {
                                for (Datacloud.MatchRecord matchRecord : matchResult.getMatchRecords()) {
                                    Location__c matchingLocation = (Location__c) matchRecord.getRecord();
                                    matchesFound.add(matchingLocation.Id);
                                    matchesFoundInBatch.add(matchingLocation.Id);
                                    // write to matching log
                    				Location_Matching__c locationMatch = new Location_Matching__c();
                    				locationMatch.Replacement__c = location.Id;
                                    locationMatch.REPLACEMENT_MOMS_ID__c = location.MOMS_ID__c;
                    				locationMatch.Matching_Location__c = matchingLocation.Id;
                    				locationMatch.Confidence__c = String.valueOf(matchRecord.matchconfidence);
                    				locationMatchingList.add(locationMatch);                
                                }
                            }
                        }
                    }                
                }
            }
        }
        		
        // write to location matching log
        if (!locationMatchingList.isEmpty()) {
            // add in matching MOMS_IDs to object
            Map<Id, Location__c> matchingLocationMap = new Map<Id, Location__c>(
                [SELECT Id, MOMS_ID__c FROM Location__c WHERE Id IN :matchesFoundInBatch]
            );
            if (!matchingLocationMap.isEmpty()) {
                for (Location_Matching__c locationMatch : locationMatchingList) {
                    if (matchingLocationMap.containsKey(locationMatch.Matching_Location__c)) {
                        locationMatch.MATCHING_LOCATION_MOMS_ID__c = 
                            matchingLocationMap.get(locationMatch.Matching_Location__c).MOMS_ID__c;                        
                    }
                }
            }
            insert locationMatchingList;
        }        
    }
    
    public void finish(Database.BatchableContext BC) {        
        String counts = 'Total Records:'+totalRecords.size()+','+'Number of clean records:'+cleanFound.size()+','+'Number of matches:'+matchesFound.size();
        System.debug(counts);
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();    
        String[] toAddresses=new String[] {'pnutley@medspeed.com','eochoco@medspeed.com'};
            mail.setToAddresses(toAddresses);
        mail.setSubject('Results of matching job');
        mail.setPlainTextBody(counts);
        
        Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage> {mail};
            Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);        
	}
}