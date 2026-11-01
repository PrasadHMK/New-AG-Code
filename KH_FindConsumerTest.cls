/**
* 22/06/2022 - Adeel Ahmad
* Test class for KH_FindConsumer
*/
@isTest
public class KH_FindConsumerTest {
    
    @TestSetup
    public static void setupTestData() {
        StaticTriggerVariables.StopAccountTrigger = true;
        ObjectCreator.cemsConnectionCreator();
        
        List<Account> acctList = ObjectCreator.accountCreator('TestConsumer', 1, 'Consumer');
        Account acc = acctList[0];
        acc.CID__c = '123456789123';
        acc.PersonEmail = 'test@hallmark.com';
        update acc;
        
        ObjectCreator.subscriptionCreator(1, acc.Id);
    }


   public static testMethod void CEMS_CreateConsumerController_Test() {
        Account acctFound = [SELECT Id, CID__c FROM Account LIMIT 1];
        acctFound.CID__c = '123456789123';
        update acctFound;
        
        Account acctCreated = new Account(FirstName = 'Lappo', LastName = 'Quapo', CID__c = '123456789789');
        
        Test.startTest();
        StaticTriggerVariables.StopAccountTrigger = true;
        KH_FindConsumer.createConsumerController(acctFound);
        KH_FindConsumer.createConsumerController(acctCreated);
        Test.stopTest();
    }
    
    public static testMethod void KH_checkCEMS(){
        Account account = [SELECT Id, CID__c, Crown_Rewards_Number__c, FirstName, LastName, PersonEmail, PersonHomePhone,
                           Address_Line_1__c,
                           Address_Line_2__c,
                           Mailing_Country__c,
                           Mailing_City__c,
                           Mailing_State_Province__c,
                           Mailing_Zip_Postal_Code__c,
                           PersonBirthdate,
                           UUID__c
                           FROM Account LIMIT 1];
        Subscription__c subFound = [SELECT Id, Subscription_Id__c FROM Subscription__c LIMIT 1];
        account.CID__c = '123456789123';
        account.FirstName = 'ADELAIDE';
        account.LastName = 'MALONEY';
        account.PersonHomePhone = '6515544977';
        account.Address_Line_1__c = '123 Dr';
        account.Address_Line_2__c = 'Unit 1';
        account.Mailing_City__c = 'KS City';
        account.Mailing_Country__c = 'US';
        account.Mailing_Zip_Postal_Code__c = '55076';
        account.PersonEmail = 'CHUCKCANDY@WORLDNET.ATT.NET';
        account.Crown_Rewards_Number__c = '927128861010';
        account.PersonBirthdate = System.today() - 999;
        
        update account;
        
        subFound.Subscription_Id__c = account.Crown_Rewards_Number__c;
        update subFound;
        
        HttpCalloutMock getConsumerIdCallouts = CEMS_HTTP_Callout_Mock.generateKHMock(
            'https://apicloud-qa.hallmark.com/secure/hmk-care-knowher-exp-api-qa/api/v1/hmkretail/consumers?consumerId=' +
            account.CID__c +
            '&homePhone=' +
            account.PersonHomePhone +
            '&email=' +
            account.PersonEmail +
            '&firstName=' +
            account.FirstName +
            '&lastName=' +
            account.LastName +
            '&zip=' +
            account.Mailing_Zip_Postal_Code__c +
            '&memberId=' +
            account.Crown_Rewards_Number__c,
            200,
            'OK',
            CEMS_HTTP_Callout_Mock.createGETResponse(false, false),
            200,
            'OK',
            CEMS_HTTP_Callout_Mock.createAccessTokenResponse(false)
        );
        Test.setMock(HttpCalloutMock.class, getConsumerIdCallouts);
        
        Test.startTest(); 
        StaticTriggerVariables.StopAccountTrigger = true;
        KH_FindConsumer.checkSalesforce(account, MockIdBuilder.getMockId(Account.getSObjectType()));                
        KH_FindConsumer.checkSalesforce(account, '1235');                        
        KH_FindConsumer.updateConsumerCallGUID(account.Id, '01757133-d12a-4239-a462-e909669357dd');        
        KH_FindConsumer.updateConsumerCallGUID(null, '01757133-d12a-4239-a462-e909669357dd');        
        KH_FindConsumer.checkCEMS(account);
        //KH_FindConsumer.doTestCoverage();
        Test.stopTest();
    }

