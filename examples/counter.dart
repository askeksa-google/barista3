import 'package:flute/material.dart';

int _last = 0;
int get now => _last = DateTime.now().millisecondsSinceEpoch;
int get since => -(_last - now);

int frame = 0;

void main() {
  int _in = now;
  runApp(MyApp());
  int _since = since;
  print("Into main:   $_in");
  print("main:     ${"$_since".padLeft(4)}");
  WidgetsBinding.instance?.addPersistentFrameCallback((_) {
    if (++frame <= 25) {
      print("frame ${"$frame".padLeft(2)}: ${"$since".padLeft(4)}");
    }
    WidgetsBinding.instance!.scheduleFrame();
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage('Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage(this.title);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  void initState() {
    super.initState();
    AnimationController(
      vsync: this,
      duration: const Duration(hours: 5),
    )
      ..addListener(() {
        _incrementCounter();
      })
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}
