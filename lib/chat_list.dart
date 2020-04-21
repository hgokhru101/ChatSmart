import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mcan/chat_message.dart';

class ChatList extends StatefulWidget{
  final String username;
  final auth;
  ChatList({Key key, this.auth, this.username}): super(key: key);
  @override
  State createState() => new ChatListState(auth, username);
}

class ChatListState extends State<ChatList>{
  String username;
  final auth;
  ChatListState(this.auth, this.username){
    auth.currentUser().then((userId) {
      setState(() {
        this.username = userId;
        print(this.username);
      });
    });
  }
  @override
  Widget build(BuildContext context){
    return new Scaffold(
      body: Center(
        child: StreamBuilder(
          stream: Firestore.instance.collection('connected').orderBy('user', descending: false).snapshots(),
          builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (!snapshot.hasData) return CircularProgressIndicator();
            return FirestoreListView(documents: snapshot.data.documents, homeUser: username,);
          },
        ),
      ),
    );
  }
}

class FirestoreListView extends StatelessWidget {
  final List<DocumentSnapshot> documents;
  final homeUser;
  FirestoreListView({this.documents, this.homeUser}); 
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: documents.length,
      itemExtent: 90.0,
      itemBuilder: (BuildContext context, int index) {
        /*if (documents[index].data['user'].toString()==homeUser){
          return SizedBox.shrink();
        }*/
        String user1 = documents[index].data['user'].toString();
        return ListTile(
          title: Container(
            decoration: BoxDecoration( //                    <-- BoxDecoration
              border: Border(top: BorderSide(), bottom: BorderSide(),),
            ),
            padding: const EdgeInsets.all(0.0),
            child: Flex(
              direction: Axis.horizontal,
              children: [
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          height: 40,
                          child: FlatButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ChatMessage(user1: user1, homeUser: homeUser)),
                              );
                            }, 
                            child: Text(
                              user1,
                              style: TextStyle(fontSize: 22,),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                ),
              ], 
            ),
          ),
        );
      },
    );
  }
}
