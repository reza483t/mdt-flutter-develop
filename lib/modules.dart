import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:core';


// classes to manage events 

// the base class
class TorEventHandler {
  final List<String> _messages = [];
  Socket? _socket;
  bool _isConnected = false;
  String? _eventName;

  Future<void> connect({String ip = '127.0.0.1', int port = 9051}) async {
    if (!_isConnected){
      try {
        _socket = await Socket.connect(ip, port);
        _isConnected = true;
        _socket!.listen(
          receiveMessage,
          onError: (error) {
            _isConnected = false;
            _socket!.close();
          },
          onDone: () {
            _isConnected = false;
            _socket!.close();
          },
        );
      } catch (e) {
        _isConnected = false;
        // Throw an error to indicate connection failure
        throw Exception('Unable to connect to Tor control port: $e');
      }
    }
  }

  void disconnect() {
    _socket!.destroy();
    _isConnected = false;
  }

  Future<void> authenticate(String password) async {
    if (_isConnected){
      await sendMessage('authenticate "$password"');
    }
  }

  void startEvent() {
    sendMessage("setevents $_eventName");
  }

  void stopEvent() {
    sendMessage("setevents");
  }

  void receiveMessage(List<int> data) {
    String message = utf8.decode(data).trim();
    _messages.add(message);
  }

  Future<void> sendMessage(String message) async {
    int len = _messages.length;
    if (_isConnected) {
      if (message.isNotEmpty) {
        _socket!.write('$message\r\n');
        while (_messages.length <= len && _isConnected) {
          await Future.delayed(Duration(milliseconds: 10));
        }
      }
    }
  }

  List<String> GetAllMessages({int? filterBy}) {
    if (filterBy == null) {
      return _messages;
    }
    int _to = _messages.length;
    int _from = _messages.length - filterBy > 0 ? _messages.length - filterBy : 0;
    return _messages.sublist(_from, _to);
  }

  bool getStatus() {
    return _isConnected;
  }
}

class BandWidthEventHandler extends TorEventHandler {
  static BandWidthEventHandler? _instance;
  String? _eventName = 'bw';

  factory BandWidthEventHandler() {
    _instance ??= BandWidthEventHandler._internal();
    return _instance!;
  }

  BandWidthEventHandler._internal();

  List<Map> GetBwList({int? filterBy}) {
    String joinedMessages = _messages.join("\n");

    LineSplitter ls = new LineSplitter();
    List<String> lines = ls.convert(joinedMessages);

    List<String> filteredMessages =
        lines.where((message) => message.startsWith("650 BW")).toList();

    if (filterBy != null) {
      int _to = filteredMessages.length;
      int _from = filteredMessages.length - filterBy > 0 ? filteredMessages.length - filterBy : 0;
      filteredMessages = filteredMessages.sublist(_from, _to);
    }

    List<Map> bandwidthMapedInfo = [];
    for (String _message in filteredMessages) {
      List<String> _listedMessage = _message.split(' ');
      Map<String, int> bwInfo = {
        'download': int.parse(_listedMessage[2]),
        'upload': int.parse(_listedMessage[3])
      };
      bandwidthMapedInfo.add(bwInfo);
    }
    return bandwidthMapedInfo;
  }
}

class LogEventHandler extends TorEventHandler {
  static LogEventHandler? _instance;
  String? _eventName = 'debug';
  List<String> enebaledEvents = ['DEBUG', 'INFO', 'NOTICE', 'WARN', 'ERR'];

  factory LogEventHandler() {
    _instance ??= LogEventHandler._internal();
    return _instance!;
  }

  void startEvent({List<String>? events }) {
    String message = 'setevents';
    if (events == null) {
      events = enebaledEvents;
    }
    for ( String event in events) {
      event = event.toUpperCase();
      if (enebaledEvents.contains(event)){
        message += ' $event';
      }else{
        throw Exception("this is not a valid event $event");
      }
    }
    sendMessage(message);
  }

  List<Map> getLogs({int? filterBy}){

    String joinedMessages = _messages.join('\n');

    LineSplitter ls = new LineSplitter();
    List<String> lines = ls.convert(joinedMessages);
    List<String> trimmedMessages = lines.map((message) => message.trim()).toList();

    List<String> filteredMessages = trimmedMessages.where((message) => message.startsWith("650")).toList();

    if (filterBy != null) {
      int _to = filteredMessages.length;
      int _from = filteredMessages.length - filterBy > 0 ? filteredMessages.length - filterBy : 0;
      filteredMessages = filteredMessages.sublist(_from, _to);
    }

    // map to list to get just downloaded and uploaded values
    List<Map> logMapedInfo = [];
    for (String _message in filteredMessages) {
      List<String> _listedMessage = _message.split(' ');

      String type = _listedMessage[1];
      _listedMessage = _listedMessage.sublist(2); // remove type of the log
      String log = _listedMessage.join(' ');

      Map<String, String> logInfo = {
        'type': type,
        'log': log
      };

      logMapedInfo.add(logInfo);
    }

    return logMapedInfo;
  }

  LogEventHandler._internal();
}


// classes to manage commands and their response

// the base class
class TorInfoFetcher {
  final List<String> _messages = [];
  Socket? _socket;
  bool _isConnected = false;

  Future<void> connect({String ip = '127.0.0.1', int port = 9051}) async {
    if(!_isConnected){
      try {
        _socket = await Socket.connect(ip, port);
        _isConnected = true;
        _socket!.listen(
          receiveMessage,
          onError: (error) {
            _isConnected = false;
            _socket!.close();
          },
          onDone: () {
            _isConnected = false;
            _socket!.close();
          },
        );
      } catch (e) {
        _isConnected = false;
        // Throw an error to indicate connection failure
        throw Exception('Unable to connect to Tor control port: $e');
      }
    }
  }

  void disconnect() {
    _socket!.destroy();
    _isConnected = false;
  }

  Future<void> authenticate(String password) async {
    if (_isConnected){
      await sendMessage('authenticate "$password"');
      _messages.removeAt(0);
    }
  }

  void receiveMessage(List<int> data) {
    String message = utf8.decode(data).trim();
    _messages.add(message);
  }

  Future<void> sendMessage(String message) async{
    int len = _messages.length;
    if (_isConnected) {
      if (message.isNotEmpty) {
        _socket!.write('$message\r\n');
        while (_messages.length <= len && _isConnected) {
          await Future.delayed(Duration(milliseconds: 10));
        }
      }
    }
  }

  bool getStatus() {
    return _isConnected;
  }

}

class DirectConnectionWithTor extends TorInfoFetcher {
  static DirectConnectionWithTor? _instance;

  factory DirectConnectionWithTor() {
    _instance ??= DirectConnectionWithTor._internal();
    return _instance!;
  }

  DirectConnectionWithTor._internal();
  
  List<String> getAllMessages({int? filterBy}) {
    if (filterBy == null) {
      return _messages;
    }
    int _to = _messages.length;
    int _from = _messages.length - filterBy > 0 ? _messages.length - filterBy : 0;
    return _messages.sublist(_from, _to);
  }
}

class TrafficRead extends TorInfoFetcher {
  static TrafficRead? _instance;

  factory TrafficRead() {
    _instance ??= TrafficRead._internal();
    return _instance!;
  }

