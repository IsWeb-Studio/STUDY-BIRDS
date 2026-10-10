const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  _id: String, owner: {type:mongoose.Schema.Types.ObjectId,required:true},
  companyId: {type:String,required:true}, resource: {type:String,required:true}, entityId: {type:String,required:true},
  revision: {type:Number,default:0}, value: mongoose.Schema.Types.Mixed,
  deleted: {type:Boolean,default:false}, updatedAt: Date,
}, {versionKey:false});
schema.index({owner:1,companyId:1,resource:1,entityId:1},{unique:true});
module.exports = mongoose.model('CrmSyncRecord',schema);
