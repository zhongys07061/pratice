import 'package:flutter/services.dart';

/// 与原生 Android 交互：接收外部“打开/分享”的文档、所有文件访问权限。
class NativeService {
  NativeService._();
  static final NativeService instance = NativeService._();

  static const MethodChannel _channel =
      MethodChannel('com.yourname.zicebao/native');

  /// 是否已授予「所有文件访问」权限（Android 11+）
  Future<bool> hasAllFilesAccess() async {
    return await _channel.invokeMethod<bool>('hasAllFilesAccess') ?? false;
  }

  /// 跳转到系统设置页请求「所有文件访问」权限
  Future<void> requestAllFilesAccess() async {
    await _channel.invokeMethod('requestAllFilesAccess');
  }

  /// 冷启动时取出通过“打开方式”传入的文档；无则返回 null。
  Future<SharedFile?> takeSharedFile() async {
    final data = await _channel.invokeMethod('getSharedFile');
    return _toSharedFile(data);
  }

  /// 监听 App 运行中收到的新文档。
  void setSharedFileListener(void Function(SharedFile file) onFile) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedFile') {
        final file = _toSharedFile(call.arguments);
        if (file != null) onFile(file);
      }
    });
  }

  SharedFile? _toSharedFile(dynamic data) {
    if (data is! Map) return null;
    final name = (data['name'] as String?) ?? '共享文档';
    final bytes = data['bytes'];
    if (bytes is! Uint8List || bytes.isEmpty) return null;
    return SharedFile(name, bytes);
  }
}

/// 外部传入的一个文档文件。
class SharedFile {
  final String name;
  final Uint8List bytes;
  const SharedFile(this.name, this.bytes);
}