    public static testMethod void getCurrentUserProfile_Test(){
        Test.startTest();
        String userProfile = KH_FindConsumer.getCurrentUserProfile();
        Test.stopTest();
    }

    public static testMethod void getConsumerCID_Test(){
        Account acctFound = [SELECT Id, CID__c FROM Account LIMIT 1];
        acctFound.CID__c = '123456789123';
        update acctFound;
        
        Test.startTest();
        String consumerCID = KH_FindConsumer.getConsumerCID(acctFound.Id);
        Test.stopTest();
    }
    
     public static testMethod void getConsumerEmails_pos1_Test(){
        Account acctFound = [SELECT Id, CID__c FROM Account LIMIT 1];
        acctFound.CID__c = '123456789123';
        update acctFound;
        SingleRequestMock fakeResponse = new SingleRequestMock(200,
                                                               'Complete',
                                                               '{   "Status": "SUCCESS",   "StatusMessage": "The request has been accepted. Email/s delete is pending." } ',
                                                               null);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, fakeResponse);
        List<CareConsumerEmails_Wrapper.Emails> consumerEmails = KH_FindConsumer.getConsumerEmails(acctFound.CID__c);
        Test.stopTest();
    }
    public static testMethod void getConsumerEmails_neg_Test(){
        Account acctFound = [SELECT Id, CID__c FROM Account LIMIT 1];
        acctFound.CID__c = '123456789123';
        update acctFound;
        SingleRequestMock fakeResponse = new SingleRequestMock(500,
                                                               'Complete',
                                                               '{   "Status": "ERROR",   "StatusMessage": "The request has been accepted. Email/s delete is pending." } ',
                                                               null);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, fakeResponse);
        List<CareConsumerEmails_Wrapper.Emails> consumerEmails = KH_FindConsumer.getConsumerEmails(acctFound.CID__c);
        Test.stopTest();
    }
    public static testMethod void getConsumerEmails_neg1_Test(){
        Account acctFound = [SELECT Id, CID__c FROM Account LIMIT 1];
        acctFound.CID__c = '123456789123';
        update acctFound;
        SingleRequestMock fakeResponse = new SingleRequestMock(1,
                                                               'Complete',
                                                               '{   "Status": "ERROR",   "StatusMessage": "The request has been accepted. Email/s delete is pending." } ',
                                                               null);
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, fakeResponse);
        List<CareConsumerEmails_Wrapper.Emails> consumerEmails = KH_FindConsumer.getConsumerEmails(acctFound.CID__c);
        Test.stopTest();
    }
    
    public static testMethod void deleteEmails_pos1_Test(){
        Account acctFound = [SELECT Id, CID__c FROM Account LIMIT 1];
        acctFound.CID__c = '123456789123';
        update acctFound;
        SingleRequestMock fakeResponse = new SingleRequestMock(200,
                                                               'Complete',
                                                               '{   "Status": "SUCCESS",   "StatusMessage": "The request has been accepted. Email/s delete is pending." } ',
                                                               null);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, fakeResponse);
        String responseStatus = KH_FindConsumer.deleteEmails(acctFound.CID__c, 'test@test.com');
        Test.stopTest();
    }
    public static testMethod void deleteEmails_neg1_Test(){
        Account acctFound = [SELECT Id, CID__c FROM Account LIMIT 1];
        acctFound.CID__c = '123456789123';
        update acctFound;
        SingleRequestMock fakeResponse = new SingleRequestMock(500,
                                                               'Complete',
                                                               '{   "Status": "SUCCESS",   "StatusMessage": "The request has been accepted. Email/s delete is pending." } ',
                                                               null);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, fakeResponse);
        String responseStatus = KH_FindConsumer.deleteEmails(acctFound.CID__c, 'test@test.com');
        Test.stopTest();
    }
    public static testMethod void deleteEmails_neg2_Test(){
        Account acctFound = [SELECT Id, CID__c FROM Account LIMIT 1];
        acctFound.CID__c = '123456789123';
        update acctFound;
        SingleRequestMock fakeResponse = new SingleRequestMock(1,
                                                               'Complete',
                                                               '{   "Status": "SUCCESS",   "StatusMessage": "The request has been accepted. Email/s delete is pending." } ',
                                                               null);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, fakeResponse);
        String responseStatus = KH_FindConsumer.deleteEmails(acctFound.CID__c, 'test@test.com');
        Test.stopTest();
    }
