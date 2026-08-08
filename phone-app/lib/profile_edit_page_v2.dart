import 'package:flutter/material.dart';

import 'models.dart';
import 'ui_kit.dart';

class ProfileEditPageV2 extends StatefulWidget {
  const ProfileEditPageV2({
    super.key,
    required this.initialProfile,
  });

  final AppUserProfile initialProfile;

  @override
  State<ProfileEditPageV2> createState() => _ProfileEditPageV2State();
}

class _ProfileEditPageV2State extends State<ProfileEditPageV2> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _deviceController;
  late final TextEditingController _ageController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _goalController;
  late final TextEditingController _preferenceController;
  late final TextEditingController _dailyTargetController;
  late final TextEditingController _allergiesController;
  late final TextEditingController _conditionsController;

  late String _gender;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _nameController = TextEditingController(text: profile.name);
    _deviceController = TextEditingController(text: profile.deviceName);
    _ageController = TextEditingController(text: '${profile.age}');
    _heightController = TextEditingController(text: '${profile.heightCm}');
    _weightController = TextEditingController(text: '${profile.weightKg}');
    _goalController = TextEditingController(text: profile.goal);
    _preferenceController = TextEditingController(text: profile.preference);
    _dailyTargetController =
        TextEditingController(text: '${profile.dailyTargetCalories}');
    _allergiesController =
        TextEditingController(text: profile.allergies.join('\u3001'));
    _conditionsController =
        TextEditingController(text: profile.conditions.join('\u3001'));
    _gender = profile.gender.isEmpty ? '\u672a\u8bbe\u7f6e' : profile.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _deviceController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _goalController.dispose();
    _preferenceController.dispose();
    _dailyTargetController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      widget.initialProfile.copyWith(
        name: _nameController.text.trim(),
        deviceName: _deviceController.text.trim(),
        gender: _gender,
        age: int.parse(_ageController.text.trim()),
        heightCm: int.parse(_heightController.text.trim()),
        weightKg: int.parse(_weightController.text.trim()),
        goal: _goalController.text.trim(),
        preference: _preferenceController.text.trim(),
        dailyTargetCalories: int.parse(_dailyTargetController.text.trim()),
        allergies: _splitTags(_allergiesController.text),
        conditions: _splitTags(_conditionsController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('\u7f16\u8f91\u6863\u6848'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('\u4fdd\u5b58'),
          ),
        ],
      ),
      body: MeshBackground(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PageHeader(
                      title: '\u57fa\u7840\u4fe1\u606f',
                      subtitle:
                          '\u8fd9\u4e9b\u4fe1\u606f\u4f1a\u5f71\u54cd\u6bcf\u65e5\u9884\u7b97\u3001\u8bc6\u522b\u5efa\u8bae\u548c OCR \u98ce\u9669\u63d0\u793a',
                    ),
                    const SizedBox(height: 18),
                    _buildField(
                      controller: _nameController,
                      label: '\u6635\u79f0',
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _deviceController,
                      label: '\u8bbe\u5907\u540d\u79f0',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration(
                        labelText: '\u6027\u522b',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: '\u7537',
                          child: Text('\u7537'),
                        ),
                        DropdownMenuItem(
                          value: '\u5973',
                          child: Text('\u5973'),
                        ),
                        DropdownMenuItem(
                          value: '\u672a\u8bbe\u7f6e',
                          child: Text('\u672a\u8bbe\u7f6e'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _gender = value ?? '\u672a\u8bbe\u7f6e';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            controller: _ageController,
                            label: '\u5e74\u9f84',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            controller: _heightController,
                            label: '\u8eab\u9ad8(cm)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            controller: _weightController,
                            label: '\u4f53\u91cd(kg)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PageHeader(
                      title: '\u996e\u98df\u7b56\u7565',
                      subtitle:
                          '\u8fd9\u91cc\u51b3\u5b9a\u9996\u9875\u9884\u7b97\u5c55\u793a\u548c AI \u751f\u6210\u5efa\u8bae\u7684\u57fa\u7ebf',
                    ),
                    const SizedBox(height: 18),
                    _buildField(
                      controller: _goalController,
                      label: '\u76ee\u6807',
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _preferenceController,
                      label: '\u996e\u98df\u504f\u597d',
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _dailyTargetController,
                      label: '\u6bcf\u65e5\u76ee\u6807\u70ed\u91cf(kcal)',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _allergiesController,
                      label: '\u8fc7\u654f\u539f',
                      hintText:
                          '\u591a\u4e2a\u9879\u76ee\u7528\u987f\u53f7\u3001\u9017\u53f7\u6216\u7a7a\u683c\u5206\u9694',
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _conditionsController,
                      label: '\u5065\u5eb7\u72b6\u6001/\u6162\u75c5',
                      hintText:
                          '\u591a\u4e2a\u9879\u76ee\u7528\u987f\u53f7\u3001\u9017\u53f7\u6216\u7a7a\u683c\u5206\u9694',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('\u4fdd\u5b58\u672c\u5730\u6863\u6848'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) {
          return '\u8bf7\u586b\u5199$label';
        }
        if (keyboardType == TextInputType.number && int.tryParse(text) == null) {
          return '$label \u9700\u8981\u662f\u6570\u5b57';
        }
        return null;
      },
    );
  }

  List<String> _splitTags(String raw) {
    return raw
        .split(RegExp(r'[\u3001,\uFF0C\s]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
