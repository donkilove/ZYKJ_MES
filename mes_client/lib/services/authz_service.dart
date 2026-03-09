import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_session.dart';
import '../models/authz_models.dart';
import 'api_exception.dart';

class AuthzService {
  AuthzService(this.session);

  final AppSession session;

  String get _basePath => '${session.baseUrl}/authz';

  Map<String, String> get _authHeaders {
    return {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  Future<List<String>> getMyPermissionCodes({String? moduleCode}) async {
    final query = <String, String>{};
    if (moduleCode != null && moduleCode.trim().isNotEmpty) {
      query['module'] = moduleCode.trim();
    }
    final uri = Uri.parse(
      '$_basePath/permissions/me',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return (data['permission_codes'] as List<dynamic>? ?? const [])
        .cast<String>();
  }

  Future<List<PermissionCatalogItem>> listPermissionCatalog({
    String? moduleCode,
  }) async {
    final query = <String, String>{};
    if (moduleCode != null && moduleCode.trim().isNotEmpty) {
      query['module'] = moduleCode.trim();
    }
    final uri = Uri.parse(
      '$_basePath/permissions/catalog',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) =>
              PermissionCatalogItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
  }

  Future<RolePermissionResult> getRolePermissions({
    required String roleCode,
    required String moduleCode,
  }) async {
    final uri = Uri.parse(
      '$_basePath/role-permissions',
    ).replace(queryParameters: {'role_code': roleCode, 'module': moduleCode});
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return RolePermissionResult.fromJson(data);
  }

  Future<RolePermissionUpdateResult> updateRolePermissions({
    required String roleCode,
    required String moduleCode,
    required List<String> grantedPermissionCodes,
    String? remark,
  }) async {
    final uri = Uri.parse('$_basePath/role-permissions/$roleCode');
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'module_code': moduleCode,
        'granted_permission_codes': grantedPermissionCodes,
        'remark': remark,
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return RolePermissionUpdateResult.fromJson(data);
  }

  Future<RolePermissionMatrixResult> loadRolePermissionMatrix({
    required String moduleCode,
  }) async {
    final uri = Uri.parse(
      '$_basePath/role-permissions/matrix',
    ).replace(queryParameters: {'module': moduleCode});
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return RolePermissionMatrixResult.fromJson(data);
  }

  Future<RolePermissionMatrixUpdateResult> updateRolePermissionMatrix({
    required String moduleCode,
    required Map<String, List<String>> grantedByRoleCode,
    bool dryRun = false,
    String? remark,
  }) async {
    final roleCodes = grantedByRoleCode.keys.toList()..sort();
    final uri = Uri.parse('$_basePath/role-permissions/matrix');
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'module_code': moduleCode,
        'dry_run': dryRun,
        'role_items': roleCodes
            .map(
              (roleCode) => {
                'role_code': roleCode,
                'granted_permission_codes':
                    grantedByRoleCode[roleCode] ?? const <String>[],
              },
            )
            .toList(),
        'remark': remark,
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return RolePermissionMatrixUpdateResult.fromJson(data);
  }

  Future<PermissionHierarchyCatalogResult> loadPermissionHierarchyCatalog({
    required String moduleCode,
  }) async {
    final uri = Uri.parse(
      '$_basePath/hierarchy/catalog',
    ).replace(queryParameters: {'module': moduleCode});
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return PermissionHierarchyCatalogResult.fromJson(data);
  }

  Future<PermissionHierarchyRoleConfigResult>
  loadPermissionHierarchyRoleConfig({
    required String roleCode,
    required String moduleCode,
  }) async {
    final uri = Uri.parse(
      '$_basePath/hierarchy/role-config',
    ).replace(queryParameters: {'role_code': roleCode, 'module': moduleCode});
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return PermissionHierarchyRoleConfigResult.fromJson(data);
  }

  Future<PermissionHierarchyRoleUpdateResult>
  updatePermissionHierarchyRoleConfig({
    required String roleCode,
    required String moduleCode,
    required bool moduleEnabled,
    required List<String> pagePermissionCodes,
    required List<String> featurePermissionCodes,
    bool dryRun = false,
    String? remark,
  }) async {
    final uri = Uri.parse('$_basePath/hierarchy/role-config/$roleCode');
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'module_code': moduleCode,
        'module_enabled': moduleEnabled,
        'page_permission_codes': pagePermissionCodes,
        'feature_permission_codes': featurePermissionCodes,
        'dry_run': dryRun,
        'remark': remark,
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return PermissionHierarchyRoleUpdateResult.fromJson(data);
  }

  Future<PermissionHierarchyPreviewResult> previewPermissionHierarchy({
    required String moduleCode,
    required List<PermissionHierarchyRoleDraftItem> roleItems,
  }) async {
    final uri = Uri.parse('$_basePath/hierarchy/preview');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'module_code': moduleCode,
        'role_items': roleItems.map((item) => item.toJson()).toList(),
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return PermissionHierarchyPreviewResult.fromJson(data);
  }

  Future<CapabilityPackCatalogResult> loadCapabilityPackCatalog({
    required String moduleCode,
  }) async {
    final uri = Uri.parse(
      '$_basePath/capability-packs/catalog',
    ).replace(queryParameters: {'module': moduleCode});
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return CapabilityPackCatalogResult.fromJson(data);
  }

  Future<CapabilityPackRoleConfigResult> loadCapabilityPackRoleConfig({
    required String roleCode,
    required String moduleCode,
  }) async {
    final uri = Uri.parse(
      '$_basePath/capability-packs/role-config',
    ).replace(queryParameters: {'role_code': roleCode, 'module': moduleCode});
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return CapabilityPackRoleConfigResult.fromJson(data);
  }

  Future<CapabilityPackRoleUpdateResult> updateCapabilityPackRoleConfig({
    required String roleCode,
    required String moduleCode,
    required bool moduleEnabled,
    required List<String> capabilityCodes,
    bool dryRun = false,
    String? remark,
  }) async {
    final uri = Uri.parse('$_basePath/capability-packs/role-config/$roleCode');
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'module_code': moduleCode,
        'module_enabled': moduleEnabled,
        'capability_codes': capabilityCodes,
        'dry_run': dryRun,
        'remark': remark,
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return CapabilityPackRoleUpdateResult.fromJson(data);
  }

  Future<CapabilityPackPreviewResult> previewCapabilityPacks({
    required String moduleCode,
    required List<CapabilityPackRoleDraftItem> roleItems,
  }) async {
    final uri = Uri.parse('$_basePath/capability-packs/preview');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'module_code': moduleCode,
        'role_items': roleItems.map((item) => item.toJson()).toList(),
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return CapabilityPackPreviewResult.fromJson(data);
  }

  Future<PermissionExplainResult> loadCapabilityPackEffective({
    required String roleCode,
    required String moduleCode,
  }) async {
    final uri = Uri.parse(
      '$_basePath/capability-packs/effective',
    ).replace(queryParameters: {'role_code': roleCode, 'module': moduleCode});
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return PermissionExplainResult.fromJson(data);
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    if (response.body.isEmpty) {
      return {};
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _extractErrorMessage(Map<String, dynamic> body, int statusCode) {
    final detail = body['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
    final message = body['message'];
    if (message is String && message.isNotEmpty) {
      return message;
    }
    return 'Request failed (status $statusCode)';
  }
}
