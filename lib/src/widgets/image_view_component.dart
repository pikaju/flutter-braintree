import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

// This image component will fade in image when loaded successfully

class ImageViewComponent extends Image {
  static Widget _imageAnimationWidget({
    required final Widget image,
    required final bool enableAnimation,
    required final bool enableTransparency,
  }) {
    if (enableAnimation) {
      return AnimatedOpacity(
        curve: Curves.easeOut,
        opacity: enableTransparency ? 0 : 1,
        duration: const Duration(seconds: 1),
        child: image,
      );
    } else {
      return image;
    }
  }

  static Widget _errorPlaceHolderWidget(final Widget? errorPlaceholder) {
    return errorPlaceholder ?? const SizedBox();
  }

  ImageViewComponent.file({
    Key? key,
    required final File file,
    final Widget? errorPlaceholder,
    final double? width,
    final double? height,
    final BoxFit? fit = BoxFit.cover,
  }) : super.file(
         file,
         key: key,
         fit: fit,
         width: width,

         height: height,
         frameBuilder: (context, image, frame, wasSynchronouslyLoaded) {
           return _imageAnimationWidget(
             image: image,
             enableAnimation: !wasSynchronouslyLoaded,
             enableTransparency: frame == null,
           );
         },
         errorBuilder: (_, _, _) {
           return _errorPlaceHolderWidget(errorPlaceholder);
         },
       );

  ImageViewComponent.asset({
    Key? key,
    required final String path,
    final Widget? errorPlaceholder,
    final double? width,
    final double? height,
    final Color? color,
    final String? packageName,
    final BoxFit? fit = BoxFit.cover,
  }) : super.asset(
         path,
         package: packageName,
         key: key,
         fit: fit,
         width: width,
         height: height,
         color: color,
         frameBuilder: (context, image, frame, wasSynchronouslyLoaded) {
           return _imageAnimationWidget(
             image: image,
             enableAnimation: !wasSynchronouslyLoaded,
             enableTransparency: frame == null,
           );
         },
         errorBuilder: (_, _, _) {
           return _errorPlaceHolderWidget(errorPlaceholder);
         },
       );

  ImageViewComponent.memory({
    Key? key,
    required final Uint8List data,
    final Widget? errorPlaceholder,
    final double? width,
    final double? height,
    final BoxFit? fit = BoxFit.cover,
  }) : super.memory(
         data,
         key: key,
         fit: fit,
         width: width,
         height: height,
         frameBuilder: (context, image, frame, wasSynchronouslyLoaded) {
           return _imageAnimationWidget(
             image: image,
             enableAnimation: !wasSynchronouslyLoaded,
             enableTransparency: frame == null,
           );
         },
         errorBuilder: (_, _, _) {
           return _errorPlaceHolderWidget(errorPlaceholder);
         },
       );

  ImageViewComponent.network({
    Key? key,
    required final String url,
    final Widget? errorPlaceholder,
    final double? width,
    final double? height,
    final BoxFit? fit = BoxFit.cover,
  }) : super.network(
         url,
         key: key,
         fit: fit,
         width: width,
         height: height,
         frameBuilder: (context, image, frame, wasSynchronouslyLoaded) {
           return _imageAnimationWidget(
             image: image,
             enableAnimation: !wasSynchronouslyLoaded,
             enableTransparency: frame == null,
           );
         },
         errorBuilder: (_, _, _) {
           return _errorPlaceHolderWidget(errorPlaceholder);
         },
       );
}
