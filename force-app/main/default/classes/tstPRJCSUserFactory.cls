/**
 * @description Test utility - provisions a user assigned the pmsPRJCSHolidayAccess permission set.
 *   Persistence/controller tests run as this user (System.runAs) so that WITH SECURITY_ENFORCED and
 *   Security.stripInaccessible are exercised under the exact access the Experience Cloud guest user
 *   will have, rather than the elevated test-running admin.
 */
@IsTest
public class tstPRJCSUserFactory {
    /**
     * @description Creates and returns a Standard User with the holiday permission set assigned.
     */
    public static User createHolidayUser() {
        Profile standard = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        Integer salt = Math.abs(Crypto.getRandomInteger());
        User user = new User(
            FirstName = 'PRJCS',
            LastName = 'Tester',
            Email = 'prjcs.tester@example.com.invalid',
            Username = 'prjcs.tester.' + salt + '@example.com.invalid',
            Alias = 'prjcst',
            TimeZoneSidKey = 'Africa/Johannesburg',
            LocaleSidKey = 'en_ZA',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = standard.Id
        );
        insert user;

        PermissionSet permset = [SELECT Id FROM PermissionSet WHERE Name = 'pmsPRJCSHolidayAccess' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = user.Id, PermissionSetId = permset.Id);
        return user;
    }
}
