exports.getSystemLogs = async (req, res) => {
  try {
    console.log("📝 [owner] Fetching system logs...");

    // Mock system logs data - in a real app, this would come from a logging service
    const mockLogs = [
      {
        timestamp: new Date(Date.now() - 1000 * 60 * 5).toISOString(),
        level: 'INFO',
        event: 'User Login',
        details: 'owner user logged into dashboard',
        user: 'owneristrator'
      },
      {
        timestamp: new Date(Date.now() - 1000 * 60 * 15).toISOString(),
        level: 'INFO',
        event: 'Agent Approved',
        details: 'Agent ID: 64f1a2b3c4d5e6f7g8h9i0j1 approved',
        user: 'owneristrator'
      },
      {
        timestamp: new Date(Date.now() - 1000 * 60 * 30).toISOString(),
        level: 'WARN',
        event: 'Failed Login Attempt',
        details: 'Invalid credentials for email: unknown@example.com',
        user: 'Unknown'
      },
      {
        timestamp: new Date(Date.now() - 1000 * 60 * 45).toISOString(),
        level: 'INFO',
        event: 'New Agent Registration',
        details: 'New agent registered: john.doe@travel.com',
        user: 'john.doe@travel.com'
      },
      {
        timestamp: new Date(Date.now() - 1000 * 60 * 60).toISOString(),
        level: 'ERROR',
        event: 'Database Connection Issue',
        details: 'Temporary connection timeout to MongoDB',
        user: 'System'
      },
      {
        timestamp: new Date(Date.now() - 1000 * 60 * 90).toISOString(),
        level: 'INFO',
        event: 'Complaint Resolved',
        details: 'Complaint ID: 64f1a2b3c4d5e6f7g8h9i0j2 marked as resolved',
        user: 'owneristrator'
      },
      {
        timestamp: new Date(Date.now() - 1000 * 60 * 120).toISOString(),
        level: 'INFO',
        event: 'System Backup',
        details: 'Automated daily backup completed successfully',
        user: 'System'
      },
      {
        timestamp: new Date(Date.now() - 1000 * 60 * 180).toISOString(),
        level: 'WARN',
        event: 'High Memory Usage',
        details: 'Server memory usage above 80% threshold',
        user: 'System'
      }
    ];

    console.log(`✅ [owner] Retrieved ${mockLogs.length} system logs`);
    res.json({
      success: true,
      logs: mockLogs,
      message: "System logs retrieved successfully"
    });
  } catch (error) {
    console.error("❌ [owner] Error fetching system logs:", error.message);
    res.status(500).json({
      success: false,
      message: "Failed to fetch system logs",
      error: error.message
    });
  }
};
