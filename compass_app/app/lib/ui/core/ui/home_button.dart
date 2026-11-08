// Copyright 2024 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import '../localization/applocalization.dart';
import '../themes/colors.dart';
import 'blur_filter.dart';

/// Home button to navigate back to the '/' path.
class HomeButton extends StatelessWidget {
  const HomeButton({super.key, this.blur = false});

  final bool blur;

  @override
  Widget build(BuildContext context) {
    // 48x48 tap target around the 40x40 visual, with a button role and label
    // for assistive technology.
    return Semantics(
      button: true,
      label: AppLocalization.of(context).home,
      child: SizedBox(
        height: 48.0,
        width: 48.0,
        child: InkWell(
          borderRadius: BorderRadius.circular(8.0),
          onTap: () {
            context.go(Routes.home);
          },
          child: Center(
            child: SizedBox(
              height: 40.0,
              width: 40.0,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (blur)
                    ClipRect(
                      child: BackdropFilter(
                        filter: kBlurFilter,
                        child: const SizedBox(height: 40.0, width: 40.0),
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.grey1),
                      borderRadius: BorderRadius.circular(8.0),
                      color: Colors.transparent,
                    ),
                    child: Center(
                      child: Icon(
                        size: 24.0,
                        Icons.home_outlined,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
