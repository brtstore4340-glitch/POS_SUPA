// Role constants - using lowercase to match Firebase Auth custom claims
export const ROLES = {
  ADMIN: 'admin',
  MANAGER: 'manager',
  SUPERVISOR: 'supervisor',
  STAFF: 'staff',
  CASHIER: 'cashier',
  VIEWER: 'viewer'
};
 
// Permission constants 
export const PERMISSIONS = { 
  MANAGE_USERS: 'MANAGE_USERS', 
  CREATE_USER: 'CREATE_USER', 
  VIEW_USERS: 'VIEW_USERS', 
  EDIT_USER: 'EDIT_USER', 
  DELETE_USER: 'DELETE_USER', 
  CREATE_ORDER: 'CREATE_ORDER', 
  VIEW_ORDERS: 'VIEW_ORDERS', 
  EDIT_ORDER: 'EDIT_ORDER', 
  DELETE_ORDER: 'DELETE_ORDER', 
  REFUND_ORDER: 'REFUND_ORDER', 
  VIEW_INVENTORY: 'VIEW_INVENTORY', 
  EDIT_INVENTORY: 'EDIT_INVENTORY', 
  VIEW_REPORTS: 'VIEW_REPORTS', 
  EXPORT_REPORTS: 'EXPORT_REPORTS' 
}; 
 
// Role hierarchy (higher level = more privileges) 
export const ROLE_LEVELS = { 
  [ROLES.ADMIN]: 100, 
  [ROLES.MANAGER]: 75, 
  [ROLES.SUPERVISOR]: 50, 
  [ROLES.STAFF]: 25, 
  [ROLES.CASHIER]: 20, 
  [ROLES.VIEWER]: 10 
}; 
 
// Role-Permission Mapping 
export const ROLE_PERMISSIONS = { 
  [ROLES.ADMIN]: Object.values(PERMISSIONS), 
  [ROLES.MANAGER]: [ 
    PERMISSIONS.MANAGE_USERS, 
    PERMISSIONS.CREATE_USER, 
    PERMISSIONS.VIEW_USERS, 
    PERMISSIONS.EDIT_USER, 
    PERMISSIONS.CREATE_ORDER, 
    PERMISSIONS.VIEW_ORDERS, 
    PERMISSIONS.EDIT_ORDER, 
    PERMISSIONS.REFUND_ORDER, 
    PERMISSIONS.VIEW_INVENTORY, 
    PERMISSIONS.EDIT_INVENTORY, 
    PERMISSIONS.VIEW_REPORTS, 
    PERMISSIONS.EXPORT_REPORTS 
  ], 
  [ROLES.SUPERVISOR]: [ 
    PERMISSIONS.VIEW_USERS, 
    PERMISSIONS.CREATE_ORDER, 
    PERMISSIONS.VIEW_ORDERS, 
    PERMISSIONS.EDIT_ORDER, 
    PERMISSIONS.VIEW_INVENTORY, 
    PERMISSIONS.VIEW_REPORTS 
  ], 
  [ROLES.STAFF]: [ 
    PERMISSIONS.CREATE_ORDER, 
    PERMISSIONS.VIEW_ORDERS, 
    PERMISSIONS.VIEW_INVENTORY 
  ], 
  [ROLES.CASHIER]: [ 
    PERMISSIONS.CREATE_ORDER, 
    PERMISSIONS.VIEW_INVENTORY 
  ], 
  [ROLES.VIEWER]: [ 
    PERMISSIONS.VIEW_ORDERS, 
    PERMISSIONS.VIEW_INVENTORY, 
    PERMISSIONS.VIEW_REPORTS 
  ] 
}; 
 

export function hasRole(user, role) {
  return user && user.role === role;
}

export function hasMinimumRole(user, minRole) {
  if (!user || !user.role) return false;
  const userLevel = ROLE_LEVELS[user.role] || 0;
  const requiredLevel = ROLE_LEVELS[minRole] || 0;
  return userLevel >= requiredLevel;
}

export function hasPermission(user, permission) {
  if (!user || !user.role) return false;
  const perms = ROLE_PERMISSIONS[user.role] || [];
  return perms.includes(permission);
}

export function hasAnyRole(user, roles) {
  if (!user || !user.role) return false;
  return roles.includes(user.role);
}

export function hasAllPermissions(user, permissions) {
  if (!user || !user.role) return false;
  const userPerms = ROLE_PERMISSIONS[user.role] || [];
  return permissions.every(p => userPerms.includes(p));
}
