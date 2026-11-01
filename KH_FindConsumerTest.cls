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
            'https://apihub.stage.hallmark.com/hmk-care-eapi/hmkretail/consumers?consumerId=' +
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
                    '"lastUpdateDate": "8/25/2026 6:04:12 AM",' +
                    '"CapturedDt": "8/26/2026 8:04:12 AM",' +
                    '"sourceOfDataDesc": "consumer care profile",' +
                    '"phoneOptIn": "Y"' +
                '}]' +
            '}' +
        '}';
        
        // Set up the mock callout
       // Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockJsonResponse, 200));
       HttpCalloutMock mock = CEMS_HTTP_Callout_Mock.generateKHMock(
            'https://apihub.stage.hallmark.com/hmk-care-eapi/hmkretail/consumers?consumerId=123456789123&retrieveAllPhones=true',
            200,
            'OK',
            mockJsonResponse,
            200,
            'OK',
            CEMS_HTTP_Callout_Mock.createAccessTokenResponse(false)
        );

Test.setMock(HttpCalloutMock.class, mock);
        
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
    
    @IsTest
    static void testConvertUtcToCentral_DaylightSavingTime() {

        // August is CDT (UTC-5)
        String utcDateTime = '8/24/2026 8:58:17 AM';

        Test.startTest();

        String result = KH_FindConsumer.convertUtcToCentral(utcDateTime);

        Test.stopTest();

        System.assertEquals(
            '8/24/2026 3:58:17 AM',
            result,
            'UTC should be converted to Central Daylight Time (CDT)'
        );
    }

    @IsTest
    static void testConvertUtcToCentral_CST() {

        // January is CST (UTC-6)
        String utcDateTime = '1/15/2026 8:58:17 AM';

        Test.startTest();

        String result = KH_FindConsumer.convertUtcToCentral(utcDateTime);

        Test.stopTest();

        System.assertEquals(
            '1/15/2026 2:58:17 AM',
            result,
            'UTC should be converted to Central Standard Time (CST)'
        );
    }

     @IsTest
    static void testConvertUtcToCentral_PM() {

        String utcDateTime = '8/24/2026 8:58:17 PM';

        Test.startTest();

        String result = KH_FindConsumer.convertUtcToCentral(utcDateTime);

        Test.stopTest();

        System.assertEquals(
            '8/24/2026 3:58:17 PM',
            result,
            'PM UTC value should be correctly converted to Central Time'
        );
    }
    
    @IsTest
    static void testConvertUtcToCentral_12AM() {

        String utcDateTime = '8/24/2026 12:30:00 AM';

        Test.startTest();

        String result = KH_FindConsumer.convertUtcToCentral(utcDateTime);

        Test.stopTest();

        System.assertEquals(
            '8/23/2026 7:30:00 PM',
            result,
            '12 AM UTC should be correctly converted to previous day Central Time'
        );
    }

    @IsTest
    static void testConvertUtcToCentral_12PM() {

        String utcDateTime = '8/24/2026 12:30:00 PM';

        Test.startTest();

        String result = KH_FindConsumer.convertUtcToCentral(utcDateTime);

        Test.stopTest();

        System.assertEquals(
            '8/24/2026 7:30:00 AM',
            result,
            '12 PM UTC should be correctly converted to Central Time'
        );
    }

