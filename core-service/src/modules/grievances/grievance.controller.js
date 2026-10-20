// ============================================================================
// FairDrop — Grievance Controller (FR-50)
// ============================================================================
// Fairwork Principle 2: Fair Management — Direct grievance & dispute resolution
// ============================================================================

const Grievance = require('./Grievance.model');

/**
 * POST /api/grievances
 * Submits a new grievance or feedback item (FR-50)
 */
async function submitGrievance(req, res) {
  try {
    const { category, order_id, subject, description } = req.body;

    if (!subject || !subject.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Subject is required.',
      });
    }

    if (!description || !description.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Description is required.',
      });
    }

    const grievance = await Grievance.create({
      user_id: req.user ? req.user.id : null,
      user_role: req.user ? req.user.role : 'rider',
      category: category && category.trim() ? category.trim() : 'general',
      order_id: order_id && order_id.trim() ? order_id.trim() : null,
      subject: subject.trim(),
      description: description.trim(),
      status: 'submitted',
    });

    const caseId = `GRV-${grievance._id.toString().slice(-6).toUpperCase()}`;

    return res.status(201).json({
      success: true,
      message: 'Grievance submitted successfully. Under human review per Kerala Fairwork Charter.',
      case_id: caseId,
      grievance: {
        id: grievance._id,
        case_id: caseId,
        category: grievance.category,
        order_id: grievance.order_id,
        subject: grievance.subject,
        description: grievance.description,
        status: grievance.status,
        created_at: grievance.created_at,
      },
    });
  } catch (error) {
    console.error('submitGrievance error:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Failed to submit grievance: ' + error.message,
    });
  }
}

/**
 * GET /api/grievances
 * Lists grievances for the current user or all if admin
 */
async function getGrievances(req, res) {
  try {
    const query = req.user && req.user.role === 'admin' ? {} : { user_id: req.user ? req.user.id : null };
    const list = await Grievance.find(query).sort({ created_at: -1 }).limit(50);

    return res.status(200).json({
      success: true,
      count: list.length,
      grievances: list.map((g) => ({
        id: g._id,
        case_id: `GRV-${g._id.toString().slice(-6).toUpperCase()}`,
        category: g.category,
        order_id: g.order_id,
        subject: g.subject,
        description: g.description,
        status: g.status,
        created_at: g.created_at,
      })),
    });
  } catch (error) {
    console.error('getGrievances error:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch grievances: ' + error.message,
    });
  }
}

module.exports = {
  submitGrievance,
  getGrievances,
};