  TrafficRead._internal();

  Future<int> getValue() async {
    if (!_isConnected){
      return 0;
    }

    await sendMessage("getinfo traffic/read");

    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null){
      return 0;
    }
    
    RegExp regex = RegExp(r"250-traffic/read=(\d+)");
    Match? match = regex.firstMatch(lastMessage);

    if (match != null) {
      String value = match.group(1)!;
      return int.parse(value);
    } else {
      return 0; // No match found
    }
  }

}

class TrafficWritten extends TorInfoFetcher {
  static TrafficWritten? _instance;

  factory TrafficWritten() {
    _instance ??= TrafficWritten._internal();
    return _instance!;
  }

  TrafficWritten._internal();

  Future<int> getValue() async {
    if (!_isConnected){
      return 0;
    }
    await sendMessage("getinfo traffic/written");

    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null){
      return 0;
    }
    
    RegExp regex = RegExp(r"250-traffic/written=(\d+)");
    Match? match = regex.firstMatch(lastMessage);

    if (match != null) {
      String value = match.group(1)!;
      return int.parse(value);
    } else {
      return 0; // No match found
    }
  }

}

class Uptime extends TorInfoFetcher {
  static Uptime? _instance;

  factory Uptime() {
    _instance ??= Uptime._internal();
    return _instance!;
  }

  Uptime._internal();

  Future<int> getValue() async {
    if (!_isConnected){
      return 0;
    }
    await sendMessage("getinfo uptime");

    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null){
      return 0;
    }
    
    RegExp regex = RegExp(r"250-uptime=(\d+)");
    Match? match = regex.firstMatch(lastMessage);

    if (match != null) {
      String value = match.group(1)!;
      return int.parse(value);
    } else {
      return 0; // No match found
    }
  }

}

class ProcessPid extends TorInfoFetcher {
  static ProcessPid? _instance;

  factory ProcessPid() {
    _instance ??= ProcessPid._internal();
    return _instance!;
  }

  ProcessPid._internal();

  Future<int> getValue() async {
    if (!_isConnected){
      return -1;
    }
    await sendMessage("getinfo process/pid");

    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null){
      return -1;
    }
    
    RegExp regex = RegExp(r"250-process/pid=(\d+)");
    Match? match = regex.firstMatch(lastMessage);

    if (match != null) {
      String value = match.group(1)!;
      return int.parse(value);
    } else {
      return -1; // No match found
    }
  }

}

class ProcessUid extends TorInfoFetcher {
  static ProcessUid? _instance;

  factory ProcessUid() {
    _instance ??= ProcessUid._internal();
    return _instance!;
  }

  ProcessUid._internal();

  Future<int> getValue() async {
    if (!_isConnected){
      return -1;
    }
    await sendMessage("getinfo process/uid");

    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null){
      return -1;
    }
    
    RegExp regex = RegExp(r"250-process/uid=(-?\d+)");
    Match? match = regex.firstMatch(lastMessage);

    if (match != null) {
      String value = match.group(1)!;
      return int.parse(value);
    } else {
      return -1; // No match found
    }
  }

}

class BootstrapPhase extends TorInfoFetcher {
  static BootstrapPhase? _instance;

  factory BootstrapPhase() {
    _instance ??= BootstrapPhase._internal();
    return _instance!;
  }

  BootstrapPhase._internal();

  Future<Map<String, String?>> getValue() async{
    if (!_isConnected){
      return {'phase' : null, 'progress': null , 'tag' : null, 'summary' : null};
    }
    await sendMessage("getinfo status/bootstrap-phase");

    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null) {
      return {'phase' : null, 'progress': null , 'tag' : null, 'summary' : null}; // No match found
    }

    RegExp regex = RegExp(r'250-status\/bootstrap-phase=(\S+) BOOTSTRAP PROGRESS=(\d+) TAG=(\S+) SUMMARY="(\S+)"');
    Match? match = regex.firstMatch(lastMessage);

    if (match != null) {
      // Create a map to display the captured groups
      Map<String, String?> capturedGroups = {
        'phase': match.group(1)!,
        'progress': match.group(2)!,
        'tag': match.group(3)!,
        'summary': match.group(4)!,
      };

      return capturedGroups;
    } else {
      return {'phase' : null, 'progress': null , 'tag' : null, 'summary' : null}; // No match found
    }
  }

}

class IpToCountry extends TorInfoFetcher {
  static IpToCountry? _instance;

  factory IpToCountry() {
    _instance ??= IpToCountry._internal();
    return _instance!;
  }

  IpToCountry._internal();

  Future<String?> getValue(String ip) async {
    if (!_isConnected){
      return null;
    }
    await sendMessage("getinfo ip-to-country/$ip");

    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null){
      return null;
    }

    RegExp regex = RegExp(r"250-ip-to-country/\S+=(\S+)");
    Match? match = regex.firstMatch(lastMessage);

    if (match != null) {
      String value = match.group(1)!;
      return value;
    } else {
      return null; // No match found
    }
  }

}

class ConsensusValidAfter extends TorInfoFetcher {
  static ConsensusValidAfter? _instance;

  factory ConsensusValidAfter() {
    _instance ??= ConsensusValidAfter._internal();
    return _instance!;
  }

  ConsensusValidAfter._internal();

  Future<DateTime?> getValue() async {
    if (!_isConnected){
      return null;
    }
    await sendMessage("getinfo consensus/valid-after");

    String? lastMessage = _messages.lastOrNull ;
    
    if (lastMessage == null){
      return null;
    }

    RegExp regex = RegExp(r"250-consensus\/valid-after=(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\S+)");
    Match? match = regex.firstMatch(lastMessage);

    if (match != null) {
      String value = match.group(1)!;

      final timeData = DateTime.tryParse(value);
      return timeData;
    } else {
      return null; // No match found
    }

  }
}

class ConsensusValidUntil extends TorInfoFetcher {
  static ConsensusValidUntil? _instance;

  factory ConsensusValidUntil() {
    _instance ??= ConsensusValidUntil._internal();
    return _instance!;
  }

  ConsensusValidUntil._internal();

  Future<DateTime?> getValue() async {
    if (!_isConnected){
      return null;
    }
    await sendMessage("getinfo consensus/valid-until");

    String? lastMessage = _messages.lastOrNull ;
    
    if (lastMessage == null){
      return null;
    }

    RegExp regex = RegExp(r"250-consensus\/valid-until=(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\S+)");
    Match? match = regex.firstMatch(lastMessage);

    if (match != null) {
      String value = match.group(1)!;

      final timeData = DateTime.tryParse(value);
      return timeData;
    } else {
      return null; // No match found
    }

  }
}

class ConsensusFreshUntil extends TorInfoFetcher {
  static ConsensusFreshUntil? _instance;

  factory ConsensusFreshUntil() {
    _instance ??= ConsensusFreshUntil._internal();
    return _instance!;
  }

  ConsensusFreshUntil._internal();

  Future<DateTime?> getValue() async {
    if (!_isConnected){
      return null;
    }
    await sendMessage("getinfo consensus/fresh-until");

    String? lastMessage = _messages.lastOrNull ;
    
    if (lastMessage == null){
      return null;
    }

    RegExp regex = RegExp(r"250-consensus\/fresh-until=(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\S+)");
    Match? match = regex.firstMatch(lastMessage);

    if (match != null) {
      String value = match.group(1)!;

      final timeData = DateTime.tryParse(value);
      return timeData;
    } else {
      return null; // No match found
    }

  }
}

