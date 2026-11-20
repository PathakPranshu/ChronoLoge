enum DiaryGenerationMode {
  automatic(
    storageKey: "automatic",
    title: "Automatic Generation",
    description: "If you haven't added your personal input by 11:45 PM, ChronoLoge automatically generates your diary entry using the moments and data collected throughout your day.",
  ),
  waitForInput(
    storageKey: "wait-for-input",
    title: "Wait for My Input",
    description: 'Add your personal thoughts before the scheduled time. If you '
        "haven't finished, ChronoLoge saves your entry as a draft. You can "
        "revisit, edit and generate it whenever you're ready.",
  );

  const DiaryGenerationMode({
    required this.storageKey,
    required this.title,
    required this.description,
  });

  final String storageKey;
  final String title;
  final String description;

  static DiaryGenerationMode fromStorageKey(String? key) {
    return DiaryGenerationMode.values.firstWhere(
      (mode) => mode.storageKey == key,
      orElse: () => DiaryGenerationMode.waitForInput,
    );
  }
}
