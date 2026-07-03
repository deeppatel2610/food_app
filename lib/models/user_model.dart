class UserModel {
  final int? id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final int age;
  final double weight;
  final double height;
  final double bmi;
  final String bmiCategory;
  final String bmiReport;
  final double calorieBudget;
  final List<String> healthConditions;

  UserModel({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.age,
    required this.weight,
    required this.height,
    required this.bmi,
    required this.bmiCategory,
    required this.bmiReport,
    required this.calorieBudget,
    required this.healthConditions,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Normalization logic for name fields
    dynamic rawFirstName = json['first_name'] ?? json['firstName'];
    dynamic rawLastName = json['last_name'] ?? json['lastName'];

    if (rawFirstName == null ||
        rawFirstName.toString() == 'null' ||
        rawFirstName.toString().trim().isEmpty) {
      if (json['name'] != null &&
          json['name'].toString() != 'null' &&
          json['name'].toString().trim().isNotEmpty) {
        final nameParts = json['name'].toString().trim().split(' ');
        rawFirstName = nameParts.first;
        if (nameParts.length > 1 &&
            (rawLastName == null || rawLastName.toString() == 'null')) {
          rawLastName = nameParts.sublist(1).join(' ');
        }
      } else if (json['username'] != null &&
          json['username'].toString() != 'null' &&
          json['username'].toString().trim().isNotEmpty) {
        rawFirstName = json['username'];
      } else if (json['email'] != null &&
          json['email'].toString() != 'null' &&
          json['email'].toString().trim().isNotEmpty) {
        rawFirstName = json['email'].toString().split('@').first;
      } else {
        rawFirstName = 'Guest';
      }
    }

    if (rawLastName == null || rawLastName.toString() == 'null') {
      rawLastName = '';
    }

    // Normalization logic for health conditions
    final healthConditionsRaw = json['health_conditions'] ?? json['healthConditions'];
    final List<String> parsedConditions = [];
    if (healthConditionsRaw is List) {
      parsedConditions.addAll(healthConditionsRaw.map((e) => e.toString()));
    } else if (json['health_problem'] != null) {
      parsedConditions.add(json['health_problem'].toString());
    } else {
      parsedConditions.add('None');
    }

    return UserModel(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      firstName: rawFirstName.toString(),
      lastName: rawLastName.toString(),
      username: json['username']?.toString() ?? 'guest',
      email: json['email']?.toString() ?? 'guest@example.com',
      age: int.tryParse(json['age']?.toString() ?? '') ?? 25,
      weight: double.tryParse(json['weight']?.toString() ?? '') ?? 70.0,
      height: double.tryParse(json['height']?.toString() ?? '') ?? 175.0,
      bmi: double.tryParse(json['bmi']?.toString() ?? '') ?? 0.0,
      bmiCategory: json['bmi_category']?.toString() ?? json['bmiCategory']?.toString() ?? 'Normal',
      bmiReport: json['bmi_report']?.toString() ?? json['bmiReport']?.toString() ?? 'BMI report and recommendations are provided by the backend API.',
      calorieBudget: double.tryParse(json['calorie_budget']?.toString() ?? json['calorieBudget']?.toString() ?? '') ?? 2000.0,
      healthConditions: parsedConditions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'firstName': firstName,
      'last_name': lastName,
      'lastName': lastName,
      'username': username,
      'email': email,
      'age': age,
      'weight': weight,
      'height': height,
      'bmi': bmi,
      'bmi_category': bmiCategory,
      'bmiCategory': bmiCategory,
      'bmi_report': bmiReport,
      'bmiReport': bmiReport,
      'calorie_budget': calorieBudget,
      'calorieBudget': calorieBudget,
      'health_conditions': healthConditions,
      'healthConditions': healthConditions,
    };
  }

  // Operator lookup for Map compatibility in UI
  dynamic operator [](String key) {
    switch (key) {
      case 'id': return id;
      case 'first_name':
      case 'firstName': return firstName;
      case 'last_name':
      case 'lastName': return lastName;
      case 'username': return username;
      case 'email': return email;
      case 'age': return age;
      case 'weight': return weight;
      case 'height': return height;
      case 'bmi': return bmi;
      case 'bmi_category':
      case 'bmiCategory': return bmiCategory;
      case 'bmi_report':
      case 'bmiReport': return bmiReport;
      case 'calorie_budget':
      case 'calorieBudget': return calorieBudget;
      case 'health_conditions':
      case 'healthConditions': return healthConditions;
      default: return null;
    }
  }
}
