# Student stories

The Flutter home dashboard uses `/api/stories`. All endpoints require an active student session. Points belong to `StoryStats`, independently of other reward systems.

## Friends and story audience

Stories appear to their author and accepted friends. Pending requests do not grant access. Feed filtering, seen events and love rewards all enforce this relationship on the server; removal revokes subsequent API access without deleting previously earned points. Existing students start with no friendships; existing stories are not automatically shared with every student.

Authenticated active students use `/api/friends`:

- `GET /?kind=friends|incoming|outgoing&before=<cursor>`: 30 people per page, list counts and `nextCursor`.
- `GET /search?q=<name>&before=<cursor>`: literal name search, 2–60 characters, 30 results per page. Responses contain only public name, avatar, id, points and relationship state; no email or phone.
- `POST /:userId/request`: send a request, capped at 50 actions per day. Duplicate and crossed requests retain a single relationship and never implicitly accept.
- `POST /:userId/accept`: only the recipient can accept; repeat acceptance is safe.
- `DELETE /:userId`: remove a friend, cancel an outgoing request or decline an incoming request. A caller can modify only their own relationship with this student.

The app exposes friends from the dashboard stories section and the profile. Friendship changes refresh the local story feed. Search is debounced and ignores old responses after a query changes.

- `GET /progress`: balance, effective streak, freeze/reset deadlines, daily task completion, ring threshold and business time zone. Expired streaks are persisted lazily with a conditional update; total points never reset.
- `PUT /preferences`: `{scoreEmoji}` saves one of the supported score emojis on the authenticated student's account. Balances cannot be edited with this endpoint. The selected emoji is returned by `/progress` and defaults to fire.
- `GET /?before=<story ObjectId>`: newest active stories, 60 per page, with author points and per-viewer seen/love state. `nextCursor` loads the next page. Stories expire after 24 hours.
- `POST /image`: JPEG/PNG/WebP multipart `file`, up to 5 MB, uploaded to the student's Cloudinary folder.
- `POST /`: `{text, imageUrl, operationId}`. Text (up to 1,000 characters), image, or both. A stable operation ID prevents duplicated posts and rewards after retries. Image URLs must belong to the student's upload folder in the configured Cloudinary account.
- `POST /:id/seen`: idempotent viewer state.
- `POST /:id/love`: permanent love; no self-loves. Unique `(story,user)` awards the author 50 once, and the giver 5 for their first 10 distinct loves per local calendar day. Further loves still work and reward the author.

The first story on each local calendar day earns 100 points and increments the streak once. Every post refreshes the activity deadline. At 24 hours without a post, the streak becomes `ice_cold`; at 36 hours it resets. A post during grace preserves continuity. Each completed block of seven consecutive posting days awards 300 points. At 10,000 points, the orange achievement ring remains unlocked independently of view state or streak expiry.

At 100,000 points the outer ring becomes purple; at 200,000 a cosmetic achievement check appears beside the profile name and on story avatars. The inner seen/unseen ring stays independent. These levels use total points, not consecutive posting days.

Winker awards an active student 10 points once per local calendar day when a server-authorized room response is in actual `playing`/`voting` state. Multiplayer and private practice share the same daily cap. Opening the game, waiting in the lobby, revealing cards, spectators, bots and revisiting finished results do not earn points. The atomic, unique-user conditional update survives concurrent requests and retries. Gameplay never changes posting streak days or their deadlines. `GET /progress` includes `playedToday`, `ringTier` and `cosmeticVerified`; Winker room responses include `pointsAwarded`.

`STORY_TIME_ZONE` defaults to `Europe/Istanbul` (use an IANA time zone). Existing Cloudinary environment variables enable image uploads. The database must support transactions (MongoDB Atlas or a replica set). Story, interaction and statistics indexes must be enabled/created; normal Mongoose index initialization creates them. Transactions commit stories, interactions and balances together, and retry conflicts. Story records remain stored after their display expiry for durable replay protection.

Validation:

```powershell
$env:STUDY_BIRDS_TEST_TOOLS = '<directory containing node_modules/mongodb-memory-server-core>'
# Optional: point MONGOMS_SYSTEM_BINARY at an existing local mongod executable.
node --test tests/storyRules.test.js tests/stories.test.js
```

In the Flutter project, run `flutter test --no-pub test/story_widgets_test.dart`. Integration tests use an isolated local replica set and never connect to production.
