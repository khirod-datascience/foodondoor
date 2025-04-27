import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final IconData? data;
  final String? hintText;
  final bool? isObsecre;
  final bool? enabled;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  const CustomTextField({
    super.key,
    this.controller,
    this.data,
    this.hintText,
    this.isObsecre = false,
    this.enabled = true,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.all(
          Radius.circular(10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      margin: const EdgeInsets.all(10),
      child: TextFormField(
        enabled: enabled,
        controller: controller,
        obscureText: isObsecre!,
        keyboardType: keyboardType,
        validator: validator,
        cursorColor: Theme.of(context).primaryColor,
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: data != null
              ? Icon(
                  data,
                  color: Theme.of(context).primaryColor.withOpacity(0.7),
                )
              : null,
          hintText: hintText,
          hintStyle: TextStyle(
            color: Theme.of(context).hintColor.withOpacity(0.5),
          ),
          errorStyle: const TextStyle(
             color: Colors.redAccent,
             fontWeight: FontWeight.bold
          )
        ),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
      ),
    );
  }
}
