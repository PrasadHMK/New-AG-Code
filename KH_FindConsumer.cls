/*
* Created Date : 17/05/2022
* Adeel Ahmad - Hallmark
* Description : Controller class to find consumer from Know Her
* @Updates : 24/11/2022 - Adeel - Setting up as without sharing because Account + needs to be removed. (CARE-47)
*/
public without sharing class KH_FindConsumer {
    private static final Map<String, String> SOURCE_MAPPINGS = new Map<String, String>{
        'consumer care profile' => 'CareTools',
        'cards now recipient' => 'eCards Recipient',
        'cards now sender' => 'Hallmark Cards Now App',
        'digital greetings web recipient' => 'eCard Recipient',
        'digital profile' => 'Hallmark.com Profile',
        'point of sale profile' => 'Gold Crown Store',
        'point of sale transaction' => 'Gold Crown Store',
        'retailer crown rewards gateway profile' => 'Gold Crown Store',
        'retailer crown rewards gateway transaction' => 'Gold Crown Store',
        'salesforce marketing cloud opts and bounces' => 'Consumer Phone Unsubscribe/Failed Phone Delivery',
        'sproutloud opts and bounces' => 'Local Marketing System',
        'koc admin' => 'KOC Enrollment',
        'paperstore profile' => 'Gold Crown Store: TPS'
    };
    //Raghav Care - 3406
    private static final Map<String, String> SOURCE_TRANSLATIONS = new Map<String, String>{
        // Existing
        'consumer care profile'                       => 'CareTools',
        'cards now recipient'                         => 'eCards Recipient',
        'cards now sender'                            => 'Hallmark Cards Now App',
        'digital greetings web recipient'             => 'eCard Recipient',
        'digital on-the-fly email'                    => 'Hallmark.com Connect with us',
        'digital profile'                             => 'Hallmark.com Profile',
        'video greetings'                             => 'Video Greetings Website',
        'point of sale profile'                       => 'Gold Crown Store',
        'point of sale transaction'                   => 'Gold Crown Store',
        'retailer crown rewards gateway profile'      => 'Gold Crown Store',
        'retailer crown rewards gateway transaction'  => 'Gold Crown Store',
        'paperstore profile'                          => 'Gold Crown Store: TPS',
        'shared email updates'                        => 'Shared Email Updates',
        'koc admin'                                   => 'KOC Enrollment',
        'hplus on hmn.com'                            => 'Hallmarkplus.com or Hallmark+ App',
        'hplus on hmk.com'                            => 'Hallmark.com Profile',
        'hplus pre load'                              => 'Hmnow.com or HMN App',

        // New Requirement
        'email preference center'                     => 'Preference Page',
        'dayspring migration'                         => 'DaySpring',
        'mahogany onboarding'                         => 'Mahogany',
        'hallmark channel migration'                  => 'Hallmark Channel',
        'hallmark channel sign-up'                    => 'Hallmark Channel',
        'salesforce marketing cloud opts and bounces'=> 'Hallmark Unsubscribe/Bounce',
        'sproutloud opts and bounces'                 => 'Local Retailer Unsubscribe/Bounce'
    };
    @AuraEnabled
    public static String createConsumerController(Account consumerRecord) {
        String consumerId = null;
        //If a record was received from the component, continue
        if (consumerRecord != null) {
            String secureCID = null;
            
            if (consumerRecord.CID__c != null) {
                secureCID = String.escapeSingleQuotes(consumerRecord.CID__c);
            }
            system.debug('??secureCID'+secureCID);
            List<Account> consumerList = new List<Account>();
            if (secureCID != null) {
                consumerList = [SELECT Id, CallGuid__c FROM Account WHERE CID__c = :secureCID AND isPersonAccount = TRUE LIMIT 1];
            }
            if (consumerList.isEmpty()) {
                Savepoint spRollback = Database.setSavepoint();
                Database.DMLOptions dml = new Database.DMLOptions();
                dml.DuplicateRuleHeader.AllowSave = true;
                consumerRecord.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Care - Consumer Account').getRecordTypeId();
                try {
                    Database.SaveResult sr = database.insert(consumerRecord, dml);
                    System.debug('@@sr='+sr);
                } catch (Exception e) {
                    Universal_Error_Logger.auraGenerateErrorLog('Consumer record could not be created.', 'KH_FindConsumer', e.getMessage());
                    Database.rollback(spRollback);
                    return consumerId;
                }
                consumerId = consumerRecord.Id;
                return consumerId;
            } else {
                //If we found a matching consumer record in SF, just pop that record instead of making a new record
                consumerId = consumerList[0].Id;
                return consumerId;
            }
        }
        return consumerId;
    }
    
    //Method called to update CallGUID on a consumer record.
    //21/07/2022 - Adeel - Update method to stamp the callGUID on account.
    @AuraEnabled
    public static String updateConsumerCallGUID(Id recordId, String callGUID) {
        String returnStr = 'SUCCESS';
        Savepoint spRollback = Database.setSavepoint();
        try{
            Account updateable = [SELECT Id FROM Account WHERE Id=:recordId];
            Database.DMLOptions dml = new Database.DMLOptions();
            dml.DuplicateRuleHeader.AllowSave = true;
            
            updateable.CallGuid__c = callGUID;
            database.update(updateable, dml);
        }catch(Exception e){
            returnStr = e.getMessage();
            Universal_Error_Logger.auraGenerateErrorLog(
                'Consumer record CallGuid__c could not be updated.',
                'KH_FindConsumer',
                e.getMessage()
            );
            Database.rollback(spRollback);
        }
        return returnStr;
    }
    
    //07/11/2022 - Method to convert phone number (remove format)
    public static String removePhoneFormat(String phone){
        String formattedPhone = phone.replace(' ', '').replace(')', '').replace('(', '').replace('-', '');
        return formattedPhone;
    }
    
    //This method produces a dynamic query based on the users input to find out if there are any matching consumers within Salesforce
    //Consumer record will be created from UI with FirstName, LastName, Email, Zip, etc
    @AuraEnabled
    public static List<KH_ConsumerMergeWrapper> checkSalesforce(Account consumerRecord, String acctId) {
        
        //Naeem: added the below change temporarily to fix the email search issue that contains + sign in it.
        if (String.isNotBlank(consumerRecord.PersonEmail)) {
            String tempPersonEmail = consumerRecord.PersonEmail;
            if(tempPersonEmail.contains('+')){
                String target = '+';
                String replacement = '%2B';
                consumerRecord.PersonEmail = tempPersonEmail.replace(target, replacement);
            }
        }
        //
            
        List<Account> consumerRecords = null;
        List<KH_ConsumerMergeWrapper> mergedRecords = new List<KH_ConsumerMergeWrapper>();
        Set<String> consumerCIDs = new Set<String>();
        String zipCode = null;
        
        //If we successfully received a consumer from the component, continue
        if (consumerRecord != null) {
            //Setting up dynamic query
            String consumerQuery = 'SELECT Id, CID__c, Birthday__c, Address_Line_1__c, Address_Line_2__c, FirstName, LastName, PersonHomePhone, PersonMobilePhone, PersonEmail, Mailing_Zip_Postal_Code__c, Crown_Rewards_Number__c,UUID__c FROM Account ';
            String whereClause = ' WHERE isPersonAccount = true ';
            //Building our dynamic query based on the users input
            if (String.isNotBlank(consumerRecord.FirstName)) {
                whereClause += ' AND FirstName = \'' + String.escapeSingleQuotes(consumerRecord.FirstName) + '\' ';
            }
            
            if (String.isNotBlank(consumerRecord.LastName)) {
                whereClause += ' AND LastName = \'' + String.escapeSingleQuotes(consumerRecord.LastName) + '\' ';
            }
            
            if (String.isNotBlank(consumerRecord.Mailing_Zip_Postal_Code__c)) {
                whereClause += ' AND Mailing_Zip_Postal_Code__c LIKE \'' + String.escapeSingleQuotes(consumerRecord.Mailing_Zip_Postal_Code__c).substring(0, 4) + '%\' ';
            }
            // 2161 - Replacing formula phone and mobile fields with standard fields.
           /* if (String.isNotBlank(consumerRecord.PersonHomePhone)) {
                whereClause += ' AND (Mobile_Formula__c = \'' + removePhoneFormat(consumerRecord.PersonHomePhone) + '\'' + 
                    'OR Preferred_Phone_Formula__c = \'' + removePhoneFormat(consumerRecord.PersonHomePhone) + '\') ';
            }*/
            if (String.isNotBlank(consumerRecord.PersonHomePhone)) {
                whereClause += ' AND (PersonMobilePhone = \'' + removePhoneFormat(consumerRecord.PersonHomePhone) + '\'' + 
                    'OR PersonHomePhone = \'' + removePhoneFormat(consumerRecord.PersonHomePhone) + '\') ';
            }
            
            if (String.isNotBlank(consumerRecord.PersonEmail)) {
                whereClause += ' AND PersonEmail = \'' + String.escapeSingleQuotes(consumerRecord.PersonEmail) + '\' ';
            }
            
            if (String.isNotBlank(acctId)) {
                whereClause += ' AND Id != \'' + String.escapeSingleQuotes(acctId) + '\' ';
            }

            //Raghav -  CARE-2018 CID added
            if (String.isNotBlank(consumerRecord.CID__c)) {
                whereClause += ' AND CID__c = \'' + String.escapeSingleQuotes(consumerRecord.CID__c) + '\' ';
            }

             //Raghav -  CARE-2019 UUID added
             if (String.isNotBlank(consumerRecord.UUID__c)) {
                whereClause += ' AND UUID__c = \'' + String.escapeSingleQuotes(consumerRecord.UUID__c) + '\' ';
            }
            
            //This is actually gonna query all membership records using the member id passed. Even though it says Crown_Rewards_Number__c it will use that value to query every subscription record.
            if (String.isNotBlank(consumerRecord.Crown_Rewards_Number__c)) {
                //Finding subscriptions in the system
                Set<Id> acctIds = KH_FindConsumer.findMatchingSubscriptions(String.escapeSingleQuotes(consumerRecord.Crown_Rewards_Number__c));
                if (!acctIds.isEmpty()) {
                    //Adding the account Ids to search on
                    whereClause += ' AND Id IN :acctIds ';
                }else{
                    //If the acctIds returned for the memberId are empty and we have no other query parameters, pass a fake id to match on so we retrieve no results from SF.
                    whereClause += ' AND Id = \'000000000000000\' ';
                }
            }
            whereClause += ' LIMIT 100';
            consumerQuery = consumerQuery + whereClause;
            System.debug('-apex-001- @@query=' + consumerQuery);
            //Trying to query for our records, if that fails, send an alert to the administrators immediately.
            try {
                consumerRecords = Database.query(consumerQuery);
            } catch (Exception e) {
                Universal_Error_Logger.auraGenerateErrorLog(
                    'There was an error retrieving the consumer records from our databases. Please check CCDB to ensure no consumer exists already. Your administrators have been notified of this error.',
                    'KH_FindConsumer',
                    e.getMessage()
                );
                return null;
            }
            
            Set<String> uniqueConsumerIds = new Set<String>();
            //care-808
            string mailingStreet = '';
            if (!consumerRecords.isEmpty()) {
                for (Account acct : consumerRecords) {
                    //care-808
                    mailingStreet = '';
                    
                    KH_ConsumerMergeWrapper mergeRecord = new KH_ConsumerMergeWrapper();
                    mergeRecord.Id = acct.Id;
                    mergeRecord.CID = acct.CID__c;
                    mergeRecord.memberId = acct.Crown_Rewards_Number__c;
                    mergeRecord.email = acct.PersonEmail;
                    mergeRecord.phone = acct.PersonHomePhone;
                    mergeRecord.mobilePhone = acct.PersonMobilePhone;
                    mergeRecord.lastName = acct.LastName;
                    mergeRecord.firstName = acct.FirstName;
                    mergeRecord.postalCode = acct.Mailing_Zip_Postal_Code__c;
                    mergeRecord.source = 'Salesforce';
                    //care-34 Update to Search Results Screen on Consumer Pop and manual Consumer Search
                    
                    //care-808
                    if(acct.Address_Line_1__c != '' && acct.Address_Line_1__c != null)
                        mailingStreet = acct.Address_Line_1__c;
                    
                    if(acct.Address_Line_2__c != '' && acct.Address_Line_2__c != null)
                        mailingStreet += ' ' + acct.Address_Line_2__c;
                    
                    mergeRecord.mailingStreet = mailingStreet;
                    
                    
                    mergeRecord.birthday = acct.Birthday__c;
                    
                    mergedRecords.add(mergeRecord);
                    uniqueConsumerIds.add(acct.CID__c);
                }
            }
            System.debug('-apex-002- unique ids are =' + uniqueConsumerIds);
            //Getting our records to match on from CEMS
            List<KH_ConsumerMergeWrapper> cemsMergeList = checkKnowHer(consumerRecord);
            
            //If we got CEMS records, continue
            if (!cemsMergeList.isEmpty()) {
                //Look through our CEMS results and ensure that we don't have duplicate record matches in Salesforce.
                
                for (KH_ConsumerMergeWrapper consumer : cemsMergeList) {
                    System.debug('-apex-003- KnowHer results are =' + consumer);
                    if (!uniqueConsumerIds.contains(consumer.CID)) {
                        mergedRecords.add(consumer);
                    }
                }
            }
        }
        System.debug('-apex-003- KnowHer results are =' + mergedRecords);
        return mergedRecords;
    }
    
    //This method is utilized to find matching subscription records
    private static Set<Id> findMatchingSubscriptions(String memberId) {
        Set<Id> acctIds = new Set<Id>();
        if (memberId != null) {
            List<Subscription__c> subsList = [SELECT Id, Consumer__c FROM Subscription__c WHERE Subscription_Id__c = :memberId];
            if (!subsList.isEmpty()) {
                for (Subscription__c sub : subsList) {
                    acctIds.add(sub.Consumer__c);
                }
            }
        }
        return acctIds;
    }
    
    @AuraEnabled
    //This method calls out to CCDB via the KnowHer API to check for consumer matches
    public static List<KH_ConsumerMergeWrapper> checkKnowHer(Account consumerRecord) {
        //Setting up variables
        List<KH_ConsumerMergeWrapper> consumerRecordsMerged = new List<KH_ConsumerMergeWrapper>();
        CEMS_CustomerData_Wrapper consumerRecords = null;
        
        //Using the CEMS Connector to make a GET request to CCDB
        CEMS_Connector_v2 cemConnect = new CEMS_Connector_v2('GET', null);
        
        //Care-808
        string mailingStreet= '';
        
        if (consumerRecord.Mailing_Zip_Postal_Code__c != null && consumerRecord.Mailing_Zip_Postal_Code__c != '' && consumerRecord.Mailing_Zip_Postal_Code__c.length() > 7) {
            consumerRecord.Mailing_Zip_Postal_Code__c = consumerRecord.Mailing_Zip_Postal_Code__c.substring(0, 4);
        }
        //Raghav - updated CID as first pararmeter in place of null
         //Raghav - 2019 added new parameter hPlusMemberUUID value null
        consumerRecords = cemConnect.CEMS_Get(consumerRecord.CID__c,
                                              consumerRecord.PersonHomePhone != null ? removePhoneFormat(consumerRecord.PersonHomePhone) : null,
                                              consumerRecord.PersonEmail,
                                              consumerRecord.FirstName,
                                              consumerRecord.LastName,
                                              consumerRecord.Mailing_Zip_Postal_Code__c,
                                              consumerRecord.Crown_Rewards_Number__c,
                                              consumerRecord.UUID__c,
                                              true);
        //If records were returned, format them as KH_ConsumerMergeWrapper records to send back to the component to display
        if (consumerRecords != null && consumerRecords.Result != null) {
            if (consumerRecords.Errors.isEmpty() && consumerRecords.Result.consumers != null) {
                for (CEMS_CustomerData_Wrapper.Consumers consumer : consumerRecords.Result.consumers) {
                    KH_ConsumerMergeWrapper cemsMerge = new KH_ConsumerMergeWrapper();
                    
                    //care-808
                    mailingStreet= '';
                    
                    cemsMerge.source = 'CCDB';
                    cemsMerge.CID = consumer.consumerId;
                    if (consumer.email != null) {
                        cemsMerge.email = consumer.email.address;
                    }
                    
                    if (consumer.phone != null) {
                        cemsMerge.phone = consumer.phone.homeNumber;
                        cemsMerge.mobilePhone = consumer.phone.mobileNumber;
                    }
                    
                    if (consumer.name != null) {
                        cemsMerge.FirstName = consumer.name.firstName;
                        cemsMerge.LastName = consumer.name.lastName;
                    }
                    
                    if (consumer.address != null) {
                        cemsMerge.postalCode = consumer.address.zip;
                        //care-34 Update to Search Results Screen on Consumer Pop and manual Consumer Search
                        
                        //care-808
                        //cemsMerge.mailingStreet = consumer.address.addressLine1;
                        if(consumer.address.addressLine1 != '' && consumer.address.addressLine1 != null)
                            mailingStreet = consumer.address.addressLine1;
                        
                        if(consumer.address.addressLine2 != '' && consumer.address.addressLine2 != null)
                            mailingStreet += ' ' + consumer.address.addressLine2;
                        
                        cemsMerge.mailingStreet = mailingStreet;
                        
                    }
                    //care-34 Update to Search Results Screen on Consumer Pop and manual Consumer Search
                    if (consumer.dateOfBirth != null && consumer.dateOfBirth != '') {
                        string month = '';
                        //string dateOfBirth = '01041993';
                        switch on consumer.dateOfBirth.substring(0, 2) {
                            when '01' {                                month = 'January';
                                      } when '02' {                                month = 'February';
                                                  }
                            when '03' {                                month = 'March';
                                      }
                            when '04' {                                month = 'April';
                                      }
                            when '05' {                                month = 'May';
                                      }
                            when '06' {                                month = 'June';
                                      }
                            when '07' {                                month = 'July';
                                      } 
                            when '08' {                                month = 'August';
                                      } 
                            when '09' {                                month = 'September';
                                      } 
                            when '10' {                                month = 'October';
                                      } 
                            when '11' {                                month = 'November';
                                      } 
                            when '12' {                                month = 'December';
                                      }
                        } 
                        cemsMerge.birthday = month +' '+ consumer.dateOfBirth.substring(2, 4);
                    }
                    
                    
                    if (consumer.memberships != null) {
                        for (CEMS_CustomerData_Wrapper.Memberships member : consumer.memberships) {
                            if (member.membershipType == 'Crown Rewards') {
                                cemsMerge.memberId = member.id;
                            }
                        }
                    }
                    consumerRecordsMerged.add(cemsMerge);
                }
                return consumerRecordsMerged;
            } else {
                //If we received an error inform the administrators immediately
                if (consumerRecords.Errors[0].ErrorMessage != 'Not Found') {
                    Universal_Error_Logger.auraGenerateErrorLog(                        'There was an error retrieving the consumer records from our databases. Please check CCDB to ensure no consumer exists already. Your administrators have been notified of this error.',                        'KH_FindConsumer',                        consumerRecords.Errors[0].ErrorMessage                    );                }                return consumerRecordsMerged;            }
        }
        return consumerRecordsMerged;
    }
    
    @AuraEnabled
    //This method calls out to CCDB via the CEMS API to check for consumer matches
    public static List<KH_ConsumerMergeWrapper> checkCEMS(Account consumerRecord) {
        //Setting up variables
        System.debug('Checking CEMS ::: ' + consumerRecord);
        List<KH_ConsumerMergeWrapper> consumerRecordsMerged = new List<KH_ConsumerMergeWrapper>();
        CEMS_CustomerData_Wrapper consumerRecords = null;
        
        //Using the CEMS Connector to make a GET request to CCDB
        CEMS_Connector_v2 cemConnect = new CEMS_Connector_v2('GET', null);
        String zip = consumerRecord.Mailing_Zip_Postal_Code__c;
        
        if (zip != null && zip != '') {
            if (zip.length() > 7) {                zip = consumerRecord.Mailing_Zip_Postal_Code__c.substring(0, 4);
                                  }
        }
        
        //Raghav - 2019 added new parameter hPlusMemberUUID value null
        consumerRecords = cemConnect.CEMS_Get(
            null,
            consumerRecord.PersonHomePhone != null ? removePhoneFormat(consumerRecord.PersonHomePhone) : null,
            consumerRecord.PersonEmail,
            consumerRecord.FirstName,
            consumerRecord.LastName,
            zip,
            consumerRecord.Crown_Rewards_Number__c,
            null,
            true
        );
        System.debug('Consumer Records Returned ::: ' + consumerRecords);
        
        //If records were returned, format them as KH_ConsumerMergeWrapper records to send back to the component to display
        if (consumerRecords != null) {
            if (consumerRecords.Result != null) {
                if (consumerRecords.Errors.isEmpty()) {
                    if (consumerRecords.Result.consumers != null) {
                        for (CEMS_CustomerData_Wrapper.Consumers consumer : consumerRecords.Result.consumers) {
                            KH_ConsumerMergeWrapper cemsMerge = new KH_ConsumerMergeWrapper();
                            
                            cemsMerge.source = 'CCDB';
                            cemsMerge.CID = consumer.consumerId;
                            
                            if (consumer.email != null) {                                cemsMerge.email = consumer.email.address;
                                                        }
                            
                            if (consumer.phone != null) {                                cemsMerge.phone = consumer.phone.homeNumber;
                                                         cemsMerge.mobilePhone = consumer.phone.mobileNumber;
                                                        }
                            
                            if (consumer.name != null) {
                                cemsMerge.FirstName = consumer.name.firstName;
                                cemsMerge.LastName = consumer.name.lastName;
                            }
                            
                            if (consumer.address != null) {                                cemsMerge.postalCode = consumer.address.zip;
                                                          }
                            
                            if (consumer.memberships != null) {                                for (CEMS_CustomerData_Wrapper.Memberships member : consumer.memberships) {
                                if (member.membershipType == 'Crown Rewards') {
                                    cemsMerge.memberId = member.id;
                                }
                            }
                                                              }
                            
                            consumerRecordsMerged.add(cemsMerge);
                        }
                        
                        return consumerRecordsMerged;
                    }
                } else {
                    //If we received an error inform the administrators immediately
                    if (consumerRecords.Errors[0].ErrorMessage != 'Not Found') {
                        Universal_Error_Logger.auraGenerateErrorLog(                            'There was an error retrieving the consumer records from our databases. Please check CCDB to ensure no consumer exists already. Your administrators have been notified of this error.',                            'KH_FindConsumer',                            consumerRecords.Errors[0].ErrorMessage                        );
                    }
                    return consumerRecordsMerged;
                }
                return consumerRecordsMerged;
            }
            return consumerRecordsMerged;
        }
        return consumerRecordsMerged;
    }
    
    //Naeem: care-1156 Ability to delete email association to Consumer record
    @AuraEnabled
    public static String getCurrentUserProfile() {
        System.debug('getCurrentUserProfile called');
        Id profileId = UserInfo.getProfileId();
        String profileName = [SELECT Id, Name FROM Profile WHERE Id = :profileId].Name;
        return  profileName;
    }
    
    //Naeem: care-1156 Ability to delete email association to Consumer record
    @AuraEnabled
    public static Boolean hasCareAdmin_PS() {
        
        Boolean showDelButton = false;
        List<PermissionSetAssignment> PermissionSetAssignmentList = [SELECT Id, PermissionSet.Name, AssigneeId FROM PermissionSetAssignment WHERE AssigneeId =: UserInfo.getUserId()];
        for(PermissionSetAssignment PSAssignment: PermissionSetAssignmentList){
            if(PSAssignment.PermissionSet.Name == 'Care_Supervisor_Hallmark'){
                showDelButton = true;
                break;
            }
            if(PSAssignment.PermissionSet.Name == 'Care_Admin'){
                showDelButton = true;
                break;
            }
        }
        return  showDelButton;
    }
    
    //Naeem: care-1156 Ability to delete email association to Consumer record
    @AuraEnabled
    public static String getConsumerCID(Id recordId) {
        System.debug('getConsumerCID recordId === '+recordId);
        String consumerCID = '';
        if(recordId != null){
            consumerCID = [Select Id, CID__c From Account Where Id = :recordId Limit 1].CID__c;
            System.debug('getConsumerCID consumerCID === '+consumerCID);
        }
        
        return  consumerCID;
    }
    
    public static String convertUtcToCentral(String utcString) {
    List<String> parts = utcString.split(' ');
    List<String> dateParts = parts[0].split('/');
    List<String> timeParts = parts[1].split(':');

    Integer month = Integer.valueOf(dateParts[0]);
    Integer day = Integer.valueOf(dateParts[1]);
    Integer year = Integer.valueOf(dateParts[2]);

    Integer hour = Integer.valueOf(timeParts[0]);
    Integer minute = Integer.valueOf(timeParts[1]);
    Integer second = Integer.valueOf(timeParts[2]);

    if (parts[2] == 'PM' && hour != 12) {
        hour += 12;
    } else if (parts[2] == 'AM' && hour == 12) {
        hour = 0;
    }

    DateTime utcDateTime = DateTime.newInstanceGmt(
        year, month, day, hour, minute, second
    );

    return utcDateTime.format(
        'M/d/yyyy h:mm:ss a',
        'America/Chicago'
    );
}
    
    //Naeem: care-1156 Ability to delete email association to Consumer record
    @AuraEnabled
    public static List<CareConsumerEmails_Wrapper.Emails> getConsumerEmails(String CID) {
        
        List<CareConsumerEmails_Wrapper.Emails> consumerEmails = new List<CareConsumerEmails_Wrapper.Emails>();
        CEMS_Connector_v2 cCon = new CEMS_Connector_v2('GET', null);
        
        CareConsumerEmails_Wrapper postResponse = new CareConsumerEmails_Wrapper();
        //Generate a post request resposnes
        postResponse = cCon.KH_ConsumerEmails_Get(CID);
        String sourceOfDataDesc = '';
        //If records were returned, format them as KH_ConsumerMergeWrapper records to send back to the component to display
        if (postResponse != null && postResponse.Result != null && postResponse.Errors.isEmpty() && postResponse.Result.emails != null) {
            System.debug('consumerEmails postResponse.Result.emails === '+ postResponse.Result.emails);
            for (Integer i = 0, j = 0; i < postResponse.Result.emails.size(); i++) {
                //sourceOfDataDesc = translateSourceDesc(postResponse.Result.emails[i].sourceOfDataDesc);
                //if(sourceOfDataDesc == '')
                //   continue;
                
                CareConsumerEmails_Wrapper.Emails consumerEmail = new CareConsumerEmails_Wrapper.Emails();
                consumerEmail.address = postResponse.Result.emails[i].address;
                consumerEmail.dfltInd = postResponse.Result.emails[i].dfltInd;
                // consumerEmail.lastUpdateDate = postResponse.Result.emails[i].lastUpdateDate;
                consumerEmail.lastUpdateDate = convertUtcToCentral(postResponse.Result.emails[i].lastUpdateDate);
                consumerEmail.sharedEmail = postResponse.Result.emails[i].sharedEmail;
               // consumerEmail.CapturedDt = postResponse.Result.emails[i].CapturedDt;
                consumerEmail.CapturedDt = convertUtcToCentral(postResponse.Result.emails[i].CapturedDt);
                //consumerEmail.sourceOfDataDesc = postResponse.Result.emails[i].sourceOfDataDesc;
               // consumerEmail.sourceOfDataDesc = translateSourceDesc(postResponse.Result.emails[i].sourceOfDataDesc);
                consumerEmail.sourceOfDataDesc =translateSource(postResponse.Result.emails[i].sourceOfDataDesc);
                consumerEmail.status = postResponse.Result.emails[i].status;
                
                System.debug('postResponse.Result.emails i consumerEmail'+                 consumerEmail);
                
                consumerEmails.add(consumerEmail);
            }
            System.debug('            consumerEmails  === '+             consumerEmails );
            return consumerEmails;
            
        } else {
            System.debug('consumerEmails error === ');
            return consumerEmails;
        }
    }
    
    //Naeem: care-1156 Ability to delete email association to Consumer record
    public static String translateSourceDesc(String sourceOfDataDesc) {
        String sourceDesc = '';
        if(sourceOfDataDesc == 'Consumer Care Profile' || sourceOfDataDesc == 'CONSUMER CARE PROFILE' )
            sourceDesc = 'CareTools';
        else if(sourceOfDataDesc == 'Cards Now Recipient' || sourceOfDataDesc == 'CARDS NOW RECIPIENT ' )
            sourceDesc = 'eCards Recipient';
        else if(sourceOfDataDesc == 'Cards Now Sender' || sourceOfDataDesc == 'CARDS NOW SENDER' )
            sourceDesc = 'Hallmark Cards Now App';
        else if(sourceOfDataDesc == 'Digital Greetings Web Recipient' || sourceOfDataDesc == 'DIGITAL GREETINGS WEB RECEIPIENT' )
            sourceDesc = 'eCard Recipient';
        else if(sourceOfDataDesc == 'Digital On-the-Fly Email' || sourceOfDataDesc == 'DIGITIAL ON-THE-FLY EMAIL' )
            sourceDesc = 'Hallmark.com Connect with us';
        else if(sourceOfDataDesc == 'Digital Profile' || sourceOfDataDesc == 'DIGITAL PROFILE' )
            sourceDesc = 'Hallmark.com Profile';
        else if(sourceOfDataDesc == 'Video Greetings' || sourceOfDataDesc == 'VIDEO GREETINGS' )
            sourceDesc = 'Video Greetings Website';        
        else if(sourceOfDataDesc == 'Point of Sale Profile' || sourceOfDataDesc == 'POINT OF SALE PROFILE' )
            sourceDesc = 'Gold Crown Store';
        else if(sourceOfDataDesc == 'Point of Sale Transaction' || sourceOfDataDesc == 'POINT OF SALE TRANSACTION' )
            sourceDesc = 'Gold Crown Store';
        else if(sourceOfDataDesc == 'Retailer Crown Rewards Gateway Profile' || sourceOfDataDesc == 'RETAILER CROWN REWARDS GATEWAY PROFILE' )
            sourceDesc = 'Gold Crown Store';
        else if(sourceOfDataDesc == 'Retailer Crown Rewards Gateway Transaction' || sourceOfDataDesc == 'RETAILER CROWN REWARDS GATEWAY TRANSACTION' )
            sourceDesc = 'Gold Crown Store';
        else if(sourceOfDataDesc == 'Salesforce Marketing Cloud Opts and Bounces' || sourceOfDataDesc == 'SALESFORCE MARKETING CLOUD OPTS AND BOUNCES' )
            sourceDesc = 'Consumer Email Unsubscribe/Failed Email Delivery';
        else if(sourceOfDataDesc == 'Sproutloud Opts and Bounces' || sourceOfDataDesc == 'SPROUTLOUD OPTS AND BOUNCES' )
            sourceDesc = 'Local Marketing System';
        else if(sourceOfDataDesc == 'KOC Admin' || sourceOfDataDesc == 'KOC ADMIN' )
            sourceDesc = 'KOC Enrollment';
        else if(sourceOfDataDesc == 'Paperstore Profile' || sourceOfDataDesc == 'PAPERSTORE PROFILE' )
            sourceDesc = 'Gold Crown Store: TPS';        
        else if(sourceOfDataDesc == 'Shared Email Updates' || sourceOfDataDesc == 'SHARED EMAIL UPDATES' )
            sourceDesc = 'Shared Email Updates';
        else if(sourceOfDataDesc == 'hplus on hmn.com' || sourceOfDataDesc == 'HPLUS ON HMN.COM' )
            sourceDesc = 'Hallmarkplus.com or Hallmark+ App';
		else if(sourceOfDataDesc == 'hplus on hmk.com' || sourceOfDataDesc == 'HPLUS ON HMK.COM' )
            sourceDesc = 'Hallmark.com Profile';
		else if(sourceOfDataDesc == 'hplus pre load' || sourceOfDataDesc == 'HPLUS PRE LOAD' )
            sourceDesc = 'Hmnow.com or HMN App';
        else
            sourceDesc = sourceOfDataDesc;
        
        return sourceDesc;
    }
    
    //Naeem: care-1156 Ability to delete email association to Consumer record
    @AuraEnabled
    public static String deleteEmails(String CID, String emailsList) {
        system.debug('deleteEmails emailsList == '+emailsList);
        
        CareConEmailDelete_Wrapper postResponse = new CareConEmailDelete_Wrapper();
        String responseStatus = '';
        String reqBody = '{"ConsumerId":'+CID+',';
        reqBody +='"VendorId":"CareProfile",';
        reqBody +='"LastUpdatedFrom":"Care Agent",';
        reqBody +='"Emails":['+emailsList+']}';
        System.debug('deleteEmails reqBody == '+reqBody);
        
        //Generate a post request resposnes
        CEMS_Connector_v2 cCon = new CEMS_Connector_v2('DELETE', reqBody);
        postResponse = cCon.KH_ConsumerEmails_Delete();
        
        //If records were returned, format them as KH_ConsumerMergeWrapper records to send back to the component to display
        if (postResponse != null) {
            System.debug('deleteEmails postResponse === '+ postResponse);
            if(postResponse.Status == 'ERROR')
                responseStatus = 'ERROR';
            if(postResponse.Status == 'SUCCESS')
                responseStatus = 'SUCCESS';
            
            return responseStatus;            
        } else {
            System.debug('deleteEmails error === ');
            
            return responseStatus;
        }
    }
       //Raghav - Start
       @AuraEnabled
       public static List<CareConsumerPhones_Wrapper.Phones> getConsumerPhones(String CID) {
           
           List<CareConsumerPhones_Wrapper.Phones> consumerPhones = new List<CareConsumerPhones_Wrapper.Phones>();
           CEMS_Connector_v2 cCon = new CEMS_Connector_v2('GET', null);
           
           CareConsumerPhones_Wrapper postResponse = new CareConsumerPhones_Wrapper();
           //Generate a post request resposnes
           postResponse = cCon.KH_ConsumerPhones_Get(CID);
           String sourceOfDataDesc = '';
           //If records were returned, format them as CareConsumerPhones_Wrapper records to send back to the component to display
           if (postResponse != null && postResponse.Result != null && postResponse.Errors.isEmpty() && postResponse.Result.phones != null) {
               System.debug('consumerPhones postResponse.Result.phones === '+ postResponse.Result.phones);
               for (Integer i = 0; i < postResponse.Result.phones.size(); i++) {  
              //  if(postResponse.Result.phones[i].phoneType.equalsIgnoreCase('HOME')) {          
                   CareConsumerPhones_Wrapper.Phones consumerPhone = new CareConsumerPhones_Wrapper.Phones();
                   consumerPhone.phone = postResponse.Result.phones[i].phone;
                   consumerPhone.phoneType = postResponse.Result.phones[i].phoneType;
                   consumerPhone.dfltInd = postResponse.Result.phones[i].dfltInd;
                   // consumerPhone.lastUpdateDate = postResponse.Result.phones[i].lastUpdateDate;
                   consumerPhone.lastUpdateDate = convertUtcToCentral(postResponse.Result.phones[i].lastUpdateDate);
                   consumerPhone.internationalPrefix = postResponse.Result.phones[i].internationalPrefix;
                   // consumerPhone.CapturedDt = postResponse.Result.phones[i].CapturedDt;
                   consumerPhone.CapturedDt = convertUtcToCentral(postResponse.Result.phones[i].CapturedDt);
                  // consumerPhone.sourceOfDataDesc = translateSourceDescForPhone(postResponse.Result.phones[i].sourceOfDataDesc);
                   consumerPhone.sourceOfDataDesc = translateSource(postResponse.Result.phones[i].sourceOfDataDesc);
                   consumerPhone.phoneOptIn = postResponse.Result.phones[i].phoneOptIn;
                   
                   System.debug('postResponse.Result.phones i consumerPhone'+ consumerPhone);
                   
                   consumerPhones.add(consumerPhone);
               // }
               }
               System.debug('consumerPhones  === '+ consumerPhones );
               return consumerPhones;
               
           } else {
               System.debug('consumerPhones error === ');
               return consumerPhones;
           }
       }

       public static String translateSourceDescForPhone(String sourceOfDataDesc) {
            // Handle null input
            if (sourceOfDataDesc == null) {
                return '';
            }
            // input to lowercase for consistent matching
            String normalizedInput = sourceOfDataDesc.trim().toLowerCase();
            
            // Return mapped value if found, otherwise return original
            return SOURCE_MAPPINGS.containsKey(normalizedInput) 
                ? SOURCE_MAPPINGS.get(normalizedInput) 
                : sourceOfDataDesc;
        }
   
       @AuraEnabled
       public static String deletePhones(String CID, String phonesList) {
           system.debug('deletePhones phonesList == '+phonesList);
           
           CareConPhoneDelete_Wrapper postResponse = new CareConPhoneDelete_Wrapper();
           String responseStatus = '';
           String reqBody = '{"ConsumerId":'+CID+',';
           reqBody +='"VendorId":"CareProfile",';
           reqBody +='"LastUpdatedFrom":"Care Agent",';
           reqBody +='"Phones":['+phonesList+']}';
           System.debug('deletePhones reqBody == '+reqBody);
           
           //Generate a post request resposnes
           CEMS_Connector_v2 cCon = new CEMS_Connector_v2('DELETE', reqBody);
           postResponse = cCon.KH_ConsumerPhones_Delete();
           
           if (postResponse != null) {
               System.debug('deletePhones postResponse === '+ postResponse);
               if(postResponse.Status == 'ERROR' || postResponse.Status == 'FAILED' || postResponse.Status == null)
                   responseStatus = 'ERROR';
               if(postResponse.Status == 'SUCCESS')
                   responseStatus = 'SUCCESS';
               
               return responseStatus;            
           } else {
               System.debug('deletePhones error === ');
               
               return responseStatus;
           }
       }
       //Raghav - End
    
    //Naeem: care-3406 Get Consumer Email Preferences
    @AuraEnabled
    public static CareConEmailPrefGETWrapper getConsumerEmailPrefs(Id recordId) {
        String consumerCID = KH_FindConsumer.getConsumerCID(recordId);
      //  CareConEmailPrefGETWrapper conEmailPrefs = new CareConEmailPrefGETWrapper();
          CareConEmailPrefGETWrapper postResponse = new CareConEmailPrefGETWrapper();
        if (String.isNotBlank(consumerCID))
        {          
            CEMS_Connector_v2 cCon = new CEMS_Connector_v2('GET', null);
            
            //Generate a post request resposnes
            postResponse = cCon.KH_ConsumerEmailPrefs_Get(consumerCID);
            
            //If records were returned, format them as KH_ConsumerMergeWrapper records to send back to the component to display
            System.debug('getConsumerEmailPrefs response === '+ postResponse);
            if (postResponse.Result == null) {
                postResponse.Result = new CareConEmailPrefGETWrapper.ResultWrapper();
                postResponse.Result.consumers = new List<CareConEmailPrefGETWrapper.ConsumerWrapper>();
            }
            if (postResponse.Result.consumers == null) {
                postResponse.Result.consumers = new List<CareConEmailPrefGETWrapper.ConsumerWrapper>();
            }

            // Translate Last Updated From values
            for (CareConEmailPrefGETWrapper.ConsumerWrapper consumer : postResponse.Result.consumers) {

                if (consumer.communicationPreferences == null ||
                    consumer.communicationPreferences.emailPreferences == null ||
                    consumer.communicationPreferences.emailPreferences.preferences == null) {
                    continue;
                }

                for (CareConEmailPrefGETWrapper.Preference pref :
                        consumer.communicationPreferences.emailPreferences.preferences) {

                    pref.prfSourceOfDataDesc =
                        translateSource(pref.prfSourceOfDataDesc);
                }
            }
        

        }
        return postResponse;
        
    }

    @AuraEnabled
    public static APIResponseWrapper saveConsumerEmailPrefs(
        Id recordId,
        String cid,
        String deliveryContactPoint,
        List<UpdatedEmailPreferenceWrapper> updatedPreferences
    ) {
        
        String successMessage;
        if (String.isBlank(cid)) {
            throw new AuraHandledException('Consumer CID is required.');
        }
        
        if (String.isBlank(deliveryContactPoint) && recordId != null) {
            Account acct = [
                SELECT Id, PersonEmail
                FROM Account
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            deliveryContactPoint = acct.PersonEmail;
        }
        
        if (String.isBlank(deliveryContactPoint)) {
            throw new AuraHandledException('Delivery contact point/email is required.');
        }
        
        if (updatedPreferences == null || updatedPreferences.isEmpty()) {
            throw new AuraHandledException('No preferences were provided to save.');
        }
        
        CareConEmailPrefPUTWrapper requestWrapper = new CareConEmailPrefPUTWrapper();
        
        requestWrapper.VendorId = 'CareProfile';
        
        requestWrapper.communicationPreferences =
            new CareConEmailPrefPUTWrapper.CommunicationPreferences();
        
        requestWrapper.communicationPreferences.emailPreferences =
            new CareConEmailPrefPUTWrapper.EmailPreferences();
        
        requestWrapper.communicationPreferences.emailPreferences.deliveryMethodId = 1;
        requestWrapper.communicationPreferences.emailPreferences.deliveryContactPoint = deliveryContactPoint;
        requestWrapper.communicationPreferences.emailPreferences.preferences =
            new List<CareConEmailPrefPUTWrapper.Preference>();
        
        requestWrapper.communicationPreferences.smsPreferences = null;
        requestWrapper.communicationPreferences.pushPreferences = null;
        requestWrapper.communicationPreferences.postalPreferences = null;
        
        Datetime currentGmtDateTime = Datetime.now();
                
        for (UpdatedEmailPreferenceWrapper pref : updatedPreferences) {
            if (pref == null || pref.prfTypeId == null) {
                continue;
            }
            
            CareConEmailPrefPUTWrapper.Preference apiPref =
                new CareConEmailPrefPUTWrapper.Preference();
            
            apiPref.prfTypeId = pref.prfTypeId;
            apiPref.prfSts = pref.value;
            apiPref.prfLastUpdateDate = currentGmtDateTime;
            
            requestWrapper.communicationPreferences.emailPreferences.preferences.add(apiPref);
        }
        
        if (requestWrapper.communicationPreferences.emailPreferences.preferences.isEmpty()) {
            throw new AuraHandledException('No valid preferences were provided to save.');
        }
        
        String requestBody = JSON.serialize(requestWrapper);
        
        System.debug('saveConsumerEmailPrefs requestBody: ' + requestBody);
        
        
        CEMS_Connector_v2 cCon = new CEMS_Connector_v2('PUT', requestBody);
        Integer statusCode = cCon.KH_ConsumerEmailPrefs_PUT(cid);
        APIResponseWrapper response = new APIResponseWrapper();
        
        //If records were returned, format them as KH_ConsumerMergeWrapper records to send back to the component to display
        if (statusCode != null) {
            System.debug('saveConsumerEmailPrefs statusCode === '+ statusCode);
            
            
            if (statusCode == 200) {
                response.success = true;
                response.message = 'Preferences updated successfully.';
            } else {
                response.success = false;
                response.message = 'The consumer Email preferences failed to updated! ';
            }
            
        } 
        
        return response;
    }
    public class UpdatedEmailPreferenceWrapper {
        @AuraEnabled public Integer prfTypeId { get; set; }
        @AuraEnabled public Boolean value { get; set; }
    }
    public class APIResponseWrapper {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public Integer statusCode { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public String responseBody { get; set; }
    }

    public static String translateSource(String source) {

        if (String.isBlank(source)) {
            return '';
        }

        String key = source.trim().toLowerCase();

        return SOURCE_TRANSLATIONS.containsKey(key)
            ? SOURCE_TRANSLATIONS.get(key)
            : source;
    }
        
    @AuraEnabled(cacheable=true)
    public static List<CEMS_CustomerData_Wrapper.AlternateId> getConsumerAccounts(Id recordId) {
        if (recordId == null) {
            return new List<CEMS_CustomerData_Wrapper.AlternateId>();
        }
        System.debug('getConsumerAccounts recordId == '+recordId);
        
        List<Consumer_Account__c> consumerAccounts = [SELECT Id, val__c, Login_Email__c, Last_Login_TS__c
                                                      FROM Consumer_Account__c
                                                      WHERE Consumer__c = :recordId];
        
        System.debug('getConsumerAccounts consumerAccounts == '+consumerAccounts);        
        List<CEMS_CustomerData_Wrapper.AlternateId> rows = new List<CEMS_CustomerData_Wrapper.AlternateId>();
        
        for (Consumer_Account__c consumerAccount : consumerAccounts) {
            CEMS_CustomerData_Wrapper.AlternateId row = new CEMS_CustomerData_Wrapper.AlternateId();
            
            row.val = consumerAccount.val__c;
            row.loginEmail = consumerAccount.Login_Email__c;
            row.lastLoginTS = consumerAccount.Last_Login_TS__c;
            
            rows.add(row);
        }
        System.debug('getConsumerAccounts rows == '+rows);       
        return rows;
    }
    @AuraEnabled(cacheable=true)
    public static Boolean canCurrentUserViewHdxRef() {
        Set<String> allowedProfiles = new Set<String>{
            'Care - Supervisor - Hallmark',
                'Care - Admin',
                'System Administrator'
                };
                    
                    String currentProfileName = [
                        SELECT Name
                        FROM Profile
                        WHERE Id = :UserInfo.getProfileId()
                        LIMIT 1
                    ].Name;
        
        return allowedProfiles.contains(currentProfileName);
    }    
    
    
    @AuraEnabled
    public static List<KH_ConsumerMergeWrapper> getDuplicateKnowHerConsumers(
        Id accountId
    ) {
        
        List<KH_ConsumerMergeWrapper> consumerRecordsMerged =
            new List<KH_ConsumerMergeWrapper>();
        
        if (accountId == null) {
            return consumerRecordsMerged;
        }
        
        List<Account> accounts = [
            SELECT
            Id,
            FirstName,
            LastName,
            PersonEmail,
            PersonHomePhone,
            Mailing_Zip_Postal_Code__c
            FROM Account
            WHERE Id = :accountId
            AND IsPersonAccount = TRUE
            LIMIT 1
        ];
        
        if (accounts.isEmpty()) {
            return consumerRecordsMerged;
        }
        
        Account consumerRecord = accounts[0];
        
        CEMS_Connector_v2 cemConnect =
            new CEMS_Connector_v2(
                'GET',
                null
            );
        
        /*
* IMPORTANT:
* Keep this search the same as fetchConsumer().
*
* processRecords = false
*/
        CEMS_CustomerData_Wrapper consumerRecords =
            cemConnect.CEMS_Get(
                null,
                consumerRecord.PersonHomePhone,
                consumerRecord.PersonEmail,
                consumerRecord.FirstName,
                consumerRecord.LastName,
                consumerRecord.Mailing_Zip_Postal_Code__c,
                null,
                null,
                false
            );
        
        if (
            consumerRecords == null ||
            consumerRecords.Result == null ||
            consumerRecords.Result.consumers == null
        ) {
            return consumerRecordsMerged;
        }
        
        if (
            consumerRecords.Errors != null &&
            !consumerRecords.Errors.isEmpty()
        ) {
            return consumerRecordsMerged;
        }
        
        for (
            CEMS_CustomerData_Wrapper.Consumers consumer :
            consumerRecords.Result.consumers
        ) {
            
            KH_ConsumerMergeWrapper cemsMerge =
                new KH_ConsumerMergeWrapper();
            
            cemsMerge.source = 'CCDB';
            cemsMerge.CID = consumer.consumerId;
            
            if (consumer.email != null) {
                cemsMerge.email =
                    consumer.email.address;
            }
            
            if (consumer.phone != null) {
                cemsMerge.phone =
                    consumer.phone.homeNumber;
                
                cemsMerge.mobilePhone =
                    consumer.phone.mobileNumber;
            }
            
            if (consumer.name != null) {
                cemsMerge.firstName =
                    consumer.name.firstName;
                
                cemsMerge.lastName =
                    consumer.name.lastName;
            }
            
            if (consumer.address != null) {
                
                cemsMerge.postalCode =
                    consumer.address.zip;
                
                String mailingStreet = '';
                
                if (
                    String.isNotBlank(
                        consumer.address.addressLine1
                    )
                ) {
                    mailingStreet =
                        consumer.address.addressLine1;
                }
                
                if (
                    String.isNotBlank(
                        consumer.address.addressLine2
                    )
                ) {
                    
                    if (
                        String.isNotBlank(
                            mailingStreet
                        )
                    ) {
                        mailingStreet += ' ';
                    }
                    
                    mailingStreet +=
                        consumer.address.addressLine2;
                }
                
                cemsMerge.mailingStreet =
                    mailingStreet;
            }
            
            if (
                String.isNotBlank(
                    consumer.dateOfBirth
                ) &&
                consumer.dateOfBirth.length() >= 4
            ) {
                
                Map<String, String> months =
                    new Map<String, String>{
                        '01' => 'January',
                            '02' => 'February',
                            '03' => 'March',
                            '04' => 'April',
                            '05' => 'May',
                            '06' => 'June',
                            '07' => 'July',
                            '08' => 'August',
                            '09' => 'September',
                            '10' => 'October',
                            '11' => 'November',
                            '12' => 'December'
                            };
                                
                                String month =
                                months.get(
                                    consumer.dateOfBirth.substring(
                                        0,
                                        2
                                    )
                                );
                
                if (month != null) {
                    cemsMerge.birthday =
                        month +
                        ' ' +
                        consumer.dateOfBirth.substring(
                            2,
                            4
                        );
                }
            }
            
            if (consumer.memberships != null) {
                
                for (
                    CEMS_CustomerData_Wrapper.Memberships member :
                    consumer.memberships
                ) {
                    
                    if (
                        member.membershipType ==
                        'Crown Rewards'
                    ) {
                        cemsMerge.memberId =
                            member.id;
                        
                        break;
                    }
                }
            }
            
            consumerRecordsMerged.add(
                cemsMerge
            );
        }
        
        return consumerRecordsMerged;
    }
    
}