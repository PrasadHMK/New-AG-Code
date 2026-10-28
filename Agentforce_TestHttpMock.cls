@IsTest
public class Agentforce_TestHttpMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setHeader('Content-Type', 'application/json');

        String endpoint = request.getEndpoint() == null ? '' : request.getEndpoint();
        String method = request.getMethod() == null ? '' : request.getMethod().toUpperCase();

        if (method == 'POST') {
            response.setBody('{"access_token":"unit-test-token"}');
            return response;
        }

        if (endpoint.contains('/exists?')) {
            response.setBody(buildConsumerExistsResponse(endpoint));
            return response;
        }

        if (endpoint.contains('/consumers/') && endpoint.endsWith('/rewards')) {
            response.setBody(buildAvailableRewardsResponse());
            return response;
        }

        if (endpoint.contains('filterLoyaltyData=true') || endpoint.contains('memberId=')
            || endpoint.contains('consumerId=')) {
            response.setBody(buildRewardsResponse(endpoint));
            return response;
        }

        response.setBody(buildOrdersResponse(endpoint));
        return response;
    }

    private static String buildRewardsResponse(String endpoint) {
        if (endpoint.contains('memberId=NOTFOUND')
            || endpoint.contains('email=notfound%40test.com')
            || endpoint.contains('homePhone=0000000000')) {
            return '{"Errors":[],"Result":{"numberOfResults":"0","consumers":[]}}';
        }

        if (endpoint.contains('email=multi%40test.com') || endpoint.contains('homePhone=2537223994')) {
            return '{"Errors":[],"Result":{"numberOfResults":"2","consumers":['
                + buildConsumerJson('265441507012', '995683737031', '0', '7', '1200', 'Gold', '7/13/2026 3:32:25 PM')
                + ','
                + buildConsumerJson('265441508014', '995683738033', '1', '8', '2600', 'Platinum', '7/13/2026 3:34:42 PM')
                + ']}}';
        }

        return '{"Errors":[],"Result":{"numberOfResults":"1","consumers":['
            + buildConsumerJson('265441500001', '995683839039', '1', '8', '2000', 'Platinum', '7/13/2026 3:34:42 PM')
            + ']}}';
    }

    private static String buildAvailableRewardsResponse() {
        String activeExpiration = String.valueOf(Date.today().addDays(30));
        String expiredDate = String.valueOf(Date.today().addDays(-1));
        String futureStart = String.valueOf(Date.today().addDays(10));
        return '{"result":{"details":['
            + rewardDetailJson('1', 'SUIA', 'REWARD-1', '$2 Reward', '0', '0', '0', null, activeExpiration)
            + ',' + rewardDetailJson('2', 'SUIA', 'REWARD-1', '$2 Reward', '0', '0', '0', null, activeExpiration)
            + ',' + rewardDetailJson('3', 'SUIB', 'BONUS-1', 'Double Points Offer', '0', '0', '0', null, activeExpiration)
            + ',' + rewardDetailJson('4', 'SUIC', 'COUPON-1', 'Excluded Coupon', '0', '0', '0', null, activeExpiration)
            + ',' + rewardDetailJson('5', 'SUIA', 'REDEEMED-1', 'Redeemed Reward', '0', '0', '1', null, activeExpiration)
            + ',' + rewardDetailJson('6', 'SUIB', 'EXPIRED-1', 'Expired Offer', '0', '1', '0', null, expiredDate)
            + ',' + rewardDetailJson('7', 'SUIB', 'FUTURE-1', 'Coming Soon Offer', '0', '0', '0', futureStart, activeExpiration)
            + ',' + orderedRewardDetailJson()
            + ']}}';
    }

    private static String orderedRewardDetailJson() {
        return '{'
            + '"id":"8",'
            + '"typeExternalReference":"Order_Email_20_26",'
            + '"name":"$20 Ordered Email Reward 2026",'
            + '"isCancelled":"0",'
            + '"isExpired":"0",'
            + '"isRedeemed":"1",'
            + '"redeemedTimestampUTC":"2026-05-01T12:00:00Z",'
            + '"expireEndOfDay":"2026-05-23",'
            + '"customFields":{'
            + '"externalReference":"ORDERED-20-2026",'
            + '"alphaTrigger":"SUIA",'
            + '"rewardType":"07",'
            + '"offerStartDate":null,'
            + '"offerDisplayExpDate":null'
            + '}}';
    }

    private static String rewardDetailJson(
        String id,
        String triggerr,
        String externalReference,
        String name,
        String isCancelled,
        String isExpired,
        String isRedeemed,
        String offerStartDate,
        String expirationDate
    ) {
        return '{'
            + '"id":"' + id + '",'
            + '"typeExternalReference":"' + externalReference + '",'
            + '"name":"' + name + '",'
            + '"isCancelled":"' + isCancelled + '",'
            + '"isExpired":"' + isExpired + '",'
            + '"isRedeemed":"' + isRedeemed + '",'
            + '"expireEndOfDay":"' + expirationDate + '",'
            + '"customFields":{'
            + '"externalReference":"' + externalReference + '",'
            + '"alphaTrigger":"' + triggerr + '",'
            + '"rewardType":"01",'
            + '"offerStartDate":' + (offerStartDate == null ? 'null' : '"' + offerStartDate + '"') + ','
            + '"offerDisplayExpDate":"' + expirationDate + '"'
            + '}}';
    }

    private static String buildConsumerExistsResponse(String endpoint) {
        if (endpoint.contains('firstName=No') || endpoint.contains('email=nomatch%40test.com')) {
            return '{"exists":false}';
        }
        return '{"exists":true,"cid":"145550869917","email":"NELOY.GHOSH@ICLOUD.COM","crownRewardsNumber":"110613552000","firstName":"NELOY","lastName":"GHOSH"}';
    }

    private static String buildConsumerJson(
        String consumerId,
        String membershipId,
        String memberStatus,
        String tierNumber,
        String points,
        String tier,
        String memberLastUpdate
    ) {
        return '{'
            + '"consumerId":"' + consumerId + '",'
            + '"alternateId":{"val":"765335799025","typ":"HDXREF"},'
            + '"name":{"firstName":"Sam","lastName":"Sami"},'
            + '"address":{"zip":"66077","country":"United States"},'
            + '"phone":{"homeNumber":"2537223994"},'
            + '"email":{"address":"multi@test.com"},'
            + '"memberships":[{'
            + '"membershipType":"Crown Rewards",'
            + '"id":"' + membershipId + '",'
            + '"memberCurrentStatus":"' + memberStatus + '",'
            + '"memberLastUpdate":"' + memberLastUpdate + '",'
            + '"rank":"2",'
            + '"CrownRewardsLoyalty":{'
            + '"currentTierNumber":"' + tierNumber + '",'
            + '"MemberPointsAvailable":"' + points + '",'
            + '"currentTier":"' + tier + '"'
            + '},'
            + '"KeepsakeOrnamentClub":{"CharterMember":"false","MemberSince":"0","DateExpires":null}'
            + '}],'
            + '"hPlusMembership":[]'
            + '}';
    }

    private static String buildOrdersResponse(String endpoint) {
        if (endpoint.contains('email=oldonly%40test.com')) {
            return '{"orders":['
                + orderSummaryJson('OSSOLD0001', Date.today().addDays(-120), 'Delivered')
                + ']}';
        }
        if (endpoint.contains('email=')) {
            return '{"orders":['
                + orderSummaryJson('OSS00033827', Date.today().addDays(-1), 'Processing')
                + ','
                + orderSummaryJson('OSS00033826', Date.today().addDays(-2), 'Processing')
                + ','
                + orderSummaryJson('OSS00033825', Date.today().addDays(-3), 'Cancelled')
                + ','
                + orderSummaryJson('OSS00033404', Date.today().addDays(-4), 'Picked Up')
                + ','
                + orderSummaryJson('OSS00033446', Date.today().addDays(-5), 'Picked Up')
                + ','
                + orderSummaryJson('OSS00033716', Date.today().addDays(-6), 'Shipped')
                + ','
                + orderSummaryJson('OSSOLD0001', Date.today().addDays(-120), 'Delivered')
                + ']}';
        }

        if (endpoint.contains('homePhone=')) {
            if (endpoint.contains('homePhone=9999999999')) {
                return '{"orders":['
                    + orderSummaryJson('OSSOLD0001', Date.today().addDays(-120), 'Delivered')
                    + ']}';
            }
            return '{"orders":['
                + orderSummaryJson('OSS00033827', Date.today().addDays(-1), 'Processing')
                + ','
                + orderSummaryJson('OSS00033716', Date.today().addDays(-6), 'Shipped')
                + ','
                + orderSummaryJson('OSSOLD0001', Date.today().addDays(-120), 'Delivered')
                + ']}';
        }

        if (endpoint.contains('orderNumber=OSS00033716')) {
            return '{"orders":[' + shippedOrderJson('OSS00033716', Date.today().addDays(-6), Date.today().addDays(-5)) + ']}';
        }
        if (endpoint.contains('orderNumber=OSS00033581') || endpoint.contains('orderNumber=OSS00033825')) {
            return '{"orders":[' + cancelledOrderJson('OSS00033581', Date.today().addDays(-3)) + ']}';
        }
        if (endpoint.contains('orderNumber=OSS00033827')) {
            return '{"orders":[' + partialOrderJson('OSS00033827', Date.today().addDays(-1)) + ']}';
        }
        if (endpoint.contains('orderNumber=OSS00033826')) {
            return '{"orders":[' + processingOrderJson('OSS00033826', Date.today().addDays(-2)) + ']}';
        }
        if (endpoint.contains('orderNumber=OSS00033404') || endpoint.contains('orderNumber=OSS00033446')) {
            return '{"orders":[' + bopisOrderJson('OSS00033446', Date.today().addDays(-5)) + ']}';
        }
        if (endpoint.contains('orderNumber=OSSRECENTSHIP')) {
            return '{"orders":[' + shippedOrderJson('OSSRECENTSHIP', Date.today().addDays(-1), Date.today()) + ']}';
        }
        if (endpoint.contains('orderNumber=OSSOLD0001')) {
            return '{"orders":[' + shippedOrderJson('OSSOLD0001', Date.today().addDays(-120), Date.today().addDays(-118)) + ']}';
        }
        if (endpoint.contains('orderNumber=NOTFOUND')) {
            return '{"orders":[]}';
        }

        return '{"orders":[]}';
    }

    private static String orderSummaryJson(String orderNumber, Date orderDate, String status) {
        return '{'
            + '"orderNumber":"' + orderNumber + '",'
            + '"orderDate":"' + String.valueOf(orderDate) + '",'
            + '"orderStatus":"' + status + '"'
            + '}';
    }

    private static String shippedOrderJson(String orderNumber, Date orderDate, Date shippedDate) {
        return '{'
            + '"orderNumber":"' + orderNumber + '",'
            + '"orderDate":"' + String.valueOf(orderDate) + '",'
            + '"orderStatus":"Shipped",'
            + '"shipToAddressShipments":[{'
            + '"status":"Delivered",'
            + '"carrier":"UPS",'
            + '"tracking_number":"1Z999999",'
            + '"shipped_date":"' + String.valueOf(shippedDate) + '",'
            + '"items":[{"description":"Baby Ornament","quantity":4,"earliest_delivery_date":"' + String.valueOf(shippedDate) + '","latest_delivery_date":"' + String.valueOf(shippedDate.addDays(2)) + '"}]'
            + '}]'
            + '}';
    }

    private static String cancelledOrderJson(String orderNumber, Date orderDate) {
        return '{'
            + '"orderNumber":"' + orderNumber + '",'
            + '"orderDate":"' + String.valueOf(orderDate) + '",'
            + '"orderStatus":"Cancelled",'
            + '"shipToAddressShipments":[{'
            + '"status":"Cancelled",'
            + '"items":[{"description":"Butterfly Figurine","quantity":1}]'
            + '}]'
            + '}';
    }

    private static String partialOrderJson(String orderNumber, Date orderDate) {
        return '{'
            + '"orderNumber":"' + orderNumber + '",'
            + '"orderDate":"' + String.valueOf(orderDate) + '",'
            + '"shipToAddressShipments":[{'
            + '"status":"Cancelled",'
            + '"items":[{"description":"Black-Billed Magpie Ornament","quantity":1}]}'
            + ',{'
            + '"status":"Processing",'
            + '"shipped_date":"' + String.valueOf(orderDate.addDays(1)) + '",'
            + '"items":[{"description":"Mini Pine Grosbeak Ornament","quantity":1},{"description":"Mini Freesia Fairy Ornament","quantity":1}]}'
            + ']'
            + '}';
    }

    private static String processingOrderJson(String orderNumber, Date orderDate) {
        return '{'
            + '"orderNumber":"' + orderNumber + '",'
            + '"orderDate":"' + String.valueOf(orderDate) + '",'
            + '"orderStatus":"Processing",'
            + '"shipToAddressShipments":[{'
            + '"status":"Open",'
            + '"items":[{"description":"Graduation Ornament","quantity":1},{"description":"Snoopy Baseball Ornament","quantity":1}]}'
            + ']'
            + '}';
    }

    private static String bopisOrderJson(String orderNumber, Date orderDate) {
        return '{'
            + '"orderNumber":"' + orderNumber + '",'
            + '"orderDate":"' + String.valueOf(orderDate) + '",'
            + '"orderStatus":"Picked Up",'
            + '"BOPISItems":{'
            + '"pickupStatus":"Picked Up",'
            + '"stores":[{'
            + '"store_info":"Trudys Hallmark Shop",'
            + '"store_address":"7625 N Macarthur Blvd Ste 3E, Irving, TX 75063",'
            + '"store_phone":"972-910-9663",'
            + '"itemList":{"pickedup_items":{"items":[{"description":"Thankful for You Birthday Card","quantity":1}]}}'
            + '}]'
            + '}'
            + '}';
    }
}
