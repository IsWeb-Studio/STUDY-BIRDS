import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/services_support/messaging_and_emergency_screens.dart';

void main(){
  setUp(()=>AuthSession.instance.token='synthetic-support-chat');
  tearDown(()=>AuthSession.instance.token=null);
  for(final empty in [false,true]){
    testWidgets('urgent support opens assigned team only (empty=$empty)',(tester)async{
      var scoped=false;
      await http.runWithClient(()async{
        await tester.pumpWidget(const MaterialApp(home:EmergencySupportScreen()));
        final button=find.text('فتح المحادثة الداخلية');
        await tester.scrollUntilVisible(button,300,scrollable:find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(button);await tester.pumpAndSettle();
        expect(tester.widget<ConversationThreadScreen>(find.byType(ConversationThreadScreen)).supportTeamOnly,isTrue);
        expect(scoped,isTrue);
        if(empty){expect(find.textContaining('لم يتم تعيين فريق دعم'),findsOneWidget);}
        else{expect(find.text('Assigned support'),findsOneWidget);}
        expect(tester.takeException(),isNull);
        await tester.pumpWidget(const SizedBox());
      },()=>MockClient((request)async{
        expect(request.url.path.endsWith('/contacts'),isTrue);
        expect(request.url.queryParameters['supportTeam'],'true');scoped=true;
        return http.Response(jsonEncode(empty?[]:[{'_id':'staff','name':'Assigned support','role':'employee'}]),200,
          headers:{'content-type':'application/json; charset=utf-8'});
      }));
    });
  }
}
