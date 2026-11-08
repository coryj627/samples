// Copyright 2024 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../core/localization/applocalization.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/dimens.dart';
import '../view_models/search_form_viewmodel.dart';

const String removeGuestsKey = 'remove-guests';
const String addGuestsKey = 'add-guests';

/// Number of guests selection form
///
/// Users can tap the Plus and Minus icons to increase or decrease
/// the number of guests.
class SearchFormGuests extends StatelessWidget {
  const SearchFormGuests({super.key, required this.viewModel});

  final SearchFormViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: Dimens.paddingVertical,
        left: Dimens.of(context).paddingScreenHorizontal,
        right: Dimens.of(context).paddingScreenHorizontal,
      ),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.grey1),
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.paddingHorizontal,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Semantics(
                headingLevel: 2,
                child: Text(
                  'Who',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _QuantitySelector(viewModel),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector(this.viewModel);

  final SearchFormViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    // IconButtons: 48x48 tap targets, a button role and a spoken label (the
    // tooltip) instead of bare 24px icons. The row sizes to its content so
    // the count still fits at large text scales.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const ValueKey(removeGuestsKey),
          tooltip: AppLocalization.of(context).removeGuest,
          onPressed: () {
            viewModel.guests--;
          },
          icon: const Icon(Icons.remove_circle_outline, color: AppColors.grey3),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ListenableBuilder(
            listenable: viewModel,
            builder: (context, _) => Text(
              viewModel.guests.toString(),
              style: viewModel.guests == 0
                  ? Theme.of(context).inputDecorationTheme.hintStyle
                  : Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        IconButton(
          key: const ValueKey(addGuestsKey),
          tooltip: AppLocalization.of(context).addGuest,
          onPressed: () {
            viewModel.guests++;
          },
          icon: const Icon(Icons.add_circle_outline, color: AppColors.grey3),
        ),
      ],
    );
  }
}
