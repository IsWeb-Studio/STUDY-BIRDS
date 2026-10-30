require("dotenv").config();
const connectDatabase = require("../config/db");
const User = require("../models/User");
const StudentProfile = require("../models/StudentProfile");
const Country = require("../models/Country");
const University = require("../models/University");
const Program = require("../models/Program");
const Application = require("../models/Application");
const Document = require("../models/Document");
const Testimonial = require("../models/Testimonial");
const Notification = require("../models/Notification");
const Recognition = require("../models/Recognition");
const Faq = require("../models/Faq");

const countriesData = [
  { name: "Canada", code: "CA", featured: true, description: "A welcoming destination with strong post-study pathways.", universityCount: 24, specialtyCount: 180, averageTuition: 18000 },
  { name: "United States", code: "US", featured: true, description: "Top-ranked institutions and broad program variety.", universityCount: 40, specialtyCount: 260, averageTuition: 24000 },
  { name: "United Kingdom", code: "GB", featured: true, description: "Fast-track master's programs and global recognition.", universityCount: 28, specialtyCount: 190, averageTuition: 21000 },
  { name: "Germany", code: "DE", featured: true, description: "High-quality education with strong engineering options.", universityCount: 18, specialtyCount: 140, averageTuition: 12000 },
  { name: "Australia", code: "AU", featured: true, description: "Career-focused programs in vibrant international cities.", universityCount: 20, specialtyCount: 150, averageTuition: 22000 },
  { name: "Ireland", code: "IE", featured: true, description: "Fast-growing tech ecosystem and student-friendly culture.", universityCount: 14, specialtyCount: 95, averageTuition: 17000 },
  { name: "Turkey", code: "TR", featured: true, description: "Affordable tuition with a rich cultural experience.", universityCount: 30, specialtyCount: 210, averageTuition: 9000 },
];

const universitiesData = [
  ["North Shore University", "Canada", "Vancouver"],
  ["Maple Gate Institute", "Canada", "Toronto"],
  ["Atlantic State University", "United States", "Boston"],
  ["Crestline Tech", "United States", "Seattle"],
  ["Kingston Metropolitan", "United Kingdom", "London"],
  ["Riverside College London", "United Kingdom", "Manchester"],
  ["Berlin School of Innovation", "Germany", "Berlin"],
  ["Southern Coast University", "Australia", "Sydney"],
  ["Dublin International College", "Ireland", "Dublin"],
  ["Bosporus Global University", "Turkey", "Istanbul"],
];

const programTemplates = [
  ["Computer Science", "Bachelor", "Technology"],
  ["Data Analytics", "Master", "Technology"],
  ["Business Administration", "Bachelor", "Business"],
  ["International Relations", "Master", "Social Sciences"],
  ["Mechanical Engineering", "Bachelor", "Engineering"],
  ["Cybersecurity", "Master", "Technology"],
];

const testimonialData = [
  { studentName: "Lina Hassan", destination: "Canada", quote: "COVEY turned a confusing process into a clear plan I could trust." },
  { studentName: "Omar Nabil", destination: "Germany", quote: "I found a program that matched both my budget and career goals." },
  { studentName: "Priya Menon", destination: "Ireland", quote: "The dashboard made every deadline and document easy to manage." },
  { studentName: "Yousef Adel", destination: "UK", quote: "I applied with confidence because everything was organized in one place." },
  { studentName: "Maya Salem", destination: "Australia", quote: "The platform felt modern, supportive, and built around real student needs." },
];

const recognitionData = [
  { title: "ICEF Agency Status", link: "https://studybirds.net", featured: true, sortOrder: 1 },
  { title: "Student Success Recognition", link: "https://studybirds.net", featured: true, sortOrder: 2 },
  { title: "Trusted Recruitment Partner", link: "https://studybirds.net", featured: true, sortOrder: 3 },
];

const faqData = [
  {
    question: "How do I choose the right country to study in?",
    answer: "Compare tuition, available programs, language, visa requirements, and future career opportunities before applying.",
    featured: true,
    sortOrder: 1,
  },
  {
    question: "What documents are usually required to apply?",
    answer: "Most universities ask for your passport, academic transcripts or certificates, and proof of language level if required.",
    featured: true,
    sortOrder: 2,
  },
  {
    question: "Can COVEY help me track my application after submission?",
    answer: "Yes. Students can organize documents, submit applications, and follow status updates from one place.",
    featured: true,
    sortOrder: 3,
  },
];

const buildArticleHeadings = (prefix, items) => items.map((item) => `${prefix} ${item}`);
const buildArticleBodies = (subject, items) => items.map((item) => `${subject} ${item}.`);

