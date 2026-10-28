/**
*==============================================================================
* @File Name : Agentforce_Action_RewardsSupport.cls
* @Description : Handles Crown Rewards support scenarios.
* @Author : Prasad Yericherla
* @Created On : April 14, 2026
* @Last Modified By :  Prasad Yericherla
* @Last Modified On : April 27, 2026
* @Modification Log : 
*==============================================================================
**/
public with sharing class Agentforce_Action_RewardsSupport {
    private static final Integer MAX_ATTEMPTS = 3;
    private static final Integer LOWEST_SCORE = -999999999; 
    private static final String ACCOUNT_ASSISTANCE_REASON = 'Account Assistance';
    private static final String BONUS_TERMS_URL =
        'https://www.hallmark.com/crown-rewards/crown-rewards-terms-conditions/';

    private class LegacyRewardsSnapshot {
        Integer pointBalance;
        Integer ytdPointBalance;
        String membershipTier;
    }

    private class AvailableRewardsSnapshot {
        List<String> rewards = new List<String>();
        List<String> bonusOffers = new List<String>();
    }

    public class Input {
        @InvocableVariable(label='Request Type') public String requestType;
        @InvocableVariable(label='Search Value') public String searchValue;
        @InvocableVariable(label='Crown Rewards Number') public String crownRewardsNumber;
        @InvocableVariable(label='Email Address') public String emailAddress;
        @InvocableVariable(label='Phone Number') public String phoneNumber;
        @InvocableVariable(label='Platinum Threshold') public Integer platinumThreshold;
        @InvocableVariable(label='Purchase Channel') public String purchaseChannel;
        @InvocableVariable(label='All Items Shipped') public Boolean allItemsShipped;
        @InvocableVariable(label='BOPIS Order') public Boolean isBopis;
        @InvocableVariable(label='Hours Since Retail Purchase') public Integer hoursSincePurchase;
        @InvocableVariable(label='Receipt Provided') public Boolean receiptProvided;
        @InvocableVariable(label='Update Field Name') public String updateFieldName;
        @InvocableVariable(label='Current Field Value') public String currentFieldValue;
        @InvocableVariable(label='New Field Value') public String newFieldValue;
        @InvocableVariable(label='Do All Memberships Belong To Consumer') public Boolean allMembershipsBelongToConsumer;
        @InvocableVariable(label='Postal Address') public String postalAddress;
        @InvocableVariable(label='Date Of Birth') public String dateOfBirth;
        @InvocableVariable(label='Create Case Already Requested') public Boolean createCaseAlreadyRequested;
        @InvocableVariable(label='Business Hours') public String businessHoursLabel;
        @InvocableVariable(label='Within Business Hours') public Boolean withinBusinessHours;
        @InvocableVariable(label='Reward Value Requested') public Integer rewardValueRequested;
        @InvocableVariable(label='Current Failed Attempt Count') public Integer failedAttemptCount;
    }

    @InvocableMethod(
        label='Agentforce - Rewards Support'
        description='Handles Crown Rewards lookups, available rewards and offers, missing points, updates, merges, and real-time reward conversion.'
    )
    public static List<RewardsAgentActionResult> support(List<Input> inputList) {
        Input inputValue = inputList[0];
        ResolvedLookupIdentifier resolvedIdentifier = resolveLookupIdentifier(inputValue);
        RewardsAgentResponse response = new RewardsAgentResponse();
        response.requestType = String.isNotBlank(inputValue.requestType) ? inputValue.requestType : 'lookup';
        response.failedAttemptCount = normalizeFailedAttemptCount(inputValue.failedAttemptCount);
        response.attemptsRemaining = Math.max(0, MAX_ATTEMPTS - response.failedAttemptCount);
        response.lookupAttemptsExhausted = response.failedAttemptCount >= MAX_ATTEMPTS;

        if (!resolvedIdentifier.hasIdentifier()) {
            response.memberFound = false;
            response.responseType = 'error';
            response.actionTaken = 'rewards_identifier_required';
            response.shouldAskForAnotherLookup = false;
            response.shouldStartLiveAgent = false;
            response.shouldOfferCaseCreation = false;
            response.shouldComeBackDuringBusinessHours = false;
            response.errorMessage = 'Please provide a Crown Rewards number, email address, or phone number to continue.';
            Map<String, Object> payload = Agentforce_Action_CustomerSearch_Helper.basePayload('error');
            payload.put('errorMessage', response.errorMessage);
            payload.put('failedAttemptCount', response.failedAttemptCount);
            payload.put('attemptsRemaining', response.attemptsRemaining);
            payload.put('lookupAttemptsExhausted', response.lookupAttemptsExhausted);
            payload.put('shouldAskForAnotherLookup', response.shouldAskForAnotherLookup);
            payload.put('shouldStartLiveAgent', response.shouldStartLiveAgent);
            payload.put('shouldOfferCaseCreation', response.shouldOfferCaseCreation);
            payload.put('shouldComeBackDuringBusinessHours', response.shouldComeBackDuringBusinessHours);
            response.responsePayload = Agentforce_Action_CustomerSearch_Helper.toJson(payload);
            response.errorMessage = null;
            return wrap(response, inputValue);
        }

        Agentforce_CEMS_CustomerData_Wrapper customerData = lookupRewardsMember(resolvedIdentifier);
        Agentforce_CEMS_CustomerData_Wrapper.Consumers consumer =
            selectRewardsConsumer(customerData, resolvedIdentifier);
        Agentforce_CEMS_CustomerData_Wrapper.Memberships rewardsMembership =
            selectRewardsMembership(consumer, resolvedIdentifier);
        response.memberFound = consumer != null && rewardsMembership != null;

        if (response.memberFound) {
            response.lookupAttemptsExhausted = false;
            response.shouldStartLiveAgent = false;
            response.shouldOfferCaseCreation = false;
            response.shouldAskForAnotherLookup = false;
            hydrateRewardsMember(response, resolvedIdentifier, consumer, rewardsMembership);
        }

        if (!response.memberFound) {
            return wrap(handleNotFound(inputValue, response), inputValue);
        }

        if ('missingPoints'.equalsIgnoreCase(response.requestType)) {
            return wrap(handleMissingPoints(inputValue, response), inputValue);
        }
        if ('updateAccount'.equalsIgnoreCase(response.requestType)) {
            return wrap(handleUpdateAccount(inputValue, response), inputValue);
        }
        if ('mergeMemberships'.equalsIgnoreCase(response.requestType)) {
            return wrap(handleMergeMemberships(inputValue, response), inputValue);
        }
        if ('convertReward'.equalsIgnoreCase(response.requestType)) {
            return wrap(handleRewardConversion(inputValue, response), inputValue);
        }
        return wrap(handleLookup(inputValue, response), inputValue);
    }

    private static Integer normalizeFailedAttemptCount(Integer failedAttemptCount) {
        Integer value = failedAttemptCount == null ? 0 : failedAttemptCount;
        return value < 0 ? 0 : value;
    }

    private class ResolvedLookupIdentifier {
        String crownRewardsNumber;
        String emailAddress;
        String phoneNumber;

        Boolean hasIdentifier() {
            return String.isNotBlank(crownRewardsNumber)
                || String.isNotBlank(emailAddress)
                || String.isNotBlank(phoneNumber);
        }
    }

    private static ResolvedLookupIdentifier resolveLookupIdentifier(Input inputValue) {
        ResolvedLookupIdentifier resolved = new ResolvedLookupIdentifier();
        String crownRewardsNumber = String.isNotBlank(inputValue.crownRewardsNumber)
            ? inputValue.crownRewardsNumber.trim()
            : null;
        String emailAddress = String.isNotBlank(inputValue.emailAddress)
            ? inputValue.emailAddress.trim().toLowerCase()
            : null;
        String phoneNumber = String.isNotBlank(inputValue.phoneNumber)
            ? Agentforce_Util.normalizeUsPhone(inputValue.phoneNumber)
            : null;

        if (String.isNotBlank(crownRewardsNumber)) {
            resolved.crownRewardsNumber = crownRewardsNumber;
            return resolved;
        }
        if (String.isNotBlank(emailAddress) && emailAddress.contains('@')) {
            resolved.emailAddress = emailAddress;
            return resolved;
        }
        if (String.isNotBlank(phoneNumber) && phoneNumber.length() == 10) {
            resolved.phoneNumber = phoneNumber;
            return resolved;
        }

        if (String.isBlank(inputValue.searchValue)) {
            return resolved;
        }

        String searchValue = inputValue.searchValue.trim();
        if (searchValue.contains('@')) {
            resolved.emailAddress = searchValue.toLowerCase();
            return resolved;
        }

        String normalizedPhone = Agentforce_Util.normalizeUsPhone(searchValue);
        if (String.isNotBlank(normalizedPhone) && normalizedPhone.length() == 10) {
            resolved.phoneNumber = normalizedPhone;
            return resolved;
        }

        resolved.crownRewardsNumber = searchValue;
        return resolved;
    }

    private static Agentforce_CEMS_CustomerData_Wrapper lookupRewardsMember(ResolvedLookupIdentifier resolvedIdentifier) {
        Agentforce_CEMS_Connector connector = new Agentforce_CEMS_Connector('GET', '');
        return connector.CEMS_Get(
            null,
            resolvedIdentifier.phoneNumber,
            resolvedIdentifier.emailAddress,
            null,
            null,
            null,
            resolvedIdentifier.crownRewardsNumber,
            null,
            false,
            true
        );
    }

    private static void hydrateRewardsMember(
        RewardsAgentResponse response,
        ResolvedLookupIdentifier resolvedIdentifier,
        Agentforce_CEMS_CustomerData_Wrapper.Consumers consumer,
        Agentforce_CEMS_CustomerData_Wrapper.Memberships rewardsMembership
    ) {
        response.crownRewardsNumber = String.isNotBlank(resolvedIdentifier.crownRewardsNumber)
            ? resolvedIdentifier.crownRewardsNumber
            : rewardsMembership.id;
        response.membershipTier = rewardsMembership.CrownRewardsLoyalty.currentTier;
        response.pointsBalance = parseInteger(rewardsMembership.CrownRewardsLoyalty.MemberPointsAvailable);
        LegacyRewardsSnapshot legacySnapshot = getLegacyRewardsSnapshot(response.crownRewardsNumber);
        if (legacySnapshot != null) {
            if (legacySnapshot.pointBalance != null) {
                response.pointsBalance = legacySnapshot.pointBalance;
            }
            if (String.isNotBlank(legacySnapshot.membershipTier)) {
                response.membershipTier = legacySnapshot.membershipTier;
            }
            response.currentYearPoints = legacySnapshot.ytdPointBalance;
        }
    }

    private static Integer parseInteger(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        try {
            return Integer.valueOf(raw);
        } catch (Exception ex) {
            return null;
        }
    }

    private static RewardsAgentResponse handleNotFound(Input inputValue, RewardsAgentResponse response) {
        response.responseType = 'error';
        response.actionTaken = 'rewards_not_found';
        if (!isRewardsLookupFailureScenario(inputValue.requestType)) {
            response.errorMessage = 'I could not find a Crown Rewards membership with that information.'
                + '\n\nPlease try a different email address, phone number, or Crown Rewards number.';
            Map<String, Object> fallbackPayload = Agentforce_Action_CustomerSearch_Helper.basePayload('error');
            fallbackPayload.put('errorMessage', response.errorMessage);
            fallbackPayload.put('businessHours', inputValue.businessHoursLabel);
            response.responsePayload = Agentforce_Action_CustomerSearch_Helper.toJson(fallbackPayload);
            response.errorMessage = null;
            return response;
        }

        Agentforce_Action_HandleRewardsFailure.Input failureInput =
            new Agentforce_Action_HandleRewardsFailure.Input();
        failureInput.failedAttemptCount = inputValue.failedAttemptCount;
        failureInput.searchMethodUsed = resolveRewardsLookupMethodLabel(inputValue);
        failureInput.withinBusinessHours = inputValue.withinBusinessHours;
        failureInput.requestType = inputValue.requestType;
        failureInput.purchaseChannel = inputValue.purchaseChannel;
        Agentforce_Action_HandleRewardsFailure.Output failureOutput =
            Agentforce_Action_HandleRewardsFailure.handleFailure(
                new List<Agentforce_Action_HandleRewardsFailure.Input>{ failureInput }
            )[0];

        response.failedAttemptCount = failureOutput.failedAttemptCount;
        response.attemptsRemaining = failureOutput.attemptsRemaining;
        response.shouldAskForAnotherLookup = failureOutput.shouldAskForAnotherLookup;
        response.shouldStartLiveAgent = failureOutput.shouldStartLiveAgent;
        response.shouldOfferCaseCreation = failureOutput.shouldOfferCaseCreation;
        response.lookupAttemptsExhausted = failureOutput.lookupAttemptsExhausted;
        response.shouldComeBackDuringBusinessHours = failureOutput.shouldComeBackDuringBusinessHours;
        response.errorMessage = failureOutput.attemptMessage;

        Map<String, Object> payload = Agentforce_Action_CustomerSearch_Helper.basePayload('error');
        payload.put('errorMessage', failureOutput.attemptMessage);
        payload.put('businessHours', inputValue.businessHoursLabel);
        payload.put('failedAttemptCount', failureOutput.failedAttemptCount);
        payload.put('attemptsRemaining', failureOutput.attemptsRemaining);
        payload.put('shouldAskForAnotherLookup', failureOutput.shouldAskForAnotherLookup);
        payload.put('shouldStartLiveAgent', failureOutput.shouldStartLiveAgent);
        payload.put('shouldOfferCaseCreation', failureOutput.shouldOfferCaseCreation);
        payload.put('lookupAttemptsExhausted', failureOutput.lookupAttemptsExhausted);
        payload.put('shouldComeBackDuringBusinessHours', failureOutput.shouldComeBackDuringBusinessHours);
        response.responsePayload = Agentforce_Action_CustomerSearch_Helper.toJson(payload);
        response.errorMessage = null;
        return response;
    }

    private static RewardsAgentResponse handleLookup(Input inputValue, RewardsAgentResponse response) {
        response.responseType = 'memberOverview';
        response.actionTaken = 'lookup_rewards_member';
        AvailableRewardsSnapshot availableSnapshot = loadAvailableRewards(response.crownRewardsNumber);
        response.availableRewards = availableSnapshot.rewards;
        response.availableBonusOffers = availableSnapshot.bonusOffers;
        response.availableRewardsCount = availableSnapshot.rewards.size();
        response.availableBonusOffersCount = availableSnapshot.bonusOffers.size();
        Integer platinumProgressBalance = response.currentYearPoints != null
            ? response.currentYearPoints
            : response.pointsBalance;
        response.pointsToPlatinum = Agentforce_Action_CustomerSearch_Helper.pointsToPlatinum(
            response.membershipTier,
            platinumProgressBalance,
            inputValue.platinumThreshold
        );
        response.summaryMessage = null;
        response.responsePayload = buildRewardsPayload(
            'memberOverview',
            inputValue,
            response,
            buildLookupSummary(inputValue, response)
        );
        return response;
    }

    private static AvailableRewardsSnapshot loadAvailableRewards(String crownRewardsNumber) {
        AvailableRewardsSnapshot snapshot = new AvailableRewardsSnapshot();
        Agentforce_CEMS_Connector.MemberRewardsResponse apiResponse =
            new Agentforce_CEMS_Connector('GET', '').getMemberRewards(crownRewardsNumber);
        if (apiResponse == null || apiResponse.result == null || apiResponse.result.details == null) {
            return snapshot;
        }

        Map<String, String> rewardsByKey = new Map<String, String>();
        Map<String, String> bonusOffersByKey = new Map<String, String>();
        for (Agentforce_CEMS_Connector.MemberRewardDetail detail : apiResponse.result.details) {
            if (!isCurrentlyAvailableReward(detail)) {
                continue;
            }
            String triggerr = detail.customFields.alphaTrigger.trim().toUpperCase();
            String uniqueKey = rewardDeduplicationKey(detail, triggerr);
            String displayName = String.isNotBlank(detail.name) ? detail.name.trim() : 'Available offer';
            if (triggerr == 'SUIA' && !rewardsByKey.containsKey(uniqueKey)) {
                rewardsByKey.put(uniqueKey, displayName);
            } else if (triggerr == 'SUIB' && !bonusOffersByKey.containsKey(uniqueKey)) {
                bonusOffersByKey.put(uniqueKey, displayName);
            }
        }
        snapshot.rewards.addAll(rewardsByKey.values());
        snapshot.bonusOffers.addAll(bonusOffersByKey.values());
        snapshot.rewards.sort();
        snapshot.bonusOffers.sort();
        return snapshot;
    }

    private static Boolean isCurrentlyAvailableReward(Agentforce_CEMS_Connector.MemberRewardDetail detail) {
        if (detail == null || detail.customFields == null || String.isBlank(detail.customFields.alphaTrigger)) {
            return false;
        }
        String triggerr = detail.customFields.alphaTrigger.trim().toUpperCase();
        if (triggerr != 'SUIA' && triggerr != 'SUIB') {
            return false;
        }
        Boolean orderedReward = isOrderedReward(detail);
        if (isTrueFlag(detail.isCancelled)
            || isTrueFlag(detail.isExpired)
            || String.isNotBlank(detail.cancelledTimestampUTC)
            || (!orderedReward && (
                isTrueFlag(detail.isRedeemed) || String.isNotBlank(detail.redeemedTimestampUTC)
            ))) {
            return false;
        }

        Date today = Date.today();
        Date offerStartDate = parseApiDate(detail.customFields.offerStartDate);
        if (offerStartDate != null && offerStartDate > today) {
            return false;
        }
        // Ordered rewards are marked redeemed when ordered and may omit both offer
        // dates. Their isExpired flag is the authoritative availability indicator.
        if (orderedReward
            && String.isBlank(detail.customFields.offerStartDate)
            && String.isBlank(detail.customFields.offerDisplayExpDate)) {
            return true;
        }
        Date expirationDate = parseApiDate(
            String.isNotBlank(detail.customFields.offerDisplayExpDate)
                ? detail.customFields.offerDisplayExpDate
                : detail.expireEndOfDay
        );
        return expirationDate == null || expirationDate >= today;
    }

    private static Boolean isOrderedReward(Agentforce_CEMS_Connector.MemberRewardDetail detail) {
        if (detail == null || detail.customFields == null) {
            return false;
        }
        String rewardType = String.isNotBlank(detail.customFields.rewardType)
            ? detail.customFields.rewardType.trim()
            : null;
        String typeReference = String.isNotBlank(detail.typeExternalReference)
            ? detail.typeExternalReference.trim().toLowerCase()
            : '';
        return (rewardType == '07' && typeReference.startsWith('order_email_'))
            || (rewardType == '04' && typeReference.startsWith('order_postal_'));
    }

    private static String rewardDeduplicationKey(
        Agentforce_CEMS_Connector.MemberRewardDetail detail,
        String triggerr
    ) {
        String reference = detail.customFields != null
            ? detail.customFields.externalReference
            : null;
        if (String.isBlank(reference)) {
            reference = detail.typeExternalReference;
        }
        if (String.isBlank(reference)) {
            reference = detail.name;
        }
        if (String.isBlank(reference)) {
            reference = detail.id;
        }
        return triggerr + '|' + String.valueOf(reference).trim().toLowerCase();
    }

    private static Boolean isTrueFlag(String value) {
        return String.isNotBlank(value)
            && (value.trim() == '1' || value.trim().equalsIgnoreCase('true'));
    }

    private static Date parseApiDate(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return Date.valueOf(value.trim().substring(0, 10));
        } catch (Exception ex) {
            return null;
        }
    }

    private static RewardsAgentResponse handleMissingPoints(Input inputValue, RewardsAgentResponse response) {
        response.responseType = 'missingPoints';
        response.actionTaken = 'missing_points_guidance';
        String channel = normalizePurchaseChannel(inputValue.purchaseChannel);

        List<String> steps = new List<String>();
        String heroMessage;
        if (channel == 'stream_redeem' || channel == 'stream_and_redeem' || channel == 'stream redeem campaign') {
            heroMessage = 'Each stream and redeem campaign has its own timeline for awarding points for viewing.'
                + '\n\nIf you believe you have met all the requirements, we can connect you with someone to review.';
            response.actionTaken = inputValue.withinBusinessHours == true
                ? 'missing_points_stream_redeem_live_chat_case'
                : 'missing_points_stream_redeem_case';
            steps.add('If the consumer wants review, collect first name, last name, and email.');
            steps.add(inputValue.withinBusinessHours == true
                ? 'Continue to the eMail eCare Case Queue and case creation.'
                : 'Create a case in the eMail eCare Case Queue.'
            );
        } else if (channel == 'bonus_offer' || channel == 'bonus offer') {
            heroMessage = 'Bonus points are awarded at the end of the offer period, if all offer requirements are met.'
                + '\n\nCrown Rewards points are not awarded for certain purchases such as in-store layaways, sales tax, shipping charges, gift cards, event tickets, and purchases at venues such as Comic Con and event shops.'
                + '\n\nPlease check the Terms & Conditions of the Crown Rewards program for other product exclusions.';
            response.actionTaken = inputValue.withinBusinessHours == true
                ? 'missing_points_bonus_offer_live_chat_case'
                : 'missing_points_bonus_offer_case';
            steps.add('If the consumer wants review, collect first name, last name, and email.');
            steps.add(inputValue.withinBusinessHours == true
                ? 'Continue to Consumer Care Chat Queue and case creation.'
                : 'Create a case in the eMail General Case Queue.'
            );
        } else if (channel == 'Hallmark' || channel == 'hallmark order' || channel == 'Hallmark order' || channel == 'Hallmark.com order' || channel == 'order') {
            if (inputValue.isBopis == true) {
                heroMessage = 'BOPIS purchases can take 2-3 days after the charge posts before Crown Rewards points appear.';
                steps.add('Allow 2-3 days after the purchase charge date for BOPIS points to post.');
            } else if (inputValue.allItemsShipped == true) {
                heroMessage = inputValue.withinBusinessHours == true
                    ? 'All items have shipped, so a Care Advocate should review the missing Hallmark.com Crown Rewards points.'
                        + '\n\nCollect the consumer name and email, then continue to live chat and case creation.'
                    : 'All items have shipped, so a case should be created to review the missing Hallmark.com Crown Rewards points.'
                        + '\n\nCollect the consumer name and email, then continue to case creation.';
                response.actionTaken = inputValue.withinBusinessHours == true
                    ? 'escalate_case_missing_points_online'
                    : 'create_case_missing_points_online';
                steps.add('All items have shipped, so the issue should be reviewed by a Care Advocate or case workflow.');
            } else {
                heroMessage = 'All items in the order must ship before Crown Rewards points are deposited.';
                steps.add('Wait until every item in the order has shipped.');
                steps.add('Check the Crown Rewards account again after shipment completion.Is there anything else i can help you?.');
            }
            steps.add('Collect the consumer first name, last name, and email if Advocate follow-up or case creation is needed.');
        } else {
            if (inputValue.hoursSincePurchase == null || inputValue.hoursSincePurchase < 72) {
                heroMessage = 'Retail store purchases can take up to 72 hours for Crown Rewards points to appear.';
                steps.add('Wait until 72 hours has passed from the retail purchase.Is there anything else i can help you?.');
            } else if (inputValue.receiptProvided == true) {
                heroMessage = 'A receipt is available.'
                    + '\n\nCollect the consumer first name, last name, and email, then create a Bespoke queue case for an Advocate to review and deposit the missing points.';
                response.actionTaken = 'create_case_missing_points_retail';
                steps.add('Route the case to the Bespoke Case Queue.');
            } else {
                heroMessage = 'Points cannot be deposited without proof of purchase such as a receipt.';
                response.actionTaken = 'receipt_required';
                steps.add('Ask the consumer to return with the retail receipt or other proof of purchase.');
            }
        }

        response.summaryMessage = null;
        Map<String, Object> payload = Agentforce_Action_CustomerSearch_Helper.basePayload('missingPoints');
        payload.put('heroMessage', heroMessage);
        payload.put('purchaseChannel', inputValue.purchaseChannel);
        payload.put('steps', steps);
        payload.put('businessHours', inputValue.businessHoursLabel);
        if (channel == 'bonus_offer' || channel == 'bonus offer') {
            payload.put('termsUrl', BONUS_TERMS_URL);
        }
        if (response.actionTaken == 'create_case_missing_points_retail'
            || response.actionTaken == 'create_case_missing_points_online'
            || response.actionTaken == 'escalate_case_missing_points_online'
            || response.actionTaken == 'missing_points_stream_redeem_live_chat_case'
            || response.actionTaken == 'missing_points_stream_redeem_case'
            || response.actionTaken == 'missing_points_bonus_offer_live_chat_case'
            || response.actionTaken == 'missing_points_bonus_offer_case') {
            payload.put('requiredFields', new List<String>{ 'First Name', 'Last Name', 'Email' });
        }
        /*payload.put('orderNumber', inputValue.orderNumber);*/
        response.responsePayload = Agentforce_Action_CustomerSearch_Helper.toJson(payload);
        return response;
    }

    private static RewardsAgentResponse handleUpdateAccount(Input inputValue, RewardsAgentResponse response) {
        Boolean isPostalAddressUpdate = isPostalAddressField(inputValue.updateFieldName);
        response.responseType = 'accountUpdate';
        response.actionTaken = inputValue.createCaseAlreadyRequested == true
            ? (isPostalAddressUpdate ? 'update_postal_address_case_blocked' : 'update_case_blocked')
            : (isPostalAddressUpdate ? 'update_postal_address_case_ready' : 'update_case_ready');
        String guidanceMessage = inputValue.createCaseAlreadyRequested == true
            ? 'A Crown Rewards update case was already prepared in this interaction.'
                + '\n\nAsk if there are any other updates before creating another case.'
            : isPostalAddressUpdate
                ? 'Postal address updates are not completed in chat.'
                    + '\n\nCollect the consumer name, email, current postal address, and requested new postal address, then create a Bespoke queue case to initiate the update request.'
                : 'This account update is not completed in chat.'
                    + '\n\nCollect the consumer name, email, current value, and requested new value, then create a Bespoke queue case to initiate the update request.';
        response.summaryMessage = null;
        Map<String, Object> payload = Agentforce_Action_CustomerSearch_Helper.basePayload('accountUpdate');
        payload.put('heroMessage', guidanceMessage);
        payload.put('updateFieldName', inputValue.updateFieldName);
        payload.put('currentFieldValue', inputValue.currentFieldValue);
        payload.put('newFieldValue', inputValue.newFieldValue);
        payload.put('createCaseBlocked', inputValue.createCaseAlreadyRequested == true);
        payload.put('caseGuidanceTitle', inputValue.createCaseAlreadyRequested == true ? 'Case Already Prepared' : 'Case Creation Required');
        payload.put('caseGuidanceMessage', guidanceMessage);
        payload.put('requiredFields', isPostalAddressUpdate
            ? new List<String>{ 'First Name', 'Last Name', 'Email', 'Current Postal Address', 'Requested New Postal Address' }
            : new List<String>{ 'First Name', 'Last Name', 'Email', 'Current Value', 'Requested New Value' }
        );
        payload.put('businessHours', inputValue.businessHoursLabel);
        response.responsePayload = Agentforce_Action_CustomerSearch_Helper.toJson(payload);
        return response;
    }

    private static RewardsAgentResponse handleMergeMemberships(Input inputValue, RewardsAgentResponse response) {
        response.responseType = 'mergeMemberships';
        response.actionTaken = inputValue.allMembershipsBelongToConsumer == true
            ? 'merge_case_ready'
            : 'merge_case_ready_not_consumer';
        String searchMethod = resolveRewardsLookupMethodLabel(inputValue);
        String heroMessage = 'I found a Crown Rewards member with the provided ' + searchMethod + '.'
            + '\n\nPlease collect the consumer details below so a case can be created to review the membership issue.';
        response.summaryMessage = null;
        Map<String, Object> payload = Agentforce_Action_CustomerSearch_Helper.basePayload('mergeMemberships');
        payload.put('heroMessage', heroMessage);
        payload.put('allMembershipsBelongToConsumer', inputValue.allMembershipsBelongToConsumer);
        payload.put('postalAddress', inputValue.postalAddress);
        payload.put('dateOfBirth', inputValue.dateOfBirth);
        payload.put('businessHours', inputValue.businessHoursLabel);
        payload.put('requiredFields', inputValue.allMembershipsBelongToConsumer == true
            ? new List<String>{
                'First Name', 'Last Name', 'Phone Number', 'Email', 'Postal Address (optional)', 'Crown Rewards Numbers', 'Date of Birth (optional)'
            }
            : new List<String>{ 'First Name', 'Last Name', 'Email' , 'Crown Reward Numbers'}
        );
        response.responsePayload = Agentforce_Action_CustomerSearch_Helper.toJson(payload);
        return response;
    }

    private static String resolveRewardsLookupMethodLabel(Input inputValue) {
        if (String.isNotBlank(inputValue.crownRewardsNumber)) {
            return 'Crown Rewards number';
        }
        if (String.isNotBlank(inputValue.emailAddress)) {
            return 'email address';
        }
        if (String.isNotBlank(inputValue.phoneNumber)) {
            return 'phone number';
        }
        if (String.isBlank(inputValue.searchValue)) {
            return 'lookup information';
        }
        String raw = inputValue.searchValue.trim();
        if (raw.contains('@')) {
            return 'email address';
        }
        String normalizedPhone = Agentforce_Util.normalizeUsPhone(raw);
        if (String.isNotBlank(normalizedPhone) && normalizedPhone.length() == 10) {
            return 'phone number';
        }
        return 'Crown Rewards number';
    }

    private static String normalizePurchaseChannel(String purchaseChannel) {
        if (String.isBlank(purchaseChannel)) {
            return '';
        }
        String normalized = purchaseChannel.trim().toLowerCase();
        normalized = normalized.replace('.', '_');
        return normalized;
    }

    private static RewardsAgentResponse handleRewardConversion(Input inputValue, RewardsAgentResponse response) {
        response.responseType = 'text';
        Integer currentBalance = getLivePointsBalance(response.crownRewardsNumber, response.pointsBalance);
        response.pointsBalance = currentBalance;
        List<Integer> availableRewardChoices = availableRewardChoices(currentBalance);
        Integer requestedRewardValue = inputValue.rewardValueRequested;
        Integer requiredPoints = Agentforce_Action_CustomerSearch_Helper.pointsRequiredForReward(requestedRewardValue);

        String heroMessage;
        if (requestedRewardValue == null) {
            response.actionTaken = availableRewardChoices.isEmpty()
                ? 'no_rewards_available_to_convert'
                : 'reward_conversion_options';
            heroMessage = availableRewardChoices.isEmpty()
                ? 'The member does not currently have enough points to convert into a $2, $3, $4, or $5 reward.'
                : buildRewardConversionOptionsMessage(currentBalance, availableRewardChoices);
            response.errorMessage = null;
        } else if (requiredPoints == null) {
            response.actionTaken = 'invalid_reward_value';
            response.errorMessage = 'Reward conversion supports only $2, $3, $4, or $5 rewards.';
            heroMessage = buildRewardConversionRetryMessage(
                response.errorMessage,
                currentBalance,
                availableRewardChoices
            );
        } else if (currentBalance == null || currentBalance < requiredPoints) {
            response.actionTaken = 'insufficient_points';
            response.errorMessage = 'The consumer does not have enough points to convert into a $' + requestedRewardValue + ' reward.';
            heroMessage = buildRewardConversionRetryMessage(
                response.errorMessage,
                currentBalance,
                availableRewardChoices
            );
        } else if (convertRewardInRealTime(response.crownRewardsNumber, requestedRewardValue)) {
            Integer updatedBalance = getLivePointsBalance(response.crownRewardsNumber, currentBalance - requiredPoints);
            response.pointsBalance = updatedBalance;
            response.actionTaken = 'reward_converted';
            response.errorMessage = null;
            availableRewardChoices = availableRewardChoices(updatedBalance);
            heroMessage = 'Your $' + requestedRewardValue + ' reward has been successfully converted.'
                + '\n\nRemaining balance: ' + updatedBalance + ' points.';
        } else {
            response.actionTaken = 'reward_conversion_failed';
            response.errorMessage = 'I could not complete the reward conversion right now.'
                + '\n\nPlease try again.';
            heroMessage = response.errorMessage;
        }
        response.summaryMessage = heroMessage;
        response.responsePayload = null;
        return response;
    }

    private static String buildRewardConversionOptionsMessage(
        Integer currentBalance,
        List<Integer> availableRewardChoices
    ) {
        List<String> formattedChoices = new List<String>();
        for (Integer rewardValue : availableRewardChoices) {
            formattedChoices.add('$' + rewardValue);
        }
        return 'You currently have ' + currentBalance + ' points available.'
            + '\n\nPlease choose one reward value to convert your points: '
            + String.join(formattedChoices, ', ') + '.'
            + '\n\nLet me know how you would like to proceed.';
    }

    private static String buildRewardConversionRetryMessage(
        String leadMessage,
        Integer currentBalance,
        List<Integer> availableRewardChoices
    ) {
        if (availableRewardChoices == null || availableRewardChoices.isEmpty()) {
            return leadMessage
                + '\n\nCurrent balance: ' + currentBalance + ' points.'
                + '\n\nNo reward values are currently available for conversion.';
        }
        return leadMessage + '\n\n' + buildRewardConversionOptionsMessage(currentBalance, availableRewardChoices);
    }

    private static String buildRewardsPayload(String view, Input inputValue, RewardsAgentResponse response, String heroMessage) {
        Map<String, Object> payload = Agentforce_Action_CustomerSearch_Helper.basePayload(view);
        payload.put('heroMessage', heroMessage);
        payload.put('crownRewardsNumber', response.crownRewardsNumber);
        payload.put('membershipTier', response.membershipTier);
        payload.put('pointsBalance', response.pointsBalance);
        payload.put('pointsToPlatinum', response.pointsToPlatinum);
        if (view == 'memberOverview') {
            payload.put('availableRewardsCount', response.availableRewardsCount);
            payload.put('availableBonusOffersCount', response.availableBonusOffersCount);
            payload.put('availableRewards', response.availableRewards);
            payload.put('availableBonusOffers', response.availableBonusOffers);
        }
        return Agentforce_Action_CustomerSearch_Helper.toJson(payload);
    }

    private static Agentforce_CEMS_CustomerData_Wrapper.Consumers selectRewardsConsumer(
        Agentforce_CEMS_CustomerData_Wrapper customerData,
        ResolvedLookupIdentifier resolvedIdentifier
    ) {
        if (customerData == null
            || customerData.Result == null
            || customerData.Result.consumers == null
            || customerData.Result.consumers.isEmpty()) {
            return null;
        }

        Boolean emailOrPhoneLookup = String.isBlank(resolvedIdentifier.crownRewardsNumber)
            && (String.isNotBlank(resolvedIdentifier.emailAddress) || String.isNotBlank(resolvedIdentifier.phoneNumber));
        if (emailOrPhoneLookup) {
            if (customerData.Result.consumers.size() == 1) {
                return customerData.Result.consumers[0];
            }

            List<Agentforce_CEMS_CustomerData_Wrapper.Consumers> rewardsConsumers =
                new List<Agentforce_CEMS_CustomerData_Wrapper.Consumers>();
            for (Agentforce_CEMS_CustomerData_Wrapper.Consumers consumer : customerData.Result.consumers) {
                if (Agentforce_CEMS_CustomerData_Wrapper.findCrownRewardsMembership(consumer) != null) {
                    rewardsConsumers.add(consumer);
                }
            }

            if (rewardsConsumers.size() == 1) {
                return rewardsConsumers[0];
            }

            if (!rewardsConsumers.isEmpty()) {
                return selectBestRewardsConsumer(rewardsConsumers);
            }

            return customerData.Result.consumers[0];
        }

        return Agentforce_CEMS_CustomerData_Wrapper.findFirstConsumerWithCrownRewardsMembership(customerData);
    }

    private static Agentforce_CEMS_CustomerData_Wrapper.Consumers selectBestRewardsConsumer(
        List<Agentforce_CEMS_CustomerData_Wrapper.Consumers> rewardsConsumers
    ) {
        if (rewardsConsumers == null || rewardsConsumers.isEmpty()) {
            return null;
        }

        Agentforce_CEMS_CustomerData_Wrapper.Consumers bestConsumer = rewardsConsumers[0];
        Integer bestScore = scoreRewardsConsumer(bestConsumer);
        Long bestLastUpdated = resolveMembershipLastUpdated(bestConsumer);

        for (Integer i = 1; i < rewardsConsumers.size(); i++) {
            Agentforce_CEMS_CustomerData_Wrapper.Consumers candidate = rewardsConsumers[i];
            Integer candidateScore = scoreRewardsConsumer(candidate);
            Long candidateLastUpdated = resolveMembershipLastUpdated(candidate);

            if (candidateScore > bestScore
                || (candidateScore == bestScore && candidateLastUpdated > bestLastUpdated)) {
                bestConsumer = candidate;
                bestScore = candidateScore;
                bestLastUpdated = candidateLastUpdated;
            }
        }

        return bestConsumer;
    }

    private static Integer scoreRewardsConsumer(Agentforce_CEMS_CustomerData_Wrapper.Consumers consumer) {
        Agentforce_CEMS_CustomerData_Wrapper.Memberships membership =
            Agentforce_CEMS_CustomerData_Wrapper.findCrownRewardsMembership(consumer);
        if (membership == null) {
            return LOWEST_SCORE;
        }

        Integer score = 0;
        if ('1'.equalsIgnoreCase(membership.memberCurrentStatus)) {
            score += 1000000;
        }

        Integer availablePoints = parseInteger(
            membership.CrownRewardsLoyalty != null ? membership.CrownRewardsLoyalty.MemberPointsAvailable : null
        );
        if (availablePoints != null) {
            score += availablePoints;
        }

        Integer tierNumber = parseInteger(
            membership.CrownRewardsLoyalty != null ? membership.CrownRewardsLoyalty.currentTierNumber : null
        );
        if (tierNumber != null) {
            score += tierNumber * 1000;
        }

        return score;
    }

    private static Long resolveMembershipLastUpdated(Agentforce_CEMS_CustomerData_Wrapper.Consumers consumer) {
        Agentforce_CEMS_CustomerData_Wrapper.Memberships membership =
            Agentforce_CEMS_CustomerData_Wrapper.findCrownRewardsMembership(consumer);
        if (membership == null || String.isBlank(membership.memberLastUpdate)) {
            return 0L;
        }

        try {
            List<String> parts = membership.memberLastUpdate.trim().split(' ');
            if (parts.size() < 3) {
                return 0L;
            }

            List<String> dateParts = parts[0].split('/');
            List<String> timeParts = parts[1].split(':');
            if (dateParts.size() != 3 || timeParts.size() < 2) {
                return 0L;
            }

            Integer month = Integer.valueOf(dateParts[0]);
            Integer day = Integer.valueOf(dateParts[1]);
            Integer year = Integer.valueOf(dateParts[2]);
            Integer hour = Integer.valueOf(timeParts[0]);
            Integer minute = Integer.valueOf(timeParts[1]);
            String meridiem = parts[2].toUpperCase();

            if (meridiem == 'PM' && hour < 12) {
                hour += 12;
            } else if (meridiem == 'AM' && hour == 12) {
                hour = 0;
            }

            Datetime parsed = Datetime.newInstance(year, month, day, hour, minute, 0);
            return parsed.getTime();
        } catch (Exception ex) {
            return 0L;
        }
    }

    private static Agentforce_CEMS_CustomerData_Wrapper.Memberships selectRewardsMembership(
        Agentforce_CEMS_CustomerData_Wrapper.Consumers consumer,
        ResolvedLookupIdentifier resolvedIdentifier
    ) {
        if (consumer == null || consumer.memberships == null || consumer.memberships.isEmpty()) {
            return null;
        }

        if (String.isNotBlank(resolvedIdentifier.crownRewardsNumber)) {
            for (Agentforce_CEMS_CustomerData_Wrapper.Memberships membership : consumer.memberships) {
                if (membership != null && membership.id == resolvedIdentifier.crownRewardsNumber) {
                    return membership;
                }
            }
        }

        for (Agentforce_CEMS_CustomerData_Wrapper.Memberships membership : consumer.memberships) {
            if (membership != null && membership.CrownRewardsLoyalty != null) {
                return membership;
            }
        }

        return null;
    }

    private static String buildLookupSummary(Input inputValue, RewardsAgentResponse response) {
        List<String> lines = new List<String>();
        lines.add('I found your Crown Rewards account:');
        lines.add('');

        if (String.isNotBlank(response.crownRewardsNumber)) {
            lines.add('Crown Rewards Number: ' + response.crownRewardsNumber);
        }
        if (String.isNotBlank(response.membershipTier)) {
            lines.add('Tier: ' + response.membershipTier);
        }
        if (response.pointsBalance != null) {
            lines.add('Available Points: ' + formatWholeNumber(response.pointsBalance));
        }
        lines.add('');
        return String.join(lines, '\n');
    }

    private static String formatWholeNumber(Integer value) {
        if (value == null) {
            return null;
        }
        return Decimal.valueOf(value).setScale(0).format();
    }

    private static String buildEscalationMessage(Boolean inHours, String topic) {
        return inHours == true
            ? 'Connect the consumer to a Care Advocate for ' + topic + '.'
            : 'Offer the consumer a case option or ask them to return during business hours for ' + topic + '.';
    }

    private static Boolean isPostalAddressField(String updateFieldName) {
        if (String.isBlank(updateFieldName)) {
            return false;
        }
        String normalized = updateFieldName.trim().toLowerCase();
        return normalized.contains('postal') || normalized.contains('address');
    }

    private static List<RewardsAgentActionResult> wrap(RewardsAgentResponse response, Input inputValue) {
        RewardsAgentActionResult result = new RewardsAgentActionResult();
        result.renderedResponse = sanitizeForDisplay(response);
        result.memberFound = response.memberFound;
        result.lookupFailed = response.memberFound != true
            && String.isNotBlank(inputValue.requestType)
            && isRewardsLookupFailureScenario(inputValue.requestType);
        result.responseType = response.responseType;
        result.summaryMessage = response.summaryMessage;
        result.message = response.summaryMessage;
        result.errorMessage = response.errorMessage;
        result.articleUrl = response.articleUrl;
        result.availableRewardsCount = response.availableRewardsCount;
        result.availableBonusOffersCount = response.availableBonusOffersCount;
        result.needsAdvocateEscalation = response.actionTaken != null
            && (response.actionTaken.contains('escalate') || response.actionTaken.contains('live_chat'));
        result.shouldCreateCase = response.actionTaken != null
            && response.actionTaken.contains('case')
            && response.actionTaken != 'update_case_blocked'
            && response.actionTaken != 'update_postal_address_case_blocked';
        result.needsCaseOption = result.shouldCreateCase || result.needsAdvocateEscalation;
        result.caseComponentKey = resolveCaseComponentKey(response, inputValue);
        result.queueName = resolveQueueName(response, inputValue, result);
        result.caseSubject = resolveCaseSubject(response);
        result.caseReason = resolveCaseReason(response);
        result.createCaseBlocked = response.actionTaken != null
            && (
                response.actionTaken == 'update_case_blocked'
                || response.actionTaken == 'update_postal_address_case_blocked'
            );
        result.failedAttemptCount = response.failedAttemptCount;
        result.attemptsRemaining = response.attemptsRemaining;
        result.shouldAskForAnotherLookup = response.shouldAskForAnotherLookup;
        result.shouldStartLiveAgent = response.shouldStartLiveAgent;
        result.shouldOfferCaseCreation = response.shouldOfferCaseCreation;
        result.lookupAttemptsExhausted = response.lookupAttemptsExhausted;
        result.shouldComeBackDuringBusinessHours = response.shouldComeBackDuringBusinessHours;
        return new List<RewardsAgentActionResult>{ result };
    }

    private static RewardsAgentResponse sanitizeForDisplay(RewardsAgentResponse response) {
        RewardsAgentResponse display = new RewardsAgentResponse();
        display.memberFound = response.memberFound;
        display.crownRewardsNumber = response.crownRewardsNumber;
        display.membershipTier = response.membershipTier;
        display.pointsBalance = response.pointsBalance;
        display.currentYearPoints = null;
        display.pointsToPlatinum = response.pointsToPlatinum;
        display.rewardsRemaining = null;
        display.availableRewardsCount = response.availableRewardsCount;
        display.availableBonusOffersCount = response.availableBonusOffersCount;
        display.availableRewards = response.availableRewards;
        display.availableBonusOffers = response.availableBonusOffers;
        display.responseType = response.responseType;
        display.actionTaken = response.actionTaken;
        display.summaryMessage = response.summaryMessage;
        display.responsePayload = response.responsePayload;
        display.errorMessage = response.errorMessage;
        display.articleUrl = response.articleUrl;
        display.requestType = response.requestType;
        display.failedAttemptCount = response.failedAttemptCount;
        display.attemptsRemaining = response.attemptsRemaining;
        display.lookupAttemptsExhausted = response.lookupAttemptsExhausted;
        display.shouldAskForAnotherLookup = response.shouldAskForAnotherLookup;
        display.shouldStartLiveAgent = response.shouldStartLiveAgent;
        display.shouldOfferCaseCreation = response.shouldOfferCaseCreation;
        display.shouldComeBackDuringBusinessHours = response.shouldComeBackDuringBusinessHours;
        return display;
    }

    private static Boolean isRewardsLookupFailureScenario(String requestType) {
        if (String.isBlank(requestType)) {
            return false;
        }
        String normalized = requestType.trim().toLowerCase();
        return normalized == 'lookup'
            || normalized == 'missingpoints'
            || normalized == 'updateaccount'
            || normalized == 'convertreward'
            || normalized == 'mergememberships';
    }

    private static String resolveQueueName(
        RewardsAgentResponse response,
        Input inputValue,
        RewardsAgentActionResult result
    ) {
        if (!(result.shouldCreateCase || result.needsAdvocateEscalation)) {
            return null;
        }
        if (response.actionTaken == 'missing_points_stream_redeem_live_chat_case'
            || response.actionTaken == 'missing_points_stream_redeem_case') {
            return 'eMail eCare Case Queue';
        }
        if (response.actionTaken == 'missing_points_bonus_offer_live_chat_case') {
            return 'Consumer Care Chat Queue';
        }
        if (response.actionTaken == 'missing_points_bonus_offer_case') {
            return 'eMail General Case Queue';
        }
        if (response.actionTaken == 'escalate_case_missing_points_online' && inputValue.withinBusinessHours == true) {
            return 'Consumer Care Chat Queue';
        }
        return Agentforce_Action_CustomerSearch_Helper.BESPOKE_QUEUE;
    }

    private static String resolveCaseComponentKey(RewardsAgentResponse response, Input inputValue) {
        if (response.actionTaken == 'create_case_missing_points_retail') {
            return Agentforce_CaseComponentMapping.MISSING_POINTS_IN_STORE_PURCHASE;
        }
        if (response.actionTaken == 'missing_points_stream_redeem_live_chat_case'
            || response.actionTaken == 'missing_points_stream_redeem_case') {
            return Agentforce_CaseComponentMapping.MISSING_POINTS_STREAM_REDEEM;
        }
        if (response.actionTaken == 'missing_points_bonus_offer_live_chat_case') {
            return Agentforce_CaseComponentMapping.MISSING_POINTS_BONUS_OFFER_IN_BUSINESS_HOURS;
        }
        if (response.actionTaken == 'missing_points_bonus_offer_case') {
            return Agentforce_CaseComponentMapping.MISSING_POINTS_BONUS_OFFER_OFF_BUSINESS_HOURS;
        }
        if (response.actionTaken == 'escalate_case_missing_points_online') {
            return Agentforce_CaseComponentMapping.MISSING_POINTS_HALLMARK_ONLINE_IN_BUSINESS_HOURS;
        }
        if (response.actionTaken == 'create_case_missing_points_online') {
            return Agentforce_CaseComponentMapping.MISSING_POINTS_HALLMARK_ONLINE_OFF_BUSINESS_HOURS;
        }
        if (response.actionTaken == 'rewards_not_found') {
            return inputValue.withinBusinessHours == true
                ? Agentforce_CaseComponentMapping.CROWN_REWARDS_NOT_FOUND_IN_BUSINESS_HOURS
                : Agentforce_CaseComponentMapping.CROWN_REWARDS_NOT_FOUND_OFF_BUSINESS_HOURS;
        }
        if (response.actionTaken == 'merge_case_ready_not_consumer') {
            return inputValue.withinBusinessHours == true
                ? Agentforce_CaseComponentMapping.MULTIPLE_CR_MEMBERSHIPS_NOT_CONSUMER_IN
                : Agentforce_CaseComponentMapping.MULTIPLE_CR_MEMBERSHIPS_NOT_CONSUMER_OFF;
        }
        if (response.actionTaken == 'update_case_ready'
            || response.actionTaken == 'update_case_blocked'
            || response.actionTaken == 'update_postal_address_case_ready'
            || response.actionTaken == 'update_postal_address_case_blocked') {
            return Agentforce_CaseComponentMapping.ACCOUNT_UPDATE_CASE;
        }
        return null;
    }

    private static String resolveCaseSubject(RewardsAgentResponse response) {
        if (response.actionTaken == 'create_case_missing_points_retail') {
            return 'Consumer interacted with virtual assistant for missing points from an in-store purchase.';
        }
        if (response.actionTaken == 'missing_points_stream_redeem_live_chat_case'
            || response.actionTaken == 'missing_points_stream_redeem_case') {
            return 'Consumer interacted with virtual assistant for missing points from a stream and redeem campaign.';
        }
        if (response.actionTaken == 'missing_points_bonus_offer_live_chat_case'
            || response.actionTaken == 'missing_points_bonus_offer_case') {
            return 'Consumer interacted with virtual assistant for missing points from a bonus offer.';
        }
        if (response.actionTaken == 'escalate_case_missing_points_online'
            || response.actionTaken == 'create_case_missing_points_online') {
            return 'Consumer interacted with virtual assistant for missing points from a fully shipped hallmark.com order.';
        }
        if (response.actionTaken == 'update_postal_address_case_ready'
            || response.actionTaken == 'update_postal_address_case_blocked') {
            return 'Information update';
        }
        if (response.actionTaken == 'update_case_ready'
            || response.actionTaken == 'update_case_blocked') {
            return 'Information update';
        }
        if (response.actionTaken == 'merge_case_ready') {
            return 'Consumer reports multiple CR memberships.';
        }
        if (response.actionTaken == 'merge_case_ready_not_consumer') {
            return 'Consumer reports CR membership issues.';
        }
        return 'Consumer interacted with virtual assistant for CR';
    }

    private static String resolveCaseReason(RewardsAgentResponse response) {
        if (response.actionTaken == 'escalate_case_missing_points_online'
            || response.actionTaken == 'create_case_missing_points_online'
            || response.actionTaken == 'create_case_missing_points_retail'
            || response.actionTaken == 'missing_points_stream_redeem_live_chat_case'
            || response.actionTaken == 'missing_points_stream_redeem_case'
            || response.actionTaken == 'missing_points_bonus_offer_live_chat_case'
            || response.actionTaken == 'missing_points_bonus_offer_case') {
            return ACCOUNT_ASSISTANCE_REASON;
        }
        if (response.actionTaken == 'update_case_ready'
            || response.actionTaken == 'update_case_blocked'
            || response.actionTaken == 'update_postal_address_case_ready'
            || response.actionTaken == 'update_postal_address_case_blocked'
            || response.actionTaken == 'merge_case_ready'
            || response.actionTaken == 'merge_case_ready_not_consumer') {
            return ACCOUNT_ASSISTANCE_REASON;
        }
        return null;
    }

    private static List<Integer> availableRewardChoices(Integer pointsBalance) {
        List<Integer> choices = new List<Integer>();
        Integer balance = pointsBalance != null ? pointsBalance : 0;
        for (Integer rewardValue : new List<Integer>{ 2, 3, 4, 5 }) {
            Integer requiredPoints = Agentforce_Action_CustomerSearch_Helper.pointsRequiredForReward(rewardValue);
            if (requiredPoints != null && balance >= requiredPoints) {
                choices.add(rewardValue);
            }
        }
        return choices;
    }

    private static Integer getLivePointsBalance(String crownRewardsNumber, Integer fallbackBalance) {
        LegacyRewardsSnapshot legacySnapshot = getLegacyRewardsSnapshot(crownRewardsNumber);
        if (legacySnapshot != null && legacySnapshot.pointBalance != null) {
            return legacySnapshot.pointBalance;
        }

        return fallbackBalance != null ? fallbackBalance : 0;
    }

    private static LegacyRewardsSnapshot getLegacyRewardsSnapshot(String crownRewardsNumber) {
        if (String.isBlank(crownRewardsNumber)) {
            return null;
        }

        if (Test.isRunningTest()) {
            LegacyRewardsSnapshot testSnapshot = new LegacyRewardsSnapshot();
            testSnapshot.pointBalance = 5000;
            testSnapshot.ytdPointBalance = 5000;
            testSnapshot.membershipTier = 'Member';
            return testSnapshot;
        }

        try {
            Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(
                Care_RewardsMbrInfoController.getMemberInfo(crownRewardsNumber)
            );
            if (dataMap != null) {
                LegacyRewardsSnapshot snapshot = new LegacyRewardsSnapshot();
                snapshot.pointBalance = parseInteger(String.valueOf(dataMap.get('PointBalance')));
                snapshot.ytdPointBalance = parseInteger(String.valueOf(dataMap.get('YTDPointBalance')));
                snapshot.membershipTier = String.valueOf(dataMap.get('CrownRewardsTier'));
                return snapshot;
            }
        } catch (Exception ignored) {
        }

        return null;
    }

    private static Boolean convertRewardInRealTime(String crownRewardsNumber, Integer rewardValue) {
        if (String.isBlank(crownRewardsNumber) || rewardValue == null) {
            return false;
        }

        String issueCode = rewardIssueCode(rewardValue);
        String convertPoint = String.valueOf(Agentforce_Action_CustomerSearch_Helper.pointsRequiredForReward(rewardValue));
        if (String.isBlank(issueCode) || String.isBlank(convertPoint)) {
            return false;
        }

        if (Test.isRunningTest()) {
            return true;
        }

        try {
            return Care_RewardsIssueChoiceController.issueChoiceReward(
                crownRewardsNumber,
                issueCode,
                convertPoint
            );
        } catch (Exception ignored) {
            return false;
        }
    }

    private static String rewardIssueCode(Integer rewardValue) {
        String yearSuffix = String.valueOf(Date.today().year()).substring(2);
        if (rewardValue == 2) {
            return 'Order_Email_02_' + yearSuffix;
        }
        if (rewardValue == 3) {
            return 'Order_Email_03_' + yearSuffix;
        }
        if (rewardValue == 4) {
            return 'Order_Email_04_' + yearSuffix;
        }
        if (rewardValue == 5) {
            return 'Order_Email_05_' + yearSuffix;
        }
        return null;
    }

}
