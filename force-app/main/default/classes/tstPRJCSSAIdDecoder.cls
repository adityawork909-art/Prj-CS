/**
 * @description Unit tests for clsPRJCSSAIdDecoder (validation + decoding rules - User Story 2).
 *   Uses independently-verified valid SA ID numbers:
 *     8001015009087 -> 1980-01-01, Male, SA Citizen
 *     9505150500188 -> 1995-05-15, Female, Permanent Resident
 */
@IsTest
private class tstPRJCSSAIdDecoder {
    @IsTest
    static void decodesValidMaleCitizen() {
        clsPRJCSSAIdDecoder.DecodedId decoded = clsPRJCSSAIdDecoder.decode('8001015009087');
        System.Assert.isTrue(decoded.isValid, 'Expected a valid ID number');
        System.Assert.areEqual(Date.newInstance(1980, 1, 1), decoded.dateOfBirth, 'Date of birth');
        System.Assert.areEqual('Male', decoded.gender, 'Gender');
        System.Assert.isTrue(decoded.isSaCitizen, 'Should be SA citizen');
        System.Assert.areEqual(1980, decoded.birthYear, 'Birth year');
    }

    @IsTest
    static void decodesValidFemaleResident() {
        clsPRJCSSAIdDecoder.DecodedId decoded = clsPRJCSSAIdDecoder.decode('9505150500188');
        System.Assert.isTrue(decoded.isValid, 'Expected a valid ID number');
        System.Assert.areEqual(Date.newInstance(1995, 5, 15), decoded.dateOfBirth, 'Date of birth');
        System.Assert.areEqual('Female', decoded.gender, 'Gender');
        System.Assert.isFalse(decoded.isSaCitizen, 'Should be a permanent resident');
    }

    @IsTest
    static void rejectsBlank() {
        clsPRJCSSAIdDecoder.DecodedId decoded = clsPRJCSSAIdDecoder.decode('   ');
        System.Assert.isFalse(decoded.isValid, 'Blank should be invalid');
        System.Assert.isNotNull(decoded.errorMessage, 'Error message expected');
    }

    @IsTest
    static void rejectsWrongLength() {
        clsPRJCSSAIdDecoder.DecodedId decoded = clsPRJCSSAIdDecoder.decode('12345');
        System.Assert.isFalse(decoded.isValid, 'Wrong length should be invalid');
    }

    @IsTest
    static void rejectsNonNumeric() {
        clsPRJCSSAIdDecoder.DecodedId decoded = clsPRJCSSAIdDecoder.decode('80010150090AB');
        System.Assert.isFalse(decoded.isValid, 'Non-numeric should be invalid');
    }

    @IsTest
    static void rejectsInvalidMonth() {
        clsPRJCSSAIdDecoder.DecodedId decoded = clsPRJCSSAIdDecoder.decode('9913320000080');
        System.Assert.isFalse(decoded.isValid, 'Month 13 should be invalid');
        System.Assert.isTrue(decoded.errorMessage.contains('date'), 'Should be a date error');
    }

    @IsTest
    static void rejectsNonLeapFebruary29() {
        clsPRJCSSAIdDecoder.DecodedId decoded = clsPRJCSSAIdDecoder.decode('9902290000080');
        System.Assert.isFalse(decoded.isValid, '29 Feb 1999 should be invalid (not a leap year)');
    }

    @IsTest
    static void rejectsInvalidCitizenship() {
        clsPRJCSSAIdDecoder.DecodedId decoded = clsPRJCSSAIdDecoder.decode('8001015009287');
        System.Assert.isFalse(decoded.isValid, 'Citizenship digit 2 should be invalid');
        System.Assert.isTrue(decoded.errorMessage.contains('citizenship'), 'Should be a citizenship error');
    }

    @IsTest
    static void rejectsBadChecksum() {
        clsPRJCSSAIdDecoder.DecodedId decoded = clsPRJCSSAIdDecoder.decode('8001015009088');
        System.Assert.isFalse(decoded.isValid, 'Bad checksum should be invalid');
        System.Assert.isTrue(decoded.errorMessage.contains('checksum'), 'Should be a checksum error');
    }
}