const seed = async () => {
  await connectDatabase();

  await Promise.all([
    Notification.deleteMany({}),
    Application.deleteMany({}),
    Document.deleteMany({}),
    Program.deleteMany({}),
    University.deleteMany({}),
    Country.deleteMany({}),
    StudentProfile.deleteMany({}),
    User.deleteMany({}),
    Testimonial.deleteMany({}),
    Recognition.deleteMany({}),
    Faq.deleteMany({}),
  ]);

  const admin = await User.create({
    name: "Admin User",
    email: "admin@studybirds.net",
    password: "Admin123!",
    role: "admin",
  });

  const students = await User.create([
    { name: "Ava Carter", email: "ava@student.com", password: "Student123!", role: "student" },
    { name: "Noah Kim", email: "noah@student.com", password: "Student123!", role: "student" },
    { name: "Sara Malik", email: "sara@student.com", password: "Student123!", role: "student" },
  ]);

  await User.create({
    name: "Partner User",
    email: "partner@studybirds.net",
    password: "Partner123!",
    role: "partner",
  });

  await StudentProfile.insertMany(
    students.map((student, index) => ({
      user: student._id,
      phone: `+1000000000${index}`,
      nationality: ["Egypt", "India", "Jordan"][index],
      currentEducation: "Bachelor's Degree",
      gpa: ["3.6", "3.8", "3.7"][index],
      intake: ["Fall 2026", "Spring 2027", "Fall 2026"][index],
      targetCountries: ["Canada", "Germany", "Australia"].slice(index, index + 2),
    }))
  );

  const countries = await Country.insertMany(
    countriesData.map((country) => ({
      ...country,
      articleTitle: `${country.name} study guide`,
      articleHeadings: buildArticleHeadings(`About ${country.name}:`, [
        "Why students choose it",
        "Popular cities",
        "University options",
        "Tuition expectations",
        "Living costs",
        "Visa preparation",
        "Next application step",
      ]),
      articleBodies: buildArticleBodies(`${country.name} offers guidance on`, [
        "the main reasons students choose this destination",
        "the most popular cities for study and lifestyle",
        "the variety of universities available",
        "expected tuition ranges and budgeting ideas",
        "daily living costs and accommodation planning",
        "visa preparation steps and document checks",
        "the best next move before starting an application",
      ]),
    }))
  );
  const countryMap = Object.fromEntries(countries.map((country) => [country.name, country]));

  const universities = await University.insertMany(
    universitiesData.map(([name, countryName, city], index) => ({
      name,
      country: countryMap[countryName]._id,
      city,
      overview: `${name} offers career-ready education for international students.`,
      articleTitle: `${name} university guide`,
      articleHeadings: buildArticleHeadings(`${name}:`, [
        "Campus environment",
        "Academic strengths",
        "International student support",
        "Tuition overview",
        "City life",
        "Admission expectations",
        "Programs to explore",
      ]),
      articleBodies: buildArticleBodies(`${name} highlights`, [
        "what students can expect from the campus environment",
        "the academic areas where the university stands out",
        "support services available for international students",
        "a broad picture of tuition and study costs",
        "the student experience in the surrounding city",
        "key expectations before applying",
        "useful programs worth exploring first",
      ]),
      ranking: 50 + index * 12,
      tuitionRange: { min: 12000 + index * 500, max: 24000 + index * 800 },
      featured: index < 5,
      isPartnerInstitution: index % 2 === 0,
    }))
  );

  const programs = [];
  universities.forEach((university, universityIndex) => {
    programTemplates.forEach(([title, degreeLevel, fieldOfStudy], templateIndex) => {
      if (programs.length < 30) {
        programs.push({
          university: university._id,
          slug: `${title}-${degreeLevel}-${universityIndex}-${templateIndex}`
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, "-")
            .replace(/^-|-$/g, ""),
          title: `${title} ${templateIndex % 2 === 0 ? "Pathway" : "Advanced Track"}`,
          degreeLevel,
          fieldOfStudy,
          duration: degreeLevel === "Bachelor" ? "4 years" : "2 years",
          tuition: 14000 + universityIndex * 1200 + templateIndex * 900,
          applicationDeadline: new Date(2026, templateIndex + 2, 15),
          intake: templateIndex % 2 === 0 ? "Fall 2026" : "Spring 2027",
          requirements: ["Academic transcripts", "Passport", "English proficiency"],
          summary: `A ${degreeLevel.toLowerCase()} program focused on ${fieldOfStudy.toLowerCase()} outcomes.`,
          articleTitle: `${title} article overview`,
          articleHeadings: buildArticleHeadings(`${title}:`, [
            "Program focus",
            "Skills gained",
            "Study duration",
            "Tuition planning",
            "Admission requirements",
            "Career pathways",
            "How to apply",
          ]),
          articleBodies: buildArticleBodies(`${title} explains`, [
            "what this program focuses on academically",
            "the practical and academic skills students develop",
            "how long the study path usually takes",
            "how to think about tuition and budget planning",
            "what documents and requirements matter most",
            "possible career directions after graduation",
            "the main steps to start the application",
          ]),
          featured: universityIndex < 3 && templateIndex < 2,
          popularity: 100 - universityIndex * 3 - templateIndex,
        });
      }
    });
  });

  const createdPrograms = await Program.insertMany(programs.slice(0, 30));
  await Testimonial.insertMany(testimonialData);
  await Recognition.insertMany(recognitionData);
  await Faq.insertMany(faqData);

  await Application.create({
    student: students[0]._id,
    program: createdPrograms[0]._id,
    university: universities[0]._id,
    notes: "Interested in scholarship options.",
    status: "under-review",
    statusTimeline: [
      { status: "submitted", note: "Application submitted", changedBy: students[0]._id },
      { status: "under-review", note: "Application reviewed by admissions", changedBy: admin._id },
    ],
    reviewedBy: admin._id,
  });

  console.log("Seed completed");
  process.exit(0);
};

seed().catch((error) => {
  console.error(error);
  process.exit(1);
});
