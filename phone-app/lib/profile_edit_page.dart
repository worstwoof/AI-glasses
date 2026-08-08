import 'package:flutter/material.dart';

import 'models.dart';
import 'ui_kit.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({
    super.key,
    required this.initialProfile,
  });

  final AppUserProfile initialProfile;

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
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
        TextEditingController(text: profile.allergies.join('、'));
    _conditionsController =
        TextEditingController(text: profile.conditions.join('、'));
    _gender = profile.gender;
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

    final profile = widget.initialProfile.copyWith(
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
    );

    Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑档案'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
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
                      title: '基础信息',
                      subtitle: '这些信息会影响每日预算、识别建议和 OCR 风险提示',
                    ),
                    const SizedBox(height: 18),
                    _buildField(
                      controller: _nameController,
                      label: '昵称',
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _deviceController,
                      label: '设备名称',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _gender.isEmpty ? '未设置' : _gender,
                      decoration: const InputDecoration(labelText: '性别'),
                      items: const [
                        DropdownMenuItem(value: '男', child: Text('男')),
                        DropdownMenuItem(value: '女', child: Text('女')),
                        DropdownMenuItem(value: '未设置', child: Text('未设置')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _gender = value ?? '未设置';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            controller: _ageController,
                            label: '年龄',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            controller: _heightController,
                            label: '身高(cm)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            controller: _weightController,
                            label: '体重(kg)',
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
                      title: '饮食策略',
                      subtitle: '这里决定首页预算展示和 AI 生成建议的基线',
                    ),
                    const SizedBox(height: 18),
                    _buildField(
                      controller: _goalController,
                      label: '目标',
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _preferenceController,
                      label: '饮食偏好',
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _dailyTargetController,
                      label: '每日目标热量(kcal)',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _allergiesController,
                      label: '过敏原',
                      hintText: '多个项目用 顿号、逗号 或 空格分隔',
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _conditionsController,
                      label: '健康状态/慢病',
                      hintText: '多个项目用 顿号、逗号 或 空格分隔',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('保存本地档案'),
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
          return '请填写$label';
        }
        if (keyboardType == TextInputType.number && int.tryParse(text) == null) {
          return '$label 需要是数字';
        }
        return null;
      },
    );
  }

  List<String> _splitTags(String raw) {
    return raw
        .split(RegExp(r'[、,，\s]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
