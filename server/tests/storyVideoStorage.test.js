const { test } = require('node:test');
const assert = require('node:assert/strict');
test('story video storage encodes MP4/H264 and removes invalid or overlong uploads', async () => {
  process.env.CLOUDINARY_CLOUD_NAME = 'story-video-storage-test';
  process.env.CLOUDINARY_API_KEY = 'test'; process.env.CLOUDINARY_API_SECRET = 'test';
  const { cloudinary } = require('../src/config/cloudinary');
  const { uploadStoryVideo } = require('../src/utils/storyVideoUpload');
  const originalStream = cloudinary.uploader.upload_stream, originalDestroy = cloudinary.uploader.destroy;
  let options, deleted;
  let result = { duration: 12, width: 1080, height: 1920, public_id: 'created-video', secure_url: 'https://res.cloudinary.com/test/video/upload/clip.mp4' };
  cloudinary.uploader.upload_stream = (config, done) => { options = config; return { end: () => done(null, result) }; };
  cloudinary.uploader.destroy = async (id, config) => { deleted = { id, config }; };
  const file = { buffer: Buffer.from('000000146674797069736f6d00000000', 'hex') };
  try {
    const video = await uploadStoryVideo(file, 'owner');
    assert.equal(video.duration, 12); assert.equal(options.resource_type, 'video'); assert.equal(options.format, 'mp4');
    assert.equal(options.folder, 'story-videos/owner'); assert.equal(options.transformation[0].video_codec, 'h264');
    result = { ...result, duration: 61 };
    await assert.rejects(uploadStoryVideo(file, 'owner'), e => e.statusCode === 400);
    assert.deepEqual(deleted, { id: 'created-video', config: { resource_type: 'video' } });
    result = { ...result, duration: 10, width: undefined };
    await assert.rejects(uploadStoryVideo(file, 'owner'), e => e.statusCode === 400);
    await assert.rejects(uploadStoryVideo({ buffer: Buffer.from('invalid-video-data') }, 'owner'), e => e.statusCode === 415);
  } finally { cloudinary.uploader.upload_stream = originalStream; cloudinary.uploader.destroy = originalDestroy; }
});
