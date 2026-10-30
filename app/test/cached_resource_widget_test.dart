import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/widgets/cached_resource.dart';
import 'persistent_response_cache_test.dart' show MemoryStore, jsonReply;

class CachedPage extends StatefulWidget {
  final ApiClient api;
  const CachedPage(this.api, {super.key});
  @override
  State<CachedPage> createState()=>_CachedPageState();
}
class _CachedPageState extends State<CachedPage> with CachedResource<CachedPage> {
  String? name;
  @override
  ApiClient get resourceCacheClient=>widget.api;
  @override
  Iterable<String> get cachedPaths=>const ['/universities'];
  @override
  void initState(){super.initState();reloadCachedResource();}
  @override
  Future<void> reloadCachedResource() async {
    final row=await widget.api.get('/universities/one');
    if(mounted)setState(()=>name=row['name'] as String);
  }
  @override
  Widget build(BuildContext context)=>Scaffold(body:Column(children:[
    if(name==null)const CircularProgressIndicator() else Text(name!),
    TextButton(onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>const Scaffold(body:Text('Other page')))),child:const Text('Next')),
  ]));
}

void main(){
  testWidgets('saved page paints before network and refreshes without another loading screen',(tester)async{
    var now=DateTime.utc(2026,10,30),calls=0;
    final pending=Completer<void>();
    final api=ApiClient.forTesting(MockClient((_)async{
      if(++calls==1)return jsonReply({'name':'Saved university'});
      await pending.future;return jsonReply({'name':'Updated university'});
    }),cacheStore:MemoryStore(),clock:()=>now);
    await api.get('/universities/one');now=now.add(const Duration(hours:1));
    await tester.pumpWidget(MaterialApp(home:CachedPage(api)));
    await tester.pump();
    expect(find.text('Saved university'),findsOneWidget);
    expect(find.byType(CircularProgressIndicator),findsNothing);
    pending.complete();await tester.pump();
    await tester.pump(const Duration(milliseconds:120));await tester.pump();
    expect(find.text('Updated university'),findsOneWidget);
    expect(find.byType(CircularProgressIndicator),findsNothing);
    expect(calls,2);
    await tester.pumpWidget(const SizedBox());
  });
}
