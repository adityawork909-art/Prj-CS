/**
 * @description LWC controller for the SA ID Holiday Checker. Orchestrates validation (US2),
 *   holiday retrieval (US4) and persistence with the search counter (US3) for a single search.
 *   Declared `with sharing`; the deliberately-elevated counter write is delegated to
 *   clsPRJCSSAIdSearchService. CloudSmiths assignment - User Stories 1-4.
 */
public with sharing class clsPRJCSSAIdHolidayController {
    /**
     * @description Aggregated result returned to the LWC. Never null.
     */
    public class SearchResult {
        @AuraEnabled public Boolean isValid = false;
        @AuraEnabled public String idNumber;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Date dateOfBirth;
        @AuraEnabled public String gender;
        @AuraEnabled public Boolean isSaCitizen = false;
        @AuraEnabled public Integer holidayYear;
        @AuraEnabled public Integer searchCount;
        @AuraEnabled public Id recordId;
        @AuraEnabled public String holidayWarning;
        @AuraEnabled
        public List<clsPRJCSCalendarificService.Holiday> holidays =
            new List<clsPRJCSCalendarificService.Holiday>();
    }

    /**
     * @description Validates an SA ID number, retrieves holidays for the birth year, stores the
     *   search (incrementing the counter) and returns everything the UI needs.
     * @param idNumber the raw ID number entered by the visitor
     * @return SearchResult (never null). Invalid input returns isValid=false + errorMessage.
     */
    @AuraEnabled
    public static SearchResult checkIdNumber(String idNumber) {
        SearchResult result = new SearchResult();
        try {
            clsPRJCSSAIdDecoder.DecodedId decoded = clsPRJCSSAIdDecoder.decode(idNumber);
            result.idNumber = decoded.idNumber;
            result.isValid = decoded.isValid;

            if (!decoded.isValid) {
                result.errorMessage = decoded.errorMessage;
                return result;
            }

            result.dateOfBirth = decoded.dateOfBirth;
            result.gender = decoded.gender;
            result.isSaCitizen = decoded.isSaCitizen;
            result.holidayYear = decoded.birthYear;

            // US4 - retrieve holidays FIRST. A callout cannot follow DML in the same transaction,
            // so the API is called before the record is persisted. Failure is non-fatal: the search
            // is still recorded and the UI shows a soft warning.
            try {
                result.holidays = clsPRJCSCalendarificService.getHolidays(decoded.birthYear);
            } catch (Exception calloutEx) {
                result.holidays = new List<clsPRJCSCalendarificService.Holiday>();
                result.holidayWarning =
                    'Holidays could not be retrieved at this time: ' + calloutEx.getMessage();
            }

            // US3 - persist the valid search and increment the counter.
            objPRJCSSAIdSearch__c saved = clsPRJCSSAIdSearchService.recordSearch(decoded);
            result.recordId = saved.Id;
            result.searchCount = (saved.fldPRJCSSearchCount__c == null)
                ? null
                : Integer.valueOf(saved.fldPRJCSSearchCount__c);

            return result;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception ex) {
            AuraHandledException handled = new AuraHandledException(ex.getMessage());
            handled.setMessage(ex.getMessage());
            throw handled;
        }
    }
}
