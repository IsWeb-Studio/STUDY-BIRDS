const express = require('express');
const run = require('../utils/asyncHandler');
const { protect } = require('../middleware/authMiddleware');
const readState = require('../utils/sharedReadState');
const router = express.Router();
router.use(protect, (req, res, next) => {
  res.set('Cache-Control', 'no-store');
  if (!['admin', 'employee'].includes(req.user.role)) return res.status(403).json({ message: 'حالة القراءة الإدارية للموظفين فقط' });
  next();
});
router.get('/', run(async (req, res) => res.json(await readState.summary(req.user, typeof req.query.resources === 'string' ? req.query.resources.split(',').filter(Boolean) : undefined))));
router.get('/:resource/unread', run(async (req, res) => res.json(await readState.unread(req.user, req.params.resource))));
router.get('/:resource/:id/detail', run(async (req, res) => res.json(await readState.detail(req.user, req.params.resource, req.params.id))));
router.post('/:resource/states', run(async (req, res) => res.json(await readState.states(req.user, req.params.resource, req.body.ids))));
router.post('/:resource/:id/read', run(async (req, res) => res.json(await readState.markRead(req.user, req.params.resource, req.params.id, req.body.version))));
module.exports = router;
