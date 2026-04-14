import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/common_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.isConnected,
    required this.syncText,
    required this.onToggleConnection,
    required this.onSyncNow,
  });

  final AppUserProfile profile;
  final bool isConnected;
  final String syncText;
  final Future<void> Function() onToggleConnection;
  final Future<void> Function() onSyncNow;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
      children: [
        Center(
          child: Text(
            '档案',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 18),
        GlassCard(
          padding: const EdgeInsets.all(18),
          accent: const Color(0xFF74FFD2),
          child: Row(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9CF7DA), Color(0xFF3B7E68)],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: const Icon(Icons.person, size: 34, color: Color(0xFF0D1B17)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '连接设备：${profile.deviceName}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF9FB3AE),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isConnected
                    ? Icons.bluetooth_connected_rounded
                    : Icons.bluetooth_disabled_rounded,
                color: isConnected ? const Color(0xFF79FFD5) : const Color(0xFFFFA384),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        InfoCard(
          title: '个人信息',
          lines: [
            '性别：${profile.gender}',
            '年龄：${profile.age} 岁',
            '身高：${profile.heightCm} cm',
            '体重：${profile.weightKg} kg',
          ],
        ),
        const SizedBox(height: 16),
        InfoCard(
          title: '健康状态',
          lines: [
            '疾病史：${profile.conditions.join('、')}',
            '过敏原：${profile.allergies.join('、')}',
            '目标：${profile.goal}',
          ],
        ),
        const SizedBox(height: 16),
        InfoCard(
          title: '饮食偏好',
          lines: [
            '饮食偏好：${profile.preference}',
            '提醒策略：高盐高糖主动预警',
            '建议模式：识别后给出替代方案',
          ],
        ),
        const SizedBox(height: 16),
        InfoCard(
          title: 'AI 系统',
          lines: [
            'AI 健康检测：已启用',
            '识别引擎：Food Vision v1.0',
            '闭环建议：已启用',
            syncText,
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: onSyncNow,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF5CF3C4),
                  foregroundColor: const Color(0xFF0B1719),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text('同步数据'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: onToggleConnection,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFB2A0),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: Color(0x66FF9B86)),
                ),
                child: Text(isConnected ? '断开眼镜' : '重新连接'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

