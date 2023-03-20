@IsTest
public class BatchLeadFromAbandonedCartTest {
    /*
    static {
		TREX1__App_Config__c setting = new TREX1__App_Config__c();
		setting.TREX1__Max_Draft_Transaction_Age_Days__c = 1;
		insert setting;
	}*/

    @IsTest static void testBatchMinus1Day() {
        TREX1__Transaction__c trans = [SELECT Id, Createddate FROM TREX1__Transaction__c LIMIT 1];
        Test.setCreatedDate(trans.Id, System.now().addDays(-1));

        Test.startTest();
            new BatchLeadFromAbandonedCart().execute(null);
		Test.stopTest();
        List<Lead> leads = [SELECT Id FROM Lead];
        System.assertEquals(leads.size(), 1);  

    }

    @IsTest static void testBatchMinus23Hours() {
        TREX1__Transaction__c trans = [SELECT Id, Createddate FROM TREX1__Transaction__c LIMIT 1];
        Test.setCreatedDate(trans.Id, System.now().addHours(-23));

        Test.startTest();
            new BatchLeadFromAbandonedCart().execute(null);
		Test.stopTest();
        List<Lead> leads = [SELECT Id FROM Lead];
        System.assertEquals(leads.size(), 0);  

    }    

	@TestSetup static void methodName() {
		String phoneNumber = '1112223344';
		String firstName = 'Test';
		String lastName = 'Test';
		String email = 'tom@jones.com';
		Date birthdate = Date.today();

		Account testAcct = new Account();
		testAcct.Name = 'Test Account';
		insert testAcct;

		Contact testContact = new Contact();
		testContact.Phone = phoneNumber;
		testContact.FirstName = firstName;
		testContact.LastName = lastName;
		testContact.Email = email;
		testContact.Birthdate = birthdate;
		testContact.Account = testAcct;
		testContact.HasOptedOutOfEmail = true;
		insert testContact;

		// Below objs are required for Membership...
		TREX1__Membership_Category__c mbCategory = new TREX1__Membership_Category__c();
		insert mbCategory;

		TREX1__Membership_Type__c mbType = MindbodyTestDataFactory.insertAbleToSyncMembershipType(mbCategory);

		TREX1__Transaction__c trans = new TREX1__Transaction__c();
		trans.TREX1__Account__c = testAcct.Id;
		trans.TREX1__Contact__c = testContact.Id;
		trans.TREX1__Status__c = 'Draft';
		trans.TREX1__Created_Online__c = true;
		insert trans;

		// need membership categoryId on membershpi?
		// need start date, end date
		// double check the sync status before calling thing...
		TREX1__Membership__c membership = new TREX1__Membership__c();
		membership.TREX1__Type_ID__c = mbType.Id;
		membership.TREX1__Purchasing_Transaction__c = trans.Id;
		membership.TREX1__Start_Date__c = Date.today();
		membership.TREX1__End_Date__c = Date.today().addDays(14);
		membership.TREX1__Account__c = testAcct.Id;
		membership.TREX1__Contact__c = testContact.Id;
		insert membership;


        TREX1__Global_Billing_Group__c billingGroup = new TREX1__Global_Billing_Group__c(
            Name = 'Test Billing Group',
            TREX1__Community_Bill_To_Account__c = 'Enabled',
            TREX1__Monthly_Billing_Day__c = 1,
            TREX1__Public_Name__c = 'Test Billing Group'
        );
        insert billingGroup;


        TREX1__Product__c productDiscount = new TREX1__Product__c(
            Name = 'Test Product',
            TREX1__Billing_Cancellation_Credit_Setting__c = 'No Credit',
            TREX1__Global_Billing_Group__c = billingGroup.Id
        );
        insert productDiscount;        

        List<TREX1__Transaction_Line_Item__c> lineItems = new List<TREX1__Transaction_Line_Item__c>();

        // Create line items with different related objects populated
        TREX1__Transaction_Line_Item__c lineItem1 = new TREX1__Transaction_Line_Item__c(
            TREX1__Transaction__c = trans.Id,
            TREX1__Product__c = productDiscount.Id,
            TREX1__Contact__c = testContact.Id,
            TREX1__Net_Price__c = 100
        );
        lineItems.add(lineItem1);

        TREX1__Transaction_Line_Item__c lineItem2 = new TREX1__Transaction_Line_Item__c(
            TREX1__Transaction__c = trans.Id,
            TREX1__Contact__c = testContact.Id,
            TREX1__Product__c = productDiscount.Id,
            TREX1__Net_Price__c = 50
        );
        lineItems.add(lineItem2);

        TREX1__Registration__c registration = new TREX1__Registration__c(
            TREX1__Account__c = testAcct.Id,
            TREX1__Contact__c = testContact.Id,
            TREX1__Registration_Status__c = 'Draft'
        );
        insert registration;

        TREX1__Transaction_Line_Item__c lineItem3 = new TREX1__Transaction_Line_Item__c(
            TREX1__Transaction__c = trans.Id,
            TREX1__Product__c = productDiscount.Id,
            TREX1__Contact__c = testContact.Id,
            TREX1__Net_Price__c = 200,
            TREX1__Registration__c = registration.Id
        );
        lineItems.add(lineItem3);

        TREX1__Transaction_Line_Item__c lineItem4 = new TREX1__Transaction_Line_Item__c(
            TREX1__Transaction__c = trans.Id,
            TREX1__Product__c = productDiscount.Id,
            TREX1__Contact__c = testContact.Id,
            TREX1__Net_Price__c = 300,
            TREX1__Membership__c = membership.Id
        );
        lineItems.add(lineItem4);

        TREX1__Add_On__c addOn = new TREX1__Add_On__c();
        addOn.Name = 'Test Add-On';
        insert addOn;

        TREX1__Transaction_Line_Item__c lineItem5 = new TREX1__Transaction_Line_Item__c(
            TREX1__Transaction__c = trans.Id,
            TREX1__Product__c = productDiscount.Id,
            TREX1__Net_Price__c = 150,
            TREX1__Add_On__c = addOn.Id
        );
        lineItems.add(lineItem5);

        // Insert line items
        insert lineItems;
       
	}    

}