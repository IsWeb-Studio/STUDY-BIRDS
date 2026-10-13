import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/screens/services_support/services_consultation_screens.dart';
import '../test/catalog_filters_test.dart' show mount,preview;
void main(){
 setUpAll(()async{final font=FontLoader('Tajawal')..addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));await font.load();final icons=FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));await icons.load();});
 testWidgets('services reference preview and card navigation',(tester)async{
  await http.runWithClient(()async{
   await mount(tester,const ServicesCenterScreen());
   tester.view.physicalSize=const Size(348,706);await tester.pumpAndSettle();
   await preview(tester,'services-reference');
   expect(tester.takeException(),isNull);
   await tester.tap(find.text('الترجمة'));await tester.pumpAndSettle();
   expect(find.byType(ServiceDetailScreen),findsOneWidget);
   expect(find.text('وصف الخدمة من السيرفر'),findsOneWidget);
   expect(tester.takeException(),isNull);
  },()=>MockClient((_)async=>http.Response(jsonEncode([for(final title in ['الترجمة','التصديق','التأمين','استقبال المطار','شريحة الاتصال','المساعدة البنكية','مساعدة الإقامة']){'title':title,'detailBody':'وصف الخدمة من السيرفر'}]),200,headers:{'content-type':'application/json; charset=utf-8'})));
 });
}
