import 'package:permission_handler/permission_handler.dart';

Future<bool> requestPermisson() async {
  var cameraStatus = await Permission.camera.request();
  var microphoneStatus = await Permission.microphone.request();

  if (cameraStatus.isGranted && microphoneStatus.isGranted) {
    return true;
  } else {
    return false;
  }
}
