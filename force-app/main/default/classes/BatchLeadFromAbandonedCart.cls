Global class BatchLeadFromAbandonedCart  implements Schedulable, Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts  {
    public String query;
    Datetime expiredTime = System.now().addHours(-23);
    public TREX1__App_Config__c settings = TREX1__App_Config__c.getInstance();
    public Id queueId = [SELECT Id FROM Group WHERE DeveloperName = 'MQL_Leads'].Id;

    Global BatchLeadFromAbandonedCart() {
        query = 'SELECT Id, Name, RecordTypeId, CreatedDate, LastModifiedDate, TREX1__Account__c,  '+
        ' TREX1__Status__c, '+
        'TREX1__Contact__c, TREX1__Contact__r.FirstName,  TREX1__Contact__r.LastName, '+
        'TREX1__Contact__r.Email,  TREX1__Contact__r.Phone, TREX1__Contact__r.Abandoned_Cart_Lead_Transaction_Id__c, '+
        '(Select Id, Name, TREX1__Contact__r.Name,TREX1__Type__c, TREX1__tli_Product__r.Name, TREX1__Description__c, TREX1__Registration__c, TREX1__Membership_Group__c, TREX1__Membership__c, TREX1__Add_On__c, TREX1__Line_Item_To_Discount__c, ' +
        'TREX1__Status__c, TREX1__Course_Option_Enrollment__c from TREX1__Transaction_Line_Items__r WHERE TREX1__Converted_Billing_Schedule__c = null Order By Name) ' +
        'FROM TREX1__Transaction__c ' +  
        'WHERE TREX1__Status__c IN (\'Draft\', \'Payment in Process\') AND  '+
        'TREX1__Created_Online__c = true AND ' +
        'TREX1__Exclude_From_Automatic_Cleanup__c != true ';            
    }

    global Database.QueryLocator start(Database.BatchableContext BC){

        return Database.getQueryLocator(query);

    }

    global  void execute(Database.BatchableContext BC, List<TREX1__Transaction__c> recs){

        List<Lead> newLeads = new List<Lead>();
        Map<Id, Contact> updContacts = new Map<Id,Contact>();
        for(TREX1__Transaction__c rec : recs){
            String productOfInterest = rec.TREX1__Transaction_Line_Items__r.size() == 0 ? 'Empty Cart' : buildDescription(rec.TREX1__Transaction_Line_Items__r);
            Boolean skipTransaction = false;
            if(rec.Id == rec.TREX1__Contact__r.Abandoned_Cart_Lead_Transaction_Id__c){
                skipTransaction = true;
            }
            if(!skipTransaction){
                List<TREX1__Registration__c> registrations = [SELECT Id FROM TREX1__Registration__c WHERE TREX1__Contact__c = :rec.TREX1__Contact__c AND TREX1__Registration_Status__c IN ('Active','Pending Active')];
                List<TREX1__Membership__c> memberships = [SELECT Id FROM TREX1__Membership__c WHERE TREX1__Contact__c = :rec.TREX1__Contact__c AND Member_Status__c = 'Active'];
                List<Lead> leads = [SELECT Id, Product_Interest__c FROM Lead WHERE Contact__c = :rec.TREX1__Contact__c]; 
                
                if(registrations.size() > 0 || memberships.size() > 0 || rec.TREX1__Transaction_Line_Items__r.size() == 0){
                    if(registrations.size() > 0 || memberships.size() > 0){
                        updContacts.put(rec.TREX1__Contact__c, new Contact(Id = rec.TREX1__Contact__c, Send_Abandoned_Cart_Email__c = true));
                    }
                    skipTransaction = true;
                } else {
                    for(Lead lead : leads){
                        if(lead.Product_Interest__c == productOfInterest){
                            skipTransaction = true;
                        }
                    }
                }
            }

            if(!skipTransaction){
                List<TREX1__Membership__c> memberships = [
                    SELECT Id FROM TREX1__Membership__c 
                    WHERE TREX1__Account__c = :rec.TREX1__Account__c
                      AND TREX1__Contact__c != :rec.TREX1__Contact__c
                      AND TREX1__Status__c IN ('Active', 'Pending')
                ];
                newLeads.add(new Lead(
                    OwnerId = this.queueId,
                    Company = 'Individual',
                    MQL__c = TRUE,
                    Status = 'New Lead',
                    LeadSource = 'Portal',
                    Lead_Type__c = 'Abandoned Cart',
                    FirstName = rec.TREX1__Contact__r.FirstName,  
                    LastName  = rec.TREX1__Contact__r.LastName, 
                    Email  = rec.TREX1__Contact__r.Email, 
                    Phone  = rec.TREX1__Contact__r.Phone,
                    Contact__c = rec.TREX1__Contact__c,
                    Product_Interest__c = productOfInterest,
                    A_Household_Member_has_Membership__c = memberships.size() > 0 ? true : false
                ));
                updContacts.put(rec.TREX1__Contact__c, new Contact(
                    Id = rec.TREX1__Contact__c,
                    Abandoned_Cart_Lead_Transaction_Id__c = rec.Id,
                    Abandoned_Cart_Lead_Timestamp__c = System.now()
                ));
                    
            }
  
        }

        if(newLeads.size() > 0 ){
            Database.DMLOptions dml = new Database.DMLOptions(); 
            dml.DuplicateRuleHeader.allowSave = true;
            dml.DuplicateRuleHeader.runAsCurrentUser = true;
            Database.SaveResult[] leadResults = Database.Insert(newLeads, dml);

            for(Lead lead : newLeads) System.debug(lead);
        }
        if(updContacts.size() > 0){
            update updContacts.values();
        }

    }

    public static String buildDescription(List<TREX1__Transaction_Line_Item__c> items){
        String description;
        String delimiter = ' // ';
        for(TREX1__Transaction_Line_Item__c item : items){
            String itemType;
            if(item.TREX1__Line_Item_To_Discount__c != null)
                itemType = 'Discount';
            else if(item.TREX1__Course_Option_Enrollment__c != null)
                //itemType = 'COE';
                itemType = 'Enrollment';
            else if(item.TREX1__Registration__c != null)
                itemType = 'Registration';
            else if(item.TREX1__Membership_Group__c != null)
                itemType = 'Membership Group';
            else if(item.TREX1__Membership__c != null)
                itemType = 'Membership';
            else if(item.TREX1__Add_On__c != null)
                itemType = 'Add On';

            itemType = '(' +itemType+') ';


            String line =   '<p>'+
                            itemType+
                            item?.TREX1__Description__c+
                            delimiter+
                            item?.TREX1__Contact__r?.Name+
                            delimiter+
                            item?.TREX1__tli_Product__r?.Name+
                            '</p>';

            if(description==null || !description.contains(line))
                description = description == null ? line : description + line;
        }
        return description;   
    }

    global void finish(Database.BatchableContext BC){

    }

	global void execute(SchedulableContext SC) 
	{		
		Id batchprocessid = Database.executeBatch(new BatchLeadFromAbandonedCart(),5);
	}     
   
}