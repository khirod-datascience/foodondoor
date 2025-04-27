import "package:flutter/material.dart";

class Address {
  int? id;
  String? address_line_1;
  String? address_line_2;
  String? city;
  String? state;
  String? pincode;
  bool? is_default;

  Address({
    this.id,
    this.address_line_1,
    this.address_line_2,
    this.city,
    this.state,
    this.pincode,
    this.is_default,
  });

  Address.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    address_line_1 = json['address_line_1'];
    address_line_2 = json['address_line_2'];
    city = json['city'];
    state = json['state'];
    pincode = json['pincode'];
    is_default = json['is_default'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['id'] = this.id;
    data['address_line_1'] = this.address_line_1;
    data['address_line_2'] = this.address_line_2;
    data['city'] = this.city;
    data['state'] = this.state;
    data['pincode'] = this.pincode;
    data['is_default'] = this.is_default;
    return data;
  }

  String get displayAddress {
    List<String> parts = [];
    if (address_line_1?.isNotEmpty ?? false) parts.add(address_line_1!);
    if (address_line_2?.isNotEmpty ?? false) parts.add(address_line_2!);
    if (city?.isNotEmpty ?? false) parts.add(city!);
    if (state?.isNotEmpty ?? false) parts.add(state!);
    if (pincode?.isNotEmpty ?? false) parts.add(pincode!);
    return parts.join(', ');
  }
}
