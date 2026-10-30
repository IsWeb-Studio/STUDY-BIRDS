import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/core/services/response_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  DeviceResponseCache store() => DeviceResponseCache(directoryProvider: () async => directory);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('covey-cache-test-');
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() async { await directory.delete(recursive:true); });

  test('a new store instance reads public content from actual device files', () async {
    final at=DateTime.utc(2026,10,30);
    await store().write('public','/universities?country=one',CachedResponse([{'name':'Saved'}],at));
    final read=await store().read('public','/universities?country=one');
    expect(read!.data[0]['name'],'Saved'); expect(read.savedAt,at);
    expect(await store().read('public','/universities?country=other'),isNull);
  });

  test('private data uses the encrypted-store backend, not public JSON files', () async {
    await store().write('alice','/students/overview',CachedResponse({'student':'Alice'},DateTime.now()));
    expect(await directory.list().toList(),isEmpty);
    expect((await store().read('alice','/students/overview'))!.data['student'],'Alice');
    expect(await store().read('bob','/students/overview'),isNull);
    await store().clearPrivate();
    expect(await store().read('alice','/students/overview'),isNull);
  });

  test('resource invalidation and corrupted files do not break other cached pages', () async {
    final cache=store(),at=DateTime.now();
    await cache.write('public','/universities',CachedResponse([1],at));
    await cache.write('public','/programs',CachedResponse([2],at));
    await cache.invalidate('public',(key)=>key=='/universities');
    expect(await cache.read('public','/universities'),isNull);
    expect((await cache.read('public','/programs'))!.data,[2]);
    final file=(await directory.list().toList()).whereType<File>().single;
    await file.writeAsString('interrupted write');
    expect(await store().read('public','/programs'),isNull);
  });

  test('logout cleanup wins over a previously queued private write', () async {
    final cache=store();
    final pending=cache.write('alice','/students/overview',CachedResponse({'secret':true},DateTime.now()));
    final clear=cache.clearPrivate();
    await pending; await clear;
    expect(await store().read('alice','/students/overview'),isNull);
  });

  test('oversized records cannot exhaust the private cache', () async {
    await store().write('alice','large',CachedResponse('x'* (130*1024),DateTime.now()));
    expect(await store().read('alice','large'),isNull);
  });
}
