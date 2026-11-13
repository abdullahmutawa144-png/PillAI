class SafetyOption {
  const SafetyOption({
    required this.label,
    required this.description,
    this.iconCodePoint,
  });

  final String label;
  final String description;
  final int? iconCodePoint;
}

abstract final class SafetyOptions {
  static const foodAndDrink = <SafetyOption>[
    SafetyOption(
      label: 'Tea or coffee',
      description: 'Caffeine and tannins can matter for selected medicines.',
    ),
    SafetyOption(
      label: 'Milk or calcium-rich foods',
      description: 'Calcium can affect absorption of selected medicines.',
    ),
    SafetyOption(
      label: 'Grapefruit or pomelo',
      description: 'These fruits affect the metabolism of selected medicines.',
    ),
    SafetyOption(
      label: 'Alcohol',
      description:
          'Alcohol can increase side effects or change medicine safety.',
    ),
    SafetyOption(
      label: 'Leafy greens / vitamin K',
      description: 'Consistency matters for selected blood-thinning medicines.',
    ),
    SafetyOption(
      label: 'High-potassium foods or salt substitutes',
      description:
          'Potassium can matter for selected heart and kidney medicines.',
    ),
    SafetyOption(
      label: 'Aged or fermented foods',
      description: 'Tyramine-rich foods interact with selected medicines.',
    ),
    SafetyOption(
      label: 'High-fiber meals',
      description: 'Fiber may change absorption timing for selected medicines.',
    ),
    SafetyOption(
      label: 'Fasting or empty-stomach routine',
      description:
          'Meal timing affects how selected medicines should be taken.',
    ),
    SafetyOption(
      label: 'Tube feeding',
      description:
          'Administration and feed timing require product-specific rules.',
    ),
  ];

  static const supplementsAndOtc = <SafetyOption>[
    SafetyOption(
      label: 'Iron',
      description: 'A mineral that may need spacing from selected medicines.',
    ),
    SafetyOption(
      label: 'Calcium',
      description:
          'A mineral that can affect absorption of selected medicines.',
    ),
    SafetyOption(
      label: 'Magnesium or zinc',
      description: 'Minerals that can interact with selected medicines.',
    ),
    SafetyOption(
      label: 'Antacids',
      description: 'May change stomach acidity or medicine absorption.',
    ),
    SafetyOption(
      label: 'Multivitamin',
      description: 'May contain several minerals or duplicate ingredients.',
    ),
    SafetyOption(
      label: 'Herbal or natural products',
      description: 'Exact ingredients and brands are important for checking.',
    ),
    SafetyOption(
      label: 'St John’s wort',
      description: 'A herb with important interactions for many medicines.',
    ),
    SafetyOption(
      label: 'Pain relievers',
      description:
          'Include ibuprofen, naproxen, aspirin, and paracetamol products.',
    ),
    SafetyOption(
      label: 'Cold or flu remedies',
      description: 'Combination products may duplicate active ingredients.',
    ),
    SafetyOption(
      label: 'Sleep aids',
      description: 'May add drowsiness when combined with other products.',
    ),
  ];

  static const lifestyle = <SafetyOption>[
    SafetyOption(
      label: 'Smoking or nicotine',
      description: 'Starting or stopping can affect selected medicines.',
    ),
    SafetyOption(
      label: 'Cannabis or CBD',
      description:
          'May affect alertness or how selected medicines are processed.',
    ),
    SafetyOption(
      label: 'Shift work',
      description: 'A changing sleep schedule can disrupt reminder plans.',
    ),
    SafetyOption(
      label: 'Frequent travel / timezone changes',
      description: 'Travel can require a reviewed reminder-plan transition.',
    ),
    SafetyOption(
      label: 'Religious or intermittent fasting',
      description:
          'PillAI can plan reminders around a confirmed fasting routine.',
    ),
    SafetyOption(
      label: 'Recent vomiting or diarrhea',
      description:
          'This can affect hydration, absorption, and missed-dose advice.',
    ),
    SafetyOption(
      label: 'Upcoming surgery or procedure',
      description:
          'Medicine instructions must come from the clinical care team.',
    ),
  ];

  static const accessibility = <SafetyOption>[
    SafetyOption(
      label: 'Larger text and buttons',
      description: 'Use the Simple layout with clearer, larger controls.',
    ),
    SafetyOption(
      label: 'Voice input',
      description:
          'Ask PillAI by speaking and review the transcript before sending.',
    ),
    SafetyOption(
      label: 'Vision support',
      description:
          'Prefer strong contrast, spoken labels, and fewer visual details.',
    ),
    SafetyOption(
      label: 'Hearing support',
      description: 'Keep every voice state and alert visible as text.',
    ),
    SafetyOption(
      label: 'Dexterity support',
      description: 'Use larger targets and avoid precise gestures.',
    ),
    SafetyOption(
      label: 'Memory support',
      description:
          'Use one-step actions, confirmations, and caregiver handoff.',
    ),
    SafetyOption(
      label: 'Caregiver helps with medicines',
      description: 'Caregiver roles and dose handoff require secure accounts.',
    ),
  ];
}