class EventNames extends TorInfoFetcher {
  static EventNames? _instance;

  factory EventNames() {
    _instance ??= EventNames._internal();
    return _instance!;
  }

  EventNames._internal();
  
  Future<List<String>> getValue() async {
    if (!_isConnected){
      return [];
    }
    await sendMessage("getinfo events/names");

    String? lastMessage = _messages.lastOrNull ;
    
    if (lastMessage == null){
      return [];
    }

    RegExp regex = RegExp(r"250-events\/names=(.*)");
    Match? match = regex.firstMatch(lastMessage);

    if (match != null) {
      String value = match.group(1)!;
      List<String> eventList = value.split(' ');
      return eventList;
    } else {
      return []; // No match found
    }

  }

}

class GetConf extends TorInfoFetcher {
  static GetConf? _instance;

  factory GetConf() {
    _instance ??= GetConf._internal();
    return _instance!;
  }

  GetConf._internal();

  Future<String?> getValue(String confName) async {
    if (!_isConnected){
      return null;
    }
    await sendMessage("getconf $confName");

    String? lastMessage = _messages.lastOrNull ;
    
    if (lastMessage == null){
      return null;
    }

    RegExp regex = RegExp(r"250 \S+=(\d+)");
    Match? match = regex.firstMatch(lastMessage);

    if (match != null) {
      String value = match.group(1)!;
      return value;
    } else {
      return null; // No match found
    }
  }
}

class SetConf extends TorInfoFetcher {
  static SetConf? _instance;

  factory SetConf() {
    _instance ??= SetConf._internal();
    return _instance!;
  }

  SetConf._internal();
  Future<Map> setConfig(String configName , String configValue) async {
    if (!_isConnected){
      return {"status" : false , "message" : "not connected to the tor"};
    }
    await sendMessage("setconf $configName=configValue");
    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null){
      return {"status" : false , "message" : "could not find correct response from server"};
    }

    List<String> splitedMessage = lastMessage.split(" ");
    String responseCode = splitedMessage[0];
    bool status = responseCode == "250" ? true : false ;
    String response = splitedMessage.sublist(1).join(" ");
    return {"status" : status , "message" : response};
  }
}

class ResetConf extends TorInfoFetcher {
  static ResetConf? _instance;

  factory ResetConf() {
    _instance ??= ResetConf._internal();
    return _instance!;
  }

  ResetConf._internal();
  Future<Map> resetConfig(String configName) async {
    if (!_isConnected){
      return {"status" : false , "message" : "not connected to the tor"};
    }
    await sendMessage("resetconf $configName");
    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null){
      return {"status" : false , "message" : "could not find correct response from server"};
    }

    List<String> splitedMessage = lastMessage.split(" ");
    String responseCode = splitedMessage[0];
    bool status = responseCode == "250" ? true : false ;
    String response = splitedMessage.sublist(1).join(" ");
    return {"status" : status , "message" : response};
  }
}

class ConfigText extends TorInfoFetcher {
  static ConfigText? _instance;

  factory ConfigText() {
    _instance ??= ConfigText._internal();
    return _instance!;
  }

  ConfigText._internal();
    
  Future<Map> getValue() async {
    if (!_isConnected){
      return {};
    }
    await sendMessage("getinfo config-text");

    String? lastMessage = _messages.lastOrNull ;
    
    if (lastMessage == null){
      return {};
    }
    
    LineSplitter ls = new LineSplitter();
    List<String> lines = ls.convert(lastMessage);

    List<String> filteredLines = lines.where((line) => !line.startsWith("250")).toList();
    filteredLines.removeAt(filteredLines.length-1);

    Map configsDetails = {} ;
    for (String config in filteredLines){
      List<String> configDetailList = config.split(" ");
      configsDetails[configDetailList[0]] = configDetailList[1] ;
    }

    return configsDetails;

  }

}

class ConfigDefaults extends TorInfoFetcher {
  static ConfigDefaults? _instance;

  factory ConfigDefaults() {
    _instance ??= ConfigDefaults._internal();
    return _instance!;
  }

  ConfigDefaults._internal();
    
  Future<Map> getValue() async {
    if (!_isConnected){
      return {};
    }
    await sendMessage("getinfo config/defaults");

    String? lastMessage = _messages.lastOrNull ;
    
    if (lastMessage == null){
      return {};
    }
    
    LineSplitter ls = new LineSplitter();
    List<String> lines = ls.convert(lastMessage);

    List<String> filteredLines = lines.where((line) => !line.startsWith("250")).toList();
    filteredLines.removeAt(filteredLines.length-1);

    Map<String, dynamic> ConfigDefaults = {};

    for (String config in filteredLines) {
      List<String> configDetailList = config.split(" ");
      String configTitle = configDetailList[0];
      String configDetail = configDetailList.sublist(1).join(" ");

      if (ConfigDefaults.containsKey(configTitle)) {
        if (ConfigDefaults[configTitle] is String) {
          ConfigDefaults[configTitle] = [ConfigDefaults[configTitle], configDetail];
        } else {
          ConfigDefaults[configTitle].add(configDetail);
        }
      
      } else {
        ConfigDefaults[configTitle] = configDetail;
      }
    }

    return ConfigDefaults;
  }

}

class ProtocolInfo extends TorInfoFetcher {
  static ProtocolInfo? _instance;

  factory ProtocolInfo() {
    _instance ??= ProtocolInfo._internal();
    return _instance!;
  }

  ProtocolInfo._internal();
      
  Future<Map?> getValue() async {
    if (!_isConnected){
      return null;
    }
    await sendMessage("protocolinfo");

    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null){
      return null;
    }

    LineSplitter ls = new LineSplitter();
    List<String> lines = ls.convert(lastMessage);

    List<String> filteredLines = lines.where((line) => !line.startsWith("250 OK")).toList();

    Map protocolsInfo = {} ;

    for (String config in filteredLines){
      RegExp regex = RegExp(r"250-(\S+) (.+)");
      Match? protocolInfo = regex.firstMatch(config);

      if (protocolInfo != null){
        String? protocolName = protocolInfo.group(1);
        String? protocolValues = protocolInfo.group(2);

        if (protocolName == "AUTH") {
          Map? authValues = authInfoHandler(protocolValues!);
          protocolsInfo[protocolName] = authValues ;
        }else if (protocolName == "VERSION"){
          Map? versionValues = versionInfoHandler(protocolValues!);
          protocolsInfo[protocolName] = versionValues ;
        }else {
          protocolsInfo[protocolName] = protocolValues ;
        }

      }
    }

