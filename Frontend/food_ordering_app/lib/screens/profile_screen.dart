import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../config.dart';
import '../utils/globals.dart'; // For globalCustomerId
import './login_screen.dart'; // For navigation on logout
import '../providers/cart_provider.dart'; // <<<--- IMPORT CartProvider
// Import a provider if you have one for user details, otherwise fetch here
// import '../providers/user_provider.dart'; 
import 'add_edit_address_screen.dart'; // Import the new screen (we'll create this next)
import 'orders_screen.dart'; // Import the OrdersScreen
import '../utils/auth_storage.dart'; // Import AuthStorage
import '../utils/auth_utils.dart'; // Import the refresh utility

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

  // --- Set Default Address ---
  Future<void> _setDefaultAddress(int addressId) async {
    try {
      final String? token = await AuthStorage.getToken();
      if (token == null || token.isEmpty || globalCustomerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not authenticated'), backgroundColor: Colors.red));
        return;
      }
      final dio = Dio();
      final url = '${AppConfig.baseUrl}/addresses/$addressId/set_default/';
      final response = await dio.post(url, options: Options(headers: {'Authorization': 'Bearer $token'}));
      if (response.statusCode == 200) {
        await _loadUserAddresses();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Default address updated.'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to set default address.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  void initState() {
    super.initState();
    refreshTokenIfNeeded(context);
    _verifyAuthentication();
    _loadUserData();
    _loadUserAddresses();
  }

  Future<void> _verifyAuthentication() async {
    final isAuth = await AuthStorage.isAuthenticated();
    if (!isAuth && mounted) {
      // Not authenticated, redirect to login
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to view your profile'))
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } else {
      debugPrint('(ProfileScreen) User is authenticated');
    }
  }

  Future<void> _loadUserData() async {
    await _fetchCustomerDetails();
  }

  Future<void> _loadUserAddresses() async {
    await _fetchSavedAddresses();
  }

  Future<void> _fetchCustomerDetails() async {
    if (globalCustomerId == null) {
      if (mounted) setState(() { _errorDetails = 'Not logged in.'; _isLoadingDetails = false; });
      return;
    }
    if (mounted) setState(() { _isLoadingDetails = true; _errorDetails = null; });
    try {
      final dio = Dio();
      final url = '${AppConfig.baseUrl}/customer/$globalCustomerId/'; 
      debugPrint('(ProfileScreen) Fetching customer details from: $url');
      final response = await dio.get(url);
      debugPrint('(ProfileScreen) Customer Details Response (${response.statusCode}): ${response.data}');

      if (response.statusCode == 200 && response.data is Map) { 
        _customerDetails = Map<String, dynamic>.from(response.data);
      } else { 
         _errorDetails = 'Failed to load details. Status: ${response.statusCode}';
      }
    } on DioException catch (e) {
      _errorDetails = 'Failed to load details: ${e.response?.data?['detail'] ?? e.message}';
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
     if (globalCustomerId == null) {
      if (mounted) setState(() { _errorAddresses = 'Not logged in.'; _isLoadingAddresses = false; });
      return;
    }
    if (mounted) setState(() { _isLoadingAddresses = true; _errorAddresses = null; });
    try {
       final dio = Dio();
       final url = '${AppConfig.baseUrl}/customer/$globalCustomerId/addresses/'; 
       debugPrint('(ProfileScreen) Fetching saved addresses from: $url');
       final response = await dio.get(url);
       debugPrint('(ProfileScreen) Saved Addresses Response (${response.statusCode}): ${response.data}');

       if (response.statusCode == 200 && response.data is List) { 
         _savedAddresses = List<Map<String, dynamic>>.from(
            (response.data as List).where((item) => item is Map).map((item) => Map<String, dynamic>.from(item))
         );
         debugPrint('(ProfileScreen) Parsed Saved Addresses: $_savedAddresses'); 
         _checkAndSetCurrentAddress();
       } else { 
          _errorAddresses = 'Failed to load addresses. Status: ${response.statusCode}';
       }
    } on DioException catch (e) {
      _errorAddresses = 'Error loading addresses: ${e.response?.data?['detail'] ?? e.message}';
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

  // Check if a global address exists or set the first one as current
  void _checkAndSetCurrentAddress() {
    if (globalCurrentAddress == null && _savedAddresses.isNotEmpty) {
      final defaultAddress = _savedAddresses.firstWhere((addr) => addr['is_default'] == true, orElse: () => _savedAddresses.first);
      if (mounted) {
         setCurrentAddress(defaultAddress);
      } 
    }
  }

  // --- Set Address as Current ---
  Future<void> setCurrentAddress(Map<String, dynamic> address) async {
    if (globalCurrentAddress?['id'] == address['id']) return;

    setState(() {
      globalCurrentAddress = address;
      if (address['id'] != null) {
        saveCurrentAddressId(address['id']!.toString());
        debugPrint('(ProfileScreen) Set and saved current address: ${address['id']}');
      } else {
        debugPrint('(ProfileScreen) Warning: Selected address has no ID. Cannot save preference.');
        saveCurrentAddressId(null); 
      }
    });
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
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this address?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) { 
      debugPrint('(ProfileScreen) Address deletion cancelled.');
      return;
    }

    debugPrint('(ProfileScreen) Attempting to delete address ID: $addressId');
    setState(() { _isLoadingAddresses = true; });
    try {
      final dio = Dio();
      final url = '${AppConfig.baseUrl}/addresses/$addressId/';
      debugPrint('(ProfileScreen) DELETE request to: $url');
      final response = await dio.delete(url);

      debugPrint('(ProfileScreen) Delete Address Response (${response.statusCode}): ${response.data}');

      if (response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address deleted successfully'), backgroundColor: Colors.green),
          );
          setState(() {
            if (globalCurrentAddress != null && globalCurrentAddress!['id'] == addressId) {
              globalCurrentAddress = null;
              saveCurrentAddressId(null); 
              debugPrint('(ProfileScreen) Cleared current address as it was deleted.');
            }
            _savedAddresses.removeWhere((addr) => addr['id'] == addressId);
            _isLoadingAddresses = false;
          });
        }
      } else {
        throw Exception('Failed to delete address. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('(ProfileScreen) Error deleting address: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting address: ${e.toString()}'), backgroundColor: Colors.red),
        );
        setState(() { _isLoadingAddresses = false; });
      }
    }
  }

  // --- Logout Logic ---
  Future<void> _logout() async {
    await AuthStorage.clearAuthData(); // Clear all tokens and credentials
    await clearGlobalData();
    Provider.of<CartProvider>(context, listen: false).clearCart();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
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
            _buildSavedAddressesSection(),
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

  Widget _buildSavedAddressesSection() {
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
                final isCurrent = globalCurrentAddress != null && globalCurrentAddress!['id'] == addressId;
                final addressLine1 = address['address_line_1']?.toString() ?? '';

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCurrent ? Icons.check_circle : Icons.location_pin,
                          color: isCurrent ? Colors.orange : Colors.grey,
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          address['is_default'] == true ? Icons.star : Icons.star_border,
                          color: address['is_default'] == true ? Colors.amber : Colors.grey,
                          size: 20,
                        ),
                      ],
                    ),
                    title: Text(addressLine1.isNotEmpty ? addressLine1 : '(No Address Line 1)',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(_formatAddressSubtitle(address)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (value) async {
                            if (value == 'set_default') {
                              await _setDefaultAddress(addressId);
                            }
                          },
                          itemBuilder: (context) => [
                            if (address['is_default'] != true)
                              const PopupMenuItem<String>(
                                value: 'set_default',
                                child: Text('Set as Default'),
                              ),
                          ],
                        ),
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