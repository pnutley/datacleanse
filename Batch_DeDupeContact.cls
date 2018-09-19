public class Batch_DeDupeContact implements Database.Batchable<Sobject>, Database.Stateful {
    private Set<Id> totalRecords = new Set<Id>();
    private Set<Id> matchesFound = new Set<Id>();
    private Set<Id> cleanFound = new Set<Id>();
    
    public Database.Querylocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(
            [SELECT Id, MOMS_ID__c FROM Contact]
        );
    }
    
    public void execute(Database.BatchableContext BC, List<Contact> dataRows) {
        List<Contact_Matching__c> contactMatchingList = new List<Contact_Matching__c>();
        Set<Id> matchesFoundInBatch = new Set<Id>();

        if (!dataRows.isEmpty()) {
            for (Contact contact : dataRows) {
                totalRecords.add(contact.Id);
                
                // skip if this id was already identified as matching another record
                if (matchesFound.contains(contact.Id)) {
                    continue;
                }
                
                List<contact> contactList = new List<contact>();
                contactList.add(contact);
                
                Datacloud.FindDuplicatesResult[] results = 
                    Datacloud.FindDuplicates.findDuplicates(contactList);
                
                for (Datacloud.FindDuplicatesResult findDupeResult : results) {
                    for (Datacloud.DuplicateResult dupeResult : findDupeResult.getDuplicateResults()) {
                        if (String.isEmpty(dupeResult.getErrorMessage())) {
                            // no matches
                            cleanFound.add(contact.Id);
                        } else {
                            // matches
                            matchesFound.add(contact.Id);
                            matchesFoundInBatch.add(contact.Id);
                            for (Datacloud.MatchResult matchResult : dupeResult.getMatchResults()) {
                                for (Datacloud.MatchRecord matchRecord : matchResult.getMatchRecords()) {
                                    Contact matchingContact = (Contact) matchRecord.getRecord();
                                    matchesFound.add(matchingContact.Id);
                                    matchesFoundInBatch.add(matchingContact.Id);
                                    // write to matching log
                    				Contact_Matching__c contactMatch = new Contact_Matching__c();
                    				contactMatch.Replacement__c = contact.Id;
                                    contactMatch.REPLACEMENT_MOMS_ID__c = contact.MOMS_ID__c;
                    				contactMatch.Matching_Contact__c = matchingContact.Id;
                    				contactMatch.Confidence__c = String.valueOf(matchRecord.matchconfidence);
                    				contactMatchingList.add(contactMatch);                
                                }
                            }
                        }
                    }                
                }
            }
        }
        		
        // write to contact maching log
        if (!contactMatchingList.isEmpty()) {
            // add in matching MOMS_IDs to object
            Map<Id, Contact> matchingContactMap = new Map<Id, Contact>(
                [SELECT Id, MOMS_ID__c FROM Contact WHERE Id IN :matchesFoundInBatch]
            );
            if (!matchingContactMap.isEmpty()) {
                for (Contact_Matching__c contactMatch : contactMatchingList) {
                    if (matchingContactMap.containsKey(contactMatch.Matching_Contact__c)) {
                        contactMatch.MATCHING_CONTACT_MOMS_ID__c = 
                            matchingContactMap.get(contactMatch.Matching_Contact__c).MOMS_ID__c;                        
                    }
                }
            }
            insert contactMatchingList;
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