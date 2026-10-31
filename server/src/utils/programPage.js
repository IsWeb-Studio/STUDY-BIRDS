const University = require('../models/University');
const Country = require('../models/Country');
const Program = require('../models/Program');
const projection = fields => Object.fromEntries(fields.split(' ').map(field => [field, 1]));
const programFields = 'title titleEn slug degreeLevel fieldOfStudy fieldsOfStudy language duration tuition partnerTuition applicationDeadline intake summary summaryEn popularity coverImage university featured createdAt updatedAt __v';
const universityFields = 'name nameEn slug city language ranking logo tuitionRange country featured isPartnerInstitution';
const countryFields = 'name nameAr slug code heroImage featured';

// Join only the bounded page, rather than making two serial populate roundtrips.
function readProgramPage(query, sort, skip, limit) {
  return Program.aggregate([
    { $match: query }, { $sort: sort }, { $skip: skip }, { $limit: limit },
    { $project: projection(programFields) },
    { $lookup: {
      from: University.collection.name, localField: 'university', foreignField: '_id', as: 'university',
      pipeline: [
        { $project: projection(universityFields) },
        { $lookup: { from: Country.collection.name, localField: 'country', foreignField: '_id', as: 'country', pipeline: [{ $project: projection(countryFields) }] } },
        { $set: { country: { $ifNull: [{ $arrayElemAt: ['$country', 0] }, null] } } },
      ],
    } },
    { $set: { university: { $ifNull: [{ $arrayElemAt: ['$university', 0] }, null] } } },
  ]);
}
module.exports = { readProgramPage };