    return protocolsInfo;
  }

  Map? authInfoHandler(String authInfo) {
    Map authOutputInfo = {};

    try{
      List<String> sepratedData = authInfo.split(" ");

      // get auth method from the auth line in protocol info
      String authMethodInfo = sepratedData[0];
      List<String> sepratedAuthMethod = authMethodInfo.split("=");
      List<String> authMethods = sepratedAuthMethod[1].split(",");
      authOutputInfo["METHODS"] = authMethods;

      // get cookie file info from the auth line in protocol info
      String? cookieFileInfo = sepratedData.asMap().containsKey(1) ? sepratedData[1] : null;

      if (cookieFileInfo != null){
        List<String> sepratedcookieFileInfo = cookieFileInfo.split("=");
        String cookieFilePath = sepratedcookieFileInfo[1];
        authOutputInfo["COOKIEFILE"] = cookieFilePath;
      }else{
        authOutputInfo["COOKIEFILE"] = null;
      }

    }
    catch (e){
      return null;
    }
    return authOutputInfo;
  }

  Map? versionInfoHandler(String versionInfo){
    Map versionOutputInfo = {};
    try{
      RegExp regex = RegExp(r'Tor="([\d.]*)"');
      Match? regexVersion = regex.firstMatch(versionInfo);
      String? version = regexVersion!.group(1);
      versionOutputInfo["Tor"] = version;
    }
    catch (e){
      return null;
    }
    return versionOutputInfo;
  }

}

class TorVersion extends TorInfoFetcher {
  static TorVersion? _instance;

  factory TorVersion() {
    _instance ??= TorVersion._internal();
    return _instance!;
  }

  TorVersion._internal();

  Future<Map> getValue() async {
    if (!_isConnected){
      return {
        "versionNumber" :null,
        "versionTitle" : null,
      };
    }

    String? versionNumber = await getVersionNumber();
    String? versionTitle = await getVersionTitle();

    return {
      "versionNumber" : versionNumber,
      "versionTitle" : versionTitle,
    };
  }

  Future<String?> getVersionNumber() async {
    await sendMessage("getinfo version");

    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null){
      return null;
    }
    
    RegExp regex = RegExp(r"250-version=([\S]+)");
    Match? match = regex.firstMatch(lastMessage);

    if (match != null) {
      String value = match.group(1)!;
      return value;
    } else {
      return null; // No match found
    }
  }

  Future<String?> getVersionTitle() async {
    await sendMessage("getinfo status/version/current");

    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null){
      return null;
    }
    
    RegExp regex = RegExp(r"250-status\/version\/current=([\S]+)");
    Match? match = regex.firstMatch(lastMessage);

    if (match != null) {
      String value = match.group(1)!;
      return value;
    } else {
      return null; // No match found
    }
  }

}

class NetListeners extends TorInfoFetcher {
  static NetListeners? _instance;

  factory NetListeners() {
    _instance ??= NetListeners._internal();
    return _instance!;
  }

  NetListeners._internal();

  Future<Map> getValue() async {
    return {
      "orConnection" : await orConnection(),
      "directoryProtocol" : await directoryProtocol(),
      "socksProxyConnections" : await socksProxyConnections(),
      "transConnections" : await transConnections(),
      "natdConnections" : await natdConnections(),
      "dnsConnections" : await dnsConnections(),
      "controlConnections" : await controlConnections(),
      "extorConnections" : await extorConnections(),
      "httptunnelConnections" : await httptunnelConnections(),
    };
  }

  Future<List<String>?> orConnection() async {
    return _getListenerInfo("net/listeners/or");
  }

  Future<List<String>?> directoryProtocol() async {
    return _getListenerInfo("net/listeners/dir");
  }

  Future<List<String>?> socksProxyConnections() async {
    return _getListenerInfo("net/listeners/socks");
  }

  Future<List<String>?> transConnections() async {
    return _getListenerInfo("net/listeners/trans");
  }

  Future<List<String>?> natdConnections() async {
    return _getListenerInfo("net/listeners/natd");
  }

  Future<List<String>?> dnsConnections() async {
    return _getListenerInfo("net/listeners/dns");
  }

  Future<List<String>?> controlConnections() async {
    return _getListenerInfo("net/listeners/control");
  }

  Future<List<String>?> extorConnections() async {
    return _getListenerInfo("net/listeners/extor");
  }

  Future<List<String>?> httptunnelConnections() async {
    return _getListenerInfo("net/listeners/httptunnel");
  }

  Future<List<String>?> _getListenerInfo(String command) async {
    if (!_isConnected){
      return null;
    }
    await sendMessage("getinfo $command");
    String? lastMessage = _messages.lastOrNull;

    if (lastMessage == null) {
      return null;
    }


    List<String> listenerInfoList = [];

    RegExp regex = RegExp(r"250-net\/listeners\/\w+=(.*)");
    Match? match = regex.firstMatch(lastMessage);
    if (match != null) {
      String value = match.group(1)!;
      listenerInfoList = value.split(" ");
    }


    return listenerInfoList;
  }
}

class StreamStatus extends TorInfoFetcher {
  static StreamStatus? _instance;

  factory StreamStatus() {
    _instance ??= StreamStatus._internal();
    return _instance!;
  }

  StreamStatus._internal();

  Future<List<Map>> getValue() async{

    await sendMessage("getinfo stream-status");
    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null){
      return [];
    }

    RegExp regex = RegExp(r"250\+stream-status=([\s\S]*)");
    Match? match = regex.firstMatch(lastMessage);
    String spacificMessage = "";

    if (match == null){
      return [];
    }

    spacificMessage = match.group(1)!.trim();

    LineSplitter ls = new LineSplitter();
    List<String> lines = ls.convert(spacificMessage);

    List<String> filteredMessages = lines.where((line) => !line.startsWith("250 OK")).toList();

    if (filteredMessages.length >0){
      filteredMessages.removeAt(filteredMessages.length-1);
    }

    return _dataAnalysis(filteredMessages);
  }

  List<Map> _dataAnalysis(List<String> data){
    if (!_isConnected){
      return [];
    }
    List<Map> analyzedData = [];
    for (final item in data){
      List<String> ListedInfo = item.split(" ");
      Map mappedData = {
        "streamId" : ListedInfo[0],
        "status" : ListedInfo[1],
        "circuitId" : ListedInfo[2],
        "targetUrl" : ListedInfo[3],
      };
      analyzedData.add(mappedData);
    }
    return analyzedData;
  }
}

class OrconnStatus extends TorInfoFetcher {
  static OrconnStatus? _instance;

  factory OrconnStatus() {
    _instance ??= OrconnStatus._internal();
    return _instance!;
  }

  OrconnStatus._internal();

  Future<List<Map>> getValue() async{

    await sendMessage("getinfo orconn-status");
    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null){
      return [];
    }

    RegExp regex = RegExp(r"250\+orconn-status=([\s\S]*)");
    Match? match = regex.firstMatch(lastMessage);
    String spacificMessage = "";

    if (match == null){
      return [];
    }

    spacificMessage = match.group(1)!.trim();

    LineSplitter ls = new LineSplitter();
    List<String> lines = ls.convert(spacificMessage);

    List<String> filteredMessages = lines.where((line) => !line.startsWith("250 OK")).toList();

    if (filteredMessages.length >0){
      filteredMessages.removeAt(filteredMessages.length-1);
    }

