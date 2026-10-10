const mongoose = require('mongoose');
module.exports = mongoose.model('CrmSyncOperation',new mongoose.Schema({
  _id:String, recordId:String, digest:String, before:mongoose.Schema.Types.Mixed,
  after:mongoose.Schema.Types.Mixed, actor:mongoose.Schema.Types.ObjectId, createdAt:Date,
}, {versionKey:false}));
