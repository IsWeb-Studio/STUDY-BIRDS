import 'package:study_birds/core/services/auth_session.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/screens/home_journey/home_dashboard_screen.dart';
import 'package:study_birds/screens/universities_programs_countries/explore_hub_screen.dart';
import '../test/catalog_filters_test.dart' show mount,preview;
void main(){
 setUpAll(()async{for(final entry in {'Tajawal':'assets/fonts/Tajawal-Regular.ttf','MaterialIcons':'fonts/MaterialIcons-Regular.otf'}.entries){await (FontLoader(entry.key)..addFont(rootBundle.load(entry.value))).load();}});
 testWidgets('shared theme home and exploration previews',(tester)async{
  AuthSession.instance.token='preview';
  addTearDown(()=>AuthSession.instance.token=null);
  await http.runWithClient(()async {
   await mount(tester,const HomeDashboardScreen());expect(find.textContaining('تعذر تحميل'),findsNothing);await preview(tester,'theme-home');expect(tester.takeException(),isNull);
   await mount(tester,const ExploreHubScreen());await preview(tester,'theme-explore');expect(tester.takeException(),isNull);
  },()=>MockClient((_)async=>http.Response(jsonEncode({'profile':{'journeyStage':'applying'},'stats':{'currentApplications':2},'progress':{'currentStage':'applying','stages':[]}}),200)));
 });
}
