enum UserRole { master, manager, driver, distributor, salesOfficer }

class AuthSession {
  static UserRole role = UserRole.manager;
  static String mobile = "";

  // Distributor single code (ex: "D031")
  static String distributorCode = "";

  // Sales Officer multi codes (ex: ["D031","D015"])
  static List<String> allowedDistributorCodes = [];

  static List<String> get effectiveDistributorCodes {
    if (allowedDistributorCodes.isNotEmpty) return allowedDistributorCodes;
    if (distributorCode.isNotEmpty) return [distributorCode];
    return [];
  }
}

/// Call this right after login success:
/// applyLoginToSession(responseJson["user"]);
void applyLoginToSession(Map<String, dynamic> user) {
  final roleStr = (user["role"] ?? "").toString().toUpperCase();

  if (roleStr == "DISTRIBUTOR") {
    AuthSession.role = UserRole.distributor;
  } else if (roleStr == "DRIVER") {
    AuthSession.role = UserRole.driver;
  } else if (roleStr == "MASTER") {
    AuthSession.role = UserRole.master;
  } else if (roleStr == "MANAGER") {
    AuthSession.role = UserRole.manager;
  } else if (roleStr == "SALES OFFICER" ||
      roleStr == "SALES_OFFICER" ||
      roleStr == "SALES OFFICER VNR" ||
      roleStr == "SALES_OFFICER_VNR") {
    AuthSession.role = UserRole.salesOfficer;
  } else {
    AuthSession.role = UserRole.manager;
  }

  AuthSession.mobile = (user["mobile"] ?? "").toString();

  // Distributor single code
  AuthSession.distributorCode = (user["distributorCode"] ?? "").toString();

  // Sales Officer codes
  final raw = user["allowedDistributorCodes"];
  if (raw is List) {
    AuthSession.allowedDistributorCodes = raw.map((e) => e.toString()).toList();
  } else {
    AuthSession.allowedDistributorCodes = [];
  }
}
