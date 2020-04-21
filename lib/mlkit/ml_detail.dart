import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mcan/chat_message.dart';
import 'dart:io';
import 'dart:async';
import 'package:mlkit/mlkit.dart';

class MLDetail extends StatefulWidget {
  final File _file;
  String user1;
  String homeUser;
  MLDetail(this._file, this.user1, this.homeUser);

  @override
  State<StatefulWidget> createState() {
    return _MLDetailState(user1, homeUser);
  }
}

class _MLDetailState extends State<MLDetail> {
  FirebaseVisionTextDetector textDetector = FirebaseVisionTextDetector.instance;
  List<VisionText> _currentTextLabels = <VisionText>[];
  String user1;
  String homeUser;
  String documentId = "";
  Stream sub;
  StreamSubscription<dynamic> subscription;

  _MLDetailState(this.user1, this.homeUser){
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
    sub = new Stream.empty();
    subscription = sub.listen((_) => _getImageSize)..onDone(analyzeLabels);
  }

  void analyzeLabels() async {
    try {
      var currentLabels;
      currentLabels = await textDetector.detectFromPath(widget._file.path);
      if (this.mounted) {
        setState(() {
          _currentTextLabels = currentLabels;
        });
      }
    } catch (e) {
      print("MyEx: " + e.toString());
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    subscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Flex(
        direction: Axis.horizontal,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Card(
              child: Center(
                child: widget._file == null
                  ? Text('No Image')
                  : FutureBuilder<Size>(
                    future: _getImageSize(
                      Image.file(widget._file, fit: BoxFit.fitWidth)
                    ),
                    builder: (BuildContext context, AsyncSnapshot<Size> snapshot) {
                    if (snapshot.hasData) {
                      return Container(
                        foregroundDecoration: TextDetectDecoration(_currentTextLabels, snapshot.data),
                        child: Image.file(widget._file, fit: BoxFit.fitWidth)
                      );
                    } else {
                      return CircularProgressIndicator();
                    }
                  },
                ),
              ),
            ),
          ),
        ]
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentTextLabels.length != 0)
          {
            String msg = "";
            for(int i=0; i<_currentTextLabels.length; i++){
              msg += _currentTextLabels[i].text + '\n';
            }
            print(msg);
            setState(() {
              Firestore.instance.collection('chat_message').document(documentId).collection('messages').add({
                'msg': msg,
                'recevier': user1,
                'sender': homeUser,
                'time': new DateTime.now()
              });
            });
          }
          Navigator.push(
            context,
            new MaterialPageRoute(
              builder: (context) => ChatMessage(user1: user1, homeUser: homeUser,),
            ),
          );
        },
        child: Icon(Icons.check),
      ),
    );
  }

  Future<Size> _getImageSize(Image image) {
    Completer<Size> completer = Completer<Size>();
    image.image.resolve(ImageConfiguration()).addListener(
        ImageStreamListener((ImageInfo info, bool _) => completer.complete(
            Size(info.image.width.toDouble(), info.image.height.toDouble()))));
    return completer.future;
  }
}

/*
  This code uses the example from azihsoyn/flutter_mlkit
  https://github.com/azihsoyn/flutter_mlkit/blob/master/example/lib/main.dart
*/

class TextDetectDecoration extends Decoration {
  final Size _originalImageSize;
  final List<VisionText> _texts;
  TextDetectDecoration(List<VisionText> texts, Size originalImageSize)
      : _texts = texts,
        _originalImageSize = originalImageSize;

  @override
  BoxPainter createBoxPainter([VoidCallback onChanged]) {
    return _TextDetectPainter(_texts, _originalImageSize);
  }
}

class _TextDetectPainter extends BoxPainter {
  final List<VisionText> _texts;
  final Size _originalImageSize;
  _TextDetectPainter(texts, originalImageSize)
      : _texts = texts,
        _originalImageSize = originalImageSize;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final paint = Paint()
      ..strokeWidth = 2.0
      ..color = Colors.red
      ..style = PaintingStyle.stroke;

    final _heightRatio = _originalImageSize.height / configuration.size.height;
    final _widthRatio = _originalImageSize.width / configuration.size.width;
    for (var text in _texts) {
      final _rect = Rect.fromLTRB(
          offset.dx + text.rect.left / _widthRatio,
          offset.dy + text.rect.top / _heightRatio,
          offset.dx + text.rect.right / _widthRatio,
          offset.dy + text.rect.bottom / _heightRatio);
      canvas.drawRect(_rect, paint);
    }
    canvas.restore();
  }
}