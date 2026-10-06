public with sharing class AccountInfoService {
    /**
     * Given an account ID or Name, queries up to 5 related Contacts, open Opportunties, and Cases from the last 90 days
     * Returns a structured object of strings.
     */
    public static FetchContext fetchAccount(
        String accountIdentifier
    ) {
        // bind variable, SOQL injection vector
        String pattern = '%' + accountIdentifier + '%';

        // fetch CRM data from org
        List<Account> accounts = [SELECT Id, Name, Industry, AnnualRevenue, Rating, BillingCity, Owner.Name,
                        (SELECT FirstName, LastName, Email, Title FROM Contacts LIMIT 5),
                        (SELECT Name, StageName, Amount, CloseDate FROM Opportunities WHERE IsClosed = false ORDER BY CloseDate ASC LIMIT 10),
                        (SELECT Subject, Status, Priority, CreatedDate FROM Cases WHERE CreatedDate = LAST_N_DAYS:90 ORDER BY CreatedDate DESC LIMIT 10)
                        FROM Account 
                        WHERE (Id = :accountIdentifier) OR (Name LIKE :pattern) WITH USER_MODE LIMIT 1];
        
        if (accounts.isEmpty()) {
            return null;
        }

        Account acc = accounts[0];

        String accDetails = 'Internal Account Details:\n' 
                            + '- Name: ' + String.valueOf(acc.Name) + '\n'
                            + '- Industry: ' + String.valueOf(acc.Industry) + '\n' 
                            + '- Revenue: $' + String.valueOf(acc.AnnualRevenue) + '\n' 
                            + '- Rating: ' + String.valueOf(acc.Rating) + '\n' 
                            + '- City: '+ String.valueOf(acc.BillingCity) + '\n' 
                            + '- Owner: ' + String.valueOf(acc.Owner.Name);
        
        FetchContext response = new FetchContext();
        // add fields
        response.accountDetails = accDetails;
        response.contactsSummary = JSON.serialize(acc.Contacts);
        response.opportunitiesSummary = JSON.serialize(acc.Opportunities);
        response.casesSummary = JSON.serialize(acc.Cases);
        response.isHighValue = (acc.AnnualRevenue != null && acc.AnnualRevenue > 1000000) || acc.Rating == 'Hot';

        return response;
    }

    public class FetchContext {
        public String accountDetails;
        public String contactsSummary;
        public String opportunitiesSummary;
        public String casesSummary;
        public Boolean isHighValue;
    }
}