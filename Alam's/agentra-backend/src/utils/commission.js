/**
 * Commission Calculation Utility
 * Handles calculations for the platform commission system.
 */

/**
 * Calculates the platform commission (5%) and net agent earning.
 * @param {number} amount - The total booking amount.
 * @returns {{ commission: number, netAgentEarning: number }}
 */
function calculateCommission(amount) {
  const numAmount = Number(amount);
  if (isNaN(numAmount) || numAmount < 0) {
    throw new Error('Invalid booking amount for commission calculation: must be non-negative');
  }

  const commission = numAmount * 0.05;
  const netAgentEarning = numAmount - commission;

  return {
    commission,
    netAgentEarning
  };
}

module.exports = {
  calculateCommission
};
