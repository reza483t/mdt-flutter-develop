import 'dart:async';
import 'dart:ui';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:helloworldtor/entity/initial-values.dart';
import 'package:helloworldtor/views/base_values_page.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'modules.dart'; // Import your TorController class

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tor Controller Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BaseValuesPage(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return ResponsiveBreakpoints.builder(child: child!, breakpoints: [
          const Breakpoint(start: 0, end: 450, name: MOBILE),
          const Breakpoint(start: 451, end: 800, name: TABLET),
          const Breakpoint(start: 801, end: 1920, name: DESKTOP),
          const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
        ]);
      },
    );
  }
}

class TorControlPage extends StatefulWidget {

  final InitialValues initialValues;

  const TorControlPage({Key? key, required this.initialValues}) : super(key: key);

  @override
  _TorControlPageState createState() => _TorControlPageState();
}

class _TorControlPageState extends State<TorControlPage> {
  final TorController torController = TorController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<String> _messages = [];
  bool _isTorConnected = false;
  Timer? _timer;
  List<FlSpot> downloadedBwInfo =
  List.generate(20, (index) => FlSpot(index.toDouble(), 0.0));

  List<Map<dynamic,dynamic>> _circuitsData = List.empty();

  late Map<dynamic, dynamic>? _circuitRelayInfo;
  late String? _countryCode;

  Future<void> _connectToTor() async {
    final res = await torController.connectToTor(
      ip: widget.initialValues.ip,
      port:widget.initialValues.port
      );
    print("res message : ${res['message']}");
    if (res['status']) {
      final authRes =
      await torController.authenticate(password: widget.initialValues.password);
      print("res message : ${authRes['message']}");
      if (authRes['status']) {
        setState(() {
          _isTorConnected = true;
        });
      } else {
        print(authRes['message']);
      }
    } else {
      print('Unable to connect to Tor control port');
    }
  }

  Future<void> _checkConnectionAndMessages() async {
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      setState(() {
        _isTorConnected = torController.getConnectionStatus();
      });

      if (_isTorConnected) {
        if (_timer == null) {
          torController.startBwEvent();
          _startTimer();
          print("timer started");
        }

        final messages=

      await torController.getDirectMessages();
      setState(() {
      _messages = (messages as List).map((item) => item as String).toList();
      });
      } else {
      _timer = null;
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text;
    await torController.sendDirectMessage(message);
    _messageController.clear();
  }

  Future<void> _tryAgain() async {
    await _connectToTor();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      setState(() {
        downloadedBwInfo = torController
            .getBandwidthInfo(filterBy: 20)
            .asMap()
            .entries
            .map((e) {
          return FlSpot(e.key.toDouble(), e.value["download"].toDouble());
        }).toList();
      });
    });
  }

  Future<void> fetchCircuitsStatus() async {
    var newCircuitsData = await torController.getCircuitStatus();

    print('newCircuitsData:$newCircuitsData');

    setState(() {
      _circuitsData = newCircuitsData;
    });
  }

  int provideRelaysLength() => _circuitsData.fold(
      0,
          (totalRelays, circuit) =>
      totalRelays +
          (circuit["relays"] as List<Map<dynamic, dynamic>>).length);

  Future<void> fetchCircuitRelayInfo(String relayFingerPrint) async {
    print('newRelayInfo:');
    var newRelayInfo =
    await torController.getRouterInfoByfingerPring(relayFingerPrint);

    // setState(() {
      print('newRelayInfo:$newRelayInfo');
      _circuitRelayInfo = newRelayInfo;
      
    // });
  }

  Future<void> fetchCountryCode(String ipv4) async {
    String? newCountryCode = await torController.getCountryFromIp(ipv4);

    setState(() {
      _countryCode = newCountryCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Tor Controller Demo'),
          backgroundColor: _isTorConnected ? Colors.green : Colors.red,
          leading: _isTorConnected
              ? null
              : IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _tryAgain,
          ),
        ),
        body: body());
  }

  Widget body() {
    if( torController.getConnectionStatus() )
    {fetchCircuitsStatus();}
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
    Expanded(
    flex: 1,
    child:

    ListView(
    scrollDirection: Axis.vertical,
    controller: ScrollController(),
    children: [
    Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [titleTextView("Circuits")],
    ),
    const SizedBox(height: 5),
    circuitInformationsBox(
    _circuitsData.length, provideRelaysLength()),
    const SizedBox(height: 30),
    Divider(),
    const SizedBox(height: 30),
    Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [titleTextView("Circuits  Details")],
    ),
    const SizedBox(height: 5),
    ciruitDetails()
    ],
    ))
    ]);
  }

  Widget circuitInformationsBox(int circuitCount, int relaysCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
      child: Container(
        height: 300,
        decoration: const BoxDecoration(
            color: Color(0xff393E46),
            borderRadius: BorderRadius.all(Radius.circular(10))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(5, 25, 5, 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  customTextView("Total Circuits $circuitCount"),
                  customTextView("Total Relays $relaysCount")
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget customTextView(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        color: Color(0xffEEEEEE),
      ),
    );
  }

  Widget titleTextView(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            color: Color(0xff00ADB5)));
  }

  Widget ciruitDetails() {
    return SizedBox(
      height: 250,
      child: ListView.separated(
          itemBuilder: (context, index) {
            return circuitDetailsBox(_circuitsData[index]);
          },
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemCount: 1),
    );
  }

  Widget circuitDetailsBox(Map<dynamic, dynamic> circuit) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
      child: Container(
        decoration: const BoxDecoration(
            color: Color(0xff393E46),
            borderRadius: BorderRadius.all(Radius.circular(15))),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  customTextView("id : ${circuit["circuitId"]}"),
                  customTextView("status : ${circuit["circuitStatus"]}"),
                ],
              ),
              Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                customTextView("purpose : ${circuit["extraInfo"]["PURPOSE"]}")
              ]),
              Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    customTextView(
                        "date created : ${(circuit["extraInfo"]["TIME_CREATED"] as String).split("T")[0]}")
                  ],

              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  customTextView(
                      "time created : ${(circuit["extraInfo"]["TIME_CREATED"] as String).split("T")[1]}")
                ],
              ),
              customTextView("relays"),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  itemBuilder: (context, index) {
                    // fetchCircuitRelayInfo(circuit["relays"][index]["Fingerprint"]);
                     fetchCountryCode(_circuitRelayInfo?["ip"]);
                    return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          customTextView("name : ${_circuitRelayInfo?["name"]}"),
                          customTextView("ip : ${_circuitRelayInfo?["ip"]}"),
                          CountryFlag.fromCountryCode("$_countryCode".toUpperCase(),
                              width: 15, height: 15)
                        ]);
                  },
                  itemCount:
                  (circuit["relays"] as List<Map<dynamic, dynamic>>).length,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _connectToTor();
    _checkConnectionAndMessages();
   fetchCircuitRelayInfo('3401BB20C195F2494CACC182A8486697995089E9');
  }

  @override
  void dispose() {
    torController.disconnectFromTor();
    super.dispose();
  }
}