const { test } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');

test('story publish route awards admin story points once without advancing game streak', async () => {
  process.env.JWT_SECRET = 'synthetic-story-points-test';
  const User = require('../src/models/User');
  const { Story, StoryStats } = require('../src/models/Stories');
  const { Session } = require('../src/models/MobileWorkspace');

  const original = {
    startSession: mongoose.startSession,
    userFindById: User.findById,
    sessionExists: Session.exists,
    storyFindOne: Story.findOne,
    storyCreate: Story.create,
    statsFindOneAndUpdate: StoryStats.findOneAndUpdate,
  };
  const user = { _id: 'synthetic-admin-id', role: 'admin', isActive: true, tokenVersion: 0 };
  const stats = {
    user: user._id,
    total_points: 40,
    gameStreakDays: 2,
    gameLongestStreak: 2,
    lastGameAt: new Date(Date.now() - 24 * 60 * 60 * 1000),
    lastGameDay: '2030-01-01',
    gameActivityDays: [],
    async save() {},
  };
  const savedStories = new Map();
  let nextId = 0;
  let server;
  try {
    mongoose.startSession = async () => ({
      async withTransaction(run) { await run(); },
      async endSession() {},
    });
    User.findById = () => ({ async select() { return user; } });
    Session.exists = async () => false;
    Story.findOne = filter => ({
      async session() {
        const record = savedStories.get(filter.operationId);
        return record || null;
      },
    });
    Story.create = async ([record]) => {
      const story = { ...record, id: `synthetic-story-${++nextId}` };
      savedStories.set(record.operationId, story);
      return [story];
    };
    StoryStats.findOneAndUpdate = async () => stats;

    const app = express();
    app.use(express.json());
    app.use('/stories', require('../src/routes/storyRoutes'));
    app.use(require('../src/middleware/errorMiddleware').errorHandler);
    server = await new Promise(resolve => {
      const listener = app.listen(0, '127.0.0.1', () => resolve(listener));
    });
    const token = jwt.sign({ userId: user._id }, process.env.JWT_SECRET);
    async function publish(operationId, text) {
      const response = await fetch(`http://127.0.0.1:${server.address().port}/stories`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ operationId, text, audience: 'students' }),
      });
      return { status: response.status, body: await response.json() };
    }

    const first = await publish('synthetic-admin-post-01', 'First test story');
    assert.equal(first.status, 201);
    assert.equal(first.body.awarded, 100);
    assert.equal(first.body.progress.total_points, 140);
    assert.equal(first.body.progress.streak_days, 2);
    assert.equal(stats.gameStreakDays, 2);
    assert.equal(stats.total_points, 140);

    const second = await publish('synthetic-admin-post-02', 'Second same-day story');
    assert.equal(second.status, 201);
    assert.equal(second.body.awarded, 0);
    assert.equal(second.body.progress.total_points, 140);

    const replay = await publish('synthetic-admin-post-01', 'Replay');
    assert.equal(replay.status, 201);
    assert.equal(replay.body.awarded, 0);
    assert.equal(replay.body.progress.total_points, 140);
    assert.equal(savedStories.size, 2);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    mongoose.startSession = original.startSession;
    User.findById = original.userFindById;
    Session.exists = original.sessionExists;
    Story.findOne = original.storyFindOne;
    Story.create = original.storyCreate;
    StoryStats.findOneAndUpdate = original.statsFindOneAndUpdate;
  }
});