    return _dataAnalysis(filteredMessages);

  }

  List<Map> _dataAnalysis(List<String> data){
    if (!_isConnected){
      return [];
    }
    List<Map> analyzedData = [];

    for (final item in data){
      List<String> ListedInfo = item.split(" ");
      List<String> NameAndIdInfo = ListedInfo[0].split("~");

      // because response is something like this we need to split it twice
      // $6315278A91710062D90B288199EFA06E4AAA9E8F~unnamed314 CONNECTED
      String fingerprint = NameAndIdInfo[0];
      String name = NameAndIdInfo[1];
      String status = ListedInfo[1];
      Map mappedData = {
        "fingerprint" : fingerprint.substring(1),
        "name" : name,
        "status" : status,
      };

      analyzedData.add(mappedData);
    }
    return analyzedData;
  }

}

class CircuitStatus extends TorInfoFetcher {
  static CircuitStatus? _instance;

  factory CircuitStatus() {
    _instance ??= CircuitStatus._internal();
    return _instance!;
  }

  CircuitStatus._internal();

  Future<List<Map>> getValue() async {
    await sendMessage("getinfo circuit-status");
    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null){
      return [];
    }

    RegExp regex = RegExp(r"250\+circuit-status=([\s\S]*)");
    Match? match = regex.firstMatch(lastMessage);
    String spacificMessage = "";

    if (match != null){
      spacificMessage = match.group(1)!;
      spacificMessage = spacificMessage.trim();
    }
    else{
      return [];
    }

    LineSplitter ls = new LineSplitter();
    List<String> lines = ls.convert(spacificMessage);

    List<String> filteredMessages = lines.where((line) => !line.startsWith("250 OK")).toList();

    if (filteredMessages.length >0){
      filteredMessages.removeAt(filteredMessages.length-1);
    }
    
    return _dataAnalysis(filteredMessages);
  }

  List<Map> _dataAnalysis(List<String> data){
    if (!_isConnected){
      return [];
    }

    List<Map> analyzedData = [];
    for (String item in data){
      List<String> listedItem = item.split(" ");
      String id = listedItem[0];
      String status = listedItem[1];
      String relays = listedItem[2].startsWith(r"$") ? listedItem[2] : "";
      List<String> extraInfo = relays == "" ? listedItem.sublist(2) : listedItem.sublist(3);

      List<Map> mappedRelays = _relayAnalysis(relays);
      Map mappedExtraInfo = _extraInfoAnalysis(extraInfo);

      analyzedData.add({
        "circuitId" : id,
        "circuitStatus" : status,
        "relays" : mappedRelays,
        "extraInfo" : mappedExtraInfo
      });

    }
    return analyzedData;
  }
  
  List<Map> _relayAnalysis(String data) {
    List<Map> analyzedData = [];
    List<String> sepratedRelays = data.split(",");
    RegExp regex = RegExp(r"\$([\S]+)~([\S]*)");
    for (final item in sepratedRelays){
      Match? extractedInfo = regex.firstMatch(item);

      if (extractedInfo != null){
        String fingerprint = extractedInfo.group(1)!;
        String name = extractedInfo.group(2)!;
        analyzedData.add({
          "Fingerprint" : fingerprint,
          "Name" : name
        });
      }
    }
    return analyzedData;
  }

  Map _extraInfoAnalysis(List<String> data){
    RegExp regex = RegExp(r"([\S]+)=([\S]*)");
    Map analyzedData = {};
    for(String item in data){
      Match? match = regex.firstMatch(item);
      if (match != null){
        String itemTitle = match.group(1)!;
        String itemValue = match.group(2)!;
        analyzedData[itemTitle] = itemValue;
      }
    }
    return analyzedData;
  }

}

class NsAll extends TorInfoFetcher {
  static NsAll? _instance;

  factory NsAll() {
    _instance ??= NsAll._internal();
    return _instance!;
  }

  NsAll._internal();

  Future<List<Map>> getValue() async {
    await sendMessage("getinfo ns/all");
    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null){
      return [];
    }

    LineSplitter ls = new LineSplitter();
    List<String> lines = ls.convert(lastMessage);

    List<String> filteredLines = lines.where((line) => !line.startsWith("250 OK")).toList();
    // remove the '.' in the list that is in the end of list.
    filteredLines.removeAt(filteredLines.length - 1);

    List<String> parsedBlocks = _seprateData(filteredLines);
    
    return _modifyData(parsedBlocks);
  }

  List<String> _seprateData(List<String> data){

    List<String> _sepratedData = [];

    String joinData(int index){
      bool flag = true;
      int currentIndex = index;
      String joinedData = "";

      while (flag){
        joinedData += " " + data[currentIndex];
        currentIndex += 1;
        flag = currentIndex >= data.length || data[currentIndex].startsWith("r") ? false : true;
      }
      return joinedData;
    }

    data.asMap().forEach((index, value) {
      if (value.startsWith("r")){
        _sepratedData.add(joinData(index));
      }
    });
    return _sepratedData;
  }

  List<Map> _modifyData(List<String> data){

    String? _extractInformation(String data , String pattern){
      if (!_isConnected){
        return null;
      }
      RegExp regex = RegExp(pattern);
      Match? match = regex.firstMatch(data);
      if (match != null){
        return match.group(1)!;
      }
      return null;
    }
    
    String? getRelayName(String data) {
      String pattern = r"r ([\S]+)";
      String? value = _extractInformation(data , pattern);
      return value;
    }

    String? getRelayFingerprint(String data) {
      String pattern = r"r [\S]+ ([\S]+ [\S]+)";
      String? value = _extractInformation(data , pattern);
      return value;
    }

    DateTime? getRelayPublicationTime(String data) {
      String pattern = r"r [\S]+ [\S]+ [\S]+ ([\S]+ [\S]+)";
      String? value = _extractInformation(data , pattern);
      return DateTime.tryParse(value!);
    }

    String? getRelayIp(String data){
      String pattern = r"r [\S]+ [\S]+ [\S]+ [\S]+ [\S]+ ([\S]+)";
      String? value = _extractInformation(data , pattern);
      return value;
    } 

    int? getRelayPort(String data){
      String pattern = r"r [\S]+ [\S]+ [\S]+ [\S]+ [\S]+ [\S]+ ([\S]+)";
      String? value = _extractInformation(data , pattern);
      int? result = int.tryParse(value!);
      return result;
    }

    bool? getIsRelayAsDefaultConfiguration(String data){
      String pattern = r"r [\S]+ [\S]+ [\S]+ [\S]+ [\S]+ [\S]+ [\S]+ (\d+)";
      String? value = _extractInformation(data , pattern);
      bool result = value == "0" ? false : true;
      return result;
    }

    String? getRelayIpV6(String data){
      String pattern = r"a (\S+)";
      String? value = _extractInformation(data , pattern);
      return value;
    }

    List<String>? getRelayFlags(String data){
      String pattern = r"s ([\S\s]+) w ";
      String? value = _extractInformation(data , pattern);
      List<String> result = value!.split(" ");
      return result;
    }

    int? getRelayBandWidth(String data){
      String pattern = r"Bandwidth=(\d+)";
      String? value = _extractInformation(data , pattern);
      int? result = int.tryParse(value!);
      return result;
    }

    List<Map> modifiedData = [];

    for (String item in data) {

      modifiedData.add(
        {
          "name" : getRelayName(item),
          "fingerprint" : getRelayFingerprint(item),
          "publicationTime" : getRelayPublicationTime(item),
          "isDefaultConfiguration" : getIsRelayAsDefaultConfiguration(item),
          "ip" : getRelayIp(item),
          "port" : getRelayPort(item),
          "ipV6" : getRelayIpV6(item),
          "flags" : getRelayFlags(item),
          "bandWidth" : getRelayBandWidth(item)
        }
      );
    }
    return modifiedData;

  }

}

