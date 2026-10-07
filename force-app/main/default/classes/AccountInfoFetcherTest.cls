@isTest
private class AccountInfoFetcherTest {

    private static Account buildAccount(String name, Decimal revenue, String rating) {
        Account acc = new Account(
            Name = name,
            AnnualRevenue = revenue,
            Rating = rating,
            BillingCity = 'San Francisco'
        );
        insert acc;
        return acc;
    }

    private static AccountInfoFetcher.FetchResponse fetchSingle(String identifier) {
        AccountInfoFetcher.FetchRequest req = new AccountInfoFetcher.FetchRequest();
        req.accountIdentifier = identifier;
        return AccountInfoFetcher.fetchInfo(
            new List<AccountInfoFetcher.FetchRequest>{ req }
        )[0];
    }

    // ─── accountFound ──────────────────────────────────────────────────────────

    @isTest
    static void testAccountFound_validId() {
        Account acc = buildAccount('FetcherFoundCorp', 500000, 'Warm');

        Test.startTest();
        AccountInfoFetcher.FetchResponse res = fetchSingle(acc.Id);
        Test.stopTest();

        Assert.isTrue(res.accountFound, 'accountFound should be true for a valid Account ID');
        Assert.isNull(res.errorMessage, 'errorMessage should be null on a successful fetch');
    }

    @isTest
    static void testAccountFound_false_noMatch() {
        Test.startTest();
        AccountInfoFetcher.FetchResponse res = fetchSingle('NoSuchAccount_XYZ');
        Test.stopTest();

        Assert.isFalse(res.accountFound, 'accountFound should be false when no account matches');
        Assert.isNotNull(res.errorMessage, 'errorMessage should be populated when account is not found');
    }

    // ─── Input validation ──────────────────────────────────────────────────────

    @isTest
    static void testNullInput_returnsError() {
        Test.startTest();
        AccountInfoFetcher.FetchResponse res = fetchSingle(null);
        Test.stopTest();

        Assert.isFalse(res.accountFound, 'accountFound should be false for a null identifier');
        Assert.isNotNull(res.errorMessage, 'errorMessage should describe the invalid input');
    }

    @isTest
    static void testEmptyInput_returnsError() {
        Test.startTest();
        AccountInfoFetcher.FetchResponse res = fetchSingle('');
        Test.stopTest();

        Assert.isFalse(res.accountFound, 'accountFound should be false for an empty identifier');
        Assert.isNotNull(res.errorMessage, 'errorMessage should describe the invalid input');
    }

    // ─── isHighValue propagation ───────────────────────────────────────────────

    @isTest
    static void testIsHighValue_true() {
        Account acc = buildAccount('FetcherHighCorp', 2000000, 'Warm');

        Test.startTest();
        AccountInfoFetcher.FetchResponse res = fetchSingle(acc.Id);
        Test.stopTest();

        Assert.isTrue(res.accountFound);
        Assert.isTrue(res.isHighValue, 'isHighValue should propagate as true from AccountInfoService');
    }

    @isTest
    static void testIsHighValue_false() {
        Account acc = buildAccount('FetcherSmallCorp', 100000, 'Cold');

        Test.startTest();
        AccountInfoFetcher.FetchResponse res = fetchSingle(acc.Id);
        Test.stopTest();

        Assert.isTrue(res.accountFound);
        Assert.isFalse(res.isHighValue, 'isHighValue should propagate as false from AccountInfoService');
    }

    // ─── Complete response ─────────────────────────────────────────────────────

    @isTest
    static void testResponseFieldsComplete() {
        Account acc = buildAccount('FetcherFullCorp', 750000, 'Warm');
        insert new List<Contact>{
            new Contact(LastName = 'Test1', AccountId = acc.Id, Email = 't1@test.com'),
            new Contact(LastName = 'Test2', AccountId = acc.Id, Email = 't2@test.com')
        };
        insert new List<Opportunity>{
            new Opportunity(Name = 'Test Opp', AccountId = acc.Id, StageName = 'Prospecting', CloseDate = Date.today().addDays(30))
        };
        insert new List<Case>{
            new Case(AccountId = acc.Id, Subject = 'Test Case 1', Status = 'New',     Priority = 'High'),
            new Case(AccountId = acc.Id, Subject = 'Test Case 2', Status = 'Working', Priority = 'Low')
        };

        Test.startTest();
        AccountInfoFetcher.FetchResponse res = fetchSingle(acc.Id);
        Test.stopTest();

        Assert.isTrue(res.accountFound);
        Assert.isNotNull(res.accountDetails, 'accountDetails should be populated');

        List<Object> contacts = (List<Object>) JSON.deserializeUntyped(res.contactsSummary);
        List<Object> opps     = (List<Object>) JSON.deserializeUntyped(res.opportunitiesSummary);
        List<Object> cases    = (List<Object>) JSON.deserializeUntyped(res.casesSummary);

        Assert.areEqual(2, contacts.size(), 'contactsSummary should contain 2 contacts');
        Assert.areEqual(1, opps.size(),     'opportunitiesSummary should contain 1 open opportunity');
        Assert.areEqual(2, cases.size(),    'casesSummary should contain 2 recent cases');
    }
}
