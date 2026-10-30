#requires -Version 5.1
<#
OWNER REVIEW AND MANUAL EXECUTION ONLY. Codex must not invoke this script.
Default: dry-run. -Execute additionally requires interactive confirmation.
No execution-policy changes, elevation, policy overrides, downloads or builds.
Requires existing Git and Windows/.NET. Stop other build tools yourself first.
Inventory is frozen from the previous no-deletion execution log, not rebaselined.
Do not edit the inventory to make a changed target pass. Obtain a new review.
#>
[CmdletBinding()]
param([switch]$Execute)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$env:GIT_OPTIONAL_LOCKS = '0'

$ExactPaths = @(
 'D:\work\studybirds_session_release\app\build\test_cache',
 'D:\work\studybirds_session_release\app\.dart_tool\flutter_build',
 'D:\work\studybirds_web\app\.dart_tool\flutter_build',
 'D:\work\studybirds-security-release-20261017-mobile\.dart_tool\flutter_build',
 'D:\work\study-birds\app\.dart_tool\flutter_build',
 'D:\work\studybirds-security-release-20261017-mobile\build\test_cache',
 'D:\work\studybirds-security-release-20261017-web\app\build\test_cache',
 'D:\work\studybirds-security-release-20261017-mobile\build\app\generated',
 'D:\work\study-birds\app\build\89a6598c8854ed031dfc25d83c80860e.cache.dill.track.dill'
)
$Frozen = @'
{
  "sourceLogSha256": "2f6228bd7b79506d4158e575694cd491e0aead756b9954881e1797644434ef0f",
  "sourceReportSha256": "ec85b10991871ef69c5e310234203486b2d82daed1da37e2ecc9b29b24751f16",
  "repositories": [
    "D:/work/studybirds_app/study_birds_app-main",
    "D:/work/studybirds_session_release",
    "D:/work/studybirds_web",
    "D:/work/studybirds-security-release-20261017-mobile",
    "D:/work/study-birds",
    "D:/work/studybirds-security-release-20261017-web"
  ],
  "protectedFiles": [
    {
      "path": "D:\\work\\studybirds_session_release\\app\\build\\app\\outputs\\flutter-apk\\app-debug.apk",
      "sha256": "9638b98f111bf25b4079555f4a48029d40a4892dc12f48f407b3894b61b9ce23"
    },
    {
      "path": "D:\\work\\studybirds_session_release\\app\\android\\app\\build.gradle.kts",
      "sha256": "2fa29230bac7cb3795ae577e5dc1a627e57e39365f34549ec4f15f63b12b0390"
    },
    {
      "path": "D:\\work\\studybirds_session_release\\app\\config\\qa_android.pending.json",
      "sha256": "a398ee5cde8131c1b75ab4abab244420ff99866a19bf13a642ba7c99e92bf3aa"
    }
  ],
  "targets": [
    {
      "id": 1,
      "path": "D:\\work\\studybirds_session_release\\app\\build\\test_cache",
      "logicalBytes": 566904920,
      "files": [
        {
          "path": "D:\\work\\studybirds_session_release\\app\\build\\test_cache\\build\\0925d5fd56903514f343f7fac03ead62.cache.dill.track.dill",
          "bytes": 94499920,
          "sha256": "eae9d6682455d821f9f033df504f16f8797a1e592abf396ab73b8797dc8f27aa"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\build\\test_cache\\build\\61d432d2dbe84cb9837e08e352ecf31a.cache.dill.track.dill",
          "bytes": 94518568,
          "sha256": "b97ae0e2a7ba6189fd08e3cbd82e9fd1ec45941b41e3ce8b379610b88330e6f4"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\build\\test_cache\\build\\6f449f566d16a0498fec28fbd9882d74.cache.dill.track.dill",
          "bytes": 94447432,
          "sha256": "fb8b89a5526576966543d21185b66ca77462af1e692f84cf5cbc086d7b056a84"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\build\\test_cache\\build\\a13f270c037cbc06df8bf270c49d8974.cache.dill.track.dill",
          "bytes": 94514952,
          "sha256": "e490dc2c5fc367b086ab90f8512d9f03dc5fa3be2993a4127124aa00ff5d13ff"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\build\\test_cache\\build\\a7d00f44b49006b2353607eb688e6768.cache.dill.track.dill",
          "bytes": 94467104,
          "sha256": "e5630e6f2a08a651d829e499275774e00ec8bfb011fd34b3576bdf8b21beb347"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\build\\test_cache\\build\\e8e3c3c33ec9973a87950a2a1a3d0a95.cache.dill.track.dill",
          "bytes": 94456944,
          "sha256": "5317aa21aa5a266d903bffbaa2b4e1874a25a2fcd69948b47f29ec5a77c29f62"
        }
      ],
      "dirs": [
        "D:\\work\\studybirds_session_release\\app\\build\\test_cache",
        "D:\\work\\studybirds_session_release\\app\\build\\test_cache\\build"
      ]
    },
    {
      "id": 2,
      "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build",
      "logicalBytes": 102746163,
      "files": [
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\dart_plugin_registrant.dart",
          "bytes": 20109,
          "sha256": "438d39a7ac28805e93ae72dc11c8647d148afd542978f8ab5efef3d9eca225dd"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\.filecache",
          "bytes": 485288,
          "sha256": "cb5bf75587f99c0e788fcefce4191483cbc72d4440f149dc2839eb7b6c453d40"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\app.dill",
          "bytes": 101576776,
          "sha256": "224f1bc8bd4410e6ebea57f9f521c1967fb87cfa459f8992c4b0830ff43d8cde"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\build_hooks.d",
          "bytes": 384,
          "sha256": "b3fbefa492060ee5d9e8603cc246be2313840170993a4d4ef65d95b79ead07d5"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\build_hooks.stamp",
          "bytes": 720,
          "sha256": "e747ae3b79ff3aff6cfe81597ce767332202a2ca9b79163d247e1482eb182b7b"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\build_hooks_result.json",
          "bytes": 1068,
          "sha256": "c2ba45035806c63bbb78d9365a9ff9c7afd4a83321fc015726243fc21e3d8e6e"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\debug_android_application.stamp",
          "bytes": 23935,
          "sha256": "2187f68dbd8274092665c06f4b381a7ca4b4eb0ea678b3a1299b2ef5191c6bff"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\flutter_assets.d",
          "bytes": 22566,
          "sha256": "efee8e2231e3c1349be32397fdc884f68551533ddbf6c826e216d1e92ef84904"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\gen_dart_plugin_registrant.stamp",
          "bytes": 201,
          "sha256": "42ae69aed5846b2548f07b627d715c2726d2ec4bd0673f0332c37beb454007dd"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\gen_l10n_inputs_and_outputs.json",
          "bytes": 401,
          "sha256": "2adbaca0cd0b78d648160babb3dcc056c2dab7587cade3a45eee342b5b35aedd"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\gen_localizations.d",
          "bytes": 422,
          "sha256": "6c51e3750688d5cee4517c12fd9e1458e121f2bd9b6b0fbe39f89ee4e43e41cd"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\gen_localizations.stamp",
          "bytes": 553,
          "sha256": "3cd7f8093f200f6a10402fe53654a124506743491ae087ec6e66a5ab817f8350"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\install_code_assets.d",
          "bytes": 125,
          "sha256": "f54d92f2ef156d96e30b8c728a8a0f2f98ec7988b9587e3c659cc8a8978764d2"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\install_code_assets.stamp",
          "bytes": 577,
          "sha256": "b6cb791bb93c98e5625736a447623d6b841ec01da073055075ae53ad9a0fb9ca"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\kernel_snapshot_program.d",
          "bytes": 300341,
          "sha256": "e2443930540e31f450104f3032f754ff5ed9d5e59128d3d9a781c89b4040395f"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\kernel_snapshot_program.stamp",
          "bytes": 306535,
          "sha256": "63e551d8a825ed51b60b70c3eeeb8889ccf5b3d902a31fba153147c2c69d9bb2"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\link_hooks.d",
          "bytes": 129,
          "sha256": "db82f857c7932753209a8a6d72bdb9efc9e5c2d0ccf03706e6f678ba6cdc780a"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\link_hooks.stamp",
          "bytes": 537,
          "sha256": "6be14dd15e3e0f594e2a17306f8d20b3cc6aa9a3b34095c38bedc0f4ac01aadd"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\link_hooks_result.json",
          "bytes": 410,
          "sha256": "570e16483f8569ace7ff3ee77365fc54a26dc1db64ab4ba65ff57497ec82e50f"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\native_assets.json",
          "bytes": 45,
          "sha256": "9548a31e4a048135c1d94f919328bfb62ae2c7bb3cab96557c7941daa97776cb"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\outputs.json",
          "bytes": 5039,
          "sha256": "9ec1bec47e697e755d1d17d9219d7fae3b09a0fbda4cef206de9d5696975f5b8"
        },
        {
          "path": "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c\\recorded_uses.json",
          "bytes": 2,
          "sha256": "44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a"
        }
      ],
      "dirs": [
        "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build",
        "D:\\work\\studybirds_session_release\\app\\.dart_tool\\flutter_build\\f9d48cf0e07f3b48e46294cba121004c"
      ]
    },
    {
      "id": 3,
      "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build",
      "logicalBytes": 496786307,
      "files": [
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\.filecache",
          "bytes": 466678,
          "sha256": "dc2065214e9a3ccdb5a278780a429d5d176a0bae12a2a7abb2a21979fedf67f1"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\app.dill",
          "bytes": 98248976,
          "sha256": "04b08671c4d6b44a0f91334518b0725306ef478af51cb0bb8d92a4e15f5ec231"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\build_hooks.d",
          "bytes": 336,
          "sha256": "5ee909558034fc20b9c61e784722075da1f33058582f9ced7f517770803e765e"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\build_hooks.stamp",
          "bytes": 648,
          "sha256": "b51cdbc0f071a0b1b8941b359c82416edb1afbc59a7ff48d2b46a26ecc686255"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\build_hooks_result.json",
          "bytes": 960,
          "sha256": "c56edb06e0f189f98786a9d092f9408740fdada00e0de4b8c1c13fb776b6eca4"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\debug_android_application.stamp",
          "bytes": 21355,
          "sha256": "5848f28298edb6a9476e913aeb30b5bf4c40b516e04e7c334346b5c7c4878cbf"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\flutter_assets.d",
          "bytes": 20082,
          "sha256": "593554389fb0068c705ae410b622c7d6070cd061ba6fcb7e0e71272eaccdfa43"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\gen_dart_plugin_registrant.stamp",
          "bytes": 177,
          "sha256": "af328752d9d3230975b4d9b2efe5ea7d6b73de666f4b05795ec989d5526c34b7"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\gen_l10n_inputs_and_outputs.json",
          "bytes": 341,
          "sha256": "b3fe88e861ddc8183492652f67dd4f6db340f423a130eb3e59bc03b918e8e18d"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\gen_localizations.d",
          "bytes": 350,
          "sha256": "7f8f0da818511e2d15cae401db54082ab46574d4d1c7a85dc1eaea7534f6f25a"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\gen_localizations.stamp",
          "bytes": 481,
          "sha256": "484dc879d2b08d04b40804dbe895dde513b35dab138789b06828ab2b179f4c30"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\install_code_assets.d",
          "bytes": 113,
          "sha256": "314fd580df16341d6e1e79011e2833c9f6a761bf5e8397e20623467e8fb533d3"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\install_code_assets.stamp",
          "bytes": 529,
          "sha256": "3ce1a9883254616bdf65706cbeab8abbd69688f14355b14fefd8caf665106547"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\kernel_snapshot_program.d",
          "bytes": 289688,
          "sha256": "f1d61a11660e523ccb05ecc783f16accebc802e17d53a0bcabeb65d66c7817a8"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\kernel_snapshot_program.stamp",
          "bytes": 295680,
          "sha256": "62aaa8639e9106654c24379a71ffb310bf5e91db7f6bb422bb3d5a03fbaba67c"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\link_hooks.d",
          "bytes": 117,
          "sha256": "1a4c48b8f2faef47aa029365d3ff9a561c43d3a1aaede15847884e816bc800dc"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\link_hooks.stamp",
          "bytes": 489,
          "sha256": "57c9ae1eeb227785344d478a3a3518d6c581740c7fdac8649d9ead5e1f030aa9"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\link_hooks_result.json",
          "bytes": 374,
          "sha256": "382559aa4cbecdc17df8079a26d5a19aacdde1521198bb9e6fc723bd1ae24c56"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\native_assets.json",
          "bytes": 45,
          "sha256": "9548a31e4a048135c1d94f919328bfb62ae2c7bb3cab96557c7941daa97776cb"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\outputs.json",
          "bytes": 4061,
          "sha256": "613b9ab9be8d16a6ccb89b801af543c186735d2e3e814216fe3f63ecd6f2de96"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29\\recorded_uses.json",
          "bytes": 2,
          "sha256": "44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\.filecache",
          "bytes": 466678,
          "sha256": "4cc1ca6cb7de49cf1b5753eb3354fb67d92de4165ee8c6c8bfe13cda84b6eaa9"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\app.dill",
          "bytes": 98245424,
          "sha256": "3bfa901c5e012ad9dd8811fa6a149abc27a8106a801cbc8891f61a3584af2f2d"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\build_hooks.d",
          "bytes": 336,
          "sha256": "3830626b6c6ecdc76bb4360af1d0d47353df9de05e3edaedf84326cc0eefefdc"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\build_hooks.stamp",
          "bytes": 648,
          "sha256": "32090af78bcf081248eb0c2e51774f1696d0de65acdde2b0bcd362eee99a2ee7"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\build_hooks_result.json",
          "bytes": 960,
          "sha256": "c56edb06e0f189f98786a9d092f9408740fdada00e0de4b8c1c13fb776b6eca4"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\debug_android_application.stamp",
          "bytes": 21355,
          "sha256": "3b2cbf8f772aedcf96098a811e798c62bb82633817c989b02590858f7b4cfbcd"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\flutter_assets.d",
          "bytes": 20082,
          "sha256": "6146a4873cba4f4a824547daab2a98616714ff09b81defb55be9c2fe9e639cc9"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\gen_dart_plugin_registrant.stamp",
          "bytes": 177,
          "sha256": "af328752d9d3230975b4d9b2efe5ea7d6b73de666f4b05795ec989d5526c34b7"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\gen_l10n_inputs_and_outputs.json",
          "bytes": 341,
          "sha256": "b3fe88e861ddc8183492652f67dd4f6db340f423a130eb3e59bc03b918e8e18d"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\gen_localizations.d",
          "bytes": 350,
          "sha256": "7f8f0da818511e2d15cae401db54082ab46574d4d1c7a85dc1eaea7534f6f25a"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\gen_localizations.stamp",
          "bytes": 481,
          "sha256": "484dc879d2b08d04b40804dbe895dde513b35dab138789b06828ab2b179f4c30"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\install_code_assets.d",
          "bytes": 113,
          "sha256": "ff5e45280d24d348b19e90c0e3ba9ea1dd07fd7d247d4071024bf7b9e5c36a23"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\install_code_assets.stamp",
          "bytes": 529,
          "sha256": "47367f24cebdb44920007394eb886b5c83681ee66c82d4e2d7256a8f3e4599fa"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\kernel_snapshot_program.d",
          "bytes": 289688,
          "sha256": "d5aec89b112dc4ce4d1744d164a8f3fc07e28bd1be9c4a7cbc5592c9661da124"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\kernel_snapshot_program.stamp",
          "bytes": 295680,
          "sha256": "fc8cdeb563541d7d10d2b170cd4daf6069044c73a859dc0f2b394009acceef04"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\link_hooks.d",
          "bytes": 117,
          "sha256": "4a88ff455f765f33017d2176a54919ca55eabb9c02c03a9718015607ce40afb6"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\link_hooks.stamp",
          "bytes": 489,
          "sha256": "a423581b92a8317c1feda6ac5310f7e0045abd7fb832582ed59c2237352f7325"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\link_hooks_result.json",
          "bytes": 374,
          "sha256": "cad4a559a0c83306d2af1dac5c92ec1d9b390f31302665cd64c2bc1ef0f71433"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\native_assets.json",
          "bytes": 45,
          "sha256": "9548a31e4a048135c1d94f919328bfb62ae2c7bb3cab96557c7941daa97776cb"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\outputs.json",
          "bytes": 4061,
          "sha256": "613b9ab9be8d16a6ccb89b801af543c186735d2e3e814216fe3f63ecd6f2de96"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc\\recorded_uses.json",
          "bytes": 2,
          "sha256": "44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\.filecache",
          "bytes": 466806,
          "sha256": "857929bc652d900295933e6788464073971168db7c45bdb1ac9a622a18368284"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\app.dill",
          "bytes": 98273144,
          "sha256": "e5a67cbd9adb4d7333ed5c463ecceffb667a2ffead0ba784da49c3c11b6e9ff6"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\build_hooks.d",
          "bytes": 336,
          "sha256": "ef9d5a64661fbd9e8f05977140755e8f12a588d669f2d6095c43eac0a3b27f0a"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\build_hooks.stamp",
          "bytes": 648,
          "sha256": "341d5d32890995d52401998fcf4a4db7fef224db0d74bb1fe2f9e40ed121165d"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\build_hooks_result.json",
          "bytes": 960,
          "sha256": "c56edb06e0f189f98786a9d092f9408740fdada00e0de4b8c1c13fb776b6eca4"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\debug_android_application.stamp",
          "bytes": 21355,
          "sha256": "e30da01c9254ee4d99c8d777d6f45335c02ffece195a703356fe60da9c4dd93b"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\flutter_assets.d",
          "bytes": 20082,
          "sha256": "c2c1f7df121085b91f1fa70aaee7c541ff3b492fa999be5de12ef24e9722edfe"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\gen_dart_plugin_registrant.stamp",
          "bytes": 177,
          "sha256": "af328752d9d3230975b4d9b2efe5ea7d6b73de666f4b05795ec989d5526c34b7"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\gen_l10n_inputs_and_outputs.json",
          "bytes": 341,
          "sha256": "b3fe88e861ddc8183492652f67dd4f6db340f423a130eb3e59bc03b918e8e18d"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\gen_localizations.d",
          "bytes": 350,
          "sha256": "7f8f0da818511e2d15cae401db54082ab46574d4d1c7a85dc1eaea7534f6f25a"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\gen_localizations.stamp",
          "bytes": 481,
          "sha256": "484dc879d2b08d04b40804dbe895dde513b35dab138789b06828ab2b179f4c30"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\install_code_assets.d",
          "bytes": 113,
          "sha256": "52876f6d33ecafb0900583a851fa3ce9fde9d4b89207e5e28df0da62c265b790"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\install_code_assets.stamp",
          "bytes": 529,
          "sha256": "ca766845c33ca371808f6b175916d112085187d08e27862c24429f100935019c"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\kernel_snapshot_program.d",
          "bytes": 289763,
          "sha256": "824b35f1ab6d2cf7d2bc5c3f45513674ac99fbceada1f39f54325c9758aabb41"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\kernel_snapshot_program.stamp",
          "bytes": 295757,
          "sha256": "04dc7f23c924bc8cc3102e2b4a2543a7a127d40c865feea2c4007b9db9f7b8fd"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\link_hooks.d",
          "bytes": 117,
          "sha256": "6312ec94ad06170f410e73d7acb44449171ab3b4269e9cb9957dc38a1691ceab"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\link_hooks.stamp",
          "bytes": 489,
          "sha256": "5c0d9c98818a634f3776a32bcfa368d5d100bbafcf516bb1f5a638c8ebac830f"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\link_hooks_result.json",
          "bytes": 374,
          "sha256": "61e6c3e3d1991adb3aec8b00a3f5f3dd283eb0c703edc3834a8b2e2f30a9dbfe"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\native_assets.json",
          "bytes": 45,
          "sha256": "9548a31e4a048135c1d94f919328bfb62ae2c7bb3cab96557c7941daa97776cb"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\outputs.json",
          "bytes": 4061,
          "sha256": "613b9ab9be8d16a6ccb89b801af543c186735d2e3e814216fe3f63ecd6f2de96"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319\\recorded_uses.json",
          "bytes": 2,
          "sha256": "44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\.filecache",
          "bytes": 466678,
          "sha256": "0491f2d36618e13b0e17322c199e5c74aac5780805859671395d235199865810"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\app.dill",
          "bytes": 98247576,
          "sha256": "a7348ef92bd48c15f42eadccde321a7825653f4b79069d593c4be2fe6e038242"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\build_hooks.d",
          "bytes": 336,
          "sha256": "d13da6d1b7f1f3cb3ca941d2e2ded43e680f78730e704cd46b7d745cee6df7cf"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\build_hooks.stamp",
          "bytes": 648,
          "sha256": "295dc389787f53496f47aded337b68a20c9b46f2a57c3ad9378a94f3c997b388"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\build_hooks_result.json",
          "bytes": 960,
          "sha256": "c56edb06e0f189f98786a9d092f9408740fdada00e0de4b8c1c13fb776b6eca4"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\debug_android_application.stamp",
          "bytes": 21355,
          "sha256": "e808da12cd69ebd861a70cc457fec71aad97360b315d321bc4224600186955c7"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\flutter_assets.d",
          "bytes": 20082,
          "sha256": "cd871564b6ce24af08b0f0ead86598f90237134542fbc4c095cb5ea1f81e77f5"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\gen_dart_plugin_registrant.stamp",
          "bytes": 177,
          "sha256": "af328752d9d3230975b4d9b2efe5ea7d6b73de666f4b05795ec989d5526c34b7"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\gen_l10n_inputs_and_outputs.json",
          "bytes": 341,
          "sha256": "b3fe88e861ddc8183492652f67dd4f6db340f423a130eb3e59bc03b918e8e18d"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\gen_localizations.d",
          "bytes": 350,
          "sha256": "7f8f0da818511e2d15cae401db54082ab46574d4d1c7a85dc1eaea7534f6f25a"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\gen_localizations.stamp",
          "bytes": 481,
          "sha256": "484dc879d2b08d04b40804dbe895dde513b35dab138789b06828ab2b179f4c30"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\install_code_assets.d",
          "bytes": 113,
          "sha256": "07b3df3d1d5563aecea3ddc1b8306df24733bcd25eb47b3517994d65fbd4613b"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\install_code_assets.stamp",
          "bytes": 529,
          "sha256": "87781026cbd183d65d5ea0cbc31835de76f9db223723fde9dfd97f6c95b348f7"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\kernel_snapshot_program.d",
          "bytes": 289688,
          "sha256": "0f1d9c75976dbfa593a4a93ced6c7a2e282dd10107ce9e8afa1e86e1f41c3911"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\kernel_snapshot_program.stamp",
          "bytes": 295680,
          "sha256": "693bed6f82cd21b111e51d96b871f00be59eebcd29f3fc4e0442ca998bb1e1f8"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\link_hooks.d",
          "bytes": 117,
          "sha256": "eacf838f30a6e2d33a7d8676899c4e9fa7be2ccf3915af6c128afd67f25e8ab0"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\link_hooks.stamp",
          "bytes": 489,
          "sha256": "97340d780365a0e4d3595738c76bae449a746751760a7bc93071a6da6ca3b224"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\link_hooks_result.json",
          "bytes": 374,
          "sha256": "cc0b8c388bd84255a0692dec361815edccc5c8bec932afd59cb530ee06dc2acc"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\native_assets.json",
          "bytes": 45,
          "sha256": "9548a31e4a048135c1d94f919328bfb62ae2c7bb3cab96557c7941daa97776cb"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\outputs.json",
          "bytes": 4061,
          "sha256": "613b9ab9be8d16a6ccb89b801af543c186735d2e3e814216fe3f63ecd6f2de96"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327\\recorded_uses.json",
          "bytes": 2,
          "sha256": "44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\.filecache",
          "bytes": 466678,
          "sha256": "a846163d5913f93bc8c0103358862e706a9e4468c18ba3a8b4d5ae900344bdcf"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\app.dill",
          "bytes": 98239456,
          "sha256": "deabc20b3742b22778787f31ca605e612694d2aaed398e194698663c09b52c5a"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\build_hooks.d",
          "bytes": 336,
          "sha256": "f480ceb700ad71f6fffaa8d5ad8681705cf9d9bd1ca0bbdf538a38ab5ae1732d"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\build_hooks.stamp",
          "bytes": 648,
          "sha256": "3697b4a564ca1dd2cd83643959f0b3049cdc8c48ff9d8d4f3d3d52e0a1329a06"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\build_hooks_result.json",
          "bytes": 960,
          "sha256": "c56edb06e0f189f98786a9d092f9408740fdada00e0de4b8c1c13fb776b6eca4"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\debug_android_application.stamp",
          "bytes": 21355,
          "sha256": "ccf59c5fd79e7e8eac69f2bf3338e44e5e26ba5d0ebb75167808c07a4e1ffd8c"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\flutter_assets.d",
          "bytes": 20082,
          "sha256": "8a200c93b797ae6612b586d2ba46dee3094059af759007ca00b6d95b234f4b26"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\gen_dart_plugin_registrant.stamp",
          "bytes": 177,
          "sha256": "af328752d9d3230975b4d9b2efe5ea7d6b73de666f4b05795ec989d5526c34b7"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\gen_l10n_inputs_and_outputs.json",
          "bytes": 341,
          "sha256": "b3fe88e861ddc8183492652f67dd4f6db340f423a130eb3e59bc03b918e8e18d"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\gen_localizations.d",
          "bytes": 350,
          "sha256": "7f8f0da818511e2d15cae401db54082ab46574d4d1c7a85dc1eaea7534f6f25a"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\gen_localizations.stamp",
          "bytes": 481,
          "sha256": "484dc879d2b08d04b40804dbe895dde513b35dab138789b06828ab2b179f4c30"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\install_code_assets.d",
          "bytes": 113,
          "sha256": "65bfdc80d4a8de8a5a60e93218066bd3261772faab2b4ef36e2692e86ea529a9"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\install_code_assets.stamp",
          "bytes": 529,
          "sha256": "6f5bedf4fb5760b1ff15890126f3b653985f0aa7cae41aae5306d46f03c7eae8"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\kernel_snapshot_program.d",
          "bytes": 289688,
          "sha256": "93bb0f680025a92c8efa29aa94d46a60cee214aac27b4e748aaad09b209495c1"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\kernel_snapshot_program.stamp",
          "bytes": 295680,
          "sha256": "613cc2def87a036f90623319bd098bad61b1fd0e4b6a21b6e8949c18086ba2ea"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\link_hooks.d",
          "bytes": 117,
          "sha256": "94177411f53225d3af8b65e53f00ed4802277780383e1799dc96f6123e8391d9"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\link_hooks.stamp",
          "bytes": 489,
          "sha256": "99a550864511da147209ca28b0d01a333d0a620b83a1d60cf3bfec62943034ca"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\link_hooks_result.json",
          "bytes": 374,
          "sha256": "eb286c78a53a1ab7c4c2550efc7a36a2721f2bb06c90e2853f77c878a52f5d2c"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\native_assets.json",
          "bytes": 45,
          "sha256": "9548a31e4a048135c1d94f919328bfb62ae2c7bb3cab96557c7941daa97776cb"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\outputs.json",
          "bytes": 4061,
          "sha256": "613b9ab9be8d16a6ccb89b801af543c186735d2e3e814216fe3f63ecd6f2de96"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436\\recorded_uses.json",
          "bytes": 2,
          "sha256": "44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a"
        },
        {
          "path": "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\dart_plugin_registrant.dart",
          "bytes": 18921,
          "sha256": "5ffc67a1f3da748f765b70a93598ad498e8fb2963acd084ec3509fb3a6273d2a"
        }
      ],
      "dirs": [
        "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build",
        "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\449203284cf852932e89b62ce237cc29",
        "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\44d344f9071381ce9f6c96ca39084edc",
        "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\52a29e40c64900cf77aea37d3eb2a319",
        "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\9606af4f124a8d051bd924921fd67327",
        "D:\\work\\studybirds_web\\app\\.dart_tool\\flutter_build\\b1b849cca9ea08b47ef2baa9e8396436"
      ]
    },
    {
      "id": 4,
      "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build",
      "logicalBytes": 226102961,
      "files": [
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\.filecache",
          "bytes": 488137,
          "sha256": "26231115ef5f7ccaaa4c2f357bf9479fbb38392e2f838d1cd55039b5a8040db9"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\android_aot_bundle_release_android-arm.stamp",
          "bytes": 284,
          "sha256": "19cb18008798ce820d294260e7f26d7db0d9f73f5bb1314689c9611e9a35f539"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\android_aot_bundle_release_android-arm64.stamp",
          "bytes": 280,
          "sha256": "71e5c6555511c19804a1fbb3fe58c958150220d0c746617fcfcf056bac4dfd69"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\android_aot_bundle_release_android-x64.stamp",
          "bytes": 274,
          "sha256": "33130d41ab3cab78af600f3d2106190fb89bcf36ddc61833838a40bbe0539386"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\android_aot_release_android-arm.stamp",
          "bytes": 515,
          "sha256": "090540f6061e896c1c1d7f1fbebd003816725202e16504c1ea783ef99e9adadf"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\android_aot_release_android-arm64.stamp",
          "bytes": 513,
          "sha256": "a5dc4a287f64ce3ec7feeabd7e7e93af0311cde14ccb7a1353cebaec8423b1e2"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\android_aot_release_android-x64.stamp",
          "bytes": 510,
          "sha256": "dc4f4341f0a82c79313390aad052a897c85865d4ff2ef2ed66f86010ed65253c"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\aot_android_asset_bundle.stamp",
          "bytes": 24274,
          "sha256": "9618dd9c630397578d9c90fec740edcbfac16036e58072a5d7097f3c7b88e90e"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\app.dill",
          "bytes": 59975280,
          "sha256": "46180a98be8683910075603107e5b4be416725f6b76b08e5f2c4a2715c9fc152"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\arm64-v8a\\app.so",
          "bytes": 17028944,
          "sha256": "18dcf35f0a47f24f0800009eae3e1bab4dad96531e1d84caeaa19df58803352f"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\armeabi-v7a\\app.so",
          "bytes": 17512600,
          "sha256": "35cae062dc28b06fb46c73dccbe5a847747194871b5d7e1fee9060097710dd08"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\build_hooks.d",
          "bytes": 432,
          "sha256": "72d90d62592d10efcd1c2bc485bb176e037994cd6458013fb3754c2a8829432d"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\build_hooks.stamp",
          "bytes": 792,
          "sha256": "32862f98bf8fbe9eba03dd25344c052546e1ee412576ace0f4351b3a6f527598"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\build_hooks_result.json",
          "bytes": 1185,
          "sha256": "5ecc718e759ca7df2a8f490064034fd6fe9f6f4ebb7d18160dc9c1ee87125b41"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\flutter_android_aot_bundle_release_android-arm.d",
          "bytes": 2,
          "sha256": "45822f54a0d0e030f75698c9252f1345982e743c9466806048f542467b3ca4f9"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\flutter_android_aot_bundle_release_android-arm64.d",
          "bytes": 2,
          "sha256": "45822f54a0d0e030f75698c9252f1345982e743c9466806048f542467b3ca4f9"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\flutter_android_aot_bundle_release_android-x64.d",
          "bytes": 2,
          "sha256": "45822f54a0d0e030f75698c9252f1345982e743c9466806048f542467b3ca4f9"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\flutter_android_aot_release_android-arm.d",
          "bytes": 2,
          "sha256": "45822f54a0d0e030f75698c9252f1345982e743c9466806048f542467b3ca4f9"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\flutter_android_aot_release_android-arm64.d",
          "bytes": 2,
          "sha256": "45822f54a0d0e030f75698c9252f1345982e743c9466806048f542467b3ca4f9"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\flutter_android_aot_release_android-x64.d",
          "bytes": 2,
          "sha256": "45822f54a0d0e030f75698c9252f1345982e743c9466806048f542467b3ca4f9"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\flutter_assets.d",
          "bytes": 23338,
          "sha256": "18bbbcacf57b2f0276731cc249c5a058fcf6f8578b6eb39ad9cec4695f82c1a1"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\gen_dart_plugin_registrant.stamp",
          "bytes": 225,
          "sha256": "9ddca4836d110ec54f2948ce6f08e3b4ec05d7c991cb70fd5faa98959017d8dd"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\gen_l10n_inputs_and_outputs.json",
          "bytes": 461,
          "sha256": "8559a4a5760ec6051407360ea47566a362d0619252d6e04c08b30a5e27ba7252"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\gen_localizations.d",
          "bytes": 494,
          "sha256": "cb77f88d0c9783733b92283325a3a9038e9fa8fd6eef05ef297ff86100f0bdf4"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\gen_localizations.stamp",
          "bytes": 625,
          "sha256": "37010bda64bee16f7e337c15bac721a1caffa526c5592d9409363e96b6404eca"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\install_code_assets.d",
          "bytes": 137,
          "sha256": "b89566472f14523e93abccee3e6bc94a3cc1ccbedf9eb6596bcd374ab69b095f"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\install_code_assets.stamp",
          "bytes": 625,
          "sha256": "b9fbc452d1aba562e0fe31594b13e2867abc78980ea0343f27a2b10e851c9925"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\kernel_snapshot_program.d",
          "bytes": 301905,
          "sha256": "46f5b6693a65bbaf4043e6bde19fbd3315b3b427d84896e5642f26dacf9ed758"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\kernel_snapshot_program.stamp",
          "bytes": 308125,
          "sha256": "3b33269bcfbd318a7f91abcc44df0b3292d02aceb923563bdd5bc3136e3fa683"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\link_hooks.d",
          "bytes": 141,
          "sha256": "d3e5c52834cb512bd0867e126d443c8535e32ddd8b4cdfabd5650ec2cbb551d0"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\link_hooks.stamp",
          "bytes": 585,
          "sha256": "427bfdb9b3e1e8c8dcd67599b1f6e834a0a3f63759114c6d29b9743a2ebc59d3"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\link_hooks_result.json",
          "bytes": 449,
          "sha256": "5a291a8d3657583ce59ef30253ddf0da29d661c2d6ac7d2a87ed9f2fa0d44a51"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\native_assets.json",
          "bytes": 45,
          "sha256": "9548a31e4a048135c1d94f919328bfb62ae2c7bb3cab96557c7941daa97776cb"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\outputs.json",
          "bytes": 5515,
          "sha256": "8353229f2199fb20eb0596bc36099a545ad4a07050501cffdef80e31b5b88f6b"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\recorded_uses.json",
          "bytes": 2,
          "sha256": "44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\x86_64\\app.so",
          "bytes": 17364720,
          "sha256": "5defbac4f8d5a41c1c05dd03c320474d3ec19355c78d831c7375994effaba7df"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\_composite.stamp",
          "bytes": 26,
          "sha256": "cc720a324af5727c74f00b41fb209465e50885fadb5f14831028fa4b418d3ccc"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\.filecache",
          "bytes": 488137,
          "sha256": "a467732e2d5bb0c92278717eb99f5ac265ec1f35743623b1e50d73fefb29acf9"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\android_aot_bundle_release_android-arm.stamp",
          "bytes": 284,
          "sha256": "e9a456818645db23a31ff3fd73886b6dc9a6857beb36cb783d683707498e02fa"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\android_aot_bundle_release_android-arm64.stamp",
          "bytes": 280,
          "sha256": "567147cb7607cf428bb133d4de7d541cb859a37e87209795f90574e9bf359e9a"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\android_aot_bundle_release_android-x64.stamp",
          "bytes": 274,
          "sha256": "9b2516b5ad3e4f500d2ce7ff531f10a99c7d25f4c8c229d144b5cd7fc742821b"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\android_aot_release_android-arm.stamp",
          "bytes": 515,
          "sha256": "28d1b736600adbe7de0979a66ac8c49c7e44f6c7380c9315ae8bd863edc39e15"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\android_aot_release_android-arm64.stamp",
          "bytes": 513,
          "sha256": "bf18a92dd2aa86cf0efc1d9348098d00e8a10869161977a5e120df4ff86bf7cb"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\android_aot_release_android-x64.stamp",
          "bytes": 510,
          "sha256": "71b6a9436295de5f13f64b947330f7fc29c1edf5470b7d3a5cc90f5c2caf1d42"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\aot_android_asset_bundle.stamp",
          "bytes": 24274,
          "sha256": "6f19cc270491053c1ed81d05251c052ab165d85eebfd788e03ac6f1f72988493"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\app.dill",
          "bytes": 59975224,
          "sha256": "5de3804eae57fe40a59fa7d0f138d5512ef7ecb2785fbe4f798ca988c06247e6"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\arm64-v8a\\app.so",
          "bytes": 17028952,
          "sha256": "fb09ba342d0190a2bcfe8c3c0ba04a9ca0e798ad0f695427a6b08e82cb463c09"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\armeabi-v7a\\app.so",
          "bytes": 17512600,
          "sha256": "eb98d7a4bc00198c45ddf958aa509a45a84d2171178df332fd60540cc390ab85"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\build_hooks.d",
          "bytes": 432,
          "sha256": "e2caade909bb1ed2734cdddea1e18713b11a9f3a2e2bffc5b87c8d866c1e1013"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\build_hooks.stamp",
          "bytes": 792,
          "sha256": "1beb067ff88d853f45b22f3ec3bd9b694439a4d3dfaa8b61b5b2d20ba33894d6"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\build_hooks_result.json",
          "bytes": 1185,
          "sha256": "5ecc718e759ca7df2a8f490064034fd6fe9f6f4ebb7d18160dc9c1ee87125b41"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\flutter_android_aot_bundle_release_android-arm.d",
          "bytes": 2,
          "sha256": "45822f54a0d0e030f75698c9252f1345982e743c9466806048f542467b3ca4f9"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\flutter_android_aot_bundle_release_android-arm64.d",
          "bytes": 2,
          "sha256": "45822f54a0d0e030f75698c9252f1345982e743c9466806048f542467b3ca4f9"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\flutter_android_aot_bundle_release_android-x64.d",
          "bytes": 2,
          "sha256": "45822f54a0d0e030f75698c9252f1345982e743c9466806048f542467b3ca4f9"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\flutter_android_aot_release_android-arm.d",
          "bytes": 2,
          "sha256": "45822f54a0d0e030f75698c9252f1345982e743c9466806048f542467b3ca4f9"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\flutter_android_aot_release_android-arm64.d",
          "bytes": 2,
          "sha256": "45822f54a0d0e030f75698c9252f1345982e743c9466806048f542467b3ca4f9"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\flutter_android_aot_release_android-x64.d",
          "bytes": 2,
          "sha256": "45822f54a0d0e030f75698c9252f1345982e743c9466806048f542467b3ca4f9"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\flutter_assets.d",
          "bytes": 23338,
          "sha256": "0b3737951d909490276ce6e02973f06d1f9b056a15d11a96d7c073f52c141c69"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\gen_dart_plugin_registrant.stamp",
          "bytes": 225,
          "sha256": "9ddca4836d110ec54f2948ce6f08e3b4ec05d7c991cb70fd5faa98959017d8dd"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\gen_l10n_inputs_and_outputs.json",
          "bytes": 461,
          "sha256": "8559a4a5760ec6051407360ea47566a362d0619252d6e04c08b30a5e27ba7252"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\gen_localizations.d",
          "bytes": 494,
          "sha256": "cb77f88d0c9783733b92283325a3a9038e9fa8fd6eef05ef297ff86100f0bdf4"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\gen_localizations.stamp",
          "bytes": 625,
          "sha256": "37010bda64bee16f7e337c15bac721a1caffa526c5592d9409363e96b6404eca"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\install_code_assets.d",
          "bytes": 137,
          "sha256": "d7def77dd42c96f7628e9c4a041169828bf7ce0d63a18a12182302e3d2db2b22"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\install_code_assets.stamp",
          "bytes": 625,
          "sha256": "528350142d9eae7d65b03991c9e7e9c26177eb5585742674e29226538e0950a2"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\kernel_snapshot_program.d",
          "bytes": 301905,
          "sha256": "ad7c666f369a31698fe50a3f28de5866cca412d0e16550d612698a22521e7677"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\kernel_snapshot_program.stamp",
          "bytes": 308125,
          "sha256": "33a92c441b1b7b6fe223dab80eecb6e7a5b44886e6379bfbc0632a6232a64132"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\link_hooks.d",
          "bytes": 141,
          "sha256": "0023bf872e11ad151f8de5fc3734ce79233524bc4b77b6954a5a84fc6c1e739f"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\link_hooks.stamp",
          "bytes": 585,
          "sha256": "142e3e78cd3816985eeac6169e5495313cbacdecce08773ba343d67d1c21b2fa"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\link_hooks_result.json",
          "bytes": 449,
          "sha256": "429b730601ef75fefe15c98cd812e1ecd237208aa8141d89e766134e0fdcbf17"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\native_assets.json",
          "bytes": 45,
          "sha256": "9548a31e4a048135c1d94f919328bfb62ae2c7bb3cab96557c7941daa97776cb"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\outputs.json",
          "bytes": 5515,
          "sha256": "4c9fc4292ff6c829e4300e65a3fb16ce51ae01abe18f732cce84793cd6db894d"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\recorded_uses.json",
          "bytes": 2,
          "sha256": "44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\x86_64\\app.so",
          "bytes": 17364720,
          "sha256": "43a96fd84da906c57271385ef60a1d386a622309376d6141d5512436fd17c7ac"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\_composite.stamp",
          "bytes": 26,
          "sha256": "cc720a324af5727c74f00b41fb209465e50885fadb5f14831028fa4b418d3ccc"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\dart_plugin_registrant.dart",
          "bytes": 20109,
          "sha256": "438d39a7ac28805e93ae72dc11c8647d148afd542978f8ab5efef3d9eca225dd"
        }
      ],
      "dirs": [
        "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build",
        "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d",
        "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\arm64-v8a",
        "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\armeabi-v7a",
        "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\34387cda8c1192f48cb6bb1f629b771d\\x86_64",
        "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90",
        "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\arm64-v8a",
        "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\armeabi-v7a",
        "D:\\work\\studybirds-security-release-20261017-mobile\\.dart_tool\\flutter_build\\4c47a1335869fe771982a220e0fdba90\\x86_64"
      ]
    },
    {
      "id": 5,
      "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build",
      "logicalBytes": 188786953,
      "files": [
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\5d6cf3e58e79ea3343825a33eb1cb091\\.filecache",
          "bytes": 471228,
          "sha256": "bb4440564ebc1ad3d8c6eeadfbca4fe4e722593e322b37440627bd3d86cfcc91"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\5d6cf3e58e79ea3343825a33eb1cb091\\app.dill",
          "bytes": 94580016,
          "sha256": "4daa2a52d9d80da9b16fc713af4d1efb7c948fbe716d39786592157312bfee4f"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\5d6cf3e58e79ea3343825a33eb1cb091\\dart_build.d",
          "bytes": 332,
          "sha256": "06f373379f1a93bca92a2a0856214e1de1391b0ad2e29b480ec3c0cd7a54a5be"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\5d6cf3e58e79ea3343825a33eb1cb091\\dart_build.stamp",
          "bytes": 646,
          "sha256": "186f82fc859d17a4ee7040ff15cc311a96b1132cf6c27bd06d09fe6aa0a56578"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\5d6cf3e58e79ea3343825a33eb1cb091\\dart_build_result.json",
          "bytes": 373,
          "sha256": "2c237a0530a6d859e6dca3f574bab6cfc1253f3159d9da5d8d070e2fcee83f0f"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\5d6cf3e58e79ea3343825a33eb1cb091\\debug_android_application.stamp",
          "bytes": 21164,
          "sha256": "0fe2d1683ebfc20c8613d6d9a74538d029dec385039801a4bb1d5dce999373f4"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\5d6cf3e58e79ea3343825a33eb1cb091\\flutter_assets.d",
          "bytes": 19975,
          "sha256": "754c0c9fad1a5d6156a361841118209de332ef940476fa93ac48cf039ff4bd69"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\5d6cf3e58e79ea3343825a33eb1cb091\\gen_dart_plugin_registrant.stamp",
          "bytes": 171,
          "sha256": "f3ee8fb60807729fee9a4c63e10c6a1f9af4528006b3879fca144dfeea993d13"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\5d6cf3e58e79ea3343825a33eb1cb091\\gen_l10n_inputs_and_outputs.json",
          "bytes": 326,
          "sha256": "26910e2dd790b1dabfc52a53671159d7972e6eeb5e713310797c0605f0e7c8e4"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\5d6cf3e58e79ea3343825a33eb1cb091\\gen_localizations.d",
          "bytes": 332,
          "sha256": "fd8911fc0b7a4c4a07ed08c09b64bc2b6cfc0bb3e9124499dec683ea533103e0"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\5d6cf3e58e79ea3343825a33eb1cb091\\gen_localizations.stamp",
          "bytes": 472,
          "sha256": "1ae7b81aa3eaf329e87d265b36568eac2f97ab8c77128d74ca47775baef00b81"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\5d6cf3e58e79ea3343825a33eb1cb091\\install_code_assets.d",
          "bytes": 110,
          "sha256": "13f09c2adee90ab882aec9b9b659716da766184a0d2d87e4388c5ccedbc125db"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\5d6cf3e58e79ea3343825a33eb1cb091\\install_code_assets.stamp",
          "bytes": 412,
          "sha256": "4af525fa62812c5b8ed01fb6a581aa596c9619e5311d3171c0b4eab93cbb58d2"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\5d6cf3e58e79ea3343825a33eb1cb091\\kernel_snapshot_program.d",
          "bytes": 294966,
          "sha256": "f56f43a9984f273be97dd661bdf63667ac95c5e554e11cd40d6849acfd947cdb"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\5d6cf3e58e79ea3343825a33eb1cb091\\kernel_snapshot_program.stamp",
          "bytes": 300872,
          "sha256": "c336ee0cc620ff03919d06fa778b686be45599119ebbd89a5fe574da56825692"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\5d6cf3e58e79ea3343825a33eb1cb091\\native_assets.json",
          "bytes": 45,
          "sha256": "9548a31e4a048135c1d94f919328bfb62ae2c7bb3cab96557c7941daa97776cb"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\5d6cf3e58e79ea3343825a33eb1cb091\\outputs.json",
          "bytes": 3959,
          "sha256": "65fb79ade240c63902333d6dead0c192b3ca2a751f3a5fa5f333db4d3cd7da5a"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\.filecache",
          "bytes": 471870,
          "sha256": "5c22243d0b570ecae44cc8c4ecbfa90eb6d1cbd77a31de9159433a13a1e11a17"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\android_aot_bundle_release_android-arm.stamp",
          "bytes": 230,
          "sha256": "a19136166c313871b650ad26e0db515f802532dbcdfaee2dde3e93cc4cb0ec8e"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\android_aot_bundle_release_android-arm64.stamp",
          "bytes": 226,
          "sha256": "e2260a2a893c6b5f4653dc9a30e5bf23136b80ce8e2e1b54f0474f8695cd99a6"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\android_aot_bundle_release_android-x64.stamp",
          "bytes": 220,
          "sha256": "ef6b5e7bc689cd6b69005c17a923a55ad7a5e2499f47a0df8d8b03ad4b6269b7"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\android_aot_release_android-arm.stamp",
          "bytes": 497,
          "sha256": "9b7392d0d4263277393d7ebfb81bbc53fe0ecbea0f2c41c09a446e5f5a41f30a"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\android_aot_release_android-arm64.stamp",
          "bytes": 495,
          "sha256": "b27265cea02caaca459831b123f501e80625bc284952ebbff183119c856fa8cd"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\android_aot_release_android-x64.stamp",
          "bytes": 492,
          "sha256": "63ad0935e4093716bf8176d7182ad0a517a781303623410f3c6e9e74f4353666"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\aot_android_asset_bundle.stamp",
          "bytes": 20790,
          "sha256": "c41435a70d1e3421de4b7a9e4d3492520494ab5cc6d2f6dd6e1c17b51456f596"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\app.dill",
          "bytes": 56939616,
          "sha256": "b7300c4ef3a52232768b85d159082e1bdafff2f29e38261483ceb7ea9959aa3d"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\arm64-v8a\\app.so",
          "bytes": 11207600,
          "sha256": "1df596bcd0573c110f244edcde9242475bebc933e0bae55e333a4f25588d36a2"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\armeabi-v7a\\app.so",
          "bytes": 12337756,
          "sha256": "8f4e0fb25756945ce8dc184129b002035fdd62d4aea58c9aea052280c85da5be"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\dart_build.d",
          "bytes": 332,
          "sha256": "66b39064bfa7b8dddbeed484804dee7e9bd0fa897ae042e4c2cb94a97fa857b2"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\dart_build.stamp",
          "bytes": 646,
          "sha256": "db61721eb832cc69cc288184bd62446e8cb10aa412cd3e81a0612cae94e21742"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\dart_build_result.json",
          "bytes": 373,
          "sha256": "d088ecc9567ab39c97330dcd6e320701aa7b3bb440a970b3beda3c67cd9f8847"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\flutter_android_aot_bundle_release_android-arm.d",
          "bytes": 2,
          "sha256": "45822f54a0d0e030f75698c9252f1345982e743c9466806048f542467b3ca4f9"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\flutter_android_aot_bundle_release_android-arm64.d",
          "bytes": 2,
          "sha256": "45822f54a0d0e030f75698c9252f1345982e743c9466806048f542467b3ca4f9"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\flutter_android_aot_bundle_release_android-x64.d",
          "bytes": 2,
          "sha256": "45822f54a0d0e030f75698c9252f1345982e743c9466806048f542467b3ca4f9"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\flutter_android_aot_release_android-arm.d",
          "bytes": 2,
          "sha256": "45822f54a0d0e030f75698c9252f1345982e743c9466806048f542467b3ca4f9"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\flutter_android_aot_release_android-arm64.d",
          "bytes": 2,
          "sha256": "45822f54a0d0e030f75698c9252f1345982e743c9466806048f542467b3ca4f9"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\flutter_android_aot_release_android-x64.d",
          "bytes": 2,
          "sha256": "45822f54a0d0e030f75698c9252f1345982e743c9466806048f542467b3ca4f9"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\flutter_assets.d",
          "bytes": 20031,
          "sha256": "df42c580152c873784f2765d89eb456db37e449c5f3f55c47341fe2af8673c74"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\gen_dart_plugin_registrant.stamp",
          "bytes": 171,
          "sha256": "f3ee8fb60807729fee9a4c63e10c6a1f9af4528006b3879fca144dfeea993d13"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\gen_l10n_inputs_and_outputs.json",
          "bytes": 326,
          "sha256": "26910e2dd790b1dabfc52a53671159d7972e6eeb5e713310797c0605f0e7c8e4"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\gen_localizations.d",
          "bytes": 332,
          "sha256": "fd8911fc0b7a4c4a07ed08c09b64bc2b6cfc0bb3e9124499dec683ea533103e0"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\gen_localizations.stamp",
          "bytes": 472,
          "sha256": "1ae7b81aa3eaf329e87d265b36568eac2f97ab8c77128d74ca47775baef00b81"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\install_code_assets.d",
          "bytes": 110,
          "sha256": "0d34df60f8cbcb8cd17a7271f13255ac33cb7dfccfa45ce22639551fe975bf75"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\install_code_assets.stamp",
          "bytes": 412,
          "sha256": "9a6e2b36256741cc4ad21410bd4cc94b1cc83474965335653cc53df3f01eade4"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\kernel_snapshot_program.d",
          "bytes": 294966,
          "sha256": "95a68c310a8bb4e22b2d110e51f037189e6703398b53e5357cd7a776bbc874fd"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\kernel_snapshot_program.stamp",
          "bytes": 300872,
          "sha256": "91eae63ce6e433e999328879ebf7db6369d3d0865dba62f8fe1835ac0f934b2c"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\native_assets.json",
          "bytes": 45,
          "sha256": "9548a31e4a048135c1d94f919328bfb62ae2c7bb3cab96557c7941daa97776cb"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\outputs.json",
          "bytes": 3971,
          "sha256": "1cd182a3714aa41f2049d649bd16e0cc39e79d3b16a8bd55866c146be1968684"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\x86_64\\app.so",
          "bytes": 11469744,
          "sha256": "0c6e0af5870ad8037ad8b6ba65c035ed6eecf4be51e8a54cf088b6bdff629759"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\_composite.stamp",
          "bytes": 26,
          "sha256": "cc720a324af5727c74f00b41fb209465e50885fadb5f14831028fa4b418d3ccc"
        },
        {
          "path": "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\dart_plugin_registrant.dart",
          "bytes": 18921,
          "sha256": "5ffc67a1f3da748f765b70a93598ad498e8fb2963acd084ec3509fb3a6273d2a"
        }
      ],
      "dirs": [
        "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build",
        "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\5d6cf3e58e79ea3343825a33eb1cb091",
        "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca",
        "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\arm64-v8a",
        "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\armeabi-v7a",
        "D:\\work\\study-birds\\app\\.dart_tool\\flutter_build\\8f0831a12078adb455675c6091415eca\\x86_64"
      ]
    },
    {
      "id": 6,
      "path": "D:\\work\\studybirds-security-release-20261017-mobile\\build\\test_cache",
      "logicalBytes": 94379064,
      "files": [
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\build\\test_cache\\build\\4ab1ed1ed73441fd54ee7b5fd695de3a.cache.dill.track.dill",
          "bytes": 94379064,
          "sha256": "7421c5c63cf5caee0acca73ff24194baa83ab7f503631e85542f2ab45176e027"
        }
      ],
      "dirs": [
        "D:\\work\\studybirds-security-release-20261017-mobile\\build\\test_cache",
        "D:\\work\\studybirds-security-release-20261017-mobile\\build\\test_cache\\build"
      ]
    },
    {
      "id": 7,
      "path": "D:\\work\\studybirds-security-release-20261017-web\\app\\build\\test_cache",
      "logicalBytes": 94379248,
      "files": [
        {
          "path": "D:\\work\\studybirds-security-release-20261017-web\\app\\build\\test_cache\\build\\4ab1ed1ed73441fd54ee7b5fd695de3a.cache.dill.track.dill",
          "bytes": 94379248,
          "sha256": "1f505b8abef7fceb1369831e96c2bce59f521b0d629ff7f170772e4e3ff713f0"
        }
      ],
      "dirs": [
        "D:\\work\\studybirds-security-release-20261017-web\\app\\build\\test_cache",
        "D:\\work\\studybirds-security-release-20261017-web\\app\\build\\test_cache\\build"
      ]
    },
    {
      "id": 8,
      "path": "D:\\work\\studybirds-security-release-20261017-mobile\\build\\app\\generated",
      "logicalBytes": 51906264,
      "files": [
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\build\\app\\generated\\jniLibs\\copyJniLibsflutterBuildRelease\\arm64-v8a\\libapp.so",
          "bytes": 17028944,
          "sha256": "18dcf35f0a47f24f0800009eae3e1bab4dad96531e1d84caeaa19df58803352f"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\build\\app\\generated\\jniLibs\\copyJniLibsflutterBuildRelease\\armeabi-v7a\\libapp.so",
          "bytes": 17512600,
          "sha256": "35cae062dc28b06fb46c73dccbe5a847747194871b5d7e1fee9060097710dd08"
        },
        {
          "path": "D:\\work\\studybirds-security-release-20261017-mobile\\build\\app\\generated\\jniLibs\\copyJniLibsflutterBuildRelease\\x86_64\\libapp.so",
          "bytes": 17364720,
          "sha256": "5defbac4f8d5a41c1c05dd03c320474d3ec19355c78d831c7375994effaba7df"
        }
      ],
      "dirs": [
        "D:\\work\\studybirds-security-release-20261017-mobile\\build\\app\\generated",
        "D:\\work\\studybirds-security-release-20261017-mobile\\build\\app\\generated\\ap_generated_sources",
        "D:\\work\\studybirds-security-release-20261017-mobile\\build\\app\\generated\\ap_generated_sources\\release",
        "D:\\work\\studybirds-security-release-20261017-mobile\\build\\app\\generated\\ap_generated_sources\\release\\out",
        "D:\\work\\studybirds-security-release-20261017-mobile\\build\\app\\generated\\jniLibs",
        "D:\\work\\studybirds-security-release-20261017-mobile\\build\\app\\generated\\jniLibs\\copyJniLibsflutterBuildRelease",
        "D:\\work\\studybirds-security-release-20261017-mobile\\build\\app\\generated\\jniLibs\\copyJniLibsflutterBuildRelease\\arm64-v8a",
        "D:\\work\\studybirds-security-release-20261017-mobile\\build\\app\\generated\\jniLibs\\copyJniLibsflutterBuildRelease\\armeabi-v7a",
        "D:\\work\\studybirds-security-release-20261017-mobile\\build\\app\\generated\\jniLibs\\copyJniLibsflutterBuildRelease\\x86_64",
        "D:\\work\\studybirds-security-release-20261017-mobile\\build\\app\\generated\\res",
        "D:\\work\\studybirds-security-release-20261017-mobile\\build\\app\\generated\\res\\pngs",
        "D:\\work\\studybirds-security-release-20261017-mobile\\build\\app\\generated\\res\\pngs\\release",
        "D:\\work\\studybirds-security-release-20261017-mobile\\build\\app\\generated\\res\\resValues",
        "D:\\work\\studybirds-security-release-20261017-mobile\\build\\app\\generated\\res\\resValues\\release"
      ]
    },
    {
      "id": 9,
      "path": "D:\\work\\study-birds\\app\\build\\89a6598c8854ed031dfc25d83c80860e.cache.dill.track.dill",
      "logicalBytes": 94580016,
      "files": [
        {
          "path": "D:\\work\\study-birds\\app\\build\\89a6598c8854ed031dfc25d83c80860e.cache.dill.track.dill",
          "bytes": 94580016,
          "sha256": "4daa2a52d9d80da9b16fc713af4d1efb7c948fbe716d39786592157312bfee4f"
        }
      ],
      "dirs": []
    }
  ]
}
'@ | ConvertFrom-Json

