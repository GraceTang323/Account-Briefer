public with sharing class AccountInfoFetcher {
    /**
     * Given an account name or ID, queries the Account and its related fields from the org
     * Returns list of responses suitable for prompting.
     */
    @InvocableMethod(
        label='Get Account Info'
        description='Queries CRM data for a specified Account by Account ID or Name.'
    )
    public static List<FetchResponse> fetchInfo(List<FetchRequest> accounts) {
        
        List<FetchResponse> responses = new List<FetchResponse>();

        for (FetchRequest acc : accounts) {

            FetchResponse response = new FetchResponse();

            // verify input is an ID or a Name
            if (!verifyInput(acc.accountIdentifier)) {
                // construct an error response
                response.accountFound = false;
                response.errorMessage = 'Input: ' + acc.accountIdentifier + ' is not a valid ID or Account Name';
                responses.add(response);
                continue;
            }

            try {
                AccountInfoService.FetchContext context = AccountInfoService.fetchAccount(acc.accountIdentifier);

                if (context == null) {
                    response.accountFound = false;
                    response.errorMessage = 'Input: ' + acc.accountIdentifier + ' has no associated Account being found';
                    responses.add(response);
                    continue;
                }

                // construct the prompt response
                response.accountDetails = context.accountDetails;
                response.contactsSummary = context.contactsSummary;
                response.opportunitiesSummary = context.opportunitiesSummary;
                response.casesSummary = context.casesSummary;
                response.isHighValue = context.isHighValue;
                response.accountFound = true;

                responses.add(response);

            } catch (Exception e) {
                response.accountFound = false;
                response.errorMessage = 'Unexpected error occurred fetching account: ' + e.getMessage();
                responses.add(response);
                System.debug('Unexpected error occurred: ' + e.getMessage());
            }
        }
        
        return responses;
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
            description='One line summary of the account: Name, Industry, AnnualRevenue, Rating, BillingCity, Owner'
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
            description='Whether a matching Account was found'
        )
        public Boolean accountFound;

        @InvocableVariable(
            description='Contains an error or status message if an Account could not be retrieved'
        )
        public String errorMessage;
    }

    // helped method to detect whether the identifier matches an Id format or Name length
    private static Boolean verifyInput(String accountIdentifier) {
        
        if (accountIdentifier == null) {
            return false;
        }
        Boolean isId = (accountIdentifier.length() == 15 || accountIdentifier.length() == 18) && accountIdentifier.startsWith('001');
        Boolean isName = (accountIdentifier.length() > 0 && accountIdentifier.length() < 200);

        return isId || isName;
    }
}