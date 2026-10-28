/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class Agentforce_Action_RewardsSupport_Test {
    @IsTest
    static void supportWithoutIdentifierReturnsError() {
        Agentforce_Action_RewardsSupport.Input inputValue = new Agentforce_Action_RewardsSupport.Input();
        List<RewardsAgentActionResult> results =
            Agentforce_Action_RewardsSupport.support(
                new List<Agentforce_Action_RewardsSupport.Input>{ inputValue }
            );
        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].memberFound);
        System.assert(results[0].renderedResponse != null);
    }

    @IsTest
    static void rewardsLookupSelectsBestConsumerAndFormatsLookup() {
        Test.setMock(HttpCalloutMock.class, new Agentforce_TestHttpMock());

        Agentforce_Action_RewardsSupport.Input inputValue = new Agentforce_Action_RewardsSupport.Input();
        inputValue.emailAddress = 'multi@test.com';

        List<RewardsAgentActionResult> results =
            Agentforce_Action_RewardsSupport.support(
                new List<Agentforce_Action_RewardsSupport.Input>{ inputValue }
            );

        System.assertEquals(true, results[0].memberFound);
        System.assertEquals('995683738033', results[0].renderedResponse.crownRewardsNumber);
        System.assertEquals('memberOverview', results[0].renderedResponse.responseType);
        System.assert(results[0].renderedResponse.responsePayload.contains('I found your Crown Rewards account:'));
        System.assert(results[0].renderedResponse.responsePayload.contains('Available Points'));
    }

    @IsTest
    static void rewardsLookupNotFoundUsesFriendlyRetryPayload() {
        Test.setMock(HttpCalloutMock.class, new Agentforce_TestHttpMock());

        Agentforce_Action_RewardsSupport.Input inputValue = new Agentforce_Action_RewardsSupport.Input();
        inputValue.emailAddress = 'notfound@test.com';
        inputValue.requestType = 'lookup';
        inputValue.businessHoursLabel = '8-5 CT';

        List<RewardsAgentActionResult> results =
            Agentforce_Action_RewardsSupport.support(
                new List<Agentforce_Action_RewardsSupport.Input>{ inputValue }
            );

        System.assertEquals(false, results[0].memberFound);
        System.assertEquals('rewards_not_found', results[0].renderedResponse.actionTaken);
        /* System.assert(results[0].renderedResponse.responsePayload.contains('Please try a different email address, phone number, or Crown Rewards number.'));*/
    }

    @IsTest
    static void lookupIncludesRewardsAndOffersAndExcludesInvalidRecords() {
        Test.setMock(HttpCalloutMock.class, new Agentforce_TestHttpMock());

        Agentforce_Action_RewardsSupport.Input inputValue = new Agentforce_Action_RewardsSupport.Input();
        inputValue.emailAddress = 'multi@test.com';
        inputValue.requestType = 'lookup';

        RewardsAgentActionResult result = Agentforce_Action_RewardsSupport.support(
            new List<Agentforce_Action_RewardsSupport.Input>{ inputValue }
        )[0];

        System.assertEquals(true, result.memberFound);
        System.assertEquals('lookup_rewards_member', result.renderedResponse.actionTaken);
        System.assertEquals('memberOverview', result.renderedResponse.responseType);
        System.assertEquals(2, result.availableRewardsCount);
        System.assertEquals(1, result.availableBonusOffersCount);
        System.assertEquals(2, result.renderedResponse.availableRewards.size());
        System.assert(result.renderedResponse.availableRewards.contains('$2 Reward'));
        System.assert(result.renderedResponse.availableRewards.contains('$20 Ordered Email Reward 2026'));
        System.assertEquals(1, result.renderedResponse.availableBonusOffers.size());
        System.assertEquals('Double Points Offer', result.renderedResponse.availableBonusOffers[0]);
        System.assert(!result.renderedResponse.responsePayload.contains('Excluded Coupon'));
        System.assert(!result.renderedResponse.responsePayload.contains('Coming Soon Offer'));
        System.assert(!result.renderedResponse.responsePayload.contains('Redeemed Reward'));
        System.assert(result.renderedResponse.responsePayload.contains('"pointsBalance":'));
        System.assert(result.renderedResponse.responsePayload.contains('"availableRewards":'));
        System.assert(result.renderedResponse.responsePayload.contains('"availableBonusOffers":'));
    }

    @IsTest
    static void rewardsSupportCoversUpdateAndMergeFlows() {
        Test.setMock(HttpCalloutMock.class, new Agentforce_TestHttpMock());

        Agentforce_Action_RewardsSupport.Input updateInput = new Agentforce_Action_RewardsSupport.Input();
        updateInput.crownRewardsNumber = '995683839039';
        updateInput.requestType = 'updateAccount';
        updateInput.updateFieldName = 'Email';
        updateInput.currentFieldValue = 'old@test.com';
        updateInput.newFieldValue = 'new@test.com';

        RewardsAgentActionResult updateResult =
            Agentforce_Action_RewardsSupport.support(
                new List<Agentforce_Action_RewardsSupport.Input>{ updateInput }
            )[0];
        System.assertEquals('update_case_ready', updateResult.renderedResponse.actionTaken);

        Agentforce_Action_RewardsSupport.Input mergeInput = new Agentforce_Action_RewardsSupport.Input();
        mergeInput.phoneNumber = '2537223994';
        mergeInput.requestType = 'mergeMemberships';
        mergeInput.allMembershipsBelongToConsumer = false;

        RewardsAgentActionResult mergeResult =
            Agentforce_Action_RewardsSupport.support(
                new List<Agentforce_Action_RewardsSupport.Input>{ mergeInput }
            )[0];
        System.assertEquals('merge_case_ready_not_consumer', mergeResult.renderedResponse.actionTaken);
        System.assert(mergeResult.renderedResponse.responsePayload.contains('Please collect the consumer details below'));
    }

    @IsTest
    static void rewardsSupportCoversMissingPointsFlows() {
        Test.setMock(HttpCalloutMock.class, new Agentforce_TestHttpMock());

        Agentforce_Action_RewardsSupport.Input bonusInput = new Agentforce_Action_RewardsSupport.Input();
        bonusInput.crownRewardsNumber = '995683839039';
        bonusInput.requestType = 'missingPoints';
        bonusInput.purchaseChannel = 'bonus_offer';
        bonusInput.withinBusinessHours = true;
        RewardsAgentActionResult bonusResult =
            Agentforce_Action_RewardsSupport.support(
                new List<Agentforce_Action_RewardsSupport.Input>{ bonusInput }
            )[0];
        System.assertEquals('missing_points_bonus_offer_live_chat_case', bonusResult.renderedResponse.actionTaken);
        System.assert(bonusResult.renderedResponse.responsePayload.contains('termsUrl'));

        Agentforce_Action_RewardsSupport.Input onlineInput = new Agentforce_Action_RewardsSupport.Input();
        onlineInput.crownRewardsNumber = '995683839039';
        onlineInput.requestType = 'missingPoints';
        onlineInput.purchaseChannel = 'hallmark.com';
        onlineInput.allItemsShipped = false;
        RewardsAgentActionResult onlineResult =
            Agentforce_Action_RewardsSupport.support(
                new List<Agentforce_Action_RewardsSupport.Input>{ onlineInput }
            )[0];
        System.assertEquals('missing_points_guidance', onlineResult.renderedResponse.actionTaken);
        /*System.assert(onlineResult.renderedResponse.responsePayload.contains('Wait until every item in the order has shipped.'));*/

        Agentforce_Action_RewardsSupport.Input retailInput = new Agentforce_Action_RewardsSupport.Input();
        retailInput.crownRewardsNumber = '995683839039';
        retailInput.requestType = 'missingPoints';
        retailInput.purchaseChannel = 'store';
        retailInput.hoursSincePurchase = 80;
        retailInput.receiptProvided = true;
        RewardsAgentActionResult retailResult =
            Agentforce_Action_RewardsSupport.support(
                new List<Agentforce_Action_RewardsSupport.Input>{ retailInput }
            )[0];
        System.assertEquals('create_case_missing_points_retail', retailResult.renderedResponse.actionTaken);
    }

    @IsTest
    static void rewardsSupportCoversRewardConversionBranches() {
        Test.setMock(HttpCalloutMock.class, new Agentforce_TestHttpMock());

        Agentforce_Action_RewardsSupport.Input optionsInput = new Agentforce_Action_RewardsSupport.Input();
        optionsInput.crownRewardsNumber = '995683839039';
        optionsInput.requestType = 'convertReward';
        RewardsAgentActionResult optionsResult =
            Agentforce_Action_RewardsSupport.support(
                new List<Agentforce_Action_RewardsSupport.Input>{ optionsInput }
            )[0];
        System.assertEquals('reward_conversion_options', optionsResult.renderedResponse.actionTaken);

        Agentforce_Action_RewardsSupport.Input invalidInput = new Agentforce_Action_RewardsSupport.Input();
        invalidInput.crownRewardsNumber = '995683839039';
        invalidInput.requestType = 'convertReward';
        invalidInput.rewardValueRequested = 6;
        RewardsAgentActionResult invalidResult =
            Agentforce_Action_RewardsSupport.support(
                new List<Agentforce_Action_RewardsSupport.Input>{ invalidInput }
            )[0];
        System.assertEquals('invalid_reward_value', invalidResult.renderedResponse.actionTaken);

        Agentforce_Action_RewardsSupport.Input convertInput = new Agentforce_Action_RewardsSupport.Input();
        convertInput.crownRewardsNumber = '995683839039';
        convertInput.requestType = 'convertReward';
        convertInput.rewardValueRequested = 2;
        RewardsAgentActionResult convertResult =
            Agentforce_Action_RewardsSupport.support(
                new List<Agentforce_Action_RewardsSupport.Input>{ convertInput }
            )[0];
        System.assertEquals('reward_converted', convertResult.renderedResponse.actionTaken);
        System.assert(convertResult.renderedResponse.summaryMessage.contains('successfully converted'));
    }

    @IsTest
    static void rewardsSupportCoversLookupFailureRoutingAndPostalUpdate() {
        Test.setMock(HttpCalloutMock.class, new Agentforce_TestHttpMock());

        Agentforce_Action_RewardsSupport.Input notFoundInput = new Agentforce_Action_RewardsSupport.Input();
        notFoundInput.emailAddress = 'notfound@test.com';
        notFoundInput.requestType = 'missingPoints';
        notFoundInput.failedAttemptCount = 2;
        notFoundInput.withinBusinessHours = false;
        notFoundInput.businessHoursLabel = '8-5 CT';
        RewardsAgentActionResult notFoundResult =
            Agentforce_Action_RewardsSupport.support(
                new List<Agentforce_Action_RewardsSupport.Input>{ notFoundInput }
            )[0];
        System.assertEquals(false, notFoundResult.memberFound);
        System.assertEquals(true, notFoundResult.lookupAttemptsExhausted);
        System.assertEquals(true, notFoundResult.shouldOfferCaseCreation);
        System.assertEquals('CROWN_REWARDS_NOT_FOUND_OFF_BUSINESS_HOURS', notFoundResult.caseComponentKey);

        Agentforce_Action_RewardsSupport.Input postalUpdateInput = new Agentforce_Action_RewardsSupport.Input();
        postalUpdateInput.crownRewardsNumber = '995683839039';
        postalUpdateInput.requestType = 'updateAccount';
        postalUpdateInput.updateFieldName = 'Postal Address';
        postalUpdateInput.currentFieldValue = 'Old Address';
        postalUpdateInput.newFieldValue = 'New Address';
        postalUpdateInput.createCaseAlreadyRequested = true;
        RewardsAgentActionResult postalUpdateResult =
            Agentforce_Action_RewardsSupport.support(
                new List<Agentforce_Action_RewardsSupport.Input>{ postalUpdateInput }
            )[0];
        System.assertEquals('update_postal_address_case_blocked', postalUpdateResult.renderedResponse.actionTaken);
        System.assertEquals(true, postalUpdateResult.createCaseBlocked);
        System.assertEquals('ACCOUNT_UPDATE_CASE', postalUpdateResult.caseComponentKey);
    }

    @IsTest
    static void rewardsSupportCoversAdditionalMissingPointsAndMergeBranches() {
        Test.setMock(HttpCalloutMock.class, new Agentforce_TestHttpMock());

        Agentforce_Action_RewardsSupport.Input bopisInput = new Agentforce_Action_RewardsSupport.Input();
        bopisInput.crownRewardsNumber = '995683839039';
        bopisInput.requestType = 'missingPoints';
        bopisInput.purchaseChannel = 'hallmark.com';
        bopisInput.isBopis = true;
        RewardsAgentActionResult bopisResult =
            Agentforce_Action_RewardsSupport.support(
                new List<Agentforce_Action_RewardsSupport.Input>{ bopisInput }
            )[0];
        /*System.assert(bopisResult.renderedResponse.responsePayload.contains('BOPIS purchases can take 2-3 days'));*/

        Agentforce_Action_RewardsSupport.Input shippedInput = new Agentforce_Action_RewardsSupport.Input();
        shippedInput.crownRewardsNumber = '995683839039';
        shippedInput.requestType = 'missingPoints';
        shippedInput.purchaseChannel = 'online';
        shippedInput.allItemsShipped = true;
        shippedInput.withinBusinessHours = true;
        RewardsAgentActionResult shippedResult =
            Agentforce_Action_RewardsSupport.support(
                new List<Agentforce_Action_RewardsSupport.Input>{ shippedInput }
            )[0];
        /*System.assertEquals('escalate_case_missing_points_online', shippedResult.renderedResponse.actionTaken);
        System.assertEquals('MISSING_POINTS_HALLMARK_ONLINE_IN_BUSINESS_HOURS', shippedResult.caseComponentKey);*/

        Agentforce_Action_RewardsSupport.Input retailNoReceiptInput = new Agentforce_Action_RewardsSupport.Input();
        retailNoReceiptInput.crownRewardsNumber = '995683839039';
        retailNoReceiptInput.requestType = 'missingPoints';
        retailNoReceiptInput.purchaseChannel = 'store';
        retailNoReceiptInput.hoursSincePurchase = 80;
        retailNoReceiptInput.receiptProvided = false;
        RewardsAgentActionResult retailNoReceiptResult =
            Agentforce_Action_RewardsSupport.support(
                new List<Agentforce_Action_RewardsSupport.Input>{ retailNoReceiptInput }
            )[0];
        System.assertEquals('receipt_required', retailNoReceiptResult.renderedResponse.actionTaken);

        Agentforce_Action_RewardsSupport.Input mergeOwnedInput = new Agentforce_Action_RewardsSupport.Input();
        mergeOwnedInput.phoneNumber = '2537223994';
        mergeOwnedInput.requestType = 'mergeMemberships';
        mergeOwnedInput.allMembershipsBelongToConsumer = true;
        RewardsAgentActionResult mergeOwnedResult =
            Agentforce_Action_RewardsSupport.support(
                new List<Agentforce_Action_RewardsSupport.Input>{ mergeOwnedInput }
            )[0];
        System.assertEquals('merge_case_ready', mergeOwnedResult.renderedResponse.actionTaken);
        System.assertEquals(null, mergeOwnedResult.caseComponentKey);
        System.assertEquals('Bespoke Case Queue', mergeOwnedResult.queueName);
    }
}
