/**
 * QA/demo-only KH responses. Do not include this class or its metadata file in
 * the PROD deployment package.
 */
public without sharing class KH_DemoDataProvider implements KH_FindConsumer.KhDemoProvider {
    private class Fixture {
        String cid;
        String email;
        String phone;
        String source;

        Fixture(String cid, String email, String phone, String source) {
            this.cid = cid;
            this.email = email;
            this.phone = phone;
            this.source = source;
        }
    }

    private static List<Fixture> fixtures() {
        return new List<Fixture>{
            new Fixture('990000000001', 'demo.kh.ios@hallmark.test', '5552100001', 'HPlusHMN - IOS'),
            new Fixture('990000000002', 'demo.kh.android@hallmark.test', '5552100002', 'HPlusHMN - Android'),
            new Fixture('990000000003', 'demo.kh.otherapp@hallmark.test', '5552100003', 'HPlusHMN - Other_App'),
            new Fixture('990000000004', 'demo.kh.googleshop@hallmark.test', '5552100004', 'GoogleUCP'),
            new Fixture('990000000005', 'demo.kh.instagramornaments@hallmark.test', '5552100005', 'Meta Shop hallmarkornaments'),
            new Fixture('990000000006', 'demo.kh.instagram@hallmark.test', '5552100006', 'Meta Shop hallmarkstores'),
            new Fixture('990000000007', 'demo.kh.doordash@hallmark.test', '5552100007', 'DoorDash'),
            new Fixture('990000000008', 'demo.kh.tiktok@hallmark.test', '5552100008', 'TikTok')
        };
    }

    private static Fixture findFixture(String email, String phone, String cid) {
        String normalizedEmail = String.isNotBlank(email) ? email.trim().toLowerCase() : null;
        String normalizedPhone = String.isNotBlank(phone) ? phone.replaceAll('[^0-9]', '') : null;
        String normalizedCid = String.isNotBlank(cid) ? cid.trim() : null;

        for (Fixture fixture : fixtures()) {
            if (normalizedEmail == fixture.email
                || normalizedPhone == fixture.phone
                || normalizedCid == fixture.cid) {
                return fixture;
            }
        }
        return null;
    }

    public KH_ConsumerMergeWrapper findConsumer(Account consumerRecord) {
        if (consumerRecord == null) {
            return null;
        }
        Fixture fixture = findFixture(
            consumerRecord.PersonEmail,
            consumerRecord.PersonHomePhone,
            consumerRecord.CID__c
        );
        if (fixture == null) {
            return null;
        }

        KH_ConsumerMergeWrapper consumer = new KH_ConsumerMergeWrapper();
        consumer.source = 'CCDB';
        consumer.CID = fixture.cid;
        consumer.firstName = 'Demo';
        consumer.lastName = 'Consumer';
        consumer.email = fixture.email;
        consumer.phone = fixture.phone;
        consumer.postalCode = '64108';
        consumer.khRecord = true;
        return consumer;
    }

    public CareConsumerEmails_Wrapper.Emails findEmail(String cid) {
        Fixture fixture = findFixture(null, null, cid);
        if (fixture == null) {
            return null;
        }

        CareConsumerEmails_Wrapper.Emails email = new CareConsumerEmails_Wrapper.Emails();
        email.address = fixture.email;
        email.dfltInd = 'Y';
        email.lastUpdateDate = String.valueOf(Date.today());
        email.CapturedDt = String.valueOf(Date.today());
        email.sharedEmail = 'N';
        email.status = 'ACTIVE';
        email.sourceOfDataDesc = KH_FindConsumer.translateSource(fixture.source);
        return email;
    }

    public CareConsumerPhones_Wrapper.Phones findPhone(String cid) {
        Fixture fixture = findFixture(null, null, cid);
        if (fixture == null) {
            return null;
        }

        CareConsumerPhones_Wrapper.Phones phone = new CareConsumerPhones_Wrapper.Phones();
        phone.phone = fixture.phone;
        phone.phoneType = 'MOBILE';
        phone.dfltInd = 'Y';
        phone.internationalPrefix = '+1';
        phone.lastUpdateDate = String.valueOf(Date.today());
        phone.CapturedDt = String.valueOf(Date.today());
        phone.phoneOptIn = 'Y';
        phone.sourceOfDataDesc = KH_FindConsumer.translateSource(fixture.source);
        return phone;
    }
}
