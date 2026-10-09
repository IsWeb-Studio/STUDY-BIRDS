const { test } = require("node:test");
const assert = require("node:assert/strict");
const mongoose = require("mongoose");
const Program = require("../src/models/Program");

const university = new mongoose.Types.ObjectId();
const makeProgram = (language, extra = {}) => new Program({
  title: "هندسة البرمجيات",
  university,
  degreeLevel: "Bachelor",
  fieldOfStudy: "Engineering",
  language,
  ...extra,
});

test("the same program at the same university supports separate language offerings", async () => {
  const programs = ["English", "Turkish", "العربية", "الروسية", "30% English + 70% Turkish", "30% Turkish + 70% English"].map((language) => makeProgram(language));
  await Promise.all(programs.map((program) => program.validate()));
  assert.equal(new Set(programs.map((program) => program.slug)).size, programs.length);
  for (const program of programs) {
    assert.equal(program.title, "هندسة البرمجيات");
    assert.equal(String(program.university), String(university));
    assert.ok(program.slug.endsWith(String(program._id)));
  }
});

test("different custom languages stay distinct when normalized to the same slug text", async () => {
  const programs = [makeProgram("中文"), makeProgram("日本語")];
  await Promise.all(programs.map((program) => program.validate()));
  assert.notEqual(programs[0].slug, programs[1].slug);
});

test("existing program links stay stable when language or title changes", async () => {
  const program = makeProgram("English", { slug: "existing-program-link" });
  await program.validate();
  program.language = "Turkish";
  program.title = "Updated title";
  await program.validate();
  assert.equal(program.slug, "existing-program-link");
});
