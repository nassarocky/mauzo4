const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.updateUserRolePermissions = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { targetUserId, newRole, newPermissions, businessId } = data;
  const adminUserId = context.auth.uid;

  try {
    // Get admin user data to verify permissions
    const adminUserDoc = await admin.firestore()
      .collection('gmanusers')
      .doc(adminUserId)
      .get();

    if (!adminUserDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Admin user not found');
    }

    const adminData = adminUserDoc.data();
    const adminRole = adminData.role;
    const adminPermissions = adminData.permissions || [];

    // Check if admin has manage_employees permission
    const hasManageEmployees = adminPermissions.includes('manage_employees') || 
                              adminRole === 'owner' || 
                              adminRole === 'manager';

    if (!hasManageEmployees) {
      throw new functions.https.HttpsError('permission-denied', 
        'You do not have permission to manage employee roles and permissions');
    }

    // Verify both users belong to the same business
    if (!adminData.business || !adminData.business.includes(businessId)) {
      throw new functions.https.HttpsError('permission-denied', 
        'You can only manage employees in your own business');
    }

    // Update target user in gmanusers collection
    const updates = {};
    if (newRole) updates.role = newRole;
    if (newPermissions !== undefined) updates.permissions = newPermissions;

    await admin.firestore()
      .collection('gmanusers')
      .doc(targetUserId)
      .update(updates);

    // Update target user in employees subcollection
    await admin.firestore()
      .collection('employees')
      .doc(businessId)
      .collection('userEmployees')
      .doc(targetUserId)
      .update(updates);

    return { 
      success: true, 
      message: 'User role and permissions updated successfully',
      updatedFields: updates
    };

  } catch (error) {
    console.error('Error updating user role/permissions:', error);
    throw new functions.https.HttpsError('internal', 
      'Failed to update user role and permissions');
  }
});
