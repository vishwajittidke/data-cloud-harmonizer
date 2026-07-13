/**
 * @description A utility class for Fuzzy Matching algorithms in Apex.
 * This class implements a standard Soundex algorithm to generate phonetic keys
 * for fuzzy string matching (e.g., catching typos in names like 'Jon' vs 'John').
 */
public with sharing class FuzzyMatcher {
    
    /**
     * @description Generates a Soundex code for a given string.
     * Soundex encodes words based on their English pronunciation, 
     * making it perfect for catching misspellings and variations.
     * 
     * @param input The raw string (e.g. 'John')
     * @return The 4-character Soundex code (e.g. 'J500')
     */
    public static String generateSoundex(String input) {
        if (String.isBlank(input)) {
            return '';
        }
        
        // 1. Clean the input (uppercase, keep letters AND numbers)
        String cleanInput = input.toUpperCase().replaceAll('[^A-Z0-9]', '');
        if (cleanInput.length() == 0) {
            return '';
        }
        
        // 2. Retain the first character
        String firstChar = cleanInput.substring(0, 1);
        String result = firstChar;
        
        String previousCode = firstChar.isNumeric() ? '0' : getSoundexDigit(firstChar);
        
        // 3. Map letters to Soundex digits, keep numbers as is
        for (Integer i = 1; i < cleanInput.length(); i++) {
            String currentChar = cleanInput.substring(i, i+1);
            
            if (currentChar.isNumeric()) {
                result += currentChar;
                previousCode = '0'; // reset previous code so subsequent letters don't falsely dedupe
                continue;
            }
            
            String currentCode = getSoundexDigit(currentChar);
            
            // Ignore vowels and W, H, Y (which map to '0')
            // Also ignore duplicates of the previous code
            if (currentCode != '0' && currentCode != previousCode) {
                result += currentCode;
            }
            
            previousCode = currentCode;
            
            // We NO LONGER truncate at 4 characters. This allows it to act as a highly specific phonetic match key!
        }
        
        return result;
    }
    
    private static String getSoundexDigit(String letter) {
        if ('BFPV'.contains(letter)) return '1';
        if ('CGJKQSXZ'.contains(letter)) return '2';
        if ('DT'.contains(letter)) return '3';
        if ('L'.contains(letter)) return '4';
        if ('MN'.contains(letter)) return '5';
        if ('R'.contains(letter)) return '6';
        return '0'; // Vowels, H, W, Y
    }
}
