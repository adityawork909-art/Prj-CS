/**
 * @description Unit tests for clsPRJCSSAIdHolidayController (end-to-end orchestration - User Stories 1-4).
 */
@IsTest
private class tstPRJCSSAIdHolidayController {
    @IsTest
    static void validSearchReturnsHolidaysAndRecords() {
        User runner = tstPRJCSUserFactory.createHolidayUser();
        clsPRJCSSAIdHolidayController.SearchResult result;
        System.runAs(runner) {
            Test.setMock(
                HttpCalloutMock.class,
                new tstPRJCSCalendarificMock(200, tstPRJCSCalendarificMock.sampleHolidaysJson())
            );
            Test.startTest();
            result = clsPRJCSSAIdHolidayController.checkIdNumber('8001015009087');
            Test.stopTest();
        }

        System.Assert.isTrue(result.isValid, 'Should be valid');
        System.Assert.areEqual('Male', result.gender, 'Gender');
        System.Assert.isTrue(result.isSaCitizen, 'Citizen');
        System.Assert.areEqual(1980, result.holidayYear, 'Holiday year');
        System.Assert.areEqual(3, result.holidays.size(), 'Holidays returned');
        System.Assert.areEqual(1, result.searchCount, 'Counter starts at 1');
        System.Assert.isNotNull(result.recordId, 'Record persisted');
        System.Assert.isNull(result.holidayWarning, 'No warning on success');
    }

    @IsTest
    static void invalidSearchReturnsErrorWithoutDml() {
        Test.startTest();
        clsPRJCSSAIdHolidayController.SearchResult result =
            clsPRJCSSAIdHolidayController.checkIdNumber('8001015009088');
        Test.stopTest();

        System.Assert.isFalse(result.isValid, 'Invalid checksum');
        System.Assert.isNotNull(result.errorMessage, 'Error message returned');
        System.Assert.areEqual(0, [SELECT COUNT() FROM objPRJCSSAIdSearch__c], 'No record created for invalid input');
    }

    @IsTest
    static void calloutFailureStillRecordsSearch() {
        User runner = tstPRJCSUserFactory.createHolidayUser();
        clsPRJCSSAIdHolidayController.SearchResult result;
        System.runAs(runner) {
            Test.setMock(HttpCalloutMock.class, new tstPRJCSCalendarificMock(500, '{"meta":{"code":500}}'));
            Test.startTest();
            result = clsPRJCSSAIdHolidayController.checkIdNumber('9505150500188');
            Test.stopTest();
        }

        System.Assert.isTrue(result.isValid, 'Still a valid ID');
        System.Assert.areEqual(0, result.holidays.size(), 'No holidays when the API fails');
        System.Assert.isNotNull(result.holidayWarning, 'Soft warning surfaced');
        System.Assert.areEqual(1, result.searchCount, 'Search is still recorded (US3 independent of US4)');
    }
}