private static User createTestUser(String profileName) {

        Profile p = [
            SELECT Id, Name
            FROM Profile
            WHERE Name = :profileName
            LIMIT 1
        ];

        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Alias = 'tuser',
            Email = 'test' + System.currentTimeMillis() + '@example.com',
            Username = 'test' + System.currentTimeMillis() + '@example.com',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Chicago',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );

        insert u;
        return u;
    }
    
    @IsTest
    static void testAllowedProfile_SystemAdministrator() {

        User testUser = createTestUser('System Administrator');

        Test.startTest();

        Boolean result;

        System.runAs(testUser) {
            result = KH_FindConsumer.canCurrentUserViewHdxRef();
        }

        Test.stopTest();

        System.assertEquals(
            true,
            result,
            'System Administrator should be allowed to view HDX Ref'
        );
    }
    
    @IsTest
    static void testNotAllowedProfile() {

        // Standard User is normally not in the allowed profile list
        User testUser = createTestUser('Standard User');

        Test.startTest();

        Boolean result;

        System.runAs(testUser) {
            result = KH_FindConsumer.canCurrentUserViewHdxRef();
        }

        Test.stopTest();

        System.assertEquals(
            false,
            result,
            'User with a non-allowed profile should not be allowed to view HDX Ref'
        );
    }
    
    @IsTest
    static void testTranslateSourceDesc() {

        // Consumer Care Profile
        System.assertEquals(
            'CareTools',
            KH_FindConsumer.translateSourceDesc('Consumer Care Profile')
        );

        System.assertEquals(
            'CareTools',
            KH_FindConsumer.translateSourceDesc('CONSUMER CARE PROFILE')
        );


        // Cards Now Recipient
        System.assertEquals(
            'eCards Recipient',
            KH_FindConsumer.translateSourceDesc('Cards Now Recipient')
        );

        System.assertEquals(
            'eCards Recipient',
            KH_FindConsumer.translateSourceDesc('CARDS NOW RECIPIENT ')
        );


        // Cards Now Sender
        System.assertEquals(
            'Hallmark Cards Now App',
            KH_FindConsumer.translateSourceDesc('Cards Now Sender')
        );

        System.assertEquals(
            'Hallmark Cards Now App',
            KH_FindConsumer.translateSourceDesc('CARDS NOW SENDER')
        );


        // Digital Greetings Web Recipient
        System.assertEquals(
            'eCard Recipient',
            KH_FindConsumer.translateSourceDesc('Digital Greetings Web Recipient')
        );

        System.assertEquals(
            'eCard Recipient',
            KH_FindConsumer.translateSourceDesc('DIGITAL GREETINGS WEB RECEIPIENT')
        );


        // Digital On-the-Fly Email
        System.assertEquals(
            'Hallmark.com Connect with us',
            KH_FindConsumer.translateSourceDesc('Digital On-the-Fly Email')
        );

        System.assertEquals(
            'Hallmark.com Connect with us',
            KH_FindConsumer.translateSourceDesc('DIGITIAL ON-THE-FLY EMAIL')
        );


        // Digital Profile
        System.assertEquals(
            'Hallmark.com Profile',
            KH_FindConsumer.translateSourceDesc('Digital Profile')
        );

        System.assertEquals(
            'Hallmark.com Profile',
            KH_FindConsumer.translateSourceDesc('DIGITAL PROFILE')
        );


        // Video Greetings
        System.assertEquals(
            'Video Greetings Website',
            KH_FindConsumer.translateSourceDesc('Video Greetings')
        );

        System.assertEquals(
            'Video Greetings Website',
            KH_FindConsumer.translateSourceDesc('VIDEO GREETINGS')
        );


        // Point of Sale Profile
        System.assertEquals(
            'Gold Crown Store',
            KH_FindConsumer.translateSourceDesc('Point of Sale Profile')
        );

        System.assertEquals(
            'Gold Crown Store',
            KH_FindConsumer.translateSourceDesc('POINT OF SALE PROFILE')
        );


        // Point of Sale Transaction
        System.assertEquals(
            'Gold Crown Store',
            KH_FindConsumer.translateSourceDesc('Point of Sale Transaction')
        );

        System.assertEquals(
            'Gold Crown Store',
            KH_FindConsumer.translateSourceDesc('POINT OF SALE TRANSACTION')
        );


        // Retailer Crown Rewards Gateway Profile
        System.assertEquals(
            'Gold Crown Store',
            KH_FindConsumer.translateSourceDesc(
                'Retailer Crown Rewards Gateway Profile'
            )
        );

        System.assertEquals(
            'Gold Crown Store',
            KH_FindConsumer.translateSourceDesc(
                'RETAILER CROWN REWARDS GATEWAY PROFILE'
            )
        );


        // Retailer Crown Rewards Gateway Transaction
        System.assertEquals(
            'Gold Crown Store',
            KH_FindConsumer.translateSourceDesc(
                'Retailer Crown Rewards Gateway Transaction'
            )
        );

        System.assertEquals(
            'Gold Crown Store',
            KH_FindConsumer.translateSourceDesc(
                'RETAILER CROWN REWARDS GATEWAY TRANSACTION'
            )
        );


        // Salesforce Marketing Cloud Opts and Bounces
        System.assertEquals(
            'Consumer Email Unsubscribe/Failed Email Delivery',
            KH_FindConsumer.translateSourceDesc(
                'Salesforce Marketing Cloud Opts and Bounces'
            )
        );

        System.assertEquals(
            'Consumer Email Unsubscribe/Failed Email Delivery',
            KH_FindConsumer.translateSourceDesc(
                'SALESFORCE MARKETING CLOUD OPTS AND BOUNCES'
            )
        );


        // Sproutloud Opts and Bounces
        System.assertEquals(
            'Local Marketing System',
            KH_FindConsumer.translateSourceDesc(
                'Sproutloud Opts and Bounces'
            )
        );

        System.assertEquals(
            'Local Marketing System',
            KH_FindConsumer.translateSourceDesc(
                'SPROUTLOUD OPTS AND BOUNCES'
            )
        );


        // KOC Admin
        System.assertEquals(
            'KOC Enrollment',
            KH_FindConsumer.translateSourceDesc('KOC Admin')
        );

        System.assertEquals(
            'KOC Enrollment',
            KH_FindConsumer.translateSourceDesc('KOC ADMIN')
        );


        // Paperstore Profile
        System.assertEquals(
            'Gold Crown Store: TPS',
            KH_FindConsumer.translateSourceDesc('Paperstore Profile')
        );

        System.assertEquals(
            'Gold Crown Store: TPS',
            KH_FindConsumer.translateSourceDesc('PAPERSTORE PROFILE')
        );


        // Shared Email Updates
        System.assertEquals(
            'Shared Email Updates',
            KH_FindConsumer.translateSourceDesc('Shared Email Updates')
        );

        System.assertEquals(
            'Shared Email Updates',
            KH_FindConsumer.translateSourceDesc('SHARED EMAIL UPDATES')
        );


        // hplus on hmn.com
        System.assertEquals(
            'Hallmarkplus.com or Hallmark+ App',
            KH_FindConsumer.translateSourceDesc('hplus on hmn.com')
        );

        System.assertEquals(
            'Hallmarkplus.com or Hallmark+ App',
            KH_FindConsumer.translateSourceDesc('HPLUS ON HMN.COM')
        );


        // hplus on hmk.com
        System.assertEquals(
            'Hallmark.com Profile',
            KH_FindConsumer.translateSourceDesc('hplus on hmk.com')
        );

        System.assertEquals(
            'Hallmark.com Profile',
            KH_FindConsumer.translateSourceDesc('HPLUS ON HMK.COM')
        );


        // hplus pre load
        System.assertEquals(
            'Hmnow.com or HMN App',
            KH_FindConsumer.translateSourceDesc('hplus pre load')
        );

        System.assertEquals(
            'Hmnow.com or HMN App',
            KH_FindConsumer.translateSourceDesc('HPLUS PRE LOAD')
        );


        // ELSE condition
        System.assertEquals(
            'Unknown Source',
            KH_FindConsumer.translateSourceDesc('Unknown Source')
        );
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
    

    
    @IsTest
    static void testGetCurrentUserProfile() {
    
        Test.startTest();
        String profileName = KH_FindConsumer.getCurrentUserProfile();
        Test.stopTest();
    
        System.assertNotEquals(null, profileName);
        System.assertEquals(
            [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId()].Name,
            profileName
        );
    }
    
    @IsTest
    static void testHasCareAdminPS() {
    
        PermissionSet ps = [
            SELECT Id
            FROM PermissionSet
            WHERE Name='Care_Admin'
            LIMIT 1
        ];
    
        insert new PermissionSetAssignment(
            AssigneeId = UserInfo.getUserId(),
            PermissionSetId = ps.Id
        );
    
        Test.startTest();
    
        Boolean result = KH_FindConsumer.hasCareAdmin_PS();
    
        Test.stopTest();
    
        System.assertEquals(true,result);
    }
    
    @IsTest
    static void testHasCareAdminPSFalse() {
    
        Test.startTest();
    
        Boolean result = KH_FindConsumer.hasCareAdmin_PS();
    
        Test.stopTest();
    
        System.assertEquals(false,result);
    }
    
    @isTest
static void testRemovePhoneFormat() {

    System.assertEquals(
        '6515544977',
        KH_FindConsumer.removePhoneFormat('(651) 554-4977'));

    System.assertEquals(
        '1234567890',
        KH_FindConsumer.removePhoneFormat('123-456-7890'));

    System.assertEquals(
        '9999999999',
        KH_FindConsumer.removePhoneFormat('(999) 999 9999'));
}
    @isTest
static void testGetConsumerCID_Null() {

    Test.startTest();

    String cid = KH_FindConsumer.getConsumerCID(null);

    Test.stopTest();

    System.assertEquals('', cid);
}
    

  	@isTest
    static void getDuplicateKnowHerConsumers_Test() {
        
        StaticTriggerVariables.StopAccountTrigger = true;
        
        Account account = [
            SELECT
            Id,
            FirstName,
            LastName,
            PersonEmail,
            PersonHomePhone,
            Mailing_Zip_Postal_Code__c
            FROM Account
            LIMIT 1
        ];
        
        account.FirstName =
            'ADELAIDE';
        
        account.LastName =
            'MALONEY';
        
        account.PersonHomePhone =
            '6515544977';
        
        account.PersonEmail =
            'CHUCKCANDY@WORLDNET.ATT.NET';
        
        account.Mailing_Zip_Postal_Code__c =
            '55076';
        
        update account;
        
        
        /*
* KH returns two matching consumers.
*/
        String mockResponse =
            '{"Errors":[],' +
            '"Result":{' +
            '"numberOfResults":"2",' +
            '"consumers":[' +
            
            '{' +
            '"consumerId":"123456789001",' +
            
            '"name":{' +
            '"firstName":"ADELAIDE",' +
            '"middleInitial":"",' +
            '"lastName":"MALONEY"' +
            '},' +
            
            '"address":{' +
            '"addressLine1":"123 Main St",' +
            '"addressLine2":"Apt 1",' +
            '"city":"Chicago",' +
            '"state":"IL",' +
            '"zip":"55076",' +
            '"country":"USA"' +
            '},' +
            
            '"phone":{' +
            '"homeNumber":"6515544977",' +
            '"mobileNumber":"6515551111"' +
            '},' +
            
            '"email":{' +
            '"address":"CHUCKCANDY@WORLDNET.ATT.NET"' +
            '},' +
            
            '"dateOfBirth":"12131989",' +
            
            '"memberships":[' +
            '{' +
            '"membershipType":"Crown Rewards",' +
            '"id":"927128861010"' +
            '}' +
            ']' +
            '},' +
            
            '{' +
            '"consumerId":"123456789002",' +
            
            '"name":{' +
            '"firstName":"ADELAIDE",' +
            '"middleInitial":"",' +
            '"lastName":"MALONEY"' +
            '},' +
            
            '"address":{' +
            '"addressLine1":"456 Second St",' +
            '"addressLine2":"",' +
            '"city":"Chicago",' +
            '"state":"IL",' +
            '"zip":"55076",' +
            '"country":"USA"' +
            '},' +
            
            '"phone":{' +
            '"homeNumber":"6515544977",' +
            '"mobileNumber":"6515552222"' +
            '},' +
            
            '"email":{' +
            '"address":"CHUCKCANDY@WORLDNET.ATT.NET"' +
            '},' +
            
            '"dateOfBirth":"01041990",' +
            
            '"memberships":[' +
            '{' +
            '"membershipType":"Crown Rewards",' +
            '"id":"927128861011"' +
            '}' +
            ']' +
            '}' +
            
            ']' +
            '}}';
        
        
        Test.setMock(
            HttpCalloutMock.class,
            new DuplicateConsumerRoutingMock(
                mockResponse
            )
        );
        
        
        Test.startTest();
        
        List<KH_ConsumerMergeWrapper> results =
            KH_FindConsumer.getDuplicateKnowHerConsumers(
                account.Id
            );
        
        Test.stopTest();
        
        
        System.assertNotEquals(
            null,
            results,
            'Results should not be null.'
        );
        
        System.assertEquals(
            2,
            results.size(),
            'Two KH duplicate consumers should be returned.'
        );
        
        
        /*
* First consumer
*/
        KH_ConsumerMergeWrapper consumer1 =
            results[0];
        
        System.assertEquals(
            'CCDB',
            consumer1.source
        );
        
        System.assertEquals(
            '123456789001',
            consumer1.CID
        );
        
        System.assertEquals(
            'ADELAIDE',
            consumer1.firstName
        );
        
        System.assertEquals(
            'MALONEY',
            consumer1.lastName
        );
        
        System.assertEquals(
            'CHUCKCANDY@WORLDNET.ATT.NET',
            consumer1.email
        );
        
        System.assertEquals(
            '6515544977',
            consumer1.phone
        );
        
        System.assertEquals(
            '6515551111',
            consumer1.mobilePhone
        );
        
        System.assertEquals(
            '55076',
            consumer1.postalCode
        );
        
        System.assertEquals(
            '123 Main St Apt 1',
            consumer1.mailingStreet
        );
        
        System.assertEquals(
            'December 13',
            consumer1.birthday
        );
        
        System.assertEquals(
            '927128861010',
            consumer1.memberId
        );
        
        
        /*
* Second consumer
*/
        KH_ConsumerMergeWrapper consumer2 =
            results[1];
        
        System.assertEquals(
            '123456789002',
            consumer2.CID
        );
        
        System.assertEquals(
            '456 Second St',
            consumer2.mailingStreet
        );
        
        System.assertEquals(
            'January 04',
            consumer2.birthday
        );
        
        System.assertEquals(
            '927128861011',
            consumer2.memberId
        );
    }
    private class DuplicateConsumerRoutingMock
        implements HttpCalloutMock {
            
            private String khResponseBody;
            
            DuplicateConsumerRoutingMock(
                String khResponseBody
            ) {
                this.khResponseBody =
                    khResponseBody;
            }
            
            public HttpResponse respond(
                HttpRequest req
            ) {
                
                HttpResponse res =
                    new HttpResponse();
                
                String endpoint =
                    req.getEndpoint() == null
                    ? ''
                    : req.getEndpoint().toLowerCase();
                
                String requestBody =
                    req.getBody() == null
                    ? ''
                    : req.getBody().toLowerCase();
                
                
                /*
* First callout:
* OAuth access token
*/
                if (
                    endpoint.contains('oauth') ||
                    endpoint.contains('accesstoken') ||
                    endpoint.contains('/token') ||
                    requestBody.contains(
                        'grant_type=client_credentials'
                    )
                ) {
                    
                    res.setStatusCode(200);
                    res.setStatus('OK');
                    
                    res.setBody(CEMS_HTTP_Callout_Mock.createAccessTokenResponse(false));
                    
                    return res;
                }
                
                
                /*
* Second callout:
* KH consumer GET
*/
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody(
                    khResponseBody
                );
                
                return res;
            }
        }

    
}