# Public Windows metadata API: detect hard links using the actual open handle.
# This utility compilation occurs ONLY if the owner runs the script.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class StudyBirdsOwnerFileInfo {
 [StructLayout(LayoutKind.Sequential)] public struct Info {
  public uint Attr; public System.Runtime.InteropServices.ComTypes.FILETIME Created;
  public System.Runtime.InteropServices.ComTypes.FILETIME Accessed;
  public System.Runtime.InteropServices.ComTypes.FILETIME Written;
  public uint Volume, SizeHigh, SizeLow, Links, IndexHigh, IndexLow;
 }
 [DllImport("kernel32.dll", SetLastError=true)]
 static extern bool GetFileInformationByHandle(SafeFileHandle h, out Info i);
 public static uint Links(SafeFileHandle h) {
  Info i; if(!GetFileInformationByHandle(h,out i))
   throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
  return i.Links;
 }
}
'@

function Assert-FileSystemObject($Item) {
 # Provider-added properties are absent on raw .NET Parent/Directory objects.
 if ($null -eq $Item -or $Item -isnot [IO.FileSystemInfo] -or
     ($Item -isnot [IO.FileInfo] -and $Item -isnot [IO.DirectoryInfo])) {
  throw 'Expected a FileInfo or DirectoryInfo filesystem object'
 }
}
function Assert-PlainAncestors([string]$Path) {
 if ([IO.Path]::GetFullPath($Path) -cne $Path) { throw "Noncanonical path: $Path" }
 $item = Get-Item -LiteralPath $Path -Force
 Assert-FileSystemObject $item
 if ($item.FullName -cne $Path) { throw "Resolved path mismatch: $Path" }
 while ($null -ne $item) {
  Assert-FileSystemObject $item
  if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point: $($item.FullName)" }
  if ($item -is [IO.DirectoryInfo]) { $item = $item.Parent } else { $item = $item.Directory }
 }
}
function Assert-Idle {
 foreach ($proc in @(Get-CimInstance Win32_Process)) {
  if ($proc.Name -match '^(java|javaw|gradle|flutter)\.exe$') { throw "Build-related process present: $($proc.Name), PID $($proc.ProcessId)" }
  if ($proc.Name -eq 'dart.exe') {
   # Conservative: require owner to close Dart tooling; never kill it here.
   throw "Dart process present, PID $($proc.ProcessId); close tooling manually and retry."
  }
 }
}
function Get-Tree([string]$Path) {
 Assert-PlainAncestors $Path
 $todo = [Collections.Generic.Stack[string]]::new()
 $todo.Push($Path)
 while ($todo.Count -gt 0) {
  $entry = Get-Item -LiteralPath $todo.Pop() -Force
  Assert-FileSystemObject $entry
  if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Descendant reparse point' }
  $entry
  if ($entry -is [IO.DirectoryInfo]) {
   foreach ($child in @(Get-ChildItem -LiteralPath $entry.FullName -Force)) { $todo.Push($child.FullName) }
  }
 }
}
function Git-Read([string]$Root, [string[]]$GitArgs) {
 $output = @(& git -C $Root @GitArgs 2>&1)
 if ($LASTEXITCODE -ne 0) { throw "Git verification failed in $Root" }
 return ($output -join "`n")
}
function Get-GitState([string]$Root) {
 $index = Git-Read $Root @('rev-parse','--path-format=absolute','--git-path','index')
 $status = Git-Read $Root @('status','--porcelain=v1','--untracked-files=all')
 # The only permitted new file during execution is this run's audit JSON.
 $status = ($status -split "`n" | Where-Object { $_ -notmatch '^\?\? docs/PHASE8_OWNER_CLEANUP_RUN_[A-Za-z0-9_-]+\.json$' }) -join "`n"
 [ordered]@{Root=$Root;Head=(Git-Read $Root @('rev-parse','HEAD'));
  IndexHash=(Get-FileHash -LiteralPath $index -Algorithm SHA256).Hash;
  Worktrees=(Git-Read $Root @('worktree','list','--porcelain'));Status=$status}
}
function Assert-GeneratedName([int]$Id, [string]$Root, [IO.FileInfo]$File) {
 $rel = if ($Id -eq 9) { $File.Name } else { $File.FullName.Substring($Root.Length + 1) }
 if ($rel -match '(?i)(^|[\\/])(\.git|node_modules|backup|backups|recovery|checkpoints?)([\\/]|$)' -or
     $File.Name -match '(?i)\.(apk|aab|jks|keystore|pem|p12|pfx|crt|cer|zip|bak|env|properties|ya?ml|toml|ini)$' -or
     $File.Name -match '(?i)^(\.env|key\.|local\.|google-services|firebase|signing)') { throw "Protected file: $rel" }
 $ok = $false
 if ($Id -in @(1,6,7,9)) { $ok = $File.Name -cmatch '^[a-f0-9]{32}\.cache\.dill\.track\.dill$' }
 elseif ($Id -eq 8) { $ok = $rel -cmatch '^jniLibs\\copyJniLibsflutterBuildRelease\\(arm64-v8a|armeabi-v7a|x86_64)\\libapp\.so$' }
 else {
  $ok = $File.Name -cin @('dart_plugin_registrant.dart','.filecache','app.dill','app.so',
    'build_hooks_result.json','link_hooks_result.json','gen_l10n_inputs_and_outputs.json',
    'native_assets.json','outputs.json','recorded_uses.json','dart_build_result.json') -or
    $File.Name -cmatch '^[a-z0-9_]+\.(d|stamp)$'
  # Only the reviewed release AOT names in targets 4/5 need a hyphen.
  # Full path, count, length and SHA-256 must still match the frozen inventory.
  if ($Id -in @(4,5) -and (
      $File.Name -cmatch '^flutter_android_aot_(bundle_)?release_android-(arm|arm64|x64)\.d$' -or
      $File.Name -cmatch '^android_aot_(bundle_)?release_android-(arm|arm64|x64)\.stamp$')) {
   $ok = $true
  }
  if ($File.Name -eq 'dart_plugin_registrant.dart' -and
      (Get-Content -LiteralPath $File.FullName -Raw) -notmatch '[Gg]enerated') { throw 'Unverified registrant' }
 }
 if (!$ok) { throw "Unexpected generated-cache filename: $rel" }
}
function Assert-Target($Target) {
 $id = [int]$Target.id
 if ($id -lt 1 -or $id -gt 9 -or $Target.path -cne $ExactPaths[$id-1]) { throw 'Target allowlist mismatch' }
 Assert-Idle
 $entries = @(Get-Tree $Target.path)
 $root = Get-Item -LiteralPath $Target.path -Force
 Assert-FileSystemObject $root
 if (($id -eq 9 -and $root -isnot [IO.FileInfo]) -or ($id -ne 9 -and $root -isnot [IO.DirectoryInfo])) { throw 'Target type changed' }
 $files = @($entries | Where-Object {$_ -is [IO.FileInfo]})
 $dirs = @($entries | Where-Object {$_ -is [IO.DirectoryInfo]} | ForEach-Object {$_.FullName} | Sort-Object)
 if (($dirs -join "`n") -cne (@($Target.dirs | Sort-Object) -join "`n")) { throw 'Directory inventory changed' }
 if ($files.Count -ne @($Target.files).Count) { throw 'File count changed' }
 $parent = [IO.Path]::GetDirectoryName($Target.path)
 [string]$repo = Git-Read $parent @('rev-parse','--show-toplevel')
 if ([string]::IsNullOrWhiteSpace($repo)) { throw 'Missing repository root' }
 $relative = $Target.path.Substring($repo.Length).TrimStart('\','/').Replace('\','/')
 if (![string]::IsNullOrEmpty((Git-Read $repo @('ls-files','--',$relative)))) { throw 'Git-tracked file in target' }
 foreach ($file in $files) {
  Assert-GeneratedName $id $Target.path $file
  $expected = @($Target.files | Where-Object {$_.path -ceq $file.FullName})
  if ($expected.Count -ne 1 -or $expected[0].bytes -ne $file.Length) { throw 'File inventory/size changed' }
  # Exclusive read denies other handles/writers; errors cause immediate failure.
  $stream = [IO.File]::Open($file.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
  try {
   if ([StudyBirdsOwnerFileInfo]::Links($stream.SafeFileHandle) -ne 1) { throw 'Hard-linked file' }
   $sha = [Security.Cryptography.SHA256]::Create()
   try { $actual = ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
   finally { $sha.Dispose() }
   if ($actual -cne $expected[0].sha256) { throw 'File content changed from frozen inventory' }
  } finally { $stream.Dispose() }
 }
}

# No caller-supplied paths, IDs, inventory or confirmation flags are accepted.
if (@($Frozen.targets).Count -ne 9) { throw 'Frozen target count invalid' }
Get-Command git -ErrorAction Stop | Out-Null
$Before = @($Frozen.repositories | ForEach-Object { Get-GitState $_ })
foreach ($item in $Frozen.protectedFiles) {
 Assert-PlainAncestors $item.path
 if ((Get-FileHash -LiteralPath $item.path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $item.sha256) { throw 'Protected APK/gate/config differs from reviewed state' }
}
foreach ($target in $Frozen.targets) {
 Assert-Target $target
 Write-Host ("DRY-RUN VERIFIED {0}: {1} ({2} logical bytes)" -f $target.id,$target.path,$target.logicalBytes)
}
Write-Host ('D free: {0:N3} GiB' -f ((Get-PSDrive D).Free / 1GB))
if (!$Execute) { Write-Host 'DRY RUN ONLY. No deletion or audit file written.'; return }

Write-Host 'Review all nine paths above. Quantis and all parents/siblings are excluded.'
$phrase = Read-Host 'Type exactly DELETE ONLY STUDY BIRDS TARGETS 1-9 to confirm manual deletion'
if ($phrase -cne 'DELETE ONLY STUDY BIRDS TARGETS 1-9') { throw 'Manual confirmation not supplied' }
$logPath = Join-Path $PSScriptRoot ('PHASE8_OWNER_CLEANUP_RUN_' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff') + '_' + [Guid]::NewGuid().ToString('N') + '.json')
if (Test-Path -LiteralPath $logPath) { throw 'Audit destination exists' }
$audit = [ordered]@{Mode='OWNER_MANUAL';Started=[DateTime]::UtcNow.ToString('o');InitialFree=(Get-PSDrive D).Free;GitBefore=$Before;Results=@();Completed=$false}
function Save-Audit { [IO.File]::WriteAllText($logPath,($audit | ConvertTo-Json -Depth 15),[Text.UTF8Encoding]::new($false)) }
Save-Audit
try {
 foreach ($target in $Frozen.targets) {
  # A second full preflight after confirmation, immediately before this target.
  Assert-Target $target
  $parent = [IO.Path]::GetDirectoryName($target.path)
  $siblings = @(Get-ChildItem -LiteralPath $parent -Force | Where-Object {$_.FullName -cne $target.path} | ForEach-Object {$_.Name} | Sort-Object)
  $record = [ordered]@{Id=$target.id;Path=$target.path;Status='STARTED';FreeBefore=(Get-PSDrive D).Free;FreeAfter=$null;ObservedReclaimedBytes=$null}
  $audit.Results += $record
  Save-Audit
  # Never use recursive deletion: only frozen exact files and empty directories.
  foreach ($file in $target.files) {
   Assert-PlainAncestors $file.path
   $info = Get-Item -LiteralPath $file.path -Force
   Assert-FileSystemObject $info
   if ($info -isnot [IO.FileInfo]) { throw 'Expected regular file before deletion' }
   $stream = [IO.File]::Open($file.path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
   try {
    if ([StudyBirdsOwnerFileInfo]::Links($stream.SafeFileHandle) -ne 1) { throw 'File became hard-linked' }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $actual = ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
    if ($actual -cne $file.sha256) { throw 'File changed during cleanup' }
   } finally { $stream.Dispose() }
   Remove-Item -LiteralPath $file.path -Force -ErrorAction Stop
  }
  foreach ($dir in @($target.dirs | Sort-Object Length -Descending)) {
   Assert-PlainAncestors $dir
   $info = Get-Item -LiteralPath $dir -Force
   Assert-FileSystemObject $info
   if ($info -isnot [IO.DirectoryInfo]) { throw 'Expected directory before deletion' }
   if (@(Get-ChildItem -LiteralPath $dir -Force).Count -ne 0) { throw 'Directory no longer empty; refusing recursive deletion' }
   [IO.Directory]::Delete($dir,$false)
  }
  $record.FreeAfter = (Get-PSDrive D).Free
  $record.ObservedReclaimedBytes = $record.FreeAfter - $record.FreeBefore
  if (Test-Path -LiteralPath $target.path) { throw 'Target still exists' }
  $afterSiblings = @(Get-ChildItem -LiteralPath $parent -Force | ForEach-Object {$_.Name} | Sort-Object)
  if (($siblings -join "`n") -cne ($afterSiblings -join "`n")) { throw 'Parent/sibling inventory changed' }
  $record.Status = 'DELETED'
  Save-Audit
 }
 $audit.Completed = $true
} catch {
 $audit['Failure'] = $_.Exception.Message
 foreach ($entry in $audit.Results) {
  if ($entry.Status -eq 'STARTED') {
   $entry.Status = 'STOPPED_REVIEW_REQUIRED'
   $entry.FreeAfter = (Get-PSDrive D).Free
   $entry.ObservedReclaimedBytes = $entry.FreeAfter - $entry.FreeBefore
  }
 }
 foreach ($pending in $Frozen.targets) {
  if (@($audit.Results | Where-Object {$_.Id -eq $pending.id}).Count -eq 0) {
   $audit.Results += [ordered]@{Id=$pending.id;Path=$pending.path;Status='SKIPPED_AFTER_FAILURE';Reason=$audit.Failure}
  }
 }
 # Abort remaining targets; never repair, retry, rebaseline or roll back by deleting.
 throw
} finally {
 $audit['FinalFree'] = (Get-PSDrive D).Free
 $audit['ObservedTotalDelta'] = $audit.FinalFree - $audit.InitialFree
 $audit['EightGiBAchieved'] = $audit.FinalFree -ge 8GB
 $After = @($Frozen.repositories | ForEach-Object { Get-GitState $_ })
 $audit['GitAfter'] = $After
 $audit['GitUnchanged'] = ($Before | ConvertTo-Json -Depth 8 -Compress) -ceq ($After | ConvertTo-Json -Depth 8 -Compress)
 $audit['ProtectedFilesUnchanged'] = @($Frozen.protectedFiles | Where-Object { (Get-FileHash -LiteralPath $_.path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $_.sha256 }).Count -eq 0
 Save-Audit
 Write-Host "Audit: $logPath"
 if (!$audit.GitUnchanged -or !$audit.ProtectedFilesUnchanged) { Write-Warning 'Integrity discrepancy: stop and review the audit.' }
}
