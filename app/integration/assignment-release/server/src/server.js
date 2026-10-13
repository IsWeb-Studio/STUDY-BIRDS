require("dotenv").config();
const app = require("./app");
const { connectDatabase } = require("./config/db");

const PORT = process.env.PORT || 5000;
const MONGODB_RETRY_DELAY_MS = Number(process.env.MONGODB_RETRY_DELAY_MS || 5000);

let stopReminders;
let stopAutomaticAssignment;
const startDatabaseConnection = async () => {
  try {
    await connectDatabase();
    if (!stopAutomaticAssignment) {
      try { stopAutomaticAssignment = require("./utils/automaticApplicationAssignment").startAutomaticAssignmentScheduler(); }
      catch (error) { console.error("Automatic assignment configuration invalid", error.message); }
    }
    if (!stopReminders) {
      try { stopReminders = require("./utils/followUpReminders").startFollowUpReminderScheduler(); }
      catch (error) { console.error("Follow-up scheduler configuration invalid", error.message); }
    }
  } catch (error) {
    console.error("MongoDB connection failed", error.message);
    console.log(`Retrying MongoDB connection in ${MONGODB_RETRY_DELAY_MS}ms`);
    setTimeout(startDatabaseConnection, MONGODB_RETRY_DELAY_MS);
  }
};

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  startDatabaseConnection();
});
