class FoodAnalysisModel {
  final dynamic id;
  final String name;
  final int calories;
  final String status;
  final String statusColor;
  final bool isPackaged;
  final bool isOpenFood;
  final List<String> badIngredients;
  final String advice;
  final String scannedAt;

  FoodAnalysisModel({
    required this.id,
    required this.name,
    required this.calories,
    required this.status,
    required this.statusColor,
    required this.isPackaged,
    required this.isOpenFood,
    required this.badIngredients,
    required this.advice,
    required this.scannedAt,
  });

  factory FoodAnalysisModel.fromJson(Map<String, dynamic> json) {
    final data = json['analysis'] ?? json;
    final String foodName = data['foodName'] ?? data['food_name'] ?? 'Scanned Meal';
    final nutrition = data['nutrition'] ?? {};
    final int calories = ((nutrition['caloriesKcal'] ?? nutrition['calories_kcal']) as num?)?.toInt() ?? 0;

    final verdict = data['verdict'] ?? {};
    final String healthyStatus = (verdict['healthyStatus'] ?? verdict['healthy_status'] ?? '').toString().toLowerCase();

    String status = 'Moderate';
    String statusColorStr = 'orange';

    if (healthyStatus.contains('unhealthy') || healthyStatus.contains('poor')) {
      status = 'Unhealthy';
      statusColorStr = 'red';
    } else if (healthyStatus.contains('healthy') || healthyStatus.contains('good')) {
      status = 'Healthy';
      statusColorStr = 'green';
    }

    final bool isPackaged = data['isPackaged'] ?? data['is_packaged'] ?? false;
    final bool isOpenFood = !isPackaged;

    final ingredients = data['ingredients'] ?? {};
    final List<dynamic> unhealthyRaw = ingredients['unhealthy'] ?? [];
    final List<String> badIngredients = unhealthyRaw.map((e) => e.toString()).toList();
    final String advice = verdict['reasoning'] ?? '';
    final String scannedAt = json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String();
    final dynamic recordId = json['recordId'] ?? json['record_id'] ?? json['id'];

    return FoodAnalysisModel(
      id: recordId,
      name: foodName,
      calories: calories,
      status: status,
      statusColor: statusColorStr,
      isPackaged: isPackaged,
      isOpenFood: isOpenFood,
      badIngredients: badIngredients,
      advice: advice,
      scannedAt: scannedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'status': status,
      'statusColor': statusColor,
      'isPackaged': isPackaged,
      'is_packaged': isPackaged,
      'isOpenFood': isOpenFood,
      'badIngredients': badIngredients,
      'advice': advice,
      'scannedAt': scannedAt,
      'scanned_at': scannedAt,
    };
  }

  // Operator lookup for Map compatibility in UI
  dynamic operator [](String key) {
    switch (key) {
      case 'id': return id;
      case 'name': return name;
      case 'calories': return calories;
      case 'status': return status;
      case 'statusColor': return statusColor;
      case 'isPackaged':
      case 'is_packaged': return isPackaged;
      case 'isOpenFood': return isOpenFood;
      case 'badIngredients': return badIngredients;
      case 'advice': return advice;
      case 'scannedAt':
      case 'scanned_at': return scannedAt;
      default: return null;
    }
  }
}
