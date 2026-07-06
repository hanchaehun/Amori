class ScenarioAnswer {
  const ScenarioAnswer({
    required this.code,
    required this.category,
    required this.question,
    required this.answerLetter,
    required this.answerText,
  });

  final String code;
  final String category;
  final String question;
  final String answerLetter;
  final String answerText;

  Map<String, Object?> toJson() => {
    'code': code,
    'category': category,
    'question': question,
    'answerLetter': answerLetter,
    'answerText': answerText,
  };
}

class ScenarioAnswersStore {
  ScenarioAnswersStore._();

  static List<ScenarioAnswer> _answers = const [];

  static List<ScenarioAnswer> get answers => List.unmodifiable(_answers);

  static void save(List<ScenarioAnswer> answers) {
    _answers = List.unmodifiable(answers);
  }

  static void clear() {
    _answers = const [];
  }
}
