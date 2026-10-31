const { test } = require('node:test');
const assert = require('node:assert/strict');
test('audio upload rejects video disguises and overlong tracks and encodes MP3', async () => {
  process.env.CLOUDINARY_CLOUD_NAME = 'audio-test'; process.env.CLOUDINARY_API_KEY = 'test'; process.env.CLOUDINARY_API_SECRET = 'test';
  const { cloudinary } = require('../src/config/cloudinary');
  const { uploadStoryAudio, validateAudio } = require('../src/utils/storyAudioUpload');
  const stream = cloudinary.uploader.upload_stream, destroy = cloudinary.uploader.destroy;
  let options, deleted;
  let asset = { duration: 15, public_id: 'audio', secure_url: 'https://example.test/a.mp3' };
  cloudinary.uploader.upload_stream = (config, done) => { options = config; return { end: () => done(null, asset) }; };
  cloudinary.uploader.destroy = async id => { deleted = id; };
  const file = { originalname: 'music.mp3', buffer: Buffer.from('ID3abcdefghijklmno') };
  try {
    assert.equal((await uploadStoryAudio(file, 'owner')).duration, 15);
    assert.equal(options.format, 'mp3'); assert.equal(options.resource_type, 'video'); assert.equal(options.folder, 'story-audio/owner');
    asset = { ...asset, duration: 61 };
    await assert.rejects(uploadStoryAudio(file, 'owner'), e => e.statusCode === 400); assert.equal(deleted, 'audio');
    asset = { ...asset, duration: 10, width: 300, height: 200 };
    await assert.rejects(uploadStoryAudio(file, 'owner'), e => e.statusCode === 400);
    assert.throws(() => validateAudio({ ...file, buffer: Buffer.from('this is not audio') }), e => e.statusCode === 415);
  } finally { cloudinary.uploader.upload_stream = stream; cloudinary.uploader.destroy = destroy; }
});
