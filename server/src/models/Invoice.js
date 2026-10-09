const mongoose = require("mongoose");

const invoiceSchema = new mongoose.Schema(
  {
    student: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    application: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Application",
    },
    invoiceNumber: {
      type: String,
      required: true,
      trim: true,
      unique: true,
    },
    description: {
      type: String,
      required: true,
      trim: true,
    },
    amount: {
      type: Number,
      required: true,
      min: 0,
    },
    dueDate: Date,
    status: {
      type: String,
      enum: ["unpaid", "pending-confirmation", "paid", "rejected"],
      default: "unpaid",
      index: true,
    },
    invoiceUrl: String,
    walletCreditApplied: { type: Number, default: 0, min: 0 },
    category: {
      type: String,
      enum: ["application-fee", "tuition", "service", "housing", "other"],
      default: "other",
    },
    serviceRequest: { type: mongoose.Schema.Types.ObjectId, ref: 'ServiceRequest', default: null },
    accommodationBooking: { type: mongoose.Schema.Types.ObjectId, ref: 'AccommodationBooking', default: null },
    adminNote: String,
    reviewedAt: Date,
    reviewedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },
    stripeSessionId: { type: String },
    currency: { type: String, default: 'USD', uppercase: true },
    crmIdentity: {owner:{type:mongoose.Schema.Types.ObjectId,ref:'User'},companyId:String,recordId:String},
    crmPaidAmount: {type:Number,default:0,min:0},
    crmPaymentHistory: [{amount:Number,changedAt:{type:Date,default:Date.now},changedBy:{type:mongoose.Schema.Types.ObjectId,ref:'User'}}],
    stripeCheckoutExpiresAt: Date,
    stripeExpectedAmount: Number,
    stripeExpectedCurrency: String,
    stripeCheckoutUrl: String,
  },
  { timestamps: true }
);

invoiceSchema.index({ student: 1, createdAt: -1 });
invoiceSchema.index({'crmIdentity.owner':1,'crmIdentity.companyId':1,'crmIdentity.recordId':1},{unique:true,partialFilterExpression:{'crmIdentity.recordId':{$type:'string'}}});

module.exports = mongoose.model("Invoice", invoiceSchema);
