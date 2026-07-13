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
        
        // 1. Clean the input (uppercase, remove non-alphas)
        String cleanInput = input.toUpperCase().replaceAll('[^A-Z]', '');
        if (cleanInput.length() == 0) {
            return '';
        }
        
        // 2. Retain the first letter
        String firstLetter = cleanInput.substring(0, 1);
        String result = firstLetter;
        
        // 3. Map letters to Soundex digits (excluding the first letter)
        // 1: B, F, P, V
        // 2: C, G, J, K, Q, S, X, Z
        // 3: D, T
        // 4: L
        // 5: M, N
        // 6: R
        // Ignored: A, E, I, O, U, H, W, Y
        String previousCode = getSoundexDigit(firstLetter);
        
        for (Integer i = 1; i < cleanInput.length(); i++) {
            String currentLetter = cleanInput.substring(i, i+1);
            String currentCode = getSoundexDigit(currentLetter);
            
            // Ignore vowels and W, H, Y (which map to '0')
            // Also ignore duplicates of the previous code
            if (currentCode != '0' && currentCode != previousCode) {
                result += currentCode;
            }
            
            // Always update previous code, even if it was ignored (unless it was H or W in strict Soundex, but this is a simplified version)
            previousCode = currentCode;
            
            if (result.length() == 4) {
                break; // Soundex codes are max 4 characters
            }
        }
        
        // 4. Pad with zeros if less than 4 characters
        while (result.length() < 4) {
            result += '0';
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