class NsWithId extends TorInfoFetcher {
  static NsWithId? _instance;

  factory NsWithId() {
    _instance ??= NsWithId._internal();
    return _instance!;
  }

  NsWithId._internal();
  
  Future<Map?> getValue(String fingerprint) async {
    await sendMessage("getinfo ns/id/$fingerprint");
    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null){
      return null;
    }

    LineSplitter ls = new LineSplitter();
    List<String> lines = ls.convert(lastMessage);

    List<String> filteredMessages = lines.where((line) => !line.startsWith("250 OK")).toList();

    if (filteredMessages.length >0){
      filteredMessages.removeAt(filteredMessages.length-1);
    }

    String filteredMessage = filteredMessages.join(" ");
    RegExp regex = RegExp(r"250\+ns/id/[\S]+=([\s\S]+)");
    Match? match = regex.firstMatch(filteredMessage);

    if (match == null){
      return null;
    }

    String data = match.group(1)!;
    
    return _modifyData(data);
  }

  Map _modifyData(String data){

    String? _extractInformation(String data , String pattern){
      if (!_isConnected){
        return null;
      }
      RegExp regex = RegExp(pattern);
      Match? match = regex.firstMatch(data);
      if (match != null){
        return match.group(1)!;
      }
      return null;
    }
    
    String? getRelayName(String data) {
      String pattern = r"r ([\S]+)";
      String? value = _extractInformation(data , pattern);
      return value;
    }

    String? getRelayFingerprint(String data) {
      String pattern = r"r [\S]+ ([\S]+ [\S]+)";
      String? value = _extractInformation(data , pattern);
      return value;
    }

    DateTime? getRelayPublicationTime(String data) {
      String pattern = r"r [\S]+ [\S]+ [\S]+ ([\S]+ [\S]+)";
      String? value = _extractInformation(data , pattern);
      return DateTime.tryParse(value!);
    }

    String? getRelayIp(String data){
      String pattern = r"r [\S]+ [\S]+ [\S]+ [\S]+ [\S]+ ([\S]+)";
      String? value = _extractInformation(data , pattern);
      return value;
    } 

    int? getRelayPort(String data){
      String pattern = r"r [\S]+ [\S]+ [\S]+ [\S]+ [\S]+ [\S]+ ([\S]+)";
      String? value = _extractInformation(data , pattern);
      int? result = int.tryParse(value!);
      return result;
    }

    bool? getIsRelayAsDefaultConfiguration(String data){
      String pattern = r"r [\S]+ [\S]+ [\S]+ [\S]+ [\S]+ [\S]+ [\S]+ (\d+)";
      String? value = _extractInformation(data , pattern);
      bool result = value == "0" ? false : true;
      return result;
    }

    String? getRelayIpV6(String data){
      String pattern = r"a (\S+)";
      String? value = _extractInformation(data , pattern);
      return value;
    }

    List<String>? getRelayFlags(String data){
      String pattern = r"s ([\S\s]+) w ";
      String? value = _extractInformation(data , pattern);
      List<String> result = value!.split(" ");
      return result;
    }

    int? getRelayBandWidth(String data){
      String pattern = r"Bandwidth=(\d+)";
      String? value = _extractInformation(data , pattern);
      int? result = int.tryParse(value!);
      return result;
    }

    Map modifiedData = {
      "name" : getRelayName(data),
      "fingerprint" : getRelayFingerprint(data),
      "publicationTime" : getRelayPublicationTime(data),
      "isDefaultConfiguration" : getIsRelayAsDefaultConfiguration(data),
      "ip" : getRelayIp(data),
      "port" : getRelayPort(data),
      "ipV6" : getRelayIpV6(data),
      "flags" : getRelayFlags(data),
      "bandWidth" : getRelayBandWidth(data)
    };

    return modifiedData;
  }

}

class NsWithName extends TorInfoFetcher {
  static NsWithName? _instance;

  factory NsWithName() {
    _instance ??= NsWithName._internal();
    return _instance!;
  }

  NsWithName._internal();
  
  Future<Map?> getValue(String name) async {
    await sendMessage("getinfo ns/name/$name");
    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null){
      return null;
    }

    LineSplitter ls = new LineSplitter();
    List<String> lines = ls.convert(lastMessage);

    List<String> filteredMessages = lines.where((line) => !line.startsWith("250 OK")).toList();

    if (filteredMessages.length >0){
      filteredMessages.removeAt(filteredMessages.length-1);
    }

    String filteredMessage = filteredMessages.join(" ");
    RegExp regex = RegExp(r"250\+ns/name/[\S]+=([\s\S]+)");
    Match? match = regex.firstMatch(filteredMessage);

    if (match == null){
      return null;
    }

    String data = match.group(1)!;
    
    return _modifyData(data);
  }

  Map _modifyData(String data){

    String? _extractInformation(String data , String pattern){
      if (!_isConnected){
        return null;
      }
      RegExp regex = RegExp(pattern);
      Match? match = regex.firstMatch(data);
      if (match != null){
        return match.group(1)!;
      }
      return null;
    }
    
    String? getRelayName(String data) {
      String pattern = r"r ([\S]+)";
      String? value = _extractInformation(data , pattern);
      return value;
    }

    String? getRelayFingerprint(String data) {
      String pattern = r"r [\S]+ ([\S]+ [\S]+)";
      String? value = _extractInformation(data , pattern);
      return value;
    }

    DateTime? getRelayPublicationTime(String data) {
      String pattern = r"r [\S]+ [\S]+ [\S]+ ([\S]+ [\S]+)";
      String? value = _extractInformation(data , pattern);
      return DateTime.tryParse(value!);
    }

    String? getRelayIp(String data){
      String pattern = r"r [\S]+ [\S]+ [\S]+ [\S]+ [\S]+ ([\S]+)";
      String? value = _extractInformation(data , pattern);
      return value;
    } 

    int? getRelayPort(String data){
      String pattern = r"r [\S]+ [\S]+ [\S]+ [\S]+ [\S]+ [\S]+ ([\S]+)";
      String? value = _extractInformation(data , pattern);
      int? result = int.tryParse(value!);
      return result;
    }

    bool? getIsRelayAsDefaultConfiguration(String data){
      String pattern = r"r [\S]+ [\S]+ [\S]+ [\S]+ [\S]+ [\S]+ [\S]+ (\d+)";
      String? value = _extractInformation(data , pattern);
      bool result = value == "0" ? false : true;
      return result;
    }

    String? getRelayIpV6(String data){
      String pattern = r"a (\S+)";
      String? value = _extractInformation(data , pattern);
      return value;
    }

    List<String>? getRelayFlags(String data){
      String pattern = r"s ([\S\s]+) w ";
      String? value = _extractInformation(data , pattern);
      List<String> result = value!.split(" ");
      return result;
    }

    int? getRelayBandWidth(String data){
      String pattern = r"Bandwidth=(\d+)";
      String? value = _extractInformation(data , pattern);
      int? result = int.tryParse(value!);
      return result;
    }

    Map modifiedData = {
      "name" : getRelayName(data),
      "fingerprint" : getRelayFingerprint(data),
      "publicationTime" : getRelayPublicationTime(data),
      "isDefaultConfiguration" : getIsRelayAsDefaultConfiguration(data),
      "ip" : getRelayIp(data),
      "port" : getRelayPort(data),
      "ipV6" : getRelayIpV6(data),
      "flags" : getRelayFlags(data),
      "bandWidth" : getRelayBandWidth(data)
    };

    return modifiedData;
  }

}

