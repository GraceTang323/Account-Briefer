public with sharing class AccountInfoFetcher {
    @InvocableMethod(
        label='Get Account Info'
        description='Queries CRM data and fetches external news for a specified Account.'
    )
    public static FetchResponse fetchInfo(String accountIdentifier) {
        // given an account name or ID, queries up to 5 related Contacts, open Opportunties, and Cases from the last 90 days
        // returns each section as a string suitable for prompt template injection.

        if (!verifyInput(accountIdentifier)) {
            return null;
        }
        // bind variable, SOQL injection vector
        String pattern = '%' + String.escapeSingleQuotes(accountIdentifier) + '%';

        // fetch CRM data from org
        Account acc = [SELECT Id, Name, Industry, AnnualRevenue, Rating, BillingCity, OwnerId,
                        (SELECT FirstName, LastName, Email, Title FROM Contacts LIMIT 5),
                        (SELECT Stage, Amount, CloseDate FROM Opportunities WHERE IsClosed = false),
                        (SELECT Subject, Status, Priority, CreatedDate FROM Cases WHERE CreatedDate = LAST_N_DAYS:90)
                        FROM Account 
                        WHERE (Id = :accountIdentifier) OR (Name LIKE :pattern) WITH USER_MODE LIMIT 1];
        
        if (!acc) {
            return null;
        }

        String accDetails = 'Internal Account Details:\n' + '- Industry: ' + acc.Industry + '\n- Revenue: $' + String.valueOf(acc.AnnualRevenue) + '\n- Rating: ' + 
                            acc.Rating + '\n- City: '+ acc.BillingCity + '\n- Owner: ' + acc.OwnerId;
        
        String ctSummary = '';
        String opSummary = '';
        String csSummary = '';
        List<Contact> contacts = acc.Contacts != null ? acc.Contacts : '';
        List<Opportunity> opportunities = acc.Opportunities;
        List<Case> cases = acc.Cases;
                            
        // create the response
        FetchResponse response = new FetchResponse();
        response.accountName = acc.Name;
        response.accountDetails = accDetails;
        response.contactsSummary = ctSummary;
        response.opportunitiesSummary = opSummary;
        response.casesSummary = csSummary;
        response.isHighValue = (acc.AnnualRevenue != null && acc.AnnualRevenue > 1000000) || acc.Rating == 'Hot' ? true : false;
        response.accountFound = true;

        return response;
    }

    public class FetchRequest {
        @InvocableVariable(
            required=true
            description='Id for which to associate an Account, or the Account Name'
        )
        public String accountIdentifier;
    }

    public class FetchResponse {
        @InvocableVariable(
            required=true
            description='Account name for prompt request'
        )
        public String accountName;
        @InvocableVariable(
            required=true
            description='One line summary of the account: Industry, AnnualRevenue, Rating, BillingCity, Owner'
        )
        public String accountDetails;
        @InvocableVariable(
            description='Formatted list of up to 5 Contacts (Name, Title, Email)'
        )
        public String contactsSummary;
        @InvocableVariable(
            description='Open opportunities: Name, Stage, Amount, CloseDate'
        )
        public String opportunitiesSummary;
        @InvocableVariable(
            description='Recent cases (90 days): Subject, Status, Priority, CreatedDate'
        )
        public String casesSummary;
        @InvocableVariable(
            description='True if AnnualRevenue is greater than 1000000, or if the Account rating is hot'
        )
        public Boolean isHighValue;
        @InvocableVariable(
            required=true
        )
        public Boolean accountFound;
    }

    // helped method to detect whether the identifier matches an Id format (length == 15 || 18 and starts with 001) and query Id, or query by name
    private Boolean verifyInput(String accountIdentifier) {
        
        if (accountIdentifier == null) {
            return false;
        }
        Boolean isId = (accountIdentifier.length() == 15 || accountIdentifier.length() == 18) && accountIdentifier.startsWith('001');
        return isId || (accountIdentifier.length() > 0 && accountIdentifier.length < 200);
    }
}