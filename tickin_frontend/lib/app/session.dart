enum UserRole { master, manager, driver, distributor, salesOfficer }

class AuthSession {
  static UserRole role = UserRole.manager;
  static String distributorCode = "";
  static List<String> allowedDistributorCodes = [];

  static List<String> get effectiveDistributorCodes {
    if (allowedDistributorCodes.isNotEmpty) return allowedDistributorCodes;
    if (distributorCode.isNotEmpty) return [distributorCode];
    return [];
  }
}

UserRole mapRole(String role) {
  switch (role.toUpperCase()) {
    case "MASTER":
      return UserRole.master;
    case "MANAGER":
      return UserRole.manager;
    case "DRIVER":
    case "LOADMAN":
      return UserRole.driver;
    case "DISTRIBUTOR":
      return UserRole.distributor;
    case "SALES":
    case "SALES_OFFICER":
    case "SALES OFFICER":
      return UserRole.salesOfficer;
    default:
      return UserRole.salesOfficer;
  }
}

void applyLoginToSession(Map<String, dynamic> userMap) {
  AuthSession.role = mapRole((userMap["role"] ?? "").toString());
  AuthSession.distributorCode = (userMap["distributorCode"] ?? "").toString();

  final raw = userMap["allowedDistributorCodes"];
  if (raw is List) {
    AuthSession.allowedDistributorCodes = raw.map((e) => e.toString()).toList();
  } else {
    AuthSession.allowedDistributorCodes = [];
  }
}
