// #PRD-Admin: Global unified search across students, applications, tickets, and service requests
const mongoose = require('mongoose');
const asyncHandler = require('../utils/asyncHandler');
const User = require('../models/User');
const Application = require('../models/Application');
const SupportTicket = require('../models/SupportTicket');
const ServiceRequest = require('../models/ServiceRequest');
const Program = require('../models/Program');
const University = require('../models/University');

const MAX_RESULTS_PER_TYPE = 5;

const unifiedSearch = asyncHandler(async (req, res) => {
  const q = String(req.query.q || '').trim();
  if (!q || q.length < 2) return res.status(400).json({ message: 'أدخل كلمة بحث (حرفين على الأقل)' });
  if (q.length > 200) return res.status(400).json({ message: 'نص البحث طويل جدًا' });

  const rx = new RegExp(q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
  const isId = mongoose.isValidObjectId(q);

  const [students, applications, tickets, requests, programs, universities] = await Promise.all([
    // Students: name or email match
    User.find({ role: 'student', isActive: true, $or: [{ name: rx }, { email: rx }] })
      .select('name email').limit(MAX_RESULTS_PER_TYPE).lean(),

    // Applications: by student name or application status or program title
    Application.find({
      $or: [
        ...(isId ? [{ _id: q }] : []),
        { 'program.title': rx },
      ],
    }).populate('student', 'name email').populate('program', 'title').select('status detailedStatus createdAt')
      .limit(MAX_RESULTS_PER_TYPE).lean()
      .catch(() => []),

    // Support tickets: title/description
    SupportTicket.find({ $or: [{ subject: rx }, { message: rx }] })
      .populate('student', 'name email').select('subject status createdAt isEmergency')
      .limit(MAX_RESULTS_PER_TYPE).lean(),

    // Service requests: service title or notes
    ServiceRequest.find({ $or: [{ serviceTitle: rx }, { notes: rx }] })
      .populate('student', 'name email').select('serviceTitle status createdAt')
      .limit(MAX_RESULTS_PER_TYPE).lean(),

    // Programs
    Program.find({ title: rx }).populate('university', 'name').select('title degreeLevel language tuition')
      .limit(MAX_RESULTS_PER_TYPE).lean(),

    // Universities
    University.find({ name: rx }).select('name country').limit(MAX_RESULTS_PER_TYPE).lean(),
  ]);

  // Also search students by exact ID if valid
  const studentById = isId
    ? await User.findOne({ _id: q, role: 'student' }).select('name email').lean().catch(() => null)
    : null;

  const allStudents = studentById
    ? [studentById, ...students.filter(s => String(s._id) !== q)].slice(0, MAX_RESULTS_PER_TYPE)
    : students;

  res.json({
    query: q,
    results: {
      students: allStudents,
      applications,
      supportTickets: tickets,
      serviceRequests: requests,
      programs,
      universities,
    },
    total: allStudents.length + applications.length + tickets.length + requests.length + programs.length + universities.length,
  });
});

module.exports = { unifiedSearch };
