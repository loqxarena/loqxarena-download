import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';

class UpdateScreen extends StatefulWidget {
  final String updateUrl;

  const UpdateScreen({super.key, required this.updateUrl});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = "A new version of LOQX ARENA is available. You must update to the latest version to ensure secure matches and payments.";

  Future<void> _startDownloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _statusText = "Downloading update... Please wait.";
    });

    try {
      // 1. Get the directory to save the APK
      Directory? tempDir = await getExternalStorageDirectory();
      String savePath = "${tempDir!.path}/loqx_arena_update.apk";

      // 2. Download the file using Dio for progress tracking
      Dio dio = Dio();
      await dio.download(
        widget.updateUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
            });
          }
        },
      );

      // 3. Download complete, trigger the Android Installer
      setState(() {
        _statusText = "Download complete! Launching installer...";
        _isDownloading = false;
      });

      final result = await OpenFilex.open(savePath);
      
      if (result.type != ResultType.done) {
        setState(() {
          _statusText = "Failed to open installer. Please check your storage permissions.";
        });
      }

    } catch (e) {
      setState(() {
        _isDownloading = false;
        _progress = 0.0;
        _statusText = "Download failed. Please check your internet connection and try again.";
      });
      debugPrint("Download Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // PopScope prevents them from using the Android Back button to escape
    return PopScope(
      canPop: false, 
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Warning Icon / Download Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 30)],
                ),
                child: Icon(
                  _isDownloading ? Icons.cloud_download : Icons.system_update, 
                  size: 80, 
                  color: AppColors.primary
                ),
              ),
              const SizedBox(height: 40),
              
              const Text(
                "MANDATORY UPDATE",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              Text(
                _statusText,
                style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // --- UI LOGIC: SHOW BUTTON OR PROGRESS BAR ---
              if (_isDownloading) ...[
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.white10,
                      color: AppColors.primary,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "${(_progress * 100).toStringAsFixed(1)}%",
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                    )
                  ],
                )
              ] else ...[
                PremiumButton(
                  text: "DOWNLOAD & INSTALL",
                  icon: Icons.download,
                  gradient: AppColors.goldButtonGradient,
                  onPressed: _startDownloadAndInstall,
                ),
                const SizedBox(height: 20),
                const Text("Note: The app will download and ask for installation permissions automatically.", style: TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center)
              ]
            ],
          ),
        ),
      ),
    );
  }
}