class EntryGuards extends TorInfoFetcher {
  static EntryGuards? _instance;

  factory EntryGuards() {
    _instance ??= EntryGuards._internal();
    return _instance!;
  }

  EntryGuards._internal();

  Future<List<Map>> getValue() async{

    await sendMessage("getinfo entry-guards");
    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null){
      return [];
    }

    RegExp regex = RegExp(r"250\+entry-guards=([\s\S]*)");
    Match? match = regex.firstMatch(lastMessage);
    String spacificMessage = "";

    if (match == null){
      return [];
    }

    spacificMessage = match.group(1)!.trim();

    LineSplitter ls = new LineSplitter();
    List<String> lines = ls.convert(spacificMessage);

    List<String> filteredMessages = lines.where((line) => !line.startsWith("250 OK")).toList();

    if (filteredMessages.length >0){
      filteredMessages.removeAt(filteredMessages.length-1);
    }

    return _dataAnalysis(filteredMessages);

  }

  List<Map> _dataAnalysis(List<String> data){
    if (!_isConnected){
      return [];
    }
    List<Map> analyzedData = [];

    for (final item in data){
      List<String> ListedInfo = item.split(" ");
      List<String> NameAndIdInfo = ListedInfo[0].split("~");

      // because response is something like this we need to split it twice
      // $6315278A91710062D90B288199EFA06E4AAA9E8F~unnamed314 up
      String fingerprint = NameAndIdInfo[0];
      String? name = NameAndIdInfo.length > 1 ? NameAndIdInfo[1] : null;
      String status = ListedInfo[1];
      Map mappedData = {
        "fingerprint" : fingerprint.substring(1),
        "name" : name,
        "status" : status,
      };

      analyzedData.add(mappedData);
    }
    return analyzedData;
  }

}

class ExtendCircuit extends TorInfoFetcher {
  static ExtendCircuit? _instance;

  factory ExtendCircuit() {
    _instance ??= ExtendCircuit._internal();
    return _instance!;
  }

  ExtendCircuit._internal();

  Future<Map> manuallyExtend(String circuitId , String relay1, String relay2 ,String relay3) async {
    if (!_isConnected){
      return {"status" : false , "message" : "not connected to the tor"};
    }
    await sendMessage("extendcircuit $circuitId $relay1 ,$relay2 ,$relay3");
    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null){
      return {"status" : false , "message" : "could not find correct response from server"};
    }

    List<String> splitedMessage = lastMessage.split(" ");
    String responseCode = splitedMessage[0];
    bool status = responseCode == "250" ? true : false;
    String response = splitedMessage.sublist(1).join(" ");
    return {"status" : status , "message" : response};
  }

  Future<Map> autoExtend({String purpose = "general"}) async{
    if (!_isConnected){
      return {"status" : false , "message" : "not connected to the tor"};
    }
    await sendMessage("extendcircuit 0 purpose=$purpose");
    
    String? lastMessage = _messages.lastOrNull ;

    if (lastMessage == null){
      return {"status" : false , "message" : "could not find correct response from server"};
    }

    List<String> splitedMessage = lastMessage.split(" ");
    String responseCode = splitedMessage[0];
    bool status = responseCode == "250" ? true : false;
    String response = splitedMessage.sublist(1).join(" ");
    return {"status" : status , "message" : response};
  }
}

class CloseCircuit extends TorInfoFetcher {
  static CloseCircuit? _instance;

  factory CloseCircuit() {
    _instance ??= CloseCircuit._internal();
    return _instance!;
  }

  CloseCircuit._internal();

  Future<Map> closeImmediately(String circuitId) async {
    if (!_isConnected){
      return {"status" : false , "message" : "not connected to the tor"};
    }
    await sendMessage("closecircuit $circuitId");
    
    String? lastMessage = _messages.lastOrNull ;
    
    if (lastMessage == null){
      return {"status" : false , "message" : "could not find correct response from server"};
    }

    RegExp regex = RegExp(r"(\d+) (.*)");
    Match? match = regex.firstMatch(lastMessage);
    
    if (match == null) {
      return {"status" : false , "message" : "could not find correct response from server"};
    }

    String responseCode = match.group(1)!;
    bool status = responseCode == "250" ? true : false;
    String message = match.group(2)!;
    return {"status" : status , "message" : message};

  }

  Future<Map> closeIfUnused(String circuitId) async {
    if (!_isConnected){
      return {"status" : false , "message" : "not connected to the tor"};
    }
    await sendMessage('closecircuit $circuitId IfUnused');
    
    String? lastMessage = _messages.lastOrNull ;
    
    if (lastMessage == null){
      return {"status" : false , "message" : "could not find correct response from server"};
    }

    RegExp regex = RegExp(r"(\d+) (.*)");
    Match? match = regex.firstMatch(lastMessage);
    
    if (match == null) {
      return {"status" : false , "message" : "could not find correct response from server"}; // No match found
    }

    String responseCode = match.group(1)!;
    bool status = responseCode == "250" ? true : false;
    String message = match.group(2)!;
    return {"status" : status , "message" : message};
  }

}


// creating manager class to control all classes and make easier to work with tor


class TorController {
  // Instantiate the classes you want to manage
  BandWidthEventHandler _bandWidthEventHandler = BandWidthEventHandler();
  LogEventHandler _logEventHandler = LogEventHandler();

  DirectConnectionWithTor _directConnectionWithTor = DirectConnectionWithTor();
  TrafficRead _trafficRead = TrafficRead();
  TrafficWritten _trafficWritten = TrafficWritten();
  Uptime _uptime = Uptime();
  ProcessPid _processPid = ProcessPid();
  ProcessUid _processUid = ProcessUid();
  BootstrapPhase _bootstrapPhase = BootstrapPhase();
  IpToCountry _ipToCountry = IpToCountry();
  ConsensusValidAfter _consensusValidAfter = ConsensusValidAfter();
  ConsensusValidUntil _consensusValidUntil = ConsensusValidUntil();
  ConsensusFreshUntil _consensusFreshUntil = ConsensusFreshUntil();
  EventNames _eventNames = EventNames();
  GetConf _getConf = GetConf();
  SetConf _setConf = SetConf();
  ResetConf _resetConf = ResetConf();
  ConfigText _configText = ConfigText();
  ConfigDefaults _configDefaults = ConfigDefaults();
  ProtocolInfo _protocolInfo = ProtocolInfo();
  TorVersion _torVersion = TorVersion();
  NetListeners _netListeners = NetListeners();
  StreamStatus _streamStatus = StreamStatus();
  OrconnStatus _orconnStatus = OrconnStatus();
  CircuitStatus _circuitStatus = CircuitStatus();
  NsAll _nsAll = NsAll();
  NsWithId _nsWithId = NsWithId();
  NsWithName _nsWithName = NsWithName();
  EntryGuards _entryGuards = EntryGuards();
  ExtendCircuit _extendCircuit = ExtendCircuit();
  CloseCircuit _closeCircuit = CloseCircuit();

