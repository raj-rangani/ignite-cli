const express = require("express");
const router = express.Router();

// Define your routes here
router.get("/", (req, res) => {
  res.json({
    message: "API is working properly",
    timestamp: new Date().toISOString(),
  });
});

// Export router
module.exports = router;
