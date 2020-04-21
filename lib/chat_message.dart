import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mlkit/mlkit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_recognition/speech_recognition.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'mlkit/ml_detail.dart';

class ChatMessage extends StatefulWidget{
  var documentId = "";
  var user1;
  var homeUser;

  ChatMessage({Key key, this.user1, this.homeUser}): super(key: key);
  @override
  State createState() => new ChatMessageState(user1, homeUser);
}

class ChatMessageState extends State<ChatMessage>{
  var user1;
  var homeUser;
  var documentId = "";

  SpeechRecognition _speech;
  bool _speechRecognitionAvailable = false;
  bool _isListening = false;
  String transcription = '';

  final TextEditingController _textController = new TextEditingController();
  
  static const String CAMERA_SOURCE = 'CAMERA_SOURCE';
  static const String GALLERY_SOURCE = 'GALLERY_SOURCE';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  ChatMessageState(String user1, String homeUser){
    this.user1 = user1;
    this.homeUser = homeUser;
    if (homeUser.compareTo(user1)>=0){
      documentId = user1+homeUser; 
    }
    else if (user1.compareTo(homeUser)>0){
      documentId = homeUser+user1;
    }
  }
  @override
  void initState() {
    super.initState();
    activateSpeechRecognizer();
    requestPermission();
  }

  void activateSpeechRecognizer() {
    _speech = new SpeechRecognition();
    _speech.setAvailabilityHandler(onSpeechAvailability);
    _speech.setCurrentLocaleHandler(onCurrentLocale);
    _speech.setRecognitionStartedHandler(onRecognitionStarted);
    _speech.setRecognitionResultHandler(onRecognitionResult);
    _speech.setRecognitionCompleteHandler(onRecognitionComplete);
    _speech
        .activate()
        .then((res) {
          setState(() => _speechRecognitionAvailable = res);
        });
  }

  void start() => _speech
      .listen(locale: 'en_US')
      .then((result) => print('Started listening => result $result'));

  void cancel() =>
      _speech.cancel().then((result) => setState(() => _isListening = result));

  void stop() => _speech.stop().then((result) {
        setState(() => _isListening = result);
      });

  void onSpeechAvailability(bool result) =>
      setState(() => _speechRecognitionAvailable = result);

  void onCurrentLocale(String locale) =>
      setState(() => print("current locale: $locale"));

  void onRecognitionStarted() => setState(() => _isListening = true);

  void onRecognitionResult(String text) {
    setState(() {
      transcription = text;
      print("result is"+text);
      stop(); //stop listening now
    });
  }

  void onRecognitionComplete() {
    setState(() => _isListening = false);
    _textController.text = transcription;
  }

  void requestPermission() async {
    PermissionStatus permission = await PermissionHandler()
        .checkPermissionStatus(PermissionGroup.microphone);

    if (permission != PermissionStatus.granted) {
      await PermissionHandler()
          .requestPermissions([PermissionGroup.microphone]);
    }
  }

  void onPickImageSelected(String source) async {
    var imageSource;
    if (source == CAMERA_SOURCE) {
      imageSource = ImageSource.camera;
    } else {
      imageSource = ImageSource.gallery;
    }

    final scaffold = _scaffoldKey.currentState;

    try {
      final file = await ImagePicker.pickImage(source: imageSource);
      if (file == null) {
        
      }

      Navigator.push(
        context,
        new MaterialPageRoute(
          builder: (context) => MLDetail(file, user1, homeUser),
        ),
      );
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }

  void sendMessage(text) {
    if (text != null && text != "") {
      setState(() {
        Firestore.instance.collection('chat_message').document(documentId).collection('messages').add({
          'msg': text,
          'recevier': user1,
          'sender': homeUser,
          'time': new DateTime.now()
        });
      });
    }
  }

  void _handleSubmitted(String text){
    _textController.clear();
    sendMessage(text);
  }
  @override
  Widget build(BuildContext context){
    return new Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(user1),
        actions: <Widget>[
          _buildVoiceInput(
            onPressed: _speechRecognitionAvailable && !_isListening
                ? () => start()
                : () => stop(),
            label: _isListening ? 'Listening...' : '',
          ),
        ],
      ),
      body: StreamBuilder(
        stream: Firestore.instance.collection('chat_message').document(documentId).collection('messages').orderBy('time', descending: false).snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.data.documents.isEmpty){
            Firestore.instance.collection('chat_message').document(documentId).setData({
              'msg': 'Hello user',
            });
            Firestore.instance.collection('chat_message').document(documentId).collection('messages').add({
              'msg': ' ',
              'recevier': user1,
              'sender': homeUser,
              'time': new DateTime.now()
            });
          }
          return Container(
            padding: EdgeInsets.all(10.0),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: FirestoreListView(documents: snapshot.data.documents, homeUser: homeUser),
                ),
                Row(children: <Widget>[
                  new Flexible(
                    child: new TextField(
                      decoration: new InputDecoration.collapsed(hintText: "Send a message",),
                      controller: _textController,
                      onSubmitted: _handleSubmitted,
                    ),
                  ),
                  new Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Row(
                      children: <Widget>[
                        new IconButton(
                          icon: new Icon(Icons.send),
                          onPressed: () => _handleSubmitted(_textController.text),
                        ),
                        PopupMenuButton<String>(
                          color: Colors.indigo[50],
                          itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: "camera",
                                  child: new IconButton(
                                    icon: new Icon(Icons.camera), 
                                    onPressed: () {
                                      onPickImageSelected(CAMERA_SOURCE);
                                    },
                                  ),
                                ),
                                PopupMenuItem(
                                  value: "gallery",
                                  child: new IconButton(
                                    icon: new Icon(Icons.image), 
                                    onPressed: () {
                                      onPickImageSelected(GALLERY_SOURCE);
                                    },
                                  ),
                                ),
                              ],
                        ),
                      ],
                    ),
                  )
                ],)
              ],
            ),
          );
        },
      ),
    );
    
  }

  Widget _buildVoiceInput({String label, VoidCallback onPressed}) =>
    new Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: Colors.white),
          ),
          IconButton(
            icon: Icon(Icons.mic),
            onPressed: onPressed,
          ),
        ],
      )
    );
}

class FirestoreListView extends StatelessWidget {
  final homeUser;
  final List<DocumentSnapshot> documents;
  FirestoreListView({this.documents, this.homeUser}); 
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: documents.length,
      itemBuilder: (BuildContext context, int index) {
        String msg = documents[index].data['msg'].toString();
        String time = documents[index].data['time'].toDate().toString();
        String sender = documents[index].data['sender'].toString();
        if (msg == " " || msg == null)
        {
          return SizedBox.shrink();
        } 
        return ListTile(
          title: Container(
            padding: const EdgeInsets.all(5.0),
            child: Wrap(
              children: <Widget>[
                Align(
                  alignment: sender == homeUser?Alignment.centerRight:Alignment.centerLeft,
                  child: SizedBox(
                    width: 250.0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: sender == homeUser?Colors.blue[100]:Colors.grey[300],
                        border: Border.all(color: sender == homeUser?Colors.blue[300]:Colors.grey[500],),
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: new Tooltip(
                        message: time, 
                        child: new Text(
                          msg,
                          style: TextStyle(fontSize: 21.0,),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox.shrink(),
              ],
            ),
          ),
        );
      },
    );
  }
}
