const buildProgramDegreeFilter = (degree) => {
  if (degree === 'Master') return { $in: ['Master', 'Non-Thesis Master', 'Thesis Master'] };
  if (degree === 'Technical Institute/Diploma') return { $in: ['Technical Institute', 'Diploma'] };
  return degree;
};

module.exports = { buildProgramDegreeFilter };
