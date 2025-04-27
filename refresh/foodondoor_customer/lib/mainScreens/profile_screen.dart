import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../providers/cart_provider.dart'; 
import '../providers/auth_provider.dart';
import 'add_edit_address_screen.dart'; 
import 'orders_screen.dart'; 
import '../utils/app_config.dart';

// Purpose: Displays user profile details and manages saved addresses.

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _customerDetails;
  List<Map<String, dynamic>> _savedAddresses = [];
  bool _isLoadingDetails = true;
  bool _isLoadingAddresses = true;
  String? _errorDetails;
  String? _errorAddresses;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserAddresses();
  }

  Future<void> _loadUserData() async {
    await _fetchCustomerDetails();
  }

  Future<void> _loadUserAddresses() async {
    await _fetchSavedAddresses();
  }

  Future<void> _fetchCustomerDetails() async {
    if (mounted) setState(() { _isLoadingDetails = true; _errorDetails = null; });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final customerId = authProvider.customerId;
      if (token == null || customerId == null) {
        setState(() { _errorDetails = 'Not logged in.'; _isLoadingDetails = false; });
        return;
      }
      final dio = Dio();
      final url = '${AppConfig.baseUrl}/api/customer/$customerId/';
      debugPrint('(ProfileScreen) Fetching customer details from: $url');
      final response = await dio.get(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      debugPrint('(ProfileScreen) Customer Details Response (${response.statusCode}): ${response.data}');

      if (response.statusCode == 200 && response.data is Map) {
        _customerDetails = Map<String, dynamic>.from(response.data);
      } else {
         _errorDetails = 'Failed to load details. Status: ${response.statusCode}';
      }
    } on DioException catch (e) {
      _errorDetails = 'Failed to load details: [31m${e.response?.data?['detail'] ?? e.message}[0m';
      debugPrint('(ProfileScreen) DioError fetching customer details: $e');
    } catch (e) {
      _errorDetails = 'An unexpected error occurred while fetching details.';
      debugPrint('(ProfileScreen) Error fetching customer details: $e');
    } finally {
      if (mounted) {
        setState(() { _isLoadingDetails = false; });
      }
    }
  }

  Future<void> _fetchSavedAddresses() async {
    if (mounted) setState(() { _isLoadingAddresses = true; _errorAddresses = null; });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      if (token == null) {
        setState(() { _errorAddresses = 'Not logged in.'; _isLoadingAddresses = false; });
        return;
      }
      final dio = Dio();
      final url = '${AppConfig.baseUrl}/api/addresses/';
      debugPrint('(ProfileScreen) Fetching saved addresses from: $url');
      final response = await dio.get(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      debugPrint('(ProfileScreen) Saved Addresses Response (${response.statusCode}): ${response.data}');

      if (response.statusCode == 200 && response.data is List) {
        _savedAddresses = List<Map<String, dynamic>>.from(
          (response.data as List).where((item) => item is Map).map((item) => Map<String, dynamic>.from(item))
        );
        debugPrint('(ProfileScreen) Parsed Saved Addresses: $_savedAddresses');
      } else {
        _errorAddresses = 'Failed to load addresses. Status: ${response.statusCode}';
      }
    } on DioException catch (e) {
      _errorAddresses = 'Error loading addresses: [31m${e.response?.data?['detail'] ?? e.message}[0m';
      debugPrint('(ProfileScreen) DioError fetching saved addresses: $e');
    } catch (e) {
      _errorAddresses = 'An unexpected error occurred loading addresses.';
      debugPrint('(ProfileScreen) Error fetching saved addresses: $e');
    } finally {
      if (mounted) {
        setState(() { _isLoadingAddresses = false; });
      }
    }
  }

  // --- Set Address as Current ---
  Future<void> setCurrentAddress(Map<String, dynamic> address) async {
    Provider.of<AuthProvider>(context, listen: false).setCurrentAddress(address);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Address set as current.'), duration: Duration(seconds: 1)),
    );
  }

  // --- Navigate to Add/Edit Address ---
  Future<void> _goToEditAddress(Map<String, dynamic>? address) async {
    debugPrint('(ProfileScreen) Navigating to edit address: $address');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditAddressScreen(address: address),
      ),
    );
    if (result == true) {
      debugPrint('(ProfileScreen) Returned from edit address screen, refreshing list...');
      _fetchSavedAddresses(); 
    }
  }

  // --- Delete Address ---
  Future<void> _deleteAddress(int addressId) async {
    setState(() { _isLoadingAddresses = true; });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      if (token == null) {
        setState(() { _errorAddresses = 'Not logged in.'; _isLoadingAddresses = false; });
        return;
      }
      final dio = Dio();
      final url = '${AppConfig.baseUrl}/api/addresses/$addressId/';
      debugPrint('(ProfileScreen) DELETE request to: $url');
      final response = await dio.delete(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 204) {
        debugPrint('(ProfileScreen) Address deleted successfully.');
        await _fetchSavedAddresses();
      } else {
        setState(() { _errorAddresses = 'Failed to delete address. Status: ${response.statusCode}'; });
      }
    } on DioException catch (e) {
      setState(() { _errorAddresses = 'Failed to delete address: \u001b[31m${e.response?.data?['detail'] ?? e.message}\u001b[0m'; });
      debugPrint('(ProfileScreen) DioError deleting address: $e');
    } catch (e) {
      setState(() { _errorAddresses = 'An unexpected error occurred while deleting address.'; });
      debugPrint('(ProfileScreen) Error deleting address: $e');
    } finally {
      setState(() { _isLoadingAddresses = false; });
    }
  }

  // --- Logout Logic ---
  Future<void> _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    // Optionally clear other providers, e.g., cart
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        color: Colors.orange,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // --- Customer Details Section ---
            _buildSectionTitle('Account Details'),
            _buildCustomerDetailsSection(),
            const SizedBox(height: 24),

            // --- Saved Addresses Section ---
            _buildSavedAddressesSection(authProvider),
            const SizedBox(height: 32),

            // --- Orders Section ---
            ListTile(
              leading: const Icon(Icons.shopping_bag_outlined, color: Colors.orange),
              title: const Text('My Orders'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OrdersScreen()),
                );
              },
            ),

            // --- Logout Button ---
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                ),
                onPressed: _logout,
              ),
             ),
             const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- Extracted Widgets for Clarity ---

  Widget _buildCustomerDetailsSection() {
    if (_isLoadingDetails) {
      return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
    }
    if (_errorDetails != null) {
      return Center(child: Text(_errorDetails!, style: const TextStyle(color: Colors.red)));
    }
    if (_customerDetails == null) {
       return const Center(child: Text('Could not load details. Pull to refresh.'));
    }
    final fullName = _customerDetails!['full_name']?.toString() ?? 'N/A';
    final email = _customerDetails!['email']?.toString() ?? 'N/A';
    final phone = _customerDetails!['phone']?.toString() ?? 'N/A';

    return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(Icons.person_outline, 'Name', fullName),
              _buildDetailRow(Icons.email_outlined, 'Email', email),
              _buildDetailRow(Icons.phone_outlined, 'Phone', phone),
            ],
          ),
        ),
      );
  }

  Widget _buildSavedAddressesSection(AuthProvider authProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
              _buildSectionTitle('Saved Addresses'),
              TextButton.icon(
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: const Text('Add New'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => _goToEditAddress(null), 
              ),
           ],
         ),
         if (_isLoadingAddresses)
           const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
         else if (_errorAddresses != null)
            Center(child: Text(_errorAddresses!, style: const TextStyle(color: Colors.red)))
         else if (_savedAddresses.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: TextButton(
                    onPressed: () => _goToEditAddress(null), 
                    child: const Text('No saved addresses. Add one?'),
                  ), 
              )
            )
         else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _savedAddresses.length,
              itemBuilder: (context, index) {
                final address = _savedAddresses[index];
                final addressId = (address['id'] as num?)?.toInt(); 
                if (addressId == null) {
                  debugPrint('(ProfileScreen) Error: Address at index $index has missing or invalid ID: $address');
                  return const SizedBox.shrink();
                }

                debugPrint('(ProfileScreen) Building ListTile for address ID $addressId: $address'); 
                final isCurrent = authProvider.currentAddress != null && authProvider.currentAddress!['id'] == addressId;
                final addressLine1 = address['address_line_1']?.toString() ?? '';

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    leading: Icon(
                      isCurrent ? Icons.check_circle : Icons.location_pin,
                      color: isCurrent ? Colors.orange : Colors.grey,
                    ),
                    title: Text(addressLine1.isNotEmpty ? addressLine1 : '(No Address Line 1)',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(_formatAddressSubtitle(address)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blueGrey),
                          tooltip: 'Edit Address',
                          onPressed: () => _goToEditAddress(address), 
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                          tooltip: 'Delete Address',
                          onPressed: () => _deleteAddress(addressId), 
                        ),
                      ],
                    ),
                    onTap: () => setCurrentAddress(address), 
                  ),
                );
              },
            ),
      ],
    );
  }

  // --- Helper Widgets ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAddressSubtitle(Map<String, dynamic> address) {
    debugPrint('Formatting address subtitle for: $address'); 

    List<String> parts = [];
    final city = address['city']?.toString() ?? '';
    final state = address['state']?.toString() ?? '';
    final postalCode = address['postal_code']?.toString() ?? '';
    final type = address['type']?.toString() ?? '';

    if (city.isNotEmpty) parts.add(city);
    if (state.isNotEmpty) parts.add(state);
    if (postalCode.isNotEmpty) parts.add(postalCode);
    
    String mainPart = parts.join(', ');
    String typePart = type.isNotEmpty ? ' ($type)' : ''; 
    
    final result = mainPart + typePart;
    return result.isEmpty ? 'Address details incomplete' : result; 
  }
}