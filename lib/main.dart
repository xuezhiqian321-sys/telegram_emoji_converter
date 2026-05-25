import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const TelegramEmojiConverterApp());
}

class TelegramEmojiConverterApp extends StatelessWidget {
  const TelegramEmojiConverterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telegram Emoji Converter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ConverterPage(),
    );
  }
}

class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key});

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  String? inputPath;
  String? outputPath;

  bool isConverting = false;
  String logText = '请选择一个 MP4 视频，然后转换为 Telegram Video Emoji 需要的 WEBM / VP9 格式。';

  int size = 100;
  int duration = 3;
  int fps = 30;
  int crf = 35;

  Future<void> pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      setState(() {
        inputPath = result.files.single.path;
        outputPath = null;
        logText = '已选择视频：\n$inputPath';
      });
    } catch (e) {
      setState(() {
        logText = '选择视频失败：\n$e';
      });
    }
  }

  Future<void> convertVideo() async {
    if (inputPath == null) {
      setState(() {
        logText = '请先选择一个 MP4 视频。';
      });
      return;
    }

    setState(() {
      isConverting = true;
      outputPath = null;
      logText = '正在转换，请稍等...';
    });

    try {
      final tempDir = await getTemporaryDirectory();

      final outputFile = File(
        '${tempDir.path}/telegram_video_emoji_${DateTime.now().millisecondsSinceEpoch}.webm',
      );

      final escapedInput = inputPath!.replaceAll("'", "'\\''");
      final escapedOutput = outputFile.path.replaceAll("'", "'\\''");

      /*
        Telegram Video Emoji 常用处理：
        -t duration        限制时长
        -an                移除音频
        fps                设置帧率
        crop               裁剪为正方形
        scale              缩放到指定尺寸
        libvpx-vp9         VP9 编码
        -b:v 0 -crf        控制质量/体积
      */

      final command = [
        '-y',
        "-i '$escapedInput'",
        '-t $duration',
        '-an',
        '-vf "fps=$fps,crop=\'min(iw,ih)\':\'min(iw,ih)\',scale=$size:$size"',
        '-c:v libvpx-vp9',
        '-b:v 0',
        '-crf $crf',
        "'$escapedOutput'",
      ].join(' ');

      await FFmpegKit.executeAsync(
        command,
        (session) async {
          final returnCode = await session.getReturnCode();
          final logs = await session.getAllLogsAsString();

          if (ReturnCode.isSuccess(returnCode)) {
            final fileSize = await outputFile.length();

            setState(() {
              isConverting = false;
              outputPath = outputFile.path;
              logText = '''
转换成功！

输出文件：
${outputFile.path}

文件大小：
${formatBytes(fileSize)}

请点击“分享 WEBM 文件”，然后选择 Telegram。
建议发送给 @Stickers 时选择“作为文件发送”。
''';
            });
          } else {
            setState(() {
              isConverting = false;
              logText = '''
转换失败。

ReturnCode:
$returnCode

日志：
$logs
''';
            });
          }
        },
        (log) {
          final message = log.getMessage();
          if (message.trim().isNotEmpty) {
            setState(() {
              logText = message;
            });
          }
        },
        (statistics) {
          // 这里可以扩展进度显示
        },
      );
    } catch (e) {
      setState(() {
        isConverting = false;
        logText = '转换异常：\n$e';
      });
    }
  }

  Future<void> shareFile() async {
    if (outputPath == null) {
      setState(() {
        logText = '还没有生成 WEBM 文件。';
      });
      return;
    }

    final file = File(outputPath!);
    if (!await file.exists()) {
      setState(() {
        logText = '输出文件不存在，请重新转换。';
      });
      return;
    }

    try {
      await Share.shareXFiles(
        [XFile(outputPath!)],
        text: 'Telegram Video Emoji WEBM VP9',
      );
    } catch (e) {
      setState(() {
        logText = '分享失败：\n$e';
      });
    }
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(2)} KB';
    }

    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  Widget buildSettingRow({
    required String label,
    required int value,
    required int min,
    required int max,
    required void Function(int) onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(label),
            ),
            Expanded(
              child: Slider(
                value: value.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: max - min,
                label: value.toString(),
                onChanged: isConverting
                    ? null
                    : (v) {
                        onChanged(v.round());
                      },
              ),
            ),
            SizedBox(
              width: 50,
              child: Text(
                value.toString(),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildInfoBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.withOpacity(0.25),
        ),
      ),
      child: const Text(
        '输出格式：WEBM\n'
        '视频编码：VP9\n'
        '音频：已移除\n'
        '画面：自动裁剪为正方形\n'
        '用途：发送给 Telegram 的 @Stickers 创建 Video Emoji',
        style: TextStyle(fontSize: 13),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = inputPath == null
        ? '未选择视频'
        : inputPath!.split(Platform.pathSeparator).last;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Telegram Emoji 转换器'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              buildInfoBox(),

              const SizedBox(height: 10),

              Card(
                child: ListTile(
                  title: Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text('选择 MP4/MOV 等视频文件'),
                  trailing: ElevatedButton(
                    onPressed: isConverting ? null : pickVideo,
                    child: const Text('选择视频'),
                  ),
                ),
              ),

              buildSettingRow(
                label: '尺寸',
                value: size,
                min: 64,
                max: 512,
                onChanged: (v) {
                  setState(() {
                    size = v;
                  });
                },
              ),

              buildSettingRow(
                label: '时长',
                value: duration,
                min: 1,
                max: 5,
                onChanged: (v) {
                  setState(() {
                    duration = v;
                  });
                },
              ),

              buildSettingRow(
                label: 'FPS',
                value: fps,
                min: 15,
                max: 60,
                onChanged: (v) {
                  setState(() {
                    fps = v;
                  });
                },
              ),

              buildSettingRow(
                label: 'CRF',
                value: crf,
                min: 20,
                max: 50,
                onChanged: (v) {
                  setState(() {
                    crf = v;
                  });
                },
              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isConverting ? null : convertVideo,
                  icon: const Icon(Icons.transform),
                  label: const Text('转换为 WEBM VP9'),
                ),
              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: outputPath == null || isConverting ? null : shareFile,
                  icon: const Icon(Icons.share),
                  label: const Text('分享 WEBM 文件'),
                ),
              ),

              const SizedBox(height: 10),

              if (isConverting) const LinearProgressIndicator(),

              const SizedBox(height: 10),

              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      logText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
