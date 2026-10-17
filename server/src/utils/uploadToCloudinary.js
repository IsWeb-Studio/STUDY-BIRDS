const { randomUUID } = require('node:crypto');
const { checkFile } = require('./fileSafety');
const path = require("path");
const { cloudinary, ensureCloudinaryConfigured } = require("../config/cloudinary");

const isPdfFile = (file) => String(file?.mimetype || "").toLowerCase() === "application/pdf";

const buildUploadOptions = (file, folder) => {
  const extension = path.extname(file.originalname || "");
  const isImage = file.mimetype.startsWith("image/");
  const isPdf = isPdfFile(file);

  return {
    folder,
    public_id: randomUUID(),
    overwrite: false,
    resource_type: isImage || isPdf ? "image" : "raw",
    use_filename: false,
    unique_filename: false,
    format: isImage ? undefined : extension.replace(/^\./, "") || undefined,
  };
};

const buildDeliveryUrl = (result, file) => {
  const isImage = file.mimetype.startsWith("image/");
  const isPdf = isPdfFile(file);
  const extension = path.extname(file.originalname || "").replace(/^\./, "");

  if (isImage) {
    return result.secure_url;
  }

  if (isPdf) {
    return cloudinary.url(result.public_id, {
      resource_type: "image",
      type: "upload",
      secure: true,
      sign_url: true,
      format: extension || "pdf",
    });
  }

  // Delivery URL for the public non-image assets supported by this helper.
  return cloudinary.url(result.public_id, {
    resource_type: result.resource_type || "raw",
    type: "upload",
    secure: true,
    sign_url: true,
  });
};

const uploadFileToCloudinary = (file, folder) =>
  new Promise((resolve, reject) => {
    checkFile(file);
    if (folder === "study-birds/agent-verification") {
      throw new Error("Verification documents require private storage");
    }
    ensureCloudinaryConfigured();

    const uploadStream = cloudinary.uploader.upload_stream(
      buildUploadOptions(file, folder),
      (error, result) => {
        if (error) {
          reject(error);
          return;
        }

        if (!result?.public_id || result.existing || result.overwritten) {
          reject(new Error("Upload did not create a new asset"));
          return;
        }
        resolve({
          url: buildDeliveryUrl(result, file),
          publicId: result.public_id,
          originalName: file.originalname,
          bytes: result.bytes,
          resourceType: result.resource_type,
        });
      }
    );

    uploadStream.on?.("error", reject);
    uploadStream.end(file.buffer);
  });

module.exports = {
  uploadFileToCloudinary,
};
