import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextFormField extends StatefulWidget {
  const CustomTextFormField({
    super.key,
    required this.controller,
    this.labelText,
    this.errorText,
    this.keyboardType,
    this.isPassword = false,
    this.readOnly = false,
    this.validator,
    this.inputFormatters,
    this.onChanged,
    this.onEditingComplete,
    this.underLineInputColor,
    this.hintText,
    this.width,
    this.maxline,
    this.onTap,
    this.suffixIcon,
    this.minline,
    this.fillColor,
    this.filled,
    this.textCapitalization,
    this.enable,
    this.focusNode,
    this.maxLength,
  });

  final TextEditingController controller;
  final String? labelText;
  final String? errorText;
  final TextInputType? keyboardType;
  final bool isPassword;
  final bool readOnly;
  final int? maxline;
  final double? width;
  final Widget? suffixIcon;
  final int? minline;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final void Function()? onTap;
  final void Function(String)? onChanged;
  final void Function()? onEditingComplete;
  final Color? underLineInputColor;
  final String? hintText;
  final Color? fillColor;
  final bool? filled;
  final bool? enable;
  final FocusNode? focusNode;
  final int? maxLength;
  final TextCapitalization? textCapitalization;

  @override
  State<CustomTextFormField> createState() => _CustomTextFormFieldState();
}

class _CustomTextFormFieldState extends State<CustomTextFormField> {
  late final textTheme = Theme.of(context).textTheme;
  bool isVisible = false;
  bool hasError = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width ?? MediaQuery.sizeOf(context).width,
      child: TextFormField(
        focusNode: widget.focusNode,
        enabled: widget.enable,
        textCapitalization: widget.textCapitalization ?? TextCapitalization.none,
        onTap: widget.onTap,
        inputFormatters: widget.inputFormatters,
        readOnly: widget.readOnly,
        controller: widget.controller,
        style: textTheme.bodyMedium,
        textInputAction: TextInputAction.next,
        keyboardType: widget.keyboardType,
        cursorColor: Theme.of(context).primaryColor,
        obscureText: widget.isPassword ? !isVisible : false,
        maxLines: widget.maxline ?? 1,
        minLines: widget.minline ?? 1,
        maxLength: widget.maxLength,
        validator: (value) {
          String? validationResult = widget.validator != null
              ? widget.validator!(value)
              : (value != null && value.isEmpty)
                  ? widget.errorText
                  : null;
          setState(() {
            hasError = validationResult != null;
          });
          return validationResult;
        },
        decoration: InputDecoration(
          counterText: '',
          hintText: widget.hintText,
          hintStyle: const TextStyle(color: Colors.grey),
          fillColor: widget.fillColor,
          filled: widget.filled ?? true,
          prefixIconConstraints: BoxConstraints.tight(const Size(10, 45)),
          prefixIcon: Container(width: 0),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          labelText: widget.labelText,
          labelStyle: textTheme.bodyMedium!.copyWith(color: Colors.grey),
          errorStyle: textTheme.bodySmall!.copyWith(color: Theme.of(context).colorScheme.error),
          suffixIcon: widget.isPassword
              ? IconButton(
                  color: Colors.grey,
                  onPressed: () => setState(() {
                    isVisible = !isVisible;
                  }),
                  icon: isVisible ? const Icon(Icons.visibility) : const Icon(Icons.visibility_off),
                )
              : hasError
                  ? Icon(Icons.warning_amber_outlined, color: Theme.of(context).colorScheme.error)
                  : widget.suffixIcon,
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(
              color: Colors.grey,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(10.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
            borderRadius: BorderRadius.circular(10.0),
          ),
          disabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.grey, width: 2),
            borderRadius: BorderRadius.circular(10.0),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 2),
            borderRadius: BorderRadius.circular(10.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 2),
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
        onChanged: widget.onChanged,
        onEditingComplete: widget.onEditingComplete,
      ),
    );
  }
}
