import 'package:flute/fake_async.dart';
import 'package:flute/ui.dart';

import 'package:flute/widgets.dart';

int _last = 0;
int get now => _last = DateTime.now().millisecondsSinceEpoch;
int get since => -(_last - now);

int frame = 0;

void timeApp(StatelessWidget app) {
  int _in = now;
  print("Into main:   $_in");
  now;
  runApp(app);
  int _since = since;
  int frameTotal = 0;
  String firstFrameHash = "";
  print("main:               ${"$_since".padLeft(6)}");
  WidgetsBinding.instance?.addPersistentFrameCallback((_) {
    String hash = globalSceneHash.toRadixString(16).padLeft(7, '0');
    if (++frame <= 1100) {
      if (frame == 1) {
        String s = "$since".padLeft(6);
        print("First frame:        $s");
        firstFrameHash = hash;
      }
      if (frame > 100) {
        frameTotal += since;
      }
      WidgetsBinding.instance!.scheduleFrameCallback((timeStamp) {
        now;
      });
      WidgetsBinding.instance!.scheduleFrame();
    } else {
      String s = "${frameTotal ~/ 1000}".padLeft(6) +
          "." +
          "${frameTotal % 1000}".padLeft(3, '0');
      print("Frame average:      $s");
      print("");
      print("First frame hash:  $firstFrameHash");
      print("Last frame hash:   $hash");
    }
  });

  now;
  fakeAsyncEventLoop();
}
