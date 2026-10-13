import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/home_journey/global_search_screen.dart';
import 'package:study_birds/screens/universities_programs_countries/countries_scholarships_screens.dart';
void main(){
 tearDown(() {AuthSession.instance.currentUser=null;AuthSession.instance.token=null;});
 testWidgets('search failure is an error with retry, not an empty result',(tester)async{
  await http.runWithClient(()async{await tester.pumpWidget(const MaterialApp(home:GlobalSearchScreen()));await tester.pumpAndSettle();expect(find.textContaining('تعذر تحميل بيانات البحث'),findsOneWidget);expect(find.text('إعادة المحاولة'),findsOneWidget);expect(find.text('لا توجد نتائج'),findsNothing);},()=>MockClient((_)async=>http.Response('{}',503)));
 });
 testWidgets('scholarships load real data and submit an application only after confirmation',(tester)async{
  AuthSession.instance.currentUser=const AuthUser(id:'student',name:'Student',email:'test@example.test',role:UserRole.student);AuthSession.instance.token='test';
  var applied=false;
  await http.runWithClient(()async{
   await tester.pumpWidget(const MaterialApp(home:ScholarshipsScreen()));await tester.pumpAndSettle();
   expect(find.text('Real scholarship'),findsOneWidget);expect(find.text('منحة التميز الهندسي'),findsNothing);
   await tester.tap(find.text('تقديم الطلب'));await tester.pumpAndSettle();expect(applied,false);
   await tester.tap(find.text('إرسال الطلب'));await tester.pumpAndSettle();expect(applied,true);expect(find.text('تم تقديم الطلب'),findsOneWidget);
  },()=>MockClient((request)async{
   if(request.method=='POST'){expect(request.url.path.endsWith('/s1/apply'),true);applied=true;return http.Response('{}',200);}
   if(request.url.path.endsWith('/mine'))return http.Response(jsonEncode(applied?[{'scholarship':{'_id':'s1','title':'Real scholarship'},'status':'submitted'}]:[]),200);
   return http.Response(jsonEncode([{'_id':'s1','title':'Real scholarship','eligibility':'Actual requirements'}]),200);
  }));
 });
}
