const mongoose = require("mongoose");

const favoriteItemSchema = new mongoose.Schema(
  {
    student: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    itemType: {
      type: String,
      enum: ["university", "program", "article"],
      required: true,
      index: true,
    },
    university: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "University",
    },
    program: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Program",
    },
    // Article favorites store slug + title inline (articles are public content,
    // not a separate DB collection the server needs to populate).
    articleSlug: String,
    articleTitle: String,
    notes: String,
  },
  { timestamps: true }
);

favoriteItemSchema.index({ student: 1, itemType: 1, university: 1 }, { unique: true, partialFilterExpression: { itemType: "university" } });
favoriteItemSchema.index({ student: 1, itemType: 1, program: 1 }, { unique: true, partialFilterExpression: { itemType: "program" } });
favoriteItemSchema.index({ student: 1, itemType: 1, articleSlug: 1 }, { unique: true, partialFilterExpression: { itemType: "article" } });

module.exports = mongoose.model("FavoriteItem", favoriteItemSchema);
