/**
 * @description Unit tests for clsPRJCSCalendarificService (holiday callout + parsing - User Story 4).
 */
@IsTest
private class tstPRJCSCalendarificService {
    @IsTest
    static void returnsHolidaysOnSuccess() {
        Test.setMock(
            HttpCalloutMock.class,
            new tstPRJCSCalendarificMock(200, tstPRJCSCalendarificMock.sampleHolidaysJson())
        );
        Test.startTest();
        List<clsPRJCSCalendarificService.Holiday> holidays =
            clsPRJCSCalendarificService.getHolidays(1980);
        Test.stopTest();

        System.Assert.areEqual(3, holidays.size(), 'Three holidays should be parsed');
        System.Assert.areEqual('New Year\'s Day', holidays[0].name, 'First holiday name');
        System.Assert.areEqual('1980-01-01', holidays[0].holidayDate, 'ISO date parsed');
        System.Assert.isTrue(holidays[2].holidayType.contains('Observance'), 'Type list joined');
    }

    @IsTest
    static void throwsOnNonOkStatus() {
        Test.setMock(HttpCalloutMock.class, new tstPRJCSCalendarificMock(500, '{"meta":{"code":500}}'));
        Test.startTest();
        try {
            clsPRJCSCalendarificService.getHolidays(1980);
            System.Assert.fail('Expected a CalendarificException for HTTP 500');
        } catch (clsPRJCSCalendarificService.CalendarificException ex) {
            System.Assert.isTrue(ex.getMessage().contains('HTTP 500'), 'Message should mention HTTP 500');
        }
        Test.stopTest();
    }

    @IsTest
    static void throwsOnNullYear() {
        Test.startTest();
        try {
            clsPRJCSCalendarificService.getHolidays(null);
            System.Assert.fail('Expected a CalendarificException for null year');
        } catch (clsPRJCSCalendarificService.CalendarificException ex) {
            System.Assert.isNotNull(ex.getMessage(), 'Message expected');
        }
        Test.stopTest();
    }

    @IsTest
    static void parsesEmptyAndMissingResponse() {
        List<clsPRJCSCalendarificService.Holiday> emptyBody =
            clsPRJCSCalendarificService.parseHolidays('');
        System.Assert.areEqual(0, emptyBody.size(), 'Empty body yields no holidays');

        List<clsPRJCSCalendarificService.Holiday> noResponse =
            clsPRJCSCalendarificService.parseHolidays('{"meta":{"code":200}}');
        System.Assert.areEqual(0, noResponse.size(), 'Missing response yields no holidays');
    }
}