//Raghav - 2003 start    
     public static testMethod void testGetConsumerPhones(){
        Account acctRec = [SELECT Id, CID__c FROM Account LIMIT 1];
        acctRec.CID__c = '123456789123';
        acctRec.PersonHomePhone = '1234567890';
        update acctRec;
          // Mock HTTP response for successful phone retrieval
        String mockJsonResponse = '{' +
            '"status": "SUCCESS",' +
            '"statusMessage": "Phones retrieved successfully",' +
            '"Errors": [],' +
            '"Result": {' +
                '"consumerId": 123456789123,' +
                '"numberOfPhones": 1,' +
                '"phones": [{' +
                    '"phone": "1234567890",' +
                    '"phoneType": "HOME",' +
                    '"dfltInd": "Y",' +
                    '"internationalPrefix": "",' +
                    '"lastUpdateDate": "2025-02-26",' +
                    '"CapturedDt": "2025-02-25",' +
                    '"sourceOfDataDesc": "consumer care profile",' +
                    '"phoneOptIn": "Y"' +
                '}]' +
            '}' +
        '}';
        
        // Set up the mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockJsonResponse, 200));
        
        // Start the test
        Test.startTest();
        List<CareConsumerPhones_Wrapper.Phones> result = KH_FindConsumer.getConsumerPhones(acctRec.CID__c);        
        // Stop the test
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Result should not be null');
        //CareConsumerPhones_Wrapper.Phones phone = result[0];
        //System.assertEquals('1234567890', phone.phone, 'Phone number should match');
    }
    
       // Test method for deletePhones
    @isTest
    static void testDeletePhones() {
        // Retrieve the test account
        Account testAccount = [SELECT Id, CID__c FROM Account LIMIT 1];
        testAccount.CID__c = '123456789123';
        testAccount.PersonHomePhone = '1234567890';
        update testAccount;
        // Mock HTTP response for successful deletion
        String mockJsonResponse = '{' +
            '"Status": "SUCCESS",' +
            '"StatusMessage": "Phones deleted successfully"' +
        '}';
        
        // Set up the mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockJsonResponse, 200));        
        // Prepare the phones list to delete
        String phonesList = '{"phone": "1234567890", "phoneType": "HOME"}';        
        // Start the test
        Test.startTest();        
        String result = KH_FindConsumer.deletePhones(testAccount.CID__c, phonesList);        
        // Stop the test
        Test.stopTest();
        
        // Assertions
        //System.assertEquals('SUCCESS', result, 'Deletion should return SUCCESS');
    }
    
    // Test method for deletePhones with error response
    @isTest
    static void testDeletePhonesError() {
        // Retrieve the test account
        Account testAccount = [SELECT Id, CID__c FROM Account LIMIT 1];
        testAccount.CID__c = '123456789123';
        testAccount.PersonHomePhone = '1234567890';
        update testAccount;        
        // Mock HTTP response for error scenario
        String mockJsonResponse = '{' +
            '"Status": "ERROR",' +
            '"StatusMessage": "Failed to delete phones"' +
        '}';
        
        // Set up the mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockJsonResponse, 500));
        
        // Prepare the phones list to delete
        String phonesList = '{"phone": "1234567890", "phoneType": "HOME"}';
        
        // Start the test
        Test.startTest();        
        String result = KH_FindConsumer.deletePhones(testAccount.CID__c, phonesList);        
        // Stop the test
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Result should not be null');
    }   
     // Test method for getConsumerPhones with error response
    @isTest
    static void testGetConsumerPhonesError() {
        Account testAccount = [SELECT Id, CID__c FROM Account LIMIT 1];
        testAccount.CID__c = '123456789123';
        testAccount.PersonHomePhone = '1234567890';
        update testAccount;
        
        // Mock HTTP response for error scenario
        String mockJsonResponse = '{' +
            '"status": "ERROR",' +
            '"statusMessage": "Failed to retrieve phones",' +
            '"Errors": [{"ErrorCode": "500", "ErrorMessage": "Internal Server Error"}]' +
        '}';
        
        // Set up the mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockJsonResponse, 500));
        
        // Start the test
        Test.startTest();        
        List<CareConsumerPhones_Wrapper.Phones> result = KH_FindConsumer.getConsumerPhones(testAccount.CID__c);        
        // Stop the test
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Should return no phone records on error');
    } 
  //Raghav - 2003 end 

    // ==================== NEW TESTS FOR EMAIL PREFERENCES ====================

    @isTest
    static void testGetConsumerEmailPrefs_Success() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        String mockResponse = '{' +
            '"Result": {' +
                '"consumers": [{' +
                    '"consumerId": "123456789123",' +
                    '"communicationPreferences": {' +
                        '"emailPreferences": {' +
                            '"deliveryContactPoint": "test@hallmark.com",' +
                            '"preferences": [' +
                                '{"prfTypeId":10,"prfSts":true,"prfSourceOfDataDesc":"CONSUMER CARE PROFILE"}' +
                            ']' +
                        '}' +
                    '}' +
                '}]' +
            '}' +
        '}';
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse, 200));
        
        Test.startTest();
        CareConEmailPrefGETWrapper result = KH_FindConsumer.getConsumerEmailPrefs(acc.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetConsumerEmailPrefs_Error() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('{}', 500));
        
        Test.startTest();
        CareConEmailPrefGETWrapper result = KH_FindConsumer.getConsumerEmailPrefs(acc.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testSaveConsumerEmailPrefs_Success() {
        Account acc = [SELECT Id, CID__c FROM Account LIMIT 1];
        
        List<KH_FindConsumer.UpdatedEmailPreferenceWrapper> prefs = new List<KH_FindConsumer.UpdatedEmailPreferenceWrapper>();
        KH_FindConsumer.UpdatedEmailPreferenceWrapper pref = new KH_FindConsumer.UpdatedEmailPreferenceWrapper();
        pref.prfTypeId = 10;
        pref.value = true;
        prefs.add(pref);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('{"status":200}', 200));
        
        Test.startTest();
        KH_FindConsumer.APIResponseWrapper result = KH_FindConsumer.saveConsumerEmailPrefs(
            acc.Id, acc.CID__c, 'test@hallmark.com', prefs
        );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testTranslateSource() {
        System.assertEquals('CareTools', KH_FindConsumer.translateSource('Consumer Care Profile'));
        System.assertEquals('Preference Page', KH_FindConsumer.translateSource('Email Preference Center'));
        System.assertEquals('Hallmark Channel', KH_FindConsumer.translateSource('Hallmark Channel Sign-Up'));
    }

    // Mock Class
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        private String body;
        private Integer statusCode;
        
        public MockHttpResponseGenerator(String body, Integer statusCode) {
            this.body = body;
            this.statusCode = statusCode;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setBody(this.body);
            res.setStatusCode(this.statusCode);
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
}
