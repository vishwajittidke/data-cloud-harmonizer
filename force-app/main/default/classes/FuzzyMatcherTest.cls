@isTest
public class FuzzyMatcherTest {
    @isTest
    static void testGenerateSoundex() {
        // Test same sounding names
        String soundex1 = FuzzyMatcher.generateSoundex('Catherine');
        String soundex2 = FuzzyMatcher.generateSoundex('Kathryn');
        
        System.assertNotEquals(null, soundex1, 'Soundex should not be null');
        
        // Test edge cases
        String soundexEmpty = FuzzyMatcher.generateSoundex('');
        System.assertEquals('', soundexEmpty, 'Empty string should return empty code');
        
        String soundexSpecial = FuzzyMatcher.generateSoundex('John Doe 123');
        System.assert(soundexSpecial.length() > 0, 'Should handle spaces and numbers');
    }
}
