import 'package:flutter/material.dart';
import 'package:foodondoor_customer/mainScreens/placed_order_screen.dart';
import 'package:foodondoor_customer/mainScreens/save_address_screen.dart';
import 'package:foodondoor_customer/models/address.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../utils/app_config.dart';
import 'package:foodondoor_customer/providers/auth_provider.dart';
import 'package:foodondoor_customer/widgets/address_design.dart';
import 'package:foodondoor_customer/widgets/progress_bar.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AddressScreen extends StatefulWidget {
  final double? totalAmount;
  final String? sellerUID;

  const AddressScreen({Key? key, this.totalAmount, this.sellerUID}) : super(key: key);

  @override
  _AddressScreenState createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  List<Address> _addresses = [];
  int? _selectedAddressId;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      if (token == null) {
        setState(() {
          _errorMessage = "Not logged in.";
          _isLoading = false;
        });
        return;
      }
      final dio = Dio();
      final response = await dio.get(
        '${AppConfig.baseUrl}/api/addresses/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      debugPrint('Get Addresses Status Code: \u001b[32m${response.statusCode}\u001b[0m');
      debugPrint('Get Addresses Response Body: \u001b[36m${response.data}\u001b[0m');
      if (response.statusCode == 200) {
        List<dynamic> body = response.data;
        List<Address> addresses = body
            .map((dynamic item) => Address.fromJson(item as Map<String, dynamic>))
            .toList();
        setState(() {
          _addresses = addresses;
          if (_addresses.isNotEmpty) {
            final defaultAddress = _addresses.firstWhere((addr) => addr.is_default == true, orElse: () => _addresses.first);
            _selectedAddressId = defaultAddress.id;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load addresses. Status code: \u001b[31m${response.statusCode}\u001b[0m';
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      setState(() {
        _errorMessage = 'Failed to load addresses: \u001b[31m${e.message}\u001b[0m';
        _isLoading = false;
      });
      debugPrint('Failed to load addresses: ${e.message}');
    }
  }

  void _handleSelectAddress(int addressId) {
    setState(() {
      _selectedAddressId = addressId;
    });
  }

  void _navigateToAddAddress() {
    debugPrint("Navigate to Add Address Screen");
    Navigator.push(context, MaterialPageRoute(builder: (c)=> SaveAddressScreen())).then((value) {
      if (value == true) { 
        _fetchAddresses();
      }
    });
  }

  void _proceedToOrder() {
    if (_selectedAddressId != null && widget.totalAmount != null && widget.sellerUID != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlacedOrderScreen(
            addressID: _selectedAddressId.toString(), 
            totalAmount: widget.totalAmount,
            sellerUID: widget.sellerUID,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an address and ensure order details are available."), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Address"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
            colors: [
              Colors.cyan,
              Colors.amber,
            ],
            begin: FractionalOffset(0.0, 0.0),
            end: FractionalOffset(1.0, 0.0),
            stops: [0.0, 1.0],
            tileMode: TileMode.clamp,
          )),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        label: const Text("Add New Address"),
        backgroundColor: Colors.cyan,
        icon: const Icon(Icons.add_location, color: Colors.white),
        onPressed: _navigateToAddAddress,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                "Select Address:",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          Expanded( 
            child: _isLoading
                ? circularProgress()
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: TextStyle(color: Colors.red, fontSize: 16)))
                    : _addresses.isEmpty
                        ? Center(child: Text("No addresses found. Please add one.", style: TextStyle(fontSize: 16)))
                        : ListView.builder(
                            itemCount: _addresses.length,
                            itemBuilder: (context, index) {
                              return AddressDesign(
                                model: _addresses[index],
                                selectedAddressId: _selectedAddressId,
                                onSelect: _handleSelectAddress,
                              );
                            },
                          ),
          ),

          Padding(
            padding: const EdgeInsets.all(10.0),
            child: ElevatedButton(
              child: const Text("Proceed to Checkout"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan, 
                minimumSize: Size(MediaQuery.of(context).size.width * 0.9, 50) 
              ),
              onPressed: _selectedAddressId != null ? _proceedToOrder : null, 
            ),
          ),
        ],
      ),
    );
  }
}
