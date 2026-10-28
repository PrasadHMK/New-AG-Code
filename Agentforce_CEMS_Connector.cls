/**
*==============================================================================
* @File Name : Agentforce_CEMS_Connector.cls
* @Description : Connects to CEMS services for customer and membership data.
* @Author : Prasad Yericherla
* @Created On : April 14, 2026
* @Last Modified By :  Prasad Yericherla
* @Last Modified On : April 27, 2026
* @Modification Log : 
*==============================================================================
**/
public with sharing class Agentforce_CEMS_Connector {

    public class MemberRewardsResponse {
        public MemberRewardsResult result;
    }

    public class MemberRewardsResult {
        public List<MemberRewardDetail> details;
    }

    public class MemberRewardDetail {
        public String id;
        public String typeExternalReference;
        public String name;
        public String value;
        public String redeemedTimestampUTC;
        public String cancelledTimestampUTC;
        public String expireEndOfDay;
        public String isCancelled;
        public String isExpired;
        public String isRedeemed;
        public MemberRewardCustomFields customFields;
    }

    public class MemberRewardCustomFields {
        public String externalReference;
        public String alphaTrigger;
        public String rewardType;
        public String offerStartDate;
        public String offerDisplayExpDate;
    }

    private final String KNOWHER_KEY;
    private final String KNOWHER_SECRET;
    private final String ACCESS_TOKEN_URL;
    private final String CLIENT_HEADER;
    private final String CONTENT_TYPE;
    private final String CONTENT_TYPE_JSON;
    private final String BASE_URL;
    private final String X_GRAVITEE_API_KEY;
    private final String ACCESS_TOKEN_FAILURE = 'Authorization Token Failure';

    private static String CEMS_BATCH_AUTH_TOKEN;

    public Agentforce_CEMS_Connector(String calloutMethodPassed, String reqBodyPassed) {
        String connectionName;
        String currentUrl = URL.getOrgDomainURL().toExternalForm();

        if (currentUrl.contains('projectdev')) {
            connectionName = 'HMK_CARE_EAPI_DEV';
        } else if (currentUrl.contains('projectqa') || currentUrl.contains('hplusdev') || currentUrl.contains('hplusqa')) {
            connectionName = 'HMK_CARE_EAPI_QA';
        } else {
            connectionName = 'CEMS_Prod_Connection';
        }

        if (Test.isRunningTest()) {
            connectionName = 'HMK_CARE_EAPI_QA';
        }
        connectionName = 'HMK_CARE_EAPI_QA'; // HMK_CARE_EAPI_PROD .. HMK_CARE_EAPI_QA
        CEMS_Connection_Setting__mdt cemConnectionSettings = [
            SELECT KnowHer_Key__c,
                KnowHer_Secret__c,
                Access_Token_URL__c,
                Base_URL__c,
                Client_Header__c,
                Content_Type__c,
                Content_Type_JSON__c,
                X_Gravitee_Api_Key__c
            FROM CEMS_Connection_Setting__mdt
            WHERE DeveloperName = :connectionName
            LIMIT 1
        ];

        KNOWHER_KEY = cemConnectionSettings.KnowHer_Key__c;
        KNOWHER_SECRET = cemConnectionSettings.KnowHer_Secret__c;
        /*ACCESS_TOKEN_URL = cemConnectionSettings.Access_Token_URL__c;*/
        /*BASE_URL = cemConnectionSettings.Base_URL__c;*/
        ACCESS_TOKEN_URL = 'https://apihub.stage.hallmark.com/hmk-pingone-token-eapi/token';
        BASE_URL = 'https://apihub.stage.hallmark.com/hmk-care-eapi/agentforce/consumers'; 
        /*ACCESS_TOKEN_URL = 'https://apihub.hallmark.com/hmk-pingone-token-eapi/token'; 
        BASE_URL = 'https://apihub.hallmark.com/hmk-care-eapi/agentforce/consumers'; */
        CLIENT_HEADER = cemConnectionSettings.Client_Header__c;
        CONTENT_TYPE = cemConnectionSettings.Content_Type__c;
        CONTENT_TYPE_JSON = cemConnectionSettings.Content_Type_JSON__c;
        X_GRAVITEE_API_KEY = cemConnectionSettings.X_Gravitee_Api_Key__c;
    }

    public Agentforce_CEMS_CustomerData_Wrapper CEMS_Get(
        String CID,
        String phoneNumber,
        String email,
        String firstName,
        String lastName,
        String zip,
        String memberId,
        String hPlusMemberUUID,
        Boolean processRecords,
        Boolean filterLoyaltyData
    ) {
        String accessToken = getAccessToken();
        if (accessToken == ACCESS_TOKEN_FAILURE) {
            return errorWrapper('777', 'Failed to retrieve access token to CEMS successfully.');
        }

        String secureCID = String.isNotBlank(CID) ? String.escapeSingleQuotes(CID) : null;
        String securePhone = String.isNotBlank(phoneNumber) ? String.escapeSingleQuotes(phoneNumber) : null;
        String secureEmail = String.isNotBlank(email) ? String.escapeSingleQuotes(email) : null;
        String secureFirstName = String.isNotBlank(firstName) ? String.escapeSingleQuotes(firstName) : null;
        String secureLastName = String.isNotBlank(lastName) ? String.escapeSingleQuotes(lastName) : null;
        String secureZip = String.isNotBlank(zip) ? String.escapeSingleQuotes(zip) : null;
        String secureMemberId = String.isNotBlank(memberId) ? String.escapeSingleQuotes(memberId) : null;
        String secureHPlusMemberUUID = String.isNotBlank(hPlusMemberUUID) ? String.escapeSingleQuotes(hPlusMemberUUID) : null;

        String urlEndpoint = BASE_URL + '?';
        urlEndpoint = appendParam(urlEndpoint, 'consumerId', secureCID);
        urlEndpoint = appendParam(urlEndpoint, 'homePhone', securePhone);
        urlEndpoint = appendParam(urlEndpoint, 'email', secureEmail);
        urlEndpoint = appendParam(urlEndpoint, 'firstName', secureFirstName);
        urlEndpoint = appendParam(urlEndpoint, 'lastName', secureLastName);
        urlEndpoint = appendParam(urlEndpoint, 'zip', secureZip);
        urlEndpoint = appendParam(urlEndpoint, 'memberId', secureMemberId);
        urlEndpoint = appendParam(urlEndpoint, 'hPlusMemberUUID', secureHPlusMemberUUID);
        if (filterLoyaltyData == true) {
            urlEndpoint = appendParam(urlEndpoint, 'filterLoyaltyData', 'true');
        }

        HttpRequest request = buildRequest('GET', urlEndpoint, accessToken, null, true, false);
        Http http = new Http();

        try {
            HttpResponse response = http.send(request);
            if (response.getStatusCode() == 200) {
                Agentforce_CEMS_CustomerData_Wrapper wrapper = Agentforce_CEMS_CustomerData_Wrapper.parseCustomerData(response.getBody());
                if (processRecords) {
                    wrapper = processCEMSResults(wrapper, securePhone, secureEmail, secureFirstName, secureLastName, secureZip);
                }
                return wrapper;
            }
            if (response.getStatusCode() == 404) {
                Agentforce_CEMS_CustomerData_Wrapper wrapper = Agentforce_CEMS_CustomerData_Wrapper.parseCustomerData(response.getBody());
                ensureErrors(wrapper).add(errorItem(String.valueOf(response.getStatusCode()), response.getStatus()));
                return wrapper;
            }
            Agentforce_CEMS_CustomerData_Wrapper wrapper = Agentforce_CEMS_CustomerData_Wrapper.parseCustomerData(response.getBody());
            ensureErrors(wrapper).add(errorItem(String.valueOf(response.getStatusCode()), response.getStatus()));
            return wrapper;
        } catch (Exception ex) {
            return errorWrapper('999', 'Connection to CEMS failed: ' + ex.getMessage());
        }
    }

    public Agentforce_ConsumerExists_Result consumerExists(
        String firstName,
        String lastName,
        String email,
        String phoneNumber,
        String zip
    ) {
        String accessToken = getAccessToken();
        if (accessToken == ACCESS_TOKEN_FAILURE) {
            return null;
        }

        String securePhone = String.isNotBlank(phoneNumber) ? String.escapeSingleQuotes(phoneNumber) : null;
        String secureEmail = String.isNotBlank(email) ? String.escapeSingleQuotes(email) : null;
        String secureFirstName = String.isNotBlank(firstName) ? String.escapeSingleQuotes(firstName) : null;
        String secureLastName = String.isNotBlank(lastName) ? String.escapeSingleQuotes(lastName) : null;
        String secureZip = String.isNotBlank(zip) ? String.escapeSingleQuotes(zip) : null;

        String urlEndpoint = normalizeExistsBaseUrl(BASE_URL) + '?';
        urlEndpoint = appendParam(urlEndpoint, 'firstName', secureFirstName);
        urlEndpoint = appendParam(urlEndpoint, 'lastName', secureLastName);
        urlEndpoint = appendParam(urlEndpoint, 'email', secureEmail);
        urlEndpoint = appendParam(urlEndpoint, 'homePhone', securePhone);
        urlEndpoint = appendParam(urlEndpoint, 'zip', secureZip);
        urlEndpoint = appendParam(urlEndpoint, 'retrieveBaseObject', 'true');

        HttpRequest request = buildRequest('GET', urlEndpoint, accessToken, null, true, false);
        Http http = new Http();

        try {
            HttpResponse response = http.send(request);
            if (response.getStatusCode() != 200 || String.isBlank(response.getBody())) {
                return null;
            }
            return (Agentforce_ConsumerExists_Result) JSON.deserialize(
                response.getBody(),
                Agentforce_ConsumerExists_Result.class
            );
        } catch (Exception ex) {
            return null;
        }
    }

    public MemberRewardsResponse getMemberRewards(String memberAccountId) {
        if (String.isBlank(memberAccountId)) {
            return null;
        }
        String accessToken = getAccessToken();
        if (accessToken == ACCESS_TOKEN_FAILURE) {
            return null;
        }

        String urlEndpoint = normalizeConsumersBaseUrl(BASE_URL)
            + '/' + EncodingUtil.urlEncode(memberAccountId.trim(), 'UTF-8') + '/rewards';
        HttpRequest request = buildRequest('GET', urlEndpoint, accessToken, null, true, false);
        try {
            HttpResponse response = new Http().send(request);
            if (response.getStatusCode() != 200 || String.isBlank(response.getBody())) {
                return null;
            }
            return (MemberRewardsResponse) JSON.deserialize(response.getBody(), MemberRewardsResponse.class);
        } catch (Exception ex) {
            return null;
        }
    }

    private Agentforce_CEMS_CustomerData_Wrapper processCEMSResults(
        Agentforce_CEMS_CustomerData_Wrapper originalConsumer,
        String phoneNumber,
        String email,
        String firstName,
        String lastName,
        String zip
    ) {
        if (originalConsumer == null || originalConsumer.Result == null || originalConsumer.Result.consumers == null) {
            return originalConsumer;
        }

        List<Agentforce_CEMS_CustomerData_Wrapper.Consumers> filteredConsumers =
            new List<Agentforce_CEMS_CustomerData_Wrapper.Consumers>();

        for (Agentforce_CEMS_CustomerData_Wrapper.Consumers consumer : originalConsumer.Result.consumers) {
            Boolean keepRecord = true;

            if (String.isNotBlank(firstName)) {
                if (consumer.name == null || String.isBlank(consumer.name.firstName)
                    || !consumer.name.firstName.equalsIgnoreCase(firstName)) {
                    keepRecord = false;
                }
            }

            if (keepRecord && String.isNotBlank(lastName)) {
                if (consumer.name == null || String.isBlank(consumer.name.lastName)
                    || !consumer.name.lastName.equalsIgnoreCase(lastName)) {
                    keepRecord = false;
                }
            }

            if (keepRecord && String.isNotBlank(email)) {
                if (consumer.email == null || String.isBlank(consumer.email.address)
                    || !consumer.email.address.equalsIgnoreCase(email)) {
                    keepRecord = false;
                }
            }

            if (keepRecord && String.isNotBlank(zip)) {
                if (consumer.address == null || String.isBlank(consumer.address.zip)
                    || consumer.address.zip != zip) {
                    keepRecord = false;
                }
            }

            if (keepRecord) {
                filteredConsumers.add(consumer);
            }
        }

        originalConsumer.Result.consumers = filteredConsumers;
        originalConsumer.Result.numberOfResults = String.valueOf(filteredConsumers.size());
        return originalConsumer;
    }

    private String appendParam(String currentURL, String fieldToAdd, String fieldData) {
        if (String.isBlank(fieldData)) {
            return currentURL;
        }
        String next = currentURL.contains('=') ? currentURL + '&' : currentURL;
        return next + fieldToAdd + '=' + EncodingUtil.urlEncode(fieldData, 'UTF-8');
    }

    private String normalizeExistsBaseUrl(String baseUrl) {
        String normalized = String.isNotBlank(baseUrl) ? baseUrl.trim() : '';
        while (normalized.endsWith('/')) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }
        if (!normalized.endsWith('/consumers')) {
            normalized += '/consumers';
        }
        return normalized + '/exists';
    }

    private String normalizeConsumersBaseUrl(String baseUrl) {
        String normalized = String.isNotBlank(baseUrl) ? baseUrl.trim() : '';
        Integer queryIndex = normalized.indexOf('?');
        if (queryIndex >= 0) {
            normalized = normalized.substring(0, queryIndex);
        }
        while (normalized.endsWith('/')) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }
        Integer consumersIndex = normalized.toLowerCase().indexOf('/consumers');
        if (consumersIndex >= 0) {
            return normalized.substring(0, consumersIndex + '/consumers'.length());
        }
        Integer agentforceIndex = normalized.toLowerCase().indexOf('/agentforce');
        if (agentforceIndex >= 0) {
            return normalized.substring(0, agentforceIndex + '/agentforce'.length()) + '/consumers';
        }
        return normalized + '/consumers';
    }

    private String getAccessToken() {
        if (String.isNotBlank(CEMS_BATCH_AUTH_TOKEN)) {
            return CEMS_BATCH_AUTH_TOKEN;
        }

        Blob authHeader = Blob.valueOf(KNOWHER_KEY + ':' + KNOWHER_SECRET);
        String authHeaderParams = 'Basic ' + EncodingUtil.base64Encode(authHeader);
        HttpRequest request = buildRequest(
            'POST',
            ACCESS_TOKEN_URL,
            authHeaderParams,
            'grant_type=client_credentials',
            false,
            true
        );
        Http http = new Http();

        try {
            HttpResponse response = http.send(request);
            Map<String, Object> returnedResults = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            CEMS_BATCH_AUTH_TOKEN = 'Bearer ' + String.valueOf(returnedResults.get('access_token'));
            return CEMS_BATCH_AUTH_TOKEN;
        } catch (Exception ex) {
            return ACCESS_TOKEN_FAILURE;
        }
    }

    private HttpRequest buildRequest(
        String calloutMethod,
        String urlEndpoint,
        String authHeaderValue,
        String requestBody,
        Boolean needsClient,
        Boolean isGeneratingAccess
    ) {
        HttpRequest request = new HttpRequest();
        request.setTimeout(40000);
        request.setMethod(calloutMethod);
        request.setEndpoint(urlEndpoint);
        request.setHeader('Authorization', authHeaderValue);

        if (needsClient) {
            request.setHeader('client', CLIENT_HEADER);
        }
        if (isGeneratingAccess) {
            request.setHeader('X-Gravitee-Api-Key', X_GRAVITEE_API_KEY);
            request.setHeader('Content-Type', CONTENT_TYPE);
        } else if (String.isNotBlank(CONTENT_TYPE_JSON)) {
            request.setHeader('Content-Type', CONTENT_TYPE_JSON);
        }
        if (requestBody != null) {
            request.setBody(requestBody);
        }
        return request;
    }

    private static Agentforce_CEMS_CustomerData_Wrapper errorWrapper(String code, String message) {
        Agentforce_CEMS_CustomerData_Wrapper wrapper = new Agentforce_CEMS_CustomerData_Wrapper();
        wrapper.Errors = new List<Agentforce_CEMS_CustomerData_Wrapper.Errors>{ errorItem(code, message) };
        return wrapper;
    }

    private static List<Agentforce_CEMS_CustomerData_Wrapper.Errors> ensureErrors(Agentforce_CEMS_CustomerData_Wrapper wrapper) {
        if (wrapper.Errors == null) {
            wrapper.Errors = new List<Agentforce_CEMS_CustomerData_Wrapper.Errors>();
        }
        return wrapper.Errors;
    }

    private static Agentforce_CEMS_CustomerData_Wrapper.Errors errorItem(String code, String message) {
        Agentforce_CEMS_CustomerData_Wrapper.Errors error = new Agentforce_CEMS_CustomerData_Wrapper.Errors();
        error.ErrorCode = code;
        error.ErrorMessage = message;
        return error;
    }
}
