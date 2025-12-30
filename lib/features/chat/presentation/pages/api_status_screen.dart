import 'package:flutter/material.dart';
import 'package:clientapp/core/services/biblical_chat_api.dart';
import 'package:clientapp/core/models/chat_models.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/core/config/app_config.dart';

class ApiStatusScreen extends StatefulWidget {
  const ApiStatusScreen({super.key});

  @override
  State<ApiStatusScreen> createState() => _ApiStatusScreenState();
}

class _ApiStatusScreenState extends State<ApiStatusScreen> {
  HealthStatus? _healthStatus;
  ApiStats? _apiStats;
  List<String>? _availableModels;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadApiInfo();
  }

  Future<void> _loadApiInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load health status
      final health = await BiblicalChatApiService.checkHealth();
      setState(() => _healthStatus = health);

      // Load stats (requires authentication)
      try {
        final stats = await BiblicalChatApiService.getStats();
        setState(() => _apiStats = stats);
      } on ApiError catch (e) {
        print('Stats error: ${e.detail}');
      }

      // Load available models
      try {
        final models = await BiblicalChatApiService.getAvailableModels();
        setState(() => _availableModels = models);
      } on ApiError catch (e) {
        print('Models error: ${e.detail}');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(
        title: const Text(
          'API Status',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: kRoyalBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApiInfo,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kPurple),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // API Configuration
                  _buildSection(
                    'Configuration',
                    [
                      _buildInfoTile(
                        'Base URL',
                        AppConfig.baseUrl,
                        icon: Icons.cloud,
                      ),
                      _buildInfoTile(
                        'API Key',
                        '${AppConfig.apiKey.substring(0, 20)}...',
                        icon: Icons.key,
                      ),
                      _buildInfoTile(
                        'Rate Limit',
                        '${AppConfig.rateLimitPerMinute} requests/minute',
                        icon: Icons.speed,
                      ),
                      _buildInfoTile(
                        'Max Characters',
                        '${AppConfig.maxCharactersPerMessage} chars',
                        icon: Icons.text_fields,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Health Status
                  _buildSection(
                    'Health Status',
                    [
                      if (_healthStatus != null) ...[
                        _buildHealthTile(),
                      ] else if (_error != null) ...[
                        _buildErrorTile(_error!),
                      ] else ...[
                        const CircularProgressIndicator(),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // API Statistics
                  if (_apiStats != null) ...[
                    _buildSection(
                      'API Statistics',
                      [
                        _buildInfoTile(
                          'Endpoints',
                          '${_apiStats!.endpoints.length} available',
                          icon: Icons.api,
                        ),
                        _buildInfoTile(
                          'Features',
                          '${_apiStats!.features.length} enabled',
                          icon: Icons.star,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Available Models
                  if (_availableModels != null && _availableModels!.isNotEmpty) ...[
                    _buildSection(
                      'Available AI Models',
                      _availableModels!
                          .map((model) => _buildInfoTile(
                                'Model',
                                model,
                                icon: Icons.psychology,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Biblical Personas
                  _buildSection(
                    'Biblical Personas',
                    BiblicalPersona.values
                        .map((persona) => _buildPersonaTile(persona))
                        .toList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kRoyalBlue.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kRoyalBlue, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: kPurple, size: 20),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8B8B92),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthTile() {
    final isHealthy = _healthStatus!.isHealthy;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isHealthy ? Colors.green : Colors.red).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHealthy ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isHealthy ? Icons.check_circle : Icons.error,
            color: isHealthy ? Colors.green : Colors.red,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHealthy ? 'API Healthy' : 'API Error',
                  style: TextStyle(
                    color: isHealthy ? Colors.green : Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _healthStatus!.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Last checked: ${_healthStatus!.timestamp}',
                  style: const TextStyle(
                    color: Color(0xFF8B8B92),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorTile(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connection Error',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  error,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonaTile(BiblicalPersona persona) {
    Color personaColor;
    switch (persona) {
      case BiblicalPersona.jesus:
        personaColor = kPurple;
        break;
      case BiblicalPersona.god:
        personaColor = kGold;
        break;
      case BiblicalPersona.livingWord:
        personaColor = kRed;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: personaColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: personaColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  persona == BiblicalPersona.jesus
                      ? Icons.auto_awesome
                      : persona == BiblicalPersona.god
                          ? Icons.cloud
                          : Icons.menu_book,
                  color: personaColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  persona.displayName,
                  style: TextStyle(
                    color: personaColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              persona.endpoint,
              style: const TextStyle(
                color: Color(0xFF8B8B92),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              persona.description,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}