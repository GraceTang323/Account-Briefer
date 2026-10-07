@isTest
private class AccountInfoServiceTest {

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

    // ─── Lookup ────────────────────────────────────────────────────────────────

    @isTest
    static void testFetchById_returnsAccount() {
        Account acc = buildAccount('TestCorp', 500000, 'Warm');

        Test.startTest();
        AccountInfoService.FetchContext ctx = AccountInfoService.fetchAccount(acc.Id);
        Test.stopTest();

        Assert.isNotNull(ctx, 'FetchContext should not be null for a valid Account ID');
        Assert.isTrue(ctx.accountDetails.startsWith('Internal Account Details:'));
        Assert.isTrue(ctx.accountDetails.contains('TestCorp'));
    }

    @isTest
    static void testFetchByName_returnsAccount() {
        Account acc = buildAccount('NameLookupCorp', 500000, 'Warm');

        Test.startTest();
        AccountInfoService.FetchContext ctx = AccountInfoService.fetchAccount('NameLookupCorp');
        Test.stopTest();

        Assert.isNotNull(ctx, 'FetchContext should not be null when account name matches');
        Assert.isTrue(ctx.accountDetails.contains('NameLookupCorp'));
    }

    @isTest
    static void testFetchNonExistent_returnsNull() {
        Test.startTest();
        AccountInfoService.FetchContext ctx = AccountInfoService.fetchAccount('NoSuchAccount_XYZ');
        Test.stopTest();

        Assert.isNull(ctx, 'FetchContext should be null when no account matches');
    }

    // ─── isHighValue logic ─────────────────────────────────────────────────────

    @isTest
    static void testIsHighValue_byRevenue() {
        Account acc = buildAccount('HighRevCorp', 1500000, 'Warm');

        Test.startTest();
        AccountInfoService.FetchContext ctx = AccountInfoService.fetchAccount(acc.Id);
        Test.stopTest();

        Assert.isTrue(ctx.isHighValue, 'AnnualRevenue > 1000000 should set isHighValue = true');
    }

    @isTest
    static void testIsHighValue_byHotRating() {
        Account acc = buildAccount('HotRatingCorp', 100000, 'Hot');

        Test.startTest();
        AccountInfoService.FetchContext ctx = AccountInfoService.fetchAccount(acc.Id);
        Test.stopTest();

        Assert.isTrue(ctx.isHighValue, 'Rating = Hot should set isHighValue = true regardless of revenue');
    }

    @isTest
    static void testIsHighValue_revenueAtBoundary() {
        // The check is strictly > 1000000, so exactly 1000000 should be false
        Account acc = buildAccount('BoundaryCorp', 1000000, 'Warm');

        Test.startTest();
        AccountInfoService.FetchContext ctx = AccountInfoService.fetchAccount(acc.Id);
        Test.stopTest();

        Assert.isFalse(ctx.isHighValue, 'AnnualRevenue exactly 1000000 should not be high value (strict > comparison)');
    }

    @isTest
    static void testNotHighValue() {
        Account acc = buildAccount('SmallCorp', 500000, 'Cold');

        Test.startTest();
        AccountInfoService.FetchContext ctx = AccountInfoService.fetchAccount(acc.Id);
        Test.stopTest();

        Assert.isFalse(ctx.isHighValue, 'Low revenue and non-Hot rating should not be high value');
    }

    // ─── Related list sizes ────────────────────────────────────────────────────

    @isTest
    static void testContactsSummarySize() {
        Account acc = buildAccount('ContactCorp', 200000, 'Warm');
        insert new List<Contact>{
            new Contact(LastName = 'Alpha', AccountId = acc.Id, Email = 'alpha@test.com'),
            new Contact(LastName = 'Beta',  AccountId = acc.Id, Email = 'beta@test.com'),
            new Contact(LastName = 'Gamma', AccountId = acc.Id, Email = 'gamma@test.com')
        };

        Test.startTest();
        AccountInfoService.FetchContext ctx = AccountInfoService.fetchAccount(acc.Id);
        Test.stopTest();

        List<Object> contacts = (List<Object>) JSON.deserializeUntyped(ctx.contactsSummary);
        Assert.areEqual(3, contacts.size(), 'contactsSummary should serialize all 3 contacts');
    }

    @isTest
    static void testOpportunitiesSummarySize() {
        Account acc = buildAccount('OppCorp', 200000, 'Warm');
        insert new List<Opportunity>{
            new Opportunity(Name = 'Deal A', AccountId = acc.Id, StageName = 'Prospecting',          CloseDate = Date.today().addDays(30)),
            new Opportunity(Name = 'Deal B', AccountId = acc.Id, StageName = 'Proposal/Price Quote', CloseDate = Date.today().addDays(60))
        };

        Test.startTest();
        AccountInfoService.FetchContext ctx = AccountInfoService.fetchAccount(acc.Id);
        Test.stopTest();

        List<Object> opps = (List<Object>) JSON.deserializeUntyped(ctx.opportunitiesSummary);
        Assert.areEqual(2, opps.size(), 'opportunitiesSummary should serialize all 2 open opportunities');
    }

    @isTest
    static void testCasesSummarySize() {
        Account acc = buildAccount('CaseCorp', 200000, 'Warm');
        insert new List<Case>{
            new Case(AccountId = acc.Id, Subject = 'Bug 1', Status = 'New',     Priority = 'High'),
            new Case(AccountId = acc.Id, Subject = 'Bug 2', Status = 'Working', Priority = 'Medium'),
            new Case(AccountId = acc.Id, Subject = 'Bug 3', Status = 'New',     Priority = 'Low')
        };

        Test.startTest();
        AccountInfoService.FetchContext ctx = AccountInfoService.fetchAccount(acc.Id);
        Test.stopTest();

        List<Object> cases = (List<Object>) JSON.deserializeUntyped(ctx.casesSummary);
        Assert.areEqual(3, cases.size(), 'casesSummary should serialize all 3 recent cases');
    }

    @isTest
    static void testOpportunities_closedExcluded() {
        Account acc = buildAccount('ClosedOppCorp', 200000, 'Warm');
        insert new List<Opportunity>{
            new Opportunity(Name = 'Open Deal',   AccountId = acc.Id, StageName = 'Prospecting', CloseDate = Date.today().addDays(30)),
            new Opportunity(Name = 'Closed Deal', AccountId = acc.Id, StageName = 'Closed Won',  CloseDate = Date.today().addDays(-10))
        };

        Test.startTest();
        AccountInfoService.FetchContext ctx = AccountInfoService.fetchAccount(acc.Id);
        Test.stopTest();

        List<Object> opps = (List<Object>) JSON.deserializeUntyped(ctx.opportunitiesSummary);
        Assert.areEqual(1, opps.size(), 'opportunitiesSummary should exclude closed opportunities');
    }
}
