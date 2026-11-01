@IsTest
private class KH_DemoDataProviderTest {
    @IsTest
    static void demoSourcesUseContractInfoTranslationsForEmailAndPhoneHistory() {
        Map<String, String> expectedTranslations = new Map<String, String>{
            'HPlusHMN - IOS' => 'H+ App Apple',
            'HPlusHMN - Android' => 'H+ App Android',
            'HPlusHMN - Other_App' => 'H+ App Other',
            'GoogleUCP' => 'Google Shop',
            'Meta Shop hallmarkornaments' => 'Instagram Shop Ornaments',
            'Meta Shop hallmarkstores' => 'Instagram Shop',
            'DoorDash' => 'DoorDash',
            'TikTok' => 'TikTok Shop'
        };
        KH_FindConsumer.sourceTranslationOverrides = expectedTranslations;

        List<String> emails = new List<String>{
            'demo.kh.ios@hallmark.test',
            'demo.kh.android@hallmark.test',
            'demo.kh.otherapp@hallmark.test',
            'demo.kh.googleshop@hallmark.test',
            'demo.kh.instagramornaments@hallmark.test',
            'demo.kh.instagram@hallmark.test',
            'demo.kh.doordash@hallmark.test',
            'demo.kh.tiktok@hallmark.test'
        };
        List<String> phones = new List<String>{
            '5552100001', '5552100002', '5552100003', '5552100004',
            '5552100005', '5552100006', '5552100007', '5552100008'
        };
        List<String> expectedLabels = new List<String>{
            'H+ App Apple', 'H+ App Android', 'H+ App Other', 'Google Shop',
            'Instagram Shop Ornaments', 'Instagram Shop', 'DoorDash', 'TikTok Shop'
        };

        for (Integer index = 0; index < emails.size(); index++) {
            List<KH_ConsumerMergeWrapper> matches = KH_FindConsumer.checkKnowHer(
                new Account(PersonEmail = emails[index])
            );
            System.assertEquals(1, matches.size(), 'Each demo email should return one KH consumer.');

            List<CareConsumerEmails_Wrapper.Emails> emailHistory =
                KH_FindConsumer.getConsumerEmails(matches[0].CID);
            List<CareConsumerPhones_Wrapper.Phones> phoneHistory =
                KH_FindConsumer.getConsumerPhones(matches[0].CID);

            System.assertEquals(1, emailHistory.size());
            System.assertEquals(1, phoneHistory.size());
            System.assertEquals(expectedLabels[index], emailHistory[0].sourceOfDataDesc);
            System.assertEquals(expectedLabels[index], phoneHistory[0].sourceOfDataDesc);

            List<KH_ConsumerMergeWrapper> phoneMatches = KH_FindConsumer.checkKnowHer(
                new Account(PersonHomePhone = phones[index])
            );
            System.assertEquals(1, phoneMatches.size(), 'Each demo phone should return one KH consumer.');
            System.assertEquals(matches[0].CID, phoneMatches[0].CID);
        }
    }

    @IsTest
    static void formattedDemoPhoneIsRecognized() {
        KH_FindConsumer.sourceTranslationOverrides = new Map<String, String>{
            'TikTok' => 'TikTok Shop'
        };

        List<KH_ConsumerMergeWrapper> matches = KH_FindConsumer.checkKnowHer(
            new Account(PersonHomePhone = '(555) 210-0008')
        );

        System.assertEquals(1, matches.size());
        System.assertEquals('990000000008', matches[0].CID);
        System.assertEquals('5552100008', matches[0].phone);
        System.assertEquals(
            'TikTok Shop',
            KH_FindConsumer.getConsumerPhones(matches[0].CID)[0].sourceOfDataDesc
        );
    }
}
