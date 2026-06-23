/**
 * @description Unit tests for clsPRJCSSAIdSearchService (persistence + search counter - User Story 3).
 */
@IsTest
private class tstPRJCSSAIdSearchService {
    @IsTest
    static void insertsThenIncrementsCounter() {
        clsPRJCSSAIdDecoder.DecodedId decoded = clsPRJCSSAIdDecoder.decode('8001015009087');
        System.Assert.isTrue(decoded.isValid, 'Precondition: valid ID');

        User runner = tstPRJCSUserFactory.createHolidayUser();
        objPRJCSSAIdSearch__c first;
        objPRJCSSAIdSearch__c second;
        System.runAs(runner) {
            Test.startTest();
            first = clsPRJCSSAIdSearchService.recordSearch(decoded);
            second = clsPRJCSSAIdSearchService.recordSearch(decoded);
            Test.stopTest();
        }

        System.Assert.areEqual(1, first.fldPRJCSSearchCount__c.intValue(), 'First search => count 1');
        System.Assert.areEqual(2, second.fldPRJCSSearchCount__c.intValue(), 'Second search => count 2');
        System.Assert.areEqual(first.Id, second.Id, 'Same ID reuses the same record');

        List<objPRJCSSAIdSearch__c> rows = [
            SELECT Id, fldPRJCSGender__c, fldPRJCSSaCitizen__c, fldPRJCSSearchCount__c, fldPRJCSDateOfBirth__c
            FROM objPRJCSSAIdSearch__c
            WHERE fldPRJCSIdNumber__c = '8001015009087'
        ];
        System.Assert.areEqual(1, rows.size(), 'Exactly one record for the ID (unique key)');
        System.Assert.areEqual('Male', rows[0].fldPRJCSGender__c, 'Gender stored');
        System.Assert.isTrue(rows[0].fldPRJCSSaCitizen__c, 'Citizenship stored');
        System.Assert.areEqual(2, rows[0].fldPRJCSSearchCount__c.intValue(), 'Counter persisted');
        System.Assert.areEqual(Date.newInstance(1980, 1, 1), rows[0].fldPRJCSDateOfBirth__c, 'DOB stored');
    }

    @IsTest
    static void rejectsInvalidDecodedId() {
        clsPRJCSSAIdDecoder.DecodedId invalid = clsPRJCSSAIdDecoder.decode('8001015009088');
        Test.startTest();
        try {
            clsPRJCSSAIdSearchService.recordSearch(invalid);
            System.Assert.fail('Expected a SecurityException for an invalid ID');
        } catch (clsPRJCSSAIdSearchService.SecurityException ex) {
            System.Assert.isNotNull(ex.getMessage(), 'Message expected');
        }
        Test.stopTest();
    }
}