  List<dynamic> _controlHandlers = [];

  TorController(){  
    _controlHandlers = [
      _bandWidthEventHandler,_logEventHandler,_trafficRead,_trafficWritten,_uptime,_processPid,_processUid,_bootstrapPhase,
      _ipToCountry,_consensusValidAfter,_consensusValidUntil,_consensusFreshUntil,
      _eventNames,_getConf,_setConf,_resetConf,_configText,_configDefaults,_protocolInfo,_torVersion,_netListeners,
      _streamStatus,_orconnStatus,_circuitStatus, _nsAll, _nsWithId, _nsWithName, _entryGuards, _extendCircuit, _closeCircuit,
      _directConnectionWithTor,
    ];
  }

  // Connect to Tor
  Future<Map> connectToTor({String ip = '127.0.0.1', int port = 9051}) async {
    try{

      for (dynamic item in _controlHandlers){
        await item.connect(ip:ip, port:port);
      }
      
      return {
        "status" : true,
        "message" : "Connected to tor successfully :)",
      };
    }
    catch (error){
      return {
        "status" : false,
        "message" : " error message : $error can't connect to tor in this address : $ip:$port",
      };
    }
  }

  // Connect to Tor
  Future<Map> authenticate({String password = ""}) async {
    try{

      for (dynamic item in _controlHandlers){
        await item.authenticate(password);
      }
      // If the connection was not closed
      if (getConnectionStatus()){
        return {
          "status" : true,
          "message" : "Authentication successfull :)",
        };
      }
      return {
        "status" : false,
        "message" : "password error ; can not connect to the control port with this password.",
      };
    }
    catch (error){
      return {
        "status" : false,
        "message" : error,
      };
    }
  }

  // Disconnect from Tor
  Map disconnectFromTor() {
    try{
      
      for (dynamic item in _controlHandlers){
        item.disconnect();
      }
      
      return {
        "status" : true,
        "message" : "Disconnected from tor successfully",
      };
    }
    catch (error) {
      return {
          "status" : false,
          "message" : error,
      };
    }
  }

  bool getConnectionStatus(){
    return !_controlHandlers.any((item) => item.getStatus() == false);
  }

  void startBwEvent(){
    _bandWidthEventHandler.startEvent();
  }

  void stopBwEvent(){
    _bandWidthEventHandler.stopEvent();
  }

  void startLogs({List<String>? events }) {
    _logEventHandler.startEvent(events : events);
  }

  void stopLogs(){
    _logEventHandler.stopEvent();
  }

  List<Map> getBandwidthInfo({int? filterBy}) {
    return _bandWidthEventHandler.GetBwList(filterBy : filterBy);
  }

  List<Map> getLogs({int? filterBy}) {
    return _logEventHandler.getLogs(filterBy : filterBy);
  }

  Future<void> sendDirectMessage(String message) async{
    await _directConnectionWithTor.sendMessage(message);
  }

  List getDirectMessages({int? filterBy}){
    return _directConnectionWithTor.getAllMessages(filterBy:filterBy);
  }

  Future<int> getTrafficRead() async {
    return await _trafficRead.getValue();
  }

  Future<int> getTrafficWritten() async {
    return await _trafficWritten.getValue();
  }

  Future<int> getUptime() async {
    return await _uptime.getValue();
  }

  Future<int> getProcessPid() async {
    return await _processPid.getValue();
  }

  Future<int> getProcessUid() async {
    return await _processUid.getValue();
  }

  Future<Map> getBootstrapPhase() async {
    return await _bootstrapPhase.getValue();
  }

  Future<String?> getCountryFromIp(String ip) async {
    return await _ipToCountry.getValue(ip);
  }

  Future<DateTime?> getConsensusValidAfter() async{
    return await _consensusValidAfter.getValue();
  }

  Future<DateTime?> getConsensusValidUntil() async {
    return await _consensusValidUntil.getValue();
  }

  Future<DateTime?> getConsensusFreshUntil() async {
    return await _consensusFreshUntil.getValue();
  }

  Future<List<String>> getEventNames() async {
    return await _eventNames.getValue();
  }

  Future<String?> getConfig(String configName) async {
    return await _getConf.getValue(configName);
  }

  Future<Map> setConfig(String configName , String configValue) async{
    return await _setConf.setConfig(configName , configValue);
  }

  Future<Map> resetConfig(String configName) async {
    return await _resetConf.resetConfig(configName);
  }

  Future<Map> getConfigText() async {
    return await _configText.getValue();
  }

  Future<Map> getDefaultConfigs() async {
    return await _configDefaults.getValue();
  }

  Future<Map?> getProtocolInfo() async {
    return await _protocolInfo.getValue();
  }

  Future<Map> getVersionInfo() async {
    return await _torVersion.getValue();
  }

  Future<Map> getNetListeners() async {
    return await _netListeners.getValue();
  }

  Future<List<Map>> getStreamStatus() async {
    List<Map> streamInfo = await _streamStatus.getValue();
    List<Map> circuitInfo = await _circuitStatus.getValue();

    streamInfo.forEach((element) {
      String id = element["circuitId"];
      Map info = circuitInfo.firstWhere((circuitElement) => circuitElement["circuitId"] == id, orElse: () => {});
      element['circuitInfo'] = info;
    });

    return streamInfo;
  }

  Future<List<Map>> getOrConnectionStatus() async {
    return await _orconnStatus.getValue();
  }

  Future<List<Map>> getCircuitStatus() async {
    return await _circuitStatus.getValue();
  }

  Future<List<Map>> getAllRouterInfo() async {
    return await _nsAll.getValue();
  }

  Future<Map?> getRouterInfoByfingerPring(String fingerPring) async {
    return await _nsWithId.getValue(fingerPring);
  }

  Future<Map?> getRouterInfoByName(String name) async {
    return await _nsWithName.getValue(name);
  }

  Future<List<Map>> getEntryGuards() async {
    return await _entryGuards.getValue();
  }

  Future<Map> manuallyExtendCircuit(String circuitId , String relay1, String relay2 ,String relay3) async {
    return await _extendCircuit.manuallyExtend(circuitId, relay1, relay2, relay3);
  }

  Future<Map> autoExtendCircuit(String purpose) async { 
    return await _extendCircuit.autoExtend(purpose : purpose);
  }

  Future<Map> closeCircuitImmediately(String circuitId) async {
    return await _closeCircuit.closeImmediately(circuitId);
  }

  Future<Map> closeCircuitIfUnused(String circuitId) async {
    return await _closeCircuit.closeIfUnused(circuitId);
  }

}


// main example function


void main() async {
  TorController bwSocket = TorController();
  Map info = await bwSocket.connectToTor(ip: "127.0.0.1" , port: 9051);
  await bwSocket.authenticate(password:"");

  if (info["status"] == true){
    bwSocket.startLogs(events : ["info"]);
    Timer.periodic(Duration(seconds: 2), (Timer timer) async {
      final bwInfo = await bwSocket.getCircuitStatus();
      print("bw info : $bwInfo");
    });
  }

}