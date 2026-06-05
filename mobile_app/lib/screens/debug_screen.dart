/// DebugScreen (TapCall)
///
/// Purpose:
/// - Displays live logs and basic system status for troubleshooting
/// - Provides quick actions (copy logs, reset service, etc.)
///
/// Notes:
/// - In production, hook this to real log sources (e.g., a logger stream)
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Debug screen with live logs, quick actions, and system status
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  Timer? _refreshTimer;
  
  // System status
  bool _accessibilityEnabled = false;
  String _deviceInfo = 'Loading...';
  
  @override
  void initState() {
    super.initState();
    _startLogCapture();
    _loadSystemInfo();
    
    // Refresh system status every 2 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadSystemInfo();
    });
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _startLogCapture() {
    // In a real implementation, you'd capture debugPrint output
    // For now, add a sample log
    _addLog('🎯 Debug screen initialized');
    _addLog('📱 Ready to capture logs...');
  }
  
  void _loadSystemInfo() async {
    try {
      // Get accessibility status
      const channel = MethodChannel('com.tapcall.app/accessibility');
      final enabled = await channel.invokeMethod<bool>('isServiceEnabled');
      
      setState(() {
        _accessibilityEnabled = enabled ?? false;
        _deviceInfo = 'Android';
      });
    } catch (e) {
      setState(() {
        _deviceInfo = 'Error: $e';
      });
    }
  }
  
  void _addLog(String message) {
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 23);
      _logs.add('[$timestamp] $message');
      if (_logs.length > 500) {
        _logs.removeAt(0); // Keep only last 500 logs
      }
    });
    
    if (_autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }
  
  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
    _addLog('🗑️  Logs cleared');
  }
  
  Future<void> _testCall() async {
    _addLog('📞 Test call initiated...');
    // Trigger a test call
    // This would connect to your actual call system
  }
  
  Future<void> _resetAccessibility() async {
    try {
      _addLog('🔄 Resetting accessibility service...');
      const channel = MethodChannel('com.tapcall.app/accessibility');
      await channel.invokeMethod('resetCallState');
      _addLog('✅ Reset complete');
    } catch (e) {
      _addLog('❌ Reset failed: $e');
    }
  }
  
  Future<void> _copyLogsToClipboard() async {
    final allLogs = _logs.join('\n');
    await Clipboard.setData(ClipboardData(text: allLogs));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logs copied to clipboard')),
      );
    }
    _addLog('📋 Logs copied to clipboard');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Console'),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: Icon(_autoScroll ? Icons.lock_outline : Icons.lock_open),
            onPressed: () {
              setState(() {
                _autoScroll = !_autoScroll;
              });
            },
            tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          _buildStatusBar(),
          
          // Quick Actions
          _buildQuickActions(),
          
          // Log Output
          Expanded(
            child: _buildLogOutput(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusBar() {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _buildStatusItem(
            'Accessibility',
            _accessibilityEnabled,
            _accessibilityEnabled ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 20),
          _buildStatusItem(
            'Device',
            true,
            Colors.blue,
            text: _deviceInfo,
          ),
          const Spacer(),
          Text(
            '${_logs.length} logs',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusItem(String label, bool status, Color color, {String? text}) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: status ? [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ] : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text ?? label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
  
  Widget _buildQuickActions() {
    return Container(
      color: Colors.grey[850],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildActionButton(
              '🔄 Hot Reload',
              Colors.blue,
              () {
                _addLog('🔥 Hot reload triggered (simulated)');
                // In dev mode, you'd trigger actual hot reload
              },
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              '🗑️  Clear Logs',
              Colors.orange,
              _clearLogs,
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              '📋 Copy Logs',
              Colors.green,
              _copyLogsToClipboard,
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              '🔄 Reset Service',
              Colors.purple,
              _resetAccessibility,
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              '📞 Test Call',
              Colors.red,
              _testCall,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(0, 36),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, color: Colors.white),
      ),
    );
  }
  
  Widget _buildLogOutput() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(8),
      child: _logs.isEmpty
          ? const Center(
              child: Text(
                'No logs yet...\nTry making a call or triggering an action',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                Color logColor = Colors.white70;
                
                // Colorize logs based on content
                if (log.contains('❌') || log.contains('ERROR') || log.contains('FAILED')) {
                  logColor = Colors.red[300]!;
                } else if (log.contains('✅') || log.contains('SUCCESS')) {
                  logColor = Colors.green[300]!;
                } else if (log.contains('⚠️') || log.contains('WARNING')) {
                  logColor = Colors.orange[300]!;
                } else if (log.contains('🔍') || log.contains('DEBUG')) {
                  logColor = Colors.blue[300]!;
                } else if (log.contains('📞') || log.contains('CALL')) {
                  logColor = Colors.cyan[300]!;
                }
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    log,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 11,
                      color: logColor,
                      height: 1.3,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
