Attaching two files can you check why address is not loading in home screen.. while in profile screen it is able to load perfectly.. select address section it is not able to load properly..
Home screen.dart..
import 'package:flutter/material.dart';
// Purpose: Provides the main home screen UI, including banners, categories, restaurants, and address selection.
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../providers/home_provider.dart';
import '../utils/globals.dart';
import '../config.dart';
import './search_screen.dart';
import '../providers/cart_provider.dart';
import './cart_screen.dart';
import './profile_screen.dart';
import './add_edit_address_screen.dart';
import '../utils/auth_storage.dart'; // <-- Import the new utility
import '../providers/auth_provider.dart';
import './login_screen.dart';
class HomeScreen extends StatefulWidget {
const HomeScreen({Key? key}) : super(key: key);
@override
_HomeScreenState createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
late Position _currentPosition;
bool _isDeliveryAvailable = false;
bool _locationPermissionDenied = false;
String? _selectedCategory;
bool _addressSheetShownAfterLoad = false; // Flag to show sheet only once
String? _authToken;
@override
void initState() {
super.initState();
_checkAuthenticationStatus();
// Schedule initialization after the first frame
WidgetsBinding.instance.addPostFrameCallback((_) {
if (mounted) {
_checkAuthToken();
_verifyAuthentication(); // Add authentication check
// Start both initialization and location check concurrently
_initializeHomeScreenData(); // <<-- Now called after first frame
_initializeLocationCheck(); // <<-- Location check can also start here
}
});
}
Future<void> _checkAuthToken() async {
final token = await AuthStorage.getToken();
debugPrint('(HomeScreen) Retrieved auth_token: ${token != null ? "exists" : "not found"}');
if (token != null) {
debugPrint('(HomeScreen) Token length: ${token.length}');
// Log first characters of token for debugging
debugPrint('(HomeScreen) Token begins with: ${token.substring(0, token.length > 10 ? 10 : token.length)}...');
}
_authToken = token;
}
// Verify authentication status and redirect to login if needed
Future<void> _verifyAuthentication() async {
if (mounted) {
final authProvider = Provider.of<AuthProvider>(context, listen: false);
final token = await AuthStorage.getToken();
if (token == null) {
debugPrint('(HomeScreen) No auth token found, redirecting to login');
_redirectToLogin('Please log in to continue');
return;
}
try {
final isAuthenticated = await authProvider.isAuthenticated();
if (!isAuthenticated && mounted) {
debugPrint('(HomeScreen) Token validation failed, redirecting to login');
_redirectToLogin('Your session has expired. Please log in again.');
return;
}
debugPrint('(HomeScreen) User is authenticated, continuing');
} catch (e) {
debugPrint('(HomeScreen) Error verifying authentication: $e');
_redirectToLogin('An error occurred. Please log in again.');
}
}
}
void _redirectToLogin([String? message]) {
// If a message is provided, show it
if (message != null && message.isNotEmpty && mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text(message)),
);
}
if (mounted) {
Navigator.of(context).pushReplacement(
MaterialPageRoute(builder: (context) => const LoginScreen()),
);
}
}
// Renamed original _initializeScreen to focus on location
Future<void> _initializeLocationCheck() async {
debugPrint('Starting location/delivery check...');
await _getUserLocation(); // This will set _isDeliveryAvailable and _locationPermissionDenied
// No need to call _initializeHomeScreenData here anymore
// The UI will rebuild based on _isDeliveryAvailable when this finishes
}
Future<void> _getUserLocation() async {
// Clear flags initially
bool wasPermissionDenied = _locationPermissionDenied;
setState(() {
_locationPermissionDenied = false;
});
bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
if (!serviceEnabled) {
debugPrint('Location service disabled.');
setState(() { _locationPermissionDenied = true; });
// If permission was previously granted, but service is now off,
// we might still show the main content but with a warning later.
// Or force pincode if _isDeliveryAvailable is false after check.
_checkDeliveryAvailability(); // Check without location to see if backend handles it
return;
}
LocationPermission permission = await Geolocator.checkPermission();
if (permission == LocationPermission.denied) {
permission = await Geolocator.requestPermission();
if (permission == LocationPermission.denied) {
debugPrint('Location permission denied.');
setState(() { _locationPermissionDenied = true; });
_checkDeliveryAvailability(); // Check without location
return;
}
}
if (permission == LocationPermission.deniedForever) {
debugPrint('Location permission denied forever.');
setState(() { _locationPermissionDenied = true; });
_checkDeliveryAvailability(); // Check without location
return;
}
// If we reach here, permission is granted
debugPrint('Location permission granted.');
try {
_currentPosition = await Geolocator.getCurrentPosition(
desiredAccuracy: LocationAccuracy.high);
debugPrint('Current position obtained: ${_currentPosition.latitude}, ${_currentPosition.longitude}');
// Check delivery using fetched location (will prioritize global address first inside the method)
await _checkDeliveryAvailability(
latitude: _currentPosition.latitude,
longitude: _currentPosition.longitude,
);
} catch (e) {
debugPrint('Error getting current position: $e');
setState(() { _locationPermissionDenied = true; });
// Check delivery without location as fallback (will use global address if available)
await _checkDeliveryAvailability();
}
}
Future<void> _checkDeliveryAvailability({double? latitude, double? longitude, String? pincode}) async {
// Prioritize using globalCurrentAddress if available
Map<String, dynamic>? addressToCheck = globalCurrentAddress;
double? checkLat = latitude;
double? checkLon = longitude;
String? checkPincode = pincode;
if (addressToCheck != null) {
debugPrint('Using globally set address for delivery check.');
// Extract details from the global address if needed by API
checkLat = (addressToCheck['latitude'] as num?)?.toDouble() ?? checkLat;
checkLon = (addressToCheck['longitude'] as num?)?.toDouble() ?? checkLon;
checkPincode = addressToCheck['postal_code']?.toString() ?? checkPincode;
}
bool deliveryStatusKnown = _isDeliveryAvailable || _locationPermissionDenied;
try {
debugPrint('Checking delivery availability (Using Lat: $checkLat, Lon: $checkLon, Pincode: $checkPincode)...');
// Prepare request data with at least one location identifier
final Map<String, dynamic> requestData = {};
// Always include customer_id if available
if (globalCustomerId != null) {
requestData['customer_id'] = globalCustomerId;
}
// Add location data if available
if (checkLat != null && checkLon != null) {
requestData['latitude'] = checkLat;
requestData['longitude'] = checkLon;
} else if (checkPincode != null && checkPincode.isNotEmpty) {
requestData['pincode'] = checkPincode;
}
// Ensure we have at least one location identifier
if (!requestData.containsKey('latitude') && !requestData.containsKey('pincode')) {
debugPrint('Cannot check delivery: No location data available.');
if (mounted) setState(() {
_locationPermissionDenied = true;
_isDeliveryAvailable = false;
});
return;
}
final dio = Dio();
final String? token = await AuthStorage.getToken();
final options = Options();
if (token != null) {
options.headers = {
'Authorization': 'Bearer $token',
'Content-Type': 'application/json'
};
debugPrint('(HomeScreen) Adding Auth header to check-delivery request.');
}
final response = await dio.post(
'${AppConfig.baseUrl}/check-delivery/',
data: requestData,
options: options,
);
debugPrint('Delivery API Response: ${response.data}');
final bool available = response.data['delivery_available'] ?? false;
if (mounted) {
setState(() {
_isDeliveryAvailable = available;
_locationPermissionDenied = false;
});
debugPrint('Delivery availability set to: $_isDeliveryAvailable');
}
} catch (e) {
debugPrint('Error in delivery API call: $e');
if (mounted) {
setState(() {
_isDeliveryAvailable = false;
if (latitude == null && longitude == null && pincode == null && globalCurrentAddress == null) {
_locationPermissionDenied = true;
}
});
}
}
}
Future<void> _initializeHomeScreenData() async {
debugPrint('Starting to initialize home screen data...');
final homeProvider = Provider.of<HomeProvider>(context, listen: false);
try {
await homeProvider.initializeHomeScreen();
debugPrint('Home screen data initialized successfully');
} catch (e) {
debugPrint('Error initializing home screen data: $e');
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Error loading data. Please try again.')),
);
}
}
Future<void> _askForPincode() async {
String? pincode = await showDialog<String>(
context: context,
builder: (context) {
String enteredPincode = '';
return AlertDialog(
title: const Text('Enter Pincode'),
content: TextField(
keyboardType: TextInputType.number,
decoration: const InputDecoration(hintText: 'Enter your pincode'),
onChanged: (value) {
enteredPincode = value;
},
),
actions: [
TextButton(
onPressed: () => Navigator.of(context).pop(),
child: const Text('Cancel'),
),
TextButton(
onPressed: () => Navigator.of(context).pop(enteredPincode),
child: const Text('Submit'),
),
],
);
},
);
if (pincode != null && pincode.isNotEmpty) {
print('Pincode entered: $pincode'); // Debug log
await _checkDeliveryAvailability(pincode: pincode);
} else {
print('No pincode entered'); // Debug log
}
}
Future<void> _onRefresh() async {
debugPrint('Refreshing home screen...');
await _getUserLocation();
final homeProvider = Provider.of<HomeProvider>(context, listen: false);
await Future.wait([
homeProvider.fetchBanners(),
homeProvider.fetchCategories(),
homeProvider.fetchNearbyRestaurants(),
homeProvider.fetchTopRatedRestaurants(),
]);
debugPrint('Banners: ${homeProvider.banners}');
debugPrint('Categories: ${homeProvider.categories}');
debugPrint('Nearby Restaurants: ${homeProvider.nearbyRestaurants}');
debugPrint('Top-rated Restaurants: ${homeProvider.topRatedRestaurants}');
}
void _selectCategory(String category) {
setState(() {
if (category == 'All') {
_selectedCategory = null;
} else if (_selectedCategory == category) {
_selectedCategory = null;
} else {
_selectedCategory = category;
}
debugPrint('Selected category: $_selectedCategory');
});
}
// *** NEW: Function to conditionally show address sheet after build ***
void _conditionallyShowAddressSheet() {
// Check if data is loaded, no address is set, and sheet hasn't been shown yet
final homeProvider = Provider.of<HomeProvider>(context, listen: false);
if (!homeProvider.isLoading && globalCurrentAddress == null && !_addressSheetShownAfterLoad) {
// Mark as shown immediately to prevent multiple triggers during rebuilds
_addressSheetShownAfterLoad = true;
// Schedule the sheet to be shown after the current frame is built
WidgetsBinding.instance.addPostFrameCallback((_) {
if (mounted) { // Ensure widget is still in the tree
_showAddressSelectionSheet(context);
}
});
}
}
@override
Widget build(BuildContext context) {
final homeProvider = Provider.of<HomeProvider>(context);
final cartProvider = Provider.of<CartProvider>(context);
// *** Call the function to check if sheet should be shown ***
_conditionallyShowAddressSheet();
final filteredPopularFood = _selectedCategory == null
? homeProvider.popularFoodItems
: homeProvider.popularFoodItems
.where((item) {
final itemCategory = item['category']?.toString()?.toLowerCase() ?? '';
final itemCuisine = item['cuisine_type']?.toString()?.toLowerCase() ?? '';
final selected = _selectedCategory!.toLowerCase();
final match = itemCategory == selected || itemCuisine == selected;
// Debug print to see values being compared
// Remove this print once filtering works
// debugPrint('Filtering item: ${item['name']} - Category: "$itemCategory", Cuisine: "$itemCuisine" | Selected: "$selected" | Match: $match');
return match;
})
.toList();
// Determine body based on loading, error, or delivery status
Widget bodyContent;
if (homeProvider.isLoading) {
bodyContent = const Center(child: CircularProgressIndicator(
valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
));
} else if (homeProvider.error != null) {
bodyContent = Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Text(homeProvider.error!),
const SizedBox(height: 16),
ElevatedButton(
onPressed: _initializeHomeScreenData, // Retry data fetch
style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
child: const Text('Retry Data'),
),
],
),
);
} else {
// Show main content (potentially with a delivery unavailable message if needed)
// The address display will show "Select Address" if globalCurrentAddress is null
bodyContent = Container(
decoration: BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
colors: [
Colors.orange.withOpacity(0.1),
Colors.white,
],
),
),
child: RefreshIndicator(
onRefresh: _onRefresh,
color: Colors.orange,
child: SingleChildScrollView(
physics: const AlwaysScrollableScrollPhysics(),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// Display Current Address Section
Padding(
padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
child: InkWell( // Make tappable
onTap: () => _showAddressSelectionSheet(context),
child: Row(
crossAxisAlignment: CrossAxisAlignment.center,
children: [
const Icon(Icons.location_on_outlined, color: Colors.orange, size: 20),
const SizedBox(width: 8),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text('Delivering To', style: TextStyle(fontSize: 11, color: Colors.grey)),
Text(
// Combine address line 1 and city if available
_formatDisplayAddress(globalCurrentAddress),
style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
overflow: TextOverflow.ellipsis,
),
],
),
),
const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
],
),
),
),
const Divider(height: 1), // Separator
// Optional: Show a non-blocking warning if delivery unavailable but location known
if (!_isDeliveryAvailable && !_locationPermissionDenied)
Padding(
padding: const EdgeInsets.all(8.0),
child: Card(
color: Colors.yellow.shade100,
child: const ListTile(
leading: Icon(Icons.warning_amber_rounded, color: Colors.orange),
title: Text('Delivery currently unavailable for your location.', style: TextStyle(fontSize: 14)),
),
),
),
// Banners Section
if (homeProvider.banners.isNotEmpty)
Container(
height: 150,
margin: const EdgeInsets.symmetric(vertical: 8),
child: ListView.builder(
scrollDirection: Axis.horizontal,
itemCount: homeProvider.banners.length,
itemBuilder: (context, index) {
return Padding(
padding: const EdgeInsets.symmetric(horizontal: 8),
child: ClipRRect(
borderRadius: BorderRadius.circular(8),
child: Image.network(
homeProvider.banners[index],
fit: BoxFit.cover,
errorBuilder: (context, error, stackTrace) {
return Container(
width: 280,
color: Colors.grey[200],
child: const Center(
child: Icon(Icons.error_outline),
),
);
},
),
),
);
},
),
),
// Categories Section - Updated to GridView
if (homeProvider.categories.isNotEmpty) ...[
const Padding(
padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
child: Text(
'Categories',
style: TextStyle(
fontSize: 20,
fontWeight: FontWeight.bold,
color: Colors.orange,
),
),
),
// Use GridView for categories with images
Padding(
padding: const EdgeInsets.symmetric(horizontal: 12.0),
child: GridView.builder(
shrinkWrap: true, // Important inside SingleChildScrollView
physics: const NeverScrollableScrollPhysics(), // Disable GridView's own scrolling
gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
crossAxisCount: 4, // Adjust number of columns
crossAxisSpacing: 8,
mainAxisSpacing: 8,
childAspectRatio: 0.85, // Adjust aspect ratio (width/height)
),
itemCount: homeProvider.categories.length,
itemBuilder: (context, index) {
final category = homeProvider.categories[index];
final categoryName = category['name']?.toString() ?? 'N/A';
final imageUrl = category['image_url']?.toString() ?? '';
final isSelected = _selectedCategory == categoryName;
return GestureDetector(
onTap: () => _selectCategory(categoryName),
child: Card(
elevation: isSelected ? 4 : 1,
color: isSelected ? Colors.orange.shade50 : Colors.white,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(10),
side: BorderSide(
color: isSelected ? Colors.orange : Colors.grey.shade300,
width: isSelected ? 1.5 : 1,
),
),
clipBehavior: Clip.antiAlias,
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Expanded(
flex: 3, // Give more space to image
child: Padding(
padding: const EdgeInsets.only(top: 6.0),
child: _buildCategoryImage(imageUrl), // Image helper
),
),
Expanded(
flex: 2, // Less space for text
child: Padding(
padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
child: Text(
categoryName,
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 11, // Smaller font size
fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
color: isSelected ? Colors.orange.shade800 : Colors.black87,
),
maxLines: 2, // Allow text wrapping
overflow: TextOverflow.ellipsis,
),
),
),
],
),
),
);
},
),
),
],
// Popular Food Items Section - Use filtered list
if (filteredPopularFood.isNotEmpty) ...[
const Padding(
padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
child: Text(
'Popular Food Items',
style: TextStyle(
fontSize: 20,
fontWeight: FontWeight.bold,
color: Colors.orange,
),
),
),
Container(
height: 190,
margin: const EdgeInsets.only(bottom: 16),
child: ListView.builder(
scrollDirection: Axis.horizontal,
padding: const EdgeInsets.symmetric(horizontal: 12),
itemCount: filteredPopularFood.length,
itemBuilder: (context, index) {
final foodItem = filteredPopularFood[index];
// Wrap FoodCard with GestureDetector
return GestureDetector(
onTap: () => _showFoodDetailsDialog(context, foodItem),
child: FoodCard(food: foodItem),
);
},
),
),
] else if (_selectedCategory != null) ...[
Padding(
padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
child: Center(
child: Text(
'No popular items found for "$_selectedCategory".',
style: const TextStyle(color: Colors.grey, fontSize: 15),
),
),
),
],
// Nearby Restaurants Section
if (homeProvider.nearbyRestaurants.isNotEmpty) ...[
const Padding(
padding: EdgeInsets.all(16),
child: Text(
'Nearby Restaurants',
style: TextStyle(
fontSize: 22,
fontWeight: FontWeight.bold,
color: Colors.orange,
),
),
),
Container(
height: 180,
margin: const EdgeInsets.only(bottom: 16),
child: ListView.builder(
scrollDirection: Axis.horizontal,
itemCount: homeProvider.nearbyRestaurants.length,
itemBuilder: (context, index) {
final restaurant = homeProvider.nearbyRestaurants[index];
return RestaurantCard(restaurant: restaurant);
},
),
),
],
// Top-rated Restaurants Section
if (homeProvider.topRatedRestaurants.isNotEmpty) ...[
const Padding(
padding: EdgeInsets.all(16),
child: Text(
'Top-rated Restaurants',
style: TextStyle(
fontSize: 22,
fontWeight: FontWeight.bold,
color: Colors.orange,
),
),
),
Container(
height: 180,
margin: const EdgeInsets.only(bottom: 16),
child: ListView.builder(
scrollDirection: Axis.horizontal,
itemCount: homeProvider.topRatedRestaurants.length,
itemBuilder: (context, index) {
final restaurant = homeProvider.topRatedRestaurants[index];
return RestaurantCard(restaurant: restaurant);
},
),
),
],
],
),
),
),
);
}
return Scaffold(
appBar: AppBar(
title: const Text('Food Delivery App'),
backgroundColor: Colors.orange,
elevation: 0,
actions: [
IconButton(
icon: const Icon(Icons.search),
onPressed: () {
Navigator.push(
context,
MaterialPageRoute(builder: (context) => const SearchScreen()),
);
},
),
Stack(
alignment: Alignment.center,
children: [
IconButton(
icon: const Icon(Icons.shopping_cart_outlined),
onPressed: () {
Navigator.push(
context,
MaterialPageRoute(builder: (context) => const CartScreen()),
);
},
),
if (cartProvider.itemCount > 0)
Positioned(
right: 8,
top: 8,
child: Container(
padding: const EdgeInsets.all(2),
decoration: BoxDecoration(
color: Colors.red,
borderRadius: BorderRadius.circular(10),
),
constraints: const BoxConstraints(
minWidth: 16,
minHeight: 16,
),
child: Text(
cartProvider.itemCount.toString(),
style: const TextStyle(
color: Colors.white,
fontSize: 10,
),
textAlign: TextAlign.center,
),
),
),
],
),
IconButton(
icon: const Icon(Icons.person_outline),
tooltip: 'My Profile',
onPressed: () {
Navigator.push(
context,
MaterialPageRoute(builder: (context) => const ProfileScreen()),
);
},
),
],
),
body: bodyContent, // Use the determined body content
);
}
// Helper function to format address for display
String _formatDisplayAddress(Map<String, dynamic>? address) {
if (address == null) return 'Select Address';
final line1 = address['address_line1']?.toString() ?? '';
final city = address['city']?.toString() ?? '';
final state = address['state']?.toString() ?? '';
// Improved formatting logic
List<String> parts = [];
if (line1.isNotEmpty) parts.add(line1);
if (city.isNotEmpty) parts.add(city);
if (state.isNotEmpty) parts.add(state);
if (parts.isEmpty) {
return 'Address Details Missing';
} else {
return parts.join(', '); // Join parts with comma and space
}
}
// Helper method to show address selection bottom sheet
void _showAddressSelectionSheet(BuildContext context) async {
List<Map<String, dynamic>> savedAddresses = [];
bool isLoading = true;
String? fetchError;
// --- Fetch addresses when the sheet is opened ---
if (globalCustomerId != null) {
try {
final dio = Dio();
// *** START CHANGE: Add Auth Header ***
final String? token = await AuthStorage.getToken(); // Retrieve token
final options = Options();
if (token != null) {
options.headers = {'Authorization': 'Bearer $token'};
debugPrint('(Sheet) Adding Auth header to fetch addresses request.');
} else {
debugPrint('(Sheet) No auth token found for fetch addresses request.');
}
// *** END CHANGE ***
final url = '${AppConfig.baseUrl}/customer/$globalCustomerId/addresses/';
debugPrint('(Sheet) Fetching addresses from: $url');
final response = await dio.get(
url,
options: options, // <-- Pass the options with potential header
);
debugPrint('(Sheet) Raw Response Data: ${response.data}'); // <<< SHEET DEBUG
if (response.statusCode == 200 && response.data is List) {
// <<< SHEET DEBUG - Print before parsing
debugPrint('(Sheet) Data before parsing: ${response.data}');
savedAddresses = List<Map<String, dynamic>>.from(
(response.data as List).where((item) => item is Map).map((item) => Map<String, dynamic>.from(item))
);
// <<< SHEET DEBUG - Print after parsing
debugPrint('(Sheet) Parsed savedAddresses: $savedAddresses');
} else {
fetchError = 'Failed to load addresses.';
debugPrint('(Sheet) Fetch failed, status: ${response.statusCode}'); // <<< SHEET DEBUG
}
} catch (e) {
fetchError = 'Could not load addresses.';
debugPrint('(Sheet) Fetch error: $e'); // <<< SHEET DEBUG
// Consider checking for 401/403 Unauthorized errors here as well
if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
fetchError = 'Authentication failed. Please log in again.';
// Optionally clear token, etc.
}
}
} else {
fetchError = 'Not logged in.';
}
isLoading = false;
// --- End fetch ---
// Use a stateful builder to handle async loading within the sheet
showModalBottomSheet(
context: context,
isScrollControlled: true, // Allows sheet to take more height if needed
shape: const RoundedRectangleBorder(
borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
),
builder: (sheetContext) {
// Use StatefulBuilder to manage loading/error state within the sheet
return StatefulBuilder(
builder: (BuildContext context, StateSetter setSheetState) {
// Function to refresh addresses within the sheet (e.g., after adding)
Future<void> refreshAddresses() async {
setSheetState(() { isLoading = true; fetchError = null; });
// Re-run fetch logic
if (globalCustomerId != null) {
try {
final dio = Dio();
// *** START CHANGE: Add Auth Header ***
final String? token = await AuthStorage.getToken(); // Retrieve token
final options = Options();
if (token != null) {
options.headers = {'Authorization': 'Bearer $token'};
}
// *** END CHANGE ***
final url = '${AppConfig.baseUrl}/customer/$globalCustomerId/addresses/';
final response = await dio.get(
url,
options: options, // <-- Pass options
);
if (response.statusCode == 200 && response.data is List) {
savedAddresses = List<Map<String, dynamic>>.from(
(response.data as List).where((item) => item is Map).map((item) => Map<String, dynamic>.from(item))
);
} else { fetchError = 'Failed to load addresses.'; }
} catch (e) { fetchError = 'Could not load addresses.'; }
} else { fetchError = 'Not logged in.'; }
isLoading = false;
// Crucially update the sheet's state
setSheetState(() {});
}
// Function to navigate to add screen and refresh on return
void goToAddAddress() async {
Navigator.pop(sheetContext); // Close sheet first
final result = await Navigator.push(
context,
MaterialPageRoute(builder: (context) => const AddEditAddressScreen())
);
if (result == true) { // If address was added
// Re-show the sheet and refresh its content (or just refresh HomeScreen)
// Option 1: Just refresh HomeScreen (simpler)
// setState((){}); // Trigger HomeScreen rebuild to show new address potentially
// Option 2: Re-show sheet with updated data (better UX)
_showAddressSelectionSheet(context);
}
}
// Function to show pincode dialog and check delivery
void checkDeliveryWithPincode() async {
Navigator.pop(sheetContext); // Close sheet first
await _askForPincode(); // Reuse existing pincode dialog logic
}
// <<<--- ADD DEBUG PRINT HERE --->>
debugPrint('(Sheet Builder) isLoading: $isLoading, fetchError: $fetchError, savedAddresses count: ${savedAddresses.length}');
final bool shouldShowList = !isLoading && fetchError == null && savedAddresses.isNotEmpty;
debugPrint('(Sheet Builder) Condition to show list (shouldShowList): $shouldShowList');
// <<<--- END DEBUG PRINT --->>
return Padding(
padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), // Adjust for keyboard
child: Container(
padding: const EdgeInsets.all(16),
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
const Text('Select Delivery Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(sheetContext)),
],
),
const Divider(height: 20),
if (isLoading)
const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())),
if (!isLoading && fetchError != null)
Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20.0), child: Text(fetchError!, style: TextStyle(color: Colors.red)))),
if (!isLoading && fetchError == null && savedAddresses.isEmpty) ...[
const SizedBox(height: 10),
Center(
child: OutlinedButton.icon(
icon: const Icon(Icons.pin_drop_outlined, size: 16),
label: const Text('Check Delivery via Pincode'),
onPressed: checkDeliveryWithPincode,
style: OutlinedButton.styleFrom(
foregroundColor: Colors.orange,
side: BorderSide(color: Colors.orange.shade200),
),
),
),
],
// Use the debugged condition here
if (shouldShowList) // <<<--- Use the boolean variable
LimitedBox(
maxHeight: MediaQuery.of(context).size.height * 0.35, // Increased height slightly
child: ListView.builder(
shrinkWrap: true,
itemCount: savedAddresses.length,
itemBuilder: (listContext, index) {
final address = savedAddresses[index];
final bool isCurrent = globalCurrentAddress?['id'] == address['id'];
final addressLine1 = address['address_line_1']?.toString() ?? ''; // Get address line 1 safely
// <<<--- ADD FINAL DEBUG CHECK HERE --->>
debugPrint('(Sheet ListTile Builder) Index: $index, Address ID: ${address['id']}, value for title: "$addressLine1", isEmpty: ${addressLine1.isEmpty}');
return ListTile(
leading: Icon(
isCurrent ? Icons.check_circle : Icons.radio_button_unchecked,
color: isCurrent ? Colors.orange : Colors.grey,
size: 22,
),
// Use the safe addressLine1 and provide placeholder if empty
title: Text(addressLine1.isNotEmpty ? addressLine1 : '(No Address Line 1)'),
subtitle: Text('${address['city'] ?? ''}, ${address['state'] ?? ''} ${address['postal_code'] ?? ''}'),
onTap: () {
// Set the global address
final selectedAddress = Map<String, dynamic>.from(address); // Create copy
setState(() { // Update HomeScreen's state
globalCurrentAddress = selectedAddress;
saveCurrentAddressId(selectedAddress['id']?.toString()); // Save preference
});
Navigator.pop(sheetContext); // Close the sheet
// Trigger delivery check with the NEWLY selected address details
_checkDeliveryAvailability(
latitude: (selectedAddress['latitude'] as num?)?.toDouble(),
longitude: (selectedAddress['longitude'] as num?)?.toDouble(),
pincode: selectedAddress['postal_code']?.toString()
);
},
);
},
),
),
const Divider(height: 20),
Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
TextButton.icon(
icon: const Icon(Icons.add_circle_outline, size: 16),
label: const Text('Add New Address'),
onPressed: goToAddAddress,
),
const SizedBox(width: 10),
TextButton.icon(
icon: const Icon(Icons.settings_outlined, size: 16),
label: const Text('Manage All'),
onPressed: () {
Navigator.pop(sheetContext); // Close sheet first
Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
},
),
],
),
// --- Option to Check Pincode (alternative place) ---
if (!isLoading && fetchError == null) ...[
const SizedBox(height: 10),
Center(
child: TextButton.icon(
icon: const Icon(Icons.pin_drop_outlined, size: 16),
label: const Text('Or Check Delivery via Pincode'),
onPressed: checkDeliveryWithPincode,
style: TextButton.styleFrom(foregroundColor: Colors.orange.shade700)
),
),
],
],
),
),
);
},
);
},
);
}
// Helper method to build category image widgets
Widget _buildCategoryImage(String imageUrl) {
// Use similar logic as _buildCartItemImage or FoodCard._buildImage
Uri? uri = Uri.tryParse(imageUrl);
bool isNetworkUrl = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
bool isLocalAsset = imageUrl.startsWith('assets/');
// Handle relative paths from server
if (!isNetworkUrl && !isLocalAsset && imageUrl.startsWith('/')) {
imageUrl = '${AppConfig.baseUrl}$imageUrl';
uri = Uri.tryParse(imageUrl);
isNetworkUrl = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
}
Widget placeholder = Icon(Icons.category_outlined, size: 30, color: Colors.grey.shade400);
if (imageUrl.isEmpty || (!isNetworkUrl && !isLocalAsset)) {
return placeholder;
}
if (isNetworkUrl) {
return Image.network(
imageUrl,
fit: BoxFit.contain, // Contain might be better than cover here
errorBuilder: (context, error, stackTrace) => placeholder,
loadingBuilder: (context, child, progress) {
if (progress == null) return child;
// Simple progress indicator
return Center(child: CircularProgressIndicator(value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null, strokeWidth: 2));
},
);
} else { // isLocalAsset
return Image.asset(
imageUrl,
fit: BoxFit.contain,
errorBuilder: (context, error, stackTrace) => placeholder,
);
}
}
// --- Copied Helper Method to Show Food Details Dialog --- (From MenuScreen)
void _showFoodDetailsDialog(BuildContext context, Map<String, dynamic> foodItem) {
final imageUrl = foodItem['image']?.toString() ?? '';
final description = foodItem['description']?.toString() ?? 'No description available.';
final rating = (foodItem['rating'] as num?)?.toDouble(); // Can be null
final priceValue = foodItem['price'];
final price = priceValue?.toString() ?? ''; // Get price for display
showDialog(
context: context,
builder: (ctx) => AlertDialog(
contentPadding: EdgeInsets.zero, // Remove default padding
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
content: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
// Image Header
ClipRRect(
borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
child: Container(
height: 150,
width: double.infinity,
child: _buildDialogImage(imageUrl), // Use helper
),
),
// Details Padding
Padding(
padding: const EdgeInsets.all(16.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(foodItem['name'] ?? 'Food Item', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
// Display Price
if (price.isNotEmpty)
Padding(
padding: const EdgeInsets.only(top: 4.0),
child: Text('₹$price', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
),
// Display Rating
if (rating != null)
Padding(
padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
child: Row(
children: [
Icon(Icons.star, color: Colors.amber.shade700, size: 16),
const SizedBox(width: 4),
Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w500)),
],
),
),
const SizedBox(height: 8),
Text(description, style: const TextStyle(fontSize: 14, color: Colors.black54)),
],
),
),
],
),
),
actions: [
TextButton(
child: const Text('Close'),
onPressed: () => Navigator.of(ctx).pop(),
),
// Add to Cart button in dialog
ElevatedButton.icon(
icon: const Icon(Icons.add_shopping_cart, size: 16),
label: const Text('Add to Cart'),
style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
onPressed: () {
// Ensure item has necessary info before adding
if (foodItem['id'] != null && priceValue != null) {
final cartItem = Map<String, dynamic>.from(foodItem);
cartItem['price'] = (priceValue is num) ? priceValue : (double.tryParse(price) ?? 0.0);
Provider.of<CartProvider>(context, listen: false).addToCart(cartItem);
Navigator.of(ctx).pop(); // Close dialog
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Added "${cartItem['name'] ?? 'Item'}" to cart!'), duration: Duration(seconds: 1))
);
} else {
Navigator.of(ctx).pop(); // Close dialog
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Could not add item: Missing details.'), duration: Duration(seconds: 2), backgroundColor: Colors.red)
);
}
},
)
],
),
);
}
// --- Copied Helper to build image for the dialog --- (From MenuScreen)
Widget _buildDialogImage(String imageUrl) {
Uri? uri = Uri.tryParse(imageUrl);
bool isNetworkUrl = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
bool isLocalAsset = imageUrl.startsWith('assets/');
if (!isNetworkUrl && !isLocalAsset && imageUrl.startsWith('/')) {
imageUrl = '${AppConfig.baseUrl}$imageUrl';
uri = Uri.tryParse(imageUrl);
isNetworkUrl = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
}
Widget placeholder = const FittedBox(
fit: BoxFit.contain,
child: Icon(Icons.fastfood, size: 60, color: Colors.grey),
);
if (imageUrl.isEmpty || (!isNetworkUrl && !isLocalAsset)) {
return placeholder;
}
if (isNetworkUrl) {
return Image.network(
imageUrl,
fit: BoxFit.cover,
errorBuilder: (context, error, stackTrace) => placeholder,
loadingBuilder: (context, child, progress) {
if (progress == null) return child;
return const Center(child: CircularProgressIndicator(strokeWidth: 2));
},
);
} else { // isLocalAsset
return Image.asset(
imageUrl,
fit: BoxFit.cover,
errorBuilder: (context, error, stackTrace) => placeholder,
);
}
}
Future<void> _checkAuthenticationStatus() async {
if (mounted) {
final authProvider = Provider.of<AuthProvider>(context, listen: false);
final isAuthenticated = await authProvider.isAuthenticated();
if (!isAuthenticated) {
// Try to load customer ID from storage again
final customerId = await AuthStorage.getCustomerId();
if (customerId != null && customerId.isNotEmpty) {
globalCustomerId = customerId;
// Also make sure we have a token
final token = await AuthStorage.getToken();
if (token == null || token.isEmpty) {
_redirectToLogin();
}
} else {
_redirectToLogin();
}
}
}
}
}
class RestaurantCard extends StatelessWidget {
final Map<String, dynamic> restaurant;
const RestaurantCard({Key? key, required this.restaurant}) : super(key: key);
@override
Widget build(BuildContext context) {
debugPrint('Restaurant Data in Card: $restaurant');
final name = restaurant['name'] ?? 'Unknown Restaurant';
final rating = (restaurant['rating'] ?? 0.0).toDouble();
final cuisineType = restaurant['cuisine_type'] ?? 'Various Cuisines';
final imageUrl = restaurant['image'] ?? '';
// Match the pattern from SearchResult - use vendor_id if available, fallback to id
final vendorId = restaurant['vendor_id']?.toString() ?? restaurant['id']?.toString() ?? '';
debugPrint('Building RestaurantCard - vendorId: $vendorId');
return GestureDetector(
onTap: () {
if (vendorId.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Restaurant ID not found')),
);
return;
}
debugPrint('Navigating to restaurant-detail with vendorId: $vendorId');
Navigator.pushNamed(
context,
'/restaurant-detail',
arguments: {
'vendor_id': vendorId,
},
);
},
child: SizedBox(
width: 160,
height: 180,
child: Card(
elevation: 4,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
child: Column(
children: [
ClipRRect(
borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
child: SizedBox(
height: 100,
width: double.infinity,
child: _buildImage(imageUrl, name),
),
),
Expanded(
child: Padding(
padding: const EdgeInsets.all(8.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisSize: MainAxisSize.min,
children: [
Text(
name,
style: const TextStyle(
fontWeight: FontWeight.bold,
fontSize: 13,
),
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
const SizedBox(height: 2),
Text(
cuisineType,
style: TextStyle(
color: Colors.grey[600],
fontSize: 11,
),
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
const Spacer(),
Row(
children: [
Icon(
Icons.star,
size: 14,
color: rating > 0 ? Colors.amber[700] : Colors.grey[400],
),
const SizedBox(width: 2),
Text(
rating > 0 ? rating.toStringAsFixed(1) : 'New',
style: TextStyle(
fontWeight: FontWeight.w500,
fontSize: 11,
color: rating > 0 ? Colors.black87 : Colors.grey[600],
),
),
],
),
],
),
),
),
],
),
),
),
);
}
// *** REPLACE THIS METHOD ***
Widget _buildImage(String imageUrl, String name) {
Uri? uri = Uri.tryParse(imageUrl);
bool isNetworkUrl = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
bool isLocalAsset = imageUrl.startsWith('assets/');
// Handle relative paths from server (if applicable)
if (!isNetworkUrl && !isLocalAsset && imageUrl.startsWith('/')) {
imageUrl = '${AppConfig.baseUrl}$imageUrl'; // Assuming AppConfig is available or adjust as needed
uri = Uri.tryParse(imageUrl);
isNetworkUrl = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
debugPrint('(RestaurantCard) Corrected relative image URL to: $imageUrl');
}
if (imageUrl.isEmpty || (!isNetworkUrl && !isLocalAsset)) {
if (imageUrl.isNotEmpty) {
debugPrint('(RestaurantCard) Invalid or unhandled image URL format: $imageUrl');
}
return _buildPlaceholderImage(name);
}
if (isNetworkUrl) {
return Image.network(
imageUrl,
fit: BoxFit.cover,
loadingBuilder: (context, child, loadingProgress) {
if (loadingProgress == null) return child;
return Center(child: CircularProgressIndicator(
value: loadingProgress.expectedTotalBytes != null
? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
: null,
strokeWidth: 2,
valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
));
},
errorBuilder: (context, error, stackTrace) {
debugPrint('(RestaurantCard) Error loading network image "$imageUrl": $error');
return _buildPlaceholderImage(name);
},
);
} else { // isLocalAsset
return Image.asset(
imageUrl,
fit: BoxFit.cover,
errorBuilder: (context, error, stackTrace) {
debugPrint('(RestaurantCard) Error loading asset image "$imageUrl": $error');
return _buildPlaceholderImage(name);
},
);
}
}
Widget _buildPlaceholderImage(String name) {
return Container(
color: Colors.grey[200],
child: Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Icons.restaurant, size: 32, color: Colors.grey[400]),
const SizedBox(height: 4),
Padding(
padding: const EdgeInsets.symmetric(horizontal: 4),
child: Text(
name,
style: TextStyle(color: Colors.grey[600], fontSize: 12),
textAlign: TextAlign.center,
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
),
],
),
),
);
}
}
class FoodCard extends StatelessWidget {
final Map<String, dynamic> food;
const FoodCard({Key? key, required this.food}) : super(key: key);
@override
Widget build(BuildContext context) {
// Ensure data types and handle nulls gracefully
final name = food['name']?.toString() ?? 'Unknown Food';
final priceValue = food['price'];
final price = priceValue?.toString() ?? '0.00';
final rating = (food['rating'] as num?)?.toDouble() ?? 0.0;
// *** START CHANGE ***
// Prioritize the first URL from image_urls if available
final imageList = food['image_urls'] as List?;
String imageUrl = '';
if (imageList != null && imageList.isNotEmpty && imageList[0] is String) {
imageUrl = imageList[0] as String;
} else {
// Fallback to the 'image' field if 'image_urls' is missing or empty
imageUrl = food['image']?.toString() ?? '';
}
// *** END CHANGE ***
final cartProvider = Provider.of<CartProvider>(context, listen: false);
debugPrint('FoodCard data: $food'); // Log data for debugging nulls
debugPrint('FoodCard using image URL: $imageUrl'); // Log the URL being used
return SizedBox(
width: 140,
height: 180,
child: Card(
elevation: 3,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(10),
),
margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
clipBehavior: Clip.antiAlias,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
SizedBox(
height: 80,
width: double.infinity,
child: _buildImage(imageUrl, name), // Pass the potentially updated imageUrl
),
Expanded(
child: Padding(
padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
name,
style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
maxLines: 1, overflow: TextOverflow.ellipsis,
),
Text(
'₹$price',
style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.bold, fontSize: 11),
maxLines: 1, overflow: TextOverflow.ellipsis,
),
const SizedBox(height: 1),
Row(
children: [
Icon(Icons.star, size: 12, color: rating > 0 ? Colors.amber[700] : Colors.grey[400]),
const SizedBox(width: 2),
Text(
rating > 0 ? rating.toStringAsFixed(1) : 'New',
style: TextStyle(fontWeight: FontWeight.w500, fontSize: 10, color: rating > 0 ? Colors.black87 : Colors.grey[600]),
maxLines: 1, overflow: TextOverflow.ellipsis,
),
],
),
const Spacer(),
SizedBox(
width: double.infinity,
height: 24,
child: ElevatedButton(
onPressed: () {
if (food['id'] != null && name != 'Unknown Food' && priceValue != null) {
final cartItem = Map<String, dynamic>.from(food);
cartItem['price'] = (priceValue is num) ? priceValue : (double.tryParse(price) ?? 0.0);
cartProvider.addToCart(cartItem);
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Added "$name" to cart'),
duration: const Duration(seconds: 1),
backgroundColor: Colors.green[700],
),
);
} else {
debugPrint('Cannot add item to cart: Missing details - $food');
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Cannot add item: Missing details'),
duration: Duration(seconds: 2),
backgroundColor: Colors.red,
),
);
}
},
style: ElevatedButton.styleFrom(
backgroundColor: Colors.orange,
padding: EdgeInsets.zero,
textStyle: const TextStyle(fontSize: 11),
tapTargetSize: MaterialTapTargetSize.shrinkWrap,
),
child: const Text('Add to Cart'),
),
),
],
),
),
),
],
),
),
);
}
Widget _buildImage(String imageUrl, String name) {
Uri? uri = Uri.tryParse(imageUrl);
bool isNetworkUrl = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
bool isLocalAsset = imageUrl.startsWith('assets/');
if (!isNetworkUrl && !isLocalAsset && imageUrl.startsWith('/')) {
imageUrl = '${AppConfig.baseUrl}$imageUrl';
uri = Uri.tryParse(imageUrl);
isNetworkUrl = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
debugPrint('Corrected relative image URL to: $imageUrl');
}
if (imageUrl.isEmpty || (!isNetworkUrl && !isLocalAsset)) {
if (imageUrl.isNotEmpty) {
debugPrint('Invalid or unhandled image URL format: $imageUrl');
}
return _buildPlaceholderImage(name);
}
if (isNetworkUrl) {
return Image.network(
imageUrl,
fit: BoxFit.cover,
loadingBuilder: (context, child, loadingProgress) {
if (loadingProgress == null) return child;
return Center(child: CircularProgressIndicator(
value: loadingProgress.expectedTotalBytes != null
? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
: null,
strokeWidth: 2,
valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
));
},
errorBuilder: (context, error, stackTrace) {
debugPrint('Error loading network image "$imageUrl": $error');
return _buildPlaceholderImage(name);
},
);
} else {
return Image.asset(
imageUrl,
fit: BoxFit.cover,
errorBuilder: (context, error, stackTrace) {
debugPrint('Error loading asset image "$imageUrl": $error');
return _buildPlaceholderImage(name);
},
);
}
}
Widget _buildPlaceholderImage(String name) {
return Container(
color: Colors.grey[200],
child: Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Icons.fastfood, size: 24, color: Colors.orange[300]),
const SizedBox(height: 4),
Padding(
padding: const EdgeInsets.symmetric(horizontal: 4),
child: Text(
name,
style: TextStyle(color: Colors.grey[600], fontSize: 10),
textAlign: TextAlign.center,
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
),
],
),
),
);
}
}
class RestaurantSearchDelegate extends SearchDelegate {
final HomeProvider homeProvider;
RestaurantSearchDelegate(this.homeProvider);
@override
List<Widget>? buildActions(BuildContext context) {
return [
IconButton(
icon: const Icon(Icons.clear),
onPressed: () {
query = '';
},
),
];
}
@override
Widget? buildLeading(BuildContext context) {
return IconButton(
icon: const Icon(Icons.arrow_back),
onPressed: () {
close(context, null);
},
);
}
@override
Widget buildResults(BuildContext context) {
final results = homeProvider.searchRestaurants(query) ?? [];
return results.isEmpty
? const Center(child: Text('No results found'))
: ListView.builder(
itemCount: results.length,
itemBuilder: (context, index) {
return ListTile(
title: Text(results[index]['name'] ?? 'Unknown'),
subtitle: Text(results[index]['description'] ?? 'No description available'),
);
},
);
}
@override
Widget buildSuggestions(BuildContext context) {
return const Center(child: Text('Search for restaurants'));
}
}
Profilescreen.dart...
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
for additional.. add_edit_addressscreen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../config.dart';
import '../utils/globals.dart';
// Purpose: Provides a form for adding a new address or editing an existing one.
class AddEditAddressScreen extends StatefulWidget {
final Map<String, dynamic>? address; // Pass address map for editing, null for adding
const AddEditAddressScreen({Key? key, this.address}) : super(key: key);
@override
_AddEditAddressScreenState createState() => _AddEditAddressScreenState();
}
class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
final _formKey = GlobalKey<FormState>();
final _addressLine1Controller = TextEditingController();
final _addressLine2Controller = TextEditingController(); // Optional
final _cityController = TextEditingController();
final _postalCodeController = TextEditingController();
final _typeController = TextEditingController(); // e.g., Home, Work, Other
final _stateController = TextEditingController(); // <<<--- ADDED State Controller
bool _isLoading = false;
String? _apiError;
bool get _isEditing => widget.address != null;
@override
void initState() {
super.initState();
if (_isEditing && widget.address != null) {
// Populate controllers if editing an existing address
_addressLine1Controller.text = widget.address!['address_line1']?.toString() ?? '';
_addressLine2Controller.text = widget.address!['address_line2']?.toString() ?? '';
_cityController.text = widget.address!['city']?.toString() ?? '';
_postalCodeController.text = widget.address!['postal_code']?.toString() ?? '';
_typeController.text = widget.address!['type']?.toString() ?? '';
_stateController.text = widget.address!['state']?.toString() ?? '';
}
}
@override
void dispose() {
_addressLine1Controller.dispose();
_addressLine2Controller.dispose();
_cityController.dispose();
_postalCodeController.dispose();
_typeController.dispose();
_stateController.dispose(); // <<<--- ADDED Dispose State Controller
super.dispose();
}
Future<void> _saveAddress() async {
if (!_formKey.currentState!.validate()) {
return; // Don't proceed if form is invalid
}
if (globalCustomerId == null) {
setState(() { _apiError = 'Cannot save address: Not logged in.'; });
return;
}
setState(() { _isLoading = true; _apiError = null; });
final addressData = {
'customer_id': globalCustomerId,
'address_line1': _addressLine1Controller.text,
'address_line2': _addressLine2Controller.text.isNotEmpty ? _addressLine2Controller.text : null,
'city': _cityController.text,
'postal_code': _postalCodeController.text,
'state': _stateController.text,
'type': _typeController.text.isNotEmpty ? _typeController.text : 'Other',
// Add any other required fields by your backend (e.g., state, country)
};
try {
Response response;
final String url;
final dio = Dio();
// TODO: Add auth headers if needed: dio.options.headers['Authorization'] = ...
if (_isEditing) {
// Update existing address (PUT or PATCH request)
final addressId = widget.address!['id'];
url = '${AppConfig.baseUrl}/addresses/$addressId/'; // Adjust endpoint if needed
debugPrint('Updating address ($addressId) at: $url with data: $addressData');
response = await dio.put(url, data: addressData);
} else {
// Add new address (POST request)
url = '${AppConfig.baseUrl}/addresses/'; // Adjust endpoint if needed
debugPrint('Adding new address at: $url with data: $addressData');
response = await dio.post(url, data: addressData);
}
debugPrint('Save Address Response (${response.statusCode}): ${response.data}');
if (response.statusCode == 200 || response.statusCode == 201) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Address ${_isEditing ? 'updated' : 'added'} successfully!'), backgroundColor: Colors.green)
);
Navigator.of(context).pop(true); // Pop screen and return true to signal success
} else {
setState(() {
_apiError = 'Failed to save address. Status: ${response.statusCode}';
});
}
} on DioException catch (e) {
debugPrint('Dio Error saving address: ${e.response?.data ?? e.message}');
setState(() {
_apiError = 'Error: ${e.response?.data?['detail'] ?? e.message ?? 'Failed to save address.'}';
});
} catch (e) {
debugPrint('Error saving address: $e');
setState(() {
_apiError = 'An unexpected error occurred.';
});
} finally {
if (mounted) {
setState(() { _isLoading = false; });
}
}
}
@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: Text(_isEditing ? 'Edit Address' : 'Add New Address'),
backgroundColor: Colors.orange,
foregroundColor: Colors.white,
),
body: SingleChildScrollView(
padding: const EdgeInsets.all(20.0),
child: Form(
key: _formKey,
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
TextFormField(
controller: _addressLine1Controller,
decoration: const InputDecoration(labelText: 'Address Line 1', border: OutlineInputBorder()),
validator: (value) {
if (value == null || value.trim().isEmpty) {
return 'Please enter the first line of the address.';
}
return null;
},
),
const SizedBox(height: 16),
TextFormField(
controller: _addressLine2Controller,
decoration: const InputDecoration(labelText: 'Address Line 2 (Optional)', border: OutlineInputBorder()),
// No validator needed for optional field
),
const SizedBox(height: 16),
Row(
children: [
Expanded(
child: TextFormField(
controller: _cityController,
decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
validator: (value) {
if (value == null || value.trim().isEmpty) {
return 'Please enter the city.';
}
return null;
},
),
),
const SizedBox(width: 16),
Expanded(
child: TextFormField(
controller: _stateController,
decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
validator: (value) {
if (value == null || value.trim().isEmpty) {
return 'Please enter the state.';
}
// Add validation like checking abbreviation length if needed
return null;
},
),
),
],
),
const SizedBox(height: 16),
TextFormField(
controller: _postalCodeController,
decoration: const InputDecoration(labelText: 'Postal Code', border: OutlineInputBorder()),
keyboardType: TextInputType.number, // Adjust keyboard type
validator: (value) {
if (value == null || value.trim().isEmpty) {
return 'Please enter the postal code.';
}
// Add more specific validation if needed (e.g., length, format)
return null;
},
),
const SizedBox(height: 16),
TextFormField(
controller: _typeController,
decoration: const InputDecoration(labelText: 'Address Type (e.g., Home, Work)', border: OutlineInputBorder()),
// Consider using DropdownButtonFormField if types are predefined
),
const SizedBox(height: 24),
if (_apiError != null)
Padding(
padding: const EdgeInsets.only(bottom: 16.0),
child: Text(_apiError!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
),
_isLoading
? const Center(child: CircularProgressIndicator(color: Colors.orange))
: ElevatedButton.icon(
icon: Icon(_isEditing ? Icons.save_alt : Icons.add_location_alt),
label: Text(_isEditing ? 'Update Address' : 'Save Address'),
style: ElevatedButton.styleFrom(
backgroundColor: Colors.orange,
foregroundColor: Colors.white,
padding: const EdgeInsets.symmetric(vertical: 14),
textStyle: const TextStyle(fontSize: 16),
),
onPressed: _saveAddress,
),
],
),
),
),
);
}
}  


