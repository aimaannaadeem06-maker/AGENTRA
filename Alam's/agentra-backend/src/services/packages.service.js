const mongoose = require("mongoose");

/**
 * Returns agent IDs whose AI subscription is currently active.
 * Queries the `agents` collection directly (the Agent model stores
 * subscription info in `aiSubscription.isActive` / `aiSubscription.expiryDate`).
 * Falls back to returning ALL active agent IDs if no subscribed agents exist,
 * so the chatbot can still show packages even when no one has subscribed.
 */
async function getSubscribedAgentIds() {
  try {
    const collection = mongoose.connection.db.collection("agents");
    const now = new Date();

    // Agents with an active paid subscription
    const subscribed = await collection.find({
      $or: [
        { "aiSubscription.isActive": true, "aiSubscription.expiryDate": { $gt: now } },
        { "aiSubscription.isActive": true, "aiSubscription.expiryDate": null },
      ],
    }).project({ _id: 1 }).toArray();

    if (subscribed.length > 0) {
      return subscribed.map((a) => a._id.toString());
    }

    // Fallback: return all approved agents so packages are always visible
    const allApproved = await collection.find(
      { status: "APPROVED", isVerified: true },
    ).project({ _id: 1 }).toArray();

    return allApproved.map((a) => a._id.toString());
  } catch (err) {
    console.error("Subscription fetch error:", err.message);
    return [];
  }
}

async function fetchRelevantPackages(userQuery) {
  try {
    const q = userQuery.toLowerCase();
    const collection = mongoose.connection.db.collection("packages");
    const subscribedAgentIds = await getSubscribedAgentIds();
    if (subscribedAgentIds.length === 0) return null;

    const query = {};
    if (q.includes("murree")) query.location = /murree/i;
    else if (q.includes("lahore")) query.location = /lahore/i;
    else query.$or = [{ location: /murree/i }, { location: /lahore/i }];
    if (q.includes("discount") || q.includes("discounted") || q.includes("offer")) {
  query.hasDiscount = true;
}
if (q.includes("featured") || q.includes("popular") || q.includes("top")) {
  query.isFeatured = true;
}
if (q.includes("cheap") || q.includes("budget") || q.includes("affordable")) {
  query.price = { $lte: 15000 };
}

    query.isActive = true;
    const packages = await collection.find(query).limit(10).toArray();
    const filtered = packages.filter((pkg) => 
      subscribedAgentIds.includes(pkg.agentId?.toString())
    );
    console.log(`📦 Packages after subscription filter: ${filtered.length}`);
    if (!filtered.length) return null;

    return filtered.map((pkg, i) => `Package ${i + 1}:
  Title: ${pkg.title}
  Location: ${pkg.location}
  Price: PKR ${pkg.price}
  Duration: ${pkg.duration}
  Description: ${pkg.description || ""}`).join("\n\n");
  } catch (err) {
    console.error("Package fetch error:", err.message);
    return null;
  }
}

async function fetchPackagesForDisplay(userQuery) {
  try {
    const q = userQuery.toLowerCase();
    const collection = mongoose.connection.db.collection("packages");
    const subscribedAgentIds = await getSubscribedAgentIds();
    if (subscribedAgentIds.length === 0) return [];

    const query = {};
    if (q.includes("murree")) query.location = /murree/i;
    else if (q.includes("lahore")) query.location = /lahore/i;
    else query.$or = [{ location: /murree/i }, { location: /lahore/i }];
    if (q.includes("discount") || q.includes("discounted") || q.includes("offer")) {
  query.hasDiscount = true;
}
if (q.includes("featured") || q.includes("popular") || q.includes("top")) {
  query.isFeatured = true;
}
if (q.includes("cheap") || q.includes("budget") || q.includes("affordable")) {
  query.price = { $lte: 15000 };
}

    query.isActive = true;
    const packages = await collection.find(query).limit(10).toArray();
    const filtered = packages.filter((pkg) => 
      subscribedAgentIds.includes(pkg.agentId?.toString())
    );
    return filtered;
  } catch (err) {
    console.error("Display package fetch error:", err.message);
    return [];
  }
}

module.exports = { fetchRelevantPackages, fetchPackagesForDisplay };
