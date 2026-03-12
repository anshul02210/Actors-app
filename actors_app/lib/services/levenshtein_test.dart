import 'dart:math';

/// Service responsible for calculating string similarity
/// using the Levenshtein Distance algorithm.
class SimilarityService {
  /// Calculates the Levenshtein distance between two strings
  /// Returns the minimum number of single-character edits to change [s1] into [s2]
  int calculateLevenshteinDistance(String s1, String s2) {
    s1 = s1.toLowerCase();
    s2 = s2.toLowerCase();

    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.filled(s2.length + 1, 0);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i <= s2.length; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce(min);
      }

      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[s2.length];
  }

  /// Returns a similarity score between 0.0 and 1.0
  /// 1.0 means exact match, 0.0 means completely different
  double calculateSimilarityScore(String original, String spoken) {
    if (original.isEmpty && spoken.isEmpty) return 1.0;
    if (original.isEmpty || spoken.isEmpty) return 0.0;
    
    int maxLength = max(original.length, spoken.length);
    int distance = calculateLevenshteinDistance(original, spoken);
    
    return 1.0 - (distance / maxLength);
  }

  /// Classifies the performance based on similarity score
  String classifyPerformance(double score) {
    if (score >= 0.95) return 'Correct';
    if (score >= 0.70) return 'Partially Correct';
    return 'Incorrect';
  }
}

void main() {
  final service = SimilarityService();
  
  // Test cases
  final String originalLine = "To be or not to be, that is the question.";
  
  print("--- Testing Similarity Service ---");
  print("Original Line: '$originalLine'\n");

  void testCase(String description, String spokenLine) {
    print("Test Case: $description");
    print("Spoken Line:   '$spokenLine'");
    
    int distance = service.calculateLevenshteinDistance(originalLine, spokenLine);
    double score = service.calculateSimilarityScore(originalLine, spokenLine);
    String classification = service.classifyPerformance(score);
    
    print("Levenshtein Distance: $distance");
    print("Similarity Score: ${(score * 100).toStringAsFixed(1)}%");
    print("Classification: $classification\n");
  }

  testCase("Exact Match", "To be or not to be, that is the question.");
  testCase("Minor STT Error (missing punctuation)", "To be or not to be that is the question");
  testCase("Partial Recitation", "To be or not to be");
  testCase("Completely Wrong", "I am Hamlet Prince of Denmark");
}
