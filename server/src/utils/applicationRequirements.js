const DEFAULT_DOCUMENT_TYPES = Object.freeze(['passport', 'biometric-photo', 'latest-qualification']);
const INVALID_DOCUMENT_STATES = new Set(['missing', 'rejected', 'needs-revision', 'needs-translation', 'expired']);

function requiredDocumentTypesFor(program) {
  return Array.isArray(program?.requiredDocumentTypes) ? [...program.requiredDocumentTypes] : [...DEFAULT_DOCUMENT_TYPES];
}

function missingDocumentTypes(required, documents) {
  const supplied = new Set(documents.filter(doc => doc.status !== 'rejected' && !INVALID_DOCUMENT_STATES.has(doc.detailedStatus) &&
    (!doc.expiresAt || new Date(doc.expiresAt) > new Date())).map(doc => doc.type));
  return required.filter(type => !supplied.has(type));
}

module.exports = { requiredDocumentTypesFor, missingDocumentTypes };
